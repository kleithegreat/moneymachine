"""Regressions for Opus's round-four review (R1-R5) and the decided schedule (audit/decisions.md, 2026-11-08 18:04 UTC)."""

import json
import threading
import time

import httpx
import pytest

from ingest.policy import DAY, DELTA, HOUR
from thesis import market, report, runner
from thesis.tests.test_market import Venue, fake_clock
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401

MIN = 60_000


def real_market(track, tmp_path, monkeypatch, rows, now):
    clock = [now]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    x = Venue(rows)
    track.market = market.Market(tmp_path / "m", x)
    return x, clock


def hourly(lo, hi):
    return [(h, .0001) for h in range(lo // HOUR * HOUR, hi, HOUR)]


def test_hours_since_the_last_fill_are_the_registrations_own_read_not_unavailability(track, tmp_path, monkeypatch):
    acquired = MONDAY + 3 * HOUR
    lo = acquired - market.HISTORY["funding"] - 2 * DAY
    x, clock = real_market(track, tmp_path, monkeypatch, hourly(lo, MONDAY + 3 * DAY), acquired)
    track.market.funding("X", acquired, background=True)
    clock[0] = MONDAY + DAY + 5 * HOUR
    assert track.market.ready("X", clock[0])
    x.requests.clear()
    _, data = track.inputs("main", ["X"], clock[0], {"daily": {}})
    assert max(data["funding"]["X"]) == clock[0] // HOUR * HOUR
    assert (acquired + 1, clock[0] + 1) in x.requests


def test_history_the_venue_was_never_asked_for_is_unavailable(track, tmp_path, monkeypatch):
    now = MONDAY + 5 * HOUR
    lo = now - market.HISTORY["funding"] - 2 * DAY
    x, clock = real_market(track, tmp_path, monkeypatch, hourly(lo, now + HOUR), now)
    assert not track.market.ready("X", now)
    track.market.funding("X", now, start=now - 10 * HOUR)
    assert not track.market.ready("X", now)
    with pytest.raises(httpx.TransportError, match="not ready"):
        track.inputs("main", ["X"], now, {"daily": {}})


def test_a_gap_beyond_one_page_since_the_last_fill_stays_unavailable(track, tmp_path, monkeypatch):
    acquired = MONDAY + 3 * HOUR
    lo = acquired - market.HISTORY["funding"] - 2 * DAY
    x, clock = real_market(track, tmp_path, monkeypatch, hourly(lo, MONDAY + 60 * DAY), acquired)
    track.market.funding("X", acquired, background=True)
    assert track.market.ready("X", acquired + market.PAGE * HOUR)
    assert not track.market.ready("X", acquired + market.PAGE * HOUR + HOUR)


def test_background_discovery_sends_the_request_bodies_the_recorded_code_sent(tmp_path):
    sent = []

    class X:
        def post(self, body, *a, **kw):
            sent.append(body)
            return [None, {"name": "xyz"}] if body["type"] == "perpDexs" else {"universe": []}

        def meta(self):
            return self.post({"type": "meta"})

    m = market.Market(tmp_path, X())
    m.listings()
    foreground = list(sent)
    sent.clear()
    m.listings(background=True)
    assert sent == foreground == [{"type": "meta"}, {"type": "perpDexs"}, {"type": "meta", "dex": "xyz"}]


def attest(track, monkeypatch, date=MONDAY):
    monkeypatch.setattr(runner, "now_ms", lambda: date + runner.SNAPSHOT_OFFSET)
    track.acquire(date)
    assert track.attested(date) is not None


def test_acquisition_is_its_own_loop_and_a_long_session_cannot_delay_it(track, monkeypatch):
    clock = [MONDAY + DAY + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    cutoffs = []
    snapshot = track.snapshot
    monkeypatch.setattr(track, "snapshot", lambda cutoff: cutoffs.append(cutoff) or snapshot(cutoff))
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "session", lambda *a, **k: None)
    track.acquisitions(clock[0], MONDAY)
    assert cutoffs == [MONDAY + DAY + runner.SNAPSHOT_OFFSET]
    cutoffs.clear()
    track.schedule(clock[0], MONDAY)
    assert cutoffs == []


def test_the_runner_starts_acquisition_beside_the_other_loops(track, monkeypatch, tmp_path):
    names = []
    monkeypatch.setattr(runner, "forever", lambda name, *a, **k: names.append(name))
    monkeypatch.setattr(runner, "hourly_marks", lambda *a: None)
    track.market.record_marks = None
    frozen = tmp_path / "frozen.json"
    frozen.write_text(json.dumps({"manifest": track.manifest, "frozen": MONDAY}))
    monkeypatch.setattr(runner, "FROZEN", frozen)
    track.run()
    assert "acquire" in names


def test_the_benchmark_reads_the_days_attested_snapshot_with_bars_known_at_midnight(track, monkeypatch):
    attest(track, monkeypatch)
    taken = []
    snapshot = track.snapshot
    monkeypatch.setattr(track, "snapshot", lambda cutoff: taken.append(cutoff) or snapshot(cutoff))
    seen = []
    inputs = track.inputs
    monkeypatch.setattr(track, "inputs", lambda account, markets, now, snap: seen.append(snap) or inputs(account, markets, now, snap))
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 10 * MIN)
    track.benchmark(MONDAY)
    assert taken == [] and len(track.ledger.theses("benchmark")) == 4
    full = json.loads((track.root / "snapshots" / f"{MONDAY + runner.SNAPSHOT_OFFSET}.json").read_text())
    assert max(r[0] for r in full["daily"]["BTC"]) == MONDAY - DAY
    assert seen and all(max(r[0] for r in s["daily"]["BTC"]) + DAY + DELTA <= MONDAY for s in seen)
    assert not (track.root / "snapshots" / f"{MONDAY}.json").exists()


def test_the_benchmark_waits_for_its_days_snapshot_and_registers_at_the_first_whole_hour_after_it(track, monkeypatch):
    clock = [MONDAY + 6 * HOUR + 30 * MIN]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.acquisitions(clock[0], MONDAY)
    assert track.attested(MONDAY) is None and track.attested(MONDAY, MONDAY + DAY) is not None
    clock[0] = MONDAY + 7 * HOUR - 1
    track.benchmarks(clock[0], MONDAY)
    assert track.ledger.theses("benchmark") == []
    clock[0] = MONDAY + 7 * HOUR
    track.benchmarks(clock[0], MONDAY)
    assert len(track.ledger.theses("benchmark")) == 4


def test_a_snapshot_attested_after_the_deadline_serves_only_the_benchmark(track, monkeypatch):
    clock = [MONDAY + 6 * HOUR]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.acquisitions(clock[0], MONDAY)
    monkeypatch.setattr(track, "session", lambda *a, **k: pytest.fail("a late session"))
    track.schedule(clock[0], MONDAY)
    assert {c["session"] for _, _, c in track.ledger.records("session_missed")} == {f"main-{MONDAY}", f"noread-{MONDAY}"}


def test_only_a_snapshot_missing_the_whole_date_leaves_the_batch_unexecuted_and_recorded(track, monkeypatch):
    monkeypatch.setattr(track, "snapshot", lambda *a: pytest.fail("a replacement snapshot"))
    track.ledger.disclose("snapshot_ready", "main", {"taken": 0, "acquired": 0, "sha256": ""})
    for now in (MONDAY + 6 * HOUR, MONDAY + DAY - 1):
        monkeypatch.setattr(runner, "now_ms", lambda now=now: now)
        track.benchmarks(now, MONDAY)
        assert track.ledger.records("skip", "benchmark") == []
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + DAY)
    track.benchmarks(MONDAY + DAY, MONDAY)
    skips = track.ledger.records("skip", "benchmark")
    assert {c["market"] for _, _, c in skips} == set(runner.BENCHMARK) and {c["reason"] for _, _, c in skips} == {"no attested snapshot"}
    assert track.ledger.theses("benchmark") == []


