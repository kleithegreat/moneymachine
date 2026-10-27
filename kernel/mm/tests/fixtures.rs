//! C1.3: hand-computed scenarios. One coin X, 4h bars k = 0.. opening at k*BAR, cost
//! 10 bps on every cell, fee 0.1%, min notional $10, szDecimals 3, initial equity $10,000. Expected
//! numbers are worked out by hand in the comments; each scenario asserts the cash, position, fees,
//! funding and equity behind one reported equity, to 1e-9 (decimal hand arithmetic is not exactly
//! representable in binary floating point).

use mm::dsl;
use mm::market::{Bar, CoinRules, Funding, Market, Policy, Venue, BAR, HOUR};
use mm::sim::{self, Event, Why};

const DELTA: i64 = 120_000;

struct Spec {
    opens: Vec<f64>,
    closes: Vec<f64>,
    highs: Option<Vec<f64>>,
    lows: Option<Vec<f64>>,
    trades: Vec<i64>,
    /// (hour index, rate, premium) for nonzero rows; every hour has a row unless listed in `missing`.
    funding: Vec<(i64, f64, f64)>,
    missing_funding: Vec<i64>,
    missing_bars: Vec<usize>,
    leverage: f64,
    delisted_at: Option<i64>,
}

impl Spec {
    fn new(opens: &[f64], closes: &[f64]) -> Spec {
        Spec {
            opens: opens.to_vec(),
            closes: closes.to_vec(),
            highs: None,
            lows: None,
            trades: vec![1; opens.len()],
            funding: vec![],
            missing_funding: vec![],
            missing_bars: vec![],
            leverage: 10.0,
            delisted_at: None,
        }
    }

    fn build(&self) -> (Market, Venue, Policy, i64) {
        let n = self.opens.len() as i64;
        let end = n * BAR;
        let bars: Vec<Bar> = (0..n as usize)
            .filter(|k| !self.missing_bars.contains(k))
            .map(|k| {
                let (o, c) = (self.opens[k], self.closes[k]);
                Bar {
                    coin: 0,
                    open_time: k as i64 * BAR,
                    event: (k as i64 + 1) * BAR,
                    known: (k as i64 + 1) * BAR + DELTA,
                    open: o,
                    high: self.highs.as_ref().map_or(o.max(c) + 1.0, |h| h[k]),
                    low: self.lows.as_ref().map_or(o.min(c) - 1.0, |l| l[k]),
                    close: c,
                    volume: 1.0,
                    trades: self.trades[k],
                }
            })
            .collect();
        let funding: Vec<Funding> = (0..=n * 4)
            .filter(|h| !self.missing_funding.contains(h) && self.delisted_at.is_none_or(|d| h * HOUR < d))
            .map(|h| {
                let (rate, premium) = self.funding.iter().find(|f| f.0 == h).map_or((0.0, 0.0), |f| (f.1, f.2));
                Funding { coin: 0, event: h * HOUR, known: h * HOUR + DELTA, rate, premium }
            })
            .collect();
        let mut bar_times = vec![bars.iter().map(|b| b.open_time).collect::<Vec<_>>()];
        bar_times[0].sort();
        let market = Market {
            bar_at: bars.iter().enumerate().map(|(i, b)| ((b.coin, b.open_time), i)).collect(),
            rate_at: funding.iter().map(|f| ((f.coin, f.event), f.rate)).collect(),
            bar_times,
            intervals: vec![(0, self.delisted_at.unwrap_or(end))],
            events: std::collections::HashMap::new(),
            funding,
            bars,
            data_hash: String::new(),
        };
        let venue = Venue {
            taker_fee: 0.001,
            min_notional: 10.0,
            coins: vec!["X".into()],
            rules: vec![CoinRules {
                sz_decimals: 3,
                min_tier_leverage: self.leverage,
                delisted: self.delisted_at.is_some(),
                cost_bps: [[10.0, 10.0], [10.0, 10.0]],
                calibration_range: None,
            }],
            rules_hash: String::new(),
            execution_hash: String::new(),
        };
        (market, venue, Policy { delta: DELTA, settlement_latency: 60_000, w_start: 0, holdout_start: i64::MAX, w_end: end }, end)
    }

