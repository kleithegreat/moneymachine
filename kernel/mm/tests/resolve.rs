//! C7.6's named loader-level tests on `mm`'s loader (audit/criteria.md, B3 revision): test 3, holdout staging, in its
//! Rust namesake of `ingest/tests/test_store.py`'s `test_holdout_check_decides_on_event_times_alone`, facing the same
//! fixtures and variants. The two-run checks are `noninterference.rs`.
//!
//! The loader's API is `market::load`; its channels are checked in a child process of this very test binary, run with
//! `--nocapture`, whose output must be the harness's own lines and nothing else.

mod common;

use arrow_array::types::Float64Type;
use arrow_array::{ArrayRef, BooleanArray, Float64Array, Int64Array, ListArray, RecordBatch, StringArray};
use arrow_schema::{DataType, Field, Schema};
use mm::market::{self, CoinRules, Policy, Venue, HOUR};
use parquet::arrow::arrow_reader::{ArrowReaderMetadata, ArrowReaderOptions};
use parquet::arrow::ArrowWriter;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::sync::Arc;

const V: i64 = 100;
const UNCHECKABLE: &str = "the holdout check cannot be made: an event time is not a non-null Int64 in range";

fn policy() -> Policy {
    market::policy(&Path::new(env!("CARGO_MANIFEST_DIR")).join("../../policy.json")).unwrap()
}

fn venue(coins: &[&str]) -> Venue {
    let rules = CoinRules { sz_decimals: 3, min_tier_leverage: 10.0, delisted: false, cost_bps: [[1.0; 2]; 2], calibration_range: None };
    Venue {
        taker_fee: 0.00045,
        min_notional: 10.0,
        coins: coins.iter().map(|c| c.to_string()).collect(),
        rules: vec![rules; coins.len()],
        rules_hash: String::new(),
        execution_hash: String::new(),
    }
}

/// A small deterministic generator (xorshift64*), seeded per fixture.
struct Rng(u64);

impl Rng {
    fn new(seed: &str) -> Rng {
        Rng(seed.bytes().fold(0x9E37_79B9_7F4A_7C15, |h, b| (h ^ b as u64).wrapping_mul(0x100_0000_01B3)) | 1)
    }
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn below(&mut self, n: u64) -> u64 {
        self.next() % n
    }
    fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }
    fn pick<T: Clone>(&mut self, xs: &[T]) -> T {
        xs[self.below(xs.len() as u64) as usize].clone()
    }
}

#[derive(Clone)]
enum Val {
    F(f64),
    I(i64),
    S(String),
    L(Vec<f64>),
}

/// The type of the value column (`close` here, `rate` in Python's fixtures) of a file.
#[derive(Clone, Copy)]
enum Kind {
    F,
    I,
    S,
    L,
}

#[derive(Clone)]
struct Row {
    coin: Option<String>,
    event: Option<i64>,
    close: Option<Val>,
    fetched: Option<i64>,
    source: String,
    hash: String,
    tombstone: Option<bool>,
}

#[derive(Clone, Copy, PartialEq)]
enum Event {
    Int64,
    Float64,
    Absent,
}

