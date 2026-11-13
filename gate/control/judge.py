"""Judging programs against the reference (steps 5, 7, 8): each program's score pairs on a market's fresh pairs,
classified by step 2's measure."""

import hashlib
import json
import os
import shutil
import statistics
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from gate.control import pairs
from gate.control.measure import Score, ScorePair, classify, effect, evaluate

PROGRAMS = Path(__file__).resolve().parent / "programs"


def load_program(name: str) -> dict[str, Any]:
    loaded: dict[str, Any] = json.loads((PROGRAMS / f"{name}.json").read_text())
    return loaded


def program_key(program: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(program, sort_keys=True).encode()).hexdigest()


def twin_in(twins: Path, market_id: str) -> Path:
    """The market's twin, generated and written once under `twins`; a twin cut short by a kill is rewritten."""
    final = twins / f"{pairs.stem(market_id)}-twin"
    if not final.exists():
        partial = pairs.write_market(twins, market_id, 0.0, "partial")
        os.replace(partial, final)
    return final


def twin_scores(programs: Sequence[dict[str, Any]], market_id: str, twins: Path) -> list[Score]:
    """Each program's score on the market's twin; a program scored there before is read from the twin's cache."""
    cache_file = twins / f"{pairs.stem(market_id)}-scores.json"
    cached: dict[str, Score] = json.loads(cache_file.read_text()) if cache_file.exists() else {}
    keys = [program_key(p) for p in programs]
    missing = [p for p, k in zip(programs, keys) if k not in cached]
    if missing:
        twin = twin_in(twins, market_id)
        for program, value in zip(missing, evaluate(missing, twin)):
            cached[program_key(program)] = value
        partial = cache_file.with_suffix(".partial")
        partial.write_text(json.dumps(cached))
        os.replace(partial, cache_file)
    return [cached[k] for k in keys]


def fresh_scores(
    strength: float, market_id: str, programs: Sequence[dict[str, Any]], work: Path, twins: Path
) -> list[list[ScorePair]]:
    """Each program's score pairs on the market's fresh pairs. A planted market is on disk only while scored; the
    twins, which do not depend on the strength, are kept under `twins`."""
    per_program: list[list[ScorePair]] = [[] for _ in programs]
    root = work / "fresh"
    for fresh in pairs.fresh_ids(market_id):
        planted = pairs.write_market(root, fresh, strength, "planted")
        try:
            at_strength = evaluate(programs, planted)
        finally:
            shutil.rmtree(root)
        at_zero = at_strength if strength == 0.0 else twin_scores(programs, fresh, twins)
        for mine, planted_score, twin_score in zip(per_program, at_strength, at_zero):
            mine.append((planted_score, twin_score))
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


def judge(
    programs: Sequence[dict[str, Any]], strength: float, market_id: str, work: Path, twins: Path
) -> list[dict[str, Any]]:
    """Each program classified against the reference on the market's fresh pairs: its hash, the inputs it reads,
    the pairs it wins, the median effects of the reference and of the program, and whether it earns."""
    reference, *rest = fresh_scores(strength, market_id, [load_program("reference"), *programs], work, twins)
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
