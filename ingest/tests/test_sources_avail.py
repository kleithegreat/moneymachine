"""C5.3 live-versus-backfill reconciliation: deletions (including tombstones), edits and backdated items."""

import json

import polars as pl

from ingest import sources_avail
from ingest.policy import HOUR as H
from ingest.store import Store
from ingest.tests.test_events import iso



def post(i, created, sha="a"):
    return {"id": i, "created_at": iso(created), "updated_at": iso(created), "version": 1, "cooked_sha256": sha}


def test_reconcile(tmp_path):
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    polls = [(10 * H, [post(1, 10 * H - 5)]), (11 * H, [post(2, 11 * H - 60_000), post(3, 11 * H - 60_000), post(4, 11 * H - 60_000, "x")])]
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps({"source": "discourse", "key": "f", "sent": t, "recv": t, "data": d}) + "\n"
                                                      for t, d in polls))
    store = Store(tmp_path / "sources", key=["forum", "upstream_id"])
    row = lambda i, c, sha="a": {"forum": "f", "upstream_id": i, "eventTime": c, "content_sha256": sha}
    whole = pl.col("forum") == "f"
    store.write("discourse", pl.DataFrame([row(1, 10 * H - 5), row(3, 11 * H - 60_000), row(4, 11 * H - 60_000, "y")]), 12 * H, "t", complete=whole)
    store.write("discourse", pl.DataFrame([row(1, 10 * H - 5), row(4, 11 * H - 60_000, "y"), row(5, 10 * H + 1)]), 13 * H, "t", complete=whole)
    r = sources_avail.reconcile(tmp_path, live_dir, 13 * H)
    assert (r["live_items"], r["deleted"], r["edited"], r["backdated"]) == (4, 2, 1, 1)
    assert r["backdated_examples"] == [("f", 5)]
