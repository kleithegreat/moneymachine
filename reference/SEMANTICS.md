# Semantics of the strategy language and simulator

The semantic contract, first for stage 6 (audit/criteria.md, stage 6), where it resolved DSL.md and INVARIANTS.md
against the engine `mm`. Section references in brackets name the engine source. Where this file and DSL.md (frozen for the pilot's agents) read differently, this file holds.

*Revision 2026-11-04 (`audit/decisions.md`, 2026-11-04 00:03 UTC (2026-11-03 19:03 EST) and 05:05 UTC (00:05 EST)):*
the nine reproduced defects are fixed here, once, for the corrected engine: stage 7 first ports the frozen kernel byte
for byte, then fixes them in that one implementation, and the Lean engine follows. The frozen pilot engine, Lean's
stage 6 model and C6.4 implement this file as of `f591e3b`. Each fix is tagged with the strict xfail that then passes: K1 to K6
`gate/tests/test_kernel_defects.py`, in its order; M1, M2, M4 `gate/tests/test_mechanism_defects.py`.

| Defect | Rule | Test |
|---|---|---|
| K1 future trading sets today's eligibility | §3 listing record, §7 intro, step 9 eligibility | `test_future_trades_cannot_change_current_orders` |
| K2 a pending close reopens after a stop-out | §7 step 7 | `test_zero_close_cannot_reopen_after_liquidation` |
| K3 holds take no gross budget | §7 step 9 scaling | `test_undefined_holds_reserve_portfolio_budget` |
| K4 sizing on pre-fill equity | §7 step 9 equity | `test_next_target_uses_post_fill_equity` |
| K5 the window revives a bankrupt account | §10 window account | `test_reporting_window_cannot_resurrect_bankrupt_account` |
| K6 the window drops its boundary fills | §10 window trace | `test_reporting_trace_includes_boundary_fill_costs` |
| M1 closing costs miss the mechanism check | §10 exposures | `test_mechanism_mean_net_return_includes_closing_fills` |
| M2 undefined labels leave its denominator | §10 exposures | `test_undefined_prediction_cannot_pass_with_under_ten_percent_coverage` |
| M4 `REPLACE` gets past the ledger's triggers | INVARIANTS.md I6 | `test_separate_connection_cannot_replace_kernel_result` |

The loss bound the holdout theorem needs holds by construction on gapless markets, from the account's stop-out at Λ
times equity (§7, Loss bound); on real markets it is an assumption.

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
  an event count (input, coin, eventTime, knownAt, count), or a delisting (coin, knownAt): knownAt is the fetchedAt of
  the first venue-rules revision marking the coin delisted, never inferred from trading. The store resolves revisions before a
  run [market.rs `resolve`]: per (dataset, coin, eventTime), the revision with the largest fetchedAt ≤
  the version. Its knownAt is computed from its observed fields by the policy's rule [market.rs
  `known`]: a funding row at max(reportedTime floored to the hour + δ, reportedTime +
  `settlement_latency_ms`), a bar or an event count at eventTime + δ. A stored knownAt
  is never read. A run receives exactly one row per key; earlier
  revisions are never delivered. The adapter supplies the rows; an admissible market has unique keys,
  bars with eventTime = openTime + BAR, coin and slot indices within range, and a delisting record for every coin its
  rules mark delisted.
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
mask L (coin c listed iff start(c) ≤ H < end(c), §7) evaluates the nodes in index
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

Let V be the venue's coins in rules.json order. The run's interval is [w_start, E), with w_start and w_end the policy's
and E = min(w_end, holdout start) in search mode, w_end in holdout mode. Coin c is listed on [start(c), end(c)), with
start(c) = w_start and end(c) = min(E, the knownAt of its delisting record, §3), so a delisting enters a run only from
its knownAt (K1). Λ = 4 sets the account's own stop-out, at most Λ times equity in gross; it is not the venue's
liquidation. The book: cash = 10,000; positions q[c] (absent means 0); and an average-entry ledger (entry[c],
realized, fees, funding, absorbed) [sim.rs `Book`]. The book's equity is cash + Σ q · mark and its gross Σ |q| · mark.
Marks start as NaN. With b = w_start, and while b + 2·BAR ≤ E, each step does, in order:

1. **Funding.** For h = b + HOUR, b + 2·HOUR, …, b + BAR, and for each coin c holding a position and
   listed at h (in coin order; none is due after delisting): a funding rate r for (c, h) must exist,
   priced at the open of c's latest bar opening at or before h (the bar opening at h when it exists,
   else the latest earlier one), else abort with R_SETTLEMENT_MISSING (a missing payment is never a
   zero one). paid = q[c] · open · r. cash −= paid and funding −= paid.
2. **Marks.** For each coin, latest(c) is the coin's last bar with openTime ≤ b, and the mark is its close.
3. **Stop-out.** The adverse price is low(latest) for q > 0 and high(latest) for q < 0 (the mark if no
   bar). Equity at adverse = cash + Σ q · adverse. Maintenance = Σ |q| · adverse · max(1/(2 · min tier
   leverage), 1/Λ), so the account stops itself out no later than the venue would liquidate it. If any position is
   held and equity at adverse < maintenance, every held position is closed: a fill of −q at reference = adverse, at
   time b + BAR, from latest(c).
4. **Delisting.** For each position with b + BAR ≥ end(c): a fill of −q at reference = mark, at
   time b + BAR, from latest(c).
5. **Bankruptcy.** If e = cash + Σ q · mark is not > 0 (NaN included), every position still held is
   closed as in step 3. Then absorbed −= cash and cash = 0 (losses are capped at equity).
6. **Accounting.**
   - **Equity.** e1 = cash + Σ q · mark. e2 = 10,000 + realized + Σ q · (mark − entry) − fees +
     funding + absorbed. Unless |e1 − e2| / max(|e1|, 10,000) ≤ 1e-9, abort with R_ACCOUNTING (a NaN or
     infinite e1 fails). Record Equity(b + BAR, e1, e2).
   - **Returns.** If previous > 0, the return is e1/previous − 1 if e1 > 0 and −1 otherwise, and the gross return is
     (e1 − previous + costs − previous costs)/previous, with costs = fees + slippage; otherwise both
     are 0. Unless the return is ≥ −1, abort with R_BOUND. Append both.
7. **Fills.** Orders decided at the previous decision (at b + δ) are due now, at b + BAR, their
   scheduled fill time. They are executed only if b + 3·BAR ≤ E; otherwise the run's horizon ends
   first, and they are dropped unresolved (only their Decision record exists). An order whose book no longer exists
   is unfilled: every due order if step 3 or 5 closed the account, and an order whose coin is not listed at
   b + BAR (K2). Otherwise, for each due order, in decision order, the selected bar is the coin's bar opening at
   b + BAR. That is INVARIANTS.md's I3: the first bar opening at or after submission, with openTime ≤ the scheduled
   fill time. It fills at its open if the bar exists with trades ≥ 1 and the fill either reduces |q[c]| without
   changing its sign or leaves the book's gross at most Λ times its equity, both at the step's marks: the margin
   check at order time. A reversal is judged like any fill. Otherwise record Unfilled; the order never rolls to a
   later bar.
8. **Ticks.** For H = b + HOUR, …, b + BAR: deliver up to H + δ, then tick (§4).
9. **Decision** at t_d = B + δ, with B = b + BAR.
   - **Eligibility.** A coin is eligible if it is listed at B: start(c) ≤ B < end(c) (K1).
   - **Holds.** An eligible coin holds as `stale` unless its held funding row and held bar both have
     eventTime B. It holds as `undefined` if its weight is Undef. The others give (c, w).
   - **Equity.** e_d is the book's equity after step 7's fills (K4). If e_d ≤ 0 (I10), scaling and sizing are
     skipped and no order is placed; holds are still recorded.
   - **Scaling.** A hold keeps its position, so it keeps its share of the gross budget: H = Σ |q[c]| ·
     mark[c] / e_d over the holds with a position, and the others share β = max(0, 2 − H) (K3).
     largest = max |w|, and relative = Σ |w|/largest. If relative · largest > β, each w becomes
     w/largest · (β/relative). Unless the scaled gross is ≤ β · (1 + 1e-12), abort with R_PORTFOLIO
     (a NaN gross aborts).
   - **Order quantity.** For each (c, w) in coin order, with price = the held bar's close and
     held = q[c]: qty = −held if w = 0 (either sign), else trunc(w · e_d/price − held) to szDecimals.
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

