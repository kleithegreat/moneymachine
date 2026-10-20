"""Agent campaigns: the single sandboxed research agent (arm A) and the swarm, on null markets as smoke
tests, and the one real campaign (arm A against the G100 searcher, one holdout batch).

Agent runs spend a usage-limited subscription, and an interrupted campaign still counts, so null
series are resumable and paced: a campaign starts only after a tiny model call succeeds, campaign
starts are SPACING apart, and a rerun skips recorded ids. A campaign whose work directory exists
without a recorded result was started and interrupted, and is recorded as a crash. Every runner
refuses a harness that differs from the frozen one.
"""

import json
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

from gate import gate, markets, search, sweep
from gate.agent import harness
from gate.kernel import MM
from ingest.policy import DAY

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "data" / "agent"
FROZEN = REPO / "audit/stage3/harness.json"
BUDGET = 100
NULL_DAYS, NULL_HOLDOUT_DAYS, NULL_REPORT_FROM_DAY = 730, 180, 640
REAL_REPORT_FROM = 1782864000000  # 2026-07-01, after the agent model's knowledge cutoff (June 2026)
PERMITTED = {"Read", "Write", "Bash"}
MIN_SWARM_EVALUATIONS = 200
SPACING = 5 * 3600
RETRY = 1800
NO_CLAIM = "One campaign per arm supports no claim that either generator is better."
SMOKE = {"agent": "20 runs bound the promotion rate only to about 0.28; this is a smoke test.",
         "swarm": "With 10 runs the 95% bound is about 0.39; this is a smoke test only."}


def freeze_harness():
    if FROZEN.exists():
        sys.exit(f"{FROZEN} exists: the harness is frozen once")
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    FROZEN.write_text(json.dumps({"harness": harness.harness_hash(), "frozen": int(time.time() * 1000)}, indent=1) + "\n")


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
    tools, denied = [], []
    for line in open(Path(run_dir) / "transcript.jsonl"):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("type") == "assistant":
            tools += [c["name"] for c in d["message"]["content"] if c.get("type") == "tool_use"]
        if d.get("type") == "result":
            denied = d.get("permission_denials", [])
    return {"daemon_evals": evals, "ledger_rows": rows, "history_calls": histories, "history_rows": history_rows,
            "match": evals == rows and histories == history_rows, "tools": sorted(set(tools)),
            "outside_permitted": sorted(set(tools) - PERMITTED), "denials": len(denied)}


def cross_agent_history(run_dirs):
    """Whether any agent received history containing another agent's evaluations."""
    for d in run_dirs:
        for line in open(d / "daemon.log"):
            e = json.loads(line)
            if e["cmd"] == "history" and any(r.get("agent") != d.name for r in e["response"].get("evaluations", [])):
                return True
    return False


def arm_a(market, ledger, campaign, run_dir):
    run = harness.run_agent(market, ledger, campaign, run_dir, budget=BUDGET)
    finalists, report = gate.search_decision(ledger, campaign, "A")
    programs = gate.programs(ledger, finalists)
    mech = gate.mechanism_check(market, ledger, campaign, programs)
    kept = {h: p for h, p in programs.items() if mech[h]["pass"]}
    return run, report, mech, kept


def null_market(cid, cost_cells):
    params = json.loads((REPO / "gate/nulls.json").read_text())["N2"]
    return markets.write(OUT / cid / "m", markets.generate("N2", params, cid, NULL_DAYS), NULL_HOLDOUT_DAYS, cost_cells)


def agent_null(cid, cost_cells):
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    run, report, mech, kept = arm_a(market, ledger, cid, OUT / cid / "run")
    gate.freeze(ledger, cid, kept, "frozen finalist A")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, NULL_REPORT_FROM_DAY * DAY)
    return {"agent_run": run, "search": report, "mechanism": mech, "kept": list(kept), "holdout": holdout,
            "promoted": promoted, "audit": audit_run(OUT / cid / "run", ledger, cid), "counts_as_promotion": bool(promoted)}


