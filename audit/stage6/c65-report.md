# Stage 6: comparison and adoption (C6.5), draft

Draft, superseded on review (PROGRESS.md, stage 6, 2026-10-23): the C6.4 run below does not qualify, and the effort and benchmark sections are incomplete.

Two reference kernels were attempted: Lean 4 (v4.34.0) and Bend 2 (2.0.37). Lean is adopted. The Rust
engine `mm` is unchanged by this stage.

## Laws

| Law | Lean | Bend |
|---|---|---|
| L1 non-interference (`L1_values`, `L1_simulator`, `L1_decisions`) | proved | not proved (needs a verified integer library; not attempted) |
| L2 unit soundness (`L2_units`, `L2_checker`) | proved | out of scope (human decision of 2026-10-21) |
| L3 rewrite soundness, every R v1 rule (`L3_rewrite`) | proved, abstract version | out of scope |
| L4 fill ordering (`L4_fills`, `L4_orders`) | proved | not proved (same reason as L1) |
| L5 binding (`L5_binding`) | proved | proved under `--verdict`, over one concrete exact number type |
| L6 bounded returns (`L6_bounded`, added with I10) | proved | not attempted |

- **Lean (C6.2 met).** Every law is proved after a clean `lake build`, with `#print axioms` ⊆ {propext,
  Classical.choice, Quot.sound} (`lean-axioms.txt`). The statements are `reference/lean/Ref/Laws.lean`, over
  every `NumOps` structure, with the dated revisions recorded under the stage 6 criteria: L4's liquidation
  reference, L1_simulator's step range, the finite filter on `hours_since` and `xs_rank`, `Dim.zip` on units
  of unequal length, and L4_orders' solvency condition with I10.
- **Abstract against binary64.** Every theorem above is abstract, over the number structure. No theorem is
  claimed for the binary64 instance: Lean's `Float` is opaque to the kernel, so L3's numeric obligations
  cannot be established for it. Binary64 behavior is supported only empirically, by C6.4's bit-exact agreement
  with `mm` (below) and by C4.1's exactness tests.
- **Bend (C6.3, reported).** It proves L5 only. The record and findings are in `bend.md`: unary `Nat`
  overflowed the checker, there are no integers and no binary64, and the language has constraints. The port
  is at commit `69e91e0`.

## Trust notes (Lean)

- **Trusted for the proofs:** Lean's kernel and the three standard axioms above.
- **Trusted for the executable `refmm`, beyond the proofs:**
  - Lean's compiler and runtime, which are not verified;
  - `Float` as the C double type, IEEE binary64 in round-to-nearest, with the platform's `exp`, `log` and
    `sqrt`;
  - the JSON front end (`Main.lean`), which parses the program and the market.
- **The implementation boundary:** `reference/mmdump`, a Rust adapter that links `mm` as a library. It loads
  the store with `mm`'s own loader, exporting the resolved market every float as its bits, and runs `mm`'s
  simulator for the comparison. So store resolution, knownAt computation and the venue files are `mm`'s,
  checked by C0.4/C5.2 and `reference/tests/test_resolution.py`, not by stage 6. The executable `refmm` uses
  the same definitions as the proofs (`Ref/Spec.lean`).

## Differential results (C6.4, met for Lean)

`c64-report.json`, on the corpus frozen in `c64-manifest.json` (commit `9c8abfc`, seed 20261022):

- **Verdicts:** 1,186 programs agree exactly: 1,125 accepted, and 61 rejected under 9 distinct codes.
- **Runs:** all 3,179 agree bit for bit (trace, returns, gross returns). There is no waiver and no
  math-library exception.
- **Coverage:** 42.6M decisions, 42.6M fills, 4.6M holds, 351M settlements, 4 liquidations, 38 delistings,
  133 unfilled orders and 3 R_INPUT_UNAVAILABLE aborts.

Bend is not eligible: it has no binary64, so it cannot pass C6.4.

## Performance (`c65-bench.json`)

Measured on an Intel i5-11400, one thread, release builds, one process at a time, on C6.4's frozen 550-day N2
market.

| | mm | refmm |
|---|---|---|
| W0 replay, evaluator only (median of 5) | 29.3 ms | 1,467.6 ms |
| W0 replay, end to end (median of 5) | 1,618.1 ms (`mm eval`: parquet load, run, ledger) | 5,990.0 ms (`refmm run`: JSON parse, run, trace) |
| Market export by `mmdump` (median of 5) | | 1,479.9 ms |
| Null-simulation throughput, evaluator only | 13.2 program-market-years/s | 0.21 program-market-years/s |

Throughput counts completed runs only: 100 of the corpus's first 100 generated programs completed on both
kernels, so 150.7 program-market-years each. Bend has no executable model that runs on real data.

## Effort

From commit times (UTC). The work ran in one long agent session (6 context compactions, resumed after usage
limits) and its continuation. Active agent time is not metered separately, so the elapsed times between
milestones include pauses.

| Milestone | Done | Commit | Retries and failures recorded |
|---|---|---|---|
| Contract, checker; verdicts agree on 79 adversarial cases | 2026-10-20 02:36 | `2c23055` | min/max ties and sum order measured against `mm` |
| Model, binary64 executable, `mmdump` | 02:48 | `7a0b899` | |
| Laws reviewed by GPT and frozen | 03:13 | `cb095f7` | 3 statements restated to the immutable engine |
| L5 | 03:24 | `7180965` | |
| L2_checker | 06:50 | `bd7c734` | |
| L1_simulator, L1_values | 14:28, 14:42 | `48fc965`, `4101f32` | L1_simulator revised (step range) |
| L2_units | 16:44 | `c5a9657` | |
| L4_fills, L4_orders | 19:49, 20:11 | `10915f9`, `b37f429` | L4 revised (liquidation reference) |
| L1_decisions | 20:37 | `22c8697` | |
| L3, 16 in-place rules | 2026-10-21 01:30 | `cc495f7` | 2 model revisions (finite filter, `Dim.zip`); a checker hole found and fixed in `mm` and the model |
| L3, `ifNotRev` (C6.2 met) | 2026-10-22 18:40 | `06df060` | do-notation join duplicated the continuation; loop-lemma shapes; elaboration timeouts |
| C6.4 judged run | 2026-10-22 about 22:30 | `f08380a` | development run on another seed first |

Bend's effort is in `bend.md`.

## Ranking and adoption

Only Lean passes C6.4, so only Lean is eligible. It has all five laws, plus L6. Lean is adopted as the
reference kernel (`reference/lean`). Its differential harness (`reference/c64.py`, `reference/c64_cases.py`,
`reference/tests/test_lean_differential.py`, `test_resolution.py`) stays in `reference/`. The Bend work left
the tree on 2026-10-22, and its record is kept in `bend.md`.
