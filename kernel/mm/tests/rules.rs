//! C4.1: every rule in R is exact (bitwise value streams and run outcomes).
//! C4.2: programs differing by random rule applications share an equivalence key.

use mm::dsl;
use mm::machine::Machine;
use mm::market::{Bar, CoinRules, Funding, Market, Policy, Venue, BAR, HOUR};
use mm::{canon, sim};
use serde_json::{json, Value};

const DELTA: i64 = 120_000;
const COINS: usize = 4;
const DAYS: i64 = 40;
const PER_RULE: usize = 1000;

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        z ^ (z >> 31)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
    fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }
    fn chance(&mut self, p: f64) -> bool {
        self.unit() < p
    }
}

/// Market variants: 0 has exact zero funding and premium; 1 varies them with signed zeros and
/// flat price stretches; 2 adds a coin delisted midway and bars without trades.
fn market(variant: usize, seed: u64) -> (Market, Venue, Policy, i64) {
    let mut rng = Rng(seed);
    let n_bars = DAYS * 6;
    let end = n_bars * BAR;
    let mut bars = vec![];
    for c in 0..COINS {
        let mut px = 100.0;
        for k in 0..n_bars {
            let flat = variant > 0 && k % 17 < 3;
            let close = if flat { px } else { px * (1.0 + 0.02 * (rng.unit() - 0.5)) };
            bars.push(Bar {
                coin: c,
                open_time: k * BAR,
                event: (k + 1) * BAR,
                known: (k + 1) * BAR + DELTA,
                open: px,
                high: px.max(close) * 1.005,
                low: px.min(close) * 0.995,
                close,
                volume: if flat { 0.0 } else { 1.0 + rng.unit() },
                trades: if variant == 2 && k % 23 == 0 { 0 } else { 1 },
            });
            px = close;
        }
    }
    let mut funding = vec![];
    for c in 0..COINS {
        for h in 0..=n_bars * 4 {
            let (rate, premium) = match variant {
                0 => (0.0, 0.0),
                _ => match h % 7 {
                    0 => (0.0, -0.0),
                    1 => (-0.0, 0.0),
                    _ => ((rng.unit() - 0.5) * 4e-4, (rng.unit() - 0.5) * 2e-3),
                },
            };
            funding.push(Funding { coin: c, event: h * HOUR, known: h * HOUR + DELTA, rate, premium });
        }
    }
    let mut bar_times = vec![vec![]; COINS];
    for b in &bars {
        bar_times[b.coin].push(b.open_time);
    }
    let mut intervals = vec![(0, end); COINS];
    if variant == 2 {
        intervals[COINS - 1] = (0, end / 2);
    }
    let m = Market {
        bar_at: bars.iter().enumerate().map(|(i, b)| ((b.coin, b.open_time), i)).collect(),
        rate_at: funding.iter().map(|f| ((f.coin, f.event), f.rate)).collect(),
        bar_times,
        intervals,
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
            .map(|c| CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: variant == 2 && c == COINS - 1, cost_bps: [[2.0, 4.0], [2.0, 4.0]], calibration_range: None })
            .collect(),
        rules_hash: String::new(),
        execution_hash: String::new(),
    };
    (m, v, Policy { delta: DELTA, settlement_latency: 60_000, w_start: 0, holdout_start: i64::MAX, w_end: end }, end)
}

fn c(x: f64) -> Value {
    json!({"const": x, "unit": "1"})
}

fn op(name: &str, args: Vec<Value>) -> Value {
    json!({"op": name, "args": args})
}

fn win(name: &str, x: Value, h: u32) -> Value {
    json!({"op": name, "args": [x], "hours": h})
}

fn leaf(rng: &mut Rng) -> Value {
    match rng.below(7) {
        0 => {
            let p = ["open", "high", "low", "close"][rng.below(4)];
            op("sub", vec![op("div", vec![json!({"input": p}), win("lag", json!({"input": p}), [1, 4, 8, 24][rng.below(4)])]), c(1.0)])
        }
        1 => op("div", vec![json!({"input": "funding"}), json!({"const": 1e-4, "unit": "1/h"})]),
        2 => json!({"input": "premium"}),
        3 => op("div", vec![json!({"input": "volume"}), win("mean", json!({"input": "volume"}), 8)]),
        4 => c([0.0, -0.0, 1.0, -1.0, 0.5][rng.below(5)]),
        5 => c(rng.unit() * 2.0 - 1.0),
        _ => op("convert", vec![json!({"input": "funding"})]).as_object().cloned().map(|mut o| {
            o.insert("to".into(), json!("1/y"));
            op("mul", vec![Value::Object(o), json!({"const": 1e-3, "unit": "y"})])
        }).unwrap(),
    }
}

