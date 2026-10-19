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
