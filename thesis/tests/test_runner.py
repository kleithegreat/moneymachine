"""The runner's ledger-driven schedule: resolutions once (or a missing-data status once), the frozen
benchmark's rule and skips, ablation inputs cut at registration, the Monday arithmetic, and the wait for a
session's readiness."""

import json
import signal
import subprocess
import sys
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
        self.delisted = set()
        self.calls = []

    def listings(self):
        self.calls.append(("listings",))
        return {m: m in self.delisted for m in (*runner.BENCHMARK, "X")}

    def listed(self, markets):
        return {m: m in self.delisted for m in (*runner.BENCHMARK, "X") if m in markets}

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
    assert skips == {"flx:OIL": f"no daily close at {[MONDAY - 2 * DAY]}"}
    assert track.unbenchmarked(MONDAY) == []


def test_a_benchmark_skip_names_its_cause():
    snapshot = {"listings": {"BTC": False, "flx:OIL": True, "xyz:GOLD": False}, "markets": {"BTC": {}},
                "daily": {"BTC": [[0, 1.0, 1.0], [DAY, 1.0, 1.0]]}}
    causes = {m: runner.unbenchmarkable(snapshot, m, (0, DAY)) for m in ("BTC", "flx:OIL", "xyz:GOLD", "xyz:XYZ100")}
    assert causes == {"BTC": None, "flx:OIL": "delisted", "xyz:GOLD": "fewer than 90 daily bars or no hourly close",
                      "xyz:XYZ100": "not listed"}
    assert runner.unbenchmarkable(snapshot, "BTC", (0, 2 * DAY)) == f"no daily close at {[2 * DAY]}"


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
    track.deadlines(MONDAY + 21 * DAY + HOUR)
    assert track.ledger.records("resolution") == []
    for later in (3, 4):
        track.resolve(MONDAY + 21 * DAY + later * HOUR)
        track.deadlines(MONDAY + 21 * DAY + later * HOUR)
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


def test_readiness_waits_for_the_model_and_the_canary_and_refuses_a_stop_or_an_expired_day(track, monkeypatch):
    clock = [MONDAY + HOUR]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    monkeypatch.setattr(runner.session, "available", lambda model: True)
    checks = iter([False, True])
    monkeypatch.setattr(runner.canary, "passes", lambda: next(checks))
    waited = []
    monkeypatch.setattr(track.stop, "wait", waited.append)
    assert track.ready(MONDAY) and waited == [runner.session.RETRY]
    monkeypatch.setattr(runner.canary, "passes", lambda: clock.__setitem__(0, MONDAY + DAY) or True)
    assert not track.ready(MONDAY)
    clock[0] = MONDAY + HOUR
    monkeypatch.setattr(runner.canary, "passes", lambda: track.stop.set() or True)
    assert not track.ready(MONDAY)


@pytest.mark.parametrize("fails_at, stopped, missed", [
    (0, False, ["main", "noread"]), (0, True, []), (1, True, []),
    (2, False, ["ablation-t2", "noread"]), (3, False, ["noread"])])
def test_every_session_of_a_day_that_cannot_run_is_missed_but_a_stop_leaves_the_date(track, monkeypatch, fails_at, stopped, missed):
    """Readiness holds for the first `fails_at` sessions (main, two ablations, noread), then fails by a stop or the
    day's end."""
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + HOUR)
    asked, ran = [], []

    def ready(date):
        asked.append(date)
        if len(asked) > fails_at and stopped:
            track.stop.set()
        return len(asked) <= fails_at

    monkeypatch.setattr(track, "ready", ready)
    monkeypatch.setattr(track, "snapshot", lambda now: {"taken": MONDAY})
    monkeypatch.setattr(track, "ablation_task", lambda th, snapshot: ({}, {"taken": th["id"]}))
    monkeypatch.setattr(track.ledger, "theses", lambda account: [{"id": t, "session": f"main-{MONDAY}"} for t in ("t1", "t2") if ran])
    monkeypatch.setattr(runner.harness, "run_session", lambda work, kind, daemon, task: ran.append(kind) or {"kind": kind})
    monkeypatch.setattr(runner.harness, "audit", lambda transcript, calls: {})
    track.day(MONDAY)
    assert ran == ["main", "ablation", "ablation", "noread"][:fails_at]
    assert [c["session"].split(f"-{MONDAY}")[0] for _, _, c in track.ledger.records("session_missed")] == missed


