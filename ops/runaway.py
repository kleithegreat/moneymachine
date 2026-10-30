"""Tests that never end, run only by ops/test_guard.py: the series' loop with STOP mocked, which ignores SIGTERM."""

import os
from pathlib import Path

from gate.agent import campaigns


def series(tmp_path, monkeypatch, chunk):
    held = []

    def wait(self, seconds):
        Path(os.environ["RUNAWAY_STARTED"]).touch()
        held.append(b"x" * chunk)

    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(campaigns, "check_frozen", lambda: None)
    monkeypatch.setattr(campaigns, "windows", lambda token=None: {"five_hour": [0.99, 100]})
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "cornell")
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"is_set": lambda self: False, "wait": wait, "set": lambda self: None})())
    campaigns.run_series("agent", 1)


def test_loops(tmp_path, monkeypatch):
    series(tmp_path, monkeypatch, 1)


def test_allocates(tmp_path, monkeypatch):
    series(tmp_path, monkeypatch, 10**7)
