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
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from scipy import stats

from gate import campaign, search
from gate.compute import workers
from gate.kernel import command
from gate.markets import generate, null_params, store_events, write

OUT = Path("data/campaigns")
# The sweeps' round, carried by every campaign id, so a rerun after a gate or null change draws fresh markets
# (audit/criteria.md, stage 2, Runs). r2: the rerun under the screen's revision of 2026-10-27.
ROUND = "r2"
PLANTED = (0, 1)
DAYS, HOLDOUT_DAYS = 730, 180
LONG_DAYS, LONG_HOLDOUT_DAYS, LONG_MEAN, LONG_YEARS = 1450, 900, 0.002, 2  # C2.6's long-holdout cell (amendment of 2026-10-26)
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


# Peak memory per task with mm 3a732069 (columnar loader), measured 2026-10-27, with margin: a campaign (684 MiB for the
# long cell with 80 finalists through the holdout; 533 MiB for a null one) and one ten-year market's evaluation (936
# MiB, as in calibration and truth).
CAMPAIGN_BYTES, CALIBRATION_BYTES = 1_000_000_000, 1_300_000_000


def run_all(specs, path):
    require_frozen_searcher()
    out = path.with_suffix("")
    with campaign.resume([s["id"] for s in specs], path, out) as todo, Pool(workers(CAMPAIGN_BYTES)) as pool, \
            open(path, "a") as fh:
        for r in pool.imap_unordered(partial(campaign.run_campaign, out=out), [s for s in specs if s["id"] in set(todo)]):
            fh.write(json.dumps(r) + "\n")
            fh.flush()
            print(r["id"], "crash" if r.get("crash") else len(r["promoted"]), r["seconds"], flush=True)


def spec(cid, model, searcher, planted=(), beta=0.0):
    return {"id": cid, "model": model, "params": null_params().get(model), "searcher": searcher, "planted": list(planted),
            "beta": beta, "cost_cells": cost_cells(), "days": DAYS, "holdout_days": HOLDOUT_DAYS}


def null_specs(markets=300, rnd=ROUND):
    return [spec(f"c24{rnd}-{m}-{s}-{i}", m, s) for m in ("N1", "N2", "N3") for s in ("G100", "G400", "H400")
            for i in range(markets)]


def mixed_specs(betas, markets=100, rnd=ROUND):
    """C2.5's cells, s1 to s3 on each base, and C2.6's long-holdout cell, N2-long (`rnd`: the round tag; the first
    round had none)."""
    return [spec(f"c25{rnd}-{m}-s{s}-{i}", m, "G400", PLANTED, betas[f"{m}-s{s}"]) for m in ("N2", "N3") for s in (1, 2, 3)
            for i in range(markets)] + \
        [spec(f"c25{rnd}-N2-long-{i}", "N2", "G400", PLANTED, betas["N2-long"]) | {"days": LONG_DAYS, "holdout_days": LONG_HOLDOUT_DAYS}
         for i in range(markets)]


def events_specs(events, markets=300):
    return [{**spec(f"c56{ROUND}-N2-G400-{i}", "N2", "G400"), "events": events} for i in range(markets)]


def net_returns(program, model, beta, market_id, years):
    """Per-step net returns of a program on one fresh market without holdout."""
    with tempfile.TemporaryDirectory() as tmp:
        root = write(Path(tmp) / "m", generate(model, null_params().get(model), market_id, years * 365, PLANTED, beta), 0,
                     cost_cells())
        p = Path(tmp) / "p.json"
        p.write_text(json.dumps(program))
        out = subprocess.run(command("eval", p, market_id, "truth", Path(tmp) / "l.sqlite", root),
                             capture_output=True, text=True)
        if out.returncode:
            raise RuntimeError(f"mm eval on {market_id} (beta {beta}) exited {out.returncode}: "
                               f"{out.stdout.strip()[-1000:]} {out.stderr.strip()[-2000:]}")
        exp = json.loads(out.stdout)["experiment"]
        blob = sqlite3.connect(Path(tmp) / "l.sqlite").execute(
            "SELECT returns FROM results WHERE experiment_id = ?", (exp,)).fetchone()[0]
        return np.frombuffer(blob, "<f8")


# Markets evaluated at once within one calibration step (each seeded by its id, so the values never depend on it).
THREADS = 1


