# GPT (gpt-6.1-sol, high, opencode) on kernel version 2 and study 2: round 3

Run 2026-11-14 15:40 to 15:59 UTC (10:40 to 10:59 EST), alongside Argon, from a clean read-only bundle (`~/.cache/mm-gpt/kv2-r3`) with the same files as Argon's round 3. Verbatim below.

# Verdict

**Not converged; do not register study 2 yet.** The strongest new breaks are:

- A **buy-and-hold account**, with no timing decisions, can beat the daily best constant mix through the confirmer’s finer rebalancing alone.
- Funding can make a benchmark’s daily factors negative, invalidating the proposed certificate.
- A pending order can acquire fresh capacity when a cycle resets, breaking Q1.
- Several ★ laws still contradict valid transitions; the confirmer’s laws and tests still admit a confirmer that never confirms.

The three named confusions are **not all removed**. The benchmark/null confusion survives in the interpretation of rung 2; the account/test confusion survives in the categorical leverage prohibition; cumulative state versus outstanding demand survives across cycle resets.

## Disposition of round-2 findings

“Removed” concerns the original construction, not approval of its replacement.

### GPT’s findings

| R2 | Disposition |
|---|---|
| **G1: quiet asset/Jensen/beta** | The particular equal-weight denominator is removed. **Cause survives:** daily constant mixes are again interpreted as excluding everything a holding without timing can earn. Finding 1 breaks that interpretation. |
| **G2: intra-step exposure** | The old exposure mismatch is removed. **Patched at another timescale:** finer rebalancing against daily mixes is treated as a tiny residual without a bound. Finding 1. |
| **G3: membership** | Settlement-inclusive, fixed-universe reporting removes the stated delisting construction. Missing initial marks, zero marks and later listings remain unspecified. Finding 2. |
| **G4: account versus test** | **Removed for the chosen recurrence:** fractional test wealth is now separate. The same confusion remains in the claim that physical leverage cannot be tested exactly. Finding 6. |
| **G5: limited-liability gift** | Removed from the proposed *leveraged* judged account by excluding it—not by correcting its statistic. Funding can still create negative cash and absorption at leverage 1. Findings 5–6. |
| **G6: repeatedly spending quote evidence** | **Removed for resting pessimistic fills.** Unique, correctly classified prints are a genuine causal repair. Quote-based taker reuse remains expressly conditional on V10, not proved evidence conservation. |
| **G7: incompatible fill laws** | Optimistic capacity is correctly separated from E1. **Partially patched:** E1 still excludes legitimate sells, and F0/L4 need scope corrections. Finding 7. |
| **G8: aggregate fidelity wall** | **Removed at its cause:** the wall and its prospective guarantee are withdrawn. The replacement’s continuous-presence premise is not observable from fills alone. Finding 8. |
| **G9: replacement and `close`** | Same-cycle replacement and double subtraction from `close` are repaired. **Cross-cycle pending orders remain broken.** Finding 3. |
| **G10: world versus view** | The principal split is correct. **Incomplete:** staleness and order-status delivery do not yet follow that split unambiguously. Findings 9–10. |
| **G11: future-defined gaps** | **Removed for operational world staleness**, taking the build plan’s “G after the last quote” as authoritative. View staleness remains open. Finding 9. |
| **G12: shared-time funding** | **Removed:** funding uses the position held into the timestamp. |
| **G13: funding, fees, conservation** | `absorbed`, fee reservation and funding-time checks are repaired. **Cash invariants remain false after funding consumes cash without liquidating.** Finding 5. |
| **G14: float activation** | **Removed**, provided all float-dependent order fields—not merely `when`—are covered by X1’s hypotheses. |
| **G15: judged projection and confirmer** | P1 and the new instruments are progress. **Still patched:** theorem domains, stopping correctness and useful numerical precision remain uncovered. Findings 2, 7 and 15. The conceded encodings are not the only remaining choices. |
| **G16: protected dates** | **Removed for `start`/`feed`/`inspect`.** The fill-replay entry must remain internal or receive the same guard; see implementation notes. |
| **G17: metered disclosure** | **Removed at its cause:** attempt-before-run and result-before-publication are the right protocol. |
| **G18: historical recording** | **Patched by polling faster.** Faster snapshots still cannot reconstruct changes that occur and reverse between polls. Findings 12–13. |

