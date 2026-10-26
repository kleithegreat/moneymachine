//! Source declarations and the registry (kernel/SOURCES.md, version 1): reading and validating them. Nothing here
//! knows a concrete source, dataset or field name; the only fixed names are the role contracts' (SOURCES.md §6).

use crate::rule::{self, Expr, Json};
use crate::units::Unit;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

/// The role contracts: each role's columns (SOURCES.md §6).
pub const ROLES: [(&str, &[&str]); 2] =
    [("bars", &["openTime", "open", "high", "low", "close", "trades"]), ("settlement", &["rate"])];

#[derive(Debug)]
pub struct Field {
    pub column: String,
    pub unit: Unit,
}

#[derive(Debug, PartialEq)]
pub enum Cadence {
    Held { period: i128, phase: i128, slot: String },
    Event { slot: String },
}

#[derive(Debug)]
pub struct Dependency {
    pub sources: Vec<String>,
    pub lag: i128,
}

#[derive(Debug)]
pub struct Declaration {
    pub name: String,
    pub version: i128,
    pub times: Vec<String>,
    /// DSL input name → field.
    pub fields: BTreeMap<String, Field>,
    pub cadence: Cadence,
    pub rule: Expr,
    /// The exact text of the `rule` member's value, which a dataset version pins.
    pub rule_text: String,
    pub depends: BTreeMap<String, Dependency>,
    /// Role → role column → stored column.
    pub roles: BTreeMap<String, BTreeMap<String, String>>,
}

const KEYS: [&str; 12] =
    ["declaration", "name", "version", "entity", "times", "fields", "cadence", "missing", "revisions", "rule", "depends", "role"];

fn name_ok(s: &str, first: fn(char) -> bool, rest: fn(char) -> bool, max: usize) -> bool {
    let mut cs = s.chars();
    cs.next().is_some_and(first) && cs.all(rest) && s.chars().count() <= max
}

fn source_name(s: &str) -> bool {
    let c = |c: char| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-';
    name_ok(s, c, c, 64)
}

