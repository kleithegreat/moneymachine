# GPT (gpt-6.1-sol, high, opencode) on kernel version 2 and study 2: round 2

Run 2026-11-14 14:59 to 15:14 UTC (09:59 to 10:14 EST), alongside Argon, from a clean read-only bundle (`~/.cache/mm-gpt/kv2-r2`) with the same files as Argon's round 2. GPT had not seen kernel version 2 before. Verbatim below.

# Verdict

**Do not register study 2 yet.** The ratio test is valid against its explicitly stated conditional-ratio null. But that null is not a “no skill” null, exposure is not actually matched within five-minute steps, and several ★ laws contradict the specified transitions.

The strongest new breaks are findings **1, 2, 4, 5 and 6** below. I distinguish a false theorem from an explicit modeling assumption: a mathematically valid test of an uninformative null is not a Type-I error violation.

## 1. Attack the claim: `M = W / B`

### 1. No skill can make `M` cross 20 almost surely

**Outcome:** the judged confirmation can be interpreted as skill when it is only differential risk.

**Claim attacked:** measuring the account against this basket removes what a rule without skill can earn.

**Construction:** two coins, zero funding and negligible costs:

- Coin A stays at 1.
- Coin B independently returns `+a` or `−a`, equally likely each step, with `0 < a < 1`.
- The account buys and holds A. Thus `e = 1`, `W = 1`.
- The equal-weight basket’s factors are `1 ± a/2`.

Consequently,

\[
E[M_t/M_{t-1}]
=\tfrac12(1+a/2)^{-1}+\tfrac12(1-a/2)^{-1}>1,
\]

and

\[
E[\log(M_t/M_{t-1})]=-\tfrac12\log(1-a^2/4)>0.
\]

Therefore `M` eventually crosses 20 almost surely. The account neither forecasts nor earns anything.

A separate deterministic construction is simply holding a permanently higher-beta coin during positive market drift. Matching **dollar exposure** does not match factor exposure.

**Smallest change, hypothesis:** name the judged hypothesis exactly: *conditional expected relative growth against this specified basket*. Do not translate its rejection into skill, market-drift removal, or outperformance unexplained by passive risk. A stronger interpretation needs assumptions about coin exchangeability, factor exposures or an explicitly richer comparator.

Fable acknowledges these residuals, but an acknowledged residual is not harmless when it can generate the entire rejection. This is the **same causal problem as round-4 D12**, now across assets rather than across average exposure.

### 2. Start-of-step exposure does not remove drift along the account’s actual exposure path

**Outcome:** judged `M` can grow from ordinary market drift even in a one-coin universe.

**Claim attacked:** drift is removed “along any path of exposure”; the basket-holder test in build step 10 should return `M = 1`.

**Construction:** at every five-minute boundary the account is flat. Shortly afterward it buys, holds during an ordinary upward price movement, and takes profit before the next boundary. Repeat on a steadily rising market.

At every benchmark reset, `e = 0`, so `B` remains 1. The account repeatedly earns positive returns, so `M = W` grows. There need be no timing skill: exposure can follow a fixed schedule.

The same problem occurs less dramatically whenever ladder orders fill or take-profit orders close **inside** a reporting step. Even an equal-weight basket account does not have return `e_start × r_step` under arbitrary intra-step trading.

**Smallest change, hypothesis:** construct the benchmark on the event-time exposure process, with a precise predictable convention, rather than on five-minute starting exposure. Alternatively, retain the five-minute benchmark and explicitly concede that it credits intra-step market exposure and timing.

The fixed hedge was replaced, but **round-4 D12’s exposure mismatch survives at a finer timescale**.

### 3. Changing membership is not yet a defined basket

**Outcome:** different conforming implementations produce different judged `B` and `M`.

**Claim attacked:** the report alone determines the benchmark.

**Construction:** A and B are listed at a step’s start. A falls from 1 to a delisting settlement of 0.1; B remains at 1.

