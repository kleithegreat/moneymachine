# Kernel version 2: semantics, the Lean and OCaml split, and the laws

Written 2026-11-14 UTC by Claude Fable 5.2 from `facts-kernel-v2.md` (`d8200f0`); revised 2026-11-14 07:43 UTC (02:43 EST) after Argon's round 1 (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r1.md`), whose seven findings are answered in part C. A design on branch `rearchitecture`. Part A is the contract the Lean engine is written from. Part B says which language holds what, and the laws. The build plan is `briefs/3-kernel-v2.md`; study 2, which needs this kernel, is `architecture.md` section 6.

Binding: maximal Lean, OCaml for the rest, no Rust or Python; strategies are data; version 2 is a clean-room design owing nothing to version 1's code (the human, 2026-11-14), and the frozen pilot kernel `mm` and its judged results are not rerun here.

## Part A. Semantics

### A1. One machine

Version 2 is one event-driven machine: a program places priced orders against recorded books and trades, and an exact ledger keeps its account. A **venue** is the record of what varies between runs: the fill rule (`optimistic` or `pessimistic`, A7), the order delay `λ`, the observation delay `δ`, the gap length `G`, the order cap and the minimum order. There is no second engine and no switch inside a rule.

Version 1's bar-and-cost-table fills are not in version 2 (A15). `mm` stays the pilot's instrument.

### A2. Numbers

There are two sorts of number, and the ledger holds only one.

- **Exact** numbers are rationals. Prices, sizes, money and rates are exact. The ledger's state is cash and a position in each coin; equity is cash plus each position times its mark. **Nothing in the ledger rounds.** Every amount it moves is a product of recorded decimals, so cash is always a finite decimal, and it is printed in full.
- **Float** numbers are binary64, evaluated in stage 6's operation order (`reference/SEMANTICS.md` §1, §5). Signals, windows and transcendental functions are floats.
- **Two crossings, both total.** `exact(f)` is the rational that the float `f` is; it changes no value. `float(e)` is the binary64 nearest the rational `e`, ties to even. A float that is not finite makes whatever reads it undefined.
- **Three roundings in the whole machine,** each of an exact value: a slot's price to the coin's price grid, away from the market (a buy down, a sell up); a slot's size to lots, toward zero; and the report's returns to binary64.
- **A recorded number enters as a decimal.** A source declares each field's scale `d` (8 for a price, `szDecimals` for a size, 12 for a rate). A stored double `x` is read as the decimal `n · 10⁻ᵈ` with `|n| < 10¹⁵` whose nearest binary64 is `x` bit for bit. At most one exists, since 15 significant digits survive binary64. If none exists the market is rejected (`E_DECIMAL`). There is no tolerance.

**Why.** Round 1 found two faults in the first draft, with one cause: I let floats compute an order's price and size and then rounded with a direction, and I kept money on an integer grid. The first moves `10 × 0.9775` one tick off the grid; the second cannot hold an average entry or a mid. Both go when the boundary is put where the meaning changes: a float decides *whether*, exact arithmetic decides *where and how much*, and a view such as average entry is a rational that needs no grid.

### A3. Time and events

Times are integer milliseconds. A market has a horizon `[w_start, w_end)` and a finite list of events. Each has a coin, a `time` at which it happened and a `known` time, at or after it, from which a program may see it.

| Kind | Holds | Class |
|---|---|---|
| listing | the coin's rules from `time` on: `szDecimals`, the price grid, margin tiers; or the end of its listing, with a settlement price | 1 |
| funding | the settled rate, and the oracle price when the source has it | 2 |
| quote | a snapshot: up to 20 bid and 20 ask levels, each a price and a size, best first | 3 |
| trade | a print: price, size, aggressor side | 3 |
| observation | one value of a declared source (a name, a unit, a float) | 3 |
| tick | the program's clock (A4); not in the market | 4 |

The machine consumes events in the order (time, class, coin, kind as listed, position in its source). Admission rejects a market whose events are out of that order, whose quote is crossed or one-sided (the reader drops and counts those; the count is in the identity), or whose numbers fail A2.

