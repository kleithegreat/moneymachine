//! The availability rule language, version 1 (kernel/RULES.md §1-5): strict JSON reading, checking, and evaluation of
//! a checked rule on a row. `ingest/knownat.py` implements the same language; the C7.6 suite holds both, and an
//! independent third, to the same results.

use std::collections::{BTreeMap, BTreeSet};

pub const LO: i128 = -(1 << 62);
pub const HI: i128 = (1 << 62) - 1;
const MAX_DEPTH: usize = 64;
const MAX_RULE_BYTES: usize = 65_536;
const MAX_ARGS: usize = 16;

/// A JSON value under RULES.md §1. Integers are exact; `Int(None)` is an integer token too long to be in range.
#[derive(Clone, Debug, PartialEq)]
pub enum Json {
    Null,
    Bool(bool),
    Int(Option<i128>),
    Real,
    Str(String),
    Arr(Vec<Json>),
    Obj(BTreeMap<String, Json>),
}

struct Parser<'a> {
    text: &'a str,
    s: &'a [u8],
    i: usize,
    /// The byte span of each top-level object member's value.
    spans: BTreeMap<String, (usize, usize)>,
}

/// The value of a JSON text, or None if it is malformed.
pub fn parse(text: &str) -> Option<Json> {
    parse_with_spans(text).map(|(v, _)| v)
}

/// The value of a JSON text and, if it is an object, the exact text of each of its members' values.
pub fn parse_with_spans(text: &str) -> Option<(Json, BTreeMap<String, &str>)> {
    let mut p = Parser { text, s: text.as_bytes(), i: 0, spans: BTreeMap::new() };
    p.space();
    let v = p.value(1)?;
    p.space();
    let spans = p.spans.iter().map(|(k, &(a, b))| (k.clone(), &text[a..b])).collect();
    (p.i == p.s.len()).then_some((v, spans))
}

