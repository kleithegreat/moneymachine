<!-- Claude, fresh session, second review of branch claude/nine-defects-spec-qhpaks at bc3700b (diffed against main 2391ea9: reference/SEMANTICS.md, kernel/INVARIANTS.md, gate/NULLS.md, docs/whitepaper.tex). Finished 2026-11-04 05:34 UTC (00:34 EST), its commit time (the session wrote 05:40, a time not yet reached). Static reading. I traced each strict xfail by hand against the revised text. I did not run the suite. I ran two scratch SQLite statements to check finding 4. -->
# Second review of the nine-defect spec revision

**Verdict.** bc3700b answers most of what the two reviews of 870c407 found, with rules that remove causes. The flip
exception is narrowed to reductions that keep the sign. The real-market extension is withdrawn. Exposures are defined
per bar, with labels, the horizon and N = 0 all specified. Undefined names, e_d ≤ 0 and the summary fields are
settled. The criteria conflict went to the human. The −2 proof in §7 is now sound, step by step, for gapless markets
with m ≤ 1/2 − 2κ, and NULLS' arithmetic gives that for the revised generators.

Two problems remain that can change outcomes:
- **K1** (finding 1). The fix names an input that no store holds and that no rule says how to build. The spec and
  PROGRESS disagree about what a real market with a delisted coin becomes. K1's test fails as written. With any
  fixture, it also passes against the residual one-bar lookahead.
- **The bound's statement** (finding 2). The paper and SEMANTICS' preamble say the −2 bound is proven on every gapless
  market. It is not: a gapless market with large bars breaks it. The paper also lists it among the Lean theorems.

Findings are ranked. Each names the outcome it could change.

## The earlier findings

| Finding (870c407) | Resolved by bc3700b? |
|---|---|
| GPT 1, Claude 3: a flip passes as a reducing fill and breaks I9 | **Yes.** A fill is admitted if it reduces \|q\| without changing sign, or if it leaves gross ≤ Λ · equity at the marks. A reversal is judged like any other fill. GPT's example (−20 → +19.99) is refused: 2,398.8 > 4 · 590.4. |
| GPT 1: the gap extension is false | **Yes, by withdrawal.** On real markets the bound is now an assumption, with a diagnostic only. |
| GPT 2, Claude 5c: exposure boundaries and labels | **Yes** (traced under M1 and M2 below). A reversal goes whole to the exposure it opens, closing costs included. That rule is unambiguous, and it is a choice (note e). |
| GPT 3, Claude 1: K1's listing end has no source | **No** (finding 1). A record type is named, but nothing defines its source, and the Blocker contradicts the spec. |
| Claude 1b: a delisting can reopen a position | **Yes.** A due order on a coin not listed at b + BAR is unfilled, under the same rule as K2. |
| GPT 4, Claude 6: Λ and the clips are policy | **Yes** for the decision (2026-11-04 05:05). Half of GPT's point is not addressed: nothing says C2's calibration and planted β do not carry over to the corrected engine's generators (note g). |
| Claude 2: conflict with C7.4 and C8 | **Yes.** The human decided at 05:05: byte identity first, then the fixes. A dated revision under C8 records it. |
| Claude 4: M4 overclaims | **Yes in scope.** I6 is limited to statements that leave the schema intact, and the gate checks `result_hash`. Both remaining clauses are implementable, though not obviously (finding 4). |
| Claude 5a, 5b, 5d | **Yes.** E, start(c) and end(c) are defined. e_d ≤ 0 places no orders. fills, fees, slippage and turnover are defined. |
| Claude 7: DSL.md | **Yes.** Blocker (3). |

## The nine tests against a faithful implementation

