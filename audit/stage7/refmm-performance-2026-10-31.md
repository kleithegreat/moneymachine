# refmm admission performance

2026-10-31 07:40 UTC (03:40 EDT), branch `stage7`; baseline `781d3d8`.

## Profile before changing code

Native phase instrumentation of Main's market/check/context/evaluation/stream helpers, compiled with
`lake env lean -c` and `lake env leanc -O3`, linking the existing Ref objects. N2, seed 20261024,
550 days, 12 coins, 237,615 observations; first 64 frozen-corpus entries naming N2, in corpus order.
The first program is the first generated rule, with cross-sectional rank, a lag and price/premium inputs.
Markets generated with `reference.differential.null_market`; `mmdump` loads version 1.

| Phase, first program (milliseconds) | 45 days, before | 550 days, before | 550 days, after |
|---|---:|---:|---:|
| Market JSON parse and unique-key guard | 96.5 | 1,092.6 | 1,072.9 |
| Market decode | 5.0 | 69.9 | 69.5 |
| Ctx.make (delivery sort and indexes) | 36.8 | 562.4 | 576.3 |
| Ctx.admissible | 1,144.5 | 236,862.3 | 133.1 |
| Ctx.inScope | 520.1 | 161,183.8 | 243.2 |
| Evaluation | 73.8 | 3,608.6 | 3,610.2 |
| Result JSON and write | 6.4 | 96.6 | 93.3 |
| Node-stream replay and write | 49.5 | 649.8 | 640.5 |

The loader is Main's resolved-observation adapter, not `resolveAll`; it does not scan stored revisions.
The two admission checks consume over 98% of the 550-day profile. `admissible`'s `eraseDups` tests each
key against a growing List. `inScope` calls `readFrom` for every observation, repeatedly rebuilding
`bounds` through `lastTick`. JSON, sorting and the small position/certificate Lists are not the bottleneck.

## Proved replacements

`Ref/Exec.lean`, imported by `Ref.lean`, supplies compiler (`csimp`) equalities:

- HashSet-backed deduplication preserves the exact original List, including order. Its loop invariant
  equates set membership with membership of the original accumulator. Hash collisions do not affect equality.
- Scope traversal receives first/last tick and use-end as scalar arguments evaluated once. Its equality
  to the frozen scope check is definitional. No scope, binding or refusal-order condition is removed.
- The equal admission wrapper is compiled in the rewrite's environment; Main's generated C calls
  `Ref.Exec.admit`. Merely importing the two check rewrites would leave the old compiled `admit` slow.

No frozen file, law statement, loader contract or numeric operation changed.

## Native executable timings and checks

All builds and heavy runs foregrounded under
`systemd-run --user --scope -p MemoryMax=6G -p MemorySwapMax=1G choom -n 1000 -- nix develop -c ...`.

- Actual `refmm run`, one program, same N2 550-day JSON: baseline **407.58 user + 0.19 system seconds,
  408.67 wall seconds**; optimized **6.421 user + 0.121 system seconds, 6.556 wall seconds** (62.3× CPU).
  JSON outputs and binary node streams agree exactly. Peak RSS before: 728,212 KiB; after: under 731 MiB.
- Actual optimized `refmm run`, 64 programs each: N1 **285.15 s wall / 284.60 s CPU**;
  N2 **363.09 / 362.32**; N3 **365.22 / 364.45**. No baseline 64-program time is extrapolated as a measurement.
- `lake build Ref refmm`: passes. Latest recorded SHA-256 matches for all 10 paths in `laws-frozen.md`.
- `#print axioms` for all 18 laws, comparing imports of `Ref.Laws` and `Ref`: identical.
  Only `propext`, `Classical.choice`, `Quot.sound`; the two L8 laws omit choice. The three executable
  equality theorems also use only these. No `sorryAx`.
- `reference/tests/test_lean_differential.py`: **2 passed**. The test process points `kernel.MM` to the
  read-only `/home/kevin/repos/moneymachine/kernel/target/release/mm` and skips rebuilding that binary.
- All **1,196 frozen corpus verdicts** agree with that native mm binary.
- **192 complete runs** (64 on each N1/N2/N3, 550 days) agree with mmdump on all trace fields,
  return and gross-return bits, types, defined-value counts, and byte-for-byte node streams.
  Separately, the read-only native mm binary's `eval --trace` agrees on every exposed trace field and
  all return bits (read from an isolated scratch ledger) for all 192 runs. Its trace omits decisionPrice;
  that field and gross returns/node streams are covered by mmdump.

This is development evidence, not a judged C6.4 rerun: regenerated store hashes differ from the old
stage 6 manifest, and only 64 programs per null market were run. No thresholds or frozen evidence changed.
Reproduction scratch: `data/refmm-performance` (ignored; also linked from `/tmp/opencode/refmm-performance`),
with native profiler source/compiler driver, baseline executable, phase logs, validator, direct-mm checker,
generated markets and output files. Initial version-0 empty exports were discarded as invalid profiling
inputs; every timing above uses version 1. Scratch moved off `/tmp` after its RAM-backed filesystem filled.

Remaining dominant cost: evaluation's repeated linear bar-time scans; these were not changed.
