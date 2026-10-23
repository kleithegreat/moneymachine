"""C6.5's measurements, on C6.4's frozen N2 market (550 days): the W0 replay benchmark (median of 5,
end to end and evaluator only) and null-simulation throughput in completed program-market-years per second.

Both kernels run single-threaded, one process at a time, on the release builds `c64.build` makes.
`mm` end to end is `mm eval` (parquet load, run, ledger). `refmm` end to end is `refmm run` on the market
`mmdump` exports, whose export time is reported separately. Evaluator-only times exclude loading.
"""

import json
import os
import platform
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

from gate import kernel
from reference import c64

REPO = c64.REPO
THROUGHPUT_PROGRAMS = 100


def wall(cmd, **kw):
    t = time.perf_counter()
    subprocess.run(cmd, check=True, capture_output=True, **kw)
    return (time.perf_counter() - t) * 1e3


def mm_evaluator(store, venue, programs, reps, work):
    src, out = work / "programs.jsonl", work / "times.jsonl"
    src.write_text("".join(json.dumps(json.loads(p)) + "\n" for p in programs))
    env = os.environ | {"MM_STORE": str(store), "MM_VENUE": str(venue), "MM_VERSION": "1", "MM_PROGRAMS": str(src),
                        "MM_REPS": str(reps), "MM_OUT": str(out)}
    subprocess.run(["cargo", "test", "-q", "--release", "--test", "bench", "evaluator_times", "--", "--ignored"],
                   cwd=REPO / "kernel", env=env, check=True, capture_output=True)
    return [json.loads(l) for l in out.read_text().splitlines()]


def ref_evaluator(program, market, reps, work):
    f = work / "p.json"
    f.write_text(program)
    r = subprocess.run([str(c64.REF), "bench", str(f), str(market), str(reps)], capture_output=True, text=True, check=True)
    return json.loads(r.stdout)


def throughput(times, days):
    done = [t[0] for t in times if t is not None]
    years = len(done) * days / 365
    return {"programs": len(times), "completed": len(done), "program_market_years": years,
            "evaluator_seconds": sum(done) / 1e3, "per_second": years / (sum(done) / 1e3)}


def main(out):
    manifest = json.loads((c64.AUDIT / "c64-manifest.json").read_text())
    corpus = [json.loads(l) for l in (c64.AUDIT / "c64-corpus.jsonl").read_text().splitlines()]
    w0 = (REPO / "kernel/strategies/w0.json").read_text()
    programs = [it["program"] for it in corpus if it["name"].startswith("gen-")][:THROUGHPUT_PROGRAMS]
    c64.build()
    work = Path(tempfile.mkdtemp(dir=REPO / "data"))
    root = c64.null_market(work / "N2", "N2", manifest["seed"])
    if c64.store_hash(root) != manifest["markets"]["N2"]["store_sha256"]:
        raise ValueError("N2 does not rebuild as frozen")
    store, venue = root / "store", root / "venue"
    (work / "w0.json").write_text(w0)
    mm_e2e = [wall([str(kernel.MM), "eval", str(work / "w0.json"), "--campaign", "c65-bench", "--agent", "bench",
                    "--store", str(store), "--venue", str(venue), "--ledger", str(work / f"l{i}.sqlite")]) for i in range(5)]
    export = [wall([str(c64.DUMP), str(work / "w0.json"), str(store), str(venue), "1", str(work / "mk.json"), str(work / "a.json")])
              for _ in range(5)]
    ref_e2e = [wall([str(c64.REF), "run", str(work / "w0.json"), str(work / "mk.json"), str(work / "b.json")]) for _ in range(5)]
    mm_eval = mm_evaluator(store, venue, [w0], 5, work)[0]
    ref_eval = ref_evaluator(w0, work / "mk.json", 5, work)
    mm_tp = mm_evaluator(store, venue, programs, 1, work)
    ref_tp = [ref_evaluator(p, work / "mk.json", 1, work) for p in programs]
    cpu = next((l.split(":", 1)[1].strip() for l in Path("/proc/cpuinfo").read_text().splitlines() if l.startswith("model name")), None)
    med = statistics.median
    report = {
        "hardware": {"cpu": cpu, "logical_cpus": os.cpu_count(), "kernel": platform.release(), "threads": 1},
        "builds": {"mm": "cargo --release (kernel/Cargo.toml profile)", "refmm": "lake build (reference/lean, Lean 4.34.0)"},
        "input": {"market": "C6.4 N2", "store_sha256": manifest["markets"]["N2"]["store_sha256"], "days": c64.DAYS},
        "replay_w0_ms": {
            "mm": {"end_to_end_median": med(mm_e2e), "end_to_end": mm_e2e, "evaluator_median": med(mm_eval), "evaluator": mm_eval},
            "refmm": {"end_to_end_median": med(ref_e2e), "end_to_end": ref_e2e, "evaluator_median": med(ref_eval), "evaluator": ref_eval,
                      "mmdump_export_median": med(export)},
        },
        "throughput": {"programs": f"the first {THROUGHPUT_PROGRAMS} generated programs of the C6.4 corpus",
                       "mm": throughput(mm_tp, c64.DAYS), "refmm": throughput(ref_tp, c64.DAYS)},
        "agree_on_completion": [a is None for a in mm_tp] == [b is None for b in ref_tp],
    }
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    return {k: report[k] for k in ("replay_w0_ms", "agree_on_completion")}
