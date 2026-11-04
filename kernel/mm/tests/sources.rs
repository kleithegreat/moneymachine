//! The committed registry reads and validates (kernel/SOURCES.md), and malformed declarations are rejected.

use mm::dsl::Node;
use mm::source::{self, Cadence, Entity};
use std::path::Path;

fn repo_sources() -> &'static Path {
    Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))
}

#[test]
fn the_committed_registry_is_valid() {
    let ds = source::registry(repo_sources()).unwrap();
    let names: Vec<_> = ds.iter().map(|d| d.name.as_str()).collect();
    assert_eq!(names, ["discourse-polls", "discourse-sightings", "forum-events", "governance-events", "hl-bars-4h", "hl-funding", "snapshot-polls", "snapshot-sightings"]);
    let bars = &ds[4];
    assert_eq!(bars.cadence, Cadence::Held { period: 14_400_000, phase: 0, slot: "eventTime".into() });
    assert!(bars.roles.contains_key("bars") && bars.fields.contains_key("close"));
    assert!(ds[5].rule_text.starts_with("{\"rule\": 1,"));
}

#[test]
fn malformed_declarations_are_rejected() {
    let good = std::fs::read_to_string(repo_sources().join("hl-funding/1.json")).unwrap();
    assert!(source::declaration(&good).is_ok());
    for (from, to) in [
        ("\"entity\": \"coin\"", "\"entity\": \"region\""),
        ("\"unit\": \"1/h\"", "\"unit\": \"furlong\""),
        ("\"phase_ms\": 0", "\"phase_ms\": 3600000"),
        ("\"slot\": \"eventTime\"", "\"slot\": \"fetchedAt\""),
        ("\"missing\": \"undefined\"", "\"missing\": \"zero\""),
        ("{\"field\": \"reportedTime\"}, {\"ms\": 60000}", "{\"field\": \"nowhere\"}, {\"ms\": 60000}"),
        ("\"rate\": \"fundingRate\"", "\"rate\": \"fundingRate\", \"extra\": \"x\""),
        ("\"depends\": {}", "\"depends\": {}, \"depends\": {}"),
        ("\"funding\": {", "\"Funding\": {"),
    ] {
        assert!(good.contains(from), "{from}");
        assert!(source::declaration(&good.replace(from, to)).is_err(), "accepted: {to}");
    }
}

