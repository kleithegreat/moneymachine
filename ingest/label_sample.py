"""C5.1: draw 50 random items per mapped key of a source and fetch short text excerpts for labeling."""

import html
import json
import random
import re
import sys
import time
from pathlib import Path

import httpx

from ingest.store import Store

PER_KEY = 50
VENUE = Path(__file__).resolve().parents[1] / "venue/sources"


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
    for row in json.loads((VENUE / "snapshot_map.json").read_text())["rows"]:
        props = http.post("https://hub.snapshot.org/graphql", json={"query": query % row["space"]}).json()["data"]["proposals"]
        for p in rng.sample(props, min(PER_KEY, len(props))):
            yield {"space": row["space"], "id": p["id"], "text": clean(p["title"] + ". " + p["body"])}


def main(source, data_root, out):
    rng = random.Random(51)
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-labeling (read-only)"})
    rows = list({"discourse": discourse, "snapshot": snapshot}[source](http, rng, data_root))
    rng.shuffle(rows)
    Path(out).write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main(*sys.argv[1:])
