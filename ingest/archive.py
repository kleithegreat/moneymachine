"""Hyperliquid's requester-pays book archive: raw files, snapshots and bars (ingest/ARCHIVE.md)."""

import datetime as dt
import json
from concurrent.futures import ThreadPoolExecutor
from collections.abc import Iterable, Sequence
from pathlib import Path
from typing import Any, Protocol

import lz4.frame  # type: ignore[import-untyped]
import polars as pl
from botocore.exceptions import ClientError  # type: ignore[import-untyped]

BUCKET = "hyperliquid-archive"
FORWARD_WINDOW = (dt.date(2026, 11, 1), dt.date(2027, 1, 31))
DOLLARS_PER_GB = 0.09
DOLLARS_PER_GET = 0.0004 / 1000
DOLLARS_PER_LIST = 0.005 / 1000
WORKERS = 16
DAY_MS = 86_400_000
LEVELS = ("bid_px", "bid_sz", "ask_px", "ask_sz")


class Refused(Exception):
    pass


class S3Client(Protocol):
    def list_objects_v2(self, **kwargs: Any) -> dict[str, Any]: ...

    def get_object(self, **kwargs: Any) -> dict[str, Any]: ...


def _utc(ms: int) -> dt.datetime:
    return dt.datetime.fromtimestamp(ms / 1000, dt.UTC)


def _refuse_window(first: dt.date, last: dt.date) -> None:
    """Refuse a range of days [first, last) that touches the forward window (CLAUDE.md, Holdout)."""
    window_start, window_end = FORWARD_WINDOW
    if first < window_end and last > window_start:
        raise Refused(f"range {first}..{last} touches the forward window [{window_start}, {window_end})")


def _key(day: dt.date, hour: int, coin: str) -> str:
    return f"market_data/{day:%Y%m%d}/{hour}/l2Book/{coin}.lz4"


def _raw_path(root: Path, day: dt.date, hour: int, coin: str) -> Path:
    return root / "hl-archive" / "raw" / f"{day:%Y%m%d}" / str(hour) / f"{coin}.lz4"


def _snapshot_path(root: Path, coin: str, day: dt.date) -> Path:
    return root / "hl-archive" / "snapshots" / coin / f"{day:%Y%m%d}.parquet"


