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
    let a = r#"{"const": 0.1, "unit": "1"}"#;
    let distl = format!(r#"{{"op": "mul", "args": [{a}, {{"op": "add", "args": [{R}, {P}]}}]}}"#);
    let distr = format!(r#"{{"op": "add", "args": [{{"op": "mul", "args": [{a}, {R}]}}, {{"op": "mul", "args": [{a}, {P}]}}]}}"#);
    assert_ne!(key(&distl), key(&distr));
    let cond = format!(r#"{{"op": "gt", "args": [{R}, {P}]}}"#);
    let andf = format!(r#"{{"op": "if", "args": [{{"op": "and", "args": [{{"op": "lt", "args": [{{"const": 1, "unit": "1"}}, {{"const": 0, "unit": "1"}}]}}, {cond}]}}, {R}, {P}]}}"#);
    let falsef = format!(r#"{{"op": "if", "args": [{{"op": "lt", "args": [{{"const": 1, "unit": "1"}}, {{"const": 0, "unit": "1"}}]}}, {R}, {P}]}}"#);
    assert_ne!(key(&andf), key(&falsef));
    let dd = format!(r#"{{"op": "xs_demean", "args": [{{"op": "xs_demean", "args": [{R}]}}]}}"#);
    let d = format!(r#"{{"op": "xs_demean", "args": [{R}]}}"#);
    assert_ne!(key(&dd), key(&d));
    let f = r#"{"input": "funding"}"#;
    let conv = format!(r#"{{"op": "mul", "args": [{{"op": "convert", "args": [{{"op": "convert", "args": [{f}], "to": "1/y"}}], "to": "1/h"}}, {{"const": 1, "unit": "h"}}]}}"#);
    let plain = format!(r#"{{"op": "mul", "args": [{f}, {{"const": 1, "unit": "h"}}]}}"#);
    assert_ne!(key(&conv), key(&plain));
    let lagmean = format!(r#"{{"op": "lag", "args": [{{"op": "mean", "args": [{R}], "hours": 4}}], "hours": 2}}"#);
    let meanlag = format!(r#"{{"op": "mean", "args": [{{"op": "lag", "args": [{R}], "hours": 2}}], "hours": 4}}"#);
    assert_ne!(key(&lagmean), key(&meanlag));
    let negsign = format!(r#"{{"op": "neg", "args": [{{"op": "sign", "args": [{R}]}}]}}"#);
    let signneg = format!(r#"{{"op": "sign", "args": [{{"op": "neg", "args": [{R}]}}]}}"#);
    assert_ne!(key(&negsign), key(&signneg));
    let minab = format!(r#"{{"op": "min", "args": [{R}, {P}]}}"#);
    let minba = format!(r#"{{"op": "min", "args": [{P}, {R}]}}"#);
    assert_ne!(key(&minab), key(&minba));
}

/// At least 20 hand-built equivalent pairs (C4.2), one or two rules each.
#[test]
fn hand_built_pairs() {
    let f = r#"{"op": "div", "args": [{"input": "funding"}, {"const": 0.0001, "unit": "1/h"}]}"#;
    let m = r#"{"op": "mean", "args": [{"input": "premium"}], "hours": 24}"#;
    let g = |a: &str, b: &str| format!(r#"{{"op": "gt", "args": [{a}, {b}]}}"#);
    let pairs: Vec<(String, String)> = vec![
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
    ];
    assert!(pairs.len() >= 20);
    for (a, b) in &pairs {
        assert_eq!(key(a), key(b), "{a}\n{b}");
    }
}
