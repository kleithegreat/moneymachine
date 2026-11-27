# System Architecture (`fabric/`)

`moneymachine` organizes all data ingestion, normalization, causal querying, agent tooling, and execution verification around a **six-plane bitemporal Data Fabric**.

Canonical long-form design documents:
- [Quantitative Multi-Modal Data Fabric Architecture](../docs/quantitative_multi_modal_data_fabric_architecture.md)
- [Data Fabric Source Implementation Playbook (PDF)](../docs/Data%20Fabric%20Source%20Implementation.pdf)

## Six-Plane Data Model

| Plane | Responsibility | Primary Components |
| --- | --- | --- |
| **0 — Source Contracts & Licensing** | Declarative YAML manifests (`modality`, `storage_tier`, `temporal_semantics`, `temporal_polarity`, `license_class`, SLAs) and permissive metadata tagging | [`fabric/manifest.py`](../fabric/manifest.py), [`fabric/manifests/`](../fabric/manifests/), [`ingest/terms.py`](../ingest/terms.py) |
| **1 — Immutable Raw CAS** | Content-addressable Zstd storage keyed by SHA-256 with decompressed hash check and corruption quarantine | [`fabric/ocaml/`](../fabric/ocaml/) (`mmfabric`), [`fabric/cas.py`](../fabric/cas.py) |
| **2 — Bitemporal Canonical Catalog** | 6 core DuckDB/DuckLake tables (`raw_artifacts`, `dim_entity`, `rel_entity_edge`, `fact_observations`, `fact_documents`, `fact_expectations`) + PIT macros (`core.pit_latest`, `core.pit_edges`, `core.pit_expectations`) | [`fabric/catalog.py`](../fabric/catalog.py), [`fabric/lean/Fabric/Causal.lean`](../fabric/lean/Fabric/Causal.lean) |
| **3 — Hybrid Retrieval & ASOF Joins** | Tantivy BM25 lexical index with `known_at_us <= as_of_us` integer fast-field gating and causal `ASOF LEFT JOIN` | [`fabric/search.py`](../fabric/search.py), `FabricCatalog.bitemporal_asof_join` |
| **4 — Pod Views, Blinding & MCP** | Isolated `PodView` filtering (`NONE`, `BLINDED_ENTITIES`, `PROSPECTIVE_ONLY`), HMAC entity/date redaction, and 6 causal MCP tools | [`fabric/views.py`](../fabric/views.py), [`fabric/mcp_server.py`](../fabric/mcp_server.py) |
| **5 — Prospective Forecast Ledger** | Append-only SQLite store guarded by `BEFORE UPDATE`/`BEFORE DELETE` triggers and SHA-256 hash chaining; out-of-sample `Brier` & log-loss scoring | [`fabric/ledger.py`](../fabric/ledger.py) |

## Polyglot Language Hierarchy

See [ADR-0002](adrs/0002-polyglot-language-hierarchy.md) for the rationale:

- **OCaml 5 (Default Systems Language):** collectors, daemons, CLI utilities, Zstd CAS, PIT core reference, and the documentation server ([`recorder/`](../recorder/), [`fabric/ocaml/`](../fabric/ocaml/), [`wiki/server/`](server/)).
- **Lean 4 (Critical Formal Proofs):** compact, axiom-free theorems establishing causal PIT guarantees (`Fabric.Causal`) and verified A18 execution semantics ([`fabric/lean/`](../fabric/lean/), [`subprojects/confirmation-wall/`](../subprojects/confirmation-wall/)).
- **Python 3.13 (ML, Stats & Agentic Fabric):** analytics, DuckDB/PyArrow tables, `numpy`/`scipy`, Tantivy bindings, Pydantic validation, FastMCP agent server, and Strategy Pods ([`fabric/`](../fabric/), [`pods/`](../pods/), legacy [`ingest/`](../ingest/)).
- **Nix (Builds, Images & CI):** single reproducible flake ([`flake.nix`](../flake.nix)) governing dev shells, containers, and checks.

## Subproject & Collector Adapters

| Adapter | Source / Target | Implementation |
| --- | --- | --- |
| Live HTTP Datalayer Bridge | `ingest.datalayer` / `ingest.live` gzip + JSONL logs -> CAS + DuckDB + Tantivy | [`fabric/adapters/datalayer_bridge.py`](../fabric/adapters/datalayer_bridge.py) |
| Hyperliquid L2 / WS Bridge | S3 archive Parquet & `mmrec` WS `.jsonl`/`.jsonl.zst` -> CAS + `mid_px` / L1 metrics | [`fabric/adapters/hyperliquid_bridge.py`](../fabric/adapters/hyperliquid_bridge.py) |
| Confirmation-Wall Exporter | PIT `PodView` snapshot -> `kernel2` A18 Bar Market (`header.json` + `<COIN>.parquet`) | [`fabric/adapters/kernel2_pod.py`](../fabric/adapters/kernel2_pod.py) |
