//! The simulator from Lean's `Ctx` (reference/lean/Ref/Sim.lean): decisions -> orders -> fills -> positions ->
//! funding/fees -> equity.
//!
//! Event order per 4h bar [b, b + 4h): funding settlements at b + 1h ..= b + 4h; marks at
//! the bar's close; margin check at its adverse extreme; delisting closeouts; the I5 check
//! and equity at B = b + 4h; fills at B of the orders decided at b + delta; machine ticks at
//! H + delta for H in (b, B]; and the decision at B + delta, filled at B + 4h. A fill happens
//! only if a later bar will mark it, so the last equity mark accounts for every fill.

use crate::dsl::Program;
use crate::machine::{Machine, Obs, RolePayload};
use crate::market::{Market, Policy, Venue, BAR, HOUR};
use std::collections::{BTreeMap, HashMap};

pub const INITIAL: f64 = 10_000.0;
pub const MAX_GROSS: f64 = 2.0;
pub const MAX_ORDER_NOTIONAL: f64 = 10_000.0;
/// I5: the two equities agree within 1e-9 of max(|e1|, 10,000, `peak`), `peak` being the largest |e1| the run reached
/// at an earlier step (revision of 2026-10-27); a non-finite e1 fails.
pub fn accounting_ok(e1: f64, e2: f64, peak: f64) -> bool {
    let scale = 10_000.0_f64.max(e1.abs()).max(peak);
    (e1 - e2).abs() / scale <= 1e-9
}
/// B: no step loses more than the account's equity, so every step return is at least −B.
pub const LOSS_BOUND: f64 = 1.0;

#[derive(Debug, PartialEq)]
pub enum Abort {
    Causality(String),
    Timing(String),
    Fill(String),
    Accounting(String),
    Portfolio(String),
    Bound(String),
    InputUnavailable(String),
    SettlementMissing(String),
    Uncertified(String),
    Holdout(String),
    Roles(String),
    Binding(String),
    Invalid(String),
}