    fn run(&self, weight: &str) -> Result<sim::Run, sim::Abort> {
        self.run_with(weight, "")
    }

    fn run_with(&self, weight: &str, extra: &str) -> Result<sim::Run, sim::Abort> {
        let prog = dsl::parse(&format!(
            r#"{{"dsl": 1, "name": "fixture", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}},
                "weight": {weight}{extra}}}"#
        ))
        .unwrap();
        let (m, v, p, end) = self.build();
        sim::run(&prog, &m, &v, &p, end)
    }
}

const HALF: &str = r#"{"const": 0.5, "unit": "1"}"#;

fn fills(run: &sim::Run) -> Vec<&sim::Fill> {
    run.trace.iter().filter_map(|e| if let Event::Fill(f) = e { Some(f) } else { None }).collect()
}

fn equity_at(run: &sim::Run, t: i64) -> f64 {
    run.trace.iter().find_map(|e| match e { Event::Equity { t: u, equity, .. } if *u == t => Some(*equity), _ => None }).unwrap()
}

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

/// The account behind the equity reported at `t`: every fill and settlement before that equity in the trace, as
/// (cash, position, fees, funding paid).
fn account(run: &sim::Run, t: i64) -> (f64, f64, f64, f64) {
    let (mut cash, mut pos, mut fees, mut funding) = (10_000.0, 0.0, 0.0, 0.0);
    for e in &run.trace {
        match e {
            Event::Equity { t: u, .. } if *u == t => return (cash, pos, fees, funding),
            Event::Fill(f) => {
                cash -= f.qty * f.price + f.fee;
                pos += f.qty;
                fees += f.fee;
            }
            Event::Funding { paid, .. } => {
                cash -= paid;
                funding += paid;
            }
            _ => {}
        }
    }
    panic!("no equity at {t}")
}

/// Asserts the hand-computed (cash, position, fees, funding, equity) behind the equity at `t`.
fn assert_account(run: &sim::Run, t: i64, expect: (f64, f64, f64, f64, f64)) {
    let (cash, pos, fees, funding) = account(run, t);
    let got = (cash, pos, fees, funding, equity_at(run, t));
    assert!(close(got.0, expect.0) && close(got.1, expect.1) && close(got.2, expect.2) && close(got.3, expect.3) && close(got.4, expect.4),
            "at {t}: got {got:?}, expected {expect:?}");
}

/// Delayed fill, fees, funding settlement, mark-to-market and rebalancing.
#[test]
fn delayed_fill_fees_funding_and_rebalance() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 120.0, 120.0], &[100.0, 110.0, 120.0, 120.0, 120.0, 120.0]);
    s.funding = vec![(8, 0.01, 0.0), (10, 0.001, 0.0)];
    let run = s.run(HALF).unwrap();
    let f = fills(&run);
    // Decision at 4h+d sees close0 = 100: qty = 0.5*10000/100 = 50. Fills at 8h at the open
    // of bar 2 (110) plus 10 bps = 110.11; fee = 50 * 110.11 * 0.001 = 5.5055.
    assert_eq!((f[0].decided, f[0].filled, f[0].source_open), (4 * HOUR + DELTA, 8 * HOUR, 8 * HOUR));
    assert!(close(f[0].qty, 50.0) && close(f[0].price, 110.11) && close(f[0].fee, 5.5055));
    // The 1% rate at 8h settles before the 8h fill, on a zero position: no payment.
    assert!(!run.trace.iter().any(|e| matches!(e, Event::Funding { t, .. } if *t == 8 * HOUR)));
    // Decision at 8h+d sees the 8h fill: target 0.5*10000/110 = 45.4545..., qty -4.545.
    assert!(close(f[1].qty, -4.545) && close(f[1].price, 119.88) && f[1].filled == 12 * HOUR);
    // 10h funding: 50 * open(bar 2) = 110 * 0.001 = 5.5 paid by the long.
    let paid: f64 = run.trace.iter().filter_map(|e| if let Event::Funding { paid, .. } = e { Some(*paid) } else { None }).sum();
    assert!(close(paid, 5.5));
    // Equity at 12h: cash 10000 - 5505.5 - 5.5055 - 5.5 = 4483.4945, plus 50 * close2 120.
    assert_account(&run, 12 * HOUR, (4483.4945, 50.0, 5.5055, 5.5, 10483.4945));
    // 12h fill: +4.545 * 119.88 - fee 0.5448546. Equity at 16h = 5027.8042454 + 45.455 * 120.
    assert!(close(f[1].fee, 0.5448546));
    assert!(close(equity_at(&run, 16 * HOUR), 5027.8042454 + 45.455 * 120.0));
    // Decision at 12h+d: target 0.5 * 10483.4945 / 120 = 43.681227..., qty -1.773.
    assert!(close(f[2].qty, -1.773));
}

