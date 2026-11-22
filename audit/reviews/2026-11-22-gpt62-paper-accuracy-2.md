# GPT-6.2's follow-up accuracy check of the paper fixes

Model `gpt-6.2-sol` (codex, high reasoning) through `ops/gpt.sh`, its jail seeing only a clone of `paper-rewrite` at `05d29e3` (Neon's fixes after `3ac040f`). Run 2026-11-22 02:20 to 02:28 UTC (2026-11-21 21:20 to 21:28 EST). Verdict: not yet accurate enough to merge. The prompt is below the reply. The reply, verbatim (its file links point into the clone):

I checked the fixes through `05d29e3` against the audit record and spot-checked the rebuilt PDF. The main counts still agree with the record. Several qualifications remain missing or misstated.

## Pilot, system, and confirmation wall

1. **Null and sensitivity scope — partly fixed.** The body gives the nine null cells, the bankrupt evaluation, the amended Sharpe 2.5 cell, and the 900-day result of 75 promotions across five campaigns, with 54 true and 21 false by the audit proxy. It restores the independent reviewer’s evidence gaps. The record supports retaining “overstate” for baseline sensitivity because the baseline procedures omit a required mechanism filter. The abstract still omits the separate positive cell and leaves the zero-promotion population implicit. Name the six zero-promotion Sharpe cells and the finalized null procedures there. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:44) · [Calibration exit](/home/kevin/.cache/mm-gpt/paper2/audit/stage2/exit-r2.md)

2. **Amendment status — fixed.** The paper restores the amended clock instrument, the martingale canary amendment, the \(10^{-9}\) fixture comparison, the zero-finalist revisions, and the prospective-only text-source amendment with the outstanding calibration requirement. The record supports saying the release path was never exercised. [Pilot](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:363) · [Real-run exit](/home/kevin/.cache/mm-gpt/paper2/audit/stage3/exit.md)

3. **Smoke-test accounting — fixed.** The single-agent second version had one counted promotion and established no procedure. The swarm’s first two versions failed, and one crashed campaign had an unknown gate outcome. The record supports retaining 26% for zero **recorded** promotions among ten starts, including the unresolved campaign. The paper also gives 28.3% for the nine established campaigns and withdraws the pooled bound. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:381) · [Swarm exit](/home/kevin/.cache/mm-gpt/paper2/audit/stage4/exit.md)

4. **Deployment and ledger scope — partly fixed.** The body correctly identifies workspace access, the sole evaluation route, the frozen identity’s missing fields, and row replacement through a separate connection. The abstract still calls the ledger append-only without a deployment qualification and implies calibration of the full adaptive agent procedure. Baseline calibration and agent smoke tests support different claims. [Abstract](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:44) · [Defect disposition](/home/kevin/.cache/mm-gpt/paper2/audit/decisions.md:682)

5. **Capabilities and evidence — partly fixed.** The relative-range diagnostic, three coverage failures, absent return-error bound, source-design distinction, empty search stores, and withdrawn handoff clock acceptance are accurate. The handoff wording is supported by the record. The revised cost paragraph drops a separate snapshot check, as detailed below. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:194) · [Cost criterion](/home/kevin/.cache/mm-gpt/paper2/audit/criteria.md:58)

6. **Gate validity — fixed.** SPA uses distinct filled candidates, the mechanism filter applies to the agent arm, and the \(-2\) bound is conditional on the corrected synthetic construction and its settlement order. The paper distinguishes centered innovations from net returns. The record supports the retained positive-terminal-return requirement in row 2. Row 8 now states the variance factors as scenarios. [Gate](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:252) · [Math findings](/home/kevin/.cache/mm-gpt/paper2/audit/program/argon-paper-findings.md:19)

7. **Proof scope and timing — partly fixed.** The shared inputs and execution view, separate fill cases, abstract proofs and sampled binary64 comparison, Lean’s eligibility, and version 2’s float and Ville qualifications are substantially correct. The evaluator medians are correct. The attached thread-sampling claim is inaccurate, as detailed below. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:393) · [Benchmark review](/home/kevin/.cache/mm-gpt/paper2/audit/stage6/gpt-exit-review.md:67)

8. **What the wall establishes — partly fixed.** The column now correctly specifies a single finalist, 2% four-hour volatility, a saturated half stake, a Brownian approximation, and threshold 20. The cutoff is identified as project policy, the first-round screen failure is distinguished from the revised holdout result, and the unsupported subscription-age and bet counts are gone. Some headline claims still present negligible power or an arithmetic explanation as established beyond those planning models. [Wall](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:405) · [Planning derivation](/home/kevin/.cache/mm-gpt/paper2/audit/program/architecture.md:26)

9. **Numerical scope — fixed.** The rejection ceilings distinguish 54 from 99 combinations. The second stake, single-run Gaussian canary miss rate, and illustrative mechanism-pass probability have the requested conditions. [Appendix](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:626)

## Study 1

10. **Strict bounds and premises — partly fixed.** The outward bounds, nominal Wald inputs, served-mix interpretation, and outage scenario are correct. The appendix calls 0.04308 exact, although it is a rounded enumeration result. The record supports the across-market independence argument under its design premises. The guarantee should state that premise explicitly, including when the served mix changes. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:788) · [Design](/home/kevin/.cache/mm-gpt/paper2/audit/program/architecture.md:134)

