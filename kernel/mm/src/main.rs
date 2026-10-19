use mm::dsl;
use mm::ledger::{Experiment, Ledger};
use mm::market::{self, sha256_hex, LoadError, BAR};
use mm::sim::{self, Event, Why};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const USAGE: &str = "mm: the auditable strategy kernel

USAGE:
  mm check FILE [--campaign C] [--agent A] [--ledger PATH]
      Type-check a strategy (kernel/DSL.md) without touching data.
  mm eval FILE --campaign C --agent A [--version V] [--store DIR] [--venue DIR]
          [--policy PATH] [--ledger PATH] [--trace OUT]
      Evaluate a strategy on the search period and print its disclosed statistics.
      --version is a dataset version (a fetchedAt cutoff in ms); default: the latest.
      --trace also writes the full event trace to OUT as JSON lines.
  mm select HASH --campaign C --agent A [--note TEXT] [--ledger PATH]
      Record that the agent chose to pursue strategy HASH, given what it has seen.

Defaults: --store data/store, --venue venue/hyperliquid, --policy policy.json,
--ledger data/ledger.sqlite. Every result is recorded in the ledger before it is
printed; if recording fails, no result is printed and the exit code is 2.
Exit codes: 0 ok, 1 rejected or aborted (reason printed), 2 ledger failure, 3 usage.";

struct Args {
    cmd: String,
    target: String,
    opts: HashMap<String, String>,
}

fn parse_args() -> Option<Args> {
    let mut it = std::env::args().skip(1);
    let cmd = it.next()?;
    if cmd == "--help" || cmd == "-h" {
        return None;
    }
    let target = it.next()?;
    let mut opts = HashMap::new();
    while let Some(k) = it.next() {
        let k = k.strip_prefix("--")?.to_string();
        opts.insert(k, it.next()?);
    }
    Some(Args { cmd, target, opts })
}

impl Args {
    fn get<'a>(&'a self, k: &str, default: &'a str) -> &'a str {
        self.opts.get(k).map_or(default, |s| s.as_str())
    }
}

/// The single path for result-bearing output: commit first, then print.
fn emit(committed: rusqlite::Result<i64>, out: &str, to_stderr: bool, code: u8) -> ExitCode {
    match committed {
        Ok(_) => {
            if to_stderr {
                eprintln!("{out}");
            } else {
                println!("{out}");
            }
            ExitCode::from(code)
        }
        Err(e) => {
            eprintln!("R_LEDGER: {e}");
            ExitCode::from(2)
        }
    }
}

fn kernel_hash() -> String {
    std::env::current_exe().ok().and_then(|p| std::fs::read(p).ok()).map_or("unknown".into(), |b| sha256_hex(&b))
}

fn latest_version(store: &Path) -> Option<i64> {
    ["funding", "bars_4h"]
        .iter()
        .flat_map(|d| std::fs::read_dir(store.join(d)).into_iter().flatten())
        .filter_map(|e| e.ok()?.path().file_stem()?.to_str()?.parse::<i64>().ok())
        .max()
}

fn summary(run: &sim::Run) -> Value {
    let r = &run.returns;
    let n = r.len() as f64;
    let mean = r.iter().sum::<f64>() / n;
    let sd = (r.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / n).sqrt();
    let per_year = (365 * 24 * 3_600_000 / BAR) as f64;
    let sharpe = if sd > 0.0 { mean / sd * per_year.sqrt() } else { 0.0 };
    let mut peak = sim::INITIAL;
    let mut mdd: f64 = 0.0;
    for &e in &run.equity {
        peak = peak.max(e);
        mdd = mdd.max(1.0 - e / peak);
    }
    let (mut fills, mut fees, mut funding, mut holds, mut turnover) = (0, 0.0, 0.0, 0, 0.0);
    for e in &run.trace {
        match e {
            Event::Fill(f) => {
                fills += 1;
                fees += f.fee;
                turnover += f.qty.abs() * f.price;
            }
            Event::Funding { paid, .. } => funding -= paid,
            Event::Hold { .. } => holds += 1,
            _ => {}
        }
    }
    json!({
        "steps": r.len(),
        "final_equity": run.equity.last().copied().unwrap_or(sim::INITIAL),
        "total_return": run.equity.last().map_or(0.0, |e| e / sim::INITIAL - 1.0),
        "sharpe_annualized": sharpe,
        "max_drawdown": mdd,
        "fills": fills,
        "fees": fees,
        "funding": funding,
        "turnover": turnover,
        "holds": holds,
    })
}

