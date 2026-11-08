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
