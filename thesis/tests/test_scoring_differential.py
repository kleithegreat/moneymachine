"""C10.4: GPT's independent scorer (gpt_scoring.py, written from thesis/SCORING.md and the stage 10
criteria alone) agrees with ours on 1,000 boundary-dense test sets: exactly on outcomes, exclusions,
counts and clusters, within 1e-12 * max(1, |a|, |b|) on finite scores (C10.4 revision), and on which
scores are undefined; the sets cover every boundary case."""

import multiprocessing
import random
from concurrent.futures import ProcessPoolExecutor

from gate import compute
from thesis import scoring
from thesis.tests import gpt_scoring, scoring_gen

TOL = 1e-12
WORKER_BYTES = 400_000_000  # a part's peak, 150 MiB measured, with margin


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


def judge(start, stop, state):
    """(sets judged, disagreements, boundary cases seen, the stream's state after them) for one part of the stream."""
    rng = random.Random()
    rng.setstate(state)
    disagreements, seen, n = [], set(), 0
    for i, s in enumerate(scoring_gen.walk(rng, start, stop), start):
        n += 1
        kind, ours = scoring_gen.KINDS[i % len(scoring_gen.KINDS)], scoring.score(s)
        d = same(ours, gpt_scoring.score(s))
        if d:
            disagreements.append((i, kind, d[:3]))
        theses = ours["theses"].values()
        seen |= {"zero_return"} if any(t["outcome"] and t["outcome"]["R_net"] == 0 for t in theses) else set()
        seen |= {"no_base_rate"} if any(t["p_ref"] is None and t["outcome"] for t in theses) else set()
        seen |= {"base_rate"} if any(t["p_ref"] is not None and t["outcome"] for t in theses) else set()
        seen |= {"b_ref_zero"} if ours["scores"]["ablation"]["B_ref"] == 0 else set()
        seen |= {"chain"} if any(len(c["members"]) >= 3 for c in ours["clusters"]) else set()
        seen |= {"unresolved_cluster"} if any(not c["resolved"] for c in ours["clusters"]) else set()
        seen |= {"null_close"} if any(r[2] is None for rows in s["hourly"].values() for r in rows) else set()
        if kind in ("no_opening_to_horizon", "missing_funding"):
            assert ours["theses"][s["theses"][0]["id"]]["outcome"] is None, (i, kind)
            seen.add(kind)
    return n, disagreements, seen, rng.getstate()


def test_independent_scorer_agrees_on_1000_sets_covering_every_boundary_case():
    ends, states = scoring_gen.boundaries(), scoring_gen.read_states()
    assert states[0] == random.Random(scoring_gen.SEED).getstate()
    with ProcessPoolExecutor(compute.workers(WORKER_BYTES), mp_context=multiprocessing.get_context("spawn")) as pool:
        parts = list(pool.map(judge, ends, ends[1:], states))
    assert [p[3] for p in parts] == states[1:], "stale states: python -m thesis.tests.scoring_gen"
    assert sum(p[0] for p in parts) == 1000
    assert [d for p in parts for d in p[1]] == []
    assert set().union(*(p[2] for p in parts)) == {"zero_return", "no_base_rate", "base_rate", "b_ref_zero", "chain", "unresolved_cluster", "null_close",
                                                   "no_opening_to_horizon", "missing_funding"}
