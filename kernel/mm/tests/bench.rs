//! C1.8: W0 over the search part of W on the stage 0 data, release build. Data load is
//! excluded; interpretation and every runtime check are included; no ledger, no caching.
//! Needs data/ and venue/hyperliquid/execution.json: `cargo test --release --test bench -- --ignored --nocapture`.

use mm::{dsl, market, sim};
use std::path::Path;
use std::time::Instant;

#[test]
#[ignore]
fn w0_median_under_100ms() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let policy = market::policy(&root.join("data/store/policy.json")).unwrap();
    let venue = market::venue(&root.join("venue/hyperliquid")).unwrap();
    let store = root.join("data/store");
    let version: i64 = std::env::var("MM_VERSION").ok().and_then(|v| v.parse().ok()).unwrap_or(i64::MAX);
    let m = market::load(&[store], version, &venue, &policy, Some(policy.holdout_start)).unwrap();
    let prog = dsl::parse(&std::fs::read_to_string(root.join("kernel/strategies/w0.json")).unwrap()).unwrap();
    let end = policy.holdout_start.min(policy.w_end);
    let mut ms: Vec<f64> = (0..20)
        .map(|_| {
            let t = Instant::now();
            let run = sim::run(&prog, &m, &venue, &policy, end).unwrap();
            assert!(!run.returns.is_empty());
            t.elapsed().as_secs_f64() * 1e3
        })
        .collect();
    ms.sort_by(f64::total_cmp);
    let cpu = std::fs::read_to_string("/proc/cpuinfo").ok().and_then(|s| s.lines().find(|l| l.starts_with("model name")).map(String::from));
    eprintln!("W0 median {:.1} ms over 20 runs (min {:.1}, max {:.1}); {cpu:?}", ms[10], ms[0], ms[19]);
    assert!(ms[10] <= 100.0);
}