def test_a_snapshot_that_outlasts_the_day_starts_nothing(track, monkeypatch):
    clock = [MONDAY + HOUR]
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "snapshot", lambda now: clock.__setitem__(0, MONDAY + DAY) or {"taken": now})
    monkeypatch.setattr(track, "session", lambda *a, **k: pytest.fail("started"))
    track.day(MONDAY)
    assert [c["session"] for _, _, c in track.ledger.records("session_missed")] == [f"main-{MONDAY}", f"noread-{MONDAY}"]


def test_versions_sharing_a_root_keep_their_own_session_directories(track, monkeypatch):
    made = []
    monkeypatch.setattr(runner.harness, "run_session", lambda work, kind, daemon, task: made.append(work) or work.mkdir(parents=True) or {})
    monkeypatch.setattr(runner.harness, "audit", lambda transcript, calls: {})
    track.session("main", MONDAY, {"taken": 0}, ())
    track.version = "thesis-later"
    track.session("main", MONDAY, {"taken": 0}, ())
    assert made[0] != made[1] and made[1].parent.name == "thesis-later"


def test_a_session_that_raises_still_ends_on_the_record(track, monkeypatch):
    monkeypatch.setattr(runner.harness, "run_session", lambda *a: (_ for _ in ()).throw(OSError("bwrap failed")))
    track.session("main", MONDAY, {"taken": 0}, ())
    [(_, _, end)] = track.ledger.records("session_end", "main")
    assert end["session"] == f"main-{MONDAY}" and "bwrap failed" in end["error"]


def test_a_stop_during_the_snapshot_starts_nothing_and_leaves_the_date(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + HOUR)
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "snapshot", lambda now: track.stop.set() or {})
    monkeypatch.setattr(track, "session", lambda *a, **k: pytest.fail("started"))
    track.day(MONDAY)
    assert track.ledger.records("session_missed") == []


# GPT's bug hunt (audit/reviews/2026-11-02-gpt-hunt-thesis.md), findings 3, 4, 5 and 8.
CHILD = """
import os, sys, time
from thesis import runner
from thesis.tests.test_runner import FakeMarket, MONDAY, DAY, HOUR, ZERO
runner.harness.manifest_hash = lambda kernel: "0" * 64
runner.now_ms = lambda: MONDAY + HOUR
root, flag, dies_in = sys.argv[1:]
t = runner.Track(root)
t.market = FakeMarket(MONDAY + 40 * DAY)
t.ready = lambda date: True
def run_session(work, kind, start_daemon, task=None):
    if kind == "main":
        t.ledger.disclose("thesis", "main", {"id": "main-1", "session": f"main-{MONDAY}", "legs": [["BTC", 1]],
                                             "t_r": MONDAY + HOUR, "T": MONDAY + 21 * DAY})
    if kind == dies_in:
        open(flag, "w").close()
        time.sleep(3600)
    return {"kind": kind}
runner.harness.run_session = run_session
runner.harness.audit = lambda transcript, calls: {}
t.day(MONDAY)
"""


def killed_during(root, kind):
    """A runner process in the sessions of MONDAY, killed by SIGKILL during its first session of `kind`."""
    flag = root / "flag"
    child = subprocess.Popen([sys.executable, "-c", CHILD, str(root), str(flag), kind], cwd=runner.REPO)
    try:
        for _ in range(600):
            if flag.exists() or child.poll() is not None:
                break
            time.sleep(0.1)
        assert flag.exists(), "the child never reached its session"
    finally:
        child.send_signal(signal.SIGKILL)
        child.wait()


