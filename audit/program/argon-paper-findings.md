# Argon's 14 findings on the paper: the architect's opinion (for architecture revision 4)

Written 2026-11-11 21:17 UTC (16:17 EST) by Claude Fable 5.2, session "architect: revision 4", and finished 2026-11-11 21:32 UTC (16:32 EST) by session "architect: revision 4, finish", which checked every number against the script's output and added the table at the end. It replaces the opinion written for revision 2 (`git show 337619f:audit/program/argon-paper-findings.md`). **Status:** the human accepted the first opinion's three recommendations on 2026-11-11 15:16 UTC (10:16 EST) and added finding 11 to the defect table on 2026-11-11 20:41 UTC (15:41 EST) (`audit/decisions.md`). What is new here and not yet decided is small: the reasons for findings 7 and 10, and finding 11's share.

**Read, for the first opinion:** Argon's review (`audit/reviews/2026-11-10-argon-web-paper-math.md`), GPT's line on each finding (`audit/reviews/2026-11-10-gpt-rearchitecture.md`, last section), and the paper's Sections 2.1, 8, 10 to 12, 15 to 17 and appendices S1 to S5, E1, E2, T4. **Read since:** Argon's two later reviews of the architecture, which return to findings 4, 7, 10 and 11 (`audit/reviews/2026-11-11-argon-web-rearchitecture-r2.md`, finding 8; `…-r3.md`, finding 7). **Not read:** the kernel, `gate/gate.py`, `gate/NULLS.md`, the audit records behind the paper's counts. **Run:** `audit/program/arithmetic.py.txt`, whose last block rechecks the numbers below.

**In one paragraph.** Thirteen of the fourteen hold in substance: two with Argon's numbers corrected (4, 10), and one that I rejected and now accept (11). One holds in part (7). None flips a recorded pass or failure: the pilot promoted nothing, and every defect here would make a promotion less trustworthy, not a non-promotion. One changes the program (1). One changes a check the program runs (14). Three narrow what a recorded pass may be said to show (4, 6, 10). The rest concern machinery that is parked.

## The findings

Each entry gives: whether it holds; what it changes; what to do. "Fix now" edits are in `paper-changes.md`, part B. "Mark" means a row in the paper's defect table (`paper-changes.md`, part C).

### 1. The power formula ignores the bet's cap (S4a, Sections 8 and 10)

- **Holds,** and Argon's third review takes it further: the cap is the gate's choice of loss bound, not a property of exact tests.
- **Changes the program.** The wall has three columns. At 91 days: 4.98 on the yardstick, 5.87 for an exact test at Kelly's fraction, 27.6 for the gate. At two years: 1.76, 2.07 and 4.0. Kelly's fraction fits under the cap while a step's worst loss is at most 23.4 of its standard deviations at Sharpe 2; the gate's bound is 100. C2.6's failure is the calendar and the gate's cap together (`architecture.md`, 2.2 and 2.3).
- **Fix now:** the abstract, Section 10, S4a, the roadmap.

### 2. The reported floor of −1 (Section 6's bounded returns, Section 8, S3)

- **(a) Mean-based search tests on capped returns have a positive null mean. Holds.** It can only pass more candidates to the holdout, which is the step that controls error.
- **(b) A path that later goes bankrupt can be promoted on its running maximum. Holds as a fact, not as an error of level:** Ville's bound is on the maximum. It is a defect of the promotion rule.
- **(c) The frozen pilot's bankruptcy resurrection breaks S3's "their running maxima agree". Holds.**
- **Changes parked machinery,** and bears on study 1 in one place. Study 1 scores picks on the frozen kernel, so a resurrected program has a score. Its measure is a majority over twin pairs, which a program that cannot read funding does not win, and wall 3 of `architecture.md` 5.5 tests exactly that before any session.
- **Mark** (a), (b) and (c).

### 3. The loss bound of −2 (E2, against E1 and D1)

- **Holds as an inconsistency.** E2's 0.448 credits the fourth hour's funding to a position that the model closes at the bar's adverse wick, which is D1's settlement order. Under a chronological order the loss is 0.512 a unit of notional and the return can reach −2.07. E1's sentence reads as the chronological order. So the paper states two orders. Which one the corrected engine implements I did not check.
- **Changes parked machinery only.** It blocks a revived gate.
- **Mark.** Before revival: one order in E1, D1 and E2, and `m` re-derived under it.

