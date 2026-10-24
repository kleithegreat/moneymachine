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
          [--ledger PATH] [--trace OUT]
      Evaluate a strategy on the search period and print its disclosed statistics as one
      JSON line. FILE is one strategy, or a .jsonl file with one strategy per line (one
      output line each, in order), or - to read JSONL from stdin and answer each line as it
      arrives. Exit code 1 if any line is a rejection or abort.
      --version is a dataset version (a fetchedAt cutoff in ms); default: the latest.
      --trace also writes the full event trace to OUT as JSON lines.
      --mechanism on adds the test of each strategy's `prediction` (for the gate; never
      passed to an agent).
  mm holdout FILE --campaign C --agent A --holdout-store DIR [--holdout-from MS] [same options as eval]
      The gate's holdout step: evaluate the finalists in FILE over the holdout window, once.
      FILE (not stdin) is read whole first, and its trials must be exactly those agent A
      selected in campaign C (R_HOLDOUT_FAMILY otherwise). The window starts at the policy's
      holdout start, or later with --holdout-from. Refused (R_HOLDOUT_SPENT) if the holdout
      store records an overlapping window as already evaluated, whichever ledger did it.
  mm select HASH --campaign C --agent A [--note TEXT] [--ledger PATH]
      Record that the agent chose to pursue strategy HASH, given what it has seen.
  mm disclose FILE --campaign C --agent A --kind KIND [--ledger PATH]
      Record FILE's content as a disclosure to agent A (for gate infrastructure such as the
      swarm's shared history); prints the disclosure id once committed.
  mm check-fills FILE
      Check fills against invariants I2/I3 and the I9 order cap, one JSON case per line
      (kernel/tests/timing/FORMAT.md); print one verdict per line. Reads no market data.

Defaults: --store data/store, --venue venue/hyperliquid, --ledger data/ledger.sqlite. The
holdout boundary comes from the store's own policy.json. Every result is recorded in the ledger before it is
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

/// The run restricted to the steps whose equity time is after `after` (the disclosed window), as an account that
/// starts the window with INITIAL: equity rescaled by the equity just before it, and only the events after it.
fn reported(run: sim::Run, after: i64) -> sim::Run {
    let times: Vec<i64> = run.trace.iter().filter_map(|e| if let Event::Equity { t, .. } = e { Some(*t) } else { None }).collect();
    let k = times.iter().position(|&t| t > after).unwrap_or(run.returns.len());
    let (base, since) = if k == 0 { (sim::INITIAL, i64::MIN) } else { (run.equity[k - 1], times[k - 1]) };
    sim::Run {
        returns: run.returns[k..].to_vec(),
        gross_returns: run.gross_returns[k..].to_vec(),
        equity: run.equity[k..].iter().map(|e| e * sim::INITIAL / base).collect(),
        exposures: run.exposures,
        trace: run.trace.into_iter().filter(|e| event_time(e) > since).collect(),
    }
}

fn event_time(e: &Event) -> i64 {
    match e {
        Event::Decision { t, .. } | Event::Hold { t, .. } | Event::Unfilled { t, .. } | Event::Funding { t, .. }
        | Event::Equity { t, .. } => *t,
        Event::Fill(f) => f.filled,
    }
}