fn input_name(s: &str) -> bool {
    name_ok(s, |c| c.is_ascii_lowercase(), |c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_', 32)
}

fn obj(v: &Json) -> Result<&BTreeMap<String, Json>, String> {
    if let Json::Obj(m) = v { Ok(m) } else { Err("an object is required".into()) }
}

fn text(v: &Json) -> Result<&str, String> {
    if let Json::Str(s) = v { Ok(s) } else { Err("a string is required".into()) }
}

fn int(v: &Json) -> Result<i128, String> {
    match v {
        Json::Int(Some(n)) if (rule::LO..=rule::HI).contains(n) => Ok(*n),
        _ => Err("an in-range integer is required".into()),
    }
}

fn exactly(m: &BTreeMap<String, Json>, keys: &[&str]) -> Result<(), String> {
    let got: BTreeSet<&str> = m.keys().map(String::as_str).collect();
    let want: BTreeSet<&str> = keys.iter().copied().collect();
    if got == want { Ok(()) } else { Err(format!("keys must be exactly {want:?}")) }
}

/// A declaration from its file's text, or why it is rejected.
pub fn declaration(file: &str) -> Result<Declaration, String> {
    let (doc, spans) = rule::parse_with_spans(file).ok_or("malformed JSON")?;
    let d = obj(&doc)?;
    exactly(d, &KEYS)?;
    if int(&d["declaration"])? != 1 {
        return Err("declaration must be 1".into());
    }
    let name = text(&d["name"])?.to_string();
    if !source_name(&name) {
        return Err("name".into());
    }
    let version = int(&d["version"])?;
    if version < 1 {
        return Err("version".into());
    }
    if text(&d["entity"])? != "coin" || text(&d["missing"])? != "undefined" || text(&d["revisions"])? != "latest" {
        return Err("entity, missing and revisions must be coin, undefined and latest".into());
    }
    let Json::Arr(ts) = &d["times"] else { return Err("times".into()) };
    let times: Vec<String> = ts.iter().map(|t| text(t).map(String::from)).collect::<Result<_, _>>()?;
    let distinct: BTreeSet<&String> = times.iter().collect();
    if distinct.len() != times.len() || times.iter().any(|t| t.is_empty() || t == "fetchedAt") {
        return Err("times must be distinct, non-empty and exclude fetchedAt".into());
    }
    let mut fields = BTreeMap::new();
    for (input, f) in obj(&d["fields"])? {
        let f = obj(f)?;
        exactly(f, &["column", "unit"])?;
        let unit = Unit::parse(text(&f["unit"])?).ok_or(format!("{input}: unit"))?;
        if !input_name(input) {
            return Err(format!("input name {input}"));
        }
        fields.insert(input.clone(), Field { column: text(&f["column"])?.to_string(), unit });
    }
    let cad = obj(&d["cadence"])?;
    let cadence = match (cad.len(), cad.get("held"), cad.get("event")) {
        (1, Some(h), None) => {
            let h = obj(h)?;
            exactly(h, &["period_ms", "phase_ms", "slot"])?;
            let (period, phase) = (int(&h["period_ms"])?, int(&h["phase_ms"])?);
            if period < 1 || !(0..period).contains(&phase) {
                return Err("held cadence needs period_ms > 0 and 0 <= phase_ms < period_ms".into());
            }
            Cadence::Held { period, phase, slot: text(&h["slot"])?.to_string() }
        }
        (1, None, Some(e)) => {
            let e = obj(e)?;
            exactly(e, &["slot"])?;
            Cadence::Event { slot: text(&e["slot"])?.to_string() }
        }
        _ => return Err("cadence must be held or event".into()),
    };
    let (Cadence::Held { slot, .. } | Cadence::Event { slot }) = &cadence;
    if !times.contains(slot) {
        return Err("the cadence's slot must be one of times".into());
    }
    let mut depends = BTreeMap::new();
    for (dep, v) in obj(&d["depends"])? {
        let v = obj(v)?;
        exactly(v, &["sources", "lag_ms"])?;
        let Json::Arr(xs) = &v["sources"] else { return Err(format!("dependency {dep}: sources")) };
        let sources: Vec<String> = xs.iter().map(|x| text(x).map(String::from)).collect::<Result<_, _>>()?;
        let lag = int(&v["lag_ms"])?;
        if dep.is_empty() || sources.is_empty() || !sources.iter().all(|s| source_name(s)) || lag < 0 {
            return Err(format!("dependency {dep}"));
        }
        depends.insert(dep.clone(), Dependency { sources, lag });
    }
    let mut roles = BTreeMap::new();
    for (role, m) in obj(&d["role"])? {
        let want = ROLES.iter().find(|(r, _)| r == role).ok_or(format!("unknown role {role}"))?.1;
        let m = obj(m)?;
        exactly(m, want)?;
        roles.insert(role.clone(), m.iter().map(|(k, v)| Ok((k.clone(), text(v)?.to_string()))).collect::<Result<_, String>>()?);
    }
    let rule_text = spans["rule"].to_string();
    let context: BTreeSet<String> = times.iter().cloned().chain(["fetchedAt".to_string()]).collect();
    let rule = rule::check(&rule_text, &context, &depends.keys().cloned().collect()).ok_or("rule: E_RULE")?;
    Ok(Declaration { name, version, times, fields, cadence, rule, rule_text, depends, roles })
}

/// The active declarations of `sources/registry.json` under `dir`, each checked against its pinned SHA-256: input
/// names unique, dependencies registered and acyclic.
pub fn registry(dir: &Path) -> Result<Vec<Declaration>, String> {
    let read = |p: &Path| std::fs::read_to_string(p).map_err(|e| format!("{}: {e}", p.display()));
    let reg = rule::parse(&read(&dir.join("registry.json"))?).ok_or("registry.json: malformed JSON")?;
    let reg = obj(&reg)?;
    exactly(reg, &["registry", "declarations"])?;
    if int(&reg["registry"])? != 1 {
        return Err("registry must be 1".into());
    }
    let mut out: Vec<Declaration> = vec![];
    for (name, entry) in obj(&reg["declarations"])? {
        let e = obj(entry)?;
        exactly(e, &["version", "sha256"])?;
        let version = int(&e["version"])?;
        let file = read(&dir.join(name).join(format!("{version}.json")))?;
        if crate::market::sha256_hex(file.as_bytes()) != text(&e["sha256"])? {
            return Err(format!("{name} {version}: SHA-256 differs from the registry"));
        }
        let d = declaration(&file).map_err(|e| format!("{name} {version}: {e}"))?;
        if &d.name != name || d.version != version {
            return Err(format!("{name} {version}: the file declares {} {}", d.name, d.version));
        }
        out.push(d);
    }
    let mut inputs = BTreeSet::new();
    for d in &out {
        for input in d.fields.keys() {
            if !inputs.insert(input.clone()) {
                return Err(format!("input name {input} is declared twice"));
            }
        }
    }
    let names: BTreeSet<&String> = out.iter().map(|d| &d.name).collect();
    let deps: BTreeMap<&String, Vec<&String>> =
        out.iter().map(|d| (&d.name, d.depends.values().flat_map(|x| &x.sources).collect())).collect();
    for d in &out {
        let mut seen = BTreeSet::new();
        let mut stack: Vec<&String> = vec![&d.name];
        while let Some(n) = stack.pop() {
            for up in deps.get(n).into_iter().flatten() {
                if !names.contains(up) {
                    return Err(format!("{}: dependency {up} is not registered", d.name));
                }
                if *up == &d.name {
                    return Err(format!("{}: its dependencies form a cycle", d.name));
                }
                if seen.insert(*up) {
                    stack.push(up);
                }
            }
        }
    }
    Ok(out)
}
