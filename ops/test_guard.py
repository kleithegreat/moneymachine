"""The test guard: a runaway test ends at the timeout even if it ignores SIGTERM, and at the memory limit if it allocates."""

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def start(tmp_path, *args):
    env = {**os.environ, "RUNAWAY_STARTED": str(tmp_path / "started")}
    return subprocess.Popen([sys.executable, "-m", "pytest", "-q", "-n0", "-p", "no:cacheprovider", *args], cwd=REPO, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def test_timeout_stops_a_test_that_ignores_sigterm(tmp_path):
    p = start(tmp_path, "--timeout=5", "ops/runaway.py::test_loops")
    while not (tmp_path / "started").exists() and p.poll() is None:
        time.sleep(0.05)
    p.send_signal(signal.SIGTERM)
    out, _ = p.communicate(timeout=60)
    assert p.returncode == 1 and "Timeout" in out, out


def test_memory_limit_stops_a_test_that_allocates(tmp_path):
    p = start(tmp_path, "--timeout=60", "-o", "worker_memory_gb=0.5", "ops/runaway.py::test_allocates")
    out, _ = p.communicate(timeout=120)
    assert p.returncode == 1 and "worker_memory_gb exceeded" in out and "Timeout" not in out, out
