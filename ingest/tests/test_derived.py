"""C5.5: the derivation (ingest/events.py) and GPT's independent implementation (derived/independent.py,
written from venue/sources/*.md and DSL.md alone, tools denied) agree exactly on synthetic event streams."""

import importlib.util
from pathlib import Path

from ingest import events

HERE = Path(__file__).parent / "derived"


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def ours(c):
    return sorted(map(tuple, events.counts([tuple(o) for o in c["observations"]], c["polls"], c["coin_of"], c["margin"], c["version"])))


def cut(c, t):
    """The case's records at version t."""
    polls = {k: [p for p in ps if p <= t] for k, ps in c["polls"].items()}
    return c | {"observations": [o for o in c["observations"] if o[3] <= t], "polls": {k: ps for k, ps in polls.items() if ps}, "version": t}


def test_rows_never_depend_on_later_records():
    """I1 for the derivation: a row at tau is the same at every version from tau on."""
    rng = __import__("random").Random(8)
    for c in load("gen").generate(2000, 56):
        times = [o[3] for o in c["observations"]] + [p for ps in c["polls"].values() for p in ps]
        if not times:
            continue
        t = rng.choice(times) + rng.choice([0, 1, -1, 3_600_000])
        assert [r for r in ours(c) if r[1] <= t] == ours(cut(c, min(t, c["version"])))


def test_cases_exercise_the_boundaries():
    cs = load("gen").generate(2000, 55)
    rows = [r for c in cs for r in ours(c)]
    assert sum(c["margin"] > 0 for c in cs) > 800 and len(rows) > 4_000
    assert sum(n > 0 for _, _, n in rows) > 1_000 and sum(n == 0 for _, _, n in rows) > 2_000
    assert any(not ours(c) and c["polls"] for c in cs)


def test_independent_implementation_agrees():
    other = load("independent")
    bad = [(i, c) for i, c in enumerate(load("gen").generate(2000, 55))
           if ours(c) != sorted(tuple(r) for r in other.counts(c))]
    assert not bad, f"{len(bad)} of 2000 differ, first: case {bad[0][0]}"
