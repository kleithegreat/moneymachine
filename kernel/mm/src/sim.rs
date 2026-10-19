//! The simulator: decisions -> orders -> fills -> positions -> funding/fees -> equity.
//!
//! Event order per 4h bar [b, b + 4h): funding settlements at b + 1h ..= b + 4h; marks at
//! the bar's close; margin check at its adverse extreme; delisting closeouts; the I5 check
//! and equity at B = b + 4h; fills at B of the orders decided at b + delta; machine ticks at
//! H + delta for H in (b, B]; and the decision at B + delta, filled at B + 4h.

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
    funding: f64,
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
    }

    fn settle(&mut self, coin: usize, price: f64, rate: f64) -> f64 {
        let paid = self.pos.get(&coin).copied().unwrap_or(0.0) * price * rate;
        self.cash -= paid;
        self.funding -= paid;
        paid
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
    pub equity: Vec<f64>,
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
    match f.why {
        Why::Fill => {
            let times = &market.bar_times[f.coin];
            let earlier = times.partition_point(|&t| t < f.submitted) < times.partition_point(|&t| t < bar.open_time);
            let ok = bar.open_time >= f.submitted
                && !earlier
                && bar.open_time <= f.filled
                && bar.trades >= 1
                && f.reference == bar.open
                && f.price == fill_price(venue, f.coin, f.qty, bar.open)
                && f.fee == fee;
            if !ok {
                return Err(Abort::Fill(format!("{f:?} vs {bar:?}")));
            }
            if f.qty.abs() * f.reference > MAX_ORDER_NOTIONAL * (1.0 + 1e-12) {
                return Err(Abort::Portfolio(format!("order notional {f:?}")));
            }
        }
        Why::Liquidation | Why::Delisting => {
            let allowed = [bar.close, if f.qty > 0.0 { bar.high } else { bar.low }];
            let ok = bar.event <= f.filled
                && allowed.contains(&f.reference)
                && f.price == fill_price(venue, f.coin, f.qty, f.reference)
                && f.fee == fee;
            if !ok {
                return Err(Abort::Fill(format!("{f:?} vs {bar:?}")));
            }
        }
    }
    Ok(())
}

struct Order {
    coin: usize,
    qty: f64,
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
    let (mut returns, mut equity_path) = (vec![], vec![]);
    let mut prev_equity = INITIAL;

    let execute = |book: &mut Book, trace: &mut Vec<Event>, f: Fill| -> Result<(), Abort> {
        check_fill(&f, market, venue)?;
        book.fill(f.coin, f.qty, f.price, f.fee);
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
        let this_bar = |c: usize| market.bar_at.get(&(c, b)).map(|&i| market.bars[i]);
        for (&c, _) in book.pos.iter() {
            if let Some(bar) = this_bar(c) {
                marks[c] = bar.close;
            }
        }
        let adverse: BTreeMap<usize, f64> = book
            .pos
            .iter()
            .map(|(&c, &q)| (c, this_bar(c).map_or(marks[c], |bar| if q > 0.0 { bar.low } else { bar.high })))
            .collect();
        let eq_adverse = book.cash + book.pos.iter().map(|(c, q)| q * adverse[c]).sum::<f64>();
        let maintenance: f64 = book.pos.iter().map(|(c, q)| q.abs() * adverse[c] / (2.0 * venue.rules[*c].min_tier_leverage)).sum();
        if !book.pos.is_empty() && eq_adverse < maintenance {
            let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
            for (c, q) in held {
                execute(&mut book, &mut trace, closeout(c, -q, adverse[&c], Why::Liquidation, b + BAR, b))?;
            }
        }
        let held: Vec<(usize, f64)> = book.pos.iter().map(|(&c, &q)| (c, q)).collect();
        for (c, q) in held {
            if b + BAR >= market.intervals[c].1 {
                execute(&mut book, &mut trace, closeout(c, -q, marks[c], Why::Delisting, b + BAR, b))?;
            }
        }

        let (e1, e2) = (book.equity(&marks), book.reconciled(&marks));
        if (e1 - e2).abs() > ACCOUNTING_TOLERANCE {
            return Err(Abort::Accounting(format!("at {}: {e1} vs {e2}", b + BAR)));
        }
        trace.push(Event::Equity { t: b + BAR, equity: e1, reconciled: e2 });
        returns.push(e1 / prev_equity - 1.0);
        equity_path.push(e1);
        prev_equity = e1;

        for o in orders.remove(&(b + BAR)).unwrap_or_default() {
            match market.bar_at.get(&(o.coin, b + BAR)).map(|&i| market.bars[i]) {
                Some(bar) if bar.trades >= 1 => {
                    let price = fill_price(venue, o.coin, o.qty, bar.open);
                    let f = Fill {
                        why: Why::Fill,
                        coin: o.coin,
                        qty: o.qty,
                        inputs_known: o.inputs_known,
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

        let big_b = b + BAR;
        let t_d = big_b + policy.delta;
        let mut weights = vec![];
        for c in 0..n {
            let (start, stop) = market.intervals[c];
            if !(start <= big_b && big_b + 2 * BAR <= stop) {
                continue;
            }
            let fresh = machine.funding[c].is_some_and(|f| f.event == big_b) && machine.bar[c].is_some_and(|x| x.event == big_b);
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
                orders.entry(big_b + BAR).or_default().push(Order { coin: c, qty, inputs_known: machine.max_known, decided: t_d });
            }
        }
        b += BAR;
    }
    Ok(Run { trace, returns, equity: equity_path })
}
