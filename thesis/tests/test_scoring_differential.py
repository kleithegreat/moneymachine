"""C10.4: GPT's independent scorer (gpt_scoring.py, written from thesis/SCORING.md and the stage 10
criteria alone) agrees with ours on 1,000 boundary-dense test sets: exactly on outcomes, exclusions,
counts and clusters, within 1e-12 * max(1, |a|, |b|) on finite scores (C10.4 revision), and on which
scores are undefined; the sets cover every boundary case."""

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


def test_independent_scorer_agrees_on_1000_sets_covering_every_boundary_case():
    disagreements, seen = [], set()
    for i, s in enumerate(scoring_gen.generate(1000)):
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
    assert disagreements == []
    assert seen == {"zero_return", "no_base_rate", "base_rate", "b_ref_zero", "chain", "unresolved_cluster", "null_close",
                    "no_opening_to_horizon", "missing_funding"}