| | Passes? | Trace |
|---|---|---|
| K1 | **No, as written** (finding 1) | The test's venue marks S0 delisted and supplies no delisting record. Under §3 the market is inadmissible, so the run exits nonzero at `assert r.returncode == 0`. |
| K2 | Yes | At 16h, equity at adverse is 15,000 − 50 · 290 = 500, below maintenance of 14,500/4 = 3,625. The account is stopped out at 290. Step 3 closed the account, so the due close is unfilled. Equity is 500. |
| K3 | Yes | The order cap makes S0 two fills of 100. At 12h+δ, H = 20,000/10,000 = 2, so β = 0. S1's scaled weight is 0 with held 0, so there is no order. At 24h, maintenance is 4,750 against 9,000, so no stop-out. Equity is 9,000. |
| K4 | Yes | e_d = 9,979.99 gives qty = trunc(−0.2001) = −0.200. Admission: 10,000 ≤ 4 · 9,979.99. |
| K5 | Yes | At 16h, equity at adverse is −5,000, so the account is stopped out at 400. Step 5 absorbs, and equity at s is 0. The window starts at 0 and e_d ≤ 0, so there are no orders. total_return is −1. |
| K6 | Yes | The fill at 24h comes after Equity(24h), so it is in the window. Fees are 10, slippage Σ qty · (price − reference) = 10, turnover Σ \|qty\| · price = 10,000, and there are 2 fills. returns[0] = −0.0010005. |
| M1 | Yes | For each coin, exposure (c, 8h) is labelled by the decision at 4h+δ. It takes the entry fill and, since 12h's fill leaves c flat, the closing fill too. Its return is −4.000/10,000 over Equity(8h) = 10,000. (c, 12h) does not exist. |
| M2 | Yes | Exposures run T = 8h … 408h per coin, 202 in all, matching `held`. T = 8h is labelled true/false from 4h+δ, and the 200 others are Undef. n_t/N = 1/202 < 0.1, so it fails. 0.1 · e_d/100 − 10 stays under the $10 minimum, so there are only 2 fills. |
| M4 | Yes | A `BEFORE INSERT` raise on a present key aborts `INSERT OR REPLACE` with recursive triggers off. See finding 4 for the companion test. |

## Findings

### 1. High — K1's delisting record has no defined source, and the spec and PROGRESS disagree about real markets. Outcomes: whether any real-data run is admissible on the corrected engine; real-data returns of strategies that hold FTM at its 2025-01 delisting; whether stage 7 can detect a surviving K1 lookahead.

§3 defines a delisting as (coin, knownAt), with knownAt "the fetchedAt of the first venue-rules revision marking the
coin delisted". The venue rules are not revisioned:
- `ingest/rules.py` writes one snapshot, `"fetched": today`, a date.
- The store's revision machinery does not cover `rules.json`; it is hashed whole under I7.
- No "venue-rules revision" exists for an implementer to take a fetchedAt from.

That leaves two readings, and they disagree.
- **Spec, read literally.** The only snapshot (2026-10) is a revision that marks FTM delisted. The market is then
  admissible, and end(FTM) = min(E, snapshot date) = E. FTM stays listed through all of W. A position held at its real
  halt is never closed, at a mark frozen at the last close. As a `stale` hold it consumes H, the gross budget, for the
  rest of W. The rule is causal but false to the market: the venue settled those positions in 2025-01. The same holds
  for any coin delisted before rules were recorded live.
- **PROGRESS Blocker (2).** "Until then a market with a delisted coin is inadmissible." U contains FTM, so this means
  every real-data market on the corrected engine is inadmissible. If that is the intent, the Blocker should say it in
  those words. The spec should also say it, and name the abort code, which neither does.

Neither reading is a defect of causality, so the cause GPT and Claude named is killed in the abstract. The trouble is
the input contract chosen to kill it. The store already treats backfilled bars as known at eventTime + δ, computed
from their observed fields. The loader's defect was inferring the end from the absence of later trades, not
backfilling.

Recommended rule:
- A delisting record is an observation with an observed eventTime: the venue's stated halt or settlement time, and its
  settlement price if the venue states one. Its knownAt follows the policy's rule, eventTime + δ, like any other row.
- The record needs a source certificate. Whether the venue publishes such a time is a sources question, so it belongs
  under Blockers.