- **`known`.** A quote's and a trade's is `time + δ`. A funding row's and an observation's is given by its source's certificate. The ledger acts on an event at its `time`; the program sees it from its `known`.
- **Observations** are how any other data enters: version 1's bars, a forum count, a signal. The machine never builds one.
- **Gaps.** Two successive quotes of a coin further apart than `G` make a gap. Inside a gap the coin's price inputs are undefined, no order of that coin fills, and no check runs, since there is no evidence. The trace marks it; the report gives each coin's share of time in gaps and whether a position or an order was open across one.

### A4. The clock

The program declares `tick`, a whole number of seconds from 1 up, and `decide_every`, a whole number of ticks. Tick `k` is at `τ = k · tick`, for every `τ` in the horizon.
- At every tick, every event with `known ≤ τ` has been delivered and every expression is evaluated once. Windows count ticks.
- At every `decide_every`-th tick, counted from the epoch, the slots are read and reconciled (A6).
- An input's value at a tick is its latest delivered value. A tick with no new quote reads the same book as the tick before: that is what "latest known" means, and a window over a tick finer than the data's cadence is defined. Only a gap (A3) makes a price input undefined.

Fills, funding, margin and the floor are not on the clock: they happen at their events.

### A5. The language

Strategies stay data: one JSON AST, type-checked, interpreted.

**Header.** `version: 2`, `tick`, `decide_every`, and `leverage`, a number for each coin or one for all, at most the coin's maximum.

**Slots.** A program has a fixed list of at most 16 named slots, the same for every coin. A slot is a standing wish, not a command:

| Field | Type | Meaning |
|---|---|---|
| `kind` | `market`, `limit` | |
| `side` | `buy`, `sell` | |
| `when` | bool | the slot is active; undefined is false |
| `price` | exact, a price | `limit` only |
| `size` | exact, a size or a notional; or `close` | the amount this slot is to have filled in the current cycle; `close` is the whole position |
| `tif` | `gtc`, `alo`, `ioc` | `limit` only; `alo` is post-only |
| `reduce_only` | bool | the order never opens, and a fill is cut to the position |

A notional becomes a size by exact division by the slot's price (`limit`) or the latest known mid (`market`).

**A cycle** on a coin runs from the first fill while flat to the fill that makes it flat. A slot's `filled` counts within the cycle and resets when it ends. A slot whose `filled` has reached its `size` wants nothing more until the next cycle. This is the whole of a ladder's memory.

**Inputs.** All are per coin and delivered with a `known` time like any event:

| Input | Sort, unit | Value |
|---|---|---|
| `bid`, `ask`, `mid` | exact, price | the latest known quote's best prices and their mean |
| `bid_size`, `ask_size` | exact, size | the best levels' sizes |
| `high`, `low` | exact, price | the highest and lowest mid, and trade price where the market has trades, known since the last tick; the latest mid when nothing arrived |
| `traded` | exact, size | the size printed since the last tick; an unknown input (`E_UNKNOWN_INPUT`) on a market with no trades |
| `oracle`, `funding` | exact, price and rate | the latest known funding row's |
| `pos` | exact, size | the signed position |
| `entry` | exact, price | the position's cost over its size; undefined when flat |
| `first_price`, `first_size` | exact | the price and size of the cycle's first fill; undefined when flat |
| `age` | exact, ticks | ticks since the cycle's first fill; undefined when flat |
| `filled(slot)`, `resting(slot)`, `resting_price(slot)` | exact | the slot's fills this cycle, and its live order's remainder and price |
| `equity`, `free_margin` | exact, money | the account's, at mids and at adverse prices |
| a declared source's name | float, its unit | its latest known observation |

**Expressions.** Float expressions are stage 6's. Exact expressions are decimal literals, exact inputs, `+ − × ÷`, `min`, `max`, negation and `exact(f)`; a division by zero is undefined. Comparisons of either sort give a bool. A float expression reads an exact one through `float(e)`.

