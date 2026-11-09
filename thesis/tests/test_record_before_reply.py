"""C10.2 (audit/stage10/criteria-revision-round11-draft.md), guarantee 1: the daemon commits each call's record before any
reply byte leaves it, so a process killed between the two leaves a record and no reply, never a reply without a record."""

import json
import multiprocessing as mp
import os
import signal
import socket
import time

from sandbox.server import Server
from thesis import daemon as thesis_daemon
from thesis import registry
from thesis.tests.test_daemon import NOW, SNAPSHOT, Fetcher

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
    calls = [c for _, _, c in ledger.records("call", ACCOUNT)]
    assert [c["request"] for c in calls] == [{"cmd": "markets", "args": []}]
    stored = tmp_path / "responses" / f"{calls[0]['response_sha256']}.json"
    assert stored.exists() and registry.sha256(stored.read_bytes()) == calls[0]["response_sha256"]
