"""The measure (step 2); only the kernel layer's `score` exists so far."""

import json
import math
import tempfile
from pathlib import Path
from subprocess import DEVNULL, run
from typing import Any

from gate.kernel import command


def score(program: dict[str, Any], market: Path) -> float | None:
    """The `sharpe_annualized` that `mm eval` discloses on the market's search period, or None when the kernel
    rejects the program or discloses no finite statistic. The ledger is a scratch one, deleted on return."""
    with tempfile.TemporaryDirectory() as scratch:
        path = Path(scratch) / "program.json"
        path.write_text(json.dumps(program))
        ledger = Path(scratch) / "ledger.sqlite"
        cmd = command("eval", path, "scratch", "scratch", ledger, market, "--disclose", "sharpe_annualized")
        out = run(cmd, capture_output=True, text=True, stdin=DEVNULL)
    lines = (out.stdout or out.stderr).strip().splitlines()
    if not lines:
        return None
    try:
        parsed = json.loads(lines[-1])
    except json.JSONDecodeError:
        return None
    value = parsed.get("disclosure", {}).get("result", {}).get("sharpe_annualized")
    if value is None or not math.isfinite(value):
        return None
    return float(value)
