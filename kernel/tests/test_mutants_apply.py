"""Every mutant's edits still apply: each old text occurs exactly once in the current tree."""

import importlib.util
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("mutants", REPO / "kernel/mutants/mutants.py")
mutants = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mutants)


def test_every_mutant_edit_matches_exactly_once():
    stale = [(name, f, old) for name, (_, edits) in mutants.MUTANTS.items() for f, old, _ in edits
             if (REPO / f).read_text().count(old) != 1]
    assert stale == []
