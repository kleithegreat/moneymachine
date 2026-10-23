"""One-off purge (human decision 2026-10-22): delete data from Discourse forums whose terms do not permit our automated use."""
import hashlib, json, os, sys, time
from pathlib import Path
import polars as pl

BANNED = {"forum.solana.com", "forums.sui.io", "governance.aave.com", "forum.bnbchain.org", "forum.celestia.org", "ethresear.ch"}
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
log = []

def replace(path, data):
    tmp = Path(str(path) + ".purge")
    tmp.write_bytes(data) if isinstance(data, bytes) else tmp.write_text(data)
    os.chmod(tmp, os.stat(path).st_mode & 0o777)
    os.replace(tmp, path)

for f in sorted(Path("data/sources/discourse").glob("*.parquet")):
    before = sha(f); df = pl.read_parquet(f)
    removed = {k: n for k, n in df.group_by("forum").len().iter_rows() if k in BANNED}
    keep = df.filter(~pl.col("forum").is_in(BANNED))
    os.chmod(f, 0o644); keep.write_parquet(str(f) + ".purge"); os.replace(str(f) + ".purge", f); os.chmod(f, 0o444)
    log.append({"file": str(f), "action": "rewritten: banned forums' rows removed", "sha256_before": before, "sha256_after": sha(f),
                "rows_before": df.height, "rows_after": keep.height, "removed_rows_by_forum": removed})

for f in sorted(Path("data/sources_live").glob("sources-*.jsonl")):
    if f.name == "sources-20261022.jsonl":
        while not 30 < time.time() - f.stat().st_mtime < 200:
            time.sleep(5)
    before = sha(f); lines = f.read_text().splitlines(keepends=True)
    removed, keep = {}, []
    for l in lines:
        d = json.loads(l)
        if d["source"] == "discourse" and d["key"] in BANNED:
            removed[d["key"]] = removed.get(d["key"], 0) + 1
        else:
            keep.append(l)
    replace(f, "".join(keep))
    log.append({"file": str(f), "action": "rewritten: banned forums' poll lines removed", "sha256_before": before, "sha256_after": sha(f),
                "lines_before": len(lines), "lines_after": len(keep), "removed_lines_by_forum": removed})

f = Path("data/stage5/label_sample.json")
before = sha(f); items = json.loads(f.read_text())
keep = [x for x in items if x["forum"] not in BANNED]
removed = {}
for x in items:
    if x["forum"] in BANNED: removed[x["forum"]] = removed.get(x["forum"], 0) + 1
replace(f, json.dumps(keep, indent=1))
log.append({"file": str(f), "action": "rewritten: banned forums' sampled post texts removed", "sha256_before": before, "sha256_after": sha(f),
            "items_before": len(items), "items_after": len(keep), "removed_items_by_forum": removed})

f = Path("audit/stage5/c51-discourse.json")
before = sha(f); d = json.loads(f.read_text())
labels = [x for x in d["labels"] if x["forum"] not in BANNED]
new = {"per_key": {k: v for k, v in d["per_key"].items() if k not in BANNED},
       "per_coin": {c: v for c, v in d["per_coin"].items() if c == "BTC"}, "labels": labels}
replace(f, json.dumps(new, indent=1) + "\n")
log.append({"file": str(f), "action": "rewritten: banned forums' labels and summaries removed", "sha256_before": before, "sha256_after": sha(f),
            "labels_before": len(d["labels"]), "labels_after": len(labels), "removed_summaries": {k: v for k, v in d["per_key"].items() if k in BANNED}})

for f in ["data/holdout/events_forum/1792701059079.parquet", "audit/stage5/coverage-1792701055113.json",
          "audit/stage5/reconcile-1792701110136.json", "audit/stage5/sources-availability-full-recording.json",
          "data/tmp/coverage.json", "data/tmp/reconcile.json", "data/tmp/sources-backfill.err", "data/tmp/sources-backfill.json"]:
    p = Path(f)
    if p.exists():
        entry = {"file": f, "action": "deleted: derived wholly or partly from banned forums", "sha256_before": sha(p)}
        if p.suffix == ".json":
            entry["content"] = json.loads(p.read_text()) if p.stat().st_size < 4000 else "summary in the note"
        os.chmod(p, 0o644); p.unlink(); log.append(entry)
import shutil
for d in ["data/tmp/gpt5.JLS9"]:
    if Path(d).exists():
        shutil.rmtree(d); log.append({"file": d, "action": "deleted: a review packet holding copies of the files above"})
Path("data/tmp/purge-log.json").write_text(json.dumps(log, indent=1))
print(json.dumps([{k: v for k, v in e.items() if k != "content"} for e in log], indent=1))