pub fn event_json(e: &Event, coins: &[String]) -> Value {
    match e {
        Event::Decision { t, coin, weight, qty } => json!({"type": "decision", "t": t, "coin": coins[*coin], "weight": weight, "qty": qty}),
        Event::Hold { t, coin, why } => json!({"type": "hold", "t": t, "coin": coins[*coin], "why": why}),
        Event::Unfilled { t, coin, qty } => json!({"type": "unfilled", "t": t, "coin": coins[*coin], "qty": qty}),
        Event::Funding { t, coin, rate, price, paid } => {
            json!({"type": "funding", "t": t, "coin": coins[*coin], "rate": rate, "price": price, "paid": paid})
        }
        Event::Equity { t, equity, reconciled } => json!({"type": "equity", "t": t, "equity": equity, "reconciled": reconciled}),
        Event::Fill(f) => json!({
            "type": match f.why { Why::Fill => "fill", Why::Liquidation => "liquidation", Why::Delisting => "delisting" },
            "t": f.filled, "coin": coins[f.coin], "qty": f.qty, "ref": f.reference, "price": f.price, "fee": f.fee,
            "decided": f.decided, "submitted": f.submitted, "inputs_known": f.inputs_known, "source_open": f.source_open,
        }),
    }
}

fn check(a: &Args, ledger: &mut Ledger) -> ExitCode {
    let (campaign, agent) = (a.get("campaign", "-"), a.get("agent", "-"));
    let text = match std::fs::read_to_string(&a.target) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("cannot read {}: {e}", a.target);
            return ExitCode::from(3);
        }
    };
    match dsl::parse(&text) {
        Ok(p) => {
            let out = json!({"ok": true, "strategy": sha256_hex(p.canonical().as_bytes())}).to_string();
            emit(ledger.disclose(campaign, agent, "check", &out), &out, false, 0)
        }
        Err(r) => {
            let out = json!({"ok": false, "code": r.code.name(), "path": r.path, "message": r.msg}).to_string();
            emit(ledger.disclose(campaign, agent, "reject", &out), &out, true, 1)
        }
    }
}