@pytest.mark.parametrize("dies_in", ["main", "ablation", "noread"])
def test_a_runner_killed_mid_day_ends_that_session_on_the_record_and_runs_the_rest(track, monkeypatch, dies_in):
    killed_during(track.root, dies_in)
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 2 * HOUR)
    monkeypatch.setattr(track, "ready", lambda date: True)
    snapshots = []

    def run_session(work, kind, start_daemon, task=None):
        snapshots.append(kind)
        return {"kind": kind}

    monkeypatch.setattr(runner.harness, "run_session", run_session)
    monkeypatch.setattr(runner.harness, "audit", lambda transcript, calls: {})
    track.schedule(MONDAY + 2 * HOUR, MONDAY)
    track.schedule(MONDAY + 2 * HOUR, MONDAY)
    order = ["main", "ablation", "noread"]
    assert snapshots == order[order.index(dies_in) + 1:]
    ends = {c["session"]: c for _, _, c in track.ledger.records("session_end")}
    names = {"main": f"main-{MONDAY}", "ablation": "ablation-main-1", "noread": f"noread-{MONDAY}"}
    assert set(ends) == set(names.values()) and "error" in ends[names[dies_in]]
    assert all("error" not in c for n, c in ends.items() if n != names[dies_in])


def test_the_noread_session_after_a_restart_sees_the_main_sessions_snapshot(track, monkeypatch):
    killed_during(track.root, "main")
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 2 * HOUR)
    monkeypatch.setattr(track, "ready", lambda date: True)
    monkeypatch.setattr(track, "ablation_task", lambda th, snapshot: ({}, {"taken": th["t_r"]}))
    seen = []
    monkeypatch.setattr(track, "daemon", lambda sock, session, account, snapshot, commands, ablation_of=None: seen.append(snapshot))
    monkeypatch.setattr(runner.harness, "run_session", lambda work, kind, start_daemon, task=None: start_daemon("s") or {"kind": kind})
    monkeypatch.setattr(runner.harness, "audit", lambda transcript, calls: {})
    track.schedule(MONDAY + 2 * HOUR, MONDAY)
    [(_, _, main)] = [r for r in track.ledger.records("session") if r[2]["kind"] == "main"]
    assert seen[-1]["taken"] == main["taken"] == MONDAY + HOUR


def test_a_stop_after_main_leaves_the_rest_of_the_date_to_the_next_start(track, monkeypatch):
    killed_during(track.root, "main")
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 2 * HOUR)
    monkeypatch.setattr(track, "ready", lambda date: track.stop.set() or False)
    track.schedule(MONDAY + 2 * HOUR, MONDAY)
    assert track.ledger.records("session_missed") == []


def test_a_date_the_runner_was_down_for_is_disclosed_missed(track, monkeypatch):
    now = MONDAY + 5 * 60_000
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    monkeypatch.setattr(track, "ready", lambda date: False)
    track.schedule(now, MONDAY - 3 * DAY + 3 * HOUR)
    missed = sorted(c["session"] for _, _, c in track.ledger.records("session_missed"))
    assert missed == sorted(f"{kind}-{MONDAY - k * DAY}" for kind in ("main", "noread") for k in (1, 2, 3))


def test_a_restart_after_the_day_ended_discloses_the_rest_as_missed(track, monkeypatch):
    killed_during(track.root, "main")
    now = MONDAY + DAY + HOUR
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    monkeypatch.setattr(track, "ready", lambda date: False)
    track.schedule(now, MONDAY)
    missed = {c["session"] for _, _, c in track.ledger.records("session_missed")}
    assert {"ablation-main-1", f"noread-{MONDAY}", f"main-{MONDAY + DAY}"} <= missed
    assert f"main-{MONDAY}" not in missed


