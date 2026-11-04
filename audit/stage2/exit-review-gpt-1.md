
1. **BLOCKING — C2.1’s numerical checks pass, but its full certification is not supplied.**  
   `c21-top5.json` has regression minima **0.05886, 0.01190, 0.03428**, all above 0.001, and maximum |z| **3.58159, 2.02919, 3.04396**, all below 3.7. Its top-5 names identify r2 campaigns 0–19. Using those same strategies against all three models is not itself a violation: the criterion does not demand separate selections per model or searcher. However, the file does not establish the required independent/fresh 200-year samples or across-market SE calculation. The standing fixed-probe evidence—including buy-and-hold **per coin**—is referenced but absent. These are verification gaps, not demonstrated statistical failures.

2. **BLOCKING — C2.2 and C2.3 are asserted, not independently auditable from this package.**  
   - **C2.2:** Standing evidence remains eligible, but no independent-generator regression results, five tolerance comparisons, implementation provenance, or recorded fallback are supplied.  
   - **C2.3:** A test-file path is not its implementation or execution evidence. Supply the new spec-only independent implementation, results for 1,000 random cases plus required edge cases, and root-cause records for resolved disagreements. It must test the latest screen, including the degenerate-variance, rescaling and error rules—not the retired σ_S implementation.

3. **BLOCKING — The additional locked holdout-calibration requirement is omitted.**  
   Calibration v3 remains eligible after the screen revision, but `exit-r2.md` neither judges it nor supplies its results. Stage 2 also requires that locked suite’s committed specification, independent implementation, complete cells and simultaneous Clopper–Pearson bounds. The betting-test theorem does not waive this explicitly retained empirical exit requirement.

4. **BLOCKING — Campaign eligibility and completeness cannot be verified from summaries alone.**  
   The referenced fan-out plans, dated addendum and host records are absent. Thus the package does not establish the pre-shard freeze of all **2,700 null and 700 mixed IDs**, commit, binary, searcher and beta pins; fresh seed-derived markets/searches; or accounting for every started campaign without prohibited reruns. Aggregate denominators and an empty `events` object do not establish that history. Also missing are the underlying N2-long calibration, per-program 200-fresh-year truth checks with 99% CIs, and evidence that its required I5/semantics/Lean changes and proof rechecks preceded execution. Cross-machine tests support reproducibility, not these separate prerequisites.

5. **NON-BLOCKING — C2.4’s numerical verdict is correct; bankruptcy is not automatically a crash.**  
   All nine supplied cells have 0/300 promotions and 0/300 SPA-and-finalist events. Their one-sided upper bound **0.009936** satisfies both limits. The one bankrupt evaluation does not, by itself, require counting a promotion: bankruptcy is a specified kernel outcome. An actual campaign crash or timeout would require promotion accounting.

   The cluster exception became effective only when test 8 passed, at **2026-10-28 04:38 UTC**. Thereafter, qualifying cluster infrastructure kills may retry the same ID after partial-output cleanup. This does not authorize campaign-error retries, off-cluster retries, or retroactively excusing round-1 crashes.

6. **NON-BLOCKING — C2.5’s numerical verdict is correct, subject to eligibility verification.**  
   Each of the six judged Sharpe cells has FDR **0**, with Hoeffding upper bound **0.122387 ≤ 0.20**. N3’s amended cell must be presented as **“N3, s = 2.5 (amended from 3)”**; the judgment acknowledges this, although the JSON retains the old key. N2-long’s FDR **0.006176** is reported only, as required. It is the mean campaign-level false-discovery proportion, not the pooled fraction 21/75.

7. **NON-BLOCKING — C2.6 fails correctly, but mandatory power reporting is incomplete.**  
   N2-s3 has **0/100** true-promotion campaigns, versus the required ≥0.30; N2-long has **5/100**, also below 0.30. Their two-sided 95% CP intervals are respectively **[0, 0.036217]** and **[0.016432, 0.112835]**. The six-cell power curve and intervals are available in `sweeps.json`.

   What is missing from the judgment is the required **test-alone simulated power at the 1,080-step holdout length alongside that curve**, and the plain statement that the pilot cannot confirm ordinary edges: the test needs approximately **0.55% net per 4h step**, whereas annualized Sharpe 1–3 corresponds to means far below 0.1%. The suspended mean-strength cells are **not** required.

8. **NON-BLOCKING — Keep development diagnostics out of r2 claims.**  
   `screen-preview.json` is explicitly ineligible: applying the revised screen to old ledgers is not the required fresh rerun. `c26-failure.md` must remain recorded but cannot supply this version’s judged results. The statement that Sharpe-cell finalists reach holdout in “6 to 84 campaigns per cell” is unsupported by `sweeps.json`; the preview actually includes **3/100** for N3-s1. Supply eligible r2 finalist counts rather than borrowing diagnostic figures. This discrepancy does not prove that the main sweep results were reused.

9. **NON-BLOCKING — Required fragility diagnostics are absent.**  
   The package does not report correlation-cluster counts at **|ρ| ≥ 0.9 and 0.5**, or the revised-screen diagnostics recomputed at those counts. They cannot replace raw N or change promotion decisions, but the criteria require reporting them.

10. **NON-BLOCKING — “Option Q” would not be an exit under the frozen criteria.**  
    Retaining a failure as a qualification does not satisfy “Exit when C2.1 to C2.6 all hold.” A human-authorized qualified exit would be a distinct waiver/change, never a pass as written. Likewise, r2 cannot erase the original gate’s recorded failure.

**Verdict:** **“Stage 2 does not exit on r2” is right; C2.4–C2.5 numerically pass and C2.6 fails, but the unconditional “C2.1 to C2.5 met” sign-off is not fully established by the supplied audit evidence.**
