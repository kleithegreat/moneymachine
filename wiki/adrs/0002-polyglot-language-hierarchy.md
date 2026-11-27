# ADR-0002: Polyglot Language Hierarchy

- **Status:** Accepted (`2026-11-27 22:18 UTC (17:18 EST)`)

## Context

Previous iterations oscillated between letting Python sprawl across every systems/orchestration utility and banning Python altogether in favor of OCaml and multi-round compiler-boundary sandboxes in Lean. Neither extreme fits a quantitative AI research lab: Python is indispensable for ML, statistics, DuckDB/Arrow data science, and MCP tooling, whereas OCaml provides clean, low-overhead, strictly typed systems binaries and Lean excels at short, decisive correctness proofs when scoped cleanly.

## Decision

Adopt an explicit three-language specialization backed by Nix:

1. **OCaml 5 (Default Systems Language):**
   - Owns daemons, collectors, CAS/storage primitives, CLI utilities, and the offline documentation server (`recorder/`, `fabric/ocaml/` `mmfabric`, `wiki/server/` `mmwiki`).
   - Enforces `ocamlformat` (`janestreet` profile), `ppx_js_style`, `-warn-error +a`, and explicit exception handling (no catch-all `with _`).
2. **Lean 4 (Critical Proofs Without Rabbit Holes):**
   - Owns concise, self-contained formal proofs of high-leverage invariants: PIT non-resurrecting retractions, causal bounds, ASOF join causal safety, and `PodView` monotonicity (`fabric/lean/Fabric/Causal.lean`), plus verified A18 execution accounting (`subprojects/confirmation-wall/`).
   - No Mathlib bloat or adversarial local-compiler theater; builds offline with `warningAsError = true` and rejects `sorry`/`admit`/`axiom`/`native_decide`.
3. **Python 3.13 (ML, Stats, Analytics & Agentic MCP):**
   - Scoped to `numpy`/`scipy`, `duckdb`/`polars`/`pyarrow`/`xarray`, `tantivy`, `mcp`, Pydantic manifests, adapters, and Strategy Pods (`fabric/`, `pods/`).
   - Non-frozen Python passes `ruff format --check`, `ruff check`, and `mypy --strict`. Minimal cluster recorder modules (`ingest/datalayer.py`, `ingest/live.py`, `ingest/sources_record.py`) keep a tiny dependency closure (`pythonFor` in `flake.nix`).
4. **Rust / Cargo:** Not included in the dev shell; Tantivy is consumed cleanly through Python wheels in nixpkgs.

## Consequences

- Systems performance and container footprints stay tight in OCaml, mathematical invariants stay verified in Lean, and quant/agent research moves fast in Python without unnecessary porting bottlenecks.