/// A file of `rows`: the event column of the given type, the value column of the given kind. A Float64 event column
/// holds the integer event times as doubles.
fn write(path: &Path, rows: &[Row], event: Event, kind: Kind) {
    let list = DataType::List(Arc::new(Field::new("item", DataType::Float64, true)));
    let mut fields = vec![Field::new("coin", DataType::Utf8, true)];
    let mut columns: Vec<ArrayRef> = vec![Arc::new(StringArray::from(rows.iter().map(|r| r.coin.as_deref()).collect::<Vec<_>>()))];
    match event {
        Event::Int64 => {
            fields.push(Field::new("eventTime", DataType::Int64, true));
            columns.push(Arc::new(Int64Array::from(rows.iter().map(|r| r.event).collect::<Vec<_>>())));
        }
        Event::Float64 => {
            fields.push(Field::new("eventTime", DataType::Float64, true));
            columns.push(Arc::new(Float64Array::from(rows.iter().map(|r| r.event.map(|e| e as f64)).collect::<Vec<_>>())));
        }
        Event::Absent => {}
    }
    let (ty, col): (DataType, ArrayRef) = match kind {
        Kind::F => (DataType::Float64, Arc::new(Float64Array::from(rows.iter().map(|r| if let Some(Val::F(x)) = r.close { Some(x) } else { None }).collect::<Vec<_>>()))),
        Kind::I => (DataType::Int64, Arc::new(Int64Array::from(rows.iter().map(|r| if let Some(Val::I(x)) = r.close { Some(x) } else { None }).collect::<Vec<_>>()))),
        Kind::S => (DataType::Utf8, Arc::new(StringArray::from(rows.iter().map(|r| if let Some(Val::S(x)) = &r.close { Some(x.as_str()) } else { None }).collect::<Vec<_>>()))),
        Kind::L => (
            list,
            Arc::new(ListArray::from_iter_primitive::<Float64Type, _, _>(
                rows.iter().map(|r| if let Some(Val::L(x)) = &r.close { Some(x.iter().map(|v| Some(*v)).collect::<Vec<_>>()) } else { None }),
            )),
        ),
    };
    fields.push(Field::new("close", ty, true));
    columns.push(col);
    fields.push(Field::new("fetchedAt", DataType::Int64, true));
    columns.push(Arc::new(Int64Array::from(rows.iter().map(|r| r.fetched).collect::<Vec<_>>())));
    fields.push(Field::new("source", DataType::Utf8, true));
    columns.push(Arc::new(StringArray::from(rows.iter().map(|r| Some(r.source.as_str())).collect::<Vec<_>>())));
    fields.push(Field::new("hash", DataType::Utf8, true));
    columns.push(Arc::new(StringArray::from(rows.iter().map(|r| Some(r.hash.as_str())).collect::<Vec<_>>())));
    fields.push(Field::new("tombstone", DataType::Boolean, true));
    columns.push(Arc::new(BooleanArray::from(rows.iter().map(|r| r.tombstone).collect::<Vec<_>>())));
    let schema = Arc::new(Schema::new(fields));
    let mut writer = ArrowWriter::try_new(File::create(path).unwrap(), schema.clone(), None).unwrap();
    writer.write(&RecordBatch::try_new(schema, columns).unwrap()).unwrap();
    writer.close().unwrap();
}

/// Every column chunk of a Parquet file but those named in `keep` overwritten with garbage, its footer, and so its
/// statistics, kept.
fn garble(path: &Path, keep: &[&str]) {
    let meta = ArrowReaderMetadata::load(&File::open(path).unwrap(), ArrowReaderOptions::new()).unwrap();
    let mut data = std::fs::read(path).unwrap();
    for group in meta.metadata().row_groups() {
        for column in group.columns().iter().filter(|c| !keep.contains(&c.column_path().parts()[0].as_str())) {
            let (start, length) = column.byte_range();
            data[start as usize..(start + length) as usize].fill(0xFF);
        }
    }
    std::fs::write(path, data).unwrap();
}

/// A good bars row of coin `coin`, fetched at `V`, at hour `hour`.
fn early(coin: &str, hour: i64) -> Row {
    Row { coin: Some(coin.into()), event: Some(hour * HOUR), close: Some(Val::F(1.0)), fetched: Some(V), source: "t".into(), hash: "x".into(), tombstone: None }
}

/// The valid datasets of a store root holding one early bar of `coin`: bars as `write` gives them but with the
/// columns a bar needs, and a funding row.
fn good_store(root: &Path, coin: &str, hour: i64) {
    for d in ["funding", "bars_4h"] {
        std::fs::create_dir_all(root.join(d)).unwrap();
    }
    let event = hour * HOUR;
    let doubles = |names: &[&str], values: &[f64]| -> (Vec<Field>, Vec<ArrayRef>) {
        (names.iter().map(|n| Field::new(*n, DataType::Float64, true)).collect(), values.iter().map(|v| Arc::new(Float64Array::from(vec![*v])) as ArrayRef).collect())
    };
    let common = |mut fields: Vec<Field>, mut columns: Vec<ArrayRef>, ints: &[(&str, i64)]| {
        fields.insert(0, Field::new("coin", DataType::Utf8, true));
        columns.insert(0, Arc::new(StringArray::from(vec![coin])));
        for (n, v) in ints {
            fields.push(Field::new(*n, DataType::Int64, true));
            columns.push(Arc::new(Int64Array::from(vec![*v])));
        }
        (fields, columns)
    };
    for (dataset, (fields, columns)) in [
        ("funding", {
            let (f, c) = doubles(&["fundingRate", "premium"], &[0.0001, 0.0]);
            common(f, c, &[("eventTime", event), ("reportedTime", event), ("fetchedAt", V)])
        }),
        ("bars_4h", {
            let (f, c) = doubles(&["open", "high", "low", "close", "volume"], &[1.0, 2.0, 0.5, 1.5, 3.0]);
            common(f, c, &[("openTime", event - 4 * HOUR), ("eventTime", event), ("trades", 5), ("fetchedAt", V)])
        }),
    ] {
        let schema = Arc::new(Schema::new(fields));
        let mut writer = ArrowWriter::try_new(File::create(root.join(dataset).join("0.parquet")).unwrap(), schema.clone(), None).unwrap();
        writer.write(&RecordBatch::try_new(schema, columns).unwrap()).unwrap();
        writer.close().unwrap();
    }
}

