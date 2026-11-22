"""G100's median effects (step 9's diagnostics): the study's own `judge` on G100's recorded pick for each judged
market, one line a market in `audit/control-1/g100-medians.jsonl`. It is no arm: nothing the arms import imports
it. It stops on any market whose `pairs_won` or `earns` differs from `searcher.jsonl`, or whose reference
median differs from `results.jsonl`'s. `python -m gate.control.g100_medians`."""

import json
import os
import shutil
import sys
import tempfile
from collections.abc import Mapping
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Any

from gate.control import manifest
from gate.control.judge import judge, program_key
from gate.control.pick import evaluated
from gate.control.runner import read_lines
from gate.control.searcher import AGENT

Line = dict[str, Any]


def recorded_pick(ledger: Path, market_id: str, key: str) -> dict[str, Any]:
    """The program G100 evaluated on the market whose hash is `key`."""
    for program, _ in evaluated(ledger, market_id, AGENT):
        if program_key(program) == key:
            return dict(program)
    raise ValueError(f"{market_id}: no evaluated program hashes to the recorded pick {key}")


def diagnose(strength: float, work: Path, scratch: Path, recorded: Line) -> Line:
    market_id = recorded["id"]
    program = recorded_pick(work / "searcher" / market_id / "ledger.sqlite", market_id, recorded["pick"])
    folder = scratch / market_id
    folder.mkdir(parents=True, exist_ok=True)
    try:
        [judged] = judge([program], strength, market_id, folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    line: Line = {"id": market_id, **judged}
    return line


def mismatches(found: Line, recorded: Line, results: Mapping[str, Line]) -> list[str]:
    market_id = found["id"]
    wrong = [key for key in ("pick", "pairs_won", "earns") if found[key] != recorded[key]]
    if found["reference_median"] != recorded["reference_median"]:
        wrong.append("reference_median (searcher.jsonl)")
    result = results.get(market_id)
    if result is not None and result["reference_median"] not in (None, found["reference_median"]):
        wrong.append("reference_median (results.jsonl)")
    return [f"{market_id}: {key}" for key in wrong]


def run(out: Path, work: Path, scratch: Path, workers: int) -> list[str]:
    """Write `out/g100-medians.jsonl` and return every mismatch."""
    content = manifest.verify()
    strength = content["strength"]
    recorded = [line for line in read_lines(out / "searcher.jsonl") if line["pick"] is not None]
    results = {line["id"]: line for line in read_lines(out / "results.jsonl")}
    judged = [line for line in recorded if line["id"] in results]
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(diagnose, strength, work, scratch, line) for line in judged]
        found = [future.result() for future in futures]
    wrong = [m for f, r in zip(found, judged) for m in mismatches(f, r, results)]
    target = out / "g100-medians.jsonl"
    partial = target.with_suffix(".partial")
    partial.write_text("".join(json.dumps(line) + "\n" for line in found))
    os.replace(partial, target)
    return wrong


WORK_ARMS = Path("/home/kevin/repos/mm-s1-arms/data/control-1")


def main() -> int:
    scratch = Path(tempfile.mkdtemp(dir=Path.home() / ".cache" / "mm-s1-report"))
    wrong = run(manifest.OUT, WORK_ARMS, scratch, os.cpu_count() or 1)
    print("\n".join(wrong) if wrong else "every market reproduced")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