/// A short receives positive funding: the payment's sign follows the position's.
#[test]
fn short_receives_funding() {
    let mut s = Spec::new(&[100.0; 5], &[100.0; 5]);
    s.funding = vec![(10, 0.002, 0.0)];
    let run = s.run(r#"{"const": -0.5, "unit": "1"}"#).unwrap();
    // 4h+d: target -0.5 * 10000 / 100 = -50, sold at 8h at 99.9 (4995), fee 4.995: cash 14990.005. The 8h+d
    // decision sizes on equity 10000 at 8h and holds. 10h: paid = -50 * open(bar 2) 100 * 0.002 = -10, so the
    // short receives 10: cash 15000.005. Equity at 12h: 15000.005 - 50 * close2 100 = 10000.005.
    assert_account(&run, 12 * HOUR, (15000.005, -50.0, 4.995, -10.0, 10000.005));
}

/// A fill bar with no trade leaves the order unfilled; the next decision re-targets.
#[test]
fn zero_trade_bar_is_unfilled() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 120.0], &[100.0, 110.0, 120.0, 120.0, 120.0]);
    s.trades[2] = 0;
    let run = s.run(HALF).unwrap();
    assert!(run.trace.iter().any(|e| matches!(e, Event::Unfilled { t, .. } if *t == 8 * HOUR)));
    // Decision at 8h+d: held 0, target 0.5*10000/110 = 45.4545 -> 45.454, filled at 12h at 120.12.
    let f = fills(&run);
    assert!(close(f[0].qty, 45.454) && close(f[0].price, 120.12) && f[0].filled == 12 * HOUR);
    // At 16h: paid 45.454 * 120.12 = 5459.93448 and fee 5.45993448, so cash 4534.60558552; marked at
    // close3 120, equity 4534.60558552 + 5454.48 = 9989.08558552. No funding (every rate is 0).
    assert_account(&run, 16 * HOUR, (4534.60558552, 45.454, 5.45993448, 0.0, 9989.08558552));
}

/// Reversal through zero: realized PnL on the closed part, new entry for the rest.
#[test]
fn position_reversal() {
    let mut s = Spec::new(&[100.0, 100.0, 100.0, 100.0, 100.0, 100.0], &[100.0; 6]);
    s.funding = vec![(4, 0.0, 1.0), (8, 0.0, -1.0), (12, 0.0, -1.0), (16, 0.0, -1.0)];
    let w = r#"{"op": "mul", "args": [{"op": "sign", "args": [{"input": "premium"}]}, {"const": 0.3, "unit": "1"}]}"#;
    let run = s.run(w).unwrap();
    let f = fills(&run);
    // 4h+d: +30 coins, filled at 8h at 100.1, fee 3.003. Cash 10000 - 3003 - 3.003 = 6993.997.
    assert!(close(f[0].qty, 30.0) && close(f[0].price, 100.1));
    // 8h+d: equity at 8h is 10000 (nothing held yet), target -30, qty -60, sold at 99.9 at 12h.
    assert!(close(f[1].qty, -60.0) && close(f[1].price, 99.9) && close(f[1].fee, 5.994));
    // Equity at 16h: cash 6993.997 + 5994 - 5.994 = 12982.003, minus 30 * close 100 = 9982.003.
    // Independently: realized 30 * (99.9 - 100.1) = -6, unrealized -30 * (100 - 99.9) = -3,
    // fees 3.003 + 5.994: 10000 - 6 - 3 - 8.997 = 9982.003.
    assert_account(&run, 16 * HOUR, (12982.003, -30.0, 8.997, 0.0, 9982.003));
}

