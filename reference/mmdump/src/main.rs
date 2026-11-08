//! The engine's side of the stage 6 differential test: loads a store with `mm`'s own loader, runs
//! `mm`'s simulator, and writes the resolved market (the reference kernels' input) and the trace,
//! every float as its bits. `mm` itself is used as a library and is not modified.
//!
//! usage: mmdump PROGRAMS STORE VENUE VERSION MARKET_OUT OUT_DIR
//! PROGRAMS lists program files, one path per line; for the i-th, OUT_DIR/i.json holds its output and OUT_DIR/i.bin
//! its node streams (written when it runs). The market is loaded and written once.
//!
//! usage: mmdump admit CASES
//! per admission case (reference/admission_differential.py), `mm::admission::admit`'s refusal code and position, or
//! `ok` and the required set, as `refmm admit` prints them.

use mm::admission::{admit, Binding, Cert, Meta, Mode, Roles};
use mm::dsl::{Program, Ty};
use mm::market::{self, Market, Policy, BAR};
use mm::sim::{self, Event, Why};
use mm::source;
use serde_json::{json, Value};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

fn b(x: f64) -> Value {
    json!(x.to_bits())
}

fn event(e: &Event) -> Value {
    match e {
        Event::Decision { t, coin, weight, qty } => json!(["decision", t, coin, b(*weight), b(*qty)]),
        Event::Hold { t, coin, why } => json!(["hold", t, coin, why]),
        Event::Fill(f) => json!(["fill", match f.why { Why::Fill => "fill", Why::Liquidation => "liquidation", Why::Delisting => "delisting" },
                                 f.coin, b(f.qty), f.inputs_known, b(f.decision_price), f.decided, f.submitted, f.filled,
                                 f.source_open, b(f.reference), b(f.price), b(f.fee)]),
        Event::Unfilled { t, coin, qty } => json!(["unfilled", t, coin, b(*qty)]),
        Event::Funding { t, coin, rate, price, paid } => json!(["funding", t, coin, b(*rate), b(*price), b(*paid)]),
        Event::Equity { t, equity, reconciled } => json!(["equity", t, b(*equity), b(*reconciled)]),
    }
}

/// A value as bytes: 0 if undefined, else 1 and its eight bytes, low byte first.
fn push_val(b: &mut Vec<u8>, v: Option<f64>) {
    match v {
        None => b.push(0),
        Some(x) => {
            b.push(1);
            b.extend_from_slice(&x.to_bits().to_le_bytes());
        }
    }
}

fn ty(t: &Ty) -> String {
    match t {
        Ty::Bool => "bool".into(),
        Ty::Num(u) => format!("num:{}", u.0.iter().map(|e| e.to_string()).collect::<Vec<_>>().join(",")),
    }
}

/// Every node's value for every coin at every tick of the machine's schedule (`sim::observe`), written to `out`;
/// returns how many were defined.
fn write_streams(out: &mut impl Write, prog: &Program, m: &Market, venue: &market::Venue, policy: &Policy, end: i64) -> Result<u64, String> {
    let mut defined = 0;
    sim::observe(prog, m, venue, policy, end, |_, machine| {
        let mut b = vec![];
        for i in 0..prog.nodes.len() {
            for c in 0..venue.coins.len() {
                let v = machine.value(i, c);
                defined += v.is_some() as u64;
                push_val(&mut b, v);
            }
        }
        out.write_all(&b).map_err(|e| e.to_string())
    })?;
    Ok(defined)
}

fn strs(v: &Value) -> Vec<String> {
    v.as_array().unwrap().iter().map(|x| x.as_str().unwrap().to_string()).collect()
}

/// Per record, whether it is the last of its key's timeline (`final`): the loader delivers a key's revisions
/// consecutively, in order.
fn finals<T>(rows: &[T], key: impl Fn(&T) -> (usize, i64)) -> Vec<bool> {
    (0..rows.len()).map(|i| rows.get(i + 1).map_or(true, |n| key(n) != key(&rows[i]))).collect()
}

