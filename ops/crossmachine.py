"""Cross-machine bit-identity of null campaigns (`audit/crossmachine/freeze.md`).

    python ops/crossmachine.py run <out_dir> <id>...        run campaigns <id> (null, or the mixed test specs) into <out_dir>
    python ops/crossmachine.py compare <a.jsonl> <a_dir> <b.jsonl> <b_dir> <id>...
    python ops/crossmachine.py compare-kernel <a.jsonl> <a_dir> <b.jsonl> <b_dir> <id>...   ignoring the kernel identity

`run` writes <out_dir>.jsonl as the sweep does, plus <out_dir>.machine.json (CPU flags, numpy's SIMD dispatch).
`compare` requires, per id, equal result rows except `seconds`, and equal ledgers: every table, every row in key
order, every column except the wall-clock `created`, blobs byte for byte. `compare-kernel` also ignores the kernel
identity (the `kernel` and `identity` columns and the disclosures' `identity`), for comparing two kernel builds."""

import json
import lzma
import platform
import sqlite3
import sys
import tempfile
from functools import partial
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def specs():
    """The null sweep's specs, and the mixed path's test specs: the mixed sweep's cells under ids `xm-…` (never judged)
    with fixed test betas, the long-holdout cell included."""
    from gate import sweep
    test_betas = {f"{m}-s{k}": 0.01 * k for m in ("N2", "N3") for k in (1, 2, 3)} | {"N2-long": 0.1}
    mixed = [s | {"id": s["id"].replace("c25-", "xm-", 1)} for s in sweep.mixed_specs(test_betas, markets=1)]
    return sweep.null_specs() + mixed


def run(out_dir, *ids):
    import numpy
    from numpy._core._multiarray_umath import __cpu_dispatch__, __cpu_features__
    from gate import campaign, sweep
    sweep.require_frozen_searcher()
    out = Path(out_dir)
    chosen = [s for s in specs() if s["id"] in ids]
    flags = next((l.split(":", 1)[1].split() for l in open("/proc/cpuinfo") if l.startswith("flags")), [])
    out.with_suffix(".machine.json").write_text(json.dumps({
        "node": platform.node(), "cpu": next((l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name")), ""),
        "avx512": sorted(f for f in flags if f.startswith("avx512")), "numpy": numpy.__version__,
        "numpy_dispatch": [f for f in __cpu_dispatch__ if __cpu_features__.get(f)]}, indent=1) + "\n")
    with Pool(sweep.workers(sweep.CAMPAIGN_BYTES)) as pool, open(out.with_suffix(".jsonl"), "a") as fh:
        for r in pool.imap_unordered(partial(campaign.run_campaign, out=out), chosen):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], r["seconds"], flush=True)


def rows(ledger_xz, ignore=("created",)):
    with tempfile.NamedTemporaryFile(suffix=".sqlite") as f:
        f.write(lzma.decompress(Path(ledger_xz).read_bytes()))
        f.flush()
        db = sqlite3.connect(f.name)
        out = {}
        for (table,) in db.execute("select name from sqlite_master where type = 'table' order by name"):
            cols = [c[1] for c in db.execute(f"pragma table_info({table})") if c[1] not in ignore]
            got = db.execute(f"select {', '.join(cols)} from {table} order by rowid").fetchall()
            if "identity" in ignore and "content" in cols:
                k = cols.index("content")
                got = [r[:k] + (json.dumps({a: b for a, b in json.loads(r[k]).items() if a != "identity"}, sort_keys=True),) + r[k + 1:]
                       for r in got]
            out[table] = got
        return out


def compare(a_jsonl, a_dir, b_jsonl, b_dir, *ids, ignore=("created",)):
    def results(path):
        return {r["id"]: {k: v for k, v in r.items() if k != "seconds"} for r in map(json.loads, open(path)) if r["id"] in ids}
    a, b = results(a_jsonl), results(b_jsonl)
    report = {cid: {"result": cid in a and a.get(cid) == b.get(cid),
                    "ledger": rows(Path(a_dir, cid, "ledger.sqlite.xz"), ignore) == rows(Path(b_dir, cid, "ledger.sqlite.xz"), ignore)}
              for cid in ids}
    print(json.dumps({"identical": all(v["result"] and v["ledger"] for v in report.values()), "campaigns": report}, indent=1))


if __name__ == "__main__":
    {"run": run, "compare": compare,
     "compare-kernel": partial(compare, ignore=("created", "kernel", "identity"))}[sys.argv[1]](*sys.argv[2:])
