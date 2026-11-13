# The Hyperliquid book archive: reader and bars

A spec for an independent implementer. The source is `venue/sources.toml` `[hyperliquid-archive]`: requester-pays S3, read with the human's AWS profile, its spending approved up to $20 in total (2026-10-26). It feeds kernel version 2 and study 2, the replication (`audit/program/architecture.md` on `rearchitecture`, revision 4, section 6). Nothing here is judged.

## What it does

1. **Fetch** the raw coin-hour book files for chosen coins and a date range:
   - the keys are `s3://hyperliquid-archive/market_data/<YYYYMMDD>/<hour>/l2Book/<COIN>.lz4`, read with `RequestPayer=requester`;
   - files are kept verbatim under `data/hl-archive/raw/<YYYYMMDD>/<hour>/<COIN>.lz4`;
   - a file already present is not fetched again.
2. **Parse** each raw file, JSON lines `{"time", "ver_num", "raw": {"channel": "l2Book", "data": {"coin", "time", "levels"}}}`, into a Parquet table of snapshots per coin and day, under `data/hl-archive/snapshots/<COIN>/<YYYYMMDD>.parquet`. Columns:
   - `time`, ms, the book's `data.time`;
   - `bid_px` and `bid_sz`, `ask_px` and `ask_sz`, as lists of the 20 levels, best first;
   - `mid`.
3. **Bars** of any interval of at least one second, from the snapshots of one coin over a range, built on demand and not stored. One row per interval `[t, t + interval)`:
   - `open`, `high`, `low` and `close` of the mid;
   - `bid` and `ask` at the bar's last snapshot;
   - `snapshots`, the count;
   - `known_at = t + interval`.

   An interval with no snapshot gives a row with null prices and `snapshots = 0`, never a carried-forward price.

## Rules

- **The forward window is never fetched or read.** A range that touches [2026-11-01, 2027-01-31) is refused before any request (CLAUDE.md, Holdout). The refusal names the window.
- **Cost guard.** Before any download, the fetch lists the keys, sums their sizes, and prints the bytes and the estimated cost at $0.09 per GB plus $0.0004 per 1,000 GETs. It downloads only if the estimate is at most `--max-dollars`, which defaults to 1. Each run appends one line to `data/hl-archive/spend.tsv`: UTC time, files, bytes, estimate.
- **Missing data is recorded, never filled.** A missing coin-hour is a row in `data/hl-archive/missing.tsv`: the key and the S3 error code. It is not retried silently.
- **Raw files are append-only.** Nothing deletes or rewrites a raw file. Parsing is a pure function of the raw bytes, so snapshots can always be rebuilt.
- **A snapshot table is a function of every raw hour on disk for its coin and day.** A fetch rebuilds any table whose source hours differ from the raw hours now on disk, whatever that run downloaded: a run killed between its downloads and its tables leaves no stale table behind.
- **`missing.tsv` holds each missing key once,** however many runs find it missing.
- **Snapshots are sorted** by `time` and deduplicated on it.

## Interface

- **`python -m cli archive-fetch <start YYYY-MM-DD> <end YYYY-MM-DD, exclusive> <COIN>... [--hours 0-23] [--max-dollars X]`:** fetch, then parse.
- **`ingest.archive.bars(coin: str, start_ms: int, end_ms: int, interval_ms: int, root: Path) -> polars.DataFrame`.**
- **Where it runs:** `boto3` and `lz4` join the dev shell in `flake.nix`.
- **Tests run offline:** they inject a fake S3 client and synthetic `.lz4` files.

## The behaviour its tests must show

1. A range touching the forward window is refused before any S3 call.
2. An estimate above `--max-dollars` downloads nothing, and still writes its spend line marked `refused`.
3. A second fetch of the same range makes no GET for a file present on disk.
4. Parsing a synthetic file gives the right best levels and mid, sorted and deduplicated by time.
5. Bars:
   - known snapshots give the hand-computed OHLC;
   - an empty interval gives nulls and `snapshots = 0`;
   - `known_at` is the interval's end;
   - bars at one interval agree with bars aggregated from a finer one, wherever both have data.
6. A missing key is recorded in `missing.tsv` and the run continues.
7. The code passes `mypy --strict` and `ruff`.