def swarm_null(cid, cost_cells):
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    swarm = harness.run_swarm(market, ledger, cid, OUT / cid / "swarm")
    finalists, report = gate.search_decision(ledger, cid)
    programs = gate.programs(ledger, finalists)
    mech = gate.mechanism_check(market, ledger, cid, programs)
    kept = {h: p for h, p in programs.items() if mech[h]["pass"]}
    gate.freeze(ledger, cid, kept, "frozen finalist swarm")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, NULL_REPORT_FROM_DAY * DAY)
    run_dirs = [OUT / cid / "swarm" / r["agent"] for r in swarm["runs"]]
    return {"runs": swarm["runs"], "evaluations": swarm["evaluations"], "search": report, "mechanism": mech,
            "kept": list(kept), "holdout": holdout, "promoted": promoted, "cross_agent_history": cross_agent_history(run_dirs),
            "audits": {d.name: audit_run(d, ledger, cid, d.name) for d in run_dirs},
            "counts_as_promotion": bool(promoted) or swarm["evaluations"] < MIN_SWARM_EVALUATIONS}


SERIES = {"agent": agent_null, "swarm": swarm_null}


def available():
    """Whether the agent model answers now: a tiny call before a campaign starts, so a spent
    subscription delays a campaign instead of interrupting one."""
    try:
        r = subprocess.run([harness.claude_binary(), "-p", "Reply with OK.", "--model", harness.MODEL, "--output-format", "json"],
                           capture_output=True, text=True, timeout=300)
        return r.returncode == 0 and not json.loads(r.stdout).get("is_error", True)
    except (subprocess.TimeoutExpired, json.JSONDecodeError):
        return False


def recorded(path):
    return {json.loads(l)["id"] for l in open(path)} if path.exists() else set()


def run_series(name, n):
    """Campaigns `{name}-null-N2-0` .. n - 1, resumable and paced (module docstring)."""
    check_frozen()
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / f"{name}-null.jsonl"
    done = recorded(log)
    for i in range(n):
        cid = f"{name}-null-N2-{i}"
        if cid in done:
            continue
        if (OUT / cid).exists():
            result = {"crash": "interrupted before its result was recorded", "counts_as_promotion": True}
        else:
            while not available():
                time.sleep(RETRY)
            started = time.time()
            try:
                result = SERIES[name](cid, sweep.cost_cells())
            except Exception as e:
                result = {"crash": repr(e), "counts_as_promotion": True}
            result["seconds"] = round(time.time() - started)
        with open(log, "a") as fh:
            fh.write(json.dumps({"id": cid, **result}) + "\n")
        if i < n - 1 and "seconds" in result:
            time.sleep(max(0, SPACING - result["seconds"]))


def real(data_root, version, cid="stage3-real"):
    """Both arms on the stage 0 data, then one holdout batch with Holm within each arm. One attempt only."""
    check_frozen()
    work = OUT / cid
    if work.exists():
        sys.exit(f"{work} exists: arm A runs once on real data")
    market = work / "m"
    market.mkdir(parents=True)
    for name, target in [("store", Path(data_root) / "store"), ("holdout", Path(data_root) / "holdout"),
                         ("venue", REPO / "venue/hyperliquid")]:
        (market / name).symlink_to(Path(target).resolve())
    ledger = work / "ledger.sqlite"
    run, report_a, mech, kept_a = arm_a(market, ledger, cid, work / "run")
    spent_b = search.run("G100", MM, market, ledger, cid, markets.market_seed(cid))
    finalists_b, report_b = gate.search_decision(ledger, cid, "G100")
    kept_b = gate.programs(ledger, finalists_b)
    gate.freeze(ledger, cid, kept_a, "frozen finalist A")
    gate.freeze(ledger, cid, kept_b, "frozen finalist B")
    results = gate.holdout_run(market, ledger, cid, {**kept_a, **kept_b}, REAL_REPORT_FROM)
    promoted_a, holdout_a = gate.promote({h: results[h] for h in kept_a}, cid + "A")
    promoted_b, holdout_b = gate.promote({h: results[h] for h in kept_b}, cid + "B")
    result = {"id": cid, "version": int(version), "agent_run": run, "audit": audit_run(work / "run", ledger, cid),
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
    baseline = [r for r in sweep.results("null") if r["id"].startswith(f"c24-N2-{searcher}-")]
    report = {"n": len(rows), "counted_promotions": sum(r["counts_as_promotion"] for r in rows),
              "evaluations": [r.get("evaluations", r.get("agent_run", {}).get("spent")) for r in rows],
              "cross_agent_history": [r.get("cross_agent_history") for r in rows],
              "spreads": spreads(rows), f"{searcher}_null_n2": spreads(baseline), "statement": SMOKE[name]}
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
