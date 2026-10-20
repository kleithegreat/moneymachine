"""Thesis scoring (thesis/SCORING.md): as-registered outcomes, the per-exposure base rate, Brier scores
and skill against the base rate and the paired ablation, clusters, and the cluster bootstrap."""

import numpy as np

from ingest.policy import DAY
from thesis.positions import outcome

WINDOW_YEARS_DAYS = 1095
MIN_WINDOWS = 10
REPLICATES = 10_000
SEED = 10


def bars(rows):
    return {t: (o, c) for t, o, c in rows}


def window_return(th, account, daily, funding, entry, exit_):
    """Net return per N of the fixed-quantity position between two daily opens, or None if incomplete."""
    total = 0.0
    for market, w in th["legs"]:
        d = daily.get(market, {})
        if entry not in d or exit_ not in d:
            return None
        cells = account["costs"][market]
        q = w * th["N"] / d[entry][0]
        for k, ref in ((q, d[entry][0]), (-q, d[exit_][0])):
            side = "buy" if k > 0 else "sell"
            bps = cells[side]["1000" if abs(k) * ref <= 1000 else "10000"]
            price = ref * (1 + (bps if k > 0 else -bps) / 1e4)
            total += -k * price - abs(k) * price * account["fee"]
        for h, rate in funding.get(market, {}).items():
            if entry < h <= exit_:
                day = h // DAY * DAY
                if day not in d:
                    return None
                total -= q * rate * d[day][0]
    return total / th["N"]


def base_rate(th, account, daily, funding):
    """(p_ref, m, x): smoothed share of positive non-overlapping historical windows of the holding duration."""
    days = int(np.floor((th["T"] - th["t_r"]) / DAY + 0.5))
    common = set.intersection(*(set(t for t in daily.get(m, {}) if t <= th["t_r"]) for m, _ in th["legs"]))
    if not common or days < 1:
        return None, 0, 0
    a = max(common)
    m = x = 0
    k = 0
    while a - (k + 1) * days * DAY >= th["t_r"] - WINDOW_YEARS_DAYS * DAY:
        r = window_return(th, account, daily, funding, a - (k + 1) * days * DAY, a - k * days * DAY)
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
            "funding": {m: dict((h, r) for h, r in rows) for m, rows in test["funding"].items()}}
    daily = {m: bars(r) for m, r in test["daily"].items()}
    per, rows = {}, []
    for th in test["theses"]:
        out = outcome(th, th["N"], account, data, now)
        p_ref, m, x = base_rate(th, account, daily, data["funding"])
        per[th["id"]] = {"outcome": out, "p_ref": p_ref, "m": m, "x": x}
        if out is not None:
            rows.append({"p": th["p"], "o": out["o"], "p_ref": p_ref, "p_ablation": th["p_ablation"]})
    return {"theses": per, "scores": scores(rows),
            "clusters": clusters(test["theses"], {k: v["outcome"] is not None for k, v in per.items()})}


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
