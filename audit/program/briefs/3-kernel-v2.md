# Brief 3: build kernel version 2

Written 2026-11-14 07:52 UTC (02:52 EST) by Claude Fable 5.2. The contract is `audit/program/kernel-v2.md` (parts A and B); this brief orders its build. Study 2, which uses it, is `architecture.md` section 6. A design on branch `rearchitecture`: nothing here is built until the advisor has had it reviewed.

## How every step runs

1. **Tests first, by a session that does not build the step,** from this brief and `kernel-v2.md`, without reading the code. Steps marked **◆** decide a judged number, so their tests go to **another model** than the builder's: GPT, or a fresh Opus session labeled as such when GPT is out.
2. **The builder (Sonnet) makes them pass without editing them,** in one commit. A test the builder believes wrong goes back to its author with the reason.
3. **A wall the brief did not foresee goes to the architect as a question.** No flag, tolerance, special case or second path (`CLAUDE.md` §1). Each step names the walls I can foresee.
4. **Opus checks the commit against its step,** and runs the step's checks itself.
5. **★ laws:** each step that proves one first commits its statement alone in `kernel2/lean/Engine/Laws.lean`. Another model reads the statements against part B3 before any proof, looking for one an empty or constant engine would satisfy. Then the proof; `checks.engine-proofs` admits no `sorryAx`.

**Languages.** Lean 4.34.0 as the flake pins it, for everything that decides a number; core `Rat` for exact numbers. OCaml 5.4.1 with dune and Jane Street's stack (`core`, `async`, `ppx_jane`, `ppx_expect`, `base_quickcheck`, v0.17), `yojson`, `ocaml_sqlite3`, and hand-written C stubs. No Rust, no Python, no new flake input: every step's first test is that `flake.lock` is unchanged.

**Data a builder may read.** The archive before 2026-11-01 and the vault's fills before 2026-11-01. Nothing recorded in [2026-11-01, 2027-01-31): the recorder's streams are read for format and integrity only, and every test fixture of their format is synthetic.

**Layout.** `kernel2/lean` (Lake library `Engine`, no executable, no `IO`), `kernel2/ocaml` (dune project, executable `mm2`), `kernel2/KERNEL.md` (part A of `kernel-v2.md`, moved there at step 0 as the spec beside the code, with `kernel-v2.md` keeping parts B and C and linking to it).

## The steps

### 0. A Lean function called from OCaml, built by Nix

- **Builds:** both packages' skeletons; `packages.mm2`; `checks.engine-proofs`; `checks.mm2-tests`; OCaml in the dev shell; one C stub file that initializes Lean's runtime once and calls an exported `check`.
- **The tests must show:**
  1. `mm2 check` on a program file prints Lean's verdict, built offline in the Nix sandbox.
  2. `flake.lock` is byte-identical to `main`'s.
  3. A fixture theorem closed with `sorry` fails `checks.engine-proofs`; without it the check passes.
  4. A `State` held by OCaml survives a major collection and is released once (a counter in the stub).
- **Foreseeable wall:** linking Lean's static runtime into an OCaml executable. If it cannot be done with what is pinned, stop and report; do not move the lock.

### 1. ◆ Exact numbers and the reading of decimals (A2)

