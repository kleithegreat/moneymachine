//! The resolver of kernel/RULES.md §6 (B3 revision) over the store's Parquet layout (kernel/SOURCES.md §2): every
//! `.parquet` file of a source's directory holds its stored revisions. `resolve` returns each key's timeline, one entry
//! per delivered revision at its own effective knownAt. `ingest/resolve.py` implements the same rules in Python; the
//! C7.6 suite holds the two, Lean and a third to the same results.
//!
//! A source is a declaration reduced to what resolution reads (RULES.md §7). Before a holdout check passes, a search
//! reads file footers and the event-time column alone: nothing else is decoded, and no statistic of another column is
//! used.

use crate::rule::{self, Expr, Json, HI, LO};
use arrow_array::{Array, BooleanArray, Float64Array, Int64Array, LargeStringArray, StringArray};
use arrow_schema::DataType;
use base64::Engine;
use bytes::Bytes;
use parquet::arrow::arrow_reader::{ArrowReaderMetadata, ArrowReaderOptions, ParquetRecordBatchReaderBuilder};
use parquet::arrow::ProjectionMask;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::path::{Path, PathBuf};
use std::sync::Arc;

pub const UNCHECKABLE: &str = "the holdout check cannot be made: an event time is not a non-null Int64 in range";
/// The columns the store writes beside observed values (SOURCES.md §1).
pub const METADATA: [&str; 6] = ["fetchedAt", "tombstone", "source", "hash", "upstream", "knownAt"];

/// An outcome with no timelines. `Display` of `Holdout` is exactly the prescribed message.
#[derive(Clone, Debug, PartialEq)]
pub enum Refusal {
    Decl,
    Rule,
    Invalid(String),
    Holdout(String),
}

impl Refusal {
    /// RULES.md §7's code, or the message of a holdout refusal.
    pub fn code(&self) -> String {
        match self {
            Refusal::Decl => "E_DECL".into(),
            Refusal::Rule => "E_RULE".into(),
            Refusal::Invalid(_) => "INVALID".into(),
            Refusal::Holdout(m) => m.clone(),
        }
    }
}

impl std::fmt::Display for Refusal {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Refusal::Invalid(m) => write!(f, "INVALID: {m}"),
            other => f.write_str(&other.code()),
        }
    }
}

fn invalid<E: std::fmt::Display>(e: E) -> Refusal {
    Refusal::Invalid(e.to_string())
}

#[derive(Clone, Debug, PartialEq)]
pub enum Cell {
    Null,
    Bool(bool),
    Int(i64),
    Real(f64),
    Str(Arc<str>),
}

/// A cell's identity: an integer is never a non-integer, a boolean never an integer, the two zeros one value.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum Ident {
    Null,
    Bool(bool),
    Int(i64),
    Real(u64),
    Str(Arc<str>),
}

impl Cell {
    pub fn ident(&self) -> Ident {
        match self {
            Cell::Null => Ident::Null,
            Cell::Bool(b) => Ident::Bool(*b),
            Cell::Int(i) => Ident::Int(*i),
            Cell::Real(x) => Ident::Real((x + 0.0).to_bits()),
            Cell::Str(s) => Ident::Str(s.clone()),
        }
    }

    /// The cell's `num` (RULES.md §6): the nearest binary64 number, none if it is not a number.
    pub fn num(&self) -> Option<f64> {
        match self {
            Cell::Int(i) => Some(*i as f64),
            Cell::Real(x) => Some(*x),
            _ => None,
        }
    }

    fn json(&self) -> Json {
        match self {
            Cell::Null => Json::Null,
            Cell::Bool(b) => Json::Bool(*b),
            Cell::Int(i) => Json::Int(Some(*i as i128)),
            Cell::Real(x) => Json::Real(*x),
            Cell::Str(s) => Json::Str(s.to_string()),
        }
    }

    pub fn value(&self) -> Value {
        match self {
            Cell::Null => Value::Null,
            Cell::Bool(b) => Value::Bool(*b),
            Cell::Int(i) => Value::from(*i),
            Cell::Real(x) => Value::from(*x),
            Cell::Str(s) => Value::from(s.to_string()),
        }
    }