/// Margin breach at a bar's adverse extreme liquidates at that extreme.
#[test]
fn liquidation_at_adverse_extreme() {
    let mut s = Spec::new(&[100.0; 5], &[100.0; 5]);
    s.leverage = 1.0;
    s.highs = Some(vec![101.0, 101.0, 101.0, 170.0, 101.0]);
    let run = s.run(r#"{"const": -0.95, "unit": "1"}"#).unwrap();
    let f = fills(&run);
    // 4h+d: target -95 coins (notional 9500), sold at 8h at 99.9, fee 9.49050.
    assert!(close(f[0].qty, -95.0));
    // Bar 3 (12h-16h) high 170: equity there = cash 10000 + 9490.5 - 9.4905 - 95 * 170 =
    // 3331.0095 < maintenance 95 * 170 / 2 = 8075, so everything is bought back at 170 * 1.001.
    let liq = f.iter().find(|x| x.why == Why::Liquidation).unwrap();
    assert!(close(liq.qty, 95.0) && close(liq.reference, 170.0) && close(liq.price, 170.17) && liq.filled == 16 * HOUR);
    // The 8h+d decision sizes on equity 10000 at 8h, so it holds -95. At 16h: paid 95 * 170.17 = 16166.15 and
    // fee 16.16615, so cash 19481.0095 - 16182.31615 = 3298.69335, flat; fees 9.4905 + 16.16615 = 25.65665.
    assert_account(&run, 16 * HOUR, (3298.69335, 0.0, 25.65665, 0.0, 3298.69335));
}

/// A liquidation past zero equity is a bankruptcy: the venue absorbs the shortfall, the order due at that
/// step is unfilled, and the step returns exactly -1, with 0 after it.
#[test]
fn bankruptcy_caps_the_loss_at_equity() {
    let mut s = Spec::new(&[100.0; 6], &[100.0; 6]);
    s.leverage = 1.0;
    s.highs = Some(vec![101.0, 101.0, 101.0, 300.0, 101.0, 101.0]);
    let run = s.run(r#"{"const": -0.95, "unit": "1"}"#).unwrap();
    let f = fills(&run);
    // Sold 95 at 8h at 99.9 (fee 9.4905): cash 19481.0095. At 12h equity is 9981.0095, so the 12h+d
    // decision buys back 0.180 at 16h. Bar 3's high 300 liquidates first: 95 bought at 300.3, fee
    // 28.5285, cash -9076.019. The venue absorbs it, so equity at 16h is 0 and the 16h order is unfilled.
    let liq = f.iter().find(|x| x.why == Why::Liquidation).unwrap();
    assert!(close(liq.qty, 95.0) && close(liq.price, 300.3) && liq.filled == 16 * HOUR);
    assert!(!f.iter().any(|x| x.why == Why::Fill && x.filled == 16 * HOUR));
    assert!(run.trace.iter().any(|e| matches!(e, Event::Unfilled { t, qty, .. } if *t == 16 * HOUR && close(*qty, 0.18))));
    assert_eq!(equity_at(&run, 16 * HOUR), 0.0);
    assert!(run.trace.iter().any(|e| matches!(e, Event::Equity { t, reconciled, .. } if *t == 16 * HOUR && reconciled.abs() < 1e-9)));
    assert_eq!(&run.returns[run.returns.len() - 2..], &[-1.0, 0.0]);
}

/// A delisted coin is closed at its last bar's close; it owes no funding once delisted, where the venue has no rows.
#[test]
fn delisting_closeout() {
    let mut s = Spec::new(&[100.0; 6], &[100.0, 100.0, 100.0, 105.0, 100.0, 100.0]);
    s.delisted_at = Some(16 * HOUR);
    let run = s.run(HALF).unwrap();
    let f = fills(&run);
    // Bought 50 at 8h (100.1). The interval ends at 16h: closed at bar 3's close 105 less 10 bps.
    let d = f.iter().find(|x| x.why == Why::Delisting).unwrap();
    assert!(close(d.qty, -50.0) && close(d.reference, 105.0) && close(d.price, 104.895) && d.filled == 16 * HOUR);
    // Decisions stop where the fill bar would end after delisting: only the 4h decision trades.
    assert_eq!(f.iter().filter(|x| x.why == Why::Fill).count(), 1);
    // At 16h: bought for 5005 with fee 5.005 (cash 4989.995), closed for 50 * 104.895 = 5244.75 with fee
    // 5.24475: cash 10229.50025, flat, fees 10.24975, no funding.
    assert_account(&run, 16 * HOUR, (10229.50025, 0.0, 10.24975, 0.0, 10229.50025));
}

/// Truncation to szDecimals, the $10 minimum, and the exact close of weight 0.
#[test]
fn rounding_min_notional_and_exact_close() {
    let mut s = Spec::new(&[100.0; 6], &[100.0, 100.3, 100.3, 100.3, 100.3, 100.3]);
    s.funding = vec![(4, 0.0, 1.0), (8, 0.0, 1.0), (12, 0.0, -1.0), (16, 0.0, -1.0)];
    let w = r#"{"op": "if", "args": [{"op": "gt", "args": [{"input": "premium"}, {"const": 0, "unit": "1"}]},
                {"const": 0.333333, "unit": "1"}, {"const": 0, "unit": "1"}]}"#;
    let run = s.run(w).unwrap();
    let f = fills(&run);
    // 4h+d: 0.333333 * 10000 / 100 = 33.3333 -> 33.333. 8h+d: target 0.333333 * 10000 / 100.3 =
    // 33.2336..., delta -0.0997 ($10.0 would be needed): dropped. 12h+d: weight 0 closes all 33.333.
    assert!(close(f[0].qty, 33.333));
    assert_eq!(f.len(), 2);
    assert!(close(f[1].qty, -33.333) && f[1].filled == 16 * HOUR);
    // At 20h: bought 33.333 * 100.1 = 3336.6333 (fee 3.3366333), sold 33.333 * 99.9 = 3329.9667 (fee
    // 3.3299667): cash 10000 - 3336.6333 - 3.3366333 + 3329.9667 - 3.3299667 = 9986.6668, flat, fees 6.6666.
    assert_account(&run, 20 * HOUR, (9986.6668, 0.0, 6.6666, 0.0, 9986.6668));
}

