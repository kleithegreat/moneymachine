//! The frozen random program generator shared by the C4.1 and C4.2 tests: well-typed programs
//! whose every numeric subtree has unit 1, over the DSL's inputs, windows and cross-sectional ops.
#![allow(dead_code)]

use serde_json::{json, Value};

pub struct Rng(pub u64);

impl Rng {
    pub fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        z ^ (z >> 31)
    }
    pub fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
    pub fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }
    pub fn chance(&mut self, p: f64) -> bool {
        self.unit() < p
    }
}

pub fn c(x: f64) -> Value {
    json!({"const": x, "unit": "1"})
}

pub fn op(name: &str, args: Vec<Value>) -> Value {
    json!({"op": name, "args": args})
}

pub fn win(name: &str, x: Value, h: u32) -> Value {
    json!({"op": name, "args": [x], "hours": h})
}

pub fn input(name: &str) -> Value {
    json!({"input": name})
}

pub fn wrap(weight: &Value) -> String {
    json!({"dsl": 1, "name": "g", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"}, "weight": weight}).to_string()
}

pub fn leaf(rng: &mut Rng) -> Value {
    match rng.below(7) {
        0 => {
            let p = ["open", "high", "low", "close"][rng.below(4)];
            op("sub", vec![op("div", vec![input(p), win("lag", input(p), [1, 4, 8, 24][rng.below(4)])]), c(1.0)])
        }
        1 => op("div", vec![input("funding"), json!({"const": 1e-4, "unit": "1/h"})]),
        2 => input("premium"),
        3 => op("div", vec![input("volume"), win("mean", input("volume"), 8)]),
        4 => c([0.0, -0.0, 1.0, -1.0, 0.5][rng.below(5)]),
        5 => c(rng.unit() * 2.0 - 1.0),
        _ => op("mul", vec![json!({"op": "convert", "args": [input("funding")], "to": "1/y"}), json!({"const": 1e-3, "unit": "y"})]),
    }
}

pub fn num(rng: &mut Rng, depth: usize) -> Value {
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

pub fn boolean(rng: &mut Rng, depth: usize) -> Value {
    let d = depth.saturating_sub(1);
    match rng.below(7) {
        0..=3 => op(["gt", "ge", "lt", "le"][rng.below(4)], vec![num(rng, d), num(rng, d)]),
        4 => op("and", vec![boolean(rng, d), boolean(rng, d)]),
        5 => op("or", vec![boolean(rng, d), boolean(rng, d)]),
        _ => op("not", vec![boolean(rng, d)]),
    }
}

/// A random program's weight: a numeric tree clipped and scaled.
pub fn weight(rng: &mut Rng, depth: usize) -> Value {
    op("mul", vec![op("clip", vec![num(rng, depth), c(-1.0), c(1.0)]), c(0.05)])
}

pub const R: &str = r#"{"op": "sub", "args": [{"op": "div", "args": [{"input": "close"}, {"input": "open"}]}, {"const": 1, "unit": "1"}]}"#;
pub const P: &str = r#"{"input": "premium"}"#;

/// Pairs of programs whose semantics provably differ (the rejected laws' counterexamples, C4.2).
pub fn rejected_pairs() -> Vec<(String, String)> {
    let mut out = vec![];
    let x = r#"{"const": 1e16, "unit": "1"}"#;
    let y = r#"{"const": -1e16, "unit": "1"}"#;
    let left = format!(r#"{{"op": "add", "args": [{{"op": "add", "args": [{x}, {y}]}}, {P}]}}"#);
    let right = format!(r#"{{"op": "add", "args": [{x}, {{"op": "add", "args": [{y}, {P}]}}]}}"#);
    out.push((left.to_string(), right.to_string()));
    let plus0 = format!(r#"{{"op": "add", "args": [{P}, {{"const": 0, "unit": "1"}}]}}"#);
    out.push((plus0.to_string(), P.to_string()));
    let ifxx = format!(r#"{{"op": "if", "args": [{{"op": "gt", "args": [{R}, {P}]}}, {P}, {P}]}}"#);
    out.push((ifxx.to_string(), P.to_string()));
    let a = r#"{"const": 0.1, "unit": "1"}"#;
    let distl = format!(r#"{{"op": "mul", "args": [{a}, {{"op": "add", "args": [{R}, {P}]}}]}}"#);
    let distr = format!(r#"{{"op": "add", "args": [{{"op": "mul", "args": [{a}, {R}]}}, {{"op": "mul", "args": [{a}, {P}]}}]}}"#);
    out.push((distl.to_string(), distr.to_string()));
    let cond = format!(r#"{{"op": "gt", "args": [{R}, {P}]}}"#);
    let andf = format!(r#"{{"op": "if", "args": [{{"op": "and", "args": [{{"op": "lt", "args": [{{"const": 1, "unit": "1"}}, {{"const": 0, "unit": "1"}}]}}, {cond}]}}, {R}, {P}]}}"#);
    let falsef = format!(r#"{{"op": "if", "args": [{{"op": "lt", "args": [{{"const": 1, "unit": "1"}}, {{"const": 0, "unit": "1"}}]}}, {R}, {P}]}}"#);
    out.push((andf.to_string(), falsef.to_string()));
    let dd = format!(r#"{{"op": "xs_demean", "args": [{{"op": "xs_demean", "args": [{R}]}}]}}"#);
    let d = format!(r#"{{"op": "xs_demean", "args": [{R}]}}"#);
    out.push((dd.to_string(), d.to_string()));
    let f = r#"{"input": "funding"}"#;
    let conv = format!(r#"{{"op": "mul", "args": [{{"op": "convert", "args": [{{"op": "convert", "args": [{f}], "to": "1/y"}}], "to": "1/h"}}, {{"const": 1, "unit": "h"}}]}}"#);
    let plain = format!(r#"{{"op": "mul", "args": [{f}, {{"const": 1, "unit": "h"}}]}}"#);
    out.push((conv.to_string(), plain.to_string()));
    let lagmean = format!(r#"{{"op": "lag", "args": [{{"op": "mean", "args": [{R}], "hours": 4}}], "hours": 2}}"#);
    let meanlag = format!(r#"{{"op": "mean", "args": [{{"op": "lag", "args": [{R}], "hours": 2}}], "hours": 4}}"#);
    out.push((lagmean.to_string(), meanlag.to_string()));
    let negsign = format!(r#"{{"op": "neg", "args": [{{"op": "sign", "args": [{R}]}}]}}"#);
    let signneg = format!(r#"{{"op": "sign", "args": [{{"op": "neg", "args": [{R}]}}]}}"#);
    out.push((negsign.to_string(), signneg.to_string()));
    let minab = format!(r#"{{"op": "min", "args": [{R}, {P}]}}"#);
    let minba = format!(r#"{{"op": "min", "args": [{P}, {R}]}}"#);
    out.push((minab.to_string(), minba.to_string()));
    let maxab = format!(r#"{{"op": "max", "args": [{R}, {P}]}}"#);
    let maxba = format!(r#"{{"op": "max", "args": [{P}, {R}]}}"#);
    out.push((maxab.to_string(), maxba.to_string()));
    out
}

/// Hand-built equivalent pairs, one or two rules each (C4.2).
pub fn hand_built_pairs() -> Vec<(String, String)> {
    let f = r#"{"op": "div", "args": [{"input": "funding"}, {"const": 0.0001, "unit": "1/h"}]}"#;
    let m = r#"{"op": "mean", "args": [{"input": "premium"}], "hours": 24}"#;
    let g = |a: &str, b: &str| format!(r#"{{"op": "gt", "args": [{a}, {b}]}}"#);
    vec![
        (format!(r#"{{"op": "mul", "args": [{R}, {P}]}}"#), format!(r#"{{"op": "mul", "args": [{P}, {R}]}}"#)),
        (format!(r#"{{"op": "abs", "args": [{{"op": "abs", "args": [{R}]}}]}}"#), format!(r#"{{"op": "abs", "args": [{R}]}}"#)),
        (format!(r#"{{"op": "abs", "args": [{{"op": "neg", "args": [{f}]}}]}}"#), format!(r#"{{"op": "abs", "args": [{f}]}}"#)),
        (format!(r#"{{"op": "div", "args": [{m}, {{"const": 1, "unit": "1"}}]}}"#), m.to_string()),
        (format!(r#"{{"op": "sub", "args": [{f}, {{"const": 0, "unit": "1"}}]}}"#), f.to_string()),
        (format!(r#"{{"op": "neg", "args": [{{"op": "neg", "args": [{m}]}}]}}"#), m.to_string()),
        (format!(r#"{{"op": "if", "args": [{}, {R}, {P}]}}"#, g(R, P)), format!(r#"{{"op": "if", "args": [{{"op": "lt", "args": [{P}, {R}]}}, {R}, {P}]}}"#)),
        (format!(r#"{{"op": "if", "args": [{{"op": "ge", "args": [{R}, {f}]}}, {R}, {P}]}}"#), format!(r#"{{"op": "if", "args": [{{"op": "le", "args": [{f}, {R}]}}, {R}, {P}]}}"#)),
        (format!(r#"{{"op": "if", "args": [{{"op": "and", "args": [{}, {}]}}, {R}, {P}]}}"#, g(R, P), g(f, m)), format!(r#"{{"op": "if", "args": [{{"op": "and", "args": [{}, {}]}}, {R}, {P}]}}"#, g(f, m), g(R, P))),
        (format!(r#"{{"op": "if", "args": [{{"op": "or", "args": [{}, {}]}}, {R}, {P}]}}"#, g(R, P), g(f, m)), format!(r#"{{"op": "if", "args": [{{"op": "or", "args": [{}, {}]}}, {R}, {P}]}}"#, g(f, m), g(R, P))),
        (format!(r#"{{"op": "if", "args": [{{"op": "not", "args": [{{"op": "not", "args": [{}]}}]}}, {R}, {P}]}}"#, g(R, P)), format!(r#"{{"op": "if", "args": [{}, {R}, {P}]}}"#, g(R, P))),
        (format!(r#"{{"op": "if", "args": [{{"op": "not", "args": [{}]}}, {R}, {P}]}}"#, g(f, m)), format!(r#"{{"op": "if", "args": [{}, {P}, {R}]}}"#, g(f, m))),
        (format!(r#"{{"op": "xs_demean", "args": [{{"op": "add", "args": [{R}, {f}]}}]}}"#), format!(r#"{{"op": "xs_demean", "args": [{{"op": "add", "args": [{f}, {R}]}}]}}"#)),
        (format!(r#"{{"op": "ema", "args": [{{"op": "mul", "args": [{f}, {{"const": 1, "unit": "1"}}]}}], "hours": 12}}"#), format!(r#"{{"op": "ema", "args": [{f}], "hours": 12}}"#)),
        (format!(r#"{{"op": "clip", "args": [{{"op": "add", "args": [{R}, {P}]}}, {{"const": -1, "unit": "1"}}, {{"const": 1, "unit": "1"}}]}}"#), format!(r#"{{"op": "clip", "args": [{{"op": "add", "args": [{P}, {R}]}}, {{"const": -1, "unit": "1"}}, {{"const": 1, "unit": "1"}}]}}"#)),
        (format!(r#"{{"op": "sign", "args": [{{"op": "neg", "args": [{{"op": "neg", "args": [{R}]}}]}}]}}"#), format!(r#"{{"op": "sign", "args": [{R}]}}"#)),
        (format!(r#"{{"op": "add", "args": [{{"op": "mul", "args": [{R}, {P}]}}, {f}]}}"#), format!(r#"{{"op": "add", "args": [{f}, {{"op": "mul", "args": [{P}, {R}]}}]}}"#)),
        (format!(r#"{{"op": "max", "args": [{{"op": "abs", "args": [{{"op": "neg", "args": [{R}]}}]}}, {P}]}}"#), format!(r#"{{"op": "max", "args": [{{"op": "abs", "args": [{R}]}}, {P}]}}"#)),
        (format!(r#"{{"op": "lag", "args": [{{"op": "sub", "args": [{m}, {{"const": 0, "unit": "1"}}]}}], "hours": 4}}"#), format!(r#"{{"op": "lag", "args": [{m}], "hours": 4}}"#)),
        (format!(r#"{{"op": "xs_rank", "args": [{{"op": "div", "args": [{{"op": "mul", "args": [{R}, {{"const": 1, "unit": "1"}}]}}, {{"const": 1, "unit": "1"}}]}}]}}"#), format!(r#"{{"op": "xs_rank", "args": [{R}]}}"#)),
    ]
}
