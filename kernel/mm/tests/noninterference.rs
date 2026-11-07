//! The resolver's two-run checks (self-composition; Clarkson and Schneider, *Hyperproperties*, 2010), the human's
//! decision of 2026-11-02 (`audit/stage7/rust-port-plan.md`, slice 5): non-interference compares two runs. Each runs
//! the kernel from Parquet stores (`market::load`, then `sim::run`); each has a positive control in
//! `kernel/mutants/mutants.py` (S1 to S3, D1), a mutant that reads ahead, which must fail it.
//!
//! The daemon's holdout-bytes check is `gate/tests/test_agent_daemon.py`.

mod common;

use common::store::{self, DELTA};
use mm::market::{self, BAR, HOUR};
use mm::sim::{self, Event};
use mm::dsl;
use std::path::Path;

const HOURS: i64 = 8 * 24;
/// Decisions through T are compared.
const T: i64 = 20 * BAR + DELTA;

/// Reads every venue-state input (funding, premium, open, high, low, close, volume) and the forum's counts.
const PROGRAM: &str = r#"{"dsl": 1, "name": "two-run", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
    "params": {"thr": {"value": 0.0001, "unit": "1/h"}, "size": {"value": 0.05, "unit": "1"}},
    "let": {"f": {"input": "funding"}, "e": {"input": "forum_posts"},
            "body": {"op": "add", "args": [{"op": "sign", "args": [{"op": "sub", "args": [{"input": "close"}, {"input": "open"}]}]},
                                           {"op": "sign", "args": [{"op": "sub", "args": [{"input": "high"}, {"input": "low"}]}]}]},
            "flow": {"op": "add", "args": [{"op": "sign", "args": [{"input": "volume"}]}, {"op": "sign", "args": [{"input": "premium"}]}]}},
    "weight": {"op": "if", "args": [
        {"op": "and", "args": [{"op": "gt", "args": [{"ref": "e"}, {"const": 1, "unit": "ev"}]},
                               {"op": "gt", "args": [{"op": "abs", "args": [{"ref": "f"}]}, {"param": "thr"}]}]},
        {"op": "mul", "args": [{"op": "neg", "args": [{"op": "sign", "args": [{"ref": "f"}]}]},
                               {"op": "mul", "args": [{"param": "size"}, {"op": "add", "args": [{"ref": "body"}, {"ref": "flow"}]}]}]},
        {"const": 0, "unit": "1"}]}}"#;

/// The store `base` holds: every venue-state and event row, fetched at 1000.
fn base(root: &Path) {
    store::write_funding(root, 1000, &store::funding(HOURS));
    store::write_bars(root, 1000, &store::bars(HOURS));
    store::write_counts(root, 1000, &store::counts(HOURS));
}

fn run(root: &Path, version: i64) -> sim::Run {
    let policy = store::policy(HOURS);
    let market = market::load(&[root.to_path_buf()], version, &store::venue(), &policy, None).unwrap();
    let program = dsl::parse(&common::inputs(), PROGRAM).unwrap();
    sim::run(&program, &market, &store::venue(), &policy, HOURS * HOUR).unwrap()
}

/// The decisions (and holds) through T: (time, coin, weight bits, quantity bits).
fn decisions(run: &sim::Run) -> Vec<String> {
    run.trace
        .iter()
        .filter_map(|e| match e {
            Event::Decision { t, coin, weight, qty } if *t <= T => Some(format!("decision {t} {coin} {} {}", weight.to_bits(), qty.to_bits())),
            Event::Hold { t, coin, why } if *t <= T => Some(format!("hold {t} {coin} {why}")),
            _ => None,
        })
        .collect()
}

/// Every input a decision through T reads: each node's value for each coin at each tick through T, as bits, taken
/// before any order is sized, so that execution state cannot hide a difference.
fn inputs(root: &Path, version: i64) -> Vec<String> {
    let policy = store::policy(HOURS);
    let venue = store::venue();
    let market = market::load(&[root.to_path_buf()], version, &venue, &policy, None).unwrap();
    let program = dsl::parse(&common::inputs(), PROGRAM).unwrap();
    let mut seen = vec![];
    sim::observe(&program, &market, &venue, &policy, HOURS * HOUR, |h, machine| {
        if h + policy.delta <= T {
            for i in 0..program.nodes.len() {
                for c in 0..venue.coins.len() {
                    seen.push(format!("{h} {i} {c} {:?}", machine.value(i, c).map(f64::to_bits)));
                }
            }
        }
        Ok(())
    })
    .unwrap();
    seen
}

fn scratch(tag: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("mm-two-run-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    dir
}

/// Two stores that differ only in records known after T, none of them a revision of a venue-state key: the event
/// counts of every hour after T, fetched later. The decisions through T are byte-identical, quantities included.
#[test]
fn decisions_through_t_ignore_records_known_after_t() {
    let (one, two) = (scratch("a1"), scratch("a2"));
    base(&one);
    store::write_funding(&two, 1000, &store::funding(HOURS));
    store::write_bars(&two, 1000, &store::bars(HOURS));
    let after = T / HOUR + 1;
    let altered: Vec<_> = store::counts(HOURS).into_iter().map(|c| if c.hour >= after { store::Count { count: 4.0 - c.count, ..c } } else { c }).collect();
    store::write_counts(&two, 1000, &altered);
    let (a, b) = (run(&one, 1000), run(&two, 1000));
    let (da, db) = (decisions(&a), decisions(&b));
    assert!(da.iter().any(|d| d.starts_with("decision")) && da.len() > 20, "the program decides: {}", da.len());
    assert_eq!(da, db);
    let all = |r: &sim::Run| r.trace.iter().filter(|e| matches!(e, Event::Decision { .. })).count();
    assert_ne!(
        a.trace.iter().filter(|e| matches!(e, Event::Decision { t, .. } if *t > T)).collect::<Vec<_>>(),
        b.trace.iter().filter(|e| matches!(e, Event::Decision { t, .. } if *t > T)).collect::<Vec<_>>(),
        "the stores differ after T ({} decisions)", all(&a)
    );
}

/// Two stores that differ only in a late final venue-state revision: corrections of early bars and funding rates,
/// fetched (so known) long after T. Fills, funding, marks and equity differ, but every input a decision through T
/// reads is byte-identical: each node's value, before any order is sized.
#[test]
fn a_late_venue_state_revision_leaves_every_decision_input_alone() {
    let (one, two) = (scratch("b1"), scratch("b2"));
    base(&one);
    base(&two);
    let late = (T / HOUR + 24) * HOUR;
    let early_funding: Vec<_> = store::funding(HOURS).into_iter().filter(|f| f.hour % 3 == 0 && f.hour < 60).map(|f| store::Funding { rate: -f.rate, ..f }).collect();
    let early_bars: Vec<_> = store::bars(HOURS).into_iter().filter(|b| b.k < 12).map(|b| store::Bar { close: b.close * 1.2, ..b }).collect();
    store::write_funding(&two, late, &early_funding);
    store::write_bars(&two, late, &early_bars);
    let (a, b) = (run(&one, late), run(&two, late));
    let (before, after) = (inputs(&one, late), inputs(&two, late));
    assert!(before.iter().filter(|v| v.contains("Some")).count() > 1000);
    assert_eq!(before, after);
    assert_ne!(a.equity, b.equity, "the revision changes execution");
    let cash = |r: &sim::Run| r.trace.iter().filter(|e| matches!(e, Event::Fill(_) | Event::Funding { .. })).count();
    assert!(cash(&a) > 0 && cash(&b) > 0);
}