    fn rank(&self) -> u8 {
        match self {
            Cell::Null => 0,
            Cell::Bool(_) => 1,
            Cell::Int(_) => 2,
            Cell::Real(_) => 3,
            Cell::Str(_) => 4,
        }
    }

    /// RULES.md §7's order: null, booleans false before true, integers, non-integers, strings by their scalars.
    pub fn cmp(&self, other: &Cell) -> Ordering {
        match (self, other) {
            (Cell::Bool(a), Cell::Bool(b)) => a.cmp(b),
            (Cell::Int(a), Cell::Int(b)) => a.cmp(b),
            (Cell::Real(a), Cell::Real(b)) => a.partial_cmp(b).unwrap_or(Ordering::Equal),
            (Cell::Str(a), Cell::Str(b)) => a.cmp(b),
            _ => self.rank().cmp(&other.rank()),
        }
    }
}

#[derive(Clone, Debug)]
pub enum Role {
    /// open, high, low, close, trades
    Bars([String; 5]),
    Settlement(String),
}

#[derive(Clone, Debug)]
pub struct Dep {
    pub name: String,
    pub sources: Vec<String>,
    pub lag: i64,
}

#[derive(Clone, Debug)]
pub struct Source {
    pub name: String,
    pub rule: String,
    pub times: Vec<String>,
    pub values: Vec<String>,
    pub entity: Vec<String>,
    pub event: String,
    pub slot: Option<String>,
    pub role: Option<Role>,
    pub evidence: bool,
    pub deps: Vec<Dep>,
}

impl Source {
    /// A source from RULES.md §7's JSON.
    pub fn from_json(v: &Value) -> Result<Source, String> {
        let strings = |k: &str| -> Result<Vec<String>, String> {
            v[k].as_array().ok_or(format!("source: {k}"))?.iter().map(|x| x.as_str().map(String::from).ok_or(format!("source: {k}"))).collect()
        };
        let text = |k: &str| v[k].as_str().map(String::from).ok_or(format!("source: {k}"));
        let role = match v["roles"].as_object() {
            None => None,
            Some(m) => {
                let cols: Vec<String> = m.values().next().and_then(|c| c.as_array()).into_iter().flatten().filter_map(|c| c.as_str().map(String::from)).collect();
                Some(if m.contains_key("bars") && cols.len() == 5 {
                    Role::Bars(cols.try_into().unwrap())
                } else if m.contains_key("settlement") && cols.len() == 1 {
                    Role::Settlement(cols[0].clone())
                } else {
                    return Err("source: roles".into());
                })
            }
        };
        let deps = v["deps"]
            .as_array()
            .ok_or("source: deps")?
            .iter()
            .map(|d| {
                Ok(Dep {
                    name: d["name"].as_str().ok_or("dep: name")?.into(),
                    sources: d["sources"].as_array().ok_or("dep: sources")?.iter().filter_map(|s| s.as_str().map(String::from)).collect(),
                    lag: d["lag"].as_i64().ok_or("dep: lag")?,
                })
            })
            .collect::<Result<Vec<_>, String>>()?;
        Ok(Source {
            name: text("name")?,
            rule: text("rule")?,
            times: strings("times")?,
            values: strings("values")?,
            entity: strings("entity")?,
            event: text("event")?,
            slot: v["slot"].as_str().map(String::from),
            role,
            evidence: v["evidence"].as_bool().unwrap_or(false),
            deps,
        })
    }

    fn role_columns(&self) -> Vec<&String> {
        match &self.role {
            None => vec![],
            Some(Role::Bars(c)) => c.iter().collect(),
            Some(Role::Settlement(c)) => vec![c],
        }
    }

    /// Every column the declaration names, sorted.
    pub fn declared(&self) -> Vec<String> {
        let mut all: BTreeSet<&String> = self.values.iter().chain(&self.times).chain(&self.entity).collect();
        all.insert(&self.event);
        all.extend(self.slot.iter());
        all.extend(self.role_columns());
        all.into_iter().cloned().collect()
    }
}

/// A file's bytes, read once, and its footer: its top-level names and types as the file states them. Everything
/// decoded later comes from these bytes (SOURCES.md §7).
struct Footer {
    path: PathBuf,
    bytes: Bytes,
    rows: i64,
    names: Vec<String>,
    types: Vec<DataType>,
    meta: ArrowReaderMetadata,
}

