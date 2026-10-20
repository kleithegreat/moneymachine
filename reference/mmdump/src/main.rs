//! The engine's side of the stage 6 differential test: loads a store with `mm`'s own loader, runs
//! `mm`'s simulator, and writes the resolved market (the reference kernels' input) and the trace,
//! every float as its bits. `mm` itself is used as a library and is not modified.
//!
//! usage: mmdump PROGRAM STORE VENUE VERSION MARKET_OUT TRACE_OUT

use mm::market::{self, BAR};
use mm::sim::{self, Event, Why};
use serde_json::{json, Value};
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

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let text = std::fs::read_to_string(&a[1]).unwrap();
    let store = PathBuf::from(&a[2]);
    let policy = market::policy(&store.join("policy.json")).unwrap();
    let venue = market::venue(Path::new(&a[3])).unwrap();
    let version: i64 = a[4].parse().unwrap();
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
    let out = match mm::dsl::parse(&text) {
        Err(r) => json!({"reject": r.code.name()}),
        Ok(p) => match sim::run(&p, &m, &venue, &policy, end) {
            Err(e) => json!({"abort": e.code()}),
            Ok(run) => json!({"trace": run.trace.iter().map(event).collect::<Vec<_>>(),
                              "returns": run.returns.iter().map(|x| b(*x)).collect::<Vec<_>>(),
                              "gross_returns": run.gross_returns.iter().map(|x| b(*x)).collect::<Vec<_>>()}),
        },
    };
    std::fs::write(&a[6], out.to_string()).unwrap();
}
