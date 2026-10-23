# Semantics of the strategy language and simulator

The semantic contract for stage 6 (PROGRESS.md, Stage 6). It resolves DSL.md and INVARIANTS.md
against the immutable engine `mm` (kernel/mm/src at the commit that freezes this file), and both
reference kernels implement exactly this. Where it and DSL.md read differently, this file states
what the engine computes. Section references in brackets name the engine source.

Times are integer milliseconds. HOUR = 3,600,000; BAR = 4 · HOUR; δ is the store policy's
`delta_ms` (120,000). Numbers are IEEE-754 binary64 in the executable instance and an abstract type
N in the proofs.

## 1. Values

A value is `Num(x)`, `Bool(b)` or `Undef`. The engine stores booleans as 1.0 and 0.0. A comparison
yields 1.0 or 0.0, and boolean operators read any nonzero as true [machine.rs `eval`]. A boolean
node therefore always holds 1.0, 0.0 or Undef.

Every sum Σ over a sequence of numbers in this file is the left fold from −0.0, in the stated
order. That is Rust's float `Sum` on this toolchain (rustc 1.95): the sum of nothing is −0.0, and
the sum of [−0.0] is −0.0.

Every node's value at a tick passes through `finite`: a non-finite number (±∞, NaN) becomes Undef
[machine.rs `tick`, `finite`]. The engine skips the filter for `hours_since` and `xs_rank`, whose
outputs are always finite in binary64 (§4); the model filters them too, which is the identity there.
Intermediate results inside an operator or a window's state can be non-finite; only stored node values
are filtered.

## 2. Programs and typing

A program is the JSON document of DSL.md, parsed strictly, with checks in this order
[dsl.rs `parse`, `expr`; serde_json]:
1. A text above 1 MiB, or with brackets nested more than 136 deep (counted outside strings), is
   E_SIZE.
2. Otherwise, a container opened at nesting depth 128 or more is E_PARSE, from serde_json's
   recursion limit. So are syntax errors, duplicate keys, unknown or missing fields, and non-finite
   numbers.
3. More than 4,096 parsed expressions, or expression depth above 64, is E_SIZE.

Expressions are hash-consed into a DAG whose nodes precede their users. `let` entries are checked in
declaration order, and a `ref` names only an earlier let. A constant's value is normalized by one
binary64 addition of +0, so a literal −0 becomes +0. A parameter's value keeps its parsed bits, so a
parameter of −0 stays −0.

A unit is an integer exponent vector over (usd, coin, h, d, y, ev) [units.rs]. The types are
`Num(unit)` and `Bool`. The signature table [dsl.rs `type_op`] is:

| Op | Arguments | Result |
|---|---|---|
| add, sub, min, max | Num(u), Num(u) | Num(u) |
| mul / div | Num(u), Num(v) | Num(u + v) / Num(u − v); exponent overflow is E_UNIT |
| neg, abs | Num(u) | Num(u) |
| sign | Num(u) | Num(1) |
| log, exp | Num(1) | Num(1) |
| sqrt | Num(u), every exponent even | Num(u / 2) |
| clip | Num(u) ×3 | Num(u) |
| gt, ge, lt, le | Num(u), Num(u) | Bool |
| and, or | Bool, Bool | Bool |
| not | Bool | Bool |
| if | Bool, T, T (both Bool, or both Num(u)) | T |
| convert `to` | Num(u), with `to` differing from u only in time units | Num(to), scaled by the exact factor |
| lag, mean, sum, std, min_over, max_over, ema (`hours` ∈ 1..4380) | Num(u) | Num(u) |
| xs_mean, xs_demean | Num(u) | Num(u) |
| xs_rank | Num(1) | Num(1) |
| hours_since | Bool | Num(h) |

Inputs and their units: funding (1/h), premium (1), open, high, low, close (usd/coin), volume
(coin), forum_posts and gov_proposals (ev). The weight must be Num(1); a `prediction.condition`
must be Bool. Rejection codes are those of INVARIANTS.md, and the first error in parse order is
reported.

## 3. Observations and delivery

