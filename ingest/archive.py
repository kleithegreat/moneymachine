"""Hyperliquid's requester-pays book archive (`venue/sources.toml`, `hyperliquid-archive`) and the C0.7 regime
diagnostic on it (PROGRESS.md; human-approved 2026-10-26, a labeled diagnostic that decides nothing).

`fetch` samples hours 0, 6, 12 and 18 UTC of each archive day for the coins of U, skipping stage 3's holdout window, and
reduces each coin-hour file at once to per-snapshot costs per C0.7 cell (C0.7's own `walk_cost` on the 20-level book;
an order the 20 levels cannot fill is censored, never costed, since the archive lacks the aggregated book C0.7 falls
back to) and its mid prices. `report` puts each day in a volatility tercile per coin, by the realized volatility of
those mids, and by calendar quarter, and compares each cell with the frozen table.

Run it in the `cloud` dev shell, which holds boto3, lz4, numpy and polars.
"""

import datetime as dt
import gzip
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np

from ingest.execution import QUANTILE, SIZES, walk_cost

BUCKET = "hyperliquid-archive"
HOURS = (0, 6, 12, 18)
SKIP = (dt.date(2026, 8, 1), dt.date(2026, 9, 30))  # stage 3's holdout, [start, end)
REPO = Path(__file__).resolve().parents[1]


def days(client):
    """The archive's dates, as listed."""
    out, token = [], None
    while True:
        kw = {"Bucket": BUCKET, "Prefix": "market_data/", "Delimiter": "/", "RequestPayer": "requester"}
        page = client.list_objects_v2(**kw, **({"ContinuationToken": token} if token else {}))
        out += [p["Prefix"].split("/")[1] for p in page.get("CommonPrefixes", [])]
        if not page.get("IsTruncated"):
            return out
        token = page["NextContinuationToken"]


def reduce(lines):
    """Per snapshot: (time, mid, {cell: cost or inf}) from one coin-hour file's JSON lines."""
    out = []
    for line in lines:
        book = json.loads(line)["raw"]["data"]
        bids, asks = book["levels"]
        if not bids or not asks:
            continue
        mid = (float(bids[0]["px"]) + float(asks[0]["px"])) / 2
        out.append((book["time"], mid, {f"{side}:{size}": walk_cost(book, side, size, mid) for side in ("buy", "sell")
                                        for size in SIZES}))
    return out


def fetch(out_dir, coins, client=None):
    """Reduce every sampled coin-hour into `out_dir`/<date>/<hour>/<coin>.json.gz (resumable: done files are skipped)."""
    import boto3
    import lz4.frame

    client = client or boto3.client("s3", region_name="us-east-1")
    out = Path(out_dir)
    for d in days(client):
        day = dt.date(int(d[:4]), int(d[4:6]), int(d[6:]))
        if SKIP[0] <= day < SKIP[1]:
            continue
        for h in HOURS:
            for coin in coins:
                path = out / d / str(h) / f"{coin}.json.gz"
                if path.exists():
                    continue
                try:
                    obj = client.get_object(Bucket=BUCKET, Key=f"market_data/{d}/{h}/l2Book/{coin}.lz4", RequestPayer="requester")
                except client.exceptions.NoSuchKey:
                    continue
                rows = reduce(lz4.frame.decompress(obj["Body"].read()).decode().splitlines())
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(gzip.compress(json.dumps(rows).encode()))


def report(out_dir, table_path=REPO / "venue/hyperliquid/execution.json"):
    """Per coin and cell, by volatility tercile and by quarter: snapshots, the censored share, the share costing more
    than the table, and the ratio of the C0.7 quantile of costed snapshots to the table's entry."""
    table = json.loads(Path(table_path).read_text())["cost_bps_ex_fee"]
    per = defaultdict(lambda: defaultdict(list))
    vol = defaultdict(dict)
    for path in sorted(Path(out_dir).glob("*/*/*.json.gz")):
        d, coin = path.parts[-3], path.name.removesuffix(".json.gz")
        rows = json.loads(gzip.decompress(path.read_bytes()))
        mids = np.array([m for _, m, _ in rows])
        if len(mids) > 1:
            vol[coin].setdefault(d, []).append(float(np.std(np.diff(np.log(mids)))))
        for _, _, costs in rows:
            for cell, c in costs.items():
                per[(coin, cell)][d].append(c)
    out = {}
    for (coin, cell), by_day in per.items():
        if coin not in table:
            continue
        side, size = cell.split(":")
        entry = table[coin][side][size]
        rv = {d: float(np.mean(v)) for d, v in vol[coin].items()}
        cuts = np.quantile(list(rv.values()), [1 / 3, 2 / 3]) if rv else [math.inf, math.inf]
        groups = defaultdict(list)
        for d, costs in by_day.items():
            groups["all"] += costs
            groups[f"vol-{'low' if rv.get(d, math.inf) <= cuts[0] else 'mid' if rv.get(d, math.inf) <= cuts[1] else 'high'}"] += costs
            groups[f"{d[:4]}Q{(int(d[4:6]) - 1) // 3 + 1}"] += costs
        out[f"{coin}:{cell}"] = {"table": entry, **{g: summary(cs, entry) for g, cs in sorted(groups.items())}}
    return out


def summary(costs, entry):
    c = np.array(costs)
    costed = c[np.isfinite(c)]
    q = float(np.quantile(costed, QUANTILE, method="higher")) if len(costed) else None
    return {"snapshots": len(c), "censored": float(np.mean(~np.isfinite(c))),
            "above_table": float(np.mean(costed > entry)) if len(costed) else None,
            "quantile_over_table": q / entry if q is not None and entry > 0 else None}
