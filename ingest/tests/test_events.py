"""Stage 5 derivation: hourly counts by knownAt (prospective, with the source's margin), coverage, and recompute."""

import json

import polars as pl

from ingest import events
from ingest.policy import HOUR as H
from ingest.store import Store



def setup(tmp_path, posts, live):
    raw = Store(tmp_path / "data" / "sources", key=["forum", "upstream_id"])
    raw.write("discourse", pl.DataFrame([{"forum": "delvingbitcoin.org", "upstream_id": i, "eventTime": c,
                                          "topic_id": 1, "post_number": 1, "updated": c, "version": 1, "content_sha256": "x"}
                                         for i, c in posts]), fetched_at=100 * H, source="t")
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps(l) + "\n" for l in live))
    return tmp_path / "data", live_dir


def iso(t):
    from datetime import datetime, timezone
    return datetime.fromtimestamp(t / 1000, timezone.utc).isoformat().replace("+00:00", "Z")


def poll(t, items=()):
    return {"source": "discourse", "key": "delvingbitcoin.org", "sent": t, "recv": t,
            "data": [{"id": i, "created_at": iso(c), "updated_at": iso(c), "version": 1} for i, c in items]}


def every_5_min(start, end, skip=()):
    return [poll(t) for t in range(start, end + 1, 300_000) if not any(a <= t < b for a, b in skip)]


def test_counts_are_prospective_with_the_margin(tmp_path):
    posts = [(1, 10 * H + 5), (2, 10 * H + 1_000_000)]
    live = every_5_min(90 * H, 120 * H) + [poll(90 * H, [(4, 89 * H + 1)]), poll(95 * H + 7, [(6, 95 * H)]),
                                           poll(97 * H - 30_000, [(7, 96 * H)])]
    root, live_dir = setup(tmp_path, posts, live)
    df = events.derive(root, 120 * H, live_dir)
    p = dict(df.select("eventTime", "count").iter_rows())
    assert df["eventTime"].min() == 92 * H and df["eventTime"].max() == 120 * H and df.height == 29
    assert p[96 * H] == 1 and p[97 * H] == 0 and p[98 * H] == 1 and df["count"].sum() == 2
    assert events.derive(root, 120 * H, live_dir).equals(df)


def test_hours_a_recording_gap_touches_are_undefined(tmp_path):
    live = every_5_min(90 * H, 110 * H, skip=[(100 * H + 1, 100 * H + 40 * 60_000)])
    root, live_dir = setup(tmp_path, [(1, 10 * H)], live)
    hours = set(events.derive(root, 110 * H, live_dir)["eventTime"])
    assert {100 * H, 102 * H} <= hours and 101 * H not in hours


def test_stored_derivation_recomputes_byte_identically(tmp_path):
    """C5.2: the derived dataset in the store is reproduced exactly from the raw store and recordings."""
    from ingest.store import _hash, stores

    live = every_5_min(20 * H, 40 * H) + [poll(t * H, [(9, 30 * H + 7)]) for t in (31, 40)]
    root, live_dir = setup(tmp_path, [(1, 10 * H + 5), (2, 33 * H)], live)
    out = events.main(root, 100 * H, live_dir, audit=tmp_path)
    stored = stores(root)[0].revisions("events_forum").sort("eventTime")
    again = events.derive(root, 100 * H, live_dir)
    assert again["count"].sum() == 1
    assert stored.height == again.height > 0
    assert stored["hash"].to_list() == [_hash(r) for r in again.sort("eventTime").iter_rows(named=True)]
    lineage = tmp_path / f"lineage-discourse-{out['version']}.json"
    assert out["cut"] == 100 * H and events.verify(lineage, root, live_dir)["identical"]
    (live_dir / "sources-x.jsonl").write_text((live_dir / "sources-x.jsonl").read_text().replace(iso(30 * H + 7), iso(30 * H + 8)))
    assert not events.verify(lineage, root, live_dir)["identical"]
