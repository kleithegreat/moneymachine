# Verdict: **not ready**

The converged test ledger and benchmark need not be redesigned. The blockers are in the new criteria and their execution: CS2.2 measures the wrong quantity for its stated claim; CS2.3 licenses more than its matching establishes; some result-changing choices remain unfrozen; step 6 explicitly uses protected data; and the release/build-hash contract prevents the registered forward run from executing as written.

I checked the supplied definitions and arithmetic. I did not execute `arithmetic.py.txt`; its simulation outputs remain scenario-specific evidence, not independently verified guarantees.

## 1. The three criteria

### F1 — CS2.1’s licensed sentence is not its rejection condition

**Outcome changed:** the reported “earned” claim.

A clean counterexample needs neither corrupt quotes nor a false statistical rejection:

- The replica’s first buy is a marketable arriving order, filled at a valid recorded ask.
- There are subsequently only quotes, with no qualifying sell-aggressor prints.
- The ledger’s held position appreciates until its day-end wealth exceeds 20.

CS2.1 passes, but the licensed sentence says the ledger was “filled only on sells through its prices.” That is not how its taker entry filled. Sales also require the mirrored description.

Conversely, let wealth reach 21 at noon and fall below 20 before midnight. The ledger **did** multiply twentyfold during the period, but CS2.1 does not confirm it. This is an intentional loss of power, not a defect in day-end monitoring; the sentence needs to describe that monitoring.

**Smallest fix:** license a sentence about wealth **at a judged day’s end**, starting at the first judged midnight, and distinguish arriving taker fills from resting maker fills. Do not change the test.

Within the correctly stated, conditional replay claim, there should be no stronger false-pass construction: exact ledger accounting and the certified bound make the descriptive comparison true whenever it passes. Statistical false rejection is a separate matter, controlled under the stated null and assumptions.

### F2 — CS2.2 uses mean square, not volatility

**Outcome changed:** “the wall held.”

Write daily returns as \(r_t\). The criterion measures

\[
E_{\rm sample}[r_t^2]
=\operatorname{Var}_{\rm sample}(r_t)+\bar r^2.
\]

The power table’s volatility is standard deviation, not this RMS quantity.

**Pass while the claim is false:** replay returns are constantly \(+0.01\); forward returns alternate \(+0.01,-0.01\). Both mean squares are \(0.0001\), so CS2.2 passes. Replay volatility is zero; forward volatility is positive.

**Fail while it holds:** replay returns alternate \(+0.01,-0.01\); forward returns alternate \(+0.03,+0.01\). Both centered variances are \(0.0001\), but the mean-square ratio is 5, so CS2.2 fails.

These examples can be perturbed without losing either conclusion.

**Smallest fix:** compare explicitly defined **centered daily variances**, using exact arithmetic. State the divisor convention. Alternatively, retain RMS and withdraw the connection to the volatility rows; that would be a different, narrower claim.

### F3 — CS2.2 has an undefined constant-instrument case

**Outcome changed:** the CS2.2 verdict and bootstrap interval.

A replica that never enters produces wealth lists containing only 1. Both mean squares are zero. The ratio is \(0/0\); cross-multiplication nevertheless makes both threshold inequalities true.

Step 1 excludes zero **wealth**, not zero replay variance. Step 5’s point-interval test has the same problem when its constant return size is zero.

**Smallest fix:** make a zero replay denominator explicitly “not judged,” report both variances, and test separately:

- replay zero, forward zero;
- replay zero, forward positive;
- replay positive, forward zero.

This is a domain clarification, not a new test design.

### F4 — CS2.3 establishes temporal correspondence, not entry identity or the same cycle

**Outcome changed:** the licensed fidelity statement.

**Pass while the stronger claim is false:** for each of 100 vault cycles, the replica enters the same coin five minutes earlier and exits one minute later. The vault enters only after the replica has exited. All 100 entries match; neither account participated in the other’s cycle.

The six-minute lifetime argument does not exclude this. It concerns the vault’s historical cycle duration, not the replica’s duration, preceding entries, or shared exposure.

Another construction is a common external trigger: two genuinely different rules react to the same clustered market events and produce matching first fills. Coincident fills do not identify the decision rule.

**Fail while the literal majority claim holds:** 99 vault entries and 99 replica entries match exactly. Every entry corresponds, but CS2.3 is “not judged.”

**Smallest fix:** license the exact observed statement:

> More than half of each account’s first-fill times had a one-to-one same-coin match within six minutes.

Do not translate that into “the same cycle” or “the trigger was the vault’s.” If order-decision identity is required, placements and a different criterion are needed.

