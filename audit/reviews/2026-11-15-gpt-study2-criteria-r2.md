The bid valuation preserves the pointwise bound \(W^b \le W\). I’m checking two separate risks now: whether the bootstrap preserves that bound when it stitches days together, and whether protected-data diagnostics can reach unfrozen-work reviewers despite the engine’s date checks.
**Not ready to commit.** The bid valuation is sound and the original findings have largely been closed at their causes. Remaining blockers concern the bootstrap’s definition, midnight ordering in the guard, the unresolved scope of the human’s decision, and protected-data disclosure.

This is a static design review. I did not execute `arithmetic.py.txt` or an engine implementation.

## 1. Round-1 findings: closure at the cause

### GPT

| Finding | Confirming disposition |
|---|---|
| F1 — licensed sentence versus rejection | **Closed:** the claim now describes day-end marked wealth and distinguishes arriving from resting fills. |
| F2 — mean square called volatility | **Closed:** centered variance, with divisor equal to the count, replaces mean square. |
| F3 — zero denominator | **Closed:** zero replay variance is explicitly “not judged”; positive replay variance against zero forward variance fails. |
| F4 — matching called entry identity | **Closed:** the claim is now the observed one-to-one temporal correspondence, not cycle or decision identity. |
| F5 — discretionary proposers | **Closed:** exact multiplier selection and a deterministic guard family remove search-effort discretion. |
| F6 — discretionary “whole days” | **Closed:** no days are excluded; gaps count through staleness. |
| F7 — pre-freeze CS2.3 window | **Closed:** its first 61 days now follow the freeze. This does not close the separate disclosure problem below. |
| F8 — protected cadence chooses delays | **Closed:** delays come from the written recorder design, not protected recordings. |
| F9 — filenames mistaken for isolation | **Closed for raw records:** content-filtered export and filesystem isolation replace the directory-list test. Existing seven-month summaries remain acknowledged development information. |
| F10 — release/build mismatch | **Closed:** computational identity is separated from the registered, release-only window transition. |
| F11 — later abort erases crossing | **Closed for `confirm`:** completed-prefix replay preserves earlier judged days. The guard still has a midnight-order discrepancy, R1 below. |
| F12 — taker-print veto | **Closed by withdrawal:** no unsupported execution certificate or discretionary veto remains. |
| F13 — bootstrap preservation guarantees | **Closed:** cycle and weekday guarantees are withdrawn. Different, result-changing bootstrap problems remain below. |
| F14 — simultaneous admission order | **Closed:** arrivals are admitted reduce-only first, then in A6’s order. |
| F15 — settlement’s reconstructed fee rate | **Closed:** the ledger uses cost per nonzero unit and never reconstructs a rate from zero notional. |
| Number/readiness notes | **Closed as specified:** exact depth derivation, full tie-break, fixed path count, step 0 first, and explicitly narrowed fixtures. |
| O6 — integer-price exception | **Closed in the design:** the certified allowed-price set and its rounding replace the old grid. |

### Argon

| Finding or construction | Confirming disposition |
|---|---|
| 1.1 — proposer trust | **Closed:** neither multiplier nor candidate mix is proposed by an unfixed search. |
| 1.2 — fully invested guard’s first charge | **Closed narrowly:** the fixed family retains cash; it is not promised survival under every admitted funding path. |
| 1.3 — terminal-only refusal | **Closed:** refusal examines every replay day-end as well as the terminal rate. R1 concerns which side of midnight is examined. |
| 2.1 — constant-ledger/zero-variance cases | **Closed:** explicit domains and centered variances handle them. |
| 2.2 — selectable stopping date | **Closed:** the first 212 days are fixed; stopping can produce “not judged,” not select a passing later prefix. |
| 2.3 — early “outgrew” prevents judging | **Closed:** recording/replay continues through day 212. |
| 2.4 — ended-ledger encoding | **Closed:** `held` receives the ending day rather than inferring it from zero wealth. |
| 3.1 — protected cadence | **Closed:** fixed design-derived delays. |
| 3.2 — pre-freeze window | **Closed:** post-freeze 61-day window. |
| 3.3 — raw fit access, admission, carried-in cycles | **Closed for these routes:** sandboxed export, engine-produced lists, and `before = 0` entry extraction. |
| 4.1 — unfixed first-buy notional | **Closed:** 100 USD, 50,000 USD cash, and tests requiring all levels and exits without refusals. |
| 4.2 — vacuous fidelity checks | **Closed:** planted counter tests and explicit training/validation walls replace reliance on exhaustive classification alone. |
| 4.3 — seed, scaling, tie-break | **Closed as choices:** deterministic draws and full tie-break are fixed. Daily-row transformation remains insufficiently specified, R2. |
| 5.1 — duplicate final span | **Closed:** row occasion/order determines one contribution per span. |
| 5.2 — zero-price settlement | **Closed:** no division by notional. |
| 5.3 — delivery at zero delay | **Closed:** the view is explicitly the world as the tick finds it. |
| Construction A — ask-only inflation | **Closed:** its unchanged bid prevents either rung. |
| Construction B — cubic-bound slack | **Closed by acknowledging the conservative failure**, not by eliminating it. No narrower numerical accuracy is promised. |
| CS2.3 optimistic mismatch and cycle claims | **Closed:** the judged run supplies the entries; the licensed sentence is only the matching count. |
| Q4 — taker-print veto | **Closed by withdrawal.** |

