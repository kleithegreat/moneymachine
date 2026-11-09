"""Every mutant's edits still apply: each old text occurs exactly once in the current tree."""

from pathlib import Path

from kernel.mutants import mutants

REPO = Path(__file__).resolve().parents[2]


def test_every_mutant_edit_matches_exactly_once() -> None:
    stale = [
        (name, f, old)
        for name, (_, edits) in mutants.MUTANTS.items()
        for f, old, _ in edits
        if (REPO / f).read_text().count(old) != 1
    ]
    assert stale == []
