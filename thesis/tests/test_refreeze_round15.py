"""Round fifteen: Argon's rounds 13-14 review (D1-D5) and the Guarantee 1 and 2 gaps, each through the runner's own paths."""

import httpx

from ingest.policy import DAY
from thesis import runner
from thesis.tests.test_refreeze_round10 import NINE, at
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401

CUT = MONDAY + runner.RETRY_UNTIL


class FlxDown(FakeMarket):
    """flx:OIL is delisted at Monday midnight; the flx dex's live listing fails all day."""

    def dexes(self, *, background=False):
        return ["flx"]

    def universe(self, dex=None, *, background=False):
        if dex == "flx":
            raise httpx.ConnectError("flx down")
        return {m: False for m in ("BTC", "ETH", "xyz:XYZ100", "xyz:GOLD", "X")}

    def listings_at(self, at):
        return at - 3_600_000, {**{m: False for m in ("BTC", "ETH", "xyz:XYZ100", "xyz:GOLD", "X")}, "flx:OIL": True}


def test_d2_a_market_delisted_at_monday_midnight_is_skipped_as_delisted_whatever_its_dex_does_after(track, monkeypatch):
    track.market = FlxDown(MONDAY + 40 * DAY)
    at(monkeypatch, CUT + 60_000)
    track.acquire(MONDAY)
    track.benchmark(MONDAY)
    skips = {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}
    assert skips["flx:OIL"] == "delisted"


class DelistedAfterMidnight(FakeMarket):
    """X is listed at Monday midnight, delisted by the snapshot, and every read of it fails."""

    def universe(self, dex=None, *, background=False):
        return {**super().universe(dex), "X": True}

    def bars(self, market, interval, now=None):
        if market == "X":
            raise httpx.ReadTimeout("x down")
        return super().bars(market, interval, now)


def test_d2_a_market_outside_the_benchmark_delisted_by_the_snapshot_needs_no_read(track, monkeypatch):
    track.market = DelistedAfterMidnight(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap is not None and "X" not in snap["failed"]
