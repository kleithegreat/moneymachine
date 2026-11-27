# ADR-0001: Pivot to Unified Multi-Modal Quantitative Data Fabric

- **Status:** Accepted (`2026-11-27 22:18 UTC (17:18 EST)`)
- **Audit Log:** [`audit/decisions.md`](../../audit/decisions.md)

## Context

Earlier development narrowed the entire repository to a single statistical confirmation problem ("The Confirmation Wall" on Hyperliquid perpetuals), backed by a synthetic positive control (Study 1), a single-venue vault replication plan awaiting multi-year forward data (Study 2), and restrictive source/tooling bans (`ops/test-python-left.sh`, `PermissionError` certificate gates in `ingest/`). Hundreds of macro and alt-data feeds collected by `datalayer` sat unread while agentic multi-modal exploration remained blocked.

## Decision

1. **Pivot project mission** to an open, hypothesis-driven **Unified Multi-Modal Quantitative Data Fabric & Agentic Quant Experiment Platform** (`fabric/`, `pods/`) guided by [`docs/quantitative_multi_modal_data_fabric_architecture.md`](../../docs/quantitative_multi_modal_data_fabric_architecture.md).
2. **Separate idea generation from causal validation:** Encourage broad cross-domain hypotheses (macro vintage revisions, clinical trial/SEC diffs, geospatial/supply-chain signals, prediction markets, microstructure) while enforcing strict bitemporal isolation (`known_at <= as_of`, `OBS` vs `FCST`, non-resurrecting `RETRACTED` rows, blinded views, hash-chained `ForecastLedger`) at evaluation time.
3. **Retire artificial tooling suppression:** Delete `ops/test-python-left.sh` and re-enable analytics/ML/data libraries (`numpy`, `scipy`, `duckdb`, `pyarrow`, `tantivy`, `mcp`, `xarray`).

## Consequences

- Existing live collectors (`recorder/`, `ingest/`) and verified A18 execution (`subprojects/confirmation-wall/`) retain full rigor while feeding a broader research pipeline.
- Reverse via git revert on `main` (append-only `audit/` entries remain untouched).