- Start-membership, settlement-inclusive mean return: `−0.45`.
- End-membership mean return: `0`, because A is no longer listed.

An account holding B has `M = 1/0.55` under the first convention and `M = 1` under the second. Repeated listings and delistings compound the difference. The current report promises every **listed** coin’s mid, not the settlement-inclusive total-return series needed to resolve this.

New listings, missing starting marks and gaps create analogous ambiguities.

**Smallest change, hypothesis:** specify a self-financing basket convention: membership and weights fixed predictably at each reset, entry rules for new coins, settlement-inclusive exits, missing-mark handling and exact reset times. Carry its required prices and settlements in the report.

### On Fable’s impossibility claim

There is a correct restricted statement:

> No nontrivial test can distinguish skill from an arbitrarily varying, unrestricted predictable market drift without additional assumptions.

But **unknown drift alone does not imply impossibility**.

For example, under the null that market returns are IID from an unknown distribution, their chronological order is conditionally uniform given their multiset. Freeze a timing rule, replay it on every permutation, and rank its observed timing profit. That is an exact fixed-horizon permutation test, with unknown mean and distribution. A buy-and-hold rule cannot win merely because the market rose; a genuinely successful dip-timing rule can win by exploiting ordering. Costs and the rule’s endogenous state must be replayed on every permutation.

It assumes exchangeability, not unrestricted conditional drift. Optional looks need separately registered error control. Thus the choice is **which scientific restriction is defensible**, not “`M` or no exact timing test.”

## 2. Attack “nothing bets more than the account”

### 4. The account is not the fastest exact wealth on its returns

**Outcome:** the claimed power wall and choice of confirmer can change.

**Claim attacked:** no exact wealth grows faster than the account without a stronger loss bound.

**Construction:** let the account’s returns alternate between `−1/2` and `+1`. Every pair returns account wealth to its starting value.

The half-bet wealth

\[
T_n=\prod_{t\le n}(1+\tfrac12R_t)
\]

gains `0.75 × 1.5 = 1.125` per pair and crosses 20 after 26 pairs. It uses only `R ≥ −1`. Under the same conditional-mean null `E[R_t | past] ≤ 0`, it is an exact nonnegative supermartingale.

The construction works equally on relative returns `R_t = M_t/M_{t-1} − 1`. Such loss/recovery paths are entirely possible for a ladder.

This does **not** establish a uniformly superior test, nor authorize a linear fraction above 1. It disproves the broader claim that the account itself exhausts exact confirmers or determines their attainable power.

**Smallest change, hypothesis:** distinguish the maximum admissible **linear betting fraction** from the best wealth process. Compare the account with predictable fractional bets or a registered mixture. Do not present account volatility alone as an impossibility result for confirmation.

### 5. A no-debt certificate establishes nonnegativity—not a no-skill supermartingale

**Outcome:** leverage can turn a fair underlying process into frequent confirmation unless the null is defined after all limited-liability transfers.

**Claim attacked:** certifying V7 preserves exactness when leverage is raised.

**Construction:** initial equity 1, long exposure 2, zero funding. The held coin independently returns `+0.9` or `−0.9`, equally likely. Other 15 basket coins remain constant.

Before debt absorption, account growth is `2.8` or `−0.8`. Basket factors are positive in both cases:

- Up: `1.1125`;
- Down: `0.8875`.

The unfloored relative factor has expectation approximately `0.808 ≤ 1`. With the no-debt floor—or with the test killed at liquidation—the factors become approximately `2.517` or `0`. Four successive wins cross 20 with probability `1/16 = 6.25%`.

The venue can genuinely promise no debt. That promise supplies the option causing this positive mean; it does not restore the pre-floor null. Fees small enough to match the recorded schedule do not remove the construction.

