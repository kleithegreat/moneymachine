"""Judging programs against the reference (steps 5, 7, 8): each program's score pairs on a market's fresh pairs,
classified by step 2's measure."""

import hashlib
import json
import shutil
import statistics
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from gate.control import pairs
from gate.control.measure import ScorePair, classify, effect, scores

PROGRAMS = Path(__file__).resolve().parent / "programs"


def load_program(name: str) -> dict[str, Any]:
    loaded: dict[str, Any] = json.loads((PROGRAMS / f"{name}.json").read_text())
    return loaded


def program_key(program: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(program, sort_keys=True).encode()).hexdigest()


def fresh_scores(
    strength: float, market_id: str, programs: Sequence[dict[str, Any]], work: Path
) -> list[list[ScorePair]]:
    """Each program's score pairs on the market's fresh pairs. A pair is on disk only while scored."""
    per_program: list[list[ScorePair]] = [[] for _ in programs]
    root = work / "fresh"
    for fresh in pairs.fresh_ids(market_id):
        planted, twin = pairs.write_pair(root, fresh, strength)
        try:
            scored = scores(programs, [(planted, twin)])
        finally:
            shutil.rmtree(root)
        for mine, [pair] in zip(per_program, scored):
            mine.append(pair)
    return per_program


def reads(program: Any) -> list[str]:
    """The inputs a program reads, sorted and without repeats."""
    found: set[str] = set()
    if isinstance(program, dict):
        name = program.get("input")
        if isinstance(name, str):
            found.add(name)
        for value in program.values():
            found.update(reads(value))
    elif isinstance(program, list):
        for item in program:
            found.update(reads(item))
    return sorted(found)


def median(values: Sequence[float | None]) -> float | None:
    defined = [v for v in values if v is not None]
    return statistics.median(defined) if defined else None


def judge(programs: Sequence[dict[str, Any]], strength: float, market_id: str, work: Path) -> list[dict[str, Any]]:
    """Each program classified against the reference on the market's fresh pairs: its hash, the inputs it reads,
    the pairs it wins, the median effects of the reference and of the program, and whether it earns."""
    reference, *rest = fresh_scores(strength, market_id, [load_program("reference"), *programs], work)
    reference_median = median([effect(pair) for pair in reference])
    judged = []
    for program, scored in zip(programs, rest):
        won, earns = classify(scored, reference)
        judged.append(
            {
                "pick": program_key(program),
                "reads": reads(program),
                "pairs_won": won,
                "reference_median": reference_median,
                "pick_median": median([effect(pair) for pair in scored]),
                "earns": earns,
            }
        )
    return judged