The 100-entry gate also needs a different justification or removal; see the number audit below.

## 2. Number audit

| Number | Assessment |
|---|---|
| **20** | Correct: \(1/0.05\), under the nonnegative-supermartingale argument and V16. The joint two-rung reasoning survives the separate nulls because the rejection events are nested. Report the conditional nature of the 5% claim, not merely V10. |
| **212 days** | Correct for `[2026-04-03, 2026-11-01)`. It is elapsed calendar coverage, not 212 complete, independent observations. |
| **2.39** | Correct rounding of \(20^{212/730}\approx2.3869\). The exact-power comparison is appropriate; 2.38 and 2.39 straddle it. This is an extrapolation convention, not evidence that growth will continue. |
| **30 pairs** | Five fractions times six depths is 30. But the depth values come from rounded historical notional ratios, not the final ladder’s exact constants and rounding. Specify whether the listed decimal budgets are exact, or derive exact budgets from the finalized ladder. Also state explicitly the conversion from “first buys” to account dollars. Otherwise different builders obtain different ledgers near a depth boundary. |
| **730 days** | Unambiguous once frozen. It means two 365-day years, not necessarily two calendar years: these dates cross February 2028. This is a wording note, not a blocker if 730 is intended. |
| **Half a row** | \(\sqrt2\) is halfway between factor-of-two volatility rows on a logarithmic scale. It does **not** imply “reads the same row”: a replay value near a row boundary can cross it after an arbitrarily small change. Nor does it imply similar power. Keep it as an explicitly chosen tolerance, not that claimed consequence. |
| **Six minutes** | Correct conversion of the reported rounded decile, 0.10 hours. It does not establish the same-cycle interpretation. Label it a tolerance motivated by that historical summary. |
| **More than half** | A valid derivation for the word **majority**, not for trigger equivalence, statistical significance, or fidelity beyond the stated matching relation. |
| **100 entries** | \(\sqrt{0.25/100}=0.05\) is correct for independent Bernoulli observations. Entries clustered by coin and market event need not have that precision. One hundred perfectly dependent observations can have standard error 0.5. For a purely descriptive majority, no sampling error calculation is needed. |
| **0.0047 chance match** | Reproduces the homogeneous-Poisson calculation using 2,022 cycles, 212 days and 17 equally treated coins. It is not a bound for two dip-buying rules exposed to common market events. Withdraw “chance is far below it” as a general justification. |
| **77 days; about 734 cycles** | Correct calendar length and rate extrapolation for `[2026-11-15, 2027-01-31)`. The extrapolation assumes the historical rate persists. |
| **212-day forward minimum** | A reasonable equal-length convention, but “shorter is noisier” requires comparable dependence and data quality. Do not present it as a distribution-free precision result. |

## 3. Choices still capable of changing a judged result

### F5 — The guard’s search and the multiplier proposer remain discretionary

**Outcomes changed:** rung-2 registration, its crossing day, and the quoted negative-control result.

The kernel correctly distrusts proposers for **validity**. That does not make their choices irrelevant to preregistration.

Concrete construction:

- On the five-minute-pairs market, a guard proposer returning cash finds no refusing witness.
- A proposer searching the useful mixes finds one and refuses rung 2.
- Both satisfy “any search; neither is trusted.”

Similarly, a deliberately poor dual multiplier raises the bar. It can suppress a guard refusal on the replay, or suppress a forward “outgrew” result. Improving it later can change the result.

**Smallest fix:** before step 4 first runs, freeze the guard-search algorithm, candidate handling, budget, seed, objective and tie rules. Step 6 must also freeze the forward multiplier/search implementations and their numerical stopping rules. A versioned executable hash is sufficient; an informal “best found” is not.

No optimizer needs to become trusted. It needs to become **fixed**.

### F6 — CS2.3’s “days the recorder holds whole” is an unfixed exclusion rule

**Outcome changed:** CS2.3’s two shares and verdict.

Suppose one day has 150 unmatched vault entries and another has 101 perfectly matched entries. Including both fails; excluding the first as “not whole” passes.

“Whole” currently specifies neither required streams nor gap tolerance, and the kernel otherwise treats gaps as staleness rather than excluded days.

**Smallest fix:** freeze a mechanical coverage predicate, applied symmetrically to both lists. Generate and seal its mask without viewing matching results. Define treatment of cycles crossing excluded intervals and the window boundaries.

Also freeze the vault-entry reconstruction rule and settlement of same-millisecond fills.

### F7 — CS2.3 lacks a freeze-before-release requirement

**Outcome changed:** whether CS2.3 measures unfitted behavior.

