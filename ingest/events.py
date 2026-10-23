"""Stage 5: hourly event counts per coin from the raw revisions and the live recorder, as specified in
`venue/sources/derived.md`."""

import hashlib
import json
import time
from pathlib import Path

import numpy as np
import polars as pl

from ingest.live import ms, read
from ingest.policy import HOUR
from ingest.store import Store, live, stores, write_split

VENUE = Path(__file__).resolve().parents[1] / "venue/sources"
AUDIT = Path(__file__).resolve().parents[1] / "audit/stage5"
GAP = 600_000
SOURCES = {
    "discourse": {"dataset": "events_forum", "map": VENUE / "discourse_map.json", "key": "forum", "margin": 60_000},
    "snapshot": {"dataset": "events_governance", "map": VENUE / "snapshot_map.json", "key": "space", "margin": 0},
}


def polls(live_dir):
    return read(live_dir, "sources")


def records(data_root, live_dir, source, version):
    """(observations, polls) at or before `version`: [(key, id, created, at)] and {key: [recv]}."""
    obs, polled = [], {}
    key = SOURCES[source]["key"]
    raw = Store(Path(data_root) / "sources", key=[key, "upstream_id"]).revisions(source)
    if raw is not None:
        obs += raw.filter((pl.col("fetchedAt") <= version) & live(raw)).select(key, "upstream_id", "eventTime", "fetchedAt").rows()
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


def covered(times, margin, version):
    """The hours τ <= version whose witness window [τ - HOUR - margin, τ - margin] the polls cover: every
    instant in it has a poll within the last GAP ms, at or before it."""
    p = np.unique(np.array(times, dtype=np.int64))
    hours = np.arange(-(-(p[0] + HOUR + margin) // HOUR) * HOUR, version // HOUR * HOUR + 1, HOUR)
    a, b = hours - HOUR - margin, hours - margin
    ia, ib = np.searchsorted(p, a, side="right") - 1, np.searchsorted(p, b, side="right") - 1
    gaps = np.concatenate([[0], np.cumsum(np.diff(p) > GAP)])
    return hours[(b - p[ib] < GAP) & (gaps[ib] == gaps[ia])]


def counts(obs, polled, coin_of, margin, version):
    """[(coin, hour, count)] over each mapped key's covered hours: items created since the key's first poll, each
    known `margin` ms after its earliest observation."""
    first = items(obs)
    out = []
    for key, times in sorted(polled.items()):
        if key not in coin_of:
            continue
        s = min(times)
        k = np.sort(np.array([w + margin for (fk, _), (c, w) in first.items() if fk == key and c >= s], dtype=np.int64))
        hours = covered(times, margin, version)
        counts = np.searchsorted(k, hours, side="right") - np.searchsorted(k, hours - HOUR, side="right")
        out += [(coin_of[key], int(h), int(n)) for h, n in zip(hours, counts)]
    return out


def sha(x):
    return hashlib.sha256(json.dumps(x, sort_keys=True).encode()).hexdigest()


def derive(data_root, version, live_dir, source="discourse"):
    """The derived rows at cut `version`, each carrying its lineage: the cut, and the hashes of this code, the
    mapping file and the records read."""
    spec = SOURCES[source]
    coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
    obs, polled = records(data_root, live_dir, source, version)
    lineage = {"cut": version, "code_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "map_sha256": hashlib.sha256(spec["map"].read_bytes()).hexdigest(),
               "inputs_sha256": sha([sorted(obs), {k: sorted(v) for k, v in polled.items()}])}
    rows = counts(obs, polled, coin_of, spec["margin"], version)
    return pl.DataFrame([{"coin": c, "eventTime": h, "count": float(n)} | lineage for c, h, n in rows])


def manifest(df):
    return {k: df[k][0] for k in ("cut", "code_sha256", "map_sha256", "inputs_sha256")} | {
        "rows": df.height, "rows_sha256": sha(sorted(df.select("coin", "eventTime", "count").rows()))}


def main(data_root, version, live_dir, source="discourse", audit=AUDIT):
    """Write the derived version and its lineage manifest (`audit/stage5/lineage-<source>-<version>.json`)."""
    df = derive(data_root, version, live_dir, source)
    search, holdout = stores(data_root)
    fetched_at = int(time.time() * 1000)
    dataset = SOURCES[source]["dataset"]
    written = write_split(search, holdout, dataset, df, fetched_at, f"derived:{source}")
    files = [s.root / dataset / f"{fetched_at}.parquet" for s in (search, holdout)]
    out = {"source": source, "dataset": dataset, "version": fetched_at, **manifest(df), "written(search, holdout)": written,
           "files_sha256": {str(f.relative_to(data_root)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files if f.exists()}}
    path = Path(audit) / f"lineage-{source}-{fetched_at}.json"
    path.write_text(json.dumps(out, indent=1) + "\n")
    return out


def verify(lineage, data_root, live_dir):
    """Recompute a derived version from the raw store and recordings at its cut, and compare it with its
    manifest, without reading the stored rows."""
    m = json.loads(Path(lineage).read_text())
    again = manifest(derive(data_root, m["cut"], live_dir, m["source"]))
    return {"lineage": str(lineage), "identical": all(again[k] == m[k] for k in again), "recomputed": again}

