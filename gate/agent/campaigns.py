"""Agent campaigns: the sandboxed research agent (arm A) and the swarm on null markets as smoke tests, and the one
real campaign (arm A against the G100 searcher, one holdout batch); null series are paced and resumable."""

import json
import signal
import sqlite3
import subprocess
import sys
import threading
import time
from pathlib import Path

from gate import campaign, gate, markets, search, sweep
from gate.agent import harness
from ingest.live import now_ms
from ingest.policy import DAY
from sandbox import session

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "data" / "agent"
FROZEN = REPO / "audit/stage3/harness.json"
REPORT_FROM_DAY = {"agent": 670, "swarm": 640}
REAL_REPORT_FROM = 1785542400000  # 2026-08-01, a month after the agent model's knowledge cutoff
LABEL = "pipeline validation run, not a test for edge; every promotion: historical holdout, costs fitted after it"
MIN_SWARM_EVALUATIONS = 200
CEILING = 0.8  # the most of any subscription window a campaign may bring it to; the rest stays with the human
FIRST_NEED = 0.5  # a campaign's assumed share of each window until one has been measured
TOKENS = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens", "output_tokens")
STOP = threading.Event()  # set by SIGTERM: the series ends between campaigns
NO_CLAIM = "One campaign per arm supports no claim that either generator is better."
SMOKE = {"agent": "20 runs bound the promotion rate only to about 0.28; this is a smoke test.",
         "swarm": "With 10 runs the 95% bound is about 0.39; this is a smoke test only."}


def freeze_harness():
    """Record the harness hash. A refreeze names the freeze it supersedes, and only while no campaign was ever started."""
    previous = json.loads(FROZEN.read_text()) if FROZEN.exists() else None
    started = OUT.exists() and any(p.is_dir() or p.read_text().strip() for p in OUT.iterdir())
    if previous and started:
        sys.exit(f"{FROZEN}: a campaign has started under it, so a changed harness needs fresh campaign ids")
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    FROZEN.write_text(json.dumps({"harness": harness.harness_hash(), "frozen": now_ms(), "previous": previous}, indent=1) + "\n")


def check_frozen():
    if not FROZEN.exists() or json.loads(FROZEN.read_text())["harness"] != harness.harness_hash():
        sys.exit(f"the harness differs from {FROZEN}: null campaigns must be rerun with fresh ids after a change")


def audit_run(run_dir, ledger, campaign, agent="A"):
    """One agent run: daemon log against ledger rows, and no tool call outside the permitted set."""
    log = [json.loads(l) for l in open(Path(run_dir) / "daemon.log")]
    evals = sum(e["cmd"] == "eval" and e["response"].get("code") != "BUDGET" for e in log)
    histories = sum(e["cmd"] == "history" and e["response"].get("ok", False) for e in log)
    db = sqlite3.connect(ledger)
    rows = db.execute("SELECT COUNT(*) FROM disclosures WHERE campaign = ? AND agent = ? AND kind IN ('eval', 'reject', 'abort')",
                      (campaign, agent)).fetchone()[0]
    history_rows = db.execute("SELECT COUNT(*) FROM disclosures WHERE campaign = ? AND agent = ? AND kind = 'history'",
                              (campaign, agent)).fetchone()[0]
    use = session.tool_use(Path(run_dir) / "transcript.jsonl", harness.CLIENT)
    return {"daemon_evals": evals, "ledger_rows": rows, "history_calls": histories, "history_rows": history_rows,
            "match": evals == rows and histories == history_rows,
            **{k: use[k] for k in ("tools", "outside_permitted", "denials")}}


def cross_agent_history(run_dirs):
    """Whether any agent received history containing another agent's evaluations."""
    for d in run_dirs:
        for line in open(d / "daemon.log"):
            e = json.loads(line)
            if e["cmd"] == "history" and any(r.get("agent") != d.name for r in e["response"].get("evaluations", [])):
                return True
    return False


def screened(market, ledger, campaign, agent=None):
    """The search decision, then the mechanism check: (report, mechanism results, kept finalists)."""
    finalists, report = gate.search_decision(ledger, campaign, agent)
    programs = gate.programs(ledger, campaign, finalists, agent)
    mech = gate.mechanism_check(market, ledger, campaign, programs)
    return report, mech, {h: p for h, p in programs.items() if mech[h]["pass"]}


def arm_a(market, ledger, campaign, run_dir):
    return harness.run_agent(market, ledger, campaign, run_dir), *screened(market, ledger, campaign, "A")


def null_market(cid, cost_cells):
    return markets.write(OUT / cid / "m", markets.generate("N2", markets.null_params()["N2"], cid, sweep.DAYS), sweep.HOLDOUT_DAYS, cost_cells)