**Typing.** Stage 6's unit checker (L2) gains the sort, the units size and money, and the rule that price times size is money. A literal in an exact expression is the decimal as written. A slot's fields have the types of the table.

**Causality.** An own-state input is a function of the account's fills, and a fill at `t` is known at `t + δ`. So what a program reads at tick `τ` is a function of events with `known ≤ τ`, its own fills included (law L1). An order wished at `τ` cannot fill on evidence at or before `τ + λ` (law L1b). A program never fills against the book it saw.

**What the ladder looks like.** A `limit` entry slot whose `when` is the trigger; five `limit` `alo` buy slots at `first_price × 0.9775`, and so on, sized `first_size × 1`, `× 1.93`, …; one `limit` `reduce_only` sell slot of size `close` at `entry × 1.0056`. Every constant is a decimal, so `10 × 0.9775` is `9.775` and `1.93` coins are 193 lots. No kernel rule knows what a ladder is.

### A6. Orders

At a deciding tick `τ` each slot's wish is compared with its live order. The wish is the pair (price, `size − filled`), rounded as A2 says, or nothing when the slot is inactive or wants nothing more. If the wish differs from the live order, the live order is cancelled and the wished one placed, both taking effect at `τ + λ`. Until then the old order can still fill. So **cancel** is a slot going inactive, **expiry** is a `when` that reads `age`, and **replace** is a wish whose price or size has moved.

Orders taking effect at one time are admitted one by one: first every `reduce_only` order, then the others, each group by (coin, slot) in the program's order. An order is admitted only if
- with it, the initial margin of the positions and of every live opening order, each order valued at its limit price or, for a market order, the latest known ask, fits in equity at adverse prices (A10);
- its notional is at least the venue's minimum, 10 USD, unless it is `reduce_only` and closes the position exactly;
- its notional is at most the policy's cap.

Otherwise it is refused, with a reason in the trace, and the slot stays empty until the next deciding tick. The order of admission is a convention; it is in the identity.

### A7. Fills

Let an order go live at `ℓ = τ + λ`. Its **arrival** is the coin's first quote with `time > ℓ`. Write the best bid and ask there as `b`, `a`. For a buy (a sell mirrors):
- **market:** it takes the ask levels in order until it is filled or the levels end; the rest is cancelled.
- **limit, `a ≤ p`** (marketable): `alo` is refused; `gtc` and `ioc` take the ask levels priced at most `p`; the rest of a `gtc` rests at `p`, the rest of an `ioc` is cancelled.
- **limit, `a > p`:** it rests at `p`; an `ioc` is cancelled.

A fill at arrival is a taker fill at the levels' prices. Orders arriving at one quote take from it in admission order, and a level's size is taken once.

**A resting order fills on evidence.** At each later quote or trade of its coin, the record shows some number of lots that a seller offered at a price where this order stood first. The venue's rule says how many:

| | A quote | A trade at price `x`, size `s` |
|---|---|---|
| `optimistic` | `b ≤ p`: the whole remainder | `x ≤ p`: the whole remainder |
| `pessimistic` | the ask sizes priced strictly below `p`, if they cover the remainder; else nothing | `x < p`: `s` |

The order fills, as a maker, at `p`, the lesser of its remainder and its evidence. Evidence is allotted to the account's resting orders best price first, then by (slot), and **each recorded lot is allotted once at its event**, after that quote's arrivals have taken theirs. A `reduce_only` fill is cut to the position, and what is cut is cancelled.

**Why these.** Under `optimistic` no recorded bid is ahead of the order, so the next seller could have reached it: no fill can be earlier. Under `pessimistic` a seller sold, or rests, at a price worse for him than `p`, so he would have sold to this order first: every lot filled is a lot the record shows was offered through the price (assumption V10). Trade evidence adds up, because each print is a different sale. Quote evidence does not, because the same resting seller is in the next snapshot, so a quote can only complete an order.