- Until such a source exists, a market whose rules mark a coin delisted is inadmissible, stated in §3 with its abort
  code.

That rule kills the cause without the stale-listing economics, and it agrees with the Blocker.

**The test.**
- As written, it fails on any faithful implementation, because its fixture has no record. The Blocker says the fixture
  "needs one" and leaves its knownAt open.
- Its only discriminating assertion is at 08:02. An implementation that keeps the loader's trade-inferred end
  (end = 12h in the early history) together with the new "listed at B" eligibility also passes. S0 is listed at
  B = 8h because 8h < 12h.
- The surviving lookahead shows at 12:02. In the early history, S0 is unlisted there and S1 alone gets weight 2. In
  the late history, both keep weight 1. The stores are identical through 12:02.
- When the fixture is amended, put the same delisting record in both histories, known after 12:02. Assert identical
  decisions at 12:02 as well as 08:02, and keep the oracle unchanged. Otherwise stage 7 can land K1 with its defect
  intact.

### 2. Medium — The paper and SEMANTICS' preamble claim the bound on every gapless market, and the paper lists it as a Lean theorem. Outcomes: whether raw holdout p-values are treated as valid on a future gapless generator, or on any market without bounded bars; whether stage 7 inherits an unstated Lean proof obligation.

§7's Loss bound is careful. It assumes a gapless market, Λκ ≤ 1, and m ≤ 1/2 − 2κ. Two other places drop the m
condition:
- **Paper, theorem 6.** "stops the account out once its gross exposure exceeds four times its equity, which proves
  that bound on markets whose bars open at the previous close".
- **SEMANTICS preamble.** "holds by construction on gapless markets, from the account's stop-out".

Both are false. Here is a gapless counterexample on the corrected engine, with zero costs:
1. Two coins are held at $10,000 each on $10,000 of equity (2×, within β and the order cap).
2. Both fall to 66.7 in one bar, with low = close. Gross is 13,340 against equity of 3,340. Equity at adverse (3,340)
   is not below maintenance (13,340/4 = 3,335), so there is no stop-out.
3. The decision at that step sizes on e_d, but its orders fill a bar later. The pending fill was sized before the drop
   and is a no-op. The next bar carries 4× gross.
4. That bar opens at 66.7 and closes and lows at 26.7. Then r′ = −200 · 40/3,340 ≈ −2.4.

Gaplessness bounds only the fills. The carry needs bounded bars, which only the null generators' clips supply.

Theorem 6 sits in the list of "six statements, pre-registered before any proof is attempted", which the paper says
are proved in Lean. The −1 part is L6_bounded. The −2 part has no Lean statement: it is a pen-and-paper argument in
SEMANTICS §7.

Fix:
- In both places, state the bound exactly: on gapless markets whose per-bar carrying loss m is at most 1/2 − 2κ, such
  as N1 to N3 with their clips, by the argument of SEMANTICS §7, not by a theorem of the reference model. The gate
  paragraph's "proves the bound on the gapless synthetic null markets" is correct in scope and needs only the source
  of the argument.
- Theorem 6 should keep only its pre-registered −1 statement.
- Name the fill admission next to the stop-out. The bound needs both.

### 3. Low — §7 step 2 now marks every coin, which makes "Σ q · mark" ambiguous. Outcome: divergent implementations; a literal one aborts real-data runs.

Step 2 changed from "for each held coin" to "for each coin". The change is needed so that an opening fill can be
judged at its coin's mark. But marks start as NaN, and a coin with no bar at or before b keeps a NaN mark. §7 now
defines "the book's equity is cash + Σ q · mark" with "q[c] absent means 0". Summed over V, 0 · NaN = NaN. Equity is
then NaN on every market where some coin's bars begin after w_start, which happens in real data, and the run goes
bankrupt or aborts with R_ACCOUNTING.

The frozen engine sums over held positions, and so does the proof. State it: Σ over coins with q[c] ≠ 0, in coin
order.