fn num(rng: &mut Rng, depth: usize) -> Value {
    if depth == 0 || rng.chance(0.25) {
        return leaf(rng);
    }
    let d = depth - 1;
    match rng.below(16) {
        0 => op("neg", vec![num(rng, d)]),
        1 => op("abs", vec![num(rng, d)]),
        2 => op("sign", vec![num(rng, d)]),
        3 => op("add", vec![num(rng, d), num(rng, d)]),
        4 => op("sub", vec![num(rng, d), num(rng, d)]),
        5 => op("mul", vec![num(rng, d), num(rng, d)]),
        6 => op("div", vec![num(rng, d), num(rng, d)]),
        7 => op("min", vec![num(rng, d), num(rng, d)]),
        8 => op("max", vec![num(rng, d), num(rng, d)]),
        9 => op("clip", vec![num(rng, d), c(-1.0), c(1.0)]),
        10 => op("if", vec![boolean(rng, d), num(rng, d), num(rng, d)]),
        11 => win(["mean", "ema", "std", "lag", "sum", "min_over", "max_over"][rng.below(7)], num(rng, d), [1, 4, 6, 13][rng.below(4)]),
        12 => op("xs_demean", vec![num(rng, d)]),
        13 => op("xs_mean", vec![num(rng, d)]),
        14 => op("xs_rank", vec![num(rng, d)]),
        _ => op("exp", vec![op("clip", vec![num(rng, d), c(-3.0), c(3.0)])]),
    }
}

fn boolean(rng: &mut Rng, depth: usize) -> Value {
    let d = depth.saturating_sub(1);
    match rng.below(7) {
        0..=3 => op(["gt", "ge", "lt", "le"][rng.below(4)], vec![num(rng, d), num(rng, d)]),
        4 => op("and", vec![boolean(rng, d), boolean(rng, d)]),
        5 => op("or", vec![boolean(rng, d), boolean(rng, d)]),
        _ => op("not", vec![boolean(rng, d)]),
    }
}

const RULES: [&str; 16] = [
    "neg-neg", "abs-abs", "abs-neg", "mul-one", "div-one", "sub-zero", "add-comm", "mul-comm", "and-comm", "or-comm",
    "not-not", "if-not", "gt-lt", "lt-gt", "ge-le", "le-ge",
];

/// (left side, right side, is boolean) of one random instance of a rule.
fn instance(rule: &str, rng: &mut Rng) -> (Value, Value, bool) {
    let (a, b) = (num(rng, 2), num(rng, 2));
    let (p, q) = (boolean(rng, 2), boolean(rng, 2));
    match rule {
        "neg-neg" => (op("neg", vec![op("neg", vec![a.clone()])]), a, false),
        "abs-abs" => (op("abs", vec![op("abs", vec![a.clone()])]), op("abs", vec![a]), false),
        "abs-neg" => (op("abs", vec![op("neg", vec![a.clone()])]), op("abs", vec![a]), false),
        "mul-one" => (op("mul", vec![a.clone(), c(1.0)]), a, false),
        "div-one" => (op("div", vec![a.clone(), c(1.0)]), a, false),
        "sub-zero" => (op("sub", vec![a.clone(), c(0.0)]), a, false),
        "add-comm" => (op("add", vec![a.clone(), b.clone()]), op("add", vec![b, a]), false),
        "mul-comm" => (op("mul", vec![a.clone(), b.clone()]), op("mul", vec![b, a]), false),
        "and-comm" => (op("and", vec![p.clone(), q.clone()]), op("and", vec![q, p]), true),
        "or-comm" => (op("or", vec![p.clone(), q.clone()]), op("or", vec![q, p]), true),
        "not-not" => (op("not", vec![op("not", vec![p.clone()])]), p, true),
        "if-not" => (op("if", vec![op("not", vec![p.clone()]), a.clone(), b.clone()]), op("if", vec![p, b, a]), false),
        r => {
            let (l, rr) = match r {
                "gt-lt" => ("gt", "lt"),
                "lt-gt" => ("lt", "gt"),
                "ge-le" => ("ge", "le"),
                _ => ("le", "ge"),
            };
            (op(l, vec![a.clone(), b.clone()]), op(rr, vec![b, a]), true)
        }
    }
}