### Argon’s findings

| R2 | Disposition |
|---|---|
| **A1: five denominator leaks; timing test** | Old denominator removed. Funding inclusion and settlement retention address specific leaks. **Benchmark/null interpretation remains broken** by Finding 1. Fable correctly rejects Argon’s paired statistic; its displayed counterexample suffices. |
| **A2: predictable stake; leverage floor** | Predictable stake is adopted correctly in principle, but Q1 is false for the present lifecycle. The floor objection is conceded; “therefore leverage cannot be exact” does not follow. Findings 3–6. |
| **A3: cross-event evidence** | **Removed for passive pessimistic fills**, conditional on authentic aggressor classification, unique matches and the stated non-impact assumptions. Pre-arrival prints are now explicitly excluded. |
| **A4: decimals** | String pre-rounding and float-observation rejection are removed. The scaled-integer range is now honest. Recovering arbitrary historical spelling from doubles is impossible, not an outstanding decimal theorem. |
| **A5: fidelity wall** | **Removed at its cause.** Order-level validation is narrower and better, but requires evidence of actual order residence. Finding 8. |
| **A6: bars and target weights** | Capability restored in principle; cumulative `filled + delta` repairs the positive-position example. **Bar equivalence is not yet true.** Finding 11. |
| **A7.1: causality/cycles** | Partially repaired; Findings 3, 9–10 remain. |
| **A7.2: moving notional wishes** | Agree with Fable: replacement is the specified consequence, not inherently a defect. |
| **A7.3–4: sparse sources and small gaps** | State/flow separation and the explicit first-tick, oracle, settlement-fee and `start` conventions repair these constructions. |
| **A7.5: missing laws/encodings** | Partially repaired; Findings 2, 7, 14–15 and the implementation notes remain. |

# Findings, in the requested attack order

## 1. Rung 2: an untimed buy-and-hold account can pass through rebalancing performed by the test

**Outcome:** a judged “timed” result with no timing decisions by the account.

**Claim:** alike days put untimed holdings inside rung 2’s null; intraday rebalancing contributes only the quoted negligible residual.

**Construction:** one coin, no funding, two steps per day. Each step independently multiplies price by either \(1/2\) or \(2\), equally likely. Days are IID, including their intraday paths.

The account buys one unit and **never trades again**. After entry, its step quantities are

