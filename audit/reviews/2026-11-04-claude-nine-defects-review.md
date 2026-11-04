<!-- Claude (claude-opus-5-5), fresh session, review of branch claude/nine-defects-spec-qhpaks at 870c407 (the nine-defect spec revision of reference/SEMANTICS.md, kernel/INVARIANTS.md, gate/NULLS.md); finished 2026-11-04 05:01 UTC (00:01 EST), its commit time (the session wrote 05:10, a time not yet reached). Static reading. I traced each strict xfail by hand against the revised text and ran nothing. -->
# Review of the nine-defect spec revision

**Verdict.** Seven of the nine revisions remove their defect's cause, and against a faithful implementation all nine
tests would pass. Two do not fully remove the cause. **K1** passes its test, but the lookahead is still there, one bar
shorter. **M4** blocks `REPLACE` but claims more than triggers can enforce. The −2 bound's argument is sound in
substance and does hold for the revised generators, but one step of its proof is false as written. The revision also
conflicts with two frozen criteria (C7.4 and C8's "the pilot reproduces"), and the branch does not record that
conflict. Findings are ranked; each names the outcome it could change.

## Per defect

I traced each test's market through the revised §7 and §10.

| | Cause killed? | Test passes against a faithful implementation? |
|---|---|---|
| K1 | **No.** The lookahead is now one bar instead of two (finding 1). | Yes, because the test compares only the 08:02 decision. |
| K2 | Yes for liquidation. A related path opens through delisting (finding 1b). | Yes. The step at 12h liquidates at 290 (maintenance is now 3,625, not 725, but it liquidates either way), the due close is unfilled, and equity stays at 500. |
| K3 | Yes. Holds take H = 2, so β = 0, and S1's scaled weight becomes 0 with qty 0. | Yes. Gross stays at 20,000 and equity at 24h is 9,000. |
| K4 | Yes. | Yes. e_d = 9,979.99, so qty = trunc(−0.2001) = −0.200, a $20 order. |
| K5 | Yes. | Yes. The window account starts at 0 because s's equity is 0, so total_return is −1. |
| K6 | Yes. | Yes. The fill at 24h comes after Equity(24h), so it is in the window. Fees are 10, slippage 10, turnover 10,000, and there are 2 fills. |
| M1 | Yes, if "fill instant" means every step's fill time (finding 5c). | Yes. Each coin's single exposure nets −4.000/10,000. |
| M2 | Yes. | Yes, if exposures are per bar (finding 5c). |
| M4 | Partly (finding 4). | Yes, if the trigger is a `BEFORE INSERT` check raising `append-only`. |

## Findings

### 1. K1's lookahead survives, one bar shorter. Outcome: real-data returns and non-interference.

§7 says end(c) is "the venue's delisting time … an observation known at end(c)". Nothing in the spec says where that
value comes from:
- §3 lists the observation records, and none of them is a listing record.
- rules.json carries only the boolean `delisted`.
- The revision removed the old pointer to how intervals are loaded ("as loaded [market.rs]").

An implementer has only one source: the loader's rule, end = the eventTime of the coin's last traded bar
(`market.rs:420–427`). Under that rule, eligibility (start ≤ B < end) and the delisting closeout (b + BAR ≥ end) at
B = end still read the trades of bar [B, B + BAR), which become known at B + BAR + δ.

The test's own market shows it:
- The two histories are identical through 12:02.
- In the early history, S0 is closed at 12h, and at 12:02 S1 alone receives weight 2 and buys 100.
- In the late history, both coins keep weight 1, and S1 places no order.

So the same assertion fails if moved from 08:02 to 12:02. INVARIANTS I1's new sentence ("a coin's listing end enters a
run only from that end on") is therefore not true of any implementation that can be built today. Lean's L1 revision
(decision of 2026-11-04 00:03) has no record to quantify over.

The cause dies only when the spec names a recorded delisting observation with its own knownAt in §3. One candidate is
the fetchedAt of the first venue-rules revision that marks the coin delisted. The closeout then happens at the first
step at or after that time, at the last mark. This needs data the store may not hold, so it belongs under Blockers and
should not be patched with a rule that infers it from trading.

**1b. Delisting can reopen a position.** The old eligibility rule (B + 2·BAR ≤ end) kept every fill strictly before
end(c). The new rule allows an order decided at B < end ≤ B + BAR. At that step, step 4 closes the coin, and step 7 can
still fill the due order if a traded bar opens at B + BAR. A zero-weight close would then open a position on a delisted
coin, the same defect as K2. Under the loader's rule that bar never trades, so the case is hidden only by accident.
Rule for step 7: an order whose coin is not listed at its fill time is unfilled. This is the same reason as K2 (the
book it was sized on no longer exists), so it belongs in that clause, not in a new one.

### 2. The corrected semantics contradicts two frozen criteria. Outcome: whether stage 7 and stage 8 can exit.

C7.4 (`audit/criteria.md`, "Baseline") requires that, after migration, "decisions, fills, accounting traces and
returns" are byte-identical to the frozen kernel's output on W0, the stage 2 probes and 200 programs from C6.4's
corpus. C8's reproduction clause requires that the pilot "reproduce bit for bit on the generalized kernel". The
decision of 00:03 says the stage 7 port implements the corrected spec.

Those cannot all hold:
- K4 alone changes the order quantities of almost every run that pays costs.
- K3 and Λ change any run with holds or high leverage.

The way out that looks cheapest, a port carrying both semantics behind a switch, is the parallel path CLAUDE.md §1
rejects. The criteria need dated revisions before the port proceeds, for example: byte identity except the
differences enumerated per defect, each one explained by its rule. Turning byte identity into identity up to
explained differences arguably loosens a frozen requirement, so I would put it to the human. The branch records
neither the conflict nor this question.

### 3. The bound's proof has a false step; its conclusion survives. Outcome: a trace check an implementer would write, and the proof's validity.

Step 7 fills an order that "lowers that gross" even when the book then exceeds Λ times its equity. A flip lowers gross
by a little while trading almost twice the coin's notional. For example, going from +10 coins to −9.99 lowers gross by
0.01 coin but trades 19.99. The proof's sentence "a reducing fill lowers gross by far more than its cost lowers equity"
is false for such a fill.

The ratio after fills can then reach Λ/(1 − 2Λκ), about 4.1 at κ = 0.003. So:
- INVARIANTS I9's "So the book leaving each step's fills has gross at most 4 times its equity" is not an invariant.
- A trace check written from I9 would abort legal runs.

NULLS' numbers still hold: −4.1 · (0.006 + 0.453) is about −1.88, which is above −2.

Fix: make the exception "or reduces |q[c]| without changing its sign". A flip is then judged like any other fill, and
the proof's sentence becomes true.

The rest of the argument checks out:
- **Step 3 leaves the book within Λ.** It leaves either nothing or a book with gross ≤ Λ · equity at the adverse
  prices. Moving those prices to the marks moves in the positions' favour, so the ratio stays ≤ max(Λ, 1).
- **Traded notional.** Fills at a step trade at most G₀ + G₁ ≤ 2Λ · e_prev.
- **Carrying.** Carrying the book through the next bar loses at most m · G₁.
- **e_prev.** e_prev is e1, the equity before that step's fills, so the fill costs fall in the next step's r′ as the
  proof assumes.

I also checked m < 0.46 case by case:
- **Stated split.** The text splits m into a loss to the close of at most |ε| plus a wick of at most 0.1 · max(o, c)/o.
  That split does not hold term by term when the bar moves in the position's favour. For a long with c > o, the
  distance from close to low is c − o + o|u|.
- **The total still holds.** The favourable move offsets the extra distance. The worst cases are about 0.28 for a long
  and 0.26 for a short, against the bound 0.3 + 0.148 + 1.63κ.
- **Costs.** κ: the median cell is about 4.5 bps plus the 4.5 bps fee, about 0.0009, so under 0.003 as claimed. That
  claim is a fact about today's cells. NULLS should state it as a precondition that market construction checks.

The PROGRESS blocker's proposal to report each real holdout's largest m is a diagnostic only. An observed maximum
does not establish the almost-sure bound (GPT, `2026-11-04-gpt-bound-check.md` §1).

### 4. M4 claims more than it enforces. Outcome: a promotion from a replaced row (low likelihood).

"No committed row is ever changed or removed, whatever the connection or its settings" is false for a writable
connection that runs `DROP TRIGGER` or uses `writable_schema`. GPT's finding located the outcome-changing step in
`committed_holdout` trusting a row without verifying its `result_hash`. A gate check of the hash, recomputed from the
returns and summary, removes that step for every write path, not only `REPLACE`.

Recommendations:
- Scope I6's claim to statements that do not alter the schema.
- Record the gate check as the cause-level fix.

For the strategies table, a repeated `INSERT OR REPLACE` falls under both of I6's clauses: "abort" and "ignored". Both
keep the row, so no outcome depends on which; one wording should go.

### 5. Gaps an independent implementer would hit. Outcome: divergent implementations, so differential failures.

a. **Undefined names.**
   - start(c), the run's end in "while b + 2·BAR ≤ end" and "b + 3·BAR ≤ end", and §4's interval_start and
     interval_end lost their definitions when the "[start, end) per coin as loaded" sentence went.
   - The loader also cut non-delisted intervals at the search or holdout end. The new "∞ if none" drops that cut
     without saying the run's end replaces it.
b. **e_d ≤ 0.** H = Σ|q| · mark / e_d is 0/0 after a bankruptcy if it is computed as a ratio of totals. A NaN gross then
   aborts with R_PORTFOLIO on every post-bankruptcy step, including K5's test. Rule: if e_d ≤ 0, no orders, as I10
   already says.
c. **Exposure boundaries.**
   - §10 says an exposure "is one bar" but also that it "ends at the next fill instant". Read as the next actual fill,
     exposures span several bars, and M2's count (one per held bar) fails.
   - Clearer: it ends at the bar's end, after that instant's fills if they leave the coin flat, else before them.
     "Labelled by the decision whose fills opened the bar" reads as needing a fill; the label comes from the decision
     due at the bar's open, filled or not.
   - Say where an exposure still open at the run's last step ends.
d. **Summary fields.** §10 names fills, fees, slippage and turnover but defines none of them. In K6's market,
   Σ|qty| · price and Σ|qty| · reference both give 10,000, so the test cannot tell the two readings apart.

### 6. Λ = 4 is new behaviour that no defect required; it is the right shape. Outcome: liquidations and returns of highly levered runs.

The bound needs some exposure limit:
- K3 fixed, holds still drift without limit while β = 0. They are bounded only by the venue's maintenance, about
  20× at leverage 10.
- Orders sized on equity from before a bar's loss can still exceed 4× when they fill.

Reusing step 3's liquidation for the stock limit and the venue's order-time margin check for fills adds no new
mechanism. That is the simplest design I can derive. Liquidation at the adverse extreme keeps the no-edge argument,
since it is never better than the close.

Two notes:
- **Thresholds.** Every coin with maxLeverage above 2 now liquidates at a quarter of gross, not 1/(2L). A 2× book is
  stopped out at an adverse move of 1/3 instead of about 0.47.
- **Naming.** This is the account's own stop-out, not the venue's rule. Trace records and DSL text should not present
  it as venue liquidation.

The branch rightly lists Λ under Blockers. It needs the reviewed decision CLAUDE.md requires, because it can change a
judged result on the corrected engine.

### 7. DSL.md will mislead agents on the corrected engine. Outcome: agents' strategy design in a future campaign.

Leaving DSL.md hash-frozen is right for the pilot. But agents on the corrected engine would read old rules: no budget
taken by holds, eligibility two bars ahead, no stop-out at 4×. Its revision belongs with the harness fork that first
runs agents on the corrected engine. A Blockers or Next line should say so, so that it is not forgotten.

## Answers to the brief

- **Does each revision remove its cause?** Seven do. K1 does not (finding 1), and M4 only partly (finding 4).
- **Is the −2 bound by construction?** Yes for the exposure, under the revised generators, once the flip exception is
  narrowed (finding 3). Real markets meet it only where m ≤ 1/2 − 2κ, as the spec says.
- **Anything new ambiguous, contradictory or a special case?**
  - Ambiguous: finding 5.
  - Contradictory: finding 2 (criteria) and finding 4's two clauses for the strategies table.
  - Special cases: none. The K2 and Λ rules each reuse an existing mechanism.
  - Behaviour no defect required: Λ and the maintenance floor, needed by the bound (finding 6).
- **Can an independent implementer build it from the spec alone?** Not yet. end(c) has no source (finding 1), and
  findings 5a to 5c leave choices that change outputs. With those fixed, yes.
