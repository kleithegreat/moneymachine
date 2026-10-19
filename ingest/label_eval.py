"""C5.1: precision and recall of the forum -> coin mapping on the blind-labeled sample."""

import json
import sys
from pathlib import Path

MAP = Path(__file__).resolve().parents[1] / "venue/sources/discourse_map.json"


def evaluate(sample_path, labels_path):
    sample = json.loads(Path(sample_path).read_text())
    labels = json.loads(Path(labels_path).read_text())
    coin_of = {r["forum"]: r["coin"] for r in json.loads(MAP.read_text())["rows"]}
    norm = lambda a: "kPEPE" if a == "PEPE" else a
    per_forum, per_coin = {}, {}
    for i, post in enumerate(sample):
        mapped = coin_of[post["forum"]]
        assets = {norm(a) for a in labels[str(i)]["assets"]}
        f = per_forum.setdefault(post["forum"], {"coin": mapped, "n": 0, "concerns_mapped": 0, "none": 0, "uncertain": 0})
        f["n"] += 1
        f["concerns_mapped"] += mapped in assets
        f["none"] += assets <= {"none"}
        f["uncertain"] += bool(labels[str(i)].get("uncertain"))
        for a in assets - {"none"}:
            c = per_coin.setdefault(a, {"labeled": 0, "in_mapped_forum": 0})
            c["labeled"] += 1
            c["in_mapped_forum"] += a == mapped
    for f in per_forum.values():
        f["precision"] = round(f["concerns_mapped"] / f["n"], 3)
    for c in per_coin.values():
        c["recall_within_sample"] = round(c["in_mapped_forum"] / c["labeled"], 3)
    return {"per_forum": per_forum, "per_coin": per_coin}


if __name__ == "__main__":
    print(json.dumps(evaluate(*sys.argv[1:]), indent=1))
