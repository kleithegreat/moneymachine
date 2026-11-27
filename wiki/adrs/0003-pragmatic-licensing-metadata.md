# ADR-0003: Pragmatic `license_class` Metadata Tagging

- **Status:** Accepted (`2026-11-27 22:18 UTC (17:18 EST)`)

## Context

Previously, `ingest/terms.py` (`certify`) and `ingest/datalayer.py` threw `PermissionError` at runtime unless a manual regulatory certificate file matched an exact quote and basis. Multiple research sources (FRED/ALFRED, IMF, Polymarket, Kalshi, open research feeds) were rejected or left uncollected over legal/redistribution ambiguities irrelevant to offline personal research.

## Decision

1. Replace runtime certificate blocking in `ingest/terms.py` with descriptive six-tier classification (`PUBLIC_DOMAIN`, `CC_BY`, `PERSONAL_RESEARCH`, `NON_COMMERCIAL`, `COMMERCIAL_API`, `RESTRICTED_INTERNAL`) parsed from `venue/sources.toml` (with `PERSONAL_RESEARCH` default).
2. Keep HTTPS + hostname validation (`validate_url`) in `ingest/datalayer.py` without halting collection on terms blocks.
3. Propagate `license_class` and CAS `raw_hash` onto every `SourceManifest`, `core.raw_artifacts`, `core.fact_*`, and `PitSearchIndex` record, allowing production or redistribution Strategy Pods to restrict visibility cleanly via `PodView.allowed_licenses`.

## Consequences

- Exploratory data collection and historical backfill operate without red-tape interruptions while maintaining full end-to-end license lineage.
- Strict commercial compliance remains one parameter change (`PodView(allowed_licenses=("PUBLIC_DOMAIN", "CC_BY", "COMMERCIAL_API"))`).
