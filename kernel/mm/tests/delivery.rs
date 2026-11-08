//! What the simulator delivers from a resolved store (kernel/RULES.md §6, SOURCES.md §4): a retraction carries no
//! value and no role payload, so an input retracted at a decision tick is stale; observations of an event source
//! sharing (knownAt, coin) arrive in (recording time, eventTime) order. Both from Parquet stores through
//! `market::load` and `sim::run`; Argon's review of slice 5 (`audit/stage7/slice5-review-argon.md`), F1 and F2.

mod common;

use common::store::{self, Col, DELTA};
use mm::dsl;
use mm::market::{self, BAR, HOUR};
use mm::sim::{self, Event};
use std::path::{Path, PathBuf};

const HOURS: i64 = 8 * 24;

fn scratch(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("mm-delivery-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    dir
}

fn run(root: &Path, program: &str) -> sim::Run {
    let policy = store::policy(HOURS);
    let market = market::load(&[root.to_path_buf()], i64::MAX / 2, common::registry(), &store::venue(), &policy, None).unwrap();
    let program = dsl::parse(&common::inputs(), program).unwrap();
    sim::run(&program, &market, &store::venue(), &policy, HOURS * HOUR).unwrap()
}

fn program(weight: &str, lets: &str) -> String {
    format!(
        r#"{{"dsl": 1, "name": "t", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}},
        "params": {{}}, "let": {{{lets}}}, "weight": {weight}}}"#
    )
}

fn at(run: &sim::Run, t: i64, coin: usize) -> Vec<String> {
    run.trace
        .iter()
        .filter_map(|e| match e {
            Event::Decision { t: u, coin: c, .. } if *u == t && *c == coin => Some("decision".to_string()),
            Event::Hold { t: u, coin: c, why } if *u == t && *c == coin => Some(format!("hold {why}")),
            _ => None,
        })
        .collect()
}

fn full_base(root: &Path) {
    store::write_funding(root, 1000, &store::funding(HOURS));
    store::write_bars(root, 1000, &store::bars(HOURS));
}

/// Row `hour`/`k` of coin A retracted by a tombstone fetched before it was known.
const T_D: i64 = BAR + DELTA;

#[test]
fn a_retracted_funding_entry_is_stale_not_fresh() {
    let root = scratch("f");
    full_base(&root);
    store::write(
        &root.join("funding/2000.parquet"),
        vec![
            ("coin", Col::S(vec![Some("A".into())])),
            ("eventTime", Col::I(vec![Some(BAR)])),
            ("fundingRate", Col::F(vec![Some(0.0)])),
            ("premium", Col::F(vec![Some(0.0)])),
            ("reportedTime", Col::I(vec![Some(BAR)])),
            ("tombstone", Col::B(vec![Some(true)])),
            ("fetchedAt", Col::I(vec![Some(2000)])),
        ],
    );
    let r = run(&root, &program(r#"{"const": 0.05, "unit": "1"}"#, ""));
    assert_eq!(at(&r, T_D, 0), vec!["hold stale"]);
    assert_eq!(at(&r, T_D, 1), vec!["decision"], "the other coin is untouched");
}

#[test]
fn a_retracted_bar_is_stale_and_cannot_size_an_order() {
    let root = scratch("b");
    full_base(&root);
    store::write(
        &root.join("bars_4h/2000.parquet"),
        vec![
            ("coin", Col::S(vec![Some("A".into())])),
            ("eventTime", Col::I(vec![Some(BAR)])),
            ("openTime", Col::I(vec![Some(0)])),
            ("open", Col::F(vec![Some(1.0)])),
            ("high", Col::F(vec![Some(1.0)])),
            ("low", Col::F(vec![Some(1.0)])),
            ("close", Col::F(vec![Some(1.0)])),
            ("volume", Col::F(vec![Some(1.0)])),
            ("trades", Col::I(vec![Some(1)])),
            ("tombstone", Col::B(vec![Some(true)])),
            ("fetchedAt", Col::I(vec![Some(2000)])),
        ],
    );
    let r = run(&root, &program(r#"{"const": 0.05, "unit": "1"}"#, ""));
    assert_eq!(at(&r, T_D, 0), vec!["hold stale"]);
}

/// Key 12h of coin A is corrected at 16h + delta, the instant key 16h becomes known; the correction was recorded
/// after key 16h's first revision, so it is delivered last and leaves the slot 12h in the latest cell, not 16h.
#[test]
fn observations_sharing_a_known_at_arrive_in_recording_order() {
    let root = scratch("e");
    full_base(&root);
    let counts = |skip: &[i64]| -> Vec<store::Count> { store::counts(HOURS).into_iter().filter(|c| !(c.coin == "A" && skip.contains(&c.hour))).collect() };
    store::write_counts(&root, 1000, &counts(&[12, 16]));
    let row = |hour, count| store::Count { coin: "A", hour, count };
    let (k12, k16) = (12 * HOUR, 16 * HOUR);
    store::write_counts(&root, k12 + 1000, &[row(12, 2.0)]);
    store::write_counts(&root, k16 + 1000, &[row(16, 3.0)]);
    store::write_counts(&root, k16 + DELTA, &[row(12, 3.0)]);
    let r = run(&root, &program(r#"{"op": "if", "args": [{"op": "gt", "args": [{"ref": "e"}, {"const": 1, "unit": "ev"}]}, {"const": 0.05, "unit": "1"}, {"const": 0, "unit": "1"}]}"#, r#""e": {"input": "forum_posts"}"#));
    assert_eq!(at(&r, k16 + DELTA, 0), vec!["hold undefined"]);
}