def failing_once(market, m):
    """`market`'s funding raises for `m` until the returned list is cleared."""
    armed, funding = [1], market.funding

    def wrapped(name, now=None):
        if name == m and armed:
            raise httpx.TransportError("down")
        return funding(name, now)

    market.funding = wrapped
    return armed


def on_record(track, monday):
    names = [th["legs"][0][0] for th in track.ledger.theses("benchmark") if th["session"] == f"benchmark-{monday}"]
    return names + [c["market"] for _, _, c in track.ledger.records("skip", "benchmark") if c["date"] == monday]


def test_a_benchmark_market_that_fails_is_retried_with_the_rest_of_its_batch(track, monkeypatch):
    now = MONDAY + 60_000
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    armed = failing_once(track.market, "ETH")
    with pytest.raises(httpx.TransportError):
        track.benchmarks(now, MONDAY)
    assert on_record(track, MONDAY) == ["BTC"]
    armed.clear()
    track.benchmarks(now, MONDAY)
    assert sorted(on_record(track, MONDAY)) == sorted(runner.BENCHMARK)
    assert track.market.calls.count(("listings",)) <= 1


def test_a_benchmark_batch_cut_off_past_its_day_logs_each_market_left_as_missed(track, monkeypatch):
    now = MONDAY + 60_000
    monkeypatch.setattr(runner, "now_ms", lambda: now)
    failing_once(track.market, "ETH")
    with pytest.raises(httpx.TransportError):
        track.benchmarks(now, MONDAY)
    track.benchmarks(MONDAY + DAY, MONDAY)
    skips = {c["market"]: c["reason"] for _, _, c in track.ledger.records("skip", "benchmark") if c["date"] == MONDAY}
    assert sorted(on_record(track, MONDAY)) == sorted(runner.BENCHMARK)
    assert skips == {m: "run missed" for m in runner.BENCHMARK if m != "BTC"}


def test_every_monday_the_runner_was_down_for_is_logged_missed(track):
    track.benchmarks(MONDAY + 15 * DAY, MONDAY)
    for monday in (MONDAY, MONDAY + 7 * DAY, MONDAY + 14 * DAY):
        assert sorted(on_record(track, monday)) == sorted(runner.BENCHMARK)