impl Parser<'_> {
    fn space(&mut self) {
        while self.i < self.s.len() && matches!(self.s[self.i], b' ' | b'\t' | b'\n' | b'\r') {
            self.i += 1;
        }
    }

    fn peek(&self) -> Option<u8> {
        self.s.get(self.i).copied()
    }

    fn value(&mut self, depth: usize) -> Option<Json> {
        let c = self.peek()?;
        if (c == b'{' || c == b'[') && depth > MAX_DEPTH {
            return None;
        }
        match c {
            b'{' => self.obj(depth),
            b'[' => self.arr(depth),
            b'"' => self.string().map(Json::Str),
            _ => {
                for (word, v) in [(&b"true"[..], Json::Bool(true)), (b"false", Json::Bool(false)), (b"null", Json::Null)] {
                    if self.s[self.i..].starts_with(word) {
                        self.i += word.len();
                        return Some(v);
                    }
                }
                self.number()
            }
        }
    }

    fn obj(&mut self, depth: usize) -> Option<Json> {
        self.i += 1;
        let mut out = BTreeMap::new();
        self.space();
        if self.peek()? == b'}' {
            self.i += 1;
            return Some(Json::Obj(out));
        }
        loop {
            self.space();
            if self.peek()? != b'"' {
                return None;
            }
            let k = self.string()?;
            self.space();
            if self.peek()? != b':' {
                return None;
            }
            self.i += 1;
            self.space();
            if out.contains_key(&k) {
                return None;
            }
            let start = self.i;
            let v = self.value(depth + 1)?;
            if depth == 1 {
                self.spans.insert(k.clone(), (start, self.i));
            }
            out.insert(k, v);
            self.space();
            let c = self.peek()?;
            self.i += 1;
            match c {
                b'}' => return Some(Json::Obj(out)),
                b',' => {}
                _ => return None,
            }
        }
    }

    fn arr(&mut self, depth: usize) -> Option<Json> {
        self.i += 1;
        let mut out = vec![];
        self.space();
        if self.peek()? == b']' {
            self.i += 1;
            return Some(Json::Arr(out));
        }
        loop {
            self.space();
            out.push(self.value(depth + 1)?);
            self.space();
            let c = self.peek()?;
            self.i += 1;
            match c {
                b']' => return Some(Json::Arr(out)),
                b',' => {}
                _ => return None,
            }
        }
    }

    fn hex4(&mut self) -> Option<u32> {
        let h = self.s.get(self.i..self.i + 4)?;
        let v = u32::from_str_radix(std::str::from_utf8(h).ok()?, 16).ok()?;
        if !h.iter().all(u8::is_ascii_hexdigit) {
            return None;
        }
        self.i += 4;
        Some(v)
    }

    fn string(&mut self) -> Option<String> {
        self.i += 1;
        let mut out = String::new();
        loop {
            let c = self.peek()?;
            match c {
                b'"' => {
                    self.i += 1;
                    return Some(out);
                }
                b'\\' => {
                    self.i += 1;
                    let e = self.peek()?;
                    self.i += 1;
                    match e {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'b' => out.push('\u{8}'),
                        b'f' => out.push('\u{c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => {
                            let u = self.hex4()?;
                            let ch = if (0xD800..0xDC00).contains(&u) {
                                if self.s.get(self.i..self.i + 2)? != b"\\u" {
                                    return None;
                                }
                                self.i += 2;
                                let low = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&low) {
                                    return None;
                                }
                                char::from_u32(0x10000 + ((u - 0xD800) << 10) + (low - 0xDC00))?
                            } else {
                                char::from_u32(u)?
                            };
                            out.push(ch);
                        }
                        _ => return None,
                    }
                }
                c if c < 0x20 => return None,
                _ => {
                    let ch = self.text[self.i..].chars().next()?;
                    out.push(ch);
                    self.i += ch.len_utf8();
                }
            }
        }
    }

    fn number(&mut self) -> Option<Json> {
        let start = self.i;
        if self.peek() == Some(b'-') {
            self.i += 1;
        }
        match self.peek()? {
            b'0' => self.i += 1,
            b'1'..=b'9' => {
                while self.peek().is_some_and(|c| c.is_ascii_digit()) {
                    self.i += 1;
                }
            }
            _ => return None,
        }
        let mut integer = true;
        if self.peek() == Some(b'.') {
            integer = false;
            self.i += 1;
            self.digits()?;
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            integer = false;
            self.i += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.i += 1;
            }
            self.digits()?;
        }
        if !integer {
            return Some(Json::Real);
        }
        let token = std::str::from_utf8(&self.s[start..self.i]).ok()?;
        if token.trim_start_matches('-').len() > 19 {
            return Some(Json::Int(None));
        }
        Some(Json::Int(Some(token.parse().ok()?)))
    }

    fn digits(&mut self) -> Option<()> {
        let start = self.i;
        while self.peek().is_some_and(|c| c.is_ascii_digit()) {
            self.i += 1;
        }
        (self.i > start).then_some(())
    }
}

/// A checked expression.
#[derive(Clone, Debug)]
pub enum Expr {
    Field(String),
    Dep(String),
    Ms(i128),
    Add(Box<Expr>, Box<Expr>),
    Floor(Box<Expr>, i128),
    Max(Vec<Expr>),
}

#[derive(PartialEq)]
enum Ty {
    Time,
    Duration,
}

/// The checked expression of a rule document text, or None (`E_RULE`).
pub fn check(text: &str, fields: &BTreeSet<String>, deps: &BTreeSet<String>) -> Option<Expr> {
    if text.len() > MAX_RULE_BYTES {
        return None;
    }
    let Json::Obj(doc) = parse(text)? else { return None };
    if doc.len() != 2 || doc.get("rule")? != &Json::Int(Some(1)) {
        return None;
    }
    let (e, ty) = typed(doc.get("expr")?, fields, deps)?;
    let lb = lower_bound(&e);
    (ty == Ty::Time && !lb.is_empty() && deps.iter().all(|d| lb.contains(&(true, d.clone())))).then_some(e)
}

