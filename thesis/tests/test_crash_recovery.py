"""Process-death checks of the runner's once-per-session and registry's retry contracts.

The model, venue and external readiness/identity checks are fakes; the kernel, registry, ledger,
snapshots and recovery are real.
Expectations come from runner/registry docstrings and audit/criteria.md's stage-10 Sessions/Registration.
"""

import json
import random
import sqlite3
from pathlib import Path

import pytest

from ingest.tests.crash_helpers import acknowledge, checkpoint, kill_during, recover
from thesis import registry, runner
from thesis.tests.test_registry import CONFIG, DATA, T_R, request
from thesis.tests.test_runner import DAY, HOUR, MONDAY, ZERO, FakeMarket

MODULE = __name__


def track(root, now=MONDAY + runner.SESSION_OFFSET):
    runner.kernel.build = lambda: runner.kernel.MM
    runner.harness.manifest_hash = lambda binary: "0" * 64
    runner.now_ms = lambda: now
    t = runner.Track(root)
    t.market = FakeMarket(MONDAY + 40 * DAY)
    t.config = lambda markets: {"initial": 10_000.0, "fee": 0.0,
                                "costs": {m: ZERO for m in markets}, "fallback": []}
    t.ready = lambda date: True
    runner.harness.audit = lambda transcript, calls: {}
    return t


def register(ledger, i, now=T_R):
    th, errors = registry.register(ledger, "main", "session", request(request_id=f"r{i}"),
                                   lambda: now, {"f1"}, CONFIG, DATA)
    assert errors is None
    return th


def worker(root, interactive):
    root = Path(root)
    mode = (root / "mode").read_text()
    if mode == "registry":
        ledger = registry.Ledger(root / "registry.sqlite", "crash-registry")
        for i in range(8):
            checkpoint(f"register:{i}", interactive)
            acknowledge(register(ledger, i, T_R if interactive else T_R + HOUR))
    else:
        now = MONDAY + runner.SESSION_OFFSET + (0 if interactive else HOUR)
        t = track(root, now)
        runner.now_ms = lambda: MONDAY + runner.SNAPSHOT_OFFSET
        assert t.acquire(MONDAY)
        runner.now_ms = lambda: now

        def model(work, kind, start_daemon, task=None):
            checkpoint(f"model:{kind}", interactive)
            if kind == "main":
                snapshot = t.snapshot(MONDAY + runner.SNAPSHOT_OFFSET)
                for i in range(2):
                    config, data = t.inputs("main", ["BTC"], now, snapshot)
                    th, errors = registry.register(
                        t.ledger, "main", f"main-{MONDAY}",
                        request(request_id=f"r{i}", legs=[["BTC", 1]], sources=[], T=MONDAY + 21 * DAY),
                        lambda: now, set(), config, data)
                    assert errors is None
                    checkpoint(f"accepted:{i}", interactive)
            acknowledge(kind)
            return {"kind": kind}

        runner.harness.run_session = model
        checkpoint("day", interactive)
        t.schedule(now, MONDAY)
    checkpoint("finished", interactive)


@pytest.mark.parametrize("seed", [7, 29, 101, 307])
def test_registry_random_sigkill_then_retries_commit_each_request_once(tmp_path, seed, built_kernel):
    (tmp_path / "mode").write_text("registry")
    ledger = registry.Ledger(tmp_path / "registry.sqlite", "crash-registry")
    first = register(ledger, 0)
    target = random.Random(seed).randrange(1, 7)
    acks = kill_during(MODULE, tmp_path, f"register:{target}", seed)
    committed = ledger.records("thesis", "main")
    recover(MODULE, tmp_path)
    rows = ledger.records("thesis", "main")
    assert rows[:len(committed)] == committed
    theses = ledger.theses("main")
    assert theses[0] == first
    assert [th["request_id"] for th in theses] == [f"r{i}" for i in range(8)]
    assert [th["id"] for th in theses] == [f"main-{i}" for i in range(1, 9)]
    assert [th["size"] for th in theses] == ["1000"] * 5 + ["0"] * 3
    assert all(th in theses for th in acks)
    with sqlite3.connect(ledger.path) as db:
        assert db.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        for (content,) in db.execute("SELECT content FROM disclosures"):
            assert content == json.dumps(json.loads(content), sort_keys=True, separators=(",", ":"))
    recover(MODULE, tmp_path)
    assert ledger.records("thesis", "main") == rows
    changed, errors = registry.register(ledger, "main", "session", request(request_id="r0", p=0.7),
                                       lambda: T_R, {"f1"}, CONFIG, DATA)
    assert changed is None and errors
    assert ledger.records("thesis", "main") == rows


@pytest.mark.parametrize("target,seed", [("day", 7), ("day", 29), ("day", 101), ("day", 307),
                                        ("model:main", 7), ("accepted:0", 29), ("accepted:1", 101),
                                        ("model:ablation", 307), ("model:noread", 503)])
def test_day_random_sigkill_consumes_started_sessions_and_runs_the_rest_once(tmp_path, monkeypatch, target, seed, built_kernel):
    (tmp_path / "mode").write_text("day")
    kill_during(MODULE, tmp_path, target, seed)
    monkeypatch.setattr(runner.harness, "manifest_hash", lambda binary: "0" * 64)
    t = runner.Track(tmp_path)
    before = t.ledger.records("session")
    ended = t.ledger.records("session_end")
    accepted = t.ledger.theses("main")
    recover(MODULE, tmp_path)
    starts = t.ledger.records("session")
    ends = t.ledger.records("session_end")
    theses = t.ledger.theses("main")
    expected = [f"main-{MONDAY}", *(f"ablation-{th['id']}" for th in theses), f"noread-{MONDAY}"]
    assert starts[:len(before)] == before
    assert ends[:len(ended)] == ended
    assert [row[2]["session"] for row in starts] == expected
    assert sorted(row[2]["session"] for row in ends) == sorted(expected)
    if any(row[2]["kind"] == "main" for row in before):
        assert theses == accepted
    else:
        assert len(theses) == 2
    assert not t.ledger.records("session_missed")
    main = next(row[2] for row in starts if row[2]["kind"] == "main")
    noread = next(row[2] for row in starts if row[2]["kind"] == "noread")
    assert main["taken"] == noread["taken"]
    interrupted = {row[2]["session"] for row in before} - {
        row[2]["session"] for row in ended}
    assert {row[2]["session"] for row in ends if "error" in row[2]} == interrupted
    all_rows = {kind: t.ledger.records(kind) for kind in ("session", "session_end", "thesis", "session_missed")}
    recover(MODULE, tmp_path)
    assert {kind: t.ledger.records(kind) for kind in all_rows} == all_rows
