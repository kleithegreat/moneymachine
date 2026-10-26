"""The kernel binary `mm`: where cargo puts it (honoring CARGO_TARGET_DIR), building it, and its command lines."""

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"


def build():
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    return MM


def command(cmd, path, campaign, agent, ledger, market=None, *extra, binary=MM):
    """`mm cmd path` for one campaign and agent (by `binary`, the current build unless a caller pins its own); with
    `market`, on its store and venue at the dataset version its `version` file pins."""
    m = ["--store", str(Path(market) / "store"), "--venue", str(Path(market) / "venue"),
         "--version", (Path(market) / "version").read_text().strip()] if market else []
    return [str(binary), cmd, str(path), "--campaign", campaign, "--agent", agent, *m, "--ledger", str(ledger), *extra]
