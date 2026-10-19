"""C5.1: draw 50 random backfilled posts per forum and fetch short text excerpts for labeling."""

import html
import json
import random
import re
import sys
import time
from pathlib import Path

import httpx

from ingest.store import Store

PER_FORUM = 50


def main(data_root, out):
    raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
    rng = random.Random(51)
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-labeling (read-only)"})
    rows = []
    for forum in sorted(set(raw["forum"])):
        ids = sorted(set(raw.filter(raw["forum"] == forum)["upstream_id"].to_list()))
        for pid in rng.sample(ids, min(PER_FORUM, len(ids))):
            r = http.get(f"https://{forum}/posts/{pid}.json")
            text = re.sub(r"<[^>]+>", " ", r.json().get("cooked", "")) if r.status_code == 200 else f"[HTTP {r.status_code}]"
            rows.append({"forum": forum, "id": pid, "text": " ".join(html.unescape(text).split())[:400]})
            time.sleep(2)
        print(forum, file=sys.stderr, flush=True)
    rng.shuffle(rows)
    Path(out).write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main(*sys.argv[1:])