The judged window starts on November 15, but there is no registration deadline before its release. A delayed registration could occur after reviewers or builders have seen released matching results and selected the final trigger.

The subsequent wealth test would still be forward from its own midnight. CS2.3 would not be an unfitted check.

**Smallest fix:** require registration before the protected window is released, with no protected-derived information reaching anyone selecting or reviewing the unfrozen replica. If that deadline is missed, CS2.3 needs a new untouched window.

Starting CS2.3 before the registration is not itself fatal if the entire interval remains genuinely sealed. The missing release deadline is.

## 4. Leakage and execution

### F8 — Step 6 explicitly sends protected information into selection

**Outcome changed:** leak of protected data into the venue and registration.

The delays are chosen from “the forward record’s slowest cadence of quotes.” That statistic is derived from the protected window. It reaches parameter selection and then unfrozen-work reviewers.

Calling it metadata does not satisfy the user’s stated embargo.

It is also ambiguous: “slowest cadence” could mean a cadence regime, the slowest stream, or the longest outage.

**Smallest fix:** derive delays from recorder configuration or allowed pre-November evidence, using an exact rule fixed before inspecting protected data. Protected-window integrity diagnostics must remain isolated from research and selection.

### F9 — The directory-list test does not enforce the trigger’s split

**Outcome changed:** contamination of the September–October check, potentially protected-data leakage.

A file named `20260831.json` can contain September fills. A fit session can also read an absolute path outside its directory. Listing its local filenames detects neither.

Kernel admission protects engine runs, not a model reading raw responses.

**Smallest fix:** provide a content-validated, date-filtered training export to a fresh session with access restricted to that export. Keep held-back and protected files outside its accessible filesystem and context.

September–October should also be described as development validation rather than wholly untouched evidence: the supplied fact pack already exposes summaries from those months, including quantities used to choose the matching tolerance.

### F10 — Release necessarily changes the hashes that forward execution requires unchanged

**Outcome changed:** no registered forward result can be produced.

The protected-windows file is compiled into the executable. A release changes that file, the executable and the run identity. Registration stores the engine build and protected-file hash; `study2 forward` refuses mismatches.

Therefore:

1. The registered executable refuses the protected dates.
2. The released executable does not match the registration.

**Smallest fix:** preregister an exact release-only transition: separately identify frozen computational semantics and the authorized release-state successor. Permit no other source change. Test both the authorized transition and an unauthorized computation change.

This is an execution-contract change, not a market-domain restriction.

### F11 — Monthly full-run failure can erase an earlier valid crossing

**Outcome changed:** loss of an “earned” or “outgrew” result.

Construct a month in which “outgrew” first occurs on day 10, followed by a missing funding event on day 11. If the engine runs the month before `confirm` reads its report, `finish` aborts and publishes no rows. The criterion says the test ended on day 10, yet the implementation never obtains that result.

The same issue affects an earlier “earned” crossing that must stand despite a later ledger end or recording failure.

**Smallest fix:** specify chronological, completed-prefix judging. Terminal-day runs must finish and be recorded without depending on later data. Add an integration test with a valid crossing followed by an aborting event—not merely a synthetic wealth table.

## 5. Fable’s four questions and the remaining brief

### F12 — The proposed taker-print veto is neither specified nor proof that the quote stood

**Outcome changed:** whether a CS2.1 crossing is reported.

A genuine print at 5 occurs 59 seconds before an arriving fill. At arrival the real ask is 100, but a corrupt snapshot says 5. With `G = 60 seconds`, the proposed print join can accept the fictitious fill even though no ask stood there then.

A print establishes a trade at its own time, not a standing quote at the simulated arrival.

**Smallest fix:** decide before commitment whether this additional veto exists. If adopted, specify its direction, interval endpoints, aggressor and size requirements, claim-prefix scope, and effect on the licensed verdict. Freeze it and test it.

Describe it as a data-quality screen, not an execution certificate. Never repair the ledger by deleting an unsupported losing fill or selectively replacing fills after seeing the result.

The other three questions resolve as follows:

- **“More than half”:** keep it only for the exact descriptive majority statement in F4.
- **Fills without placements:** acceptable for measuring first-fill correspondence; insufficient for identifying placement decisions. Certified placements would support a different study.
- **CS2.2’s units:** keep the ledger’s absolute return units. Normalizing by the basket can hide the very loss of volatility that lengthens confirmation time. Report basket-normalized changes as a diagnostic.

### Brief checks that need tightening

**F13 — The bootstrap’s preservation claims exceed its construction.**  
**Outcome changed:** the forecast and selected pair.

