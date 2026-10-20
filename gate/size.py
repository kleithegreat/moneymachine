"""Direct calibration of the holdout test's size (PROGRESS.md, Stage 2, revision of 2026-10-20).

Two suites of zero-mean series at holdout lengths: `development`, reported only, and `locked`,
whose generators played no part in designing the test, judged once. Each cell (generator x
length) is resumable: finished cells are kept in a work file.
"""

import hashlib
import json
import multiprocessing
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
from scipy import stats

from gate.gate import holdout_pvalue, seed_of

LENGTHS = (540, 546, 1080)
BURN = 500
LIMITS = {0.05: 0.0625, 0.01: 0.015, 0.005: 0.01}
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
        "id": "holdout-calibration-v1", "series": 4000,
        "generators": {
            "gaussian": lambda rng, m, n: rng.standard_normal((m, n)),
            "t3": lambda rng, m, n: _t(rng, 3, (m, n)),
            "garch_t5": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5),
            "vol_triple_half": lambda rng, m, n: rng.standard_normal((m, n)) * _sd_step(n, n // 2, 3.0),
            "ar1_02": lambda rng, m, n: _ar1(rng, m, n, 0.2),
            "zero_inflated": lambda rng, m, n: _garch(rng, m, n, 0.1, 0.85, 5) * _active(rng, m, n, 1 / 12, 1 / 4),
        },
    },
    "locked": {
        "id": "holdout-calibration-locked-v1", "series": 20000,
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
}


def _pvalues(args):
    tag, rows, start = args
    return [holdout_pvalue(r, seed_of(f"{tag}/{start + i}")) for i, r in enumerate(rows)]


def cell(suite, gen, n, m=None, workers=None, chunk=50):
    spec = SUITES[suite]
    m = m or spec["series"]
    tag = f"{spec['id']}/{gen}/{n}"
    rng = np.random.default_rng(int.from_bytes(hashlib.sha256(tag.encode()).digest()[:8], "little"))
    series = spec["generators"][gen](rng, m, n)
    jobs = [(tag, series[i:i + chunk], i) for i in range(0, m, chunk)]
    with ProcessPoolExecutor(workers, mp_context=multiprocessing.get_context("spawn")) as pool:
        return np.concatenate([p for p in pool.map(_pvalues, jobs)])


def cp_upper(k, m, confidence):
    return 1.0 if k >= m else float(stats.beta.ppf(confidence, k + 1, m - k))


def report(pvalues):
    """Per cell and level: rejection count and the one-sided Clopper-Pearson upper bound at
    confidence 1 - 0.05/K over the K judged (cell, level) pairs; passed iff every bound is within LIMITS."""
    k = len(pvalues) * len(LIMITS)
    confidence = 1 - 0.05 / k
    cells, ok = {}, True
    for c, p in pvalues.items():
        p = np.asarray(p)
        out = {}
        for u in list(LIMITS) + list(REPORTED):
            count = int((p <= u).sum())
            out[str(u)] = {"rejections": count, "rate": count / len(p)}
            if u in LIMITS:
                out[str(u)]["upper"] = cp_upper(count, len(p), confidence)
                ok &= out[str(u)]["upper"] <= LIMITS[u]
        cells[c] = {"series": len(p), "levels": out}
    return {"judged_pairs": k, "confidence": confidence, "limits": {str(u): v for u, v in LIMITS.items()},
            "cells": cells, "passed": bool(ok)}


def main(suite, work, audit):
    path = Path(work)
    pvalues = json.loads(path.read_text()) if path.exists() else {}
    for gen in SUITES[suite]["generators"]:
        for n in LENGTHS:
            if f"{gen}/{n}" not in pvalues:
                pvalues[f"{gen}/{n}"] = cell(suite, gen, n).tolist()
                path.write_text(json.dumps(pvalues))
                print(gen, n, flush=True)
    Path(audit).write_text(json.dumps({"suite": suite, "id": SUITES[suite]["id"], **report(pvalues)}, indent=1) + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:])
