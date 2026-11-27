# `moneymachine` Documentation & Research Wiki

central knowledge hub for the **Unified Multi-Modal Quantitative Data Fabric & Agentic Quant Experiment Platform** — designed for both human exploration and autonomous agent navigation.

> Note: There is intentionally no root `README.md` (`git` tracks [AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md) for onboarding, and this Wiki + `mmwiki` for full documentation).

## Quick Navigation

| Section | Purpose | Location |
| --- | --- | --- |
| **Architecture** | 6-plane Data Fabric design, canonical tables, and polyglot stack | [architecture.md](architecture.md) |
| **ADRs** | Architectural Decision Records documenting structural choices | [adrs/index.md](adrs/index.md) |
| **Behavioral Quirks** | Operational traps, SQL/Lean/mypy/Nix edge cases, cluster & blinding notes | [quirks.md](quirks.md) |
| **Research Hub** | Strategy Pods A–E, whitepaper, findings, and historical research archive | [research/index.md](research/index.md) |
| **Operations** | Dev shell, Nix checks, `mmwiki`, `mmfabric`, `python -m fabric`, cluster runbook | [operations.md](operations.md) |
| **Governance & State** | Onboarding rules, live status, hardware checklist | [AGENTS.md](../AGENTS.md), [CLAUDE.md](../CLAUDE.md), [PROGRESS.md](../PROGRESS.md), [CLUSTER.md](../CLUSTER.md) |
| **Plug-in Execution** | Verified Lean 4 + OCaml A18 Bar Market verification subproject | [subprojects/confirmation-wall/README.md](../subprojects/confirmation-wall/README.md) |
| **Strategy Pods** | Scoped `PodView` isolation, causal MCP tools & forecast ledger | [pods/README.md](../pods/README.md) |

## Repository Map

```text
├── wiki/                  # Markdown documentation hub & OCaml `mmwiki` server
├── fabric/                # Unified Multi-Modal Data Fabric (Planes 0–5)
│   ├── lean/              # Lean 4 causal, non-resurrection, ASOF & PodView proofs
│   ├── ocaml/             # Default OCaml 5 Zstd CAS, PIT core & `mmfabric` CLI
│   ├── manifests/         # Declarative YAML source manifests
│   ├── adapters/          # Bridges for datalayer, Hyperliquid L2/WS, kernel2 A18
│   └── tests/             # Python CAS, catalog, search, MCP & adapter suites
├── pods/                  # Isolated agentic strategy pods & experiment protocols
├── recorder/              # Live OCaml Hyperliquid WS collector (`mmrec`) & vault (`mmvault`)
├── ingest/                # Live HTTP datalayer recorder, terms metadata & HL archive reader
├── subprojects/
│   └── confirmation-wall/ # Plug-in verified A18 execution (`kernel2/`, `reference/`, `kernel-v1/`)
├── venue/                 # Feed declarations & metadata (`sources.toml`, `datalayer.json`)
├── ops/                   # Cluster workloads, mirror, diskguard & git/CI checks
├── audit/                 # Append-only criteria, decisions & external review trail
└── docs/                  # Architecture specs, whitepaper & research archive
```

## Serving This Wiki (`mmwiki`)

Launch the local offline HTTP wiki server:

```bash
nix run .#wiki -- --root . --port 8080
```

Machine-readable endpoints for agents & scripts:
- `GET /api/index` or `nix run .#mmwiki -- index --root .` — JSON catalog of all discoverable markdown docs
- `GET /api/search?q=<terms>` or `nix run .#mmwiki -- search --root . "<terms>"` — JSON full-text line search
- `GET /raw/<repo-relative-path>` — unrendered raw Markdown / source file
- `GET /view/<repo-relative-path>` — safe CommonMark HTML view with sidebar navigation
