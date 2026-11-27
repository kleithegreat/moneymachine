"""Adapter ingesting Hyperliquid L2 Parquet archives and WS JSONL recordings into the fabric."""

from __future__ import annotations

import io
import json
import math
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pyarrow.parquet as pq
import zstandard as zstd

from fabric.cas import CASStore
from fabric.catalog import FabricCatalog, canonical_uuid


def _ms_to_utc(ms: int) -> datetime:
    return datetime.fromtimestamp(ms / 1000.0, tz=UTC)


def _first_level(levels: Any) -> tuple[float | None, float | None]:
    if isinstance(levels, (list, tuple)) and levels:
        first = levels[0]
        if isinstance(first, (int, float)):
            return float(first), None
        if isinstance(first, dict):
            px = first.get("px")
            sz = first.get("sz")
            return (float(px) if px is not None else None, float(sz) if sz is not None else None)
    return None, None


def _obs_exists(catalog: FabricCatalog, obs_id: str) -> bool:
    row = catalog.conn.execute(
        "SELECT 1 FROM core.fact_observations WHERE obs_id = CAST(? AS UUID)", [obs_id]
    ).fetchone()
    return row is not None


def _emit_tick_metrics(
    catalog: FabricCatalog,
    *,
    entity_id: str,
    source_id: str,
    license_class: str,
    raw_hash: str,
    time_ms: int,
    known_lag_ms: int,
    mid: float | None,
    bid_px: float | None,
    bid_sz: float | None,
    ask_px: float | None,
    ask_sz: float | None,
) -> int:
    event_ts = _ms_to_utc(time_ms)
    known_ts = _ms_to_utc(time_ms + max(0, known_lag_ms))
    metrics: list[tuple[str, float, str]] = []
    if mid is not None and math.isfinite(mid):
        metrics.append(("mid_px", float(mid), "USD"))
    if bid_px is not None and math.isfinite(bid_px):
        metrics.append(("best_bid_px", float(bid_px), "USD"))
    if ask_px is not None and math.isfinite(ask_px):
        metrics.append(("best_ask_px", float(ask_px), "USD"))
    if bid_sz is not None and math.isfinite(bid_sz):
        metrics.append(("top_bid_sz", float(bid_sz), "BASE"))
    if ask_sz is not None and math.isfinite(ask_sz):
        metrics.append(("top_ask_sz", float(ask_sz), "BASE"))
    if bid_px is not None and ask_px is not None and mid is not None and mid > 0.0:
        spread_bps = ((ask_px - bid_px) / mid) * 10_000.0
        if math.isfinite(spread_bps):
            metrics.append(("spread_bps", spread_bps, "BPS"))

    written = 0
    for metric_name, val, unit in metrics:
        oid = canonical_uuid("obs", entity_id, source_id, metric_name, event_ts.isoformat(), known_ts.isoformat(), "1")
        if _obs_exists(catalog, oid):
            continue
        catalog.add_observation(
            obs_id=oid,
            entity_id=entity_id,
            source_id=source_id,
            metric=metric_name,
            value_num=val,
            unit=unit,
            event_time=event_ts,
            known_at=known_ts,
            license_class=license_class,
            raw_hash=raw_hash,
        )
        written += 1
    return written


def ingest_archive_parquet(
    parquet_path: Path | str,
    *,
    cas: CASStore,
    catalog: FabricCatalog,
    coin: str | None = None,
    known_lag_ms: int = 0,
    stride: int = 1,
    source_id: str = "hyperliquid_l2_archive",
    license_class: str = "PERSONAL_RESEARCH",
) -> dict[str, int]:
    """Ingest a Hyperliquid `snapshots/<COIN>/<YYYYMMDD>.parquet` file into CAS + DuckDB."""
    path = Path(parquet_path)
    if stride < 1:
        raise ValueError(f"stride must be >= 1, got {stride}")
    symbol = (coin or path.parent.name).upper()

    raw_bytes = path.read_bytes()
    cas_rec = cas.put(raw_bytes)
    table = pq.read_table(io.BytesIO(raw_bytes))
    rows = table.to_pylist()
    if not rows:
        return {"rows": 0, "observations": 0}

    last_ms = max(int(row["time"]) for row in rows)
    catalog.record_artifact(cas_rec, source_id=source_id, license_class=license_class, ingested_at=_ms_to_utc(last_ms))
    entity_id = catalog.upsert_entity(
        entity_type="CRYPTO_ASSET",
        canonical_name=symbol,
        external_ids={"symbol": symbol, "venue": "hyperliquid"},
        updated_at=_ms_to_utc(last_ms),
    )

    obs_count = 0
    sampled_rows = 0
    for row in rows[::stride]:
        time_ms = int(row["time"])
        bid_px, _ = _first_level(row.get("bid_px"))
        bid_sz, _ = _first_level(row.get("bid_sz"))
        ask_px, _ = _first_level(row.get("ask_px"))
        ask_sz, _ = _first_level(row.get("ask_sz"))
        mid_raw = row.get("mid")
        mid = (
            float(mid_raw)
            if mid_raw is not None
            else (0.5 * (bid_px + ask_px) if (bid_px is not None and ask_px is not None) else None)
        )
        obs_count += _emit_tick_metrics(
            catalog,
            entity_id=entity_id,
            source_id=source_id,
            license_class=license_class,
            raw_hash=cas_rec.sha256,
            time_ms=time_ms,
            known_lag_ms=known_lag_ms,
            mid=mid,
            bid_px=bid_px,
            bid_sz=bid_sz,
            ask_px=ask_px,
            ask_sz=ask_sz,
        )
        sampled_rows += 1
    return {"rows": sampled_rows, "observations": obs_count}