\[
pnl=q(P'-P),\qquad a=qP.
\]

With registered \(\phi=1/2\), the confirmer therefore multiplies by \(3/4\) or \(3/2\) each step. Its expected daily log growth is

\[
g_V=\log(9/8)\approx0.11778.
\]

A daily constant mix with coin weight \(b\) encounters coin gross returns \(1/4,1,4\), with probabilities \(1/4,1/2,1/4\). Its optimal weight is \(b=1/2\), giving

\[
g_B=\tfrac14\log(5/8)+\tfrac14\log(5/2)
=\tfrac14\log(25/16)\approx0.11157.
\]

Thus \(V/B^\circ\) grows exponentially almost surely. It eventually crosses 20 with probability one, hence exceeds 5% at some finite horizon. Initial spread and fees contribute only a finite initial cost. Larger reciprocal swings make the effect much faster.

There is no forecast, no changing account exposure and no fill better than a mid. **The test manufactures the finer rebalancing.** The script’s \(1.7\cdot10^{-5}\) is one parameterized example, not a bound.

The literal ratio-supermartingale null need not hold in this construction. Therefore this is **not** a violation of Ville under that literal null. It disproves the asserted implication “days alike ⇒ untimed holdings are covered.”

**Smallest change, hypothesis:** either name the result “beats daily constant mixes,” expressly crediting grid-induced rebalancing without limiting its size, or establish a comparator/null on the same trading opportunities as \(V\).

This lands again on **a benchmark taken for a null**.

## 2. Funding can invalidate the best-mix certificate’s arithmetic domain

**Outcome:** a false “timed” certificate, or an unprovable K2.

**Claim:** every allowed constant mix is bounded by the proposed mix times the largest mean corner ratio raised to the day count.

**Construction:** keep a coin’s daily endpoint mid at 100. On each of two days, one unit pays 300 in funding. Its defined daily gross return is then \(-2\).

This is possible under A9’s admitted numbers: an oracle of 7,500 and rate 4% suffice. The benchmark definition has no solvency restriction.

Propose cash. Then \(f_d=1\), and the certificate’s largest mean corner ratio is

\[
\max(1,-2)=1.
\]

It certifies every mix’s wealth as at most 1. But the all-coin mix has the formally defined wealth

\[
(-2)(-2)=4.
\]

Consequently, a report with \(V=40\) can be certified “timed” although the required threshold is 80. AM–GM does not apply to the negative ratios.

Rejecting only proposals with nonpositive factors does not fix this: the proposed cash factors are positive.

There are additional domain holes: a universe coin without an initial mark has no first daily return; a zero starting mark makes division undefined; a later listing has no stated cash-to-coin entry convention.

**Smallest change, hypothesis:** define an admissible, nonnegative benchmark total-return process and its listing/zero-price conventions. K2 must require nonnegative factors for **every compared mix**, positive proposed factors, and a feasible normalized proposal. Changing the benchmark to a floored funded account would introduce a transfer that also needs accounting.

## 3. Q1 loses pending capacity when a cycle resets

**Outcome:** negative confirmer wealth with no funding and \(\phi=1\).

**Claim:** current position value plus current remainders of live/pending buys bounds every step’s trading loss.

**Construction:** at a step’s start:

- Two units are held, mid 100; hence position risk is 200.
- A buy slot has filled one unit this cycle.
- Its replacement, target one at 100, is still pending because \(\lambda\) exceeds a step. Its current remainder is zero.
- A live `close` sell rests at 40. A sufficiently wide quote permits this.

The
The `close` sell fills both units at 40 on a qualifying buy-aggressor print above 40. That realizes a loss of 120 against the starting mark and ends the cycle.

Resetting the slot’s `filled` from one to zero now gives the pending target **one fresh unit of remainder**. When it activates, it buys at 100; a subsequent fall almost to zero loses another 100.

The step loses approximately 220, before fees, against starting `at_risk = 200`. Its pending buy contributed zero at the start because its target was already filled.

This requires no simultaneous duplicate orders: **one pending target regains capacity through a cycle reset**. The pending replacement can originally have been wished before its predecessor’s final fill.

**Smallest change, hypothesis:** bind every order and pending action to a cycle generation; ending that generation invalidates its remaining actions. Alternatively, `at_risk` must cover every capacity increase that can occur before the next boundary—not just current remainders.

Also specify whether the step starts **before or after** its deciding tick creates new pending orders. Q1 fails under the former convention for a flat account opening its first position.

This lands again on **cumulative state mistaken for outstanding flow**, not merely an implementation detail.

## 4. V16 is not implied by a funding-rate cap

**Outcome:** an apparently nonnegative exact wealth becomes negative, or the judged run is retrospectively voided.

**Claim:** a registered rate bound supplies the funding component of the step’s predictable loss bound.

**Construction:** start with one unit marked at 100, so `at_risk = 100`. Let the registered \(\bar\rho=0.04\). During the step:

1. Funding settles at oracle 10,000 and rate 4%: payment 400.
2. The position subsequently becomes worthless.

The loss before absorption can approach 500, not 104. Multiple settlements in a long step and newly filled positions create additional discrepancies.

V16 explicitly assumes something stronger than a rate cap, so this is not a contradiction *under V16*. But checking the realized payment does not establish a predictable, universally covered bet.

The void rule also needs a stopping convention. A monthly replay can discover a violating step **after an earlier day crossed “timed.”** Does that rescind the stopped result, or was the test already stopped?

**Smallest change, hypothesis:** supply a bound on total dollar funding, conditional on starting information, including oracle basis, settlement count and pending fills. Otherwise define failure as an adapted termination with no confirmation thereafter, and state the mathematical null for that stopped process. Do not describe a retrospective payment check as certification of the venue-cap derivation.

## 5. Funding consumes reserved cash without necessarily liquidating

**Outcome:** violated cash laws, unintended leverage and potentially subsidized judged profits.

**Claim:** leverage-1 admission ensures cash remains nonnegative after every fill.

**Construction:** hold a long position and have cash 101. A live buy reserves approximately 100 including fees. Funding then debits 2:

- Cash becomes 99.
- Total equity remains comfortably above maintenance, so A10 does not liquidate.
- The previously admitted buy fills for approximately 100.
- Cash becomes negative.

Admission reserved its fee, but **did not reserve subsequent funding**. No rule cancels or revalidates live buys when funding consumes their reservation.

Even without that buy, funding can make cash negative while equity remains positive. A later price decline can then liquidate the account. Thus the unconditional cash clause in L6 and build step 7’s property are false.

**Smallest change, hypothesis:** define funding-aware collateral reservation and what happens to outstanding opening orders after collateral changes. If negative cash is allowed, withdraw the cash theorem and prevent a judged account from treating subsequent absorption as price-earned profit.

This is a surviving part of **G13**, not settled by adding the taker fee.

## 6. Section 6.2’s stopped-account bound is sound conditionally; its leverage prohibition is not

**Outcome:** changes permitted experiments and the claimed power wall.

**Claim:** “leverage cannot be exact against a null about prices.”

**Construction:** a physical account has equity \(E\), long notional \(2E\), zero funding and a fair price moving by \(+90\%\) or \(-90\%\). Its **unabsorbed** profit is \(+1.8E\) or \(-1.8E\).

Use

\[
V'=V\left(1+\frac{pnl-\Delta absorbed}{2E}\right).
\]

Its factors are 1.9 and 0.1: nonnegative and conditionally mean one. If the physical account goes bankrupt, stop betting and retain the remaining test wealth. This is an exact test on a physically leveraged account, without treating its bankruptcy gift as profit.

It does not provide test exposure above full investment. That narrower conclusion is valid; the categorical prohibition is not.

The displayed bound

\[
P(\text{reach }20)\le(1+E[A])/20
\]

is valid for the specified **stopped unfloored account**, assuming its supermartingale premise and suitable integrability. It is not automatically the bound for the dynamically normalized \(V\): there, absorbed dollars receive different predictable betting multipliers.

**Smallest change, hypothesis:** distinguish physical leverage, test leverage and transfers. Keep the proposed unleveraged study if desired, but replace “cannot be exact” with “does not increase the admissible normalized exposure under this loss bound.”

This lands again on **the account taken for the test**.

## 7. The print rule’s causal repair is real, but its ★ laws still exclude legitimate fills

**Outcome:** an impossible proof gate, or a silently weakened sell implementation.

**Claim:** E1 characterizes every pessimistic maker fill.

**Construction:** a resting sell at 100 fills on a buy-aggressor print at 101. A7 explicitly mirrors buys, so this is required. E1 nevertheless requires **every** maker fill to be an order strictly above a sell-aggressor print.

That theorem excludes all such sell fills.

Further scope conflicts:

- F0 says “No other fill exists,” but liquidation and listing settlement create fills outside A7.
- F0’s raw `min(remainder, allotted lots)` needs the reduce-only restriction when `remainder` exceeds the remaining position.
- L4’s taker-at-recorded-level requirement needs explicit exceptions for settlement and liquidation’s synthetic tail beyond recorded depth.

**Smallest change, hypothesis:** state separate buy/sell clauses and quantify order-execution laws over order executions, with explicit forced-close characterizations. These are theorem-statement corrections, not tolerances.

I found no additional seller invented by **unique, authentic sell-aggressor prints** under A7’s explicit counterfactual assumptions. A wrong aggressor flag can fabricate one, but then source authenticity—not print allocation—is the failed premise.

## 8. Layer 2 does not know when the real order actually stood

**Outcome:** a sound fill rule fails the fidelity wall, or an unexplained discrepancy is incorrectly blamed on execution.

**Claim:** the real order stood at the same price and ahead; therefore pessimistic cannot fill first.

**Construction:** the published constants imply a bid at 100 throughout a cycle. The vault actually:

1. Cancels that order.
2. Observes a sell-aggressor print at 99 during its absence.
3. Reposts at 100 and fills later—or never reposts.

The replica correctly fills on the print. Layer 2 records an early or unmatched fill even though A7 is sound.

A historical maker fill supplies a price and an eventual execution, **not its placement time, continuous residence or full original quantity**. Implied unfilled levels provide still less evidence. Hidden liquidity and venue-specific matching exceptions likewise require an explicit matching-priority premise.

**Smallest change, hypothesis:** require order placement/cancellation history for the one-sided theorem, or label residence as an assumption and classify such comparisons as unidentified. An explanation list is valuable, but it cannot turn absent order history into a testable continuous-presence premise.

Deleting the aggregate wall removed its original cause. This is a new limitation of the replacement, not a reason to restore that wall.

## 9. L1a is provable only if staleness belongs to the delayed view too

**Outcome:** protected future information changes wishes before delivery, or the ★ theorem is false.

**Claim:** the stated equal prefixes imply equal views and wishes.

**Construction:** the latest delivered quote is old enough to be stale at tick \(\tau\).

- In market A, a fresh quote arrives in \((\tau-\delta,\tau]\), but is not yet known.
- In market B, it does not.
- Both markets satisfy L1a’s equality conditions.

World staleness differs. If “while a coin is stale its price inputs are undefined” reads the **world’s** freshness flag, the program gets a defined old price in A and an undefined one in B. It learns that an unseen quote arrived.

**Smallest change, hypothesis:** give the view its own freshness calculation from delivered timestamps; specify the exact undefined-time convention. World freshness governs fills; view freshness governs inputs.

With that correction, identical headers and a complete deterministic effect-delivery protocol, I see no inherent obstruction to L1a. Recent hidden events cannot influence already-delivered effects. The present text simply does not enforce that separation consistently.

## 10. Targets still need pending-action and order-status semantics

**Outcome:** duplicate pending actions, stranded orders or different judged exits across conforming implementations.

**Claim:** reconciliation is idempotent and own-state inputs are reconstructible from delayed effects.

**Construction:** a slot has no live order and wishes target 10 at successive deciding ticks while \(\lambda\) exceeds a step. Comparing each wish only with the **live** order schedules another placement each time. The text never specifies whether these replace, coalesce or coexist.

Likewise, a target-10 order partially fills, then an IOC remainder expires or an ALO order is accepted without filling. The listed effects do not explicitly include successful activation and arrival/resting status. A view cannot reconstruct `resting` and `resting_price` solely from fills, refusals and cancellations.

`close` also needs an empty-order convention: when flat, is it retained as a dormant target that grows with a later position, or removed? Those choices produce different exits.

**Smallest change, hypothesis:** define one desired/pending/live lifecycle per slot, generation-tagged acknowledgments, supersession and cancellation ordering, and the complete delayed status effects. R1 should characterize that lifecycle, not merely compare wishes with live orders.

## 11. A16 is not equivalent to its claimed classical bar readings

**Outcome:** bar-market fills and strategy information differ from the promised tests.

**Claim:** optimistic resting buys fill exactly when the bar low touches; IOC buys fill at the next open; the four assumptions suffice.

**Constructions:**

- **Quote-triggered optimistic fill:** open 100, half-spread 1%, low 100. A buy rests at 99.5. At a later derived quote, `bid = 99 ≤ 99.5`, so A7’s optimistic quote condition fills it although the bar low never touched 99.5.
- **Staleness:** choose \(G<\Delta/3\). The only quote is at the open; the synthetic extreme prints occur while stale. A7 forbids their fills, contradicting step 8’s unconditional bar tests.
- **IOC limit:** an IOC buy capped at 98 cannot fill a next-open ask of 101. With a long \(\lambda\), its arrival need not even be the next bar.
- **Finite shared depth:** B2 covers an order cap, but several qualifying capped orders share one print. They cannot all receive their classical full-bar fills.
- **Information:** an extreme’s synthetic fill is delivered at its synthetic event time plus \(\delta\), before the bar closes, although the print itself is withheld until close. The program can infer a threshold crossing early through its position.

The last point is legitimate only if B3 deliberately grants early account feedback from an assumed latent path. It is not equivalent to “the program learns nothing about unfinished extremes.”

**Smallest change, hypothesis:** define bars as exactly the derived-event model and withdraw the unconditional classical equivalence. Alternatively, revise the derivation and register its freshness, capacity and feedback conventions explicitly. B1–B4 currently do not settle those interactions.

## 12. Hourly rule copies do not make missed changes detectable

**Outcome:** lost historical rules change judged admission, fees or liquidation.

**Claim:** an intrahour grid/lot change produces an off-grid record; vault fees witness the fee schedule.

**Construction:** the lot step changes from 0.01 to 0.001 and back between polls. Every observed trade happens to remain a multiple of 0.01. Admission detects nothing, while a replica order of 0.015 would have different admissibility during the change.

Similarly, a fee changes while the vault has no fills, then changes back. The vault’s fee witnesses all agree with the hourly copies; replica fills during the interval are still mispriced.

**Smallest change, hypothesis:** obtain effective-dated history, or explicitly assume no relevant undetected intrapoll changes. Faster polling reduces exposure; it does not prove detection.

This is **G18’s original cause**, still patched rather than removed.

## 13. Overlap is necessary, not a completeness proof for fill pulls

**Outcome:** lost vault recordings corrupt prospective fidelity.

**Claim:** containing the previous pull’s last fill proves that a pull lost nothing.

**Construction:** more than one response page of fills occurs during an interval. A response contains the previous last fill and the next page’s worth, but not all later fills. The overlap check passes.

The specification gives no pagination loop, complete-through watermark or rule for a response reaching its item cap. Missing a complete round trip can also leave subsequent `startPosition` chains consistent: the position returns to its previous value.

**Smallest change, hypothesis:** specify pagination through an explicit interval endpoint, inclusive-boundary deduplication, saturation detection and an advancing complete-through watermark. Overlap checks continuity at one boundary, not completeness of the interval.

## 14. Global trade-ID deduplication conflicts with the stated memory wall

**Outcome:** either missing/duplicate prints change judged fills, or the two-year replay cannot meet its resource contract.

**Claim:** C2 rejects any repeated trade ID across the run; streaming state remains within 2 GB.

**Construction:** feed more distinct arbitrary trade IDs than bounded memory can distinguish, then repeat an old ID. Exact global duplicate detection must retain enough information to distinguish that history from one where the ID is new.

The design states neither monotone IDs nor a bounded duplicate horizon. The first performance wall feeds **quotes only**, so it does not exercise this growing state. `finish` also retains a potentially enormous trace, without a trace-size contract.

**Smallest change, hypothesis:** establish and check an ordered-ID property, use an explicitly external exact deduplication structure, or bound the accepted trade history. State whether traces are bounded, streamed through a publication-safe spool, or excluded from the 2 GB promise.

The memory issue is not a demand for optimization; the missing input restriction determines whether the promised machine exists.

## 15. The confirmer’s proof gate still admits an engine that never confirms

**Outcome:** a genuine threshold crossing fails to produce a judged result while every listed ★ confirmer law holds.

**Claim:** K1/K2 and the build tests characterize the running confirmer.

**Construction:** return lower bound zero at every step and never report either rung.

- Zero is at most exact nonnegative \(V\): K1 holds.
- “If timed, then …”: K2 holds vacuously.
- “Timed implies earned”: holds.
- Bad proposals never confirm more: holds.
- The null simulation passes.
- All round-2 constructions return “not timed,” as requested.

No test requires confirmation on a constructed positive path. Nor is there a stated accuracy bound preventing downward rounding from destroying power on a fine clock.

**Smallest change, hypothesis:** characterize the wealth recurrence and stopping rule in both directions, with a registered rounding-error bound and explicit positive crossing fixtures. A conservative lower bound establishes safety, not faithful implementation or useful power.

This is **G15/A7.5’s original specification-coverage cause**.

## Remaining implementation decisions

These are additional blockers where the choice changes a judged result or a protected-data boundary, not requests for stylistic detail:

- **Equal timestamps across chunks:** `feed` needs a watermark convention before firing a tick or completing an event timestamp. C1 must cover a chunk ending halfway through that timestamp.
- **Listing changes:** specify treatment of existing off-grid orders, lot changes and a maintenance-tier change without another quote. A rule change can require liquidation without moving cash or a mark.
- **Marks:** specify whether an adverse print persists until the next quote, next print or only that event’s check.
- **Layer-1 printed digits:** exact rationals need an explicit venue comparison-rounding rule. “To its printed digits” is not one.
- **Funding lateness:** identify the settlement hour independently of its possibly late event timestamp, and define horizon-edge obligations.
- **Fill-replay entry:** if publicly accessible, it must enforce protected-date admission and metered publication too. Otherwise G16 has another route.
- **Proof checking:** rejecting `sorryAx` alone does not reject a newly declared axiom that supplies a theorem. Preserve an explicit allowed-axiom audit.
- **Bar time encoding:** \(\Delta/3\) need not be an integer millisecond; ordering and rounding must be specified.

The admitted grammar/chunk/event work can resolve these, but cannot be treated as encoding-only if it chooses these semantics.

# The three human choices: what each run looks like

| Choice | Run under each option |
|---|---|
| **Reading of “timed”** | **Daily-comparator reading:** run the current comparison after fixing its domain; report “beats daily constant mixes,” including finer-rebalancing gains. **Knowledge-of-when reading:** do not register that interpretation until the null covers the same intraday opportunities and relevant risk adaptation. A stronger scientific interpretation cannot be selected merely by renaming the output. |
| **V10 replenishment** | **Accept:** replay taker snapshots without persistent depletion; label results conditional on non-impact/replenishment. **Reject:** use a specified counterfactual depletion/replenishment model, or restrict the experiment so unsupported repeated taker consumption is absent. Keep recording either way. |
| **Two-year disk** | **Buy sufficient storage:** preserve the broad-universe recording, with capacity monitoring and a recovery/copy policy. **Restrict to 17 coins:** retain study 2, lose the broader future holdout from the switch onward. **Neither:** recordings eventually stop or are lost; end or shorten the forward measurement explicitly rather than silently continuing on gaps. |

V10’s truth is empirical. The human can choose **whether to condition the academic claim on it**, not make it true.

# Convergence ledger

### Agreed

- Exact rational accounting and the two-sort language remove the original numerical causes.
- Prints, rather than recurring snapshots, are the right evidence for the stated passive-fill rule.
- World/view separation, protected-date admission and commit-before-publication are correct foundations.
- Whole-run fill-return bounds and historical aggregate non-flattery guarantees should remain withdrawn.
- The best-mix certificate is sound **on its positive-factor domain**.
- The stopped unfloored-account absorption bound is sound under its stated supermartingale and integrability premises.
- Preserve forward recordings; prospective fidelity remains worthwhile without confirmation.

### Open disputes that change the build or run

1. Rung 2’s interpretation and trading-grid mismatch.
2. Benchmark solvency and certificate domain.
3. Pending orders across cycle resets and deciding-boundary risk.
4. Predictable funding coverage and collateral reservation.
5. Delayed freshness, status effects and pending reconciliation.
6. Bar-source equivalence and information conventions.
7. Recording completeness, bounded-memory deduplication and confirmer characterization.

The categorical leverage prohibition should also be withdrawn, though retaining an unleveraged study need not change its immediate implementation.

### Human-only choices

The scientific interpretation worth pursuing, acceptance of V10 as a conditional modeling assumption, and the storage commitment. None settles the false laws or missing mathematical hypotheses.

**Convergence test: failed.** The open issues change accepted reports, orders, threshold crossings, required recordings or implementation state. Another round is necessary after those causes—not just their examples—are resolved.