impl Abort {
    pub fn code(&self) -> &'static str {
        match self {
            Abort::Causality(_) => "R_CAUSALITY",
            Abort::Timing(_) => "R_TIMING",
            Abort::Fill(_) => "R_FILL",
            Abort::Accounting(_) => "R_ACCOUNTING",
            Abort::Portfolio(_) => "R_PORTFOLIO",
            Abort::Bound(_) => "R_BOUND",
            Abort::InputUnavailable(_) => "R_INPUT_UNAVAILABLE",
            Abort::SettlementMissing(_) => "R_SETTLEMENT_MISSING",
            Abort::Uncertified(_) => "R_UNCERTIFIED",
            Abort::Holdout(_) => "R_HOLDOUT",
            Abort::Roles(_) => "R_ROLES",
            Abort::Binding(_) => "R_BINDING",
            Abort::Invalid(_) => "R_INVALID",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Why {
    Fill,
    Liquidation,
    Delisting,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Fill {
    pub why: Why,
    pub coin: usize,
    pub qty: f64,
    pub inputs_known: i64,
    /// Price the order was sized at: the close of the bar ending at the decision's boundary.
    pub decision_price: f64,
    pub decided: i64,
    pub submitted: i64,
    pub filled: i64,
    /// openTime of the source bar; for closeouts, the bar whose close or extreme is used.
    pub source_open: i64,
    pub reference: f64,
    pub price: f64,
    pub fee: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Decision { t: i64, coin: usize, weight: f64, qty: f64 },
    Hold { t: i64, coin: usize, why: &'static str },
    Fill(Fill),
    Unfilled { t: i64, coin: usize, qty: f64 },
    Funding { t: i64, coin: usize, rate: f64, price: f64, paid: f64 },
    Equity { t: i64, equity: f64, reconciled: f64 },
}

/// Cash account plus an independent average-entry ledger used only to check it (I5).
#[derive(Default)]
struct Book {
    cash: f64,
    pos: BTreeMap<usize, f64>,
    entry: BTreeMap<usize, f64>,
    realized: f64,
    fees: f64,
    slippage: f64,
    funding: f64,
    /// Shortfalls the venue absorbed when the account went bankrupt.
    absorbed: f64,
    /// Per-coin cash flows (trades, fees, funding), for per-coin PnL attribution.
    coin_cash: BTreeMap<usize, f64>,
}

impl Book {
    fn fill(&mut self, coin: usize, qty: f64, price: f64, fee: f64) {
        let old = self.pos.get(&coin).copied().unwrap_or(0.0);
        let new = old + qty;
        if old != 0.0 && (old > 0.0) != (qty > 0.0) {
            let closed = qty.abs().min(old.abs()) * old.signum();
            self.realized += closed * (price - self.entry[&coin]);
        }
        if new == 0.0 {
            self.entry.remove(&coin);
            self.pos.remove(&coin);
        } else {
            if old == 0.0 || (old > 0.0) != (new > 0.0) {
                self.entry.insert(coin, price);
            } else if (old > 0.0) == (qty > 0.0) {
                let e = self.entry[&coin];
                self.entry.insert(coin, (old * e + qty * price) / new);
            }
            self.pos.insert(coin, new);
        }
        self.cash -= qty * price + fee;
        self.fees += fee;
        *self.coin_cash.entry(coin).or_default() -= qty * price + fee;
    }

    fn costs(&self) -> f64 {
        self.fees + self.slippage
    }

    fn settle(&mut self, coin: usize, price: f64, rate: f64) -> f64 {
        let paid = self.pos.get(&coin).copied().unwrap_or(0.0) * price * rate;
        self.cash -= paid;
        self.funding -= paid;
        *self.coin_cash.entry(coin).or_default() -= paid;
        paid
    }

    fn coin_value(&self, coin: usize, marks: &[f64]) -> f64 {
        let q = self.pos.get(&coin).copied().unwrap_or(0.0);
        self.coin_cash.get(&coin).copied().unwrap_or(0.0) + if q != 0.0 { q * marks[coin] } else { 0.0 }
    }

    fn equity(&self, marks: &[f64]) -> f64 {
        self.cash + self.pos.iter().map(|(&c, q)| q * marks[c]).sum::<f64>()
    }

    fn reconciled(&self, marks: &[f64]) -> f64 {
        let unrealized: f64 = self.pos.iter().map(|(&c, q)| q * (marks[c] - self.entry[&c])).sum();
        INITIAL + self.realized + unrealized - self.fees + self.funding + self.absorbed
    }

    /// Losses are capped at the account's equity: once flat, the venue absorbs a negative balance.
    fn absorb(&mut self) {
        self.absorbed -= self.cash;
        self.cash = 0.0;
    }
}

pub struct Run {
    pub trace: Vec<Event>,
    /// Equity return of each 4h step.
    pub returns: Vec<f64>,
    /// The same before fees and slippage: (change in equity + that step's costs) / previous equity.
    pub gross_returns: Vec<f64>,
    pub equity: Vec<f64>,
    /// Per (coin, decision interval) with a position: the prediction condition at the decision
    /// that set it, and the coin's net PnL over the interval over the previous equity.
    pub exposures: Vec<(bool, f64)>,
}

fn truncate(x: f64, decimals: i32) -> f64 {
    let f = 10f64.powi(decimals);
    (x * f).trunc() / f
}

/// Cost in bps for an order, from the cost table by side and notional.
pub fn cost_bps(venue: &Venue, coin: usize, qty: f64, reference: f64) -> f64 {
    let side = if qty > 0.0 { 0 } else { 1 };
    let size = if qty.abs() * reference <= 1000.0 { 0 } else { 1 };
    venue.rules[coin].cost_bps[side][size]
}

pub fn fill_price(venue: &Venue, coin: usize, qty: f64, reference: f64) -> f64 {
    let bps = cost_bps(venue, coin, qty, reference);
    reference * (1.0 + qty.signum() * bps / 1e4)
}

/// A bar as execution reads it: the bars provider's final role payload (Lean's `BarRow`).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BarRow {
    pub coin: usize,
    pub open_time: i64,
    pub event: i64,
    pub known: i64,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub trades: i64,
}

/// The bars provider's final observations, as execution reads them (Lean's `barRow`).
pub fn bar_rows(market: &Market) -> Vec<BarRow> {
    let bar = |o: &Obs| match o.role {
        Some(RolePayload::Bar { open, high, low, close, trades }) if o.source == market.roles.bars && o.last => {
            Some(BarRow { coin: o.coin, open_time: o.key - BAR, event: o.key, known: o.known, open, high, low, close, trades })
        }
        _ => None,
    };
    market.obs.iter().filter_map(bar).collect()
}

/// Execution's lookups (Lean's `Index`): a bar by (coin, openTime), each coin's sorted openTimes, a settlement rate by
/// (coin, event time).
pub struct Index {
    pub bar_at: HashMap<(usize, i64), usize>,
    pub bar_times: Vec<Vec<i64>>,
    pub rate_at: HashMap<(usize, i64), f64>,
}

impl Index {
    pub fn of(bars: &[BarRow], rates: impl IntoIterator<Item = ((usize, i64), f64)>, coins: usize) -> Index {
        let mut bar_times = vec![vec![]; coins];
        for b in bars {
            bar_times[b.coin].push(b.open_time);
        }
        for t in &mut bar_times {
            t.sort();
        }
        Index { bar_at: bars.iter().enumerate().map(|(i, b)| ((b.coin, b.open_time), i)).collect(), bar_times, rate_at: rates.into_iter().collect() }
    }

    /// Coin c's latest bar opened by t (Lean's `latestOf`).
    fn latest(&self, bars: &[BarRow], c: usize, t: i64) -> Option<BarRow> {
        let times = &self.bar_times[c];
        let k = times.partition_point(|&u| u <= t).checked_sub(1)?;
        Some(bars[self.bar_at[&(c, times[k])]])
    }
}

/// I2 and I3 (and the I9 order cap) for one fill, recomputed from the source bars.
pub fn check_fill(f: &Fill, bars: &[BarRow], ix: &Index, venue: &Venue) -> Result<(), Abort> {
    if !(f.inputs_known <= f.decided && f.decided <= f.submitted && f.submitted <= f.filled) {
        return Err(Abort::Timing(format!("{f:?}")));
    }
    let Some(&bi) = ix.bar_at.get(&(f.coin, f.source_open)) else {
        return Err(Abort::Fill(format!("no source bar {f:?}")));
    };
    let bar = bars[bi];
    let fee = f.qty.abs() * f.price * venue.taker_fee;
    let priced = f.qty != 0.0 && f.price == fill_price(venue, f.coin, f.qty, f.reference) && f.fee == fee;
    let times = &ix.bar_times[f.coin];
    let ok = match f.why {
        Why::Fill => {
            let first = times.get(times.partition_point(|&t| t < f.submitted)).copied();
            first == Some(bar.open_time) && bar.open_time <= f.filled && bar.trades >= 1 && f.reference == bar.open
        }
        Why::Liquidation | Why::Delisting => {
            let latest = times.iter().rev().find(|&&t| bars[ix.bar_at[&(f.coin, t)]].event <= f.filled);
            let reference = match f.why {
                Why::Delisting => bar.close,
                _ if f.qty > 0.0 => bar.high,
                _ => bar.low,
            };
            latest == Some(&bar.open_time) && f.reference == reference
        }
    };
    if !(ok && priced) {
        return Err(Abort::Fill(format!("{f:?} vs {bar:?}")));
    }
    if f.why == Why::Fill && f.qty.abs() * f.decision_price > MAX_ORDER_NOTIONAL * (1.0 + 1e-12) {
        return Err(Abort::Portfolio(format!("order notional {f:?}")));
    }
    Ok(())
}

struct Order {
    coin: usize,
    qty: f64,
    price: f64,
    inputs_known: i64,
    decided: i64,
}

/// Everything a run fixes before its first step (Lean's `Ctx`).
pub struct Ctx<'a> {
    prog: &'a Program,
    market: &'a Market,
    venue: &'a Venue,
    policy: &'a Policy,
    stop: i64,
    /// Positions in `market.obs`, in delivery order.
    order: Vec<usize>,
    bars: Vec<BarRow>,
    ix: Index,
}

impl<'a> Ctx<'a> {
    /// Lean's `Ctx.make`: the observations in delivery order (knownAt, source, coin, tie, position), the tie being (event
    /// time, recording time) for a held source and (recording time, event time) for an event source, the one with a
    /// slot; execution's bars and rates from the role providers' final observations.
    pub fn make(prog: &'a Program, market: &'a Market, venue: &'a Venue, policy: &'a Policy, stop: i64) -> Ctx<'a> {
        let obs = &market.obs;
        let tie = |o: &Obs| if o.slot.is_some() { (o.recorded, o.key) } else { (o.key, o.recorded) };
        let mut order: Vec<usize> = (0..obs.len()).collect();
        order.sort_by_key(|&i| (obs[i].known, obs[i].source, obs[i].coin, tie(&obs[i])));
        let bars = bar_rows(market);
        let rates = obs.iter().filter_map(|o| match o.role {
            Some(RolePayload::Rate(r)) if o.source == market.roles.settlement && o.last => Some(((o.coin, o.key), r)),
            _ => None,
        });
        let ix = Index::of(&bars, rates, market.intervals.len());
        Ctx { prog, market, venue, policy, stop, order, bars, ix }
    }

    fn coins(&self) -> usize {
        self.market.intervals.len()
    }

    fn listed(&self, c: usize, t: i64) -> bool {
        let (start, end) = self.market.intervals[c];
        start <= t && t < end
    }

    fn mask(&self, t: i64) -> Vec<bool> {
        (0..self.coins()).map(|c| self.listed(c, t)).collect()
    }

    fn machine(&self) -> Machine<'a> {
        Machine::new(self.prog, self.market.bound.len(), self.coins())
    }

