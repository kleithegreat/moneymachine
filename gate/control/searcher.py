"""G100's arm (step 7): G100 on each study market, its pick classified like the agent's, one line a market in
`audit/control-1/searcher.jsonl`. `python -m gate.control.searcher`."""

import json
import os
import shutil
import sys
import tempfile
from collections.abc import Callable, Mapping
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Any

from gate import search
from gate.control import manifest, pairs
from gate.control.calibrate import g100_seed
from gate.control.judge import judge
from gate.control.pick import evaluated

AGENT = "G100"
WORK = manifest.REPO / "data" / "control-1"

Trial = Callable[[str, float, int, Path], dict[str, Any]]


def bests(ledger: Path, campaign: str, agent: str) -> list[int]:
    """The numbers, from 1, of the agent's evaluations after which the pick of the ledger cut there changed."""
    changed: list[int] = []
    best: float | None = None
    for number, (_, value) in enumerate(evaluated(ledger, campaign, agent), start=1):
        if value is not None and (best is None or value > best):
            best = value
            changed.append(number)
    return changed


def g100_trial(market_id: str, strength: float, seed: int, scratch: Path) -> dict[str, Any]:
    """G100 on the market, with its ledger kept in `scratch`: its pick and each earlier best, classified."""
    scratch.mkdir(parents=True, exist_ok=True)
    market = pairs.write_market(scratch, market_id, strength)
    ledger = scratch / "ledger.sqlite"
    spent = search.run(AGENT, market, ledger, market_id, seed)
    shutil.rmtree(market)
    programs = [program for program, _ in evaluated(ledger, market_id, AGENT)]
    numbers = bests(ledger, market_id, AGENT)
    judged: list[dict[str, Any]] = []
    if numbers:
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as temporary:
            judged = judge([programs[n - 1] for n in numbers], strength, market_id, Path(temporary))
    earlier = [
        {"evaluation": n, "pick": j["pick"], "pairs_won": j["pairs_won"], "earns": j["earns"]}
        for n, j in zip(numbers, judged)
    ]
    final = (
        judged[-1] if judged else {"pick": None, "reads": [], "pairs_won": 0, "reference_median": None, "earns": False}
    )
    return {
        "evaluations": spent,
        "pick": final["pick"],
        "reads": final["reads"],
        "pairs_won": final["pairs_won"],
        "reference_median": final["reference_median"],
        "earns": final["earns"],
        "earlier": earlier,
    }


def line_of(trial: Trial, seed: str, strength: float, work: Path, market_id: str) -> dict[str, Any]:
    scratch = work / "searcher" / market_id
    shutil.rmtree(scratch, ignore_errors=True)
    market_seed = g100_seed(seed, market_id)
    return {"id": market_id, "seed": market_seed, **trial(market_id, strength, market_seed, scratch)}


def run(
    out: Path, work: Path, *, verify: Callable[[], Mapping[str, Any]], trial: Trial = g100_trial, workers: int = 1
) -> None:
    """Verify the manifest, refuse if any study market has an agent run, then write `out/searcher.jsonl`: the same
    file however the markets are spread over workers, and all or nothing."""
    content = verify()
    ids: list[str] = content["markets"]
    started = [market_id for market_id in ids if (work / "agent" / market_id).exists()]
    if started:
        raise RuntimeError(f"G100's arm must be complete before the first session; agent runs exist on {started[:3]}")
    strength = content["strength"]
    seed = content["seed"]
    if workers <= 1:
        lines = [line_of(trial, seed, strength, work, market_id) for market_id in ids]
    else:
        with ProcessPoolExecutor(max_workers=workers) as pool:
            futures = [pool.submit(line_of, trial, seed, strength, work, market_id) for market_id in ids]
            lines = [future.result() for future in futures]
    target = out / "searcher.jsonl"
    partial = target.with_suffix(".partial")
    partial.write_text("".join(json.dumps(line) + "\n" for line in lines))
    os.replace(partial, target)


def main() -> int:
    run(manifest.OUT, WORK, verify=manifest.verify, workers=os.cpu_count() or 1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
