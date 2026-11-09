"""Round eight: G1-G4 of the round-seven review (audit/reviews/2026-11-08-opus-thesis-refreeze-round7.md)."""
import json
import threading
from pathlib import Path

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import runner
from thesis.tests.test_refreeze_round6_inputs import MIN, acquire, synthetic_market
from thesis.tests.test_runner import MONDAY, failing_once, track  # noqa: F401

ROOT = Path(__file__).resolve().parents[2]


def skips(track):
    return {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}


@pytest.mark.parametrize("attest", [23 * HOUR + 59 * MIN + 30_000, DAY - 1_000])
def test_g1_an_attestation_after_the_last_pass_before_midnight_registers(track, tmp_path, monkeypatch, attest):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    clock[0] = MONDAY + DAY - 45_000
    track.benchmarks(clock[0], MONDAY)
    acquire(track, clock, MONDAY + attest)
    clock[0] = MONDAY + DAY + 15_000
    track.benchmarks(clock[0], MONDAY)
    assert set(skips(track)) == {"flx:OIL"} and "run missed" not in skips(track).values()
    assert len(track.ledger.theses("benchmark")) == 4


def test_g1_no_attested_snapshot_waits_for_an_attestation_in_flight(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    writing, release = threading.Event(), threading.Event()
    disclose = track.ledger.disclose

    def slow(kind, account, content):
        if kind == "snapshot_ready":
            writing.set()
            release.wait(5)
        return disclose(kind, account, content)

    monkeypatch.setattr(track.ledger, "disclose", slow)
    clock[0] = MONDAY + DAY - 100
    attesting = threading.Thread(target=track.acquire, args=(MONDAY,))
    attesting.start()
    assert writing.wait(5)
    clock[0] = MONDAY + DAY + 1_000
    benchmarking = threading.Thread(target=track.benchmarks, args=(clock[0], MONDAY))
    benchmarking.start()
    release.set()
    attesting.join()
    benchmarking.join()
    assert set(skips(track)) == {"flx:OIL"} and "run missed" not in skips(track).values()
    assert len(track.ledger.theses("benchmark")) == 4


def test_g1_a_batch_failing_past_the_stated_give_up_time_is_logged_missed(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 6 * HOUR)
    track.acquire(MONDAY)
    failing_once(track.market, "ETH")
    with pytest.raises(httpx.TransportError):
        track.benchmarks(MONDAY + 6 * HOUR, MONDAY)
    track.benchmarks(runner.BENCHMARK_GIVE_UP + MONDAY, MONDAY)
    assert track.unbenchmarked(MONDAY) == []
    assert skips(track) == {m: "run missed" for m in runner.BENCHMARK if m != "BTC"}


def test_g1_no_snapshot_for_the_whole_date_is_logged_at_its_end(track):
    track.benchmarks(MONDAY + DAY - 1, MONDAY)
    assert skips(track) == {}
    track.benchmarks(MONDAY + DAY, MONDAY)
    assert set(skips(track).values()) == {"no attested snapshot"} and track.unbenchmarked(MONDAY) == []


def test_g2_a_batch_with_an_operational_skip_is_not_executed():
    text = (ROOT / "audit/stage10/criteria-revision-draft.md").read_text()
    assert "A batch with any operational skip is not executed" in text
    for reason in ("no attested snapshot", "no listing observation", "funding not ready at the snapshot", "run missed"):
        assert f"\"{reason}" in text


def test_g3_the_latency_allowance_is_derived_from_the_stress_inventory():
    tex = (ROOT / "docs/whitepaper.tex").read_text()
    assert "1,144" not in tex and r"796\cdot0.45=358.2" in tex


def test_g4_freeze_records_the_instant_its_guard_decided(tmp_path, monkeypatch):
    clock = [MONDAY - 1_000]
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(runner, "FROZEN", tmp_path / "manifest.json")
    monkeypatch.setattr(runner.canary, "check", lambda: None)
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    monkeypatch.setattr(runner.harness, "manifest_hash", lambda kernel: "1" * 64)

    def pin(*a, **k):
        clock[0] += 5_000
    monkeypatch.setattr(runner, "pinned_kernel", pin)

    class Slow:
        def __init__(self, *a):
            self.seen = []

        def listings_at(self, at):
            return (None, {}) if not self.seen or self.seen[0] > at else (self.seen[0], {"BTC": False})

        def listings(self):
            clock[0] += 3_000
            self.seen.append(clock[0])
            return {"BTC": False}

        def ready(self, m, now):
            return True
    monkeypatch.setattr(runner, "Market", lambda *a: Slow())
    runner.freeze()
    frozen = json.loads((tmp_path / "manifest.json").read_text())["frozen"]
    assert frozen == MONDAY - 1_000
