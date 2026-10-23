"""The kernel binary `mm`: where cargo puts it (honoring CARGO_TARGET_DIR), building it, and its command lines."""

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"


def build():
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    return MM


def command(cmd, path, campaign, agent, ledger, market=None, *extra):
    """`mm cmd path` for one campaign and agent; with `market`, on its store and venue."""
    m = ["--store", str(Path(market) / "store"), "--venue", str(Path(market) / "venue")] if market else []
    return [str(MM), cmd, str(path), "--campaign", campaign, "--agent", agent, *m, "--ledger", str(ledger), *extra]
