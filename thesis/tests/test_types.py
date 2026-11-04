"""The thesis track's fixed modules hold to `mypy --strict`, so a later change cannot quietly drop their types."""

import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MODULES = ["thesis/positions.py", "thesis/market.py", "thesis/registry.py", "thesis/daemon.py", "thesis/runner.py",
           "ingest/live.py", "ingest/datalayer.py", "ingest/hl.py"]


def test_the_fixed_modules_pass_mypy_strict():
    r = subprocess.run([sys.executable, "-m", "mypy", "--strict", "--follow-imports=skip", *MODULES], cwd=REPO,
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