fn typed(v: &Json, fields: &BTreeSet<String>, deps: &BTreeSet<String>) -> Option<(Expr, Ty)> {
    let Json::Obj(m) = v else { return None };
    if m.len() != 1 {
        return None;
    }
    let (k, a) = m.iter().next()?;
    let args = |n: Option<usize>| -> Option<Vec<(Expr, Ty)>> {
        let Json::Arr(xs) = a else { return None };
        if n.is_some_and(|n| xs.len() != n) {
            return None;
        }
        xs.iter().map(|x| typed(x, fields, deps)).collect()
    };
    match k.as_str() {
        "field" | "dep" => {
            let Json::Str(name) = a else { return None };
            let known = if k == "field" { fields } else { deps };
            if name.is_empty() || !known.contains(name) {
                return None;
            }
            Some((if k == "field" { Expr::Field(name.clone()) } else { Expr::Dep(name.clone()) }, Ty::Time))
        }
        "ms" => match a {
            Json::Int(Some(n)) if (0..=HI).contains(n) => Some((Expr::Ms(*n), Ty::Duration)),
            _ => None,
        },
        "add" => {
            let mut xs = args(Some(2))?;
            let (d, dt) = xs.pop()?;
            let (t, tt) = xs.pop()?;
            (tt == Ty::Time && dt == Ty::Duration).then(|| (Expr::Add(Box::new(t), Box::new(d)), Ty::Time))
        }
        "floor" => {
            let mut xs = args(Some(2))?;
            let (p, _) = xs.pop()?;
            let (t, tt) = xs.pop()?;
            match (tt, p) {
                (Ty::Time, Expr::Ms(n)) if n > 0 => Some((Expr::Floor(Box::new(t), n), Ty::Time)),
                _ => None,
            }
        }
        "max" => {
            let xs = args(None)?;
            if !(2..=MAX_ARGS).contains(&xs.len()) || xs.iter().any(|(_, t)| *t != Ty::Time) {
                return None;
            }
            Some((Expr::Max(xs.into_iter().map(|(e, _)| e).collect()), Ty::Time))
        }
        _ => None,
    }
}

/// RULES.md §4's lower-bound set, as (is a dependency, name).
fn lower_bound(e: &Expr) -> BTreeSet<(bool, String)> {
    match e {
        Expr::Field(f) => BTreeSet::from([(false, f.clone())]),
        Expr::Dep(d) => BTreeSet::from([(true, d.clone())]),
        Expr::Add(t, _) => lower_bound(t),
        Expr::Max(xs) => xs.iter().flat_map(lower_bound).collect(),
        Expr::Ms(_) | Expr::Floor(..) => BTreeSet::new(),
    }
}

/// An evaluation's rejection code.
pub type Code = &'static str;

fn ranged(x: i128) -> Result<i128, Code> {
    if (LO..=HI).contains(&x) {
        Ok(x)
    } else {
        Err("R_OVERFLOW")
    }
}

/// A checked expression's value on decoded row and deps objects.
pub fn evaluate(e: &Expr, row: &BTreeMap<String, Json>, deps: &BTreeMap<String, Json>) -> Result<i128, Code> {
    match e {
        Expr::Field(n) | Expr::Dep(n) => match (if matches!(e, Expr::Field(_)) { row } else { deps }).get(n) {
            None | Some(Json::Null) => Err("R_FIELD_ABSENT"),
            Some(Json::Int(Some(x))) => ranged(*x),
            Some(Json::Int(None)) => Err("R_OVERFLOW"),
            Some(_) => Err("R_FIELD_TYPE"),
        },
        Expr::Ms(n) => Ok(*n),
        Expr::Add(t, d) => {
            let t = evaluate(t, row, deps)?;
            ranged(t + evaluate(d, row, deps)?)
        }
        Expr::Floor(t, p) => {
            let t = evaluate(t, row, deps)?;
            ranged(t - t.rem_euclid(*p))
        }
        Expr::Max(xs) => {
            let mut best = i128::MIN;
            for x in xs {
                best = best.max(evaluate(x, row, deps)?);
            }
            Ok(best)
        }
    }
}