impl Footer {
    /// A file's footer, or INVALID if it fails SOURCES.md §2's footer schema checks.
    fn read(path: &Path) -> Result<Footer, Refusal> {
        let at = |e: String| Refusal::Invalid(format!("{}: {e}", path.display()));
        let bytes = Bytes::from(std::fs::read(path).map_err(|e| at(e.to_string()))?);
        let meta = ArrowReaderMetadata::load(&bytes, ArrowReaderOptions::new()).map_err(|e| at(e.to_string()))?;
        let file = meta.metadata().file_metadata();
        let names: Vec<String> = file.schema_descr().root_schema().get_fields().iter().map(|f| f.name().to_string()).collect();
        let embedded = file.key_value_metadata().and_then(|kv| kv.iter().find(|k| k.key == "ARROW:schema")).and_then(|k| k.value.clone());
        if let Some(blob) = embedded {
            let bytes = base64::engine::general_purpose::STANDARD.decode(blob).map_err(|e| at(e.to_string()))?;
            let schema = arrow_ipc::convert::try_schema_from_ipc_buffer(&bytes).map_err(|e| at(e.to_string()))?;
            if schema.fields().iter().map(|f| f.name().as_str()).ne(names.iter().map(String::as_str)) {
                return Err(at("the two schemas' top-level names differ".into()));
            }
        }
        if names.iter().collect::<BTreeSet<_>>().len() != names.len() {
            return Err(at("a top-level name repeats".into()));
        }
        let types: Vec<DataType> = meta.schema().fields().iter().map(|f| f.data_type().clone()).collect();
        if types.len() != names.len() {
            return Err(at("the schemas differ".into()));
        }
        let footer = Footer { path: path.to_path_buf(), bytes, rows: file.num_rows(), names, types, meta };
        if footer.type_of("fetchedAt") != Some(&DataType::Int64) || footer.type_of("tombstone").is_some_and(|t| t != &DataType::Boolean) {
            return Err(at("fetchedAt is not Int64 or tombstone is not Boolean".into()));
        }
        Ok(footer)
    }

    fn index(&self, name: &str) -> Option<usize> {
        self.names.iter().position(|n| n == name)
    }

    fn type_of(&self, name: &str) -> Option<&DataType> {
        self.index(name).map(|i| &self.types[i])
    }

    /// The batches of the named top-level columns, projected so that no other column chunk is decoded.
    fn batches(&self, columns: &[&str]) -> Result<parquet::arrow::arrow_reader::ParquetRecordBatchReader, Refusal> {
        let schema = self.meta.metadata().file_metadata().schema_descr();
        let mask = ProjectionMask::roots(schema, columns.iter().filter_map(|c| self.index(c)));
        ParquetRecordBatchReaderBuilder::new_with_metadata(self.bytes.clone(), self.meta.clone())
            .with_projection(mask)
            .build()
            .map_err(invalid)
    }
}

/// The `.parquet` files of a source's directory under each root, in name order.
pub fn files(roots: &[PathBuf], name: &str) -> Vec<PathBuf> {
    let mut out = vec![];
    for root in roots {
        let mut here: Vec<PathBuf> = std::fs::read_dir(root.join(name))
            .into_iter()
            .flatten()
            .filter_map(|e| Some(e.ok()?.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "parquet"))
            .collect();
        here.sort();
        out.extend(here);
    }
    out
}

/// SOURCES.md §2's holdout check on the event-time column of every row of the files of `checks`, pairs of footers and
/// their event column, which projects that column alone, and only when its footer type is Int64. Any uncheckable
/// event time, in any pair, takes precedence over every crossing, and a crossing names the least of them all.
fn holdout_check(checks: &[(&[Footer], &str)], boundary: i64) -> Result<(), Refusal> {
    let uncheckable = || Refusal::Holdout(UNCHECKABLE.into());
    let mut least: Option<i64> = None;
    for (footers, event) in checks {
        for f in footers.iter().filter(|f| f.rows > 0) {
            if f.type_of(event) != Some(&DataType::Int64) {
                return Err(uncheckable());
            }
            for batch in f.batches(&[event])? {
                let batch = batch.map_err(invalid)?;
                let col = batch.column(0);
                let Some(times) = col.as_any().downcast_ref::<Int64Array>().filter(|_| col.null_count() == 0) else { return Err(uncheckable()) };
                for &t in times.values().iter() {
                    if !(LO..=HI).contains(&(t as i128)) {
                        return Err(uncheckable());
                    }
                    if t >= boundary && least.is_none_or(|l| t < l) {
                        least = Some(t);
                    }
                }
            }
        }
    }
    match least {
        Some(l) => Err(Refusal::Holdout(format!("holdout crossing: event time {l} at or after {boundary}"))),
        None => Ok(()),
    }
}

