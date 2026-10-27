"""Fan a judged sweep out across hosts, and merge it back (human request of 2026-10-26; PROGRESS.md, homelab workers).

    python ops/fanout.py plan <job> <plan.json> <host>=<campaigns per hour> ...   job: mixed | truth
    python ops/fanout.py run <plan.json> <host>       on that host, from the plan's commit and binary
    python ops/fanout.py merge <plan.json> <dir>...   each dir a host's fanout/<job>/<host>: <job>.jsonl, <job>/<id>/

A plan, committed before any shard runs, fixes the commit, the `mm` binary's sha256, the searchers' pin, the betas'
hash and every id's host, assigned by smooth weighted round robin over the sweep's own order, so each host gets its
share of every cell. Results never depend on the host (`audit/crossmachine/freeze.md`). A shard is `sweep.run_all`
over its ids, so a started and unrecorded campaign is a crash, never rerun anywhere; only never-started ids may move
to another host, by a dated addendum to the plan. The merge requires every planned id exactly once and every ledger's
kernel to be the plan's, then writes the job's file in id order beside a manifest of each id's host."""

import hashlib
import json
import lzma
import sqlite3
import subprocess
import sys
import tempfile
from functools import partial
from multiprocessing import Pool
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from gate import campaign, compute, kernel, search, sweep  # noqa: E402


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def job_ids(job):
    betas = json.loads((sweep.OUT / "betas.json").read_text())
    if job == "mixed":
        return [s["id"] for s in sweep.mixed_specs(betas)]
    return [sweep.truth_id(r["id"], p["hash"]) for r in sweep.results("mixed") for p in r.get("promoted", [])]


def assign(ids, weights):
    """Smooth weighted round robin: every id to the host whose credit is highest after adding each host's weight."""
    credit, total, out = {h: 0.0 for h in weights}, sum(weights.values()), {}
    for i in ids:
        for h in weights:
            credit[h] += weights[h]
        h = max(credit, key=lambda k: (credit[k], k))
        credit[h] -= total
        out[i] = h
    return out


def plan(job, path, *hosts):
    weights = {h: float(w) for h, w in (x.split("=") for x in hosts)}
    ids = job_ids(job)
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip()
    Path(path).write_text(json.dumps({
        "job": job, "commit": commit, "mm_sha256": sha256(kernel.MM), "searcher": search.identity(),
        "betas_sha256": sha256(sweep.OUT / "betas.json"), "weights": weights, "assignment": assign(ids, weights)},
        indent=1) + "\n")
    counts = {h: sum(v == h for v in assign(ids, weights).values()) for h in weights}
    print(json.dumps({"ids": len(ids), "per_host": counts}))


def truth_one(tid, by_id, betas):
    cid, h = tid.rsplit("-", 1)
    _, model, cell, _ = cid.split("-")
    program = next(p["program"] for p in by_id[cid]["promoted"] if p["hash"] == h)
    return {"id": tid, "true": sweep.is_true(program, model, betas[f"{model}-{cell}"], tid)}


def run(path, host):
    p = json.loads(Path(path).read_text())
    if sha256(kernel.MM) != p["mm_sha256"] or search.identity() != p["searcher"] or \
            sha256(sweep.OUT / "betas.json") != p["betas_sha256"]:
        raise SystemExit("binary, searchers or betas differ from the plan")
    mine = [i for i, h in p["assignment"].items() if h == host]
    log = sweep.OUT / "fanout" / p["job"] / host / f"{p['job']}.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    if p["job"] == "mixed":
        betas = json.loads((sweep.OUT / "betas.json").read_text())
        sweep.run_all([s for s in sweep.mixed_specs(betas) if s["id"] in set(mine)], log)
        return
    todo = [i for i in mine if i not in campaign.recorded(log)]
    by_id, betas = {r["id"]: r for r in sweep.results("mixed")}, json.loads((sweep.OUT / "betas.json").read_text())
    with Pool(compute.workers(sweep.CALIBRATION_BYTES)) as pool, open(log, "a") as fh:
        for r in pool.imap_unordered(partial(truth_one, by_id=by_id, betas=betas), todo):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], r["true"], flush=True)


def kernels(ledger_xz):
    with tempfile.NamedTemporaryFile(suffix=".sqlite") as f:
        f.write(lzma.decompress(Path(ledger_xz).read_bytes()))
        f.flush()
        return {k for (k,) in sqlite3.connect(f.name).execute("select distinct kernel from experiments")}


def merge(path, *dirs):
    p = json.loads(Path(path).read_text())
    job, rows, where = p["job"], {}, {}
    for d in map(Path, dirs):
        for line in open(d / f"{job}.jsonl"):
            r = json.loads(line)
            if r["id"] in rows:
                raise SystemExit(f"{r['id']} recorded twice ({where[r['id']]} and {d})")
            rows[r["id"]], where[r["id"]] = r, d
    missing = set(p["assignment"]) - set(rows)
    extra = set(rows) - set(p["assignment"])
    if missing or extra:
        raise SystemExit(f"missing {sorted(missing)[:5]} ({len(missing)}), unplanned {sorted(extra)[:5]} ({len(extra)})")
    if job == "mixed":
        for i, d in where.items():
            ledger = d / job / i / "ledger.sqlite.xz"
            if ledger.exists() and kernels(ledger) - {p["mm_sha256"]}:
                raise SystemExit(f"{i}: a kernel other than the plan's")
    target = sweep.OUT / f"{job}.jsonl"
    if target.exists():
        raise SystemExit(f"{target} exists")
    with open(target, "w") as fh:
        for i in sorted(rows):
            fh.write(json.dumps(rows[i]) + "\n")
    if job == "mixed":
        (sweep.OUT / job).mkdir(exist_ok=True)
        for i, d in where.items():
            if (d / job / i).exists():
                (d / job / i).rename(sweep.OUT / job / i)
    (sweep.OUT / f"{job}.hosts.json").write_text(json.dumps({i: str(where[i]) for i in sorted(where)}, indent=1) + "\n")
    print(json.dumps({"merged": len(rows), "file": str(target)}))


if __name__ == "__main__":
    {"plan": plan, "run": run, "merge": merge}[sys.argv[1]](*sys.argv[2:])
