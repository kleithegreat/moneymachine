# Edge market: 60 of 61 runs disagree on stage 7

2026-11-07 06:45 UTC (01:45 EST). Builder "edge-market regression", branch `edge-fix` off `stage7` (`eff52b0`).

## Finding

The Lean side is stale; Rust is right. No kernel change is needed, so `edge-fix` carries this record only.

- **First bad commit:** `e67027b` ("stage7 slice 5, part 2: mm's resolver and loader follow RULES.md §6 B3"). Bisected over the
  first-parent range `0738c2d..eff52b0` (20 candidates) on the edge market's `case-op-add` and `case-op-neg`
  (market hash equal to the frozen one; Rust, mmdump and `refmm` rebuilt per step). Its parent `7983958` agrees.
- **Cause.** The edge market (`reference/edge_markets.py`, version 2) restates E0's funding on 13 keys:
  hours 100 to 109, 200, 300 and 301 (coin 0). The old loader collapsed a key to its latest revision (3,574 funding rows,
  one per key, revised values, the correction's own knownAt). `market::load` now follows B3: every delivered revision is a
  record at its own knownAt, and execution reads the key's last entry (`final`). `mmdump` therefore exports 3,587 rows,
  the 13 keys twice (original, then the restatement), and `reference/lean/Main.lean:70` imports every row with
  `final := true` (and `retraction := false`, `recorded := known`). Lean's admission (`Ctx.admissible`,
  `Ref/Sim.lean:440`) requires one final record per key, so every run on the edge market stops at `R_BINDING`
  before the machine starts. Rust runs to its abort (below) or to the end.
- **Verified.** Handing `refmm run` the same `mk.json` with each key cut to its last row gives `R_SETTLEMENT_MISSING`,
  equal to `mm`. The two sides differ only in the importer, not in any rule.
- **Why Rust is right.** RULES.md §6 B3 and `Ref/Resolve.lean`'s `resolveAll` (the proved side, "every entry of every key's
  timeline, in order", `final := i + 1 == es.length`) agree with the new Rust loader: earlier revisions are delivered when
  known, only the last is final. The stage 6 collapse hid a value that was knowable at the time, which B3 deliberately
  changed. `mm`'s own resolver is equal to Lean's on all 652 frozen resolver cases (slice 5).
- **The 61st run** is the one rejection case, where no run happens.
- **Pre-existing, not a regression:** 45 of the 61 edge runs abort with `R_SETTLEMENT_MISSING` on both sides already at
  `0738c2d` (coin 2, E2, hour 600: its designed funding gap, with a position held). Only 16 edge runs executed to the end;
  those 16 are what the importer now loses. The abort-code agreement of the other 45 is also gone, though it checked only the code.

## What the importer must carry (C7.7's revision-carrying exporter)

Per observation, from `market::Market`/`resolve::Resolved`: `final` (last entry of its key's timeline; mmdump does not
emit it), `retraction` (mmdump now emits one more column on funding and bars, and two on events; the
importer ignores both), `recorded` (the revision's `fetchedAt`; the importer uses `known`), and rows in timeline order.
`Main.lean` must read these instead of hard-coding `final := true`, `retraction := false`, `recorded := known`.
No Lean semantics change: `Ctx.admissible`, `readFrom` and `Resolve.lean` already express all of it. The planned
registry/certificate part of C7.7 (the fixed `admissionMeta`) is a separate gap.

## Can C6.4 be claimed on stage 7 meanwhile?

- C6.4 as judged at the stage 6 exit (one frozen kernel, 3,372 runs agreeing, `slice2-differential.md`) stands; it is
  history and is not touched.
- On stage 7, honestly: N1, N2, N3 (3,303), liquidation and ruin (8) still agree, 3,311 runs. The edge market's 61 runs
  are not differentially checked, and what they covered (a restated funding key, knownAt exactly at a tick and 1 ms
  after, the late stamp) is exactly what stage 7 changed. Nothing may say "C6.4 holds on stage 7" until the exporter
  lands and the 61 runs agree again; "equal to Lean on every frozen case" (PROGRESS, slice 5) means the resolver
  suite, not C6.4's corpus. Resolver agreement on revisions is carried by the 652 resolver cases meanwhile.

## Reproduce

`reference/differential.chunk` on `case-op-add` over `edge_markets.edge` at `eff52b0`: `('abort', 0, 'R_SETTLEMENT_MISSING', 'R_BINDING')`.

## Revision 2026-11-08 02:10 UTC (21:10 EST), branch `revision-exporter`

The importer now carries the revisions: `mmdump` exports `final` (last entry of the key's timeline), `retraction` and `recorded`
(the revision's fetchedAt) per observation, in timeline order, and `Main.lean` reads them; the hard-codings are deleted and no
Lean semantics changed. A differential test on the restated edge market (`test_runs_agree_on_restated_keys`) failed before and passes.
The full C6.4 harness result on this branch is recorded below when it finishes.
