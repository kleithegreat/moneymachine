"""Our N2/N3 generators against GPT's independent ones (gpt_nulls.py) on 100 simulated years: the
statistics both must agree on, and the regression p-value of GPT's markets."""

import json
from pathlib import Path

import numpy as np

from gate import markets, probes
from gate.tests import gpt_nulls

YEARS, MARKET_DAYS = 100, 3650


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


def run(out):
    params = json.loads(Path("gate/nulls.json").read_text())
    report = {}
    for model in ("N2", "N3"):
        p = params[model]
        F, P, cols = markets.funding_source(p["funding"])
        short = [i for i, c in enumerate(cols) if c is None]
        n = YEARS * 365 // MARKET_DAYS
        ours = [markets.generate(model, p, f"c22-ours-{model}-{i}", MARKET_DAYS) for i in range(n)]
        theirs = [gpt_nulls.generate(model, p, F, P, short, 1000 + i, MARKET_DAYS) for i in range(n)]
        report[model] = {"ours": stats(ours), "gpt": stats(theirs), "gpt_regression_min_p": min(probes.pooled_pvalues(theirs))}
    Path(out).write_text(json.dumps(report, indent=1))
