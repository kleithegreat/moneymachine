//! The committed registry reads and validates (kernel/SOURCES.md), and malformed declarations are rejected.

use mm::source::{self, Cadence, Entity};
use std::path::Path;

fn repo_sources() -> &'static Path {
    Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))
}

#[test]
fn the_committed_registry_is_valid() {
    let ds = source::registry(repo_sources()).unwrap();
    let names: Vec<_> = ds.iter().map(|d| d.name.as_str()).collect();
    assert_eq!(names, ["hl-bars-4h", "hl-funding"]);
    let bars = &ds[0];
    assert_eq!(bars.cadence, Cadence::Held { period: 14_400_000, phase: 0, slot: "eventTime".into() });
    assert!(bars.roles.contains_key("bars") && bars.fields.contains_key("close"));
    assert!(ds[1].rule_text.starts_with("{\"rule\": 1,"));
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
    std::fs::write(dir.join("registry.json"), std::fs::read_to_string(repo_sources().join("registry.json")).unwrap()
        .replace("\"hl-bars-4h\": {\n   \"version\": 2,\n   \"sha256\": \"f0292b9bd871a810aa7d0240cda19c68e9609797c8f4dea1256b5cd17cd42a91\"\n  },\n  ", "")).unwrap();
    assert!(source::registry(&dir).unwrap_err().contains("SHA-256"));
    std::fs::remove_dir_all(&dir).unwrap();
}
