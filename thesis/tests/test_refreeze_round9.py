"""Round nine: F1-F4 and the lower notes of the Opus hunt (audit/reviews/2026-11-09-opus-hunt-thesis.md)."""
import json
import multiprocessing as mp
import os

import httpx
import pytest

from ingest.policy import DAY, HOUR
from thesis import daemon as thesis_daemon
from thesis import harness, registry, runner, scoring
from thesis.market import Market
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401


def refuse(market_name, interval=None):
    def bars(self, market, i, now=None):
        if market == market_name and interval in (None, i):
            raise httpx.HTTPStatusError("500 from candleSnapshot", request=httpx.Request("POST", "https://x"),
                                        response=httpx.Response(500))
        return FakeMarket.bars(self, market, i, now)

    return type("Refusing", (FakeMarket,), {"bars": bars})


def skips(track):
    return {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}


def test_f1_a_failing_listed_market_does_not_cost_the_snapshot(track, monkeypatch):
    class Listed(refuse("NEW")):
        def universe(self, dex=None, *, background=False):
            return {**super().universe(dex, background=background), "NEW": False}

    track.market = Listed(MONDAY + 40 * DAY)
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    attested = track.attested(MONDAY, MONDAY + DAY)
    assert attested is not None and "500" in attested["failed"]["NEW"] and attested["ready"]["NEW"] is False
    assert "NEW" not in attested["markets"] and "BTC" in attested["markets"]


def test_f1_a_market_that_failed_at_the_snapshot_is_skipped_with_that_reason_and_the_others_register(track, monkeypatch):
    track.market = refuse("BTC", "1h")(MONDAY + 40 * DAY)
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    track.benchmark(MONDAY)
    assert skips(track)["BTC"].startswith("market read failed at the snapshot: ") and "500" in skips(track)["BTC"]
    assert {th["legs"][0][0] for th in track.ledger.theses("benchmark")} == {"ETH", "xyz:XYZ100", "xyz:GOLD"}


def test_f1_a_failing_input_read_does_not_stop_the_markets_after_it(track, monkeypatch):
    funding = track.market.funding

    def wrapped(market, now=None, start=None):
        if market == "BTC":
            raise httpx.ReadTimeout("BTC's funding tail keeps timing out")
        return funding(market, now, start)

    track.market.funding = wrapped
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.SNAPSHOT_OFFSET)
    track.acquire(MONDAY)
    track.benchmarks(runner.now_ms(), MONDAY - DAY)
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + runner.BENCHMARK_GIVE_UP)
    track.benchmarks(runner.now_ms(), MONDAY - DAY)
    assert {th["legs"][0][0] for th in track.ledger.theses("benchmark")} == {"ETH", "xyz:XYZ100", "xyz:GOLD"}
    assert skips(track)["BTC"] == "run missed"


SNAPSHOT = {"taken": 1, "listings": {"X": False}, "markets": {f"M{i}": {"last_close": 100.0 + i, "t": 1} for i in range(4000)},
            "daily": {}}


def a_daemon(root, session, account):
    ledger = registry.Ledger(root / "l.sqlite", "thesis-test")
    return thesis_daemon.Daemon(root / "s.sock", session, account, ledger, SNAPSHOT, None, root / "responses",
                                lambda a, n: {}, lambda a, m, n: ({}, {}), ("markets",), clock=lambda: 5), ledger


def test_f2_an_identical_response_does_not_rewrite_the_bytes_a_record_cites(tmp_path, monkeypatch):
    main, ledger = a_daemon(tmp_path, "main-0", "main")
    main.handle({"cmd": "markets", "args": []})
    cited = ledger.calls("main")[0]["response_sha256"]
    path = tmp_path / "responses" / f"{cited}.json"

    def killed_midway(self, data):
        with open(self, "wb") as f:
            f.write(data[: len(data) // 3])
        raise OSError("killed midway")

    monkeypatch.setattr(type(path), "write_bytes", killed_midway)
    noread, _ = a_daemon(tmp_path, "noread-0", "noread")
    try:
        noread.handle({"cmd": "markets", "args": []})
    except OSError:
        pass
    assert registry.sha256(path.read_bytes()) == cited


def test_f2_a_response_never_appears_partly_written(tmp_path, monkeypatch):
    daemon, ledger = a_daemon(tmp_path, "main-0", "main")
    monkeypatch.setattr(os, "replace", lambda *a: (_ for _ in ()).throw(OSError("killed before the rename")))
    with pytest.raises(OSError):
        daemon.handle({"cmd": "markets", "args": []})
    assert list((tmp_path / "responses").glob("*.json")) == [] and not ledger.calls("main")


COMMITS = 150


def commit_funding(root, seed):
    market = Market(root, exchange=None)
    path = market._funding_path("BTC")
    for k in range(COMMITS):
        a = (seed * 1_000_000 + k * 2) * HOUR
        market._funding_commit(path, [[h * HOUR, 1e-05] for h in range(3000)], a, a + HOUR)


def test_f3_two_processes_commit_one_cache_without_losing_ranges(tmp_path):
    procs = [mp.get_context("fork").Process(target=commit_funding, args=(tmp_path, s)) for s in (1, 2)]
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    assert [p.exitcode for p in procs] == [0, 0]
    saved = json.loads(Market(tmp_path, exchange=None)._funding_path("BTC").read_text())
    assert len(saved["fetched"]) == 2 * COMMITS
    assert not [p for p in tmp_path.rglob("*") if p.suffix == ".tmp"]


def test_f3_two_processes_extend_one_bar_cache_without_losing_rows(tmp_path):
    def rows(a, b):
        return [[t, 1.0, 1.0] for t in range(a // HOUR * HOUR, b, HOUR)]

    def extend(seed):
        market = Market(tmp_path, exchange=None)
        for k in range(60):
            now = (1000 + seed * 100_000 + k) * HOUR
            market._cached("BTC", "1h", rows, now)

    procs = [mp.get_context("fork").Process(target=extend, args=(s,)) for s in (1, 2)]
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    assert [p.exitcode for p in procs] == [0, 0]
    json.loads((tmp_path / "BTC" / "1h.json").read_text())
    assert not [p for p in tmp_path.rglob("*") if p.suffix == ".tmp"]


def test_lower_a_session_that_raises_closes_its_daemon(tmp_path, monkeypatch):
    closed = []

    class D:
        def close(self):
            closed.append(1)

    monkeypatch.setattr(harness, "workspace", lambda *a: None)
    monkeypatch.setattr(harness.session, "socket_path", lambda w, c: "s")
    monkeypatch.setattr(harness.session, "run", lambda *a: (_ for _ in ()).throw(RuntimeError("boom")))
    with pytest.raises(RuntimeError):
        harness.run_session(tmp_path, "main", lambda sock: D())
    assert closed == [1]


def test_lower_the_undefined_skill_count_is_per_comparison():
    test = {"theses": [{"id": f"t{i}", "p": 0.6, "p_ablation": None} for i in range(4)]}
    result = {"theses": {f"t{i}": {"outcome": {"o": i % 2}, "p_ref": 0.5} for i in range(4)},
              "clusters": [{"name": f"t{i}", "members": [f"t{i}"], "resolved": True} for i in range(4)]}
    assert scoring.bootstrap(test, result)["replicates_with_undefined_skill"] == {"base_rate": 0, "ablation": scoring.REPLICATES}
