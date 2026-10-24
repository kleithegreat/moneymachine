"""The statistical gate of paper §8 with the stage 2 parameters (audit/criteria.md, stage 2, Gate)."""

import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
from arch.bootstrap import SPA, StepM
from scipy.stats import norm

from gate import markets
from gate.kernel import command

ALPHA = 0.05
DSR_MIN = 0.95
BLOCK = 6
REPS = 1000
LOSS_BOUND = 1.0
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


def trials(ledger, campaign, agent=None):
    """Distinct trials an arm evaluated in search mode that filled at least once: {trial key: (returns, program)},
    both from the key's first such evaluation."""
    db = sqlite3.connect(ledger)
    rows = db.execute(
        "SELECT e.trial, r.returns, r.summary, e.program FROM experiments e "
        "JOIN results r ON r.experiment_id = e.id "
        "WHERE e.campaign = ? AND e.mode = 'search' AND (? IS NULL OR e.agent = ?) ORDER BY e.id",
        (campaign, agent, agent)).fetchall()
    out = {}
    for key, blob, summary, program in rows:
        if key not in out and json.loads(summary)["fills"] > 0:
            out[key] = (np.frombuffer(blob, "<f8"), json.loads(program))
    return out


def candidates(ledger, campaign, agent=None):
    return {k: r for k, (r, _) in trials(ledger, campaign, agent).items()}


def programs(ledger, campaign, keys, agent=None):
    """The submitted program of each of an arm's trials, from the evaluation `candidates` takes its returns from."""
    found = trials(ledger, campaign, agent)
    return {k: found[k][1] for k in keys}


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
    seed = markets.seed(campaign + (agent or "")) & 0xFFFFFFFF
    spa = SPA(np.zeros(len(r)), -r, block_size=BLOCK, reps=REPS, seed=seed)
    spa.compute()
    p = float(spa.pvalues["consistent"])
    report.update(spa_p=p, screened=screened, max_dsr=max(dsrs.values()), top5=sorted(names, key=lambda h: -sharpes[h])[:5])
    finalists = stepm(r, screened, seed) if p <= ALPHA else []
    report["finalists"] = finalists
    report["effective_n"] = effective_n(r, sharpe_sd, p, seed)
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


def effective_n(r, sharpe_sd, spa_p, seed):
    """Screen and StepM rerun at each effective-N estimate (SPA does not depend on N)."""
    out = {"spa_p": spa_p, "by_n": {}}
    for name, n in [("raw", len(r.columns)), ("cluster_0.9", clusters(r, 0.9)), ("cluster_0.5", clusters(r, 0.5))]:
        screened = [h for h in r.columns if dsr(r[h], n, sharpe_sd) >= DSR_MIN]
        finalists = stepm(r, screened, seed) if spa_p <= ALPHA else []
        out["by_n"][name] = {"n": n, "screened": len(screened), "finalists": finalists}
    status = [set(v["finalists"]) for v in out["by_n"].values()]
    out["fragile"] = sorted(set().union(*status) - set.intersection(*status))
    return out


def holdout_pvalues(r):
    """Testing by betting (audit/criteria.md, stage 2, calibration v3) along the last axis: wealth prod(1 + λ_t r_t)
    with the aGRAPA bet λ_t = clip(S_{t-1} / Q_{t-1}, 0, 1/(2B)) from the past sums of r and r², and
    p = min(1, 1 / max wealth). Valid at every level by Ville's inequality when E[r_t | past] <= 0 and r_t >= -B."""
    r = np.asarray(r, float)
    if not (np.isfinite(r).all() and (r >= -LOSS_BOUND).all()):
        raise ValueError("holdout return non-finite or below -B")
    zero = np.zeros(r.shape[:-1] + (1,))
    s = np.concatenate([zero, np.cumsum(r, axis=-1)[..., :-1]], axis=-1)
    q = np.concatenate([zero, np.cumsum(r * r, axis=-1)[..., :-1]], axis=-1)
    with np.errstate(divide="ignore", invalid="ignore"):
        bet = np.where(q > 0, np.clip(s / q, 0.0, 0.5 / LOSS_BOUND), 0.0)
    wealth = np.cumprod(1 + bet * r, axis=-1).max(axis=-1, initial=1.0)
    if not np.isfinite(wealth).all():
        raise ValueError("holdout wealth non-finite")
    return 1 / wealth


def bankrupt(ledger):
    """The experiments whose returns reach −B, I10's bankruptcy step (NULLS.md, No edge)."""
    rows = sqlite3.connect(ledger).execute("SELECT experiment_id, returns FROM results").fetchall()
    return [e for e, blob in rows if (np.frombuffer(blob, "<f8") <= -LOSS_BOUND).any()]


def holdout_pvalue(r):
    return float(holdout_pvalues(r))


def holm(pvalues):
    p = np.asarray(pvalues, float)
    if not ((p >= 0) & (p <= 1)).all():
        raise ValueError("p-value outside [0, 1]")
    order = np.argsort(p)
    adjusted = np.empty(len(p))
    adjusted[order] = np.minimum(1.0, np.maximum.accumulate((len(p) - np.arange(len(p))) * p[order]))
    return adjusted


def freeze(ledger, campaign, hashes, note):
    """Record each finalist's selection in the ledger before the holdout is opened."""
    for h in hashes:
        subprocess.run(command("select", h, campaign, "gate", ledger, None, "--note", note), check=True, capture_output=True)


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
        r = subprocess.run(command("eval", p, campaign, "gate-mechanism", ledger, m, "--mechanism", "on"),
                           capture_output=True, text=True, check=True)
        out[h] = json.loads(r.stdout)["disclosure"]["result"]["mechanism"]
        p.unlink()
    return out


def holdout_run(market, ledger, campaign, programs, holdout_from=None):
    """The single holdout batch: {hash: (net returns, total return, diagnostics)} for every frozen finalist."""
    if not programs:
        return {}
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as fh:
        fh.write("".join(json.dumps(p) + "\n" for p in programs.values()))
    extra = ["--holdout-from", str(holdout_from)] if holdout_from else []
    out = subprocess.run(command("holdout", fh.name, campaign, "gate", ledger, market, "--holdout-store",
                                 str(Path(market) / "holdout"), *extra), capture_output=True, text=True)
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


def promote(results):
    """Net holdout return > 0 and the betting p-value passing Holm across `results`."""
    if not results:
        return [], {}
    hashes = list(results)
    p = np.array([holdout_pvalue(results[h][0]) for h in hashes])
    adj = holm(p)
    promoted = [h for h, a in zip(hashes, adj) if results[h][1] > 0 and a <= ALPHA]
    return promoted, {"holdout_p": dict(zip(hashes, p.tolist())), "holm": dict(zip(hashes, adj.tolist())),
                      "holdout_total_return": {h: results[h][1] for h in hashes}}


def with_diagnostics(decision, results):
    """The promotion decision, then the diagnostics it never read (audit/criteria.md, C3.4 revision)."""
    promoted, report = decision
    return promoted, {**report, "diagnostics": {h: results[h][2] for h in report.get("holdout_p", {})}}


def holdout_decision(market, ledger, campaign, finalists_programs, holdout_from=None):
    """Evaluate the frozen finalists on the holdout once; promote by net return > 0 and Holm."""
    results = holdout_run(market, ledger, campaign, finalists_programs, holdout_from)
    return with_diagnostics(promote(results), results)