**Smallest change, hypothesis:** state and justify the null for the **actual stopped, fee-inclusive, funding-inclusive, limited-liability account**, including all backstop transfers. Exactness against that null survives leverage; exactness inferred merely from fair prices does not.

**What the certificate must quote:** the applicable account mode, collateral and products; treatment of negative equity after gaps; liquidation fees and penalties; funding obligations; later clawbacks/socialized debits; and whether any residual debt can subsequently be collected. It must cover the account being simulated, during the judged dates—not merely an isolated-margin feature or an insurance fund’s existence.

It cannot certify the simulator’s invented liquidation prices, record completeness or the statistical null.

## 3. Attack evidence allotment

### 6. Per-event depletion still spends one seller more than once

**Outcome:** judged fills, account wealth and confirmation can be inflated.

**Claim attacked:** every pessimistic fill is backed by a distinct recorded lot offered through its price.

**Construction:** two resting buy slots each want one unit at 100.

1. A snapshot shows one seller at 99. Slot A fills.
2. The next snapshot shows the **same unchanged seller** at 99. Slot B fills.

Each quote completes an order; each event allocates its one unit only once. Nevertheless, the account bought two units from one unit of historical supply.

A related construction uses that seller’s quote first, then the subsequent buyer-initiated print executing the same resting seller. Quote evidence fills one slot; print evidence fills another. Separate snapshot/trade feeds—and duplicated buyer/seller records without canonical trade-ID deduplication—make this especially important.

V10’s “book refills between events” can assume the missing replacement seller into existence. Then the fill is supported by **a replenishment hypothesis**, not by recorded evidence.

**Smallest change, hypothesis:** either use a coherent persistent counterfactual depletion model with explicit replenishment and trade-ID rules, or narrow the claim. Unique prints can support a cleaner passive-fill rule than snapshots, but snapshot-based taker consumption must still be reconciled with subsequent prints if the global “lot once” claim is retained.

This is **round-1 finding 3b’s same cause, moved across events**. Event-local allotment is a patch, not its removal.

### 7. `F0`, `E1` and `F1` cannot all describe the proposed venues

**Outcome:** the Lean proof gate is impossible as written, or its statements must quietly weaken.

**Construction:** a resting buy has remainder 10. A qualifying trade prints size 1.

- `optimistic`, under A7 and F0, fills the whole remainder: 10.
- E1 allows at most the recorded print: 1.

There is also an allocation problem with per-order F1. Suppose a higher-priority order needs two units, a lower-priority order needs one, and quote evidence contains one unit. Pessimistic skips the first because the quote cannot complete it, then fills the second. An optimistic rule repaired by clipping to recorded evidence spends that unit on the first, leaving the second with zero. The second order’s pessimistic fill exceeds its optimistic fill.

**Smallest change, hypothesis:** separate fictitious optimistic touch capacity from recorded pessimistic evidence in the laws. Drop or appropriately restrict the per-order ordering theorem after joint allocation. Freeze these corrected statements before any implementation.

## 4. Decimal reading

**No counterexample found within the intended normal-range, fixed-scale domain.** If the original value really is `n × 10⁻ᵈ`, `|n| < 10¹⁵`, and conversion is correctly rounded, recovery is unique for the proposed price/rate scales. Argon’s original directed-rounding problem has genuinely been removed.

Three limits should be explicit:

- This recovers the **numeric value**, not the original spelling.
- “At most 15 significant digits” is not equivalent to `|n| < 10¹⁵` at a declared scale. For example, price `10000000` at scale 8 is rejected despite having one significant digit.
- The uniqueness argument needs a bounded scale/range excluding underflow collisions and a signed-zero convention.

These are **notes**, not a demonstrated wrong accepted price in the proposed study. X2 would nevertheless be a better theorem about `ofDouble` than a million-case property test.

## 5. Attack the fidelity wall

### 8. Aggregate underperformance can conceal selective flattering fills

**Outcome:** a flattering execution model passes the freeze wall and inflates the forward judged result.