def oracle_returns(model, beta, tag, weight=None, years=TRUTH_YEARS):
    """The oracle's per-step net returns over TRUTH_MARKETS fresh markets; `weight` replaces its per-coin weight."""
    program = json.loads(ORACLE.read_text())
    if weight is not None:
        program["weight"]["args"][1]["const"] = weight
    with ThreadPoolExecutor(THREADS) as ex:
        return np.concatenate(list(ex.map(lambda i: net_returns(program, model, beta, f"oracle-{tag}-{model}-{i}", years),
                                          range(TRUTH_MARKETS))))


def oracle_sharpe(model, beta, tag):
    """Annualized net Sharpe of the oracle over TRUTH_MARKETS x TRUTH_YEARS simulated years."""
    r = oracle_returns(model, beta, tag)
    return float(r.mean() / r.std(ddof=1) * np.sqrt(PER_YEAR))


def oracle_cap_mean(beta):
    """Mean net return per step of the oracle at the kernel's gross cap (weight 2.0) on N2, over TRUTH_MARKETS fresh
    LONG_YEARS-year markets: the long-holdout cell's strength."""
    return float(oracle_returns("N2", beta, "cal-long", weight=2.0, years=LONG_YEARS).mean())


STEPS = OUT / "betas-steps.jsonl"


def bisect(key, f, target, lo, hi, steps):
    """The point in [lo, hi] where the increasing f reaches target, each step's value recorded in STEPS as it is
    computed, so a rerun resumes at the first unrecorded step (a crash loses at most one)."""
    done = {r["step"]: r for r in map(json.loads, open(STEPS)) if r["key"] == key} if STEPS.exists() else {}
    for k in range(steps):
        mid = (lo + hi) / 2
        if k in done:
            if done[k]["mid"] != mid:
                raise SystemExit(f"{STEPS}: {key} step {k} was recorded at {done[k]['mid']}, not {mid}")
            v = done[k]["value"]
        else:
            v = f(mid)
            with open(STEPS, "a") as fh:
                fh.write(json.dumps({"key": key, "step": k, "mid": mid, "value": v}) + "\n")
        lo, hi = (mid, hi) if v < target else (lo, mid)
    return (lo + hi) / 2


def oracle_sharpe_for(model, target):
    return lambda b: oracle_sharpe(model, b, f"cal{target}")


# The s = 3 cells (audit/decisions.md, 2026-10-27): N2's oracle reaches Sharpe 3 only above 0.05, so its range is
# [0, 0.08]; N3's cannot reach 3, so its cell is amended to s = 2.5 on [0.044, 0.06] (criteria, C2.5).
CALIBRATIONS = {**{f"{m}-s{s}": (oracle_sharpe_for(m, s), s, 0.0, 0.05, 12) for m in ("N2", "N3") for s in (1, 2)},
                "N2-s3": (oracle_sharpe_for("N2", 3), 3, 0.0, 0.08, 12),
                "N3-s3": (oracle_sharpe_for("N3", 2.5), 2.5, 0.044, 0.06, 12),
                "N2-long": (oracle_cap_mean, LONG_MEAN, 0.0, 0.5, 16)}


def calibrate(key):
    return bisect(key, *CALIBRATIONS[key])


def betas(keys=None):
    """Calibrate the given keys (comma-separated; all by default), resuming from STEPS, one process per key and as many
    markets at a time in each as memory allows; betas.json is written once every key is calibrated."""
    global THREADS
    OUT.mkdir(parents=True, exist_ok=True)
    todo = keys.split(",") if keys else list(CALIBRATIONS)
    n = min(len(todo), workers(CALIBRATION_BYTES))
    THREADS = max(1, workers(CALIBRATION_BYTES) // n)
    with Pool(n) as pool:
        values = dict(zip(todo, pool.map(calibrate, todo)))
    if set(values) == set(CALIBRATIONS):
        (OUT / "betas.json").write_text(json.dumps({k: values[k] for k in CALIBRATIONS}, indent=1))


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
    """Whether each promotion of the mixed sweep is true, appended to truth.jsonl as each is judged."""
    path, beta = OUT / "truth.jsonl", json.loads((OUT / "betas.json").read_text())
    with campaign.exclusive(path) as fh:
        done = campaign.recorded(path)
        todo = [(truth_id(r["id"], p["hash"]), p["program"], r["id"].split("-")[1], beta["-".join(r["id"].split("-")[1:3])])
                for r in results("mixed") for p in r.get("promoted", []) if truth_id(r["id"], p["hash"]) not in done]
        with Pool(workers(CALIBRATION_BYTES)) as pool:
            for tid, true in pool.imap_unordered(judge, todo):
                fh.write(json.dumps({"id": tid, "true": true}) + "\n")
                fh.flush()


def judge(item):
    tid, program, model, beta = item
    return tid, is_true(program, model, beta, tid)


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
