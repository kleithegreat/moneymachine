"""Hyperliquid's requester-pays book archive (`venue/sources.toml`, `hyperliquid-archive`) and the C0.7 regime
diagnostic on it (PROGRESS.md; human-approved 2026-10-26, a labeled diagnostic that decides nothing).

`fetch` downloads chosen hours of chosen archive days for the coins of U (for the diagnostic, hours 0, 6, 12 and 18 of
every day outside stage 3's holdout window) and reduces each coin-hour file at once to per-snapshot costs per C0.7 cell (C0.7's own `walk_cost` on the 20-level book;
an order the 20 levels cannot fill is censored, never costed, since the archive lacks the aggregated book C0.7 falls
back to) and its mid prices. `report` puts each day in a volatility tercile per coin, by the realized volatility of
those mids, and by calendar quarter, and compares each cell with the frozen table. `equivalence` and `table` are stage 3's
revision of 2026-10-26: the archive checked against our live books, then a cost table fitted before the holdout.

Run it in the `cloud` dev shell, which holds boto3, lz4, numpy and polars.
"""

import bisect
import datetime as dt
import gzip
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np

from ingest.execution import QUANTILE, SIZES, calibrate_and_validate, walk_cost

BUCKET = "hyperliquid-archive"
HOURS = (0, 6, 12, 18)
SKIP = (dt.date(2026, 8, 1), dt.date(2026, 9, 30))  # stage 3's holdout, [start, end)
EQUIVALENCE = (dt.date(2026, 10, 19), dt.date(2026, 10, 25))  # the frozen check's days, [start, end)
TABLE = (dt.date(2026, 6, 1), dt.date(2026, 8, 1))  # the table's window, [start, end)
MATCH_MS, MATCHED, AGREE, SLOT_MS = 1_000, 0.5, 0.95, 30_000
HOUR = 3_600_000
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


def day_of(d):
    return dt.date(int(d[:4]), int(d[4:6]), int(d[6:]))


def fetch(out_dir, coins, hours=HOURS, window=None, client=None):
    """Reduce each chosen coin-hour into `out_dir`/<date>/<hour>/<coin>.json.gz (resumable: done files are skipped): the
    given hours of every archive day in `window` ([start, end) dates), or by default of every day outside SKIP."""
    import boto3
    import lz4.frame

    client = client or boto3.client("s3", region_name="us-east-1")
    out = Path(out_dir)
    for d in days(client):
        day = day_of(d)
        if (not window[0] <= day < window[1]) if window else SKIP[0] <= day < SKIP[1]:
            continue
        for h in hours:
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


def archived(out_dir, coin, window):
    """[(book time, {cell: cost})] of a coin's reduced archive snapshots on the days of `window`, by time."""
    rows = []
    for path in Path(out_dir).glob(f"*/*/{coin}.json.gz"):
        if window[0] <= day_of(path.parts[-3]) < window[1]:
            rows += [(t, costs) for t, _, costs in json.loads(gzip.decompress(path.read_bytes()))]
    return sorted(rows, key=lambda r: r[0])


def live(live_dirs, coins, window):
    """{coin: [(book time, {cell: cost})]} of every live L2 snapshot the recorders logged on the days of `window`,
    costed like the archive's, on the 20-level book alone."""
    out = defaultdict(list)
    for d in live_dirs:
        for path in sorted(Path(d).glob("polls-*.jsonl")):
            if not window[0] <= day_of(path.stem.split("-")[1]) < window[1]:
                continue
            for line in open(path):
                p = json.loads(line)
                if p["kind"] != "l2" or p["coin"] not in coins or not all(p["data"]["levels"]):
                    continue
                book = p["data"]
                mid = (float(book["levels"][0][0]["px"]) + float(book["levels"][1][0]["px"])) / 2
                out[p["coin"]].append((book["time"], {f"{side}:{size}": walk_cost(book, side, size, mid)
                                                      for side in ("buy", "sell") for size in SIZES}))
    return out


def agree(a, b):
    return abs(a - b) <= max(0.5, 0.1 * abs(b))


