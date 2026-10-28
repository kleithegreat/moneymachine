"""A recorder stops between polls on SIGTERM, and `restart` relaunches it from its pidfile."""

import json
import subprocess
import sys
import threading

import pytest

from ingest import live, record


def test_forever_stops_between_steps():
    stop, steps = threading.Event(), []
    record.forever(lambda: (steps.append(1), stop.set()), stop)
    assert steps == [1]


def sleeper(*argv):
    """A process with the given argv that exits cleanly on SIGTERM, returned once its handler is set."""
    code = "import signal, sys, time; signal.signal(signal.SIGTERM, lambda *_: sys.exit(0)); print(flush=True); time.sleep(60)"
    p = subprocess.Popen([sys.executable, "-c", code, *argv], stdout=subprocess.PIPE)
    p.stdout.readline()
    return p


def test_restart_stops_the_recorder_and_starts_it_with_the_new_budget(tmp_path, monkeypatch):
    old = sleeper("cli", "record")
    args = {"universe_path": "u.json", "rules_path": "r.json", "out_dir": str(tmp_path), "budget": 1200}
    (tmp_path / live.PIDFILE).write_text(json.dumps({"pid": old.pid, "command": "record", "args": args}))
    started = []
    monkeypatch.setattr(live.subprocess, "Popen", lambda argv, **kw: started.append(argv) or type("P", (), {"pid": 1})())
    assert {k: v for k, v in live.restart(tmp_path, 480, wait=10).items() if k != "unit"} == {"stopped": old.pid, "started": 1}
    assert old.wait(timeout=5) == 0
    assert started[0][:4] == ["systemd-run", "--user", "--scope", "--quiet"]
    assert started[0][5:] == [sys.executable, "-m", "cli", "record", "u.json", "r.json", str(tmp_path), "480"]


def test_restart_leaves_an_unrelated_process_with_a_reused_pid_alone(tmp_path, monkeypatch):
    other = sleeper("something", "else")
    (tmp_path / live.PIDFILE).write_text(json.dumps({"pid": other.pid, "command": "sources-record", "args": {"out_dir": "x"}}))
    started = []
    monkeypatch.setattr(live.subprocess, "Popen", lambda argv, **kw: started.append(argv) or type("P", (), {"pid": 1})())
    live.restart(tmp_path, wait=10)
    assert other.poll() is None
    other.kill()
    assert started[0][5:] == [sys.executable, "-m", "cli", "sources-record", "x"]


def test_restart_refuses_a_budget_the_recorder_does_not_take(tmp_path):
    (tmp_path / live.PIDFILE).write_text(json.dumps({"pid": 0, "command": "sources-record", "args": {"out_dir": "x"}}))
    with pytest.raises(ValueError):
        live.restart(tmp_path, 480)


def test_recording_writes_the_pidfile_with_out_dir_among_the_arguments(tmp_path):
    import os
    import signal

    before = signal.getsignal(signal.SIGTERM)
    try:
        stop = live.recording(tmp_path, "sources-record", out_dir=str(tmp_path))
        rec = json.loads((tmp_path / live.PIDFILE).read_text())
        assert rec == {"pid": os.getpid(), "command": "sources-record", "args": {"out_dir": str(tmp_path)}}
        assert not stop.is_set()
        with pytest.raises(SystemExit):
            live.recording(tmp_path, "sources-record", out_dir=str(tmp_path))
    finally:
        signal.signal(signal.SIGTERM, before)
