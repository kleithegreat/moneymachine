"""Bit-identity of campaigns across machines and kernel builds (`audit/crossmachine/freeze.md`).

    python ops/crossmachine.py compare <a.jsonl> <a_dir> <b.jsonl> <b_dir> <id>...
    python ops/crossmachine.py compare-kernel <a.jsonl> <a_dir> <b.jsonl> <b_dir> <id>...   ignoring the kernel identity
    python ops/crossmachine.py reproduce <out_dir> <id>...   first-round campaigns' search phase against their records

`compare` requires, per id, equal result rows except `seconds`, and equal ledgers: every table, every row in key
order, every column except the wall-clock `created`, blobs byte for byte. `compare-kernel` also ignores the kernel
identity (the `kernel` and `identity` columns and the disclosures' `identity`), for comparing two kernel builds.
`reproduce` reruns first-round campaigns' searches on regenerated markets with the current `mm` (CARGO_TARGET_DIR
picks a candidate build) and compares each ledger with the recorded one as `compare-kernel` does: the first round
froze no finalist, so its ledgers hold exactly the search phase, all kernel output."""

import json
import lzma
import sqlite3
import sys
import tempfile
from functools import partial
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


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


def reproduce(out_dir, *ids):
    from gate import compute, sweep

    betas = json.loads((sweep.OUT / "betas.json").read_text())
    specs = {s["id"]: s | {"sweep": name} for name, ss in (("null", sweep.null_specs(rnd="")),
                                                           ("mixed", sweep.mixed_specs(betas, rnd=""))) for s in ss}
    with Pool(compute.workers(sweep.CAMPAIGN_BYTES)) as pool:
        found = pool.map(partial(reproduce_one, out_dir=out_dir), [specs[i] for i in ids])
    print(json.dumps({"identical": all(same for _, same, _ in found), "kernels": sorted({k for _, _, ks in found for k in ks}),
                      "campaigns": {i: same for i, same, _ in found}}, indent=1))


def reproduce_one(spec, out_dir):
    from gate import markets, search, sweep

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "m"
        markets.write(root, markets.generate(spec["model"], spec["params"], spec["id"], spec["days"], spec.get("planted", ()),
                                             spec.get("beta", 0.0), spec.get("events")), spec["holdout_days"], spec["cost_cells"])
        search.run(spec["searcher"], root, root / "ledger.sqlite", spec["id"], markets.seed(spec["id"]))
        kept = Path(out_dir, spec["id"], "ledger.sqlite.xz")
        kept.parent.mkdir(parents=True, exist_ok=True)
        kept.write_bytes(lzma.compress((root / "ledger.sqlite").read_bytes()))
        kernels = {k for (k,) in sqlite3.connect(root / "ledger.sqlite").execute("SELECT DISTINCT kernel FROM experiments")}
    recorded = sweep.OUT / "round1" / spec["sweep"] / spec["id"] / "ledger.sqlite.xz"
    ignore = ("created", "kernel", "identity")
    return spec["id"], rows(kept, ignore) == rows(recorded, ignore), kernels


if __name__ == "__main__":
    {"compare": compare, "reproduce": reproduce,
     "compare-kernel": partial(compare, ignore=("created", "kernel", "identity"))}[sys.argv[1]](*sys.argv[2:])