**Loss bound.** Let r′ be a step's net return before absorption, (e′ − e_prev)/e_prev, with e′ the equity before
step 5's absorption and e_prev the previous step's e1, its equity before its fills. Let κ be the largest cost per unit
of reference notional over the cells, s + f + s·f with s = bps/10⁴ and f the taker fee, and m the largest loss, per
unit of mark notional, of carrying a position from one step's marks through the next step's funding to a closeout at
that bar's adverse extreme, its cost included. Take a gapless market, whose bars open at the previous close, with
Λκ ≤ 1. Then:
- the book leaving steps 3 to 5 has gross G₀ ≤ Λ · e_prev. A stop-out leaves nothing. Otherwise the gross at the
  adverse prices is at most Λ times the equity there, and moving each price to its mark, a move in the position's
  favour, keeps that ratio at most Λ. A delisting fill lowers gross by its notional and equity by at most κ times it.
- step 7's fills are at the marks plus costs, so they never raise equity. A reduction that keeps the sign keeps gross
  within Λ times equity (Λκ ≤ 1), and any other fill is admitted only if it does, so the book leaving them has gross
  G₁ ≤ Λ · e_prev.
- with at most one fill per coin, they trade at most G₀ + G₁ ≤ 2Λ · e_prev, costing at most 2Λκ · e_prev, and the
  next bar loses at most m · G₁.

So r′ ≥ −Λ(2κ + m), and with Λ = 4, r′ ≥ −2, the condition of the holdout theorem (`gate/NULLS.md`, limited
liability), whenever m ≤ 1/2 − 2κ. NULLS.md's gapless synthetic nulls meet it by construction. A real market gaps: a
fill then trades at an open away from its mark, which this proof does not cover
(`audit/reviews/2026-11-04-gpt-nine-defects-review.md`, finding 1). On real markets r′ ≥ −2 is an assumption that the
holdout's conclusion rests on; a report of realized excursions is a diagnostic, never proof of it.

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

## 10. Reports

A result reports a window of one run: its steps with equity time > R, the window's start (w_start, or a holdout's
`--holdout-from`), and s, the last step at or before R, if any [main.rs `reported`].

- **Window account.** It starts at 10,000 if there is no s or the run's equity at s is positive, else at 0 (I10: a
  bankrupt account stays at 0), and compounds the window's returns (K5). final_equity is its last value and
  total_return = final_equity/10,000 − 1.
- **Window trace.** The run's trace after its Equity record at s (the whole trace without s). s's fills come after
  that record and their costs fall in the window's first return, so they are in the window's trace (K6). Over that
  trace, fills counts the fill records, closeouts included; fees is Σ fee, slippage Σ qty · (price − reference), and
  turnover Σ |qty| · price.
- **Exposures** (`--mechanism on`). Each step time T = b + BAR is a fill instant: its closeouts (steps 3 to 5), then
  its fills (step 7). An exposure is a pair (c, T) with c held after T's fills and T + BAR an Equity time in the
  window, so a position still open at the run's end ends at its last Equity record, at its marks. Its label is c's
  prediction condition (true, false or Undef) at the decision due at T, the one at T − BAR + δ, whether or not it ordered c or its order filled. With v_c
  the coin's cash flows (fills, fees and funding) plus q[c] · mark, its return is the change in v_c over it divided
  by the Equity recorded at T. It starts where c's previous exposure ended (v_c = 0 at the run's start) and ends at
  T + BAR: after that instant's closeouts and fills if they leave c flat, else before them. So every fill, a reversal
  whole, falls in exactly one exposure, the one it closes if it leaves c flat, else the one it opens, and so does
  every price change and funding payment while held (M1). Every exposure counts: with n_t, n_f and n_u the true,
  false and Undef counts and N their sum, the check passes iff N > 0, n_t/N and n_f/N both lie in [0.1, 0.9], and the
  true exposures' mean return exceeds the false ones' (M2). share_true is n_t/N, absent when N = 0.
