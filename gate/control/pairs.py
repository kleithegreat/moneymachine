"""Markets and twins (step 1): a study market at strength b and its twin at strength 0, from the frozen generator."""

import hashlib
import json
import os
from functools import cache
from pathlib import Path

import numpy as np
import polars as pl

from gate import markets
from gate.agent import campaigns
from gate.control.constants import PAIRS, PLANTED
from gate.sweep import DAYS, HOLDOUT_DAYS
from ingest.policy import BAR, DAY, HOUR, POLICY

FETCHED_AT = 1


@cache
def series() -> campaigns.SeriesInputs:
    return campaigns.series_inputs()


def fresh_ids(market_id: str) -> list[str]:
    return [f"{market_id}/fresh/{i}" for i in range(PAIRS)]


def arrays(market_id: str, strength: float) -> markets.Arrays:
    return markets.generate("N2", series()["params"], market_id, DAYS, PLANTED, strength)


def stem(market_id: str) -> str:
    return hashlib.sha256(market_id.encode()).hexdigest()[:16]


def write_market(root: Path, market_id: str, strength: float, label: str = "market") -> Path:
    """The market at `strength`, in the directory of `root` named by the id and `label`."""
    path = root / f"{stem(market_id)}-{label}"
    written: Path = markets.write(path, arrays(market_id, strength), HOLDOUT_DAYS, series()["cost_cells"])
    return written


def scored_store(path: Path, arrays: markets.Arrays) -> Path:
    """The market's search period as the kernel reads it: the rows of the `store/` that `gate.markets.write` gives
    for the same arrays, holdout days and cost cells, with `fetchedAt` and without `hash`, `source` and `holdout/`.
    The row hash is most of a store write's time, and the kernel skips it (`UNREAD`)."""
    n, coins = arrays["open"].shape
    hours = arrays["funding"].shape[0]
    names = [f"S{i}" for i in range(coins)]
    k = np.arange(n)
    h = np.arange(hours)
    w_end = n * BAR + HOUR
    holdout_start = n * BAR - HOLDOUT_DAYS * DAY
    bars = pl.DataFrame(
        {
            "coin": np.repeat(names, n),
            "eventTime": np.tile((k + 1) * BAR, coins),
            "openTime": np.tile(k * BAR, coins),
            **{col: arrays[col].T.reshape(-1) for col in ("open", "high", "low", "close", "volume")},
            "trades": np.full(n * coins, 100),
        }
    )
    funding = pl.DataFrame(
        {
            "coin": np.repeat(names, hours),
            "eventTime": np.tile(h * HOUR, coins),
            "fundingRate": arrays["funding"].T.reshape(-1),
            "premium": arrays["premium"].T.reshape(-1),
            "reportedTime": np.tile(h * HOUR, coins),
        }
    )
    for dataset, frame in {"funding": funding, "bars_4h": bars}.items():
        searched = frame.filter(pl.col("eventTime") < holdout_start)
        file = path / "store" / dataset / f"{FETCHED_AT}.parquet"
        file.parent.mkdir(parents=True, exist_ok=True)
        searched.with_columns(pl.lit(FETCHED_AT, pl.Int64).alias("fetchedAt")).write_parquet(file)
        os.chmod(file, 0o444)
    markets.write_venue(path, {c: (3, 10, False) for c in names}, series()["cost_cells"])
    policy = POLICY | {"w_start": 0, "holdout_start": holdout_start, "w_end": w_end}
    (path / "store" / "policy.json").write_text(json.dumps(policy))
    (path / "version").write_text(f"{FETCHED_AT}\n")
    return path


def write_one(root: Path, market_id: str, strength: float, label: str) -> Path:
    return scored_store(root / f"{stem(market_id)}-{label}", arrays(market_id, strength))


def write_pair(root: Path, market_id: str, strength: float) -> tuple[Path, Path]:
    """The market at `strength` and its twin at strength 0, written for scoring (`scored_store`) in two directories
    of `root`; at strength 0 the two are one market, written once."""
    planted = write_one(root, market_id, strength, "planted")
    if strength == 0.0:
        return planted, planted
    return planted, write_one(root, market_id, 0.0, "twin")
