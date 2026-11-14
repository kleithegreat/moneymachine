# Kernel version 2: semantics, the Lean and OCaml split, and the laws

Written 2026-11-14 UTC by Claude Fable 5.2 from `facts-kernel-v2.md` (`d8200f0`). Revised 2026-11-14 15:29 UTC (10:29 EST) after round 2 by Argon and GPT (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r2.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r2.md`), and 2026-11-14 17:25 UTC (12:25 EST) after round 3 by the same two (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r3.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r3.md`), answered in part C; the answers to rounds 1 and 2 are in `ledger.md` and in git (`2a4cd2a`, `d014b87`). A design on branch `rearchitecture`. Part A is the contract the Lean engine is written from. Part B says which language holds what, and the laws. The build plan is `briefs/3-kernel-v2.md`; study 2, which needs this kernel, is `architecture.md` section 6.

Binding: maximal Lean, OCaml for the rest, no Rust or Python; strategies are data; version 2 is a clean-room design owing nothing to version 1's code. Version 1 (`mm`) is deleted, with a git tag for the archive, after study 1's last judged run (the human, 2026-11-14), so version 2 is the project's only kernel from then on and nothing here is compared with `mm`.

## Part A. Semantics

### A1. One machine, two states

Version 2 is one event-driven machine: a program places priced orders, and an exact ledger keeps its account against recorded quotes and prints. It has two states, and round 2's contradictions came from writing laws about one "machine state" that mixed them:

- **The world:** the ledger, the orders, the wishes on their way to it (A6) and the book's latest quote. It acts on an event at the event's `time`.
- **The view:** what the program may read: the market as the world had it `δ` ago, and the account as its effects say. It holds an event from the event's `known` time, and an effect from the effect's time plus `δ`.

An **effect** is any change the world makes to the account or its orders: an order placed or refused, a fill with its fee, a cancellation with its cause, a funding payment, a liquidation, a bankruptcy with what was absorbed, a cycle's end. That is a definition, not a list to keep complete: nothing in the account or the orders changes without an effect, so the view's copy of them is the world's, `δ` late.

A **venue** is the record of what varies between runs: the fill rule (`optimistic` or `pessimistic`, A7), the order delay `λ`, the observation delay `δ`, the staleness length `G`, the order cap and the minimum order. There is no second engine and no switch inside a rule. A market of bars runs on the same machine, through a source that derives quotes and prints from bars under stated assumptions (A16).

### A2. Numbers

There are two sorts of number, and the ledger holds only one.

- **Exact** numbers are rationals. Prices, sizes, money and rates are exact. The ledger's state is cash and a position in each coin; equity is cash plus each position times its mark. **Nothing in the ledger rounds.**
- **Float** numbers are binary64, evaluated in stage 6's operation order (`reference/SEMANTICS.md` §1, §5). Signals, windows and transcendental functions are floats.
- **Three crossings, all total.** `exact(f)` is the rational that the float `f` is. `float(e)` is the binary64 nearest the rational `e`, ties to even. A comparison of floats gives a bool. A float that is not finite makes whatever reads it undefined.
- **Roundings,** each of an exact value: a slot's price to the coin's price grid, away from the market (a buy down, a sell up); a slot's size to lots, toward zero; and, at 128 significant bits, the report's benchmark sums and the confirmer's wealth and bar, each toward the side that can only fail to confirm (A12, architecture 6.1).
- **A recorded number enters as an integer.** A source declares each exact field's scale `d`, from 0 to 12 (8 for a price, `szDecimals` for a size, 12 for a rate), and the engine receives the integer `n` of `n · 10⁻ᵈ`. A source declares one of two encodings:
  - `string`: the venue's decimal string, which the reader turns into `n` with no arithmetic but the placing of digits. A string with more decimals than the scale, or with `|n| ≥ 10¹⁵`, rejects the market (`E_DECIMAL`). The recorder's streams and the API are this.
  - `double`: a stored binary64, as the archive's Parquet holds. The engine reads it as the one `n` with `|n| < 10¹⁵` whose nearest binary64 it is, bit for bit, or rejects. Decimals of that range are at least four units in the last place apart, so at most one exists (law X2).
- **What a double cannot say.** The range is `|n| < 10¹⁵` at the declared scale, not "15 significant digits": a price of `10⁷` at scale 8 is rejected, and no recorded price is within a factor of fifty of it. A double that was never a decimal can still be the nearest of one; nothing that reads doubles can see that. What catches it is the coin's grid: such a value has more than five significant figures and admission rejects it (C2). Float observations are never read as decimals.

### A3. Time and events

Times are integer milliseconds. A market has a horizon `[w_start, w_end)` and a finite list of events. Each has a coin, a `time` at which it happened and a `known` time, at or after it.

| Kind | Holds | Class |
|---|---|---|
| listing | the coin's rules from `time` on: `szDecimals`, the price grid as its rule (the most significant figures and the most decimals, V1), margin tiers; or the end of its listing, with a settlement price | 1 |
| funding | the hour it settles, the settled rate, and the oracle price when the source has it | 2 |
| quote | a snapshot: up to 20 bid and 20 ask levels, each a price and a size, best first | 3 |
| trade | a print: its venue id, price, size, aggressor side | 3 |
| observation | one value of a declared source (a name, a unit, a float; a `state` or a `flow`) | 3 |
| tick | the program's clock (A4); not in the market | 4 |

