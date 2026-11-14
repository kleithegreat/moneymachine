# Brief 3: build kernel version 2

Written 2026-11-14 07:52 UTC (02:52 EST) by Claude Fable 5.2; revised 2026-11-14 15:37 UTC (10:37 EST) after round 2. The contract is `audit/program/kernel-v2.md` (parts A and B); this brief orders its build. Study 2, which uses it, is `architecture.md` section 6. A design on branch `rearchitecture`: nothing here is built until its review has converged (`ledger.md`).

## How every step runs

1. **Tests first, by a session that does not build the step,** from this brief and `kernel-v2.md`, without reading the code. Steps marked **◆** decide a judged number, so their tests go to **another model** than the builder's: GPT, or a fresh Opus session labeled as such when GPT is out.
2. **The builder (Sonnet) makes them pass without editing them,** in one commit. A test the builder believes wrong goes back to its author with the reason.
3. **A wall the brief did not foresee goes to the architect as a question.** No flag, tolerance, special case or second path (`CLAUDE.md` §1). Each step names the walls I can foresee.
4. **Opus checks the commit against its step,** and runs the step's checks itself.
5. **★ laws:** each step that proves one first commits its statement alone in `kernel2/lean/Engine/Laws.lean`. Another model reads the statements against part B3 before any proof, looking for one an empty or constant engine would satisfy, and for one the transitions of part A contradict (round 2 found four). Then the proof; `checks.engine-proofs` admits no `sorryAx`.

**Languages.** Lean 4.34.0 as the flake pins it, for everything that decides a number; core `Rat` for exact numbers. OCaml 5.4.1 with dune and Jane Street's stack (`core`, `async`, `ppx_jane`, `ppx_expect`, `base_quickcheck`, v0.17), `yojson`, `ocaml_sqlite3`, and hand-written C stubs. No Rust, no Python, no new flake input: every step's first test is that `flake.lock` is unchanged.

**Data a builder may read.** The archive before 2026-11-01 and the vault's fills before 2026-11-01. Nothing dated in [2026-11-01, 2027-01-31). From step 3 the executable enforces it (kernel A13); before that, and for every fixture of the recorder's format, data is synthetic.

**Layout.** `kernel2/lean` (Lake library `Engine`, no executable, no `IO`), `kernel2/ocaml` (dune project, executable `mm2`), `kernel2/KERNEL.md` (part A of `kernel-v2.md`, moved there at step 0 as the spec beside the code, with `kernel-v2.md` keeping parts B and C and linking to it).

**Owed by the architect before step 3:** in `KERNEL.md`, the chunk's layout and the canonical encoding of every event; **before step 4:** the program's JSON grammar, the float operators that name the hour restated in ticks, and funding's lateness rule (GPT's finding 15). A builder who meets one of these missing stops and asks.

## The steps

### 0. A Lean function called from OCaml, built by Nix

- **Builds:** both packages' skeletons; `packages.mm2`; `checks.engine-proofs`; `checks.mm2-tests`; OCaml in the dev shell; one C stub file that initializes Lean's runtime once and calls an exported `check`.
- **The tests must show:**
  1. `mm2 check` on a program file prints Lean's verdict, built offline in the Nix sandbox.
  2. `flake.lock` is byte-identical to `main`'s.
  3. A fixture theorem closed with `sorry` fails `checks.engine-proofs`; without it the check passes.
  4. A `State` held by OCaml survives a major collection and is released once (a counter in the stub).
- **Foreseeable wall:** linking Lean's static runtime into an OCaml executable. If it cannot be done with what is pinned, stop and report; do not move the lock.

### 1. ◆ Exact numbers and the two readings of a decimal (A2)

