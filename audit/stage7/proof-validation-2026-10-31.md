# Frozen-law proof validation

Validated 2026-10-31 05:22 UTC (01:22 EDT), on branch `stage7`.

Each requested law was committed separately after `lake build Ref` and its axiom check passed:

| Law | Commit | Actual commit time, 2026-10-31 |
|---|---|---|
| `L7_reads` | `93f8dbf` | 04:51 UTC (00:51 EDT) |
| `L4_fills` | `e9f7c53` | 04:52 UTC (00:52 EDT) |
| `L4_orders` | `e77ebc0` | 04:55 UTC (00:55 EDT) |
| `L1_values` | `1ed34e8` | 05:02 UTC (01:02 EDT) |
| `L3_rewrite` | `d726f5b` | 05:12 UTC (01:12 EDT) |
| `L1_decisions` | `e408089` | 05:20 UTC (01:20 EDT) |

The times embedded in some commit subjects were incorrect; this table uses Git's recorded commit times.

Validation ran in the foreground through `nix develop`, under a systemd scope with `MemoryMax=6G`,
`MemorySwapMax=1G` and OOM score 1000:

- `lake build Ref`: passes. The executable target's pre-existing interface blocker is outside this check.
- `#print axioms Ref.<law>` after `import Ref`, for all 17 completed laws: only `propext`,
  `Classical.choice` and `Quot.sound` (the two L8 laws need no `Classical.choice`). No `sorryAx` or added axioms.
- All 18 theorem declaration headers through `:= by` match their text at `93f8dbf^` byte for byte.
- `L5_text`, including its proof body, matches `93f8dbf^` byte for byte; it belongs to branch `stage7-l5`.
- SHA-256 of `Ref/{Source,Resolve,Syntax,Machine,Sim,Units,Spec}.lean` matches each file's latest
  recorded hash in `laws-frozen.md`. No frozen definition changed.
- `git diff --check 93f8dbf^..HEAD`: passes.

No new frozen-law blocker was found. The earlier proof fragments were completed rather than replaced
with axioms, alternative definitions or weaker statements.
