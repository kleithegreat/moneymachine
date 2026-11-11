# Argon's 14 findings on the paper: the architect's opinion

Written 2026-11-11 08:41 UTC (03:41 EST) by Claude Fable 5.2, session "architect: revision, part 2". An opinion for the human to decide on. Nothing here is in force.

**Read:** Argon's review (`audit/reviews/2026-11-10-argon-web-paper-math.md` on `main`), GPT's line on each finding (`audit/reviews/2026-11-10-gpt-rearchitecture.md`, last section), and the paper's Sections 2.1, 8, 10 to 12, 15 to 17 and appendices S1 to S5, E1, E2, T4. Section numbers are this branch's (gate 8, mechanism 9, wall 10, multi-asset 11, roadmap 16, findings 17); Argon's bundle numbered them differently. One line of `gate/markets.py` (189) for finding 8. **Not read:** the kernel, `gate/gate.py`, `gate/NULLS.md`, the audit records behind the paper's counts. **Run:** `audit/program/arithmetic.py.txt`, whose last block rechecks the numbers below.

**In one paragraph.** Twelve of the fourteen hold in substance, two of them with Argon's own numbers corrected (4, 10). One holds in part (7), and one does not hold as stated (11). None flips a recorded pass or failure: the pilot promoted nothing, and every defect here would make a promotion less trustworthy, not a non-promotion. One changes the program and is already in the architecture (1). One changes a check the program runs (14). Three narrow what a recorded pass may be said to show (4, 6, 10). The rest concern machinery that is parked.

## The findings

Each entry gives: whether it holds, with GPT's line; what it changes; what to do and when. "Fix now" edits are listed in `paper-changes.md`. "Mark" means a row in the paper's defect table (see the recommendation).

### 1. The power formula ignores the bet's cap (S4a, Sections 8 and 10)

- **Holds.** I agree with GPT. Reproduced: at 2% a step and Sharpe 4.9, Kelly's bet is 5.2 against a cap of 0.5, expected log wealth over 546 steps is 0.54 against 3.0, and the capped bet needs Sharpe 26.
- **Changes the program.** The wall has two numbers, 4.98 on the Gaussian yardstick and 26 for the gate's test. C2.6's failure is the calendar and the gate's cap together. An earlier-cutoff campaign needs a re-derived confirmer (`architecture.md`, sections 2.2, 2.3 and 4).
- **Fix now:** the abstract, Section 10, S4a, the roadmap.

### 2. The reported floor of −1 (Section 6's bounded returns, Section 8, S3)

Three claims.
- **(a) Mean-based search tests on capped returns have a positive null mean. Holds,** and S3 already states the identity that shows it. It can only pass more candidates to the holdout, which is the step that controls error.
- **(b) A path that later goes bankrupt can be promoted on its running maximum. Holds as a fact, and is not an error of level.** I agree with GPT: Ville's bound is on the maximum. It is a defect of the promotion rule, which should require the finalist to end above its start.
- **(c) The frozen pilot's bankruptcy resurrection breaks S3's "their running maxima agree". Holds.** S3's proof needs later returns to be zero, and the paper's own defect list says the pilot kernel does not guarantee it.
- **Changes parked machinery only.** No finalist ever reached the holdout, so no recorded result used the claim. GPT ties it to study 1; I disagree in part: study 1 judges holdings and reads no return, so absorption matters there only for when a holding ends, which brief 1 asks the design to specify.
- **Mark** (a), (b) and (c). Clear them before the gate's holdout test judges anything again.

### 3. The loss bound of −2 (E2, against E1 and D1)

- **Holds as an inconsistency, not as an error in the algebra.** E2's 0.448 credits the fourth hour's funding to a position that the model closes at the bar's adverse wick. That is D1's stated settlement order: funding settles at the boundary, then the stop-out is priced at the wick. Under that order the bound is as derived. Under a chronological order, where the wick comes before the boundary, Argon's arithmetic is right: the loss is 0.512 a unit of notional and the return can reach −2.07. E1's sentence, that the position which held the hour pays for it, reads as the chronological order. So the paper states two orders. Which one the corrected engine implements I did not check.
- **Changes parked machinery only.** I agree with GPT that it blocks a revived gate. Neither study judges the betting bound.
- **Mark.** Before revival: state one order in E1, D1 and E2, and re-derive `m` under it. If the order is chronological, the stop-out multiple or the clips must tighten.

