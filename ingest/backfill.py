"""Fetch W for the universe into the point-in-time store as one dataset version."""

import json
import sys
import time
from pathlib import Path

import polars as pl

from ingest import checks
from ingest.hl import HOUR, Info
from ingest.store import DELTA, HOLDOUT_START, W_END, W_START, stores, write_split

BAR = 4 * HOUR


def funding_frame(rows):
    return pl.DataFrame(
        [{"coin": r["coin"], "eventTime": r["time"] // HOUR * HOUR, "knownAt": r["time"] // HOUR * HOUR + DELTA,
          "fundingRate": float(r["fundingRate"]), "premium": float(r["premium"]), "reportedTime": r["time"]}
         for r in rows],
        schema={"coin": pl.Utf8, "eventTime": pl.Int64, "knownAt": pl.Int64, "fundingRate": pl.Float64,
                "premium": pl.Float64, "reportedTime": pl.Int64},
    )


def bar_frame(rows, fetched_at):
    closed = [c for c in rows if c["t"] + BAR <= fetched_at]
    return pl.DataFrame(
        [{"coin": c["s"], "eventTime": c["t"] + BAR, "knownAt": c["t"] + BAR + DELTA, "openTime": c["t"],
          "open": float(c["o"]), "high": float(c["h"]), "low": float(c["l"]), "close": float(c["c"]),
          "volume": float(c["v"]), "trades": int(c["n"])}
         for c in closed],
        schema={"coin": pl.Utf8, "eventTime": pl.Int64, "knownAt": pl.Int64, "openTime": pl.Int64,
                "open": pl.Float64, "high": pl.Float64, "low": pl.Float64, "close": pl.Float64,
                "volume": pl.Float64, "trades": pl.Int64},
    )


def main(data_root, budget):
    root = Path(data_root)
    coins = json.loads((root / "universe.json").read_text())["universe"]
    info = Info(int(budget))
    delisted = {a["name"] for a in info.meta()["universe"] if a.get("isDelisted")}
    fetched_at = int(time.time() * 1000)
    funding, bars = [], []
    for coin in coins:
        funding += info.funding(coin, W_START, W_END)
        bars += info.candles(coin, "4h", W_START, W_END)
        print(coin, len(funding), len(bars), file=sys.stderr, flush=True)
    funding, bars = funding_frame(funding), bar_frame(bars, fetched_at)

    intervals = checks.listed_intervals(bars, W_START, W_END, delisted & set(coins))
    report = {
        "version": fetched_at,
        "intervals": intervals,
        "coverage": checks.coverage(funding, bars, intervals),
        "integrity": checks.integrity(funding, bars),
        "replay_from_keys": checks.replay_completeness(funding, bars, intervals),
    }
    search, holdout = stores(root)
    report["written(search, holdout)"] = {
        "funding": write_split(search, holdout, "funding", funding, fetched_at, "hl-info:fundingHistory"),
        "bars_4h": write_split(search, holdout, "bars_4h", bars, fetched_at, "hl-info:candleSnapshot"),
    }

    def view(dataset, t):
        return dict(search.as_of(dataset, t, fetched_at).group_by("coin").agg(pl.col("eventTime").max()).iter_rows())

    search_intervals = {c: (s, min(e, HOLDOUT_START)) for c, (s, e) in intervals.items()}
    report["replay_search_as_of"] = checks.replay_completeness(funding, bars, search_intervals, view)
    out = root / "reports" / f"stage0-ingest-{fetched_at}.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report, indent=1))
    print(out)


if __name__ == "__main__":
    main(*sys.argv[1:])
