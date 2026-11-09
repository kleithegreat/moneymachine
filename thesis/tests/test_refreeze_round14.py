"""Round fourteen: Argon's rounds 11-12 review, F1-F2 and the restart hunt."""

import json

import httpx
import pytest

from ingest.policy import DAY
from thesis import report, runner
from thesis.tests.test_refreeze_round10 import NINE, at
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401

CUT = MONDAY + runner.RETRY_UNTIL


class Healing(FakeMarket):
    """BTC fails its first daily read; X fails every read; `during` runs inside a market's retry."""

    def __init__(self, until, clock, during=None):
        super().__init__(until)
        self.clock, self.during, self.first = clock, during, True

    def bars(self, market, interval, now=None):
        if market == "X":
            self.clock[0] = max(self.clock[0], CUT) if self.clock[0] > NINE else self.clock[0]
            raise httpx.ReadTimeout("x down")
        if market == "BTC" and interval == "1d" and self.first:
            self.first = False
            raise httpx.ReadTimeout("btc once")
        if market == "BTC" and interval == "1h" and self.during:
            self.during()
        return super().bars(market, interval, now)


def test_f1_a_market_healed_before_the_cutoff_is_not_left_failed_by_a_later_cut(track, monkeypatch):
    clock = [NINE]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.market = Healing(MONDAY + 40 * DAY, clock)
    track.acquire(MONDAY)
    clock[0] = CUT - 1
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert set(snap["failed"]) == {"X"} and snap["ready"]["BTC"] is True and "BTC" in snap["benchmark_markets"]


def test_f1_an_in_flight_read_finishing_after_the_cutoff_still_gets_its_readiness(track, monkeypatch):
    clock = [NINE]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.market = Healing(MONDAY + 40 * DAY, clock, during=lambda: clock.__setitem__(0, CUT) if clock[0] > NINE else None)
    track.market.bars = (lambda f: lambda m, i, now=None: f("ETH", i, now) if m == "X" else f(m, i, now))(track.market.bars)
    track.acquire(MONDAY)
    clock[0] = CUT - 1
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap is not None and snap["failed"] == {} and snap["ready"]["BTC"] is True


class Dex(FakeMarket):
    """Builder dex xyz is down until `heal`; reading a market takes 30 s."""

    def __init__(self, until, clock, heal):
        super().__init__(until)
        self.clock, self.heal = clock, heal

    def dexes(self, *, background=False):
        return ["xyz"]

    def universe(self, dex=None, *, background=False):
        if dex is None:
            return {m: False for m in ("BTC", "ETH", "flx:OIL")}
        if self.clock[0] < self.heal:
            raise httpx.ConnectError("xyz down")
        return {**{f"xyz:A{i}": False for i in range(6)}, "xyz:D0": True, "xyz:GOLD": False, "xyz:XYZ100": False}

    def bars(self, market, interval, now=None):
        self.clock[0] += 30_000
        return super().bars(market, interval, now)


def test_f2_a_dex_healing_late_gets_a_first_read_of_every_market_and_delisted_ones_need_none(track, monkeypatch):
    clock = [NINE]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    track.market = Dex(MONDAY + 40 * DAY, clock, CUT - 120_000)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is None
    clock[0] = CUT - 120_000
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap is not None and snap["failed"] == {}
    assert {"xyz:GOLD", "xyz:XYZ100"} <= set(snap["benchmark_markets"])


class Counting(FakeMarket):
    def __init__(self, until):
        super().__init__(until)
        self.btc = 0

    def bars(self, market, interval, now=None):
        if market == "BTC":
            self.btc += 1
            raise httpx.ReadTimeout("btc down")
        return super().bars(market, interval, now)


def test_restart_keeps_the_draft_so_readiness_at_and_the_cutoff_survive_it(track, monkeypatch):
    track.market = Counting(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    attempts = track.market.btc
    track.draft = None
    at(monkeypatch, CUT + 60_000)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert track.market.btc == attempts and "BTC" in snap["failed"] and snap["readiness_at"] == NINE


def transcript(work, tool):
    work.mkdir(parents=True, exist_ok=True)
    line = {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "a", "name": tool, "input": {}}]}}
    (work / "transcript.jsonl").write_text(json.dumps(line) + "\n")


def c10_2_after(track, monkeypatch, tmp_path, tool, how):
    """C10.2's verdict on a report written after a session that used `tool` and ended `how`."""
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)

    def run_session(work, kind, start_daemon, task=None):
        transcript(work, tool)
        if how == "error":
            raise OSError("the sandbox died")
        return {"kind": kind}

    monkeypatch.setattr(runner.harness, "run_session", run_session)
    track.session("main", MONDAY, {"taken": MONDAY}, ())
    report.write(track, MONDAY + DAY, tmp_path / "r.json")
    return json.loads((tmp_path / "r.json").read_text())["c10_2"]


@pytest.mark.parametrize("how", ["finished", "error"])
def test_c10_2_fails_a_session_that_used_a_tool_outside_the_permitted_set(track, monkeypatch, tmp_path, how):
    c10_2 = c10_2_after(track, monkeypatch, tmp_path, "WebFetch", how)
    assert c10_2["pass"] is False and c10_2["outside_permitted"] == {"main-%d" % MONDAY: ["WebFetch"]}


@pytest.mark.parametrize("how", ["finished", "error"])
def test_c10_2_passes_a_session_that_used_only_permitted_tools(track, monkeypatch, tmp_path, how):
    assert c10_2_after(track, monkeypatch, tmp_path, "Read", how) == {"pass": True, "outside_permitted": {}}


def test_c10_2_fails_a_session_whose_transcript_cannot_be_audited(track, monkeypatch, tmp_path):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    monkeypatch.setattr(runner.harness, "run_session", lambda work, *a, **k: work.mkdir(parents=True) or (work / "transcript.jsonl").mkdir() or {})
    track.session("main", MONDAY, {"taken": MONDAY}, ())
    report.write(track, MONDAY + DAY, tmp_path / "r.json")
    assert json.loads((tmp_path / "r.json").read_text())["c10_2"]["pass"] is False


def test_c10_2_audits_a_session_the_runner_died_in(track, monkeypatch, tmp_path):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.ledger.disclose("session", "main", {"session": "main-1", "kind": "main", "started": 1, "taken": MONDAY, "manifest": "0"})
    transcript(track.root / "sessions" / track.version / "main-1", "WebSearch")
    track.close_interrupted()
    report.write(track, MONDAY + DAY, tmp_path / "r.json")
    assert json.loads((tmp_path / "r.json").read_text())["c10_2"]["outside_permitted"] == {"main-1": ["WebSearch"]}
