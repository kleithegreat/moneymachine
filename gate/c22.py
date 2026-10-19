"""C2.2: GPT's independent N2/N3 generators pass C2.1's regression test and agree with ours on
100 simulated years within the pre-registered tolerances."""

import json
import sys
from pathlib import Path

import numpy as np
import statsmodels.api as sm

from gate import gpt_nulls, markets, probes

YEARS, MARKET_DAYS = 100, 3650
TOL = {"mean_abs_eps": ("rel", 0.05), "kurtosis": ("rel", 0.20), "acf1_abs_eps": ("abs", 0.05),
       "cross_corr": ("abs", 0.05), "funding_ar": ("abs", 0.05)}


def stats(arrays):
    e = np.concatenate([a["eps"] for a in arrays])
    f = np.concatenate([a["funding"] for a in arrays])
    z = (e - e.mean(0)) / e.std(0)
    c = np.corrcoef(e.T)
    a = np.abs(e)
    return {"mean_abs_eps": float(a.mean()), "kurtosis": float((z**4).mean()),
            "acf1_abs_eps": float(np.mean([np.corrcoef(a[:-1, i], a[1:, i])[0, 1] for i in range(e.shape[1])])),
            "cross_corr": float(c[np.triu_indices_from(c, 1)].mean()),
            "funding_ar": float(np.mean([np.polyfit(f[:-1, i], f[1:, i], 1)[0] for i in range(f.shape[1])]))}


def regression_min_p(arrays):
    rows = None
    for a in arrays:
        obs = probes.observables(a)
        rows = obs if rows is None else [(np.vstack([X0, X]), np.r_[y0, y]) for (X0, y0), (X, y) in zip(rows, obs)]
    out = []
    for X, y in rows:
        X = X[:, X.std(axis=0) > 0]
        out.append(float(sm.OLS(y, sm.add_constant(X)).fit(cov_type="HC3").f_pvalue))
    return min(out)


def main(out):
    params = json.loads(Path("gate/nulls.json").read_text())
    report = {}
    for model in ("N2", "N3"):
        p = params[model]
        F, P, cols = markets.funding_source(p["funding"])
        short = [i for i, c in enumerate(cols) if c is None]
        n = YEARS * 365 // MARKET_DAYS
        ours = [markets.generate(model, p, f"c22-ours-{model}-{i}", MARKET_DAYS) for i in range(n)]
        theirs = [gpt_nulls.generate(model, p, F, P, short, 1000 + i, MARKET_DAYS) for i in range(n)]
        so, st = stats(ours), stats(theirs)
        ok = {k: (abs(st[k] - so[k]) <= (t * abs(so[k]) if kind == "rel" else t)) for k, (kind, t) in TOL.items()}
        report[model] = {"ours": so, "gpt": st, "within_tolerance": ok, "gpt_regression_min_p": regression_min_p(theirs)}
        print(model, json.dumps(report[model]), flush=True)
    report["pass"] = all(all(r["within_tolerance"].values()) and r["gpt_regression_min_p"] > probes.P_MIN
                         for r in (report["N2"], report["N3"]))
    Path(out).write_text(json.dumps(report, indent=1))
    print("pass", report["pass"])


if __name__ == "__main__":
    main(sys.argv[1])