**What the rules do not bound.** Fills feed back: a fill starts a take-profit, ends a cycle, frees margin. The two venues give two runs, and neither run's return bounds the other's or the truth's, in either direction (Argon's two constructions, round 1, finding 3). There is no law of whole runs. A study names the venue its claim is about (study 2: `pessimistic`), and measures both rules against an account that really traded.

**On a book that held the real order.** In the vault's own history its order was in the book, so `optimistic` fires when that order became the best bid and `pessimistic` only on flow beyond what filled it. That is what the rules mean: they price a second, identical order. A replica trading beside the vault is such an order.

**Cadence and trades.** The archive's snapshots are 0.54 s apart until 2026-06-15, 2.2 s for five days, then 5.4 s (facts §6). Without trades a wick between two snapshots fills a real order and leaves no trace, so `optimistic` is no longer the earliest fill and `pessimistic` misses more. With trades both rules see every print, and what is left between them is the queue alone. So **trade events are built**, not deferred: the forward recorder has carried `trades` for every perp since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST), and the judged run needs them. For the archive's dates the trades are in `s3://hl-mainnet-node-data`, to be certified and read within the 17.54 USD left (architecture 6); until then the archive runs are the rules' limit with no trade events, and the cost of the cadence is measured by decimating the fast period.

### A8. Fees

A fill's fee is its notional times the rate of its role, maker or taker, in the fee schedule in force at the fill's time, exactly. The schedule is a market input: a list of dated tiers. The fill's trace row records the role, the tier and the rate. Today the schedule has one tier, the venue's base (maker 0.015%, taker 0.045%), from 2026-04-03: every one of the vault's 5,806 fills paid it (facts §7). The simulated account does not move between tiers (assumption V4).

### A9. Funding

At a funding event of a coin at `time` with rate `ρ`, cash falls by `q · O · ρ` exactly, `q` being the position at that time, fills at it included, and `O` the event's oracle price, or where the source has none the mid of the latest quote at or before it. A coin with a position and no funding event within its hour's registered lateness aborts the run (`R_SETTLEMENT_MISSING`).

### A10. Margin and liquidation

**Marks.** The account is marked at mids for reporting and at adverse prices for every check: the bid for a long and the ask for a short, and at a trade the print's price when it is worse.

**Cross margin, one balance.** Maintenance is the sum over coins of notional times `1 / (2 · maxLeverage)` of the tier holding that notional. Initial margin is notional over the header's leverage, for positions and for live opening orders. At every quote or trade of a held coin, after that event's fills: if equity at adverse prices is below maintenance, the account is **liquidated**. Every order is cancelled, and every position is closed as a market order against its coin's latest quote, paying the taker fee, a remainder beyond the levels closing at the last level's price.

Fills come before the check because a resting bid fills as the price passes it, which is before the low. Isolated margin is not in version 2: no study uses it.

### A11. The floor

After a liquidation, if equity is not positive the account is **bankrupt**: equity is set to zero, the shortfall is recorded as `absorbed`, and every later return is zero. So equity is never negative and no step's return is below −1. A liquidation and a bankruptcy are events in the trace, so a study can end its test at the first of either (study 2 does).

### A12. One event, in order

1. **Listing:** the coin's rules change; a coin whose listing ends has its orders cancelled and its position closed at the record's settlement price.
2. **Funding:** A9.
3. **Quote or trade:** orders whose life starts or ends by now do so; arrival fills; resting fills; fees; cycles and `filled` updated; then marks, liquidation, the floor. An observation changes nothing here.
4. **Tick:** deliver, evaluate, and at a deciding tick reconcile.

A report step is a whole number of ticks. For each step the report gives the equity at mids at its end, exactly, its return in binary64, the long and short notional at mids, and every listed coin's mid, so that a study can form any benchmark from the report alone.

### A13. Identity and the ledger

A run's identity hashes the program, the market's every file, the venue (`λ`, `δ`, `G`, the cap, the minimum, the admission order), the fee schedule, the coin rules, the sources' scales and `known` rules, the reader's dropped-row counts, and the engine's build. The evaluation ledger is SQLite whose schema rejects UPDATE, DELETE and REPLACE.

