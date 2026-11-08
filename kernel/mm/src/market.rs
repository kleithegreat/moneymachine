//! Market data for one run: the store resolved at a dataset version into observations, plus venue files.
//!
//! Resolution is `resolve.rs` (kernel/RULES.md §6, bitemporal), the same as `ingest/store.py`'s; `load` decodes every
//! entry of every key's timeline into an observation of its registry declaration, as Lean's `resolveAll`. In search mode
//! the holdout check of SOURCES.md §2 precedes all other decoding (I8).

use crate::admission::Roles;
use crate::machine::{Obs, RolePayload};
use crate::resolve::{self, Cell, Refusal, Role, Source};
use crate::source::Declaration;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
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

/// A store resolved for one run under a registry: what Lean's `Ctx.make` takes.
#[derive(Debug)]
pub struct Market<'r> {
    pub reg: &'r [Declaration],
    /// Every entry of every key's timeline of the bound declarations.
    pub obs: Vec<Obs>,
    /// Per registry declaration, whether the store binds a dataset to it.
    pub bound: Vec<bool>,
    pub roles: Roles,
    /// Listed interval [start, end) per coin, cut at the search end. A delisted coin's ends at
    /// the close of its last traded bar; the venue keeps writing zero funding rows after it.
    pub intervals: Vec<(i64, i64)>,
    pub data_hash: String,
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

/// The stage 6 store's datasets and the declarations they bind, until the run manifest binds them (port plan, slice 6).
const BINDINGS: [(&str, &str); 4] =
    [("funding", "hl-funding"), ("bars_4h", "hl-bars-4h"), ("events_forum", "forum-events"), ("events_governance", "governance-events")];

/// A role provider's payload from a revision's cells (Lean's `rolePayload`): none unless its columns decode.
fn role_payload<'a>(d: &Declaration, cell: impl Fn(&str) -> &'a Cell) -> Option<RolePayload> {
    let (role, cols) = d.roles.iter().next()?;
    let num = |c: &str| cell(&cols[c]).num();
    if role == "settlement" {
        return num("rate").map(RolePayload::Rate);
    }
    let Cell::Int(trades) = cell(&cols["trades"]) else { return None };
    Some(RolePayload::Bar { open: num("open")?, high: num("high")?, low: num("low")?, close: num("close")?, trades: *trades })
}

/// Load the union of `stores` at `version` as observations of the registry `reg`. A declaration providing a role must
/// be bound in every store, any other is bound when some store holds its dataset. `holdout` is the holdout start in
/// search mode, None in holdout mode.
pub fn load<'r>(stores: &[PathBuf], version: i64, reg: &'r [Declaration], venue: &Venue, policy: &Policy, holdout: Option<i64>) -> Result<Market<'r>, LoadError> {
    let mut bindings = vec![];
    for (dataset, name) in BINDINGS {
        let s = reg.iter().position(|d| d.name == name).ok_or_else(|| io(format!("the registry has no {name}")))?;
        if !reg[s].roles.is_empty() {
            for st in stores {
                fs::read_dir(st.join(dataset)).map_err(|e| io(format!("{}: {e}", st.join(dataset).display())))?;
            }
        } else if !stores.iter().any(|st| st.join(dataset).exists()) {
            continue;
        }
        bindings.push((dataset, s));
    }
    let provider = |role: &str| bindings.iter().map(|b| b.1).find(|&s| reg[s].roles.contains_key(role)).ok_or_else(|| io(format!("no {role} provider")));
    let roles = Roles { bars: provider("bars")?, settlement: provider("settlement")? };
    let resolved = resolve::resolve(stores, bindings.iter().map(|(ds, _)| source(ds, policy)).collect(), &venue.coins, version, holdout)?;
    let mut hasher = Sha256::new();
    for (name, digest) in resolved.files.iter().flatten() {
        hasher.update(name.as_bytes());
        hasher.update(digest);
    }
    let mut obs = vec![];
    for k in &resolved.keys {
        let Some(coin) = k.coin else { continue };
        let (source, d) = (bindings[k.source].1, &reg[bindings[k.source].1]);
        for (n, e) in k.entries.iter().enumerate() {
            let live = !e.retraction;
            obs.push(Obs {
                source,
                coin,
                key: k.event,
                slot: e.slot,
                known: e.known,
                vals: d.fields.values().map(|f| resolved.cell(k, e, &f.column).num().filter(|_| live)).collect(),
                role: role_payload(d, |c| resolved.cell(k, e, c)).filter(|_| live),
                last: n + 1 == k.entries.len(),
                retraction: e.retraction,
                recorded: e.fetched,
            });
        }
    }
    let end = holdout.unwrap_or(policy.w_end).min(policy.w_end);
    let traded = |c: usize| {
        let bars = obs.iter().filter(|o| o.source == roles.bars && o.coin == c && o.last);
        bars.filter(|o| matches!(o.role, Some(RolePayload::Bar { trades, .. }) if trades > 0)).map(|o| o.key).max()
    };
    let intervals = (0..venue.coins.len())
        .map(|c| if venue.rules[c].delisted { (policy.w_start, traded(c).unwrap_or(policy.w_start).min(end)) } else { (policy.w_start, end) })
        .collect();
    let bound = (0..reg.len()).map(|s| bindings.iter().any(|b| b.1 == s)).collect();
    let data_hash = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    Ok(Market { reg, obs, bound, roles, intervals, data_hash })
}
