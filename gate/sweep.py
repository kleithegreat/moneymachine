"""Stage 2 sweeps: C2.4 (complete null), C2.5/C2.6 (mixed and power), oracle calibration, truth.

Every campaign result is appended to data/campaigns/<sweep>.jsonl and never rewritten. A rerun
skips ids already recorded, so sweeps resume after an interruption.
"""

import json
import sys
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from scipy import stats

from gate import campaign, probes
from gate.markets import generate, write

OUT = Path("data/campaigns")
PLANTED = (0, 1)
DAYS, HOLDOUT_DAYS = 730, 180
TRUTH_MARKETS, TRUTH_YEARS = 20, 10
ORACLE = Path("gate/strategies/oracle.json")
PER_YEAR = 365 * 6


def params():
    return json.loads(Path("gate/nulls.json").read_text())


def cost_cells():
    """Median over U of each C0.7 cost cell."""
    cost = json.loads(Path("venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]
    return {side: {size: float(np.median([cost[c][side][size] for c in cost])) for size in ("1000", "10000")}
            for side in ("buy", "sell")}


def recorded(path):
    return {json.loads(l)["id"] for l in open(path)} if path.exists() else set()


def run_all(specs, path, workers=10):
    done = recorded(path)
    todo = [s for s in specs if s["id"] not in done]
    with Pool(workers) as pool, open(path, "a") as fh:
        for r in pool.imap_unordered(campaign.run_campaign, todo):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], "crash" if r.get("crash") else len(r["promoted"]), r["seconds"], flush=True)


def spec(cid, model, searcher, planted=(), beta=0.0):
    return {"id": cid, "model": model, "params": params().get(model), "searcher": searcher, "planted": list(planted),
            "beta": beta, "cost_cells": cost_cells(), "days": DAYS, "holdout_days": HOLDOUT_DAYS}


def c24_specs(markets=300):
    return [spec(f"c24-{m}-{s}-{i}", m, s) for m in ("N1", "N2", "N3") for s in ("G100", "G400", "H400")
            for i in range(markets)]


def net_returns(program, model, beta, market_id, years):
    """Per-step net returns of a program on one fresh market without holdout."""
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        root = write(Path(tmp) / "m", generate(model, params().get(model), market_id, years * 365, PLANTED, beta), 0,
                     cost_cells())
        p = Path(tmp) / "p.json"
        p.write_text(json.dumps(program))
        out = subprocess.run([campaign.MM, "eval", str(p), "--campaign", market_id, "--agent", "truth",
                              "--store", str(root / "store"), "--venue", str(root / "venue"),
                              "--policy", str(root / "policy.json"), "--ledger", str(Path(tmp) / "l.sqlite")],
                             capture_output=True, text=True, check=True)
        import sqlite3

        exp = json.loads(out.stdout)["experiment"]
        blob = sqlite3.connect(Path(tmp) / "l.sqlite").execute(
            "SELECT returns FROM results WHERE experiment_id = ?", (exp,)).fetchone()[0]
        return np.frombuffer(blob, "<f8")


def oracle_sharpe(model, beta, tag):
    """Annualized net Sharpe of the oracle over TRUTH_MARKETS x TRUTH_YEARS simulated years."""
    program = json.loads(ORACLE.read_text())
    r = np.concatenate([net_returns(program, model, beta, f"oracle-{tag}-{model}-{i}", TRUTH_YEARS)
                        for i in range(TRUTH_MARKETS)])
    return float(r.mean() / r.std(ddof=1) * np.sqrt(PER_YEAR))


def calibrate_beta(model, target, lo=0.0, hi=0.05, steps=12):
    """Bisection on beta so that the oracle's net Sharpe is `target` (monotone in beta)."""
    for _ in range(steps):
        mid = (lo + hi) / 2
        if oracle_sharpe(model, mid, f"cal{target}") < target:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def is_true(program, model, beta, tag):
    """True iff mean net return over 200 fresh years is positive with a 99% CI excluding 0."""
    means = np.array([net_returns(program, model, beta, f"truth-{tag}-{i}", TRUTH_YEARS).mean()
                      for i in range(TRUTH_MARKETS)])
    lo = means.mean() - stats.t.ppf(0.995, len(means) - 1) * means.std(ddof=1) / np.sqrt(len(means))
    return bool(lo > 0)


def c25_specs(betas, markets=100):
    return [spec(f"c25-{m}-s{s}-{i}", m, "G400", PLANTED, betas[f"{m}-{s}"]) for m in ("N2", "N3") for s in (1, 2, 3)
            for i in range(markets)]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    what = sys.argv[1]
    if what == "c24":
        run_all(c24_specs(), OUT / "c24.jsonl")
    elif what == "calibrate":
        betas = {f"{m}-{s}": calibrate_beta(m, s) for m in ("N2", "N3") for s in (1, 2, 3)}
        (OUT / "betas.json").write_text(json.dumps(betas, indent=1))
        print(betas)
    elif what == "c25":
        run_all(c25_specs(json.loads((OUT / "betas.json").read_text())), OUT / "c25.jsonl")
