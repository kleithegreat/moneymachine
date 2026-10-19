//! C1.7 leak canary. 12 coins, 550 days of i.i.d. Gaussian 4h log returns (sigma 2%), zero
//! funding, production fee and a production-like cost table. No admitted program may reach an
//! annualized net Sharpe above 4 on any seed. The leaking evaluator is the same kernel fed bars
//! whose timestamps claim they were known two bars early (so a decision sees the bar its order
//! will be held through), which must exceed 20.

use mm::dsl;
use mm::market::{Bar, CoinRules, Funding, Market, Policy, Venue, BAR, HOUR};
use mm::sim;
use std::fs;
use std::path::Path;

const DELTA: i64 = 120_000;
const COINS: usize = 12;
const DAYS: i64 = 550;
const SIGMA: f64 = 0.02;
const FIXED_SEEDS: [u64; 5] = [1, 2, 3, 4, 5];

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        z ^ (z >> 31)
    }
    fn uniform(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }
    fn normal(&mut self) -> f64 {
        let (u, v) = (self.uniform().max(1e-300), self.uniform());
        (-2.0 * u.ln()).sqrt() * (2.0 * std::f64::consts::PI * v).cos()
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

/// `early` shifts every bar's event and knownAt back by two bars: the leak.
fn market(seed: u64, early: bool) -> (Market, Venue, Policy, i64) {
    let mut rng = Rng(seed);
    let n_bars = DAYS * 6;
    let end = n_bars * BAR;
    let shift = if early { 2 * BAR } else { 0 };
    let mut bars = vec![];
    for c in 0..COINS {
        let mut px = 100.0;
        for k in 0..n_bars {
            let open = px;
            let close = open * (SIGMA * rng.normal()).exp();
            let wick = (SIGMA * rng.normal()).abs() * 0.5;
            bars.push(Bar {
                coin: c,
                open_time: k * BAR,
                event: (k + 1) * BAR - shift,
                known: (k + 1) * BAR + DELTA - shift,
                open,
                high: open.max(close) * (1.0 + wick),
                low: open.min(close) * (1.0 - wick),
                close,
                volume: 1.0,
                trades: 1,
            });
            px = close;
        }
    }
    let funding: Vec<Funding> = (0..COINS)
        .flat_map(|c| (0..=n_bars * 4).map(move |h| Funding { coin: c, event: h * HOUR, known: h * HOUR + DELTA, rate: 0.0, premium: 0.0 }))
        .collect();
    let mut bar_times = vec![vec![]; COINS];
    for b in &bars {
        bar_times[b.coin].push(b.open_time);
    }
    let m = Market {
        bar_at: bars.iter().enumerate().map(|(i, b)| ((b.coin, b.open_time), i)).collect(),
        rate_at: funding.iter().map(|f| ((f.coin, f.event), f.rate)).collect(),
        bar_times,
        intervals: vec![(0, end); COINS],
        events: std::collections::HashMap::new(),
        funding,
        bars,
        data_hash: String::new(),
    };
    let v = Venue {
        taker_fee: 0.00045,
        min_notional: 10.0,
        coins: (0..COINS).map(|c| format!("S{c}")).collect(),
        rules: (0..COINS)
            .map(|_| CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: false, cost_bps: [[2.0, 4.0], [2.0, 4.0]] })
            .collect(),
        rules_hash: String::new(),
        execution_hash: String::new(),
    };
    (m, v, Policy { delta: DELTA, w_start: 0, holdout_start: i64::MAX, w_end: end }, end)
}

fn sharpe(run: &sim::Run) -> f64 {
    let r = &run.returns;
    let n = r.len() as f64;
    let mean = r.iter().sum::<f64>() / n;
    let sd = (r.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / n).sqrt();
    if sd > 0.0 { mean / sd * (365.0 * 6.0f64).sqrt() } else { 0.0 }
}

