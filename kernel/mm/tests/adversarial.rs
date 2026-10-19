//! Every case in kernel/tests/adversarial must be rejected with exactly its expected code.
//! A case file is a JSON header line followed by the program text.

use std::fs;
use std::path::Path;

fn cases() -> Vec<(String, serde_json::Value, String)> {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/adversarial");
    let mut out: Vec<_> = fs::read_dir(dir)
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| p.extension().is_some_and(|x| x == "case"))
        .map(|p| {
            let text = fs::read_to_string(&p).unwrap();
            let (hdr, prog) = text.split_once('\n').unwrap();
            (p.file_stem().unwrap().to_string_lossy().into_owned(), serde_json::from_str(hdr).unwrap(), prog.to_string())
        })
        .collect();
    out.sort_by(|a, b| a.0.cmp(&b.0));
    out
}

#[test]
fn type_checker_rejects_with_expected_code() {
    let mut failures = vec![];
    for (name, hdr, prog) in cases() {
        let expect = hdr["expect"].as_str().unwrap();
        if !expect.starts_with("E_") {
            continue;
        }
        match mm::dsl::parse(&prog) {
            Err(r) if r.code.name() == expect => {}
            Err(r) => failures.push(format!("{name}: expected {expect}, got {r}")),
            Ok(_) => failures.push(format!("{name}: expected {expect}, but it type-checked")),
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

#[test]
fn reference_strategies_type_check() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../strategies");
    for e in fs::read_dir(dir).unwrap() {
        let p = e.unwrap().path();
        mm::dsl::parse(&fs::read_to_string(&p).unwrap()).unwrap_or_else(|r| panic!("{}: {r}", p.display()));
    }
}
