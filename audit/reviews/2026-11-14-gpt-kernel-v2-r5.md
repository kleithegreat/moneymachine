# GPT (gpt-6.1-sol, high, opencode) on kernel version 2 and study 2: round 5

Run 2026-11-14 20:22 to 20:52 UTC (15:22 to 15:52 EST), alongside Argon, from a clean read-only bundle (`~/.cache/mm-gpt/kv2-r5`) with the same files. Verbatim below.

# Verdict

**This is a genuine re-derivation, but not yet a converged design.** The economic test ledger removes the old free resizing of held exposure. My round-4 wish-padding construction no longer works.

I found a different route through the **unspent budgets**: funding can make “free cash” negative without ending the ledger, after which the stated stake rule produces a negative scale. I also found a failure of K1’s proposed rounding contract, a short-liquidation counterexample to T1 as written, and a market that passes the rung-2 guard while a mechanical rebalancer outgrows the certificate.

None requires restoring `at_risk`, deferred accounting, or a second valuation clock.

## The re-derivation test

| Report’s row | Judgment |
|---|---|
| **A benchmark taken for a null** | **Removed from the mathematical derivation, not fully removed from the coverage argument.** The literal rung-2 null is a genuine conditional numeraire hypothesis. The benchmark does not establish that hypothesis. The hourly/daily guard cannot establish it either; Finding 4 gives a counterexample. |
| **A state taken for a flow** | **Removed from execution reporting.** Fills, liquidation closes, funding and absorption are now distinct, contemporaneous cash flows. Budgets must remain reservations—not additional money. Their interaction with funding is nevertheless incomplete: Finding 1. |
| **The account taken for the test** | **Removed at the economic level.** Copying a sale’s fraction, using cycle IDs, and stopping on a short account do not import the account’s equity or absorption. They select transactions in the test’s own books. This remains sound when the test copied fewer units than the account, provided the denominator is the account’s position immediately before that particular fill. |

**My round-4 construction:** after the down print, the test has already taken the loss on its existing units. An unfilled far wish changes neither cash nor units. A subsequent buy at 99 against a price of 98 costs wealth rather than retroactively diluting the previous loss. There is no surviving version of that particular exploit under nonnegative, self-financing transactions.

The new budgets can violate the *nonnegative-scale premise*, however. That is a different failure, not evidence that the old normalization survived.

# Findings, in the requested attack order

## 1. D29/O5: funding can make free cash negative, producing a negative scale

**Outcome changed:** the judged wealth and potentially a false “earned” result.

**Claim:** the stake rule always supplies nonnegative scales, and its budget state affects power only.

**Construction:** take \(\phi=1\). Normalize the ledger’s starting cash to 1.

1. Coin A’s first buy spends 0.4 of its cycle’s budget. The ledger now has:
   - cash 0.6;
   - A worth 0.4;
   - A’s unspent budget 0.6.
2. A funding payment charges 0.1. Cash can pay, so the test does **not** end.
3. Cash is now 0.5, but the outstanding reservation is still 0.6. The stated definition gives
   \[
   \text{free cash}=0.5-0.6=-0.1.
   \]
4. Coin B’s cycle begins. Its budget, and consequently its scale, is negative.

This payment satisfies V16: A paid only one quarter of its unit value. No leverage, bankruptcy or excessive settlement is needed.

K1 applies only to nonnegative scales. The proposed stake rule has failed its premise.

If implemented literally, negative scaling can manufacture precisely the prohibited short test position. For example:

- B’s account buy produces a test “buy” of \(-0.1\) units at price 1, adding 0.1 to test cash.
- B then charges funding of 0.9 per unit: the negative position **receives** 0.09.
- B’s price falls from 1 to 0.1: the negative position gains another 0.09.

The test’s wealth becomes

\[
1-0.1+0.09+0.09=1.08.
\]

Every price or funding return to a **long** holder in this construction is nonpositive. The account buys positive units and loses money; it has no skill. Close both cycles and repeat the same fixed-notional account transactions, with sufficient account starting cash. The literal negative-scale ledger compounds upward.

Both funding charges are less than the corresponding unit’s price. Small spreads and the stated fees do not remove the strict gap.

A correct implementation cannot execute this sequence while also maintaining A12’s nonnegative units. That is the specification conflict: it must either refuse, clamp, or change reservations, and none is currently specified.

