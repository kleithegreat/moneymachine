# Confirmation Wall & Verified Kernel Subproject (`subprojects/confirmation-wall/`)

This directory houses the original confirmation-wall research program, frozen pilot kernel rules, and verified Lean 4 + OCaml bar-market execution engine as a self-contained subproject inside `moneymachine`.

Rather than defining the upper bound of the entire repository, this engine serves as the **verification and execution plug-in** for strategies discovered on the unified multi-modal data fabric (`fabric/`).

## Contents

- [`kernel2/`](kernel2/): Independent Nix sub-flake (`kernel2/flake.nix`) implementing A18 Bar Market verification in Lean 4.34.0 + OCaml 5.4.1 with pinned MPFR transcendental arithmetic (`exp`/`log`). Run its checks via:
  ```bash
  nix flake check -L ./subprojects/confirmation-wall/kernel2
  ```
- [`reference/`](reference/): Stage 6 Lean 4 reference kernel (`refmm` executable & `Ref` library) and Study 1 formalized theorems ([`Ref/Study1.lean`](reference/lean/Ref/Study1.lean)), built by the root flake check `lean-proofs`.
- [`kernel-v1/`](kernel-v1/): Archived v1 pilot DSL, canonical semantics, invariants documentation, and `admitted/` / `adversarial/` regression test fixtures (`CANONICAL.md`, `DSL.md`, `INVARIANTS.md`).

## Plugging Into the Data Fabric

Any exploratory Pod (`pods/`) or Python strategy script that produces discrete-bar signals over spot/perpetual markets exports a causally isolated A18 Bar Market directory directly from `FabricCatalog` using [`fabric/adapters/kernel2_pod.py`](../../fabric/adapters/kernel2_pod.py):

```python
from fabric.adapters import Kernel2CoinSpec, export_kernel2_bar_market
```

## Research Record

- Overview paper: [`../../docs/whitepaper.pdf`](../../docs/whitepaper.pdf) ([LaTeX source](../../docs/whitepaper.tex))
- Study index: [`../../docs/findings.md`](../../docs/findings.md)
- Append-only audit trail: [`../../audit/decisions.md`](../../audit/decisions.md), [`../../audit/criteria.md`](../../audit/criteria.md)
