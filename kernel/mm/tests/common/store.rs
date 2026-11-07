//! Parquet stores of the layout `market::load` reads, for tests that run the kernel from files.

#![allow(dead_code)]

use arrow_array::{ArrayRef, BooleanArray, Float64Array, Int64Array, RecordBatch, StringArray};
use arrow_schema::{DataType, Field, Schema};
use mm::market::{CoinRules, Policy, Venue, BAR, HOUR};
use parquet::arrow::ArrowWriter;
use std::fs::File;
use std::path::Path;
use std::sync::Arc;

pub const DELTA: i64 = 120_000;
pub const COINS: [&str; 2] = ["A", "B"];

pub enum Col {
    I(Vec<Option<i64>>),
    F(Vec<Option<f64>>),
    S(Vec<Option<String>>),
    B(Vec<Option<bool>>),
}

/// One Parquet file of the given columns.
pub fn write(path: &Path, columns: Vec<(&str, Col)>) {
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    let (fields, arrays): (Vec<Field>, Vec<ArrayRef>) = columns
        .into_iter()
        .map(|(name, col)| match col {
            Col::I(v) => (Field::new(name, DataType::Int64, true), Arc::new(Int64Array::from(v)) as ArrayRef),
            Col::F(v) => (Field::new(name, DataType::Float64, true), Arc::new(Float64Array::from(v)) as ArrayRef),
            Col::S(v) => (Field::new(name, DataType::Utf8, true), Arc::new(StringArray::from(v)) as ArrayRef),
            Col::B(v) => (Field::new(name, DataType::Boolean, true), Arc::new(BooleanArray::from(v)) as ArrayRef),
        })
        .unzip();
    let schema = Arc::new(Schema::new(fields));
    let mut writer = ArrowWriter::try_new(File::create(path).unwrap(), schema.clone(), None).unwrap();
    writer.write(&RecordBatch::try_new(schema, arrays).unwrap()).unwrap();
    writer.close().unwrap();
}

/// A deterministic value in [0, 1) for (a, b, c).
pub fn noise(a: u64, b: u64, c: u64) -> f64 {
    let mut x = a.wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ b.wrapping_mul(0xBF58_476D_1CE4_E5B9) ^ c.wrapping_mul(0x94D0_49BB_1331_11EB);
    x ^= x >> 31;
    x = x.wrapping_mul(0x2545_F491_4F6C_DD1D);
    x ^= x >> 29;
    (x >> 11) as f64 / (1u64 << 53) as f64
}

#[derive(Clone)]
pub struct Funding {
    pub coin: &'static str,
    pub hour: i64,
    pub rate: f64,
}

#[derive(Clone)]
pub struct Bar {
    pub coin: &'static str,
    pub k: i64,
    pub close: f64,
}

#[derive(Clone)]
pub struct Count {
    pub coin: &'static str,
    pub hour: i64,
    pub count: f64,
}

pub fn funding(hours: i64) -> Vec<Funding> {
    COINS.iter().enumerate().flat_map(|(c, &coin)| (0..=hours).map(move |hour| Funding { coin, hour, rate: (noise(1, c as u64, hour as u64) - 0.5) * 6e-4 })).collect()
}

pub fn bars(hours: i64) -> Vec<Bar> {
    COINS.iter().enumerate().flat_map(|(c, &coin)| (0..hours / 4).map(move |k| Bar { coin, k, close: 100.0 + 10.0 * noise(2, c as u64, k as u64) })).collect()
}

pub fn counts(hours: i64) -> Vec<Count> {
    COINS.iter().enumerate().flat_map(|(c, &coin)| (1..=hours).map(move |hour| Count { coin, hour, count: (noise(3, c as u64, hour as u64) * 5.0).floor() })).collect()
}

/// The three datasets' files at `fetched`: every row given, in `<fetched>.parquet`.
pub fn write_funding(root: &Path, fetched: i64, rows: &[Funding]) {
    let n = rows.len();
    write(
        &root.join("funding").join(format!("{fetched}.parquet")),
        vec![
            ("coin", Col::S(rows.iter().map(|r| Some(r.coin.to_string())).collect())),
            ("eventTime", Col::I(rows.iter().map(|r| Some(r.hour * HOUR)).collect())),
            ("fundingRate", Col::F(rows.iter().map(|r| Some(r.rate)).collect())),
            ("premium", Col::F(vec![Some(0.0); n])),
            ("reportedTime", Col::I(rows.iter().map(|r| Some(r.hour * HOUR)).collect())),
            ("fetchedAt", Col::I(vec![Some(fetched); n])),
        ],
    );
}

pub fn write_bars(root: &Path, fetched: i64, rows: &[Bar]) {
    let n = rows.len();
    let price = |f: fn(f64) -> f64| Col::F(rows.iter().map(|r| Some(f(r.close))).collect());
    write(
        &root.join("bars_4h").join(format!("{fetched}.parquet")),
        vec![
            ("coin", Col::S(rows.iter().map(|r| Some(r.coin.to_string())).collect())),
            ("eventTime", Col::I(rows.iter().map(|r| Some((r.k + 1) * BAR)).collect())),
            ("openTime", Col::I(rows.iter().map(|r| Some(r.k * BAR)).collect())),
            ("open", price(|c| c - 0.1)),
            ("high", price(|c| c + 1.0)),
            ("low", price(|c| c - 1.0)),
            ("close", price(|c| c)),
            ("volume", Col::F(vec![Some(1.0); n])),
            ("trades", Col::I(vec![Some(5); n])),
            ("fetchedAt", Col::I(vec![Some(fetched); n])),
        ],
    );
}

pub fn write_counts(root: &Path, fetched: i64, rows: &[Count]) {
    write(
        &root.join("events_forum").join(format!("{fetched}.parquet")),
        vec![
            ("coin", Col::S(rows.iter().map(|r| Some(r.coin.to_string())).collect())),
            ("eventTime", Col::I(rows.iter().map(|r| Some(r.hour * HOUR)).collect())),
            ("count", Col::F(rows.iter().map(|r| Some(r.count)).collect())),
            ("fetchedAt", Col::I(vec![Some(fetched); rows.len()])),
        ],
    );
}

pub fn venue() -> Venue {
    let rules = CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: false, cost_bps: [[2.0; 2]; 2], calibration_range: None };
    Venue {
        taker_fee: 0.00045,
        min_notional: 10.0,
        coins: COINS.iter().map(|c| c.to_string()).collect(),
        rules: vec![rules; COINS.len()],
        rules_hash: String::new(),
        execution_hash: String::new(),
    }
}

pub fn policy(hours: i64) -> Policy {
    Policy { delta: DELTA, settlement_latency: 60_000, w_start: 0, holdout_start: i64::MAX, w_end: hours * HOUR }
}
