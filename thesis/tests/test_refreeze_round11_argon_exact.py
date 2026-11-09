"""Argon's full-size timing inputs, without a ledger, kernel or network."""
import threading
from types import SimpleNamespace

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import runner
from thesis.market import FRESH
from thesis.tests.test_runner import FakeMarket, MONDAY


def draft_track(tmp_path, market):
    track = object.__new__(runner.Track)
    track.root, track.draft, track.stop, track.market = tmp_path, None, threading.Event(), market
    track.ledger = SimpleNamespace(theses=lambda account: [])
    track.config = lambda markets: {}
    return track


@pytest.mark.parametrize("date", [MONDAY, MONDAY + DAY])
def test_argon_eleven_91_second_failures_do_not_chain_past_retry_cutoff(tmp_path, monkeypatch, date):
    clock, attempts = [date + runner.SNAPSHOT_OFFSET], []
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])

    class Eleven(FakeMarket):
        def universe(self, dex=None, *, background=False):
            return {f"M{i:02}": False for i in range(11)}

        def listings_at(self, at):
            return at - HOUR, self.universe()

        def bars(self, market, interval, now=None):
            attempts.append((market, clock[0]))
            clock[0] += 91_000
            raise httpx.ReadTimeout("six failed attempts")

    track = draft_track(tmp_path, Eleven(date))
    assert track.snapshot(date + runner.SNAPSHOT_OFFSET) is None
    attempts.clear()
    clock[0] = date + 4 * HOUR + 44 * 60_000
    snap = track.snapshot(date + runner.SNAPSHOT_OFFSET)
    assert len(attempts) == 1 and clock[0] == date + 4 * HOUR + 45 * 60_000 + 31_000
    assert len(snap["failed"]) == 11 and not snap["markets"]


def test_argon_347_early_markets_keep_funding_when_eth_heals_at_0444(tmp_path, monkeypatch):
    first = MONDAY + 15 * 60_000
    clock, covered_until = [first], first - FRESH + HOUR
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])

    class Many(FakeMarket):
        def universe(self, dex=None, *, background=False):
            return {m: False for m in ["BTC", "ETH", *(f"M{i:03}" for i in range(346))]}

        def listings_at(self, at):
            return at - HOUR, self.universe()

        def bars(self, market, interval, now=None):
            if market == "ETH" and clock[0] < MONDAY + 4 * HOUR + 44 * 60_000:
                raise httpx.ReadTimeout("ETH fails until late pass")
            return super().bars(market, interval, now)

        def ready(self, market, now):
            return market != "BTC" or covered_until >= now - FRESH

    market = Many(MONDAY + DAY)
    track = draft_track(tmp_path, market)
    assert track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET) is None
    assert len(track.draft[1]["ready"]) == 347
    clock[0] = MONDAY + 4 * HOUR + 44 * 60_000
    snap = track.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)
    track.inputs("main", ["BTC"], MONDAY + 5 * HOUR + 10 * 60_000, snap)
    starts = [c[2] for c in market.calls if c[:2] == ("funding", "BTC")]
    assert snap["readiness_at"] == first and starts == [first - FRESH]
    assert starts[0] <= covered_until
