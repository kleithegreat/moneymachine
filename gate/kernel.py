"""The kernel binary `mm`: where cargo puts it (honoring CARGO_TARGET_DIR), and building it."""

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"


def build():
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    return MM
