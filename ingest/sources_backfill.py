"""Stage 5: backfill Discourse post metadata (no text) from W's start, as immutable revisions.

Rows are keyed by (forum, upstream_id). eventTime and knownAt hold the server-set created time
(the claim); each revision's fetchedAt is our witness. Admissible availability times are derived
from both later (C5.3), so an unchanged post refetched later is not a new revision.
"""

import hashlib
import json
import sys
import time
from datetime import datetime
from pathlib import Path

import httpx
import polars as pl

from ingest.store import W_START, Store

MAP = Path(__file__).resolve().parents[1] / "venue/sources/discourse_map.json"
START = W_START - 30 * 86_400_000
PAUSE = 2.0


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def backfill(forum, http, fetched_at):
    rows, before = [], None
    while True:
        r = http.get(f"https://{forum}/posts.json", params={"before": before} if before else None)
        r.raise_for_status()
        page = r.json().get("latest_posts", [])
        if not page:
            return rows
        for p in page:
            rows.append({"forum": forum, "upstream_id": p["id"], "eventTime": ms(p["created_at"]),
                         "knownAt": ms(p["created_at"]), "topic_id": p["topic_id"], "post_number": p["post_number"],
                         "updated": ms(p["updated_at"]), "version": p.get("version") or 1,
                         "content_sha256": hashlib.sha256((p.get("cooked") or "").encode()).hexdigest()})
        before = min(p["id"] for p in page)
        if ms(page[-1]["created_at"]) < START:
            return [x for x in rows if x["eventTime"] >= START]
        time.sleep(PAUSE)


def main(data_root):
    forums = [r["forum"] for r in json.loads(MAP.read_text())["rows"]]
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-backfill (read-only)"})
    fetched_at = int(time.time() * 1000)
    rows = []
    for forum in forums:
        got = backfill(forum, http, fetched_at)
        print(forum, len(got), file=sys.stderr, flush=True)
        rows += got
    store = Store(Path(data_root) / "sources", key=["forum", "upstream_id"])
    print(json.dumps({"version": fetched_at, "written": store.write("discourse", pl.DataFrame(rows), fetched_at, "discourse-posts")}))


if __name__ == "__main__":
    main(sys.argv[1])
