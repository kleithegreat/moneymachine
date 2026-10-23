//! Stage 5 event inputs: hourly counts visible only at their own hour's tick (never held),
//! the knownAt boundary, hours_since, and R_INPUT_UNAVAILABLE.

use mm::dsl;
use mm::machine::Machine;
use mm::market::{Event, HOUR};

const DELTA: i64 = 120_000;

fn prog(weight: &str, lets: &str) -> dsl::Program {
    dsl::parse(&format!(
        r#"{{"dsl": 1, "name": "e", "mechanism": {{"counterparty": "-", "predictions": [], "capacity": "-"}}, "let": {{{lets}}}, "weight": {weight}}}"#
    ))
    .unwrap()
}

fn probe(p: &dsl::Program) -> usize {
    p.lets.iter().find(|(n, _)| n == "x").unwrap().1
}

#[test]
fn counts_are_fresh_only_and_respect_known_at() {
    let p = prog(r#"{"const": 0, "unit": "1"}"#, r#""x": {"input": "forum_posts"}"#);
    let mut m = Machine::new(&p, 1);
    let e = Event { coin: 0, event: 5 * HOUR, known: 5 * HOUR + DELTA, count: 3.0 };
    assert!(m.deliver_event(0, e, 5 * HOUR + DELTA - 1).is_err());
    m.deliver_event(0, e, 5 * HOUR + DELTA).unwrap();
    m.tick(&[true], 5 * HOUR);
    assert_eq!(m.value(probe(&p), 0), Some(3.0));
    m.tick(&[true], 6 * HOUR);
    assert_eq!(m.value(probe(&p), 0), None);
}

#[test]
fn hours_since_counts_ticks_since_the_condition_held() {
    let p = prog(r#"{"const": 0, "unit": "1"}"#,
                 r#""x": {"op": "hours_since", "args": [{"op": "gt", "args": [{"input": "forum_posts"}, {"const": 0, "unit": "ev"}]}]}"#);
    let mut m = Machine::new(&p, 1);
    m.tick(&[true], 0);
    assert_eq!(m.value(probe(&p), 0), None);
    m.deliver_event(0, Event { coin: 0, event: HOUR, known: HOUR, count: 1.0 }, HOUR).unwrap();
    m.tick(&[true], HOUR);
    assert_eq!(m.value(probe(&p), 0), Some(0.0));
    for h in 2..5 {
        m.tick(&[true], h * HOUR);
    }
    assert_eq!(m.value(probe(&p), 0), Some(3.0));
}

#[test]
fn counts_have_their_own_unit() {
    let r = dsl::parse(r#"{"dsl": 1, "name": "e", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
        "weight": {"op": "add", "args": [{"input": "forum_posts"}, {"input": "premium"}]}}"#);
    assert_eq!(r.unwrap_err().code.name(), "E_UNIT");
}

#[test]
fn missing_dataset_is_input_unavailable() {
    for (input, dataset) in [("forum_posts", "events_forum"), ("gov_proposals", "events_governance")] {
        let p = prog(&format!(r#"{{"op": "sign", "args": [{{"op": "div", "args": [{{"input": "{input}"}}, {{"const": 1, "unit": "ev"}}]}}]}}"#), "");
        assert_eq!(p.event_datasets(), vec![dataset]);
        let market = mm::market::Market {
            funding: vec![], bars: vec![], bar_at: Default::default(), rate_at: Default::default(), bar_times: vec![vec![]],
            intervals: vec![(0, 10 * HOUR)], events: Default::default(), data_hash: String::new(),
        };
        let venue = mm::market::Venue { taker_fee: 0.0, min_notional: 10.0, coins: vec!["X".into()],
            rules: vec![mm::market::CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: false, cost_bps: [[0.0; 2]; 2], calibration_range: None }],
            rules_hash: String::new(), execution_hash: String::new() };
        let policy = mm::market::Policy { delta: DELTA, settlement_latency: 60_000, w_start: 0, holdout_start: i64::MAX, w_end: 100 * HOUR };
        match mm::sim::run(&p, &market, &venue, &policy, 100 * HOUR) {
            Err(e) => assert_eq!(e.code(), "R_INPUT_UNAVAILABLE"),
            Ok(_) => panic!("a program needing an absent dataset ran"),
        }
    }
}