- **Records.** An observation is a funding row (coin, eventTime, knownAt, rate, premium), a bar
  (coin, openTime, eventTime = openTime + BAR, knownAt, open, high, low, close, volume, trades), or
  an event count (input, coin, eventTime, knownAt, count). The store resolves revisions before a
  run [market.rs `resolve`]: per (dataset, coin, eventTime), the revision with the largest fetchedAt ≤
  the version. Its knownAt is computed from its observed fields by the policy's rule [market.rs
  `known`]: a funding row at max(reportedTime floored to the hour + δ, reportedTime +
  `settlement_latency_ms`), a bar or an event count at eventTime + δ. A stored knownAt
  is never read. A run receives exactly one row per key; earlier
  revisions are never delivered. The adapter supplies the rows; an admissible market has unique keys,
  bars with eventTime = openTime + BAR, and coin and slot indices within range.
- **Delivery order.** Each stream is sorted by (knownAt, coin, eventTime): funding, bars, then each
  event input in EVENT_INPUTS order (sorted by knownAt, coin, slot, index). Before the tick at time
  τ, every row with knownAt ≤ τ is delivered, funding first, then bars, then events [sim.rs
  `deliver_until`].
- **Held state.** Delivery of a row with knownAt > τ aborts with R_CAUSALITY [machine.rs
  `deliver_*`]. Delivery overwrites the coin's held funding row, held bar, or event slot. `max_known`
  is the largest knownAt delivered so far, over all coins.
- **Input values at a tick.** funding and premium come from the held funding row. open, high, low,
  close and volume come from the held bar. An event input is the held row's count only if its
  eventTime equals the tick's hour H; otherwise it is Undef. Every input is Undef before its first
  delivery.

## 4. Ticks

The first tick is at H = w_start (delivery up to w_start + δ). Then, in each 4h step, there is one
tick per H in (b, b + BAR], each after delivery up to H + δ (§7). A tick at hour H with listing
mask L (coin c listed iff interval_start(c) ≤ H < interval_end(c)) evaluates the nodes in index
order. Per node i and coin c:

- **hours_since(cond).** If c is listed and cond[c] is defined and nonzero at this tick, last[i][c]
  becomes H. The value is the integer (H − last) div HOUR converted to a number, if c is listed and
  last is set; otherwise Undef. Then finite() is applied. The state persists across unlisted ticks.
