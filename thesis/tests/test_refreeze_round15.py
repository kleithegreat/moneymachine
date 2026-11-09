"""Round fifteen: Argon's rounds 13-14 review (D1-D5) and the Guarantee 1 and 2 gaps, each through the runner's own paths."""

import multiprocessing as mp
import os
import signal
import time

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import market, runner
from thesis.tests.test_market import fake_clock
from thesis.tests.test_record_before_reply import wait_for
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


class PausesAtX(FakeMarket):
    """BTC fails every read; reading X marks `paused` and stalls, where the test kills the process."""

    def __init__(self, until, paused=None):
        super().__init__(until)
        self.paused, self.btc = paused, 0

    def bars(self, market, interval, now=None):
        if market == "BTC":
            self.btc += 1
            raise httpx.ReadTimeout("btc down")
        if market == "X" and self.paused is not None:
            self.paused.touch()
            time.sleep(3600)
        return super().bars(market, interval, now)


def acquire_until_killed(track, paused):
    track.market = PausesAtX(MONDAY + 40 * DAY, paused)
    track.acquire(MONDAY)


def test_d4_a_pass_killed_midway_resumes_its_draft_its_readiness_time_and_its_failures(track, monkeypatch, tmp_path):
    at(monkeypatch, NINE)
    child = mp.get_context("fork").Process(target=acquire_until_killed, args=(track, tmp_path / "paused"))
    child.start()
    try:
        wait_for(tmp_path / "paused")
        os.kill(child.pid, signal.SIGKILL)
        child.join()
    finally:
        if child.is_alive():
            os.kill(child.pid, signal.SIGKILL)
    track.draft = None
    track.market = PausesAtX(MONDAY + 40 * DAY)
    at(monkeypatch, CUT + 60_000)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap["readiness_at"] == NINE and "BTC" in snap["failed"] and track.market.btc == 0


TUESDAY = MONDAY + DAY
TUESDAY_CUT = TUESDAY + runner.RETRY_UNTIL


def test_d4_a_retry_keeps_the_daily_bars_its_first_attempt_read_through_the_real_limiter(track, monkeypatch, tmp_path):
    """Through the real Exchange and its limiter: BTC's hourly read fails on the first pass. The retry at 04:44:30 UTC asks
    only for the hourly read, never again for the daily bars. Its first page is admitted before the cutoff and answered
    after it; its next page is an admission within a retry at the cutoff, cancelled, so the retry is left incomplete there
    and BTC's failure is final (wording (a))."""
    clock = [TUESDAY + runner.SNAPSHOT_OFFSET + 60_000]
    fake_clock(monkeypatch, clock)
    monkeypatch.setattr(runner, "now_ms", lambda: int(clock[0]))
    daily, hourly = [], []

    def post(url, json):
        request = httpx.Request("POST", url)
        if json["type"] == "meta":
            return httpx.Response(200, json={"universe": [{"name": "BTC"}]}, request=request)
        if json["type"] == "perpDexs":
            return httpx.Response(200, json=[None], request=request)
        req = json["req"]
        step = DAY if req["interval"] == "1d" else HOUR
        (daily if step == DAY else hourly).append(dict(clock=clock[0]))
        if step == HOUR and clock[0] < TUESDAY_CUT - HOUR:
            return httpx.Response(500, json={}, request=request)
        if step == HOUR:
            clock[0] += 60_000
        first = max(req["startTime"], TUESDAY - 400 * DAY) // step * step
        rows = [{"t": t, "o": "100", "c": "101"} for t in range(first, min(req["endTime"] + 1, TUESDAY), step)]
        return httpx.Response(200, json=rows, request=request)

    x = market.Exchange(tmp_path / "x")
    monkeypatch.setattr(x.http, "post", post)
    track.market = market.Market(tmp_path / "m", x)
    track.acquire(TUESDAY)
    assert track.attested(TUESDAY) is None and len(daily) == 1
    clock[0] = TUESDAY_CUT - 30_000
    track.acquire(TUESDAY)
    snap = track.attested(TUESDAY)
    assert len(daily) == 1 and len(hourly) == 7 and snap["failed"] == {"BTC": "TimeoutError('admission cancelled')"}


class CoreThenDexes(FakeMarket):
    """The core listing answers once and then fails; the builder-dex list fails once and then answers."""

    def __init__(self, until):
        super().__init__(until)
        self.core = self.dex_list = 0

    def universe(self, dex=None, *, background=False):
        self.core += dex is None
        if dex is None and self.core > 1:
            raise httpx.ReadTimeout("core down")
        return super().universe(dex)

    def dexes(self, *, background=False):
        self.dex_list += 1
        if self.dex_list == 1:
            raise httpx.ReadTimeout("dex list down")
        return []


def test_d5_a_core_listing_read_is_kept_when_the_builder_dex_list_fails(track, monkeypatch):
    track.market = CoreThenDexes(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    with pytest.raises(httpx.ReadTimeout):
        track.acquire(MONDAY)
    at(monkeypatch, NINE + 60_000)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is not None


class LateDex(FakeMarket):
    """Builder dex xyz is down until `heal`."""

    def __init__(self, until, clock, heal):
        super().__init__(until)
        self.clock, self.heal = clock, heal

    def dexes(self, *, background=False):
        return ["xyz"]

    def universe(self, dex=None, *, background=False):
        if dex is None:
            return {m: False for m in ("BTC", "ETH", "flx:OIL")}
        if self.clock[0] < self.heal:
            raise httpx.ConnectError("xyz down")
        return {"xyz:GOLD": False, "xyz:XYZ100": False}


def test_d5_each_listing_source_is_labelled_with_the_time_it_was_read(track, monkeypatch):
    clock = [NINE]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.market = LateDex(MONDAY + 40 * DAY, clock, NINE + HOUR)
    track.acquire(MONDAY)
    clock[0] = NINE + HOUR
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap["listed_at"] == {"": NINE, "xyz": NINE + HOUR}