#[test]
fn evidence_declarations_are_keyed_by_their_own_columns() {
    let polls = r#"{"declaration": 1, "name": "forum-polls", "version": 1, "entity": {"evidence": ["key", "recv"], "event": "recv"},
        "times": ["recv"], "fields": {}, "cadence": {"evidence": {}}, "missing": "undefined", "revisions": "latest",
        "rule": {"rule": 1, "expr": {"max": [{"field": "recv"}, {"field": "fetchedAt"}]}}, "depends": {}, "role": {}}"#;
    let d = source::declaration(polls).unwrap();
    let key = vec!["key".into(), "recv".into()];
    assert_eq!((d.entity, d.cadence), (Entity::Evidence { key, event: "recv".into() }, Cadence::Evidence));
    for (from, to) in [
        (r#"["key", "recv"], "event": "recv"}"#, r#"[], "event": "recv"}"#),
        (r#"["key", "recv"], "event": "recv"}"#, r#"["key", "key"], "event": "recv"}"#),
        (r#"["key", "recv"], "event": "recv"}"#, r#"["key", "recv"], "event": "recv", "coin": []}"#),
        (r#"["key", "recv"], "event": "recv"}"#, r#"["key", "recv"]}"#),
        (r#""event": "recv"}"#, r#""event": "id"}"#),
        (r#""event": "recv"}"#, r#""event": "key"}"#),
        (r#"{"evidence": ["key", "recv"], "event": "recv"}"#, r#""coin""#),
        (r#""fields": {}"#, r#""fields": {"polls": {"column": "n", "unit": "ev"}}"#),
        (r#""role": {}"#, r#""role": {"settlement": {"rate": "recv"}}"#),
        (r#"{"evidence": {}}"#, r#"{"event": {"slot": "recv"}}"#),
        (r#"{"evidence": {}}"#, r#"{"evidence": {"slot": "recv"}}"#),
    ] {
        assert!(polls.contains(from), "{from}");
        assert!(source::declaration(&polls.replace(from, to)).is_err(), "accepted: {to}");
    }
    let funding = std::fs::read_to_string(repo_sources().join("hl-funding/1.json")).unwrap();
    let evidence_cadence = funding.replace(r#"{"held": {"period_ms": 3600000, "phase_ms": 0, "slot": "eventTime"}}"#, r#"{"evidence": {}}"#);
    assert!(source::declaration(&evidence_cadence).is_err());
}

#[test]
fn a_registry_entry_must_match_its_file() {
    let dir = std::env::temp_dir().join(format!("mm-sources-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(dir.join("hl-funding")).unwrap();
    let file = std::fs::read_to_string(repo_sources().join("hl-funding/1.json")).unwrap();
    std::fs::write(dir.join("hl-funding/1.json"), file.replace("60000", "60001")).unwrap();
    let sha = source::declaration(&file).unwrap().hash;
    std::fs::write(dir.join("registry.json"), format!(r#"{{"registry": 1, "declarations": {{"hl-funding": {{"version": 1, "sha256": "{sha}"}}}}}}"#)).unwrap();
    assert!(source::registry(&dir).unwrap_err().contains("SHA-256"));
    std::fs::remove_dir_all(&dir).unwrap();
}

const HELD: &str = r#"{"declaration": 1, "name": "zeta", "version": 1, "entity": "coin", "times": ["eventTime"],
    "fields": {"alpha": {"column": "a", "unit": "usd/coin"}, "beta": {"column": "b", "unit": "1/h"}},
    "cadence": {"held": {"period_ms": 3600000, "phase_ms": 0, "slot": "eventTime"}}, "missing": "undefined",
    "revisions": "latest", "rule": {"rule": 1, "expr": {"field": "eventTime"}}, "depends": {}, "role": {}}"#;

const EVENT: &str = r#"{"declaration": 1, "name": "omega", "version": 1, "entity": "coin", "times": ["eventTime"],
    "fields": {"gamma": {"column": "count", "unit": "ev"}}, "cadence": {"event": {"slot": "eventTime"}},
    "missing": "undefined", "revisions": "latest", "rule": {"rule": 1, "expr": {"field": "eventTime"}}, "depends": {},
    "role": {}}"#;

/// `sign(input + 1 usd/coin)`: accepted only while `name` is a declared input in usd/coin.
fn reading(name: &str) -> String {
    format!(r#"{{"dsl": 1, "name": "p", "mechanism": {{"counterparty": "", "predictions": [], "capacity": ""}},
        "weight": {{"op": "sign", "args": [{{"op": "add", "args": [{{"input": "{name}"}}, {{"const": 1, "unit": "usd/coin"}}]}}]}}}}"#)
}

fn check(files: &[&str], name: &str) -> Result<mm::dsl::Program, &'static str> {
    let reg: Vec<_> = files.iter().map(|f| source::declaration(f).unwrap()).collect();
    mm::dsl::parse(&source::inputs(&reg), &reading(name)).map_err(|r| r.code.name())
}

/// Lean's `Registry.inputs` over a registry the tests make up: each input keeps its declaration and field, renaming
/// or retyping a field changes what the checker accepts, and a legacy name is no input unless declared.
#[test]
fn the_checker_reads_inputs_from_the_registry_it_is_given() {
    let reg = [EVENT, HELD].map(|f| source::declaration(f).unwrap());
    let table: Vec<_> = source::inputs(&reg).into_iter().map(|i| (i.name, i.source, i.field, i.event, i.unit)).collect();
    let want = [("gamma", 0, 0, true, "ev"), ("alpha", 1, 0, false, "usd/coin"), ("beta", 1, 1, false, "1/h")];
    assert_eq!(table, want.map(|(n, s, k, e, u)| (n.to_string(), s, k, e, mm::units::Unit::parse(u).unwrap())));

    let p = check(&[EVENT, HELD], "alpha").unwrap();
    assert_eq!(p.sources(), [1]);
    let input = |p: &mm::dsl::Program| p.nodes.iter().find_map(|n| if let Node::Input(k) = n { Some(p.inputs[*k].clone()) } else { None }).unwrap();
    assert_eq!((input(&p).source, input(&p).field), (1, 0));
    let p = check(&[HELD, EVENT], "alpha").unwrap();
    assert_eq!((p.sources(), input(&p).source, input(&p).field), (vec![0], 0, 0));

    let renamed = HELD.replace(r#""alpha""#, r#""delta""#);
    assert_eq!(check(&[EVENT, &renamed], "alpha").err(), Some("E_UNKNOWN_INPUT"));
    assert_eq!(input(&check(&[EVENT, &renamed], "delta").unwrap()).name, "delta");
    let retyped = HELD.replace(r#""unit": "usd/coin""#, r#""unit": "coin""#);
    assert_eq!(check(&[EVENT, &retyped], "alpha").err(), Some("E_UNIT"));
    assert_eq!(check(&[EVENT, HELD], "funding").err(), Some("E_UNKNOWN_INPUT"));
}

/// Each committed event feed depends on its own family's evidence only (the migration annex, §1).
#[test]
fn each_event_feed_depends_on_its_own_evidence() {
    let ds = source::registry(repo_sources()).unwrap();
    for (feed, family) in [("forum-events", "discourse-"), ("governance-events", "snapshot-")] {
        let d = ds.iter().find(|d| d.name == feed).unwrap();
        let ups: Vec<_> = source::depends(&ds, d).into_iter().map(|u| ds[u].name.as_str()).collect();
        assert_eq!(ups, [format!("{family}polls"), format!("{family}sightings")], "{feed}");
    }
}
