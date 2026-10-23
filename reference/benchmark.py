"""C6.5's measurements on the differential corpus's frozen N2 market (550 days): the W0 replay benchmark (median
of 5, end to end and evaluator only) and null-simulation throughput in completed program-market-years per second.

`freeze` builds, then records the hardware, toolchains, the git trees of `kernel/` and `reference/` (which must
be clean), the built binaries' sha256 and the inputs before any measurement (`audit/stage6/benchmark-manifest.json`);
`run` builds again and refuses to measure if any of them differs. Each timed process's thread count is
sampled while it runs and reported; processes run one at a time. `mm` end to end is `mm eval` (parquet load, run, ledger). `refmm` end to
end is `refmm run` on the market `mmdump` writes. `mmdump`, timed separately, loads the store, writes that
market and also runs `mm`'s simulator and machine. Evaluator-only times exclude loading.
"""

import hashlib
import json
import os
import platform
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

from gate import kernel
from reference import differential as diff

REPO = diff.REPO
MANIFEST = diff.AUDIT / "benchmark-manifest.json"
REPS = 5
THROUGHPUT_PROGRAMS = 100


THREADS = []


def wall(cmd):
    """Milliseconds of one run of `cmd`, sampling its thread count into THREADS while it runs."""
    t = time.perf_counter()
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    most = 0
    while proc.poll() is None:
        try:
            most = max(most, len(os.listdir(f"/proc/{proc.pid}/task")))
        except OSError:
            pass
        time.sleep(0.002)
    ms = (time.perf_counter() - t) * 1e3
    if proc.returncode:
        raise subprocess.CalledProcessError(proc.returncode, cmd)
    THREADS.append(most)
    return ms


def version(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()


def configuration():
    """What the measurement depends on, besides the code at HEAD: hardware, toolchains, build profiles, inputs."""
    corpus = [json.loads(l) for l in (diff.AUDIT / diff.CORPUS).read_text().splitlines()]
    w0 = next(it["program"] for it in corpus if it["name"] == "W0")
    programs = [it["program"] for it in corpus if it["name"].startswith("gen-")][:THROUGHPUT_PROGRAMS]
    cpu = next((l.split(":", 1)[1].strip() for l in Path("/proc/cpuinfo").read_text().splitlines() if l.startswith("model name")), None)
    return {
        "hardware": {"cpu": cpu, "logical_cpus": os.cpu_count(), "kernel": platform.release()},
        "builds": {"rustc": version(["rustc", "--version"]), "lean": version(["lean", "--version"]),
                   "trees": {d: version(["git", "rev-parse", f"HEAD:{d}"]) for d in ("kernel", "reference")},
                   "dirty": version(["git", "status", "--porcelain", "kernel", "reference"]),
                   "binaries": {str(b.relative_to(REPO)): hashlib.sha256(b.read_bytes()).hexdigest()
                                for b in (kernel.MM, diff.REF, diff.DUMP)}},
        "inputs": {"differential_manifest_sha256": diff.sha((diff.AUDIT / diff.MANIFEST).read_text()),
                   "w0_sha256": diff.sha(w0), "throughput_programs_sha256": diff.sha("\n".join(programs)),
                   "reps": REPS, "throughput_programs": THROUGHPUT_PROGRAMS},
    }, w0, programs


def freeze():
    if MANIFEST.exists():
        raise FileExistsError(MANIFEST)
    diff.build()
    config = configuration()[0]
    if config["builds"]["dirty"]:
        raise ValueError("kernel/ or reference/ has uncommitted changes")
    MANIFEST.write_text(json.dumps(config, indent=1) + "\n")
    return str(MANIFEST)


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
    r = subprocess.run([str(diff.REF), "bench", str(f), str(market), str(reps)], capture_output=True, text=True, check=True)
    return json.loads(r.stdout)


def throughput(times):
    done = [t[0] for t in times if t is not None]
    years = len(done) * diff.DAYS / 365
    return {"programs": len(times), "completed": len(done), "program_market_years": years,
            "evaluator_seconds": sum(done) / 1e3, "per_second": years / (sum(done) / 1e3)}


def run(out):
    frozen = json.loads(MANIFEST.read_text())
    diff.build()
    now, w0, programs = configuration()
    changed = [k for k in ("hardware", "inputs", "builds") if now[k] != frozen[k]]
    if changed:
        raise ValueError(f"the configuration differs from the frozen one: {changed}")
    manifest = json.loads((diff.AUDIT / diff.MANIFEST).read_text())
    work = Path(tempfile.mkdtemp(dir=REPO / "data"))
    root = diff.null_market(work / "N2", "N2", manifest["seed"])
    if diff.market_hash(root) != manifest["markets"]["N2"]["market_sha256"]:
        raise ValueError("N2 does not rebuild as frozen")
    store, venue = root / "store", root / "venue"
    (work / "w0.json").write_text(w0)
    mm_e2e = [wall([str(kernel.MM), "eval", str(work / "w0.json"), "--campaign", "benchmark", "--agent", "bench",
                    "--store", str(store), "--venue", str(venue), "--ledger", str(work / f"l{i}.sqlite")]) for i in range(REPS)]
    mmdump = [wall([str(diff.DUMP), str(work / "w0.json"), str(store), str(venue), "1", str(work / "mk.json"), str(work / "a.json"),
                    str(work / "sa.bin")]) for _ in range(REPS)]
    ref_e2e = [wall([str(diff.REF), "run", str(work / "w0.json"), str(work / "mk.json"), str(work / "b.json"), str(work / "sb.bin")])
               for _ in range(REPS)]
    mm_eval = mm_evaluator(store, venue, [w0], REPS, work)[0]
    ref_eval = ref_evaluator(w0, work / "mk.json", REPS, work)
    mm_tp = mm_evaluator(store, venue, programs, 1, work)
    ref_tp = [ref_evaluator(p, work / "mk.json", 1, work) for p in programs]
    med = statistics.median
    report = {
        "manifest_sha256": hashlib.sha256(MANIFEST.read_bytes()).hexdigest(), "end_to_end_threads_sampled_max": max(THREADS),
        "replay_w0_ms": {
            "mm": {"end_to_end_median": med(mm_e2e), "end_to_end": mm_e2e, "evaluator_median": med(mm_eval), "evaluator": mm_eval},
            "refmm": {"end_to_end_median": med(ref_e2e), "end_to_end": ref_e2e, "evaluator_median": med(ref_eval), "evaluator": ref_eval},
            "mmdump_load_write_and_mm_run_median": med(mmdump),
        },
        "throughput": {"mm": throughput(mm_tp), "refmm": throughput(ref_tp)},
        "agree_on_completion": [a is None for a in mm_tp] == [b is None for b in ref_tp],
    }
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    return {k: report[k] for k in ("replay_w0_ms", "agree_on_completion")}
