"""C0.7: per-coin taker cost model from recorded L2 snapshots, and its held-out validation.

Cost is in bps from mid, excluding the fee: buys walk the asks, sells walk the bids. The
model for (coin, side, notional) is the 95th percentile of costs in the chronologically
first 70% of snapshots; a snapshot whose depth cannot fill the order has infinite cost.
"""

import json
import math
import sys
from collections import defaultdict

import numpy as np

from ingest.availability import load

SIZES = (1_000, 10_000)
QUANTILE = 0.95
CALIBRATION = 0.7


def walk_cost(book, side, notional):
    bids, asks = book["levels"]
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


def costs_by_cell(polls):
    snaps = defaultdict(list)
    for p in polls:
        if p["kind"] == "l2" and all(p["data"]["levels"]):
            snaps[p["coin"]].append(p)
    out = {}
    for coin, ps in snaps.items():
        ps.sort(key=lambda p: p["sent"])
        for side in ("buy", "sell"):
            for size in SIZES:
                out[(coin, side, size)] = ([p["sent"] for p in ps], np.array([walk_cost(p["data"], side, size) for p in ps]))
    return out


def calibrate_and_validate(cells):
    model, report = {}, {}
    for (coin, side, size), (times, c) in cells.items():
        k = int(len(c) * CALIBRATION)
        cal, test = c[:k], c[k:]
        q = float(np.quantile(cal, QUANTILE)) if np.isfinite(np.quantile(cal, QUANTILE)) else math.inf
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


if __name__ == "__main__":
    live_dir, model_out = sys.argv[1:]
    model, report = calibrate_and_validate(costs_by_cell(load(live_dir)))
    with open(model_out, "w") as f:
        json.dump({"quantile": QUANTILE, "calibration_fraction": CALIBRATION, "cost_bps_ex_fee": model}, f, indent=1)
        f.write("\n")
    print(json.dumps(report, indent=1))