**Claim attacked:** layer 3 establishes that the judged venue “does not flatter.”

**Construction:** in each pre-freeze cadence period there are two cycle classes:

| | Real profit | Simulated profit |
|---|---:|---:|
| Class A | 10 | 19 |
| Class B | 10 | 0 |

The simulated sum is 19, below the real 20, so the wall passes with zero tolerance. Forward, the fitted trigger selects only class A. Every selected cycle is flattered.

The same construction uses overcredited profitable exits offset by missed profitable entries, or exaggerated losses offsetting exaggerated wins. Conditioning on real first buys and completed cycles does not remove this selection problem. Excluding cycles still open at the historical endpoint introduces another conditioning difference.

**Smallest change, hypothesis:** call the wall exactly an aggregate historical comparison. For execution fidelity, examine paired errors conditional on entry/exit role, size, market state and trigger selection, preferably on an untouched pre-freeze validation interval. Include unfinished cycles and terminal marking explicitly.

No finite historical wall proves future non-flattery. The forward comparison remains necessary.

This retains **D14’s same cause**: validation of an aggregate on fitted/conditioned dates does not identify the execution error relevant to the selected forward rule.

## 6. The deletions

**Deleting `mm` after study 1 is compatible with reproducibility from its tag.** It does not require reproducing its nine defects in version 2.

But two market slots do **not** replace a bars-only execution venue: they replace a target-output interface. A later study with only historical bars, funding or synthetic bar markets cannot run at all without manufacturing books or adding a venue.

That is a **capability-loss note**, not a defect in study 2’s current judged number. It is a correct specialization if version 2 means “the book-replay instrument.” It is an architectural wall if version 2 is meant to replace the project’s general research kernel.

A clean derivation could include a bar-reference execution convention in the same event machine, explicitly labeling its execution assumptions. No restoration of Rust or the old cost table follows. The human should not be told that clean-room design logically requires this loss.

## 7. Can independent builders implement and prove this specification?

**Not yet.** In addition to the contradictions above:

### 9. Delayed replacement can exceed a cycle’s size; `close` can strand a position

**Outcome:** judged fills and ladder exits change.

**Construction A:** a slot wants 10 units. At tick `τ`, a price change schedules a replacement for 10 at `τ + λ`. Before cancellation takes effect, the old order fills 6. The replacement then fills its scheduled 10: cycle total 16.

A6 never says to resize the pending replacement against intervening fills. Per-order L4 holds; cycle S1 fails.

**Construction B:** position 3, take-profit `size = close`. It fills 1. At reconciliation, “whole position” is now 2 and `filled = 1`, so the wish becomes 1 rather than the live remainder 2. After that fills, position 1 remains while `filled = 2`; the slot wants nothing more.

A changing size expression can also fall below already accumulated `filled`, making S1’s unconditional bound false.

**Smallest change, hypothesis:** define whether size is a cycle target or current outstanding demand; specify pending-replacement accounting at activation; and define `close` so cumulative fills are not subtracted twice. State S1 against the appropriate committed target, including shrink/cancel semantics.

This is **round-1 finding 7’s cycle issue**, now supplied with a law but not compatible transitions.

### 10. L1 forbids the hidden ledger state the design intentionally requires

**Outcome:** the causality proof gate is impossible, or an implementation can expose undelivered account information.

**Claim attacked:** equality of events with `known ≤ τ` implies equal machine states, orders and traces through `τ`.

**Construction:** two markets have identical delivered events. At `τ − δ/2`, an unseen quote fills a resting order in one market but not the other. Actual positions, fees, fill traces and possibly liquidation states differ before `τ`.

That is intended: the ledger acts at event time. Delayed strategy knowledge does not make the actual states equal.

**Smallest change, hypothesis:** distinguish actual market/account state from the strategy’s delivered information state. Prove non-interference for the latter and its wishes. Specify delayed delivery of fills, refusals, cancellations, liquidations and funding effects, rather than assuming a delayed `pos` input alone seals the boundary.

