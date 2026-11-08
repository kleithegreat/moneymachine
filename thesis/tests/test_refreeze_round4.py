"""Offline regressions for the seven findings in GPT's 2026-11-08 prewarm review."""

import json
import threading

import httpx
import pytest

from ingest import hl
from thesis import market, runner
from thesis.tests.test_market import Venue, fake_clock
from thesis.tests.test_runner import track
from thesis.tests.test_runner import MONDAY, benchmark, registration

H, D = market.HOUR, market.DAY
NOW = 2000 * D + 600_000


def test_registration_refuses_unacquired_comparator_history(track):
    track.market.ready = lambda m, now: False
    with pytest.raises(httpx.TransportError, match="funding history is not ready"):
        track.inputs("main", ["BTC"], NOW, {"daily": {}})
    assert track.ledger.theses("main") == []


def test_cold_market_stays_eligible_but_unavailable_until_acquired(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    snapshot = track.snapshot(MONDAY)
    track.market.ready = lambda m, now: False
    assert "BTC" in snapshot["markets"]
    with pytest.raises(httpx.TransportError):
        registration(track, snapshot)
    assert not track.ledger.theses("main")
    track.market.ready = lambda m, now: True
    assert registration(track, snapshot)["ok"]


def test_benchmark_retries_unacquired_inputs_like_other_availability_failures(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.market.ready = lambda m, now: False
    with pytest.raises(httpx.TransportError):
        benchmark(track)
    assert not track.ledger.theses("benchmark")
    assert not track.ledger.records("skip", "benchmark")
    track.market.ready = lambda m, now: True
    benchmark(track)
    assert len(track.ledger.theses("benchmark")) == 4


def test_widened_covered_holes_are_not_starved_by_hourly_narrow_reads(tmp_path, monkeypatch):
    clock = [NOW]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    hole = NOW // H * H - 100 * H
    x = Venue([(h, .001) for h in range(hole - 2 * H, NOW // H * H + H, H) if h != hole])
    m = market.Market(tmp_path, x)
    m.funding("X", NOW, start=hole - 2 * H)
    x.rows.append((hole, .5))
    for k in range(1, 4):
        clock[0] = NOW + k * H
        m.funding("X", clock[0], start=clock[0] - 2 * H)
        got = m.funding("X", clock[0], start=hole - 2 * H)
    assert [hole, .5] in got


def test_frequent_reads_do_not_renew_repairs_they_did_not_perform(tmp_path, monkeypatch):
    clock = [NOW]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    hole = NOW // H * H - 100 * H
    lo = hole - 2 * H
    x = Venue([(h, .001) for h in range(lo, NOW // H * H + H, H) if h != hole])
    m = market.Market(tmp_path, x)
    m.funding("X", NOW, start=lo)
    x.rows.append((hole, .5))
    for k in range(1, 13):
        clock[0] = NOW + k * 5 * 60_000
        got = m.funding("X", clock[0], start=lo)
    assert [hole, .5] in got


def test_cold_fill_does_not_reprobe_the_ranges_it_just_acquired(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [NOW])
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    birth = NOW // H * H - 40 * D
    rows = [(h, 0.) for h in range(birth, NOW // H * H + H, H)]
    charges = []
    charge = x._charge
    monkeypatch.setattr(x, "_charge", lambda w, background=False: (charges.append(w), charge(w, background))[1])

    def post(url, json):
        payload = [{"time": h, "fundingRate": str(r)} for h, r in rows
                   if json["startTime"] <= h <= json["endTime"]][:500]
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    m.prewarm("X", NOW, threading.Event())
    assert sum(charges) <= (len(rows) // 500 + 1) * 45
    assert charges == [45, 44]


def test_session_hold_covers_background_inventory(tmp_path, monkeypatch):
    x = market.Exchange(tmp_path / "x", limiter=hl.WeightLimit(600))
    m = market.Market(tmp_path / "m", x)
    entered, sent = threading.Event(), []

    def post(url, json):
        sent.append(json)
        payload = [None, {"name": "xyz"}] if json["type"] == "perpDexs" else {"universe": []}
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    t = runner.Track.__new__(runner.Track)
    t.market = m
    t.markets_of = lambda account: []
    thread = threading.Thread(target=lambda: (entered.set(), t.warm_order()))
    with m.hold():
        thread.start()
        assert entered.wait(2)
        thread.join(.5)
        blocked = thread.is_alive() and not sent
    thread.join(5)
    assert blocked and not thread.is_alive() and len(sent) == 3


def test_bootstrap_is_available_without_a_frozen_track(tmp_path, monkeypatch):
    import cli

    calls = []
    m = market.Market(tmp_path / "m", Venue([]))
    m.listings = lambda **kw: {"X": False, "OLD": True}
    m.prewarm = lambda name, now, stop: calls.append(name)
    monkeypatch.setattr(runner, "Market", lambda *a: m)
    monkeypatch.setattr(runner, "Exchange", lambda *a: None)
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(runner, "FROZEN", tmp_path / "absent.json")
    cli.main(["thesis-prewarm"])
    assert calls == ["X"] and not runner.FROZEN.exists()


def test_legacy_rows_survive_refill_without_claiming_range_coverage(tmp_path):
    p = tmp_path / "X"
    p.mkdir()
    (p / "funding.json").write_text(json.dumps([[H, .1]]))
    m = market.Market(tmp_path, Venue([(H, .9)]))
    assert not m.ready("X", 2 * H)
    assert m.funding("X", 2 * H, start=0) == [[H, .1]]
    assert not m.ready("X", 2 * H)


def test_excess_response_charges_difference_of_total_surcharges(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [NOW])
    x = market.Exchange(tmp_path)
    monkeypatch.setattr(x.http, "post", lambda url, json: httpx.Response(
        200, json=[{"time": i, "fundingRate": "0"} for i in range(21)], request=httpx.Request("POST", url)))
    x.funding_page("X", 0, 19 * H)
    assert sum(w for _, w in x.limiter.spent) == 22


def test_full_scope_cold_fill_and_every_retry_reserve_the_paper_weights(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [NOW])
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    charges, attempts = [], []
    charge = x._charge
    monkeypatch.setattr(x, "_charge", lambda w, background=False: (charges.append(w), charge(w, background))[1])
    lo = (NOW - market.HISTORY["funding"]) // H * H

    def post(url, json):
        attempts.append(json)
        payload = [{"time": t, "fundingRate": "0"} for t in range(lo, NOW + 1, H)
                   if json["startTime"] <= t <= json["endTime"]][:500]
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    m.prewarm("X", NOW, threading.Event())
    assert len(attempts) == 55 and charges == [45] * 54 + [21]
    assert sum(charges) == 2451 <= 55 * 45
    charges.clear()
    monkeypatch.setattr(x.http, "post", lambda url, json: httpx.Response(429, request=httpx.Request("POST", url)))
    with pytest.raises(httpx.HTTPStatusError):
        x.funding_page("X", lo, NOW)
    assert charges == [45] * 6


def test_daily_funding_tail_and_discovery_costs_use_ceiling(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [NOW])
    x = market.Exchange(tmp_path)
    monkeypatch.setattr(x.http, "post", lambda url, json: httpx.Response(200, json=[], request=httpx.Request("POST", url)))
    x.funding_page("X", 0, D + H)
    assert sum(w for _, w in x.limiter.spent) == 22
    assert (348 * 22 + 278 * 45) == 20166
    assert (D // runner.PREWARM_EVERY) * 20 * (5 + 2) == 13440


def test_hole_plans_never_repair_outside_the_requested_scope():
    rows = [[t, 1.] for t in (0, 2 * H, 4 * H, 6 * H, 8 * H)]
    spans = market.holes(rows, H, 3 * H, 5 * H)
    assert spans and all(3 * H <= a < b <= 5 * H for a, b in spans)
