"""C10.4: GPT's independent scorer (gpt_scoring.py, written from thesis/SCORING.md and the stage 10
criteria alone) agrees with ours on 1,000 boundary-dense test sets: exactly on outcomes, exclusions,
counts and clusters, within 1e-12 * max(1, |a|, |b|) on finite scores (C10.4 revision), and on which
scores are undefined."""

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


def test_independent_scorer_agrees_on_1000_sets():
    sets = scoring_gen.generate(1000)
    disagreements = []
    for i, s in enumerate(sets):
        d = same(scoring.score(s), gpt_scoring.score(s))
        if d:
            disagreements.append((i, scoring_gen.KINDS[i % len(scoring_gen.KINDS)], d[:3]))
    assert disagreements == []


def test_the_sets_cover_every_boundary_case():
    sets = scoring_gen.generate(1000)
    results = [scoring.score(s) for s in sets]
    assert any(r["theses"][t]["outcome"] and r["theses"][t]["outcome"]["R_net"] == 0 for r in results for t in r["theses"])
    assert any(r["theses"][t]["p_ref"] is None and r["theses"][t]["outcome"] for r in results for t in r["theses"])
    assert any(r["scores"]["ablation"]["B_ref"] == 0 for r in results)
    assert any(len(c["members"]) >= 3 for r in results for c in r["clusters"])
    assert any(not c["resolved"] for r in results for c in r["clusters"])
