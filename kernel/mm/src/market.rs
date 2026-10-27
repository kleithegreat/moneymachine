//! Market data for one run: the store resolved at a dataset version, plus venue files.
//!
//! Resolution matches `ingest/store.py`: per (coin, eventTime) key, the revision with the
//! largest fetchedAt <= version, known at the time `known` computes from its observed fields (a
//! stored knownAt is never read). In search mode any row with eventTime >= holdout start aborts
//! the load (I8), whichever file it came from.

use crate::dsl::EVENT_INPUTS;
use parquet::file::reader::{FileReader, SerializedFileReader};
use parquet::record::Field;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs::{self, File};
use std::path::{Path, PathBuf};

pub const HOUR: i64 = 3_600_000;
pub const BAR: i64 = 4 * HOUR;

#[derive(Debug)]
pub struct Policy {
    pub delta: i64,
    pub settlement_latency: i64,
    pub w_start: i64,
    pub holdout_start: i64,
    pub w_end: i64,
}

#[derive(Clone, Copy, Debug)]
pub struct Funding {
    pub coin: usize,
    pub event: i64,
    pub known: i64,
    pub rate: f64,
    pub premium: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct Bar {
    pub coin: usize,
    pub open_time: i64,
    pub event: i64,
    pub known: i64,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub trades: i64,
}

/// An hourly event count: items whose knownAt falls in (event - 1h, event], known at `known`.
#[derive(Clone, Copy, Debug)]
pub struct Event {
    pub coin: usize,
    pub event: i64,
    pub known: i64,
    pub count: f64,
}

#[derive(Clone, Debug)]
pub struct CoinRules {
    pub sz_decimals: i32,
    pub min_tier_leverage: f64,
    pub delisted: bool,
    /// Cost in bps from the reference price, ex fee, for [buy, sell] x [<= $1k, <= $10k].
    pub cost_bps: [[f64; 2]; 2],
    /// [min, max] of (high - low) / open over the coin's 4h bars in the cost model's calibration span.
    pub calibration_range: Option<(f64, f64)>,
}

#[derive(Clone, Debug)]
pub struct Venue {
    pub taker_fee: f64,
    pub min_notional: f64,
    pub coins: Vec<String>,
    pub rules: Vec<CoinRules>,
    pub rules_hash: String,
    pub execution_hash: String,
}

#[derive(Debug)]
pub struct Market {
    pub funding: Vec<Funding>,
    pub bars: Vec<Bar>,
    pub bar_at: HashMap<(usize, i64), usize>,
    pub rate_at: HashMap<(usize, i64), f64>,
    /// Sorted bar openTimes per coin.
    pub bar_times: Vec<Vec<i64>>,
    /// Listed interval [start, end) per coin, cut at the search end. A delisted coin's ends at
    /// the close of its last traded bar; the venue keeps writing zero funding rows after it.
    pub intervals: Vec<(i64, i64)>,
    /// Event datasets present in the store, by name; an absent name means the input is unavailable.
    pub events: HashMap<&'static str, Vec<Event>>,
    pub data_hash: String,
}

#[derive(Debug)]
pub enum LoadError {
    Holdout(String),
    Io(String),
}

fn io<E: std::fmt::Display>(e: E) -> LoadError {
    LoadError::Io(e.to_string())
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes).iter().map(|b| format!("{b:02x}")).collect()
}

fn json(path: &Path) -> Result<(Value, String), LoadError> {
    let bytes = fs::read(path).map_err(|e| io(format!("{}: {e}", path.display())))?;
    Ok((serde_json::from_slice(&bytes).map_err(io)?, sha256_hex(&bytes)))
}

pub fn policy(path: &Path) -> Result<Policy, LoadError> {
    let (v, _) = json(path)?;
    let get = |k: &str| v[k].as_i64().ok_or_else(|| io(format!("policy.json: missing {k}")));
    Ok(Policy { delta: get("delta_ms")?, settlement_latency: get("settlement_latency_ms")?, w_start: get("w_start")?, holdout_start: get("holdout_start")?, w_end: get("w_end")? })
}

