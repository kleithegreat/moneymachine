//! Evaluator-only timings, release build: data load is excluded; interpretation and every runtime
//! check are included; no ledger, no caching.
//! C1.8: W0 over the search part of W on the stage 0 data. Needs data/ and venue/hyperliquid/execution.json:
//! `cargo test --release --test bench w0_median -- --ignored --nocapture`.
//! C6.5: `evaluator_times` (below).

use mm::{dsl, market, sim};
use std::path::{Path, PathBuf};
use std::time::Instant;

fn load(store: &Path, venue_dir: &Path, version: i64) -> (market::Market, market::Venue, market::Policy, i64) {
    let policy = market::policy(&store.join("policy.json")).unwrap();
    let venue = market::venue(venue_dir).unwrap();
    let m = market::load(&[store.to_path_buf()], version, &venue, &policy, Some(policy.holdout_start)).unwrap();
    let end = policy.holdout_start.min(policy.w_end);
    (m, venue, policy, end)
}

/// Milliseconds of `reps` runs of `prog`, or None if it is rejected or aborts.
fn times(prog: &str, m: &market::Market, venue: &market::Venue, policy: &market::Policy, end: i64, reps: usize) -> Option<Vec<f64>> {
    let prog = dsl::parse(prog).ok()?;
    (0..reps)
        .map(|_| {
            let t = Instant::now();
            let run = sim::run(&prog, m, venue, policy, end).ok()?;
            assert!(!run.returns.is_empty());
            Some(t.elapsed().as_secs_f64() * 1e3)
        })
        .collect()
}

#[test]
#[ignore]
fn w0_median_under_100ms() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let venue_dir = std::env::var("MM_VENUE").map(PathBuf::from).unwrap_or_else(|_| root.join("venue/hyperliquid"));
    let version: i64 = std::env::var("MM_VERSION").ok().and_then(|v| v.parse().ok()).unwrap_or(i64::MAX);
    let (m, venue, policy, end) = load(&root.join("data/store"), &venue_dir, version);
    let mut ms = times(&std::fs::read_to_string(root.join("kernel/strategies/w0.json")).unwrap(), &m, &venue, &policy, end, 20).unwrap();
    ms.sort_by(f64::total_cmp);
    let cpu = std::fs::read_to_string("/proc/cpuinfo").ok().and_then(|s| s.lines().find(|l| l.starts_with("model name")).map(String::from));
    eprintln!("W0 median {:.1} ms over 20 runs (min {:.1}, max {:.1}); {cpu:?}", ms[10], ms[0], ms[19]);
    assert!(ms[10] <= 100.0);
}

/// C6.5: for each line of the JSONL file `MM_PROGRAMS`, `MM_REPS` evaluator times on the store `MM_STORE`
/// (venue `MM_VENUE`, version `MM_VERSION`), as one JSON list per line to `MM_OUT` (null if not completed).
#[test]
#[ignore]
fn evaluator_times() {
    let var = |k: &str| std::env::var(k).unwrap_or_else(|_| panic!("{k} is not set"));
    let (m, venue, policy, end) = load(Path::new(&var("MM_STORE")), Path::new(&var("MM_VENUE")), var("MM_VERSION").parse().unwrap());
    let reps: usize = var("MM_REPS").parse().unwrap();
    let out: String = std::fs::read_to_string(var("MM_PROGRAMS"))
        .unwrap()
        .lines()
        .map(|p| serde_json::to_string(&times(p, &m, &venue, &policy, end, reps)).unwrap() + "\n")
        .collect();
    std::fs::write(var("MM_OUT"), out).unwrap();
}
