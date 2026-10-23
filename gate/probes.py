"""Probes of the null markets' lack of edge: a joint regression of each coin's next-bar epsilon on what
is observable at the bar's open, and DSL probes whose mean gross PnL is z-scored across markets."""

import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import statsmodels.api as sm

from gate import markets
from gate.kernel import command
from gate.search import compile_feature, const, op

YEARS_PER_MARKET = 10
MARKETS = 20


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


def pooled_pvalues(arrays):
    """Per coin, the HC3 F-test p-value of epsilon on the observables, pooled over markets."""
    rows = None
    for a in arrays:
        obs = observables(a)
        rows = obs if rows is None else [(np.vstack([X0, X]), np.r_[y0, y]) for (X0, y0), (X, y) in zip(rows, obs)]
    pvalues = []
    for X, y in rows:
        X = X[:, X.std(axis=0) > 0]
        pvalues.append(float(sm.OLS(y, sm.add_constant(X)).fit(cov_type="HC3").f_pvalue) if X.shape[1] else 1.0)
    return pvalues


def regression_pvalues(model, params, events=None):
    return pooled_pvalues(markets.generate(model, params, f"probe-reg-{model}-{m}", YEARS_PER_MARKET * 365, events=events)
                          for m in range(MARKETS))


def program(name, weight):
    return {"dsl": 1, "name": name, "mechanism": {"counterparty": "probe", "predictions": [], "capacity": "-"}, "weight": weight}


def sign_probe(name, feature, size=0.05):
    return program(name, op("mul", op("sign", feature), const(size)))


def probes(events=False):
    ps = [program("buy-and-hold", const(0.08))]
    if events:
        ps.append(sign_probe("sign-forum-activity", compile_feature(6, None, 48)))
        ps.append(sign_probe("sign-forum-burst", op("sub", {"input": "forum_posts"}, const(1.0, "ev"))))
    for x in ("open", "high", "low", "close"):
        ps.append(sign_probe(f"sign-{x}-return", compile_feature(0, x, 4)))
    ps.append(sign_probe("sign-funding", op("div", {"input": "funding"}, const(1e-4, "1/h"))))
    ps.append(sign_probe("sign-premium", {"input": "premium"}))
    ps.append(sign_probe("sign-volume", op("sub", op("div", {"input": "volume"}, op("mean", {"input": "volume"}, hours=48)), const(1))))
    ps.append(sign_probe("sign-range", op("sub", op("div", op("sub", {"input": "high"}, {"input": "low"}), {"input": "close"}),
                                          op("mean", op("div", op("sub", {"input": "high"}, {"input": "low"}), {"input": "close"}), hours=48))))
    ps.append(sign_probe("xs-demean-return", op("xs_demean", compile_feature(0, "close", 24))))
    ps.append(sign_probe("xs-rank-return", op("sub", op("xs_rank", compile_feature(0, "close", 24)), const(0.5))))
    ps.append(sign_probe("xs-mean-return", op("xs_mean", compile_feature(0, "close", 4))))
    drawdown = op("max", op("neg", compile_feature(0, "close", 96)), const(0.0))
    ps.append(program("martingale-sizing", op("clip", op("mul", op("add", const(1.0), op("mul", drawdown, const(20.0))), const(0.05)),
                                              const(0.0), const(0.15))))
    return ps


def gross_pnl(programs, model, params, market_id, cost_cells, events=None):
    """Mean per-step gross return (after funding, before fees and slippage) of each program on one
    fresh market. Per-step returns have zero conditional mean under a null; dollar PnL of a
    compounding strategy is too skewed across markets for a z-test."""
    with tempfile.TemporaryDirectory() as tmp:
        root = markets.write(Path(tmp) / "m", markets.generate(model, params, market_id, YEARS_PER_MARKET * 365, events=events), 0,
                             cost_cells)
        batch = Path(tmp) / "p.jsonl"
        batch.write_text("".join(json.dumps(p) + "\n" for p in programs))
        out = subprocess.run(command("eval", batch, market_id, "probe", Path(tmp) / "l.sqlite", root),
                             capture_output=True, text=True)
        results = []
        for line in out.stdout.splitlines():
            r = json.loads(line)["disclosure"]["result"]
            results.append(r["gross_return_mean"])
        if len(results) != len(programs):
            raise RuntimeError(out.stdout + out.stderr)
        return results


def probe_zscores(programs, model, params, cost_cells, tag="", events=None):
    g = np.array([gross_pnl(programs, model, params, f"probe{tag}-{model}-{m}", cost_cells, events) for m in range(MARKETS)])
    mean, se = g.mean(axis=0), g.std(axis=0, ddof=1) / np.sqrt(MARKETS)
    z = np.divide(mean, se, out=np.zeros_like(mean), where=se > 0)
    if np.any((se == 0) & (mean != 0)):
        raise ValueError("a probe has constant nonzero gross return across markets")
    return {p["name"]: float(x) for p, x in zip(programs, z)}


def run(out, data_root=None, version=None):
    """The probes on null markets; with a dataset, its real event counts replayed."""
    events = None
    if data_root:
        coins = json.loads((Path(data_root) / "universe.json").read_text())["universe"]
        events = markets.store_events(str(Path(data_root) / "store"), version, tuple(coins))
    measure(out, events=events)


def top5(out):
    """The probes plus the complete-null sweep's first in-sample top-5 strategies."""
    from gate import sweep

    measure(out, sweep.top5_programs())


def measure(out, extra_programs=None, events=None):
    """Regression p-values and probe z-scores per null model on the frozen parameters. With `events`
    (markets.store_events), the markets replay real event counts and event probes join."""
    params = markets.null_params()
    programs = probes(events is not None) + (extra_programs or [])
    result = {}
    for model in ("N1", "N2", "N3"):
        p = params.get(model)
        pv = regression_pvalues(model, p, events)
        z = probe_zscores(programs, model, p, markets.FLAT_COST, tag="-c21", events=events)
        result[model] = {"regression_p": pv, "min_p": min(pv), "z": z, "max_abs_z": max(abs(v) for v in z.values())}
    Path(out).write_text(json.dumps(result, indent=1))