/// Funding is priced at the open of the latest bar opened by its hour, and a held hour without a rate aborts.
#[test]
fn settlement_price_and_missing_rate() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 130.0, 130.0], &[100.0, 110.0, 120.0, 130.0, 130.0, 130.0]);
    s.funding = vec![(12, 0.001, 0.0)];
    s.missing_bars = vec![3];
    let run = s.run(HALF).unwrap();
    // Long 50 from the 8h fill at bar 2. Bar 3 (opening 12h) is missing, so the 12h payment is priced at bar 2's
    // open, 110: 50 * 110 * 0.001 = 5.5.
    let paid = run.trace.iter().find_map(|e| match e { Event::Funding { t, price, paid, .. } if *t == 12 * HOUR => Some((*price, *paid)), _ => None });
    assert!(paid.is_some_and(|(price, paid)| close(price, 110.0) && close(paid, 5.5)), "{paid:?}");
    // The 8h+d order is unfilled (its bar is missing). At 12h: cash 10000 - 5505.5 - 5.5055 - 5.5 = 4483.4945,
    // marked at close2 120: equity 10483.4945.
    assert_account(&run, 12 * HOUR, (4483.4945, 50.0, 5.5055, 5.5, 10483.4945));
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 130.0], &[100.0, 110.0, 120.0, 130.0, 130.0]);
    s.missing_funding = vec![9];
    assert!(matches!(s.run(HALF), Err(sim::Abort::SettlementMissing(_))));
}

/// I5's tolerance: $1e-5 up to $10,000 of equity, 1e-9 of the larger of equity and its earlier peak above it; a
/// non-finite equity fails.
#[test]
fn accounting_tolerance_is_relative_above_initial_equity() {
    assert!(sim::accounting_ok(100.0, 100.0 + 9e-6, 0.0) && !sim::accounting_ok(100.0, 100.0 + 1.1e-5, 0.0));
    assert!(sim::accounting_ok(1e10, 1e10 + 9.0, 0.0) && !sim::accounting_ok(1e10, 1e10 + 11.0, 0.0));
    // The 2026-10-27 crash: equity 0 after a bankruptcy from a peak of 1e14, off by rounding.
    assert!(sim::accounting_ok(0.0, -0.0004425048828125, 1e14) && !sim::accounting_ok(0.0, -0.0004425048828125, 0.0));
    for (a, b) in [(f64::INFINITY, 1.0), (f64::INFINITY, f64::INFINITY), (1.0, f64::INFINITY), (f64::NAN, f64::NAN), (1.0, f64::NAN)] {
        assert!(!sim::accounting_ok(a, b, 1e14), "{a} {b}");
    }
}

