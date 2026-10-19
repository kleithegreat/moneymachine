"""C0.7: per-coin taker cost model from recorded L2 snapshots, and its held-out validation.

Cost is in bps from mid, excluding the fee: buys walk the asks, sells walk the bids, through
the full-precision book and, if that cannot fill, through the 4-significant-figure aggregated
book, whose bucket prices are conservative. The model for (coin, side, notional) is the 95th
percentile (an order statistic) of costs in the chronologically first 70% of snapshots; a
snapshot where neither book fills the order has infinite cost. A coin without a live book
(delisted) gets the cell-wise maximum of the others, flagged.
"""

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

from ingest.availability import judged, window

SIZES = (1_000, 10_000)
QUANTILE = 0.95
CALIBRATION = 0.7


def walk_cost(book, side, notional, mid=None):
    bids, asks = book["levels"]
    if mid is None:
        mid = (float(bids[0]["px"]) + float(asks[0]["px"])) / 2
    remaining, qty = notional, 0.0
    for level in asks if side == "buy" else bids:
        px, sz = float(level["px"]), float(level["sz"])
        take = min(sz, remaining / px)
        qty += take
        remaining -= take * px
        if remaining <= 1e-9:
            vwap = notional / qty
            return (vwap / mid - 1) * 1e4 if side == "buy" else (1 - vwap / mid) * 1e4
    return math.inf


def cost(snapshot, side, notional):
    full = snapshot["data"]
    mid = (float(full["levels"][0][0]["px"]) + float(full["levels"][1][0]["px"])) / 2
    c = walk_cost(full, side, notional, mid)
    return c if math.isfinite(c) or not all(snapshot["agg"]["levels"]) else walk_cost(snapshot["agg"], side, notional, mid)


def costs_by_cell(polls):
    snaps = defaultdict(list)
    for p in polls:
        if p["kind"] == "l2" and "agg" in p and all(p["data"]["levels"]):
            snaps[p["coin"]].append(p)
    out = {}
    for coin, ps in snaps.items():
        ps.sort(key=lambda p: p["sent"])
        for side in ("buy", "sell"):
            for size in SIZES:
                out[(coin, side, size)] = ([p["sent"] for p in ps], np.array([cost(p, side, size) for p in ps]))
    return out


def calibrate_and_validate(cells):
    model, report = {}, {}
    for (coin, side, size), (times, c) in cells.items():
        k = int(len(c) * CALIBRATION)
        cal, test = c[:k], c[k:]
        q = float(np.quantile(cal, QUANTILE, method="higher")) if k else math.inf
        model.setdefault(coin, {}).setdefault(side, {})[str(size)] = q
        finite = test[np.isfinite(test)]
        coverage = float(np.mean(test <= q)) if len(test) else 0.0
        excess = float(np.median(q - finite)) if len(finite) and math.isfinite(q) else math.inf
        report[f"{coin}:{side}:{size}"] = {
            "n_cal": int(k), "n_test": int(len(test)), "model_bps": q, "coverage": coverage,
            "median_excess_bps": excess, "test_median_bps": float(np.median(finite)) if len(finite) else math.inf,
            "calibration_span": [times[0], times[k - 1]] if k else None,
            "pass": coverage >= 0.9 and excess <= 3.0,
        }
    return model, report


def fill_missing(model, coins):
    """Coins without a live book get the cell-wise maximum over the calibrated coins."""
    flagged = [c for c in coins if c not in model]
    worst = {side: {size: max(model[c][side][size] for c in model) for size in model[next(iter(model))][side]}
             for side in ("buy", "sell")}
    return {c: model.get(c, worst) for c in coins}, flagged


if __name__ == "__main__":
    live_dir, model_out = sys.argv[1:]
    model, report = calibrate_and_validate(costs_by_cell(judged(live_dir)))
    coins = json.loads((Path(__file__).resolve().parents[1] / "data" / "universe.json").read_text())["universe"]
    model, flagged = fill_missing(model, coins)
    with open(model_out, "w") as f:
        json.dump({"quantile": QUANTILE, "calibration_fraction": CALIBRATION, "no_live_book_cellwise_max": flagged,
                   "cost_bps_ex_fee": model}, f, indent=1)
        f.write("\n")
    print(json.dumps({"window": window(live_dir), **report}, indent=1))