**Smallest change, hypothesis:** define allocatable cash as

\[
\max\!\left(0,\ C-\sum \text{unspent budgets}\right),
\]

and prove the actual stake rule—not merely an arbitrary nonnegative scale—satisfies K1’s premise. Funding may leave reservations underfunded; subsequent buys can still be cut to cash. Alternatively specify how funding reduces reservations. Neither operation should credit cash.

### Other D29 attacks

These did **not** produce an economic exploit:

- **Returning an unused budget:** safe if it removes a reservation only. Adding its amount to cash would be a gift.
- **Partial sales after following less:** \(h\leftarrow h(1-s/q)\), using the account’s pre-fill \(q\), is an ordinary sale of \(hs/q\) units. It does not need the account’s cost basis.
- **Cash cuts on buys:** safe when they include fees and debit exactly the executed quantity’s all-in cost.
- **Account absorption:** correctly ignored.

Those conclusions assume exact transaction arithmetic. The proposed rounded implementation has a separate problem.

## 2. K1: rounding every stored number down does not make the resulting wealth a lower bound

**Outcome changed:** the reported judged wealth; a sufficiently close threshold comparison can change.

**Claim:** the rounded ledger is always at most the exact ledger using the registered stake rule.

**Construction:** consider the natural reading that budgets, scales and ledger balances are stored with the specified downward rounding. Let

\[
u=2^{-128}.
\]

Start with cash 1, use a budget fraction \(\phi=1/5\), and buy at price 1 with zero fees. Zero is sufficient to test the general arithmetic contract.

The exact ledger buys \(1/5\) units and retains \(4/5\) cash.

At 128 significant bits, the rounded budget is

\[
\widehat q=\frac15-\frac u5.
\]

Spending that rounded budget leaves

\[
\widehat C=\frac45+\frac u5,
\]

which is representable at the cash balance’s precision. The approximate ledger bought slightly less and retained slightly more cash.

Now let the price fall to \(1/10\). Exact wealth is

\[
W=\frac45+\frac1{50}=\frac{41}{50}=0.82.
\]

Before final rounding, approximate wealth is

\[
\widehat W=W+\frac9{50}u.
\]

The fractional part of \(W/u\) is \(46/50\). Consequently, rounding the approximate wealth **down** still gives

\[
\operatorname{roundDown}(\widehat W)=W+\frac2{25}u>W.
\]

The strict inequality survives rounding the asset multiplication down as well.

There is no economic money creation here: buying slightly less before a fall is a different, perfectly feasible strategy. But its wealth is **not** a lower approximation to the exact registered strategy’s wealth. Thus K1’s stated one-sided contract does not follow from downward rounding.

Likewise, a uniform relative-error guarantee for a cash-flow fold needs a cancellation argument. Rounding positive balances before nearly exhausting them through payments is not covered by a count-times-machine-epsilon argument for positive products.

**Smallest change, hypothesis:** choose between two distinct contracts:

- fold the defined test ledger exactly and round only its reported outputs; or
- define the implementable rounded transaction policy as the test itself, prove its self-financing/nonnegativity directly, and use an appropriate enclosure contract.

Do not claim componentwise downward rounding makes a nonlinear, cash-constrained policy a lower approximation to another policy. The exact rounding specification owed before step 10 must resolve this.

## 3. T1: A10’s literal liquidation rule buys back a short below the tape

**Outcome changed:** a general kernel run’s liquidation proceeds and judged result. This does not rescue study 2’s long-only ledger.

**Claim:** T1 covers every fill, including liquidation buys.

**Construction:**

- Hold a short of one unit, with cash 102.
- Latest quote: bid 99, ask 101; price initially 100.
- A buy-aggressor print moves the coin’s price to 102.
- Adverse short equity becomes zero, triggering liquidation.

A10 says every position closes at each level’s price **or the coin’s price, whichever is less**. Applied literally to the short’s buyback, that buys at

\[
\min(101,102)=101<102.
\]

It beats the post-event tape and leaves roughly one dollar more cash than a buyback at 102.

A7’s sell/buy mirroring convention does not clearly specify this position-dependent forced-close rule; A10 explicitly quantifies over every position while giving the long-sale formula.

**Smallest change, hypothesis:** write both liquidation directions:

- close a long at \(\min(\text{bid level},P)\);
- close a short at \(\max(\text{ask level},P)\).

Add the short-print fixture explicitly to step 7. If that mirror was already intended, this is a clarification with a concrete result-changing interpretation removed.

### The remaining T1 cases

I found no counterexample for eligible **long-only** transactions:

- arriving buys pay asks above the quote mid;
- optimistic resting buys on quotes require \(a\le p\), hence \(P\le a\le p\);
- print equality gives equality, not a favorable fill;
- pessimistic print-through fills have the correct adverse inequality;
- the bar’s two prints are separate ordered events, even when timestamps match;
- settlement satisfies T1 **provided settlement explicitly updates the valuation price to the settlement price before closing**.

One further premise belongs in the derivation: **fees must be nonnegative**. T1 constrains execution price, not rebates. The current positive base schedule satisfies that premise; T1 alone would not prove the assertion for an unrestricted negative-fee schedule.

## Attack 3 — O3: ordinary bid–ask bounce does not give a taker this exploit

**No result-changing finding under a fixed executable book.**

For a fixed bid \(b\) and ask \(a>b\), a taker buys at least at \(a\) and sells at most at \(b\). Print marks bouncing between those prices telescope while units are held. They do not turn a completed taker round trip into a profit. Nonnegative fees strengthen that conclusion.

At a day’s end immediately after an ask print, marking a newly bought unit at the ask only removes its initial mark-to-mid loss; it does not create profit over its purchase cost.

Two qualifications:

- This does **not** make rung 1’s price null true. A predictable rebound from a bid print can violate that null even when no taker can profit.
- The argument is about bounce inside a fixed executable spread, not arbitrary changing quotes. A mechanical taker can earn from sufficiently large quote oscillations. That is not an accounting defect, and “earned” already declines to mean skill.

Thus O3’s narrow executable-book argument survives; it should not be advertised as validation of the null on real prints.

## 4. D30/O4: the hourly/daily guard passes a mechanical rebalancer that outgrows the certificate

**Outcome changed:** whether rung 2 is registered, and its claimed exclusion of mechanical rebalancing.

**Claim:** requiring the event-level bar to exceed the best hourly and daily mixes screens out the problematic event-order market.

**Construction:** modify Argon’s market by alternating its assignments. In every two-pair block:

| Pair | A return | B return |
|---|---:|---:|
| 1 | \(+25\%\) | \(-15\%\) |
| 2 | \(-15\%\) | \(+25\%\) |

Within each pair, quote A and then B. Put an even number of pairs inside every hour and day.

An account mechanically restoring half its wealth to each coin **after every pair**, without forecasting, grows per block by

\[
W_{\rm block}=1.05^2=1.1025.
\]

Each individual coin grows per block by

\[
1.25\cdot0.85=1.0625.
\]

At hourly and daily boundaries the coins therefore have identical cumulative returns. The best slower mix is fully invested and grows by \(1.0625\) per block.

The event-level best constant mix grows by

\[
(1.125\cdot0.925)^2=1.082900390625.
\]

The certificate is slightly larger. For each coin, per block,

\[
S_1=0.10,\quad S_2=0.085,\quad S_3=0.01225,
\]
\[
Q=0.038416666\ldots.
\]

The minimized dual bound is

\[
D=0.080791666\ldots.
\]

Thus the certified bar grows approximately by \(e^D\) per block, giving the ordering

\[
1.0625
<
e^{0.080791666\ldots}
<
1.1025.
\]

**The guard passes. The mechanical rebalancer nevertheless outgrows the certified bar exponentially**, crossing twenty times it after roughly 179 blocks before costs.

Small positive spreads and the stated fees leave a substantial strict gap. This is a counterexample to the guard’s coverage, not a prediction that the frozen ladder implements this controller. It uses the class of self-financing holdings that the claimed exclusion discusses.

**Smallest change, hypothesis:** retain “outgrew” as the descriptive comparison, but remove the guard’s interpretation as certifying the exclusion of unskilled rebalancing. Report the hourly/daily comparisons as diagnostics. Adding another finite list of clocks would not remove the cause.

### Does any record condition exclude holdings?

Yes, but distinguish the classes:

