//! Admission on metadata and event times (laws-v2-draft.md §2): each named attack refused with its code and position,
//! beside its positive control.

use mm::admission::{admit, Binding, Cert, Meta, Mode, Roles};
use mm::source::{self, Declaration};
use std::path::Path;

const POLLS: &str = r#"{"declaration": 1, "name": "forum-polls", "version": 1, "entity": {"evidence": ["key", "recv"], "event": "recv"},
    "times": ["recv"], "fields": {}, "cadence": {"evidence": {}}, "missing": "undefined", "revisions": "latest",
    "rule": {"rule": 1, "expr": {"max": [{"field": "recv"}, {"field": "fetchedAt"}]}}, "depends": {}, "role": {}}"#;

const COUNTS: &str = r#"{"declaration": 1, "name": "forum-counts", "version": 1, "entity": "coin",
    "times": ["eventTime"], "fields": {"posts": {"column": "count", "unit": "ev"}}, "cadence": {"event": {"slot": "eventTime"}},
    "missing": "undefined", "revisions": "latest",
    "rule": {"rule": 1, "expr": {"max": [{"add": [{"field": "eventTime"}, {"ms": 120000}]}, {"dep": "recording"}]}},
    "depends": {"recording": {"sources": ["forum-polls"], "lag_ms": 0}}, "role": {}}"#;

/// The committed registry's venue sources (bars 0, funding 1) with a derived event source (3) over an evidence source (2).
fn registry() -> Vec<Declaration> {
    let mut reg = source::registry(Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))).unwrap();
    reg.retain(|d| d.name.starts_with("hl-"));
    reg.extend([POLLS, COUNTS].map(|f| source::declaration(f).unwrap()));
    reg
}

const ROLES: Roles = Roles { bars: 0, settlement: 1 };

fn cert(reg: &[Declaration], s: usize) -> Cert {
    let upstream = source::depends(reg, &reg[s]).iter().map(|u| format!("cert{u}")).collect();
    Cert { id: format!("cert{s}"), decl: reg[s].hash.clone(), manifest: format!("data{s}"), policy: "P".into(),
           verifier: "V".into(), upstream, controls: reg[s].controls().iter().map(|c| c.to_string()).collect(),
           venue_state: true }
}

/// Every source bound to its own dataset under a matching certificate: the positive control.
fn meta(reg: &[Declaration]) -> Meta {
    let n = reg.len();
    Meta { bindings: (0..n).map(|s| (s, Binding { dataset: format!("data{s}"), cert: format!("cert{s}") })).collect(),
           certs: (0..n).map(|s| cert(reg, s)).collect(), supersessions: vec![], position: 10, policy: "P".into(),
           verifier: "V".into(), holdout: vec!["held-out".into()], holdout_start: 1_000 }
}

fn refusal(reg: &[Declaration], m: &Meta, sources: &[usize], rows: &[(usize, i64)]) -> Option<(u8, &'static str)> {
    admit(reg, &ROLES, sources, m, Mode::Search, |_| rows.to_vec()).err().map(|(p, e)| (p, e.code()))
}

fn admitted(reg: &[Declaration], m: &Meta, sources: &[usize]) -> Vec<usize> {
    admit(reg, &ROLES, sources, m, Mode::Search, |_| vec![(0, 999)]).unwrap()
}

#[test]
fn every_bound_source_and_its_dependencies_are_required() {
    let reg = registry();
    let mut m = meta(&reg);
    assert_eq!(admitted(&reg, &m, &[]), [0, 1, 3, 2]);
    m.bindings.remove(&3);
    assert_eq!(admitted(&reg, &m, &[]), [0, 1]);
    assert_eq!(refusal(&reg, &m, &[3], &[]), Some((2, "R_INPUT_UNAVAILABLE")));
}

