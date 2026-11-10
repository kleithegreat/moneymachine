"""C10.2 (audit/stage10/criteria-revision-round11-draft.md), guarantee 1: the daemon commits each call's record before any
reply byte leaves it, so a process killed between the two leaves a record and no reply, never a reply without a record."""

import json
import multiprocessing as mp
import os
import signal
import socket
import time

import pytest

from sandbox.server import Server
from thesis import daemon as thesis_daemon
from thesis import positions, registry
from thesis.tests.test_daemon import CONFIG, DATA, NOW, SNAPSHOT, Fetcher, thesis

ACCOUNT = "main"


def build(root):
    ledger = registry.Ledger(root / "l.sqlite", "thesis-test")
    d = thesis_daemon.Daemon(root / "s.sock", "s1", ACCOUNT, ledger, SNAPSHOT, Fetcher(), root / "responses",
                             lambda account, now: None, lambda account, markets, now: None, ("markets",), clock=lambda: NOW)
    return d, ledger


def serve_then_stall_before_replying(root):
    d, _ = build(root)

    def stalled(req):
        body = d.handle(req)
        (root / "recorded").touch()
        time.sleep(3600)
        return body

    Server(root / "s.sock", stalled)
    (root / "ready").touch()
    time.sleep(3600)


def ask(root, request):
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(str(root / "s.sock"))
        s.sendall(json.dumps(request).encode() + b"\n")
        (root / "reply").write_bytes(s.makefile("rb").readline())


def wait_for(path):
    for _ in range(500):
        if path.exists():
            return
        time.sleep(0.02)
    raise AssertionError(f"{path} never appeared")


def test_a_kill_between_the_record_and_the_reply_leaves_a_record_and_no_reply(tmp_path):
    child = mp.get_context("fork").Process(target=serve_then_stall_before_replying, args=(tmp_path,))
    child.start()
    try:
        wait_for(tmp_path / "ready")
        asked = mp.get_context("fork").Process(target=ask, args=(tmp_path, {"cmd": "markets", "args": []}))
        asked.start()
        wait_for(tmp_path / "recorded")
        os.kill(child.pid, signal.SIGKILL)
        child.join()
        asked.join(timeout=10)
        assert (tmp_path / "reply").read_bytes() == b""
    finally:
        if child.is_alive():
            os.kill(child.pid, signal.SIGKILL)
        if asked.is_alive():
            asked.terminate()
    ledger = registry.Ledger(tmp_path / "l.sqlite", "thesis-test")
    calls = ledger.calls(ACCOUNT)
    assert [c["request"] for c in calls] == [{"cmd": "markets", "args": []}]
    stored = tmp_path / "responses" / f"{calls[0]['response_sha256']}.json"
    assert stored.exists() and registry.sha256(stored.read_bytes()) == calls[0]["response_sha256"]


def register_and_exit_stalling(root, stall_at, stalled):
    """Registers a thesis and then exits it, where every ledger commit stalls on its `stall_at`-th call: before the
    commit when `stall_at` is negative, after it otherwise."""
    ledger = registry.Ledger(root / "l.sqlite", "thesis-test")
    commit = ledger.disclose
    counted = []

    def disclose(kind, account, content):
        counted.append(kind)
        if -stall_at == len(counted):
            stalled.touch()
            time.sleep(3600)
        row = commit(kind, account, content)
        if stall_at == len(counted):
            stalled.touch()
            time.sleep(3600)
        return row

    ledger.disclose = disclose
    replay = lambda account, now: positions.run(10_000.0, ledger.theses(account), ledger.exits(account), DATA, now)
    d = thesis_daemon.Daemon(root / "s.sock", "s1", ACCOUNT, ledger, SNAPSHOT, Fetcher(), root / "responses", replay,
                             lambda account, markets, now: (CONFIG, DATA), ("register", "exit"), clock=lambda: NOW)
    d.handle({"cmd": "register", "args": [thesis()]})
    d.handle({"cmd": "exit", "args": ["main-1", "done"]})


@pytest.mark.parametrize("stall_at", [-1, 1, -2, 2])
def test_a_kill_at_any_commit_leaves_no_effect_row_without_its_call_record(tmp_path, built_kernel, stall_at):
    """A thesis, exit or ablation row carries its call record, so a daemon killed at any point of a command's commits leaves
    both or neither (D3 of audit/reviews/2026-11-09-argon-web-refreeze-rounds13-14.md)."""
    stalled = tmp_path / "stalled"
    child = mp.get_context("fork").Process(target=register_and_exit_stalling, args=(tmp_path, stall_at, stalled))
    child.start()
    try:
        wait_for(stalled)
        os.kill(child.pid, signal.SIGKILL)
        child.join()
    finally:
        if child.is_alive():
            os.kill(child.pid, signal.SIGKILL)
    ledger = registry.Ledger(tmp_path / "l.sqlite", "thesis-test")
    effects = [c for kind in ("thesis", "exit", "ablation") for _, _, c in ledger.records(kind, ACCOUNT)]
    assert all("call" in c for c in effects)
    for c in effects:
        stored = tmp_path / "responses" / f"{c['call']['response_sha256']}.json"
        assert stored.exists() and registry.sha256(stored.read_bytes()) == c["call"]["response_sha256"]
    assert [c["seq"] for c in ledger.calls(ACCOUNT)] == list(range(1, len(effects) + 1))


def test_a_fetched_body_is_stored_by_its_hash_before_the_record_commits(tmp_path, built_kernel, monkeypatch):
    ledger = registry.Ledger(tmp_path / "l.sqlite", "thesis-test")
    d = thesis_daemon.Daemon(tmp_path / "s.sock", "s1", ACCOUNT, ledger, SNAPSHOT, Fetcher(), tmp_path / "responses",
                             lambda account, now: None, lambda account, markets, now: None, ("fetch",), clock=lambda: NOW)
    seen = []
    commit = ledger.disclose
    monkeypatch.setattr(ledger, "disclose", lambda *a: seen.append(sorted(p.name for p in (tmp_path / "responses").iterdir())) or commit(*a))
    d.handle({"cmd": "fetch", "args": ["https://ok"]})
    digest = registry.sha256(b"news")
    [call] = ledger.calls(ACCOUNT)
    assert call["fetch"]["body_sha256"] == digest and f"{digest}.body" in seen[0]
    assert (tmp_path / "responses" / f"{digest}.body").read_bytes() == b"news"
