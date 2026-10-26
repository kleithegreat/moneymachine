# Stage 7 law statements, frozen 2026-10-26 23:30 UTC (19:30 EDT)

Human decision of 2026-10-26 (`audit/decisions.md` on main): freeze the law statements after the bitemporal revision.
C7.7 requires each revised law to be reviewed and frozen before its proof. The statements are `reference/lean/Ref/Laws.lean`, over the definitions in the files below, at commit `f35748b6ea8032b6fa27c4c87aab23cf4eee9e08`. From here a statement or a definition it uses changes only by a dated revision in this file, before any proof that depends on it is judged.

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `32fc75d75f6b91413ef9c5f1ddb70bca18f275be3ef97196051d9e738f36d183` |
| `reference/lean/Ref/Resolve.lean` | `fdfe8ca4ea8ad98fc1082e51e0a1a8cff74f16af6eabdf905eaa6083fd66642d` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `4ea816a2623a2ee5ffb0aef05629b2e63c0c7e0c1a36b243d154f28d1ae34d64` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `9094d3e65aae38d3a028c562833649bc6aee76acb4ed7da320039cef8500dfdc` |
| `reference/lean/Ref/Laws.lean` | `55ddbf7a198e28fbb0902b662fa75e1c91a214120e105b28eb1931d383d4652d` |
| `kernel/RULES.md` | `6492c17f9a1f338a5e1c43a6abb74afdc230660c4fa2256cded4ec8f29fa15f7` |

Reviews before the freeze: four fresh-context Opus reviews and six GPT reviews (`laws-review-*.md`), their findings and answers in `laws-v2-draft.md` §4. Queued: GPT's review of the bitemporal resolver (revision 12), whose findings become dated revisions here.
