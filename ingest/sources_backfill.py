"""Stage 5: backfill Discourse post metadata (no text) from W's start, as immutable revisions.

Rows are keyed by (forum, upstream_id). eventTime holds the server-set created time (the claim),
and a revision is known when fetched (our witness). No claimed time is admitted: the derivation
(venue/sources/derived.md) reads a revision only as our observation at fetchedAt. Each forum's fetch is complete back to START, so a post it no
longer lists becomes a tombstone.
"""

import hashlib
import sys
import time
from pathlib import Path

import httpx
import polars as pl

from ingest.live import ms
from ingest.sources_record import FORUMS
from ingest.policy import DAY, W_START
from ingest.store import Store

START = W_START - 30 * DAY
PAUSE = 2.0


def backfill(forum, http, fetched_at):
    rows, before = [], None
    while True:
        r = http.get(f"https://{forum}/posts.json", params={"before": before} if before else None)
        r.raise_for_status()
        page = r.json().get("latest_posts", [])
        if not page:
            return rows
        for p in page:
            rows.append({"forum": forum, "upstream_id": p["id"], "eventTime": ms(p["created_at"]), "topic_id": p["topic_id"], "post_number": p["post_number"],
                         "updated": ms(p["updated_at"]), "version": p.get("version") or 1,
                         "content_sha256": hashlib.sha256((p.get("cooked") or "").encode()).hexdigest()})
        before = min(p["id"] for p in page)
        if ms(page[-1]["created_at"]) < START:
            return [x for x in rows if x["eventTime"] >= START]
        time.sleep(PAUSE)


def main(data_root):
    forums = FORUMS
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-backfill (read-only)"})
    fetched_at = int(time.time() * 1000)
    rows = []
    for forum in forums:
        got = backfill(forum, http, fetched_at)
        print(forum, len(got), file=sys.stderr, flush=True)
        rows += got
    store = Store(Path(data_root) / "sources", key=["forum", "upstream_id"])
    written = store.write("discourse", pl.DataFrame(rows), fetched_at, "discourse-posts", complete=pl.col("forum").is_in(forums))
    return {"version": fetched_at, "written": written}

