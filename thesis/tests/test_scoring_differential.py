"""C10.4: GPT's independent scorer (gpt_scoring.py, written from thesis/SCORING.md and the stage 10
criteria alone) agrees with ours on 1,000 boundary-dense test sets: exactly on outcomes, exclusions,
counts and clusters, within 1e-12 * max(1, |a|, |b|) on finite scores (C10.4 revision), and on which
scores are undefined; the sets cover every boundary case."""

import random

import pytest

from thesis import scoring
from thesis.tests import gpt_scoring, scoring_gen

TOL = 1e-12


def same(a, b, path="", out=None):
    out = [] if out is None else out
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            out.append((path, sorted(a), sorted(b)))
        for k in set(a) & set(b):
            same(a[k], b[k], f"{path}.{k}", out)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append((path, len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            same(x, y, f"{path}[{i}]", out)
    elif isinstance(a, float) or isinstance(b, float):
        if a is None or b is None or abs(a - b) > TOL * max(1.0, abs(a), abs(b)):
            out.append((path, a, b))
    elif a != b or type(a) is not type(b):
        out.append((path, a, b))
    return out


REQUIRED = {"zero_return", "no_base_rate", "base_rate", "b_ref_zero", "chain", "unresolved_cluster", "null_close",
            "no_opening_to_horizon", "missing_funding"}
ENDS, STATES = scoring_gen.boundaries(), scoring_gen.read_states()
PARTS = range(len(ENDS) - 1)


def reached(i, s, ours):
    """The boundary cases set i (`s`, scored as `ours`) exhibits."""
    kind, seen, theses = scoring_gen.KINDS[i % len(scoring_gen.KINDS)], set(), ours["theses"].values()
    seen |= {"zero_return"} if any(t["outcome"] and t["outcome"]["R_net"] == 0 for t in theses) else set()
    seen |= {"no_base_rate"} if any(t["p_ref"] is None and t["outcome"] for t in theses) else set()
    seen |= {"base_rate"} if any(t["p_ref"] is not None and t["outcome"] for t in theses) else set()
    seen |= {"b_ref_zero"} if ours["scores"]["ablation"]["B_ref"] == 0 else set()
    seen |= {"chain"} if any(len(c["members"]) >= 3 for c in ours["clusters"]) else set()
    seen |= {"unresolved_cluster"} if any(not c["resolved"] for c in ours["clusters"]) else set()
    seen |= {"null_close"} if any(r[2] is None for rows in s["hourly"].values() for r in rows) else set()
    if kind in ("no_opening_to_horizon", "missing_funding") and ours["theses"][s["theses"][0]["id"]]["outcome"] is None:
        seen.add(kind)
    return seen


def judge(start, stop, state):
    """(sets judged, disagreements, the stream's state after them) for one part of the stream."""
    rng = random.Random()
    rng.setstate(state)
    disagreements, n = [], 0
    for i, s in enumerate(scoring_gen.walk(rng, start, stop), start):
        n += 1
        ours = scoring.score(s)
        d = same(ours, gpt_scoring.score(s))
        if d:
            disagreements.append((i, scoring_gen.KINDS[i % len(scoring_gen.KINDS)], d[:3]))
        kind = scoring_gen.KINDS[i % len(scoring_gen.KINDS)]
        if kind in ("no_opening_to_horizon", "missing_funding"):
            assert kind in reached(i, s, ours), (i, kind)
    return n, disagreements, rng.getstate()


def set_at(i):
    p = max(k for k in PARTS if ENDS[k] <= i)
    rng = random.Random()
    rng.setstate(STATES[p])
    for s in scoring_gen.walk(rng, ENDS[p], i + 1):
        pass
    return s


def witnesses():
    """{case: the first set that exhibits it}: how WITNESS is made (python -m thesis.tests.test_scoring_differential prints it)."""
    found = {}
    for k in PARTS:
        rng = random.Random()
        rng.setstate(STATES[k])
        for i, s in enumerate(scoring_gen.walk(rng, ENDS[k], ENDS[k + 1]), ENDS[k]):
            for case in reached(i, s, scoring.score(s)):
                found.setdefault(case, i)
    return found


# One set exhibiting each boundary case is the evidence that the 1,000 sets cover it.
WITNESS = {'b_ref_zero': 6, 'base_rate': 11, 'chain': 0, 'missing_funding': 10, 'no_base_rate': 0, 'no_opening_to_horizon': 9,
           'null_close': 8, 'unresolved_cluster': 0, 'zero_return': 0}


@pytest.mark.parametrize("i", PARTS)
def test_independent_scorer_agrees_on_each_part_of_the_1000_sets(i):
    n, disagreements, state = judge(ENDS[i], ENDS[i + 1], STATES[i])
    assert state == STATES[i + 1], "stale states: python -m thesis.tests.scoring_gen"
    assert n == ENDS[i + 1] - ENDS[i]
    assert disagreements == []


def test_the_parts_are_the_1000_sets():
    assert STATES[0] == random.Random(scoring_gen.SEED).getstate()
    assert ENDS[0] == 0 and ENDS[-1] == 1000 and all(a < b for a, b in zip(ENDS, ENDS[1:]))


@pytest.mark.parametrize("case", sorted(REQUIRED))
def test_the_sets_cover_every_boundary_case(case):
    assert case in WITNESS, "python -m thesis.tests.test_scoring_differential finds each case's witness"
    i = WITNESS[case]
    s = set_at(i)
    assert 0 <= i < 1000 and case in reached(i, s, scoring.score(s))


if __name__ == "__main__":
    print("WITNESS =", dict(sorted(witnesses().items())))
