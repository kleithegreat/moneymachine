"""Unified CLI entry point for initializing, validating, auditing, and serving the data fabric."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any, cast

from fabric.adapters import ingest_datalayer, ingest_hyperliquid_path
from fabric.cas import CASStore
from fabric.catalog import FabricCatalog
from fabric.ledger import ForecastLedger
from fabric.manifest import load_all_manifests
from fabric.mcp_server import CausalFabricService, create_mcp_server
from fabric.search import PitSearchIndex
from fabric.views import BlindingMode, PodView

_DEFAULT_MANIFEST_DIR = Path(__file__).resolve().parent / "manifests"


def _paths(root: Path) -> tuple[Path, Path, Path]:
    return root / "catalog.duckdb", root / "tantivy", root / "ledger.sqlite"


def _cmd_init(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, index_dir, ledger_path = _paths(root)
    CASStore(root).base_dir.mkdir(parents=True, exist_ok=True)
    with FabricCatalog(catalog_path) as catalog:
        audit = catalog.audit_invariants()
    PitSearchIndex(index_dir)
    ledger = ForecastLedger(ledger_path)
    manifests = load_all_manifests(Path(args.manifests))
    summary = {
        "root": str(root.resolve()),
        "catalog": str(catalog_path),
        "search_index": str(index_dir),
        "ledger": str(ledger_path),
        "ledger_chain_valid": ledger.verify_chain(),
        "manifests_validated": sorted(manifests),
        "audit_passed": audit["passed"],
    }
    print(json.dumps(summary, indent=2))
    return 0


def _cmd_validate_manifests(args: argparse.Namespace) -> int:
    manifests = load_all_manifests(Path(args.manifests))
    payload = {
        "count": len(manifests),
        "sources": {
            sid: {
                "domain": m.domain,
                "modality": m.modality,
                "storage_tier": m.storage_tier,
                "temporal_semantics": m.temporal_semantics,
                "license_class": m.license_class,
            }
            for sid, m in manifests.items()
        },
    }
    print(json.dumps(payload, indent=2))
    return 0


def _cmd_status(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, _, ledger_path = _paths(root)
    with FabricCatalog(catalog_path) as catalog:
        audit = catalog.audit_invariants()
    ledger = ForecastLedger(ledger_path)
    payload: dict[str, Any] = {
        "root": str(root.resolve()),
        "counts": audit["counts"],
        "ledger": ledger.score_summary(),
        "ledger_chain_valid": ledger.verify_chain(),
    }
    print(json.dumps(payload, indent=2))
    return 0


def _cmd_audit(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, _, ledger_path = _paths(root)
    with FabricCatalog(catalog_path) as catalog:
        audit = catalog.audit_invariants(now=args.now)
    ledger = ForecastLedger(ledger_path)
    chain_valid = ledger.verify_chain()
    audit["ledger_chain_valid"] = chain_valid
    audit["passed"] = bool(audit["passed"] and chain_valid)
    print(json.dumps(audit, indent=2))
    return 0 if audit["passed"] else 1


def _cmd_ingest_datalayer(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, index_dir, _ = _paths(root)
    cas = CASStore(root)
    search_idx = PitSearchIndex(index_dir)
    with FabricCatalog(catalog_path) as catalog:
        stats = ingest_datalayer(
            Path(args.live_dir),
            cas=cas,
            catalog=catalog,
            prefix=args.prefix,
            feeds=args.feed,
            limit=args.limit,
            search_index=search_idx,
        )
    print(json.dumps(stats, indent=2))
    return 0


def _cmd_ingest_hl_ws(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, _, _ = _paths(root)
    cas = CASStore(root)
    with FabricCatalog(catalog_path) as catalog:
        stats = ingest_hyperliquid_path(
            Path(args.input),
            cas=cas,
            catalog=catalog,
            coin=args.coin,
            known_lag_ms=args.known_lag_ms,
            stride=args.stride,
        )
    print(json.dumps(stats, indent=2))
    return 0


def _cmd_mcp(args: argparse.Namespace) -> int:
    root = Path(args.root)
    catalog_path, index_dir, ledger_path = _paths(root)
    pod_view = PodView(
        pod_id=args.pod_id,
        blinding_mode=cast(BlindingMode, args.blinding),
        blind_salt=args.blind_salt,
    )
    ledger = ForecastLedger(ledger_path)
    search_idx = PitSearchIndex(index_dir)
    with FabricCatalog(catalog_path) as catalog:
        service = CausalFabricService(
            catalog,
            pod_view=pod_view,
            search_index=search_idx,
            ledger=ledger,
            pinned_as_of=args.as_of,
        )
        server = create_mcp_server(service)
        server.run()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m fabric", description="Unified multi-modal quantitative data fabric"
    )
    parser.add_argument("--root", default="data/fabric", help="Data fabric storage root (default: data/fabric)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", help="Initialize CAS, DuckDB catalog, Tantivy index, and SQLite ledger")
    p_init.add_argument("--manifests", default=str(_DEFAULT_MANIFEST_DIR), help="Directory of *.yaml source manifests")
    p_init.set_defaults(func=_cmd_init)

    p_val = sub.add_parser("validate-manifests", help="Validate YAML source manifests against Pydantic schema")
    p_val.add_argument("--manifests", default=str(_DEFAULT_MANIFEST_DIR), help="Directory of *.yaml source manifests")
    p_val.set_defaults(func=_cmd_validate_manifests)

    p_status = sub.add_parser("status", help="Inspect catalog row counts and ledger integrity")
    p_status.set_defaults(func=_cmd_status)

    p_audit = sub.add_parser("audit", help="Run causal, provenance, retraction, and ledger hash-chain audits")
    p_audit.add_argument("--now", default=None, help="Reference UTC timestamp for future-known_at check")
    p_audit.set_defaults(func=_cmd_audit)

    p_dl = sub.add_parser("ingest-datalayer", help="Bridge ingest.datalayer/live recordings into the data fabric")
    p_dl.add_argument("--live-dir", required=True, help="Directory holding live logs and raw/*.gz blobs")
    p_dl.add_argument("--prefix", default="fetch", help="Log file prefix read by ingest.live.read")
    p_dl.add_argument("--feed", action="append", default=None, help="Filter to specific feed name(s)")
    p_dl.add_argument("--limit", type=int, default=None, help="Maximum records to ingest")
    p_dl.set_defaults(func=_cmd_ingest_datalayer)

    p_hl = sub.add_parser("ingest-hl-ws", help="Bridge Hyperliquid Parquet or WS JSONL recordings into the fabric")
    p_hl.add_argument("--input", required=True, help="File or directory containing .parquet / .jsonl(.zst)")
    p_hl.add_argument("--coin", default=None, help="Override coin symbol (default inferred from directory/record)")
    p_hl.add_argument("--known-lag-ms", type=int, default=0, help="Conservative arrival lag added to known_at")
    p_hl.add_argument("--stride", type=int, default=1, help="Downsample stride across records")
    p_hl.set_defaults(func=_cmd_ingest_hl_ws)

    p_mcp = sub.add_parser("mcp", help="Run the FastMCP stdio server over the fabric")
    p_mcp.add_argument("--pod-id", default="default", help="Pod ID bound to the MCP view")
    p_mcp.add_argument("--as-of", default=None, help="Optional pinned causal ceiling UTC timestamp")
    p_mcp.add_argument(
        "--blinding",
        default="NONE",
        choices=["NONE", "BLINDED_ENTITIES", "PROSPECTIVE_ONLY"],
        help="Blinding mode applied by the pod view",
    )
    p_mcp.add_argument("--blind-salt", default="default-salt", help="HMAC salt when blinding entities")
    p_mcp.set_defaults(func=_cmd_mcp)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