struct Fixture {
    name: &'static str,
    /// The event times of the late rows, and the type of their column.
    times: [Option<i64>; 2],
    event: Event,
    shared: bool,
    coin: &'static str,
    diagnostic: Option<&'static str>,
}

fn fixtures(crossing: i64, early_time: i64) -> Vec<Fixture> {
    let f = |name, times, event, shared, coin, diagnostic| Fixture { name, times, event, shared, coin, diagnostic };
    let c = Some(crossing);
    vec![
        f("own file", [Some(crossing + HOUR), c], Event::Int64, false, "A", None),
        f("shared file", [Some(crossing + HOUR), c], Event::Int64, true, "A", None),
        f("undecodable event time", [Some(early_time - HOUR), Some(early_time - 2 * HOUR)], Event::Float64, false, "A", Some(UNCHECKABLE)),
        f("null event time", [c, None], Event::Int64, false, "A", Some(UNCHECKABLE)),
        f("event time below range", [c, Some(-(1 << 62) - 1)], Event::Int64, false, "A", Some(UNCHECKABLE)),
        f("event time above range", [c, Some(1 << 62)], Event::Int64, false, "A", Some(UNCHECKABLE)),
        f("absent event time", [None, None], Event::Absent, false, "A", Some(UNCHECKABLE)),
        f("outside-U late rows", [Some(crossing + HOUR), c], Event::Int64, false, "ZZZ", None),
    ]
}

/// The late rows' kind, rows and whether their file is garbled, for variant `i`: the late rows eligible and live,
/// fetched after the version, tombstoned, an Int64-null fetchedAt, then 32 drawn varying every column but the event time.
fn variant(rng: &mut Rng, i: usize, fixture: &Fixture) -> (Kind, Vec<Row>, bool) {
    let plain = |fetched: Option<i64>, tombstone: Option<bool>| {
        (Kind::F, (0..2).map(|_| Row { coin: Some(fixture.coin.into()), event: None, close: Some(Val::F(1.0)), fetched, source: "t".into(), hash: "x".into(), tombstone }).collect(), false)
    };
    let (kind, mut rows, garbled) = match i {
        0 => plain(Some(50), None),
        1 => plain(Some(200), None),
        2 => plain(Some(50), Some(true)),
        3 => plain(None, None),
        _ => {
            let kind = rng.pick(&[Kind::F, Kind::F, Kind::F, Kind::I, Kind::S, Kind::L]);
            let rows: Vec<Row> = (0..2)
                .map(|_| Row {
                    coin: rng.pick(&[None, Some(fixture.coin.to_string())]),
                    event: None,
                    close: if rng.below(10) == 0 {
                        None
                    } else {
                        Some(match kind {
                            Kind::F => Val::F(match (rng.below(10), rng.below(3)) {
                                (0..=1, 0) => f64::NAN,
                                (0..=1, 1) => f64::INFINITY,
                                (0..=1, _) => f64::NEG_INFINITY,
                                _ => (if rng.below(2) == 0 { -1.0 } else { 1.0 }) * 10f64.powf(rng.unit() * 10.0 - 2.0),
                            }),
                            Kind::I => Val::I(rng.next() as i64),
                            Kind::S => Val::S(rng.unit().to_string()),
                            Kind::L => Val::L((0..rng.below(3)).map(|_| rng.unit()).collect()),
                        })
                    },
                    fetched: match rng.below(3) {
                        0 => None,
                        1 => Some(rng.next() as i64 % (V + 1)),
                        _ => Some(V + 1 + (rng.next() >> 2) as i64),
                    },
                    source: rng.unit().to_string(),
                    hash: rng.unit().to_string(),
                    tombstone: rng.pick(&[None, Some(true), Some(false)]),
                })
                .collect();
            (kind, rows, rng.below(10) < 3)
        }
    };
    for (row, t) in rows.iter_mut().zip(fixture.times) {
        row.event = t;
    }
    (kind, rows, garbled)
}