## 2. The fourteen ledger checks

1. **D67 — `held`.** The revised arithmetic judges the intended finite-sample quantity. Alternating \(+0.01,-0.01\) versus \(+0.03,+0.01\) has equal variance and holds; constant replay returns are not judged. Ending after day 212 must not retroactively invalidate that list. The brief’s “changing a later day changes nothing” test establishes this.

2. **D68 — entries of the judged run.** A faithful placement trigger can still yield “not shown”: let every real maker fill occur exactly at the resting limit, with no strict-through print. The replica receives none. This is now an honest failure of **fill correspondence**, not a false finding about trigger identity. The optimistic diagnostic cannot identify how much divergence came solely from fills, because fills also change subsequent cycles.

3. **D69 — guard family.** The normalization and lesser-weight tie rule make the bar’s mix defined, including an all-zero vector. The reserved-cash five-minute pair control still has room to refuse; the astride construction remains a legitimate silence case. Cash does **not** guarantee survival: a daily rule holding 0.96 at unchanged prices exhausts its 0.04 cash on the second hourly 4% charge. This is a **note**, since ending is explicitly part of the fixed rule, not a violation of its definition.

4. **D70 — least multiplier.** The finite-list argument holds: include zero, nonnegative breakpoints, and stationary points inside each quadratic interval. Beyond the last breakpoint \(D(\mu)=\mu\), so no omitted tail minimum exists. For two coins with \(S_1=3,Q=-4.5\), the minimum is at \(7.5\); both endpoint maximizers tie there and the lesser weights are zero. That potentially weak control is deterministic, not undefined.

5. **D72 — completed prefixes.** For `confirm`, day rows exclude events at midnight, and artificial final-span rows follow that day’s rows. Funding-completeness checks near the horizon therefore do not change the earlier day’s valuation. **The guard’s arithmetic oracle does not respect that boundary: R1 below.**

6. **D73 — registered build.** Within the specified pinned computational build, changing a window endpoint, adding a window, or making another non-release change must fail the registration comparison. No permitted non-release mutation is described. Keep the omitted file declarative and include the computational build’s toolchain/dependency identity; merely calling an arbitrary source-file digest “the build” would not establish that.

7. **D76 — fit isolation.** An August-named file containing a September row is excluded by content, and opening the archive directly fails. These close the original raw-record routes. The fit is **not informationally untouched** by September–October: the supplied facts already disclose summaries. The brief now admits this correctly. Newly produced held-back reports should not acquire access merely by becoming tracked files.

8. **D56/D64/D65 against part A.** Simultaneous close-before-buy, day/account/final-span ordering, and cost-per-unit settlement handling agree. A sale of nonzero units for zero cash neither divides by zero nor leaves test units behind.

9. **D78 — bid dominance and missing rows.** No counterexample found. A positive holding requires an earlier quote. A delisting at the day’s last millisecond closes that holding before the day row; delisting exactly at midnight happens after the preceding day’s row. No positive holding needs the bid of an already removed coin.

10. **D79 — noninterference.** Conditional on identical cash-flow rows, the test ledger’s cash, units, scales, ending, and bar do not read `bid`. Do not strengthen this into noninterference of arbitrary raw markets: the account’s existing adverse-price margin checks and executions legitimately depend on bids and can produce different fills.

11. **D80 — other bid readers.** Forecasting the new threshold requires accounting for bids. It does **not** force CS2.2 to change, and multiplying resampled bid-mark returns is not sufficient to forecast that threshold coherently. See R3 and R4.

