"""The runner's ledger-driven schedule: resolutions once (or a missing-data status once), the frozen
benchmark's rule and skips, ablation inputs cut at registration, and the Monday arithmetic."""

import json
import threading
import time

import httpx
import pytest

from gate import kernel
from ingest.policy import DAY, DELTA, HOUR
from thesis import report, runner

ZERO = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}
MONDAY = 20388 * DAY  # 1970-01-01 was a Thursday, so day 20388 is a Monday


class FakeMarket:
    def __init__(self, hourly_until):
        self.until = hourly_until

    def listings(self):
        return {m: False for m in runner.BENCHMARK} | {"X": False}

    def bars(self, market, interval, now=None):
        """Daily bars known by `now`, as the real market's: a bar is known DELTA after its close."""
        if interval == "1d":
            up = market != "ETH"
            return [[t * DAY, 100.0 + (t if up else -t), 100.0 + (t + 1 if up else -t - 1)] for t in range(MONDAY // DAY - 400, MONDAY // DAY)
                    if (market != "flx:OIL" or t != MONDAY // DAY - 2) and (now is None or (t + 1) * DAY + DELTA <= now)]
        return [[h * HOUR, 100.0, 100.0] for h in range(MONDAY // HOUR - 200, min(self.until, now or self.until) // HOUR)]

    def funding(self, market, now=None):
        return [[h * HOUR, 0.0] for h in range((MONDAY // DAY - 400) * 24, min(self.until, now or self.until) // HOUR + 1)]

    def lag(self, market):
        return 0


@pytest.fixture
def track(tmp_path, monkeypatch):
    kernel.build()
    monkeypatch.setattr(runner.harness, "manifest_hash", lambda kernel: "0" * 64)
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
    track.resolve(MONDAY + 30 * DAY)
    report.write(track, MONDAY + 30 * DAY, tmp_path / "r.json")
    import json

    r = json.loads((tmp_path / "r.json").read_text())
    b = r["accounts"]["benchmark"]
    assert b["theses"] == 4 and b["resolved"] == 4 and b["forecast"]["n_resolved"] == 4 and "as_managed_mean" in b["positions"]
    assert r["accounts"]["main"] == {"theses": 0} and report.NO_CLAIM in r["statements"]
    assert [s["market"] for s in r["benchmark_skips"]] == ["flx:OIL"]


def test_outcome_markets_show_the_named_markets_prices_at_t_r_and_resolution(tmp_path):
    from ingest import datalayer

    def poll(feed, recv, markets):
        http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, json=markets)))
        rec = datalayer.get(http, feed, "https://gamma-api.polymarket.com/markets", None, tmp_path)
        lines = (tmp_path / f"datalayer-{time.strftime('%Y%m%d', time.gmtime(rec['sent'] / 1000))}.jsonl")
        rows = [json.loads(l) for l in lines.read_text().splitlines()]
        rows[-1]["recv"] = recv
        lines.write_text("".join(json.dumps(r) + "\n" for r in rows))

    m = {"id": "7", "question": "Fed cut in December?", "outcomes": '["Yes", "No"]'}
    poll("polymarket-active", 100, [m | {"outcomePrices": '["0.3", "0.7"]', "closed": False}])
    poll("polymarket-active", 200, [m | {"outcomePrices": '["0.4", "0.6"]', "closed": False}])
    poll("polymarket-resolved", 900, [m | {"outcomePrices": '["1", "0"]', "closed": True}])
    theses = [{"id": "main-1", "p": 0.6, "t_r": 150, "outcome_market": "7"}, {"id": "main-2", "p": 0.5, "t_r": 150, "outcome_market": None}]
    out = report.outcome_markets(theses, tmp_path)
    assert out == {"main-1": {"market": "7", "p": 0.6, "question": "Fed cut in December?",
                              "prices_at_t_r": {"Yes": "0.3", "No": "0.7"}, "resolution": {"Yes": "1", "No": "0"}}}


def test_the_manifest_covers_every_file_the_track_runs_on():
    from thesis import harness

    files = {str(p.relative_to(harness.REPO)) for p in harness.manifest_files(runner.ROOT / "bin" / "mm")}
    assert {"ingest/hl.py", "ingest/fallback.py", "ingest/terms.py", "thesis/report.py", "thesis/positions.py",
            "sandbox/session.py", "gate/kernel.py", "data/thesis/bin/mm", "venue/hyperliquid/execution.json",
            "venue/hyperliquid/rules.json", "policy.json", "flake.lock", "thesis/brief.md"} <= files
    assert not any(f.startswith(("thesis/tests", "data/")) for f in files - {"data/thesis/bin/mm"})


def test_a_new_root_pins_its_kernel_before_hashing_it(tmp_path, monkeypatch):
    kernel.build()
    hashed = []
    monkeypatch.setattr(runner.harness.session, "identity", lambda files, extra: hashed.extend(files) or "0" * 64)
    runner.harness.manifest_hash.cache_clear()
    runner.Track(tmp_path)
    assert tmp_path / "bin" / "mm" in hashed and (tmp_path / "bin" / "mm").exists()


def test_a_loop_finishes_its_step_and_ends_when_stopped():
    stop, steps = threading.Event(), []
    runner.forever("t", lambda: (steps.append(1), stop.set()), lambda now: 0, stop)
    assert steps == [1]
