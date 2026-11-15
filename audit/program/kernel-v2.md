# Kernel version 2: semantics, the Lean and OCaml split, and the laws

Written 2026-11-14 UTC by Claude Fable 5.2 from `facts-kernel-v2.md` (`d8200f0`). Revised after rounds 2 to 6 by Argon and GPT; round 5 (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r5.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r5.md`) is answered in part C, round 6 (`audit/reviews/2026-11-15-argon-cli-kernel-v2-r6.md`, `audit/reviews/2026-11-15-gpt-kernel-v2-r6.md`) in part D, and the answers to rounds 1 to 4 are in `ledger.md` and in git (`2a4cd2a`, `d014b87`, `99f8fd5`, `1f6a3f8`). A design on branch `rearchitecture`. Part A is the contract the Lean engine is written from. Part B says which language holds what, and the laws. The build plan is `briefs/3-kernel-v2.md`; study 2, which needs this kernel, is `architecture.md` section 6.

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
- **Roundings,** each of an exact value: a slot's price to the coin's price grid, away from the market (a buy down, a sell up); a slot's size to lots, toward zero; the report's three sums a coin, each term to a multiple of `2⁻¹²⁸`; a trade of the test ledger, to its own lot and toward zero; and the confirmer's bar, up, at 128 significant bits. The sums and the bar round toward the side that can only fail to confirm (A12, architecture 6.1).
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
| trade | a print: its venue id, price, size, aggressor side | 3 |
| quote | a snapshot: up to 20 bid and 20 ask levels, each a price and a size, best first | 3 |
| observation | one value of a declared source (a name, a unit, a float; a `state` or a `flow`) | 3 |
| tick | the program's clock (A4); not in the market | 4 |

The machine consumes events in the order (time, class, coin, kind as listed, position in its source). A print comes before a quote of its own millisecond: a snapshot stamped `t` shows the book after what traded at `t`, and an order that arrives at that quote was not there for those prints. Admission rejects a market whose events are out of that order, whose quote is crossed or one-sided (the reader drops and counts those; the count is in the identity), whose trade repeats an id at one timestamp (a source that writes a match twice, once a side, is deduplicated by the reader, counted; a print is its coin, time and id, and the reader checks ids unique over each coin-day file on disk, B2), whose numbers fail A2 or the coin's grid, whose quote or print holds a price that is not above zero, whose settlement price is below zero, or whose time lies in a protected window (A13). So a listed coin's price is above zero, and a return has a divisor.

- **`known`.** A quote's and a trade's is `time + δ`. A listing's, a funding row's and an observation's is given by its source's certificate. An effect's is its time plus `δ`.
- **A timestamp is complete** only when an event with a later time has been fed, or at `finish`: until then the machine neither fires that time's tick nor closes its events, so a chunk may end anywhere (C1).
- **Observations** are how any other data enters: bars as signals, a forum count. A `state` source's value at a tick is its latest known observation. A `flow` source's is the sum, in order of delivery, of those that became known since the last tick, and undefined when none did. A quote is a state and a print is a flow; a declared source says which it is.
- **A coin's price** is the mid of its latest quote, or the price of a print since, and from the end of its listing its settlement price. It is the one valuation in the machine: a print is the newest fact about what the coin trades at, and a mid that a print has passed is an old one. A **price event** is a quote, a print, a funding event or a settlement: what moves the price or pays on a unit held. Rounds 3 and 4 both broke a report that valued at mids while orders filled on prints (part C).
- **Staleness.** A coin is stale from its latest quote's `time + G` until its next quote, before its first quote, and after its last. It is causal: nothing later decides it. The next quote ends it for what follows that quote in the order above and for nothing before: a print in the millisecond of the first quote after a gap is still inside it (Argon's finding 5, round 5). While a coin is stale no order of it fills. **The view has its own staleness, the world's `δ` earlier:** at a tick `τ` a coin's price inputs are undefined exactly when the world held it stale at `τ − δ`, which known quotes alone decide. Round 3 showed that inputs read from the world's flag told the program a quote it had not yet seen had arrived. The trace marks both, and marks each print with the world's, so that nothing outside the engine decides staleness a second time (architecture 6.4); the report gives each coin's stale share and whether a position or an order was open across it.

### A4. The clock

The program declares `tick`, a whole number of seconds from 1 up, and `decide_every`, a whole number of ticks. Tick `k` is at `τ = k · tick`, for every `τ` in the horizon.
- At every tick the view takes every event and effect that has become known, and every expression is evaluated once. Windows count ticks.
- At every `decide_every`-th tick, counted from the epoch, the slots are read and reconciled (A6).
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
| `size` | exact, a size or a notional; or `close` | the **target**: what this slot is to have filled in its cycle. `close` has no target: its order's remainder is what of the position it would reduce, a sell's the long and a buy's the short |
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
| `equity`, `free_margin` | exact, money | equity at prices (A3); and equity at adverse prices less the initial margin of the positions and of what the live orders open, with their fees (the two sides of A6's first condition) |
| a declared source's name | float, its unit | A3 |

Own-state inputs are computed from the effects the view holds, so they lag the world by `δ`.

**Expressions.** Float expressions are stage 6's; where one of its operators names the hour, version 2 counts ticks. Exact expressions are decimal literals, exact inputs, `+ − × ÷`, `min`, `max`, negation and `exact(f)`; a division by zero is undefined. Comparisons of either sort give a bool. A float expression reads an exact one through `float(e)`.

**Typing.** Stage 6's unit checker (L2) gains the sort, the units size and money, and the rule that price times size is money. A literal in an exact expression is the decimal as written.

**What the ladder looks like.** An entry slot whose `when` is the trigger; five `alo` buy slots at `first_price × 0.9775`, and so on, with targets `first_size × 1`, `× 1.93`, …; one `reduce_only` sell slot of size `close` at `entry × 1.0056`. Every constant is a decimal. No kernel rule knows what a ladder is. A target weight is two `ioc` slots, the buy's target `filled(buy) + max(0, w × equity ÷ ask − pos)` and the sell's its mirror: both terms come from one view, so a fill in flight is subtracted once by the world (A6). A view `δ` old holds the weight `δ` late, as any controller of a delayed reading does.

### A6. Orders

**An order is a price and a target, and belongs to one cycle.** At every deciding tick `τ` each slot sends its **wish**: its exact price and target, or nothing when the slot is inactive, with the cycle the view stood in. The wish reaches the world at `τ + λ`, a slot's wishes in the order sent, and the world rounds it (A2) by the coin's rules in force then: a wish has no grid of its own, so none can carry an old one past a change of rules (GPT's finding 5, round 4). When one arrives:
- if its cycle has ended, it does nothing;
- if it equals the slot's live order in price and target, nothing changes;
- otherwise the live order is cancelled, and the wished order is placed, if its remainder is not zero and it is admitted.

Until a wish arrives the old order can still fill. The world, not the view, computes what an order may still fill: its **remainder** is its target minus the slot's fills in the cycle, never below zero, and for `close` what of the position it would reduce. So a fill between a wish and its arrival is never bought twice, a target below what has filled places nothing, a take-profit follows the position without being replaced, and a `close` wished while flat places nothing.

**A cycle's end cancels the coin's every order,** at the fill that ends it and before any other fill of that event. A target is a quantity of a cycle, so an order has no meaning outside its own: one that outlived its cycle regained its whole target when `filled` started again (round 3). A new cycle's orders therefore come only from wishes sent after the view saw the old one end, `δ + λ` later at the soonest. A liquidation ends every coin's cycle, a flat coin's too, so no wish on its way at one places an order (Argon's finding 4, round 4). A listing event that changes a coin's rules cancels its orders; the next wish places them again on the new grid.

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

**What is assumed (V10).** Our orders move nobody: a taker fill does not thin the next snapshot, and every print would have happened as recorded. So two orders arriving at two snapshots can each take the same standing seller, and a seller taken at a quote can still sell in a later print (Argon's finding 4). No rule about one event removes that: it is a hypothesis about how the book refills, the policy's cap keeps an order inside the first levels, and the human accepts it as an assumption that both of study 2's claims name (architecture 6.8). The report counts the taker fills made within `G` of an earlier one on the same coin and side. That count is a diagnostic and not a certificate: two takes further apart than `G` can meet one seller who never moved, so a count of zero does not show the assumption unused (GPT, round 4), and a claim names V10 whatever the count.

**No fill beats the tape.** Every fill is at a price no better than its coin's price after the fill's event: a buy at or above it, a sale at or below. An arriving buy pays asks, which are above the quote's mid. A resting buy fills at its own price on a print at or below it, or on a quote whose ask is. A liquidation sells no higher than the price and buys back no lower (A10), and a settlement moves the price to itself before it closes (A12). No fee is negative (A8). So a trade is never a gain on the books at the moment it happens, under either rule, and the test of a study rests on that alone (law T1, architecture 6.1).

### A8. Fees

A fill's fee is its notional times the rate of its role, maker or taker, in the fee schedule in force at the fill's time, exactly. The schedule is a market input: a list of dated tiers. The fill's trace row records the role, the tier and the rate. Today it has one tier, the venue's base (maker 0.015%, taker 0.045%), from 2026-04-03 (facts §7). The simulated account does not move between tiers (V4). A listing's settlement charges no fee. **Every rate is from 0 to 1:** `start` rejects a schedule that holds one outside, and so does the replay of given fills. A rebate is a fill better than the tape under another name, and T1 speaks of prices alone (GPT, round 5). A rate above 1 makes a sale cost its seller cash: a sale brings the price times one less the rate, and a dated tier of 2 took the test ledger's cash to −1 at an ordinary sale (GPT's finding 1, round 6).

### A9. Funding

A funding event names the hour it settles. At one, of a coin at `time` with rate `ρ`, cash falls by `q · O · ρ` exactly, `q` being the position held into that time, before any fill at it (funding's class is before a quote's), and `O` the event's oracle price, or where the source has none the coin's price. Then the margin check of A10 runs. A coin held into an hour inside the horizon whose event has not come within the registered lateness of that hour aborts the run (`R_SETTLEMENT_MISSING`); `finish` checks the last hours.

### A10. Margin and liquidation

**Marks.** The account is valued at prices (A3) for reporting and at adverse prices for every check: for a long the lesser of its latest quote's bid and its price, for a short the greater of the ask and the price.

**Cross margin, one balance.** Maintenance is the sum over coins of notional times `1 / (2 · maxLeverage)` of the tier holding that notional. Initial margin is notional over the header's leverage. **After every event that changes cash, a mark or a rule** (a quote or a print of a held coin after its fills, a funding payment, a listing's change or end): if equity at adverse prices is below maintenance, the account is **liquidated**. Every order is cancelled, every coin's cycle ends, and every position is closed against its coin's latest quote, level by level, paying the taker fee, a remainder beyond the levels closing at the last one's. **A long is sold into the bids, each level at the lesser of its price and the coin's price; a short is bought back from the asks, each at the greater.** A print under the bid has spent that bid, so nothing is sold above it, and a print over the ask has spent that ask. Round 4's text gave the long's rule for every position, and a short was bought back under the tape (both reviewers, round 5).

Fills come before the check because a resting bid fills as the price passes it. Isolated margin is not in version 2.

### A11. The floor

After a liquidation, if equity is not positive the account is **bankrupt**: cash is raised by the shortfall, which is recorded as `absorbed`; equity is zero, every later return is zero and no wish places an order.

**The floor is a gift, and no test receives it.** `absorbed` is money the venue paid. It has its own row in the report, and a test copies fills and funding, of which it is neither (A12, architecture 6.2).

### A12. One event, in order

1. **Listing:** the coin's rules change; a coin whose listing ends has its price moved to the settlement price, its orders cancelled and its position closed there, then the check.
2. **Funding:** A9.
3. **Print or quote:** the coin's price moves; orders whose life starts or ends by now do so; then the fills, one at a time, arrivals before resting orders, each with its fee, each changing the position and `filled` before the next, and the one that brings a position to zero ending its cycle there; then the check and the floor. An observation changes nothing here.
4. **Tick:** deliver, evaluate, and at a deciding tick reconcile.

**A fill** is one of three kinds: an order's (A7), a liquidation's close (A10), a listing's settlement. The laws about orders speak of the first.

**The report is the world's own books,** written as the run goes. Equity is cash plus each position at its coin's price. Every fill, fee, funding payment and absorption is in cash at its own event and nowhere else. The report holds nothing back and normalizes nothing: three rounds of findings came from a report that kept a second account of when a fill counted and what was at stake (part C).
- **A row for each cash flow:** every fill of the three kinds, every funding payment, every absorption. Its time, coin and kind; the coin's cycle; the units bought or sold; the cash paid or received, with the fee and beside it the fee alone; the position before it; and the coin's price after its event.
- **A row for each of a span's coins at each UTC day's end and at the span's end:** its price, and its first price in the span; and since the span began, over the coin's price events, their count, the least of their returns and zero, the funding a unit paid, and three sums: of the returns, of their squares and of their cubes. A quote's or a print's return is the new price over the old, less one. A funding event's is minus what a unit paid over the price. A settlement is the coin's last return. A coin has no return before its first quote. Each term of a sum is rounded to a multiple of `2⁻¹²⁸`, a return and a cube up and a square down, and the sums are then exact; the prices and the funding are exact. A **span** begins at the horizon's start and again when a universe coin's listing ends: at that event, after the settlement, the row of each of the ending span's coins is written, and the next span starts from the prices then. **A span's coins** are the universe coins still listed at its start. A coin whose listing ended has its last row at that span's end and is in no later span: its settlement turned every holding of it into cash, and it has no event after. Left in, a coin settled at zero was a first price of zero, which the next span's coin held alone and a guard's weight both divide by (GPT's finding 2, round 6). Rows at days' ends alone lost the last hours of a span that ended at noon, the settlement among them (Argon's finding 4, round 5).
- **A row for the account at each UTC day's end:** equity; what was absorbed and what funding was paid so far; the long and short notional at prices; each coin's stale share; the count of A7.

**The trace** is the run in full, for whoever asks why: every effect; every funding event of a universe coin, with what a unit paid at it, whether or not the account held the coin; at every tick each probe's value and, for each coin, its price and the world's and the view's staleness; and every print, with the world's staleness at it. Study 2 reads three of these and decides none a second time: layer 2's join reads the prints' marks, and rung 2's guard reads the prices at ticks and the funding events (architecture 6.4, 6.1). Round 5's trace held a tick's total of funding and not the events. Whether a rule's cash runs out depends on which payment comes first, and a total does not say (GPT's finding 3, round 6).

**The test ledger** is what a study's confirmer folds from the cash-flow rows (architecture 6.1 derives it). It is a second set of books, with its own cash, starting at 1, and its own units of each coin, starting at none and held in whole **test lots** of `10⁻³⁰` of a unit, defined for an account that is never short:
- **at a buy** of the account's, it buys at the same price and fee rate a **scale** times the lots, cut so that its cash pays for them, then down to whole test lots. A cycle's scale is fixed at its first buy: `φ` of the ledger's cash then, over `d`. The study registers both, `φ` at most 1 and `d` a sum in the account's money. The ledger follows the first `d` of the account's buys in the cycle, counted before fees, the buy that crosses `d` in part, and nothing after;
- **at a sale,** it sells the fraction of its units that the account sold of its position, at the same price and fee rate, down to whole test lots, and all of them when the account sold all;
- **at a funding payment,** it pays or receives on its own units; one its cash cannot pay **ends** it, as does a fill that takes the account short;
- an absorption is not its.

Its **wealth** is its cash plus its units at prices. Nothing else moves it: no step, no stake set between fills, no cash set aside, no mark but the price.

**Nothing in it rounds but the size of a trade,** and that is the ledger's to choose, since any size its cash pays for is a scale. A price has at most 8 decimals and a rate 12 (A2), and a mid is half a sum of two prices, so its cash is always a whole multiple of half of `10⁻⁵⁰`, exactly, and no denominator grows with the run. Its numerators can, as any account's cash can, and exact arithmetic carries them. Round 4 instead rounded every stored balance down to 128 bits and called the result a lower bound. It is another ledger: one that bought a little less before a fall, or paid funding on a little less, ends above the exact one and can outlive it (both reviewers, round 5).

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
| V10 | Impact and replenishment | A7 | A taker's later fills too cheap; one seller taken at two snapshots; a large order's maker fills too many | The cap and the print's own size bound it. The report's count is a diagnostic only |
| V11 | Whether a resting order reserves margin | It does, at its limit price | A ladder needs more equity than the venue asks | Nothing; pessimistic |
| V12 | The queue, and when the vault's orders stood | None: `optimistic` at a touch, `pessimistic` only on sells through the price | Fill timing between the two | Architecture 6.4, each real fill at its recorded price |
| V13 | That the record is complete | Staleness is marked and nothing fills in it | A fill or a liquidation inside it is missed | The report's stale shares |
| V14 | What is left after a liquidation | The remainder stays | Equity after a liquidation overstated | Nothing |
| V16 | That one settlement charges a unit long at most its price | An oracle price at most 25 times the price at the venue's cap of 4% an hour (`rules.json`) | The test's wealth could fall below zero at that event, and its size is `(1 + E[shortfall]) / 20`, not 5% | Every settlement of a universe coin is in its row's least return: one below minus one is seen, and nothing is confirmed from that day on. Seeing none establishes nothing: on a path that confirms, the payment that would have broken it is the one that did not come (GPT, round 5). So the 5% is under V16 (architecture 6.1) |
| V17 | That a cycle's end cancels at once | A6 | A level the vault filled after its own take-profit, while its cancels travelled, is not in the replica | Layer 2 counts the vault's fills after their cycle's exit |
| V18 | That the API shows a fill within a bounded time of its timestamp, and keeps it until pulled | A registered delay; pulls far inside the 10,000-fill retention | A round trip indexed later than the delay is never recorded, and its absence breaks no position chain | A daily re-read of the whole registered delay counts what it adds; nothing shows a fill indexed later still (GPT's finding 11, round 4) |

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

With `mm` gone, version 2 is the only kernel, and synthetic markets, where observations are free, and histories older than any recorded book are markets of bars. A **bar source** gives, for a coin and a span `[t, t + Δ)`, an open, high, low, close and volume. **A bar is known when it closes,** so the engine derives three events, all at the bar's end `t + Δ` and in this order, and the rest of the machine does not know they were derived:

| Derived event | What |
|---|---|
| two prints | the low as a sell-aggressor print and the high as a buy-aggressor print; the low first when the bar closed at or above its open, else the high first |
| a quote | bid `c × (1 − h)` rounded down to the grid, ask `c × (1 + h)` rounded up, one level a side |

They are a print's and a quote's in every way: known at `t + Δ + δ`, ordered as A3 orders any millisecond, prints first. A print's price is the rational its double is, rounded to the grid's nearest step. The bar's five values are observations at the same time. Round 3's three events sat a millisecond apart, and a tick could fall among their `known` times and read a bar in pieces (round 4, Argon's finding 6, GPT's 7).

**What a bar market assumes,** registered in the market's header and hashed:
- **B1, the spread:** a half-spread `h` above zero, one rate or one a coin. A bar shows none.
- **B2, depth:** every derived level and print holds a registered notional at its own price, in lots rounded up. A bar shows no depth, an order for more is filled in part as on any book, and a bar market says nothing of impact. Round 3 promised that every capped order was covered; a cap on notional at a limit price is no cap on units at another (GPT's finding 8).
- **B3, the path:** the two extremes in the order above, then the close, all at the bar's end; nothing trades between a close and the next bar's end.
- **B4, the extremes traded:** the low was sold into and the high bought.
- **B5, staleness:** `start` rejects a bar market whose venue has `G < Δ`. A coin is stale when a bar is missing.

**What the machine then does, with no rule of its own for bars.** An order placed before a bar's end arrives at that bar's closing quote, and one placed at its end or later at the next bar's: an `ioc` or a marketable `gtc` fills at the ask if its limit allows, and pays the schedule's taker fee. A buy resting since an earlier close fills under `pessimistic` when a bar's low is strictly below its price. Under `optimistic` it fills when the low touches it, in the bar it was placed in too. Margin is checked at the extremes, because they are prints. A program learns everything of a bar, its fills included, at the first tick at or after its end plus `δ`.

Round 2's text claimed more: that these were the classical readings of a bar, with a fill at the next open. Round 3 showed the claim false, and it is withdrawn: an order placed on one bar's information trades at the next bar's close, which is the conservative convention and not the classical one. Nothing here is fitted, and no result of a bar market is compared with `mm`'s.

## Part B. The split, and the laws

### B1. What is Lean

Everything that decides a number: the program's parser and checker; both evaluators; slots and reconciliation; the fill rules; the ledger, fees, funding, margin and the floor; the reading of doubles as decimals; the derivation of events from bars; the admission of dates; the trace and the report; the replay of given fills; study 2's confirmer and its guard. One Lake library, `Engine`, in a new package `kernel2/lean`, with no executable and no `IO`. Exact numbers are core Lean's `Rat`.

- **The float evaluator is stage 6's semantics.** The build plan's step 4 takes the parked stage 7 files (`Ref/Source.lean`, `Ref/Resolve.lean`) if they stand alone, and otherwise writes it from `SEMANTICS.md` §1 to §5; B4 judges it either way.
- **The engine is written as its own specification:** plain, total, pure functions, with no second fast copy. A law is then a theorem about the code that runs. Only if the wall of B5 fails does a step get a faster twin, proved equal to it.
- **The exported surface** is pure functions, `@[export]`ed to C:
  - `check : String → String`, a program's JSON to a verdict;
  - `start : String → String → Except String State`, a program and a market's header (horizon, venue, policy, universe, coin rules, fee schedule, sources with their encodings and scales, bar assumptions, alias map);
  - `feed : State → Chunk → State × Rows`, a chunk being flat arrays of events (kinds, coins, `time`s, `known`s, integers, doubles), and the rows being the trace and report rows of the timestamps it completed;
  - `finish : State → Rows × String`, which runs the clock to the horizon's end and gives the last rows and the summary;
  - `confirm`, study 2's confirmer, from the report's rows, a stake rule's constants and proposed multipliers to a result (architecture 6.1);
  - `guard`, from the trace's prices at ticks and its funding events, the report's coin rows, a clock and a proposed mix for each span, to that rule's wealth at each day's end: the test ledger's books, folded over those rows in the machine's order (A3). At one timestamp that is a span's end, then funding, then the tick. A funding event is paid, as the ledger pays it, on the units held into it, one event at a time, and the first the cash cannot pay ends the rule. At the clock's ticks the rule is traded back to the mix, at prices. A mix weighs its span's coins and no other, and a coin with no price yet is not bought. At a span's end the rule sells what it holds at that row's prices and buys the next span's mix at them.

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
- **X1 ★ The crossings.** A placed order's price and target are the A2 roundings of its slot's exact values by the coin's rules in force at its placement. Two float evaluators that agree on every `when` and on every argument of `exact(·)` place the same orders.
- **X2 ★ Decimals.** On a double's bits: the reading returns `n` only if `|n| < 10¹⁵` and the binary64 nearest `n · 10⁻ᵈ` is the input; and for every such `n` and every scale from 0 to 12, reading that binary64 returns `n`. Negative zero reads as zero.
- **L2 Units.** The instrumented machine never raises a unit or sort error; erasing them gives the executable values. Proved.
- **L3 Rewrites, L5 Binding, N1 Renaming.** As stage 6 and 7 state them, over declared sources. Proved, abstract numbers.

**Orders and fills**
- **R1 ★ Wishes.** Each slot sends one wish at each deciding tick and none between. A wish arrives at `τ + λ` and does exactly A6's three cases; two equal wishes arriving in turn do what one does. Orders are admitted in A6's order, and an order is admitted exactly when A6's three conditions hold.
- **S1 ★ Cycles.** A cycle ends exactly at a fill that returns the position to zero, and at a liquidation. From that fill on, the coin has no order, no order of that cycle fills, and no wish of that cycle ever places one. No order fill takes a slot's fills in its cycle above the target of the order it fills; a `close` order's fill is at most the position.
- **F0 ★ Order fills, exactly.** An arriving order's fill is A7's walk of the levels. A resting order's fill at an event is, under `pessimistic`, the least of its remainder, its allotted lots and, when `reduce_only`, the position; under `optimistic` its whole remainder, cut the same way, exactly when the event qualifies. An order has no other fill. A liquidation's closes are A10's walk exactly, and a settlement closes the position at the settlement price.
- **E1 ★ Recorded lots, once.** Under `pessimistic`, over a whole run, the maker fills credited to a print sum to at most its size; each is to a buy priced strictly above a sell-aggressor print or to a sell priced strictly below a buy-aggressor print. At one quote the lots taken by arriving orders are, level by level, at most the level's.
- **L4 ★ Order fills are well formed.** Every order fill belongs to one order live at its time. A maker fill is at the order's price; an order's taker fill at recorded levels' prices, each no worse than the limit. A post-only order never takes. A `reduce_only` fill never raises the position in absolute value and never flips it. No order survives a liquidation.
- **T1 ★ No fill beats the tape.** After the event of any fill, of any of the three kinds, the fill's price is at least the coin's price if it bought and at most it if it sold, a liquidation's buying back of a short included; and its fee is at least nothing and at most its notional.
- **F1 The rules at one event.** From one state at one print, each resting order's `pessimistic` fill is at most its `optimistic` fill. A property test: no judged number rests on it.

**The ledger**
- **A1 ★ Conservation.** Cash is the starting cash, minus buys, plus sells, minus fees, minus funding, plus `absorbed`, each exactly as A7 to A11 give it, and each fee is its fill's notional times its role's rate in the tier in force. Equity is cash plus positions at their coins' prices. `entry` is the cost of the open position over its size. No operation of the ledger rounds.
- **U1 ★ Funding.** At every funding event of a held coin cash changes by exactly `−q · O · ρ`, `q` the position before any fill at that time, and at no other time for funding. A held coin's hour with no event inside its lateness rejects the run.
- **M1 ★ Margin.** The account is liquidated at an event exactly when, after that event's fills and payments, its equity at adverse prices is below its maintenance.
- **L6 ★ The floor.** Equity is never negative; `absorbed` rises only at a bankruptcy, by exactly the shortfall; after one every return is zero.
- **P1 ★ The report.** Every row is the stated function of the world at its time. The cash-flow rows are all of A1's terms and each once: starting cash plus their cash is the world's cash at every event, and the units of a coin's rows sum to its position. A coin's row holds its price, its first price in the span and the funding a unit paid in it, exactly; its sums bracket the exact sums of its returns, squares and cubes over its price events, each within the count of events times `2⁻¹²⁸` on the side A12 names; its least return is exact. Every price event of a universe coin is in exactly one span's last row, and a coin has no row in a span that began at or after its listing's end.

**The confirmer** (architecture 6.1)
- **K1 ★ The test ledger.** For every `φ` in (0, 1], every `d` above zero and every fee rate from 0 to 1:
  - every cycle's scale is at least zero, and before the ledger's end its cash and units are never negative;
  - its units are whole test lots and its cash a whole multiple of half of `10⁻⁵⁰`, and no number in it is rounded but a trade's size, toward zero;
  - it changes only at a cash-flow row, each trade at its row's price and fee rate, so with T1 none raises its wealth;
  - its cash and units after every event are the same whether folded over every event of the run or over the rows alone, and its wealth at a day's end is those at that day's prices. The rows hold one coin's price at an event and every coin's at a day's end, so no wealth between is promised (Argon, round 5);
  - it reports "earned" at a day exactly when its wealth at that day's end is at least 20, the ledger had not ended, and no coin's row so far, of any span, held a return below minus one.
- **K2 ★ The bar.** For every multiplier it is given, with `D` its dual bound (architecture 6.1) and `n` the product of `2⁴⁰` and the least of 1, 2, 4, … at or above `D`: a span's bar is the greater of `(1 − D/n)⁻ⁿ`, rounded up at 128 significant bits, and the most that 1 put in one of the span's coins at its first price in the span became, its funding paid in cash, which is exact; that price is above zero (A3, A12). The bar at a day's end is the product over the spans so far. **On a record with no return below minus one** it is at least the wealth, at that day's end, of every constant mix, in each span, of that span's coins and cash rebalanced at every price event, and of every holding bought at the start from its starting cash and never traded whose cash paid its funding; and it is at most the product of the unrounded spans' bars times `1 + 2⁻¹⁰⁰`. Outside that record the bound is not claimed, and K1 confirms nothing. It reports "outgrew" at a day exactly when it reports "earned" there and its wealth is at least 20 times its bar.
- **K3 Ville's bound,** under each rung's null, is mathematics on paper (architecture 6.1), not a theorem about code. The simulation that exercises it has a registered acceptance region.

Each is an "exactly when" about a number the law defines. The ledger is exact, and the bar's one error is relative and on the side that can only fail to confirm. Round 3 found laws a confirmer that never confirms would satisfy; round 4 an absolute error promised of a number with no bound on its size, and a bar compared with `e^D` that it exceeds by design; round 5 a rounded ledger on the wrong side of a subtraction, and a bound stated outside its domain (part C).

**The boundary**
- **C1 ★ Chunking.** `feed` over a list of events, then `finish`, gives the same state and the same rows in the same order as over any cutting of it into chunks, a cut inside one timestamp included.
- **C2 ★ Admission.** A fed event that is out of order, crossed, a trade id repeated at its timestamp, off its coin's rules, out of its number's range, or dated in an unreleased protected window puts the state in a rejecting state that `finish` reports with no report row and no trace, whatever follows.
- **D1 Determinism.** A run is a function of its program, market and header. In Lean this is purity; across the boundary it is tested by running twice, on two hosts.
- **W1 Recorded before published.** Tested by killing the process at each of A13's three boundaries.

**What is deliberately not a law.** That either venue's return bounds the truth. That the rules reproduce real fills: that is measured on the vault's own orders (architecture 6.4). That cash stays positive at a leverage of 1: funding can take it. What a deciding tick's orders can lose: round 3's law of it served a stake that no longer exists. That a record which passes rung 2's guard holds no rule without skill that passes rung 2 (architecture 6.5).

### B4. Against stage 6

Version 2 shares one thing with the pilot: the float expression language, whose reference is Lean (`reference/lean`), not `mm`. Each expression of the frozen C6.4 corpus is evaluated by version 2 at a tick of one hour, its inputs given as observations (the two event counts as `flow` sources) and its nodes as `probes`, and the streams equal the reference evaluator's bit for bit. The reference's streams are stored under a hash, so the check outlives `mm`. If step 4 takes the reference's own files, this is a test that they were taken whole.

The ledger's oracle is not a kernel: it is 5,806 fills of a real account, each with the venue's own fee, realized profit and position (architecture 6.4).

### B5. Scale

A book market is slow and a bar market fast. The wall for books: one run of 16 coins over 212 days at every recorded snapshot (229 million quotes) finishes within one hour on one core and within 2 GB, measured at the build plan's first slice that feeds quotes and again, with trades, at the slice that fills. The rows it writes are streamed and are not in the 2 GB. A bar market has three derived events a bar, so a search at the pilot's scale runs on bars; a search over book markets is not a goal.

## Part C. Round 5, answered

A is Argon's finding, G is GPT's, both of round 5. Both judge round 4's test ledger a re-derivation at the cause, and neither asks for the wealth to be built again. What they found is below, cause by cause. Every one is conceded, and none needed a second clock, a deferred count or a stake that moves without a fill. Each construction is run in `arithmetic.py.txt`, `round5`.

| Cause | Findings | Verdict | What changed |
|---|---|---|---|
| **Free cash was cash less promises, and funding moved one and not the other.** A budget set aside was a number kept beside the cash it stood for. A payment took the cash and left the promise, so the next cycle's scale was negative: a short, in a ledger defined as never short | G1; A1.2 | **Conceded; the promise is deleted, not clamped** | A cycle's scale is `φ` of the ledger's cash at its first buy, over `d`. Nothing is set aside and nothing returned, so cash is the only thing a scale reads, and it is never negative (A12, K1). Cycles that go deep together are cut to the cash there is; that is power, which the replay measures |
| **A rounded balance is another ledger, not a bound on the first.** Rounding down what was bought leaves more cash and less funding to pay | G2; A1.1 | **Conceded; there is no rounded ledger** | The test trades in whole lots of its own, as any account does. The size of a trade is a scale, which the test may choose; every balance is then exact on one fixed grid (A2, A12, K1) |
| K1 promised the wealth at any event from rows that hold every price only at a day's end | A1.3 | **Conceded** | Cash and units after every event; wealth at a day's end (K1) |
| A10 gave the long's rule for every position; a settlement did not move the price; T1 did not bound a fee | G3; A2 | **Conceded** | Both directions written (A10); a listing's end moves the price first (A3, A12); no rate is negative (A8, T1) |
| **The guard was read as showing a record safe.** A bar above the hourly and daily mixes passes markets where a rebalancer at another clock outgrows it | G4; A3 | **Conceded; the reading is withdrawn** | The guard is rung 2's own test run on rules that have no skill. It can refuse a registration and it is quoted beside the claim; its passing shows nothing (architecture 6.1, 6.5). Each rule is the test ledger's books traded at the prices the trace holds at ticks (A12, B1) |
| The condition offered for rung 2's null spoke of each return's law and not of which coin moves | G5 | **Conceded** | The condition is on the whole event: its coin, its return and its time (architecture 6.1). "Fills better than the tape" is no way to pass, since T1 forbids them |
| A holding's funding was called second order. It is not bounded by any mix | G4's note | **Conceded; bounded exactly** | A holding never traded is a mean of cash and of each coin held alone with its funding paid in cash. The bar is at least the best of those, from two exact numbers a coin (A12, K2) |
| A span that ended inside a day lost its last hours; the least return began again with each span; `n` had no value at `D = 0`; the search for a multiplier stopped short when several `Q < 0` | A4 | **Conceded** | A row at a span's end; the veto reads every row so far; `n` from the least of 1, 2, 4, …; the search's bound (A12, K1, K2, `arithmetic.py.txt`) |
| K2 was stated for every record, and is false where a return is below minus one; the bar's log is a little more than `D / 2⁴¹` above `D` | G, notes | **Conceded** | K2's domain is stated; the bound quoted is `D / 2⁴⁰` |
| "Decided by the past" is not the whole proof that ending keeps the size; a least return seen does not establish V16 | G, attack 6 | **Conceded as wording** | The payment is counted before the ledger ends, and under V16 the wealth is still not negative then (architecture 6.1). The 5% is under V16 (A14) |
| The join decided staleness by a time, and the engine by an order; one print could carry two fills | A5 | **Conceded** | The engine marks each print, and the join reads the mark; a print's size covers the sum of the fills matched to it (A3, architecture 6.4) |
| A matching print does not show that a placement history exists | G, attack 7 | **Conceded as wording** | Architecture 6.4 |
| O3, the bounce of prints between bid and ask | Both examined it | **Holds, narrowly** | Neither found a taker that gains from it in a standing book. Both note it does not make rung 1's null true of real prints, and 6.1 now says so |

## Part D. Round 6, answered

Both reviewers confirm every finding of round 5 fixed at its cause, and both keep the test ledger and the narrowed claims. Argon finds the design converged with two edits to step 10; GPT finds four gaps in what the specification admits or hands its instruments. All six are conceded. None changed the ledger, the bar or a claim, and none needed a second clock, a deferred count or a stake that moves without a fill. F is GPT's finding and A Argon's, both of round 6; the constructions are run in `arithmetic.py.txt`, `round6`.

| Cause | Findings | Verdict | What changed |
|---|---|---|---|
| **A fee rate was bounded on one side.** A sale brings the price times one less the rate, so a rate above 1 takes cash at a sale | F1 | **Conceded** | Every rate is from 0 to 1, at `start` and in the replay of given fills (A8); K1 is stated for those rates and T1 bounds a fee by its notional |
| **A coin whose listing had ended was still a coin of the next span.** Settled at zero, it was a first price of zero under the coin held alone and under a guard's weight | F2 | **Conceded; the coin leaves, and no zero is special-cased** | A span's coins are the universe coins still listed at its start (A12, K2, P1). Admission holds every quote's and print's price above zero (A3), so no span's first price is zero |
| **The guard was handed funding as a total a tick.** Its books end at the first payment the cash cannot meet, which is a fact about order: two payments in one minute, and a payment and a rebalance at one tick | F3; A's finding 1 | **Conceded; one cause for both** | The trace holds every funding event of a universe coin and no total (A12). The guard folds them with the ticks in the machine's order, funding before the tick of its timestamp (B1) |
| The guard's fixtures were markets the engine refuses: prices off the grid within three moves and out of range within two days, and a bar given as a rate | F4 | **Conceded** | A pair of +25% and −20%, whose prices are 100, 125 and 80 for ever, run from admitted events through the engine and both instruments (build plan, step 10) |
| Step 10 listed a decimation and a bootstrap that no test of it calls | A's finding 2 | **Conceded** | The decimation is deleted: layer 2 reads the archive's cadence as a class. The bootstrap decides power and the choice of `φ` and `d`, never a result; it is built with the replay it resamples, under study 2's brief |
| "Its numbers do not grow"; the guard's ratio to the bar called a supermartingale | F, notes | **Conceded as wording** | Denominators do not grow (A12). The ratio to the null's mix is the supermartingale, and the bar is at least that mix (architecture 6.1) |
