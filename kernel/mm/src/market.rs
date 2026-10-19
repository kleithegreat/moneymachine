//! Market data for one run: the store resolved at a dataset version, plus venue files.
//!
//! Resolution matches `ingest/store.py`: per (coin, eventTime) key, the revision with the
//! largest fetchedAt <= version. In search mode any row with eventTime >= holdout start
//! aborts the load (I8), whichever file it came from.

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

pub const EVENT_DATASETS: [&str; 2] = ["events_forum", "events_governance"];

#[derive(Debug)]
pub struct CoinRules {
    pub sz_decimals: i32,
    pub min_tier_leverage: f64,
    pub delisted: bool,
    /// Cost in bps from the reference price, ex fee, for [buy, sell] x [<= $1k, <= $10k].
    pub cost_bps: [[f64; 2]; 2],
}

#[derive(Debug)]
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
    Ok(Policy { delta: get("delta_ms")?, w_start: get("w_start")?, holdout_start: get("holdout_start")?, w_end: get("w_end")? })
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

type Row = HashMap<String, Field>;

fn read_rows(dir: &Path, version: i64, hasher: &mut Sha256) -> Result<Vec<Row>, LoadError> {
    let mut files: Vec<(i64, PathBuf)> = fs::read_dir(dir)
        .map_err(|e| io(format!("{}: {e}", dir.display())))?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "parquet"))
        .filter_map(|p| Some((p.file_stem()?.to_str()?.parse::<i64>().ok()?, p)))
        .filter(|(f, _)| *f <= version)
        .collect();
    files.sort();
    let mut rows = vec![];
    for (_, p) in files {
        let bytes = fs::read(&p).map_err(io)?;
        hasher.update(p.file_name().unwrap().to_string_lossy().as_bytes());
        hasher.update(Sha256::digest(&bytes));
        let reader = SerializedFileReader::new(File::open(&p).map_err(io)?).map_err(io)?;
        for row in reader.get_row_iter(None).map_err(io)? {
            let row = row.map_err(io)?;
            rows.push(row.get_column_iter().map(|(k, v)| (k.clone(), v.clone())).collect());
        }
    }
    Ok(rows)
}

fn long(r: &Row, k: &str) -> Result<i64, LoadError> {
    match r.get(k) {
        Some(Field::Long(x)) => Ok(*x),
        Some(Field::Int(x)) => Ok(*x as i64),
        other => Err(io(format!("column {k}: {other:?}"))),
    }
}

fn double(r: &Row, k: &str) -> Result<f64, LoadError> {
    match r.get(k) {
        Some(Field::Double(x)) => Ok(*x),
        other => Err(io(format!("column {k}: {other:?}"))),
    }
}

fn text<'a>(r: &'a Row, k: &str) -> Result<&'a str, LoadError> {
    match r.get(k) {
        Some(Field::Str(s)) => Ok(s),
        other => Err(io(format!("column {k}: {other:?}"))),
    }
}

/// Latest revision per key, in deterministic (coin, eventTime) order.
fn resolve(rows: Vec<Row>, coin_ix: &HashMap<&str, usize>, holdout: Option<i64>) -> Result<Vec<Row>, LoadError> {
    let mut best: HashMap<(usize, i64), (i64, Row)> = HashMap::new();
    for r in rows {
        let event = long(&r, "eventTime")?;
        if let Some(h) = holdout {
            if event >= h {
                return Err(LoadError::Holdout(format!("row with eventTime {event} >= holdout start {h}")));
            }
        }
        let Some(&c) = coin_ix.get(text(&r, "coin")?) else { continue };
        let fetched = long(&r, "fetchedAt")?;
        match best.get(&(c, event)) {
            Some((f, _)) if *f >= fetched => {}
            _ => {
                best.insert((c, event), (fetched, r));
            }
        }
    }
    let mut out: Vec<_> = best.into_iter().collect();
    out.sort_by_key(|(k, _)| *k);
    Ok(out.into_iter().map(|(_, (_, r))| r).collect())
}

/// Load the union of `stores` at `version`. `holdout` is the holdout start in search mode, None
/// in holdout mode.
pub fn load(stores: &[PathBuf], version: i64, venue: &Venue, policy: &Policy, holdout: Option<i64>) -> Result<Market, LoadError> {
    let coin_ix: HashMap<&str, usize> = venue.coins.iter().enumerate().map(|(i, c)| (c.as_str(), i)).collect();
    let mut hasher = Sha256::new();
    let mut rows = |dataset: &str| -> Result<Vec<Row>, LoadError> {
        let mut all = vec![];
        for s in stores {
            if s.join(dataset).exists() || !dataset.starts_with("events_") {
                all.extend(read_rows(&s.join(dataset), version, &mut hasher)?);
            }
        }
        Ok(all)
    };
    let f_rows = resolve(rows("funding")?, &coin_ix, holdout)?;
    let b_rows = resolve(rows("bars_4h")?, &coin_ix, holdout)?;
    let mut events = HashMap::new();
    for ds in EVENT_DATASETS {
        if !stores.iter().any(|s| s.join(ds).exists()) {
            continue;
        }
        let mut v = vec![];
        for r in resolve(rows(ds)?, &coin_ix, holdout)? {
            v.push(Event { coin: coin_ix[text(&r, "coin")?], event: long(&r, "eventTime")?, known: long(&r, "knownAt")?, count: double(&r, "count")? });
        }
        events.insert(ds, v);
    }
    let mut funding = Vec::with_capacity(f_rows.len());
    for r in &f_rows {
        funding.push(Funding {
            coin: coin_ix[text(r, "coin")?],
            event: long(r, "eventTime")?,
            known: long(r, "knownAt")?,
            rate: double(r, "fundingRate")?,
            premium: double(r, "premium")?,
        });
    }
    let mut bars = Vec::with_capacity(b_rows.len());
    for r in &b_rows {
        bars.push(Bar {
            coin: coin_ix[text(r, "coin")?],
            open_time: long(r, "openTime")?,
            event: long(r, "eventTime")?,
            known: long(r, "knownAt")?,
            open: double(r, "open")?,
            high: double(r, "high")?,
            low: double(r, "low")?,
            close: double(r, "close")?,
            volume: double(r, "volume")?,
            trades: long(r, "trades")?,
        });
    }
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