**What a harness needs** (`docs/research/2026-11-13-argon-multiagent-strategy-research.md`, part 3, experiments 1, 2 and 6):
- **Budgets:** every ledger row carries a `session` and an `agent`, and the count of a session's rows is the budget's only meter. The kernel never stops a session; the harness does.
- **Team topologies:** a row carries `parents`, the rows its author had seen. A harness gives an agent a view, so islands, swarms and migrations are views of one ledger.
- **Anonymized inputs:** a market may carry an alias map, a bijection from source and coin names to opaque names. A program written in aliases runs as its translation (law N1), and the map is in the identity.

### A14. What the venue's terms and our certificates do not establish

| # | Not established | Assumed | Consequence if wrong | Checked by |
|---|---|---|---|---|
| V1 | The price grid | 5 significant figures and at most `6 − szDecimals` decimals (a lead) | A wished price off the real grid, by under one grid step | Every price of the vault's fills must lie on it |
| V2 | Order types and their rules | `gtc`, `ioc`, post-only refused when marketable, `reduce_only` cut to the position | A refused order that would have rested, or the reverse | The fills' `crossed` flag against each slot's `tif` |
| V3 | Lot sizes, leverage and tiers of 12 of the 17 coins, and any coin's history | Today's `meta`, constant since 2026-04-03 | Sizes off by a lot; a wrong maintenance | Every fill's size is a whole number of lots |
| V4 | The fee tiers and their history | The base tier, for every fill | Fees overstated for an account large enough to leave it | The vault's fills, exactly, to 2026-10-31 |
| V6 | Historical mark prices | Checks at the book's adverse side and at prints | A liquidation earlier than the venue's | Nothing; the vault was never liquidated |
| V7 | Who bears a shortfall | The venue: an account cannot owe (A11) | A levered account's loss is understated, and an exact test of it is not exact | A certificate, before any run that takes leverage above 1 (architecture 6) |
| V8 | The oracle price in history | The mid at the settlement | A funding payment off by the basis | `userFunding`, which gives the payment and so the price |
| V9 | An account's delays | `λ` and `δ` registered; results at two values | Fills and reactions too early | Nothing |
| V10 | Impact | Our order moves nobody; the policy caps an order's notional; the book refills between events | `pessimistic` is not certain for a large order | The evidence rule covers the order's own size at each event |
| V11 | Whether a resting order reserves margin | It does, at its limit price | A ladder needs more equity than the venue asks | Nothing; pessimistic |
| V12 | The queue | None: `optimistic` fills whole at a touch, `pessimistic` only on flow through the price | Fill timing between the two rules | The fill check's counts (13% of the vault's orders filled in parts) |
| V13 | That the record is complete | Gaps are marked and nothing happens in them | A liquidation or a fill inside a gap is missed | The report's gap shares |
| V14 | What is left after a liquidation | The remainder stays | Equity after a liquidation overstated | Nothing. Study 2 ends its test at the first liquidation |
| V15 | The market order's slippage limit | None beyond the 20 levels | A fill the venue would have cut short | Nothing; the cap keeps orders inside the levels |

### A15. Against version 1's nine choices (facts §2)

| Version 1 | Version 2 |
|---|---|
| The four-hour grid and hourly clock | `tick` and `decide_every` |
| No book, sub-bar price or own state | The inputs of A5 |
| One target weight a coin | Slots. A target weight is two `market` slots, a buy when `weight × equity ÷ mid − pos` is positive and a sell when negative; no slot kind is needed |
| The fill at the next open with a cost table | Not built. Version 2 fills against recorded books and trades only; a market of bars alone is not runnable, and bars are observations |
| One taker fee | The schedule and the role |
| Funding at the bar's open | At the oracle price, else the mid |
| Margin once a step | At every quote and trade |
| Delisting | Listing events |
| I7's conventions | A13 |

