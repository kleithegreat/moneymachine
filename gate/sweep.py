"""Sweeps of baseline-searcher campaigns on simulated markets: the complete null, mixed markets with
planted signals (with the oracle's beta calibrated to a target Sharpe, and each promotion judged
true or false on fresh years), and the complete null with real event counts replayed.

Every campaign result is appended to data/campaigns/<sweep>.jsonl and never rewritten, and each campaign keeps
its ledger in data/campaigns/<sweep>/<id>/. A rerun skips ids already recorded and records a started, unrecorded
campaign as a crash, so sweeps resume after an interruption. Campaign ids are committed: seeds derive from them.
"""

import json
import math
import sqlite3
import subprocess
import tempfile
from functools import partial
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from scipy import stats

from gate import campaign, search
from gate.kernel import command
from gate.markets import generate, null_params, store_events, write

OUT = Path("data/campaigns")
PLANTED = (0, 1)
DAYS, HOLDOUT_DAYS = 730, 180
TRUTH_MARKETS, TRUTH_YEARS = 20, 10
ORACLE = Path("gate/strategies/oracle.json")
PER_YEAR = 365 * 6
TOP5_CAMPAIGNS = 20


def cost_cells():
    """Median over U of each C0.7 cost cell."""
    cost = json.loads(Path("venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]
    return {side: {size: float(np.median([cost[c][side][size] for c in cost])) for size in ("1000", "10000")}
            for side in ("buy", "sell")}


SEARCHER = Path(__file__).resolve().parents[1] / "audit/stage2/searcher.json"


def freeze_searcher():
    """Record the searchers' pin before the first judged sweep, once."""
    if SEARCHER.exists():
        raise FileExistsError(SEARCHER)
    SEARCHER.write_text(json.dumps({"searcher": search.identity(), "disclosed": list(search.DISCLOSED)}, indent=1) + "\n")
    return str(SEARCHER)


def require_frozen_searcher():
    if not SEARCHER.exists() or json.loads(SEARCHER.read_text())["searcher"] != search.identity():
        raise SystemExit(f"the searchers differ from {SEARCHER}: freeze them first, and rerun with fresh ids after a change")


def run_all(specs, path, workers=10):
    require_frozen_searcher()
    out = path.with_suffix("")
    todo = set(campaign.resume([s["id"] for s in specs], path, out))
    with Pool(workers) as pool, open(path, "a") as fh:
        for r in pool.imap_unordered(partial(campaign.run_campaign, out=out), [s for s in specs if s["id"] in todo]):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], "crash" if r.get("crash") else len(r["promoted"]), r["seconds"], flush=True)


def spec(cid, model, searcher, planted=(), beta=0.0):
    return {"id": cid, "model": model, "params": null_params().get(model), "searcher": searcher, "planted": list(planted),
            "beta": beta, "cost_cells": cost_cells(), "days": DAYS, "holdout_days": HOLDOUT_DAYS}


def null_specs(markets=300):
    return [spec(f"c24-{m}-{s}-{i}", m, s) for m in ("N1", "N2", "N3") for s in ("G100", "G400", "H400")
            for i in range(markets)]


def mixed_specs(betas, markets=100):
    return [spec(f"c25-{m}-s{s}-{i}", m, "G400", PLANTED, betas[f"{m}-{s}"]) for m in ("N2", "N3") for s in (1, 2, 3)
            for i in range(markets)]


def events_specs(events, markets=300):
    return [{**spec(f"c56-N2-G400-{i}", "N2", "G400"), "events": events} for i in range(markets)]


def net_returns(program, model, beta, market_id, years):
    """Per-step net returns of a program on one fresh market without holdout."""
    with tempfile.TemporaryDirectory() as tmp:
        root = write(Path(tmp) / "m", generate(model, null_params().get(model), market_id, years * 365, PLANTED, beta), 0,
                     cost_cells())
        p = Path(tmp) / "p.json"
        p.write_text(json.dumps(program))
        out = subprocess.run(command("eval", p, market_id, "truth", Path(tmp) / "l.sqlite", root),
                             capture_output=True, text=True, check=True)
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


def betas():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "betas.json").write_text(json.dumps({f"{m}-{s}": calibrate_beta(m, s) for m in ("N2", "N3") for s in (1, 2, 3)}, indent=1))


def is_true(program, model, beta, tag):
    """True iff mean net return over 200 fresh years is positive with a 99% CI excluding 0."""
    means = np.array([net_returns(program, model, beta, f"truth-{tag}-{i}", TRUTH_YEARS).mean()
                      for i in range(TRUTH_MARKETS)])
    lo = means.mean() - stats.t.ppf(0.995, len(means) - 1) * means.std(ddof=1) / np.sqrt(len(means))
    return bool(lo > 0)