fn admit_case(c: &Value) -> String {
    let Ok(reg) = c["decls"].as_array().unwrap().iter().map(|d| source::declaration(d["text"].as_str().unwrap())).collect::<Result<Vec<_>, _>>() else {
        return "invalid 0".into();
    };
    let n = |v: &Value| v.as_u64().unwrap() as usize;
    let s = |v: &Value| v.as_str().unwrap().to_string();
    let roles = Roles { bars: n(&c["roles"][0]), settlement: n(&c["roles"][1]) };
    let sources: Vec<usize> = c["sources"].as_array().unwrap().iter().map(n).collect();
    let m = Meta {
        bindings: c["bindings"].as_array().unwrap().iter().rev().map(|b| (n(&b[0]), Binding { dataset: s(&b[1]), cert: s(&b[2]) })).collect(),
        certs: c["certs"].as_array().unwrap().iter().map(|k| Cert {
            id: s(&k["id"]), decl: s(&k["decl"]), manifest: s(&k["manifest"]), policy: s(&k["policy"]),
            verifier: s(&k["verifier"]), upstream: strs(&k["upstream"]), controls: strs(&k["controls"]).into_iter().collect(),
            venue_state: k["venueState"].as_bool().unwrap() }).collect(),
        supersessions: c["supersessions"].as_array().unwrap().iter().map(|x| (s(&x[0]), x[1].as_u64().unwrap())).collect(),
        position: c["position"].as_u64().unwrap(), policy: s(&c["policy"]), verifier: s(&c["verifier"]),
        holdout: strs(&c["holdout"]), holdout_start: c["holdoutStart"].as_i64().unwrap(),
    };
    let mode = if c["mode"] == "search" { Mode::Search } else { Mode::Holdout };
    let rows: Vec<(usize, i64)> = c["rows"].as_array().unwrap().iter().map(|r| (n(&r[0]), r[1].as_i64().unwrap())).collect();
    let read = |req: &[usize]| req.iter().flat_map(|s| rows.iter().filter(move |r| r.0 == *s).copied()).collect();
    match admit(&reg, &roles, &sources, &m, mode, read) {
        Ok(req) => format!("ok {}", req.iter().map(usize::to_string).collect::<Vec<_>>().join(",")),
        Err((p, e)) => format!("{} {p}", e.code()),
    }
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    if a[1] == "admit" {
        let cases: Value = serde_json::from_str(&std::fs::read_to_string(&a[2]).unwrap()).unwrap();
        for c in cases.as_array().unwrap() {
            println!("{}", admit_case(c));
        }
        return;
    }
    let programs: Vec<String> = std::fs::read_to_string(&a[1]).unwrap().lines().filter(|l| !l.is_empty()).map(String::from).collect();
    let store = PathBuf::from(&a[2]);
    let policy = market::policy(&store.join("policy.json")).unwrap();
    let venue = market::venue(Path::new(&a[3])).unwrap();
    let version: i64 = a[4].parse().unwrap();
    let out_dir = PathBuf::from(&a[6]);
    let m = market::load(&[store], version, &venue, &policy, Some(policy.holdout_start)).unwrap();
    let end = policy.holdout_start.min(policy.w_end);
    let slots: Vec<usize> = mm::dsl::EVENT_INPUTS.iter().enumerate().filter(|(_, (_, ds))| m.events.contains_key(ds)).map(|(i, _)| i).collect();
    let events: Vec<Value> = mm::dsl::EVENT_INPUTS
        .iter()
        .enumerate()
        .flat_map(|(slot, (_, ds))| {
            let es = m.events.get(ds).map(Vec::as_slice).unwrap_or_default();
            let last = finals(es, |e| (e.coin, e.key));
            es.iter().zip(last).map(move |(e, f)| json!([slot, e.coin, e.event, e.known, b(e.count), e.recorded, e.key, e.retraction, f]))
        })
        .collect();
    let funding_last = finals(&m.funding, |f| (f.coin, f.event));
    let bars_last = finals(&m.bars, |x| (x.coin, x.event));
    let market_json = json!({
        "funding": m.funding.iter().zip(funding_last).map(|(f, last)| json!([f.coin, f.event, f.known, b(f.rate), b(f.premium), f.retraction, f.recorded, last])).collect::<Vec<_>>(),
        "bars": m.bars.iter().zip(bars_last).map(|(x, last)| json!([x.coin, x.open_time, x.event, x.known, b(x.open), b(x.high), b(x.low), b(x.close), b(x.volume), x.trades, x.retraction, x.recorded, last])).collect::<Vec<_>>(),
        "events": events, "present": slots, "intervals": m.intervals,
        "venue": {"taker_fee": b(venue.taker_fee), "min_notional": b(venue.min_notional),
                  "sz_decimals": venue.rules.iter().map(|r| r.sz_decimals).collect::<Vec<_>>(),
                  "min_tier_leverage": venue.rules.iter().map(|r| b(r.min_tier_leverage)).collect::<Vec<_>>(),
                  "cost_bps": venue.rules.iter().map(|r| r.cost_bps.iter().map(|s| s.iter().map(|x| b(*x)).collect::<Vec<_>>()).collect::<Vec<_>>()).collect::<Vec<_>>()},
        "policy": {"delta": policy.delta, "w_start": policy.w_start, "end": end, "bar": BAR},
    });
    std::fs::write(&a[5], market_json.to_string()).unwrap();
    let inputs = mm::source::inputs(&mm::source::registry(std::path::Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../sources"))).unwrap());
    for (i, path) in programs.iter().enumerate() {
        let text = std::fs::read_to_string(path).unwrap();
        let streams = out_dir.join(format!("{i}.bin"));
        let out = match mm::dsl::parse(&inputs, &text) {
            Err(r) => json!({"reject": r.code.name()}),
            Ok(p) => match sim::run(&p, &m, &venue, &policy, end) {
                Err(e) => json!({"abort": e.code()}),
                Ok(run) => json!({"trace": run.trace.iter().map(event).collect::<Vec<_>>(),
                                  "returns": run.returns.iter().map(|x| b(*x)).collect::<Vec<_>>(),
                                  "gross_returns": run.gross_returns.iter().map(|x| b(*x)).collect::<Vec<_>>(),
                                  "types": p.types.iter().map(ty).collect::<Vec<_>>(),
                                  "nodes": match write_streams(&mut BufWriter::new(File::create(&streams).unwrap()), &p, &m,
                                                               &venue, &policy, end) {
                                      Ok(defined) => json!({"defined": defined}),
                                      Err(e) => json!(e),
                                  }}),
            },
        };
        std::fs::write(out_dir.join(format!("{i}.json")), out.to_string()).unwrap();
    }
}