The nine defects' lessons are laws here and not ported code: no fill after a liquidation's cancel (K2: L4), no future listing in today's state (K1: L1), a bankrupt account stays bankrupt (K5: L6), REPLACE rejected (M4: B2). K3, K4 and K6 are about the target-weight loop and the reporting window, which do not exist.

## Part B. The split, and the laws

### B1. What is Lean

Everything that decides a number: the program's parser and checker; both evaluators; slots and reconciliation; the fill rules; the ledger, fees, funding, margin and the floor; the reading of recorded doubles as decimals; the trace and the report. One Lake library, `Engine`, in a new package `kernel2/lean`, with no executable and no `IO`. Exact numbers are core Lean's `Rat`.

- **The float evaluator is stage 6's semantics,** which is what a clean derivation produces for a language that stays the same typed AST: one fixed operation order, proved laws, and an oracle of 11.36 billion values. Its inputs are declared sources, as the parked stage 7 tree already has them (`Ref/Source.lean`, `Ref/Resolve.lean`). The build plan's first step takes those files if they stand alone, and otherwise writes the evaluator from `SEMANTICS.md` §1 to §5; either way B4 judges it. `reference/lean` on `main` is not edited.
- **The engine is written as its own specification:** plain, total, pure functions over lists and maps, with no second fast copy. A law is then a theorem about the code that runs. Only if the wall of B5 fails does a step get a faster twin, proved equal to it as stage 7's `csimp` replacements were.
- **The exported surface** is four pure functions, `@[export]`ed to C:
  - `check : String → String`, a program's JSON to a verdict;
  - `start : String → String → Except String State`, a program and a market's header (horizon, venue, policy, coin rules, fee schedule, sources and their scales, alias map);
  - `feed : State → Chunk → State`, a chunk being flat arrays of events: kinds, coins, `time`s, `known`s, and one `FloatArray` of values with offsets;
  - `finish : State → String`, which runs the clock to the horizon's end and gives the report and the trace.

### B2. What is OCaml

Everything that touches the world, and nothing that decides: one dune project, `kernel2/ocaml`, giving the executable `mm2`, on Jane Street's stack as the project decided (`core`, `async`, `ppx_expect`, `base_quickcheck`, v0.17, in the pinned nixpkgs).

- **Reading.** The archive's Parquet through DuckDB 1.5.2's C API, by hand-written C stubs (`docs/research/2026-11-13-argon-ocaml-parquet-duckdb.md`, a lead I accept). The recorder's hourly zstd streams of JSON lines through `mmrec cat` (`recorder/RECORDER.md`). Trades, when certified, in their source's format. Decimal strings become doubles by `Float.of_string`, which rounds correctly, and Lean recovers the decimal (A2), so the reader does no arithmetic. Headers and funding rows are JSON (`yojson`).
- **Merging** the coins' streams into the order of A3, and cutting chunks.
- **Calling Lean.** The executable is OCaml's; it links the engine's compiled C and Lean's static runtime through one stub file that initializes the runtime once and holds the `State` in a custom block whose finalizer releases it. One run a process, one thread in Lean.
- **Writing.** The SQLite ledger (`ocaml_sqlite3` 5.3.1; `sqlite3` is not an attribute of the pinned nixpkgs), reports and traces to disk, file hashes for the identity.
- **Orchestration.** A pool of processes sized from measured peak memory and free memory, and the command line.
- **Nix.** `packages.mm2` builds both; `checks.engine-proofs` type-checks every theorem with no `sorryAx`. OCaml 5.4.1, dune 3.21.1. Everything is in the pinned nixpkgs, so `flake.lock` does not move.

**The trust boundary.** Not proved: Lean's compiler and runtime, `Float` as the platform's double, the C stubs, DuckDB, OCaml's readers and merge, and the printing of JSON. What guards it:
- Lean re-checks the order of what it is fed (C2) and that every number is a decimal of its scale (A2), so a reader can only be wrong about content that is still well formed.
- Chunk boundaries cannot matter (C1).
- Each reader is compared, event for event, with an independent one on sampled coin-days: the archive's with `ingest/archive.py`, which stays a test's oracle outside the kernel.
- A coin-day's row count and hours are checked against its raw files' manifest (the defect of facts §6).