/// Stale inputs and undefined weights hold.
#[test]
fn stale_and_undefined_hold() {
    let mut s = Spec::new(&[100.0; 5], &[100.0; 5]);
    s.missing_funding = vec![4];
    let run = s.run(HALF).unwrap();
    assert!(run.trace.iter().any(|e| matches!(e, Event::Hold { t, why: "stale", .. } if *t == 4 * HOUR + DELTA)));
    let undefined = r#"{"op": "div", "args": [{"const": 1, "unit": "1"}, {"const": 0, "unit": "1"}]}"#;
    let run = Spec::new(&[100.0; 5], &[100.0; 5]).run(undefined).unwrap();
    assert!(fills(&run).is_empty());
    assert!(run.trace.iter().any(|e| matches!(e, Event::Hold { why: "undefined", .. })));
}

/// Gross leverage above 2 is scaled down, and an order is capped at $10k notional.
#[test]
fn leverage_scale_and_notional_cap() {
    let run = Spec::new(&[100.0; 5], &[100.0; 5]).run(r#"{"const": 5, "unit": "1"}"#).unwrap();
    let f = fills(&run);
    // Weight 5 -> scaled to 2 -> target 200 coins ($20k) -> capped at $10k: 100 coins.
    assert!(close(f[0].qty, 100.0));
    let d = run.trace.iter().find_map(|e| if let Event::Decision { weight, .. } = e { Some(*weight) } else { None });
    assert_eq!(d, Some(2.0));
}

/// I5: every equity mark reconciles with the independent average-entry ledger.
#[test]
fn equity_reconciles_every_step() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 90.0, 95.0, 100.0], &[100.0, 110.0, 120.0, 90.0, 95.0, 100.0, 100.0]);
    s.funding = (1..28).map(|h| (h, 0.0005 * if h % 3 == 0 { -1.0 } else { 1.0 }, if h % 8 < 4 { 1.0 } else { -1.0 })).collect();
    let w = r#"{"op": "mul", "args": [{"op": "sign", "args": [{"input": "premium"}]}, {"const": 0.4, "unit": "1"}]}"#;
    let run = s.run(w).unwrap();
    let marks: Vec<(f64, f64)> =
        run.trace.iter().filter_map(|e| if let Event::Equity { equity, reconciled, .. } = e { Some((*equity, *reconciled)) } else { None }).collect();
    assert!(marks.len() >= 4 && fills(&run).len() >= 3);
    assert!(run.trace.iter().any(|e| matches!(e, Event::Funding { paid, .. } if *paid != 0.0)));
    for (e, r) in marks {
        assert!((e - r).abs() <= 1e-9, "{e} vs {r}");
    }
}

/// I1: the decision at 4h+d sees bar 0 (up), not bar 1 (down) or later, and goes long.
#[test]
fn decision_sees_only_closed_bars() {
    let s = Spec::new(&[100.0, 110.0, 90.0, 95.0, 95.0], &[110.0, 90.0, 95.0, 95.0, 95.0]);
    let w = r#"{"op": "mul", "args": [{"op": "sign", "args": [{"op": "sub", "args": [{"input": "close"}, {"input": "open"}]}]}, {"const": 0.5, "unit": "1"}]}"#;
    let run = s.run(w).unwrap();
    let first = run.trace.iter().find_map(|e| if let Event::Decision { t, weight, .. } = e { Some((*t, *weight)) } else { None });
    assert_eq!(first, Some((4 * HOUR + DELTA, 0.5)));
}