    /// Deliver every observation known by `tick` from position `next` of the delivery order on (SEMANTICS.md §3).
    pub fn deliver(&self, machine: &mut Machine, next: &mut usize, tick: i64) -> Result<(), Abort> {
        while let Some(o) = self.order.get(*next).map(|&i| &self.market.obs[i]).filter(|o| o.known <= tick) {
            machine.deliver(o.clone(), tick).map_err(|e| Abort::Causality(format!("{e:?}")))?;
            *next += 1;
        }
        Ok(())
    }

    /// The step boundaries (Lean's `Ctx.bounds`): b = wStart, wStart + BAR, … while b + 2·BAR ≤ stop.
    fn bounds(&self) -> impl Iterator<Item = i64> + '_ {
        (0..).map(|k| self.policy.w_start + k * BAR).take_while(|b| b + 2 * BAR <= self.stop)
    }

    /// Whether coin c's latest observation of `source` is the live record of the bar-hour `big_b`.
    fn fresh(&self, machine: &Machine, source: usize, c: usize, big_b: i64) -> bool {
        machine.latest[source][c].as_ref().is_some_and(|o| o.key == big_b && o.role.is_some())
    }

    /// Drive a machine over the run's tick schedule alone (wStart, then each hour of every step, no orders), handing
    /// `emit` each tick's hour and the machine after its deliveries and tick.
    pub fn observe(&self, mut emit: impl FnMut(i64, &Machine) -> Result<(), String>) -> Result<(), String> {
        let mut machine = self.machine();
        let mut next = 0;
        let w_start = self.policy.w_start;
        let hours = std::iter::once(w_start).chain((1..=4 * self.bounds().count() as i64).map(|k| w_start + k * HOUR));
        for h in hours {
            self.deliver(&mut machine, &mut next, h + self.policy.delta).map_err(|e| format!("{e:?}"))?;
            machine.tick(&self.mask(h), h);
            emit(h, &machine)?;
        }
        Ok(())
    }

    /// Lean's `Ctx.evaluate`: its trace and returns, or the abort.
    pub fn evaluate(&self) -> Result<Run, Abort> {
        let (venue, policy, roles, bars, ix, end) = (self.venue, self.policy, self.market.roles, &self.bars[..], &self.ix, self.stop);
        let n = self.coins();
        let mut machine = self.machine();
        let mut next = 0;

        let mut book = Book { cash: INITIAL, ..Book::default() };
        let mut marks = vec![f64::NAN; n];
        let mut trace = vec![];
        let mut orders: BTreeMap<i64, Vec<Order>> = BTreeMap::new();
        let (mut returns, mut gross_returns, mut equity_path) = (vec![], vec![], vec![]);
        let (mut prev_equity, mut prev_costs, mut peak_equity) = (INITIAL, 0.0, 0.0_f64);
        let mut exposures = vec![];
        let (mut cond_latest, mut cond_held): (Vec<Option<bool>>, Vec<Option<bool>>) = (vec![None; n], vec![None; n]);
        let mut value_prev = vec![0.0; n];
        let mut held_prev: Vec<bool> = vec![false; n];

        let execute = |book: &mut Book, trace: &mut Vec<Event>, f: Fill| -> Result<(), Abort> {
            check_fill(&f, bars, ix, venue)?;
            book.fill(f.coin, f.qty, f.price, f.fee);
            book.slippage += f.qty * (f.price - f.reference);
            trace.push(Event::Fill(f));
            Ok(())
        };
        let closeout = |coin: usize, qty: f64, reference: f64, why: Why, t: i64, source_open: i64| {
            let price = fill_price(venue, coin, qty, reference);
            Fill {
                why,
                coin,
                qty,
                inputs_known: t,
                decision_price: reference,
                decided: t,
                submitted: t,
                filled: t,
                source_open,
                reference,
                price,
                fee: qty.abs() * price * venue.taker_fee,
            }
        };

        self.deliver(&mut machine, &mut next, policy.w_start + policy.delta)?;
        machine.tick(&self.mask(policy.w_start), policy.w_start);

        for b in self.bounds() {
            for h in (b + HOUR..=b + BAR).step_by(HOUR as usize) {
                let held: Vec<usize> = book.pos.keys().copied().filter(|&c| self.listed(c, h)).collect();
                for coin in held {
                    let (Some(&rate), Some(bar)) = (ix.rate_at.get(&(coin, h)), ix.latest(bars, coin, h)) else {
                        return Err(Abort::SettlementMissing(format!("coin {coin} at {h}: no funding row or no bar to price it")));
                    };
                    let price = bar.open;
                    let paid = book.settle(coin, price, rate);
                    trace.push(Event::Funding { t: h, coin, rate, price, paid });
                }
            }
            let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
            let latest: BTreeMap<usize, BarRow> = held.iter().filter_map(|&(c, _)| Some((c, ix.latest(bars, c, b)?))).collect();
            for (&c, bar) in &latest {
                marks[c] = bar.close;
            }
            let adverse = |c: usize, q: f64| latest.get(&c).map_or(marks[c], |bar| if q > 0.0 { bar.low } else { bar.high });
            let eq_adverse = book.cash + held.iter().map(|&(c, q)| q * adverse(c, q)).sum::<f64>();
            let maintenance: f64 = held.iter().map(|&(c, q)| q.abs() * adverse(c, q) / (2.0 * venue.rules[c].min_tier_leverage)).sum();
            if !held.is_empty() && eq_adverse < maintenance {
                for &(c, q) in &held {
                    let bar = latest[&c];
                    execute(&mut book, &mut trace, closeout(c, -q, adverse(c, q), Why::Liquidation, b + BAR, bar.open_time))?;
                }
            }
            let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
            for (c, q) in held {
                if b + BAR >= self.market.intervals[c].1 {
                    execute(&mut book, &mut trace, closeout(c, -q, marks[c], Why::Delisting, b + BAR, latest[&c].open_time))?;
                }
            }

            if !(book.equity(&marks) > 0.0) {
                let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
                for (c, q) in held {
                    execute(&mut book, &mut trace, closeout(c, -q, adverse(c, q), Why::Liquidation, b + BAR, latest[&c].open_time))?;
                }
                book.absorb();
            }

            let (e1, e2) = (book.equity(&marks), book.reconciled(&marks));
            if !accounting_ok(e1, e2, peak_equity) {
                return Err(Abort::Accounting(format!("at {}: {e1} vs {e2}", b + BAR)));
            }
            peak_equity = peak_equity.max(e1.abs());
            trace.push(Event::Equity { t: b + BAR, equity: e1, reconciled: e2 });
            for c in 0..n {
                let v = book.coin_value(c, &marks);
                if held_prev[c] {
                    if let Some(cond) = cond_held[c] {
                        exposures.push((cond, (v - value_prev[c]) / prev_equity));
                    }
                }
                value_prev[c] = v;
            }
            let (r, gross) = if prev_equity > 0.0 {
                (if e1 > 0.0 { e1 / prev_equity - 1.0 } else { -LOSS_BOUND }, (e1 - prev_equity + book.costs() - prev_costs) / prev_equity)
            } else {
                (0.0, 0.0)
            };
            if !(r >= -LOSS_BOUND) {
                return Err(Abort::Bound(format!("return {r} at {}", b + BAR)));
            }
            returns.push(r);
            gross_returns.push(gross);
            equity_path.push(e1);
            prev_equity = e1;
            prev_costs = book.costs();

            let fills = orders.remove(&(b + BAR)).unwrap_or_default();
            for o in if b + 3 * BAR <= end { fills } else { vec![] } {
                match ix.bar_at.get(&(o.coin, b + BAR)).map(|&i| bars[i]) {
                    Some(bar) if bar.trades >= 1 && e1 > 0.0 => {
                        let price = fill_price(venue, o.coin, o.qty, bar.open);
                        let f = Fill {
                            why: Why::Fill,
                            coin: o.coin,
                            qty: o.qty,
                            inputs_known: o.inputs_known,
                            decision_price: o.price,
                            decided: o.decided,
                            submitted: o.decided,
                            filled: b + BAR,
                            source_open: b + BAR,
                            reference: bar.open,
                            price,
                            fee: o.qty.abs() * price * venue.taker_fee,
                        };
                        execute(&mut book, &mut trace, f)?;
                    }
                    _ => trace.push(Event::Unfilled { t: b + BAR, coin: o.coin, qty: o.qty }),
                }
            }

            for h in (b + HOUR..=b + BAR).step_by(HOUR as usize) {
                self.deliver(&mut machine, &mut next, h + policy.delta)?;
                machine.tick(&self.mask(h), h);
            }

            for c in 0..n {
                held_prev[c] = book.pos.contains_key(&c);
            }
            cond_held.clone_from(&cond_latest);

            let big_b = b + BAR;
            let t_d = big_b + policy.delta;
            let mut weights = vec![];
            for c in 0..n {
                let (start, stop) = self.market.intervals[c];
                if !(start <= big_b && big_b + 2 * BAR <= stop) {
                    continue;
                }
                let fresh = self.fresh(&machine, roles.bars, c, big_b) && self.fresh(&machine, roles.settlement, c, big_b);
                cond_latest[c] = machine.condition(c);
                if !fresh {
                    trace.push(Event::Hold { t: t_d, coin: c, why: "stale" });
                    continue;
                }
                match machine.weight(c) {
                    Some(w) => weights.push((c, w)),
                    None => trace.push(Event::Hold { t: t_d, coin: c, why: "undefined" }),
                }
            }
            let largest = weights.iter().map(|(_, w)| w.abs()).fold(0.0, f64::max);
            let relative: f64 = weights.iter().map(|(_, w)| w.abs() / largest).sum();
            let scaled = |w: f64| if relative * largest > MAX_GROSS { w / largest * (MAX_GROSS / relative) } else { w };
            let gross: f64 = weights.iter().map(|(_, w)| scaled(*w).abs()).sum();
            if !(gross <= MAX_GROSS * (1.0 + 1e-12)) {
                return Err(Abort::Portfolio(format!("gross {gross} at {t_d}")));
            }
            for (c, w) in weights {
                let w = scaled(w);
                let price = match machine.latest[roles.bars][c].as_ref().and_then(|o| o.role) {
                    Some(RolePayload::Bar { close, .. }) => close,
                    _ => 0.0,
                };
                let held = book.pos.get(&c).copied().unwrap_or(0.0);
                let dec = venue.rules[c].sz_decimals;
                let mut qty = if w == 0.0 { -held } else { truncate(w * e1 / price - held, dec) };
                if qty.abs() * price > MAX_ORDER_NOTIONAL {
                    qty = qty.signum() * truncate(MAX_ORDER_NOTIONAL / price, dec);
                }
                if qty != 0.0 && (qty.abs() * price >= venue.min_notional || w == 0.0) {
                    trace.push(Event::Decision { t: t_d, coin: c, weight: w, qty });
                    orders.entry(big_b + BAR).or_default().push(Order { coin: c, qty, price, inputs_known: machine.max_known, decided: t_d });
                }
            }
        }
        Ok(Run { trace, returns, gross_returns, equity: equity_path, exposures })
    }
}

/// A run of `prog` on `market`: R_INPUT_UNAVAILABLE if the program reads a source the store does not bind (SEMANTICS.md
/// §8, stage 1's check until admission is wired, port plan slice 6), else `Ctx::evaluate`.
pub fn run(prog: &Program, market: &Market, venue: &Venue, policy: &Policy, end: i64) -> Result<Run, Abort> {
    if let Some(s) = prog.sources().into_iter().find(|&s| !market.bound[s]) {
        let input = prog.inputs.iter().find(|i| i.source == s).map_or("", |i| i.name.as_str());
        return Err(Abort::InputUnavailable(format!("{input}: its source is not bound in this store")));
    }
    Ctx::make(prog, market, venue, policy, end).evaluate()
}