pub fn venue(dir: &Path) -> Result<Venue, LoadError> {
    let (rules, rules_hash) = json(&dir.join("rules.json"))?;
    let (exec, execution_hash) = json(&dir.join("execution.json"))?;
    let num = |v: &Value, what: &str| v.as_f64().ok_or_else(|| io(format!("venue: bad {what}")));
    let coins_v = rules["coins"].as_object().ok_or_else(|| io("rules.json: no coins"))?;
    let mut coins = vec![];
    let mut per = vec![];
    for (c, r) in coins_v {
        let tiers = r["marginTiers"].as_array().ok_or_else(|| io("rules.json: no marginTiers"))?;
        let min_lev = tiers.iter().filter_map(|t| t["maxLeverage"].as_f64()).fold(f64::INFINITY, f64::min);
        let cost = &exec["cost_bps_ex_fee"][c];
        let cell = |side: &str, size: &str| num(&cost[side][size], &format!("cost {c} {side} {size}"));
        per.push(CoinRules {
            sz_decimals: r["szDecimals"].as_i64().ok_or_else(|| io("rules.json: szDecimals"))? as i32,
            min_tier_leverage: min_lev,
            delisted: r["delisted"].as_bool().unwrap_or(false),
            cost_bps: [[cell("buy", "1000")?, cell("buy", "10000")?], [cell("sell", "1000")?, cell("sell", "10000")?]],
            calibration_range: exec["calibration_relative_range"][c].as_array().and_then(|r| Some((r.first()?.as_f64()?, r.get(1)?.as_f64()?))),
        });
        coins.push(c.clone());
    }
    Ok(Venue {
        taker_fee: num(&rules["rules"]["taker_fee"]["value"], "taker_fee")?,
        min_notional: num(&rules["rules"]["min_order_notional_usd"]["value"], "min notional")?,
        coins,
        rules: per,
        rules_hash,
        execution_hash,
    })
}

impl Venue {
    /// The same venue with every cost-table entry multiplied by `k` (fees unchanged).
    pub fn costs_scaled(&self, k: f64) -> Venue {
        let mut v = self.clone();
        for r in &mut v.rules {
            r.cost_bps = r.cost_bps.map(|side| side.map(|x| x * k));
        }
        v
    }
}

/// One stored value: a parquet `Field` kept in 16 bytes (strings interned per dataset), or `Absent` where the
/// row's file has no such column. Equality is `Field`'s: variants differ (`Int` is not `Long`) and NaN is unequal.
#[derive(Clone, Debug)]
enum Cell {
    Absent,
    Null,
    Long(i64),
    Int(i32),
    Double(f64),
    Bool(bool),
    Str(u32),
    Other(Box<Field>),
}

/// Columns that are not observed values: the store's metadata, a legacy stored knownAt, and the tombstone flag.
const NOT_VALUES: [&str; 5] = ["fetchedAt", "source", "hash", "knownAt", "tombstone"];
/// Of those, the ones never read: not stored at all (the files are hashed whole).
const UNREAD: [&str; 3] = ["source", "hash", "knownAt"];

/// A dataset's rows, in read order (stores, then files by version, then rows), as columns.
#[derive(Default)]
struct Table {
    names: Vec<String>,
    cols: Vec<Vec<Cell>>,
    strings: Vec<String>,
    interned: HashMap<String, u32>,
    rows: usize,
}

