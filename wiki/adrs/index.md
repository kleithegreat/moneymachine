# Architectural Decision Records (ADRs)

ADRs capture durable architectural choices alongside context, trade-offs, and pointers into code and append-only [`audit/decisions.md`](../audit/decisions.md).

## Active Index

| ID | Title | Status | Scope |
| --- | --- | --- | --- |
| [0001](0001-unified-data-fabric-pivot.md) | Pivot to Unified Multi-Modal Quantitative Data Fabric | Accepted | Project scope, open hypothesis generation, causal guardrails |
| [0002](0002-polyglot-language-hierarchy.md) | Polyglot Language Hierarchy: OCaml Default, Lean Critical Proofs, Python ML/Stats | Accepted | `fabric/`, `recorder/`, `wiki/server/`, `pods/`, `flake.nix` |
| [0003](0003-pragmatic-licensing-metadata.md) | Pragmatic `license_class` Metadata Tagging over Runtime Blocks | Accepted | `ingest/terms.py`, `ingest/datalayer.py`, `PodView` |
| [0004](0004-subproject-confirmation-wall.md) | Confirmation Wall (`kernel2`, `reference`, `kernel-v1`) as Plug-In Subproject | Accepted | `subprojects/confirmation-wall/`, `kernel2_pod.py` |

## Adding a New ADR

Create `wiki/adrs/NNNN-short-slug.md` with four short sections:
1. **Status & Date** (use `YYYY-MM-DD HH:MM UTC (HH:MM EST/EDT)`)
2. **Context** (what concrete problem or bottleneck motivated the change)
3. **Decision** (exact modules/contracts affected)
4. **Consequences** (what is enabled, what is retired, how to reverse)

Register the new row in this table and log major irreversible/study decisions in [`../../audit/decisions.md`](../audit/decisions.md).
