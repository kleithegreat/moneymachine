"""Round-trip tests for `datalayer`, `hyperliquid`, and `kernel2` fabric adapters."""

from __future__ import annotations

import gzip
import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from fabric.adapters import (
    Kernel2CoinSpec,
    export_kernel2_bar_market,
    ingest_archive_parquet,
    ingest_datalayer,
    ingest_hyperliquid_path,
)
from fabric.cas import CASStore
from fabric.catalog import FabricCatalog


def test_datalayer_bridge_ingests_raw_gzip_and_tags_license(tmp_path: Path) -> None:
    live_dir = tmp_path / "live"
    raw_dir = live_dir / "raw"
    raw_dir.mkdir(parents=True)

    payload = json.dumps({"gdp": 2.4, "nested": {"cpi": 3.1}, "flag": True}).encode("utf-8")
    digest = hashlib.sha256(payload).hexdigest()
    (raw_dir / f"{digest}.gz").write_bytes(gzip.compress(payload))

    log_entry = {
        "feed": "bls-cpi",
        "url": "https://api.bls.gov/publicAPI/v2/timeseries/data/",
        "sent": "2026-05-01T12:00:00Z",
        "recv": "2026-05-01T12:00:02Z",
        "status": 200,
        "sha256": digest,
        "bytes": len(payload),
    }
    (live_dir / "fetch-20260501.jsonl").write_text(json.dumps(log_entry) + "\n")

    cas = CASStore(tmp_path / "fabric")
    with FabricCatalog() as cat:
        stats = ingest_datalayer(live_dir, cas=cas, catalog=cat)
        assert stats["records"] == 1
        assert stats["documents"] == 1
        assert stats["observations"] >= 3

        rows = cat.pit_latest("2026-05-01T12:01:00Z")
        by_metric = {r["metric"]: r["value_num"] for r in rows}
        assert by_metric["http_status"] == 200.0
        assert by_metric["gdp"] == pytest.approx(2.4)
        assert by_metric["nested.cpi"] == pytest.approx(3.1)
        assert rows[0]["license_class"] == "PUBLIC_DOMAIN"

        # Idempotent re-run skips duplicates cleanly
        stats2 = ingest_datalayer(live_dir, cas=cas, catalog=cat)
        assert stats2["documents"] == 0
        assert cat.audit_invariants(now="2026-05-01T12:05:00Z")["passed"] is True


def test_hyperliquid_bridge_and_kernel2_a18_export(tmp_path: Path) -> None:
    hl_dir = tmp_path / "snapshots" / "BTC"
    hl_dir.mkdir(parents=True)
    pq_file = hl_dir / "20260501.parquet"

    t0 = int(datetime(2026, 5, 1, 10, 0, tzinfo=UTC).timestamp() * 1000)
    rows = [
        {"time": t0, "bid_px": [99990.0], "bid_sz": [1.5], "ask_px": [100010.0], "ask_sz": [2.0], "mid": 100000.0},
        {
            "time": t0 + 30_000,
            "bid_px": [100090.0],
            "bid_sz": [1.0],
            "ask_px": [100110.0],
            "ask_sz": [1.5],
            "mid": 100100.0,
        },
        {
            "time": t0 + 60_000,
            "bid_px": [100190.0],
            "bid_sz": [1.2],
            "ask_px": [100210.0],
            "ask_sz": [1.8],
            "mid": 100200.0,
        },
    ]
    pq.write_table(pa.Table.from_pylist(rows), pq_file)

    ws_jsonl = tmp_path / "eth_ws.jsonl"
    ws_jsonl.write_text(
        json.dumps(
            {
                "coin": "ETH",
                "time": t0,
                "levels": [[{"px": "3000.0", "sz": "4.0"}], [{"px": "3002.0", "sz": "5.0"}]],
            }
        )
        + "\n"
    )

    cas = CASStore(tmp_path / "fabric")
    with FabricCatalog() as cat:
        res_btc = ingest_archive_parquet(pq_file, cas=cas, catalog=cat, known_lag_ms=50)
        assert res_btc["rows"] == 3
        res_walk = ingest_hyperliquid_path(tmp_path / "eth_ws.jsonl", cas=cas, catalog=cat, known_lag_ms=50)
        assert res_walk["files"] == 1
        assert res_walk["rows"] == 1

        btc_id = cat.upsert_entity(entity_type="CRYPTO_ASSET", canonical_name="BTC")
        k2_out = tmp_path / "k2_market"
        exported = export_kernel2_bar_market(
            cat,
            k2_out,
            coins=[Kernel2CoinSpec(name="BTC", entity_id=btc_id)],
            start_utc="2026-05-01T10:00:00Z",
            end_utc="2026-05-01T10:02:00Z",
            as_of_utc="2026-05-01T10:03:00Z",
            bar_span_ms=60_000,
        )
        assert exported.coin_bar_counts["BTC"] == 2
        header = json.loads(exported.header_path.read_text())
        assert header["venue"]["stale"] == 120_000
        assert header["sources"]["bars"]["span"] == 60_000
        btc_bars = pq.read_table(exported.parquet_paths["BTC"]).to_pylist()
        assert btc_bars[0]["open"] == pytest.approx(100000.0)
        assert btc_bars[0]["close"] == pytest.approx(100100.0)

        with pytest.raises(ValueError, match="exceeds as_of_utc"):
            export_kernel2_bar_market(
                cat,
                k2_out / "leaky",
                coins=[Kernel2CoinSpec(name="BTC", entity_id=btc_id)],
                start_utc="2026-05-01T10:00:00Z",
                end_utc="2026-05-01T10:05:00Z",
                as_of_utc="2026-05-01T10:03:00Z",
            )