/// A conformance case's result (RULES.md §7): the Time, or a code.
pub fn result(rule: &str, fields: &BTreeSet<String>, deps_declared: &BTreeSet<String>, row: &str, deps: &str) -> Result<i128, Code> {
    let Some(e) = check(rule, fields, deps_declared) else { return Err("E_RULE") };
    let (Some(Json::Obj(row)), Some(Json::Obj(deps))) = (parse(row), parse(deps)) else { return Err("R_ROW") };
    evaluate(&e, &row, &deps)
}

/// A resolver conformance case's result (RULES.md §6; kernel/tests/rules/resolver_suite.py).
pub fn resolve(case: &serde_json::Value) -> serde_json::Value {
    use serde_json::json;
    let set = |k: &str| -> BTreeSet<String> {
        case[k].as_array().into_iter().flatten().filter_map(|x| x.as_str().map(String::from)).collect()
    };
    let fields: BTreeSet<String> = set("fields").into_iter().chain(["fetchedAt".to_string()]).collect();
    let Some(e) = check(case["rule"].as_str().unwrap_or_default(), &fields, &set("deps_declared")) else { return json!("E_RULE") };
    let version = case["version"].as_i64().unwrap_or(i64::MIN);
    let queries: Vec<i64> = case["queries"].as_array().into_iter().flatten().filter_map(|q| q.as_i64()).collect();
    let none = |selected: serde_json::Value| json!({"selected": selected, "knownAt": null, "visible": vec![false; queries.len()]});
    let eligible: Vec<&serde_json::Value> = case["revisions"].as_array().into_iter().flatten()
        .filter(|r| r["fetchedAt"].as_i64().is_some_and(|f| f <= version)).collect();
    let fetched = |r: &serde_json::Value| r["fetchedAt"].as_i64().unwrap_or_default();
    if eligible.iter().map(|r| fetched(r)).collect::<BTreeSet<_>>().len() != eligible.len() {
        return json!("INVALID");
    }
    let (Some(selected), Some(earliest)) = (eligible.iter().max_by_key(|r| fetched(r)), eligible.iter().min_by_key(|r| fetched(r))) else {
        return none(json!(null));
    };
    if selected["tombstone"].as_bool().unwrap_or(false) {
        return none(json!(fetched(selected)));
    }
    let lags: Vec<(String, i128)> = case["lags"].as_object().into_iter().flatten()
        .map(|(k, v)| (k.clone(), v.as_i64().unwrap_or_default() as i128)).collect();
    let known = effective(&e, selected, earliest, &lags);
    let visible: Vec<bool> = queries.iter().map(|&t| known.as_ref().is_ok_and(|k| *k <= t as i128)).collect();
    json!({"selected": fetched(selected), "knownAt": match known { Ok(k) => json!(k as i64), Err(c) => json!(c) }, "visible": visible})
}

fn effective(e: &Expr, selected: &serde_json::Value, earliest: &serde_json::Value, lags: &[(String, i128)]) -> Result<i128, Code> {
    let text = |r: &serde_json::Value, k: &str| r[k].as_str().unwrap_or_default().to_string();
    let (Some(Json::Obj(mut row)), Some(Json::Obj(deps))) = (parse(&text(selected, "row")), parse(&text(selected, "deps"))) else {
        return Err("R_ROW");
    };
    let fetched = selected["fetchedAt"].as_i64().unwrap_or_default() as i128;
    let observed = row.clone();
    row.insert("fetchedAt".into(), Json::Int(Some(fetched)));
    let Some(Json::Obj(first)) = parse(&text(earliest, "row")) else { return Err("R_ROW") };
    let mut known = evaluate(e, &row, &deps)?;
    let keys: BTreeSet<&String> = observed.keys().chain(first.keys()).collect();
    if keys.iter().any(|k| observed.get(*k).unwrap_or(&Json::Null) != first.get(*k).unwrap_or(&Json::Null)) {
        known = known.max(fetched);
    }
    for (d, lag) in lags {
        let Some(Json::Int(Some(t))) = deps.get(d) else { return Err("R_FIELD_ABSENT") };
        known = known.max(ranged(t + lag)?);
    }
    Ok(known)
}
