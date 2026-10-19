"""C5.5: the derivation (ingest/events.py) and an independent implementation written from
venue/sources/derived.md alone agree exactly on synthetic event streams."""

import importlib.util
from pathlib import Path

import pytest

from ingest import events

HERE = Path(__file__).parent / "derived"


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def ours(c):
    return sorted(map(tuple, events.counts([tuple(o) for o in c["observations"]], c["polls"], c["coin_of"],
                                           c["admitted"], c["start"])))


def test_cases_exercise_the_boundaries():
    cs = load("gen").generate(2000, 55)
    rows = [r for c in cs for r in ours(c)]
    assert sum(c["admitted"] for c in cs) > 800 and len(rows) > 20_000
    assert sum(n > 0 for _, _, n in rows) > 2_000 and sum(n == 0 for _, _, n in rows) > 2_000
    assert any(not ours(c) and c["polls"] for c in cs)


@pytest.mark.skipif(not (HERE / "independent.py").exists(), reason="no independent implementation yet")
def test_independent_implementation_agrees():
    other = load("independent")
    bad = [(i, c) for i, c in enumerate(load("gen").generate(2000, 55))
           if ours(c) != sorted(tuple(r) for r in other.counts(c))]
    assert not bad, f"{len(bad)} of 2000 differ, first: case {bad[0][0]}"