/// Reported beside a holdout result, never judged (audit/criteria.md, C3.4 revision): the return of a full
/// rerun with every cost-table entry doubled, and per coin the holdout 4h bars whose (high - low)/open
/// lies within the range the cost model was calibrated on.
fn holdout_diagnostics(prog: &dsl::Program, c: &Ctx) -> Value {
    let stressed = match sim::run(prog, &c.market, &c.venue.costs_scaled(2.0), &c.policy, c.end) {
        Ok(run) => summary(&reported(run, c.report_after))["total_return"].clone(),
        Err(e) => json!({"abort": e.code()}),
    };
    let mut coverage = serde_json::Map::new();
    for (i, coin) in c.venue.coins.iter().enumerate() {
        let Some((lo, hi)) = c.venue.rules[i].calibration_range else {
            coverage.insert(coin.clone(), Value::Null);
            continue;
        };
        let (start, stop) = (c.report_after.max(c.market.intervals[i].0), c.end.min(c.market.intervals[i].1));
        let first = start + (BAR - start.rem_euclid(BAR)) % BAR;
        let expected = if stop > first { (stop - first) / BAR } else { 0 };
        let bars: Vec<_> = c.market.bars.iter().filter(|b| b.coin == i && b.open_time >= first && b.open_time + BAR <= stop).collect();
        let inside = bars.iter().filter(|b| (lo..=hi).contains(&((b.high - b.low) / b.open))).count();
        coverage.insert(coin.clone(), json!({"inside": inside, "bars": bars.len(), "missing": expected - bars.len() as i64}));
    }
    json!({"total_return_2x_costs": stressed, "relative_range_coverage": coverage})
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
    let (mut fills, mut fees, mut funding, mut holds, mut turnover, mut slippage) = (0, 0.0, 0.0, 0, 0.0, 0.0);
    for e in &run.trace {
        match e {
            Event::Fill(f) => {
                fills += 1;
                fees += f.fee;
                turnover += f.qty.abs() * f.price;
                slippage += f.qty * (f.price - f.reference);
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
        "slippage": slippage,
        "gross_return_mean": run.gross_returns.iter().sum::<f64>() / n,
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
            let out = json!({"ok": true, "strategy": sha256_hex(p.canonical().as_bytes()),
                             "equivalence": mm::canon::equivalence_key(&p)}).to_string();
            emit(ledger.disclose(campaign, agent, "check", &out), &out, false, 0)
        }
        Err(r) => {
            let out = json!({"ok": false, "code": r.code.name(), "path": r.path, "message": r.msg}).to_string();
            emit(ledger.disclose(campaign, agent, "reject", &out), &out, true, 1)
        }
    }
}

struct Ctx {
    policy: market::Policy,
    venue: market::Venue,
    version: i64,
    market: market::Market,
    mode: &'static str,
    /// Steps whose equity time is after this are the disclosed result (the holdout window).
    report_after: i64,
    end: i64,
    kernel: String,
}

fn load_ctx(a: &Args, mode: &'static str) -> Result<Ctx, LoadError> {
    let store = PathBuf::from(a.get("store", "data/store"));
    let policy = market::policy(&store.join("policy.json"))?;
    let venue = market::venue(Path::new(a.get("venue", "venue/hyperliquid")))?;
    let version = match a.opts.get("version") {
        Some(v) => v.parse().map_err(|_| LoadError::Io("bad --version".into()))?,
        None => latest_version(&store).ok_or_else(|| LoadError::Io("empty store".into()))?,
    };
    let (stores, holdout, report_after, end) = if mode == "holdout" {
        let h = PathBuf::from(a.opts.get("holdout-store").ok_or_else(|| LoadError::Io("--holdout-store required".into()))?);
        let from = match a.opts.get("holdout-from") {
            Some(v) => v.parse::<i64>().map_err(|_| LoadError::Io("bad --holdout-from".into()))?.max(policy.holdout_start),
            None => policy.holdout_start,
        };
        (vec![store, h], None, from, policy.w_end)
    } else {
        (vec![store], Some(policy.holdout_start), i64::MIN, policy.holdout_start.min(policy.w_end))
    };
    let market = market::load(&stores, version, &venue, &policy, holdout)?;
    Ok(Ctx { policy, venue, version, market, mode, report_after, end, kernel: kernel_hash() })
}

/// Claim [start, end) of a holdout store before evaluating it: false if an overlapping window
/// was already claimed. The record lives with the data, so a fresh ledger cannot reuse it.
/// The record is read, checked and appended under an exclusive lock.
fn claim_holdout(store: &Path, start: i64, end: i64, campaign: &str) -> std::io::Result<bool> {
    use std::io::{Read, Write};
    let mut f = std::fs::OpenOptions::new().read(true).append(true).create(true).open(store.join("spent.jsonl"))?;
    f.lock()?;
    let mut text = String::new();
    f.read_to_string(&mut text)?;
    for line in text.lines() {
        let v: Value = serde_json::from_str(line).map_err(std::io::Error::other)?;
        if v["start"].as_i64().unwrap_or(i64::MIN) < end && v["end"].as_i64().unwrap_or(i64::MAX) > start {
            return Ok(false);
        }
    }
    writeln!(f, "{}", json!({"start": start, "end": end, "campaign": campaign}))?;
    f.sync_all()?;
    Ok(true)
}

/// The programs to evaluate: one file, a .jsonl file (one per line), or `-` to stream JSONL from
/// stdin, answering each line before reading the next.
fn programs(path: &str) -> std::io::Result<Box<dyn Iterator<Item = String>>> {
    if path == "-" {
        use std::io::BufRead;
        return Ok(Box::new(std::io::stdin().lock().lines().map_while(Result::ok).filter(|l| !l.trim().is_empty())));
    }
    let text = std::fs::read_to_string(path)?;
    Ok(if path.ends_with(".jsonl") {
        Box::new(text.lines().filter(|l| !l.trim().is_empty()).map(String::from).collect::<Vec<_>>().into_iter())
    } else {
        Box::new(std::iter::once(text))
    })
}

/// Evaluate one checked program and commit its experiment, result and disclosure.
fn mechanism_report(exposures: &[(bool, f64)]) -> Value {
    let branch = |b: bool| {
        let r: Vec<f64> = exposures.iter().filter(|(c, _)| *c == b).map(|(_, r)| *r).collect();
        (r.len(), if r.is_empty() { f64::NAN } else { r.iter().sum::<f64>() / r.len() as f64 })
    };
    let ((n_t, m_t), (n_f, m_f)) = (branch(true), branch(false));
    let share = n_t as f64 / (n_t + n_f).max(1) as f64;
    json!({"exposures_true": n_t, "exposures_false": n_f, "mean_true": m_t, "mean_false": m_f, "share_true": share,
           "pass": (0.1..=0.9).contains(&share) && m_t > m_f})
}

fn evaluate(prog: &dsl::Program, text: &str, c: &Ctx, campaign: &str, agent: &str, trace_path: Option<&String>, mechanism: bool, ledger: &mut Ledger)
    -> Result<String, (String, String)> {
    let run = sim::run(prog, &c.market, &c.venue, &c.policy, c.end).map_err(|e| (e.code().to_string(), format!("{e:?}")))?;
    let run = reported(run, c.report_after);
    let canonical = prog.canonical();
    let strategy_hash = sha256_hex(canonical.as_bytes());
    let equivalence = mm::canon::equivalence_key(prog);
    let params = params_json(prog);
    let trial = mm::ledger::trial(&equivalence, &params);
    let universe = json!(c.venue.coins).to_string();
    let market::Policy { delta, settlement_latency, w_start, holdout_start, w_end } = &c.policy;
    let conventions = json!({"delta_ms": delta, "settlement_latency_ms": settlement_latency, "w_start": w_start,
                             "holdout_start": holdout_start, "w_end": w_end, "decision_grid_ms": BAR,
                             "fill": "open of first bar with openTime >= submission",
                             "settlement": "hourly at open of containing 4h bar, before fills"}).to_string();
    let window = (c.report_after.max(c.policy.w_start), c.end);
    let identity = sha256_hex(
        [&canonical, &params, &universe, &window.0.to_string(), &window.1.to_string(), &c.version.to_string(),
         &c.market.data_hash, &conventions, &c.venue.rules_hash, &c.venue.execution_hash, &c.kernel, "0", c.mode]
            .join("\n")
            .as_bytes(),
    );
    let mut summary = summary(&run);
    if mechanism {
        summary["mechanism"] = mechanism_report(&run.exposures);
    }
    let summary = summary.to_string();
    let returns_bytes: Vec<u8> = run.returns.iter().flat_map(|r| r.to_le_bytes()).collect();
    let result_hash = sha256_hex(&[summary.as_bytes(), &returns_bytes].concat());
    let trace_text = trace_path.map(|_| run.trace.iter().map(|e| event_json(e, &c.venue.coins).to_string()).collect::<Vec<_>>().join("\n") + "\n");
    let mut content = json!({
        "strategy": strategy_hash, "equivalence": equivalence, "identity": identity, "result_hash": result_hash, "mode": c.mode,
        "result": serde_json::from_str::<Value>(&summary).unwrap(),
        "trace_sha256": trace_text.as_ref().map(|t| sha256_hex(t.as_bytes())),
    });
    if c.mode == "holdout" {
        content["diagnostics"] = holdout_diagnostics(prog, c);
    }
    let e = Experiment {
        campaign,
        agent,
        mode: c.mode,
        strategy_hash: &strategy_hash,
        canonical: &canonical,
        program: text,
        equivalence: &equivalence,
        trial: &trial,
        params: &params,
        universe: &universe,
        window,
        dataset_version: c.version,
        data_hash: &c.market.data_hash,
        conventions: &conventions,
        rules_hash: &c.venue.rules_hash,
        execution_hash: &c.venue.execution_hash,
        kernel: &c.kernel,
        seed: 0,
        identity: &identity,
        mechanism: &prog.mechanism.to_string(),
    };
    let id = ledger
        .disclose_result(&e, &run.returns, &summary, &result_hash, &content.to_string())
        .map_err(|err| ("R_LEDGER".to_string(), err.to_string()))?;
    if let (Some(path), Some(t)) = (trace_path, &trace_text) {
        if let Err(err) = std::fs::write(path, t) {
            eprintln!("cannot write trace: {err}");
        }
    }
    Ok(json!({"experiment": id, "disclosure": content}).to_string())
}

fn params_json(prog: &dsl::Program) -> String {
    json!(prog.param_values().into_iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>()).to_string()
}

/// The context, or the exit after reporting why it could not be loaded.
fn context(a: &Args, mode: &'static str, ledger: &mut Ledger, campaign: &str, agent: &str) -> Result<Ctx, ExitCode> {
    match load_ctx(a, mode) {
        Ok(c) => Ok(c),
        Err(LoadError::Holdout(m)) => {
            let out = json!({"ok": false, "code": "R_HOLDOUT", "message": m}).to_string();
            Err(emit(ledger.disclose(campaign, agent, "abort", &out), &out, false, 1))
        }
        Err(LoadError::Io(m)) => {
            eprintln!("load error: {m}");
            Err(ExitCode::from(3))
        }
    }
}

/// The holdout's one batch: refused unless its trials are exactly `agent`'s selections in `campaign`, then the
/// window is claimed before anything is evaluated.
fn open_holdout(a: &Args, texts: &[String], ledger: &mut Ledger, campaign: &str, agent: &str) -> Result<Ctx, ExitCode> {
    let abort = |ledger: &mut Ledger, code: &str, message: &str| {
        let out = json!({"ok": false, "code": code, "message": message}).to_string();
        emit(ledger.disclose(campaign, agent, "abort", &out), &out, false, 1)
    };
    let trials: Option<std::collections::BTreeSet<String>> = texts
        .iter()
        .map(|t| dsl::parse(t).ok().map(|p| mm::ledger::trial(&mm::canon::equivalence_key(&p), &params_json(&p))))
        .collect();
    let selected = ledger.selected(campaign, agent).map_err(|e| {
        eprintln!("R_LEDGER: {e}");
        ExitCode::from(2)
    })?;
    if trials.as_ref() != Some(&selected) || texts.len() != selected.len() {
        return Err(abort(ledger, "R_HOLDOUT_FAMILY", "the batch is not exactly the campaign's frozen selections"));
    }
    let c = context(a, "holdout", ledger, campaign, agent)?;
    match claim_holdout(Path::new(&a.opts["holdout-store"]), c.report_after, c.end, campaign) {
        Ok(true) => Ok(c),
        Ok(false) => Err(abort(ledger, "R_HOLDOUT_SPENT", "an overlapping holdout window was already evaluated")),
        Err(e) => {
            eprintln!("cannot record holdout use: {e}");
            Err(ExitCode::from(3))
        }
    }
}

/// `eval` and `holdout`: one output line per program, each committed before it is printed.
fn eval(a: &Args, ledger: &mut Ledger, mode: &'static str) -> ExitCode {
    let (Some(campaign), Some(agent)) = (a.opts.get("campaign"), a.opts.get("agent")) else {
        eprintln!("{USAGE}");
        return ExitCode::from(3);
    };
    if mode == "holdout" && a.target == "-" {
        eprintln!("holdout reads its batch from a file");
        return ExitCode::from(3);
    }
    let mut texts = match programs(&a.target) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("cannot read {}: {e}", a.target);
            return ExitCode::from(3);
        }
    };
    let mut ctx: Option<Ctx> = None;
    if mode == "holdout" {
        let batch: Vec<String> = texts.collect();
        match open_holdout(a, &batch, ledger, campaign, agent) {
            Ok(c) => ctx = Some(c),
            Err(code) => return code,
        }
        texts = Box::new(batch.into_iter());
    }
    let mut status = 0;
    for text in texts {
        let outcome = match dsl::parse(&text) {
            Err(r) => Err((r.code.name().to_string(), format!("{} at {}", r.msg, r.path))),
            Ok(prog) => {
                if ctx.is_none() {
                    match context(a, mode, ledger, campaign, agent) {
                        Ok(c) => ctx = Some(c),
                        Err(code) => return code,
                    }
                }
                evaluate(&prog, &text, ctx.as_ref().unwrap(), campaign, agent, a.opts.get("trace"), a.opts.contains_key("mechanism"), ledger)
            }
        };
        match outcome {
            Ok(line) => println!("{line}"),
            Err((code, _)) if code == "R_LEDGER" => {
                eprintln!("R_LEDGER");
                return ExitCode::from(2);
            }
            Err((code, msg)) => {
                status = 1;
                let out = json!({"ok": false, "code": code, "message": msg}).to_string();
                let kind = if code.starts_with("E_") { "reject" } else { "abort" };
                match ledger.disclose(campaign, agent, kind, &out) {
                    Ok(_) => println!("{out}"),
                    Err(e) => {
                        eprintln!("R_LEDGER: {e}");
                        return ExitCode::from(2);
                    }
                }
            }
        }
    }
    ExitCode::from(status)
}

