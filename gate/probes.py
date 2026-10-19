"""C2.1: the null markets have no edge. A joint regression of each coin's next-bar epsilon on what is
observable at the bar's open, and DSL probes whose gross PnL must be indistinguishable from zero."""

import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import statsmodels.api as sm

from gate import markets
from gate.search import const, op

YEARS_PER_MARKET = 10
MARKETS = 20
Z_MAX = 3.7
P_MIN = 0.001


def observables(a, k0=7):
    """Per coin: X (bars k0.., features known at each bar's open) and y = epsilon of that bar. Forum
    counts, where the coin has them, enter as the last 4 hours' sum and the mean over up to 48 hours."""
    o, c, h, l, v, f, p, e = (a[x] for x in ("open", "close", "high", "low", "volume", "funding", "premium", "eps"))
    ev = a.get("forum_posts")
    n, coins = o.shape
    ret = c / o - 1
    k = np.arange(k0, n)
    out = []
    for i in range(coins):
        cols = [f[4 * k - 1, i], p[4 * k - 1, i]] + [ret[k - j, i] for j in range(1, 7)] + [
            (h[k - 1, i] - l[k - 1, i]) / c[k - 1, i], np.log(v[k - 1, i]), ret[k - 1].mean(axis=1)]
        if ev is not None and not np.isnan(ev[:, i]).any():
            cum = np.r_[0.0, np.cumsum(ev[:, i])]
            first = np.maximum(4 * k - 47, 0)
            cols += [cum[4 * k + 1] - cum[4 * k - 3], (cum[4 * k + 1] - cum[first]) / (4 * k + 1 - first)]
        out.append((np.column_stack(cols), e[k, i]))
    return out


def regression_pvalues(model, params, events=None):
    rows = None
    for m in range(MARKETS):
        a = markets.generate(model, params, f"probe-reg-{model}-{m}", YEARS_PER_MARKET * 365, events=events)
        obs = observables(a)
        rows = obs if rows is None else [(np.vstack([X0, X]), np.r_[y0, y]) for (X0, y0), (X, y) in zip(rows, obs)]
    pvalues = []
    for X, y in rows:
        X = X[:, X.std(axis=0) > 0]
        pvalues.append(float(sm.OLS(y, sm.add_constant(X)).fit(cov_type="HC3").f_pvalue) if X.shape[1] else 1.0)
    return pvalues


def program(name, weight):
    return {"dsl": 1, "name": name, "mechanism": {"counterparty": "probe", "predictions": [], "capacity": "-"}, "weight": weight}


def ret(x, h):
    return op("sub", op("div", {"input": x}, op("lag", {"input": x}, hours=h)), const(1))


def sign_probe(name, feature, size=0.05):
    return program(name, op("mul", op("sign", feature), const(size)))


def probes(events=False):
    ps = [program("buy-and-hold", const(0.08))]
    if events:
        e, mean = {"input": "forum_posts"}, op("mean", {"input": "forum_posts"}, hours=48)
        ps.append(sign_probe("sign-forum-activity", op("div", op("sub", e, mean), op("add", mean, const(1.0, "ev")))))
        ps.append(sign_probe("sign-forum-burst", op("sub", e, const(1.0, "ev"))))
    for x in ("open", "high", "low", "close"):
        ps.append(sign_probe(f"sign-{x}-return", ret(x, 4)))
    ps.append(sign_probe("sign-funding", op("div", {"input": "funding"}, const(1e-4, "1/h"))))
    ps.append(sign_probe("sign-premium", {"input": "premium"}))
    ps.append(sign_probe("sign-volume", op("sub", op("div", {"input": "volume"}, op("mean", {"input": "volume"}, hours=48)), const(1))))
    ps.append(sign_probe("sign-range", op("sub", op("div", op("sub", {"input": "high"}, {"input": "low"}), {"input": "close"}),
                                          op("mean", op("div", op("sub", {"input": "high"}, {"input": "low"}), {"input": "close"}), hours=48))))
    ps.append(sign_probe("xs-demean-return", op("xs_demean", ret("close", 24))))
    ps.append(sign_probe("xs-rank-return", op("sub", op("xs_rank", ret("close", 24)), const(0.5))))
    ps.append(sign_probe("xs-mean-return", op("xs_mean", ret("close", 4))))
    drawdown = op("max", op("neg", ret("close", 96)), const(0.0))
    ps.append(program("martingale-sizing", op("clip", op("mul", op("add", const(1.0), op("mul", drawdown, const(20.0))), const(0.05)),
                                              const(0.0), const(0.15))))
    return ps


def gross_pnl(mm, programs, model, params, market_id, cost_cells, events=None):
    """Mean per-step gross return (after funding, before fees and slippage) of each program on one
    fresh market. Per-step returns have zero conditional mean under a null; dollar PnL of a
    compounding strategy is too skewed across markets for a z-test."""
    with tempfile.TemporaryDirectory() as tmp:
        root = markets.write(Path(tmp) / "m", markets.generate(model, params, market_id, YEARS_PER_MARKET * 365, events=events), 0,
                             cost_cells)
        batch = Path(tmp) / "p.jsonl"
        batch.write_text("".join(json.dumps(p) + "\n" for p in programs))
        out = subprocess.run([str(mm), "eval", str(batch), "--campaign", market_id, "--agent", "probe",
                              "--store", str(root / "store"), "--venue", str(root / "venue"),
                              "--ledger", str(Path(tmp) / "l.sqlite")],
                             capture_output=True, text=True)
        results = []
        for line in out.stdout.splitlines():
            r = json.loads(line)["disclosure"]["result"]
            results.append(r["gross_return_mean"])
        if len(results) != len(programs):
            raise RuntimeError(out.stdout + out.stderr)
        return results


def probe_zscores(mm, programs, model, params, cost_cells, tag="", events=None):
    g = np.array([gross_pnl(mm, programs, model, params, f"probe{tag}-{model}-{m}", cost_cells, events) for m in range(MARKETS)])
    mean, se = g.mean(axis=0), g.std(axis=0, ddof=1) / np.sqrt(MARKETS)
    z = np.divide(mean, se, out=np.zeros_like(mean), where=se > 0)
    if np.any((se == 0) & (mean != 0)):
        raise ValueError("a probe has constant nonzero gross return across markets")
    return {p["name"]: float(x) for p, x in zip(programs, z)}
