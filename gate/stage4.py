"""Stage 4 C4.5: swarm null smoke campaigns (4 sandboxed agents sharing history) on N2 markets.
`python -m gate.stage4 N` runs campaigns 0..N-1; `report` applies C4.5."""

import json
import sys
import time

from gate import gate, markets, stage3, sweep
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


def report_c45():
    rows = [json.loads(l) for l in open(OUT / "c45.jsonl")]
    promoted = sum(r["counts_as_promotion"] for r in rows)
    h400 = [r for r in sweep.results("c24") if r["id"].startswith("c24-N2-H400-")]
    return {"n": len(rows), "counted_promotions": promoted, "pass": len(rows) == 10 and promoted <= 1,
            "evaluations": [r.get("evaluations") for r in rows], "cross_agent_history": [r.get("cross_agent_history") for r in rows],
            "swarm": stage3.summary(rows), "h400_c24_n2": stage3.summary(h400),
            "statement": "With 10 runs the 95% bound is about 0.39; this is a smoke test only."}


if __name__ == "__main__":
    if sys.argv[1] == "report":
        print(json.dumps(report_c45(), indent=1))
        sys.exit()
    stage3.check_frozen()
    out = OUT / "c45.jsonl"
    done = {json.loads(l)["id"] for l in open(out)} if out.exists() else set()
    for i in range(int(sys.argv[1])):
        if f"c45-N2-{i}" not in done:
            with open(out, "a") as fh:
                fh.write(json.dumps(swarm_campaign(i, sweep.cost_cells())) + "\n")