### 11. Gap semantics use future quotes to change earlier decisions

**Outcome:** judged fills and wishes depend on future data.

**Construction:** quote at time 0, `G = 10`, a trade at time 4 and a tick at 5.

- Market A’s next quote is at 6.
- Market B’s next quote is at 100.

The delivered prefixes through 5 are identical. But A3 places time 4 inside a gap only in B, disabling its fills/checks and making price inputs undefined. The strategy can therefore act differently before the distinguishing quote exists.

**Smallest change, hypothesis:** make operational staleness causal—e.g. it begins when the last usable quote becomes older than `G`. Retrospective gap labels may remain report metadata, but cannot rewrite earlier execution. Define initial and trailing gaps too.

For physical-account claims, “nothing happened during the gap” also needs justification. A held leveraged account may have liquidated and recovered between recordings. Ending its test at an unacceptable evidence gap is different from silently suppressing liquidation checks.

### 12. Funding-at-the-same-time has contradictory position conventions

**Outcome:** judged funding, margin and returns differ.

**Construction:** an opening fill and funding settlement share a timestamp.

- A3/A12 process funding first.
- A9 says funding uses the position “fills at it included.”

One convention charges the new position; the other does not. A closing fill gives the reverse discrepancy.

**Smallest change, hypothesis:** choose and document one total ordering and its funding-position convention. Make U1 state that convention explicitly. It cannot simultaneously include later-class fills and be an ordinary immediate funding transition.

### 13. The floor and conservation laws omit permitted cash-changing events

**Outcome:** negative reported wealth, inconsistent proofs, or artificial debt absorption.

**Construction A:** funding takes a held account below zero. There is no subsequent quote before a report tick. A12 performs no funding-time liquidation/floor check, while L6 requires equity never to be negative.

**Construction B:** a leverage-1 order spends all available cash; admission does not reserve its fee. Its fee leaves negative cash. A subsequent sufficiently low positive price can liquidate it. Thus build step 7’s “never liquidated by any price path, only funding” property is false.

**Construction C:** bankruptcy absorbs a negative cash balance. A1’s conservation equation includes buys, sells, fees and funding—but not `absorbed`. It cannot remain an equality after that transition.

**Smallest change, hypothesis:** specify checks after every relevant cash/rule transition, fee-aware cash admission where cash ownership is claimed, and conservation including absorption/transfers. Do not waive the no-debt requirement at leverage 1 merely because positions are long.

### 14. X1 contradicts the intended role of floats

**Outcome:** a ★ law cannot be proved as stated; weakening it without review could conceal decision errors.

**Construction:** a program has exact constant price and size, no `exact(·)` node, and:

```text
when = float_source > 0
```

Two float evaluators returning opposite signs place different orders. X1 says they place the same orders.

**Smallest change, hypothesis:** condition the numerical-boundary theorem on equal activation/control decisions, and prove price/size independence only where their dependency graphs exclude float crossings. Float-to-bool is a decision boundary even when no float becomes a rational.

### 15. The proof list does not cover the confirmer’s judged number

**Outcome:** all listed engine proofs can pass while reported `M` or the stopping result is wrong.

**Construction:** the internal ledger is correct, but report generation swaps two coin columns, uses the wrong endpoint mark, or omits a boundary fee from the reported equity projection. The listed accounting/fill theorems remain true internally. Step 10 then faithfully computes the wrong benchmark or ratio.

There is no ★ theorem for:

- report-to-state correspondence;
- the exact `B`/`M` recurrence and initial row;
- liquidation versus threshold precedence;
- or the conditional-null-to-crossing bound.

A Monte Carlo null check is not that proof. Moreover, requiring at most 1,000 rejections in 20,000 paths will reject a correct test operating at exactly 5% roughly half the time.

