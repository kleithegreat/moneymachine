# Stage 6: comparison and adoption (C6.5)

Two reference kernels were attempted: Lean 4 (v4.34.0) and Bend 2 (2.0.37). Lean is the candidate for adoption. The Rust
engine `mm` is unchanged by this stage.

## Laws

| Law | Lean | Bend |
|---|---|---|
| L1 non-interference (`L1_values`, `L1_simulator`, `L1_decisions`) | proved | not proved (needs a verified integer library; not attempted) |
| L2 unit soundness (`L2_units`, `L2_checker`) | proved | out of scope (human decision of 2026-10-21) |
| L3 rewrite soundness, every R v1 rule (`L3_rewrite`) | proved, abstract version | out of scope |
| L4 fill ordering (`L4_fills`, `L4_orders`) | proved | not proved (same reason as L1) |
| L5 binding (`L5_binding`) | proved | verdict run succeeded over one concrete exact number type; not an accepted law, since the statement was never frozen with review (C6.1 amendment of 2026-10-23) |
| L6 bounded returns (`L6_bounded`, added with I10) | proved | not attempted |

- **Lean (C6.2 met).** Every law is proved after a clean `lake build`. L3 assumes the number structure is
  `Lawful` (its rewrite obligations), and L6 assumes it is `Bounded`. The others hold for every `NumOps`. Each has `#print axioms` ⊆ {propext,
  Classical.choice, Quot.sound} (`lean-axioms.txt`). The statements are `reference/lean/Ref/Laws.lean`, over
  every `NumOps` structure, with the dated revisions recorded under the stage 6 criteria: L4's liquidation
  reference, L1_simulator's step range, the finite filter on `hours_since` and `xs_rank`, `Dim.zip` on units
  of unequal length, and L4_orders' solvency condition with I10.
- **Abstract against binary64.** Every theorem above is abstract, over the number structure. No theorem is
  claimed for the binary64 instance: Lean's `Float` is opaque to the kernel, so L3's numeric obligations
  cannot be established for it. Binary64 behavior is supported only empirically, by C6.4's bit-exact agreement
  with `mm` (below) and by C4.1's exactness tests.
- **Bend (C6.3, reported; not met).** Its only verdict run is L5's, archived with its BendTT translation and an audit against the frozen law (`bend-l5-verdict.txt`, `bend-l5-PROOF.bendtt`, `bend-l5-translated.md`). The record and findings are in `bend.md`: unary `Nat`
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
  simulator for the comparison. For the node streams it drives `mm`'s own `Machine` through `mm`'s public API,
  re-implementing only `sim::run`'s delivery order. So store resolution, knownAt computation and the venue
  files are `mm`'s,
  checked by C0.4/C5.2 and `reference/tests/test_resolution.py`, not by stage 6. The executable `refmm` uses
  the same definitions as the proofs (`Ref/Spec.lean`).

## Trust notes (Bend)

- **Trusted for L5:**
  - Bend 2.0.37's front end, which translates the Bend source into BendTT;
  - the bundled BendTT kernel `bendtt.lean`, checked by Lean 4.34.0 under `--verdict`;
  - the correspondence between the Bend model and the Lean model's definitions. That was ported definition for
    definition and audited by hand, not mechanically.
- **Scope of the law:** it is stated over one concrete exact number type, not every number structure.
- **Archived evidence:** `bend-l5-verdict.txt`, from re-running the proof at commit `69e91e0` on 2026-10-23. It
  has the invocation, the binary's store path, every model file's sha256, the output (ALL PROOFS CHECK) and
  exit status 0.

## Differential results (C6.4)

`differential-run2-report.json`, on the corpus frozen in `differential-run2-manifest.json` (commit `2eac75f`, seed
20261023, harness at `c007644`).
- **The corpus:** 1,024 programs from the frozen stage 4 generator; W0 and stage 2's probes; 69 deterministic
  cases on their own markets (`edge`, `liquidation`, `ruin`) and on each of N1, N2 and N3 (550 days each); every
  rejection path and every adversarial case. `pass` also checks the corpus's completeness, and nothing is
  missing.
- **Verdicts:** 1,196 programs agree exactly: 1,135 accepted, and 61 rejected under 9 distinct codes.
- **Runs:** all 3,372 agree bit for bit, with no waiver and no math-library exception. Each comparison covers:
  - the trace (decisions, holds, fills with their source bars and times, closeouts, unfilled orders,
    settlements, equity), returns and gross returns;
  - every node's static type (value category and unit);
  - a digest of every node's value stream: definedness and bits, every coin, every tick of the machine's
    schedule.
- **Coverage:** 11.5 billion defined node values, 43.5M decisions, 43.5M fills, 4.9M holds, 353M settlements,
  16 liquidations, 45 delistings, 159 unfilled orders and 6 R_INPUT_UNAVAILABLE aborts.
- **An earlier run that did not qualify.** `c64-manifest.json` and `c64-report.json` (2026-10-22) record a run
  that also agreed everywhere, but on a corpus GPT's review found incomplete (PROGRESS.md, stage 6).

