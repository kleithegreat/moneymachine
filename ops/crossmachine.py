"""Cross-machine bit-identity of null campaigns (`audit/crossmachine/freeze.md`).

    python ops/crossmachine.py run <out_dir> <id>...        run the null campaigns <id> into <out_dir>
    python ops/crossmachine.py compare <a.jsonl> <a_dir> <b.jsonl> <b_dir> <id>...

`run` writes <out_dir>.jsonl as the sweep does, plus <out_dir>.machine.json (CPU flags, numpy's SIMD dispatch).
`compare` requires, per id, equal result rows except `seconds`, and equal ledgers: every table, every row in key
order, every column except the wall-clock `created`, blobs byte for byte."""

import json
import lzma
import platform
import sqlite3
import sys
import tempfile
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def run(out_dir, *ids):
    import numpy
    from functools import partial
    from numpy._core._multiarray_umath import __cpu_dispatch__, __cpu_features__
    from gate import campaign, sweep
    sweep.require_frozen_searcher()
    out = Path(out_dir)
    specs = [s for s in sweep.null_specs() if s["id"] in ids]
    flags = next((l.split(":", 1)[1].split() for l in open("/proc/cpuinfo") if l.startswith("flags")), [])
    out.with_suffix(".machine.json").write_text(json.dumps({
        "node": platform.node(), "cpu": next((l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name")), ""),
        "avx512": sorted(f for f in flags if f.startswith("avx512")), "numpy": numpy.__version__,
        "numpy_dispatch": [f for f in __cpu_dispatch__ if __cpu_features__.get(f)]}, indent=1) + "\n")
    with Pool(sweep.workers(sweep.CAMPAIGN_BYTES)) as pool, open(out.with_suffix(".jsonl"), "a") as fh:
        for r in pool.imap_unordered(partial(campaign.run_campaign, out=out), specs):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], r["seconds"], flush=True)


def rows(ledger_xz):
    with tempfile.NamedTemporaryFile(suffix=".sqlite") as f:
        f.write(lzma.decompress(Path(ledger_xz).read_bytes()))
        f.flush()
        db = sqlite3.connect(f.name)
        out = {}
        for (table,) in db.execute("select name from sqlite_master where type = 'table' order by name"):
            cols = [c[1] for c in db.execute(f"pragma table_info({table})") if c[1] != "created"]
            out[table] = db.execute(f"select {', '.join(cols)} from {table} order by rowid").fetchall()
        return out


def compare(a_jsonl, a_dir, b_jsonl, b_dir, *ids):
    def results(path):
        return {r["id"]: {k: v for k, v in r.items() if k != "seconds"} for r in map(json.loads, open(path)) if r["id"] in ids}
    a, b = results(a_jsonl), results(b_jsonl)
    report = {cid: {"result": cid in a and a.get(cid) == b.get(cid),
                    "ledger": rows(Path(a_dir, cid, "ledger.sqlite.xz")) == rows(Path(b_dir, cid, "ledger.sqlite.xz"))}
              for cid in ids}
    print(json.dumps({"identical": all(v["result"] and v["ledger"] for v in report.values()), "campaigns": report}, indent=1))


if __name__ == "__main__":
    {"run": run, "compare": compare}[sys.argv[1]](*sys.argv[2:])