/// Fixture `name`'s 36 variants under `base`: the exact refusal of each call, then an independent dataset through the
/// same API, equal to a second load of it.
fn matrix(base: &Path, name: &str) {
    let policy = policy();
    let (crossing, early_time) = (policy.holdout_start + HOUR, policy.holdout_start - HOUR);
    let fixture = fixtures(crossing, early_time).into_iter().find(|f| f.name == name).unwrap();
    let diagnostic = fixture.diagnostic.map(String::from).unwrap_or_else(|| format!("holdout crossing: event time {crossing} at or after {}", policy.holdout_start));
    let venue = venue(&["A", "B"]);
    let mut rng = Rng::new(name);
    for i in 0..36 {
        let root = base.join(i.to_string());
        let store = root.join("store");
        good_store(&store, "A", early_time / HOUR);
        std::fs::remove_file(store.join("bars_4h/0.parquet")).unwrap();
        let (kind, late, garbled) = variant(&mut rng, i, &fixture);
        let e = if early_time % HOUR == 0 { early_time } else { early_time - early_time.rem_euclid(HOUR) };
        let first = Row { event: Some(e), ..early("A", e / HOUR) };
        let bars = store.join("bars_4h");
        let (parts, event): (Vec<Vec<Row>>, Event) = if fixture.shared {
            (vec![[vec![first], late].concat()], fixture.event)
        } else {
            (vec![vec![first], late], fixture.event)
        };
        for (n, rows) in parts.iter().enumerate() {
            let last = n + 1 == parts.len();
            let rows: Vec<Row> = if last && fixture.shared { rows.iter().enumerate().map(|(r, row)| if r == 0 { Row { close: Some(same(kind)), ..row.clone() } } else { row.clone() }).collect() } else { rows.clone() };
            write(&bars.join(format!("{n}.parquet")), &rows, if last { event } else { Event::Int64 }, if last { kind } else { Kind::F });
            if last && garbled {
                garble(&bars.join(format!("{n}.parquet")), &["eventTime"]);
            }
        }
        let clean = root.join("clean");
        good_store(&clean, "B", early_time / HOUR);
        let refusal = market::load(&[store.clone()], V, common::registry(), &venue, &policy, Some(policy.holdout_start));
        match refusal {
            Err(e) => assert_eq!(e.to_string(), diagnostic, "refusal of {name} variant {i}"),
            Ok(_) => panic!("{name} variant {i}: loaded"),
        }
        let view = |m: market::Market| (m.obs.iter().any(|o| o.source == m.roles.settlement), format!("{m:?}"));
        let again = market::load(&[clean.clone()], V, common::registry(), &venue, &policy, Some(policy.holdout_start)).map(view);
        let fresh = market::load(&[clean], V, common::registry(), &venue, &policy, Some(policy.holdout_start)).map(view);
        assert!(again.as_ref().is_ok_and(|a| a.0) && again.as_ref().ok() == fresh.as_ref().ok(), "state: {name} variant {i}");
    }
}

fn same(kind: Kind) -> Val {
    match kind {
        Kind::F => Val::F(1.0),
        Kind::I => Val::I(1),
        Kind::S => Val::S("1".into()),
        Kind::L => Val::L(vec![1.0]),
    }
}