def agent_null(cid, cost_cells):
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    run, report, mech, kept = arm_a(market, ledger, cid, OUT / cid / "run")
    gate.freeze(ledger, cid, kept, "frozen finalist A")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, REPORT_FROM_DAY["agent"] * DAY)
    return {"agent_run": run, "search": report, "mechanism": mech, "kept": list(kept), "holdout": holdout,
            "bankrupt": gate.bankrupt(ledger),
            "promoted": promoted, "audit": audit_run(OUT / cid / "run", ledger, cid), "counts_as_promotion": bool(promoted)}


def swarm_null(cid, cost_cells):
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    swarm = harness.run_swarm(market, ledger, cid, OUT / cid / "swarm")
    report, mech, kept = screened(market, ledger, cid)
    gate.freeze(ledger, cid, kept, "frozen finalist swarm")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, REPORT_FROM_DAY["swarm"] * DAY)
    run_dirs = [OUT / cid / "swarm" / r["agent"] for r in swarm["runs"]]
    return {"runs": swarm["runs"], "evaluations": swarm["evaluations"], "search": report, "mechanism": mech,
            "kept": list(kept), "holdout": holdout, "promoted": promoted, "cross_agent_history": cross_agent_history(run_dirs),
            "bankrupt": gate.bankrupt(ledger),
            "audits": {d.name: audit_run(d, ledger, cid, d.name) for d in run_dirs},
            "counts_as_promotion": bool(promoted) or swarm["evaluations"] < MIN_SWARM_EVALUATIONS}


SERIES = {"agent": agent_null, "swarm": swarm_null}
STAGE = {"agent": 3, "swarm": 4}


def windows():
    """The subscription's usage windows, {name: [utilization, resets_at]}, from one tiny model call; None if it fails."""
    try:
        out = subprocess.run([session.claude_binary(), "-p", "Reply with OK.", "--model", harness.MODEL, "--output-format",
                              "stream-json", "--verbose"], capture_output=True, text=True, timeout=300).stdout
    except subprocess.TimeoutExpired:
        return None
    for line in out.splitlines():
        if '"rate_limit_event"' in line:
            found = json.loads(line)["rate_limit_info"].get("unifiedWindows")
            return found and {k: [w["utilization"], w["resetsAt"]] for k, w in found.items()}
    return None


def need(log):
    """Per window, the most any campaign recorded in `log` used of it within one reset period. It counts the
    subscription's other use meanwhile, so it overstates."""
    used = {}
    for row in map(json.loads, open(log)) if log.exists() else []:
        w = row.get("windows", {})
        for k, (u, reset) in (w.get("after") or {}).items():
            before = (w.get("before") or {}).get(k)
            if before and before[1] == reset:
                used[k] = max(used.get(k, 0.0), u - before[0])
    return used


def wait_for_room(log):
    """Wait until every window's utilization plus `need(log)` (FIRST_NEED where unmeasured) is within CEILING, so no
    campaign exhausts the subscription mid-run; return the windows last read, or None once STOP is set."""
    while not STOP.is_set():
        w = windows()
        if w is not None:
            used = need(log)
            full = [reset for k, (u, reset) in w.items() if u + used.get(k, FIRST_NEED) > CEILING]
            if not full:
                return w
        STOP.wait(session.RETRY if w is None else max(60, min(full) - time.time()))
    return None


def usage(work):
    """Tokens and cost summed over the result lines of every transcript under `work`."""
    total = dict.fromkeys(TOKENS, 0) | {"cost_usd": 0.0}
    for t in sorted(Path(work).rglob("transcript.jsonl")):
        for line in open(t):
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") == "result":
                total = {k: total[k] + d["usage"].get(k, 0) for k in TOKENS} | {"cost_usd": total["cost_usd"] + d["total_cost_usd"]}
    return total


def run_series(name, n):
    """Campaigns `{name}-null-N2-0` .. n - 1, resumable (a started, unrecorded id is recorded as a crash), each started
    when the subscription has room for it (`wait_for_room`) and the harness is still the frozen one, and recorded with
    its usage and the windows around it. SIGTERM ends the series between campaigns."""
    signal.signal(signal.SIGTERM, lambda *_: STOP.set())
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / f"{name}-null.jsonl"
    with campaign.resume([f"{name}-null-N2-{i}" for i in range(n)], log, OUT) as todo:
        for cid in todo:
            before = wait_for_room(log)
            if before is None:
                break
            check_frozen()
            started = time.time()
            try:
                result = SERIES[name](cid, sweep.cost_cells())
            except Exception as e:
                result = {"crash": repr(e), "counts_as_promotion": True}
            result |= {"seconds": round(time.time() - started), "usage": usage(OUT / cid),
                       "windows": {"before": before, "after": windows()}}
            with open(log, "a") as fh:
                fh.write(json.dumps({"id": cid, **result}) + "\n")