def test_a_horizon_still_unresolved_gets_its_status_before_the_two_hour_deadline(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    T = MONDAY + 21 * DAY
    track.market.until = T - HOUR
    track.deadlines(T + runner.RESOLUTION_GRACE - 1)
    assert track.ledger.records("resolution") == []
    track.deadlines(T + runner.RESOLUTION_GRACE)
    assert len(track.ledger.records("resolution")) == 4


def test_a_status_does_not_stop_a_later_score(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    T = MONDAY + 21 * DAY
    track.market.until = T - HOUR
    track.resolve(T + 2 * HOUR - 300_000)
    track.deadlines(T + 2 * HOUR - 300_000)
    track.market.until = T + 4 * HOUR
    track.resolve(T + 4 * HOUR)
    track.deadlines(T + 4 * HOUR)
    statuses = [c["status"] for _, _, c in track.ledger.records("resolution")]
    assert statuses == ["missing data"] * 4 + ["resolved"] * 4


# F5: a thesis's score depends only on its own markets, and its status on no market at all.
def test_a_resolvable_thesis_is_scored_though_an_unrelated_market_fails(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    T = MONDAY + 21 * DAY
    failing_once(track.market, "ETH")
    track.resolve(T + HOUR)
    by_id = {th["id"]: th["legs"][0][0] for th in track.ledger.theses("benchmark")}
    scored = {by_id[c["id"]] for _, _, c in track.ledger.records("resolution") if c["status"] == "resolved"}
    assert scored == {"BTC", "xyz:XYZ100", "xyz:GOLD"}


def test_a_managed_replay_that_fails_still_scores_the_outcome_and_the_remaining_theses(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    monkeypatch.setattr(runner.positions, "run", lambda *a: (_ for _ in ()).throw(LookupError("no bar")))
    track.resolve(MONDAY + 21 * DAY + HOUR)
    records = [c for _, _, c in track.ledger.records("resolution")]
    assert [c["status"] for c in records] == ["resolved"] * 4
    assert all(c["outcome"] is not None and c["managed_return"] is None and "no bar" in c["managed_failure"] for c in records)


def test_a_thesis_scored_alone_has_the_managed_return_of_its_whole_account(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    now = MONDAY + 21 * DAY + HOUR
    track.resolve(now)
    whole = track.replay("benchmark", now)["theses"]
    assert all(c["managed_return"] == whole[c["id"]]["managed_return"] for _, _, c in track.ledger.records("resolution"))


def test_a_market_that_hangs_holds_up_no_status(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    T = MONDAY + 21 * DAY
    entered, release = threading.Event(), threading.Event()
    funding = track.market.funding

    def hung(name, now=None):
        entered.set()
        release.wait(30)
        return funding(name, now)

    track.market.funding = hung
    resolving = threading.Thread(target=track.resolve, args=(T + runner.RESOLUTION_GRACE,))
    resolving.start()
    try:
        assert entered.wait(30)
        track.deadlines(T + runner.RESOLUTION_GRACE)
        assert [c["status"] for _, _, c in track.ledger.records("resolution")] == ["missing data"] * 4
    finally:
        release.set()
        resolving.join()
    assert [c["status"] for _, _, c in track.ledger.records("resolution")][4:] == ["resolved"] * 4


def test_a_record_carries_the_time_it_was_written_beside_its_data_cutoff(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.benchmark(MONDAY)
    T = MONDAY + 21 * DAY
    cutoff, written = T + 95 * 60_000, T + 126 * 60_000
    monkeypatch.setattr(runner, "now_ms", lambda: written)
    track.deadlines(cutoff)
    track.resolve(cutoff)
    for _, _, c in track.ledger.records("resolution"):
        assert c["at"] == written
    assert all(c["cutoff"] == cutoff for _, _, c in track.ledger.records("resolution") if c["status"] == "resolved")


def test_the_runner_runs_the_deadlines_on_their_own_loop(track, monkeypatch, tmp_path):
    frozen = tmp_path / "manifest.json"
    frozen.write_text(json.dumps({"manifest": track.manifest, "frozen": MONDAY}))
    monkeypatch.setattr(runner, "FROZEN", frozen)
    names = []
    monkeypatch.setattr(runner, "forever", lambda name, step, wait, stop: names.append(name))
    monkeypatch.setattr(signal, "signal", lambda *a: None)
    track.market.record_marks = lambda: None
    track.run()
    assert "deadlines" in names and "resolve" in names


# F6: a benchmark's p is the base rate of what it registers.
class Trending(FakeMarket):
    """ETH's opens gain 10.5 bp each 21 days, so a window's sign turns on its cost cell, and BTC doubles from `jump`."""

    def __init__(self, until, jump):
        super().__init__(until)
        self.jump = jump

    def bars(self, market, interval, now=None):
        if market == "ETH" and interval == "1d":
            first = MONDAY // DAY - 400
            price = lambda t: round(100.0 * 1.00105 ** ((t - first) / 21), 6)
            return [[t * DAY, price(t), price(t + 1)] for t in range(first, MONDAY // DAY) if now is None or (t + 1) * DAY + DELTA <= now]
        rows = super().bars(market, interval, now)
        return [[t, 200.0, 200.0] if market == "BTC" and interval == "1h" and t >= self.jump else [t, o, c] for t, o, c in rows]


def test_a_benchmark_resumed_after_its_equity_moved_registers_the_base_rate_of_its_own_notional(track, monkeypatch):
    cells = {"buy": {"1000": 1, "10000": 8}, "sell": {"1000": 1, "10000": 8}}
    track.market = Trending(MONDAY + 40 * DAY, MONDAY + 3 * HOUR)
    monkeypatch.setattr(track, "config", lambda markets: {"initial": 10_000.0, "fee": 0.0, "costs": {m: cells for m in markets}, "fallback": []})
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    armed = failing_once(track.market, "ETH")
    with pytest.raises(httpx.TransportError):
        track.benchmark(MONDAY)
    armed.clear()
    later = MONDAY + 5 * HOUR
    monkeypatch.setattr(runner, "now_ms", lambda: later)
    track.benchmark(MONDAY)
    eth = next(th for th in track.ledger.theses("benchmark") if th["legs"][0][0] == "ETH")
    assert runner.positions.exact(eth["N"]) > 1000
    assert eth["p"] == eth["p_ref"] == 1 / (eth["base_windows"] + 2)


def test_a_benchmark_without_a_base_rate_at_its_commit_is_skipped(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    monkeypatch.setattr(runner.scoring, "base_rate", lambda th, daily, funding: (None, 0, 0))
    track.benchmark(MONDAY)
    assert track.ledger.theses("benchmark") == []
    assert "no base rate" in {c["reason"] for _, _, c in track.ledger.records("skip", "benchmark")}


# F9: eligibility is read at the commit, after the slow preparation.
def registration(track, snapshot):
    d = runner.Daemon(track.root / "s", "main-x", "main", track.ledger, snapshot, None, track.root / "responses", None,
                      lambda account, markets, now: track.inputs(account, markets, now, snapshot), runner.MAIN_COMMANDS,
                      clock=lambda: MONDAY + 60_000)
    return d.register([json.dumps({"request_id": "r", "legs": [["BTC", 1]], "T": MONDAY + 10 * DAY, "p": 0.5, "L": 0.1,
                                   "catalyst": "c", "catalyst_id": "c", "sources": [], "outcome_market": None})])


def test_a_market_delisted_while_its_inputs_are_prepared_is_refused(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    snapshot = track.snapshot(MONDAY)
    funding = track.market.funding
    track.market.funding = lambda name, now=None: (track.market.delisted.add("BTC"), funding(name, now))[1]
    out = registration(track, snapshot)
    assert not out["ok"] and "legs: BTC is not listed" in out["errors"]


def test_a_thesis_records_the_listing_read_its_eligibility_came_from(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    out = registration(track, track.snapshot(MONDAY))
    assert out["thesis"]["listings"] == {"BTC": False} and out["thesis"]["listings_read"][1] <= out["thesis"]["t_r"]


def test_a_market_delisted_after_the_snapshot_is_refused_at_registration(track, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    snapshot = track.snapshot(MONDAY)
    track.market.delisted = {"BTC"}
    out = registration(track, snapshot)
    assert not out["ok"] and "legs: BTC is not listed" in out["errors"]


def test_a_horizon_exit_frees_its_reservation_for_the_session_of_that_morning(tmp_path, monkeypatch):
    # A position whose horizon is 00:00 has closed by the 00:10 session, whose candle at 00:00 is still in progress.
    th = {"id": "a", "t_r": MONDAY - 5 * DAY, "legs": [["X", 1]], "T": MONDAY, "L": 0.1, "fee": 0.0, "costs": {"X": ZERO},
          "N": 1000.0, "size": 1000.0, "b": 100.0}
    hours = range(MONDAY // HOUR - 200, MONDAY // HOUR + 1)

    class Venue:
        def candles(self, market, interval, start, end):
            return [{"t": h * HOUR, "o": "100", "c": "100"} for h in hours if start <= h * HOUR < end]

        def funding(self, market, start, end):
            return [{"time": h * HOUR, "fundingRate": "0"} for h in hours if start <= h * HOUR < end]

    m = runner.Market(tmp_path, Venue())
    now = MONDAY + 10 * 60_000
    data = {"bars": {"X": runner.scoring.bars(m.bars("X", "1h", now))}, "funding": {"X": dict(m.funding("X", now))},
            "lag": {"X": m.lag("X")}}
    assert runner.positions.replay(10_000.0, [th], [], data, now)[0].reserved() == 0
