# Brief 3: build kernel version 2

Written 2026-11-14 07:52 UTC (02:52 EST) by Claude Fable 5.2; revised 2026-11-14 15:37 UTC (10:37 EST) after round 2 and 2026-11-14 17:31 UTC (12:31 EST) after round 3, and 2026-11-14 20:14 UTC (15:14 EST) after round 4, which replaced the report and the confirmer (steps 9 and 10). The contract is `audit/program/kernel-v2.md` (parts A and B); this brief orders its build. Study 2, which uses it, is `architecture.md` section 6. A design on branch `rearchitecture`: nothing here is built until its review has converged (`ledger.md`).

## How every step runs

1. **Tests first, by a session that does not build the step,** from this brief and `kernel-v2.md`, without reading the code. Steps marked **◆** decide a judged number, so their tests go to **another model** than the builder's: GPT, or a fresh Opus session labeled as such when GPT is out.
2. **The builder (Sonnet) makes them pass without editing them,** in one commit. A test the builder believes wrong goes back to its author with the reason.
3. **A wall the brief did not foresee goes to the architect as a question.** No flag, tolerance, special case or second path (`CLAUDE.md` §1). Each step names the walls I can foresee.
4. **Opus checks the commit against its step,** and runs the step's checks itself.
5. **★ laws:** each step that proves one first commits its statement alone in `kernel2/lean/Engine/Laws.lean`. Another model reads the statements against part B3 before any proof, looking for one an empty or constant engine would satisfy, for one the transitions of part A contradict (round 2 found four, round 3 three more, round 4 three), and for one written for buys or for order fills that is quantified over every fill. Then the proof; `checks.engine-proofs` prints each ★ law's axioms and admits only `propext`, `Classical.choice` and `Quot.sound`.

**Languages.** Lean 4.34.0 as the flake pins it, for everything that decides a number; core `Rat` for exact numbers. OCaml 5.4.1 with dune and Jane Street's stack (`core`, `async`, `ppx_jane`, `ppx_expect`, `base_quickcheck`, v0.17), `yojson`, `ocaml_sqlite3`, and hand-written C stubs. No Rust, no Python, no new flake input: every step's first test is that `flake.lock` is unchanged.

**Data a builder may read.** The archive before 2026-11-01 and the vault's fills before 2026-11-01. Nothing dated in [2026-11-01, 2027-01-31). From step 3 the executable enforces it (kernel A13); before that, and for every fixture of the recorder's format, data is synthetic.

**Layout.** `kernel2/lean` (Lake library `Engine`, no executable, no `IO`), `kernel2/ocaml` (dune project, executable `mm2`), `kernel2/KERNEL.md` (part A of `kernel-v2.md`, moved there at step 0 as the spec beside the code, with `kernel-v2.md` keeping parts B and C and linking to it).

**Owed by the architect before step 3:** in `KERNEL.md`, the chunk's layout and the canonical encoding of every event; **before step 4:** the program's JSON grammar, the float operators that name the hour restated in ticks, and funding's lateness rule; **before step 9:** the layout of the report's three kinds of row; **before step 10:** the exact form of the confirmer's rounding. A builder who meets one of these missing stops and asks.

## The steps

### 0. A Lean function called from OCaml, built by Nix

