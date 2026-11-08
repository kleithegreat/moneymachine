//! Lean's `Ctx.make` and `Ctx.admissible` (reference/lean/Ref/Sim.lean) on constructed markets: a run refuses an
//! inadmissible market with R_BINDING before step 0, delivers the bound sources alone, and R_INPUT_UNAVAILABLE names the
//! input the program read. Argon's review of slice 4 (`audit/stage7/slice4-review-argon.md`), F1, F2, F4 and F5.

mod common;

use mm::dsl;
use mm::machine::Obs;
use mm::market::{CoinRules, Market, Policy, Venue, BAR, HOUR};
use mm::sim::{self, Abort, Event};

const DELTA: i64 = 120_000;
const END: i64 = 6 * BAR;

fn prog(weight: &str, lets: &str) -> dsl::Program {
    dsl::parse(&common::inputs(), &format!(
        r#"{{"dsl": 1, "name": "c", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}}, "let": {{{lets}}}, "weight": {weight}}}"#
    ))
    .unwrap()
}

fn source(name: &str) -> usize {
    common::registry().iter().position(|d| d.name == name).unwrap()
}

/// One coin's bars and hourly funding through `END`, each known 60 s after its event time.
fn base() -> Vec<Obs> {
    let bars = (1..=END / BAR).map(|k| common::bar(0, k * BAR, k * BAR + 60_000, [100.0, 101.0, 99.0, 100.0], 1.0, 1));
    bars.chain((0..=END / HOUR).map(|h| common::funding(0, h * HOUR, h * HOUR + 60_000, 0.0, 0.0))).collect()
}

fn run(p: &dsl::Program, m: &Market) -> Result<sim::Run, Abort> {
    let rules = CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: false, cost_bps: [[0.0; 2]; 2], calibration_range: None };
    let venue = Venue { taker_fee: 0.0, min_notional: 10.0, coins: vec!["X".into()], rules: vec![rules], rules_hash: String::new(), execution_hash: String::new() };
    let policy = Policy { delta: DELTA, settlement_latency: 60_000, w_start: 0, holdout_start: i64::MAX, w_end: END };
    sim::run(p, m, &venue, &policy, END)
}

fn code(r: Result<sim::Run, Abort>) -> String {
    r.map_or_else(|e| e.code().to_string(), |_| "ok".to_string())
}

/// F1: an event source's observation without a slot (the review's retraction of key 4h) is inadmissible, whatever
/// the delivery order would make of it.
#[test]
fn an_event_observation_without_a_slot_is_r_binding() {
    let p = prog(r#"{"op": "sign", "args": [{"op": "div", "args": [{"ref": "x"}, {"const": 1, "unit": "ev"}]}]}"#, r#""x": {"input": "forum_posts"}"#);
    let mut obs = base();
    let mut a = common::count("forum_posts", 0, BAR, 2 * BAR + DELTA, 0.0);
    (a.slot, a.vals, a.retraction, a.recorded) = (None, vec![None], true, 2 * BAR + 10);
    let mut b = common::count("forum_posts", 0, 2 * BAR, 2 * BAR + DELTA, 3.0);
    b.recorded = 2 * BAR + 5;
    obs.extend([a, b]);
    assert_eq!(code(run(&p, &common::market(obs, vec![(0, END)]))), "R_BINDING");
}

/// F2: a bars record that is not a retraction but has no role payload (its trades cell null) is inadmissible, not
/// dropped from execution while its values still reach the machine.
#[test]
fn a_live_role_record_without_a_payload_is_r_binding() {
    let p = prog(r#"{"op": "sign", "args": [{"op": "div", "args": [{"ref": "m"}, {"const": 1, "unit": "usd/coin"}]}]}"#,
                 r#""m": {"op": "mean", "hours": 4, "args": [{"input": "close"}]}"#);
    let mut obs = base();
    obs[0].role = None;
    assert_eq!(code(run(&p, &common::market(obs, vec![(0, END)]))), "R_BINDING");
}

/// F4: an observation of a source the store does not bind is never delivered, so it cannot move `inputs_known`.
#[test]
fn an_unbound_source_is_not_delivered() {
    let p = prog(r#"{"const": 1, "unit": "1"}"#, "");
    let mut obs = base();
    obs.push(common::count("forum_posts", 0, BAR, BAR + 100_000, 1.0));
    let mut m = common::market(obs, vec![(0, END)]);
    m.bound[source("forum-events")] = false;
    let known = run(&p, &m).unwrap().trace.iter().find_map(|e| match e {
        Event::Fill(f) => Some(f.inputs_known),
        _ => None,
    });
    assert_eq!(known, Some(BAR + 60_000));
}

/// F5: the refusal names the input the program read, not the first of its source's inputs.
#[test]
fn input_unavailable_names_the_input_read() {
    let p = prog(r#"{"op": "sign", "args": [{"op": "div", "args": [{"input": "open"}, {"const": 1, "unit": "usd/coin"}]}]}"#, "");
    let mut m = common::market(base(), vec![(0, END)]);
    m.bound[source("hl-bars-4h")] = false;
    match run(&p, &m) {
        Err(Abort::InputUnavailable(msg)) => assert!(msg.starts_with("open:"), "{msg}"),
        other => panic!("{:?}", other.map(|_| ())),
    }
}