fn scratch(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("mm-staged-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// The child half: the whole matrix of the fixture named by the environment, silently.
#[test]
fn staged_child() {
    let Ok(name) = std::env::var("MM_STAGED_FIXTURE") else { return };
    let dir = scratch(&name.replace(' ', "-"));
    matrix(&dir, &name);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
fn holdout_check_decides_on_event_times_alone() {
    let p = policy();
    for fixture in fixtures(p.holdout_start + HOUR, p.holdout_start - HOUR) {
        let out = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["staged_child", "--exact", "--nocapture", "--test-threads", "1"])
            .env("MM_STAGED_FIXTURE", fixture.name)
            .output()
            .unwrap();
        let (stdout, stderr) = (String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
        assert!(out.status.success(), "{}: {stdout}{stderr}", fixture.name);
        let strays: Vec<&str> = stdout.lines().filter(|l| !(l.is_empty() || l.starts_with("running ") || l.starts_with("test "))).collect();
        assert!(strays.is_empty() && stderr.is_empty(), "{}: output {strays:?} {stderr:?}", fixture.name);
    }
}

fn late_file(path: &Path, event: Event, fetched: i64, hour: i64) {
    let row = Row { fetched: Some(fetched), ..early("A", hour) };
    write(path, &[row], event, Kind::F);
}

/// SOURCES.md §2: a file whose rows are all fetched after V may hold anything undecodable without changing the
/// dataset at V. Argon's review of slice 5, F3.
#[test]
fn an_undecodable_file_fetched_after_the_version_changes_nothing() {
    let root = scratch("post-v").join("store");
    good_store(&root, "A", 8);
    let venue = venue(&["A"]);
    let policy = policy();
    let view = |m: market::Market| format!("{:?}", m.obs);
    let clean = view(market::load(&[root.clone()], V, common::registry(), &venue, &policy, None).unwrap());
    late_file(&root.join("bars_4h/1.parquet"), Event::Int64, V + 100, 9);
    garble(&root.join("bars_4h/1.parquet"), &["eventTime", "fetchedAt"]);
    let after = market::load(&[root.clone()], V, common::registry(), &venue, &policy, Some(policy.holdout_start)).map(view);
    assert_eq!(after.as_ref().ok(), Some(&clean), "{after:?}");
}

/// Argon's review of slice 5, F6: an event column whose type is not Int64 is uncheckable whatever its pages hold.
#[test]
fn an_event_column_of_another_type_is_uncheckable_without_decoding_it() {
    let root = scratch("event-type").join("store");
    good_store(&root, "A", 8);
    late_file(&root.join("bars_4h/1.parquet"), Event::Float64, V, 9);
    garble(&root.join("bars_4h/1.parquet"), &[]);
    let policy = policy();
    assert!(matches!(market::load(&[root], V, common::registry(), &venue(&["A"]), &policy, Some(policy.holdout_start)), Err(market::LoadError::Holdout(m)) if m == UNCHECKABLE));
}

/// C7.6 test 3, across the call's datasets: any uncheckable event time takes precedence over crossings whatever the
/// dataset, and a crossing refusal names the least crossing time of them all. Argon's review of slice 5, F4.
#[test]
fn the_holdout_check_spans_the_datasets_of_a_call() {
    let policy = policy();
    let h = policy.holdout_start / HOUR;
    let venue = venue(&["A"]);
    let mixed = |tag: &str, funding_hour: i64, bars: &dyn Fn(&Path)| {
        let root = scratch(tag);
        good_store(&root.join("a"), "A", funding_hour);
        good_store(&root.join("b"), "A", 8);
        let store = root.join("store");
        std::fs::create_dir_all(&store).unwrap();
        std::fs::rename(root.join("a/funding"), store.join("funding")).unwrap();
        std::fs::create_dir_all(store.join("bars_4h")).unwrap();
        bars(&store.join("bars_4h/0.parquet"));
        market::load(&[store], V, common::registry(), &venue, &policy, Some(policy.holdout_start)).map(|_| ())
    };
    let crossing = |hour: i64| format!("holdout crossing: event time {} at or after {}", hour * HOUR, policy.holdout_start);
    let err = mixed("uncheckable", h + 2, &|p| late_file(p, Event::Float64, V, h + 1)).unwrap_err();
    assert_eq!(err.to_string(), UNCHECKABLE);
    let err = mixed("least", h + 2, &|p| late_file(p, Event::Int64, V, h + 1)).unwrap_err();
    assert_eq!(err.to_string(), crossing(h + 1));
}

/// C7.6 test 3's namesake also holds evidence late rows: an evidence dataset's rows at or after the boundary refuse a
/// search, whatever else they hold, and are never decoded. Argon's review of slice 5, F5.
#[test]
fn an_evidence_dataset_is_checked_for_late_rows_too() {
    let policy = policy();
    let root = scratch("evidence");
    let evidence = mm::resolve::Source {
        name: "obs".into(),
        rule: r#"{"rule": 1, "expr": {"field": "eventTime"}}"#.into(),
        times: vec!["eventTime".into()],
        values: vec!["close".into()],
        entity: vec!["coin".into()],
        event: "eventTime".into(),
        slot: None,
        role: None,
        evidence: true,
        deps: vec![],
    };
    let crossing = policy.holdout_start + HOUR;
    let row = |event| Row { event: Some(event), ..early("A", 8) };
    std::fs::create_dir_all(root.join("obs")).unwrap();
    write(&root.join("obs/0.parquet"), &[row(8 * HOUR)], Event::Int64, Kind::F);
    write(&root.join("obs/1.parquet"), &[row(crossing), row(crossing + HOUR)], Event::Int64, Kind::F);
    garble(&root.join("obs/1.parquet"), &["eventTime"]);
    let got = mm::resolve::resolve(&[root.clone()], vec![evidence], &[], V, Some(policy.holdout_start)).err().map(|e| e.to_string());
    assert_eq!(got, Some(format!("holdout crossing: event time {crossing} at or after {}", policy.holdout_start)));
}
