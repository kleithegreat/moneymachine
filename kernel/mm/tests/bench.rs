//! Evaluator-only timings, release build: data load is excluded; interpretation and every runtime
//! check are included; no ledger, no caching.
//! C1.8: W0 over the search part of W on the stage 0 data. Needs data/ and venue/hyperliquid/execution.json:
//! `cargo test --release --test bench w0_median -- --ignored --nocapture`.

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

/// Milliseconds of `reps` runs of `prog`.
fn times(prog: &str, m: &market::Market, venue: &market::Venue, policy: &market::Policy, end: i64, reps: usize) -> Vec<f64> {
    let prog = dsl::parse(prog).unwrap();
    (0..reps)
        .map(|_| {
            let t = Instant::now();
            let run = sim::run(&prog, m, venue, policy, end).unwrap();
            assert!(!run.returns.is_empty());
            t.elapsed().as_secs_f64() * 1e3
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
    let mut ms = times(&std::fs::read_to_string(root.join("kernel/strategies/w0.json")).unwrap(), &m, &venue, &policy, end, 20);
    ms.sort_by(f64::total_cmp);
    let cpu = std::fs::read_to_string("/proc/cpuinfo").ok().and_then(|s| s.lines().find(|l| l.starts_with("model name")).map(String::from));
    eprintln!("W0 median {:.1} ms over 20 runs (min {:.1}, max {:.1}); {cpu:?}", ms[10], ms[0], ms[19]);
    assert!(ms[10] <= 100.0);
}
