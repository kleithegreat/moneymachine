"""Stage 5: hourly event counts per coin from the raw revisions and the live recorder, under the
admissibility rule (PROGRESS.md, Stage 5, as revised): `events_forum` from Discourse posts, and
`events_governance` from Snapshot proposals.

An item's knownAt is created + 600 s if the source passed C5.3 (`admitted`). Otherwise it is the
earliest witness (the first live observation or the first fetch that saw it), and only items
created after the first live poll count, since older ones are not new events. Snapshot's created time is
client-claimed, so it is never admitted. Counts are written for every hour of the source's
coverage, so zero means no events, and hours outside coverage have no row (the input is undefined
there).
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
VENUE = Path(__file__).resolve().parents[1] / "venue/sources"
SOURCES = {
    "discourse": {"dataset": "events_forum", "map": VENUE / "discourse_map.json", "key": "forum"},
    "snapshot": {"dataset": "events_governance", "map": VENUE / "snapshot_map.json", "key": "space"},
}


def live_items(live_dir, source, version):
    """(key, id) -> (created, first observed) from the recorder."""
    out = {}
    for poll in polls(live_dir):
        if poll["source"] != source or poll["recv"] > version:
            continue
        data = poll["data"] if source == "discourse" else (poll["data"].get("data") or {}).get("proposals")
        if not isinstance(data, list):
            continue
        for p in data:
            created = ms(p["created_at"]) if source == "discourse" else p["created"] * 1000
            key = (poll["key"], p["id"])
            out[key] = (created, min(out.get(key, (0, poll["recv"]))[1], poll["recv"]))
    return out


def items(data_root, version, live_dir, source="discourse"):
    """One row per item: (key, id) -> (created, first witness), from backfilled revisions and live polls."""
    first = {}
    if source == "discourse":
        raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
        if raw is not None:
            raw = raw.filter(pl.col("fetchedAt") <= version)
            first = {(r["forum"], r["upstream_id"]): (r["eventTime"], r["fetchedAt"])
                     for r in raw.group_by(["forum", "upstream_id"]).agg(pl.col("eventTime").first(), pl.col("fetchedAt").min()).iter_rows(named=True)}
    for key, (created, seen) in live_items(live_dir, source, version).items():
        c, w = first.get(key, (created, seen))
        first[key] = (c, min(w, seen))
    return first


def coverage(data_root, version, live_dir, admitted, source="discourse"):
    """(first live poll, start, end) per key: hours [start, end], from the backfill's start if admitted, else from the first live poll,
    to the last live poll. The first hour counted lies wholly after the start, so items that already
    existed at the first poll are not counted as new, and a recording gap at the end is not read as
    zero events."""
    from ingest.sources_backfill import START

    first, last = {}, {}
    for poll in polls(live_dir):
        if poll["source"] == source and poll["recv"] <= version:
            first.setdefault(poll["key"], poll["recv"])
            last[poll["key"]] = poll["recv"]
    ceil = lambda t: -(-t // HOUR) * HOUR
    return {k: (s, ceil(START if admitted else s) + HOUR, last[k] // HOUR * HOUR) for k, s in first.items()}


def derive(data_root, version, live_dir, admitted, source="discourse"):
    spec = SOURCES[source]
    admitted = admitted and source == "discourse"
    coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
    code = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    map_hash = hashlib.sha256(spec["map"].read_bytes()).hexdigest()
    cover = coverage(data_root, version, live_dir, admitted, source)
    known = {}
    for (key, _), (created, witness) in items(data_root, version, live_dir, source).items():
        if admitted:
            known.setdefault(key, []).append(created + RULE_MS)
        elif key in cover and created >= cover[key][0]:
            known.setdefault(key, []).append(witness)
    rows = []
    for forum, (_, start, end) in cover.items():
        if forum not in coin_of:
            continue
        hours = np.arange(start, end + 1, HOUR)
        k = np.sort(np.array(known.get(forum, []), dtype=np.int64))
        counts = np.searchsorted(k, hours, side="right") - np.searchsorted(k, hours - HOUR, side="right")
        rows += [{"coin": coin_of[forum], "eventTime": int(h), "knownAt": int(h), "count": float(n),
                  "code_sha256": code, "map_sha256": map_hash} for h, n in zip(hours, counts)]
    return pl.DataFrame(rows)


def main(data_root, version, live_dir, admitted, source="discourse"):
    df = derive(data_root, int(version), live_dir, admitted == "admitted", source)
    search, holdout = stores(data_root)
    fetched_at = int(time.time() * 1000)
    written = write_split(search, holdout, SOURCES[source]["dataset"], df, fetched_at, f"derived:{source}")
    print(json.dumps({"version": fetched_at, "rows": df.height, "written(search, holdout)": written}))


if __name__ == "__main__":
    main(*sys.argv[1:])
