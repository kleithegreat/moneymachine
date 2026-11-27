"""Adapter exporting PIT-safe PodViews into verified `kernel2` A18 Bar Markets."""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pyarrow as pa
import pyarrow.parquet as pq

from fabric.catalog import FabricCatalog, ensure_utc
from fabric.views import PodView


@dataclass(frozen=True)
class Kernel2CoinSpec:
    """Registration-fixed coin specification matching `kernel2` A18 `header.json` rules."""

    name: str
    entity_id: str
    sz_decimals: int = 4
    figures: int = 5
    decimals: int = 2
    max_leverage: int = 20
    metric: str = "mid_px"


@dataclass(frozen=True)
class Kernel2ExportResult:
    """Paths and causal metadata produced by `export_kernel2_bar_market`."""

    output_dir: Path
    header_path: Path
    parquet_paths: dict[str, Path]
    coin_bar_counts: dict[str, int]
    as_of_utc: str
    pod_id: str
    observation_sources: list[str] = field(default_factory=list)


def _to_ms(ts: datetime) -> int:
    return int(round(ts.timestamp() * 1000))


def _bucket_bars(
    rows: Sequence[dict[str, Any]],
    *,
    start_ms: int,
    end_ms: int,
    bar_span_ms: int,
) -> list[dict[str, Any]]:
    buckets: dict[int, list[float]] = {}
    for row in rows:
        val = row["value_num"]
        if val is None:
            continue
        et_ms = _to_ms(row["event_time"])
        if et_ms < start_ms or et_ms > end_ms:
            continue
        bucket_close = ((et_ms - start_ms) // bar_span_ms) * bar_span_ms + start_ms
        if bucket_close < start_ms:
            continue
        buckets.setdefault(bucket_close, []).append(float(val))

    bars: list[dict[str, Any]] = []
    for close_ms in sorted(buckets):
        vals = buckets[close_ms]
        bars.append(
            {
                "time": close_ms,
                "open": vals[0],
                "high": max(vals),
                "low": min(vals),
                "close": vals[-1],
                "volume": float(len(vals)),
            }
        )
    return bars


def _write_bar_parquet(path: Path, bars: Sequence[dict[str, Any]]) -> None:
    schema = pa.schema(
        [
            pa.field("time", pa.int64()),
            pa.field("open", pa.float64()),
            pa.field("high", pa.float64()),
            pa.field("low", pa.float64()),
            pa.field("close", pa.float64()),
            pa.field("volume", pa.float64()),
        ]
    )
    table = pa.Table.from_pylist(list(bars), schema=schema)
    pq.write_table(table, path)


def export_kernel2_bar_market(
    catalog: FabricCatalog,
    output_dir: Path | str,
    *,
    coins: Sequence[Kernel2CoinSpec],
    start_utc: datetime | str,
    end_utc: datetime | str,
    as_of_utc: datetime | str,
    pod_view: PodView | None = None,
    bar_span_ms: int = 60_000,
    stale_ms: int | None = None,
    cash: str = "100000",
    half_spread: str = "0.0005",
    depth: str = "100000",
    maker_fee: str = "0.00015",
    taker_fee: str = "0.00045",
    fill_mode: str = "pessimistic",
    extra_observation_metrics: Sequence[tuple[str, str, str, int]] = (),
) -> Kernel2ExportResult:
    """Export a leak-free PIT slice of `FabricCatalog` to a `kernel2` A18 Bar Market directory."""
    start_ts = ensure_utc(start_utc)
    end_ts = ensure_utc(end_utc)
    as_of_ts = ensure_utc(as_of_utc)
    if end_ts > as_of_ts:
        raise ValueError(f"end_utc {end_ts.isoformat()} exceeds as_of_utc {as_of_ts.isoformat()}")
    if start_ts >= end_ts:
        raise ValueError(f"start_utc {start_ts.isoformat()} must precede end_utc {end_ts.isoformat()}")
    if bar_span_ms <= 0:
        raise ValueError(f"bar_span_ms must be > 0, got {bar_span_ms}")

    effective_stale = stale_ms if stale_ms is not None else 2 * bar_span_ms
    if not (bar_span_ms < effective_stale <= 2 * bar_span_ms):
        raise ValueError(f"A18 requires bar_span_ms < stale_ms <= 2 * bar_span_ms, got {effective_stale}")

    out_root = Path(output_dir)
    out_root.mkdir(parents=True, exist_ok=True)
    start_ms = _to_ms(start_ts)
    end_ms = _to_ms(end_ts)

    parquet_paths: dict[str, Path] = {}
    coin_bar_counts: dict[str, int] = {}
    coin_entries: list[dict[str, Any]] = []

    for spec in coins:
        if spec.sz_decimals > 6 or spec.figures < 1 or spec.decimals > 8:
            raise ValueError(f"invalid A18 coin precision constraints on {spec.name}")
        pit_rows = catalog.pit_latest(
            as_of_ts, pod_view=pod_view, entity_id=spec.entity_id, metric=spec.metric, polarity="OBS"
        )
        bars = _bucket_bars(pit_rows, start_ms=start_ms, end_ms=end_ms, bar_span_ms=bar_span_ms)
        bar_path = out_root / f"{spec.name}.parquet"
        _write_bar_parquet(bar_path, bars)
        parquet_paths[spec.name] = bar_path
        coin_bar_counts[spec.name] = len(bars)
        coin_entries.append(
            {
                "name": spec.name,
                "sz_decimals": spec.sz_decimals,
                "figures": spec.figures,
                "decimals": spec.decimals,
                "tiers": [{"from": "0", "max_leverage": spec.max_leverage}],
            }
        )

    obs_specs: list[dict[str, Any]] = []
    obs_names: list[str] = []
    for entity_id, metric_name, unit, lag_ms in extra_observation_metrics:
        obs_rows = catalog.pit_latest(
            as_of_ts, pod_view=pod_view, entity_id=entity_id, metric=metric_name, polarity="OBS"
        )
        obs_path = out_root / f"obs_{metric_name}.parquet"
        obs_records = [
            {"time": _to_ms(r["event_time"]), "value": float(r["value_num"])}
            for r in obs_rows
            if r["value_num"] is not None and start_ms <= _to_ms(r["event_time"]) <= end_ms
        ]
        obs_schema = pa.schema([pa.field("time", pa.int64()), pa.field("value", pa.float64())])
        pq.write_table(pa.Table.from_pylist(obs_records, schema=obs_schema), obs_path)
        parquet_paths[f"obs:{metric_name}"] = obs_path
        obs_specs.append({"name": metric_name, "unit": unit, "kind": "state", "lag": lag_ms})
        obs_names.append(metric_name)

    header: dict[str, Any] = {
        "horizon": {"start": start_ms, "end": end_ms},
        "venue": {
            "fill": fill_mode,
            "lambda": 0,
            "delta": bar_span_ms,
            "stale": effective_stale,
            "cap": "1000000",
            "minimum": "10",
        },
        "cash": cash,
        "coins": coin_entries,
        "fees": [{"from": start_ms, "tier": "base", "maker": maker_fee, "taker": taker_fee}],
        "sources": {
            "listings": {"lag": 0},
            "funding": {"encoding": "string", "lag": bar_span_ms, "late": 2 * bar_span_ms},
            "bars": {"span": bar_span_ms, "half_spread": half_spread, "depth": depth},
            "observations": obs_specs,
        },
        "aliases": {"coins": {c.name: c.entity_id for c in coins}, "sources": {}},
        "exported_at": datetime.now(UTC).isoformat(),
        "as_of_utc": as_of_ts.isoformat(),
    }
    header_path = out_root / "header.json"
    header_path.write_text(json.dumps(header, indent=2, sort_keys=False) + "\n")

    return Kernel2ExportResult(
        output_dir=out_root,
        header_path=header_path,
        parquet_paths=parquet_paths,
        coin_bar_counts=coin_bar_counts,
        as_of_utc=as_of_ts.isoformat(),
        pod_id=pod_view.pod_id if pod_view is not None else "default",
        observation_sources=obs_names,
    )