### 4. The pooled stage 4 bound (Section 17, S4)

- **Holds in part.** Argon's recount to 13 rests on a misreading: v2's "two counted campaigns" are the two in which an agent got no evaluation. The right reason is GPT's: three versions, each stopped and redesigned after the one before, are not one procedure sampled 22 times, so 0.133 and 0.198 bound nothing that was defined in advance.
- **Changes a recorded result's summary,** not its judgment. C4.5 v3 passed as written, and S4 gives its own bound, 26% for no promotion in ten.
- **Fix now:** withdraw the pooled bounds in Section 17 and keep the counts.

### 5. The mechanism check passes selected noise (Sections 8 and 9, S5)

- **Holds.** With a fifth of the exposure in a regime three times as volatile, a null strategy selected at `z` = 3 passes the sign check with probability 0.999.
- **Changes parked machinery only.** A filter can only remove candidates. It removes almost nothing.
- **Mark.**

### 6. C2.5 is met by any gate that seldom promotes (Section 17, S4)

- **Holds.** C2.5 bounds the false discovery rate, which counts a campaign with no promotion as zero. A cell that promotes in at most 7 of 100 campaigns meets the cutoff 0.0776 whatever it promotes.
- **Changes a qualification.** C2.5 stays met as written. It shows that few campaigns promoted, not that a promotion is reliable.
- **Fix now:** one sentence in Section 17 and one in S4.

### 7. The deflated Sharpe ratio (Section 8, S2, S5)

- **Holds in part,** and Argon's two later points do not add to it.
  - *Non-monotone in the Sharpe ratio:* true of the formula, which is Bailey and López de Prado's own.
  - *A ceiling that no Sharpe passes:* does not hold for sample moments. The limit of the statistic as the Sharpe grows is under 1.645 only above a kurtosis of 807 at 546 steps, and a sample of 546 returns has kurtosis below 546.
  - *Sharpe 3.5 fails over 91 days* (third review): against a threshold of 2 its `z` is at most 0.75. So is any test's. That is the wall, not a defect.
  - *The radicand can be negative for positive skewness* (third review): not for a sample. A sample's kurtosis is at least its skewness squared plus one, so the radicand is at least `(1 − skewness·S/2)²`. Argon's example, skewness 4 with kurtosis 10, is no sample's. This holds for moments computed with the same divisor; one property test of the gate's own estimator would confirm it, and it is noted, not acted on, since a crash promotes nothing.
  - *The largest of several `N` is always the raw count:* true. Section 8's step 2 describes a maximum that never binds.
- **Mark** the last point. Nothing else.

### 8. N2's innovations are not Student t (D1, Section 17)

- **Holds as a description.** `gate/markets.py` mixes two truncated t5 draws, and a mixture has kurtosis `9 − 12λ²(1 − λ²)` before truncation.
- **Changes nothing judged.** Study 1 compares two arms on the same markets, so its test does not depend on the innovations' law.
- **Fix now:** one clause in D1, and the same in `gate/NULLS.md`, line 63.

### 9. The plug-in bet is a switch (Section 8, S3)

- **Holds.** After the first step the bet is `min(1/2, 1/r₁)`, so any positive first return sets it to the cap. Validity is untouched; power is not what S3's Kelly motivation suggests.
- **Changes parked machinery only.** The confirmer of `architecture.md` 2.2 registers one fraction before the data, for this reason.
- **Mark.**

### 10. The v3 locked suite's tolerances (Section 17, S4)

- **Holds, with corrected numbers and one clause that does not.** The suite passes a cell when the upper confidence bound of its rejection rate, at confidence `1 − 0.05/99`, is under a tolerance of 0.0625, 0.015 or 0.01. Argon's third review says the Bonferroni level is applied in the wrong direction. It is not: a higher confidence makes each cell harder to pass. What holds is that the suite certifies the tolerance, not the nominal level. A true rate of 0.056 at level 0.05 passes 72% of the time, 0.012 at 0.01 passes 62%, and 0.0075 at 0.005 passes 65%, each because it is inside its tolerance.
- **Changes a qualification.** The v3 pass stands. It shows a size of at most the tolerance, and the test's nominal level rests on the proof and the return bound (findings 2 and 3).
- **Fix now:** one sentence in S4.

