"""Direct calibration of the holdout test's size (PROGRESS.md, Stage 2, revision 2026-10-20).

The test runs on zero-mean series of holdout length from generators the test's assumptions do and
do not cover; at each level u, the rate of p <= u must not exceed u by more than sampling error.
"""

import hashlib
import json
import multiprocessing
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

from gate.gate import holdout_pvalue, seed_of

CALIBRATION_ID = "holdout-calibration-v1"
LENGTHS = (540, 1080)
SERIES = 4000
LEVELS = (0.05, 0.01)
REPORTED = (0.005,)
TOLERANCE_SE = 3
BURN = 500


def _garch_t5(rng, m, n, a=0.1, b=0.85):
    z = rng.standard_t(5, (m, n + BURN)) * np.sqrt(3 / 5)
    out, var = np.empty_like(z), np.ones(m)
    for t in range(n + BURN):
        out[:, t] = np.sqrt(var) * z[:, t]
        var = (1 - a - b) + a * out[:, t] ** 2 + b * var
    return out[:, BURN:]


def _ar1(rng, m, n, phi=0.2):
    e = rng.standard_normal((m, n + BURN))
    for t in range(1, n + BURN):
        e[:, t] += phi * e[:, t - 1]
    return e[:, BURN:]


def _active(rng, m, n, flat_mean=12, active_mean=4):
    """Alternating flat and active runs, geometric with the given means, from the stationary state."""
    on = rng.random(m) < active_mean / (flat_mean + active_mean)
    out = np.empty((m, n), bool)
    for t in range(n):
        out[:, t] = on
        on = np.where(on, rng.random(m) >= 1 / active_mean, rng.random(m) < 1 / flat_mean)
    return out


GENERATORS = {
    "gaussian": lambda rng, m, n: rng.standard_normal((m, n)),
    "student_t3": lambda rng, m, n: rng.standard_t(3, (m, n)),
    "garch_t5": _garch_t5,
    "vol_break": lambda rng, m, n: rng.standard_normal((m, n)) * np.where(np.arange(n) < n // 2, 1.0, 3.0),
    "ar1": _ar1,
    "zero_inflated": lambda rng, m, n: _garch_t5(rng, m, n) * _active(rng, m, n),
}


def _cell_seed(gen, n):
    return int.from_bytes(hashlib.sha256(f"{CALIBRATION_ID}/{gen}/{n}".encode()).digest()[:8], "little")


def _pvalues(args):
    gen, n, rows, start = args
    return [holdout_pvalue(r, seed_of(f"{CALIBRATION_ID}/{gen}/{n}/{start + i}")) for i, r in enumerate(rows)]


def cell(gen, n, m=SERIES, workers=None, chunk=50):
    series = GENERATORS[gen](np.random.default_rng(_cell_seed(gen, n)), m, n)
    jobs = [(gen, n, series[i:i + chunk], i) for i in range(0, m, chunk)]
    with ProcessPoolExecutor(workers, mp_context=multiprocessing.get_context("spawn")) as pool:
        return np.concatenate([p for p in pool.map(_pvalues, jobs)])


def limit(u, m=SERIES):
    return u + TOLERANCE_SE * np.sqrt(u * (1 - u) / m)


def report(pvalues):
    """{cell: {u: rate}} plus whether every cell is within its limit at every judged level."""
    rates = {c: {str(u): float((np.asarray(p) <= u).mean()) for u in LEVELS + REPORTED} for c, p in pvalues.items()}
    ok = all(r[str(u)] <= limit(u, len(pvalues[c])) for c, r in rates.items() for u in LEVELS)
    return {"calibration_id": CALIBRATION_ID, "series": {c: len(p) for c, p in pvalues.items()},
            "limits": {str(u): limit(u) for u in LEVELS}, "rates": rates, "passed": ok}


def main(work, audit):
    """Resumable: finished cells are kept in `work`; the report goes to `audit`."""
    path = Path(work)
    pvalues = json.loads(path.read_text()) if path.exists() else {}
    for gen in GENERATORS:
        for n in LENGTHS:
            if f"{gen}/{n}" not in pvalues:
                pvalues[f"{gen}/{n}"] = cell(gen, n).tolist()
                path.write_text(json.dumps(pvalues))
    Path(audit).write_text(json.dumps(report(pvalues), indent=1) + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:])
