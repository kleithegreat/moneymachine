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
    track.acquisitions(clock[0], MONDAY)
    track.schedule(clock[0], MONDAY)
    assert events == [("snapshot", MONDAY + runner.SNAPSHOT_OFFSET)]
    clock[0] = MONDAY + runner.SESSION_OFFSET
    track.schedule(clock[0], MONDAY)
    assert ("main", MONDAY + runner.SNAPSHOT_OFFSET) in events
    assert events.index(("ready", clock[0])) > 0


def test_an_outage_past_acquisition_does_not_create_a_late_snapshot(track, monkeypatch):
    now = MONDAY + runner.DAY + 20 * runner.HOUR
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "snapshot", lambda *a: (_ for _ in ()).throw(AssertionError("late fetch")))
    track.acquisitions(now, MONDAY + runner.DAY)
    track.schedule(now, MONDAY + runner.DAY)
    assert len(track.ledger.records("session_missed")) == 2


def test_recovery_uses_only_the_timely_published_snapshot_bytes(track, monkeypatch):
    clock = [MONDAY + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.acquisitions(clock[0], MONDAY)
    [(_, _, ready)] = track.ledger.records("snapshot_ready", "main")
    assert ready["taken"] == MONDAY + runner.SNAPSHOT_OFFSET and ready["acquired"] == clock[0]
    path = track.root / "snapshots" / f"{ready['taken']}.json"
    path.write_text(path.read_text() + " ")
    clock[0] = MONDAY + runner.SESSION_OFFSET
    monkeypatch.setattr(track, "session", lambda *a, **kw: (_ for _ in ()).throw(AssertionError("changed snapshot")))
    track.schedule(clock[0], MONDAY)
    assert len(track.ledger.records("session_missed")) == 2


def test_recovery_after_main_never_reconstructs_its_lost_snapshot(track, monkeypatch):
    clock = [MONDAY + runner.SNAPSHOT_OFFSET]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.acquisitions(clock[0], MONDAY)
    track.ledger.disclose("session", "main", {"session": f"main-{MONDAY}", "kind": "main",
                                              "taken": clock[0], "started": MONDAY + runner.SESSION_OFFSET})
    (track.root / "snapshots" / f"{clock[0]}.json").unlink()
    clock[0] = MONDAY + runner.SESSION_OFFSET + runner.HOUR
    monkeypatch.setattr(track, "snapshot", lambda *a: (_ for _ in ()).throw(AssertionError("reconstructed snapshot")))
    monkeypatch.setattr(track, "ready", lambda date: True)
    track.schedule(clock[0], MONDAY)
    assert [c["session"] for _, _, c in track.ledger.records("session_missed")] == [f"noread-{MONDAY}"]


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


def inventory(tails):
    """The weights of one snapshot of the 2026-10-28 inventory (counts only: ages, no prices): 348 live listings, ten dexes.
    `tails` is the number of 21-weight requests: 349 when the venue returns the unclosed candle (the 10 daily scopes with no
    trade yet add a terminal request each), 863 when it omits it (a terminal request for all 348 daily and 176 hourly)."""
    others = [(22, 8), (23, 7), (24, 9), (25, 5), (26, 2), (27, 7), (28, 16), (29, 5), (30, 9), (31, 2), (39, 197), (53, 1), (57, 1)]
    return [20] * 12 + [21] * tails + [w for w, n in others for _ in range(n)]


def packed(monkeypatch, tmp_path, weights):
    clock = [0]
    fake_clock(monkeypatch, clock)
    limiter = market.Exchange(tmp_path, limiter=market.WeightLimit(120))
    for w in weights[:12] + sorted(weights[12:]):
        limiter._charge(w)
    return clock[0] // 60_000


def test_the_recorded_and_stress_histograms_pack_in_155_and_257_zero_latency_minutes(tmp_path, monkeypatch):
    recorded, stress = inventory(349), inventory(863)
    assert (len(recorded), sum(recorded)) == (630, 17_206) and (len(stress), sum(stress)) == (1_144, 28_000)
    assert packed(monkeypatch, tmp_path / "a", recorded) == 155
    assert packed(monkeypatch, tmp_path / "b", stress) == 257


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