fn program(probe: Value, rng_ctx: &mut Rng, is_bool: bool) -> String {
    let probe_ref = json!({"ref": "probe"});
    let mut x = if is_bool { op("if", vec![probe_ref, num(rng_ctx, 1), num(rng_ctx, 1)]) } else { probe_ref };
    for _ in 0..rng_ctx.below(3) {
        x = match rng_ctx.below(4) {
            0 => op("add", vec![x, num(rng_ctx, 1)]),
            1 => win("ema", x, 4),
            2 => op("xs_demean", vec![x]),
            _ => op("neg", vec![x]),
        };
    }
    let weight = op("mul", vec![op("clip", vec![x, c(-1.0), c(1.0)]), c(0.05)]);
    json!({"dsl": 1, "name": "rule", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
           "let": {"probe": probe}, "weight": weight})
    .to_string()
}

/// Per-tick value bits of the probe node for every coin, as the kernel's machine sees them.
fn streams(p: &dsl::Program, m: &Market, end: i64) -> Vec<Option<u64>> {
    let probe = p.lets.iter().find(|(n, _)| n == "probe").unwrap().1;
    let mut machine = Machine::new(p, COINS);
    let mut f: Vec<&Funding> = m.funding.iter().collect();
    f.sort_by_key(|x| (x.known, x.coin));
    let mut b: Vec<&Bar> = m.bars.iter().collect();
    b.sort_by_key(|x| (x.known, x.coin));
    let (mut fi, mut bi) = (0, 0);
    let mut out = vec![];
    for h in (0..=end).step_by(HOUR as usize) {
        let tick = h + DELTA;
        while fi < f.len() && f[fi].known <= tick {
            machine.deliver_funding(*f[fi], tick).unwrap();
            fi += 1;
        }
        while bi < b.len() && b[bi].known <= tick {
            machine.deliver_bar(*b[bi], tick).unwrap();
            bi += 1;
        }
        let listed: Vec<bool> = (0..COINS).map(|c| m.intervals[c].0 <= h && h < m.intervals[c].1).collect();
        machine.tick(&listed, h);
        out.extend((0..COINS).map(|c| machine.value(probe, c).map(f64::to_bits)));
    }
    out
}

fn outcome(p: &dsl::Program, m: &Market, v: &Venue, pol: &Policy, end: i64) -> String {
    match sim::run(p, m, v, pol, end) {
        Ok(r) => format!("{:?}|{:?}|{:?}", r.returns.iter().map(|x| x.to_bits()).collect::<Vec<_>>(), r.trace, r.exposures),
        Err(e) => format!("abort {e:?}"),
    }
}

#[test]
fn every_rule_is_exact() {
    let markets: Vec<_> = (0..3).map(|v| market(v, 7 + v as u64)).collect();
    let nontrivial: Vec<usize> = std::thread::scope(|scope| {
        let markets = &markets;
        let threads: Vec<_> = RULES
            .iter()
            .enumerate()
            .map(|(ri, rule)| {
                scope.spawn(move || {
                    let mut rng = Rng(1000 + ri as u64);
                    let mut nontrivial = 0;
                    for i in 0..PER_RULE {
                        let (lhs, rhs, is_bool) = instance(rule, &mut rng);
                        let seed = rng.next();
                        let (a, b) = (program(lhs, &mut Rng(seed), is_bool), program(rhs, &mut Rng(seed), is_bool));
                        let (pa, pb) = (dsl::parse(&a).unwrap_or_else(|e| panic!("{rule} {i}: {e}\n{a}")), dsl::parse(&b).unwrap());
                        for (m, v, pol, end) in markets {
                            let (sa, sb) = (streams(&pa, m, *end), streams(&pb, m, *end));
                            assert_eq!(sa, sb, "{rule} #{i}: probe streams differ\n{a}\n{b}");
                            nontrivial += sa.iter().any(|x| x.is_some()) as usize;
                            assert_eq!(outcome(&pa, m, v, pol, *end), outcome(&pb, m, v, pol, *end), "{rule} #{i}: outcomes differ");
                        }
                    }
                    nontrivial
                })
            })
            .collect();
        threads.into_iter().map(|t| t.join().unwrap()).collect()
    });
    for (ri, n) in nontrivial.iter().enumerate() {
        assert!(*n >= PER_RULE, "{}: only {n} runs with any defined probe value", RULES[ri]);
    }
}

