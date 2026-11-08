//! C4.2: programs differing by up to 10 random rule applications share an equivalence key, and a
//! fresh process computes the same key for every program.

mod common;

use common::*;
use mm::{canon, dsl};
use serde_json::{json, Value};
use std::process::Command;

const PAIRS: usize = 1000;
const CHILDREN: usize = 3;

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
            _ if node.get("op").is_some() || node.get("input").is_some() => Some(match rng.below(4) {
                0 => op("neg", vec![op("neg", vec![node.clone()])]),
                1 => op("mul", vec![node.clone(), c(1.0)]),
                2 => op("sub", vec![node.clone(), c(0.0)]),
                _ => op("div", vec![node.clone(), c(1.0)]),
            }),
            _ => None,
        };
        if let Some(n) = new {
            let old = std::mem::replace(node, n);
            if dsl::parse(&wrap(&out)).is_ok() {
                return out;
            }
            *at(&mut out, path) = old;
        }
    }
    out
}

/// The 1,000 frozen pairs: a random program and its form after 1 to 10 random rule applications.
fn pairs() -> Vec<(String, String)> {
    let mut rng = Rng(42);
    (0..PAIRS)
        .map(|_| {
            let w = weight(&mut rng, 3);
            let mut rewritten = w.clone();
            for _ in 0..1 + rng.below(10) {
                rewritten = rewrite_once(&rewritten, &mut rng);
            }
            (wrap(&w), wrap(&rewritten))
        })
        .collect()
}

fn key(text: &str) -> String {
    canon::equivalence_key(&dsl::parse(text).unwrap_or_else(|e| panic!("{e:?}\n{text}")))
}

#[test]
fn rewritten_programs_share_a_key() {
    let mut unmerged = vec![];
    for (i, (a, b)) in pairs().iter().enumerate() {
        let (pa, pb) = (dsl::parse(a).unwrap(), dsl::parse(b).unwrap());
        if canon::equivalence_key(&pa) != canon::equivalence_key(&pb) {
            unmerged.push(format!("#{i}:\n  {}\n  {}", canon::canonical_term(&pa), canon::canonical_term(&pb)));
        }
    }
    eprintln!("C4.2: {} of {PAIRS} rewritten programs got a different key", unmerged.len());
    for u in &unmerged {
        eprintln!("unmerged {u}");
    }
    assert!(unmerged.len() * 100 <= PAIRS, "{} of {PAIRS} rewritten programs got a different key", unmerged.len());
}

/// Child mode: print the key of every program in the file named by `MM_KEYS_PROGRAMS`.
#[test]
fn fresh_process_child() {
    let Ok(path) = std::env::var("MM_KEYS_PROGRAMS") else { return };
    let text = std::fs::read_to_string(path).unwrap();
    let keys: Vec<String> = text.lines().map(|l| key(&serde_json::from_str::<String>(l).unwrap())).collect();
    println!("KEYS\n{}\nEND", keys.join("\n"));
}

#[test]
fn fresh_processes_compute_the_same_keys() {
    let weights = hand_built_pairs().into_iter().chain(rejected_pairs()).flat_map(|(a, b)| [a, b]);
    let named = weights.map(|w| wrap(&serde_json::from_str(&w).unwrap()));
    let programs: Vec<String> = pairs().into_iter().flat_map(|(a, b)| [a, b]).chain(named).collect();
    let here: Vec<String> = programs.iter().map(|p| key(p)).collect();
    let file = std::env::temp_dir().join(format!("mm-keys-{}.jsonl", std::process::id()));
    let lines: Vec<String> = programs.iter().map(|p| serde_json::to_string(p).unwrap()).collect();
    std::fs::write(&file, lines.join("\n")).unwrap();
    for child in 0..CHILDREN {
        let out = Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "fresh_process_child", "--nocapture", "--test-threads=1"])
            .env("MM_KEYS_PROGRAMS", &file)
            .output()
            .unwrap();
        assert!(out.status.success(), "child {child} failed: {}", String::from_utf8_lossy(&out.stderr));
        let stdout = String::from_utf8(out.stdout).unwrap();
        let body = stdout.split("KEYS\n").nth(1).and_then(|s| s.split("\nEND").next()).expect("child printed no keys");
        let theirs: Vec<&str> = body.lines().collect();
        assert_eq!(theirs.len(), here.len(), "child {child}: key count");
        for (i, (a, b)) in here.iter().zip(&theirs).enumerate() {
            assert_eq!(a, b, "child {child}: program {i} got a different key in a fresh process");
        }
    }
    std::fs::remove_file(file).ok();
}
