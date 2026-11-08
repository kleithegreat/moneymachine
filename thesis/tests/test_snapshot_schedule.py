"""The proposed dated schedule separates the information cutoff, acquisition and session admission."""

import json

import httpx

from thesis import market, runner
from thesis.tests.test_market import fake_clock
from thesis.tests.test_runner import MONDAY, track


def test_snapshot_acquisition_precedes_the_session_and_uses_one_fixed_cutoff(track, monkeypatch):
    clock, events = [MONDAY + 5 * 60_000], []
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    snapshot = track.snapshot
    monkeypatch.setattr(track, "snapshot", lambda cutoff: events.append(("snapshot", cutoff)) or snapshot(cutoff))
    monkeypatch.setattr(track, "ready", lambda date: events.append(("ready", clock[0])) or True)
    monkeypatch.setattr(track, "session", lambda kind, date, snap, *a, **kw: events.append((kind, snap["taken"])))
    track.schedule(clock[0], MONDAY)
    assert events == [("snapshot", MONDAY + runner.SNAPSHOT_OFFSET)]
    clock[0] = MONDAY + runner.SESSION_OFFSET
    track.schedule(clock[0], MONDAY)
    assert ("main", MONDAY + runner.SNAPSHOT_OFFSET) in events
    assert events.index(("ready", clock[0])) > 0


def test_acquisition_that_misses_its_completion_deadline_cannot_start_a_session(track, monkeypatch):
    clock = [MONDAY + 5 * 60_000]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    snapshot = track.snapshot

    def slow(cutoff):
        clock[0] = MONDAY + runner.SESSION_OFFSET + 1
        return snapshot(cutoff)

    monkeypatch.setattr(track, "snapshot", slow)
    monkeypatch.setattr(track, "session", lambda *a, **kw: (_ for _ in ()).throw(AssertionError("late session")))
    track.schedule(clock[0], MONDAY)
    assert {c["session"] for _, _, c in track.ledger.records("session_missed")} == {f"main-{MONDAY}", f"noread-{MONDAY}"}


def test_an_outage_past_acquisition_does_not_create_a_late_snapshot(track, monkeypatch):
    now = MONDAY + 20 * runner.HOUR
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "snapshot", lambda *a: (_ for _ in ()).throw(AssertionError("late fetch")))
    track.schedule(now, MONDAY)
    assert len(track.ledger.records("session_missed")) == 2


def test_snapshot_publication_must_finish_before_the_deadline(track, monkeypatch):
    clock = [MONDAY + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    monkeypatch.setattr(track, "ready", lambda date: True)
    snapshot = track.snapshot

    def delayed_publication(cutoff):
        snap = snapshot(cutoff)
        clock[0] = MONDAY + runner.SESSION_OFFSET + 1
        return snap

    monkeypatch.setattr(track, "snapshot", delayed_publication)
    monkeypatch.setattr(track, "session", lambda *a, **kw: (_ for _ in ()).throw(AssertionError("late publication")))
    track.schedule(clock[0], MONDAY)
    assert len(track.ledger.records("session_missed")) == 2


def test_recovery_uses_only_the_timely_published_snapshot_bytes(track, monkeypatch):
    clock = [MONDAY + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.schedule(clock[0], MONDAY)
    [(_, _, ready)] = track.ledger.records("snapshot_ready", "main")
    assert ready["taken"] == MONDAY + runner.SNAPSHOT_OFFSET and ready["acquired"] == clock[0]
    path = track.root / "snapshots" / f"{ready['taken']}.json"
    path.write_text(path.read_text() + " ")
    clock[0] = MONDAY + runner.SESSION_OFFSET
    monkeypatch.setattr(track, "session", lambda *a, **kw: (_ for _ in ()).throw(AssertionError("changed snapshot")))
    track.schedule(clock[0], MONDAY)
    assert len(track.ledger.records("session_missed")) == 2


def test_the_paper_snapshot_envelope_includes_real_prefix_tail_and_empty_requests(tmp_path, monkeypatch):
    cutoff = MONDAY + 5 * 60_000
    fake_clock(monkeypatch, [cutoff])
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    charges = []
    charge = x._charge
    monkeypatch.setattr(x, "_charge", lambda w, background=False: (charges.append(w), charge(w, background))[1])

    def post(url, json):
        req = json["req"]
        step = market.STEP[req["interval"]]
        t = MONDAY - step
        payload = [{"t": t, "o": "100", "c": "100"}] if req["startTime"] <= t <= req["endTime"] else []
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    for kind, expected in [("1d", [31, 21, 21]), ("1h", [92, 21, 21])]:
        path = m.root / "X" / f"{kind}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        step = market.STEP[kind]
        path.write_text(json.dumps([[MONDAY - i * step, 100., 100.] for i in range(502, 1, -1)]))
        charges.clear()
        m.bars("X", kind, cutoff)
        assert charges == expected
    weights = [20] * 7
    for i in range(348):
        weights += ([39] if i < 278 else []) + [21, 21]
        if i < 176:
            weights += [100, 21, 21]
    assert len(weights) == 1509 and sum(weights) == 50590
    limiter = market.Exchange(tmp_path / "bound", limiter=market.WeightLimit(120))
    clock = [cutoff]
    fake_clock(monkeypatch, clock)
    for w in weights:
        limiter._charge(w)
    assert clock[0] - cutoff == 632 * 60_000
    bound = (348 + 2 * 176 + 1 + 5) * 60_000 + 1514 * 10_000 + 31_000 + 19 * 7 * 60_000 + 2 * 60_000
    assert bound == 65_631_000
    assert runner.SESSION_OFFSET == 19 * runner.HOUR
    assert runner.SNAPSHOT_OFFSET + bound < runner.SESSION_OFFSET


def test_snapshot_discovery_costs_one_core_one_inventory_and_each_dex(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [MONDAY + runner.SNAPSHOT_OFFSET])
    x = market.Exchange(tmp_path / "x")
    sent, weights = [], []
    charge = x._charge
    monkeypatch.setattr(x, "_charge", lambda w, background=False: (weights.append(w), charge(w, background))[1])

    def post(url, json):
        sent.append(json)
        payload = [None, *({"name": str(i)} for i in range(5))] if json["type"] == "perpDexs" else {"universe": []}
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    market.Market(tmp_path / "m", x).listings()
    assert len(sent) == 7 and [p["type"] for p in sent].count("meta") == 6
    assert weights == [20] * 7
    archive = [json.loads(line) for p in (tmp_path / "x").glob("info-*.jsonl") for line in p.read_text().splitlines()]
    assert len(archive) == 7
