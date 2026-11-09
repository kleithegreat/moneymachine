"""Refreeze round seven: Opus's round-six findings F1-F8, each from the construction that reproduced it."""

import json

import pytest

from ingest.policy import DAY, HOUR
from thesis import market, runner
from thesis.tests.test_market import Venue
from thesis.tests.test_refreeze_round6_inputs import MIN, acquire, synthetic_market  # noqa: F401
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401


@pytest.mark.parametrize("kind,step", [("1d", DAY), ("1h", HOUR)])
def test_f3_a_fetch_never_asks_past_the_last_row_it_can_show(tmp_path, kind, step):
    now = 40 * DAY + 12 * HOUR + 30 * MIN
    venue = Venue([(t, 1.0) for t in range(0, now, step)])
    shown = market.Market(tmp_path, venue).bars("X", kind, now)
    last = (now - market.SHOWN[kind]) // step * step
    assert shown[-1][0] == last
    assert venue.requests and max(end for _, end in venue.requests) <= last + step


def test_f3_a_second_read_in_the_same_period_asks_for_nothing(tmp_path):
    now = 40 * DAY + 12 * HOUR
    venue = Venue([(t, 1.0) for t in range(0, now, DAY)])
    m = market.Market(tmp_path, venue)
    m.bars("X", "1d", now)
    sent = len(venue.requests)
    m.bars("X", "1d", now + HOUR)
    assert len(venue.requests) == sent


def test_f1_a_missing_listing_observation_is_not_a_not_listed_market():
    snapshot = {"listings": {}, "markets": {}, "daily": {}, "ready": {}}
    assert "no listing observation" in runner.unbenchmarkable(snapshot, "BTC", (0, DAY))
    assert runner.unbenchmarkable({**snapshot, "listings": {"ETH": False}}, "BTC", (0, DAY)) == "not listed"


def test_f1_the_first_monday_midnight_needs_an_observation_before_it(track, monkeypatch, tmp_path):
    frozen = MONDAY + 10 * HOUR
    fake = FakeMarket(frozen)
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(runner, "FROZEN", tmp_path / "manifest.json")
    monkeypatch.setattr(runner.canary, "check", lambda: None)
    monkeypatch.setattr(runner, "Market", lambda *a: fake)
    monkeypatch.setattr(runner, "pinned_kernel", lambda *a, **k: None)
    monkeypatch.setattr(runner.harness, "manifest_hash", lambda kernel: "1" * 64)
    monkeypatch.setattr(runner, "now_ms", lambda: frozen)
    fake.listings_at = lambda at: (None, {}) if at < MONDAY - HOUR else (MONDAY - HOUR, {"BTC": False})
    fake_empty = FakeMarket(frozen)
    fake_empty.listings_at = lambda at: (None, {})
    monkeypatch.setattr(runner, "Market", lambda *a: fake_empty)
    with pytest.raises(SystemExit, match="listing observation"):
        runner.freeze()
    assert not (tmp_path / "manifest.json").exists()
    monkeypatch.setattr(runner, "Market", lambda *a: fake)
    runner.freeze()
    assert json.loads((tmp_path / "manifest.json").read_text())["frozen"] == frozen


def test_f1_a_freeze_before_the_first_monday_needs_no_observation(track, monkeypatch, tmp_path):
    frozen = MONDAY - 2 * DAY
    fake = FakeMarket(frozen)
    fake.listings_at = lambda at: (None, {})
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(runner, "FROZEN", tmp_path / "manifest.json")
    monkeypatch.setattr(runner.canary, "check", lambda: None)
    monkeypatch.setattr(runner, "Market", lambda *a: fake)
    monkeypatch.setattr(runner, "pinned_kernel", lambda *a, **k: None)
    monkeypatch.setattr(runner.harness, "manifest_hash", lambda kernel: "1" * 64)
    monkeypatch.setattr(runner, "now_ms", lambda: frozen)
    runner.freeze()
    assert (tmp_path / "manifest.json").exists()


def test_f2_monday_asks_only_for_benchmark_markets_beyond_the_current_listing(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.SNAPSHOT_OFFSET)
    fake = track.market
    fake.listings_at = lambda at: (MONDAY - HOUR, {"BTC": False, "GONE": False, "xyz:GOLD": False})
    fake.listings = lambda background=False: {"BTC": False}
    asked = set()
    bars = fake.bars
    fake.bars = lambda m, interval, now=None: (asked.add(m), bars(m, interval, now))[1]
    track.acquire(MONDAY)
    assert "GONE" not in asked and "xyz:GOLD" in asked


def test_f8_a_benchmark_market_not_ready_at_the_snapshot_is_skipped_not_retried(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.SNAPSHOT_OFFSET)
    track.market.ready = lambda m, now: m != "ETH"
    track.acquire(MONDAY)
    track.benchmark(MONDAY)
    skips = {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}
    assert skips["ETH"] == "funding not ready at the snapshot" and set(skips) == {"ETH", "flx:OIL"}
    assert track.unbenchmarked(MONDAY) == []
    assert {th["legs"][0][0] for th in track.ledger.theses("benchmark")} == set(runner.BENCHMARK) - {"ETH", "flx:OIL"}


@pytest.mark.parametrize("attested", [3 * HOUR, 5 * HOUR + 7 * MIN, 23 * HOUR + 59 * MIN + 30_000])
def test_f4_the_batch_registers_at_the_first_pass_after_attestation(track, tmp_path, monkeypatch, attested):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock, MONDAY + attested)
    assert track.unbenchmarked(MONDAY) == list(runner.BENCHMARK)
    track.benchmarks(clock[0], MONDAY)
    assert not track.unbenchmarked(MONDAY)
    assert "run missed" not in {c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}
    assert len(track.ledger.theses("benchmark")) == 4


def test_f5_a_benchmark_thesis_records_the_observation_it_used(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    snap = acquire(track, clock)
    assert snap["benchmark_listings_at"] == MONDAY - HOUR
    clock[0] = MONDAY + 5 * HOUR
    track.benchmark(MONDAY)
    assert {tuple(th["listings_read"]) for th in track.ledger.theses("benchmark")} == {(MONDAY - HOUR, MONDAY - HOUR)}