**Smallest change, hypothesis:** add report projection, benchmark recurrence and stopping-characterization laws, plus the mathematical validity theorem under the explicitly defined null. Give simulation checks registered statistical acceptance rules.

Independent implementation also needs an actual JSON grammar for exact literals/slots and canonical event encodings, funding-hour/lateness rules, grid-change handling and source revision/deduplication rules. These choices change orders or settlements; they are not mere plumbing preferences.

This is **round-1 finding 7’s specification-completeness cause**, not yet removed by adding characterizations.

### 16. Protected-date admission disappeared with version 1

**Outcome:** protected data can be disclosed.

**Construction:** a conforming reader feeds well-formed November–January events under a caller-supplied horizon. C2 accepts them. `finish` returns equity and every coin’s mids. No version-2 rule rejects protected dates or enforces release authorization.

The build plan’s instruction not to read them is a work instruction, not the old I8/I11 boundary. Hashing a prohibited read does not prevent disclosure.

**Smallest change, hypothesis:** put a trusted release/window policy outside caller control at market admission, covering every source and report path. Separate format/integrity inspection from value disclosure. A harness may own this protection, but the contract must identify and test it.

### 17. Append-only rows do not establish metered disclosure

**Outcome:** a later judged search can receive uncounted evaluations.

**Construction:** an implementation writes its report, then inserts the SQLite row. Kill it between those actions. The agent has the score; the ledger has no row. This satisfies the plan’s killed-run/no-row test and append-only schema, but the budget meter misses the evaluation.

**Smallest change, hypothesis:** restore an explicit commit-before-publication protocol for every result-bearing channel and file. If attempts are budgeted, reserve an append-only attempt before evaluation; distinguish an attempt record from a completed result.

This does not affect the frozen study-1 harness. It affects the version-2 harness capabilities A13 expressly promises.

### 18. Daily/weekly polling can permanently lose required historical rules

**Outcome:** lost recordings later change judged fees, admission or liquidation.

**Construction:** leverage tiers change from 40 to 20 during the day, then back to 40 before the next daily `meta` copy. A position breaches maintenance only under the intervening tier. Both stored snapshots say 40.

Two fee changes between weekly checks produce the analogous unrecoverable history. Daily vault-fill collection also needs a demonstrated bound or recovery mechanism against the latest-10,000 cap; an average fill rate is not that bound.

**Smallest change, hypothesis:** record effective-dated changes from a source that preserves them, or establish and monitor a collection cadence with recoverable history and completeness guarantees. Persist the existing pre-freeze raw fill responses now; do not leave the only copy in a session scratchpad.

## Recommendation A — What should study 2 claim?

**Recommend reporting both `W` and `M`, with `B`, but judging only one predeclared scientific hypothesis. Under the present design, that can be the narrowly named ratio-null—not “skill.”**

| Quantity | What no skill can pass | What it misses |
|---|---|---|
| `W` | Passive positive drift, risk premia, limited-liability subsidies | Whether gains beat a relevant passive alternative |
| `M` | Lower-risk coins against a volatility-decaying basket, unmatched beta, intra-step exposure, membership artifacts | Market-wide timing removed by the benchmark; profitable performance shared with the basket |
| Both | Neither number alone separates skill from all passive effects | They at least expose absolute versus relative performance |

“Earned” should be permitted as a **descriptive outcome**: the account earned money under the registered execution model. It should not be prohibited merely because a bull market can produce it.

If the real scientific question is whether the vault times market-wide dips, I would prefer a registered timing test under an explicit exchangeability or other restricted-drift null over `M` as the sole answer. That trades a visible assumption for an informative question. Fable’s unrestricted-drift impossibility argument does not choose that trade for the human.

## Recommendation B — Run the forward test despite expected non-confirmation?

**Yes—as bounded prospective validation, not as an already established positive control with useful power.**

