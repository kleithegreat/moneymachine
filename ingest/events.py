"""Stage 5: hourly event counts per coin from the raw revisions and the live recorder, as specified in
`venue/sources/derived.md`."""

import hashlib
import json
import time
from pathlib import Path

import numpy as np
import polars as pl

from ingest.live import ms
from ingest.policy import HOUR
from ingest.sources_avail import polls
from ingest.store import Store, live, stores, write_split

VENUE = Path(__file__).resolve().parents[1] / "venue/sources"
SOURCES = {
    "discourse": {"dataset": "events_forum", "map": VENUE / "discourse_map.json", "key": "forum", "margin": 60_000},
    "snapshot": {"dataset": "events_governance", "map": VENUE / "snapshot_map.json", "key": "space", "margin": 0},
}


def records(data_root, live_dir, source, version):
    """(observations, polls) at or before `version`: [(key, id, created, at)] and {key: [recv]}."""
    obs, polled = [], {}
    if source == "discourse":
        raw = Store(Path(data_root) / "sources", key=["forum", "upstream_id"]).revisions("discourse")
        if raw is not None:
            obs += raw.filter((pl.col("fetchedAt") <= version) & live(raw)).select("forum", "upstream_id", "eventTime", "fetchedAt").rows()
    for poll in polls(live_dir):
        if poll["source"] != source or poll["recv"] > version:
            continue
        d = poll["data"]
        seen = d if source == "discourse" else (d.get("data") or {}).get("proposals")
        if not isinstance(seen, list):
            continue
        polled.setdefault(poll["key"], []).append(poll["recv"])
        for p in seen:
            created = ms(p["created_at"]) if source == "discourse" else p["created"] * 1000
            obs.append((poll["key"], p["id"], created, poll["recv"]))
    return obs, polled


def items(obs):
    """(key, id) -> (created, witness), both from the item's earliest observation."""
    first = {}
    for key, item, created, at in sorted(obs, key=lambda o: (o[3], o[2])):
        first.setdefault((key, item), (created, at))
    return first


def counts(obs, polled, coin_of, margin):
    """[(coin, hour, count)] over each covered key's hours: items created since the key's first poll, each known
    `margin` ms after its earliest observation."""
    first = items(obs)
    ceil = lambda t: -(-t // HOUR) * HOUR
    out = []
    for key, times in sorted(polled.items()):
        if key not in coin_of:
            continue
        s = min(times)
        k = np.sort(np.array([w + margin for (fk, _), (c, w) in first.items() if fk == key and c >= s], dtype=np.int64))
        hours = np.arange(ceil(s) + HOUR, max(times) // HOUR * HOUR + 1, HOUR)
        counts = np.searchsorted(k, hours, side="right") - np.searchsorted(k, hours - HOUR, side="right")
        out += [(coin_of[key], int(h), int(n)) for h, n in zip(hours, counts)]
    return out


def derive(data_root, version, live_dir, source="discourse"):
    spec = SOURCES[source]
    coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
    code = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    map_hash = hashlib.sha256(spec["map"].read_bytes()).hexdigest()
    obs, polled = records(data_root, live_dir, source, version)
    rows = counts(obs, polled, coin_of, spec["margin"])
    return pl.DataFrame([{"coin": c, "eventTime": h, "knownAt": h, "count": float(n), "code_sha256": code,
                          "map_sha256": map_hash} for c, h, n in rows])


def main(data_root, version, live_dir, source="discourse"):
    df = derive(data_root, version, live_dir, source)
    search, holdout = stores(data_root)
    fetched_at = int(time.time() * 1000)
    written = write_split(search, holdout, SOURCES[source]["dataset"], df, fetched_at, f"derived:{source}")
    return {"version": fetched_at, "rows": df.height, "written(search, holdout)": written}