- **Builds:** `Engine.Exact`: grid rounding (a buy's price down, a sell's up, a size toward zero); the reading of a double's bits at a scale, and the nearest double of a rational, both by integer arithmetic. In OCaml, the placing of a decimal string's digits into an integer at a scale.
- **The tests must show:**
  1. `10 × 0.9775` is `9.775` and rounds to itself as a buy on a grid of 0.001; `10 × 1.0056` to `10.056` as a sell; `1.93` coins are 193 lots and `0.29` are 29.
  2. For every scale from 0 to 12 and sampled `n` with `|n| < 10¹⁵`, the nearest double of `n · 10⁻ᵈ` reads back as `n`, and agrees with OCaml's `Float.of_string` on the written decimal.
  3. Rejected: `0.1 + 0.2` at every scale from 0 to 12; a NaN; an infinity; `10⁷` at scale 8 (its `n` is `10¹⁵`). Negative zero reads as zero.
  4. A string with more decimals than its scale is rejected, as is `"100.00000000000001"` at scale 8, which `Float.of_string` would have rounded to 100 (Argon's finding 4).
  5. A value off the grid by any amount rounds in its direction and by less than one grid step.
- **Laws ★:** X2, as a theorem on bits; the rounding bounds of test 5.
- **Foreseeable wall:** Lean's `Float` is opaque to proofs. X2 is about the integer functions on bits; `Float.toBits` stays in the trust boundary.

### 2. ◆ The ledger, and the vault's fills through it (A8, A9, A11's arithmetic; study 2's layer 1)

- **Builds:** `Engine.Ledger`: cash, positions, cost; a fill, a fee, a funding payment, an absorption; the views `entry`, realized and unrealized profit, equity at given marks. An entry point that applies given fills with no venue. In OCaml, a reader of the fills file the advisor stores under `data/` (dated before 2026-11-01).
- **The tests must show:**
  1. One lot at 100 and two at 101, closed at 102, change cash by exactly 4 and never round; `entry` is `302/3`; a partial close leaves cost and position consistent; two opposite positions' funding sums to zero.
  2. Conservation (law A1) at every event of random sequences of fills, funding and one bankruptcy, as an equality of rationals with `absorbed` in it (GPT's finding 13).
  3. Every fee is its notional times its role's rate in the tier in force at its time, across a change of tier.
  4. **Layer 1:** for all 5,806 fills, the fee and `closedPnl` equal the venue's to its printed digits, `startPosition` chains exactly, every price is on V1's grid and every size a whole number of lots. The test prints every difference; the step is done at none.
- **Laws ★:** A1, U1.
- **Foreseeable walls:** a difference in layer 1 is a finding about V1, V3, V4 or the ledger. It goes to the architect with the fills that show it.

### 3. ◆ Events, admission, protected dates and the archive's reader (A3, A13, B1, B2)

- **Builds:** the event type with `time` and `known`; `start`, `feed`, `finish` over a machine that only admits, orders and counts; chunks; staleness; the protected windows as a tracked file compiled in; `mm2 inspect`; the DuckDB stubs and the archive reader; the merge; the manifest check of a coin-day against its raw files.
- **The tests must show:**
  1. C2: an event out of order, a crossed quote, a repeated trade id, a price off its coin's grid, a number out of range, each put the state in a rejecting state that `finish` reports with no report and no trace.
  2. **Protected dates (GPT's finding 16):** a horizon meeting an unreleased window is refused by `start`; a well-formed event dated in one, fed under any horizon, rejects; `mm2 inspect` on such a file prints counts, sizes, hashes and stale spans and no price; no command-line argument or header field changes any of this; a release in the tracked file changes the identity.
  3. C1: any cutting of an event list into chunks gives the same final state (property).
  4. Staleness is causal (GPT's finding 11): two markets equal through `t` are stale or not at `t` alike, whatever comes later; a coin is stale before its first quote and from `G` after its last.
  5. The reader equals `ingest/archive.py`, event for event, on 20 sampled coin-days across the three cadence periods, and names BTC's 2026-10-01 table as short of its raw files.
  6. **The wall of B5:** feeding 16 coins over 212 days, with no program, takes under 20 minutes on one core and under 2 GB.
- **Laws ★:** C1, C2.
- **Foreseeable wall:** the speed, with a double read by integer arithmetic for each of 18 billion numbers. If it fails, report the profile; a faster twin needs a proof that it equals the plain one.

### 4. The float evaluator, the clock, the view and inputs (A1, A4, A5's float half, B4)

- **Builds:** the parser and checker for programs with no slots; the float evaluator over declared sources, `state` and `flow`; `probes`; ticks; the view, fed by events at their `known`. Take `Ref/Source.lean`, `Ref/Resolve.lean` and the evaluator from the parked `stage7` tree if they build alone in `kernel2/lean`; otherwise write the evaluator from `reference/SEMANTICS.md` §1 to §5. Say which in the commit.
- **The tests must show:**
  1. **B4:** every expression of the frozen C6.4 corpus, at a tick of one hour, its inputs as observations and its nodes as probes, gives streams bit-identical to the Lean reference's, which the test stores under a hash. The two event counts are `flow` sources: defined at the tick they arrive and undefined after (Argon's finding 7).
  2. A tick finer than the data's cadence reads the latest known value of a `state` source and no window goes undefined; a `flow` source read at two ticks is not counted twice.
  3. An event is never read before its `known`. `high`, `low` and `traded` at the first tick cover the horizon's start to it; a program reading `traded` is refused by `start`, not by `check`, on a market with no trade source.
- **Laws:** L2, L3, L5, N1 restated over declared sources and proved; L1a ★ for the machine so far.

### 5. Exact expressions, slots, and orders as targets (A5, A6)

- **Builds:** the exact sort and the three crossings in the checker and evaluator; slots; cycles; own-state inputs from effects delivered `δ` late; reconciliation; admission, with margin's inputs given.
- **The tests must show:**
  1. A float literal where an exact one is required is a type error; `exact(f)` changes no value; a non-finite float makes its slot inactive. Two float evaluators that differ on a `when` place different orders, and two that agree on every `when` and every `exact(·)` argument place the same (GPT's finding 14).
  2. The ladder of A5 as a program: given a first fill at 10, its five wishes are at the published prices and targets exactly, on the grid.
  3. **A replacement does not buy twice (GPT's finding 9, Argon's 7):** a slot's target is 10; a price change at `τ` schedules a replacement; the old order fills 6 before `τ + λ`; the replacement fills at most 4, though the view still read `filled = 0` when it was wished.
  4. **`close` follows the position:** position 3 and a `close` take-profit that fills 1 has remainder 2, then 0 when flat; a level filling meanwhile raises the remainder with no replacement.
  5. A target below what has filled wants nothing. A target weight written as two `ioc` slots tracks 10, 15, 8, then 12 without going flat (Argon's finding 6).
  6. Cancel, expiry and replace each arise from reconciliation alone; a wish equal to the live order's price and target places nothing; reconciling twice equals once.
  7. Orders taking effect together are admitted in A6's order; each refusal names which condition failed; a sell that only reduces a long needs no margin; an order's requirement holds its taker fee.
- **Laws ★:** X1, R1, S1.

### 6. ◆ Fills: arrivals on quotes, resting orders on prints (A7)

- **Builds:** arrival; the trade event; resting orders and the two rules; allotment; fees through the schedule; `high`, `low`, `traded`; marks at prints; the reader of the recorder's streams through `mmrec cat`; the reader of `node_trades` once the bucket is certified, deduplicating by id.
- **The tests must show:**
  1. F0: for one order, each rule's fill is A7's, for every case of `b`, `a`, `p`, `tif`, remainder, print price and aggressor, a sell mirroring a buy.
  2. **One seller, once (Argon's finding 3, GPT's 6):** five levels and one seller standing 14.68 units below the lowest through five snapshots fill nothing under `pessimistic`. The same seller selling 14.68 in one sell-aggressor print fills 14.68 in all, best price first. A buyer lifting him fills nothing. A snapshot followed by a print of the same lots fills them once.
  3. Two orders arriving at one quote take a level once, best level first, in admission order. A print between an order's going live and its arrival quote does not fill it.
  4. A `pessimistic` venue on a market with no trade source is refused by `start`. A `reduce_only` fill is cut to the position and its rest cancelled.
  5. L1b: no fill on an event with `time ≤ τ + λ`; an order replaced at `τ` can still fill until `τ + λ`.
  6. A wick between two snapshots, present only as prints, fills under both rules. Argon's two whole-run constructions of round 1 run and invert as he says, kept as tests that no one claims a bound.
  7. An engine that never fills fails tests 1 and 2. The recorder's reader on synthetic streams reads every line and reports a killed run's gap as staleness.
- **Laws ★:** F0, E1, L4, L1b. F1 is a property test.

### 7. ◆ Margin, liquidation, the floor, listings (A9 to A12)

- **Builds:** marks; cross margin; the check after every event that moves cash or a mark; liquidation; bankruptcy; a listing's end; the full order of one event.
- **The tests must show:**
  1. M1 as an "exactly when", on both sides of the threshold by one unit of the last decimal.
  2. Fills come before the check at one event; a liquidation cancels every order and nothing fills after it.
  3. **Funding (GPT's findings 12 and 13):** a fill and a funding event at one timestamp: the payment is on the position held before the fill. A funding payment that takes a held account under maintenance liquidates it at that event, with no quote after.
  4. **A leverage of 1 (GPT's finding 13):** for a long-only account, cash after every fill is at least zero on every price path, fees included (property), and only a funding payment can liquidate it.
  5. L6: equity is never negative; after a bankruptcy every return is zero and `absorbed` is the shortfall, with A1 still an equality.
  6. **Two states (Argon's finding 7, GPT's 10):** two markets that differ only in a quote at `τ − δ/2`, which fills an order in one, have different worlds at `τ` and equal views and wishes at `τ`. Two markets equal through `t` have equal worlds through `t`, a later listing's end included.
- **Laws ★:** M1, L6, L1, L1a for the whole machine.

### 8. A market of bars (A16)

- **Builds:** the bar source and its header fields; the derivation of a quote and two prints from a bar, in Lean; a JSON bar reader.
- **The tests must show:**
  1. A resting buy fills under `pessimistic` exactly when a later bar's low is strictly below its price, and under `optimistic` exactly when it touches.
  2. An `ioc` buy fills at the next bar's open plus the half-spread, and pays the taker fee. A bar's open is known at the open and its extremes only at its close: a program never reads a high or a low of a bar still running, though a resting order can fill on them.
  3. The low comes first in a bar that closed at or above its open, else the high; a liquidation is checked at each extreme.
  4. Each of B1 to B4 is in the header and changes the identity; a bar market's run equals the run of its derived events fed as a book market.
  5. A year of four-hour bars for 16 coins runs in under a second.
- **Not built:** a generator of synthetic bar markets. It comes with the study that needs it.

### 9. The report, the identity, the SQLite ledger, the pool (A12, A13)

- **Builds:** the step and day rows with `pnl`, funding paid and `at_risk`; the trace; the identity hash; the ledger's `attempt` and `result` tables with `session`, `agent`, `parents`; alias maps; the process pool.
- **The tests must show:**
  1. P1: a report with two coins' columns swapped, a mid taken at the wrong end, or a fee left out of an equity fails against the world it came from (GPT's finding 15).
  2. Q1: on random long-only runs, with a coin going to zero inside a step while every live buy fills, a step's `pnl` plus its funding is never below minus its `at_risk`. An account with a short has no `at_risk`.
  3. UPDATE, DELETE and REPLACE are each rejected by the schema.
  4. **W1 (GPT's finding 17):** the process is killed before the attempt row, between the two rows, between the result row and the files, and after. In every case each run that started has an attempt row, and no report, trace or printed score exists without its result row.
  5. D1: one run twice, and on two hosts, gives byte-identical reports. Changing any hashed input changes the identity; changing nothing does not.
  6. N1 end to end: an aliased program on the aliased market gives the same trace up to names.
- **Laws ★:** P1, Q1.

### 10. ◆ Study 2's instruments (architecture 6)

- **Builds, in Lean:** the confirmer, a pure function from a report and a proposed mix to `V`'s lower bound at every step, `B` of the proposed mix and its certificate at every day's end, and the result: "timed" at a day, "earned" at a step, void, or neither. **In OCaml:** the proposer of a mix (any ascent; it is not trusted), the runner of layer 2, the decimation of the fast period, the block bootstrap.
- **The tests must show:**
  1. `V` is never negative: on paths where every held coin goes to zero in one step with every live buy filled, `V` stays at or above zero with `φ = 1`. A step whose funding exceeds V16 voids the run. A report with an undefined `at_risk` is refused.
  2. **Round 2's constructions, each "not timed":** a still coin against a moving one (GPT 1); a high-beta coin in a rising market; an account flat at every boundary that buys and sells inside each step of a rising market (GPT 2, Argon 1.1); a holder of a coin with negative funding (Argon 1.4); a coin delisted at a tenth of its price (GPT 3). For each, `V ≤ 20 × B` of a constant mix the test names.
  3. **K2 against a bad proposal:** for random reports and random proposed mixes, whenever the confirmer says "timed", `V ≥ 20 × B(b)` for 10,000 random mixes `b` and for every corner. A proposal far from the best never confirms more than the best does.
  4. "Timed" implies "earned" on every report.
  5. A simulated null, 20,000 paths of independent days with drift and fat tails, a dip-buying program: each rung is reached on at most 1,117 paths (`arithmetic.py.txt`; 1,000 would fail a test of exactly 5% half the time).
  6. Layer 2 on a synthetic vault whose orders stood ahead of the replica's in a generated book: no violation of the one-sided property. With quote evidence planted in the rule, the violations are listed.
- **Laws ★:** K1, K2.
- **Foreseeable wall:** K2 needs the inequality of arithmetic and geometric means over rationals. If the pinned Lean has no library holding it, it is proved by induction; no flake input is added.
- The replica's program, its trigger and the registered constants are not this brief's: they come with study 2's criteria.

## What the recorders must hold for the forward run

GPT's finding 18: a daily or weekly copy cannot show a rule that changed and changed back. Each row below says how a missed change would show.

| Needed | Source | State, and how a loss would show |
|---|---|---|
| Trades and books for the 17 coins | the websocket recorder: `trades` and five-level `l2Book` about every 0.55 s for every perp; 20 levels about every 10 s on the main dex | running since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST). A gap is staleness, reported |
| Settled hourly funding and oracle price | `fundingHistory`, by range | fetched at replay time; a missing hour aborts the run |
| Each coin's `szDecimals`, grid and margin tiers, dated | `meta` | **add:** in the hourly listings copy, for every dex. A change of lots or grid inside an hour makes recorded prices or sizes fail admission. Tiers do not enter study 2's judged run, which takes no leverage |
| The fee schedule, dated | the API's fee endpoint (a lead, to certify) | **add:** hourly with the listings. Its witness is the vault's own fills: at replay each one's fee over its notional must equal the schedule's rate, or the replay stops for the architect |
| The vault's fills in the forward window | `userFillsByTime` | **add:** hourly, stored unread like any recording. Each pull must contain the last fill of the pull before; a pull that does not has lost fills, and says so at once. An average rate is not a bound against the API's latest 10,000 |
| The vault's fills before 2026-11-01, as fetched | the session that fetched them | **now, by the advisor:** the raw responses stored under `data/` with their hash in the audit record; a session's scratch is not a copy |
| Trades for the archive's dates | `s3://hl-mainnet-node-data`, `node_trades` | to certify. **Required** since round 2: without it nothing before the freeze runs under `pessimistic` |
| Disk for two years | the recorder's volume, 300 Gi, one copy | full about 2027-05-20 at 1.6 GB a day; about 1.2 TB a copy for two years. The human's to buy (architecture 12) |

It lacks, for studies not yet designed: spot, and 20-level books off the main dex (both wait for a second IP).
