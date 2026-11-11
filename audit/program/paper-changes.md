# Paper changes for architecture revision 4

Written 2026-11-11 21:36 UTC (16:36 EST) by Claude Fable 5.2, session "architect: revision 4, finish". It replaces the list written for revision 2 (`git show 9e5240b:audit/program/paper-changes.md`), none of which was applied. An edit list for a builder, authorized by the human's decisions of 2026-11-11 15:16 UTC (10:16 EST), 20:41 UTC (15:41 EST) and 21:26 UTC (16:26 EST) (`audit/decisions.md`). Line numbers are those of `docs/whitepaper.tex` at `85764b6`, its last change.

- "Architecture" means `audit/program/architecture.md`, revision 4 (`44fb5ae`). "Script" means `audit/program/arithmetic.py.txt`, whose functions are named in the Source column. Where this list and the script disagree, the script is right and the list is a defect.
- New text is given as prose to typeset, not as final wording, except where quoted.
- Apply parts A to C in one commit with the rebuilt PDF (`TMPDIR=/tmp nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`), and part D in a second.
- Afterwards, grep the paper for `stage 11`, `live size`, `retail`, `event contract`, `week 26`, `information rate`, `by the hundred`, `any valid test`, `4.9` and `0.133`. None may remain in a sentence about the program.

## A. The program

### A1. The framing: an academic study, and the machinery as an aim

| Where | Old claim | New claim | Source |
|---|---|---|---|
| Title (38) | "Draft white paper, revision 8" | "revision 9" | |
| Abstract (48) | "at that length no test can confirm an edge of ordinary Sharpe" | At that length a test of fixed length has 80% power only near Sharpe 5, an exact test near 5.9, and the pilot's own gate near 28 | Architecture 2.3; `yardstick`, `exact_cost`, `confirmer` |
| Abstract (48) | "The program that follows asks two questions where observations are plentiful", then the positive control and the event-contract study | The paper is a study of what can and cannot be confirmed about an agent's edge, and the research system is one of its two products. The program is the wall with matched numbers and two positive controls: whether the agent finds an edge that exists (synthetic markets), and whether the confirmer confirms a rule that plausibly has one (a replication of a published strategy, judged forward) | Architecture, the result; the human, 2026-11-11 20:41 UTC (15:41 EST) and 20:57 UTC (15:57 EST) |
| Motivation (57) | "The question for retail traders is how much of this structure carries over to strategy research" and the comparison of retail with institutions | The question is how much of this structure carries over to strategy research, and what a verifier can honestly confirm there. Delete the sentences on what retail can and cannot match | The human, 20:41 UTC (15:41 EST) |
| Figure 1 (114) | The last node, "Paper trading, then small live size", and its arrow | Delete both. The holdout test is the last node | Stage 11 is gone |
| Section 11, venue eligibility (443) | "an operator in one of them cannot assume access ... Live trading must use a venue the operator is permitted to access" | Keep the fact about the interface. Replace the consequence: the program reads Hyperliquid's public data under its certificates and trades nowhere, so a venue need not be tradeable by the operator | Architecture, section 3 |
| Section 12, opening (449) | "The research direction we consider most promising for an agent-assisted retail trader is discretionary, event-driven macro" | The direction the project first judged most promising for a reading agent was discretionary, event-driven macro. Section 10 and the roadmap say why no forward study of it has honest power today | Architecture, section 4 |
| Section 13, title and opening (480, 482) | "Research directions for retail edge"; "where a small account might compete" | "Research directions"; "where an edge might exist". Add one sentence: each is a frozen rule under the wall, confirmable forward only at a Sharpe near 2 within two years | Architecture 2.3 |

### A2. Section 10, the confirmation wall (370 to 407): the finding on Q3

1. **Opening (372).** Old: "no edge of ordinary size can be confirmed, by this gate or by any valid test". New: this section is the paper's finding on whether anything an agent proposes can be shown to earn a positive expected net return (Q3). At the lengths a frontier model allows, an edge of ordinary size cannot be confirmed. The threshold depends on the test, so it is stated for three, at matched power. Source: architecture 2.3.
2. **The arithmetic (374).** Keep through the Bailey and López de Prado sentence. Delete from "The gate's betting test pays for validity" to the paragraph's end. Add: this yardstick assumes independent, near-Gaussian observations and a fixed length. It is a planning reference, not a test. Source: 2.1.
3. **New paragraph after the arithmetic, "The exact test and what it costs".**
   - A test that assumes only its null is a bet (Ville; Kelly; Shafer; Waudby-Smith and Ramdas). If each return is at least `−L` with non-positive conditional mean, wealth bet at a predictable fraction of at most `1/L` reaches 20 with probability at most 5%, under any dependence and any stopping rule.
   - For independent even bets of net edge `e` at Kelly's fraction, log wealth is near a Brownian motion with drift `e²/2` and variance `e²` a bet. It reaches `log 20` before `N` bets with probability 0.80 at `N = 8.59/e²`, 1.39 times the yardstick's 6.18.
   - The fraction is registered before the data: a bet sized for Sharpe 2 has power 0.77 within two years at a true Sharpe of 2, 0.47 at 1.4 and 0.90 at 2.4, and averaging the bets for 1, 2 and 3 is worse at each.
   - The cap `1/L` is the rule's own loss bound. Kelly's fraction fits under it while a step's worst loss is at most `√2190/S` standard deviations of a step: 23.4 at Sharpe 2. The gate has `L = 2`, a hundred standard deviations, which is why it needs more. A bound must be a property of the tested rule: clipping a loss afterwards raises the mean and breaks the null.
   - Source: 2.2; `exact_cost`, `confirmer`.