/// I2: every fill in a busy run is ordered known <= decided <= submitted <= filled.
#[test]
fn timing_order_holds_for_every_fill() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 120.0, 90.0, 95.0, 100.0], &[100.0, 110.0, 120.0, 90.0, 95.0, 100.0, 100.0]);
    s.funding = (1..28).map(|h| (h, 0.0, if h % 8 < 4 { 1.0 } else { -1.0 })).collect();
    let run = s.run(r#"{"op": "mul", "args": [{"op": "sign", "args": [{"input": "premium"}]}, {"const": 0.4, "unit": "1"}]}"#).unwrap();
    let f = fills(&run);
    assert!(f.len() >= 3);
    for x in f {
        assert!(x.inputs_known <= x.decided && x.decided <= x.submitted && x.submitted <= x.filled, "{x:?}");
        assert!(x.decided < x.filled);
    }
}

/// Paper Figure 2: for a decision at B + δ, the bar opening at B is never the fill source; the
/// fill is at the open of the bar opening at B + 4h (distinct opens make the price tell them apart).
#[test]
fn bar_opening_at_the_decision_boundary_is_never_the_fill_source() {
    let opens = [100.0, 101.0, 112.0, 123.0, 94.0, 97.0, 102.0, 99.0];
    let mut s = Spec::new(&opens, &[101.0, 112.0, 123.0, 94.0, 97.0, 102.0, 99.0, 99.0]);
    s.funding = (1..32).map(|h| (h, 0.0, if h % 8 < 4 { 1.0 } else { -1.0 })).collect();
    let run = s.run(r#"{"op": "mul", "args": [{"op": "sign", "args": [{"input": "premium"}]}, {"const": 0.4, "unit": "1"}]}"#).unwrap();
    let f: Vec<_> = fills(&run).into_iter().filter(|x| x.why == Why::Fill).collect();
    assert!(f.len() >= 3);
    for x in f {
        let b = x.decided - DELTA;
        assert_eq!(b % BAR, 0, "{x:?}");
        assert_ne!(x.source_open, b, "{x:?}");
        assert_eq!(x.source_open, b + BAR, "{x:?}");
        assert_eq!(x.reference, opens[((b + BAR) / BAR) as usize], "{x:?}");
    }
}


/// Mechanism exposures: labeled by the condition at the deciding tick, and summing to total PnL.
#[test]
fn mechanism_exposures_attribute_all_pnl() {
    let mut s = Spec::new(&[100.0, 100.0, 110.0, 105.0, 120.0, 115.0, 118.0], &[100.0, 110.0, 105.0, 120.0, 115.0, 118.0, 118.0]);
    s.funding = (1..28).map(|h| (h, 0.0002, if (h / 4) % 2 == 0 { 1.0 } else { -1.0 })).collect();
    let cond = r#", "prediction": {"condition": {"op": "gt", "args": [{"input": "premium"}, {"const": 0, "unit": "1"}]}}"#;
    let run = s.run_with(HALF, cond).unwrap();
    let mut equity_prev = 10_000.0;
    let mut attributed = 0.0;
    let marks: Vec<f64> = run.trace.iter().filter_map(|e| if let Event::Equity { equity, .. } = e { Some(*equity) } else { None }).collect();
    // One coin, so each step with a position has exactly one exposure; scale it back to dollars.
    let mut k = 0;
    for (i, e) in marks.iter().enumerate() {
        let prev = if i == 0 { 10_000.0 } else { marks[i - 1] };
        if i >= marks.len() - run.exposures.len() {
            attributed += run.exposures[k].1 * prev;
            k += 1;
        }
        equity_prev = *e;
    }
    assert!((attributed - (equity_prev - 10_000.0)).abs() < 1e-6, "{attributed} vs {}", equity_prev - 10_000.0);
    assert!(run.exposures.iter().any(|(c, _)| *c) && run.exposures.iter().any(|(c, _)| !*c));
}


/// Finite huge weights do not overflow the gross norm into a silent close (GPT red team).
#[test]
fn huge_finite_weights_scale_without_overflow() {
    let run = Spec::new(&[100.0; 5], &[100.0; 5]).run(r#"{"const": 1e308, "unit": "1"}"#).unwrap();
    let d = run.trace.iter().find_map(|e| if let Event::Decision { weight, .. } = e { Some(*weight) } else { None });
    assert_eq!(d, Some(2.0));
    assert!(fills(&run)[0].qty > 0.0);
}
