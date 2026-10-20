"""Direct calibration of the holdout test's size (PROGRESS.md, Stage 2, revisions of 2026-10-20).

Suites of zero-mean series at holdout lengths: `development` (and `development-v2`, its sparser additions after the
locked v1 failure), measuring the bootstrap p-value (its results are the committed calibration table,
gate/holdout_calibration.json), and `locked`, whose
generators played no part in designing the test, judging the calibrated holdout p-value once. Each cell (generator x
length) is resumable: finished cells are kept in a work file.
"""

import hashlib
import json
import multiprocessing
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
from scipy import stats

from gate.gate import CALIBRATION, bootstrap_pvalue, campaign_seed, floor, holdout_pvalue

LENGTHS = (540, 546, 1080)
BURN = 500
JUDGED = (0.05, 0.01, 0.005)
REPORTED = (0.001, 0.0005)


def _t(rng, nu, shape):
    return rng.standard_t(nu, shape) / np.sqrt(nu / (nu - 2))


def _garch(rng, m, n, a, b, nu):
    z = _t(rng, nu, (m, n + BURN))
    out, var = np.empty_like(z), np.ones(m)
    for t in range(n + BURN):
        out[:, t] = np.sqrt(var) * z[:, t]
        var = (1 - a - b) + a * out[:, t] ** 2 + b * var
    return out[:, BURN:]


def _garch_exposed(rng, m, n, a, b, nu, threshold):
    """A GARCH-t series, exposed (nonzero) exactly while its conditional variance exceeds `threshold`."""
    z = _t(rng, nu, (m, n + BURN))
    out, var = np.empty_like(z), np.ones(m)
    for t in range(n + BURN):
        out[:, t] = np.sqrt(var) * z[:, t] * (var > threshold)
        var = (1 - a - b) + a * (np.sqrt(var) * z[:, t]) ** 2 + b * var
    return out[:, BURN:]


def _ar1(rng, m, n, phi):
    e = rng.standard_normal((m, n + BURN))
    for t in range(1, n + BURN):
        e[:, t] += phi * e[:, t - 1]
    return e[:, BURN:]


def _active(rng, m, n, to_active, to_flat):
    """A stationary two-state chain: True while active."""
    on = rng.random(m) < to_active / (to_active + to_flat)
    out = np.empty((m, n), bool)
    for t in range(n):
        out[:, t] = on
        on = np.where(on, rng.random(m) >= to_flat, rng.random(m) < to_active)
    return out


def _sd_step(n, start, factor):
    return np.where(np.arange(n) < start, 1.0, factor)