/// Apply one random rule, in either direction where it applies, somewhere in the tree.
fn rewrite_once(v: &Value, rng: &mut Rng) -> Value {
    fn paths(v: &Value, here: Vec<usize>, out: &mut Vec<Vec<usize>>) {
        out.push(here.clone());
        if let Some(args) = v.get("args").and_then(Value::as_array) {
            for (i, a) in args.iter().enumerate() {
                let mut p = here.clone();
                p.push(i);
                paths(a, p, out);
            }
        }
    }
    fn at<'a>(v: &'a mut Value, path: &[usize]) -> &'a mut Value {
        path.iter().fold(v, |n, &i| &mut n["args"][i])
    }
    fn is_bool(n: &Value) -> bool {
        matches!(n.get("op").and_then(Value::as_str), Some("gt" | "ge" | "lt" | "le" | "and" | "or" | "not"))
    }
    let mut all = vec![];
    paths(v, vec![], &mut all);
    let mut out = v.clone();
    for _ in 0..20 {
        let path = &all[rng.below(all.len())];
        let node = at(&mut out, path);
        let name = node.get("op").and_then(Value::as_str).unwrap_or("").to_string();
        let args = node.get("args").and_then(Value::as_array).cloned().unwrap_or_default();
        let swap = |n: &str| op(n, vec![args[1].clone(), args[0].clone()]);
        let new = match (name.as_str(), rng.below(2)) {
            ("add" | "mul" | "and" | "or", _) => Some(swap(&name)),
            ("gt", _) => Some(swap("lt")),
            ("lt", _) => Some(swap("gt")),
            ("ge", _) => Some(swap("le")),
            ("le", _) => Some(swap("ge")),
            ("neg", 0) if args[0].get("op") == Some(&json!("neg")) => Some(args[0]["args"][0].clone()),
            ("if", 0) => Some(op("if", vec![op("not", vec![args[0].clone()]), args[2].clone(), args[1].clone()])),
            ("abs", 0) => Some(op("abs", vec![op("abs", vec![args[0].clone()])])),
            ("abs", _) => Some(op("abs", vec![op("neg", vec![args[0].clone()])])),
            _ if is_bool(node) => Some(op("not", vec![op("not", vec![node.clone()])])),
            _ if node.get("op").is_some() || node.get("input").is_some() => Some(match rng.below(3) {
                0 => op("neg", vec![op("neg", vec![node.clone()])]),
                1 => op("mul", vec![node.clone(), c(1.0)]),
                _ => op("div", vec![node.clone(), c(1.0)]),
            }),
            _ => None,
        };
        if let Some(n) = new {
            *node = n;
            return out;
        }
    }
    out
}

#[test]
fn rewritten_programs_share_a_key() {
    let mut rng = Rng(42);
    let mut failures = vec![];
    for i in 0..1000 {
        let weight = op("mul", vec![op("clip", vec![num(&mut rng, 3), c(-1.0), c(1.0)]), c(0.05)]);
        let mut rewritten = weight.clone();
        for _ in 0..1 + rng.below(10) {
            rewritten = rewrite_once(&rewritten, &mut rng);
        }
        let wrap = |w: &Value| {
            json!({"dsl": 1, "name": "k", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"}, "weight": w}).to_string()
        };
        let (a, b) = (dsl::parse(&wrap(&weight)).unwrap(), dsl::parse(&wrap(&rewritten)).unwrap());
        if canon::equivalence_key(&a) != canon::equivalence_key(&b) {
            failures.push((i, canon::canonical_term(&a), canon::canonical_term(&b)));
        }
    }
    eprintln!("C4.2: {} of 1000 rewritten programs got a different key", failures.len());
    for f in failures.iter().take(5) {
        eprintln!("unmerged #{}:\n  {}\n  {}", f.0, f.1, f.2);
    }
    assert!(failures.len() <= 10, "{} of 1000 rewritten programs got a different key", failures.len());
}