- **Builds:** `Engine.Exact`: grid rounding (a buy's price down, a sell's up, a size toward zero), `ofDouble x scale`, `toDouble`, both by integer arithmetic on the double's bits.
- **The tests must show:**
  1. `10 × 0.9775` is `9.775` and rounds to itself as a buy on a grid of 0.001; `10 × 1.0056` to `10.056` as a sell; `1.93` coins are 193 lots and `0.29` are 29 (Argon's round 1, finding 1).
  2. `ofDouble` returns the written decimal for every decimal of up to 15 significant digits at its scale (property, a million cases), and agrees with OCaml's `Float.of_string` on each.
  3. It rejects `0.1 + 0.2` at any scale up to 16, a NaN, an infinity, and a mantissa of 10¹⁵ or more.
  4. A value off the grid by any amount rounds in its direction and by less than one grid step.
- **Laws:** X2 as tests 2 and 3; the rounding bounds of test 4 proved.

### 2. ◆ The ledger, and the vault's fills through it (A8, A9, A11's arithmetic; study 2's layer 1)

- **Builds:** `Engine.Ledger`: cash, positions, cost; a fill, a fee, a funding payment; the views `entry`, realized and unrealized profit, equity at given marks. An entry point that applies given fills with no venue. In OCaml, a reader of the fills file the advisor stores under `data/` (fetched under the info API's certificate, dated before 2026-11-01).
- **The tests must show:**
  1. Argon's finding 2: one lot at 100 and two at 101, closed at 102, change cash by exactly 4 and never round; `entry` is `302/3`; a partial close leaves cost and position consistent; a mid of an odd sum is exact; two opposite positions' funding sums to zero.
  2. Conservation (law A1) at every event of random fill sequences, as an equality of rationals.
  3. **Layer 1:** for all 5,806 fills, the fee and `closedPnl` equal the venue's to its printed digits, `startPosition` chains exactly, every price is on V1's grid and every size a whole number of lots. The test prints every difference; the step is done at none.
- **Laws ★:** A1, U1.
- **Foreseeable walls:** a difference in layer 1 is a finding about V1, V3, V4 or the ledger. It goes to the architect with the fills that show it; it is never tolerated away.

### 3. ◆ Events, admission and the archive's reader (A3, B1, B2)

- **Builds:** the event type with `time` and `known`; `start`, `feed`, `finish` over a machine that only admits, orders and counts; chunks; the DuckDB stubs and the archive reader; the merge; the manifest check of a coin-day against its raw files.
- **The tests must show:**
  1. C2: an event out of (time, class, coin, kind) order, a crossed quote, a number that is not a decimal of its scale, each put the state in a rejecting state that `finish` reports.
  2. C1: any cutting of an event list into chunks gives the same final state (property).
  3. The reader equals `ingest/archive.py`, event for event, on 20 sampled coin-days across the three cadence periods, and names BTC's 2026-10-01 table as short of its raw files.
  4. **The wall of B5:** feeding 16 coins over 212 days, with no program, takes under 20 minutes on one core and under 2 GB. Measured here, before anything is built on it.
- **Laws ★:** C1, C2.
- **Foreseeable wall:** the speed. If it fails, report the profile; a faster twin of a step needs a proof that it equals the plain one (B1).

### 4. The float evaluator, the clock and inputs (A4, A5's float half, B4)

- **Builds:** the parser and checker for version 2 programs with no slots; the float evaluator over declared sources; ticks, delivery by `known`, windows. Take `Ref/Source.lean`, `Ref/Resolve.lean` and the evaluator from the parked `stage7` tree if they build alone in `kernel2/lean`; otherwise write the evaluator from `reference/SEMANTICS.md` §1 to §5. Say which in the commit.
- **The tests must show:**
  1. **B4:** every program of the frozen C6.4 corpus, its inputs given as observations, a tick of one hour and no slots, gives node streams bit-identical to `mm`'s on all 3,372 runs.
  2. A tick finer than the data's cadence reads the latest known value and no window goes undefined (Argon's finding 7); a gap makes a coin's price inputs undefined and ends when quotes resume.
  3. An event is never read before its `known`.
- **Laws:** L2, L3, L5, N1 restated over declared sources and proved; L1 ★ for the machine so far.

### 5. Exact expressions, slots and orders (A5, A6)

- **Builds:** the exact sort and its crossings in the checker and evaluator; slots; cycles and own-state inputs fed by given fills; reconciliation; admission, with margin's inputs given.
- **The tests must show:**
  1. A program with a float literal where an exact one is required is a type error; `exact(f)` changes no value; a non-finite float makes its slot inactive.
  2. The ladder of A5 as a program: given a first fill at 10, its five wishes are at the published prices and sizes exactly, on the grid.
  3. Cancel, expiry and replace each arise from reconciliation alone; a wish equal to the live order places nothing; reconciling twice equals once.
  4. Orders taking effect together are admitted in A6's order; each refusal names which of the three conditions failed.
  5. `filled` never exceeds `size` in a cycle and resets exactly at flat.
- **Laws ★:** X1, R1, S1.

### 6. ◆ Fills on quotes (A7)

- **Builds:** arrival; resting orders; the two evidence rules on quotes; allotment; fees through the schedule.
- **The tests must show:**
  1. F0: for one order and one quote, each rule's fill is the table's, for every case of `b`, `a`, `p`, `tif` and remainder, a sell mirroring a buy.
  2. E1 on Argon's finding 3: five rungs and one seller resting 14.68 units below the lowest fill 14.68 units in all, best price first; two orders arriving at one quote take a level once.
  3. A `reduce_only` fill is cut to the position and its rest cancelled.
  4. L1b: no fill on an event with `time ≤ τ + λ`; an order replaced at `τ` can still fill until `τ + λ`.
  5. F1 from one state at one event. And Argon's two whole-run constructions run and inverted as he says, kept as tests that no one claims a bound.
  6. An engine that never fills fails tests 1 and 2.
- **Laws ★:** F0, E1, L4, F1, L1b.

### 7. ◆ Margin, liquidation, the floor, listings (A10 to A12)

- **Builds:** marks; cross margin; liquidation; bankruptcy; a listing's end; the full order of one event.
- **The tests must show:**
  1. M1 as an "exactly when", on both sides of the threshold by one unit of the last decimal.
  2. Fills come before the check at one event; a liquidation cancels every order and nothing fills after it (K2's lesson).
  3. A long account at a leverage of 1 is never liquidated by any price path (property), only by funding.
  4. L6: equity is never negative; after a bankruptcy every return is zero (K5's lesson).
  5. L1 for the whole machine: two markets equal up to `known ≤ τ` agree through `τ`, a later listing's end included (K1's lesson).
- **Laws ★:** M1, L6, L1.

### 8. ◆ Trades (A7's second column)

- **Builds:** the trade event; trade evidence in both rules; `high`, `low`, `traded`; marks at prints; the reader of the recorder's streams through `mmrec cat`; the reader of `node_trades` once the bucket is certified.
- **The tests must show:**
  1. On a market with no trades the run equals step 6's.
  2. Prints through the price add up across events; a quote completes an order or gives nothing; a print and a later quote never count one lot twice.
  3. A wick between two snapshots, present only as prints, fills under both rules.
  4. The recorder's reader on synthetic streams: every line read, a killed run's gap reported as a gap.
- **Laws ★:** F0 and E1 extended; their statements are frozen again before the proofs.

### 9. The report, the identity, the SQLite ledger, the pool (A12, A13)

- **Builds:** report steps with equity, return, notional and every coin's mid; the trace; the identity hash; the append-only ledger with `session`, `agent`, `parents`; alias maps; the process pool.
- **The tests must show:**
  1. UPDATE, DELETE and REPLACE are each rejected by the schema (M4's lesson).
  2. D1: one run twice, and on two hosts, gives byte-identical reports.
  3. Changing any hashed input changes the identity; changing nothing does not.
  4. N1 end to end: an aliased program on the aliased market gives the same trace up to names.
  5. A killed run leaves no ledger row; its rerun leaves one.

### 10. ◆ Study 2's instruments (architecture 6)

- **Builds, in Lean:** the confirmer, a pure function from a report's columns to `B`, `M` and the first step at which `M ≥ 20`, the test ended, or neither. **In OCaml:** the runners of layers 2 and 3, the decimation of the fast period, the block bootstrap.
- **The tests must show:**
  1. An account holding the equal-weight basket at any exposure path has `M = 1` at every step, whatever the drift (D12's attack as a test).
  2. Under a simulated null `M` reaches 20 in at most 5% of 20,000 paths, with fat tails and with a liquidation.
  3. A liquidation, or a basket factor that is not positive, ends the test not confirmed.
  4. Layers 2 and 3 on a synthetic vault whose fills were generated by a known rule recover that rule's counts.
- The replica's program, its trigger and the registered constants are not this brief's: they come with study 2's criteria.

## What the recorders must hold for the forward run

| Needed | Source | State |
|---|---|---|
| Trades and books for the 17 coins | the websocket recorder: `trades` and five-level `l2Book` about every 0.55 s for every perp; 20 levels about every 10 s on the main dex | running since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST) |
| Settled hourly funding and oracle price | `fundingHistory`, by range | fetched at replay time; nothing to record |
| Each coin's `szDecimals`, leverage and margin tiers, dated | `meta` | **add:** a daily copy for every dex, if the hourly listings do not already hold the tiers |
| The fee schedule, dated | the venue's fees page under its certificate | **add:** a dated copy whenever it changes, checked weekly |
| The vault's fills in the forward window | `userFillsByTime` | **add:** a daily copy, stored unread like any recording, since the API keeps only the latest 10,000 |
| Trades for the archive's dates | `s3://hl-mainnet-node-data`, `node_trades` | to certify; then architecture 6.3's order of reading |

It lacks, for studies not yet designed: spot, and 20-level books off the main dex (both wait for a second IP).
