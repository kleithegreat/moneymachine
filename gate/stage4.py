"""Stage 4 C4.5: swarm null smoke campaigns (4 sandboxed agents sharing history) on N2 markets."""

import json
import sys
import time
from pathlib import Path

from gate import gate, markets, stage3
from gate.agent import harness

OUT = stage3.OUT
MIN_EVALUATIONS = 200


def cross_agent_history(run_dirs):
    """Whether any agent received history containing another agent's evaluations."""
    for d in run_dirs:
        agent = d.name
        for line in open(d / "daemon.log"):
            e = json.loads(line)
            if e["cmd"] == "history" and any(r.get("agent") != agent for r in e["response"].get("evaluations", [])):
                return True
    return False


def swarm_campaign(i, cost_cells):
    cid = f"c45-N2-{i}"
    work = OUT / cid
    params = json.loads((stage3.REPO / "gate/nulls.json").read_text())["N2"]
    t0 = time.time()
    try:
        market = markets.write(work / "m", markets.generate("N2", params, cid, 730), 180, cost_cells)
        ledger = work / "ledger.sqlite"
        swarm = harness.run_swarm(market, ledger, cid, work / "swarm")
        finalists, report = gate.search_decision(ledger, cid)
        programs = gate.programs(ledger, finalists)
        mech = stage3.mechanism_check(market, ledger, cid, programs)
        kept = {h: p for h, p in programs.items() if mech[h]["pass"]}
        stage3.freeze(ledger, cid, kept, "swarm")
        promoted, holdout = gate.holdout_decision(stage3.MM, market, ledger, cid, kept, stage3.NULL_REPORT_FROM_DAY * stage3.DAY)
        run_dirs = [work / "swarm" / r["agent"] for r in swarm["runs"]]
        result = {"id": cid, "runs": swarm["runs"], "evaluations": swarm["evaluations"], "search": report,
                  "mechanism": mech, "kept": list(kept), "holdout": holdout, "promoted": promoted,
                  "cross_agent_history": cross_agent_history(run_dirs),
                  "audits": {d.name: stage3.audit(d, ledger, cid, d.name) for d in run_dirs}}
        result["counts_as_promotion"] = bool(promoted) or swarm["evaluations"] < MIN_EVALUATIONS
    except Exception as e:
        result = {"id": cid, "crash": repr(e), "counts_as_promotion": True}
    result["seconds"] = round(time.time() - t0)
    return result


if __name__ == "__main__":
    from gate.sweep import cost_cells

    out = OUT / "c45.jsonl"
    done = {json.loads(l)["id"] for l in open(out)} if out.exists() else set()
    for i in range(int(sys.argv[1])):
        if f"c45-N2-{i}" not in done:
            with open(out, "a") as fh:
                fh.write(json.dumps(swarm_campaign(i, cost_cells())) + "\n")
