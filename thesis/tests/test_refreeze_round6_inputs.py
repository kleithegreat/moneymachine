"""Round-six input contracts, source-blind against baseline 2229563.

Monday is the benchmark's information/forecast time, not its commit time.
Daily readiness is shared; the discretionary arms' runtime prices are not.
"""

import json

import httpx
import pytest

from ingest.policy import DAY, DELTA, HOUR
from thesis import market, runner
from thesis.tests.test_market import Venue, fake_clock
from thesis.tests.test_runner import MONDAY, ZERO, FakeMarket, Trending, track  # noqa: F401

MIN = 60_000
REGISTRATIONS = (5 * HOUR, 14 * HOUR, 23 * HOUR + 30 * MIN)


@pytest.fixture(autouse=True)
def offline(monkeypatch):
    def forbidden(*args, **kwargs):
        pytest.fail("round-six tests must not use the network")

    monkeypatch.setattr(httpx.Client, "send", forbidden)


def synthetic_market(track, tmp_path, monkeypatch, *, history=True):
    """Real metadata/archive adapter; all prices and HTTP replies are synthetic."""
    clock = [MONDAY - HOUR]
    fake_clock(monkeypatch, clock)
    monkeypatch.setattr(runner, "now_ms", lambda: int(clock[0]))
    live = {name: False for name in (*runner.BENCHMARK, "X")}
    exchange = market.Exchange(tmp_path / "exchange", limiter=market.WeightLimit(market.BUDGET_PER_MIN))

    def post(url, json):
        if json["type"] == "perpDexs":
            payload = [None, *({"name": dex} for dex in sorted({m.split(":")[0] for m in live if ":" in m}))]
        else:
            assert json["type"] == "meta"
            payload = {"universe": [{"name": name, "isDelisted": dead} for name, dead in live.items()
                                    if (name.split(":")[0] if ":" in name else None) == json.get("dex")]}
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(exchange.http, "post", post)
    adapter = market.Market(tmp_path / "market", exchange)
    prices = FakeMarket(MONDAY + 40 * DAY)
    for name in ("bars", "funding", "ready", "lag"):
        monkeypatch.setattr(adapter, name, getattr(prices, name))
    track.market = adapter
    if history:
        adapter.listings()
    return clock, live, exchange, prices


def acquire(track, clock, at=None):
    clock[0] = MONDAY + runner.SNAPSHOT_OFFSET if at is None else at
    track.acquire(MONDAY)
    return json.loads((track.root / "snapshots" / f"{MONDAY + runner.SNAPSHOT_OFFSET}.json").read_text())


@pytest.mark.parametrize("delay", REGISTRATIONS)
def test_benchmark_holding_window_is_monday_not_registration(track, tmp_path, monkeypatch, delay):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock)
    clock[0] = MONDAY + delay
    track.benchmark(MONDAY)
    theses = track.ledger.theses("benchmark")
    assert len(theses) == 4
    assert {(th["t_r"], th["T"], th["cutoff"]) for th in theses} == {(MONDAY, MONDAY + 21 * DAY, MONDAY)}


@pytest.mark.parametrize("delay", REGISTRATIONS)
def test_benchmark_records_actual_commit_separately(track, tmp_path, monkeypatch, delay):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock)
    clock[0] = MONDAY + delay
    track.benchmark(MONDAY)
    theses = track.ledger.theses("benchmark")
    assert len(theses) == 4
    assert {th["registered_at"] for th in theses} == {MONDAY + delay}


@pytest.mark.parametrize("delay", REGISTRATIONS)
def test_every_benchmark_base_rate_is_a_twenty_one_day_forecast(track, tmp_path, monkeypatch, delay):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock)
    seen, base_rate = [], runner.scoring.base_rate

    def measured(thesis, daily, funding):
        seen.append((thesis["t_r"], thesis["T"]))
        return base_rate(thesis, daily, funding)

    monkeypatch.setattr(runner.scoring, "base_rate", measured)
    clock[0] = MONDAY + delay
    track.benchmark(MONDAY)
    assert len(track.ledger.theses("benchmark")) == 4
    assert seen and set(seen) == {(MONDAY, MONDAY + 21 * DAY)}


