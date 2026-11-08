//! Market data for one run: the store resolved at a dataset version, plus venue files.
//!
//! Resolution is `resolve.rs` (kernel/RULES.md §6, bitemporal), the same as `ingest/store.py`'s: every delivered
//! revision of a key is a record at its own knownAt, a retraction a flagged record whose values are undefined (NaN);
//! the execution maps read each key's final revision. In search mode the holdout check of SOURCES.md §2 precedes all
//! other decoding (I8).

use crate::dsl::EVENT_INPUTS;
use crate::resolve::{self, Cell, Key, Refusal, Resolved, Role, Source};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
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
    pub retraction: bool,
    pub recorded: i64,
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
    pub retraction: bool,
    pub recorded: i64,
}

/// An hourly event count: items whose knownAt falls in (event - 1h, event], known at `known`. `event` is the slot
/// delivered; `recorded` and `key` (the key's eventTime) order observations sharing a knownAt.
#[derive(Clone, Copy, Debug)]
pub struct Event {
    pub coin: usize,
    pub event: i64,
    pub known: i64,
    pub count: f64,
    pub recorded: i64,
    pub key: i64,
    pub retraction: bool,
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

/// The order records reach a machine: by knownAt, then coin; within one, a key's entries as resolved, and event
/// observations by (recording time, eventTime) (SOURCES.md §4). Indices into `funding` and `bars`; event
/// observations with the event input's row in EVENT_INPUTS.
pub struct Delivery {
    pub funding: Vec<usize>,
    pub bars: Vec<usize>,
    pub events: Vec<(usize, Event)>,
}

impl Market {
    pub fn delivery(&self) -> Delivery {
        let mut funding: Vec<usize> = (0..self.funding.len()).collect();
        funding.sort_by_key(|&i| (self.funding[i].known, self.funding[i].coin, self.funding[i].event));
        let mut bars: Vec<usize> = (0..self.bars.len()).collect();
        bars.sort_by_key(|&i| (self.bars[i].known, self.bars[i].coin, self.bars[i].event));
        let mut events: Vec<(usize, Event)> = EVENT_INPUTS
            .iter()
            .enumerate()
            .filter_map(|(slot, (_, ds))| self.events.get(ds).map(|v| v.iter().map(move |&e| (slot, e))))
            .flatten()
            .collect();
        events.sort_by_key(|(slot, e)| (e.known, e.coin, *slot, e.recorded, e.key));
        Delivery { funding, bars, events }
    }
}

#[derive(Debug)]
pub enum LoadError {
    Holdout(String),
    Io(String),
}

impl std::fmt::Display for LoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let (LoadError::Holdout(m) | LoadError::Io(m)) = self;
        f.write_str(m)
    }
}

impl From<Refusal> for LoadError {
    fn from(r: Refusal) -> LoadError {
        match r {
            Refusal::Holdout(m) => LoadError::Holdout(m),
            other => LoadError::Io(other.to_string()),
        }
    }
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

/// The dataset as a source for the resolver: its rule is the policy's (`rule_expr` in `ingest/store.py`).
fn source(dataset: &str, policy: &Policy) -> Source {
    let field = |f: &str| json!({"field": f});
    let expr = match dataset {
        "funding" => {
            let r = field("reportedTime");
            json!({"max": [{"add": [{"floor": [r, {"ms": HOUR}]}, {"ms": policy.delta}]}, {"add": [r, {"ms": policy.settlement_latency}]}]})
        }
        _ => json!({"add": [field("eventTime"), {"ms": policy.delta}]}),
    };
    let names = |xs: &[&str]| xs.iter().map(|x| x.to_string()).collect::<Vec<_>>();
    let (times, values, slot, role) = match dataset {
        "funding" => (names(&["eventTime", "reportedTime"]), names(&["fundingRate", "premium"]), None, Some(Role::Settlement("fundingRate".into()))),
        "bars_4h" => (
            names(&["eventTime"]),
            names(&["open", "high", "low", "close", "volume", "trades"]),
            None,
            Some(Role::Bars(["open", "high", "low", "close", "trades"].map(String::from))),
        ),
        _ => (names(&["eventTime"]), names(&["count"]), Some("eventTime".to_string()), None),
    };
    Source {
        name: dataset.into(),
        rule: json!({"rule": 1, "expr": expr}).to_string(),
        times,
        values,
        entity: names(&["coin"]),
        event: "eventTime".into(),
        slot,
        role,
        evidence: false,
        deps: vec![],
    }
}

/// The keys of U of a dataset, sorted by (coin, event time).
fn keys<'a>(resolved: &'a Resolved, dataset: &str) -> Vec<&'a Key> {
    let mut keys: Vec<&Key> = resolved.keys.iter().filter(|k| k.coin.is_some() && resolved.sources[k.source].name == dataset).collect();
    keys.sort_by_key(|k| (k.coin, k.event));
    keys
}