def equivalence(archive_dir, live_dirs, coins):
    """The frozen equivalence check (stage 3 revision of 2026-10-26): per coin, the share of its live snapshots matched
    to an archive snapshot within MATCH_MS of book time, over the hours both cover; per cell, among matched pairs, the
    share agreeing on censoring and, among pairs both costed (vacuously met when there are none: clarification of
    2026-10-26), on cost. It passes only if every coin and cell does."""
    recorded = live(live_dirs, coins, EQUIVALENCE)
    out = {}
    for coin in coins:
        arch = archived(archive_dir, coin, EQUIVALENCE)
        hours = {t // HOUR for t, _ in arch}
        snaps = [s for s in recorded.get(coin, []) if s[0] // HOUR in hours]
        times = [t for t, _ in arch]
        pairs = []
        for t, costs in snaps:
            i = bisect.bisect_left(times, t)
            near = min((j for j in (i - 1, i) if 0 <= j < len(times)), key=lambda j: abs(times[j] - t), default=None)
            if near is not None and abs(times[near] - t) <= MATCH_MS:
                pairs.append((costs, arch[near][1]))
        cells = {}
        for cell in (snaps[0][1] if snaps else {}):
            both = [(l[cell], a[cell]) for l, a in pairs]
            censoring = float(np.mean([math.isinf(x) == math.isinf(y) for x, y in both])) if both else 0.0
            costed = [(x, y) for x, y in both if math.isfinite(x) and math.isfinite(y)]
            cost = float(np.mean([agree(y, x) for x, y in costed])) if costed else 1.0
            cells[cell] = {"pairs": len(both), "censoring_agree": censoring, "costed": len(costed), "cost_agree": cost,
                           "pass": censoring >= AGREE and cost >= AGREE}
        matched = len(pairs) / len(snaps) if snaps else 0.0
        out[coin] = {"live": len(snaps), "matched": len(pairs), "matched_share": matched, "cells": cells,
                     "pass": matched >= MATCHED and bool(cells) and all(c["pass"] for c in cells.values())}
    return {"coins": out, "pass": all(c["pass"] for c in out.values())}


def table(archive_dir, coins, c07=REPO / "venue/hyperliquid/execution.json"):
    """Stage 3's cost table: C0.7's procedure on the archive's books in TABLE, one snapshot per SLOT_MS slot (the first),
    with every cell censored in any snapshot of the window keeping C0.7's value."""
    frozen = json.loads(Path(c07).read_text())["cost_bps_ex_fee"]
    cells, kept = {}, []
    for coin in coins:
        slots = {}
        for t, costs in archived(archive_dir, coin, TABLE):
            slots.setdefault(t // SLOT_MS, (t, costs))
        rows = [slots[k] for k in sorted(slots)]
        for side in ("buy", "sell"):
            for size in SIZES:
                c = np.array([costs[f"{side}:{size}"] for _, costs in rows])
                if not len(c) or not np.isfinite(c).all():
                    kept.append(f"{coin}:{side}:{size}")
                else:
                    cells[(coin, side, size)] = ([t for t, _ in rows], c)
    model, validation = calibrate_and_validate(cells)
    for k in kept:
        coin, side, size = k.split(":")
        model.setdefault(coin, {}).setdefault(side, {})[size] = frozen[coin][side][size]
    return {"window": [str(TABLE[0]), str(TABLE[1])], "slot_ms": SLOT_MS, "cost_bps_ex_fee": model,
            "kept_from_c07": kept, "validation": validation}


def main(step):
    """`python -m ingest.archive STEP` in the cloud shell, after stage 0 is committed: `equivalence` (fetch the check's
    hours, then judge), `table` (fetch the window, then fit; only after the check passed), `diagnostic` (fetch the
    sampled hours, then report). Outputs go to audit/stage3/ and audit/diagnostics/."""
    coins = json.loads((REPO / "data/universe.json").read_text())["universe"]
    oci = sorted((REPO / "data/live-oci").glob("*/live"))
    store = REPO / "data/archive"
    if step == "equivalence":
        fetch(store / "equivalence", coins, range(24), EQUIVALENCE)
        out, path = equivalence(store / "equivalence", [REPO / "data/live", *oci], coins), REPO / "audit/stage3/archive-equivalence.json"
    elif step == "table":
        check = json.loads((REPO / "audit/stage3/archive-equivalence.json").read_text())
        if not check["pass"]:
            raise SystemExit("the equivalence check failed: the revision lapsed, and stage 3 keeps C0.7's table")
        fetch(store / "table", coins, range(24), TABLE)
        out, path = table(store / "table", coins), REPO / "audit/stage3/archive-cost-table.json"
    else:
        fetch(store / "diagnostic", coins)
        out, path = report(store / "diagnostic"), REPO / "audit/diagnostics/c07-regimes.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(out, indent=1) + "\n")
    print(path)


if __name__ == "__main__":
    import sys

    main(sys.argv[1])