12. **D81 — row meanings.** A12, P1 and A19 agree: `bid`/`quoted` belong to the latest quote; prints and settlement change neither. Settlement changes `price`, then disposes of the holding. Final-span rows must not replace the earlier midnight snapshot.

13. **D83 — claim, blind.** The current explicitly marked, recorded-data comparison is honest about size, staleness and unfilled resting exits. A fourth case is a **fresh but fabricated bid**, even with fabricated depth: admission cannot establish that it stood. This is already covered by the broader wrong-record qualification. I found no admitted, correctly folded record that passes while its **literal marked-wealth comparison** is false.

14. **D84–D86 — grid.** The union of the significant-figure and integer grids, intersected with the decimal restriction, gives the stated step. The tested boundaries and directed roundings agree. Refusing `szDecimals > 6` is a conservative unsupported-domain stop, not evidence that those products cannot exist. The unrun historical witness remains a build wall, not an unresolved grid choice.

### R1 — The guard’s midnight ordering disagrees with the judged day

**Outcome changed:** rung-2 registration and the quoted negative-control result.

In `arithmetic.py.txt`, `guard_fold` consumes events with `time <= tick`, rebalances, and **then** records midnight wealth. `KERNEL.md` A19 instead judges the world **before** events at that midnight.

**Construction:** use the five-minute pair control that exceeds 20 times the bar immediately before its first midnight. At midnight, add a permitted funding payment exceeding its cash. The correct first day records the crossing; the script records zero. A short replay ending at midnight and a longer replay containing that funding event consequently disagree about the earlier guard observation.

**Smallest fix:** record each guard day-end before **all** actions stamped with that midnight, using that day’s coin-row prices. Correct the arithmetic oracle and add this prefix-extension fixture through the engine.

### R2 — The bootstrap still lacks an exact daily-row transformation

**Outcome changed:** the selected \((\phi,d)\), hence future CS2.1 and CS2.2 results.

A19’s sums and funding are **cumulative since the span began**. Step 5 says to add “a day’s three sums” but never defines their extraction, including days containing a span end.

**Construction:** one coin returns \(+0.01\) on day 1 and never moves again. Every later cumulative row still contains \(S_1=0.01\). Adding those rows as daily increments invents a return contribution on every sampled flat day. Across 730 samples this gives \(S_1=7.3\), rather than contributions only when day 1 is sampled. It can suppress the top-rung forecast and change the selector when another coin supplies the profitable strategy.

**Smallest fix:** define a daily slice explicitly: difference cumulative rows, stitch every within-day span closure, and specify undefined starting prices. Test that sampling a zero-event day adds exactly zero sums and funding. If this is already what “day’s” means, write that transformation rather than leaving it to the builder.

## 3. Wealth at the bid: sound bound, unsound stitching, unresolved authorization

For every living ledger,
\[
W-W^b=\sum_c q_c\bigl(p_c-\min(b_c,p_c)\bigr)\ge0.
\]
No additional martingale proof for \(W^b\) is needed. The bar and guard correctly remain at prices. Existing account-side bid-dependent execution is not a new bid read by the test ledger.

### R3 — Multiplying resampled bid-mark factors can manufacture wealth

**Outcome changed:** bootstrap selection of the registered stake/depth, and therefore judged forward results.

Write \(h_t=W^b_t/W_t\). A recorded daily factor is
\[
\frac{W^b_t}{W^b_{t-1}}
=\frac{W_t}{W_{t-1}}\frac{h_t}{h_{t-1}}.
\]
The haircut ratios telescope on the original record. They need not telescope across resampled block boundaries.

**Construction:** hold one coin without trading; keep its mid at 100 and funding zero. Normally quote 99.99/100.01. At one midnight quote 1/199, restoring the ordinary quote the next day. Thus \(W\) stays essentially constant, while \(W^b\) falls about hundredfold and recovers.

A fourteen-day block beginning on the recovery includes the roughly hundredfold factor but excludes the preceding haircut. Stitching such blocks multiplies recoveries without the corresponding low starting marks. The synthetic numerator can exceed 20 while its constant-price bar is 1—even though the underlying books never gained. Fixed digest draws remove seed shopping; they do not remove this construction.

**Smallest fix:** resample the price-wealth factors and endpoint haircut separately, defining synthetic \(W^b_t=h_tW_t\), with \(0\le h_t\le1\); or reconstruct a coherent marked ledger path. Add this constant-mid fixture requiring every synthetic bid wealth to remain below its corresponding price wealth.

