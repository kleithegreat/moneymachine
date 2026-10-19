"""C5.1: precision and recall of a source's key -> coin mapping on its blind-labeled sample."""

import json
import sys
from pathlib import Path

from ingest.events import SOURCES


def evaluate(source, sample_path, labels_path):
    spec = SOURCES[source]
    sample = json.loads(Path(sample_path).read_text())
    labels = json.loads(Path(labels_path).read_text())
    coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
    norm = lambda a: "kPEPE" if a == "PEPE" else a
    per_key, per_coin = {}, {}
    for i, item in enumerate(sample):
        mapped = coin_of[item[spec["key"]]]
        assets = {norm(a) for a in labels[str(i)]["assets"]}
        k = per_key.setdefault(item[spec["key"]], {"coin": mapped, "n": 0, "concerns_mapped": 0, "none": 0, "uncertain": 0})
        k["n"] += 1
        k["concerns_mapped"] += mapped in assets
        k["none"] += not assets
        k["uncertain"] += bool(labels[str(i)].get("uncertain"))
        for a in assets:
            c = per_coin.setdefault(a, {"labeled": 0, "in_mapped_key": 0})
            c["labeled"] += 1
            c["in_mapped_key"] += a == mapped
    for k in per_key.values():
        k["precision"] = round(k["concerns_mapped"] / k["n"], 3)
    for c in per_coin.values():
        c["recall_within_sample"] = round(c["in_mapped_key"] / c["labeled"], 3)
    return {"per_key": per_key, "per_coin": per_coin,
            "labels": [{spec["key"]: s[spec["key"]], "id": s["id"], **labels[str(i)]} for i, s in enumerate(sample)]}


if __name__ == "__main__":
    print(json.dumps(evaluate(*sys.argv[1:]), indent=1))
