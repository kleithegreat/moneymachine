"""C3.1: the agent sandbox cannot see the repo, data, ledger, real HOME, scratch space, host processes or host
environment, cannot change or subvert its client, and reaches the network only through the egress relay."""

import json
import os
import socket
import subprocess
import sys
from pathlib import Path

import pytest

from gate.agent import harness
from sandbox import session
from sandbox.egress import Proxy

REPO = Path(__file__).resolve().parents[2]


@pytest.fixture(autouse=True)
def token(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "test-token")


def inside(workdir, script):
    return subprocess.run(session.sandbox_command(workdir, harness.CLIENT, ["/bin/sh", "-c", script]),
                          capture_output=True, text=True, env=os.environ | {"MM_SECRET": "x"})


def test_sandbox_view(tmp_path):
    harness.build_workspace(tmp_path)
    secret_paths = [str(REPO), str(REPO / "data"), str(Path.home()), str(tmp_path), "/run", "/var", "/etc/static"]
    script = "; ".join(f"test -e '{p}' && echo VISIBLE {p}" for p in secret_paths)
    script += "; n=0; for p in /proc/[0-9]*; do n=$((n+1)); done; echo $n; ls /work; ls -A /home; ls /etc"
    r = inside(tmp_path, script)
    assert "VISIBLE" not in r.stdout, r.stdout
    lines = r.stdout.split()
    assert int(lines[0]) <= 4
    assert set(lines[1:]) >= {"DSL.md", "brief.md", "mm-agent", "research.md", "agent"}
    assert "shadow" not in lines and "nixos" not in lines


def test_only_the_closure_of_the_store_and_no_host_environment(tmp_path):
    """Flake source snapshots of the repo sit in /nix/store; only the CLI's, Python's and coreutils' closure is
    mounted."""
    harness.build_workspace(tmp_path)
    r = inside(tmp_path, "ls /nix/store; echo ENV; env")
    store, env = r.stdout.split("ENV\n")
    assert {f"/nix/store/{p}" for p in store.split()} == set(session.store_paths())
    assert not any(p.endswith("-source") for p in store.split())
    assert "MM_SECRET" not in env and str(REPO) not in env
    assert "CLAUDE_CODE_OAUTH_TOKEN=test-token" in env.split()


def test_the_client_cannot_be_replaced_or_fed_modules(tmp_path):
    harness.build_workspace(tmp_path)
    (tmp_path / "work" / "json.py").write_text("print('PLANTED')\n")
    r = inside(tmp_path, "echo x > ./mm-agent; mv brief.md mm-agent; rm -f mm-agent; ./mm-agent budget; head -c 2 ./mm-agent")
    assert "PLANTED" not in r.stdout
    assert r.stdout.endswith("#!"), r.stdout + r.stderr


def test_network_only_through_the_relay_to_its_hosts(tmp_path):
    harness.build_workspace(tmp_path)
    proxy = Proxy((tmp_path / "tool").resolve() / "egress.sock", ["example.invalid"], tmp_path / "egress.log")
    probe = ("import socket, urllib.request\n"
             "try:\n    socket.create_connection(('1.1.1.1', 443), timeout=3); print('DIRECT')\n"
             "except OSError:\n    print('no route')\n"
             "s = socket.create_connection(('127.0.0.1', 3128), timeout=3)\n"
             "s.sendall(b'CONNECT api.hyperliquid.xyz:443 HTTP/1.1\\r\\n\\r\\n'); print(s.recv(100).split()[1].decode())\n")
    r = subprocess.run(session.sandbox_command(tmp_path, harness.CLIENT, [sys.executable, "-c", probe]),
                       capture_output=True, text=True)
    proxy.close()
    assert r.stdout.split() == ["no", "route", "403"], r.stdout + r.stderr
    log = [json.loads(line) for line in open(tmp_path / "egress.log")]
    assert log[0]["request"].startswith("CONNECT api.hyperliquid.xyz:443") and not log[0]["allowed"]


def test_swarm_agents_cannot_reach_each_other(tmp_path):
    """C4.3: an agent's sandbox sees neither another agent's workspace nor its socket."""
    a1, a2 = tmp_path / "A1", tmp_path / "A2"
    for a in (a1, a2):
        harness.build_workspace(a, swarm=True)
    other = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    other.bind(str(session.socket_path(a2, harness.CLIENT)))
    other.listen()
    target = str(session.socket_path(a2, harness.CLIENT))
    probe = ("import socket, os\n"
             f"for p in [{str(a2)!r}, {target!r}, {str(tmp_path)!r}]:\n"
             "    print('VISIBLE' if os.path.exists(p) else 'hidden', p)\n"
             "s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
             f"try:\n    s.connect({target!r}); print('CONNECTED')\n"
             "except OSError as e:\n    print('refused', e.errno)\n"
             "print(sorted(os.listdir('/work')))\n")
    r = subprocess.run(session.sandbox_command(a1, harness.CLIENT, [sys.executable, "-c", probe]),
                       capture_output=True, text=True)
    other.close()
    assert "VISIBLE" not in r.stdout and "CONNECTED" not in r.stdout and "refused" in r.stdout, r.stdout + r.stderr
    assert "mm-agent.sock" not in r.stdout.splitlines()[-1]


def test_closing_the_proxy_stops_its_thread(tmp_path):
    import threading

    before = threading.active_count()
    Proxy(tmp_path / "e.sock", [], tmp_path / "e.log").close()
    for _ in range(50):
        if threading.active_count() == before:
            break
        threading.Event().wait(0.02)
    assert threading.active_count() == before
