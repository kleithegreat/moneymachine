"""Stage 3 campaigns (PROGRESS.md, Stage 3): arm A (sandboxed LLM agent), arm B (G100), one holdout.

Null smoke runs (C3.2) use arm A alone on N2 markets whose holdout report window mirrors the
real campaign's post-cutoff window.
"""

import json
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

from gate import gate, markets, search
from gate.agent import harness

REPO = Path(__file__).resolve().parents[1]
MM = REPO / "kernel/target/release/mm"
OUT = REPO / "data" / "stage3"
DAY = 24 * 3_600_000
BUDGET = 100
NULL_REPORT_FROM_DAY = 640
REAL_REPORT_FROM = 1782864000000  # 2026-07-01, after the agent model's knowledge cutoff (June 2026)
PERMITTED = {"Read", "Write", "Bash"}


def mechanism_check(market, ledger, campaign, programs):
    """For each finalist: its prediction's test on the search period (never disclosed to the agent)."""
    m = Path(market)
    out = {}
    for h, prog in programs.items():
        if "prediction" not in prog:
            out[h] = {"pass": False, "reason": "no prediction"}
            continue
        p = m / f"mech-{h[:16]}.json"
        p.write_text(json.dumps(prog))
        r = subprocess.run([str(MM), "eval", str(p), "--campaign", campaign, "--agent", "gate-mechanism", "--mechanism", "on",
                            "--store", str(m / "store"), "--venue", str(m / "venue"), "--policy", str(m / "policy.json"),
                            "--ledger", str(ledger)], capture_output=True, text=True, check=True)
        out[h] = json.loads(r.stdout)["disclosure"]["result"]["mechanism"]
        p.unlink()
    return out


def audit(run_dir, ledger, campaign, agent="A"):
    """C3.1 for one agent run: daemon log vs ledger rows, and no tool call outside the permitted set."""
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


def arm_a(market, ledger, campaign, run_dir):
    run = harness.run_agent(market, ledger, campaign, run_dir, budget=BUDGET)
    finalists, report = gate.search_decision(ledger, campaign, "A")
    programs = gate.programs(ledger, finalists)
    mech = mechanism_check(market, ledger, campaign, programs)
    kept = {h: p for h, p in programs.items() if mech[h]["pass"]}
    return run, report, mech, kept


def freeze(ledger, campaign, hashes, arm):
    for h in hashes:
        subprocess.run([str(MM), "select", h, "--campaign", campaign, "--agent", "gate", "--note", f"frozen finalist {arm}",
                        "--ledger", str(ledger)], check=True, capture_output=True)


def null_campaign(i, cost_cells):
    cid = f"c32-N2-{i}"
    work = OUT / cid
    params = json.loads((REPO / "gate/nulls.json").read_text())["N2"]
    t0 = time.time()
    try:
        market = markets.write(work / "m", markets.generate("N2", params, cid, 730), 180, cost_cells)
        ledger = work / "ledger.sqlite"
        run, report, mech, kept = arm_a(market, ledger, cid, work / "run")
        freeze(ledger, cid, kept, "A")
        promoted, holdout = gate.holdout_decision(MM, market, ledger, cid, kept, NULL_REPORT_FROM_DAY * DAY)
        result = {"id": cid, "agent_run": run, "search": report, "mechanism": mech, "kept": list(kept),
                  "holdout": holdout, "promoted": promoted, "audit": audit(work / "run", ledger, cid)}
    except Exception as e:
        result = {"id": cid, "crash": repr(e)}
    result["seconds"] = round(time.time() - t0)
    return result


def real_campaign(data_root, version, cid="stage3-real"):
    """Both arms on the stage 0 data, then one holdout batch with Holm within each arm. One attempt only."""
    work = OUT / cid
    if work.exists():
        sys.exit(f"{work} exists: arm A runs once on real data")
    work.mkdir(parents=True)
    market = work / "m"
    market.mkdir()
    for name, target in [("store", Path(data_root) / "store"), ("holdout", Path(data_root) / "holdout"),
                         ("venue", REPO / "venue/hyperliquid"), ("policy.json", REPO / "policy.json")]:
        (market / name).symlink_to(Path(target).resolve())
    ledger = work / "ledger.sqlite"
    run, report_a, mech, kept_a = arm_a(market, ledger, cid, work / "run")
    search.run("G100", MM, market, ledger, cid, markets.seed_of(cid))
    finalists_b, report_b = gate.search_decision(ledger, cid, "G100")
    kept_b = gate.programs(ledger, finalists_b)
    freeze(ledger, cid, kept_a, "A")
    freeze(ledger, cid, kept_b, "B")
    results = gate.holdout_run(MM, market, ledger, cid, {**kept_a, **kept_b}, REAL_REPORT_FROM)
    promoted_a, holdout_a = gate.promote({h: results[h] for h in kept_a}, cid + "A")
    promoted_b, holdout_b = gate.promote({h: results[h] for h in kept_b}, cid + "B")
    return {"id": cid, "version": version, "agent_run": run, "audit": audit(work / "run", ledger, cid),
            "A": {"search": report_a, "mechanism": mech, "kept": list(kept_a), "holdout": holdout_a, "promoted": promoted_a},
            "B": {"search": report_b, "kept": list(kept_b), "holdout": holdout_b, "promoted": promoted_b}}