### 11. The bootstrap's block length (Section 8, S5)

- **Holds, at the variance share of a hedged funding book.** I rejected this on the ground that a predictable position's returns are martingale differences under the null. That is wrong where funding is a persistent, paid component of the return. Funding's autocorrelation gives its part of the variance of the mean a long-run factor of 83, of which blocks of mean six keep 9.7. So the bootstrap understates the variance of the mean by `(1 − w + 83w) / (1 − w + 9.7w)`, where `w` is funding's share of a step's variance: 1.002 for a directional position (`w` = 2.5·10⁻⁵), 1.1 at a share of 0.0014, and 3.6 to 6.8 at shares of 0.05 to 0.25, Argon's range for a book whose price risk is hedged. A `t` statistic is then overstated by 1.9 to 2.6.
- **Changes parked machinery,** in the one family the program plants: study 1's plant is a funding edge. Study 1 does not use the bootstrap. `w` on the pilot's markets is not measured, and Argon's range is a lead.
- **Mark.** Before the gate judges a funding strategy: measure `w` for the judged book, and derive the block length from the funding process's persistence.

### 12. The licensing boundary's attack suite (Section 11, D3)

- **Holds.** Three reports over cells of permitted size recover one date's value exactly, and none of the four attack patterns covers it. This is the tracker attack of the statistical database literature (Denning and Denning 1979; Dinur and Nissim 2003; *leads*).
- **Changes parked machinery,** with one live consequence: the boundary is the rule under which reviewers and agents may see aggregates of kernel-only sources.
- **Mark, and act on the rule now:** no kernel-only aggregate crosses until a redesigned boundary is reviewed. The advisor should confirm that none is crossing today; I did not check.

### 13. Table 1's noise ceiling (Section 2.1, S1)

- **Holds.** The table uses the leading term `√(2 log N)`. The expected maximum of ten Gaussians is 1.54, not 2.15; of a thousand, 3.24, not 3.72.
- **Fix now:** the table's nine entries.

### 14. The stage 1 canary (Section 17, K1)

- **Holds.** Over 550 days the standard error of an annualized Sharpe is 0.81, so a leak worth Sharpe 2 stays under the alarm at 4 in 99.3% of single runs.
- **Changes the program:** study 1's measure is itself calibrated before use, on programs known to earn from the plant and programs known not to (`architecture.md` 5.5, walls 2 and 3). C1.7 stays met.
- **Fix now:** one sentence in K1 stating the power.

## Recommendation

1. **Fix now, in the paper:** findings 1, 4, 6, 8, 10, 13 and 14.
2. **Do not repair parked machinery now:** findings 2, 3, 5, 7, 9, 11 and 12. Each repair is a design with its own review, for code no study runs.
3. **Carry the known-wrong claims openly,** in the paper's defect table. A row leaves the table only in the commit that re-derives its claim, after review. No parked item is revived with a row still open against it.
4. **One rule changes today whatever else is decided:** no kernel-only aggregate crosses the licensing boundary until it is redesigned (finding 12).

What I am least sure of: finding 3, because I did not read which settlement order the corrected engine implements; finding 11's share, which nobody has measured; and finding 4's history of what changed between the swarm's three versions, which I took from the paper's own account.

## Where each finding lands

`paper-changes.md` holds the edits: part A the program, part B the fixes, part C the defect table.

| Finding | Verdict | Lands in |
|---|---|---|
| 1 | Holds | A2, A7 (the wall's three columns; S4a) |
| 2a, 2b, 2c | Hold | C, rows 2a to 2c |
| 3 | Holds as an inconsistency | C, row 3 |
| 4 | Holds in part | B, Section 17 |
| 5 | Holds | C, row 5 |
| 6 | Holds | B, Section 17 and S4 |
| 7 | Holds in part: the maximum that never binds | C, row 7 |
| 8 | Holds as a description | B, D1; `gate/NULLS.md` in part D |
| 9 | Holds | C, row 9 |
| 10 | Holds: the suite certifies the tolerance | B, S4; C, row 10 |
| 11 | Holds at a hedged book's funding share | C, row 11 |
| 12 | Holds | C, row 12; the rule is in force |
| 13 | Holds | B, Table 1 and S1 |
| 14 | Holds | B, K1 |