type Lineage = BTreeMap<String, Vec<(usize, Vec<Ident>, i64)>>;

struct Rev {
    fetched: i64,
    tombstone: bool,
    /// The declared columns' cells, in `Source::declared` order; an absent column is null.
    cells: Vec<Cell>,
    lineage: Option<Lineage>,
}

pub struct Entry {
    pub fetched: i64,
    pub known: i64,
    pub retraction: bool,
    pub slot: Option<i64>,
    rev: usize,
}

pub struct Key {
    pub source: usize,
    pub entity: Vec<Cell>,
    pub event: i64,
    pub coin: Option<usize>,
    pub entries: Vec<Entry>,
    revs: Vec<usize>,
}

impl Key {
    /// The entry a query at t sees, or none.
    pub fn sees(&self, t: i64) -> Option<&Entry> {
        self.entries.iter().rfind(|e| e.known <= t).filter(|e| !e.retraction)
    }
}

/// The resolution of a registry: every key with an eligible revision, grouped by source in first-appearance order.
pub struct Resolved {
    pub sources: Vec<Source>,
    pub keys: Vec<Key>,
    revs: Vec<Vec<Rev>>,
    declared: Vec<Vec<String>>,
    /// Per source, each file's name and the SHA-256 of the bytes resolution read, in name order.
    pub files: Vec<Vec<(String, [u8; 32])>>,
}

fn cell_of(json: &Json) -> Option<Cell> {
    Some(match json {
        Json::Null => Cell::Null,
        Json::Bool(b) => Cell::Bool(*b),
        Json::Int(Some(i)) => Cell::Int(i64::try_from(*i).ok()?),
        Json::Real(x) if x.is_finite() => Cell::Real(*x),
        Json::Str(s) => Cell::Str(s.as_str().into()),
        _ => return None,
    })
}

fn lineage_of(text: &str, names: &HashMap<String, usize>, entity_columns: &[usize]) -> Result<Lineage, Refusal> {
    let bad = || Refusal::Invalid("lineage".into());
    let Some(Json::Obj(doc)) = rule::parse(text) else { return Err(bad()) };
    let mut out = Lineage::new();
    for (name, keys) in doc {
        let Json::Arr(keys) = keys else { return Err(bad()) };
        let mut list = vec![];
        for k in keys {
            let Json::Arr(k) = k else { return Err(bad()) };
            let [Json::Str(s), Json::Arr(cells), Json::Int(Some(e))] = k.as_slice() else { return Err(bad()) };
            let Some(&u) = names.get(s.as_str()) else { return Err(bad()) };
            if cells.len() != entity_columns[u] || !(LO..=HI).contains(e) {
                return Err(bad());
            }
            let idents: Option<Vec<Ident>> = cells.iter().map(|c| cell_of(c).map(|c| c.ident())).collect();
            list.push((u, idents.ok_or_else(bad)?, *e as i64));
        }
        out.insert(name, list);
    }
    Ok(out)
}