def test_the_snapshot_records_when_its_listings_were_read(track, monkeypatch):
    clock = [MONDAY + 3 * HOUR]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    snap = track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)
    assert snap["taken"] == MONDAY + runner.SNAPSHOT_OFFSET and snap["listed_at"] == MONDAY + 3 * HOUR


def test_the_schedule_is_cutoff_0005_and_start_and_deadline_0500():
    assert runner.SNAPSHOT_OFFSET == 5 * MIN and runner.SESSION_OFFSET == 5 * HOUR


def test_an_attestation_after_a_non_mondays_deadline_is_refused_and_misses_both_sessions(track, monkeypatch):
    date = MONDAY + DAY
    clock = [date + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    snapshot = track.snapshot

    def slow(cutoff):
        snap = snapshot(cutoff)
        clock[0] = date + runner.SESSION_OFFSET + 1
        return snap

    monkeypatch.setattr(track, "snapshot", slow)
    track.acquisitions(clock[0], MONDAY)
    monkeypatch.setattr(track, "snapshot", lambda *a: pytest.fail("a replacement snapshot"))
    monkeypatch.setattr(track, "session", lambda *a, **k: pytest.fail("a late session"))
    track.acquisitions(clock[0], MONDAY)
    track.schedule(clock[0], MONDAY)
    assert track.ledger.records("snapshot_ready", "main") == []
    missed = {c["session"] for _, _, c in track.ledger.records("session_missed")}
    assert {f"main-{date}", f"noread-{date}"} <= missed


def test_a_snapshot_attested_at_the_boundary_is_late_and_never_also_on_time(track, monkeypatch):
    date = MONDAY + DAY
    clock = [date + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    snapshot = track.snapshot

    def to_the_boundary(cutoff):
        snap = snapshot(cutoff)
        clock[0] = date + runner.SESSION_OFFSET
        return snap

    monkeypatch.setattr(track, "snapshot", to_the_boundary)
    track.acquire(date)
    monkeypatch.setattr(track, "session", lambda *a, **k: pytest.fail("a late session"))
    track.schedule(clock[0], MONDAY)
    assert track.attested(date) is None and track.ledger.records("snapshot_ready", "main") == []
    assert {c["session"] for _, _, c in track.ledger.records("session_missed")} >= {f"main-{date}", f"noread-{date}"}


def test_the_deadline_decision_waits_for_an_attestation_in_flight(track, monkeypatch):
    """The attestation is stamped before it is written: the miss decision on the other thread must not fall between."""
    date = MONDAY + DAY
    clock = [date + runner.SESSION_OFFSET - 1]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    monkeypatch.setattr(track, "session", lambda *a, **k: None)
    monkeypatch.setattr(track, "ready", lambda d: True)
    real, racer = track.ledger.disclose, []

    def disclose(kind, *a, **k):
        if kind == "snapshot_ready":
            clock[0] = date + runner.SESSION_OFFSET
            racer.append(threading.Thread(target=track.schedule, args=(clock[0], MONDAY)))
            racer[0].start()
            time.sleep(.3)
        return real(kind, *a, **k)

    monkeypatch.setattr(track.ledger, "disclose", disclose)
    track.acquire(date)
    racer[0].join(10)
    assert len(track.ledger.records("snapshot_ready", "main")) == 1
    assert not [c for _, _, c in track.ledger.records("session_missed") if c["date"] == date and "no attested" in c["reason"]]


def test_each_dates_attestation_carries_its_timing_and_request_count_into_the_report(track, tmp_path, monkeypatch):
    fake_clock(monkeypatch, [MONDAY + runner.SNAPSHOT_OFFSET])
    sent = []

    def post(url, json):
        sent.append(json)
        payload = [None] if json["type"] == "perpDexs" else {"universe": []}
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.SNAPSHOT_OFFSET)
    x = market.Exchange(tmp_path / "x")
    monkeypatch.setattr(x.http, "post", post)
    track.market = market.Market(tmp_path / "m", x)
    track.acquire(MONDAY)
    report.write(track, MONDAY + runner.SESSION_OFFSET, tmp_path / "report.json")
    [row] = json.loads((tmp_path / "report.json").read_text())["snapshots"]
    assert row["taken"] == MONDAY + runner.SNAPSHOT_OFFSET and row["acquired"] == MONDAY + runner.SNAPSHOT_OFFSET
    assert row["listed_at"] == MONDAY + runner.SNAPSHOT_OFFSET and row["requests"] == len(sent) == 2
