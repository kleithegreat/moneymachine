"""The runner's ledger-driven schedule: resolutions once (or a missing-data status once), the frozen
benchmark's rule and skips, ablation inputs cut at registration, and the Monday arithmetic."""

import pytest

from gate import kernel
from ingest.policy import DAY, HOUR
from thesis import runner

ZERO = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}
MONDAY = 20388 * DAY  # 1970-01-01 was a Thursday, so day 20388 is a Monday


class FakeMarket:
    def __init__(self, hourly_until):
        self.until = hourly_until

    def listings(self):
        return {m: False for m in runner.BENCHMARK} | {"X": False}

    def bars(self, market, interval, now=None):
        if interval == "1d":
            up = market != "ETH"
            return [[t * DAY, 100.0 + (t if up else -t), 100.0 + (t + 1 if up else -t - 1)] for t in range(MONDAY // DAY - 400, MONDAY // DAY)
                    if market != "flx:OIL" or t != MONDAY // DAY - 1]
        return [[h * HOUR, 100.0, 100.0] for h in range(MONDAY // HOUR - 200, min(self.until, now or self.until) // HOUR)]

    def funding(self, market, now=None):
        return []

    def lag(self, market):
        return 0


@pytest.fixture
def track(tmp_path, monkeypatch):
    kernel.build()
    t = runner.Track(tmp_path)
    t.market = FakeMarket(MONDAY + 40 * DAY)
    monkeypatch.setattr(t, "config", lambda markets: {"initial": 10_000.0, "fee": 0.0, "costs": {m: ZERO for m in markets}, "fallback": []})
    return t


def test_mondays():
    for date in (MONDAY, MONDAY + 3 * DAY, MONDAY + 6 * DAY):
        assert date - ((date // DAY + 3) % 7) * DAY == MONDAY


def test_benchmark_registers_the_trend_sign_with_its_base_rate_and_logs_skips(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    theses = {th["legs"][0][0]: th for th in track.ledger.theses("benchmark")}
    assert theses["BTC"]["legs"] == [["BTC", 1]] and theses["ETH"]["legs"] == [["ETH", -1]]
    assert theses["BTC"]["T"] == MONDAY + 21 * DAY and theses["BTC"]["L"] == 0.1 and 0 < theses["BTC"]["p"] < 1
    skips = {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}
    assert skips == {"flx:OIL": "missing daily close"}
    assert track.benchmarked(MONDAY)


def test_resolutions_are_recorded_once_and_missing_data_once(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    track.market.until = MONDAY + 21 * DAY + HOUR
    track.resolve(MONDAY + 21 * DAY + HOUR)
    track.resolve(MONDAY + 21 * DAY + 2 * HOUR)
    statuses = [c["status"] for _, _, c in track.ledger.records("resolution")]
    assert statuses == ["resolved"] * 4


def test_missing_data_is_recorded_once_after_the_grace(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    track.market.until = MONDAY + 21 * DAY - HOUR
    track.resolve(MONDAY + 21 * DAY + HOUR)
    assert track.ledger.records("resolution") == []
    for later in (3, 4):
        track.resolve(MONDAY + 21 * DAY + later * HOUR)
    assert [c["status"] for _, _, c in track.ledger.records("resolution")] == ["missing data"] * 4


def test_ablation_sees_only_prices_known_at_registration(track):
    th = {"legs": [["X", 1]], "t_r": MONDAY - 10 * DAY + 5 * HOUR, "T": MONDAY + 10 * DAY}
    snapshot = {"listings": {"X": False}, "daily": {"X": track.market.bars("X", "1d")}, "markets": {}}
    task, snap = track.ablation_task(th, snapshot)
    assert max(r[0] for r in snap["daily"]["X"]) + DAY <= th["t_r"] and task["horizon_ms"] == th["T"]
    assert "catalyst" not in task and "p" not in task


def test_report_separates_forecasts_from_positions_and_states_the_floor(track, monkeypatch, tmp_path):
    from thesis import report

    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    track.market.until = MONDAY + 30 * DAY
    report.write(track, MONDAY + 30 * DAY, tmp_path / "r.json")
    import json

    r = json.loads((tmp_path / "r.json").read_text())
    b = r["accounts"]["benchmark"]
    assert b["theses"] == 4 and b["resolved"] == 4 and b["forecast"]["n_resolved"] == 4 and "as_managed_mean" in b["positions"]
    assert r["accounts"]["main"] == {"theses": 0} and report.NO_CLAIM in r["statements"]
    assert [s["market"] for s in r["benchmark_skips"]] == ["flx:OIL"]
