"""Synthetic markets in the kernel's store format: <root>/{store,venue,policy.json}."""

import json
from pathlib import Path

import numpy as np
import polars as pl

from ingest.store import Store, write_split

HOUR = 3_600_000
BAR = 4 * HOUR
DELTA = 120_000


def write_market(root, seed, coins=12, days=60, sigma=0.02, fetched_at=1, holdout_days=0):
    """i.i.d. Gaussian 4h log returns, zero funding. Rows from the last `holdout_days` go to
    <root>/holdout, the rest to <root>/store, as real ingestion splits them."""
    rng = np.random.default_rng(seed)
    root = Path(root)
    n_bars = days * 6
    names = [f"S{c}" for c in range(coins)]
    bars, funding = [], []
    for name in names:
        r = sigma * rng.standard_normal(n_bars)
        close = 100 * np.exp(np.cumsum(r))
        open_ = np.concatenate([[100.0], close[:-1]])
        wick = np.abs(sigma * rng.standard_normal(n_bars)) * 0.5
        for k in range(n_bars):
            bars.append({"coin": name, "eventTime": (k + 1) * BAR, "knownAt": (k + 1) * BAR + DELTA, "openTime": k * BAR,
                         "open": float(open_[k]), "high": float(max(open_[k], close[k]) * (1 + wick[k])),
                         "low": float(min(open_[k], close[k]) * (1 - wick[k])), "close": float(close[k]),
                         "volume": 1.0, "trades": 1})
        for h in range(n_bars * 4 + 1):
            funding.append({"coin": name, "eventTime": h * HOUR, "knownAt": h * HOUR + DELTA,
                            "fundingRate": 0.0, "premium": 0.0, "reportedTime": h * HOUR})
    w_end = n_bars * BAR + HOUR
    holdout_start = (days - holdout_days) * 24 * HOUR if holdout_days else w_end
    search, holdout = Store(root / "store", event_before=holdout_start), Store(root / "holdout")
    write_split(search, holdout, "funding", pl.DataFrame(funding), fetched_at, "synth", holdout_start)
    write_split(search, holdout, "bars_4h", pl.DataFrame(bars), fetched_at, "synth", holdout_start)
    venue = root / "venue"
    venue.mkdir(parents=True, exist_ok=True)
    rules = {"rules": {"taker_fee": {"value": 0.00045}, "min_order_notional_usd": {"value": 10.0}},
             "coins": {n: {"szDecimals": 3, "maxLeverage": 10, "marginTiers": [{"lowerBound": "0.0", "maxLeverage": 10}],
                           "delisted": False} for n in names}}
    (venue / "rules.json").write_text(json.dumps(rules))
    cost = {n: {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")} for n in names}
    (venue / "execution.json").write_text(json.dumps({"cost_bps_ex_fee": cost}))
    (root / "policy.json").write_text(json.dumps(
        {"delta_ms": DELTA, "w_start": 0, "holdout_start": holdout_start, "w_end": w_end}))
    return root
