//! C4.2 smoke: equivalent programs share an equivalence key; rejected-law counterexamples do not.

use mm::{canon, dsl};

fn prog(weight: &str) -> dsl::Program {
    dsl::parse(&format!(
        r#"{{"dsl": 1, "name": "c", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}}, "weight": {weight}}}"#
    ))
    .unwrap()
}

const R: &str = r#"{"op": "sub", "args": [{"op": "div", "args": [{"input": "close"}, {"input": "open"}]}, {"const": 1, "unit": "1"}]}"#;
const P: &str = r#"{"input": "premium"}"#;

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
    let x = r#"{"const": 1e16, "unit": "1"}"#;
    let y = r#"{"const": -1e16, "unit": "1"}"#;
    let left = format!(r#"{{"op": "add", "args": [{{"op": "add", "args": [{x}, {y}]}}, {P}]}}"#);
    let right = format!(r#"{{"op": "add", "args": [{x}, {{"op": "add", "args": [{y}, {P}]}}]}}"#);
    assert_ne!(key(&left), key(&right));
    let plus0 = format!(r#"{{"op": "add", "args": [{P}, {{"const": 0, "unit": "1"}}]}}"#);
    assert_ne!(key(&plus0), key(P));
    let ifxx = format!(r#"{{"op": "if", "args": [{{"op": "gt", "args": [{R}, {P}]}}, {P}, {P}]}}"#);
    assert_ne!(key(&ifxx), key(P));
    let minab = format!(r#"{{"op": "min", "args": [{R}, {P}]}}"#);
    let minba = format!(r#"{{"op": "min", "args": [{P}, {R}]}}"#);
    assert_ne!(key(&minab), key(&minba));
}
