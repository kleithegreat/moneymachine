"""C10.2 (audit/stage10/criteria-revision-round11-draft.md), guarantee 2: in the thesis workspace the daemon's socket is the
only way to protected data. gate/tests/test_sandbox.py proves the sandbox's isolation for the research workspace;
this runs its view and network probes on the thesis workspace, where only the client's name and spec differ."""

import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from sandbox import session
from thesis import harness
from thesis.tests.test_record_before_reply import wait_for

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


def descendants(pid):
    out = []
    for p in os.listdir("/proc"):
        if p.isdigit():
            try:
                parent = int(Path(f"/proc/{p}/stat").read_text().rsplit(")", 1)[1].split()[1])
            except OSError:
                continue
            if parent == pid:
                out += [int(p), *descendants(int(p))]
    return out


def running(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0] != "Z"
    except OSError:
        return False


def test_the_cli_dies_with_the_runner(tmp_path):
    """bwrap --die-with-parent: SIGKILL of the runner takes every process of the sandbox with it, so no CLI outlives the
    runner to keep writing a transcript nobody audits."""
    harness.workspace(tmp_path, "main")
    sleeper = "import os, time; open('/work/up', 'w').write(str(os.getpid())); time.sleep(600)"
    runner_code = (
        "import os, subprocess, sys, time\n"
        "from sandbox import session\n"
        "os.environ['CLAUDE_CODE_OAUTH_TOKEN'] = 'x'\n"
        f"subprocess.Popen(session.sandbox_command(sys.argv[1], 'thesis-agent', [sys.executable, '-c', {sleeper!r}]),"
        " stdin=subprocess.DEVNULL)\n"
        "time.sleep(600)\n"
    )
    parent = subprocess.Popen([sys.executable, "-c", runner_code, str(tmp_path)], cwd=REPO)
    try:
        wait_for(tmp_path / "work" / "up")
        sandboxed = descendants(parent.pid)
        assert len(sandboxed) >= 2
        parent.kill()
        parent.wait()
        deadline = time.time() + 10
        while time.time() < deadline and any(running(p) for p in sandboxed):
            time.sleep(0.1)
        assert [p for p in sandboxed if running(p)] == []
    finally:
        parent.kill()
