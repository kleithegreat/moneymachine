"""One stage 2 campaign: market -> searcher -> gate -> holdout, appended to a campaign log.

A crash is recorded as a result with "crash" set; C2.4 counts it as a promotion.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from pathlib import Path

from gate import gate, markets, search

REPO = Path(__file__).resolve().parents[1]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"


def run_campaign(spec, keep=None):
    """spec: {"id", "model", "params", "searcher", "planted", "beta", "cost_cells", "days", "holdout_days"}."""
    t0 = time.time()
    work = Path(tempfile.mkdtemp(prefix="campaign-"))
    try:
        root = markets.write(work / "m", markets.generate(spec["model"], spec["params"], spec["id"], spec["days"],
                                                          spec.get("planted", ()), spec.get("beta", 0.0), spec.get("events")),
                             spec["holdout_days"], spec["cost_cells"])
        ledger = root / "ledger.sqlite"
        spent = search.run(spec["searcher"], MM, root, ledger, spec["id"], markets.seed_of(spec["id"]))
        finalists, report = gate.search_decision(ledger, spec["id"])
        for h in finalists:
            subprocess.run([str(MM), "select", h, "--campaign", spec["id"], "--agent", "gate", "--note", "finalist",
                            "--ledger", str(ledger)], check=True, capture_output=True)
        programs = gate.programs(ledger, finalists)
        promoted, holdout = gate.holdout_decision(MM, root, ledger, spec["id"], programs)
        top = gate.programs(ledger, report.get("top5", []))
        result = {"spent": spent, "search": report, "holdout": holdout,
                  "promoted": [{"hash": h, "program": programs[h]} for h in promoted],
                  "top5": [{"hash": h, "program": top[h]} for h in report.get("top5", [])]}
        if keep:
            shutil.copytree(root, Path(keep) / spec["id"], dirs_exist_ok=True)
    except Exception:
        result = {"crash": traceback.format_exc()}
    finally:
        shutil.rmtree(work, ignore_errors=True)
    out = {k: v for k, v in spec.items() if k not in ("params", "events")}
    return {**out, **result, "seconds": round(time.time() - t0, 1)}


def promoted_anything(result):
    return bool(result.get("crash")) or bool(result.get("promoted"))


if __name__ == "__main__":
    spec = json.loads(sys.argv[1])
    print(json.dumps(run_campaign(spec)))
