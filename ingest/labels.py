"""Blind labeling of a source's entity mapping: draw 50 random items per key with short text excerpts,
and score the key -> coin mapping's precision and recall from the labels."""

import html
import json
import random
import re
import time
from pathlib import Path

import httpx

from ingest.events import SOURCES
from ingest.sources_record import HUB
from ingest.store import Store

PER_KEY = 50


def clean(text):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", text)).split())[:400]


def discourse(http, rng, data_root):
    raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
    for forum in sorted(set(raw["forum"])):
        ids = sorted(set(raw.filter(raw["forum"] == forum)["upstream_id"].to_list()))
        for pid in rng.sample(ids, min(PER_KEY, len(ids))):
            r = http.get(f"https://{forum}/posts/{pid}.json")
            yield {"forum": forum, "id": pid, "text": clean(r.json().get("cooked", "")) if r.status_code == 200 else f"[HTTP {r.status_code}]"}
            time.sleep(2)


def snapshot(http, rng, data_root):
    query = '{proposals(first: 1000, where: {space: "%s"}, orderBy: "created", orderDirection: asc) {id title body}}'
    for row in json.loads(SOURCES["snapshot"]["map"].read_text())["rows"]:
        props = http.post(HUB, json={"query": query % row["space"]}).json()["data"]["proposals"]
        for p in rng.sample(props, min(PER_KEY, len(props))):
            yield {"space": row["space"], "id": p["id"], "text": clean(p["title"] + ". " + p["body"])}


def sample(source, data_root, out):
    rng = random.Random(51)
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-labeling (read-only)"})
    rows = list({"discourse": discourse, "snapshot": snapshot}[source](http, rng, data_root))
    rng.shuffle(rows)
    Path(out).write_text(json.dumps(rows, indent=1))



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