fn disclose(a: &Args, ledger: &mut Ledger) -> ExitCode {
    let (Some(campaign), Some(agent), Some(kind)) = (a.opts.get("campaign"), a.opts.get("agent"), a.opts.get("kind")) else {
        eprintln!("{USAGE}");
        return ExitCode::from(3);
    };
    let Ok(content) = std::fs::read_to_string(&a.target) else {
        eprintln!("cannot read {}", a.target);
        return ExitCode::from(3);
    };
    let r = ledger.disclose(campaign, agent, kind, &content);
    let out = r.as_ref().map(|id| json!({"disclosure": id}).to_string()).unwrap_or_default();
    emit(r, &out, false, 0)
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

fn check_fills(path: &str) -> ExitCode {
    let Ok(text) = std::fs::read_to_string(path) else {
        eprintln!("cannot read {path}");
        return ExitCode::from(3);
    };
    for line in text.lines().filter(|l| !l.trim().is_empty()) {
        let c: Value = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("bad case: {e}");
                return ExitCode::from(3);
            }
        };
        let verdict = match fill_case(&c) {
            Some((f, m, v)) => sim::check_fill(&f, &m, &v).err().map_or("ok", |e| e.code()),
            None => "bad-case",
        };
        println!("{}", json!({"id": c["id"], "verdict": verdict}));
    }
    ExitCode::SUCCESS
}

