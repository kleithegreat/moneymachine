# Kernel version 2: semantics, the Lean and OCaml split, and the laws

Written 2026-11-14 UTC by Claude Fable 5.2 from `facts-kernel-v2.md` (`d8200f0`). Revised 2026-11-14 15:29 UTC (10:29 EST) after round 2 by Argon and GPT (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r2.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r2.md`), answered in part C; round 1's answers are in `ledger.md` and in git (`2a4cd2a`). A design on branch `rearchitecture`. Part A is the contract the Lean engine is written from. Part B says which language holds what, and the laws. The build plan is `briefs/3-kernel-v2.md`; study 2, which needs this kernel, is `architecture.md` section 6.

Binding: maximal Lean, OCaml for the rest, no Rust or Python; strategies are data; version 2 is a clean-room design owing nothing to version 1's code. Version 1 (`mm`) is deleted, with a git tag for the archive, after study 1's last judged run (the human, 2026-11-14), so version 2 is the project's only kernel from then on and nothing here is compared with `mm`.

## Part A. Semantics

### A1. One machine, two states

Version 2 is one event-driven machine: a program places priced orders, and an exact ledger keeps its account against recorded quotes and prints. It has two states, and round 2's contradictions came from writing laws about one "machine state" that mixed them:

- **The world:** the ledger, the live orders and the book's latest quote. It acts on an event at the event's `time`.
- **The view:** what the program may read. It holds an event from the event's `known` time, and an **effect** on the account (a fill, a fee, a funding payment, a refusal, a cancellation, a liquidation) from the effect's time plus `δ`.

A **venue** is the record of what varies between runs: the fill rule (`optimistic` or `pessimistic`, A7), the order delay `λ`, the observation delay `δ`, the staleness length `G`, the order cap and the minimum order. There is no second engine and no switch inside a rule. A market of bars runs on the same machine, through a source that derives quotes and prints from bars under stated assumptions (A16).

### A2. Numbers

There are two sorts of number, and the ledger holds only one.

- **Exact** numbers are rationals. Prices, sizes, money and rates are exact. The ledger's state is cash and a position in each coin; equity is cash plus each position times its mark. **Nothing in the ledger rounds.**
- **Float** numbers are binary64, evaluated in stage 6's operation order (`reference/SEMANTICS.md` §1, §5). Signals, windows and transcendental functions are floats.
- **Three crossings, all total.** `exact(f)` is the rational that the float `f` is. `float(e)` is the binary64 nearest the rational `e`, ties to even. A comparison of floats gives a bool. A float that is not finite makes whatever reads it undefined.
- **Roundings,** each of an exact value: a slot's price to the coin's price grid, away from the market (a buy down, a sell up); a slot's size to lots, toward zero; the report's returns to binary64; and the confirmer's wealth, downward (architecture 6).
- **A recorded number enters as an integer.** A source declares each exact field's scale `d`, from 0 to 12 (8 for a price, `szDecimals` for a size, 12 for a rate), and the engine receives the integer `n` of `n · 10⁻ᵈ`. A source declares one of two encodings:
  - `string`: the venue's decimal string, which the reader turns into `n` with no arithmetic but the placing of digits. A string with more decimals than the scale, or with `|n| ≥ 10¹⁵`, rejects the market (`E_DECIMAL`). The recorder's streams and the API are this.
  - `double`: a stored binary64, as the archive's Parquet holds. The engine reads it as the one `n` with `|n| < 10¹⁵` whose nearest binary64 it is, bit for bit, or rejects. Decimals of that range are at least four units in the last place apart, so at most one exists (law X2).
- **What a double cannot say.** The range is `|n| < 10¹⁵` at the declared scale, not "15 significant digits": a price of `10⁷` at scale 8 is rejected, and no recorded price is within a factor of fifty of it. A double that was never a decimal can still be the nearest of one; nothing that reads doubles can see that. What catches it is the coin's grid: such a value has more than five significant figures and admission rejects it (C2). Float observations are never read as decimals.

### A3. Time and events

Times are integer milliseconds. A market has a horizon `[w_start, w_end)` and a finite list of events. Each has a coin, a `time` at which it happened and a `known` time, at or after it.

| Kind | Holds | Class |
|---|---|---|
| listing | the coin's rules from `time` on: `szDecimals`, the price grid, margin tiers; or the end of its listing, with a settlement price | 1 |
| funding | the settled rate, and the oracle price when the source has it | 2 |
| quote | a snapshot: up to 20 bid and 20 ask levels, each a price and a size, best first | 3 |
| trade | a print: its venue id, price, size, aggressor side | 3 |
| observation | one value of a declared source (a name, a unit, a float; a `state` or a `flow`) | 3 |
| tick | the program's clock (A4); not in the market | 4 |

The machine consumes events in the order (time, class, coin, kind as listed, position in its source). Admission rejects a market whose events are out of that order, whose quote is crossed or one-sided (the reader drops and counts those; the count is in the identity), whose trade repeats an id (a source that writes a match twice, once a side, is deduplicated by the reader, counted), whose numbers fail A2 or the coin's grid, or whose time lies in a protected window (A13).

- **`known`.** A quote's and a trade's is `time + δ`. A funding row's and an observation's is given by its source's certificate. An effect's is its time plus `δ`.
- **Observations** are how any other data enters: bars as signals, a forum count. A `state` source's value at a tick is its latest known observation. A `flow` source's is the sum, in order of delivery, of those that became known since the last tick, and undefined when none did. A quote is a state and a print is a flow; a declared source says which it is.
- **Staleness.** A coin is stale from its latest quote's `time + G` until its next quote, before its first quote, and after its last. It is causal: nothing later decides it. While a coin is stale its price inputs are undefined, no order of it fills, and its mark is its last mid. The trace marks it; the report gives each coin's stale share and whether a position or an order was open across it.

### A4. The clock

The program declares `tick`, a whole number of seconds from 1 up, and `decide_every`, a whole number of ticks. Tick `k` is at `τ = k · tick`, for every `τ` in the horizon.
- At every tick the view takes every event and effect that has become known, and every expression is evaluated once. Windows count ticks.
- At every `decide_every`-th tick, counted from the epoch, the slots are read and reconciled (A6). The interval from one deciding tick to the next is a **step**.
- A tick with nothing new reads what the tick before read. Only staleness makes a price input undefined.

Fills, funding, margin and the floor are not on the clock: they happen at their events.

### A5. The language

Strategies stay data: one JSON AST, type-checked, interpreted. Its grammar and the canonical encoding of every event are part of the spec beside the code (`kernel2/KERNEL.md`) and are owed before the build's step 4 (part C, finding G15).

**Header.** `version: 2`, `tick`, `decide_every`, `leverage` (a number for each coin or one for all, at most the coin's maximum), and `probes`, named expressions written to the trace at every tick.

**Slots.** A program has a fixed list of at most 16 named slots, the same for every coin. A slot is a standing wish, not a command:

| Field | Type | Meaning |
|---|---|---|
| `side` | `buy`, `sell` | |
| `when` | bool | the slot is active; undefined is false |
| `price` | exact, a price | every order has one |
| `size` | exact, a size or a notional; or `close` | the **target**: what this slot is to have filled in the current cycle. `close` has no target: its order's remainder is the position |
| `tif` | `gtc`, `alo`, `ioc` | `alo` is post-only |
| `reduce_only` | bool | a fill is cut to the position |

There is no market order. An order that must fill now is an `ioc` at a price the program states, such as `ask × 1.01`; so every buy has a largest cost, known when it is placed. A notional becomes a size by exact division by the slot's price.

**A cycle** on a coin runs from the first fill while flat to the fill that makes it flat. A slot's `filled` counts within the cycle and resets when it ends. This is the whole of a ladder's memory.

**Inputs.** All are per coin, read from the view:

| Input | Sort, unit | Value |
|---|---|---|
| `bid`, `ask`, `mid` | exact, price | the latest known quote's best prices and their mean |
| `bid_size`, `ask_size` | exact, size | the best levels' sizes |
| `high`, `low` | exact, price | the highest and lowest mid and print price that became known since the last tick (at the first tick, since the horizon's start); the latest mid when nothing did |
| `traded` | exact, size | the size printed in the same interval; on a market with no trade source, `start` rejects a program that reads it (`E_UNKNOWN_INPUT`) |
| `oracle`, `funding` | exact, price and rate | the latest known funding row's; `oracle` is undefined when the row has none |
| `pos`, `entry` | exact | the signed position, and its cost over its size (undefined when flat) |
| `first_price`, `first_size`, `age` | exact | the cycle's first fill, and ticks since it; undefined when flat |
| `filled(slot)`, `resting(slot)`, `resting_price(slot)` | exact | the slot's fills this cycle, and its live order's remainder and price |
| `equity`, `free_margin` | exact, money | the account's, at mids and at adverse prices |
| a declared source's name | float, its unit | A3 |

Own-state inputs are computed from the effects the view holds, so they lag the world by `δ`.

**Expressions.** Float expressions are stage 6's; where one of its operators names the hour, version 2 counts ticks. Exact expressions are decimal literals, exact inputs, `+ − × ÷`, `min`, `max`, negation and `exact(f)`; a division by zero is undefined. Comparisons of either sort give a bool. A float expression reads an exact one through `float(e)`.

**Typing.** Stage 6's unit checker (L2) gains the sort, the units size and money, and the rule that price times size is money. A literal in an exact expression is the decimal as written.

**What the ladder looks like.** An entry slot whose `when` is the trigger; five `alo` buy slots at `first_price × 0.9775`, and so on, with targets `first_size × 1`, `× 1.93`, …; one `reduce_only` sell slot of size `close` at `entry × 1.0056`. Every constant is a decimal. No kernel rule knows what a ladder is. A target weight is two `ioc` slots, the buy's target `filled(buy) + max(0, w × equity ÷ ask − pos)` and the sell's its mirror: both terms come from one view, so a fill in flight is subtracted once by the world (A6).

### A6. Orders

**An order is a price and a target, never a quantity.** At a deciding tick `τ` each slot's wish, the pair (price, target) rounded as A2 says, or nothing when the slot is inactive, is compared with its live order. If they differ, the live order is cancelled and the wished one placed, both taking effect at `τ + λ`; until then the old order can still fill. The world, not the view, computes what an order may still fill: its **remainder** is its target minus the slot's fills in the cycle so far, never below zero, and for `close` the position. So a fill between the wish and its taking effect is never bought twice, a target that falls below what has filled wants nothing, and a take-profit follows the position without being replaced.

**Cancel** is a slot going inactive, **expiry** a `when` that reads `age`, **replace** a wish whose rounded price or target has moved.

Orders taking effect at one time are admitted one by one: first every `reduce_only` order, then the others, each group by (coin, slot) in the program's order. What an order **opens** is the amount by which filling its remainder would raise the position's absolute size. An order is admitted only if
- with it, the initial margin of the positions and of what every live order opens, at its limit price, plus each such order's taker fee, fits in equity at adverse prices (A10);
- its notional is at least the venue's minimum, 10 USD, unless it opens nothing and closes the position exactly;
- its notional is at most the policy's cap.

Otherwise it is refused, with a reason in the trace, and the slot stays empty until the next deciding tick. At a leverage of 1 the first condition says that live buys and their fees fit in cash, so cash is never negative after a fill.

### A7. Fills

Let an order go live at `ℓ = τ + λ`. Its **arrival** is the coin's first quote with `time > ℓ`; before it the order is not in the book and nothing fills it. Write the best bid and ask there as `b`, `a`. For a buy at `p` (a sell mirrors):
- **`a ≤ p`** (marketable): `alo` is refused; `gtc` and `ioc` take the ask levels priced at most `p`, best first; the rest of a `gtc` rests at `p`, the rest of an `ioc` is cancelled.
- **`a > p`:** it rests at `p`; an `ioc` is cancelled.

A fill at arrival is a taker fill at the levels' prices. Orders arriving at one quote take from it in admission order, each from what the ones before left.

**A resting order fills on flow.** Round 2 found that allotting evidence once an event still spent one seller many times, across snapshots and between a snapshot and a print. The cause was counting a quote as evidence: a quote shows who is standing, and the same seller stands in the next one. A print is a sale that happened once. So only prints fill a resting order:

| | A print at price `x`, size `s`, against a resting buy at `p` |
|---|---|
| `pessimistic` | a **sell-aggressor** print with `x < p`: `s` lots |
| `optimistic` | any print with `x ≤ p`, or a quote with `b ≤ p`: the whole remainder |

Under `pessimistic` the order fills, as a maker at `p`, the lesser of its remainder and the lots allotted to it. A print's lots are allotted to the account's resting orders it qualifies for, best price first, then by slot, **each lot once**. Since a print is one event with one id, no lot is counted twice in a run. A `reduce_only` fill is cut to the position, and what is cut is cancelled.

**Why these.** A seller who hit a bid below `p` would have hit this order first: his lots are offered through the price. A buyer lifting an ask priced under `p` proves only that someone stood there, and in a book that held this order he would have traded at arrival, where the taker rule already took him. `optimistic` is the first moment the record does not exclude a fill; it is a fiction of unlimited size, named so, and the law about recorded lots (E1) is about `pessimistic` alone. A `pessimistic` venue needs a trade source: `start` rejects one on a market without it.

**What the rules do not bound.** Fills feed back: a fill starts a take-profit, ends a cycle, frees margin. Neither run's return bounds the other's or the truth's (Argon's two constructions, round 1). There is no law of whole runs. For one order against the vault's own order at the same price, there is a bracket, and it is measured (architecture 6.3): the real order stood ahead, so it filled no later than `pessimistic` fills.

**What is assumed (V10).** Our orders move nobody: a taker fill does not thin the next snapshot, and every print would have happened as recorded. The policy's cap keeps an order inside the first levels. This is a hypothesis about replenishment, not evidence.

### A8. Fees

A fill's fee is its notional times the rate of its role, maker or taker, in the fee schedule in force at the fill's time, exactly. The schedule is a market input: a list of dated tiers. The fill's trace row records the role, the tier and the rate. Today it has one tier, the venue's base (maker 0.015%, taker 0.045%), from 2026-04-03 (facts §7). The simulated account does not move between tiers (V4). A listing's settlement charges no fee.

### A9. Funding

At a funding event of a coin at `time` with rate `ρ`, cash falls by `q · O · ρ` exactly, `q` being the position held into that time, before any fill at it (funding's class is before a quote's), and `O` the event's oracle price, or where the source has none the latest mid. Then the margin check of A10 runs. A coin with a position and no funding event within its hour's registered lateness aborts the run (`R_SETTLEMENT_MISSING`).

### A10. Margin and liquidation

**Marks.** The account is marked at mids for reporting and at adverse prices for every check: the bid for a long and the ask for a short, and at a print its price when it is worse.

**Cross margin, one balance.** Maintenance is the sum over coins of notional times `1 / (2 · maxLeverage)` of the tier holding that notional. Initial margin is notional over the header's leverage. **After every event that changes cash or a mark** (a quote or a print of a held coin after its fills, a funding payment, a listing's end): if equity at adverse prices is below maintenance, the account is **liquidated**. Every order is cancelled, and every position is closed against its coin's latest quote, level by level, paying the taker fee, a remainder beyond the levels closing at the last level's price.

Fills come before the check because a resting bid fills as the price passes it. Isolated margin is not in version 2.

### A11. The floor

After a liquidation, if equity is not positive the account is **bankrupt**: cash is raised by the shortfall, which is recorded as `absorbed`; equity is zero and every later return is zero. A liquidation and a bankruptcy are effects in the trace.

**The floor is a gift, and the ledger says so.** `absorbed` is money the venue paid. An account that can receive it has a higher mean than its prices give it, so no test of prices is exact on it (architecture 6.2). An account at a leverage of 1 holding longs cannot be liquidated by a price (A6); only funding can reach its cash.

### A12. One event, in order

1. **Listing:** the coin's rules change; a coin whose listing ends has its orders cancelled and its position closed at the settlement price, then the check.
2. **Funding:** A9.
3. **Quote or print:** orders whose life starts or ends by now do so; arrival fills; resting fills; fees; cycles and `filled` updated; then marks, the check, the floor. An observation changes nothing here.
4. **Tick:** deliver, evaluate, and at a deciding tick reconcile.

**The report** has a row for each step: equity at mids at its end, exactly; its change over the step (`pnl`); the funding paid in it; the long and short notional at mids; and `at_risk` at its start, which for an account with no short and no order that can open one is the positions at mids plus, for every buy live or pending, its price times its remainder with its taker fee, and is otherwise undefined. And a row for each day and each coin of the header's universe: the mid at the day's start and end and the funding a unit position paid, a coin whose listing ended keeping its settlement price. A study forms any benchmark from the report alone.

### A13. Identity, the ledger and protected dates

A run's identity hashes the program, the market's every file, the venue, the fee schedule, the coin rules, the sources' encodings, scales and `known` rules, the reader's dropped and deduplicated counts, the protected windows, and the engine's build.

**Protected dates.** Version 1 refused holdout dates in the kernel (I8, I11); a build instruction not to read them is not that. The protected windows and their releases are a tracked file compiled into the executable, not an argument. `start` rejects a horizon that meets an unreleased window, and admission rejects any event whose `time` is in one (C2), so no report or trace can hold a value from it. `mm2 inspect` is the only other entry: it prints counts, sizes, hashes and stale spans of a file, never a value. A release is a commit to that file, and changes the identity.

**The evaluation ledger** is SQLite whose schema rejects UPDATE, DELETE and REPLACE. **Nothing is published before it is recorded:**
1. an `attempt` row (identity, `session`, `agent`, `parents`) is committed before the engine starts;
2. the `result` row is committed and synced when it ends;
3. only then are the report and trace written and anything printed.

A session's count of attempts is the budget's meter, so a run killed anywhere is counted, and no result exists outside the ledger.

**What a harness needs** (`docs/research/2026-11-13-argon-multiagent-strategy-research.md`, part 3): the meter above; `parents`, the rows an author had seen, so that team topologies are views of one ledger; and an alias map, a bijection from source and coin names to opaque names, under which a program runs as its translation (law N1).

### A14. What the venue's terms and our certificates do not establish

| # | Not established | Assumed | Consequence if wrong | Checked by |
|---|---|---|---|---|
| V1 | The price grid | 5 significant figures and at most `6 − szDecimals` decimals (a lead) | A wished price off the real grid | Every price of the vault's fills must lie on it |
| V2 | Order types and their rules | `gtc`, `ioc`, post-only refused when marketable, `reduce_only` cut to the position | A refused order that would have rested, or the reverse | The fills' `crossed` flag against each slot's `tif` |
| V3 | Lot sizes, leverage and tiers, and their history | The hourly copy of `meta`; a change inside an hour shows as an off-grid price or size, which admission rejects | A wrong maintenance for a levered account | Every fill's size is a whole number of lots |
| V4 | The fee tiers and their history | The base tier, for every fill | Fees wrong from an unseen change | Every fill of the vault, to the digit, before and after the freeze |
| V6 | Historical mark prices | Checks at the book's adverse side and at prints | A liquidation earlier than the venue's | Nothing; the vault was never liquidated |
| V7 | Who bears a shortfall | The venue (A11) | A levered account's loss understated | A certificate, before any levered run; it does not make a test exact (architecture 6.2) |
| V8 | The oracle price in history | The mid at the settlement | A funding payment off by the basis | `userFunding`, which gives the payment |
| V9 | An account's delays | `λ` and `δ` registered; results at two values | Fills and reactions too early | Nothing |
| V10 | Impact and replenishment | A7's last paragraph | A taker's later fills too cheap; a large order's maker fills too many | The cap; the print's own size |
| V11 | Whether a resting order reserves margin | It does, at its limit price | A ladder needs more equity than the venue asks | Nothing; pessimistic |
| V12 | The queue | None: `optimistic` at a touch, `pessimistic` only on sells through the price | Fill timing between the two | Architecture 6.3, order by order |
| V13 | That the record is complete | Staleness is marked and nothing fills in it | A fill or a liquidation inside it is missed | The report's stale shares |
| V14 | What is left after a liquidation | The remainder stays | Equity after a liquidation overstated | Nothing |
| V16 | Funding within a step | A long pays at most `ρ̄` of its value at the step's start, `ρ̄` registered from the venue's cap of 4% an hour (`rules.json`) | The confirmer's bet is not surely covered | The confirmer voids a run in which a step's funding exceeds it |

### A15. Against version 1's nine choices (facts §2)

| Version 1 | Version 2 |
|---|---|
| The four-hour grid and hourly clock | `tick` and `decide_every` |
| No book, sub-bar price or own state | The inputs of A5 |
| One target weight a coin | Slots; a target weight is two `ioc` slots (A5) |
| The fill at the next open with a cost table | Orders against quotes and prints; a market of bars derives them (A16), with no cost table |
| One taker fee | The schedule and the role |
| Funding at the bar's open | At the oracle price, else the mid |
| Margin once a step | After every event that moves cash or a mark |
| Delisting | Listing events |
| I7's conventions, I8 and I11's dates | A13 |

The nine defects' lessons are laws here and not ported code: no fill after a liquidation's cancel (K2: L4), no future listing in today's state (K1: L1), a bankrupt account stays bankrupt (K5: L6), REPLACE rejected (M4: A13).

### A16. A market of bars

With `mm` gone, version 2 is the only kernel, and synthetic markets, where observations are free, and histories older than any recorded book are markets of bars. They need no second fill rule. A **bar source** gives, for a coin and a span `[t, t + Δ)`, an open, high, low, close and volume. The engine derives events from each bar, and the rest of the machine does not know:

| Derived event | At | What |
|---|---|---|
| a quote | `t` | bid `o × (1 − h)`, ask `o × (1 + h)`, one level a side |
| two prints | `t + Δ/3`, `t + 2Δ/3` | the low as a sell-aggressor print and the high as a buy-aggressor print; the low first when the bar closed at or above its open, else the high first |

All are known at `t + Δ + δ`, when the bar is. A price is the rational its double is, rounded to the grid's nearest step. The bar's values are also observations, for signals.

**The four assumptions,** registered in the market's header and hashed:
- **B1, the spread:** a half-spread `h`, one rate or one a coin. A bar shows none.
- **B2, depth:** every derived level and print covers the policy's cap. A bar shows none, so a bar market says nothing of impact.
- **B3, the path:** open, then the two extremes in the order above, then the next open. A bar does not say which came first.
- **B4, the extremes traded:** the low was sold into and the high bought.

Then the two rules are the two classical readings of a bar: `pessimistic` fills a resting buy when the low is strictly below its price, `optimistic` when it touches. An `ioc` fills at the next open plus the half-spread, and pays the schedule's taker fee. Margin is checked at the extremes, because they are prints. Nothing here is fitted, and no result of a bar market is compared with `mm`'s.

## Part B. The split, and the laws

### B1. What is Lean

Everything that decides a number: the program's parser and checker; both evaluators; slots and reconciliation; the fill rules; the ledger, fees, funding, margin and the floor; the reading of doubles as decimals; the derivation of events from bars; the admission of dates; the trace and the report; study 2's confirmer. One Lake library, `Engine`, in a new package `kernel2/lean`, with no executable and no `IO`. Exact numbers are core Lean's `Rat`.

- **The float evaluator is stage 6's semantics.** The build plan's step 4 takes the parked stage 7 files (`Ref/Source.lean`, `Ref/Resolve.lean`) if they stand alone, and otherwise writes it from `SEMANTICS.md` §1 to §5; B4 judges it either way.
- **The engine is written as its own specification:** plain, total, pure functions, with no second fast copy. A law is then a theorem about the code that runs. Only if the wall of B5 fails does a step get a faster twin, proved equal to it.
- **The exported surface** is four pure functions, `@[export]`ed to C:
  - `check : String → String`, a program's JSON to a verdict;
  - `start : String → String → Except String State`, a program and a market's header (horizon, venue, policy, universe, coin rules, fee schedule, sources with their encodings and scales, bar assumptions, alias map);
  - `feed : State → Chunk → State`, a chunk being flat arrays of events: kinds, coins, `time`s, `known`s, integers, and doubles;
  - `finish : State → String`, which runs the clock to the horizon's end and gives the report and the trace.

### B2. What is OCaml

Everything that touches the world, and nothing that decides: one dune project, `kernel2/ocaml`, giving the executable `mm2`, on Jane Street's stack (`core`, `async`, `ppx_expect`, `base_quickcheck`, v0.17, in the pinned nixpkgs).

- **Reading.** The archive's Parquet through DuckDB 1.5.2's C API, by hand-written C stubs (`docs/research/2026-11-13-argon-ocaml-parquet-duckdb.md`, a lead I accept): its doubles go to Lean untouched. The recorder's hourly zstd streams through `mmrec cat`, and `node_trades` when certified: their decimal strings become integers at the declared scale. Bars, headers and funding rows are JSON (`yojson`).
- **Merging** the coins' streams into the order of A3, deduplicating trades by id, and cutting chunks.
- **Calling Lean.** The executable links the engine's compiled C and Lean's static runtime through one stub file that initializes the runtime once and holds the `State` in a custom block whose finalizer releases it. One run a process, one thread in Lean.
- **Writing.** The SQLite ledger in A13's order (`ocaml_sqlite3` 5.3.1), reports and traces, file hashes for the identity.
- **Orchestration.** A pool of processes sized from measured peak memory and free memory, and the command line.
- **Nix.** `packages.mm2` builds both; `checks.engine-proofs` type-checks every theorem with no `sorryAx`. OCaml 5.4.1, dune 3.21.1. Everything is in the pinned nixpkgs, so `flake.lock` does not move.

**The trust boundary.** Not proved: Lean's compiler and runtime, `Float` as the platform's double, the C stubs, DuckDB, OCaml's readers and merge, the placing of a string's digits, and the printing of JSON. What guards it:
- Lean re-checks the order of what it is fed, every number's range and grid, and every date (C2), so a reader can only be wrong about content that is still well formed.
- Chunk boundaries cannot matter (C1).
- Each reader is compared, event for event, with an independent one on sampled coin-days: the archive's with `ingest/archive.py`, which stays a test's oracle outside the kernel.
- A coin-day's row count and hours are checked against its raw files' manifest (the defect of facts §6).

### B3. The laws

★ marks a law a judged number depends on: proved in Lean on the running code, its statement frozen before its proof. The rest are property tests. Each rule has a **characterization**, an "exactly when", which an engine that does nothing fails. Round 2 showed four statements that the transitions contradicted; each is restated from the transition, not the reverse.

**Causality**
- **L1 ★ No future.** Two markets whose events with `time ≤ t` are equal give equal worlds and traces through `t`.
- **L1a ★ Delivery.** Two markets equal on the events with `known ≤ τ_k`, and on the events with `time ≤ τ_k − δ`, give equal views, evaluations and wishes at tick `k`. (The world acts on what the program has not yet seen; that is intended, and round 2 showed the old L1 forbade it.)
- **L1b ★ No fill on what was seen.** An order wished at `τ` has no fill on an event with `time ≤ τ + λ`.

**Numbers and the language**
- **X1 ★ The crossings.** A placed order's price and target are the A2 roundings of its slot's exact values. Two float evaluators that agree on every `when` and on every argument of `exact(·)` place the same orders.
- **X2 ★ Decimals.** On a double's bits: the reading returns `n` only if `|n| < 10¹⁵` and the binary64 nearest `n · 10⁻ᵈ` is the input; and for every such `n` and every scale from 0 to 12, reading that binary64 returns `n`. Negative zero reads as zero.
- **L2 Units.** The instrumented machine never raises a unit or sort error; erasing them gives the executable values. Proved.
- **L3 Rewrites, L5 Binding, N1 Renaming.** As stage 6 and 7 state them, over declared sources. Proved, abstract numbers.

**Orders and fills**
- **R1 ★ Reconciliation.** A wish equal to the live order's price and target places and cancels nothing; reconciling twice at one tick equals once. Orders are admitted in A6's order, and an order is admitted exactly when A6's three conditions hold.
- **F0 ★ Fills, exactly.** An arriving order's fill is A7's walk of the levels. A resting order's fill at an event is, under `pessimistic`, the lesser of its remainder and its allotted lots, and under `optimistic` its whole remainder exactly when the event qualifies. No other fill exists.
- **E1 ★ Recorded lots, once.** Under `pessimistic`, over a whole run, the maker fills credited to a print sum to at most its size, and every one is to an order priced strictly above a sell-aggressor print. At one quote the lots taken by arriving orders are, level by level, at most the level's.
- **L4 ★ Fills are well formed.** Every fill belongs to one order live at its time. A maker fill is at the order's price; a taker fill at recorded levels' prices, each no worse than the limit. A post-only order never takes. A `reduce_only` fill never raises the position in absolute value and never flips it. No order survives a liquidation.
- **S1 ★ Cycles.** No fill takes a slot's fills in the cycle above the target of the order it fills; a `close` order's fill is at most the position; `filled` resets exactly when the position returns to zero.
- **F1 The rules at one event.** From one state at one print, each resting order's `pessimistic` fill is at most its `optimistic` fill. A property test: no judged number rests on it.

**The ledger**
- **A1 ★ Conservation.** Cash is the starting cash, minus buys, plus sells, minus fees, minus funding, plus `absorbed`, each exactly as A7 to A11 give it, and each fee is its fill's notional times its role's rate in the tier in force. Equity at mids is cash plus positions at mids. `entry` is the cost of the open position over its size. No operation of the ledger rounds.
- **U1 ★ Funding.** At every funding event of a held coin cash changes by exactly `−q · O · ρ`, `q` the position before any fill at that time, and at no other time for funding. A held coin's hour with no event inside its lateness rejects the run.
- **M1 ★ Margin.** The account is liquidated at an event exactly when, after that event's fills and payments, its equity at adverse prices is below its maintenance.
- **L6 ★ The floor.** Equity is never negative, and after a bankruptcy every return is zero. At a leverage of 1 with no short, cash after every fill is at least zero, and `absorbed` is zero unless a funding payment exceeded cash.
- **Q1 ★ What a step can lose.** For an account with no short and no order that can open one, a step's `pnl` plus the funding paid in it is at least minus the positions at mids and the buys, with fees, that make up `at_risk` at its start. (Prices are not negative; nothing else is used.)
- **P1 ★ The report.** Every report row is the stated function of the world at its time: equity is cash plus positions at their coins' mids, each column its coin's, `pnl` the difference of two equities, and a day's row the mids and funding of its coin.

**The confirmer** (architecture 6.1)
- **K1 ★ The wealth.** `V`'s lower bound is at most `V` as the report's rows define it, and `V` is never negative when no step is void.
- **K2 ★ The certificate.** If the confirmer reports "timed" at a day, then `V` there is at least 20 times the wealth of every constant mix of the universe and cash, not only of the mix it was shown.
- **K3 Ville's bound,** under each rung's null, is mathematics on paper (architecture 6.1), not a theorem about code. The simulation that exercises it has a registered acceptance region.

**The boundary**
- **C1 ★ Chunking.** `feed` over a list of events equals `feed` over any cutting of it into chunks.
- **C2 ★ Admission.** A fed event that is out of order, crossed, a repeated trade id, off its coin's rules, out of its number's range, or dated in an unreleased protected window puts the state in a rejecting state that `finish` reports with no report row and no trace, whatever follows.
- **D1 Determinism.** A run is a function of its program, market and header. In Lean this is purity; across the boundary it is tested by running twice, on two hosts.
- **W1 Recorded before published.** Tested by killing the process at each of A13's three boundaries.

**What is deliberately not a law.** That either venue's return bounds the truth. That the rules reproduce real fills: that is measured on the vault's own orders (architecture 6.3).

### B4. Against stage 6

Version 2 shares one thing with the pilot: the float expression language, whose reference is Lean (`reference/lean`), not `mm`. Each expression of the frozen C6.4 corpus is evaluated by version 2 at a tick of one hour, its inputs given as observations (the two event counts as `flow` sources) and its nodes as `probes`, and the streams equal the reference evaluator's bit for bit. The reference's streams are stored under a hash, so the check outlives `mm`. If step 4 takes the reference's own files, this is a test that they were taken whole.

The ledger's oracle is not a kernel: it is 5,806 fills of a real account, each with the venue's own fee, realized profit and position (architecture 6.3).

### B5. Scale

A book market is slow and a bar market fast. The wall for books: one run of 16 coins over 212 days at every recorded snapshot (229 million quotes) finishes within one hour on one core and within 2 GB, measured at the build plan's first slice that feeds quotes. A bar market has three derived events a bar, so a search at the pilot's scale runs on bars; a search over book markets is not a goal.

## Part C. Round 2, answered

A is Argon's finding, G is GPT's. "Cause" names what was re-derived; nothing below is a tolerance, a flag or an exemption.

| Finding | Verdict | Cause, and what changed |
|---|---|---|
| A1, G1 to G3. `M = W / B` drifts without skill; no exact test can credit timing | **Conceded,** both halves | A ratio to a benchmark is exact for every rule only when the benchmark is the growth-optimal holding, and an equal-weight basket at the account's exposure is not. The claim is re-derived as a ladder of two nested nulls on one wealth (architecture 6.1). Argon's `M*` is refuted: a benchmark holding the account's own coins over its own intervals removes the rule's whole effect and leaves the fee. Argon's paired statistic is refuted: its mean is positive for a dip buyer with no skill (`arithmetic.py.txt`) |
| A2, G4. "Nothing bets more than the account" | **Conceded** | I merged the account, which gives the loss bound, with the test wealth, which is a bet on it. The bound is the step's `at_risk`, known at its start (Q1), and the wealth bets against it. The account's equity leaves the test altogether |
| A2, G5. Leverage and the floor | **Conceded, and settled:** leverage cannot be exact | The floor pays the account `absorbed`. A test of a floored account confirms falsely with probability up to `(1 + E[absorbed]) / 20`, and no certificate bounds an expectation (architecture 6.2) |
| A3, G6. One seller spent across events | **Conceded** | A quote is a state, a print is a flow; only flow fills a resting order, and only a seller's (A7). The quote column, "a quote can only complete an order" and the test of a print against a later quote are gone |
| G7. F0, E1 and F1 cannot all hold | **Conceded** | E1 is about `pessimistic`; `optimistic` is a named fiction; F1 is a property test |
| A4, G's notes. The decimal bound | **Conceded** | Decimals went through doubles. Strings now enter as integers; doubles are read only where the archive stored doubles; the range is stated as a range; X2 is a theorem (A2) |
| A5, G8. Layer 3's wall | **Conceded** | A sum of profits pools errors that cancel, and no wall on the past shows a rule will not flatter. The wall is deleted. Fidelity is order by order, against the vault's own order at the same price (architecture 6.3) |
| A6, G on deletions. Bars, target weights | **Conceded** | A16; a target weight under target semantics (A5); `market` deleted, so every order has a largest cost |
| A7.1, G9, G10. L1, S1, delayed `filled`, `close` | **Conceded** | Two states (A1). An order is a target whose remainder the world computes (A6). L1, L1a, S1 restated |
| A7.2. Notional sizing replaces every tick | **Refuted as a defect:** a wish that moves is replaced, and a program that wants a still order writes a still target. Study 2's replica has constant sizes (architecture 6.1) | A6 says a notional is converted before it is compared |
| A7.3. Sparse observations; the corpus's schema | **Conceded** | `state` and `flow` sources; `probes`; B4 is against the Lean reference |
| A7.4. Four small gaps | **Conceded** | `traded` at `start`; the first tick; no fee at a settlement; `oracle` undefined without one (A5, A8) |
| A7.5, G15. No law on the report or the confirmer | **Conceded** | P1, Q1, K1, K2; fees inside A1; the simulation's acceptance region (`arithmetic.py.txt`). The grammar and the event encodings are owed before step 4, by the architect |
| G11. A later quote decides an earlier gap | **Conceded** | Staleness, which is causal (A3) |
| G12. Funding at a shared time | **Conceded** | The position held into the time (A9, U1) |
| G13. Funding below zero; the fee at admission; `absorbed` | **Conceded** | The check after every cash event (A10); an order's requirement holds its fee (A6); `absorbed` in A1 |
| G14. X1 and float booleans | **Conceded** | X1 restated; a comparison is a crossing |
| G16. Protected dates | **Conceded** | A13, C2 |
| G17. A result before its row | **Conceded** | A13, W1 |
| G18. Polling loses history | **Conceded** | The build plan's table: hourly copies; the vault's fills as the fee schedule's witness; overlap as the proof that a pull lost nothing; V3 and V4 |