- **Initial buy-and-hold without funding:** the existing pathwise dominance by cash and single-coin corners works.
- **Fixed units with funding:** their wealth is linear in initial units:
  \[
  H_T=1+\sum_c q_c\left(P_c(T)-P_c(0)-F_c(T)\right),
  \]
  where \(F_c(T)\) is cumulative funding paid per unit. Initial funding and every prefix cash-solvency constraint are linear too. A record-based linear program can bound every such holding, rather than dismissing the discrepancy as “second order.”
- **Arbitrary adaptive holdings:** comparing three hindsight benchmarks cannot certify a conditional-law null. A pathwise perfect-foresight upper bound can exclude *all* such holdings, but would then exclude the tested strategy as well.

The actual null needs a distributional hypothesis, not a record-level ranking.

## 5. Rung 2’s asserted sufficient condition ignores predictable coin identity

**Outcome changed:** scientific coverage of the judged result; a rule can pass despite satisfying the stated scalar-return independence condition.

**Claim:** if each price event’s return has the same law whatever preceded it, a constant mix is the best holding, excluding rising-market and rebalancing profits.

**Construction:** price events alternate predictably between A and B. At every event, its coin rises by \(a>0\). The scalar event returns are constant, hence independent of everything before them.

A calendar controller holds the coin scheduled to move next, switching between events. Before costs, it gains

\[
(1+a)^2
\]

per A/B pair. A constant mix is maximized at half in each coin and gains

\[
(1+a/2)^2.
\]

The controller’s ratio grows exponentially. With \(a=0.01\), the cubic certificate’s slack is tiny compared with that growth gap; sufficiently narrow spreads and the stated fees preserve it.

Over complete hourly or daily blocks, both coins appreciate equally. The event benchmark also exceeds the slower benchmark, so the existing guard does not reject this market.

No scalar return predicts another scalar return. **The predictable opportunity is which coin moves next.**

This does not disprove the literal rung-2 null: that null is false here. It disproves the offered sufficient condition for that null. Independence of scalar innovations is not enough.

**Smallest change, hypothesis:** remove that sufficient-condition sentence, or replace it with a condition on the **full marked event process**, including coin identity and calendar information, under which the proposed constant mix’s conditional numeraire inequalities are actually established.

“Fills better than the tape” should also be removed from the list of ways to pass under the null: T1 prohibits those fills. Maker gains arise from subsequent price changes, not a violation of T1.

# Attack 5 — The certificate

The main certificate repairs survive examination.

- **Several \(Q_c\le0\):** the endpoint maximum is correct. Summing the individual maxima gives a valid multiplier relaxation even when its maximizing coordinates cannot jointly satisfy the simplex constraint. That costs tightness, not validity.
- **Directed fixed-point sums:** increasing \(S_1\), decreasing \(S_2\), and increasing \(S_3\) conservatively increases the cubic envelope, including across the \(Q=0\) branch.
- **One return or no returns:** a first quote initializes price rather than inventing a return; a subsequent single return is covered. For no returns, \(\mu=0\) gives \(D=0\) and bar 1.
- **A return exactly \(-1\):** a corner mix can become zero, but the product bound remains valid. The logarithmic proof must handle the zero factor separately rather than evaluate \(\log0\).
- **A return below \(-1\):** the certificate is outside its economic domain. The least-return veto correctly prevents subsequent confirmation.

Two contract qualifications remain:

1. **K2 needs its domain stated.** Its unconditional “every constant mix” bound is false for formal products with negative factors. For example, two funding returns of \(-3\) give the all-coin formal product 4, while \(\mu=0\) gives \(D=0\), bar 1. The veto prevents a false result, so this is a theorem-domain correction, not an additional result-changing finding.

2. **The tiny stated log-slack bound is slightly too small.** When \(D/n=2^{-40}\),
   \[
   -n\log(1-D/n)-D
   =\frac{D}{2^{41}}+\text{positive higher terms}.
   \]
   This does not invalidate the upper certificate or change a decision. It is a note: use a bound including the remainder.

The arithmetic script does **not** test the fixed-point implementation: `mix_bound` uses floating-point sums. The planned Lean theorem remains the substantive wall; sampled optimizer comparisons are supplementary.

# Attack 6 — D32: ending at an unaffordable payment

**The rejection rule can retain its size under V16, but “a stopping time” is not the whole proof.**

Let \(C\) be cash, \(q\) the held units, \(P\) the price, and \(f\) the payment per unit. If \(0\le f\le P\), then even when \(qf>C\), post-payment total wealth is