### 4. Low — I6's two clauses hold together only through a non-obvious construction, and the `result_hash` check is weaker than stated. Outcome: low; at worst the currently passing duplicate-strategy test, or a promotion from a deliberately rewritten row.

**The two clauses.** I6 now says:
- "every replacing insert abort … in every table";
- `disclose()` inserts a present strategy "as a no-op", that is, `INSERT OR IGNORE`, which
  `test_insert_or_ignore_duplicate_strategy_is_harmless` requires to succeed with rowcount 0.

The obvious trigger, `BEFORE INSERT … WHEN EXISTS(same key) RAISE(ABORT, 'append-only')`, also aborts `OR IGNORE`. A
`BEFORE` trigger fires before conflict resolution, and `RAISE(ABORT)` overrides the statement's clause. I checked this
on SQLite 3.53.1, and that test would then fail.

A construction that satisfies both exists: an `AFTER INSERT` guard against a shadow key table, filled by a second
`AFTER INSERT` trigger. `OR IGNORE` fires neither, and `REPLACE` aborts. But it depends on SQLite firing the most
recently created trigger first, which is observed behaviour and undocumented.

No outcome depends on whether a `REPLACE` of a strategy aborts or is ignored, since the row is kept either way.
Simplest fix: for `strategies`, require only that no committed row changes, and allow `RAISE(IGNORE)`.

**The hash check.** `result_hash` is sha256(summary ‖ returns), unkeyed (`main.rs:348`). A writer able to alter the
schema can recompute it. The gate check therefore catches only rewrites that leave the hash stale. Against a
deliberate rewrite, the protection is that no untrusted code holds a writable connection. I6 should say that, rather
than that the gate "trusts the row only if it matches".

## Is the −2 proof sound, step by step?

Yes, for a gapless market (each selected bar's open equals the step's mark), with Λκ ≤ 1 and m ≤ 1/2 − 2κ. r′_t runs
from e1 at step t−1 to the equity at step t before absorption. It therefore covers step t−1's step 7 fills, the carry,
and step t's closeouts.

1. **G₀ ≤ Λ · e_prev.** If there is no stop-out, equity at adverse ≥ G_adv · max(1/(2L), 1/Λ) ≥ G_adv/Λ ≥ 0.
   Moving from adverse to mark adds x to both sides for a long, so (G + x)/(E + x) ≤ Λ because Λ ≥ 1. For a short,
   gross falls while equity rises. A delisting fill cuts gross by N and equity by at most κN, and G − ΛE ≤ N(1 − Λκ)
   holds. e_prev is e1, which comes after steps 3 to 5, as the bullet needs. Funding precedes margin, so it is
   inside equity at adverse.
2. **Step 7.** Fills at mark plus costs lower equity by (s + f + sf) · notional for a buy and (s + f − sf) for a sell,
   so κ is right. A sign-keeping reduction preserves G ≤ ΛE by the same inequality. Equity after it is
   ≥ E(1 − Λκ) ≥ 0. Any other fill must re-establish G ≤ ΛE itself. By induction in decision order, G₁ ≤ Λ · E_after
   ≤ Λ · e_prev.
3. **Costs.** There is at most one step 7 fill per coin: K2's rule removes due orders on stopped-out, bankrupt or
   delisted coins. Each fill trades at most (|q₀| + |q₁|) · mark, so the total is at most G₀ + G₁ and the cost at
   most 2Λκ · e_prev.
4. **Carry.** The carry plus step t's closeouts loses at most m · G₁. Marking at the close, and a delisting at the
   close, each lose no more than a closeout at the adverse extreme, because κ < 1.
5. **Result.** r′ ≥ −Λ(2κ + m) ≥ −2.