SUITES = {
    "development": {
        "id": "holdout-calibration-v1", "series": 4000, "pvalue": "bootstrap_pvalue",
        "generators": {
            "gaussian": lambda rng, m, n: rng.standard_normal((m, n)),
            "t3": lambda rng, m, n: _t(rng, 3, (m, n)),
            "garch_t5": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5),
            "vol_triple_half": lambda rng, m, n: rng.standard_normal((m, n)) * _sd_step(n, n // 2, 3.0),
            "ar1_02": lambda rng, m, n: _ar1(rng, m, n, 0.2),
            "zero_inflated": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5) * _active(rng, m, n, 1 / 12, 1 / 4),
        },
    },
    "development-v2": {
        "id": "holdout-calibration-v2", "series": 4000, "pvalue": "bootstrap_pvalue",
        "generators": {
            "sparse10": lambda rng, m, n: _t(rng, 5, (m, n)) * _active(rng, m, n, 1 / 36, 1 / 4),
            "sparse5": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5) * _active(rng, m, n, 1 / 76, 1 / 4),
            "sparse5_long": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5) * _active(rng, m, n, 1 / 228, 1 / 12),
        },
    },
    "locked": {
        "id": "holdout-calibration-locked-v1", "series": 20000, "pvalue": "holdout_pvalue",
        "generators": {
            "ar1_03": lambda rng, m, n: _ar1(rng, m, n, 0.3),
            "t4": lambda rng, m, n: _t(rng, 4, (m, n)),
            "garch_persistent_t4": lambda rng, m, n: _garch(rng, m, n, 0.05, 0.93, 4),
            "vol_double_last_third": lambda rng, m, n: rng.standard_normal((m, n)) * _sd_step(n, -(-2 * n // 3), 2.0),
            "sparse": lambda rng, m, n: _t(rng, 5, (m, n)) * _active(rng, m, n, 1 / 36, 1 / 4),
            "jumps": lambda rng, m, n: rng.standard_normal((m, n))
            + (rng.random((m, n)) < 0.01) * rng.choice([-10.0, 10.0], (m, n)),
        },
    },
    "locked-v2": {
        "id": "holdout-calibration-locked-v2.1", "series": 20000, "pvalue": "holdout_pvalue",
        "generators": {
            "sparse_long": lambda rng, m, n: _garch(rng, m, n, 0.08, 0.9, 4) * _active(rng, m, n, 1 / 160, 1 / 12),
            "very_sparse": lambda rng, m, n: _t(rng, 4, (m, n)) * _active(rng, m, n, 1 / 129, 1 / 4),
            "rare_loss": lambda rng, m, n: 0.1 + rng.standard_normal((m, n)) - 20.0 * (rng.random((m, n)) < 0.005),
            "noisy_sparse": lambda rng, m, n: 0.05 * rng.standard_normal((m, n))
            + _t(rng, 5, (m, n)) * _active(rng, m, n, 1 / 36, 1 / 4),
            "endogenous": lambda rng, m, n: _garch_exposed(rng, m, n, 0.1, 0.85, 5, 1.5),
            "persistent": lambda rng, m, n: _ar1(rng, m, n, 0.8),
        },
    },
}


PVALUES = {"bootstrap_pvalue": bootstrap_pvalue, "holdout_pvalue": holdout_pvalue}


def _pvalues(args):
    kind, tag, rows, start = args
    return [PVALUES[kind](r, campaign_seed(f"{tag}/{start + i}")) for i, r in enumerate(rows)]


def series(suite, gen, n, m=None):
    spec = SUITES[suite]
    tag = f"{spec['id']}/{gen}/{n}"
    rng = np.random.default_rng(int.from_bytes(hashlib.sha256(tag.encode()).digest()[:8], "little"))
    return tag, spec["generators"][gen](rng, m or spec["series"], n)


def cell(suite, gen, n, m=None, workers=None, chunk=50):
    """A cell's p-values and each series' count of nonzero steps."""
    tag, xs = series(suite, gen, n, m)
    jobs = [(SUITES[suite]["pvalue"], tag, xs[i:i + chunk], i) for i in range(0, len(xs), chunk)]
    with ProcessPoolExecutor(workers, mp_context=multiprocessing.get_context("spawn")) as pool:
        p = np.concatenate([p for p in pool.map(_pvalues, jobs)])
    return {"p": p.tolist(), "active": np.count_nonzero(xs, axis=1).tolist()}


def cp_upper(k, m, confidence):
    return 1.0 if k >= m else float(stats.beta.ppf(confidence, k + 1, m - k))


def report(pvalues):
    """Per cell and level: rejection count and rate, and at the judged levels the one-sided
    Clopper-Pearson upper bound at confidence 1 - 0.05/K over the K judged (cell, level) pairs."""
    k = len(pvalues) * len(JUDGED)
    confidence = 1 - 0.05 / k
    cells = {}
    for c, w in pvalues.items():
        p, active = np.asarray(w["p"]), np.asarray(w["active"])
        n = int(c.rsplit("/", 1)[1])
        eligible = active >= floor(n)
        out = {}
        for u in JUDGED + REPORTED:
            count = int((p <= u).sum())
            out[str(u)] = {"rejections": count, "rate": count / len(p),
                           "eligible_rate": float((p[eligible] <= u).mean()) if eligible.any() else None}
            if u in JUDGED:
                out[str(u)]["upper"] = cp_upper(count, len(p), confidence)
        cells[c] = {"series": len(p), "levels": out, "floored": float((~eligible).mean()),
                    "mean_active_share": float(active.mean() / n)}
    return {"judged_pairs": k, "confidence": confidence, "cells": cells}


def main(suite, work, audit):
    path = Path(work)
    pvalues = json.loads(path.read_text()) if path.exists() else {}
    for gen in SUITES[suite]["generators"]:
        for n in LENGTHS:
            if f"{gen}/{n}" not in pvalues:
                pvalues[f"{gen}/{n}"] = cell(suite, gen, n)
                path.write_text(json.dumps(pvalues))
                print(gen, n, flush=True)
    Path(audit).write_text(json.dumps({"suite": suite, "id": SUITES[suite]["id"], **report(pvalues)}, indent=1) + "\n")


def table(development, development_v2):
    """The calibration table (gate/holdout_calibration.json): each development cell's bootstrap p-values as integers
    over 10,001, sorted."""
    cells = {}
    for work in (development, development_v2):
        for c, w in json.loads(Path(work).read_text()).items():
            cells[c] = sorted(round(p * 10_001) for p in w["p"])
    CALIBRATION.write_text(json.dumps({"id": "holdout-calibration-v2", "denominator": 10_001,
                                       "cells": dict(sorted(cells.items()))}) + "\n")

