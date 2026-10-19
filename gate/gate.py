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
    if var <= 1e-12 * (1 + abs(skew * s) + (kurt - 1) / 4 * s**2):
        return 0.0
    return float(norm.cdf((s - s0) * np.sqrt(t - 1) / np.sqrt(var)))


def seed_of(text):
    return int.from_bytes(hashlib.sha256(text.encode()).digest()[:4], "little")


def candidates(ledger, campaign, agent=None):
    """Distinct trials an arm evaluated in search mode that filled at least once: {trial key: returns}."""
    db = sqlite3.connect(ledger)
    rows = db.execute(
        "SELECT e.equivalence, e.params, r.returns, r.summary FROM experiments e JOIN results r ON r.experiment_id = e.id "
        "WHERE e.campaign = ? AND e.mode = 'search' AND (? IS NULL OR e.agent = ?) ORDER BY e.id",
        (campaign, agent, agent)).fetchall()
    out = {}
    for h, params, blob, summary in rows:
        key = trial_key(h, params)
        if key not in out and json.loads(summary)["fills"] > 0:
            out[key] = np.frombuffer(blob, "<f8")
    return out


def trial_key(equivalence, params):
    """A statistical trial is an equivalence class (kernel/CANONICAL.md) with its parameter values."""
    return equivalence if params == "[]" else hashlib.sha256(f"{equivalence}{params}".encode()).hexdigest()


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
    report.update(spa_p=p, screened=screened, max_dsr=max(dsrs.values()), top5=sorted(names, key=lambda h: -sharpes[h])[:5])
    finalists = stepm(r, screened, seed) if p <= ALPHA else []
    report["finalists"] = finalists
    report["effective_n"] = effective_n(r, sharpe_sd, p, seed, finalists)
    return finalists, report


def stepm(r, screened, seed):
    if not screened:
        return []
    st = StepM(np.zeros(len(r)), -r[screened], size=ALPHA, block_size=BLOCK, reps=REPS, seed=seed)
    st.compute()
    return [h for h in screened if h in set(st.superior_models)]


def clusters(r, threshold):
    """Complete-linkage clusters at |rho| >= threshold; zero-variance series are singletons."""
    from scipy.cluster.hierarchy import fcluster, linkage
    from scipy.spatial.distance import squareform

    varying = [c for c in r.columns if r[c].std() > 0]
    if len(varying) < 2:
        return len(r.columns)
    d = 1 - np.abs(np.nan_to_num(np.corrcoef(r[varying].to_numpy().T)))
    np.fill_diagonal(d, 0)
    labels = fcluster(linkage(squareform(np.clip(d, 0, None), checks=False), "complete"), 1 - threshold, "distance")
    return len(set(labels)) + len(r.columns) - len(varying)


def effective_n(r, sharpe_sd, spa_p, seed, official):
    """Screen and StepM rerun at each effective-N estimate (SPA does not depend on N)."""
    out = {"spa_p": spa_p, "by_n": {}}
    for name, n in [("raw", len(r.columns)), ("cluster_0.9", clusters(r, 0.9)), ("cluster_0.5", clusters(r, 0.5))]:
        screened = [h for h in r.columns if dsr(r[h], n, sharpe_sd) >= DSR_MIN]
        finalists = stepm(r, screened, seed) if spa_p <= ALPHA else []
        out["by_n"][name] = {"n": n, "screened": len(screened), "finalists": finalists}
    status = [set(v["finalists"]) for v in out["by_n"].values()]
    out["fragile"] = sorted(set().union(*status) - set.intersection(*status))
    return out


def programs(ledger, keys):
    """The submitted program of each trial: the first experiment whose (strategy, params) has that key."""
    db = sqlite3.connect(ledger)
    rows = db.execute("SELECT equivalence, params, program FROM experiments WHERE mode = 'search' ORDER BY id").fetchall()
    found = {}
    for h, params, program in rows:
        found.setdefault(trial_key(h, params), json.loads(program))
    return {k: found[k] for k in keys}


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
                          "--ledger", str(ledger), *extra], capture_output=True, text=True)
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