impl Table {
    fn read(&mut self, dir: &Path, version: i64, hasher: &mut Sha256) -> Result<(), LoadError> {
        let mut files: Vec<(i64, PathBuf)> = fs::read_dir(dir)
            .map_err(|e| io(format!("{}: {e}", dir.display())))?
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "parquet"))
            .filter_map(|p| Some((p.file_stem()?.to_str()?.parse::<i64>().ok()?, p)))
            .filter(|(f, _)| *f <= version)
            .collect();
        files.sort();
        for (_, p) in files {
            let bytes = fs::read(&p).map_err(io)?;
            hasher.update(p.file_name().unwrap().to_string_lossy().as_bytes());
            hasher.update(Sha256::digest(&bytes));
            let reader = SerializedFileReader::new(File::open(&p).map_err(io)?).map_err(io)?;
            for row in reader.get_row_iter(None).map_err(io)? {
                for (k, v) in row.map_err(io)?.get_column_iter() {
                    if UNREAD.contains(&k.as_str()) {
                        continue;
                    }
                    let c = match self.names.iter().position(|n| n == k) {
                        Some(c) => c,
                        None => {
                            self.names.push(k.clone());
                            self.cols.push(vec![Cell::Absent; self.rows]);
                            self.cols.len() - 1
                        }
                    };
                    let cell = self.cell(v);
                    self.cols[c].resize(self.rows, Cell::Absent);
                    self.cols[c].push(cell);
                }
                self.rows += 1;
            }
        }
        for col in self.cols.iter_mut() {
            col.resize(self.rows, Cell::Absent);
        }
        Ok(())
    }

    fn cell(&mut self, v: &Field) -> Cell {
        match v {
            Field::Null => Cell::Null,
            Field::Long(x) => Cell::Long(*x),
            Field::Int(x) => Cell::Int(*x),
            Field::Double(x) => Cell::Double(*x),
            Field::Bool(x) => Cell::Bool(*x),
            Field::Str(x) => Cell::Str(match self.interned.get(x) {
                Some(&i) => i,
                None => {
                    self.strings.push(x.clone());
                    self.interned.insert(x.clone(), self.strings.len() as u32 - 1);
                    self.strings.len() as u32 - 1
                }
            }),
            other => Cell::Other(Box::new(other.clone())),
        }
    }

    fn get(&self, row: usize, k: &str) -> &Cell {
        self.names.iter().position(|n| n == k).map_or(&Cell::Absent, |c| &self.cols[c][row])
    }

    /// The cell as the `Field` a row map would have held (None where absent), for comparison and messages.
    fn field(&self, row: usize, k: &str) -> Option<Field> {
        self.value(self.get(row, k))
    }

    fn value(&self, cell: &Cell) -> Option<Field> {
        Some(match cell {
            Cell::Absent => return None,
            Cell::Null => Field::Null,
            Cell::Long(x) => Field::Long(*x),
            Cell::Int(x) => Field::Int(*x),
            Cell::Double(x) => Field::Double(*x),
            Cell::Bool(x) => Field::Bool(*x),
            Cell::Str(i) => Field::Str(self.strings[*i as usize].clone()),
            Cell::Other(f) => (**f).clone(),
        })
    }

    fn long(&self, row: usize, k: &str) -> Result<i64, LoadError> {
        match self.get(row, k) {
            Cell::Long(x) => Ok(*x),
            Cell::Int(x) => Ok(*x as i64),
            _ => Err(io(format!("column {k}: {:?}", self.field(row, k).as_ref()))),
        }
    }

    fn double(&self, row: usize, k: &str) -> Result<f64, LoadError> {
        match self.get(row, k) {
            Cell::Double(x) => Ok(*x),
            _ => Err(io(format!("column {k}: {:?}", self.field(row, k).as_ref()))),
        }
    }

    fn text(&self, row: usize, k: &str) -> Result<&str, LoadError> {
        match self.get(row, k) {
            Cell::Str(i) => Ok(&self.strings[*i as usize]),
            _ => Err(io(format!("column {k}: {:?}", self.field(row, k).as_ref()))),
        }
    }

    /// Whether two rows' observed values are equal, a missing column and a null alike.
    fn same_values(&self, a: usize, b: usize) -> bool {
        let value = |r: usize, c: usize| self.value(&self.cols[c][r]).filter(|v| !matches!(v, Field::Null));
        (0..self.names.len()).filter(|&c| !NOT_VALUES.contains(&self.names[c].as_str())).all(|c| value(a, c) == value(b, c))
    }
}

/// A key's latest revision (a row of its table), and whether its observed values differ from the key's first
/// revision's.
struct Revision {
    row: usize,
    correction: bool,
}

/// A revision's knownAt from its observed fields, by the policy's rule (`known_at` in `ingest/store.py`); a
/// correction is known no earlier than it was fetched.
fn known(dataset: &str, t: &Table, r: &Revision, policy: &Policy) -> Result<i64, LoadError> {
    let rule = match dataset {
        "funding" => {
            let reported = t.long(r.row, "reportedTime")?;
            (reported.div_euclid(HOUR) * HOUR + policy.delta).max(reported + policy.settlement_latency)
        }
        _ => t.long(r.row, "eventTime")? + policy.delta,
    };
    Ok(if r.correction { rule.max(t.long(r.row, "fetchedAt")?) } else { rule })
}

