"""One baseline-searcher campaign on a simulated market: market -> searcher -> gate -> holdout.

A campaign runs in its own directory, whose existence marks it started. Its ledger is kept there, xz-compressed,
with the holdout's spent record; the simulated market is deleted, since its id regenerates it. A crash is recorded
as a result with "crash" set, and counts as a promotion; so does a campaign started and never recorded.
"""

import fcntl
import json
import lzma
import shutil
import time
import traceback
from contextlib import contextmanager
from pathlib import Path

from gate import gate, markets, search


def run_campaign(spec, out):
    """spec: {"id", "model", "params", "searcher", "planted", "beta", "cost_cells", "days", "holdout_days"}."""
    t0 = time.time()
    work = Path(out) / spec["id"]
    work.mkdir(parents=True)
    root = work / "m"
    try:
        markets.write(root, markets.generate(spec["model"], spec["params"], spec["id"], spec["days"],
                                             spec.get("planted", ()), spec.get("beta", 0.0), spec.get("events")),
                      spec["holdout_days"], spec["cost_cells"])
        ledger = root / "ledger.sqlite"
        spent = search.run(spec["searcher"], root, ledger, spec["id"], markets.seed(spec["id"]))
        finalists, report = gate.search_decision(ledger, spec["id"])
        gate.freeze(ledger, spec["id"], finalists, "finalist")
        programs = gate.programs(ledger, spec["id"], finalists)
        promoted, holdout = gate.holdout_decision(root, ledger, spec["id"], programs)
        top = gate.programs(ledger, spec["id"], report.get("top5", []))
        result = {"spent": spent, "search": report, "holdout": holdout, "bankrupt": gate.bankrupt(ledger),
                  "promoted": [{"hash": h, "program": programs[h]} for h in promoted],
                  "top5": [{"hash": h, "program": top[h]} for h in report.get("top5", [])]}
    except Exception:
        result = {"crash": traceback.format_exc()}
    for kept in ("ledger.sqlite", "holdout/spent.jsonl"):
        if (root / kept).exists():
            (work / f"{Path(kept).name}.xz").write_bytes(lzma.compress((root / kept).read_bytes()))
    shutil.rmtree(root, ignore_errors=True)
    out = {k: v for k, v in spec.items() if k not in ("params", "events")}
    return {**out, **result, "seconds": round(time.time() - t0, 1)}


def recorded(path):
    return {json.loads(l)["id"] for l in open(path)} if Path(path).exists() else set()


@contextmanager
def exclusive(log):
    """`log` opened for appending under an exclusive lock held for the run's lifetime (released when its last process,
    pool workers included, exits), so a second run of the same log fails at once."""
    with open(log, "a") as fh:
        try:
            fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError(f"another run of {log} is alive") from None
        yield fh


@contextmanager
def resume(ids, log, out):
    """The ids still to run, for the duration of the run. One whose directory under `out` exists with no result in
    `log` was started and interrupted: it is recorded as a crash, which counts as a promotion, and never rerun. That
    holds only if no other run of `log` is alive, which `exclusive` ensures."""
    with exclusive(log) as fh:
        done, todo = recorded(log), []
        for i in ids:
            if i in done:
                continue
            if (Path(out) / i).exists():
                crash = {"id": i, "crash": "interrupted before its result was recorded", "counts_as_promotion": True}
                fh.write(json.dumps(crash) + "\n")
            else:
                todo.append(i)
        fh.flush()
        yield todo


def promoted_anything(result):
    return bool(result.get("crash")) or bool(result.get("promoted"))