def real(data_root, version, cid="stage3-real"):
    """Both arms on the stage 0 data, then one holdout batch with Holm within each arm. One attempt only."""
    check_frozen()
    work = OUT / cid
    if work.exists():
        sys.exit(f"{work} exists: arm A runs once on real data")
    wait_for_room(OUT / "agent-null.jsonl")
    market = work / "m"
    market.mkdir(parents=True)
    for name, target in [("store", Path(data_root) / "store"), ("holdout", Path(data_root) / "holdout"),
                         ("venue", REPO / "venue/hyperliquid")]:
        (market / name).symlink_to(Path(target).resolve())
    (market / "version").write_text(f"{int(version)}\n")
    ledger = work / "ledger.sqlite"
    run, report_a, mech, kept_a = arm_a(market, ledger, cid, work / "run")
    sweep.require_frozen_searcher()
    spent_b = search.run("G100", market, ledger, cid, markets.seed(cid))
    finalists_b, report_b = gate.search_decision(ledger, cid, "G100")
    kept_b = gate.programs(ledger, cid, finalists_b, "G100")
    gate.freeze(ledger, cid, kept_a, "frozen finalist A")
    gate.freeze(ledger, cid, kept_b, "frozen finalist B")
    results = gate.holdout_run(market, ledger, cid, {**kept_a, **kept_b}, REAL_REPORT_FROM)
    promoted_a, holdout_a = gate.with_diagnostics(gate.promote({h: results[h] for h in kept_a}), results)
    promoted_b, holdout_b = gate.with_diagnostics(gate.promote({h: results[h] for h in kept_b}), results)
    result = {"id": cid, "version": int(version), "label": LABEL, "qualifications": "PROGRESS.md, Qualifications, stage 3", "agent_run": run, "audit": audit_run(work / "run", ledger, cid),
              "bankrupt": gate.bankrupt(ledger), "usage": usage(work),
              "A": {"evaluations": run["spent"], "search": report_a, "mechanism": mech, "kept": list(kept_a),
                    "holdout": holdout_a, "promoted": promoted_a},
              "B": {"evaluations": spent_b, "search": report_b, "kept": list(kept_b), "holdout": holdout_b,
                    "promoted": promoted_b}}
    result["comparison"] = comparison(result, ledger)
    (REPO / "audit/stage3/real.json").write_text(json.dumps(result, indent=1) + "\n")


def comparison(result, ledger):
    """Per arm: evaluations, distinct canonical strategies, N, SPA p-value, screened count, finalists,
    mechanism failures, each finalist's holdout return, bootstrap and Holm p-values, and promotions."""
    db = sqlite3.connect(ledger)
    out = {}
    for arm, agent in (("A", "A"), ("B", "G100")):
        r = result[arm]
        distinct = db.execute("SELECT COUNT(DISTINCT equivalence) FROM experiments WHERE campaign = ? AND agent = ?",
                              (result["id"], agent)).fetchone()[0]
        h = r["holdout"]
        out[arm] = {"evaluations": r["evaluations"], "distinct_canonical": distinct, "N": r["search"]["n"],
                    "spa_p": r["search"]["spa_p"], "screened": len(r["search"]["screened"]), "finalists": r["search"]["finalists"],
                    "mechanism_failures": [k for k, m in r.get("mechanism", {}).items() if not m["pass"]],
                    "holdout": {k: {"return": h["holdout_total_return"][k], "p": h["holdout_p"][k], "holm": h["holm"][k]}
                                for k in h.get("holm", {})},
                    "promotions": r["promoted"]}
    out["statement"] = NO_CLAIM
    return out


def spread(xs):
    xs = sorted(x for x in xs if x is not None)
    return {"n": len(xs), "min": xs[0], "median": xs[len(xs) // 2], "max": xs[-1]} if xs else None


def spreads(rows):
    s = [r["search"] for r in rows if "search" in r]
    return {"spa_p": spread([x["spa_p"] for x in s]), "max_dsr": spread([x.get("max_dsr") for x in s]),
            "screened": spread([len(x["screened"]) for x in s])}


BASELINE = {"agent": "G100", "swarm": "H400"}


def summary(name, out):
    """A null series (`agent` or `swarm`): campaigns, counted promotions, evaluations and history use,
    and the spreads of SPA p-values, maximum DSR and screened counts beside its baseline searcher's
    complete-null N2 runs."""
    searcher = BASELINE[name]
    log = OUT / f"{name}-null.jsonl"
    rows = [json.loads(l) for l in open(log)] if log.exists() else []
    baseline = [r for r in sweep.results("null") if r["id"].startswith(f"c24{sweep.ROUND}-N2-{searcher}-")]
    report = {"n": len(rows), "counted_promotions": sum(r["counts_as_promotion"] for r in rows),
              "evaluations": [r.get("evaluations", r.get("agent_run", {}).get("spent")) for r in rows],
              "cross_agent_history": [r.get("cross_agent_history") for r in rows],
              "spreads": spreads(rows), f"{searcher}_null_n2": spreads(baseline), "statement": SMOKE[name],
              "qualifications": f"PROGRESS.md, Qualifications, stage {STAGE[name]}"} | ({"label": LABEL} if name == "agent" else {})
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