4. **Table `tab:wall` (376 to 388).** Old: two rows by Sharpe, "Years for 80% power" and "Years for even odds". New: keep them as the yardstick, and add a second table, "The Sharpe each test needs for 80% power", with the architecture's rows:

   | Length | Yardstick | Exact test at Kelly's fraction | The gate's test, `L = 2` |
   |---|---|---|---|
   | 91 days | 4.98 | 5.87 | 27.6 |
   | One year | 2.49 | 2.93 | 7.4 |
   | Two years | 1.76 | 2.07 | 4.0 |

   Beneath it: an ordinary edge, Sharpe at most 1, takes 6.2 years on the yardstick and 8.6 under an exact test. Source: 2.3; `confirmer`.
5. **The cutoff bounds T (391).** Old: "At those lengths a test of fixed length has 80% power only at Sharpe 6.1 and 5.0, and the gate's ..." to the paragraph's end. New: keep 6.1 and 5.0 for the yardstick. At 91 days an exact test needs 5.87 and the gate 27.6. A year after the cutoff the three figures are 2.49, 2.93 and 7.4. Source: 2.3.
6. **What the pilot observed (393).** No change.
7. **What this shows (395).** Old: "The second fact is arithmetic, not a defect of the gate ... on any venue and with any kernel." New: the second fact has two causes. The calendar, which no test removes. And the gate's loss cap, a choice of that test, which raises its threshold at 91 days from about 6 to about 28. C2.6's failure is both together. For a frontier model's systematic strategy a rapid and honest confirmation is not available at ordinary Sharpe. Source: 2.2, 2.3; `argon-paper-findings.md`, finding 1.
8. **What it does not show (397).** Old: "It does not show that the gate lacks power on long holdouts." New: it does not show that no exact test does better than the gate: one with the rule's own loss bound needs 2.07 at two years where the gate needs 4.0. Keep the other sentences. Source: 2.2.
9. **How the wall moves (399 to 404).** Old: three ways, "a longer `T`", "a higher `S` through breadth", "a different observation". New: only by more independent observations, in three ways.
   - **A longer calendar.** Keep the earlier-cutoff sentences. Add: a rule that someone else froze is a longer calendar. A model's cutoff binds what the model proposes; a published rule is bound by the date we freeze our copy, and the evidence that it is worth freezing is a live record, not a backtest. This is study 2.
   - **A faster source of independent bets.** Old item 2 (Grinold's law, twenty bets once hedged) and item 3's "Forecasts of exactly resolved events arrive by the hundred each month". New: for a forward account in bounded bets, where the 5% stake cap does not bind, 80% power within two years needs independent bets a week times net edge squared of at least `8.59/104 = 0.083`: 92 a week at an edge of 0.03, 33 at 0.05, 13 at 0.08. No count has been measured for a reading agent. Keep Grinold's sentence as the reason perpetuals alone supply few.
   - **Synthetic markets,** where observations are free and which answer only whether agents search well. This is study 1.
   - Source: 2.3, section 4; `forward_account`.
10. **After the list (405).** Old: "The roadmap is built on the third. It compares designs by their information rate ...". New: the roadmap is built on the first and third, and states the second as the condition that would reopen a reading-agent study. Source: section 7.
11. **The unit of an edge claim (407).** Replace the paragraph. Old: one rule-sized paper portfolio marked each week, the calendar-time portfolio of event studies. New: overlapping bets are dependent, and dependence costs power, never validity, when the judged statistic is the cash of one self-financing account (Appendix T4). A weekly marked portfolio judged by a Student statistic is not valid under the same null. Remove the citations of `jaffe1974` and `fama1998`, and their entries if nothing else cites them. Source: section 6, the account; GPT's finding 1 on revision 1.

### A3. Section 12, the thesis track (451, 475)

1. **Two instances (451).** Old: "it is parked ... about 15 to 40 independent bets arrive a month, so the instance informs in years ... The program's forward study registers theses on exactly resolved event contracts instead, where the comparator is the market's own price and independent events arrive by the hundred." New: the track is parked entire: the code, both branches and the prewarm job. No event-contract exchange is certified, so no second instance exists. It reopens on a measured count of at least 33 near-independent bets a week on a certified venue (Section 10). Delete the event-contract sentences. Source: sections 4, 7 and 10; `audit/decisions.md`, 2026-11-11 17:25 UTC (12:25 EST) and 17:39 UTC (12:39 EST).
2. **Dependence and the protocol (475).** Old: "The unit is instead the calendar week of one marked-to-market paper portfolio (Section wall), and one pre-registered protocol judges its mean." New: a reopened study would be judged by the cash of one self-financing account (Appendix T4). Source: section 6.

### A4. Section 15, open problems (518 to 520)

| Item | Old claim | New claim | Source |
|---|---|---|---|
| Slow forward evidence | "On perpetuals the thesis track needs years ... On event contracts the same per-bet effect needs months, because independent bets arrive faster" | A reading agent's forward study needs 33 independent bets a week at a net edge of 0.05. Its count is unmeasured, and at 5 to 10 a week it needs a hit rate of 55% to 59% after costs. A frozen rule needs a forward Sharpe of about 2 for two years. Keep "forward weeks under a frozen protocol cannot be bought later" | Section 4 |
| Paper fills | "A forward result is a claim about the frozen procedure's paper portfolio" | A replay on recorded books assumes the book was there to hit. Study 2's fidelity comparison against an account that really traded is the first check of that, and a forward result stays a claim about the frozen replica | Section 6 |
| Venue and access risk | "Live trading must use a venue the operator is permitted to access ... checked during feasibility" | Delete that sentence. Keep the sentence on tail risks, as a limit on what a short record shows | Stage 11 is gone |
| New item, "An unmeasured prior" | none | The net effect a skilled forecaster keeps on a priced outcome is taken as at most 0.05 a bet. That is a prior; the benchmarks behind it test forecasting on given questions, not selection among markets | 2.4; section 11, item 7 |

### A5. Section 16, the roadmap (524 to 571)

1. **Second paragraph (528).** Old: "two studies chosen for their information rate come first. The program was derived on 2026-11-10 ... and is in force once its review is logged". New: two positive controls come first, one of the search and one of the confirmer. The program was derived on 2026-11-10 and re-derived on 2026-11-11 after four adversarial reviews (`audit/program/ledger.md`); the human approved it on 2026-11-11 21:26 UTC (16:26 EST) (`audit/decisions.md`).
2. **Item 7.** Old: "Parked, with the executable Lean engine, until a study needs it ... Neither study below does." New: the same, and add: study 2 needs limit and maker orders at any bar interval, which is version 2 of the Rust kernel, a new identity. No pilot result is rerun on it.
3. **Item 8.** Old: "The licensing boundary, the certificates and the recordings stand." New: the certificates and the recordings stand. The licensing boundary stands as a rule and its certification is a known defect (defect table, row 12).
4. **Item 10.** Old: "Restarted as study 2 below." New: parked entire (Section 12).
5. **Item 11.** Delete it. The list ends at 10. Add after the list: the project is academic, and no stage leads to live trading (the human, 2026-11-11).
6. **Designs compared and Table `tab:rates` (544 to 563).** Old: six rows by information rate, among them "The positive control: about 90 sessions ... 0.5" months and "Theses on exactly resolved event contracts: 100 to 400 ... 6 to 25; 3 to 13; 1.5 to 6". New: the architecture's section 4 table: a reading agent's bracketed theses at 5, 10, 15, 33 and 60 independent bets a week, needing net edges of 0.177, 0.108, 0.083, 0.052 and 0.039 for 80% power within two years, with power at edges of 0.03, 0.05 and 0.08 of 0.00, 0.16, 0.48 at 10 a week and 0.21, 0.76, 0.99 at 33; and a frozen rule replayed on recordings, needing Sharpe 2.07 with its own loss bound and 4.0 under the gate, with power 0.28, 0.47, 0.77 and 0.90 at Sharpe 1, 1.4, 2 and 2.4. Caption: "Forward designs on Hyperliquid, 80% power within two years, the account simulated as specified in Appendix T4." Add the settlement-timing sentence of section 4. In the paragraph, replace "applies the information rate" with "states the exact test's requirement for". Source: section 4; `forward_account`, `confirmer`.
7. **Study 1 (565).** Replace the paragraph. Old claims removed: "at the same budget"; "discovers it in a fifth of markets"; "Discovery is exact: the plant's expected gross return ..."; "0.2 against 0.5 ... truncated at 33 markets ... size 0.041, power 0.949, about 15 markets". New, in this order:
   - the claim: on synthetic markets carrying a planted funding edge, the frozen agent's session ends on a program that earns from the plant with a higher chance than G100's 100 evaluations do;
   - the two arms on every market, and the pick;
   - the measure: for each market, 32 fresh pairs, each a planted market and its twin at strength zero; a pick earns from the plant when its effect is at least half the reference's, and that is positive, on at least 24 pairs;
   - why: a pick whose chance on a pair is at most one half passes with probability at most 0.0035;
   - the strength, by bisection without a model, G100's rate between 0.13 and 0.17 on 2,000 calibration markets;
   - the test: Wald's sequential sign test on discordant markets, `θ ≤ 1/2` against 0.7, at most 100 markets, size at most 0.043;
   - power: at an agent's rate of 0.5 the claim's chance is at least 0.943 across the band and every overlap; at 0.4, 0.73 to 1.00; at 0.3 the study is not powered;
   - what each result is called, and what is not claimed.
   - Source: section 5; Appendix P1 (A9 below); `study1`, `sign_test`.
8. **Study 2 (567).** Replace the paragraph and its title. Old: "Study 2: the thesis track on event contracts", "filled at the recorded ask and marked each week at the recorded bid", "judged at weeks 26 and 52", "Whether size could trade is stage 11". New title: "Study 2: the positive control of the confirmer". New text, in this order:
   - the place of a replication: given a rule that plausibly has an edge, on evidence better than a backtest, can the confirmer confirm it within the calendar;
   - the rule: the published long-only ladder of the vault named in `audit/decisions.md` (2026-11-11 21:27 UTC (16:27 EST)), reported Sharpe 2.4 and about 1.4 recently;
   - fidelity, with no waiting: the replica run by the kernel over the archive against the vault's public record;
   - decomposition, descriptive only: the return of holding the vault's average exposure against timing;
   - forward confirmation: the hedged series on isolated margin under the exact test, the fraction registered for Sharpe 2, the claim at wealth 20, reading only steps after the freeze;
   - power within one year and two: 0.12 and 0.28 at Sharpe 1; 0.22 and 0.47 at 1.4; 0.42 and 0.77 at 2; 0.57 and 0.90 at 2.4; under no edge 0.04;
   - what it cannot establish: that an agent has edge, or that the vault's record is skill, since we know of the vault because it survived;
   - the published finding on replication (McLean and Pontiff 2016; Hou, Xue and Zhang 2020, each checked before it is cited);
   - a non-rejection is "not confirmed", with the realized Sharpe, its standard error and the power row.
   - Source: section 6; `confirmer`.
9. **Parked (569).** Old: "The perpetual instance of the thesis track: when study 2 rejects its null ... A campaign with an earlier-cutoff model: when study 1 accepts 0.5 both for ...". New: the thesis track, on a measured count of at least 33 independent bets a week on a certified venue. A campaign with an earlier-cutoff model, when study 1 reaches its upper boundary and a confirmer with the rule's own loss bound exists. Stage 7, the Lean engine and the swarm, when a study needs them, their rows in the defect table cleared first. The stage 3 forward window lapses on 2027-01-31 with nothing registered in it, and its prices stay unread. Source: section 10.
10. **Stop rules (571).** Replace. Old claims removed: "33 markets"; "at week 26 if its statistic is below zero, and at week 52 regardless"; "The program is abandoned when study 1 accepts 0.2 and study 2 ends without rejecting ... on a retail budget". New: study 1 ends at a boundary or at 100 markets, with no extension, and does not start if a model-free wall fails. Study 2 does not freeze if one of its walls fails, and its forward test ends at wealth 20 or two years after the freeze. The program pauses for the human when study 1 has reported and study 2's fidelity result is in. Keep "Nothing is rescued by lowering a threshold", and add "or by calling a non-rejection absence". Source: section 8.

### A6. Section 17, findings to date (573 to 599)

1. **Opening (575).** Old: "Stage 7 is parked, stages 8 and 9 are superseded, and C10.5 has no exit judgment to report". New: stage 7 and the thesis track are parked, stages 8 and 9 are superseded, stage 11 has left the roadmap, and C10.5 has no exit judgment to report.
2. **New paragraph, placed first, "The wall (Q3)".** The pilot's result on whether an agent's proposal can be confirmed is Section 10's table: at 91 days, Sharpe 4.98, 5.87 or 27.6 by test. It is a finding about the method, derived and not sampled; C2.6's failure and stage 3's empty finalist lists are consistent with it and do not prove it. Source: 2.3.
3. **New paragraph, placed last, "Review of the paper's own derivations".** An outside review raised fourteen findings on this paper's mathematics (`audit/reviews/2026-11-10-argon-web-paper-math.md`). Thirteen hold in substance and one in part. None flips a recorded pass or failure. Seven are corrected in this revision, and the rest are carried in the defect table (Appendix) until the machinery they concern is revived. Source: `argon-paper-findings.md`.
4. **Thesis implementation (595).** Add at the end: the track is parked (Section 12).
5. The stage 2 and stage 4 paragraphs change in part B.

### A7. Appendix S4a (648)

Old: "An unconstrained second-order Kelly approximation gives `log K ≃ nS²/2`, hence annualized `S ≃ 4.9` at 546 steps." New: that approximation holds only when Kelly's fraction `μ/σ²` is within the cap of one half. At 2% a step that is `μ ≤ 0.0002`, an annualized Sharpe of at most `0.01·√2190 = 0.47`. With the cap, and at 80% power, the gate's test needs Sharpe 27.6 at 546 steps, 7.4 at one year and 4.0 at two (Section 10). Keep the half-cap line, "Neither is a theorem ..." and the Bahadur sentence. Source: 2.2; `confirmer`; finding 1.

### A8. Appendix T4 (746 to 753)

Retitle: "T4. A forward account in bounded bets (derived; no study uses it)". Keep the label.

1. **Paragraph 1.** Old: the paired Brier difference and "`|e| ≤ 0.05` needs 618 to 2,473 independent pairs". New: pairing an agent that reads with the same agent that does not is fair, and buys no power: where the arms agree the difference is zero, so the law holds in discordant forecasts, 859 if reading adds five points of hit rate and 3,437 if it adds two and a half. Source: section 4, Q2.
2. **Paragraph 2.** Replace with the account of section 6 and its proof on the world's filtration: cash from 1; a registered stake of at most 5% of cash at recorded all-in cost `c < 1`; a recorded settlement `x` in [0, 1] pays `(stake/c)·x`; null `E[x | everything that has happened by registration, recorded or not] ≤ c`; `V` is cash plus `stake/c` times the conditional expectation of `x` over positions not yet recorded as paid; `V` is a non-negative supermartingale from 1 and cash never exceeds it, whenever and in whatever order records arrive. Old claims removed: `z = d√(mH)`, the looks at weeks 26 and 52, "At `m` = 60, 80% power needs ...". Source: section 6.
3. **Paragraph 3.** Replace with the power of that account: the law `bets a week × e² ≥ 0.083` where the cap does not bind; the three settlement timings of section 4; the size check, 2.4% of fair paths reaching 20 at 33 bets a week. Old claims removed: the simulated sizes 26% and 6.4%, "each look's critical value is set by simulation". Source: section 4; `forward_account`.
4. **Identity paragraph.** Delete: no instance is frozen.

### A9. New appendix subsection, "The program", after the thesis track's

- **P1. Study 1 (derived; chosen targets).** The twin construction and why twins are not additive (the plant feeds N2's variance path); the majority rule's exact bound, `P(Bin(32, 1/2) ≥ 24) = 0.0035`, and 0.997 at a chance of 0.9; the sign test's size by exact enumeration, 0.043; the power table of section 5.3 in full, with the worst null row; the band 0.11 to 0.19 from a standard error of 0.008; the choices: half the reference, 24 of 32, `θ = 0.7`, 100 markets, target 0.15, each with its reason from section 5. Source: section 5; `study1`, `sign_test`.
- **P2. The confirmer (derived).** `8.59/e²` by the reflection formula; the registered fraction and the mixture's power; the loss bound `√2190/S`; the hedge as a choice and what a wrong size does. Source: 2.2, section 6, section 11 item 4; `exact_cost`, `confirmer`.

### A10. Bibliography

Add, each checked against its source before it is cited: Kelly (1956); Shafer, "Testing by betting" (2021); McLean and Pontiff (2016); Hou, Xue and Zhang (2020); Prophet Arena (arXiv 2510.17638). `ville1939` and `waudbysmith2024` exist. Remove `jaffe1974` and `fama1998` if A2.11 leaves them uncited.

## B. Argon's findings, fixed now

Finding 1 is A2 and A7.

| Finding | Where | Old claim | New claim | Source |
|---|---|---|---|---|
| 4 | Section 17, stage 4 (589) | "Pooled over the three versions, 22 campaigns started and 21 are known non-promotions, an upper bound of 0.133 at 95%; ... counted as a promotion the bound is 0.198." | Over the three versions 22 campaigns started and 21 are known non-promotions; one campaign of v2 crashed without a gate outcome. The versions were stopped and redesigned in turn, so they are not one procedure sampled 22 times and no pooled bound is stated. V3 alone, no promotion in ten, bounds its rate at 26% (S4) | `argon_paper`, item 4 |
| 4 | Section 10, what the pilot observed (393) | "21 known non-promotions of 22 swarm campaigns" | No change: it is a count | |
| 6 | Section 17, stage 2 (583) | "every judged Sharpe mixed cell had zero FDR" | Add: a campaign that promotes nothing counts as zero, so this shows that few campaigns promoted and not that a promotion is reliable | Finding 6 |
| 6 | S4 (645), after "≃ 0.0776" | none | Add: the cutoff is met by any gate that promotes in at most 7 of 100 campaigns. C2.5 bounds the false discovery rate, not the share of promotions that are false | Finding 6 |
| 8 | D1 (709) | "N2's GARCH and `t₅` with common factor" | N2's GARCH with a common factor, each innovation a mix of two truncated `t₅` draws at loading `λ`; the mix is not `t₅`, and before truncation its kurtosis is `9 − 12λ²(1 − λ²)` | Finding 8; `gate/markets.py`, `generate` |
| 10 | S4 (645) | "The tolerances 0.0625, 0.015 and 0.01 are chosen slack for an implementation check." | Add: the suite certifies the tolerance and not the nominal level. Up to 1,138, 244 and 154 rejections in 20,000 pass, so a true rate of 0.056 at level 0.05 passes 72% of the time, 0.012 at 0.01 passes 62%, and 0.0075 at 0.005 passes 65%. The certified sizes are the tolerances; the nominal levels rest on the proof and the return bound | `argon_paper`, item 10 |
| 13 | Table `tab:ceiling` (73 to 89) | 1.24, 0.68, 0.48; 2.15, 1.18, 0.83; 2.77, 1.52, 1.07; "Approximate noise ceiling `h(N,T)`" | 0.89, 0.49, 0.34; 1.87, 1.03, 0.72; 2.53, 1.39, 0.98; caption "Expected maximum of `N` independent null Sharpe estimates over `T` years" | `expected_max` |
| 13 | S1 (614) | "The leading term at N = 1,000 and T = 5 gives 1.66; integrating ... gives about 1.45." | The table integrates the maximum's density. The leading term `√(2 log N)` overstates it by 39%, 15% and 9% at `N` = 10, 1,000 and 100,000 | `argon_paper`, item 13 |
| 14 | K1, the C1.7 sentence | "... have no joint calibration of false alarms and detection" | Add: over 550 days the standard error of an annualized Sharpe is 0.81, so a leak worth Sharpe 2 stays below the alarm at 4 in 99.3% of single runs. C1.7 detects gross lookahead only | `argon_paper`, item 14 |

## C. The defect table

A new appendix paragraph, "Known defects of parked machinery", placed after S5. One row per defect: the claim and where it is stated, what is wrong, the review that found it, and what is re-derived before the machinery judges anything. The affected passage gets a pointer to its row and no other change. A row is deleted only by the commit that re-derives its claim, after review. No parked item is revived with a row open against it.

| Row | Pointer placed at | Defect | Before revival |
|---|---|---|---|
| 2a | S3, the identity for `E[max(r', −B)]`; Section 8, steps 2 to 4 | Mean-based search tests on returns floored at −1 have a positive null mean | State each screen's null on the returns it reads |
| 2b | Section 8, holdout batch (321) | A finalist can be promoted on a running maximum and end bankrupt | Promotion also requires ending above the start |
| 2c | S3, "Thus their running maxima agree"; Section 8 (329) | The equality needs absorption, which the frozen pilot kernel's resurrection defect breaks | Judge only on an engine with absorption proved |
| 3 | E2; E1's settlement sentence; D1 | E2's bound uses boundary settlement before a wick closeout; under a chronological order the return reaches −2.07 | One order stated in all three, and `m` re-derived under it |
| 5 | Section 8, step 5; Section 9; S5 | A sign check on the selection sample passes selected noise with probability up to 0.999 | The mechanism is tested on data the selection did not use, or dropped |
| 7 | Section 8, step 2 | The largest of the effective-`N` estimates is always the raw count | Describe the screen as it is |
| 9 | S3, the plug-in bet; S4a | The bet is `min(1/2, 1/r₁)` at step 2 and saturates | A confirmer with one registered fraction and stated power (Section 10) |
| 10 | S4, the locked suites | A pass certifies a size of at most the tolerance, not the nominal level | Re-read the recorded counts against the levels themselves |
| 11 | Section 8, the stationary bootstrap; S5, the block length | For a market-neutral funding book, where funding is 0.05 to 0.25 of a step's variance, blocks of mean six understate the variance of the mean by 3.6 to 6.8 and overstate a `t` statistic by 1.9 to 2.6. For a directional position the factor is 1.002. The share on the pilot's markets is not measured | Measure the share for the judged book, and derive the block length from the funding process's persistence |
| 12 | Section 11, the licensing boundary (441); D3 | Three reports over permitted cells recover one date's value; the four-pattern suite cannot certify the boundary | A fixed, strategy-independent partition or noise under a budget, reviewed. Until then no kernel-only aggregate crosses |

Source for every row: `audit/reviews/2026-11-10-argon-web-paper-math.md`, the finding of the row's number, and `audit/program/argon-paper-findings.md`. Row 11's numbers: `argon_paper`, item 11.

## D. Other stale files

A second commit. Each edit is spelled out; a builder applies it as written and stops at anything that does not match.

### D1. `CLAUDE.md`

| Where | Old text | New text | Why |
|---|---|---|---|
| §3, the spec paragraph | "its roadmap sets the stages, and stage 11 is the human's." | "its roadmap sets the stages and the studies." | Stage 11 is gone (the human, 2026-11-11 20:41 UTC (15:41 EST)) |
| §3, opening paragraph, new second sentence | none | "The project is academic: a study of what can and cannot be confirmed about an agent's edge, in which the research system is an aim and not only a means (the human, 2026-11-11)." | The human, 20:41 UTC (15:41 EST) and 20:57 UTC (15:57 EST) |
| Where information lives, a new line | no line for the index | Add after the Status line: "**Findings index:** `docs/findings.md`, one row per completed study, each linking the paper and the audit record. It holds no number of its own." | Architecture, section 7, item 6 |
| Where information lives, Specs | "(`kernel/DSL.md`, `thesis/SCORING.md`)" | "(`kernel/DSL.md`, `ingest/ARCHIVE.md`)" | The thesis track is parked; the example should be live |
| Frozen identities | "The thesis track's operational layer is outside its identity: a patch to it gets a decisions line and a targeted test, and each session records its operational commit." | Delete the sentence | The track runs no session, so the failure the rule prevents cannot happen; it returns with the track |
| Frozen identities | "a thesis refreeze a new forward window" | Keep, and add: "a refrozen replica a new freeze date" | Study 2 |
| Holdout | "The thesis track's forward use is its own design." | "Study 2 reads the vault's fills and the recorded books after its freeze only through the confirmer's replay, as its design states." | The decision of 2026-11-11 21:27 UTC (16:27 EST); the detail arrives with the kernel version 2 design |
| Tech | "Every judged pilot result comes from one frozen kernel; the Lean engine ..." | Add before the semicolon: ", and study 1 runs on it unchanged. Study 2's replica runs on kernel version 2, a new identity" | The decision of 21:26 UTC (16:26 EST) |

The Holdout and Tech rows are applied only once the kernel version 2 design is decided; the others now.

### D2. `docs/future-work.md`

| Old text | New text |
|---|---|
| "Its metric is ... it is worth running if that study accepts 0.2." (the DSL designed for agents) | "... it is worth running if that study ends at its futility stop or undecided." |
| "**A second event venue**: Kalshi, which a United States resident may trade on (to verify), needs its own certificate." | "**An event-contract venue**: none is certified. Kalshi's and Polymarket US's terms permit trading use only without written consent (`audit/decisions.md`, 2026-11-11). A reading-agent study reopens on a certificate and a measured count of at least 33 near-independent bets a week (paper, Section 10)." |
| "Under the wall each can be tested only forward: as theses on event contracts where a market quotes the event, otherwise on the parked perp instance." | "Under the wall each is a frozen rule, confirmable forward only at a Sharpe near 2 within two years (paper, Section 10)." |
| "Event exchanges with official APIs are a separate case, and the thesis track's venue." | "Event exchanges with official APIs are a separate case." |
| In "Rejected": "(`audit/program/architecture.md`, section 3 ...)" | Point to the paper's Section 10 instead; revision 4's section 3 is a different section |
| New entries, in the first list | "**Study 1's second cell**: a plant with no economic story, worth its sessions only after an upper boundary (`audit/program/architecture.md`, 5.4)." and "**The paired reading design** (an agent with filings against the same agent without): fair, and it needs 859 to 3,437 discordant forecasts (paper, T4)." |

### D3. `CLUSTER.md`

- No line is stale today: line 4 already says the thesis track is parked and the prewarm job suspended.
- When study 1's runner is built, its builder adds the workload's row to the table at line 51 with the accounts it uses (TAMU and Cornell, never the personal account) and the pacing sentence at line 106.
- The thesis rows stay while its manifests exist. They leave with the manifests if the human retires the track.

### D4. `PROGRESS.md`

Applied by the advisor; the architect does not edit this file.

| Where | Old text | New text |
|---|---|---|
| Now, item 1 | "Round fifteen done on `thesis-refreeze` ..." | Delete: the track is parked and the commit is in git |
| Now, item 2, "The program" and "The human answered" bullets | The paper account in event contracts; Kalshi, the $2,500 bankroll | Delete both. One line: "The program (revision 4, approved 2026-11-11 21:26 UTC (16:26 EST)): study 1, study 2, no reading-agent study; `audit/program/architecture.md`, `ledger.md`." |
| Now, item 2, "Not written before the session hit its limit" | the whole bullet | "Written: `paper-changes.md`, `briefs/1-positive-control.md`, `ledger.md`. Next: Fable designs kernel version 2; a builder applies `paper-changes.md`; study 1's tests are written from its brief." |
| Now, item 3 | "Search API: surveyed ... Not needed under revision 3." | Delete |
| Now, item 4 | "Stage 8 and 9 criteria are marked superseded when a study is defined." | "Stage 8 and 9 criteria: the advisor appends `audit/program/criteria-notes.md` (D5) beneath them." |
| Parked, item 2 | "Stage 8 data (below the critical path)" | "Stage 8 data (superseded; recording only)" |
| Blockers | "No US event-contract venue is certified for study 2 ..." | Delete: study 2 is no longer on event contracts, and the decision stays in `audit/decisions.md` |
| Blockers | "Stage 8 equities and index constituents: no purchase, indefinitely ...; stage 8 reports its admitted scope." | End at "indefinitely (the human, `audit/decisions.md`)." |
| Qualifications, stage 2 | "(the B = 1 bound is examined in stage 7)" | "(paper, Section 10: the calendar and the gate's loss cap together)" |
| Decisions awaiting the human's review | none | Add the advisor's decisions taken on this list, if any reviewed decision was needed to apply it |

### D5. Specs and program files

| File | Edit |
|---|---|
| `gate/NULLS.md`, lines 62 to 64 | After "scaled to unit variance by the exact truncated standard deviation." add: "The sum `x_i` is therefore a mix of two truncated t draws and is not itself Student-t: before truncation its kurtosis is `9 − 12λ²(1 − λ²)`." The generator does not change. Check first that `harness_hash` does not read this file; if it does, the sentence goes in the paper only |
| `kernel/DSL.md` | No edit. It advertises inputs N2 lacks, and the frozen harness shows it to the agent, so changing it forks the harness. Study 1 reports evaluations that name a missing input |
| `thesis/SCORING.md`, `thesis/brief*.md` | No edit. The scientific manifest hashes them |
| `ingest/ARCHIVE.md` | No edit |
| `audit/program/criteria-notes.md` | Its stage 8 and 9 notes cite revision 2's sections "2.3, 3 D and 4" and a revival condition naming an old-cutoff model. The advisor replaces the citations with "revision 4, sections 2.3 and 10" and the revival condition with A5.9's, then appends the notes. No threshold is touched |
| `audit/program/briefs/2-thesis-track.md` | A brief for the withdrawn event-contract study. Nothing may be built from it. Whether it is deleted is the human's (it lies under `audit/`); until then the advisor adds one first line: "Withdrawn 2026-11-11: no venue is certified and the study is not in the program (`architecture.md`, revision 4)." |
| Branch `positive-controls` | Not merged. PC1 to PC6 are replaced by `briefs/1-positive-control.md` |

### D6. The new `docs/findings.md`

One table. Columns: study; question; result in one line; record; stands. A row holds no number that is not in the paper's Section 17 or the record it links. First rows, to be written from Section 17 as it stands after parts A and B:

| Study | Question | Result | Record | Stands |
|---|---|---|---|---|
| Stage 0, feasibility | Can funding dislocations be replayed point in time at known cost? | Supported the pilot; C0.7 failed coverage in 3 of 44 cost cells; exit by the human's authorization | `audit/stage0/criteria-result.txt` | Yes, with the cost qualification |
| Stage 1, kernel MVP | Does the evaluator hold its invariants? | C1.1 to C1.8 met; C1.7 detects gross lookahead only | `audit/stage1/` | Yes |
| Holdout-test studies | Does the holdout test hold its size? | Suites v1 and v2.1 failed; the betting test's v3 suite passed 99 pairs, certifying the tolerances | `audit/stage2/holdout-size-locked-v3.json` | Yes, as narrowed (finding 10) |
| Stage 2, calibration | Does the pipeline promote noise, and can it see a planted edge? | No promotion in 300 null campaigns a cell; C2.6 failed and was waived | `audit/stage2/exit-r2.md`, `c26-failure.md` | Yes; C2.5 as narrowed (finding 6) |
| Historical-cost alternative | Can archive books replace the live cost table? | Failed coverage and agreement; the alternative lapsed | `audit/stage3/archive-equivalence.json` | Yes |
| Stage 3, single agent | Does the pipeline run end to end with an agent? | No promotion in 20 null campaigns; no finalist in either arm of the real run | `audit/stage3/exit.md` | Yes, as pipeline validation only |
| Stage 4, swarm | Does a swarm run without false promotion? | v1 and v2 failed; v3 passed, none promoted in ten | `audit/stage4/exit.md` | Yes; no pooled bound (finding 4) |
| Stage 5, data integration | Can text sources be bound point in time? | Prospective-only exit; unlocks blocked | `audit/stage5/gpt-exit-review.md` | Yes |
| Stage 6, reference kernels | Does a verified reference agree with the engine? | Lean adopted; 1,196 verdicts and 3,372 runs agreed exactly | `audit/stage6/report.md` | Yes |
| Thesis track | Does the implementation score correctly? | Implementation checks only; seven frozen versions, none completed its window | `audit/stage10/manifest.json` | Parked; no outcome |
| Bug hunts | Does the frozen pilot implement its spec? | Nine reproduced defects remain qualifications | `audit/reviews/2026-11-03-gpt-hunt-kernel.md`, `…-gate.md` | Yes |
| The paper's derivations | Does the paper's mathematics hold? | Thirteen of fourteen findings hold in substance; seven corrected, the rest in the defect table | `audit/program/argon-paper-findings.md` | Yes |
| The wall | Can an agent's proposal be confirmed within the calendar? | At 91 days: Sharpe 4.98 on the yardstick, 5.87 exact, 27.6 by the gate | `audit/program/architecture.md`, 2.3; paper, Section 10 | Yes |

The builder checks each row's numbers and record path against Section 17 before writing it, and adds the reproducibility and operations studies from that section the same way. Studies 1 and 2 get rows when they report.
