"""fastmm against mm and refmm, evaluator only, as C6.5 measured them (the spent reference/benchmark.py, in git at
e58b2e6^): W0's replay on the frozen N2 (median of 5) and null-simulation throughput on the first 100 generated
corpus programs (one run each). A diagnostic on branch lean-bench, not a judged measurement.

usage: fast_benchmark.py WORK OUT [refmm-throughput]   (WORK holds N2/, mk.json from mmdump, w0.json, tp/*.json)
"""

import json
import os
import statistics
import subprocess
import sys
from pathlib import Path

from reference import differential as diff

LEAN = diff.REPO / "reference/lean/.lake/build/bin"
REPS = 5


def mm_times(work, programs, reps):
    src, out = work / "programs.jsonl", work / "times.jsonl"
    src.write_text("".join(json.dumps(json.loads(p.read_text())) + "\n" for p in programs))
    env = os.environ | {"MM_STORE": str(work / "N2/store"), "MM_VENUE": str(work / "N2/venue"), "MM_VERSION": "1",
                        "MM_PROGRAMS": str(src), "MM_REPS": str(reps), "MM_OUT": str(out)}
    subprocess.run(["cargo", "test", "-q", "--release", "--offline", "--test", "bench", "evaluator_times", "--", "--ignored"],
                   cwd=diff.REPO / "kernel", env=env, check=True, capture_output=True)
    return [json.loads(l) for l in out.read_text().splitlines()]


def lean_times(exe, program, work, reps):
    r = subprocess.run([str(LEAN / exe), "bench", str(program), str(work / "mk.json"), str(reps)], capture_output=True,
                       text=True, check=True)
    return json.loads(r.stdout)


def throughput(times):
    done = [t[0] for t in times if t is not None]
    years = len(done) * diff.DAYS / 365
    return {"completed": len(done), "of": len(times), "program_market_years": years,
            "evaluator_seconds": sum(done) / 1e3, "per_second": years / (sum(done) / 1e3)}


def main(work, out, ref_throughput=None):
    work = Path(work)
    tp = sorted((work / "tp").glob("*.json"), key=lambda p: int(p.stem))
    w0 = {"mm": mm_times(work, [work / "w0.json"], REPS)[0],
          "fastmm": lean_times("fastmm", work / "w0.json", work, REPS),
          "refmm": lean_times("refmm", work / "w0.json", work, REPS)}
    report = {"w0_evaluator_ms": {k: {"median": statistics.median(v), "runs": v} for k, v in w0.items()},
              "throughput": {"mm": throughput(mm_times(work, tp, 1)),
                             "fastmm": throughput([lean_times("fastmm", p, work, 1) for p in tp])}}
    if ref_throughput:
        report["throughput"]["refmm"] = throughput([lean_times("refmm", p, work, 1) for p in tp])
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps({k: v["median"] for k, v in report["w0_evaluator_ms"].items()}),
          json.dumps({k: round(v["per_second"], 2) for k, v in report["throughput"].items()}))


if __name__ == "__main__":
    main(*sys.argv[1:])