fn program(weight: &str) -> String {
    format!(r#"{{"dsl": 1, "name": "canary", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}}, "weight": {weight}}}"#)
}

/// A random well-typed dimensionless expression over bar inputs.
fn random_weight(rng: &mut Rng, depth: usize) -> String {
    let price = ["open", "high", "low", "close"];
    let ret = |rng: &mut Rng| {
        let a = price[rng.below(4)];
        let h = [1, 4, 8, 24, 72, 168][rng.below(6)];
        format!(
            r#"{{"op": "sub", "args": [{{"op": "div", "args": [{{"input": "{a}"}}, {{"op": "lag", "args": [{{"input": "{a}"}}], "hours": {h}}}]}}, {{"const": 1, "unit": "1"}}]}}"#
        )
    };
    if depth == 0 {
        return ret(rng);
    }
    match rng.below(5) {
        0 => format!(r#"{{"op": "neg", "args": [{}]}}"#, random_weight(rng, depth - 1)),
        1 => format!(r#"{{"op": "sign", "args": [{}]}}"#, random_weight(rng, depth - 1)),
        2 => format!(r#"{{"op": "mean", "args": [{}], "hours": {}}}"#, random_weight(rng, depth - 1), [4, 12, 48][rng.below(3)]),
        3 => format!(r#"{{"op": "sub", "args": [{}, {}]}}"#, random_weight(rng, depth - 1), random_weight(rng, depth - 1)),
        _ => format!(r#"{{"op": "xs_demean", "args": [{}]}}"#, random_weight(rng, depth - 1)),
    }
}

fn scaled(w: &str, size: f64) -> String {
    format!(r#"{{"op": "mul", "args": [{{"op": "sign", "args": [{w}]}}, {{"const": {size}, "unit": "1"}}]}}"#)
}

fn admitted_programs() -> Vec<(String, dsl::Program)> {
    let mut out = vec![];
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/adversarial");
    for e in fs::read_dir(dir).unwrap() {
        let p = e.unwrap().path();
        let text = fs::read_to_string(&p).unwrap();
        if let Some((_, prog)) = text.split_once('\n') {
            if let Ok(prog) = dsl::parse(prog) {
                out.push((p.display().to_string(), prog));
            }
        }
    }
    let mut rng = Rng(42);
    for i in 0..20 {
        let text = program(&scaled(&random_weight(&mut rng, 1 + i % 3), 0.08));
        out.push((format!("random{i}"), dsl::parse(&text).unwrap_or_else(|r| panic!("random{i}: {r}"))));
    }
    out
}

#[test]
fn no_admitted_program_beats_the_canary() {
    let drawn: Vec<u64> = (0..5).map(|_| std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos() as u64).collect();
    let drawn: Vec<u64> = drawn.iter().enumerate().map(|(i, s)| s.wrapping_mul(i as u64 + 7)).collect();
    eprintln!("canary drawn seeds: {drawn:?}");
    let progs = admitted_programs();
    for seed in FIXED_SEEDS.iter().chain(drawn.iter()) {
        let (m, v, p, end) = market(*seed, false);
        for (name, prog) in &progs {
            let run = sim::run(prog, &m, &v, &p, end).unwrap_or_else(|e| panic!("{name} seed {seed}: {e:?}"));
            let s = sharpe(&run);
            assert!(s <= 4.0, "{name} on seed {seed}: annualized Sharpe {s}");
        }
    }
}

#[test]
fn leaking_evaluator_has_power() {
    // Sized so that compounding never makes the $10k order cap bind, which would confound
    // the leak's power with the kernel's capacity limit (0.08 per coin reached only 19.6).
    let peek = scaled(r#"{"op": "sub", "args": [{"op": "div", "args": [{"input": "close"}, {"input": "open"}]}, {"const": 1, "unit": "1"}]}"#, 0.005);
    let prog = dsl::parse(&program(&peek)).unwrap();
    for seed in FIXED_SEEDS {
        let (m, v, p, end) = market(seed, true);
        let leak = sharpe(&sim::run(&prog, &m, &v, &p, end).unwrap());
        let (m, v, p, end) = market(seed, false);
        let honest = sharpe(&sim::run(&prog, &m, &v, &p, end).unwrap());
        eprintln!("seed {seed}: leaking Sharpe {leak}, honest {honest}");
        assert!(leak > 20.0, "seed {seed}: leaking Sharpe only {leak}");
        assert!(honest <= 4.0, "seed {seed}: honest Sharpe {honest}");
    }
}
