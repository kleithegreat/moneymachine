"""Stage 5: hourly forum-post counts per coin (`events_forum`) from the raw Discourse revisions and
the live recorder, under the admissibility rule (PROGRESS.md, Stage 5, as revised).

An item's knownAt is created + 600 s if the source passed C5.3 (`admitted`), otherwise its earliest
witness: the first live observation or the first fetch that saw it. Counts are written for every
hour of the source's coverage, so zero means no posts, and hours outside coverage have no row
(the input is undefined there).
"""

import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import polars as pl

from ingest.sources_avail import ms, polls
from ingest.store import HOLDOUT_START, Store, stores, write_split

HOUR = 3_600_000
RULE_MS = 600_000
MAP = Path(__file__).resolve().parents[1] / "venue/sources/discourse_map.json"


def items(data_root, version, live_dir):
    """One row per post: forum, id, created, first witness."""
    raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
    raw = raw.filter(pl.col("fetchedAt") <= version)
    first = {(r["forum"], r["upstream_id"]): (r["eventTime"], r["fetchedAt"])
             for r in raw.group_by(["forum", "upstream_id"]).agg(pl.col("eventTime").first(), pl.col("fetchedAt").min()).iter_rows(named=True)}
    for poll in polls(live_dir):
        if poll["source"] != "discourse" or not isinstance(poll["data"], list) or poll["recv"] > version:
            continue
        for p in poll["data"]:
            key = (poll["key"], p["id"])
            created, witness = first.get(key, (ms(p["created_at"]), poll["recv"]))
            first[key] = (created, min(witness, poll["recv"]))
    return first


def coverage(data_root, version, live_dir, admitted):
    """[start, end) per forum: from the backfill's start if admitted, else from the first live poll."""
    from ingest.sources_backfill import START

    live_start = {}
    for poll in polls(live_dir):
        if poll["source"] == "discourse" and poll["recv"] <= version:
            live_start.setdefault(poll["key"], poll["recv"])
    return {f: ((START if admitted else s) // HOUR * HOUR + HOUR, version // HOUR * HOUR) for f, s in live_start.items()}


def derive(data_root, version, live_dir, admitted):
    mapping = json.loads(MAP.read_text())
    coin_of = {r["forum"]: r["coin"] for r in mapping["rows"]}
    code = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    map_hash = hashlib.sha256(MAP.read_bytes()).hexdigest()
    known = {}
    for (forum, _), (created, witness) in items(data_root, version, live_dir).items():
        known.setdefault(forum, []).append(created + RULE_MS if admitted else witness)
    rows = []
    for forum, (start, end) in coverage(data_root, version, live_dir, admitted).items():
        hours = np.arange(start, end + 1, HOUR)
        k = np.sort(np.array(known.get(forum, []), dtype=np.int64))
        counts = np.searchsorted(k, hours, side="right") - np.searchsorted(k, hours - HOUR, side="right")
        rows += [{"coin": coin_of[forum], "eventTime": int(h), "knownAt": int(h), "count": float(n),
                  "code_sha256": code, "map_sha256": map_hash} for h, n in zip(hours, counts)]
    return pl.DataFrame(rows)


def main(data_root, version, live_dir, admitted):
    df = derive(data_root, int(version), live_dir, admitted == "admitted")
    search, holdout = stores(data_root)
    fetched_at = int(time.time() * 1000)
    print(json.dumps({"version": fetched_at, "rows": df.height,
                      "written(search, holdout)": write_split(search, holdout, "events_forum", df, fetched_at, "derived:discourse")}))


if __name__ == "__main__":
    main(*sys.argv[1:])