### B3. The laws

★ marks a law a judged number depends on: proved in Lean on the running code, its statement frozen before its proof. The rest are property tests or differentials as said. Round 1 showed that properties alone can be met by an engine that does nothing, so each rule also has a **characterization**: an "exactly when", which an empty engine fails.

**Causality**
- **L1 ★ Non-interference.** Two markets whose events with `known ≤ τ_k` are equal give equal machine states, wishes, orders and traces through tick `k`. Own-state inputs and listings are inside the statement.
- **L1b ★ No fill on what was seen.** An order wished at `τ` has no fill on an event with `time ≤ τ + λ`.

**Numbers and the language**
- **X1 ★ The crossing.** A placed order's price and size are the A2 roundings of its slot's exact values. A program with no `exact(·)` node places the same orders whatever the float evaluator returns.
- **X2 Decimals.** Reading a recorded double gives a decimal whose nearest binary64 it is, or rejects. A property test over every decimal of each scale's range sampled, and a differential with OCaml's printing.
- **L2 Units.** The instrumented machine never raises a unit or sort error; erasing them gives the executable values. Proved.
- **L3 Rewrites, L5 Binding, N1 Renaming.** As stage 6 and 7 state them, over declared sources. Proved, abstract numbers.

**Orders and fills**
- **R1 ★ Reconciliation.** A wish equal to the live order places and cancels nothing; reconciling twice at one tick equals once. Orders are admitted in A6's order, and an order is admitted exactly when A6's three conditions hold.
- **F0 ★ Fills, exactly.** At a quote or trade, a resting order's fill is the lesser of its remainder and its allotted evidence under the venue's rule of A7, and an arriving order's fill is A7's walk of the levels. No other fill exists.
- **E1 ★ Evidence once.** At one event the lots filled by resting orders and taken by arriving ones, level by level and print by print, are at most the lots recorded.
- **L4 ★ Fills are well formed.** Every fill belongs to one order live at its time. A maker fill is at the order's price; a taker fill at recorded levels' prices, each no worse than the limit. An order's fills sum to at most its size. A post-only order never takes. A `reduce_only` fill never raises the position in absolute value and never flips it. No order survives a liquidation.
- **F1 ★ The rules are ordered, one event at a time.** From one state at one event, each resting order's `pessimistic` fill is at most its `optimistic` fill. (Not a law of runs: A7.)
- **S1 ★ Cycles.** Within a cycle a slot's fills sum to at most its `size`; `filled` resets exactly when the position returns to zero.

**The ledger**
- **A1 ★ Conservation.** Cash is the starting cash, minus buys, plus sells, minus fees, minus funding, each exactly as A7 to A9 give it; equity at mids is cash plus positions at mids. `entry` is the cost of the open position over its size, so realized and unrealized profit, as views, sum with fees and funding to the change in equity. No operation of the ledger rounds.
- **U1 ★ Funding.** At every funding event of a held coin cash changes by exactly `−q · O · ρ`, and at no other time for funding. A held coin's hour with no event inside its lateness rejects the run.
- **M1 ★ Margin.** The account is liquidated at an event exactly when, after that event's fills, its equity at adverse prices is below its maintenance.
- **L6 ★ The floor.** Equity is never negative, every report step's return is at least −1, and after a bankruptcy every return is zero.

**The boundary**
- **C1 ★ Chunking.** `feed` over a list of events equals `feed` over any cutting of it into chunks.
- **C2 ★ Admission.** A fed event that is out of order, crossed, off its coin's rules or not a decimal of its scale puts the state in a rejecting state that `finish` reports, whatever follows.
- **D1 Determinism.** A run is a function of its program, market and header. In Lean this is purity; across the boundary it is tested by running twice, on two hosts.

**What is deliberately not a law.** That either venue's return bounds the truth. That the rules reproduce real fills: that is measured on the vault's own orders (architecture 6).

