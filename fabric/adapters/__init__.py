"""Adapters bridging existing moneymachine pipelines and verified execution into the data fabric."""

from fabric.adapters.datalayer_bridge import ingest_datalayer
from fabric.adapters.hyperliquid_bridge import ingest_archive_parquet, ingest_hyperliquid_path, ingest_ws_jsonl
from fabric.adapters.kernel2_pod import Kernel2CoinSpec, Kernel2ExportResult, export_kernel2_bar_market

__all__ = [
    "Kernel2CoinSpec",
    "Kernel2ExportResult",
    "export_kernel2_bar_market",
    "ingest_archive_parquet",
    "ingest_datalayer",
    "ingest_hyperliquid_path",
    "ingest_ws_jsonl",
]