fn eval(a: &Args, ledger: &mut Ledger) -> ExitCode {
    let (Some(campaign), Some(agent)) = (a.opts.get("campaign"), a.opts.get("agent")) else {
        eprintln!("{USAGE}");
        return ExitCode::from(3);
    };
    let abort = |ledger: &mut Ledger, code: &str, msg: &str| {
        let out = json!({"ok": false, "code": code, "message": msg}).to_string();
        let kind = if code.starts_with("E_") { "reject" } else { "abort" };
        emit(ledger.disclose(campaign, agent, kind, &out), &out, true, 1)
    };
    let text = match std::fs::read_to_string(&a.target) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("cannot read {}: {e}", a.target);
            return ExitCode::from(3);
        }
    };
    let prog = match dsl::parse(&text) {
        Ok(p) => p,
        Err(r) => return abort(ledger, r.code.name(), &format!("{} at {}", r.msg, r.path)),
    };
    let store = PathBuf::from(a.get("store", "data/store"));
    let load = || -> Result<_, LoadError> {
        let policy = market::policy(Path::new(a.get("policy", "policy.json")))?;
        let venue = market::venue(Path::new(a.get("venue", "venue/hyperliquid")))?;
        let version = match a.opts.get("version") {
            Some(v) => v.parse().map_err(|_| LoadError::Io("bad --version".into()))?,
            None => latest_version(&store).ok_or_else(|| LoadError::Io("empty store".into()))?,
        };
        let m = market::load(&store, version, &venue, &policy, Some(policy.holdout_start))?;
        Ok((policy, venue, version, m))
    };
    let (policy, venue, version, market) = match load() {
        Ok(x) => x,
        Err(LoadError::Holdout(m)) => return abort(ledger, "R_HOLDOUT", &m),
        Err(LoadError::Io(m)) => {
            eprintln!("load error: {m}");
            return ExitCode::from(3);
        }
    };
    let end = policy.holdout_start.min(policy.w_end);
    let run = match sim::run(&prog, &market, &venue, &policy, end) {
        Ok(r) => r,
        Err(e) => return abort(ledger, e.code(), &format!("{e:?}")),
    };

    let canonical = prog.canonical();
    let strategy_hash = sha256_hex(canonical.as_bytes());
    let params = json!(prog.param_values().into_iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>()).to_string();
    let universe = json!(venue.coins).to_string();
    let conventions = json!({"delta_ms": policy.delta, "decision_grid_ms": BAR, "fill": "open of first bar with openTime >= submission",
                             "settlement": "hourly at open of containing 4h bar, before fills"}).to_string();
    let kernel = kernel_hash();
    let identity = sha256_hex(
        [&canonical, &params, &universe, &policy.w_start.to_string(), &end.to_string(), &version.to_string(),
         &market.data_hash, &conventions, &venue.rules_hash, &venue.execution_hash, &kernel, "0"]
            .join("\n")
            .as_bytes(),
    );
    let summary = summary(&run).to_string();
    let returns_bytes: Vec<u8> = run.returns.iter().flat_map(|r| r.to_le_bytes()).collect();
    let result_hash = sha256_hex(&[summary.as_bytes(), &returns_bytes].concat());
    let trace_text = a.opts.get("trace").map(|_| {
        run.trace.iter().map(|e| event_json(e, &venue.coins).to_string()).collect::<Vec<_>>().join("\n") + "\n"
    });
    let content = json!({
        "strategy": strategy_hash, "identity": identity, "result_hash": result_hash,
        "result": serde_json::from_str::<Value>(&summary).unwrap(),
        "trace_sha256": trace_text.as_ref().map(|t| sha256_hex(t.as_bytes())),
    });
    let e = Experiment {
        campaign,
        agent,
        mode: "search",
        strategy_hash: &strategy_hash,
        canonical: &canonical,
        params: &params,
        universe: &universe,
        window: (policy.w_start, end),
        dataset_version: version,
        data_hash: &market.data_hash,
        conventions: &conventions,
        rules_hash: &venue.rules_hash,
        execution_hash: &venue.execution_hash,
        kernel: &kernel,
        seed: 0,
        identity: &identity,
        mechanism: &prog.mechanism.to_string(),
    };
    let committed = ledger.disclose_result(&e, &run.returns, &summary, &result_hash, &content.to_string());
    if committed.is_ok() {
        if let (Some(path), Some(t)) = (a.opts.get("trace"), &trace_text) {
            if let Err(err) = std::fs::write(path, t) {
                eprintln!("cannot write trace: {err}");
            }
        }
    }
    let out = committed.as_ref().map(|id| json!({"experiment": id, "disclosure": content}).to_string()).unwrap_or_default();
    emit(committed, &out, false, 0)
}

fn select(a: &Args, ledger: &mut Ledger) -> ExitCode {
    let (Some(campaign), Some(agent)) = (a.opts.get("campaign"), a.opts.get("agent")) else {
        eprintln!("{USAGE}");
        return ExitCode::from(3);
    };
    let r = ledger.select(campaign, agent, &a.target, a.get("note", ""));
    let out = r.as_ref().map(|id| json!({"selection": id}).to_string()).unwrap_or_default();
    emit(r, &out, false, 0)
}

fn main() -> ExitCode {
    let Some(a) = parse_args() else {
        println!("{USAGE}");
        return ExitCode::from(3);
    };
    let mut ledger = match Ledger::open(Path::new(a.get("ledger", "data/ledger.sqlite"))) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("R_LEDGER: {e}");
            return ExitCode::from(2);
        }
    };
    match a.cmd.as_str() {
        "check" => check(&a, &mut ledger),
        "eval" => eval(&a, &mut ledger),
        "select" => select(&a, &mut ledger),
        _ => {
            println!("{USAGE}");
            ExitCode::from(3)
        }
    }
}
