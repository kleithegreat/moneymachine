//! C4.2 smoke: equivalent programs share an equivalence key; rejected-law counterexamples do not.

mod common;

use common::*;
use mm::{canon, dsl};

fn prog(weight: &str) -> dsl::Program {
    dsl::parse(&format!(
        r#"{{"dsl": 1, "name": "c", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}}, "weight": {weight}}}"#
    ))
    .unwrap()
}


fn key(w: &str) -> String {
    canon::equivalence_key(&prog(w))
}

#[test]
fn equivalent_forms_share_a_key() {
    let a = format!(r#"{{"op": "add", "args": [{R}, {P}]}}"#);
    let b = format!(r#"{{"op": "add", "args": [{P}, {R}]}}"#);
    assert_eq!(key(&a), key(&b));
    let nn = format!(r#"{{"op": "neg", "args": [{{"op": "neg", "args": [{a}]}}]}}"#);
    assert_eq!(key(&nn), key(&a));
    let gt = format!(r#"{{"op": "if", "args": [{{"op": "gt", "args": [{R}, {P}]}}, {R}, {P}]}}"#);
    let swapped = format!(r#"{{"op": "if", "args": [{{"op": "not", "args": [{{"op": "lt", "args": [{P}, {R}]}}]}}, {P}, {R}]}}"#);
    assert_eq!(key(&gt), key(&swapped));
    let one = format!(r#"{{"op": "mul", "args": [{a}, {{"const": 1, "unit": "1"}}]}}"#);
    assert_eq!(key(&one), key(&a));
    let zero = format!(r#"{{"op": "sub", "args": [{a}, {{"const": 0, "unit": "1"}}]}}"#);
    assert_eq!(key(&zero), key(&a));
}

#[test]
fn rejected_laws_keep_distinct_keys() {
    let pairs = rejected_pairs();
    for (a, b) in &pairs {
        assert_ne!(key(a), key(b), "{a}\n{b}");
    }
}

/// At least 20 hand-built equivalent pairs (C4.2), one or two rules each.
#[test]
fn hand_built_pairs_share_a_key() {
    let pairs = hand_built_pairs();
    assert!(pairs.len() >= 20);
    for (a, b) in &pairs {
        assert_eq!(key(a), key(b), "{a}\n{b}");
    }
}