11. **Score and checks — fixed.** The selection score and tie-break, shared expression with possible zero weights, illustrative oracle comparison, conditional binomial probabilities, limited mirror and constant-position screens, and approximate calibration band are correctly scoped. The record supports the earlier 0.20 proposal and its 0.25 upper edge. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:481) · [Calibration design](/home/kevin/.cache/mm-gpt/paper2/audit/program/architecture.md:174)

## Study 2

12. **Vault versus replica — fixed.** The tentative identification, replica constants, coin-size multiples and recorded departures are supported. The accessible summary supports about 2.4 for the top-ten reconstruction over 2023–2026 with the time stop and about 1.4 for its latest year. Those specifics would make “overall” and “recently” precise. The original post still returned HTTP 403. [Audit facts](/home/kevin/.cache/mm-gpt/paper2/audit/program/facts-kernel-v2.md:123) · [Accessible summary](https://tradingstrategy.ai/docslearn/mean-reversion.html#i-reverse-engineered-a-1-9-sharpe-hyperliquid-vault-here-s-how-it-works-and-how-to-trade-it)

13. **Fit, recording, and fidelity — partly fixed.** The first-fit data restriction, refit feedback, three sampled cadences, BTC measurement, staleness rationale, initial cash, and separate fee and P&L arithmetic agree with the record. The cadence changed around 02:00 UTC **on** June 15. “Through June 15” implies a later change. Daily funding summaries check aggregates. Daily cash at unobserved oracle prices is measured separately without a pass mark. [Archive facts](/home/kevin/.cache/mm-gpt/paper2/audit/program/facts-kernel-v2.md:117) · [Fidelity design](/home/kevin/.cache/mm-gpt/paper2/audit/program/architecture.md:350)

14. **Registered judgment rules — partly fixed.** The timing paragraph correctly starts at the first UTC midnight at or after freeze. Elsewhere the paper still places ledger initialization and the start of judging at freeze. Event eligibility, the \(D=0\) certificate case, guard refusal, first crossings, once-only judgments, maximum matching and the requested bid and guard reporting are present. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:509) · [Registered criteria](/home/kevin/.cache/mm-gpt/paper2/audit/criteria.md:1170)

15. **What the control can show — partly fixed.** The Gaussian reference, conditional bootstrap, inability to simulate new cash exhaustion, design expectation, and distinct trades driving the three measurements are correctly scoped. The appendix still says the ledger’s volatility *falls* in particular rows. The record supports an expectation pending replay. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:848) · [Audit expectation](/home/kevin/.cache/mm-gpt/paper2/audit/program/architecture.md:480)

## Citations, cuts, and index

16. **Citations — fixed.** The attributions and Holm reference are corrected. ALFRED’s fallback dating and the forecasting comparisons are supported. [Related work](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:539) · [ALFRED](https://alfred.stlouisfed.org/help) · [ForecastBench](https://proceedings.iclr.cc/paper_files/paper/2025/hash/ea74e45a229dac70b5b63b28d8934db6-Abstract-Conference.html) · [Halawi et al.](https://papers.nips.cc/paper_files/paper/2024/hash/5a5acfd0876c940d81619c1dc60e7748-Abstract-Conference.html) · [Prophet Arena](https://arxiv.org/html/2510.17638v2)

17. **Cleared effective-\(N\) row — fixed.** Raw \(N\) remains the production choice. Cluster counts rerun finalist selection as a fragility diagnostic. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:246)

18. **Cuts and index — partly fixed.** The paper introduces no repository paths, internal audit labels, or cluster operations. The effort proxy is restored. “Deviations reproduced” is supported and keeps the index free of its own measured numbers. The pointers remain non-clickable, and “only above the threshold” turns an 80%-power benchmark into a hard cutoff. [Findings index](/home/kevin/.cache/mm-gpt/paper2/docs/findings.md:17)

## New issues introduced by the fixes

- The cost model was checked for coverage **and** excess over the held-out 90th percentile. The new “only” wording drops the latter. [Cost criterion](/home/kevin/.cache/mm-gpt/paper2/audit/criteria.md:58)
- Thread counts up to four were sampled for **end-to-end** timings. The new parenthetical attaches that observation to evaluator-only medians. [Benchmark review](/home/kevin/.cache/mm-gpt/paper2/audit/stage6/gpt-exit-review.md:67)
- Study 2 now calls its two additional criteria “independent.” They are separately judged measurements on overlapping days of the same run, with no established statistical independence. [Paper](/home/kevin/.cache/mm-gpt/paper2/docs/whitepaper.tex:517)

**Merge verdict: the paper is not yet accurate enough to merge.**
## Prompt

You are re-checking a research paper's accuracy fixes. This directory is the project's own repository at branch `paper-rewrite`, read-only for you (read `CLAUDE.md`; its "Where information lives" section sets the paper's rules). Your earlier accuracy review is `audit/reviews/2026-11-21-gpt62-paper-accuracy.md`. Another model (Gemini 4 Neon) then fixed the paper: commits after `3ac040f` (`git log 3ac040f..HEAD`, `git diff 3ac040f..HEAD -- docs/`), ending with a decisions line.

Check only this: is each of your findings fixed correctly against the audit record, without new inaccuracies, overstatement, or a broken rule of the paper (no repository paths, internal labels or cluster operations; `docs/findings.md` holds no number of its own). Where the fixer kept the record's wording over yours, say whether the record supports it. Accuracy only, not prose. Per finding: fixed, partly fixed (what remains), or wrong (what is now inaccurate). List any new issue the fixes introduced. Under 1,500 words. End with whether the paper is accurate enough to merge.