### 4. The pooled stage 4 bound (Section 17, S4)

- **Holds in part.** Argon's recount to 13 rests on a misreading: v2's "two counted campaigns" are the two in which an agent got no evaluation, not seven. GPT's reason is the right one: three versions, each stopped and redesigned after the one before, are not one procedure sampled 22 times, so 0.133 and 0.198 bound nothing that was defined in advance.
- **Changes a recorded result's summary,** not its judgment. C4.5 v3 passed as written, and S4 already gives its own bound, 26% for no promotion in ten.
- **Fix now:** withdraw the pooled bounds in Section 17 and keep the counts. Section 10's "21 known non-promotions of 22" is a count and stays.

### 5. The mechanism check passes selected noise (Sections 8 and 9, S5)

- **Holds.** Reproduced: with a fifth of the exposure in a regime three times as volatile, a null strategy selected at `z` = 3 passes the sign check with probability 0.999. I agree with GPT that a check conditioned on selection is not independent evidence. Section 9 and S5 already say the check is weak; they do not say it is this weak.
- **Changes parked machinery only.** A filter can only remove candidates, so it cannot raise false promotions. It removes almost nothing.
- **Mark.** When the gate is revived, the mechanism is tested on data the selection did not use, or it is dropped.

### 6. C2.5 is met by any gate that seldom promotes (Section 17, S4)

- **Holds.** I agree with GPT: C2.5 bounds the false discovery rate, which counts a campaign with no promotion as zero. A cell that promotes in at most 7 of 100 campaigns meets the cutoff 0.0776 whatever it promotes. The paper's reported cells promoted in 0 and in 5.
- **Changes a qualification.** C2.5 stays met as written. It shows that few campaigns promoted, and not that a promotion is reliable. Its single-cell penalty across several cells is a second, smaller gap.
- **Fix now:** one sentence in Section 17 and one in S4. A criterion on promotions' reliability is written new if the gate is revived.

### 7. The deflated Sharpe ratio (Section 8, S2, S5)

- **Holds in part.** I agree with GPT.
  - *Non-monotone in the Sharpe ratio:* true of the formula, which is Bailey and López de Prado's own. The turning point is a per-step Sharpe of about two divided by the skewness: at skewness 5, an annualized Sharpe near 19.
  - *A ceiling that no Sharpe passes:* does not hold for sample moments. The ceiling falls below 0.95 only above a kurtosis of about `1 + 1.48(T − 1)`, and a sample of `T` returns has kurtosis below `T`.
  - *The largest of several `N` is always the raw count:* true. Section 8's step 2 describes a maximum that never binds.
- **Changes parked machinery only,** and only its description.
- **Mark** the third point. Nothing else.

### 8. N2's innovations are not Student t (D1, Section 17)

- **Holds as a description.** `gate/markets.py` mixes two truncated t5 draws, and a mixture has kurtosis `9 − 12λ²(1 − λ²)` before truncation. I agree with GPT that the infinite fourth moment does not apply: the generator truncates and caps. Whether this caused C2.2's first failure is Argon's guess.
- **Changes nothing judged.** C2.2 passed on the generator as implemented. Study 1 runs on N2 and compares two arms on the same markets, so its test does not depend on the innovations' law.
- **Fix now:** one clause in D1. It costs nothing and study 1's section will cite the generator.

### 9. The plug-in bet is a switch (Section 8, S3)

- **Holds.** After the first step the bet is `min(1/2, 1/r₁)`, so any positive first return sets it to the cap, and at 2% volatility and under the null the estimate sits inside (0, 1/2) less than a tenth of the time. I agree with GPT: validity is untouched, since the bet is predictable and capped, and power is not what S3's Kelly motivation suggests.
- **Changes parked machinery only.** It is a second reason, beside the cap, that the gate's test is not the confirmer an earlier-cutoff campaign needs.
- **Mark.** The re-derived confirmer replaces the rule; study 2's stake rule is unrelated to it.

### 10. The v3 locked suite's tolerances (Section 17, S4)