fn fill_case(c: &Value) -> Option<(sim::Fill, market::Market, market::Venue)> {
    let num = |v: &Value| v.as_f64();
    let int = |v: &Value| v.as_i64();
    let bars: Vec<market::Bar> = c["bars"]
        .as_array()?
        .iter()
        .map(|b| {
            Some(market::Bar {
                coin: 0,
                open_time: int(&b["open_time"])?,
                event: int(&b["event"])?,
                known: int(&b["event"])?,
                open: num(&b["open"])?,
                high: num(&b["high"])?,
                low: num(&b["low"])?,
                close: num(&b["close"])?,
                volume: 0.0,
                trades: int(&b["trades"])?,
            })
        })
        .collect::<Option<_>>()?;
    let cost = &c["cost_bps"];
    let venue = market::Venue {
        taker_fee: num(&c["taker_fee"])?,
        min_notional: 10.0,
        coins: vec!["X".into()],
        rules: vec![market::CoinRules {
            sz_decimals: 8,
            min_tier_leverage: 1.0,
            delisted: false,
            cost_bps: [[num(&cost["buy"][0])?, num(&cost["buy"][1])?], [num(&cost["sell"][0])?, num(&cost["sell"][1])?]],
            calibration_range: None,
        }],
        rules_hash: String::new(),
        execution_hash: String::new(),
    };
    let mut bar_times = vec![bars.iter().map(|b| b.open_time).collect::<Vec<_>>()];
    bar_times[0].sort();
    let market = market::Market {
        bar_at: bars.iter().enumerate().map(|(i, b)| ((0, b.open_time), i)).collect(),
        rate_at: HashMap::new(),
        bar_times,
        intervals: vec![(i64::MIN, i64::MAX)],
        events: HashMap::new(),
        funding: vec![],
        bars,
        data_hash: String::new(),
    };
    let f = &c["fill"];
    let why = match f["why"].as_str()? {
        "fill" => Why::Fill,
        "liquidation" => Why::Liquidation,
        "delisting" => Why::Delisting,
        _ => return None,
    };
    let fill = sim::Fill {
        why,
        coin: 0,
        qty: num(&f["qty"])?,
        inputs_known: int(&f["inputs_known"])?,
        decision_price: num(&f["decision_price"])?,
        decided: int(&f["decided"])?,
        submitted: int(&f["submitted"])?,
        filled: int(&f["filled"])?,
        source_open: int(&f["source_open"])?,
        reference: num(&f["reference"])?,
        price: num(&f["price"])?,
        fee: num(&f["fee"])?,
    };
    Some((fill, market, venue))
}