/// Per key, the latest revision unless it is a tombstone, in (coin, eventTime) order (`as_of` in
/// `ingest/store.py`). Rows are checked in read order; a key's first and latest revisions are its earliest-read
/// rows with the smallest and the largest fetchedAt, found by a stable sort on the key.
fn resolve(t: &Table, coin_ix: &HashMap<&str, usize>, holdout: Option<i64>) -> Result<Vec<Revision>, LoadError> {
    let mut keyed = Vec::with_capacity(t.rows);
    for row in 0..t.rows {
        let event = t.long(row, "eventTime")?;
        if let Some(h) = holdout {
            if event >= h {
                return Err(LoadError::Holdout(format!("row with eventTime {event} >= holdout start {h}")));
            }
        }
        let Some(&c) = coin_ix.get(t.text(row, "coin")?) else { continue };
        keyed.push((c, event, t.long(row, "fetchedAt")?, row));
    }
    keyed.sort_by_key(|&(c, e, _, _)| (c, e));
    let mut out = vec![];
    for group in keyed.chunk_by(|a, b| (a.0, a.1) == (b.0, b.1)) {
        let (mut first, mut best) = (group[0], group[0]);
        for &g in &group[1..] {
            if g.2 < first.2 {
                first = g;
            }
            if g.2 > best.2 {
                best = g;
            }
        }
        if !matches!(t.get(best.3, "tombstone"), Cell::Bool(true)) {
            out.push(Revision { row: best.3, correction: !t.same_values(first.3, best.3) });
        }
    }
    Ok(out)
}

/// Load the union of `stores` at `version`. `holdout` is the holdout start in search mode, None
/// in holdout mode.
pub fn load(stores: &[PathBuf], version: i64, venue: &Venue, policy: &Policy, holdout: Option<i64>) -> Result<Market, LoadError> {
    let coin_ix: HashMap<&str, usize> = venue.coins.iter().enumerate().map(|(i, c)| (c.as_str(), i)).collect();
    let mut hasher = Sha256::new();
    let mut table = |dataset: &str, required: bool| -> Result<Table, LoadError> {
        let mut t = Table::default();
        for s in stores {
            if required || s.join(dataset).exists() {
                t.read(&s.join(dataset), version, &mut hasher)?;
            }
        }
        Ok(t)
    };
    let f_table = table("funding", true)?;
    let f_rows = resolve(&f_table, &coin_ix, holdout)?;
    let b_table = table("bars_4h", true)?;
    let b_rows = resolve(&b_table, &coin_ix, holdout)?;
    let mut events = HashMap::new();
    for (_, ds) in EVENT_INPUTS {
        if !stores.iter().any(|s| s.join(ds).exists()) {
            continue;
        }
        let t = table(ds, false)?;
        let mut v = vec![];
        for r in resolve(&t, &coin_ix, holdout)? {
            v.push(Event { coin: coin_ix[t.text(r.row, "coin")?], event: t.long(r.row, "eventTime")?, known: known(ds, &t, &r, policy)?,
                           count: t.double(r.row, "count")? });
        }
        events.insert(ds, v);
    }
    let mut funding = Vec::with_capacity(f_rows.len());
    for r in &f_rows {
        let t = &f_table;
        funding.push(Funding {
            coin: coin_ix[t.text(r.row, "coin")?],
            event: t.long(r.row, "eventTime")?,
            known: known("funding", t, r, policy)?,
            rate: t.double(r.row, "fundingRate")?,
            premium: t.double(r.row, "premium")?,
        });
    }
    drop(f_table);
    let mut bars = Vec::with_capacity(b_rows.len());
    for rev in &b_rows {
        let (t, r) = (&b_table, rev.row);
        bars.push(Bar {
            coin: coin_ix[t.text(r, "coin")?],
            open_time: t.long(r, "openTime")?,
            event: t.long(r, "eventTime")?,
            known: known("bars_4h", t, rev, policy)?,
            open: t.double(r, "open")?,
            high: t.double(r, "high")?,
            low: t.double(r, "low")?,
            close: t.double(r, "close")?,
            volume: t.double(r, "volume")?,
            trades: t.long(r, "trades")?,
        });
    }
    drop(b_table);
    let end = holdout.unwrap_or(policy.w_end).min(policy.w_end);
    let intervals = (0..venue.coins.len())
        .map(|c| {
            if !venue.rules[c].delisted {
                return (policy.w_start, end);
            }
            let last = bars.iter().filter(|b| b.coin == c && b.trades > 0).map(|b| b.event).max();
            (policy.w_start, last.unwrap_or(policy.w_start).min(end))
        })
        .collect();
    let bar_at = bars.iter().enumerate().map(|(i, b)| ((b.coin, b.open_time), i)).collect();
    let rate_at = funding.iter().map(|f| ((f.coin, f.event), f.rate)).collect();
    let mut bar_times = vec![vec![]; venue.coins.len()];
    for b in &bars {
        bar_times[b.coin].push(b.open_time);
    }
    for t in bar_times.iter_mut() {
        t.sort();
    }
    let data_hash = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    Ok(Market { funding, bars, bar_at, rate_at, bar_times, intervals, events, data_hash })
}
