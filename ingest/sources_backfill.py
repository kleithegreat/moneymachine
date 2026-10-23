"""Stage 5: backfill each source's item metadata (no text) from START, as immutable revisions.

Rows are keyed by (forum or space, upstream_id). eventTime holds the claimed created time, and a revision
is known when fetched (our witness). No claimed time is admitted: the derivation (venue/sources/derived.md)
reads a revision only as our observation at fetchedAt. Each key's fetch is complete back to START, so an item
it no longer lists becomes a tombstone.
"""

import hashlib
import sys
import time
from pathlib import Path

import httpx
import polars as pl

from ingest.live import ms, now_ms
from ingest.sources_record import FORUMS, HUB, SPACES
from ingest.policy import DAY, W_START
from ingest.store import Store

START = W_START - 30 * DAY
PAUSE = 2.0


def backfill(forum, http):
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


def proposals(space, http):
    rows, skip = [], 0
    while True:
        query = ('{ proposals(first: 1000, skip: %d, where: {space: "%s", created_gte: %d}, orderBy: "created", '
                 'orderDirection: asc) { id created updated } }') % (skip, space, START // 1000)
        page = http.post(HUB, json={"query": query}).json()["data"]["proposals"]
        rows += [{"space": space, "upstream_id": p["id"], "eventTime": p["created"] * 1000, "updated": p["updated"]} for p in page]
        if len(page) < 1000:
            return rows
        skip += 1000
        time.sleep(PAUSE)


def main(data_root, source="discourse"):
    """One complete fetch from START of every recorded key of `source`, written as revisions."""
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-backfill (read-only)"})
    fetched_at = now_ms()
    keys, key, fetch = (FORUMS, "forum", backfill) if source == "discourse" else (SPACES, "space", proposals)
    rows = []
    for k in keys:
        got = fetch(k, http)
        print(k, len(got), file=sys.stderr, flush=True)
        rows += got
    store = Store(Path(data_root) / "sources", key=[key, "upstream_id"])
    written = store.write(source, pl.DataFrame(rows), fetched_at, f"{source}-backfill", complete=pl.col(key).is_in(keys))
    return {"version": fetched_at, "written": written}

