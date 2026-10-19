"""C3.1: the agent sandbox cannot see the repo, data, ledger, real HOME, scratch space or host processes."""

import subprocess
from pathlib import Path

from gate.agent import harness

REPO = Path(__file__).resolve().parents[2]


def test_sandbox_view(tmp_path):
    work, home = harness.build_workspace(tmp_path)
    secret_paths = [str(REPO), str(REPO / "data"), str(Path.home()), str(tmp_path), "/run", "/var"]
    script = "; ".join(f"test -e '{p}' && echo VISIBLE {p}" for p in secret_paths)
    script += "; n=0; for p in /proc/[0-9]*; do n=$((n+1)); done; echo $n; ls /work; ls -A /home; ls /etc"
    r = subprocess.run(harness.sandbox_command(work, home, ["/bin/sh", "-c", script]), capture_output=True, text=True)
    assert "VISIBLE" not in r.stdout, r.stdout
    lines = r.stdout.split()
    assert int(lines[0]) <= 3
    assert set(lines[1:]) >= {"DSL.md", "brief.md", "mm-agent", "research.md", "agent"}
    assert "shadow" not in lines and "nixos" not in lines


def test_swarm_agents_cannot_reach_each_other(tmp_path):
    """C4.3: an agent's sandbox sees neither another agent's workspace nor its socket."""
    import socket
    import sys

    (w1, h1), (w2, h2) = (harness.build_workspace(tmp_path / a, swarm=True) for a in ("A1", "A2"))
    other = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    other.bind(str(w2 / "mm-agent.sock"))
    other.listen()
    probe = ("import socket, os\n"
             f"for p in [{str(w2)!r}, {str(w2 / 'mm-agent.sock')!r}, {str(tmp_path)!r}]:\n"
             "    print('VISIBLE' if os.path.exists(p) else 'hidden', p)\n"
             "s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
             f"try:\n    s.connect({str(w2 / 'mm-agent.sock')!r}); print('CONNECTED')\n"
             "except OSError as e:\n    print('refused', e.errno)\n"
             "print(sorted(os.listdir('/work')))\n")
    r = subprocess.run(harness.sandbox_command(w1, h1, [sys.executable, "-c", probe]), capture_output=True, text=True)
    other.close()
    assert "VISIBLE" not in r.stdout and "CONNECTED" not in r.stdout and "refused" in r.stdout, r.stdout + r.stderr
    assert "mm-agent.sock" not in r.stdout.splitlines()[-1]