const OPTIONS: [&str; 10] =
    ["campaign", "agent", "ledger", "version", "store", "venue", "trace", "mechanism", "holdout-store", "holdout-from"];

fn main() -> ExitCode {
    let Some(a) = parse_args() else {
        println!("{USAGE}");
        return ExitCode::from(3);
    };
    if let Some(k) = a.opts.keys().find(|k| !OPTIONS.contains(&k.as_str()) && !(a.cmd == "select" && *k == "note") && !(a.cmd == "disclose" && *k == "kind")) {
        eprintln!("unknown option --{k}\n{USAGE}");
        return ExitCode::from(3);
    }
    if a.cmd == "check-fills" {
        return check_fills(&a.target);
    }
    let mut ledger = match Ledger::open(Path::new(a.get("ledger", "data/ledger.sqlite"))) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("R_LEDGER: {e}");
            return ExitCode::from(2);
        }
    };
    match a.cmd.as_str() {
        "check" => check(&a, &mut ledger),
        "eval" => eval(&a, &mut ledger, "search"),
        "holdout" => eval(&a, &mut ledger, "holdout"),
        "select" => select(&a, &mut ledger),
        "disclose" => disclose(&a, &mut ledger),
        _ => {
            println!("{USAGE}");
            ExitCode::from(3)
        }
    }
}