enum Column<'a> {
    Int(&'a Int64Array),
    Real(&'a Float64Array),
    Str(&'a StringArray),
    Large(&'a LargeStringArray),
    Bool(&'a BooleanArray),
}

impl Column<'_> {
    fn of(array: &dyn Array) -> Option<Column<'_>> {
        let any = array.as_any();
        Some(match array.data_type() {
            DataType::Int64 => Column::Int(any.downcast_ref()?),
            DataType::Float64 => Column::Real(any.downcast_ref()?),
            DataType::Utf8 => Column::Str(any.downcast_ref()?),
            DataType::LargeUtf8 => Column::Large(any.downcast_ref()?),
            DataType::Boolean => Column::Bool(any.downcast_ref()?),
            _ => return None,
        })
    }

    fn cell(&self, row: usize) -> Cell {
        let null = match self {
            Column::Int(a) => a.is_null(row),
            Column::Real(a) => a.is_null(row),
            Column::Str(a) => a.is_null(row),
            Column::Large(a) => a.is_null(row),
            Column::Bool(a) => a.is_null(row),
        };
        if null {
            return Cell::Null;
        }
        match self {
            Column::Int(a) => Cell::Int(a.value(row)),
            Column::Real(a) => Cell::Real(a.value(row)),
            Column::Str(a) => Cell::Str(a.value(row).into()),
            Column::Large(a) => Cell::Str(a.value(row).into()),
            Column::Bool(a) => Cell::Bool(a.value(row)),
        }
    }
}

fn read_revisions(footers: &[Footer], s: &Source, declared: &[String], version: i64, names: &HashMap<String, usize>, entity_columns: &[usize]) -> Result<Vec<Rev>, Refusal> {
    let mut out = vec![];
    let wanted: Vec<&str> = ["fetchedAt", "tombstone"].into_iter().chain(s.deps.first().map(|_| "upstream")).chain(declared.iter().map(String::as_str)).collect();
    let event = declared.iter().position(|c| c == &s.event).unwrap();
    for f in footers {
        let mut fetched_at = vec![];
        for batch in f.batches(&["fetchedAt"])? {
            let batch = batch.map_err(invalid)?;
            let fetched = batch.column(0).as_any().downcast_ref::<Int64Array>().ok_or_else(|| Refusal::Invalid(format!("{}: fetchedAt", f.path.display())))?;
            if fetched.null_count() > 0 {
                return Err(Refusal::Invalid(format!("{}: a null fetchedAt", f.path.display())));
            }
            fetched_at.extend(fetched.values().iter().map(|&t| t <= version));
        }
        if !fetched_at.contains(&true) {
            continue;
        }
        let present: Vec<&str> = wanted.iter().copied().filter(|c| f.index(c).is_some()).collect();
        let mut first = 0;
        for batch in f.batches(&present)? {
            let batch = batch.map_err(invalid)?;
            let at = |e: &str| Refusal::Invalid(format!("{}: {e}", f.path.display()));
            let fetched = batch.column_by_name("fetchedAt").and_then(|c| c.as_any().downcast_ref::<Int64Array>()).ok_or_else(|| at("fetchedAt"))?;
            let eligible: Vec<usize> = (0..batch.num_rows()).filter(|&r| fetched_at[first + r]).collect();
            first += batch.num_rows();
            if eligible.is_empty() {
                continue;
            }
            let columns: Vec<Option<Column>> = declared
                .iter()
                .map(|c| match batch.column_by_name(c) {
                    None => Ok(None),
                    Some(a) => Column::of(a.as_ref()).map(Some).ok_or_else(|| at(&format!("column {c} is not a cell type"))),
                })
                .collect::<Result<_, _>>()?;
            let tombstone = batch.column_by_name("tombstone").and_then(|c| c.as_any().downcast_ref::<BooleanArray>());
            let upstream = batch.column_by_name("upstream").and_then(|a| Column::of(a.as_ref()));
            for r in eligible {
                let cells: Vec<Cell> = columns.iter().map(|c| c.as_ref().map_or(Cell::Null, |c| c.cell(r))).collect();
                if cells.iter().any(|c| matches!(c, Cell::Real(x) if !x.is_finite())) {
                    return Err(at("a non-finite Double"));
                }
                let (at_time, Cell::Int(ev)) = (fetched.value(r), &cells[event]) else { return Err(at("event time is not an integer")) };
                if !(LO..=HI).contains(&(at_time as i128)) || !(LO..=HI).contains(&(*ev as i128)) {
                    return Err(at("fetchedAt or event time outside the range"));
                }
                let dead = tombstone.is_some_and(|t| t.is_valid(r) && t.value(r));
                let lineage = if s.deps.is_empty() || dead {
                    None
                } else {
                    let Some(Cell::Str(text)) = upstream.as_ref().map(|u| u.cell(r)) else { return Err(at("no lineage")) };
                    Some(lineage_of(&text, names, entity_columns)?)
                };
                out.push(Rev { fetched: at_time, tombstone: dead, cells, lineage });
            }
        }
    }
    Ok(out)
}

/// The timelines of every key with an eligible revision, for the registry `sources` stored under `roots`. `holdout`
/// is the boundary of a search, whose holdout check precedes everything else.
pub fn resolve(roots: &[PathBuf], sources: Vec<Source>, universe: &[String], version: i64, holdout: Option<i64>) -> Result<Resolved, Refusal> {
    if sources.iter().any(|s| s.declared().iter().any(|c| METADATA.contains(&c.as_str()))) {
        return Err(Refusal::Decl);
    }
    let exprs: Vec<Expr> = sources
        .iter()
        .map(|s| {
            let fields = s.times.iter().cloned().chain(["fetchedAt".to_string()]).collect();
            let deps = s.deps.iter().map(|d| d.name.clone()).collect();
            rule::check(&s.rule, &fields, &deps).ok_or(Refusal::Rule)
        })
        .collect::<Result<_, _>>()?;
    let footers: Vec<Vec<Footer>> = sources.iter().map(|s| files(roots, &s.name).iter().map(|p| Footer::read(p)).collect::<Result<_, _>>()).collect::<Result<_, _>>()?;
    if let Some(boundary) = holdout {
        let checks: Vec<(&[Footer], &str)> = sources.iter().zip(&footers).map(|(s, fs)| (fs.as_slice(), s.event.as_str())).collect();
        holdout_check(&checks, boundary)?;
    }
    let names: HashMap<String, usize> = sources.iter().enumerate().map(|(i, s)| (s.name.clone(), i)).collect();
    let entity_columns: Vec<usize> = sources.iter().map(|s| s.entity.len()).collect();
    let declared: Vec<Vec<String>> = sources.iter().map(Source::declared).collect();
    let revs: Vec<Vec<Rev>> = (0..sources.len())
        .map(|i| read_revisions(&footers[i], &sources[i], &declared[i], version, &names, &entity_columns))
        .collect::<Result<_, _>>()?;
    let files = footers.iter().map(|fs| fs.iter().map(|f| (f.path.file_name().unwrap().to_string_lossy().into_owned(), Sha256::digest(&f.bytes).into())).collect()).collect();
    let mut resolved = Resolved { sources, keys: vec![], revs, declared, files };
    let mut index: HashMap<(usize, Vec<Ident>, i64), usize> = HashMap::new();
    let mut done = vec![false; resolved.sources.len()];
    for i in 0..done.len() {
        build(&mut resolved, &exprs, &mut index, &mut done, i, universe, &names)?;
    }
    Ok(resolved)
}

fn build(r: &mut Resolved, exprs: &[Expr], index: &mut HashMap<(usize, Vec<Ident>, i64), usize>, done: &mut Vec<bool>, i: usize, universe: &[String], names: &HashMap<String, usize>) -> Result<(), Refusal> {
    if done[i] {
        return Ok(());
    }
    done[i] = true;
    for d in r.sources[i].deps.clone() {
        for u in &d.sources {
            if let Some(&u) = names.get(u.as_str()) {
                build(r, exprs, index, done, u, universe, names)?;
            }
        }
    }
    let s = r.sources[i].clone();
    let declared = r.declared[i].clone();
    let col = |name: &str| declared.iter().position(|d| d == name).unwrap();
    let entity_ix: Vec<usize> = s.entity.iter().map(|c| col(c)).collect();
    let event_ix = col(&s.event);
    let start = r.keys.len();
    let mut groups: HashMap<(Vec<Ident>, i64), usize> = HashMap::new();
    for (n, rev) in r.revs[i].iter().enumerate() {
        let Cell::Int(event) = rev.cells[event_ix] else { unreachable!() };
        let id: Vec<Ident> = entity_ix.iter().map(|&c| rev.cells[c].ident()).collect();
        let k = *groups.entry((id, event)).or_insert_with(|| {
            let entity: Vec<Cell> = entity_ix.iter().map(|&c| rev.cells[c].clone()).collect();
            let coin = match (s.evidence, s.entity.iter().position(|c| c == "coin")) {
                (false, Some(p)) => match &entity[p] {
                    Cell::Str(c) => universe.iter().position(|u| u.as_str() == &**c),
                    _ => None,
                },
                _ => None,
            };
            r.keys.push(Key { source: i, entity, event, coin, entries: vec![], revs: vec![] });
            r.keys.len() - 1
        });
        r.keys[k].revs.push(n);
    }
    for k in start..r.keys.len() {
        index.insert((i, r.keys[k].entity.iter().map(Cell::ident).collect(), r.keys[k].event), k);
        let mut revs = std::mem::take(&mut r.keys[k].revs);
        revs.sort_by_key(|&n| r.revs[i][n].fetched);
        if revs.windows(2).any(|w| r.revs[i][w[0]].fetched == r.revs[i][w[1]].fetched) {
            return Err(Refusal::Invalid(format!("{}: two revisions of a key share a fetchedAt", s.name)));
        }
        r.keys[k].entries = timeline(r, index, &exprs[i], i, &s, &declared, &revs);
        r.keys[k].revs = revs;
    }
    Ok(())
}

fn timeline(r: &Resolved, index: &HashMap<(usize, Vec<Ident>, i64), usize>, expr: &Expr, i: usize, s: &Source, declared: &[String], revs: &[usize]) -> Vec<Entry> {
    let mut entries: Vec<Entry> = vec![];
    let mut last: Option<&Rev> = None;
    let col = |name: &String| declared.iter().position(|d| d == name).unwrap();
    for &n in revs {
        let rev = &r.revs[i][n];
        if last.is_some_and(|l| l.tombstone == rev.tombstone && l.cells == rev.cells) {
            last = Some(rev);
            continue;
        }
        let known = if rev.tombstone { None } else { candidate(r, index, expr, s, declared, rev, last.is_some(), entries.last().map(|e| e.known)) };
        let usable = known.and_then(|known| decode(s, rev, &col).map(|slot| (known, slot)));
        match usable {
            Some((known, slot)) => entries.push(Entry { fetched: rev.fetched, known, retraction: false, slot, rev: n }),
            None => {
                if let Some(prev) = entries.last() {
                    entries.push(Entry { fetched: rev.fetched, known: rev.fetched.max(prev.known), retraction: true, slot: prev.slot, rev: n });
                }
            }
        }
        last = Some(rev);
    }
    entries
}

/// The slot of a revision whose slot and role payload decode (Some(None): a source without a slot), or None.
fn decode(s: &Source, rev: &Rev, col: &dyn Fn(&String) -> usize) -> Option<Option<i64>> {
    let slot = match &s.slot {
        None => None,
        Some(c) => match rev.cells[col(c)] {
            Cell::Int(v) => Some(v),
            _ => return None,
        },
    };
    let number = |c: &String| matches!(rev.cells[col(c)], Cell::Int(_) | Cell::Real(_));
    let ok = match &s.role {
        None => true,
        Some(Role::Settlement(c)) => number(c),
        Some(Role::Bars(c)) => c[..4].iter().all(number) && matches!(rev.cells[col(&c[4])], Cell::Int(_)),
    };
    ok.then_some(slot)
}

#[allow(clippy::too_many_arguments)]
fn candidate(r: &Resolved, index: &HashMap<(usize, Vec<Ident>, i64), usize>, expr: &Expr, s: &Source, declared: &[String], rev: &Rev, after_one: bool, prev: Option<i64>) -> Option<i64> {
    let lineage = rev.lineage.as_ref();
    let mut deps = BTreeMap::new();
    let mut raises: Vec<i128> = vec![];
    for d in &s.deps {
        let mut latest: Option<i64> = None;
        for (u, entity, event) in lineage?.get(&d.name)? {
            if !d.sources.contains(&r.sources[*u].name) {
                return None;
            }
            let key = &r.keys[*index.get(&(*u, entity.clone(), *event))?];
            let seen = key.entries.iter().filter(|e| e.fetched <= rev.fetched).map(|e| e.known).max()?;
            latest = Some(latest.map_or(seen, |l| l.max(seen)));
        }
        let latest = latest?;
        deps.insert(d.name.clone(), Json::Int(Some(latest as i128)));
        raises.push(latest as i128 + d.lag as i128);
    }
    let row: BTreeMap<String, Json> = s
        .times
        .iter()
        .map(|t| (t.clone(), rev.cells[declared.iter().position(|d| d == t).unwrap()].json()))
        .chain([("fetchedAt".to_string(), Json::Int(Some(rev.fetched as i128)))])
        .collect();
    let mut known = rule::evaluate(expr, &row, &deps).ok()?;
    if after_one {
        raises.push(rev.fetched as i128);
    }
    raises.extend(prev.map(|p| p as i128));
    if raises.iter().any(|x| !(LO..=HI).contains(x)) {
        return None;
    }
    for x in raises {
        known = known.max(x);
    }
    Some(known as i64)
}

impl Resolved {
    /// The cell of `column` in an entry's revision.
    pub fn cell(&self, key: &Key, entry: &Entry, column: &str) -> &Cell {
        let col = self.declared[key.source].iter().position(|d| d == column);
        col.map_or(&Cell::Null, |c| &self.revs[key.source][entry.rev].cells[c])
    }

    /// RULES.md §7's result: every key with an eligible revision, sorted by source name, entity and event time.
    pub fn listing(&self, queries: &[i64]) -> Value {
        let mut order: Vec<&Key> = self.keys.iter().collect();
        order.sort_by(|a, b| {
            let cmp = |x: &[Cell], y: &[Cell]| x.iter().zip(y).map(|(p, q)| p.cmp(q)).find(|o| o.is_ne()).unwrap_or(Ordering::Equal);
            self.sources[a.source].name.cmp(&self.sources[b.source].name).then_with(|| cmp(&a.entity, &b.entity)).then(a.event.cmp(&b.event))
        });
        let keys: Vec<Value> = order
            .into_iter()
            .map(|k| {
                let s = &self.sources[k.source];
                let declared = s.declared();
                let timeline: Vec<Value> = k
                    .entries
                    .iter()
                    .map(|e| {
                        let cells = (!e.retraction).then(|| declared.iter().map(|c| (c.clone(), self.cell(k, e, c).value())).collect::<serde_json::Map<_, _>>());
                        let role = (!e.retraction && s.role.is_some()).then(|| s.role_columns().iter().map(|c| self.cell(k, e, c).value()).collect::<Vec<_>>());
                        serde_json::json!([e.fetched, e.known, e.retraction, e.slot, cells, role])
                    })
                    .collect();
                let visible: Vec<Value> = queries.iter().map(|&q| k.sees(q).map_or(Value::Null, |e| Value::from(e.fetched))).collect();
                serde_json::json!({"source": s.name, "entity": k.entity.iter().map(Cell::value).collect::<Vec<_>>(), "event": k.event,
                                   "coin": k.coin, "timeline": timeline, "visible": visible})
            })
            .collect();
        serde_json::json!({"keys": keys})
    }

    /// The loader-level observations (RULES.md §7): per delivery of a key of U of a non-evidence source, sorted by
    /// source name, coin, event time and fetchedAt.
    pub fn observations(&self) -> Value {
        let bits = |c: &Cell| c.num().map_or(Value::Null, |x| Value::from(x.to_bits()));
        let mut out: Vec<(String, usize, i64, i64, Value)> = vec![];
        for k in &self.keys {
            let s = &self.sources[k.source];
            let Some(coin) = k.coin.filter(|_| !s.evidence) else { continue };
            for (n, e) in k.entries.iter().enumerate() {
                let values: Vec<Value> = s.values.iter().map(|v| if e.retraction { Value::Null } else { bits(self.cell(k, e, v)) }).collect();
                let role = if e.retraction {
                    Value::Null
                } else {
                    match &s.role {
                        None => Value::Null,
                        Some(Role::Settlement(c)) => serde_json::json!([bits(self.cell(k, e, c))]),
                        Some(Role::Bars(c)) => {
                            let mut v: Vec<Value> = c[..4].iter().map(|c| bits(self.cell(k, e, c))).collect();
                            v.push(self.cell(k, e, &c[4]).value());
                            Value::from(v)
                        }
                    }
                };
                let row = serde_json::json!([s.name, coin, k.event, e.fetched, e.known, e.retraction, e.slot, values, role, n + 1 == k.entries.len()]);
                out.push((s.name.clone(), coin, k.event, e.fetched, row));
            }
        }
        out.sort_by(|a, b| (&a.0, a.1, a.2, a.3).cmp(&(&b.0, b.1, b.2, b.3)));
        Value::from(out.into_iter().map(|o| o.4).collect::<Vec<_>>())
    }
}