Fourteen-day blocks do not guarantee that a 10.6-day cycle stays together: a block boundary can cut it. Uniform circular starts also do not preserve weekday phase; 212 is not divisible by seven.

**Smallest fix:** retain the fully specified circular bootstrap if desired, but withdraw those guarantees and label the block length a planning choice. If weekday alignment is genuinely required, specify a different resampling rule before running it. The 7- and 28-day sensitivities are useful.

The count is otherwise correct: 52 complete fourteen-day blocks plus two days makes 730.

**Readiness notes, not new statistical criteria:**

- Step 2 test 4 can pass with **every** real order classified as a mismatch. It checks exhaustive classification, not ladder fidelity. Do not cite its passing as evidence of fidelity; report its actual counts.
- Step 3’s empty-trigger and every-minute controls are useful and non-vacuous.
- `matched`’s maximality theorem and counterexample prevent a constant-zero matcher; `held` still needs F3.
- Step 5’s “no coin moves ⇒ bar 1” fixture must also exclude funding and settlements. Constant quoted prices alone do not imply a bar of 1.
- Specify bootstrap chaining across listing ends and undefined initial prices, or explicitly restrict that bootstrap’s domain. Repeatedly resampling a listing end cannot silently resurrect a coin.
- The proposed reduction from 10,000 paths to 1,000 changes the prescribed selector. It needs a recorded specification revision, not an undocumented runtime fallback.
- Step 0 should precede study-specific fitting and checks, not merely step 4’s first price read, to match `criteria-process.md`.

The deferred disk decision is already explicit. I do not reopen it or make purchasing storage a criterion. Its stated consequence—an early, uninformative end and potentially lost irreplaceable recordings—must remain visible.

## 6. `KERNEL.md`: short read

### F14 — D56 needs to preserve A6’s simultaneous admission order

**Outcome changed:** fills, cycle endings and ledger wealth.

A18 says arriving wishes are processed in send order. A6 requires simultaneous admissions to put reduce-only orders first, then use coin/slot order.

With a buy slot preceding a closing sell slot, both arriving together, send-order processing can establish the opposite arrival priority at the next quote. Closing first can end the cycle and cancel the buy; buying first can add exposure before closing.

**Smallest fix:** explicitly distinguish arrival collection from admission: simultaneous arrivals are reconciled/admitted in A6’s order, preserving order within a slot where relevant. Add the buy-before-close program as a fixture.

### F15 — D65 cannot recover a fee rate at a zero-price settlement

**Outcome changed:** ledger termination or failed replay on an expressly admitted settlement.

A long settles at zero. Its flow has nonzero sold units, zero cash and zero fee. The recovered price is zero, but the proposed fee-rate reconstruction is \(0/0\).

Zero-price settlement was deliberately admitted and handled in round 6.

**Smallest fix:** dispatch by flow kind and define a settlement’s fee rate as zero without division. Test that `confirm` disposes of all test units and continues with the correct cash and remaining holdings.

### O6 — The whole-number exception must be certified and encoded

**Outcome changed:** rejection or premature termination of the forward run.

The precise problematic price is **100,001**, not 100,000: 100,000 itself has only one significant figure. Under the written five-figure grid, prices around that magnitude are spaced by ten, so 100,001 is rejected.

If the venue’s documented rule permits arbitrary integer prices, it is an **alternative** to the significant-figure restriction, not an increase in `figures`.

**Smallest fix:** obtain the official certificate and define the allowed-price set and rounding from it. Test 99,999, 100,000, 100,001, and fractional prices around the boundary. Retain A2’s independent numeric-range limit.

The rest of D51–D66 does not, on this read, require abandoning part A. O7 remains outside study 2’s unlevered scope.

## Closing ledger

| Status | Point |
|---|---|
| **Kept** | Exact self-financing test ledger; certified benchmark; two rungs; threshold 20; conditional joint 5%; guard as refusal and quoted negative control only. |
| **Open—criteria** | F1–F4: licensed sentences, centered volatility, zero denominator, and matching interpretation/sample gate. |
| **Open—registration and isolation** | F5–F10: fixed proposers, coverage rule, release deadline, protected-cadence leak, training isolation, authorized release transition. |
| **Open—execution** | F11–F13: completed-prefix judging, taker-veto decision, bootstrap specification. |
| **Open—kernel wording/encoding** | F14–F15 and O6. |
| **Notes only** | Calendar-year wording, non-certifying ladder classification test, explicitly narrowed bootstrap fixtures, already-deferred disk choice. |

**Plain verdict: not ready to commit.** Resolve the result-changing definitions and freeze/disclosure contracts first. Most fixes are local; none currently requires reopening the converged wealth or benchmark design.
