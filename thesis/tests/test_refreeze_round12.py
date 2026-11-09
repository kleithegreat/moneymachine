"""Round twelve: a pass is a retry only once the date's first pass has attempted its whole scope (Opus R2)."""

import tempfile
import threading
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import runner
from thesis.tests.test_runner import MONDAY, FakeMarket

MINUTE = 60_000


class Outage(FakeMarket):
    def __init__(self, until, heal, clock, slow=False):
        super().__init__(until)
        self.heal, self.clock, self.slow = heal, clock, slow

    def universe(self, dex=None, *, background=False):
        if self.clock[0] < self.heal:
            raise httpx.ConnectError("venue down")
        return {m: False for m in (*runner.BENCHMARK, *(f"A{i:02}" for i in range(20)))} if self.slow else super().universe(dex)

    def listings_at(self, at):
        return at - HOUR, {m: False for m in runner.BENCHMARK}

    def bars(self, market, interval, now=None):
        if self.slow:
            self.clock[0] += 30_000
        return super().bars(market, interval, now)


def run_day(monkeypatch, heal, slow):
    clock = [0]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track = object.__new__(runner.Track)
    track.root, track.draft, track.stop = Path(tempfile.mkdtemp()), None, threading.Event()
    track.market = Outage(MONDAY + 40 * DAY, MONDAY + heal, clock, slow)
    track.ledger = SimpleNamespace(theses=lambda account: [])
    for minute in range(5, 24 * 60):
        clock[0] = max(clock[0], MONDAY + minute * MINUTE)
        try:
            snap = track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)
        except httpx.HTTPError:
            continue
        if snap is not None:
            return snap
    return None


def test_monday_core_listing_outage_healing_after_the_retry_cutoff_still_attests(monkeypatch):
    snap = run_day(monkeypatch, 4 * HOUR + 46 * MINUTE, slow=False)
    assert snap is not None and snap["failed"] == {}


def test_monday_outage_healing_before_the_cutoff_is_not_cut_by_it(monkeypatch):
    snap = run_day(monkeypatch, 4 * HOUR + 30 * MINUTE, slow=True)
    assert snap is not None and not any(m in snap["failed"] for m in runner.BENCHMARK)


def test_a_builder_dex_list_failure_leaves_no_snapshot_until_it_heals(monkeypatch):
    clock = [0]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])

    class DexListDown(FakeMarket):
        def dexes(self, *, background=False):
            if clock[0] < MONDAY + HOUR:
                raise httpx.ConnectError("perpDexs down")
            return []

    track = object.__new__(runner.Track)
    track.root, track.draft, track.stop = Path(tempfile.mkdtemp()), None, threading.Event()
    track.market, track.ledger = DexListDown(MONDAY + 40 * DAY), SimpleNamespace(theses=lambda account: [])
    clock[0] = MONDAY + 5 * MINUTE
    with pytest.raises(httpx.HTTPError):
        track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)
    clock[0] = MONDAY + HOUR
    assert track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)["failed"] == {}
