"""The statistical gate of paper §6 with the stage 2 parameters (PROGRESS.md, Stage 2, Gate)."""

import hashlib
import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
from arch.bootstrap import SPA, StationaryBootstrap, StepM
from scipy.stats import norm

ALPHA = 0.05
DSR_MIN = 0.95
BLOCK = 6
REPS = 1000
HOLDOUT_REPS = 10_000
EULER = 0.5772156649015329


def dsr(returns, n_trials, sharpe_sd):
    """Deflated Sharpe ratio of one per-period return series (paper §6, Bailey-López de Prado S0)."""
    r = np.asarray(returns, float)
    t = r.size
    sd = r.std(ddof=1)
    if t < 3 or sd == 0:
        return 0.0
    s = r.mean() / sd
    z = (r - r.mean()) / r.std(ddof=0)
    skew, kurt = (z**3).mean(), (z**4).mean()
    s0 = 0.0 if n_trials <= 1 else sharpe_sd * ((1 - EULER) * norm.ppf(1 - 1 / n_trials)
                                                 + EULER * norm.ppf(1 - 1 / (n_trials * np.e)))
    var = 1 - skew * s + (kurt - 1) / 4 * s**2
    if var <= 0:
        return 0.0
    return float(norm.cdf((s - s0) * np.sqrt(t - 1) / np.sqrt(var)))


def seed_of(text):
    return int.from_bytes(hashlib.sha256(text.encode()).digest()[:4], "little")


def candidates(ledger, campaign, agent=None):
    """Distinct strategies an arm evaluated in search mode that filled at least once: {hash: returns}."""
    db = sqlite3.connect(ledger)
    rows = db.execute(
        "SELECT e.strategy_hash, r.returns, r.summary FROM experiments e JOIN results r ON r.experiment_id = e.id "
        "WHERE e.campaign = ? AND e.mode = 'search' AND (? IS NULL OR e.agent = ?) ORDER BY e.id",
        (campaign, agent, agent)).fetchall()
    out = {}
    for h, blob, summary in rows:
        if h not in out and json.loads(summary)["fills"] > 0:
            out[h] = np.frombuffer(blob, "<f8")
    return out


def search_decision(ledger, campaign, agent=None):
    """Screen, SPA and StepM on the search period. Returns the finalists' strategy hashes and a report."""
    cands = candidates(ledger, campaign, agent)
    n = len(cands)
    report = {"n": n, "spa_p": None, "screened": [], "finalists": []}
    if n == 0:
        return [], report
    names = list(cands)
    r = pd.DataFrame({h: cands[h] for h in names})
    sharpes = r.mean() / r.std(ddof=1)
    sharpe_sd = float(sharpes.std(ddof=1)) if n > 1 else 0.0
    dsrs = {h: dsr(r[h], n, sharpe_sd) for h in names}
    screened = [h for h in names if dsrs[h] >= DSR_MIN]
    seed = seed_of(campaign + (agent or ""))
    spa = SPA(np.zeros(len(r)), -r, block_size=BLOCK, reps=REPS, seed=seed)
    spa.compute()
    p = float(spa.pvalues["consistent"])
    report.update(spa_p=p, screened=screened, max_dsr=max(dsrs.values()))
    if p > ALPHA or not screened:
        return [], report
    stepm = StepM(np.zeros(len(r)), -r[screened], size=ALPHA, block_size=BLOCK, reps=REPS, seed=seed)
    stepm.compute()
    finalists = [h for h in screened if h in set(stepm.superior_models)]
    report["finalists"] = finalists
    return finalists, report


def programs(ledger, hashes):
    """The submitted programs of the given strategies, as recorded in the ledger."""
    db = sqlite3.connect(ledger)
    return {h: json.loads(db.execute("SELECT program FROM strategies WHERE hash = ?", (h,)).fetchone()[0]) for h in hashes}


def holdout_pvalue(r, seed):
    """One-sided stationary-bootstrap p-value for mean(r) > 0."""
    r = np.asarray(r, float)
    bs = StationaryBootstrap(BLOCK, r, seed=seed)
    means = np.array([x[0][0].mean() for x in bs.bootstrap(HOLDOUT_REPS)])
    return float(((means - r.mean()) >= r.mean()).mean())


def holm(pvalues):
    order = np.argsort(pvalues)
    m = len(pvalues)
    adjusted = np.empty(m)
    running = 0.0
    for rank, i in enumerate(order):
        running = max(running, (m - rank) * pvalues[i])
        adjusted[i] = min(1.0, running)
    return adjusted


def holdout_run(mm, market, ledger, campaign, programs, holdout_from=None):
    """The single holdout batch: {hash: (net returns, total return)} for every frozen finalist."""
    if not programs:
        return {}
    m = Path(market)
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as fh:
        fh.write("".join(json.dumps(p) + "\n" for p in programs.values()))
    extra = ["--holdout-from", str(holdout_from)] if holdout_from else []
    out = subprocess.run([str(mm), "holdout", fh.name, "--campaign", campaign, "--agent", "gate",
                          "--store", str(m / "store"), "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"),
                          "--policy", str(m / "policy.json"), "--ledger", str(ledger), *extra], capture_output=True, text=True)
    Path(fh.name).unlink()
    if out.returncode != 0:
        raise RuntimeError(out.stdout + out.stderr)
    db = sqlite3.connect(ledger)
    results = {}
    for line, h in zip(out.stdout.splitlines(), programs):
        exp = json.loads(line)["experiment"]
        blob, summary = db.execute("SELECT returns, summary FROM results WHERE experiment_id = ?", (exp,)).fetchone()
        results[h] = (np.frombuffer(blob, "<f8"), json.loads(summary)["total_return"])
    return results


def promote(results, campaign):
    """Net holdout return > 0 and the one-sided bootstrap p-value passing Holm across `results`."""
    if not results:
        return [], {}
    hashes = list(results)
    p = np.array([holdout_pvalue(results[h][0], seed_of(campaign + h)) for h in hashes])
    adj = holm(p)
    promoted = [h for h, a in zip(hashes, adj) if results[h][1] > 0 and a <= ALPHA]
    return promoted, {"holdout_p": dict(zip(hashes, p.tolist())), "holm": dict(zip(hashes, adj.tolist())),
                      "holdout_total_return": {h: results[h][1] for h in hashes}}


def holdout_decision(mm, market, ledger, campaign, finalists_programs, holdout_from=None):
    """Evaluate the frozen finalists on the holdout once; promote by net return > 0 and Holm."""
    return promote(holdout_run(mm, market, ledger, campaign, finalists_programs, holdout_from), campaign)
