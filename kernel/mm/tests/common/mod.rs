//! The committed registry, which every test program is checked against, and observations of its declarations as
//! `market::load` decodes a key's only revision.

#![allow(dead_code)]

use mm::admission::Roles;
use mm::dsl::Input;
use mm::machine::{Obs, RolePayload};
use mm::market::Market;
use mm::source::Declaration;
use std::path::Path;
use std::sync::OnceLock;

pub fn registry() -> &'static [Declaration] {
    static REG: OnceLock<Vec<Declaration>> = OnceLock::new();
    REG.get_or_init(|| mm::source::registry(Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))).unwrap())
}

pub fn inputs() -> Vec<Input> {
    mm::source::inputs(registry())
}

pub fn roles() -> Roles {
    let provider = |role: &str| registry().iter().position(|d| d.roles.contains_key(role)).unwrap();
    Roles { bars: provider("bars"), settlement: provider("settlement") }
}

/// An observation of the declaration with input `named[0].0`, its fields by input name (the others undefined).
fn obs(named: &[(&str, f64)], coin: usize, key: i64, slot: Option<i64>, known: i64, role: Option<RolePayload>) -> Obs {
    let source = registry().iter().position(|d| d.fields.contains_key(named[0].0)).unwrap();
    let vals = registry()[source].fields.keys().map(|k| named.iter().find(|n| n.0 == k).map(|n| n.1)).collect();
    Obs { source, coin, key, slot, known, vals, role, last: true, retraction: false, recorded: known }
}

pub fn funding(coin: usize, hour: i64, known: i64, rate: f64, premium: f64) -> Obs {
    obs(&[("funding", rate), ("premium", premium)], coin, hour, None, known, Some(RolePayload::Rate(rate)))
}

/// The bar ending at `event`.
pub fn bar(coin: usize, event: i64, known: i64, [open, high, low, close]: [f64; 4], volume: f64, trades: i64) -> Obs {
    let named = [("open", open), ("high", high), ("low", low), ("close", close), ("volume", volume)];
    obs(&named, coin, event, None, known, Some(RolePayload::Bar { open, high, low, close, trades }))
}

/// An event input's count for the hour `hour`.
pub fn count(input: &str, coin: usize, hour: i64, known: i64, n: f64) -> Obs {
    obs(&[(input, n)], coin, hour, Some(hour), known, None)
}

/// A market of these observations, binding the role providers and every declaration observed.
pub fn market(obs: Vec<Obs>, intervals: Vec<(i64, i64)>) -> Market {
    let roles = roles();
    let bound = (0..registry().len()).map(|s| s == roles.bars || s == roles.settlement || obs.iter().any(|o| o.source == s)).collect();
    Market { obs, bound, roles, intervals, data_hash: String::new() }
}

pub mod store;
