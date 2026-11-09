"""C10.2 (audit/stage10/criteria-revision-round11-draft.md), guarantee 2: in the thesis workspace the daemon's socket is the
only way to protected data. gate/tests/test_sandbox.py proves the sandbox's isolation for the research workspace;
this runs its view and network probes on the thesis workspace, where only the client's name and spec differ."""

import os
import subprocess
import sys
from pathlib import Path

import pytest

from sandbox import session
from thesis import harness

REPO = Path(__file__).resolve().parents[2]


@pytest.fixture(autouse=True)
def token(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "test-token")


def test_the_thesis_workspace_shows_neither_the_repo_nor_the_data_and_has_no_route_out(tmp_path):
    harness.workspace(tmp_path, "main")
    secret_paths = [str(REPO), str(REPO / "data"), str(Path.home()), str(tmp_path), "/run", "/var"]
    probe = ("import os, socket\n"
             f"for p in {secret_paths!r}:\n    print('VISIBLE' if os.path.exists(p) else 'hidden', p)\n"
             "print(sorted(os.listdir('/work')))\n"
             "try:\n    socket.create_connection(('1.1.1.1', 443), timeout=3); print('DIRECT')\n"
             "except OSError:\n    print('no route')\n")
    r = subprocess.run(session.sandbox_command(tmp_path, harness.CLIENT, [sys.executable, "-c", probe]),
                       capture_output=True, text=True, env=os.environ)
    assert "VISIBLE" not in r.stdout and "DIRECT" not in r.stdout and "no route" in r.stdout, r.stdout + r.stderr
    assert f"['brief.md', '{harness.CLIENT}']" in r.stdout