The machine consumes events in the order (time, class, coin, kind as listed, position in its source). Admission rejects a market whose events are out of that order, whose quote is crossed or one-sided (the reader drops and counts those; the count is in the identity), whose trade repeats an id at one timestamp (a source that writes a match twice, once a side, is deduplicated by the reader, counted; a print is its coin, time and id, and the reader checks ids unique over each coin-day file on disk, B2), whose numbers fail A2 or the coin's grid, or whose time lies in a protected window (A13).

- **`known`.** A quote's and a trade's is `time + δ`. A listing's, a funding row's and an observation's is given by its source's certificate. An effect's is its time plus `δ`.
- **A timestamp is complete** only when an event with a later time has been fed, or at `finish`: until then the machine neither fires that time's tick nor closes its events, so a chunk may end anywhere (C1).
- **Observations** are how any other data enters: bars as signals, a forum count. A `state` source's value at a tick is its latest known observation. A `flow` source's is the sum, in order of delivery, of those that became known since the last tick, and undefined when none did. A quote is a state and a print is a flow; a declared source says which it is.
- **Staleness.** A coin is stale from its latest quote's `time + G` until its next quote, before its first quote, and after its last. It is causal: nothing later decides it. While a coin is stale no order of it fills and its mark is its last mid. **The view has its own staleness, the world's `δ` earlier:** at a tick `τ` a coin's price inputs are undefined exactly when the world held it stale at `τ − δ`, which known quotes alone decide. Round 3 showed that inputs read from the world's flag told the program a quote it had not yet seen had arrived. The trace marks both; the report gives each coin's stale share and whether a position or an order was open across it.

### A4. The clock

The program declares `tick`, a whole number of seconds from 1 up, and `decide_every`, a whole number of ticks. Tick `k` is at `τ = k · tick`, for every `τ` in the horizon.
- At every tick the view takes every event and effect that has become known, and every expression is evaluated once. Windows count ticks.
- At every `decide_every`-th tick, counted from the epoch, the slots are read and reconciled (A6). A **step** runs from one deciding tick, after its wishes are sent, to the next.
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
| `size` | exact, a size or a notional; or `close` | the **target**: what this slot is to have filled in its cycle. `close` has no target: its order's remainder is the position |
| `tif` | `gtc`, `alo`, `ioc` | `alo` is post-only |
| `reduce_only` | bool | a fill is cut to the position |

There is no market order. An order that must fill now is an `ioc` at a price the program states, such as `ask × 1.01`; so every buy has a largest cost, known when it is placed. A notional becomes a size by exact division by the slot's price.

**A cycle** on a coin runs from one return to flat to the next: it begins flat, and ends at the event that brings the position back to zero. So the flat wait before an entry and the position it opens are one cycle. A slot's `filled` counts within the cycle. This is the whole of a ladder's memory.

**Inputs.** All are per coin, read from the view:

| Input | Sort, unit | Value |
|---|---|---|
| `bid`, `ask`, `mid` | exact, price | the latest known quote's best prices and their mean |
| `bid_size`, `ask_size` | exact, size | the best levels' sizes |
| `high`, `low` | exact, price | the highest and lowest mid and print price that became known since the last tick (at the first tick, since the horizon's start); the latest mid when nothing did |
| `traded` | exact, size | the size printed in the same interval; on a market with no trade source, `start` rejects a program that reads it (`E_UNKNOWN_INPUT`) |
| `oracle`, `funding` | exact, price and rate | the latest known funding row's; `oracle` is undefined when the row has none |
| `pos`, `entry` | exact | the signed position, and its cost over its size (undefined when flat); a fill that reduces the position leaves `entry` as it was |
| `first_price`, `first_size`, `age` | exact | the mean price and the total size of the fills of the order that opened the cycle, and the ticks since its first fill became known; undefined when flat |
| `filled(slot)`, `resting(slot)`, `resting_price(slot)` | exact | the slot's fills this cycle, and its live order's remainder and price |
| `equity`, `free_margin` | exact, money | equity at mids; and equity at adverse prices less the initial margin of the positions and of what the live orders open, with their fees (the two sides of A6's first condition) |
| a declared source's name | float, its unit | A3 |

Own-state inputs are computed from the effects the view holds, so they lag the world by `δ`.

**Expressions.** Float expressions are stage 6's; where one of its operators names the hour, version 2 counts ticks. Exact expressions are decimal literals, exact inputs, `+ − × ÷`, `min`, `max`, negation and `exact(f)`; a division by zero is undefined. Comparisons of either sort give a bool. A float expression reads an exact one through `float(e)`.

**Typing.** Stage 6's unit checker (L2) gains the sort, the units size and money, and the rule that price times size is money. A literal in an exact expression is the decimal as written.

**What the ladder looks like.** An entry slot whose `when` is the trigger; five `alo` buy slots at `first_price × 0.9775`, and so on, with targets `first_size × 1`, `× 1.93`, …; one `reduce_only` sell slot of size `close` at `entry × 1.0056`. Every constant is a decimal. No kernel rule knows what a ladder is. A target weight is two `ioc` slots, the buy's target `filled(buy) + max(0, w × equity ÷ ask − pos)` and the sell's its mirror: both terms come from one view, so a fill in flight is subtracted once by the world (A6). A view `δ` old holds the weight `δ` late, as any controller of a delayed reading does.

### A6. Orders

**An order is a price and a target, and belongs to one cycle.** At every deciding tick `τ` each slot sends its **wish**: the pair (price, target) rounded as A2 says, or nothing when the slot is inactive, with the cycle the view stood in. The wish reaches the world at `τ + λ`, a slot's wishes in the order sent. When one arrives:
- if its cycle has ended, it does nothing;
- if it equals the slot's live order in price and target, nothing changes;
- otherwise the live order is cancelled, and the wished order is placed, if its remainder is not zero and it is admitted.

Until a wish arrives the old order can still fill. The world, not the view, computes what an order may still fill: its **remainder** is its target minus the slot's fills in the cycle, never below zero, and for `close` the position. So a fill between a wish and its arrival is never bought twice, a target below what has filled places nothing, a take-profit follows the position without being replaced, and a `close` wished while flat places nothing.

**A cycle's end cancels the coin's every order,** at the event that ends it. A target is a quantity of a cycle, so an order has no meaning outside its own. Round 3 found what happens otherwise: an order that outlives its cycle regains its whole target when `filled` starts again, once for every cycle that ends in a step (GPT's finding 3, Argon's 2). A new cycle's orders therefore come only from wishes sent after the view saw the old one end, `δ + λ` later at the soonest. A listing event that changes a coin's rules cancels its orders the same way.

**Cancel** is a slot going inactive, **expiry** a `when` that reads `age`, **replace** a wish whose rounded price or target has moved. There is one wish a slot a deciding tick, so nothing is scheduled twice and an `ioc` that found nothing is sent again.

Orders placed at one time are admitted one by one: first every `reduce_only` order, then the others, each group by (coin, slot) in the program's order. What an order **opens** is the amount by which filling its remainder would raise the position's absolute size. An order is admitted only if
- with it, the initial margin of the positions and of what every live order opens, at its limit price, plus each such order's taker fee, fits in equity at adverse prices (A10);
- its remainder's notional is at least the venue's minimum, 10 USD, unless it opens nothing and closes the position exactly;
- its notional is at most the policy's cap.

Otherwise it is refused, with a reason, and the next wish tries again. The minimum is the venue's, and a remainder under it is refused there too; a program closes dust with `close`. At a leverage of 1 the first condition says that live buys and their fees fit in cash when each is admitted. Funding can take that cash later; what answers it is the check of A10, and no law promises cash stays positive.

### A7. Fills

**A sell mirrors a buy throughout:** exchange bid and ask, buyer and seller, and reverse each inequality. Every rule and law below is written for a buy.

Let a buy at `p` be placed at `ℓ`. Its **arrival** is the coin's first quote with `time > ℓ`, with best bid `b` and ask `a`:
- **`a ≤ p`** (marketable): `alo` is refused; `gtc` and `ioc` take the ask levels priced at most `p`, best first; the rest of a `gtc` rests at `p`, the rest of an `ioc` is cancelled.
- **`a > p`:** it rests at `p`; an `ioc` is cancelled.

A fill at arrival is a taker fill at the levels' prices. Orders arriving at one quote take from it in admission order, each from what the ones before left. An order meets the first book recorded after it is placed, never one the program had seen.

**A resting order fills on flow.** A quote shows who is standing, and the same seller stands in the next one; a print is a sale that happened once. So a quote never fills a resting order under the judged rule. The two rules differ in one thing, the burden of proof:

| | Credits a resting buy at `p` | Fills |
|---|---|---|
| `pessimistic`: only what the record proves | after its arrival, a **sell-aggressor** print at `x < p`, size `s` | `s` lots, shared as below |
| `optimistic`: whatever the record does not exclude | after `ℓ`, any print at `x ≤ p`; after its arrival, a quote with `a ≤ p` | the whole remainder |

- Before its arrival the record neither proves the order rests nor excludes it, so `optimistic` fills there and `pessimistic` does not.
- Under `pessimistic` the order fills, as a maker at `p`, the lesser of its remainder and the lots allotted to it. A print's lots are allotted to the account's resting orders it qualifies for, best price first, then by slot, **each lot once**. A `reduce_only` fill is cut to the position, and what is cut is cancelled.
- Under `optimistic` the fill is a maker's at `p`. Round 2's text had `b ≤ p` for the quote, which filled an order for joining the best bid (Argon's finding 4); what cannot be excluded is a sale at the order's price or below, and a bid standing under it is not one.

**Why these.** A seller who hit a bid below `p` would have hit this order first: his lots are offered through the price. A buyer lifting an ask priced under `p` proves only that someone stood there. `optimistic` is a fiction of unlimited size, named so, and the law about recorded lots (E1) is about `pessimistic` alone. A `pessimistic` venue needs a trade source: `start` rejects one on a market without it.

**What the rules do not bound.** Fills feed back: a fill starts a take-profit, ends a cycle, frees margin. Neither run's return bounds the other's or the truth's (Argon's two constructions, round 1). There is no law of whole runs. For one real order at its recorded price there is a statement that needs no assumption, and it is tested (architecture 6.4).

**What is assumed (V10).** Our orders move nobody: a taker fill does not thin the next snapshot, and every print would have happened as recorded. So two orders arriving at two snapshots can each take the same standing seller, and a seller taken at a quote can still sell in a later print (Argon's finding 4). No rule about one event removes that: it is a hypothesis about how the book refills, the policy's cap keeps an order inside the first levels, and whether a claim may rest on it is the human's to choose (architecture 6.8). The report counts what leans on it: the taker fills made within `G` of an earlier taker fill on the same coin and side.

### A8. Fees

A fill's fee is its notional times the rate of its role, maker or taker, in the fee schedule in force at the fill's time, exactly. The schedule is a market input: a list of dated tiers. The fill's trace row records the role, the tier and the rate. Today it has one tier, the venue's base (maker 0.015%, taker 0.045%), from 2026-04-03 (facts §7). The simulated account does not move between tiers (V4). A listing's settlement charges no fee.

### A9. Funding

A funding event names the hour it settles. At one, of a coin at `time` with rate `ρ`, cash falls by `q · O · ρ` exactly, `q` being the position held into that time, before any fill at it (funding's class is before a quote's), and `O` the event's oracle price, or where the source has none the latest mid. Then the margin check of A10 runs. A coin held into an hour inside the horizon whose event has not come within the registered lateness of that hour aborts the run (`R_SETTLEMENT_MISSING`); `finish` checks the last hours.

### A10. Margin and liquidation

**Marks.** The account is marked at mids for reporting and at adverse prices for every check: the bid for a long and the ask for a short, and at a print its price when it is worse, for that event's check only.

**Cross margin, one balance.** Maintenance is the sum over coins of notional times `1 / (2 · maxLeverage)` of the tier holding that notional. Initial margin is notional over the header's leverage. **After every event that changes cash, a mark or a rule** (a quote or a print of a held coin after its fills, a funding payment, a listing's change or end): if equity at adverse prices is below maintenance, the account is **liquidated**. Every order is cancelled, and every position is closed against its coin's latest quote, level by level, paying the taker fee, a remainder beyond the levels closing at the last level's price.

Fills come before the check because a resting bid fills as the price passes it. Isolated margin is not in version 2.

### A11. The floor

After a liquidation, if equity is not positive the account is **bankrupt**: cash is raised by the shortfall, which is recorded as `absorbed`; equity is zero and every later return is zero.

**The floor is a gift, and the report keeps it apart.** `absorbed` is money the venue paid. The report's profit is taken before it (A12), so a test on the report never counts the gift, whatever the account's leverage (architecture 6.2).

### A12. One event, in order

1. **Listing:** the coin's rules change; a coin whose listing ends has its orders cancelled and its position closed at the settlement price, then the check.
2. **Funding:** A9.
3. **Quote or print:** orders whose life starts or ends by now do so; arrival fills; resting fills; fees; cycles and `filled` updated; then marks, the check, the floor. An observation changes nothing here.
4. **Tick:** deliver, evaluate, and at a deciding tick reconcile.

**A fill** is one of three kinds: an order's (A7), a liquidation's close (A10), a listing's settlement. The laws about orders speak of the first.

**The report** is a function of the world, written as the run goes.
- **A row for each step:** equity at mids at its end, exactly; `pnl`, its change over the step **less what was absorbed in it**; the funding paid in it; the long and short notional at mids; `at_risk` and `fundable` at its start; the count of taker fills that lean on V10 (A7).
- **`at_risk`** is defined for an account with no short and no sell that is not `reduce_only`, and is otherwise undefined: the positions at mids, plus for each buy slot the most it can still buy in the step. That is the largest target among its live order and the wishes on their way from the current cycle, less the slot's fills, never below zero, at the largest of their prices, with the taker fee. Nothing else can buy in the step: a wish sent later arrives in a later step or is counted then, and a cycle that ends takes its orders and wishes with it (A6).
- **`fundable`** is the value, at the step's first mids, of the most units the account can hold (positions plus the same buys) of the coins with a settlement due inside the step. It is zero in a step with none.
- **A row for each universe coin at each UTC day's last step:** three sums over the coin's quotes since the span began, of its mid's return from one quote to the next, of the squares and of the cubes. A funding event enters as a return of minus what a unit position paid over the mid, and a settlement as the coin's last return. They are rounded at 128 bits, the first and third up and the second down. A **span** begins at the horizon's start and again when a universe coin's listing ends. A study forms its benchmark from these alone (architecture 6.1).

### A13. Identity, the ledger and protected dates

A run's identity hashes the program, the market's every file, the venue, the fee schedule, the coin rules, the sources' encodings, scales and `known` rules, the reader's dropped and deduplicated counts, the protected windows, and the engine's build.

**Protected dates.** Version 1 refused holdout dates in the kernel (I8, I11); a build instruction not to read them is not that. The protected windows and their releases are a tracked file compiled into the executable, not an argument. `start` rejects a horizon that meets an unreleased window, and admission rejects any event whose `time` is in one (C2), so no report or trace can hold a value from it. There are two other entries. `mm2 inspect` prints counts, sizes, hashes and stale spans of a file, never a value. The replay of given fills through the ledger (study 2's layer 1) passes every fill through the same admission and its result through the same ledger rows. A release is a commit to that file, and changes the identity.

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
| V3 | Lot sizes, the grid, leverage and tiers, and their history | The hourly copy of `meta`, and that no rule changed and changed back between two copies | An order admitted or refused wrongly inside that hour; a wrong maintenance for a levered account | Every recorded price and size on the copied grid; nothing sees a change no trade crossed (GPT's finding 12) |
| V4 | The fee tiers and their history | The base tier, for every fill; no change and return between two copies | Fees wrong from an unseen change | Every fill of the vault, to the digit; nothing while the vault does not trade |
| V6 | Historical mark prices | Checks at the book's adverse side and at prints | A liquidation earlier than the venue's | Nothing; the vault was never liquidated |
| V7 | Who bears a shortfall | The venue (A11) | A levered account's loss understated | A certificate, before any levered run; it does not make a test exact (architecture 6.2) |
| V8 | The oracle price in history | The mid at the settlement | A funding payment off by the basis | `userFunding`, which gives the payment |
| V9 | An account's delays | `λ` and `δ` registered; results at two values | Fills and reactions too early | Nothing |
| V10 | Impact and replenishment | A7's last paragraph | A taker's later fills too cheap; one seller taken at two snapshots; a large order's maker fills too many | The cap; the print's own size; the report's count of taker fills that lean on it |
| V11 | Whether a resting order reserves margin | It does, at its limit price | A ladder needs more equity than the venue asks | Nothing; pessimistic |
| V12 | The queue, and when the vault's orders stood | None: `optimistic` at a touch, `pessimistic` only on sells through the price | Fill timing between the two | Architecture 6.4, each real fill at its recorded price |
| V13 | That the record is complete | Staleness is marked and nothing fills in it | A fill or a liquidation inside it is missed | The report's stale shares |
| V14 | What is left after a liquidation | The remainder stays | Equity after a liquidation overstated | Nothing |
| V16 | Funding within a step | At one settlement a unit long pays at most `ρ̄` of the coin's mid at the step's start: the venue's cap of 4% an hour (`rules.json`) at an oracle price up to twice that mid, so `ρ̄ = 0.08`, registered | The confirmer's bet is not surely covered, and its size is `(1 + E[shortfall]) / 20`, not 5% | Nothing certifies it: a cap on a rate is not a cap on a payment (GPT's finding 4). The replay reports the largest payment against the room; an uncovered step ends the test (architecture 6.1) |
| V17 | That a cycle's end cancels at once | A6 | A level the vault filled after its own take-profit, while its cancels travelled, is not in the replica | Layer 2 counts the vault's fills after their cycle's exit |

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

With `mm` gone, version 2 is the only kernel, and synthetic markets, where observations are free, and histories older than any recorded book are markets of bars. A **bar source** gives, for a coin and a span `[t, t + Δ)`, an open, high, low, close and volume. **A bar is known when it closes,** so the engine derives three events at its end, and the rest of the machine does not know they were derived:

| Derived event | At (ms) | What |
|---|---|---|
| two prints | `t + Δ − 3`, `t + Δ − 2` | the low as a sell-aggressor print and the high as a buy-aggressor print; the low first when the bar closed at or above its open, else the high first |
| a quote | `t + Δ − 1` | bid `c × (1 − h)`, ask `c × (1 + h)`, one level a side |

Each is known at its `time + δ`, like any print or quote: no event has a rule of its own. A price is the rational its double is, rounded to the grid's nearest step. The bar's values are also observations, for signals, the open known from `t`.

**What a bar market assumes,** registered in the market's header and hashed:
- **B1, the spread:** a half-spread `h`, one rate or one a coin. A bar shows none.
- **B2, depth:** every derived level and print holds 16 times the policy's cap over its price, in lots rounded up, so each of 16 slots' capped orders is covered. A bar shows none, so a bar market says nothing of impact.
- **B3, the path:** the two extremes in the order above, then the close; and nothing trades between a close and the next bar's events.
- **B4, the extremes traded:** the low was sold into and the high bought.
- **B5, staleness:** `start` rejects a bar market whose venue has `G < Δ`. A coin is stale when a bar is missing.

**What the machine then does, with no rule of its own for bars.** An order wished during a bar arrives at that bar's closing quote: an `ioc` or a marketable `gtc` fills there at `c × (1 + h)` if its limit allows, and pays the schedule's taker fee. A buy resting since an earlier close fills under `pessimistic` when a bar's low is strictly below its price. Under `optimistic` it fills when the low touches it, in the bar it was placed in too. Margin is checked at the extremes, because they are prints. A program learns of a fill at an extreme `δ` after the bar's end, when it learns the extreme.

Round 2's text claimed more: that these were the classical readings of a bar, with a fill at the next open. Round 3 showed the claim false five ways (GPT's finding 11, Argon's 6). The cause was giving bar events their own times and their own `known`, so they met A3 and A7 as exceptions. They now have neither, and the claim is withdrawn: an order placed on one bar's information trades at the next bar's close, which is the conservative convention and not the classical one. Nothing here is fitted, and no result of a bar market is compared with `mm`'s.

## Part B. The split, and the laws

### B1. What is Lean

Everything that decides a number: the program's parser and checker; both evaluators; slots and reconciliation; the fill rules; the ledger, fees, funding, margin and the floor; the reading of doubles as decimals; the derivation of events from bars; the admission of dates; the trace and the report; the replay of given fills; study 2's confirmer. One Lake library, `Engine`, in a new package `kernel2/lean`, with no executable and no `IO`. Exact numbers are core Lean's `Rat`.

- **The float evaluator is stage 6's semantics.** The build plan's step 4 takes the parked stage 7 files (`Ref/Source.lean`, `Ref/Resolve.lean`) if they stand alone, and otherwise writes it from `SEMANTICS.md` §1 to §5; B4 judges it either way.
- **The engine is written as its own specification:** plain, total, pure functions, with no second fast copy. A law is then a theorem about the code that runs. Only if the wall of B5 fails does a step get a faster twin, proved equal to it.
- **The exported surface** is pure functions, `@[export]`ed to C:
  - `check : String → String`, a program's JSON to a verdict;
  - `start : String → String → Except String State`, a program and a market's header (horizon, venue, policy, universe, coin rules, fee schedule, sources with their encodings and scales, bar assumptions, alias map);
  - `feed : State → Chunk → State × Rows`, a chunk being flat arrays of events (kinds, coins, `time`s, `known`s, integers, doubles), and the rows being the trace and report rows of the timestamps it completed;
  - `finish : State → Rows × String`, which runs the clock to the horizon's end and gives the last rows and the summary;
  - `confirm`, study 2's confirmer, from report rows and proposed multipliers to a result (architecture 6.1).

  The state holds no history: the ledger, the orders, the wishes on their way, the windows, the running sums and the ids of the current timestamp. Round 3 found two things that grew without bound in it, every trade id and the whole trace (GPT's finding 14).

### B2. What is OCaml

Everything that touches the world, and nothing that decides: one dune project, `kernel2/ocaml`, giving the executable `mm2`, on Jane Street's stack (`core`, `async`, `ppx_expect`, `base_quickcheck`, v0.17, in the pinned nixpkgs).

- **Reading.** The archive's Parquet through DuckDB 1.5.2's C API, by hand-written C stubs (`docs/research/2026-11-13-argon-ocaml-parquet-duckdb.md`, a lead I accept): its doubles go to Lean untouched. The recorder's hourly zstd streams through `mmrec cat`, and `node_trades` when certified: their decimal strings become integers at the declared scale. Bars, headers and funding rows are JSON (`yojson`).
- **Merging** the coins' streams into the order of A3, and cutting chunks. Trade ids are checked unique over each coin-day file by DuckDB on disk, exactly, and a match written once a side is deduplicated there, counted.
- **Calling Lean.** The executable links the engine's compiled C and Lean's static runtime through one stub file that initializes the runtime once and holds the `State` in a custom block whose finalizer releases it. One run a process, one thread in Lean.
- **Writing.** The SQLite ledger in A13's order (`ocaml_sqlite3` 5.3.1), file hashes for the identity. Rows from `feed` go to a private spool, and become the report and the trace only after the result row (A13).
- **Orchestration.** A pool of processes sized from measured peak memory and free memory, and the command line.
- **Nix.** `packages.mm2` builds both; `checks.engine-proofs` type-checks every theorem and prints each ★ law's axioms, which may be `propext`, `Classical.choice` and `Quot.sound` and no other: no `sorryAx`, no declared axiom, no `native_decide`. OCaml 5.4.1, dune 3.21.1. Everything is in the pinned nixpkgs, so `flake.lock` does not move.

**The trust boundary.** Not proved: Lean's compiler and runtime, `Float` as the platform's double, the C stubs, DuckDB, OCaml's readers and merge, the placing of a string's digits, and the printing of JSON. What guards it:
- Lean re-checks the order of what it is fed, every number's range and grid, and every date (C2), so a reader can only be wrong about content that is still well formed.
- Chunk boundaries cannot matter (C1).
- Each reader is compared, event for event, with an independent one on sampled coin-days: the archive's with `ingest/archive.py`, which stays a test's oracle outside the kernel.
- A coin-day's row count and hours are checked against its raw files' manifest (the defect of facts §6).

### B3. The laws

★ marks a law a judged number depends on: proved in Lean on the running code, its statement frozen before its proof. The rest are property tests. Each rule has a **characterization**, an "exactly when", which an engine that does nothing fails. Round 2 showed four statements that the transitions contradicted; each is restated from the transition, not the reverse.

**Causality**
- **L1 ★ No future.** Two markets whose events with `time ≤ t` are equal give equal worlds, effects and rows through `t`.
- **L1a ★ Delivery.** Two markets equal on the events with `known ≤ τ_k`, and on the events with `time ≤ τ_k − δ`, give equal views, evaluations and wishes at tick `k`. Its two premises: the view's account is the fold of the effects with time at most `τ_k − δ`, and the view's staleness is a function of known quotes (A3).
- **L1b ★ No fill on what was seen.** An order wished at `τ` has no fill on an event with `time ≤ τ + λ`.

**Numbers and the language**
- **X1 ★ The crossings.** A placed order's price and target are the A2 roundings of its slot's exact values. Two float evaluators that agree on every `when` and on every argument of `exact(·)` place the same orders.
- **X2 ★ Decimals.** On a double's bits: the reading returns `n` only if `|n| < 10¹⁵` and the binary64 nearest `n · 10⁻ᵈ` is the input; and for every such `n` and every scale from 0 to 12, reading that binary64 returns `n`. Negative zero reads as zero.
- **L2 Units.** The instrumented machine never raises a unit or sort error; erasing them gives the executable values. Proved.
- **L3 Rewrites, L5 Binding, N1 Renaming.** As stage 6 and 7 state them, over declared sources. Proved, abstract numbers.

**Orders and fills**
- **R1 ★ Wishes.** Each slot sends one wish at each deciding tick and none between. A wish arrives at `τ + λ` and does exactly A6's three cases; two equal wishes arriving in turn do what one does. Orders are admitted in A6's order, and an order is admitted exactly when A6's three conditions hold.
- **S1 ★ Cycles.** A cycle ends exactly when the position returns to zero. After the event that ends one, the coin has no order, and no wish of that cycle ever places one. No order fill takes a slot's fills in its cycle above the target of the order it fills; a `close` order's fill is at most the position.
- **F0 ★ Order fills, exactly.** An arriving order's fill is A7's walk of the levels. A resting order's fill at an event is, under `pessimistic`, the least of its remainder, its allotted lots and, when `reduce_only`, the position; under `optimistic` its whole remainder, cut the same way, exactly when the event qualifies. An order has no other fill. A liquidation's closes are A10's walk exactly, and a settlement closes the position at the settlement price.
- **E1 ★ Recorded lots, once.** Under `pessimistic`, over a whole run, the maker fills credited to a print sum to at most its size; each is to a buy priced strictly above a sell-aggressor print or to a sell priced strictly below a buy-aggressor print. At one quote the lots taken by arriving orders are, level by level, at most the level's.
- **L4 ★ Order fills are well formed.** Every order fill belongs to one order live at its time. A maker fill is at the order's price; an order's taker fill at recorded levels' prices, each no worse than the limit. A post-only order never takes. A `reduce_only` fill never raises the position in absolute value and never flips it. No order survives a liquidation.
- **F1 The rules at one event.** From one state at one print, each resting order's `pessimistic` fill is at most its `optimistic` fill. A property test: no judged number rests on it.

**The ledger**
- **A1 ★ Conservation.** Cash is the starting cash, minus buys, plus sells, minus fees, minus funding, plus `absorbed`, each exactly as A7 to A11 give it, and each fee is its fill's notional times its role's rate in the tier in force. Equity at mids is cash plus positions at mids. `entry` is the cost of the open position over its size. No operation of the ledger rounds.
- **U1 ★ Funding.** At every funding event of a held coin cash changes by exactly `−q · O · ρ`, `q` the position before any fill at that time, and at no other time for funding. A held coin's hour with no event inside its lateness rejects the run.
- **M1 ★ Margin.** The account is liquidated at an event exactly when, after that event's fills and payments, its equity at adverse prices is below its maintenance.
- **L6 ★ The floor.** Equity is never negative; `absorbed` rises only at a bankruptcy, by exactly the shortfall; after one every return is zero.
- **Q1 ★ What a step can lose.** For an account with no short and no sell that is not `reduce_only`: the buys an account makes in a step, with their fees, cost at most the buys counted in `at_risk` at its start; so at every event of the step its positions at mids are at most `at_risk` plus its profit since the start, before absorption and before funding. Hence that profit is at least minus `at_risk`, and the units it holds of each coin are at most those counted in `fundable`. (Prices are not negative, and A6's cycles; nothing else is used. It holds at any leverage.)
- **P1 ★ The report.** Every report row is the stated function of the world at its time: equity is cash plus positions at their coins' mids, each column its coin's, `pnl` the difference of two equities less the step's absorption, and a coin's day row brackets the exact sums of its returns, squares and cubes, each within one part in `2¹²⁰` on the side A12 names.

**The confirmer** (architecture 6.1)
- **K1 ★ The wealth.** The confirmer's `V` is at most the exact `V` of the report's rows and at least it less one part in `2⁹⁰`, over at most `2³²` steps. It reports "earned" at a step exactly when its `V` there is at least 20 and no earlier step was uncovered. It is never negative, and is zero from an uncovered step on.
- **K2 ★ The bar.** For every multiplier it is given, the confirmer's bar is at least the wealth of every constant mix of the universe and cash on the quotes' clock, span by span, and at most the multiplier's exact dual bound plus one part in `2⁹⁰`. It reports "timed" at a day exactly when its `V` is at least 20 times its bar there and no earlier step was uncovered or ended rung 2. So "timed" implies "earned".
- **K3 Ville's bound,** under each rung's null, is mathematics on paper (architecture 6.1), not a theorem about code. The simulation that exercises it has a registered acceptance region.

Round 3 showed that K1 and K2 as written before bounded the confirmer from one side only, so one that never confirms satisfied them (GPT's finding 15). Each is now an "exactly when" with a stated error.

**The boundary**
- **C1 ★ Chunking.** `feed` over a list of events, then `finish`, gives the same state and the same rows in the same order as over any cutting of it into chunks, a cut inside one timestamp included.
- **C2 ★ Admission.** A fed event that is out of order, crossed, a trade id repeated at its timestamp, off its coin's rules, out of its number's range, or dated in an unreleased protected window puts the state in a rejecting state that `finish` reports with no report row and no trace, whatever follows.
- **D1 Determinism.** A run is a function of its program, market and header. In Lean this is purity; across the boundary it is tested by running twice, on two hosts.
- **W1 Recorded before published.** Tested by killing the process at each of A13's three boundaries.

**What is deliberately not a law.** That either venue's return bounds the truth. That the rules reproduce real fills: that is measured on the vault's own orders (architecture 6.4). That cash stays positive at a leverage of 1: funding can take it (GPT's finding 5).

### B4. Against stage 6

Version 2 shares one thing with the pilot: the float expression language, whose reference is Lean (`reference/lean`), not `mm`. Each expression of the frozen C6.4 corpus is evaluated by version 2 at a tick of one hour, its inputs given as observations (the two event counts as `flow` sources) and its nodes as `probes`, and the streams equal the reference evaluator's bit for bit. The reference's streams are stored under a hash, so the check outlives `mm`. If step 4 takes the reference's own files, this is a test that they were taken whole.

The ledger's oracle is not a kernel: it is 5,806 fills of a real account, each with the venue's own fee, realized profit and position (architecture 6.4).

### B5. Scale

A book market is slow and a bar market fast. The wall for books: one run of 16 coins over 212 days at every recorded snapshot (229 million quotes) finishes within one hour on one core and within 2 GB, measured at the build plan's first slice that feeds quotes and again, with trades, at the slice that fills. The rows it writes are streamed and are not in the 2 GB. A bar market has three derived events a bar, so a search at the pilot's scale runs on bars; a search over book markets is not a goal.

## Part C. Round 3, answered

A is Argon's finding, G is GPT's, both of round 3. Findings are grouped by cause, and each cause is removed once. Nothing below is a tolerance, a flag or an exemption. Two of round 2's three confusions did come back, and the first rows say where.

| Cause | Findings | Verdict | What changed |
|---|---|---|---|
| **The benchmark traded on a slower clock, and in a wider domain, than the wealth it judged.** A benchmark is a null only if it is the best any wealth with the test's own opportunities can do. Mine rebalanced daily while `V` re-staked every step and the account's orders filled between; it carried funding factors of either sign, and dead coins as cash. This is "a benchmark taken for a null" a third time | G1, G2; A1.1, A1.2, A1.3, A1.5 | **Conceded** | The benchmark trades at every quote, the record's own clock, so nothing trades finer (architecture 6.1). A step clock would have been the same patch one scale down: an account that sells a quarter after a rise beats the best step mix with no timing (`arithmetic.py.txt`). The mix is chosen anew when a universe coin's listing ends. A funding payment at or above a coin's mid ends rung 2. The certificate is three sums a coin and a multiplier; days as a unit, the proposed mix and the inequality of means are deleted. The pair's 5% rests on rejections being nested, not nulls |
| A rule that holds less in turbulent days passes rung 2 with no forecast of a mean | A1.4 | **Not a defect; a choice.** Round 2 said the rung credits it | It is the human's reading of "timed" (architecture 6.8) |
| **An order outlived the cycle its target was a quantity of, and "pending" was a word, not a state.** `filled` restarts with the cycle, so a live or pending order got its target back. This is "a state taken for a flow" again | G3, G10; A2.1, A2.2 | **Conceded** | An order belongs to one cycle and ends with it. A slot sends one wish a deciding tick; the world compares it on arrival. `at_risk` counts the live order and the wishes on their way, after the tick's wishes are sent (A4, A6, A12; S1, R1, Q1) |
| A target weight strands when a fill is in flight; a remainder under 10 USD strands | A5.3 | **Refuted.** The first is a controller reading `δ` late: it holds the weight `δ` later, and Argon's example reaches 12 at the next tick that sees the sale. The second is the venue's own minimum | A6 says both in a line each |
| **A cap on a rate taken for a cap on a payment, and a void taken for a bound.** A payment is units times an oracle price times a rate; the step's start bounds none of the first two. And voiding a run after an uncovered loss truncates the loss, as a floor does | G4; A2.3 | **Conceded** | V16 is an assumption about the payment, said to be one; the room is in the bet only in steps with a settlement due (`fundable`); an uncovered step ends the test with nothing confirmed after it, in step order; the size without V16 is stated (architecture 6.1) |
| **The account taken for the test, again.** I asked the account to make the test exact: no leverage, cash never negative. The test needs one thing of the account, that what it can lose in a step is known at the step's start | G5, G6; A3 | **Conceded** | `pnl` is before absorption. The categorical "leverage cannot be exact" is withdrawn: `V` is exact at any leverage, and leverage never raises its exposure above full investment. The cash law is withdrawn (A11, A12, L6, Q1; architecture 6.2) |
| **The view read a flag of the world, and effects were a list.** | G9, G10; A5.1, A5.2 | **Conceded** | The view's staleness is the world's `δ` earlier; an effect is defined, not listed; a listing's `known` (A1, A3, L1a) |
| `optimistic` filled on `b ≤ p`; a print before an order's arrival quote fills under neither rule | A4.2, A4.3a | **Conceded** | One principle orders both rules: `pessimistic` credits what the record proves, `optimistic` what it does not exclude (A7) |
| Laws for buys and for order fills, quantified over every fill | G7 | **Conceded** | "A sell mirrors" is defined once; fills are of three kinds; F0, E1, L4 speak of each (A7, A12, B3) |
| Layer 2 assumed when and where the vault's orders stood | G8; A4.3b, A4.3c | **Conceded** | Each real fill is tested alone at its recorded price; what needs the vault's placement times is a count, not a wall (architecture 6.4) |
| One seller taken at two snapshots, or at a quote and then a print | A4.1 | **Conceded as V10, not removed.** No rule about one event removes it; removing it is a model of how books refill | The human's choice; the report counts what leans on it (A7, architecture 6.8) |
| Bars met A3 and A7 as exceptions | G11; A6 | **Conceded** | Three events at a bar's end with no rule of their own; the classical equivalence withdrawn (A16) |
| Completeness claimed from signs that are only necessary | G12, G13 | **Conceded** | V3 and V4 say what no copy can see; the vault's fills are pulled by pages to an unsaturated one (the build plan's table) |
| State that grows with the run | G14 | **Conceded** | Ids are unique at a timestamp in the engine and over a coin-day on disk; rows are streamed (A3, B1, B2) |
| Laws a confirmer that never confirms satisfies | G15 | **Conceded** | K1 and K2 are "exactly when", with an error bound |
| `first_size` from a first slice; `entry` on a partial close; `age`; `free_margin`; the grid | A7.1, A7.3 | **Conceded** | A5's table, A3 |
| Inputs are undefined at the first tick when `δ > 0` | A7.2 | **Refuted as a defect:** nothing is known yet, so nothing may be read | The build plan's test names the first tick at which something is known |
| GPT's eight implementation decisions | G, last section | **Conceded,** each decided | A timestamp completes on a later event (A3); a rule change cancels the coin's orders and runs the check (A6, A10); a print's adverse mark lasts one check (A10); the venue's printed digits (architecture 6.4); funding names its hour (A9); the fill replay is admitted like a run (A13); the axiom audit (B2); bar times are integers (A16) |