def _read_jsonl_bytes(path: Path) -> bytes:
    raw = path.read_bytes()
    if path.suffix == ".zst":
        dctx = zstd.ZstdDecompressor()
        with dctx.stream_reader(io.BytesIO(raw)) as reader:
            return reader.read()
    return raw


def ingest_ws_jsonl(
    jsonl_path: Path | str,
    *,
    cas: CASStore,
    catalog: FabricCatalog,
    default_coin: str | None = None,
    known_lag_ms: int = 0,
    stride: int = 1,
    source_id: str = "hyperliquid_ws_l2",
    license_class: str = "PERSONAL_RESEARCH",
) -> dict[str, int]:
    """Ingest Hyperliquid WebSocket `.jsonl` / `.jsonl.zst` tick messages into CAS + DuckDB."""
    path = Path(jsonl_path)
    if stride < 1:
        raise ValueError(f"stride must be >= 1, got {stride}")
    payload_bytes = _read_jsonl_bytes(path)
    lines = [line for line in payload_bytes.decode("utf-8", errors="replace").splitlines() if line.strip()]
    if not lines:
        return {"rows": 0, "observations": 0}

    cas_rec = cas.put(payload_bytes)
    entity_cache: dict[str, str] = {}
    parsed: list[dict[str, Any]] = []
    for raw_line in lines:
        try:
            obj = json.loads(raw_line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and "time" in obj:
            parsed.append(obj)
    if not parsed:
        return {"rows": 0, "observations": 0}

    max_ms = max(int(row["time"]) for row in parsed)
    catalog.record_artifact(cas_rec, source_id=source_id, license_class=license_class, ingested_at=_ms_to_utc(max_ms))

    obs_count = 0
    sampled = 0
    for row in parsed[::stride]:
        symbol = str(row.get("coin") or default_coin or path.parent.name).upper()
        entity_id = entity_cache.get(symbol)
        if entity_id is None:
            entity_id = catalog.upsert_entity(
                entity_type="CRYPTO_ASSET",
                canonical_name=symbol,
                external_ids={"symbol": symbol, "venue": "hyperliquid"},
                updated_at=_ms_to_utc(int(row["time"])),
            )
            entity_cache[symbol] = entity_id

        levels = row.get("levels")
        if isinstance(levels, list) and len(levels) == 2:
            bid_px, bid_sz = _first_level(levels[0])
            ask_px, ask_sz = _first_level(levels[1])
        else:
            bid_px, _ = _first_level(row.get("bid_px"))
            bid_sz, _ = _first_level(row.get("bid_sz"))
            ask_px, _ = _first_level(row.get("ask_px"))
            ask_sz, _ = _first_level(row.get("ask_sz"))
        mid_raw = row.get("mid")
        mid = (
            float(mid_raw)
            if mid_raw is not None
            else (0.5 * (bid_px + ask_px) if (bid_px is not None and ask_px is not None) else None)
        )
        obs_count += _emit_tick_metrics(
            catalog,
            entity_id=entity_id,
            source_id=source_id,
            license_class=license_class,
            raw_hash=cas_rec.sha256,
            time_ms=int(row["time"]),
            known_lag_ms=known_lag_ms,
            mid=mid,
            bid_px=bid_px,
            bid_sz=bid_sz,
            ask_px=ask_px,
            ask_sz=ask_sz,
        )
        sampled += 1
    return {"rows": sampled, "observations": obs_count}


def ingest_hyperliquid_path(
    input_path: Path | str,
    *,
    cas: CASStore,
    catalog: FabricCatalog,
    coin: str | None = None,
    known_lag_ms: int = 0,
    stride: int = 1,
) -> dict[str, int]:
    """Ingest a Hyperliquid Parquet/JSONL file or walk a directory tree of recordings."""
    root = Path(input_path)
    files = [root] if root.is_file() else sorted(p for p in root.rglob("*") if p.is_file())
    total = {"files": 0, "rows": 0, "observations": 0}
    for file_path in files:
        if file_path.suffix == ".parquet":
            res = ingest_archive_parquet(
                file_path, cas=cas, catalog=catalog, coin=coin, known_lag_ms=known_lag_ms, stride=stride
            )
        elif file_path.suffix == ".jsonl" or file_path.name.endswith(".jsonl.zst"):
            res = ingest_ws_jsonl(
                file_path, cas=cas, catalog=catalog, default_coin=coin, known_lag_ms=known_lag_ms, stride=stride
            )
        else:
            continue
        total["files"] += 1
        total["rows"] += res["rows"]
        total["observations"] += res["observations"]
    return total