def _append(path: Path, fields: Sequence[object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as out:
        out.write("\t".join(str(x) for x in fields) + "\n")


def parse(path: Path) -> pl.DataFrame:
    """Snapshots of one raw coin-hour file, sorted and deduplicated by time; a pure function of the bytes."""
    text = lz4.frame.decompress(path.read_bytes()).decode()
    columns: dict[str, list[Any]] = {"time": [], "mid": [], **{name: [] for name in LEVELS}}
    for raw_line in text.splitlines():
        if not raw_line:
            continue
        book = json.loads(raw_line)["raw"]["data"]
        bids, asks = book["levels"]
        if not bids or not asks:
            continue
        columns["time"].append(book["time"])
        columns["bid_px"].append([float(x["px"]) for x in bids])
        columns["bid_sz"].append([float(x["sz"]) for x in bids])
        columns["ask_px"].append([float(x["px"]) for x in asks])
        columns["ask_sz"].append([float(x["sz"]) for x in asks])
        columns["mid"].append((float(bids[0]["px"]) + float(asks[0]["px"])) / 2)
    schema = {
        "time": pl.Int64,
        "bid_px": pl.List(pl.Float64),
        "bid_sz": pl.List(pl.Float64),
        "ask_px": pl.List(pl.Float64),
        "ask_sz": pl.List(pl.Float64),
        "mid": pl.Float64,
    }
    return pl.DataFrame(columns, schema=schema).sort("time").unique("time", keep="first", maintain_order=True)


def _download(client: S3Client, key: str, path: Path) -> str | None:
    """Fetch one key into `path` atomically; the S3 error code on failure."""
    try:
        body = client.get_object(Bucket=BUCKET, Key=key, RequestPayer="requester")["Body"].read()
    except ClientError as error:
        code: str = error.response["Error"]["Code"]
        return code
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_suffix(".part")
    partial.write_bytes(body)
    partial.rename(path)
    return None


def _write_snapshots(root: Path, coin: str, day: dt.date, hours: Iterable[int]) -> None:
    files = [p for p in (_raw_path(root, day, h, coin) for h in hours) if p.exists()]
    if not files:
        return
    frame = pl.concat([parse(p) for p in files]).sort("time").unique("time", keep="first", maintain_order=True)
    path = _snapshot_path(root, coin, day)
    path.parent.mkdir(parents=True, exist_ok=True)
    frame.write_parquet(path)


def fetch(
    start: dt.date,
    end: dt.date,
    coins: Sequence[str],
    root: Path,
    client: S3Client,
    hours: Sequence[int] = tuple(range(24)),
    max_dollars: float = 1.0,
) -> None:
    """Fetch the raw coin-hours of days [start, end) not yet on disk, then rebuild their snapshots."""
    _refuse_window(start, end)
    days = [start + dt.timedelta(days=i) for i in range((end - start).days)]
    wanted = [(d, h, c) for d in days for h in hours for c in coins if not _raw_path(root, d, h, c).exists()]
    wanted_keys = {_key(*w) for w in wanted}
    listed: dict[str, int] = {}
    list_calls = 0
    for day in sorted({d for d, _, _ in wanted}):
        token: str | None = None
        while True:
            extra = {"ContinuationToken": token} if token else {}
            page = client.list_objects_v2(
                Bucket=BUCKET, Prefix=f"market_data/{day:%Y%m%d}/", RequestPayer="requester", **extra
            )
            list_calls += 1
            listed.update({x["Key"]: x["Size"] for x in page.get("Contents", []) if x["Key"] in wanted_keys})
            if not page.get("IsTruncated"):
                break
            token = page["NextContinuationToken"]
    missing_path = root / "hl-archive" / "missing.tsv"
    for key in sorted(wanted_keys - listed.keys()):
        _append(missing_path, [key, "NotListed"])
    size = sum(listed.values())
    estimate = size / 1e9 * DOLLARS_PER_GB + len(listed) * DOLLARS_PER_GET + list_calls * DOLLARS_PER_LIST
    print(f"{len(listed)} files, {size} bytes, {list_calls} lists, estimated ${estimate:.4f} (limit ${max_dollars})")
    refused = estimate > max_dollars
    stamp = dt.datetime.now(dt.UTC).isoformat(timespec="seconds")
    spend = [stamp, len(listed), size, f"{estimate:.4f}", *(["refused"] if refused else [])]
    _append(root / "hl-archive" / "spend.tsv", spend)
    fresh: set[tuple[str, dt.date]] = set()
    if not refused:
        found = [w for w in wanted if _key(*w) in listed]
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            codes = list(pool.map(lambda w: _download(client, _key(*w), _raw_path(root, w[0], w[1], w[2])), found))
        for (day, hour, coin), code in zip(found, codes, strict=True):
            if code is None:
                fresh.add((coin, day))
            else:
                _append(missing_path, [_key(day, hour, coin), code])
    for day in days:
        for coin in coins:
            if (coin, day) in fresh or not _snapshot_path(root, coin, day).exists():
                _write_snapshots(root, coin, day, hours)


def bars(coin: str, start_ms: int, end_ms: int, interval_ms: int, root: Path) -> pl.DataFrame:
    """One row per whole interval [t, t + interval) in [start_ms, end_ms); empty intervals hold nulls."""
    if interval_ms < 1000:
        raise ValueError(f"interval {interval_ms} ms is under one second")
    first_day = _utc(start_ms).date()
    last_day = _utc(end_ms - 1).date()
    _refuse_window(first_day, last_day + dt.timedelta(days=1))
    paths = [
        _snapshot_path(root, coin, first_day + dt.timedelta(days=i)) for i in range((last_day - first_day).days + 1)
    ]
    frames = [pl.read_parquet(p, columns=["time", "mid", "bid_px", "ask_px"]) for p in paths if p.exists()]
    count = (end_ms - start_ms) // interval_ms
    grid = pl.DataFrame({"index": range(count)}, schema={"index": pl.Int64}).with_columns(
        t=start_ms + pl.col("index") * interval_ms
    )
    if not frames:
        snapshots = pl.DataFrame(
            schema={"time": pl.Int64, "mid": pl.Float64, "bid_px": pl.List(pl.Float64), "ask_px": pl.List(pl.Float64)}
        )
    else:
        snapshots = pl.concat(frames)
    aggregated = (
        snapshots.filter(pl.col("time").is_between(start_ms, start_ms + count * interval_ms, closed="left"))
        .sort("time")
        .group_by(((pl.col("time") - start_ms) // interval_ms).alias("index"))
        .agg(
            open=pl.col("mid").first(),
            high=pl.col("mid").max(),
            low=pl.col("mid").min(),
            close=pl.col("mid").last(),
            bid=pl.col("bid_px").last().list.first(),
            ask=pl.col("ask_px").last().list.first(),
            snapshots=pl.len(),
        )
    )
    return (
        grid.join(aggregated, on="index", how="left")
        .with_columns(pl.col("snapshots").fill_null(0), known_at=pl.col("t") + interval_ms)
        .select("t", "open", "high", "low", "close", "bid", "ask", "snapshots", "known_at")
        .sort("t")
    )


def main(
    start: str, end: str, coins: Sequence[str], hours: Sequence[int] | None = None, max_dollars: float | None = None
) -> None:
    import boto3  # type: ignore[import-untyped]

    client = boto3.Session().client("s3", region_name="us-east-1")
    root = Path(__file__).resolve().parents[1] / "data"
    options: dict[str, Any] = {}
    if hours is not None:
        options["hours"] = hours
    if max_dollars is not None:
        options["max_dollars"] = max_dollars
    fetch(dt.date.fromisoformat(start), dt.date.fromisoformat(end), coins, root, client, **options)