**NULLS' numbers.**
- c/o < 1.48.
- Long: against, ≤ 0.3 + 0.1; for, funding plus |u₂| < 0.28.
- Short: against, ≤ 0.3 + 0.148; for, ≤ 0.26.
- Cost at adverse ≤ 1.628κ.
- So m ≤ 0.4529 < 0.46 ≤ 0.494.
- |f| ≤ 0.04 is enforced by the generator's clip (`gate/markets.py` CAP). κ ≤ 0.003 is now a construction check.

**What is assumed and what is proven**, stated exactly in §7 and NULLS:
- Proven: the gapless synthetic nulls.
- Assumed: real markets.
- Diagnostic only: realized excursions.

The paper and the preamble overstate it (finding 2).

## Notes (none can change an outcome as the spec stands)

a. **r′ at a bankruptcy step.** r′ is defined with "e′ the equity before step 5's absorption". It does not say whether
   that is before or after step 5's own closeout at the adverse extreme. The bound holds either way, since m covers
   the adverse closeout, but a reported "lowest pre-absorption return" depends on the reading.

b. **Mechanism output fields.** §10 names share_true but not the output keys `exposures_true`, `exposures_false`,
   `mean_true`, `mean_false` and `pass`, which the tests read. It also does not say what an empty branch's mean is.
   The summary enters `result_hash` (I7).

c. **I3's enforcement column.** It still says "against the bar table", but the admission rule needs the book's gross
   and equity at the marks.

d. **I9's consequence sentence.** "So, in a market whose bars open at the previous close, the gross leaving each
   step's fills is at most 4 times the equity before them" is a consequence, not a check. On real markets it is false,
   so the column "then a trace check" should not cover it.

e. **Reversal attribution.** A reversal's closing component, with its costs, is charged to the new exposure and its
   label. Splitting it would attribute more faithfully. No defect requires either rule.

f. **NULLS' no-edge paragraph.** It lists what a position depends on ("decided … sized with equity, the decision
   price, the cap and rounding"). It should add the fill admission and the stop-out. Both read only marks and extremes
   of bars closed by b, so positions stay F_o-measurable and the argument holds.

g. **The clip changes.** The changes to ε and the wicks alter every N1 to N3 and planted market. C2's calibration and
   planted β were judged on the old generators, so they do not carry over. NULLS should say this next to "fresh
   campaign ids".

h. **Relisting and abort code.** A revision that un-delists a coin is not addressed. Neither is the abort code for an
   inadmissible market. Both are subsumed if finding 1 is fixed.

i. **"Gapless".** The term should mean that the selected bar's open equals the step's mark. "Bars open at the
   previous close" is ambiguous when a bar is missing.

j. **Trace label.** The stop-out still records `why = "liquidation"`, which K2 and K5 depend on. Only the prose
   distinguishes it from the venue's liquidation.

k. **Old contract.** SEMANTICS' body is rewritten in place, with one dated header pointing to `f591e3b` as the
   frozen contract. That meets C6.1 only if `f591e3b` stays the named source for C6.4 and Lean's stage 6 model. It
   does, as stated.

## Answers to the brief

- **Is each finding resolved by a rule that kills its cause?** All but GPT 3 and Claude 1. For K1, the abstract rule
  is right, but its input has no source, and the spec and the Blocker disagree (finding 1). No special cases were
  added.
- **Would the nine tests pass?** Eight would. K1 fails as written. Once amended, it does not tell the fix from the
  residual lookahead unless it also asserts at 12:02.
- **Is the −2 proof sound?** Yes, for gapless markets with m ≤ 1/2 − 2κ, and NULLS' generators meet that. §7 and
  NULLS state proven versus assumed exactly. The paper and the preamble do not (finding 2).
- **New ambiguities or contradictions?** The spec contradicts the Blocker (finding 1). Σ over V (finding 3). I6's two
  clauses (finding 4). Notes a to d.
- **Could an independent implementer build it from the spec alone?** Yes once findings 1 and 3 are fixed. Today they
  would have to guess where a delisting record comes from, and the obvious Σ yields NaN.
- **Is the paper's text correct and consistent with the spec?** The holdout paragraph is. Theorem 6 is not
  (finding 2).
