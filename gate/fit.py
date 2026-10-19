"""Fit N2/N3 parameters (gate/NULLS.md) to the search part of the stage 0 store; write gate/nulls.json."""

import hashlib
import json
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from arch import arch_model
from statsmodels.tsa.regime_switching.markov_regression import MarkovRegression

from gate import markets
from ingest.store import HOLDOUT_START, Store

HOUR = 3_600_000
BAR = 4 * HOUR
MIN_BARS = 1000


def frames(data_root, version):
    store = Store(Path(data_root) / "store")
    bars = store.as_of("bars_4h", HOLDOUT_START, version).to_pandas()
    funding = store.as_of("funding", HOLDOUT_START, version).to_pandas()
    return bars, funding


def bar_innovations(bars, funding, coins):
    """r = c/o - 1 - (f1 + f2 + f3) - f4 c/o per coin and bar (the generator's epsilon, inverted)."""
    f = funding.pivot(index="eventTime", columns="coin", values="fundingRate")
    out = {}
    for coin in coins:
        b = bars[(bars.coin == coin) & (bars.trades > 0)].set_index("openTime").sort_index()
        fs = [f[coin].reindex(b.index + i * HOUR).to_numpy() for i in (1, 2, 3, 4)]
        ratio = (b.close / b.open).to_numpy()
        out[coin] = pd.Series(ratio - 1 - fs[0] - fs[1] - fs[2] - fs[3] * ratio, index=b.index).dropna()
    return pd.DataFrame(out)


def fit_garch(r):
    """(alpha, beta) from a GARCH-t fit; omega by variance targeting (NULLS.md)."""
    r = r.dropna()
    res = arch_model(100 * r, mean="Zero", vol="GARCH", p=1, q=1, dist="t").fit(disp="off")
    a, b = res.params["alpha[1]"], res.params["beta[1]"]
    return {"omega": r.var() * (1 - a - b), "alpha": a, "beta": b}, r / (res.conditional_volatility / 100)


def mean_pairwise_corr(df):
    c = df.corr().to_numpy()
    return float(np.nanmean(c[np.triu_indices_from(c, 1)]))


def fit(data_root, version, coins):
    bars, funding = frames(data_root, version)
    r = bar_innovations(bars, funding, coins)
    long_enough = [c for c in coins if r[c].count() >= MIN_BARS]
    garch, z = {}, {}
    for c in long_enough:
        garch[c], z[c] = fit_garch(r[c])
    med = lambda d, k: float(np.median([d[c][k] for c in long_enough]))
    per = lambda d, k: [d[c][k] if c in d else med(d, k) for c in coins]
    lam = float(np.sqrt(max(mean_pairwise_corr(pd.DataFrame(z)), 0.0)))

    mkt = r[long_enough].mean(axis=1).dropna()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        ms = MarkovRegression(mkt.to_numpy(), k_regimes=2, trend="n", switching_variance=True).fit(disp=False)
    named = dict(zip(ms.model.param_names, ms.params))
    variances = np.array([named[f"sigma2[{j}]"] for j in range(2)])
    trans = ms.regime_transition[:, :, 0]
    order = np.argsort(variances)
    m = np.sqrt(variances[order] / mkt.var())
    P = trans[np.ix_(order, order)].T
    smoothed = ms.smoothed_marginal_probabilities[:, order]
    rho = [mean_pairwise_corr(r.loc[mkt.index[smoothed[:, j] > 0.5], long_enough]) for j in range(2)]
    sigma_bar = r.std()
    big = (r.abs() / sigma_bar) > 5
    excess = (r.abs() - 5 * sigma_bar)[big]
    short = [c for c in coins if c not in long_enough]
    fund, prem = markets.store_funding(str(Path(data_root) / "store"), version, tuple(long_enough))
    source = {"store": str(Path(data_root) / "store"), "version": version, "coins": coins, "short": short,
              "block_hours": 168, "sha256": hashlib.sha256(np.ascontiguousarray(np.r_[fund, prem]).tobytes()).hexdigest()}
    params = {
        "coins": coins,
        "fitted_on": {"version": version, "search_end": HOLDOUT_START, "short_history_coins": [c for c in coins if c not in long_enough]},
        "N2": {"garch": {k: per(garch, k) for k in ("omega", "alpha", "beta")}, "lambda": lam,
               "funding": source},
        "N3": {"regime": {"P": P.tolist(), "m": m.tolist(), "rho": [max(x, 0.0) for x in rho],
                          "sigma": [float(sigma_bar[c]) if c in long_enough else float(np.median(sigma_bar[long_enough])) for c in coins],
                          "p_jump": float(big[long_enough].to_numpy().mean()),
                          "k_jump": float(np.nanmean(excess[long_enough].to_numpy()))},
               "funding": source},
    }
    return params


if __name__ == "__main__":
    data_root, version, out = sys.argv[1], int(sys.argv[2]), Path(sys.argv[3])
    coins = list(json.loads((Path(__file__).resolve().parents[1] / "venue/hyperliquid/rules.json").read_text())["coins"])
    text = json.dumps(fit(data_root, version, coins), indent=1, default=float) + "\n"
    out.write_text(text)
    print(hashlib.sha256(text.encode()).hexdigest())