- **xs ops.** Let X be the listed coins whose argument is defined, with their values, in coin
  order. If X is empty, every coin is Undef. Otherwise mean = (Σ values, summed in coin order)/|X|:
  - xs_mean gives finite(mean) to every coin in X;
  - xs_demean gives finite(v − mean);
  - xs_rank gives finite of 1/2 if |X| = 1, else of (#{x < v} + (#{x = v} − 1)/2)/(|X| − 1).

  Coins outside X are Undef. These ops hold no window state.
- **Every other node.** If c is unlisted, the value is Undef, and the node's window (if any) is not
  pushed. Otherwise the pointwise value v is computed (§5). If the node is a window, v is pushed and
  the window's output replaces v. Then finite() is applied.

## 5. Pointwise operators

With a(k) the value of argument k at this tick for this coin, any Undef argument read gives Undef,
except as noted [machine.rs `eval`]:

- add, sub, mul: the IEEE operation. div: Undef if a(1) = 0, else a(0)/a(1).
- min(a, b) = b if b < a, else a. max(a, b) = b if a < b, else a. A tie, including −0 against +0,
  returns the first argument. This is what the engine's release build computes for `f64::min` and
  `f64::max`, measured with rustc -O on this toolchain: min(−0, +0) = −0, min(+0, −0) = +0, and the
  same for max.
- neg: −x. abs: |x| (the sign bit cleared). sign: 1 if x > 0, −1 if x < 0, else 0 (so sign(−0) = 0).
- log: Undef unless x > 0, else ln x. exp: e^x. sqrt: Undef unless x ≥ 0, else √x (√−0 = −0).
- clip(x, lo, hi) = min(max(x, lo), hi), with min and max as above.
- gt, ge, lt, le: 1 or 0.
- and, or: both arguments are read (both must be defined); nonzero is true; the result is 1 or 0.
- not: 1 if x = 0, else 0.
- if(c, a, b): Undef if c is Undef; else a(1) if c ≠ 0, else a(2). The unselected branch's value
  is not read, but it is evaluated at this tick like every node.
- convert: x · f. The factor f is fixed when the program is checked, as the engine computes it
  [units.rs `conversion`]: hours(u) = ((1 · 1^e_h) · 24^e_d) · 8760^e_y, each power by compiler-rt's
  `__powidf2` (Rust's `powi`): multiply by the base on each odd bit of |e|, halving |e| and squaring
  the base, and take the reciprocal for negative e. Then f = hours(from) / hours(to). A non-finite f is
  accepted by the checker, and x · f is then filtered by `finite` like any node value. Conversion
  nodes are interned by (factor bits, target unit, argument), as the engine does.
  *Revision 2026-10-21, recorded here 2026-10-23:* before the fix (commit `5f2b538`, made in the engine and
  the model together, adversarial case t22), they were interned by (factor bits, argument) only, so of two
  conversions sharing both, the first one's target unit applied. Every C6.4 run is on the fixed behavior.
- Window nodes: the pointwise value is a(0), then pushed (below).

## 6. Windows

A window node with n = `hours` keeps per-coin state, pushed once per listed tick
[machine.rs `Win::push`]:

- **lag.** A buffer of the last n + 1 pushed values (defined or not). The output is the oldest one
  once the buffer holds n + 1, else Undef.
- **mean, sum, std.**
  - **State.** A buffer of the last n pushed values; running `sum` and `sumsq` over its defined
    values, both starting at +0; a count of Undef values, starting at 0; and `since_exact`, starting
    at 0.
  - **On a push.** Append the value and add it (or count it Undef). If the buffer exceeds n, remove
    the front and subtract it (or uncount it). Then increment since_exact. If since_exact ≥ n, set
    since_exact = 0 and recompute sum and sumsq exactly, as left-to-right sums over the buffer's
    defined values.
  - **Output.** Undef if the buffer holds fewer than n values or any Undef. Otherwise:
    - sum: sum;
    - mean: m = sum/n;
    - std: √max(sumsq/n − m², 0), the population form. When sumsq/n − m² is NaN (sumsq and m²
      both overflow), max returns 0, so the output is 0 (§5's max, measured).
- **min_over, max_over.** The output is Undef until n values have been pushed, or if any of the
  last n pushed values was Undef. Otherwise it is the minimum (maximum) of the last n. On equal
  values, the engine keeps the later one (it pops `b >= v` for min and `b <= v` for max), which
  matters only for signed zeros.
- **ema.**
  - **State.** α = 2/(n + 1), the running value s (starting at +0), and the count `seen` of defined
    values pushed (starting at 0).
  - **On a push.** An Undef push leaves the state and outputs Undef. A defined x sets s = x if
    seen = 0, else s = α·x + (1 − α)·s, then increments seen.
  - **Output.** s once seen ≥ n, else Undef.

## 7. The simulation loop

Let V be the venue's coins in rules.json order; intervals [start, end) per coin as loaded
[market.rs]. The book: cash = 10,000; positions q[c] (absent means 0); and an average-entry ledger
(entry[c], realized, fees, funding, absorbed) [sim.rs `Book`]. Marks start as NaN. With b = w_start, and while
b + 2·BAR ≤ end, each step does, in order:

1. **Funding.** For h = b + HOUR, b + 2·HOUR, …, b + BAR, and for each coin c holding a position (in
   coin order): if a funding rate r exists for (c, h) and a bar opens at h − (h mod BAR), then
   paid = q[c] · open(that bar) · r. cash −= paid and funding −= paid.
2. **Marks.** For each held coin, latest(c) is the coin's last bar with openTime ≤ b, and the mark
   is its close.
3. **Margin.** The adverse price is low(latest) for q > 0 and high(latest) for q < 0 (the mark if no
   bar). Equity at adverse = cash + Σ q · adverse. Maintenance = Σ |q| · adverse / (2 · min tier
   leverage). If any position is held and equity at adverse < maintenance, every held position is
   liquidated: a fill of −q at reference = adverse, at time b + BAR, from latest(c).
4. **Delisting.** For each position with b + BAR ≥ end(c): a fill of −q at reference = mark, at
   time b + BAR, from latest(c).
5. **Bankruptcy.** If e = cash + Σ q · mark is not > 0 (NaN included), every position still held is
   liquidated as in step 3. Then absorbed −= cash and cash = 0 (losses are capped at equity), and the
   order due at this step is unfilled (step 7).
6. **Accounting.**
   - **Equity.** e1 = cash + Σ q · mark. e2 = 10,000 + realized + Σ q · (mark − entry) − fees +
     funding + absorbed. Unless |e1 − e2| ≤ 1e-5, abort with R_ACCOUNTING. Record Equity(b + BAR, e1, e2).
   - **Returns.** If previous > 0, the return is e1/previous − 1 if e1 > 0 and −1 otherwise, and the gross return is
     (e1 − previous + costs − previous costs)/previous, with costs = fees + slippage; otherwise both
     are 0. Unless the return is ≥ −1, abort with R_BOUND. Append both.
7. **Fills.** Orders decided at the previous decision (at b + δ) are due now, at b + BAR, their
   scheduled fill time. They are executed only if b + 3·BAR ≤ end; otherwise the run's horizon ends
   first, and they are dropped unresolved (only their Decision record exists). For each due order,
   in decision order, the selected bar is the coin's bar opening at b + BAR. That is INVARIANTS.md's
   I3: the first bar opening at or after submission, with openTime ≤ the scheduled fill time. If it
   exists with trades ≥ 1 and e1 > 0, fill at its open. Otherwise record Unfilled; the order never rolls to a
   later bar.
8. **Ticks.** For H = b + HOUR, …, b + BAR: deliver up to H + δ, then tick (§4).
9. **Decision** at t_d = B + δ, with B = b + BAR.
   - **Eligibility.** A coin is eligible if start(c) ≤ B and B + 2·BAR ≤ end(c).
   - **Holds.** An eligible coin holds as `stale` unless its held funding row and held bar both have
     eventTime B. It holds as `undefined` if its weight is Undef. The others give (c, w).
   - **Scaling.** largest = max |w|, and relative = Σ |w|/largest. If relative · largest > 2, each
     w becomes w/largest · (2/relative). Unless the scaled gross is ≤ 2 · (1 + 1e-12), abort with
     R_PORTFOLIO (a NaN gross aborts).
   - **Order quantity.** For each (c, w) in coin order, with price = the held bar's close and
     held = q[c]: qty = −held if w = 0 (either sign), else trunc(w · e1/price − held) to szDecimals.
     If |qty| · price > 10,000, qty = signum(qty) · truncate_d(10,000/price), where
     truncate_d(x) = trunc(x · 10^d)/10^d with d the coin's szDecimals. A weight of exactly 0 (a
     close) skips the first truncation and the minimum notional, but not this cap.
   - **Orders.** An order is placed if qty ≠ 0 and (|qty| · price ≥ min notional or w = 0). It is
     recorded as Decision(t_d, c, w, qty) and due at B + BAR, with inputs_known = max_known and
     decided = t_d.

   Then b += BAR.

**A fill** of qty at reference r [sim.rs `fill_price`, `Book::fill`]:
- **Price and fee.** The cell is buy if qty > 0 else sell, and ≤ $1k if |qty| · r ≤ 1000, else the
  $10k cell. price = r · (1 + sign(qty) · bps/10⁴), and fee = |qty| · price · taker_fee.
- **Book update.** If the old position is nonzero and qty has the opposite sign, realized +=
  min(|qty|, |old|) · sign(old) · (price − entry). The new position is old + qty. If it is 0, the
  entry is removed. If it is a new position or flips sign, entry = price. If it adds to the position
  in the same direction, entry = (old · entry + qty · price)/new.
- **Cash.** cash −= qty · price + fee, fees += fee, and slippage += qty · (price − r).
- **Recording.** Each fill is checked by I2 and I3 [sim.rs `check_fill`] and recorded.

## 8. Binding preflight

Sources(s) is the set of event inputs named by any node of the program's DAG, which includes let
bodies and the prediction condition [dsl.rs `event_datasets`]. The core funding and bar datasets are
always present: the loader fails without them, an adapter invariant. For each event source the adapter
supplies a binding flag. In the pilot it is set when the source's dataset is in the store, and that
flag is stage 6's certificate interface, trusted as given. Before any delivery or tick, if some source
in Sources(s) is not bound, the run's result is R_INPUT_UNAVAILABLE, with no trace [sim.rs `run`].
Otherwise the run proceeds, and missing observations follow the operator semantics.

## 9. Decide

decide(s, h, t), for a decision tick t = B + δ, is the sequence of decision records of step 9 at t:
each eligible coin's hold (with its reason) or (w, scaled w, qty), as the run from w_start produces
them. raw(s, h, t) is the vector of each listed coin's weight value at the tick H = B, before any
scaling.