@pytest.mark.parametrize("delay", REGISTRATIONS)
def test_benchmark_runtime_bars_and_funding_never_advance_past_monday(track, tmp_path, monkeypatch, delay):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock)
    seen, reads, inputs, bars = [], [], track.inputs, track.market.bars

    def measured_bars(name, interval, now=None):
        reads.append(now)
        return bars(name, interval, now)

    def measured(account, markets, now, snap):
        config, data = inputs(account, markets, now, snap)
        seen.append((now, data["cutoff"], max(t for rows in data["funding"].values() for t in rows)))
        return config, data

    monkeypatch.setattr(track, "inputs", measured)
    monkeypatch.setattr(track.market, "bars", measured_bars)
    clock[0] = MONDAY + delay
    track.benchmark(MONDAY)
    assert len(track.ledger.theses("benchmark")) == 4
    assert seen and all(now == cutoff == MONDAY and funding <= MONDAY for now, cutoff, funding in seen)
    assert reads and all(now is not None and now <= MONDAY for now in reads)


def test_late_monday_attestation_registers_at_2330_without_waiting_for_tuesday(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquire(track, clock, MONDAY + REGISTRATIONS[-1])
    track.benchmarks(clock[0], MONDAY)
    assert len(track.ledger.theses("benchmark")) == 4
    assert not track.unbenchmarked(MONDAY)


@pytest.mark.parametrize("name", ["BTC", "xyz:GOLD"])
@pytest.mark.parametrize("historical,current", [(False, True), (True, False), (None, False)])
def test_benchmark_listing_eligibility_uses_midnight_not_live_metadata(
        track, tmp_path, monkeypatch, name, historical, current):
    clock, live, _, _ = synthetic_market(track, tmp_path, monkeypatch, history=False)
    if historical is None:
        live.pop(name)
    else:
        live[name] = historical
    track.market.listings()
    clock[0] = MONDAY + MIN
    live[name] = current
    track.market.listings()
    snap = acquire(track, clock)
    clock[0] = MONDAY + 14 * HOUR
    track.benchmark(MONDAY)
    registered = {th["legs"][0][0] for th in track.ledger.theses("benchmark")}
    assert (name in registered) == (historical is False)
    expected = {} if historical is None else {name: historical}
    assert {m: dead for m, dead in snap["benchmark_listings"].items() if m == name} == expected


def test_benchmark_missing_pre_monday_metadata_fails_closed(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch, history=False)
    snap = acquire(track, clock)
    clock[0] = MONDAY + 5 * HOUR
    track.benchmark(MONDAY)
    assert track.ledger.theses("benchmark") == []
    assert {row["market"] for _, _, row in track.ledger.records("skip", "benchmark")} == set(runner.BENCHMARK)
    assert snap["benchmark_listings"] == {}


def test_metadata_sent_before_midnight_but_received_after_it_is_not_known(track, tmp_path, monkeypatch):
    clock, live, exchange, _ = synthetic_market(track, tmp_path, monkeypatch)
    live["BTC"] = True
    post = exchange.http.post

    def delayed(url, json):
        reply = post(url, json)
        clock[0] = MONDAY + 1
        return reply

    clock[0] = MONDAY - 1
    monkeypatch.setattr(exchange.http, "post", delayed)
    track.market.listings()
    monkeypatch.setattr(exchange.http, "post", post)
    snap = acquire(track, clock)
    assert snap["benchmark_listings"]["BTC"] is False


@pytest.mark.parametrize("received", [MONDAY - 1, MONDAY])
def test_latest_metadata_received_by_monday_is_used_after_restart(track, tmp_path, monkeypatch, received):
    clock, live, exchange, prices = synthetic_market(track, tmp_path, monkeypatch)
    live["BTC"] = True
    clock[0] = received
    track.market.listings()
    live["BTC"] = False
    recovered = market.Market(tmp_path / "market", exchange)
    for name in ("bars", "funding", "ready", "lag"):
        monkeypatch.setattr(recovered, name, getattr(prices, name))
    track.market = recovered
    snap = acquire(track, clock)
    assert snap["benchmark_listings"]["BTC"] is True


def test_listing_observations_are_completed_metadata_only_and_prospective(track, tmp_path, monkeypatch):
    clock, live, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    old = dict(live)
    clock[0] = MONDAY + MIN
    live["BTC"] = True
    track.market.listings()
    acquire(track, clock)
    clock[0] = MONDAY + 5 * HOUR
    track.benchmark(MONDAY)
    assert "BTC" in {th["legs"][0][0] for th in track.ledger.theses("benchmark")}
    assert track.market.listings_at(MONDAY)[1] == old
    assert track.market.listings_at(MONDAY - HOUR - 1) == (None, {})
    observations = [json.loads(line) for path in (tmp_path / "market").glob("listings-*.jsonl")
                    for line in path.read_text().splitlines()]
    assert observations and all(set(row) == {"at", "listings"} for row in observations)
    assert {row["at"] for row in observations} >= {MONDAY - HOUR, MONDAY + MIN}
    assert not [row for row in observations if MONDAY - HOUR < row["at"] <= MONDAY]


def test_incomplete_discovery_cannot_publish_a_partial_listing_observation(track, tmp_path, monkeypatch):
    clock, live, exchange, _ = synthetic_market(track, tmp_path, monkeypatch)
    old = dict(live)
    live["BTC"] = True
    post = exchange.post

    def incomplete(body, *args, **kwargs):
        if body.get("dex") == "xyz":
            raise httpx.TransportError("discovery interrupted")
        return post(body, *args, **kwargs)

    clock[0] = MONDAY - MIN
    monkeypatch.setattr(exchange, "post", incomplete)
    with pytest.raises(httpx.TransportError, match="discovery interrupted"):
        track.market.listings()
    monkeypatch.setattr(exchange, "post", post)
    live["BTC"] = False
    snap = acquire(track, clock)
    clock[0] = MONDAY + 5 * HOUR
    track.benchmark(MONDAY)
    assert "BTC" in {th["legs"][0][0] for th in track.ledger.theses("benchmark")}
    assert snap["benchmark_listings"] == old
    assert track.market.listings_at(MONDAY)[1] == old


def test_snapshot_fixes_readiness_at_the_first_pass_start(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    bars, reads = track.market.bars, []
    end = MONDAY + 3 * HOUR
    start = MONDAY + runner.SNAPSHOT_OFFSET

    def slow(name, interval, now=None):
        clock[0] = end
        return bars(name, interval, now)

    monkeypatch.setattr(track.market, "bars", slow)
    monkeypatch.setattr(track.market, "ready", lambda name, now: reads.append((name, now)) or name != "X")
    snap = acquire(track, clock)
    assert snap["readiness_at"] == start
    assert snap["ready"]["X"] is False and snap["ready"]["BTC"] is True
    assert set(snap["ready"]) >= set(snap["markets"])
    assert reads and {now for _, now in reads} == {start}


def test_shared_ready_true_survives_the_500_hour_freshness_boundary(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    acquired = MONDAY - 495 * HOUR
    rows = [(h, 0.0) for h in range(acquired - market.HISTORY["funding"] - DAY, MONDAY + DAY, HOUR)]
    coverage = market.Market(tmp_path / "coverage", Venue(rows))
    clock[0] = acquired
    coverage.funding("X", acquired, background=True)
    monkeypatch.setattr(track.market, "ready", coverage.ready)
    snap = acquire(track, clock)
    snap["ready"] = {"X": True}
    for account, hours in (("main", 4), ("noread", 6)):
        clock[0] = MONDAY + hours * HOUR
        assert coverage.ready("X", clock[0]) == (account == "main")
        _, data = track.inputs(account, ["X"], clock[0], snap)
        assert data["cutoff"] == clock[0]


@pytest.mark.parametrize("improvement", ["prior_read", "prewarm"])
def test_frozen_unready_cannot_be_promoted_by_prior_reads_or_prewarm(track, tmp_path, monkeypatch, improvement):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    warm = [False]
    monkeypatch.setattr(track.market, "ready", lambda name, now: warm[0])
    snap = acquire(track, clock)
    snap["ready"] = {"X": False}
    clock[0] = MONDAY + 5 * HOUR
    with pytest.raises(httpx.TransportError, match="not ready"):
        track.inputs("main", ["X"], clock[0], snap)
    if improvement == "prior_read":
        track.market.funding("X", clock[0])
    else:
        monkeypatch.setattr(track.market, "prewarm", lambda *args: warm.__setitem__(0, True))
        track.market.prewarm("X", clock[0], track.stop)
    warm[0] = True
    clock[0] += HOUR
    with pytest.raises(httpx.TransportError, match="not ready"):
        track.inputs("noread", ["X"], clock[0], snap)
    assert snap["ready"] == {"X": False}


def test_discretionary_arms_keep_registration_time_inputs_and_one_daily_snapshot(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    snap = acquire(track, clock)
    snap["ready"] = {"X": True}
    before = json.dumps(snap, sort_keys=True)
    seen, bars = [], track.market.bars

    def measured(name, interval, now=None):
        seen.append((name, interval, now))
        return bars(name, interval, now)

    monkeypatch.setattr(track.market, "bars", measured)
    outputs = []
    for account, hours in (("main", 5), ("noread", 14)):
        clock[0] = MONDAY + hours * HOUR
        _, data = track.inputs(account, ["X"], clock[0], snap)
        assert data["cutoff"] == clock[0]
        assert data["daily"]["X"] == runner.scoring.bars(snap["daily"]["X"])
        outputs.append(max(data["funding"]["X"]))
    assert outputs == [MONDAY + 5 * HOUR, MONDAY + 14 * HOUR]
    assert {now for name, interval, now in seen if name == "X" and interval == "1h"} == set(outputs)
    assert json.dumps(snap, sort_keys=True) == before
    assert max(row[0] for row in snap["daily"]["X"]) + DAY + DELTA <= snap["taken"]


def test_discretionary_sizing_can_differ_despite_the_shared_daily_snapshot(track, tmp_path, monkeypatch):
    clock, _, _, _ = synthetic_market(track, tmp_path, monkeypatch)
    prices = Trending(MONDAY + 40 * DAY, MONDAY + 10 * HOUR)
    monkeypatch.setattr(track.market, "bars", prices.bars)
    snap = acquire(track, clock)
    snap["ready"] = {"BTC": True, "X": True}
    before = json.dumps(snap, sort_keys=True)
    registered, commits = [], []
    for account, hours in (("main", 5), ("noread", 14)):
        track.ledger.disclose("thesis", account, {
            "id": f"{account}-1", "request_id": "prior", "account": account, "session": "prior",
            "t_r": MONDAY + HOUR, "T": MONDAY + 21 * DAY, "legs": [["BTC", 1]], "L": 0.5,
            "N": "1000", "size": "1000", "b": "100", "fee": 0.0, "costs": {"BTC": ZERO},
        })
        clock[0] = MONDAY + hours * HOUR
        daemon = runner.Daemon(
            track.root / f"{account}.sock", f"{account}-{MONDAY}", account, track.ledger, snap,
            None, track.root / "responses", None,
            lambda account, markets, now: track.inputs(account, markets, now, snap),
            runner.MAIN_COMMANDS, clock=lambda: clock[0],
        )
        out = daemon.register([json.dumps({
            "request_id": "new", "legs": [["X", 1]], "T": MONDAY + 10 * DAY, "p": 0.5, "L": 0.1,
            "catalyst": "synthetic", "catalyst_id": "synthetic", "sources": [], "outcome_market": None,
        })])
        assert out["ok"], out
        registered.append(out["thesis"])
        commits.append(clock[0])
    assert [th["t_r"] for th in registered] == commits
    assert MONDAY + 5 * HOUR <= commits[0] < MONDAY + 6 * HOUR
    assert MONDAY + 14 * HOUR <= commits[1] < MONDAY + 15 * HOUR
    assert [runner.positions.exact(th["E_r"]) for th in registered] == [10_000, 11_000]
    assert [runner.positions.exact(th["N"]) for th in registered] == [1000, 1100]
    assert json.dumps(snap, sort_keys=True) == before