- **Builds:** both packages' skeletons; `packages.mm2`; `checks.engine-proofs`; `checks.mm2-tests`; OCaml in the dev shell; one C stub file that initializes Lean's runtime once and calls an exported `check`.
- **The tests must show:**
  1. `mm2 check` on a program file prints Lean's verdict, built offline in the Nix sandbox.
  2. `flake.lock` is byte-identical to `main`'s.
  3. A fixture theorem closed with `sorry`, one resting on a declared axiom and one on `native_decide` each fail `checks.engine-proofs`; without them the check passes.
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
  1. One lot at 100 and two at 101, closed at 102, change cash by exactly 4 and never round; `entry` is `302/3`; a partial close leaves `entry` as it was; two opposite positions' funding sums to zero.
  2. Conservation (law A1) at every event of random sequences of fills, funding and one bankruptcy, as an equality of rationals with `absorbed` in it (GPT's finding 13).
  3. Every fee is its notional times its role's rate in the tier in force at its time, across a change of tier.
  4. **Layer 1:** for all 5,806 fills, the fee and `closedPnl` equal the venue's printed values under one rounding of the exact value to the printed decimals, the mode found for each field on the first hundred fills and fixed in the test; `startPosition` chains exactly, every price is on V1's grid and every size a whole number of lots. The test prints every difference; the step is done at none.
  5. The replay is admitted like a run: a fill dated in an unreleased protected window rejects it, and its result is written through the same two ledger rows (from step 9; until then the test is marked as waiting on it).
- **Laws ★:** A1, U1.
- **Foreseeable walls:** a difference in layer 1 is a finding about V1, V3, V4 or the ledger. It goes to the architect with the fills that show it.

### 3. ◆ Events, admission, protected dates and the archive's reader (A3, A13, B1, B2)

- **Builds:** the event type with `time` and `known`; `start`, `feed`, `finish` over a machine that only admits, orders and counts; chunks; staleness; the protected windows as a tracked file compiled in; `mm2 inspect`; the DuckDB stubs and the archive reader; the merge; the manifest check of a coin-day against its raw files.
- **The tests must show:**
  1. C2: an event out of order, a crossed quote, a trade id repeated at one timestamp, a price off its coin's grid, a number out of range, each put the state in a rejecting state that `finish` reports with no report and no trace.
  2. **Protected dates (GPT's finding 16):** a horizon meeting an unreleased window is refused by `start`; a well-formed event dated in one, fed under any horizon, rejects; `mm2 inspect` on such a file prints counts, sizes, hashes and stale spans and no price; no command-line argument or header field changes any of this; a release in the tracked file changes the identity.
  3. C1: any cutting of an event list into chunks gives the same final state and the same rows in the same order (property), a cut inside one timestamp that carries a tick included. The reader refuses a coin-day file in which a trade id repeats, checked on disk; the engine's state does not grow with the count of trades fed (GPT's finding 14).
  4. Staleness is causal (GPT's finding 11): two markets equal through `t` are stale or not at `t` alike, whatever comes later; a coin is stale before its first quote and from `G` after its last.
  5. The reader equals `ingest/archive.py`, event for event, on 20 sampled coin-days across the three cadence periods, and names BTC's 2026-10-01 table as short of its raw files.
  6. **The wall of B5:** feeding 16 coins over 212 days, with no program, takes under 20 minutes on one core, and the state stays under 2 GB with the rows streamed out.
- **Laws ★:** C1, C2.
- **Foreseeable wall:** the speed, with a double read by integer arithmetic for each of 18 billion numbers. If it fails, report the profile; a faster twin needs a proof that it equals the plain one.

### 4. The float evaluator, the clock, the view and inputs (A1, A4, A5's float half, B4)

- **Builds:** the parser and checker for programs with no slots; the float evaluator over declared sources, `state` and `flow`; `probes`; ticks; the view, fed by events at their `known`. Take `Ref/Source.lean`, `Ref/Resolve.lean` and the evaluator from the parked `stage7` tree if they build alone in `kernel2/lean`; otherwise write the evaluator from `reference/SEMANTICS.md` §1 to §5. Say which in the commit.
- **The tests must show:**
  1. **B4:** every expression of the frozen C6.4 corpus, at a tick of one hour, its inputs as observations and its nodes as probes, gives streams bit-identical to the Lean reference's, which the test stores under a hash. The two event counts are `flow` sources: defined at the tick they arrive and undefined after (Argon's finding 7).
  2. A tick finer than the data's cadence reads the latest known value of a `state` source and no window goes undefined; a `flow` source read at two ticks is not counted twice.
  3. An event is never read before its `known`. At the first tick at which anything is known, `high`, `low` and `traded` cover the horizon's start to it; before it every input is undefined and no slot is active.
  4. **The view's staleness (GPT's finding 9, Argon's 5):** two markets that differ only in a quote inside `(τ − δ, τ]` give equal inputs at `τ`, though the world is stale in one and not the other. With `G ≤ δ` a quote is still read for `G` after it became known.
  5. A program reading `traded` is refused by `start`, not by `check`, on a market with no trade source.
- **Laws:** L2, L3, L5, N1 restated over declared sources and proved; L1a ★ for the machine so far.

### 5. Exact expressions, slots, and orders of one cycle (A5, A6)

- **Builds:** the exact sort and the three crossings in the checker and evaluator; slots; cycles; wishes and their arrival; effects, and own-state inputs as their fold `δ` late; admission, with margin's inputs given.
- **The tests must show:**
  1. A float literal where an exact one is required is a type error; `exact(f)` changes no value; a non-finite float makes its slot inactive. Two float evaluators that differ on a `when` place different orders, and two that agree on every `when` and every `exact(·)` argument place the same.
  2. The ladder of A5 as a program: given a first order filled at 10, its five wishes are at the published prices and targets exactly, on the grid. A first order that swept 0.1 at one level and 0.9 at the next gives `first_size = 1` and their mean price (Argon's finding 7).
  3. **A replacement does not buy twice:** a slot's target is 10; a price change at `τ` sends a new wish; the old order fills 6 before `τ + λ`; the new one fills at most 4, though the view still read `filled = 0` when it was wished.
  4. **`close` follows the position:** position 3 and a `close` take-profit that fills 1 has remainder 2; a level filling meanwhile raises the remainder with no replacement; a `close` wished while flat places nothing and is sent again; a buy slot of size `close` on a long places nothing (Argon's finding 2, round 4).
  5. A target below what has filled places nothing. A target weight written as two `ioc` slots tracks 10, 15, 8, then 12 without going flat; with a sale still in flight it reaches 12 at the first tick that sees the sale (Argon's finding 5, refuted as stranding).
  6. **One wish a slot a tick (GPT's finding 10):** with `λ` longer than two deciding ticks, wishes arrive in the order sent and no order is placed twice; an arriving wish equal to the live order changes nothing; an `ioc` that found nothing is sent again at the next tick; a refused order is tried again by the next wish.
  7. Orders placed together are admitted in A6's order; each refusal names which condition failed; a sell that only reduces a long needs no margin; an order's requirement holds its taker fee; a remainder under 10 USD is refused unless it closes the position exactly.
  8. **An order ends with its cycle (GPT's finding 3, Argon's 2).** GPT's construction: two units, a slot that has filled its one, its replacement on the way, a `close` at 40 that fills: the replacement places nothing, and the account loses 120, not 220. Argon's: a live buy of target 10 with 9 filled is cancelled at the fill that ends the cycle, and any number of later prints buy nothing. A new cycle's first order is placed no sooner than `δ + λ` after the old one's end. **A cycle ends at the fill (Argon's finding 4, round 4):** a `reduce_only` sell and a buy of one cycle arrive at one quote, the sell takes the position to zero, and the buy is cancelled before it fills.
  9. **A wish has no grid of its own (GPT's finding 5, round 4):** a buy wished at 1.0001 while `szDecimals` is 2 arrives after a listing event made it 3: the live order was cancelled at the event, and the wish places an order at 1.000. The position was open throughout, so no cycle ended.
  10. **Effects are everything (GPT's finding 10, Argon's 5):** on random runs, the view's `pos`, `filled`, `resting`, `resting_price` and equity equal the world's `δ` earlier at every tick, across an order placed with no fill, an `ioc` remainder cancelled, a refusal, a cycle's end, a liquidation and a bankruptcy.
- **Laws ★:** X1, R1, S1.

### 6. ◆ Fills: arrivals on quotes, resting orders on prints (A7)

- **Builds:** arrival; the trade event; resting orders and the two rules; allotment; fees through the schedule; `high`, `low`, `traded`; the coin's price, which a print moves; the count of taker fills near an earlier one (V10's diagnostic); the reader of the recorder's streams through `mmrec cat`; the reader of `node_trades` once the bucket is certified.
- **The tests must show:**
  1. F0: for one order, each rule's fill is A7's, for every case of `b`, `a`, `p`, `tif`, remainder, print price and aggressor, **with the sells written out and not derived from the buys' fixtures:** a resting sell at 100 fills under `pessimistic` on a buy-aggressor print at 101 (GPT's finding 7).
  2. **One seller, once:** five levels and one seller standing 14.68 units below the lowest through five snapshots fill nothing under `pessimistic`. The same seller selling 14.68 in one sell-aggressor print fills 14.68 in all, best price first. A buyer lifting him fills nothing. A snapshot followed by a print of the same lots fills them once.
  3. **The burden of proof (Argon's finding 4):** a print between an order's placement and its arrival quote fills it under `optimistic` and not under `pessimistic`. A buy that joins the best bid, book unchanged at the next quote, fills under neither. A quote whose ask is at or below a resting buy fills it under `optimistic` only.
  4. Two orders arriving at one quote take a level once, best level first, in admission order. Two `ioc` buys arriving at two snapshots of one standing seller both fill, and the second is in the report's count (V10, named).
  5. A `pessimistic` venue on a market with no trade source is refused by `start`. A `reduce_only` fill is cut to the position and its rest cancelled, under both rules.
  6. L1b: no fill on an event with `time ≤ τ + λ`; an order replaced at `τ` can still fill until `τ + λ`.
  7. A wick between two snapshots, present only as prints, fills under both rules. Argon's two whole-run constructions of round 1 run and invert as he says, kept as tests that no one claims a bound.
  8. An engine that never fills fails tests 1 and 2. The recorder's reader on synthetic streams reads every line and reports a killed run's gap as staleness.
  9. **No fill beats the tape (T1):** on random markets under both rules, every order fill is at a price no better than its coin's price after the fill's event; a maker buy under the last mid fills on a print under its own price and equity does not rise at that event. A print and a quote of one millisecond come in that order: an order arriving at the quote does not fill on the print under `pessimistic`.
  10. **The wall of B5 again,** with trades and a ladder program on 16 coins over 212 days: one hour, one core, the state under 2 GB.
- **Laws ★:** F0, E1, L4, L1b, and T1 for order fills. F1 is a property test.

### 7. ◆ Margin, liquidation, the floor, listings (A9 to A12)

- **Builds:** marks; cross margin; the check after every event that moves cash, a mark or a rule; liquidation; bankruptcy; a listing's change and end; funding by its hour; the full order of one event.
- **The tests must show:**
  1. M1 as an "exactly when", on both sides of the threshold by one unit of the last decimal. A print under a long's bid is its adverse price until the coin's next quote.
  2. Fills come before the check at one event; a liquidation cancels every order and nothing fills after it; its closes are A10's walk, each level at the lesser of its price and the coin's price, the tail at the last one's, so after a print under the bid nothing is sold above the print. **It ends every cycle (Argon's finding 4, round 4):** a wish on its way for a coin that was flat at the liquidation places nothing, and after a bankruptcy no wish places anything. A listing event that raises a held coin's maintenance above equity liquidates at that event; a listing's end closes the position at the settlement price with no fee, then runs the check.
  3. **Funding:** a fill and a funding event at one timestamp: the payment is on the position held before the fill. A funding payment that takes a held account under maintenance liquidates it at that event, with no quote after. An event late within its hour's lateness is accepted; a held hour with none aborts the run, the horizon's last hours included. **Layer 1's funding:** each of the vault's `userFunding` payments before 2026-11-01 is A9's from its own size and rate at the settlement's mid, and the differences are reported as V8's basis, not hidden by a rounding (marked as waiting until the advisor stores those rows).
  4. **Funding takes reserved cash (GPT's finding 5):** cash 101, a live buy that reserved 100, a funding payment of 2, then the buy fills: cash is negative, no law is broken, and the check runs. A later fall liquidates the account, and what was absorbed is a row of its own and in no fill's cash.
  5. L6: equity is never negative; `absorbed` is the shortfall and rises at no other time; after a bankruptcy every return is zero, with A1 still an equality.
  6. **Two states:** two markets that differ only in a quote at `τ − δ/2`, which fills an order in one, have different worlds at `τ` and equal views and wishes at `τ`. Two markets equal through `t` have equal worlds through `t`, a later listing's end included.
- **Laws ★:** M1, L6, T1 for every kind of fill, L1, L1a for the whole machine.

### 8. A market of bars (A16)

- **Builds:** the bar source and its header fields; the derivation of two prints and a quote, all at a bar's end, in Lean; a JSON bar reader.
- **The tests must show:**
  1. A buy resting since an earlier bar's close fills under `pessimistic` exactly when a bar's low is strictly below its price; under `optimistic` exactly when the low is at or below it, in the bar it was placed in too. Argon's bar (open 100, low 100, a buy at 99.5, half-spread 1%) fills under neither.
  2. **Arrival (GPT's finding 7, Argon's 6, round 4):** an `ioc` buy placed one millisecond before a bar's end fills at that bar's closing ask when its limit allows, is cancelled when it does not, and pays the taker fee; one placed at the bar's end arrives at the next bar's. **Known together:** with `δ` of 1 ms, 2 ms and one second, the first tick at or after a bar's end plus `δ` reads its extremes, its close and every fill in it, and no earlier tick reads any of them.
  3. The low comes first in a bar that closed at or above its open, else the high; a liquidation is checked at each extreme; a position is valued at the close.
  4. Each of B1 to B5 is in the header and changes the identity. A bar market's run equals the run of its derived events fed as a book market, with no rule of `known`, time or order that a book market lacks.
  5. `start` rejects a venue with `G < Δ` and a half-spread of zero; a missing bar makes its coin stale. A close of 10,000 on a grid of 1 with a half-spread of 0.00001 gives a bid of 9,999 and an ask of 10,001. A sell resting far under a high fills to the print's registered depth and no further (GPT's finding 8).
  6. A year of four-hour bars for 16 coins runs in under a second.
- **Not built:** a generator of synthetic bar markets. It comes with the study that needs it.

### 9. ◆ The report, the identity, the SQLite ledger, the pool (A12, A13)

- **Builds:** the report's three kinds of row: one for each cash flow, one for each universe coin at each day's end (its price, and by span the count, the least return and the three sums over its price events), one for the account at each day's end; rows streamed from `feed` to a private spool; the trace; the identity hash; the ledger's `attempt` and `result` tables with `session`, `agent`, `parents`; alias maps; the process pool.
- **The tests must show:**
  1. **P1, the books:** on random runs with liquidations and a bankruptcy, starting cash plus the rows' cash is the world's cash after every event, and a coin's rows' units sum to its position. A report with two coins swapped, a fee left out, an absorption inside a fill's cash, or a fill's row at any event but its own fails.
  2. **Round 4's three (GPT's findings 2 and 3, Argon's 2):** one unit at 100 with a sale resting at 50 and a print of 51, the coin never quoted again: the sale's row is at the print and equity is cash from then on. One unit each of two coins, cash −150, a quote of 1 on one: both closes and the absorption of 50.045 have rows at that event, equity is zero there and after, whether the other coin is quoted again or not. A fill in a day's last second and the price that follows it are in the rows whichever side of midnight the next quote falls.
  3. **The sums:** over quotes and prints alike, each sum is on its stated side of the exact rational sum and within the count of events times `2⁻¹²⁸`, a sum that is exactly zero included; the least return is exact; a funding event enters as minus the unit payment over the price, and one before the coin's first quote not at all; a settlement is the last return; a span restarts when a universe coin's listing ends; `start` refuses a universe coin not listed at the horizon's start.
  4. UPDATE, DELETE and REPLACE are each rejected by the schema.
  5. **W1:** the process is killed before the attempt row, between the two rows, between the result row and the files, and after. In every case each run that started has an attempt row, and no report, trace or printed score exists without its result row; the spool is not a report.
  6. D1: one run twice, and on two hosts, gives byte-identical reports. Changing any hashed input changes the identity; changing nothing does not.
  7. N1 end to end: an aliased program on the aliased market gives the same trace up to names.
- **Laws ★:** P1.

### 10. ◆ Study 2's instruments (architecture 6)

- **Builds, in Lean:** `confirm`, a pure function from the report's rows, the stake rule's `φ` and `d`, and proposed multipliers to the test ledger's wealth and the bar at every day's end, and the result: "outgrew" at a day, "earned" at a day, the ledger's end with its cause, a return below minus one, or none. **In OCaml:** the proposer of multipliers (any search; it is not trusted), layer 2's join and the runner of its measurement, the decimation of the fast period, the block bootstrap.
- **The tests must show:**
  1. **The ledger is never overdrawn (K1):** on random long-only runs at leverages of 1 and 5, with liquidations and bankruptcies, under random stake rules: its cash and units are never negative; with every held coin at zero its wealth is its cash; the account's `absorbed` changes nothing in it. A funding payment beyond its cash ends it at that event: an "earned" before stands and nothing is confirmed after. A fill that takes the account short ends it.
  2. **Nothing moves a stake but a fill (round 4, GPT's finding 1, Argon's 1.1):** GPT's account, ten units at 100, a bid of 0.2 at 99, a print of 102 or of 98, and a far wish after the fill: the ledger's factors are 1.01961 and 0.98019, and with the wish removed they are the same. Argon's ladder, whose next level is activated by a fill: 1.00500 and 0.99005. His two-coin account whose resting buy is cancelled by the other coin's exit: the ledger's units of the first coin are unchanged. On random runs the ledger's units of a coin change at that coin's fills and at no other event.
  3. **K1, the fold:** on random runs the wealth at each day's end computed from the rows equals, as rationals, the wealth of the same books carried through every event of the market.
  4. **Holdings, on every path:** on 10,000 random markets a ledger whose account buys at the first quotes and never trades is at or under the bar at every day's end, whatever the multiplier. Round 2's and 3's constructions are each never "outgrew": GPT's coin that doubles or halves twice a day, held; the same account selling a quarter into each first rise; two coins of equal drift, one delisted halfway; a still coin against a moving one; a high-beta coin in a rising market; a holder of a coin with negative funding; a coin delisted at a tenth of its price.
  5. **The limit of the claim, kept as a test (Argon's finding 1.2):** two coins quoted in turn, half the wealth in each, rebalanced at each pair. Where the second quote is independent of the first, 20,000 paths reach "outgrew" at most 1,117 times. Where it always moves against the first, the account does reach it, and the test asserts that: nobody is to claim the rung covers it.
  6. **K2 from above (GPT's finding 4):** for random reports and multipliers, whenever the confirmer says "outgrew", the wealth is at least 20 times the exact wealth, computed event by event, of 10,000 random mixes and of every corner. A multiplier of `3 × 2⁴⁰` with no returns gives a bar of at least 1. One return of 20,000 gives a bar of at least 20,001. A return below minus one confirms nothing from that day on.
  7. **K1 and K2 from below (GPT's findings 12 and 13):** a report built so that the wealth first reaches 20 at a known day is "earned" at exactly that day; one built so that it first reaches 20 times the bar of a given multiplier at a known day is "outgrew" at that day. The fixture is built against the bar, not against the best mix; the gap between the two is printed. A wealth of `2²⁰⁰ + 1` is within `2⁻¹⁰⁰` of itself. A confirmer that never confirms fails both.
  8. "Outgrew" implies "earned" on every report.
  9. **A simulated null,** 20,000 paths of independent price events with fat tails, prints leading quotes, with drift for rung 2 and without for rung 1, under a dip buyer at depths of one, two and the whole ladder, a buy-and-hold account, the quarter seller and GPT's account of test 2: each rung is reached on at most 1,117 paths (`arithmetic.py.txt`).
  10. **Layer 2** on a synthetic vault whose fills were generated in a book: every fill passes the wall; with one print removed from the record that fill is listed; a fill in a stale span is counted as stale and not as missing; a partial fill of 2 USD passes. The measurement's classes equal the planted ones, a witness order under the minimum and one refused at arrival included; counts of implied orders are labeled as under the residence assumption.
- **Laws ★:** K1, K2.
- **Foreseeable wall:** K2 joins a product over price events to three sums through two classical inequalities of real numbers, `log(1 + x) ≤ x − x²/2 + x³/3` and `e^D ≤ (1 − D/n)⁻ⁿ` for `D < n`. Core Lean has no real `exp`. If the pinned nixpkgs carries Mathlib for the pinned Lean, K2 is proved whole. If it does not, stop and ask: the answer I foresee is to prove in Lean everything that is arithmetic (the sums bracket; `D` bounds the cubic form for every mix; `D < n`; the bar is at least `(1 − D/n)⁻ⁿ`) and to keep the two inequalities on paper beside K3, held by test 6. No flake input is added.
- The replica's program, its trigger and the registered constants are not this brief's: they come with study 2's criteria.

## What the recorders must hold for the forward run

A copy taken at intervals cannot show a rule that changed and changed back between two of them (GPT's finding 12, round 3): each row below says what a loss would show as, and what nothing shows.

| Needed | Source | State, and how a loss would show |
|---|---|---|
| Trades and books for the 17 coins | the websocket recorder: `trades` and five-level `l2Book` about every 0.55 s for every perp; 20 levels about every 10 s on the main dex | running since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST). A gap is staleness, reported |
| Settled hourly funding and oracle price, by the hour settled | `fundingHistory`, by range | fetched at replay time; a missing hour aborts the run |
| Each coin's `szDecimals`, grid and margin tiers, dated | `meta` | **add:** in the hourly listings copy, for every dex. A change that a recorded trade crosses fails admission; one that no trade crosses, or that reverts inside the hour, is not seen (assumption V3). Tiers do not enter study 2's judged run, which takes no leverage |
| The fee schedule, dated | the API's fee endpoint (a lead, to certify) | **add:** hourly with the listings. Its witness is the vault's own fills: at replay each one's fee over its notional must equal the schedule's rate, or the replay stops for the architect. Nothing witnesses a change while the vault does not trade (assumption V4) |
| The vault's fills in the forward window | `userFillsByTime` | **add:** hourly, stored unread like any recording, **by pages:** from the watermark less an overlap, each page starting at the last item's time, inclusive, until a page comes back under the API's item cap; duplicates dropped by fill id; the watermark moves to the request's end only then. A page at the cap that cannot be continued stops the pull and says so. An unsaturated last page shows only that nothing indexed was lost. **A fill indexed late (GPT's finding 11, round 4):** once a day the whole registered delay behind the watermark is read again, and what it adds is appended and counted; a pull that returns more than half the API's retention of 10,000 raises an alarm. A fill indexed later than the registered delay is lost and nothing shows it (assumption V18) |
| The vault's funding payments | `userFunding`, by range | **add:** before 2026-11-01 now, stored with the fills; in the forward window hourly, by the same pages. Layer 1 and V8 read them (architecture 6.4) |
| The vault's order placements and cancels | `historicalOrders` (a lead, to certify) | **add if certified:** with the fills. It would turn layer 2's assumption about when the vault's orders stood into a record (GPT's finding 8). Without it the assumption stays one |
| The vault's fills before 2026-11-01, as fetched | the session that fetched them | **now, by the advisor:** the raw responses stored under `data/` with their hash in the audit record; a session's scratch is not a copy |
| Trades for the archive's dates | `s3://hl-mainnet-node-data`, `node_trades` | to certify. **Required** since round 2: without it nothing before the freeze runs under `pessimistic` |
| Disk for two years | the recorder's volume, 300 Gi, one copy | full about 2027-05-20 at about 1.6 GB a day. Two years' size is to be measured on the volume, every stream and what is already there included, and a second copy belongs to the choice. The human's, with its three runs (architecture 6.8) |

It lacks, for studies not yet designed: spot, and 20-level books off the main dex (both wait for a second IP).
