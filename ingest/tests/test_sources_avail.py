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
    polls = [(10 * H, [post(1, 10 * H - 5)]), (11 * H, [post(2, 11 * H - 60_000), post(3, 11 * H - 60_000), post(4, 11 * H - 60_000, "x")]),
             (14 * H, [post(6, 14 * H - 5)])]
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


def test_availability_report_counts_new_items_and_edits(tmp_path):
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    edited = post(1, 10 * H - 5) | {"version": 2, "updated_at": iso(11 * H - 1_000)}
    polls = [(10 * H, [post(1, 10 * H - 5)]), (10 * H + 300_000, [post(1, 10 * H - 5)]),
             (11 * H, [post(2, 11 * H - 60_000), edited]), (12 * H, [post(2, 11 * H - 60_000), edited])]
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps({"source": "discourse", "key": "f", "sent": t, "recv": t, "data": d}) + "\n"
                                                      for t, d in polls))
    r = sources_avail.analyze(live_dir)
    assert r["window"] == [10 * H, 12 * H] and r["poll_gaps_s"]["over_10_min"] == 2
    assert r["new_items_claimed_lag_ms"] == {"n": 1, "min": 60_000, "p50": 60_000, "p90": 60_000, "max": 60_000}
    assert r["edits_claimed_lag_ms"]["n"] == 1 and r["claimed_rule_failures"] == {"items": 0, "edits": 0}
    assert r["operative_slack_ms"] == 60_000
    assert r["polls_without_overlap"] == 0 and r["failed_polls"] == 0
    assert abs(r["uptime_fraction"] - 300_000 / (2 * H)) < 1e-12


def test_a_poll_sharing_no_item_with_the_previous_one_is_counted(tmp_path):
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    polls = [(10 * H, [post(1, 10 * H - 5)]), (10 * H + 300_000, [post(1, 10 * H - 5), post(2, 10 * H)]),
             (10 * H + 600_000, [post(3, 10 * H + 500_000)]), (10 * H + 900_000, None)]
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps({"source": "discourse", "key": "f", "sent": t, "recv": t, "data": d}) + "\n"
                                                      for t, d in polls))
    r = sources_avail.analyze(live_dir)
    assert r["polls_without_overlap"] == 1 and r["failed_polls"] == 1


def test_kernel_clock_is_a_bound_and_validity_checked(tmp_path):
    from ingest.sources_record import kernel_clock
    read = kernel_clock()
    assert set(read) == {"maxerror_ms", "esterror_ms", "unsynced"} and read["maxerror_ms"] >= 0
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    clock = lambda t, e, u: {"source": "clock", "key": "kernel", "sent": t, "recv": t, "data": {"maxerror_ms": e, "esterror_ms": 0.0, "unsynced": u}}
    (live_dir / "sources-x.jsonl").write_text("".join(json.dumps(c) + "\n" for c in [clock(H, 5.0, False), clock(2 * H, 40.0, False)]))
    r = sources_avail.analyze(live_dir)
    assert r["clock_bound_ms"] == {"max_maxerror": 40.0, "n": 2, "valid": True} and r["clock_offset_ms"] is None
    (live_dir / "sources-x.jsonl").write_text(json.dumps(clock(H, 5.0, True)) + "\n" + json.dumps(clock(2 * H, 1500.0, False)) + "\n")
    assert sources_avail.analyze(live_dir)["clock_bound_ms"]["valid"] is False
