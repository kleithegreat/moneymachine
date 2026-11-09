"""Round eleven: Argon's N1 deadline and moving-readiness counterexamples."""
import httpx
import pytest

from ingest.hl import WeightLimit
from ingest.policy import DAY, HOUR
from thesis import runner
from thesis.market import FRESH
from thesis.tests.test_refreeze_round10 import NINE, at, blip
from thesis.tests.test_runner import MONDAY, track  # noqa: F401


def test_f3_no_retry_starts_at_deadline_even_inside_a_pass(track, monkeypatch):
    clock = [NINE]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    bars, attempts = track.market.bars, []

    def failing(m, interval, now=None):
        if m in {"BTC", "ETH"}:
            attempts.append((m, clock[0]))
            if clock[0] >= MONDAY + runner.RETRY_UNTIL - 1:
                clock[0] = MONDAY + runner.RETRY_UNTIL
            raise httpx.ReadTimeout("persistent")
        return bars(m, interval, now)

    track.market.bars = failing
    track.acquire(MONDAY)
    attempts.clear()
    clock[0] = MONDAY + runner.RETRY_UNTIL - 1
    track.acquire(MONDAY)
    assert attempts == [("BTC", MONDAY + runner.RETRY_UNTIL - 1)]
    assert set(track.attested(MONDAY, MONDAY + DAY)["failed"]) == {"BTC", "ETH"}


def test_f3_pass_at_deadline_attests_without_retry(track, monkeypatch):
    track.market = blip("BTC", "1h", 10**6)(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    failures = type(track.market).failures
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    assert type(track.market).failures == failures
    assert "BTC" in track.attested(MONDAY, MONDAY + DAY)["failed"]


def test_f4_later_readiness_does_not_move_earlier_funding_lower_bound(track, monkeypatch):
    track.market = blip("ETH", "1h", 1)(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    at(monkeypatch, NINE + 2 * HOUR)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    track.inputs("main", ["BTC"], NINE + 3 * HOUR, snap)
    assert ("funding", "BTC", NINE - FRESH) in track.market.calls


@pytest.mark.parametrize("when", [runner.RETRY_UNTIL, runner.RETRY_UNTIL + 60_000])
def test_f3_first_failure_on_a_late_initial_pass_is_final(track, monkeypatch, when):
    track.market = blip("BTC", "1h", 10**6)(MONDAY + 40 * DAY)
    at(monkeypatch, MONDAY + when)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert "BTC" in snap["failed"] and "BTC" not in snap["markets"] and snap["ready"]["BTC"] is False
    failures = type(track.market).failures
    track.acquire(MONDAY)
    assert type(track.market).failures == failures


def test_f3_retry_cannot_send_another_page_after_cutoff_and_releases_hold(track, monkeypatch):
    clock, attempts = [NINE], []
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    limiter, bars = WeightLimit(120), track.market.bars
    track.market.hold = lambda cancel=None: limiter.hold(cancel)

    def paginated(m, interval, now=None):
        if m != "BTC":
            return bars(m, interval, now)
        if clock[0] == NINE:
            raise httpx.ReadTimeout("first failure")
        for _ in range(2):
            limiter.charge(1)
            attempts.append(clock[0])
            clock[0] = MONDAY + runner.RETRY_UNTIL
        raise AssertionError("second page must not be admitted")

    track.market.bars = paginated
    track.acquire(MONDAY)
    clock[0] = MONDAY + runner.RETRY_UNTIL - 1
    track.acquire(MONDAY)
    assert attempts == [MONDAY + runner.RETRY_UNTIL - 1]
    assert limiter.holds == 0 and limiter.foreground == []
    assert track.attested(MONDAY, MONDAY + DAY)["failed"]["BTC"]


def test_f4_every_check_uses_the_same_fixed_time_across_passes(track, monkeypatch):
    track.market = blip("ETH", "1h", 1)(MONDAY + 40 * DAY)
    times = []
    track.market.ready = lambda m, now: times.append(now) or True
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    at(monkeypatch, NINE + HOUR)
    track.acquire(MONDAY)
    assert times and set(times) == {NINE}
    assert track.attested(MONDAY, MONDAY + DAY)["readiness_at"] == NINE


def test_failed_readiness_is_unavailable_in_both_views(track, monkeypatch):
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL)

    def ready(m, now):
        if m == "BTC":
            raise httpx.ReadTimeout("readiness failed")
        return True

    track.market.ready = ready
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert "BTC" in snap["failed"] and not snap["ready"]["BTC"]
    assert all("BTC" not in snap[k] for k in ("markets", "daily", "benchmark_markets"))