\[
C+q(P-f)+\text{other assets}\ge0.
\]

For the proof, kill the process to zero at that event. This only lowers the nonnegative post-payment wealth, and it matches the rule that nothing can be confirmed afterward.

Do **not** freeze the pre-payment wealth and call that the stopped supermartingale: that skips the adverse payment. Operationally retained balances may be displayed as diagnostics, but are not that proof process.

### A payment above the unit’s price

The observed least-return veto cannot replace V16. For example, start half in cash and half in a coin at price 1. Let the next funding return per unit be:

- \(+40\), probability \(0.1\);
- \(-40/9\), probability \(0.9\).

Its conditional mean is zero. On the first branch wealth becomes 21 and can confirm; on the second branch the payment is unaffordable and the test ends. The confirmation probability is 10%.

V16 excludes the losing branch’s excessive unit payment. Seeing no such payment on the winning branch does not establish the assumption.

This is **not a new counterexample to the design conditional on V16**; the design already concedes the shortfall issue. The conclusion is that the 5% guarantee must remain explicitly conditional on V16, not be described as certified by the observed minimum. Earlier confirmations “stand” under that maintained assumption.

# Attack 7 — D14-v5: the join

**The revised join survives its narrowed purpose.** An eligible, live, non-stale optimistic resting order at the matched print’s price qualifies by equality. Parent-order minimums and earlier arrival refusals no longer defeat the join, because it is no longer an order replay.

A real fill with its print present can still be unrepresentable as an optimistic *run*. For example, the real order rests and fills within one millisecond; both placement and print have timestamp \(t\). A7 requires a print strictly after placement, and L1b forbids filling at \(t\). The join passes while that timestamped replay cannot fill.

That is **a note, not a wall failure** under the new design: the order measurement has no pass mark. State the implication narrowly:

> The matching print qualifies an already eligible model order; it does not establish a model placement history reproducing the real fill.

Stale fills likewise remain a separate class, not evidence of missing prints.

# The human’s three choices

1. **Rung 2: agree with recommendation a, as a narrow comparison.** “Outgrew every constant mix” is informative; the guard must not imply that it excludes mechanical rebalancing or establishes the null.
2. **V10: agree with accepting the named academic counterfactual.** Neither a cap nor a zero diagnostic count proves replenishment; an invented depletion model would be another assumption.
3. **Disk: agree with measured capacity and an independent second copy.** Size for existing recordings, every stream, measured growth and headroom; do not treat 1.2 TB per copy as a capacity guarantee.

# Convergence ledger

## Agreed

- The new economic ledger removes round 4’s free retrospective resizing.
- Executed flows are now booked at their events; absorption stays outside the test.
- Sale fractions, cycle boundaries and cash cuts can select valid test transactions without importing account equity.
- Ordinary fixed-book print bounce does not make completed taker round trips profitable.
- The cubic envelope, multi-coin dual relaxation and fixed-point rounding directions are sound on their proper domain.
- Killing the test at an unaffordable payment preserves validity under V16.
- Layer 2’s join is properly narrower than replaying real orders.
- The prospective recording/fidelity study remains worthwhile.

## Disputes open

| Point | Finding | Changes what is built or run? |
|---|---:|---|
| Funding leaves negative allocatable cash and a negative cycle scale | 1 | **Yes:** stake rule and its proof |
| Downward-rounded policy is not a lower approximation to the exact policy | 2 | **Yes:** confirmer arithmetic and K1 |
| Short liquidation contradicts T1’s universal statement | 3 | **Yes:** liquidation semantics and fixtures |
| Hourly/daily guard does not exclude mechanical rebalancers | 4 | **Yes:** registration wall or its interpretation |
| Scalar-return independence does not establish the rung-2 null | 5 | **Yes:** criteria and coverage language |

These are mathematical specification questions, not choices the human can settle by preference.

## Human-only decisions

The comparison worth pursuing, acceptance of V10, and recording scope/capacity remain legitimate human decisions. Agreement with all three recommendations does not resolve the disputes above.

**Convergence test: failed.** Several open points change the implementation or registration. Nevertheless, this round’s appropriate response is **not another replacement of the economic wealth construction**: retain the self-financing ledger, complete its budget and numerical contracts, and withdraw the guard’s unsupported coverage inference.
