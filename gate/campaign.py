"""One baseline-searcher campaign on a simulated market: market -> searcher -> gate -> holdout.

A crash is recorded as a result with "crash" set, and counts as a promotion.
"""

import shutil
import tempfile
import time
import traceback
from pathlib import Path

from gate import gate, markets, search
from gate.kernel import MM


def run_campaign(spec, keep=None):
    """spec: {"id", "model", "params", "searcher", "planted", "beta", "cost_cells", "days", "holdout_days"}."""
    t0 = time.time()
    work = Path(tempfile.mkdtemp(prefix="campaign-"))
    try:
        root = markets.write(work / "m", markets.generate(spec["model"], spec["params"], spec["id"], spec["days"],
                                                          spec.get("planted", ()), spec.get("beta", 0.0), spec.get("events")),
                             spec["holdout_days"], spec["cost_cells"])
        ledger = root / "ledger.sqlite"
        spent = search.run(spec["searcher"], MM, root, ledger, spec["id"], markets.market_seed(spec["id"]))
        finalists, report = gate.search_decision(ledger, spec["id"])
        gate.freeze(ledger, spec["id"], finalists, "finalist")
        programs = gate.programs(ledger, finalists)
        promoted, holdout = gate.holdout_decision(root, ledger, spec["id"], programs)
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

