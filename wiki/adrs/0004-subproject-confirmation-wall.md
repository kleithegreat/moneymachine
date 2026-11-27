# ADR-0004: Confirmation Wall as Plug-In Verification Subproject

- **Status:** Accepted (`2026-11-27 22:18 UTC (17:18 EST)`)

## Context

`kernel2/`, `reference/`, and `kernel/` dominated the repository top level even though they address a specialized problem: formally verifying discrete-bar microstructure simulations (A18 Bar Markets) and recording the original pilot / Study 1 benchmark.

## Decision

1. Move `kernel2/`, `reference/`, and `kernel/` (preserving git history) into `subprojects/confirmation-wall/{kernel2,reference,kernel-v1}` with a dedicated [`README.md`](../../subprojects/confirmation-wall/README.md).
2. Update `flake.nix` (`refmm`), `docs/findings.md`, `CLAUDE.md`, and `PROGRESS.md` paths while leaving `subprojects/confirmation-wall/kernel2/` as an independent Nix sub-flake (`nix flake check -L ./subprojects/confirmation-wall/kernel2`) and preserving `docs/whitepaper.{tex,pdf}` and `audit/` intact.
3. Connect the subproject to the main data layer via [`fabric/adapters/kernel2_pod.py`](../../fabric/adapters/kernel2_pod.py) (`export_kernel2_bar_market`).

## Consequences

- Top-level repo structure cleanly reflects the Data Fabric (`fabric/`), experimentation (`pods/`), live capture (`recorder/`, `ingest/`), documentation (`wiki/`), and specialized verification (`subprojects/confirmation-wall/`).
- No loss of Lean theorems, A18 bar tests, or paper traceability.
