"""Thesis scoring (thesis/SCORING.md): as-registered outcomes, the per-exposure base rate, Brier scores
and skill against the base rate and the paired ablation, clusters, and the cluster bootstrap."""

import numpy as np

from ingest.policy import DAY, HOUR
from thesis.positions import Bars, fill, outcome

WINDOW_YEARS_DAYS = 1095
MIN_WINDOWS = 10
REPLICATES = 10_000
SEED = 10


def bars(rows):
    return Bars((t, (o, c)) for t, o, c in rows)


def window_return(th, daily, funding, entry, exit_):
    """Net return per N of the fixed-quantity position between two daily opens, or None if incomplete."""
    total = 0.0
    for market, w in th["legs"]:
        d, rates = daily.get(market, Bars()), funding.get(market, {})
        if entry not in d or exit_ not in d:
            return None
        q = w * th["N"] / d[entry][0]
        for k, ref in ((q, d[entry][0]), (-q, d[exit_][0])):
            price, fee, _ = fill(ref, k, th["costs"][market], th["fee"])
            total += -k * price - fee
        for h in range(entry + HOUR, exit_ + 1, HOUR):
            day = h // DAY * DAY
            if h not in rates or day not in d:
                return None
            total -= q * rates[h] * d[day][0]
    return total / th["N"]


def base_rate(th, daily, funding):
    """(p_ref, m, x): smoothed share of positive non-overlapping historical windows of the holding duration."""
    days = int(np.floor((th["T"] - th["t_r"]) / DAY + 0.5))
    common = set.intersection(*(set(t for t in daily.get(m, {}) if t <= th["t_r"]) for m, _ in th["legs"]))
    if not common or days < 1:
        return None, 0, 0
    a = max(common)
    m = x = 0
    k = 0
    while a - (k + 1) * days * DAY >= th["t_r"] - WINDOW_YEARS_DAYS * DAY:
        r = window_return(th, daily, funding, a - (k + 1) * days * DAY, a - k * days * DAY)
        if r is not None:
            m += 1
            x += r > 0
        k += 1
    return ((x + 1) / (m + 2) if m >= MIN_WINDOWS else None), m, x


def brier(pairs):
    return float(np.mean([(p - o) ** 2 for p, o in pairs])) if pairs else None


def paired(rows, key):
    pairs = [(r["p"], r[key], r["o"]) for r in rows if r[key] is not None]
    b, b_ref = brier([(p, o) for p, _, o in pairs]), brier([(q, o) for _, q, o in pairs])
    return {"n_pairs": len(pairs), "B": b, "B_ref": b_ref, "diff": None if b is None else b - b_ref,
            "skill": None if not pairs or b_ref == 0 else 1 - b / b_ref}


def scores(rows):
    """rows: resolved theses with p, o, p_ref and p_ablation."""
    return {"n_resolved": len(rows), "B": brier([(r["p"], r["o"]) for r in rows]),
            "base_rate": paired(rows, "p_ref"), "ablation": paired(rows, "p_ablation")}


def clusters(theses, resolved):
    """Connected components: same session, same catalyst id, or a shared market with intersecting [t_r, T]."""
    parent = list(range(len(theses)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i, a in enumerate(theses):
        for j in range(i):
            b = theses[j]
            shared = {m for m, _ in a["legs"]} & {m for m, _ in b["legs"]}
            if (a["session"] == b["session"] or a["catalyst_id"] == b["catalyst_id"]
                    or (shared and a["t_r"] <= b["T"] and b["t_r"] <= a["T"])):
                parent[root(i)] = root(j)
    groups = {}
    for i, t in enumerate(theses):
        groups.setdefault(root(i), []).append(t["id"])
    return [{"name": m[0], "members": m, "resolved": all(resolved[x] for x in m)}
            for m in sorted(groups.values(), key=lambda m: [t["id"] for t in theses].index(m[0]))]


def score(test):
    """The SCORING.md output for one input set."""
    account, now = test["account"], test["now"]
    data = {"bars": {m: bars(r) for m, r in test["hourly"].items()},
            "funding": {m: dict(rows) for m, rows in test["funding"].items()}}
    daily = {m: bars(r) for m, r in test["daily"].items()}
    per = {}
    for t in test["theses"]:
        th = {**t, "costs": account["costs"], "fee": account["fee"]}
        p_ref, m, x = base_rate(th, daily, data["funding"])
        per[th["id"]] = {"outcome": outcome(th, data, now), "p_ref": p_ref, "m": m, "x": x}
    return summary(test["theses"], per)


def summary(theses, per):
    """Scores and clusters of `theses` (with p and p_ablation) from each one's outcome and p_ref in `per`."""
    rows = [{"p": th["p"], "o": per[th["id"]]["outcome"]["o"], "p_ref": per[th["id"]]["p_ref"], "p_ablation": th["p_ablation"]}
            for th in theses if per[th["id"]]["outcome"] is not None]
    return {"theses": per, "scores": scores(rows),
            "clusters": clusters(theses, {k: v["outcome"] is not None for k, v in per.items()})}


def bootstrap(test, result):
    """Percentile 95% intervals of B, and of each comparison's diff and skill, over resolved clusters."""
    by_id = {t["id"]: t for t in test["theses"]}
    resolved = [c["members"] for c in result["clusters"] if c["resolved"]]
    if len(resolved) < 2:
        return None
    rng = np.random.default_rng(SEED)
    stats, undefined = [], 0
    for _ in range(REPLICATES):
        rows = []
        for k in rng.integers(0, len(resolved), len(resolved)):
            for tid in resolved[k]:
                r = result["theses"][tid]
                rows.append({"p": by_id[tid]["p"], "o": r["outcome"]["o"], "p_ref": r["p_ref"],
                             "p_ablation": by_id[tid]["p_ablation"]})
        s = scores(rows)
        stats.append(s)
        undefined += any(s[k]["skill"] is None for k in ("base_rate", "ablation"))
    interval = lambda xs: [float(np.percentile(xs, 2.5)), float(np.percentile(xs, 97.5))] if xs else None
    out = {"B": interval([s["B"] for s in stats]), "replicates_with_undefined_skill": undefined}
    for k in ("base_rate", "ablation"):
        out[k] = {f: interval([s[k][f] for s in stats if s[k][f] is not None]) for f in ("diff", "skill")}
    return out
