<!-- GPT (openai/gpt-6.1-sol#high), independent check of the bankruptcy bound in audit/reviews/2026-11-03-claude-fork-review.md; finished 2026-11-04 00:01 UTC (2026-11-03 19:01 EST). Static reading of 4dd775b. -->
# Check

**The limited-liability argument has a sound core, but it does not establish the review’s unconditional conclusion for this code.** The stopping argument can be repaired—and strengthened to cover the **raw p-values**, which Holm needs. But the required loss condition is distributional, not something established by observing no bankruptcies. The N2 tail calculation is a restricted, per-wick estimate, not a campaign error bound.

Static reading only; no execution or edits.

## 1. Optional stopping: valid with qualifications

Let \(\tau\) be the first bankruptcy step, and define \(r'_t\) as the step’s net equity return **before shortfall absorption**, including funding, ordinary execution costs and liquidation fills. Stop this process after \(\tau\).

Before bankruptcy, \(r'_t=r_t>-1\). At bankruptcy, \(r'_\tau\le-1\), whereas the reported return is \(-1\). Consider
\[
V_t=\prod_{s\le t\wedge\tau}(1+\lambda_s r'_s).
\]

If the bets are predictable, the relevant variables are integrable, and
\[
E[r'_t\mid\mathcal F_{t-1}]\le0
\]
while the account is alive, then \(V\) is a supermartingale **provided its wealth before each next bet is nonnegative**. The sufficient condition
\[
r'_t\ge-2,\qquad 0\le\lambda_t\le\tfrac12
\]
ensures nonnegativity, including the bankruptcy step. Ville’s inequality then applies.

There is a useful strengthening missing from the review:

* At bankruptcy, neither the reported factor \(1-\lambda_\tau\) nor the untruncated factor \(1+\lambda_\tau r'_\tau\) creates a new wealth maximum.
* Subsequent reported returns are zero.
* Consequently, the reported betting wealth and \(V\) have **the same running maximum**, although their terminal values differ.

Thus, under those assumptions, **the raw `holdout_pvalue` is superuniform on all paths, including bankrupt paths**. The positive-total-return filter is not needed for this particular validity proof.

### What happens when the terminal factor can be negative?

The review’s correction term is essentially right for one strategy, but needs a finite-horizon indicator and, for the sharp version, stopping at the threshold crossing too.

Writing \(K_{\tau-1}\) for betting wealth before bankruptcy, a valid weaker bound is
\[
P(p\le u)\le
u\left(
1+E\!\left[
\mathbf1_{\{\tau\le T\}}K_{\tau-1}
(\lambda_\tau|r'_\tau|-1)^+
\right]\right).
\]

This follows by stopping at the first threshold crossing, bankruptcy, or the horizon, and charging any negative terminal wealth against the threshold-crossing probability.

Important qualifications:

1. **Below \(-2\) is necessary for a negative factor under this cap, not sufficient.** The exact condition is \(\lambda_\tau|r'_\tau|>1\).
2. A negative factor means the exact Ville proof can fail; it does **not** prove that the actual rejection probability exceeds \(\alpha\).
3. The correction is **wealth-weighted overshoot**, not bankruptcy probability or extreme-wick probability.
4. The loss condition must hold almost surely under the null law. Checking it only on realized evaluations does not establish an error guarantee.

For example, independent untruncated returns of \(+0.02\) with probability \(0.999\), and \(-19.98\) otherwise, have mean zero. With bankruptcy absorption, 303 consecutive gains pass this gate’s single-strategy p-value threshold and positive-return rule; that event has probability about \(0.738\). Every such promoted path avoids bankruptcy. The catastrophic losses on *other* paths are what invalidate the guarantee.

This is not an N2 counterexample; it shows why survival alone cannot prove the claim.

## 2. “Promoted implies never bankrupt”: true for genuine kernel results

The implication survives inspection:

* `sim.rs:357–363` closes remaining positions and absorbs the nonpositive cash balance.
* `sim.rs:380–384` records the bankruptcy return as \(-1\), followed by zeros.
* Further ordinary fills require positive equity (`sim.rs:397`).
* `reported()` compounds retained returns (`main.rs:107–120`). A retained \(-1\) therefore makes reported total return \(-1\).
* Bankruptcy before the reporting window produces zero retained returns; the reporting bug reconstructs total return as **zero**, not positive.
* Both fail `gate.py:252`.

So a genuinely kernel-produced promoted evaluation has not gone bankrupt, including in its replay prefix.

**Liquidation is not bankruptcy.** The maintenance branch at `sim.rs:344–348` can close positions while leaving positive equity. Such an account can subsequently trade and potentially promote.

Strictly, that branch closes **every held position**, rather than performing partial-quantity margin liquidation. But a liquidation that destroys only part of the account’s equity is possible, and ordinary partial reductions are supported by `Book::fill`. Neither constitutes bankruptcy.

The pending-close reopening defect therefore does not refute the survival implication. It can, however, create highly leveraged **subsequent** positions.

## 3. Is the untruncated return conditionally nonpositive?

**Yes, under the intended null model and ordinary execution-cost assumptions.** “Supermartingale difference,” rather than “martingale difference,” is the appropriate term once costs and adverse liquidation are included.

For predictable opening quantities \(q_i\), the generator and funding settlement give
\[
\Delta E'_t
=\sum_i q_i o_i\varepsilon_i-C_t-A_t,
\]
where ordinary execution costs \(C_t\ge0\), and \(A_t\ge0\) represents the additional loss from liquidation relative to marking the same positions at the close, including liquidation execution costs.

The essential points are:

* Funding settles before boundary fills, matching the generator’s cancellation formula.
* Positions remain constant through the bar’s funding settlements and price move.
* Liquidation is assessed afterward. Its dependence on the realized bar does not create a predictable-selection problem: the adverse-price adjustment is nonpositive **pathwise**.
* Boundary fills, including partial reductions or erroneous reopenings, set the next bar’s quantities using information available before that bar’s innovation.

Dividing by the positive, past-measurable previous equity preserves the conditional inequality. Predictable leverage—even erroneous leverage—does not by itself create positive conditional expected untruncated P&L.

Two qualifications matter:

* This requires the null’s conditional-zero innovation assumption to hold given **all search information and the joint market past**, not merely a strategy’s own return history.
* `gross_returns` is **not** the required \(r'\): it removes some costs but still uses equity after absorption.

There is also a literal generator defect relevant to the review’s long-loss assertion: `markets.py:197` permits **negative lows**, since Gaussian wicks are unbounded, and the loader does not reject them. Thus “a long can lose at most its notional” is not literally true here. Funding and costs also make net loss different from price-only loss.

Negative lows even produce negative modeled liquidation fees. With the intended small, nonnegative cost rates, the **combined** long closeout proceeds remain adverse relative to the positive close, so this does not overturn the conditional-P&L argument. It does invalidate the blanket explanation that every separately named cost always subtracts.

## 4. Holm: the review needs validity of every raw p-value

Paper §8 states the correct selection requirement:
\[
P(p_i\le u\mid\mathcal F_{\rm search})\le u.
\]

Given that requirement for each true null in the frozen family, Holm works under arbitrary dependence. Finalists may share every market observation. Search-only mechanism defects can change the family without introducing an additional multiplicity failure.

But **a bound only on surviving candidates’ promotion events is insufficient**.

`promote()` computes Holm over **all supplied results before applying the positive-return filter** (`gate.py:245–253`). A bankrupt finalist can retain a tiny p-value from an earlier wealth peak. For example, raw p-values \(0.001\) and \(0.04\) let the second finalist pass Holm at \(0.05\), even if the first is bankrupt and cannot promote.

The strengthened raw-p-value proof in section 1 repairs this gap **when its loss assumptions hold for every relevant finalist**. Without that proof, “promoted paths survive” is not enough.

For a complete-null family of \(m\) finalists, individual bounds
\[
P(p_i\le u\mid\mathcal F_{\rm search})\le u(1+\delta_i)
\]
give the conservative campaign bound
\[
P(\text{any promotion}\mid\mathcal F_{\rm search})
\le \alpha\left(1+\frac1m\sum_i\delta_i\right),
\]
using Holm’s necessary first-rejection threshold \(\alpha/m\). The \(\delta_i\) must include the appropriate overshoot expectations.

**Therefore the two selection defects are not independently fatal to a valid holdout test, but “they stay within \(\alpha\)” is conditional, not established unconditionally here.** They may change which leverage/overshoot processes reach that test.

Also, the family must match the claim:

* `promote()` corrects only across its `results`.
* Recovery appropriately retains missing frozen finalists using `ABSENT`.
* `gate/agent/campaigns.py:552–554` runs separate corrections for arms A and B. That supplies per-arm control, not automatically \(\alpha\) control for “either arm promotes.”

## 5. The N2 \(10^{-21}\) figure: plausible scale, wrong interpretation

For a genuinely two-times short, let \(k=c/o\), let \(w\) be its upward fractional wick, and initially ignore execution costs. Its untruncated liquidation return is
\[
r'=-2(\varepsilon+kw).
\]

Since
\[
k\le\frac{1+0.12+0.5}{1-0.04}=1.6875,
\]
a loss below \(-2\) requires, at the most favorable extreme \(\varepsilon=0.5\),
\[
w>\frac{0.5}{1.6875}\approx0.2963.
\]
N2’s largest wick standard deviation is \(0.0625/2=0.03125\), giving about **9.48 Gaussian standard deviations**. The corresponding half-normal tail is roughly \(2.5\times10^{-21}\). With zero funding the threshold is 10.67 standard deviations instead.

So the review’s order of magnitude is recognizable. However:

* It is a **single-wick tail envelope**, not the joint probability of the needed innovation, funding, volatility, position and liquidation.
* Costs lower the threshold.
* Campaign exposure includes many coins and bars.
* Finalists share those draws: neither independent-finalist multiplication nor an independence assumption is justified.
* The stopping correction requires overshoot **severity and betting wealth**, not just event frequency.

Most importantly, **the code does not establish actual held gross exposure of at most two**. Undefined holds, delayed sizing/fills, and post-liquidation reopening prevent using the normalized target vector as such a bound. Nor is \(2\times12\) a universal bound relative to shrinking account equity.

The review also conflates *liquidation* with *loss below twice equity*. A two-times short with zero funding, negligible costs and high equal to close triggers maintenance liquidation when
\[
1-2\varepsilon<\frac{2(1+\varepsilon)}{20},
\quad\text{i.e.}\quad \varepsilon>\frac37.
\]
At \(\varepsilon=0.45\), liquidation leaves positive equity. This is within N2’s innovation support and requires no enormous wick. The \(10^{-21}\) calculation therefore does **not** establish that the reopening defect’s prerequisite is essentially unreachable.

## 6. Corrected conclusion

The defensible theorem is:

> Conditional on search information, suppose every relevant finalist has predictable opening positions, integrable pre-absorption net returns with nonpositive conditional means while alive, and absorbing bankruptcy as implemented here. If every terminal betting factor is nonnegative almost surely—sufficiently, \(r'\ge-2\) under the gate’s cap—then its reported running-maximum p-value is valid even on bankrupt paths. Holm across the complete frozen family controls false promotions at \(\alpha\), without independence between finalists. The positive-return filter can only reduce promotions.

This is a genuine improvement over a survival-only qualification. **It is not an established exact guarantee for the current N1–N3 implementation**, whose wick support is unbounded and whose actual exposure lacks the assumed two-times bound. Any “effectively exact” claim needs a justified family-level overshoot bound.

## 7. Exact replacement for `NULLS.md:42–49`

Replace that paragraph with:

> **Limited liability and bankruptcy.** The conditional no-edge argument above applies to net PnL before the venue absorbs a shortfall, including execution costs and adverse liquidation fills. Absorption increases reported PnL by the absorbed amount; therefore reported net returns need not have nonpositive conditional means. Conditioning on an evaluation never going bankrupt does not restore the no-edge property, because survival is outcome-dependent. A maintenance liquidation that leaves positive equity is not bankruptcy.
>
> For the current holdout test, bankruptcy does not by itself invalidate the running-maximum p-value. Let \(r'_t\) be the net step return before shortfall absorption, and stop its betting process at the first bankruptcy. If these returns have nonpositive conditional means while the account is alive and every stopped betting factor \(1+\lambda_t r'_t\) is nonnegative almost surely, the stopped wealth is a nonnegative supermartingale. Its running maximum equals that used by the gate: the bankruptcy return of \(-1\) cannot create a new maximum, and subsequent reported returns are zero. Thus the raw p-values remain valid, including on bankrupt paths, and Holm controls false promotions across the complete frozen finalist family. With \(0\le\lambda_t\le1/2\), the bound \(r'_t\ge-2\) is sufficient.
>
> This sufficient bound is not established for N1–N3 in the current implementation. Wicks are unbounded, and normalization of defined target weights does not bound actual held exposure. If a terminal betting factor can be negative, the stopping bound requires an expected wealth-weighted overshoot correction; a small observed bankruptcy rate alone does not establish exact or approximate \(\alpha\) control. Null campaigns retain and report all evaluations, including those with a step return of \(-1\); none are removed by conditioning on survival. Genuine kernel results with bankruptcy cannot pass the positive-total-return rule, but a bankrupt finalist’s earlier wealth peak can still affect Holm’s calculation.
