# Kernel version 2: semantics, the Lean and OCaml split, and the laws

Written 2026-11-14 UTC by Claude Fable 5.2, session "architect: kernel version 2 and study 2", from `facts-kernel-v2.md` (`d8200f0`). A design on branch `rearchitecture`, not yet reviewed. Part A is the contract a Lean specification and an OCaml implementation are written from. Part B says which language holds what, and the laws. The build plan is `briefs/3-kernel-v2.md`; study 2, which needs this kernel, is `architecture.md` section 6.

Binding: maximal Lean, OCaml for the rest, no Rust or Python; strategies are data; the frozen pilot kernel `mm` and its judged results are not rerun here.

## Part A. Semantics

### A1. One machine, and what varies

Version 1 hard-wired a four-hour bar into its loop, its fills, its funding and its margin. Version 2 is one event-driven machine, and a **venue** is the record of rules that vary:

| Venue | Price evidence | Fills | Used for |
|---|---|---|---|
| `book-optimistic` | L2 snapshots | arrival against the book; a resting order at a touch (A7) | study 2 |
| `book-pessimistic` | L2 snapshots | arrival against the book; a resting order at a trade-through (A7) | study 2 |
| `table` | bars | market orders only, at the next bar's open with the cost table | the overlap with version 1 (B4) |

Everything else is shared: the clock, the language, orders, the ledger, fees, funding, margin, the floor, the trace. Version 1 is the `table` venue with a tick of one hour and a decision every fourth tick. There is no second engine and no switch inside a rule.

### A2. Numbers

- **The ledger is exact.** A price is an integer count of 10⁻⁸ USD, the finest the venue quotes. A size is an integer count of lots, a lot being 10^(−`szDecimals`) of the coin. Money is an integer count of 10⁻¹³ USD, so that a price times a size needs no rounding. A rate (fee, funding) is a decimal held as an integer and its scale.
- **Every rounding is against the account** and is at most one unit of money: a fee and a funding payment made round up, a funding payment received rounds down. Nothing else in the ledger rounds.
- **Expressions are binary64,** evaluated by the stage 6 evaluator unchanged in operation order (`reference/SEMANTICS.md` §1, §5). A float leaves the evaluator in two places only: a slot's price, rounded to the price grid away from the market (a buy down, a sell up), and a slot's size, truncated toward zero to lots. A float that is not finite makes the slot inactive.
- **A recorded price enters** as the decimal nearest its stored double at 8 places; a double further than 10⁻⁹ relative from that decimal rejects the market (`E_PRICE`).
- **Why.** Version 1 checked its float ledger against a second ledger to a tolerance (I5). With an exact ledger the accounting laws are theorems about the code that runs, and floats can choose an order but cannot corrupt a balance.
- **Returns** are computed once, at the report: the ratio of two exact equities, converted to binary64.

### A3. Time and events

Times are integer milliseconds. A market is a finite list of events, each with a coin, a time `t` and a kind:

| Kind | Holds | Class |
|---|---|---|
| listing | the coin's rules from `t` on: `szDecimals`, the price grid, margin tiers; or the end of its listing | 1 |
| funding | the settled rate, and the oracle price when the source has it | 2 |
| quote | a snapshot: up to 20 bid and 20 ask levels, each a price and a size, best first | 3 |
| range | a bar: its start, open, high, low, close, volume | 3 |
| trade | a print: price, size, aggressor side (only if a certified source has trades, A7) | 3 |
| tick | the program's clock (A4); not in the market | 4 |

The machine consumes events in the order (time, class, coin). Admission rejects a market whose events are not strictly ordered in each coin and kind, whose quote is crossed or one-sided (the reader drops and counts those; the count is in the identity), or which mixes quotes and ranges for one coin.

**Gaps.** A venue has a registered gap length `G`. Two successive quotes of a coin further apart than `G` make a gap. The machine does nothing inside a gap, since there is no evidence there; the trace marks it, and the report gives the share of each coin's time in gaps and whether a position or an order was open across one.

### A4. The clock

