"""The holdout test's locked calibration v3 (audit/criteria.md, stage 2, revision of 2026-10-21): GPT's suite of
null series (gate/null_suite.py, implemented from the spec alone), each cell (generator x length) of 20,000
series scored once by the betting p-value. Finished cells are kept in a work file, so a run resumes.
"""

import json
from pathlib import Path

import numpy as np

from gate import markets, null_suite
from gate.gate import holdout_pvalues
from gate.sweep import cp_upper

SERIES = 20_000
JUDGED = (0.05, 0.01, 0.005)
REPORTED = (0.001, 0.0005)


def series(gen, n, m=SERIES):
    tag = f"{null_suite.SUITE_ID}/{gen}/{n}"
    rng = np.random.default_rng(markets.seed(tag))
    return null_suite.GENERATORS[gen](rng, m, n)


def report(pvalues):
    """Per cell and level: rejection count and rate, and at the judged levels the one-sided
    Clopper-Pearson upper bound at confidence 1 - 0.05/K over the K judged (cell, level) pairs."""
    k = len(pvalues) * len(JUDGED)
    confidence = 1 - 0.05 / k
    cells = {}
    for c, p in pvalues.items():
        p = np.asarray(p)
        levels = {}
        for u in JUDGED + REPORTED:
            count = int((p <= u).sum())
            levels[str(u)] = {"rejections": count, "rate": count / len(p)}
            if u in JUDGED:
                levels[str(u)]["upper"] = cp_upper(count, len(p), confidence)
        cells[c] = {"series": len(p), "levels": levels, "min_p": float(p.min())}
    return {"judged_pairs": k, "confidence": confidence, "cells": cells}


def main(work, audit):
    path = Path(work)
    pvalues = json.loads(path.read_text()) if path.exists() else {}
    for gen in null_suite.GENERATORS:
        for n in null_suite.LENGTHS:
            if f"{gen}/{n}" not in pvalues:
                pvalues[f"{gen}/{n}"] = holdout_pvalues(series(gen, n)).tolist()
                path.write_text(json.dumps(pvalues))
                print(gen, n, flush=True)
    Path(audit).write_text(json.dumps({"suite": null_suite.SUITE_ID, **report(pvalues)}, indent=1) + "\n")
