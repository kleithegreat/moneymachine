"""The statistical gate of paper §8 with the stage 2 parameters (PROGRESS.md, Stage 2, Gate)."""

import functools
import hashlib
import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
from arch.bootstrap import SPA, StationaryBootstrap, StepM
from scipy.signal import fftconvolve
from scipy.stats import norm

from gate.kernel import MM

ALPHA = 0.05
DSR_MIN = 0.95
BLOCK = 6
REPS = 1000
HOLDOUT_REPS = 10_000
LAGS = 36
CALIBRATION = Path(__file__).resolve().parent / "holdout_calibration.json"
EULER = 0.5772156649015329


def dsr(returns, n_trials, sharpe_sd):
    """Deflated Sharpe ratio of one per-period return series (paper §8, Bailey-López de Prado S0)."""
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


def campaign_seed(text):
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
    seed = campaign_seed(campaign + (agent or ""))
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


def long_run_sd(x):
    """sqrt of sum over |k| <= LAGS of w_k * gamma(k) along the last axis, w_k = (1 - |k|/(LAGS + 1)) (1 - 1/BLOCK)^|k|,
    with gamma the biased autocovariance: the quadratic form x'Wx/n of the demeaned series, W the banded Toeplitz
    matrix of w. The weights are a product of positive-definite sequences, so it is never negative."""
    constant = x.max(axis=-1) == x.min(axis=-1)
    x = x - x.mean(axis=-1, keepdims=True)
    n = x.shape[-1]
    k = np.arange(-min(LAGS, n - 1), min(LAGS, n - 1) + 1)
    w = (1 - np.abs(k) / (LAGS + 1)) * (1 - 1 / BLOCK) ** np.abs(k)
    var = np.where(constant, 0.0, (x * fftconvolve(x, w.reshape((1,) * (x.ndim - 1) + (-1,)), mode="same", axes=-1)).sum(axis=-1) / n)
    if not np.all(np.isfinite(var) & (var >= 0)):
        raise ArithmeticError("long-run variance negative or non-finite")
    return np.sqrt(var)


def bootstrap_pvalue(r, seed):
    """One-sided studentized stationary-bootstrap p-value for mean(r) > 0 (PROGRESS.md, Stage 2, revision 2026-10-20)."""
    r = np.asarray(r, float)
    sd = long_run_sd(r)
    if sd == 0:
        return 1.0
    t = r.mean() / sd
    bs = StationaryBootstrap(BLOCK, r, seed=seed)
    x = r[np.array([bs.update_indices() for _ in range(HOLDOUT_REPS)])]
    dev, sds = x.mean(axis=1) - r.mean(), long_run_sd(x)
    with np.errstate(divide="ignore", invalid="ignore"):
        ts = np.where(sds > 0, dev / sds, np.where(dev >= 0, np.inf, -np.inf))
    return float((1 + (ts >= t).sum()) / (1 + HOLDOUT_REPS))


@functools.lru_cache(maxsize=1)
def _calibration():
    c = json.loads(CALIBRATION.read_text())
    return c["denominator"], [np.array(ks) for ks in c["cells"].values()]


def holdout_pvalue(r, seed):
    """The bootstrap p-value calibrated on the development suite: the largest, over its generators, Monte Carlo
    p-value of the bootstrap p-value against that generator's null distribution (Stage 2, revision 2026-10-20)."""
    denominator, cells = _calibration()
    k = round(bootstrap_pvalue(r, seed) * denominator)
    return max((1 + int(np.searchsorted(ks, k, side="right"))) / (len(ks) + 1) for ks in cells)


def holm(pvalues):
    order = np.argsort(pvalues)
    m = len(pvalues)
    adjusted = np.empty(m)
    running = 0.0
    for rank, i in enumerate(order):
        running = max(running, (m - rank) * pvalues[i])
        adjusted[i] = min(1.0, running)
    return adjusted


def freeze(ledger, campaign, hashes, note):
    """Record each finalist's selection in the ledger before the holdout is opened."""
    for h in hashes:
        subprocess.run([str(MM), "select", h, "--campaign", campaign, "--agent", "gate", "--note", note,
                        "--ledger", str(ledger)], check=True, capture_output=True)


def mechanism_check(market, ledger, campaign, programs):
    """For each finalist: its pre-registered prediction tested on the search period (never disclosed to agents)."""
    m = Path(market)
    out = {}
    for h, prog in programs.items():
        if "prediction" not in prog:
            out[h] = {"pass": False, "reason": "no prediction"}
            continue
        p = m / f"mech-{h[:16]}.json"
        p.write_text(json.dumps(prog))
        r = subprocess.run([str(MM), "eval", str(p), "--campaign", campaign, "--agent", "gate-mechanism", "--mechanism", "on",
                            "--store", str(m / "store"), "--venue", str(m / "venue"), "--ledger", str(ledger)],
                           capture_output=True, text=True, check=True)
        out[h] = json.loads(r.stdout)["disclosure"]["result"]["mechanism"]
        p.unlink()
    return out


def holdout_run(market, ledger, campaign, programs, holdout_from=None):
    """The single holdout batch: {hash: (net returns, total return, diagnostics)} for every frozen finalist."""
    if not programs:
        return {}
    m = Path(market)
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as fh:
        fh.write("".join(json.dumps(p) + "\n" for p in programs.values()))
    extra = ["--holdout-from", str(holdout_from)] if holdout_from else []
    out = subprocess.run([str(MM), "holdout", fh.name, "--campaign", campaign, "--agent", "gate",
                          "--store", str(m / "store"), "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"),
                          "--ledger", str(ledger), *extra], capture_output=True, text=True)
    Path(fh.name).unlink()
    if out.returncode != 0:
        raise RuntimeError(out.stdout + out.stderr)
    db = sqlite3.connect(ledger)
    results = {}
    for line, h in zip(out.stdout.splitlines(), programs):
        d = json.loads(line)
        blob, summary = db.execute("SELECT returns, summary FROM results WHERE experiment_id = ?", (d["experiment"],)).fetchone()
        results[h] = (np.frombuffer(blob, "<f8"), json.loads(summary)["total_return"], d["disclosure"]["diagnostics"])
    return results


def promote(results, campaign):
    """Net holdout return > 0 and the one-sided bootstrap p-value passing Holm across `results`."""
    if not results:
        return [], {}
    hashes = list(results)
    p = np.array([holdout_pvalue(results[h][0], campaign_seed(campaign + h)) for h in hashes])
    adj = holm(p)
    promoted = [h for h, a in zip(hashes, adj) if results[h][1] > 0 and a <= ALPHA]
    return promoted, {"holdout_p": dict(zip(hashes, p.tolist())), "holm": dict(zip(hashes, adj.tolist())),
                      "holdout_total_return": {h: results[h][1] for h in hashes}}


def with_diagnostics(decision, results):
    """The promotion decision, then the diagnostics it never read (PROGRESS.md, C3.4 revision)."""
    promoted, report = decision
    return promoted, {**report, "diagnostics": {h: results[h][2] for h in report.get("holdout_p", {})}}


def holdout_decision(market, ledger, campaign, finalists_programs, holdout_from=None):
    """Evaluate the frozen finalists on the holdout once; promote by net return > 0 and Holm."""
    results = holdout_run(market, ledger, campaign, finalists_programs, holdout_from)
    return with_diagnostics(promote(results, campaign), results)
