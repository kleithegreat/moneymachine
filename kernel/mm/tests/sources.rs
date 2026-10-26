//! The committed registry reads and validates (kernel/SOURCES.md), and malformed declarations are rejected.

use mm::source::{self, Cadence};
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
fn a_registry_entry_must_match_its_file() {
    let dir = std::env::temp_dir().join(format!("mm-sources-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(dir.join("hl-funding")).unwrap();
    let file = std::fs::read_to_string(repo_sources().join("hl-funding/1.json")).unwrap();
    std::fs::write(dir.join("hl-funding/1.json"), file.replace("60000", "60001")).unwrap();
    std::fs::write(dir.join("registry.json"), std::fs::read_to_string(repo_sources().join("registry.json")).unwrap()
        .replace("\"hl-bars-4h\": {\n   \"version\": 1,\n   \"sha256\": \"c5f6ed32c5cf757df70890ba2442182fb45be25bec431f3237a423637f9e9ca1\"\n  },\n  ", "")).unwrap();
    assert!(source::registry(&dir).unwrap_err().contains("SHA-256"));
    std::fs::remove_dir_all(&dir).unwrap();
}