It uniquely measures the frozen rule’s performance on unfitted dates, the forward execution discrepancy, trigger fidelity, changing utilization and whether the pre-freeze power forecast transports. The pre-freeze bootstrap measures none of those out of sample.

But it is not merely “a replay a month.” Its cost includes continuous recording, completeness monitoring, changing rule histories, API retention limits, storage and human investigation. Register that budget and the intended interpretation of an inconclusive end.

Record now; freeze only after the semantic breaks are settled. Report prospective fidelity and estimation results even if confirmation is unlikely. Do not turn a fitted bootstrap
into a measured upper bound on what exact confirmation can achieve. The Gaussian figures are planning approximations; the bootstrap is a fitted forecast, not an impossibility theorem.

## Convergence ledger

### Points I agree with

1. **One event-driven account and exact rational accounting are sound foundations.** They genuinely remove the integer-ledger contradiction and directed binary64 grid-rounding problem.
2. **The Lean/OCaml division is appropriate.** Proofs must concern the running transitions; readers, FFI and publication remain explicit trust boundaries.
3. **Neither fill venue bounds whole-run returns.** Fill feedback prevents that inference.
4. **The conditional-ratio null gives a valid nonnegative supermartingale**, provided the benchmark is positive, the recurrence is correctly implemented, and stopping is adapted. This establishes validity against that null—not its interpretation as no skill.
5. **Leverage is not inherently incompatible with exact testing.** The relevant lower bound and conditional-mean null must concern the actual limited-liability, stopped account.
6. **Pre-freeze accounting replay is valuable independent evidence.** Prospective trigger and execution validation remain separate.
7. **Non-confirmation is not evidence of absence.** Recording forward data now preserves an otherwise irrecoverable research option.
8. **Deleting version 1 after study 1 need not invalidate archived results**, provided the tag and required dependencies/data remain sufficient for reproduction.

### Disputes still open

| Point | What would settle it |
|---|---|
| `M` removes no-skill performance | A defensible restricted null or a narrower claim accepting the constructions in findings 1–3 |
| Exposure matching at five-minute boundaries | An event-time benchmark definition, or explicit attribution of intra-step market exposure to the judged residual |
| The account exhausts exact confirmers | Withdrawal of that universal claim; comparison with fractional or mixed betting wealth |
| No-debt certification establishes exactness | Separate justification of nonnegativity and the post-transfer conditional-mean null |
| Pessimistic fills consume distinct evidence | A cross-event depletion/replenishment contract, or a narrower evidentiary claim |
| Layer 3 establishes non-flattery | A narrower historical statement plus validation addressing selective execution errors |
| Documents determine independently implementable semantics | Resolution of findings 7 and 9–15 before proof statements are frozen |
| Protected data and evaluation budgets remain guarded | Explicit admission and commit-before-disclosure contracts |
| Forward recordings preserve needed history | Effective-dated collection and tested completeness/recovery rules |

**These are not all new objections to settled mathematics.** Findings 2, 6, 8, 9 and 15 identify causes from earlier rounds that remain after a change of representation, timescale or validation layer. Calling those revisions re-derivations does not settle their surviving constructions.

### Choices only the human can settle

- **Scientific target:** absolute earning, relative growth against a named comparator, or timing skill under stated assumptions. Mathematics can show their differences; it cannot choose their importance.
- **Acceptable assumptions:** exchangeability, factor restrictions, counterfactual replenishment and reliance on venue guarantees.
- **Forward commitment:** the collection/maintenance budget and whether prospective fidelity and estimation justify running despite low confirmation power.
- **Kernel scope:** a specialized book-replay instrument, or a general replacement that must eventually support explicitly modeled bars-only markets.

### Overall status

**Not converged.** No study-2 criterion should be registered from these documents yet. Preserve recordings and continue reversible infrastructure work, but settle the benchmark, evidence accounting and contradictory laws before treating the proof gate—or the advertised power wall—as established.