def results(name):
    path = OUT / f"{name}.jsonl"
    return [json.loads(l) for l in open(path)] if path.exists() else []


def cp_upper(k, n, level=0.95):
    return 1.0 if k >= n else float(stats.beta.ppf(level, k + 1, n - k))


def cp_interval(k, n, level=0.95):
    a = (1 - level) / 2
    return [0.0 if k == 0 else float(stats.beta.ppf(a, k, n - k + 1)), 1.0 if k == n else float(stats.beta.ppf(1 - a, k + 1, n - k))]


def truth_id(campaign_id, h):
    return f"{campaign_id}-{h}"


def truth():
    """Whether each promotion of the mixed sweep is true, appended to truth.jsonl."""
    path, beta = OUT / "truth.jsonl", json.loads((OUT / "betas.json").read_text())
    done = campaign.recorded(path)
    with open(path, "a") as fh:
        for r in results("mixed"):
            _, model, s, _ = r["id"].split("-")
            for p in r.get("promoted", []):
                tid = truth_id(r["id"], p["hash"])
                if tid not in done:
                    fh.write(json.dumps({"id": tid, "true": is_true(p["program"], model, beta[f"{model}-{s[1:]}"], tid)}) + "\n")
                    fh.flush()


def null_summary(name="null"):
    """Per (model, searcher): campaigns, promoting campaigns (a crash promotes), campaigns where SPA
    rejected and finalists existed, one-sided 95% Clopper-Pearson upper bounds on both rates, and campaigns with
    a bankrupt evaluation (NULLS.md, No edge)."""
    cells = {}
    for r in results(name):
        _, model, searcher, _ = r["id"].split("-")
        c = cells.setdefault(f"{model}-{searcher}", {"n": 0, "promoted": 0, "spa_and_finalists": 0, "bankrupt": 0})
        c["n"] += 1
        c["promoted"] += campaign.promoted_anything(r)
        c["spa_and_finalists"] += bool(r.get("crash")) or bool(r["search"]["finalists"])
        c["bankrupt"] += bool(r.get("bankrupt"))
    for c in cells.values():
        c["promoted_upper"], c["spa_upper"] = cp_upper(c["promoted"], c["n"]), cp_upper(c["spa_and_finalists"], c["n"])
    return cells


def mixed_summary():
    """Per (model, s): FDR (a crash is one false promotion) with a one-sided Hoeffding upper bound
    at 95% over markets, and the rate of markets with a true promotion with its 95% CI."""
    true = {t["id"]: t["true"] for t in results("truth")}
    cells = {}
    for r in results("mixed"):
        _, model, s, _ = r["id"].split("-")
        ts = [False] if r.get("crash") else [true[truth_id(r["id"], p["hash"])] for p in r["promoted"]]
        c = cells.setdefault(f"{model}-{s}", {"n": 0, "fdp": [], "with_true": 0})
        c["n"] += 1
        c["fdp"].append(ts.count(False) / max(len(ts), 1))
        c["with_true"] += any(ts)
    for c in cells.values():
        fdr = float(np.mean(c.pop("fdp")))
        c.update(fdr=fdr, fdr_upper=fdr + math.sqrt(math.log(20) / (2 * c["n"])), power=c["with_true"] / c["n"],
                 power_ci=cp_interval(c["with_true"], c["n"]))
    return cells


def summary(out):
    Path(out).write_text(json.dumps({"null": null_summary(), "mixed": mixed_summary(), "events": null_summary("events"),
                                     "qualifications": "PROGRESS.md, Qualifications, stage 2"}, indent=1) + "\n")


def top5_programs(first=TOP5_CAMPAIGNS):
    """The in-sample top-5 strategies of the first `first` complete-null campaigns in null_specs() order."""
    by_id = {r["id"]: r for r in results("null")}
    out = []
    for s in null_specs()[:first]:
        for rank, p in enumerate(by_id[s["id"]].get("top5", [])):
            out.append({**p["program"], "name": f"top5-{s['id']}-{rank}"})
    return out


def sweep(name, data_root=None, version=None):
    """Run the `null`, `mixed` or `events` sweep (events: real forum counts at a dataset version)."""
    OUT.mkdir(parents=True, exist_ok=True)
    if name == "null":
        specs = null_specs()
    elif name == "mixed":
        specs = mixed_specs(json.loads((OUT / "betas.json").read_text()))
    else:
        coins = tuple(json.loads((Path(data_root) / "universe.json").read_text())["universe"])
        specs = events_specs(store_events(str(Path(data_root) / "store"), int(version), coins))
    run_all(specs, OUT / f"{name}.jsonl")
