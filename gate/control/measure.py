"""The measure (step 2): the pure layer that classifies a pick against the reference, and the kernel layer that
scores programs on markets."""

import json
import math
import subprocess
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from gate.control.constants import MAJORITY, PAIRS, SHARE
from gate.kernel import command

Score = float | None
ScorePair = tuple[Score, Score]


def finite(value: Score) -> bool:
    return value is not None and math.isfinite(value)


def effect(pair: ScorePair) -> float | None:
    """The planted score minus the twin score; None when either is missing or not finite, or the difference is not."""
    planted, twin = pair
    if planted is None or twin is None or not finite(planted) or not finite(twin):
        return None
    difference = planted - twin
    return difference if math.isfinite(difference) else None


def wins(pick: ScorePair, reference: ScorePair) -> bool:
    """Both effects are defined, the reference's is positive and the pick's is at least SHARE times it."""
    pick_effect = effect(pick)
    reference_effect = effect(reference)
    if pick_effect is None or reference_effect is None:
        return False
    return reference_effect > 0 and pick_effect >= SHARE * reference_effect


def classify(pick: Sequence[ScorePair], reference: Sequence[ScorePair]) -> tuple[int, bool]:
    """The count of pairs the pick wins against the reference, and whether it earns from the plant."""
    if len(pick) != PAIRS or len(reference) != PAIRS:
        raise ValueError(f"a pick and a reference need {PAIRS} pairs each, got {len(pick)} and {len(reference)}")
    won = sum(wins(p, r) for p, r in zip(pick, reference))
    return won, won >= MAJORITY


def mean(first: Score, second: Score) -> Score:
    return None if first is None or second is None else (first + second) / 2


def even(member: Sequence[ScorePair], mirror: Sequence[ScorePair]) -> list[ScorePair]:
    """The even part of a mirror pair: on each market, the mean of the two members' scores."""
    return [(mean(a[0], b[0]), mean(a[1], b[1])) for a, b in zip(member, mirror)]


def disclosed(line: str) -> Score:
    try:
        parsed = json.loads(line)
    except json.JSONDecodeError:
        return None
    value = parsed.get("disclosure", {}).get("result", {}).get("sharpe_annualized")
    if value is None or not math.isfinite(value):
        return None
    return float(value)


def evaluate(programs: Sequence[dict[str, Any]], market: Path) -> list[Score]:
    """Every program's disclosed `sharpe_annualized` on the market's search period, through one `mm eval` process
    and a scratch ledger deleted on return; None for a program the kernel rejects."""
    with tempfile.TemporaryDirectory() as scratch:
        ledger = Path(scratch) / "ledger.sqlite"
        cmd = command("eval", "-", "scratch", "scratch", ledger, market, "--disclose", "sharpe_annualized")
        with subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1
        ) as process:
            assert process.stdin is not None and process.stdout is not None
            results: list[Score] = []
            for program in programs:
                process.stdin.write(json.dumps(program) + "\n")
                process.stdin.flush()
                line = process.stdout.readline()
                if not line:
                    raise RuntimeError(f"mm eval exited with {process.wait()}")
                results.append(disclosed(line))
            process.stdin.close()
    return results


def score(program: dict[str, Any], market: Path) -> Score:
    return evaluate([program], market)[0]


def scores(programs: Sequence[dict[str, Any]], pairs: Sequence[tuple[Path, Path]]) -> list[list[ScorePair]]:
    """For each program, its (planted, twin) scores on each pair, with one kernel process a distinct market for
    all the programs."""
    by_market = {market: evaluate(programs, market) for market in dict.fromkeys(m for pair in pairs for m in pair)}
    return [[(by_market[planted][i], by_market[twin][i]) for planted, twin in pairs] for i in range(len(programs))]