- **Holds, with corrected numbers.** The tolerances were kept from the asymptotic tests the betting test replaced. By exact Clopper–Pearson bounds, Argon's two examples (160 and 248 rejections) fail, narrowly. But an implementation whose true rate is 0.0075 at level 0.005 passes 65% of the time, and one at 0.012 at level 0.01 passes 62%. I agree with GPT that the suite cannot certify nominal size.
- **Changes a qualification.** The v3 pass stands. It is an implementation check of that resolution, and the test's level rests on the proof and the return bound (findings 2 and 3).
- **Fix now:** one sentence in S4. On revival, the suite's recorded counts are re-read against the levels themselves, which needs no new run.

### 11. The bootstrap's block length (Section 8, S5)

- **Does not hold as stated.** I agree with GPT. The factor 8.5 assumes that a strategy's returns are autocorrelated at the weekly scale. Under the null the returns of a predictable position are martingale differences: funding persists, the return's mean does not. Persistent variance is real and a mean block of six steps treats it roughly, which S5 already calls a heuristic choice.
- **Changes nothing.**
- **Nothing.** The block length is re-derived with the screens if the gate is revived.

### 12. The licensing boundary's attack suite (Section 11, D3)

- **Holds.** Three reports over cells of permitted size recover one date's value exactly, and none of the four attack patterns covers it. This is the tracker attack of the statistical database literature (Denning and Denning 1979; Dinur and Nissim 2003; *leads*): exact answers to enough overlapping aggregate queries reconstruct the rows, and a list of attack patterns cannot certify otherwise.
- **Changes parked machinery,** with one live consequence. Stage 8 is superseded, but the boundary is the rule under which reviewers and agents may see aggregates of kernel-only sources. I agree with GPT: superseding the stage does not dissolve it.
- **Mark, and act on the rule now:** no kernel-only aggregate crosses until a redesigned boundary is reviewed. The redesign fixes the partition of dates in the class annex, independent of any strategy, or adds noise under a stated budget. `criteria-notes.md` carries this in stage 8's note. The advisor should confirm that no kernel-only aggregate is crossing today; I did not check.

### 13. Table 1's noise ceiling (Section 2.1, S1)

- **Holds.** The table uses the leading term `√(2 log N)`. The expected maximum of ten Gaussians is 1.54, not 2.15; of a thousand, 3.24, not 3.72. S1 already says so for one cell and the table ignores it.
- **Changes nothing judged.** I agree with GPT.
- **Fix now:** the table's nine entries, from the quadrature in the script.

### 14. The stage 1 canary (Section 17, K1)

- **Holds.** Over 550 days the standard error of an annualized Sharpe is 0.81, so a leak worth Sharpe 2 stays under the alarm at 4 in 99.3% of single runs. K1 already says the canary has no calibration of detection.
- **Changes the program:** study 1's third model-free check exists for this (`architecture.md`, section 6). C1.7 stays met.
- **Fix now:** one sentence in K1 stating the power. The stage 1 qualification is drafted in `criteria-notes.md`.

## Recommendation

1. **Fix now, in the paper, what the program rests on or what summarizes a recorded result:** findings 1, 4, 6, 8, 10, 13 and 14. All are small, each is a derivation I can state today, and `paper-changes.md` lists them. Append the four qualifications drafted in `criteria-notes.md` (stages 1, 2 and 4).
2. **Do not repair parked machinery now:** findings 2, 3, 5, 7, 9 and 12. Each repair is a design with its own review, for code no study runs, and it would be spent before knowing whether that code returns.
3. **Carry the known-wrong claims openly.** The paper gets one short appendix paragraph, "Known defects of parked machinery", with a table: the claim and where it is stated, what is wrong, the review that found it, and what must be re-derived before the machinery judges anything. Each affected passage gets a pointer to its row and is otherwise left as written, since it describes what the frozen pilot ran. A row leaves the table only in the commit that re-derives its claim, after review. The table is the precondition list of the parked items in `architecture.md`, section 4: no parked item is revived with a row still open against it.
4. **One rule changes today whatever else is decided:** no kernel-only aggregate crosses the licensing boundary until it is redesigned (finding 12).
5. **Finding 11 is recorded as not accepted,** with the reason above, so that it is not raised again.

What I am least sure of: finding 3, because I did not read which settlement order the corrected engine implements; and finding 4's history of what changed between the swarm's three versions, which I took from the paper's own account.
