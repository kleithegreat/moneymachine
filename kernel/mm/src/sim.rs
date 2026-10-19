//! The simulator: decisions -> orders -> fills -> positions -> funding/fees -> equity.
//!
//! Event order per 4h bar [b, b + 4h): funding settlements at b + 1h ..= b + 4h; marks at
//! the bar's close; margin check at its adverse extreme; delisting closeouts; the I5 check
//! and equity at B = b + 4h; fills at B of the orders decided at b + delta; machine ticks at
//! H + delta for H in (b, B]; and the decision at B + delta, filled at B + 4h. A fill happens
//! only if a later bar will mark it, so the last equity mark accounts for every fill.

use crate::dsl::Program;
use crate::machine::Machine;
use crate::market::{Market, Policy, Venue, BAR, HOUR};
use std::collections::BTreeMap;

pub const INITIAL: f64 = 10_000.0;
pub const MAX_GROSS: f64 = 2.0;
pub const MAX_ORDER_NOTIONAL: f64 = 10_000.0;
pub const ACCOUNTING_TOLERANCE: f64 = 1e-5;

#[derive(Debug, PartialEq)]
pub enum Abort {
    Causality(String),
    Timing(String),
    Fill(String),
    Accounting(String),
    Portfolio(String),
}

impl Abort {
    pub fn code(&self) -> &'static str {
        match self {
            Abort::Causality(_) => "R_CAUSALITY",
            Abort::Timing(_) => "R_TIMING",
            Abort::Fill(_) => "R_FILL",
            Abort::Accounting(_) => "R_ACCOUNTING",
            Abort::Portfolio(_) => "R_PORTFOLIO",
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
        INITIAL + self.realized + unrealized - self.fees + self.funding
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

/// I2 and I3 (and the I9 order cap) for one fill, recomputed from the source bars.
pub fn check_fill(f: &Fill, market: &Market, venue: &Venue) -> Result<(), Abort> {
    if !(f.inputs_known <= f.decided && f.decided <= f.submitted && f.submitted <= f.filled) {
        return Err(Abort::Timing(format!("{f:?}")));
    }
    let Some(&bi) = market.bar_at.get(&(f.coin, f.source_open)) else {
        return Err(Abort::Fill(format!("no source bar {f:?}")));
    };
    let bar = market.bars[bi];
    let fee = f.qty.abs() * f.price * venue.taker_fee;
    let priced = f.qty != 0.0 && f.price == fill_price(venue, f.coin, f.qty, f.reference) && f.fee == fee;
    let times = &market.bar_times[f.coin];
    let ok = match f.why {
        Why::Fill => {
            let first = times.get(times.partition_point(|&t| t < f.submitted)).copied();
            first == Some(bar.open_time) && bar.open_time <= f.filled && bar.trades >= 1 && f.reference == bar.open
        }
        Why::Liquidation | Why::Delisting => {
            let latest = times.iter().rev().find(|&&t| market.bars[market.bar_at[&(f.coin, t)]].event <= f.filled);
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

pub fn run(prog: &Program, market: &Market, venue: &Venue, policy: &Policy, end: i64) -> Result<Run, Abort> {
    let n = venue.coins.len();
    let mut machine = Machine::new(prog, n);
    let mut f_order: Vec<usize> = (0..market.funding.len()).collect();
    f_order.sort_by_key(|&i| (market.funding[i].known, market.funding[i].coin, market.funding[i].event));
    let mut b_order: Vec<usize> = (0..market.bars.len()).collect();
    b_order.sort_by_key(|&i| (market.bars[i].known, market.bars[i].coin, market.bars[i].event));
    let (mut fi, mut bi) = (0, 0);

    let mut book = Book { cash: INITIAL, ..Book::default() };
    let mut marks = vec![f64::NAN; n];
    let mut trace = vec![];
    let mut orders: BTreeMap<i64, Vec<Order>> = BTreeMap::new();
    let (mut returns, mut gross_returns, mut equity_path) = (vec![], vec![], vec![]);
    let (mut prev_equity, mut prev_costs) = (INITIAL, 0.0);
    let mut exposures = vec![];
    let (mut cond_latest, mut cond_held): (Vec<Option<bool>>, Vec<Option<bool>>) = (vec![None; n], vec![None; n]);
    let mut value_prev = vec![0.0; n];
    let mut held_prev: Vec<bool> = vec![false; n];

    let execute = |book: &mut Book, trace: &mut Vec<Event>, f: Fill| -> Result<(), Abort> {
        check_fill(&f, market, venue)?;
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

    let mut deliver_until = |machine: &mut Machine, tick: i64| -> Result<(), Abort> {
        while fi < f_order.len() && market.funding[f_order[fi]].known <= tick {
            machine.deliver_funding(market.funding[f_order[fi]], tick).map_err(|e| Abort::Causality(format!("{e:?}")))?;
            fi += 1;
        }
        while bi < b_order.len() && market.bars[b_order[bi]].known <= tick {
            machine.deliver_bar(market.bars[b_order[bi]], tick).map_err(|e| Abort::Causality(format!("{e:?}")))?;
            bi += 1;
        }
        Ok(())
    };

    let listed = |c: usize, t: i64| market.intervals[c].0 <= t && t < market.intervals[c].1;
    deliver_until(&mut machine, policy.w_start + policy.delta)?;
    machine.tick(&(0..n).map(|c| listed(c, policy.w_start)).collect::<Vec<_>>());

    let mut b = policy.w_start;
    while b + 2 * BAR <= end {
        for h in (b + HOUR..=b + BAR).step_by(HOUR as usize) {
            let held: Vec<usize> = book.pos.keys().copied().collect();
            for coin in held {
                if let (Some(&rate), Some(&i)) = (market.rate_at.get(&(coin, h)), market.bar_at.get(&(coin, h - h % BAR))) {
                    let price = market.bars[i].open;
                    let paid = book.settle(coin, price, rate);
                    trace.push(Event::Funding { t: h, coin, rate, price, paid });
                }
            }
        }
        let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
        let latest: BTreeMap<usize, crate::market::Bar> = held
            .iter()
            .filter_map(|&(c, _)| {
                let times = &market.bar_times[c];
                let k = times.partition_point(|&t| t <= b).checked_sub(1)?;
                Some((c, market.bars[market.bar_at[&(c, times[k])]]))
            })
            .collect();
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
            if b + BAR >= market.intervals[c].1 {
                execute(&mut book, &mut trace, closeout(c, -q, marks[c], Why::Delisting, b + BAR, latest[&c].open_time))?;
            }
        }

        let (e1, e2) = (book.equity(&marks), book.reconciled(&marks));
        if (e1 - e2).abs() > ACCOUNTING_TOLERANCE {
            return Err(Abort::Accounting(format!("at {}: {e1} vs {e2}", b + BAR)));
        }
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
        returns.push(e1 / prev_equity - 1.0);
        gross_returns.push((e1 - prev_equity + book.costs() - prev_costs) / prev_equity);
        equity_path.push(e1);
        prev_equity = e1;
        prev_costs = book.costs();

        let fills = orders.remove(&(b + BAR)).unwrap_or_default();
        for o in if b + 3 * BAR <= end { fills } else { vec![] } {
            match market.bar_at.get(&(o.coin, b + BAR)).map(|&i| market.bars[i]) {
                Some(bar) if bar.trades >= 1 => {
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
            let tick = h + policy.delta;
            deliver_until(&mut machine, tick)?;
            machine.tick(&(0..n).map(|c| listed(c, h)).collect::<Vec<_>>());
        }

        for c in 0..n {
            held_prev[c] = book.pos.contains_key(&c);
        }
        cond_held.clone_from(&cond_latest);

        let big_b = b + BAR;
        let t_d = big_b + policy.delta;
        let mut weights = vec![];
        for c in 0..n {
            let (start, stop) = market.intervals[c];
            if !(start <= big_b && big_b + 2 * BAR <= stop) {
                continue;
            }
            let fresh = machine.funding[c].is_some_and(|f| f.event == big_b) && machine.bar[c].is_some_and(|x| x.event == big_b);
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
        let gross: f64 = weights.iter().map(|(_, w)| w.abs()).sum();
        let scale = if gross > MAX_GROSS { MAX_GROSS / gross } else { 1.0 };
        if gross * scale > MAX_GROSS * (1.0 + 1e-12) {
            return Err(Abort::Portfolio(format!("gross {gross} at {t_d}")));
        }
        for (c, w) in weights {
            let w = w * scale;
            let price = machine.bar[c].unwrap().close;
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
        b += BAR;
    }
    Ok(Run { trace, returns, gross_returns, equity: equity_path, exposures })
}
