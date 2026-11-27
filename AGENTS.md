# Agent & Researcher Onboarding Guide (`AGENTS.md`)

Welcome to `moneymachine`. You are joining a **hypothesis-driven, polyglot quantitative research lab** built around a unified, point-in-time bitemporal Data Fabric (`fabric/`) and documented in [`wiki/index.md`](wiki/index.md).

## Research Mindset

- **Think like a junior researcher eager to discover what works:** Treat unexplored strategies, cross-modal combinations, alternative datasets, and agentic pipelines as testable hypotheses—not forbidden territory.
- **Let empirical out-of-sample data decide:** Test ideas rigorously using proper scoring rules (`mean_brier`, `mean_log_loss`, `brier_skill_vs_crowd` in [`fabric/ledger.py`](fabric/ledger.py)) and realistic cost/latency execution ([`subprojects/confirmation-wall/kernel2/`](subprojects/confirmation-wall/kernel2/)) rather than dismissing hypotheses upfront.
- **Build breadth without losing rigor:** Freedom in hypothesis generation pairs with ironclad causal hygiene at evaluation time.

## Causal & Scientific Invariants

Every dataset, adapter, and agent pod must respect these structural guarantees:

1. **Bitemporal Isolation (`event_time` vs. `known_at`):**
   - Queries as of `T` only observe rows with `known_at <= T`.
   - Historical restatements accumulate with rising `revision_id` and `known_at`; retractions use `revision_state = 'RETRACTED'` and are never resurrected by earlier revisions (`core.pit_latest`, verified in [`fabric/lean/Fabric/Causal.lean`](fabric/lean/Fabric/Causal.lean)).
2. **`OBS` vs. `FCST` Separation:**
   - Realized observations (`polarity = 'OBS'`) must satisfy `known_at >= event_time`.
   - Prospective probabilities, targets, and schedules (`FCST`, `SCHED`) never contaminate factual observation panels.
3. **Content-Addressable Provenance:**
   - Every parsed row, edge, document, or forecast traces back to a raw payload SHA-256 (`raw_hash`) registered in `core.raw_artifacts` and stored compressed in Zstd CAS ([`fabric/ocaml/`](fabric/ocaml/) / [`fabric/cas.py`](fabric/cas.py)).
4. **Blinded Evaluation:**
   - When evaluating out-of-sample entity reasoning without ticker/name memorization, configure `PodView(blinding_mode="BLINDED_ENTITIES", blind_salt=...)` (`fabric/views.py`) so [`CausalFabricService`](fabric/mcp_server.py) masks canonical names, aliases, dates, and document IDs end-to-end.
5. **Immutable Audit Trail:**
   - [`audit/`](audit/) (`audit/decisions.md`, `audit/criteria.md`, etc.) and `ForecastLedger` SQLite databases are strictly append-only. Never delete, rewrite, or backfill historical entries.

## Polyglot Stack & Documentation Hub

- **OCaml 5 (`recorder/`, `fabric/ocaml/`, `wiki/server/`) — Default Systems Language:** High-reliability collectors (`mmrec`, `mmvault`), Zstd CAS (`mmfabric`), and the markdown wiki/docs server (`mmwiki`).
- **Lean 4 (`fabric/lean/`, `subprojects/confirmation-wall/{kernel2,reference}/`) — Critical Proofs Without Rabbit Holes:** Concise, axiom-free proofs of causal PIT semantics (`Fabric.Causal`), `PodView` monotonicity, and verified A18 execution accounting. Keep proofs small, direct, and fast to check.
- **Python 3.13 (`fabric/`, `pods/`, `ingest/`) — ML, Stats, Fabric Analytics & MCP:** `numpy`, `scipy`, `polars`, `duckdb`, `pyarrow`, `xarray`, `tantivy`, Pydantic manifests, `ForecastLedger`, FastMCP server, and strategy pods (`pods/`).
- **Nix (`flake.nix`, `ops/`) — Cluster & Builds:** Reproducible dev environments, OCI images, `moneymachine-live` manifests (`CLUSTER.md`), and verification gates.
- **Wiki & Docs (`wiki/`, `mmwiki`):** Start at [`wiki/index.md`](wiki/index.md), review [`wiki/quirks.md`](wiki/quirks.md) and [`wiki/adrs/index.md`](wiki/adrs/index.md), or launch the local web/JSON docs server with `nix run .#wiki -- --root . --port 8080`. There is intentionally no root `README.md`.

## Licensing Pragmatism

Data sources carry a descriptive `license_class` metadata tag (`PUBLIC_DOMAIN`, `CC_BY`, `PERSONAL_RESEARCH`, `NON_COMMERCIAL`, `COMMERCIAL_API`, `RESTRICTED_INTERNAL`) via [`ingest/terms.py`](ingest/terms.py) and [`SourceManifest`](fabric/manifest.py). Research pods explore freely across local/research datasets; provenance tags stay attached so deployment pods can filter via `PodView.allowed_licenses` cleanly.

## Working Practices & Hygiene

- Default new systems daemons, parsers, and CLI utilities to **OCaml 5**; reserve **Python** for ML, statistics, DuckDB/Arrow data science, and agentic MCP harnesses; prove critical invariants concisely in **Lean 4**.
- Run checks inside Nix: `nix run .#test` and `nix flake check ./subprojects/confirmation-wall/kernel2`.
- Python code in non-frozen modules must be fully type-annotated (`mypy --strict`) and pass `ruff format --check` and `ruff check`. OCaml code uses `ocamlformat` (`janestreet` profile), `ppx_js_style`, and `-warn-error +a`. Lean projects build with `warningAsError = true`.
- Keep [`PROGRESS.md`](PROGRESS.md) concise (`<= 12,288` bytes) and pair every `HH:MM UTC` timestamp in `PROGRESS.md` or `audit/` (outside `audit/reviews/`) with `HH:MM EST`/`EDT` on the same line.
- Never commit `data/` payloads or touch `~/embargo/` forward-window directories.
