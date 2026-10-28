"""Agent campaigns: the sandboxed research agent (arm A) and the swarm on null markets as smoke tests, and the one
real campaign (arm A against the G100 searcher, one holdout batch); null series are paced and resumable."""

import json
import sqlite3
import sys
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
LABEL = "pipeline validation run, not a test for edge (stage 3 revision of 2026-10-23)"
MIN_SWARM_EVALUATIONS = 200
SPACING = 5 * 3600
NO_CLAIM = "One campaign per arm supports no claim that either generator is better."
SMOKE = {"agent": "20 runs bound the promotion rate only to about 0.28; this is a smoke test.",
         "swarm": "With 10 runs the 95% bound is about 0.39; this is a smoke test only."}


def freeze_harness():
    if FROZEN.exists():
        sys.exit(f"{FROZEN} exists: the harness is frozen once")
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    FROZEN.write_text(json.dumps({"harness": harness.harness_hash(), "frozen": now_ms()}, indent=1) + "\n")


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


def run_series(name, n):
    """Campaigns `{name}-null-N2-0` .. n - 1, resumable and paced (module docstring)."""
    check_frozen()
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / f"{name}-null.jsonl"
    with campaign.resume([f"{name}-null-N2-{i}" for i in range(n)], log, OUT) as todo:
        for k, cid in enumerate(todo):
            while not session.available(harness.MODEL):
                time.sleep(session.RETRY)
            started = time.time()
            try:
                result = SERIES[name](cid, sweep.cost_cells())
            except Exception as e:
                result = {"crash": repr(e), "counts_as_promotion": True}
            result["seconds"] = round(time.time() - started)
            with open(log, "a") as fh:
                fh.write(json.dumps({"id": cid, **result}) + "\n")
            if k < len(todo) - 1:
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
