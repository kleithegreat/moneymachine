"""Frozen readiness must preserve the entire registration funding tail."""

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import market, runner
from thesis.tests.test_market import Venue, fake_clock
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401


@pytest.mark.parametrize("account,hours", [("main", 4), ("noread", 6)])
def test_frozen_ready_registration_fills_every_hour_since_acquisition(
        track, tmp_path, monkeypatch, account, hours):
    def forbidden(*args, **kwargs):
        pytest.fail("readiness-tail test must not use the network")

    monkeypatch.setattr(httpx.Client, "send", forbidden)
    old_acquired = MONDAY - 495 * HOUR
    clock = [old_acquired - 1]
    fake_clock(monkeypatch, clock)
    monkeypatch.setattr(runner, "now_ms", lambda: int(clock[0]))
    rows = [(t, 0.001) for t in range(
        old_acquired - market.HISTORY["funding"] - DAY, MONDAY + DAY, HOUR)]
    coverage = market.Market(tmp_path / "funding", Venue(rows))
    coverage.funding("X", clock[0], background=True)
    prices = FakeMarket(MONDAY + DAY)
    monkeypatch.setattr(coverage, "bars", prices.bars)
    monkeypatch.setattr(coverage, "lag", prices.lag)
    track.market = coverage
    snapshot = {"readiness_at": MONDAY + runner.SNAPSHOT_OFFSET,
                "ready": {"X": True}, "daily": {}}
    assert coverage.ready("X", snapshot["readiness_at"])
    clock[0] = MONDAY + hours * HOUR
    assert coverage.ready("X", clock[0]) == (account == "main")

    _, data = track.inputs(account, ["X"], clock[0], snapshot)

    assert data["cutoff"] == clock[0]
    expected = set(range(old_acquired, clock[0] + HOUR, HOUR))
    missing = sorted(expected - set(data["funding"]["X"]))
    assert not missing, f"{account} left unacquired hourly funding timestamps: {missing}"
    assert all(data["funding"]["X"][t] == 0.001 for t in expected)