This does not invalidate the actual forward test. It invalidates treating the prescribed selector’s stitched numerator as that test’s wealth.

### R4 — D80 is a result-changing human decision, not a forced consequence

**Outcome changed:** CS2.2’s verdict.

The bootstrap should forecast the bid-based comparisons. CS2.2 could nevertheless remain a separately worded measurement of price-wealth volatility. Neither mathematics nor consistency authorizes changing the human’s explicit “two comparisons only.”

The claim that ordinary spreads cannot move the verdict is also false for an almost idle ledger.

**Construction:** both records have identical constant mids, one identical first buy, and no later trades. Price-wealth returns match, so their positive initial-entry-loss variances match: **held**. In the replay, alternate bids 99.99 and 99.98 around mid 100, adjusting asks to preserve that mid; forward, keep the bid at 99.99. Bid-return variance in the replay includes the repeated one-basis-point oscillations, while forward variance contains essentially only the initial entry loss. The ratio can fall below one-half: **did not hold**, with ordinary spreads.

**Smallest fix:** obtain an explicit pre-commit human decision ratifying bid-based CS2.2, or restore its price-based series and accurately name what it measures. Do not attribute the broader change to the existing decision.

## 4. Protected-window leakage

### R5 — Admission protects engine outputs, not the required information boundary

**Outcome changed:** disclosure of protected-derived information to research, selection or unfrozen-work reviewers.

Two routes remain expressly available:

- `kernel-v2.md` A13 permits `mm2 inspect` to publish protected-file counts, sizes, hashes and stale spans.
- `architecture.md` 6.6 says the vault’s public record **up to the freeze can influence the decision to freeze**. Before release, that interval includes protected dates.

**Construction:** before registration, an unfrozen-work reviewer receives protected-window stale spans and fill counts to assess whether to freeze now, delay, or abandon the replica. No price is printed and no engine admission fails. Nevertheless, protected-derived information has reached a prohibited recipient. Reading the public vault record is an even more direct route.

**Smallest fix:** separate integrity operations from research. Restrict protected files, APIs and diagnostics to an integrity role; retain diagnostics sealed until release; prohibit their appearance in prompts, tracked reports and review bundles. Remove or qualify the public-record permission. Test an unfrozen-work sandbox against raw files, diagnostic outputs and indirect tracked artifacts—not merely `start` and `feed`.

The two old explicit leaks—delay estimation and pre-freeze judged dates—are fixed. The requested end-to-end embargo is not yet established.

### R6 — The forward collector’s lookback remains unpinned

**Outcome changed:** lost vault recordings, potentially changing CS2.3’s counts and result.

The recorder table prescribes re-reading a “registered delay,” but supplies no value, and the study registration’s enumerated contents omit it.

**Construction:** an open-and-close round trip is indexed twelve hours late. A collector using a one-hour lookback misses it; one using a one-day lookback recovers it. Omitting both fills preserves the position chain, so the promised chain check cannot discover the loss. Eventually retention makes recovery impossible.

**Smallest fix:** pin the collector lookback and retention/alarm policy before collection relies on them, in its readiness specification and recorded configuration. Preserve the explicit V18 limitation. If completeness cannot be established, license CS2.3 as correspondence among **recorded** entries, not an unconditional statement about every vault entry.

This is a recording-readiness requirement, not a reason to invent another statistical criterion or reopen the deferred disk purchase.

## Closing ledger

| Status | Item |
|---|---|
| **Confirmed** | Original specific repairs; deterministic guard/multiplier; centered fixed-window variance; descriptive entry matching; authorized release transition; certified grid. |
| **Confirmed** | Pointwise \(W^b\le W\); unchanged test books; price-based bar and guard; conditional two-rung size argument. |
| **Open — result-changing** | R1 guard midnight order; R2 exact daily bootstrap slices; R3 bid-haircut stitching; R4 human authorization of CS2.2. |
| **Open — protected disclosure** | R5 role/access/output isolation and contradictory public-record permission. |
| **Open — recording readiness** | R6 collector lookback and qualified completeness claim. |
| **Notes only** | Guard survival limitations, conservative grid domain, existing held-back summaries, fresh fabricated bids, deferred disk choice. |

**Plain verdict: not ready to commit.** Resolve R1–R5 before freezing these criteria; pin R6 before collection can lose the records. None requires redesigning the actual self-financing ledger or abandoning bid-based rung comparisons.