Bend is not eligible: it has no binary64, so it cannot pass C6.4.

## Performance (`benchmark.json`)

The configuration was frozen before any measurement (`benchmark-manifest.json`, commit `77f9a48`): an Intel
i5-11400, one thread, rustc and Lean versions, release profiles, the differential manifest's digest, and the
corpus's W0 and first 100 generated programs. The run refused to measure if any of them changed. It used the
frozen 550-day N2 market, one process at a time, with nothing else heavy running.

| | mm | refmm |
|---|---|---|
| W0 replay, evaluator only (median of 5) | 16.0 ms | 652.1 ms |
| W0 replay, end to end (median of 5) | 900.1 ms (`mm eval`: parquet load, run, ledger) | 2,915.5 ms (`refmm run`: JSON parse, run, node digests, trace) |
| `mmdump` (median of 5): load, write the market JSON, run `mm` and its node digests | 800.1 ms | |
| Null-simulation throughput, evaluator only | 34.4 program-market-years/s | 0.70 program-market-years/s |

Throughput counts completed runs only: 100 of 100 programs completed on both kernels, 150.7
program-market-years each. Bend has no executable model that runs on real data. The draft's figures
(`c65-bench.json`, 2026-10-23) were measured while other work loaded the machine, and are superseded.

## Effort

Per-milestone active agent time and retries were not instrumented while the work ran, so this element is unmet as
written. It is reported as a proxy recovered afterwards (C6.5 amendment of 2026-10-23; `effort.py`, `effort.json`).
Intervals run between consecutive milestone commits (UTC).
- **Active** is the sum over each session transcript of its gaps of at most 5 minutes. It excludes tool runs
  longer than that (long Lean builds) and includes any other work in the interval: stage 2's calibration v3 during
  `ifNotRev`, and the Bend port, which was written while that proof built.
- **Commits** and **revisions or in-progress steps** come from git, and stand in for retries.

| Milestone | Commit | Elapsed (h) | Active (h) | Sessions | Commits | Revisions or in-progress steps |
|---|---|---|---|---|---|---|
| contract, checker | `2c23055` | 0.9 | 0.73 | 1 | 18 | 3 |
| model, binary64, mmdump | `7a0b899` | 0.2 | 0.2 | 1 | 2 | 0 |
| laws frozen | `cb095f7` | 0.41 | 0.4 | 1 | 9 | 1 |
| L5 | `7180965` | 0.18 | 0.17 | 1 | 3 | 2 |
| L2_checker | `bd7c734` | 3.44 | 0.81 | 1 | 1 | 0 |
| L1_simulator | `48fc965` | 7.63 | 0.82 | 1 | 4 | 2 |
| L1_values | `4101f32` | 0.24 | 0.23 | 1 | 2 | 0 |
| L2_units | `c5a9657` | 2.03 | 2.03 | 1 | 4 | 2 |
| L4_fills | `10915f9` | 3.08 | 0.62 | 1 | 10 | 4 |
| L4_orders | `b37f429` | 0.37 | 0.27 | 1 | 1 | 0 |
| L1_decisions | `22c8697` | 0.44 | 0.43 | 1 | 1 | 0 |
| L3 in-place rules | `cc495f7` | 4.88 | 1.37 | 1 | 16 | 10 |
| L3 ifNotRev, C6.2 | `06df060` | 41.16 | 1.63 | 1 | 12 | 5 |
| Bend machine port | `dedfffa` | 0.16 | 0.16 | 1 | 2 | 1 |
| Bend simulator port | `2fb8517` | 0.21 | 0.21 | 1 | 1 | 1 |
| Bend L5 | `69e91e0` | 0.12 | 0.11 | 1 | 1 | 0 |
| Bend stopped | `e0453e0` | 0.5 | 0.22 | 1 | 4 | 1 |
| C6.4 v1 run | `f08380a` | 2.65 | 1.4 | 3 | 10 | 1 |
| C6.4 v2 judged run | `1981f94` | 6.31 | 1.03 | 1 | 10 | 2 |

**Failures recorded:**
- dated law and model revisions for L1_simulator, L4_fills, L4_orders and L3 (stage 6 criteria);
- a checker hole found by L3 and fixed in `mm` and the model;
- `ifNotRev`'s failed proof attempts (a duplicated do-notation continuation, mismatched loop-lemma shapes,
  elaboration timeouts);
- Bend's unary `Nat` overflow and its smoke run's OOM kill;
- two C6.4 corpora that did not qualify on review (PROGRESS.md, stage 6).

## Ranking and adoption

Only Lean passes C6.4, so only Lean is eligible. It has all five laws, plus L6. Lean is adopted as the
reference kernel (`reference/lean`). Its differential harness stays in `reference/`: `differential.py`,
`edge_markets.py`, `mmdump/`, `benchmark.py`, `tests/test_lean_differential.py` and `tests/test_resolution.py`. The Bend work left
the tree on 2026-10-22, and its record is kept in `bend.md`.