#[test]
fn invalid_roles() {
    let reg = registry();
    let m = meta(&reg);
    for roles in [Roles { bars: 1, settlement: 0 }, Roles { bars: 0, settlement: 0 }, Roles { bars: 0, settlement: 9 }] {
        let r = admit(&reg, &roles, &[], &m, Mode::Search, |_| vec![]);
        assert_eq!(r.err().map(|(p, e)| (p, e.code())), Some((1, "R_ROLES")));
    }
}

#[test]
fn replayed_certificate() {
    let reg = registry();
    let mut m = meta(&reg);
    m.bindings.get_mut(&3).unwrap().dataset = "data3-recomputed".into();
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")));
    m.certs[3].manifest = "data3-recomputed".into();
    assert_eq!(admitted(&reg, &m, &[]), [0, 1, 3, 2]);
    for replay in [|k: &mut Cert| k.decl = "another".into(), |k: &mut Cert| k.policy = "P2".into(),
                   |k: &mut Cert| k.verifier = "V2".into(), |k: &mut Cert| k.upstream.clear()] {
        let mut m = meta(&reg);
        replay(&mut m.certs[3]);
        assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")));
    }
}

#[test]
fn superseded_certificates() {
    let reg = registry();
    let mut m = meta(&reg);
    m.supersessions.push(("cert2".into(), 11));
    assert_eq!(admitted(&reg, &m, &[]), [0, 1, 3, 2]);
    m.position = 11;
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")));
    m.bindings.remove(&3);
    m.bindings.remove(&2);
    assert_eq!(admitted(&reg, &m, &[]), [0, 1], "a superseded upstream certificate of an unrequired source");
}

#[test]
fn uncertified_role_provider() {
    let reg = registry();
    let mut m = meta(&reg);
    m.bindings.get_mut(&0).unwrap().cert = "cert-missing".into();
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")));
}

#[test]
fn provider_without_venue_state() {
    let reg = registry();
    let mut m = meta(&reg);
    m.certs[3].venue_state = false;
    assert_eq!(admitted(&reg, &m, &[]), [0, 1, 3, 2]);
    m.certs[1].venue_state = false;
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")));
}

#[test]
fn control_column_unauthorized() {
    let reg = registry();
    for col in ["coin", "eventTime", "fetchedAt", "tombstone"] {
        let mut m = meta(&reg);
        m.certs[3].controls.remove(col);
        assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")), "{col}");
    }
}

#[test]
fn upstream_controls_unauthorized() {
    let reg = registry();
    for col in ["key", "recv", "fetchedAt", "tombstone"] {
        let mut m = meta(&reg);
        m.certs[2].controls.remove(col);
        assert_eq!(refusal(&reg, &m, &[], &[]), Some((4, "R_UNCERTIFIED")), "{col}");
    }
}

#[test]
fn holdout_copy_refused() {
    let reg = registry();
    let mut m = meta(&reg);
    m.holdout.push("data1".into());
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((3, "R_HOLDOUT")));
    assert!(admit(&reg, &ROLES, &[], &m, Mode::Holdout, |_| vec![]).is_ok());
}

#[test]
fn holdout_dependency_refused() {
    let reg = registry();
    let mut m = meta(&reg);
    m.holdout.push("data2".into());
    assert_eq!(refusal(&reg, &m, &[], &[]), Some((3, "R_HOLDOUT")));
}

#[test]
fn holdout_rows_refused_after_metadata() {
    let reg = registry();
    let m = meta(&reg);
    let mut asked = vec![];
    let r = admit(&reg, &ROLES, &[], &m, Mode::Search, |req| {
        asked = req.to_vec();
        vec![(0, 999), (2, 1_000)]
    });
    assert_eq!(r.err().map(|(p, e)| (p, e.code())), Some((5, "R_HOLDOUT")));
    assert_eq!(asked, [0, 1, 3, 2]);
    let mut m = meta(&reg);
    m.certs[0].venue_state = false;
    let r = admit(&reg, &ROLES, &[], &m, Mode::Search, |_| panic!("rows read before stage 1 passed"));
    assert_eq!(r.err().map(|(p, e)| (p, e.code())), Some((4, "R_UNCERTIFIED")));
}