### B4. Against stage 6

Version 2 shares one thing with version 1: the float expression language. That is checked at full strength. Each program of the frozen C6.4 corpus (3,372 runs) is run with version 1's inputs given as observations, a tick of one hour and no slots, and its node streams equal `mm`'s bit for bit on every run. Expressions read nothing of the ledger, so no defect of `mm` can touch this.

Nothing else is compared with `mm`. Its ledger is binary64 and holds nine defects, so a comparison of decisions needs a list of excused differences, and round 1 showed that such a list excuses a broken engine (finding 6). The ledger's oracle is better than `mm`: 5,806 fills of a real account, each with the venue's own fee, realized profit and position (architecture 6, layer 1).

### B5. Scale

Study 2 runs a fixed rule a handful of times, not a search. The wall: one run of 16 coins over 212 days at every recorded snapshot (229 million quotes) finishes within one hour on one core and within 2 GB, since events stream and no book is kept. It is measured at the build plan's first slice that feeds quotes, before anything is built on top. A search over book markets at the pilot's scale is not a goal of version 2 (facts §9).

## Part C. Argon's round 1, answered

| Finding | Answer | What changed |
|---|---|---|
| 1. Directed rounding of binary64 moves `9.775` to `9.774` and 193 lots to 192; sizes and rates enter as floats with no rule | **Conceded.** The proposed tolerance is a patch: any tolerance has its own boundary. The cause is that floats computed the order | Two sorts and total crossings; slot prices and sizes are exact expressions; recorded doubles are read as the decimals they came from, or rejected (A2, A5, X1, X2) |
| 2. Conservation, average entry and one rounding a payment cannot all hold on integers | **Conceded.** The proposed finer unit and floors are patches. The cause is a grid for money | The ledger is rational and never rounds; cash is the state and `entry` a view; the rounding law is deleted (A2, A1) |
| 3a. Whole runs invert in both directions | **Already the design** (the first draft's "what they do not bound"), now with Argon's constructions cited. No venue is called conservative for a run | A7 |
| 3b. The trade-through counted one seller for every rung | **Conceded.** The cause is a rule about one order. Fills are now an allotment of recorded evidence over all the account's orders, each lot once | A7, E1, F0 |
| 3c. The vault's own order was in the archive's book | **Refuted as a defect, kept as the reading.** The rules price a second identical order, which is what a replica beside the vault is | A7 |
| 3d. F2 is false at arrival and under liquidation; trades unbuilt leave most of the calendar unbracketed | **Conceded.** F2 is deleted: no single-order monotonicity survives the allotment, and none is needed. Trade events are built (H11 is settled: now) | A7, B3 |
| 4. The threshold 20(1 + ε̄) is wrong under compounding | **Conceded.** No threshold is patched: the tested account cannot owe (architecture 6) | Architecture 6 |
| 5. The 16-coin hedge fails the 10 USD minimum; Kelly scaling fails initial margin | **Conceded.** The hedge is not an order at all: the benchmark is the unit the wealth is measured in. Legs, which existed only for the hedge, are deleted | A5, architecture 6 |
| 6. "First difference satisfies a K condition" passes a broken engine; part A contradicts `SEMANTICS.md` §7 | **Conceded.** Under the human's clean-room answer nothing needs the `table` venue but that comparison, so the venue, `target` and the comparison are deleted, and with them the contradictions | A1, A15, B4 |
| 7a. A tick finer than the data gives undefined bars | **Conceded.** The machine builds no bars; inputs are latest known values | A4, A5 |
| 7b. Simultaneous admission, depletion, `reduce_only` | **Conceded.** One admission order; evidence once; a `reduce_only` fill cut to the position | A6, A7 |
| 7c. One time an event; no horizon | **Conceded.** `time` and `known`; the horizon in the header | A3, B1 |
| 7d. No law on funding, cycles or progress | **Conceded.** U1, S1, and a characterization for every rule (F0, R1, M1) | B3 |