/// Load the union of `stores` at `version`. `holdout` is the holdout start in search mode, None
/// in holdout mode.
pub fn load(stores: &[PathBuf], version: i64, venue: &Venue, policy: &Policy, holdout: Option<i64>) -> Result<Market, LoadError> {
    let mut datasets = vec!["funding", "bars_4h"];
    for ds in ["funding", "bars_4h"] {
        for s in stores {
            fs::read_dir(s.join(ds)).map_err(|e| io(format!("{}: {e}", s.join(ds).display())))?;
        }
    }
    datasets.extend(EVENT_INPUTS.iter().map(|e| e.1).filter(|ds| stores.iter().any(|s| s.join(ds).exists())));
    let resolved = resolve::resolve(stores, datasets.iter().map(|ds| source(ds, policy)).collect(), &venue.coins, version, holdout)?;
    let mut hasher = Sha256::new();
    for (name, digest) in resolved.files.iter().flatten() {
        hasher.update(name.as_bytes());
        hasher.update(digest);
    }
    let value = |k: &Key, e: &resolve::Entry, column: &str| if e.retraction { f64::NAN } else { resolved.cell(k, e, column).num().unwrap_or(f64::NAN) };
    let mut funding = vec![];
    let mut rate_at = HashMap::new();
    for k in keys(&resolved, "funding") {
        let coin = k.coin.unwrap();
        for e in &k.entries {
            funding.push(Funding { coin, event: k.event, known: e.known, rate: value(k, e, "fundingRate"), premium: value(k, e, "premium"), retraction: e.retraction, recorded: e.fetched });
        }
        if let Some(last) = k.entries.last().filter(|e| !e.retraction) {
            rate_at.insert((coin, k.event), value(k, last, "fundingRate"));
        }
    }
    let mut bars = vec![];
    let mut bar_at = HashMap::new();
    for k in keys(&resolved, "bars_4h") {
        let coin = k.coin.unwrap();
        for (n, e) in k.entries.iter().enumerate() {
            let trades = match resolved.cell(k, e, "trades") {
                Cell::Int(t) if !e.retraction => *t,
                _ => 0,
            };
            let (open_time, price) = (k.event - BAR, |c: &str| value(k, e, c));
            if n + 1 == k.entries.len() && !e.retraction {
                bar_at.insert((coin, open_time), bars.len());
            }
            bars.push(Bar {
                coin,
                open_time,
                event: k.event,
                known: e.known,
                open: price("open"),
                high: price("high"),
                low: price("low"),
                close: price("close"),
                volume: price("volume"),
                trades,
                retraction: e.retraction,
                recorded: e.fetched,
            });
        }
    }
    let mut events = HashMap::new();
    for (_, ds) in EVENT_INPUTS {
        if datasets.contains(&ds) {
            let list = keys(&resolved, ds)
                .into_iter()
                .flat_map(|k| k.entries.iter().map(move |e| Event { coin: k.coin.unwrap(), event: e.slot.unwrap_or(k.event), known: e.known, count: value(k, e, "count"), recorded: e.fetched, key: k.event, retraction: e.retraction }))
                .collect();
            events.insert(ds, list);
        }
    }
    let end = holdout.unwrap_or(policy.w_end).min(policy.w_end);
    let intervals = (0..venue.coins.len())
        .map(|c| {
            if !venue.rules[c].delisted {
                return (policy.w_start, end);
            }
            let last = bar_at.iter().filter(|((coin, _), &i)| *coin == c && bars[i].trades > 0).map(|(_, &i)| bars[i].event).max();
            (policy.w_start, last.unwrap_or(policy.w_start).min(end))
        })
        .collect();
    let mut bar_times = vec![vec![]; venue.coins.len()];
    for &(c, t) in bar_at.keys() {
        bar_times[c].push(t);
    }
    for t in bar_times.iter_mut() {
        t.sort();
    }
    let data_hash = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    Ok(Market { funding, bars, bar_at, rate_at, bar_times, intervals, events, data_hash })
}
