//! The engine's side of the stage 6 differential test: loads a store with `mm`'s own loader, runs
//! `mm`'s simulator, and writes the resolved market (the reference kernels' input) and the trace,
//! every float as its bits. `mm` itself is used as a library and is not modified.
//!
//! usage: mmdump PROGRAMS STORE VENUE VERSION MARKET_OUT OUT_DIR
//! PROGRAMS lists program files, one path per line; for the i-th, OUT_DIR/i.json holds its output and OUT_DIR/i.bin
//! its node streams (written when it runs). The market is loaded and written once.

use mm::dsl::{Program, Ty, EVENT_INPUTS};
use mm::machine::Machine;
use mm::market::{self, Market, Policy, BAR, HOUR};
use mm::sim::{self, Event, Why};
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

/// Every node's value for every coin at every tick of the machine's schedule (wStart, then each hour of every
/// step), written to `out`, driving mm's own `Machine` with `sim::run`'s delivery order; returns how many were
/// defined.
fn write_streams(out: &mut impl Write, prog: &Program, m: &Market, n: usize, policy: &Policy, end: i64) -> Result<u64, String> {
    let mut machine = Machine::new(prog, n);
    let slots: Vec<(usize, &Vec<market::Event>)> =
        EVENT_INPUTS.iter().enumerate().filter_map(|(slot, (_, ds))| m.events.get(ds).map(|v| (slot, v))).collect();
    let mut e_order: Vec<(i64, usize, usize, usize)> =
        slots.iter().flat_map(|(slot, v)| v.iter().enumerate().map(move |(i, e)| (e.known, e.coin, *slot, i))).collect();
    e_order.sort();
    let mut f_order: Vec<usize> = (0..m.funding.len()).collect();
    f_order.sort_by_key(|&i| (m.funding[i].known, m.funding[i].coin, m.funding[i].event));
    let mut b_order: Vec<usize> = (0..m.bars.len()).collect();
    b_order.sort_by_key(|&i| (m.bars[i].known, m.bars[i].coin, m.bars[i].event));
    let (mut fi, mut bi, mut ei) = (0, 0, 0);
    let mut deliver = |machine: &mut Machine, tick: i64| -> Result<(), String> {
        while fi < f_order.len() && m.funding[f_order[fi]].known <= tick {
            machine.deliver_funding(m.funding[f_order[fi]], tick).map_err(|e| format!("{e:?}"))?;
            fi += 1;
        }
        while bi < b_order.len() && m.bars[b_order[bi]].known <= tick {
            machine.deliver_bar(m.bars[b_order[bi]], tick).map_err(|e| format!("{e:?}"))?;
            bi += 1;
        }
        while ei < e_order.len() && e_order[ei].0 <= tick {
            let (_, _, slot, i) = e_order[ei];
            machine.deliver_event(slot, slots.iter().find(|(s, _)| *s == slot).unwrap().1[i], tick).map_err(|e| format!("{e:?}"))?;
            ei += 1;
        }
        Ok(())
    };
    let mask = |h: i64| (0..n).map(|c| m.intervals[c].0 <= h && h < m.intervals[c].1).collect::<Vec<_>>();
    let mut defined = 0;
    let mut emit = |out: &mut dyn Write, machine: &Machine| -> Result<(), String> {
        let mut b = vec![];
        for i in 0..prog.nodes.len() {
            for c in 0..n {
                let v = machine.value(i, c);
                defined += v.is_some() as u64;
                push_val(&mut b, v);
            }
        }
        out.write_all(&b).map_err(|e| e.to_string())
    };
    deliver(&mut machine, policy.w_start + policy.delta)?;
    machine.tick(&mask(policy.w_start), policy.w_start);
    emit(out, &machine)?;
    let steps = (0..).map(|k| policy.w_start + k * BAR).take_while(|b| b + 2 * BAR <= end).count() as i64;
    for k in 1..=4 * steps {
        let h = policy.w_start + k * HOUR;
        deliver(&mut machine, h + policy.delta)?;
        machine.tick(&mask(h), h);
        emit(out, &machine)?;
    }
    Ok(defined)
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
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
        .flat_map(|(slot, (_, ds))| m.events.get(ds).into_iter().flatten().map(move |e| json!([slot, e.coin, e.event, e.known, b(e.count)])))
        .collect();
    let market_json = json!({
        "funding": m.funding.iter().map(|f| json!([f.coin, f.event, f.known, b(f.rate), b(f.premium)])).collect::<Vec<_>>(),
        "bars": m.bars.iter().map(|x| json!([x.coin, x.open_time, x.event, x.known, b(x.open), b(x.high), b(x.low), b(x.close), b(x.volume), x.trades])).collect::<Vec<_>>(),
        "events": events, "present": slots, "intervals": m.intervals,
        "venue": {"taker_fee": b(venue.taker_fee), "min_notional": b(venue.min_notional),
                  "sz_decimals": venue.rules.iter().map(|r| r.sz_decimals).collect::<Vec<_>>(),
                  "min_tier_leverage": venue.rules.iter().map(|r| b(r.min_tier_leverage)).collect::<Vec<_>>(),
                  "cost_bps": venue.rules.iter().map(|r| r.cost_bps.iter().map(|s| s.iter().map(|x| b(*x)).collect::<Vec<_>>()).collect::<Vec<_>>()).collect::<Vec<_>>()},
        "policy": {"delta": policy.delta, "w_start": policy.w_start, "end": end, "bar": BAR},
    });
    std::fs::write(&a[5], market_json.to_string()).unwrap();
    for (i, path) in programs.iter().enumerate() {
        let text = std::fs::read_to_string(path).unwrap();
        let streams = out_dir.join(format!("{i}.bin"));
        let out = match mm::dsl::parse(&text) {
            Err(r) => json!({"reject": r.code.name()}),
            Ok(p) => match sim::run(&p, &m, &venue, &policy, end) {
                Err(e) => json!({"abort": e.code()}),
                Ok(run) => json!({"trace": run.trace.iter().map(event).collect::<Vec<_>>(),
                                  "returns": run.returns.iter().map(|x| b(*x)).collect::<Vec<_>>(),
                                  "gross_returns": run.gross_returns.iter().map(|x| b(*x)).collect::<Vec<_>>(),
                                  "types": p.types.iter().map(ty).collect::<Vec<_>>(),
                                  "nodes": match write_streams(&mut BufWriter::new(File::create(&streams).unwrap()), &p, &m,
                                                               venue.coins.len(), &policy, end) {
                                      Ok(defined) => json!({"defined": defined}),
                                      Err(e) => json!(e),
                                  }}),
            },
        };
        std::fs::write(out_dir.join(format!("{i}.json")), out.to_string()).unwrap();
    }
}