The program declares `tick`, any whole number of seconds from 1 up, and `decide_every`, a whole number of ticks. Tick `k` is at `τ = k·tick + δ`, with `δ` the observation delay of the market's policy.
- At every tick, every observation with `knownAt ≤ τ` is delivered and every expression is evaluated once. Windows count ticks.
- At every `decide_every`-th tick, counted from the epoch, the slots are read and reconciled (A6).
- A bar input is the bar of the tick interval just closed, built from quote mids (book venues) or given (the `table` venue, whose range events must be multiples of the tick). A quote's `knownAt` is `t + δ`; a bar's is its end plus `δ`; a funding row's is version 1's rule.

Fills, funding, margin and the floor are not on the clock: they happen at their events (A7 to A11).

### A5. The language

Strategies stay data: one JSON AST, type-checked, interpreted. Version 2 adds to version 1's surface; it removes `weight` as a special output and keeps it as a slot kind.

**Header.** `version: 2`, `tick`, `decide_every`, `leverage` (a number for each coin or one for all, at most the coin's maximum), `margin` (`cross`, or `isolated`), and `legs`.

**Legs.** A program is a list of named legs. A leg has its own slots and its own state. The account nets the legs' positions coin by coin, as the venue would, and margins the net. A program with one leg is the common case; a second leg exists so that a rule and its hedge can live in one account (study 2) without the hedge's fills corrupting the rule's average entry.

**Slots.** A leg has a fixed list of at most 16 named slots, the same for every coin. A slot is a standing wish, not a command:

| Field | Type | Meaning |
|---|---|---|
| `kind` | `target`, `market`, `limit` | |
| `side` | `buy`, `sell` | absent for `target` |
| `when` | bool | the slot is active; undefined is false |
| `price` | price | `limit` only |
| `size` | size, notional, or `close` | the amount this slot is to have filled in the current cycle; `close` is the leg's whole position |
| `tif` | `gtc`, `alo`, `ioc` | `limit` only; `alo` is post-only |
| `reduce_only` | bool | the order never exceeds the leg's position and never opens |
| `weight` | ratio | `target` only: version 1's target fraction of equity |

A notional is turned into a size at the slot's price (`limit`) or the last known mid (`market`).

**A cycle** of a leg on a coin runs from its first fill while flat to the fill that makes it flat. A slot's `filled` counts within the cycle and resets when the cycle ends. A slot whose `filled` has reached its `size` wants nothing more until the next cycle. This is the whole of the ladder's memory: a level that has filled does not fill again, and a level that has not rests.

**New inputs.** All are per coin, typed with version 1's units, and delivered with a `knownAt` like any observation:

| Input | Unit | Value |
|---|---|---|
| `bid`, `ask`, `mid` | price | the latest known quote's best prices and their mean (book venues) |
| `bid_size`, `ask_size` | size | the best levels' sizes |
| `oracle` | price | the latest known funding row's oracle price, where the source has it |
| `pos` | size | the leg's signed position |
| `entry` | price | the leg's average entry price; undefined when flat |
| `first_price` | price | the price of the cycle's first fill; undefined when flat |
| `age` | ticks | ticks since the cycle's first fill; undefined when flat |
| `filled(slot)`, `resting(slot)`, `resting_price(slot)` | size, size, price | the slot's fills this cycle, and its live order's remainder and price |
| `equity`, `free_margin` | money | the account's, at mids and at adverse prices |
| `leg(name, input)` | as the input | another leg's `pos`, `entry` or notional |

The `table` venue has no quote, so `bid`, `ask`, `mid` and the size inputs are unknown inputs there (`E_UNKNOWN_INPUT`), and `limit` slots are a type error (`E_NO_BOOK`).

**Typing.** Version 1's unit checker (L2) gains two units, size and money, and one rule: price times size is money. A slot's fields must have the types of the table above. A `reduce_only` slot may not be `target`. A slot may not read its own `resting` in its `when` in a way that makes the wish depend on the order it creates within one tick; the checker forbids nothing here, because the inputs it reads are those known at the tick, before reconciliation.

**Causality.** An own-state input is a function of the leg's fills, and a fill at time `t` is known at `t + δ`. So the state a program reads at tick `τ` is a function of events with `knownAt ≤ τ`, its own fills included, and non-interference (L1) is stated over the whole machine (B3). An order wished at `τ` cannot fill on evidence at or before `τ + λ` (A6). The program can never fill against the book it saw.

**What the ladder looks like.** One leg; a `limit` entry slot whose `when` is the trigger; five `limit` `alo` buy slots at `first_price` times (1 − 2.25%), and so on, with notional sizes in the published multiples of the entry; one `limit` `reduce_only` sell slot of size `close` at `entry` times 1.0056. No kernel rule knows what a ladder is.

### A6. Orders

At a deciding tick `τ` each slot's wish is compared with its live order. The wish is the pair (price, `size − filled`), or nothing when the slot is inactive or wants nothing more. If the wish differs from the live order, the live order is cancelled and the wished one placed, both taking effect at `τ + λ`, `λ` being the venue's registered order delay. Until then the old order can still fill. So:
- **cancel** is a slot going inactive;
- **expiry** is a `when` that reads `age` or the clock;
- **replace** is a wish whose price or size has moved.

An order is admitted at `τ + λ` only if, with it, the initial margin of the net positions and of every live opening order fits in the account's equity at adverse prices (A10); if its notional is at least the venue's minimum, 10 USD, unless it is `reduce_only` and closes the position exactly; and if its notional is at most the policy's cap. Otherwise it is refused, with a reason in the trace, and the slot stays empty until the next deciding tick. A `target` slot places version 1's order: a market order of size `trunc(weight · equity / price − held)`, under version 1's portfolio rules.

### A7. Fills

**The `table` venue** fills a market order as version 1 does: at the open of the first range starting at or after `τ + λ`, at the cost table's price, in full, and not at all if that range has no trade (I3).

**The book venues.** Let an order go live at `ℓ = τ + λ`. Its **arrival** is the coin's first quote with `t > ℓ`. Write the best bid and ask there as `b`, `a`. For a buy (a sell mirrors):
- **market:** it takes the ask levels in order until it is filled or the 20 levels end; the unfilled rest is cancelled.
- **limit, `a ≤ p`** (marketable): `alo` is refused; `gtc` and `ioc` take the ask levels priced at most `p`; the rest of a `gtc` rests at `p`, the rest of an `ioc` is cancelled.
- **limit, `a > p`:** it rests at `p`; an `ioc` is cancelled.

A fill at arrival is a taker fill at the levels' prices. A **resting** order is judged at each later quote, and fills as a maker, in full, at `p`:
- **optimistic, at a touch:** when `b ≤ p`. No recorded bid is ahead of it, so the next seller would reach it.
- **pessimistic, at a trade-through:** when the ask levels priced strictly below `p` hold at least the order's remainder. A seller has then rested below the order's price with at least its size left over, which he would have sold to it first.

Neither rule fills in part, and neither has a queue.

**What the two rules bound.** Take one order and suppose the book were seen continuously and our order moved nobody (assumption V10). A resting bid cannot fill while a recorded bid is above it, so the true fill is no earlier than the touch. And a seller who rests below `p` with the order's size left over would have filled it, so the true fill is no later than the trade-through. Between them the truth depends on the queue and on trades, which snapshots do not hold.

**What they do not bound.** Fills feed back: a fill starts a take-profit, ends a cycle, frees margin. So the two venues give two runs, and neither run's return bounds the other's or the truth's. Both are reported. The pessimistic run fills a dip-buyer only when price went through its level, which is when the fill is worst; the optimistic run also fills it at the exact low.

**The cadence.** The archive's snapshots are 0.54 s apart until 2026-06-15, 2.2 s for five days, then 5.4 s (facts §6). Both rules are monotone in the evidence: add snapshots and an order fills no later, under either rule (law F2, B3). Two consequences:
- The pessimistic rule stays valid at any cadence. Evidence that it saw is evidence that existed; a sparser record only makes it later, or miss.
- The optimistic rule stops being a bound. A wick that touches the price and recovers between two snapshots fills the real order and leaves no trace, so the true fill can precede the "optimistic" one. After 2026-06-21 a dip shorter than about 5 s is invisible to both rules.

So the two runs bracket the truth only up to wicks, and how much that is must be measured, not assumed: study 2's fill check counts, by cadence period, the vault's real maker fills that each rule reproduces (architecture 6). Decimating the fast period to the slow cadence, and rerunning, measures the cadence's cost directly on dates where the finer truth is known.

**What the trades bucket would add** (`s3://hl-mainnet-node-data`, not certified): every print between snapshots. With trade events the optimistic rule becomes "a print at or below `p`, or the touch", which is again the earliest possible fill at any cadence, and the pessimistic rule becomes "prints strictly below `p` of at least the order's size, or the trade-through", which is certain and earlier. The bracket then holds at any cadence, and its width is the queue alone. The machine already has the event kind; the rules above are their limit with no trade events.

### A8. Fees

A fill's fee is its notional times the rate of its role, maker or taker, in the fee schedule in force at the fill's time. The schedule is a market input: a list of dated tiers, each a maker and a taker rate. The fill's trace row records the role, the tier and the rate, so the tier is recorded per fill. Today the schedule has one tier, the venue's base (maker 0.015%, taker 0.045%), from 2026-04-03: every one of the vault's 5,806 fills paid exactly it (facts §7). The simulated account does not move between tiers (assumption V4).

### A9. Funding

At a funding event of a coin at time `t` with rate `ρ`, the account pays `q · O · ρ`, `q` being its net position in the coin at `t`, fills at `t` included, and `O` the event's oracle price. Where the source has no oracle price, `O` is the mid of the latest quote at or before `t` (book venues) or version 1's bar open (`table`). A coin with a position and no funding event within its hour's registered lateness aborts the run (`R_SETTLEMENT_MISSING`), as in version 1. Each leg is charged for its own position, so the legs' payments sum to the account's.

### A10. Margin and liquidation

**Marks.** At a quote the account is marked twice: at mids for reporting, and at adverse prices, the bid for a long and the ask for a short, for every check. At a range, adverse is the low for a long and the high for a short (version 1).

**Cross.** One balance. Equity is the balance plus each net position's unrealized profit. Maintenance is the sum over coins of notional times `1 / (2 · maxLeverage)` of the tier holding that notional. Initial margin is notional over the header's leverage, for net positions and for live opening orders. At every quote or range of a held coin, after fills: if equity at adverse prices is below maintenance, the account is **liquidated**: every order is cancelled, and every position is closed as a market order against that quote's levels (at the adverse extreme of a range), paying the taker fee, a remainder beyond the levels closing at the last level's price. What is left stays in the account.

**Isolated.** Each coin's position carries its own margin, taken from the balance at each opening fill as notional over leverage. The position is liquidated alone when its margin plus its unrealized profit at the adverse price is below its maintenance. Its loss is at most its margin: a shortfall is the venue's, and what is left of the margin is lost with it (assumption V5, the pessimistic reading). No study uses isolated margin; it is specified for the bracket account (architecture 6, D15) and is not built until a study names it.

### A11. The floor

After any liquidation, if equity is not positive the account is **bankrupt**: equity is set to zero, the shortfall is recorded as `absorbed`, every later return is zero, and the run goes on only to keep the trace's shape. So equity is never negative and no step's return is below −1. A liquidation and a bankruptcy are both events in the trace with their times, so a study can end its test at the first of either (study 2 does).

### A12. One event, in order

At an event's time, by class:
1. **Listing:** the coin's rules change; a coin whose listing ends is closed at its record's settlement price, as the current `SEMANTICS.md` says.
2. **Funding:** A9.
3. **Quote, range or trade:** orders whose life starts or ends by now do so; arrival fills; resting fills; fees; cycles and `filled` updated; then marks, liquidation, the floor.
4. **Tick:** deliver, evaluate, and at a deciding tick reconcile (A6).

A report step is a whole number of ticks; its return is the ratio of equities at mids at its ends.

### A13. Identity and the ledger

A run's identity hashes what version 1's did (I7) with the conventions now being: the venue and its parameters (`λ`, `δ`, `G`, the cap, the minimum), the fee schedule, the coin rules, the reader's dropped-row counts, and the engine's build. The evaluation ledger stays SQLite with triggers rejecting UPDATE and DELETE.

**What a harness needs** (`docs/research/2026-11-13-argon-multiagent-strategy-research.md`, part 3, experiments 1, 2 and 6):
- **Forced continuation and budgets:** every ledger row carries a `session` and an `agent`, and the count of a session's rows is the budget's only meter. The kernel never stops a session; the harness does.
- **Team topologies:** a row carries `parents`, the rows its author had seen. A harness gives an agent a view, the rows of a named set of agents, so islands, swarms and migrations are views of one ledger, and what each agent could see is on record.
- **Anonymized inputs:** a market may carry an alias map, a bijection from source names to opaque names. A program written in aliases runs as its translation (law N1, B3), and the map is in the identity.

### A14. What the venue's terms and our certificates do not establish

Each is an assumption. "Checked by" names evidence already readable; where there is none the consequence stands.

| # | Not established | Assumed | Consequence if wrong | Checked by |
|---|---|---|---|---|
| V1 | The price grid | 5 significant figures and at most `6 − szDecimals` decimals (a lead) | A wished price off the real grid; under one grid step an order | Every price of the vault's fills must lie on it |
| V2 | Order types and their rules | `gtc`, `ioc`, post-only refused when marketable, `reduce_only` capped at the position | A refused order that would have rested, or the reverse | The fills' `crossed` flag against each slot's `tif` |
| V3 | Lot sizes, leverage and tiers of 12 of the 17 coins, and any coin's history | Today's `meta`, constant since 2026-04-03 | Sizes off by a lot; a wrong maintenance | Every fill's size is a whole number of lots |
| V4 | The fee tiers, rebates and their history | The base tier, for every fill of the simulated account | Fees overstated for an account large enough to leave the base tier | The vault's fills, exactly, to 2026-10-31 |
| V5 | Isolated margin | A10 | Only the bracket account | Nothing |
| V6 | Historical mark prices | Checks at the book's adverse side | A liquidation earlier than the venue's, never later, on a snapshot | Nothing; the vault was never liquidated |
| V7 | Who bears a shortfall | The venue (A11) | A bankrupt account's loss is understated | Nothing. Study 2 ends its test at the first liquidation, so no claim rests on it |
| V8 | The oracle price in history | The mid at the settlement | A funding payment off by the basis, a few basis points of a payment | `userFunding`, which gives the payment and so the price |
| V9 | An account's delays | `λ` and `δ` registered, each at least one snapshot gap; results at two values | Fills and reactions too early | Nothing |
| V10 | Impact | Our order moves nobody; the policy caps an order's notional | The pessimistic rule is not certain for a large order | The trade-through's size condition covers the order itself |
| V11 | Whether a resting order reserves margin | It does | A ladder needs more equity than the venue asks | Nothing; pessimistic |
| V12 | Partial maker fills | None | Fill timing only; 13% of the vault's orders filled in parts | The fill check's counts |
| V13 | That the archive is complete | Gaps are marked and nothing happens in them | A liquidation or a fill inside a gap is missed | The report's gap shares |
| V14 | What happens after a liquidation | The remainder stays (A10) | Equity after a liquidation overstated | Nothing. As V7 |
| V15 | The market order's slippage limit | None beyond the 20 levels | A fill the venue would have cut short | Nothing; the cap keeps orders inside the levels |

### A15. Version 1's nine choices (facts §2)

| Version 1 | Version 2 |
|---|---|
| The four-hour grid and hourly clock | `tick` and `decide_every` (A4) |
| No book, sub-bar price or own state | The new inputs (A5) |
| One target weight a coin | Slots; `target` is one kind (A5) |
| The fill at the next open | The venue (A1, A7) |
| One taker fee | The schedule and the role (A8) |
| Funding at the bar's open | At the oracle price or the mid; the `table` venue keeps the open (A9) |
| Margin once a step, cross | At every price event; cross and isolated (A10) |
| Delisting | Listing events; the current text's rule (A12) |
| I7's conventions | A13 |

## Part B. The split, and the laws

### B1. What is Lean

Everything that decides a number: the program's parser and checker; the evaluator; slots and reconciliation; the three venues; the ledger, fees, funding, margin and the floor; the trace and the report's returns. It is one Lake library, `Engine`, in a new package `kernel2/lean`, with no executable and no `IO`.

- **The evaluator is reused, not rewritten.** Stage 6's `Ref` (on `main`, L1 to L6 proved, bit-identical to `mm` on 11.36 billion values) or the parked stage 7 tree, whose evaluator already takes its inputs from declared sources (`Ref/Source.lean`, `Ref/Resolve.lean`, L7 and L8). The new inputs of A5 are declared sources, so the second fits better; the build plan's step 0 settles which, by reading both. `reference/lean` on `main` is not edited: it stays the pilot's reference.
- **The exported surface** is four pure functions, `@[export]`ed to C:
  - `check : String → String`, a program's JSON to a verdict;
  - `start : String → String → Except String State`, a program and a market's header (venue, policy, coin rules, fee schedule, alias map);
  - `feed : State → Chunk → State`, a chunk being flat arrays of events (kinds, coins, times, and one `FloatArray` of values with offsets);
  - `finish : State → String`, the report and the trace.
- **What is proved is what runs.** The ledger is integers, so its laws are theorems about the compiled code with no numeric caveat. The evaluator's laws stay as stage 6 left them: proved over abstract numbers, with binary64 resting on the differential of B4.

### B2. What is OCaml

Everything that touches the world, and nothing that decides: one dune project, `kernel2/ocaml`, giving the executable `mm2`.

- **Reading.** Parquet through DuckDB 1.5.2's C API, by hand-written C stubs (`docs/research/2026-11-13-argon-ocaml-parquet-duckdb.md`, a lead I accept: `arrow-cpp` is C++, and no binding is in the pinned nixpkgs). One query a coin-day, ordered by time; the stubs copy each chunk's columns into arrays before the chunk is freed, and release OCaml's runtime lock while DuckDB works. Funding rows, coin rules, the fee schedule and policy are JSON (`yojson`).
- **Merging** the coins' streams into the order (time, class, coin), and cutting chunks.
- **Calling Lean.** The executable is OCaml's; it links the engine's compiled C and Lean's static runtime through one stub file that initializes the runtime once and holds the `State` in a custom block whose finalizer releases it. One run a process, one thread in Lean.
- **Writing.** The SQLite ledger (`ocaml_sqlite3`), whose schema rejects UPDATE, DELETE and REPLACE (the gate hunt's M4); reports and traces to disk; file hashes for the identity.
- **Orchestration.** A pool of processes sized from measured peak memory and free memory, and the command line.
- **Nix.** `packages.mm2` builds both; `checks.engine-proofs` type-checks every theorem with no `sorryAx`; OCaml 5.4.1, dune 3.21.1, `ctypes` not needed. Everything is in the pinned nixpkgs, so `flake.lock` does not move.

**The trust boundary.** Not proved: Lean's compiler and runtime, `Float` as the platform's double, the C stubs, DuckDB, OCaml's reader and merge, and the printing of JSON. What guards it:
- Lean re-checks the order of what it is fed (law C2), so the reader can only be wrong about content.
- Chunk boundaries cannot matter (law C1).
- The reader is compared with the existing one (`ingest/archive.py`) on sampled coin-days, event for event; that Python stays a test's oracle, outside the kernel, until it is ported or retired.
- The archive defect of facts §6 (a table with fewer hours than its raw files) becomes the reader's check: a coin-day's row count and hours against its raw files' manifest.

### B3. The laws

★ marks a law that a judged number depends on. It is proved in Lean on the running code, and its statement is frozen before its proof, as stage 7's were. The others are property tests, or hold by a differential as said.

**Causality**
- **L1 ★ Non-interference.** Two markets whose events with `knownAt ≤ τ_k` are equal give equal machine states, wishes, orders and traces through tick `k`. Own-state inputs are inside the statement.
- **L1b ★ No fill on what was seen.** An order wished at `τ` has no fill, arrival or resting, on an event with time at most `τ + λ`.

**The language** (stage 6's, restated over legs and slots)
- **L2 Units.** The instrumented machine never raises a unit error, with size and money as units; erasing units gives the executable values. Proved.
- **L3 Rewrites.** Every rule of R v1 preserves node values and traces. Proved, abstract numbers.
- **L5 Binding.** `inputUnavailable` exactly when a slot of the registry is unbound. Proved.
- **N1 Renaming.** For every bijection of source names, the renamed program on the renamed market gives the same trace up to the renaming. Proved.

**Orders and fills**
- **L4 ★ Fills.** Every fill belongs to one order that is live at its time. A maker fill is at the order's price. A taker fill is at recorded levels' prices, each no worse than the limit, taking no more than each level shows, in price order. An order's fills sum to at most its size. A post-only order never takes. A `reduce_only` order never raises the leg's position in absolute value and never flips it. A fill's fee is its notional times the rate of its role and tier at its time, rounded up.
- **R1 Reconciliation.** A wish equal to the live order places and cancels nothing. Reconciling twice at one tick equals once.
- **F1 ★ The rules are ordered.** On any admitted market, for one resting order: if the pessimistic rule fills it at a quote, the optimistic rule fills it at that quote or an earlier one.
- **F2 ★ The rules are monotone in evidence.** For one resting order, adding quotes to the market never makes its fill later, under either rule. (Not a law of whole runs: A7.)
- **F3 Trades.** On a market with no trade events, the trade-aware rules are the snapshot rules. Proved when trade events are built.

**The ledger**
- **A1 ★ Conservation.** At every event, equity at mids equals the starting equity plus realized and unrealized profit minus fees and funding, exactly. The legs' positions sum to the account's net position in every coin, and the legs' profits, fees and funding to the account's.
- **A2 ★ Average entry.** A leg's `entry` is the size-weighted mean price of its opening fills since it was flat, and a closing fill realizes its size times the difference between its price and `entry`.
- **A3 ★ Rounding.** Every rounding lowers equity, by less than one unit of money, and there is at most one for each fee and funding payment.
- **M1 ★ Margin.** The account is liquidated at an event exactly when, after that event's fills, its equity at adverse prices is below its maintenance. No order is admitted that takes initial margin above equity at adverse prices. An isolated position loses at most its margin.
- **L6 ★ The floor.** Equity is never negative, every report step's return is at least −1, and after a bankruptcy every return is zero.

**The boundary**
- **C1 ★ Chunking.** `feed` over a list of events equals `feed` over any cutting of it into chunks.
- **C2 ★ Admission.** A fed event that is out of order, crossed or off its coin's rules puts the state in a rejecting state that `finish` reports, whatever follows.
- **D1 Determinism.** A run is a function of its program, market and header. In Lean this is purity; across the boundary it is tested by running twice, on two hosts.

**What is deliberately not a law.** That either venue's return bounds the truth (A7). That the snapshot rules reproduce real fills: that is measured on the vault's own orders (architecture 6), by cadence.

### B4. Against version 1

Version 2 is not required to equal `mm` bit for bit, for two reasons. Its ledger is exact where `mm`'s is binary64. And `mm` holds the nine defects (K1 to K6, M1, M2, M4), which the current `reference/SEMANTICS.md` fixes and no engine implements; version 2's `table` venue implements the current text, and never the defects behind a switch. The frozen kernel's judged results stay its own. The overlap is checked in three parts, on the frozen C6.4 corpus (3,372 runs):

1. **The evaluator, bit for bit.** Each corpus program is lifted to version 2: one leg, one `target` slot, a tick of one hour, a decision every fourth tick. Its node streams equal `mm`'s on every run. Expressions read nothing of the ledger, so the defects cannot touch this, and it is the full strength of stage 6's check.
2. **The ledger, by replay.** The ledger can be driven by given fills in place of a venue's. `mm`'s own fills and funding rows, replayed, must give `mm`'s equity at every step until the run's first stop-out or bankruptcy, within the sum of two derived terms: `mm`'s own float tolerance (I5), and one price unit a fill, since version 2 rounds a table price to 10⁻⁸ USD against the account. The same replay, fed the vault's real fills, is study 2's accounting check; it is one mechanism.
3. **Decisions, with every difference named.** The whole `table` venue is run on the corpus and compared with `mm` step by step. A run agrees, or its first differing step satisfies the stated condition of one of K1 to K6 (or the stop-out at Λ = 4) in the current text. A difference that no defect's condition explains is a failure. The count of agreeing runs is reported, not judged. The nine strict-xfail tests (`gate/tests/test_kernel_defects.py`, `test_mechanism_defects.py`) are ported to run against `mm2` and must pass.

Where a size falls within 10⁻⁹ of a lot boundary, an exact ledger and a float one may truncate differently. Such steps are listed and counted with the K conditions.

### B5. Scale

Study 2 runs a fixed rule a handful of times, not a search. The wall: one run of 16 coins over 212 days at every recorded snapshot (229 million quotes) finishes within one hour on one core and within 2 GB, since events stream and no book is kept. A search over book markets at the pilot's scale (10 million evaluations) is out of reach at any plausible speed (facts §9) and is not a goal of version 2.
