"""Stage 5 derivation: hourly counts by knownAt, admissibility switch, coverage, and recompute."""

import json

import polars as pl

from ingest import events
from ingest.store import Store

H = 3_600_000


def setup(tmp_path, posts, live):
    raw = Store(tmp_path / "data" / "sources", key=["forum", "upstream_id"])
    raw.write("discourse", pl.DataFrame([{"forum": "ethresear.ch", "upstream_id": i, "eventTime": c, "knownAt": c,
                                          "topic_id": 1, "post_number": 1, "updated": c, "version": 1, "content_sha256": "x"}
                                         for i, c in posts]), fetched_at=100 * H, source="t")
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps(l) + "\n" for l in live))
    return tmp_path / "data", live_dir


def iso(t):
    from datetime import datetime, timezone
    return datetime.fromtimestamp(t / 1000, timezone.utc).isoformat().replace("+00:00", "Z")


def test_counts_follow_admissibility(tmp_path, monkeypatch):
    monkeypatch.setattr("ingest.sources_backfill.START", 0)
    posts = [(1, 10 * H + 5), (2, 10 * H + 1_000_000), (3, 11 * H + 10), (5, 13 * H - 300_000)]
    live = [{"source": "discourse", "key": "ethresear.ch", "sent": 90 * H, "recv": 90 * H,
             "data": [{"id": 4, "created_at": iso(89 * H + 1), "updated_at": iso(89 * H + 1), "version": 1}]},
            {"source": "discourse", "key": "ethresear.ch", "sent": 95 * H + 7, "recv": 95 * H + 7,
             "data": [{"id": 6, "created_at": iso(95 * H), "updated_at": iso(95 * H), "version": 1}]},
            {"source": "discourse", "key": "ethresear.ch", "sent": 120 * H, "recv": 120 * H, "data": []}]
    root, live_dir = setup(tmp_path, posts, live)
    admitted = events.derive(root, 120 * H, live_dir, True)
    by_hour = dict(admitted.select("eventTime", "count").iter_rows())
    assert by_hour[11 * H] == 2 and by_hour[12 * H] == 1 and by_hour[13 * H] == 0 and by_hour[14 * H] == 1
    assert by_hour[10 * H] == 0 and by_hour[90 * H] == 1 and by_hour[96 * H] == 1
    assert admitted["eventTime"].min() == H
    prospective = events.derive(root, 120 * H, live_dir, False)
    assert prospective["eventTime"].min() == 91 * H
    p = dict(prospective.select("eventTime", "count").iter_rows())
    assert prospective["eventTime"].max() == 120 * H and prospective["count"].sum() == 1 and p[96 * H] == 1
    assert events.derive(root, 120 * H, live_dir, True).equals(admitted)
