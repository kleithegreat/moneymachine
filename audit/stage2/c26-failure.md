# C2.6 failed on the stage 2 sweeps of 2026-10-27 (2026-10-27 18:32 UTC, 14:32 EDT)

**Result.** C2.6 as written (N2-s3) and as amended on 2026-10-26 (N2-long) both fail: the rate of markets with at least
one true promotion is 0 of 100 in every mixed cell (95% Clopper-Pearson [0, 0.036]); the criterion asks for ≥ 0.30
(`audit/stage2/sweeps.json`, merged from `data/campaigns/mixed.jsonl` at d7ba19b). The recorded figures stand; the
two spurious N2-long crashes do not change power (`n2-long-crashes.md`).

**Where the planted edge is lost.** No campaign in any cell has a screened candidate, so no finalist and no holdout
test exist. The search does find the edge: in N2-long, SPA rejects in 94 of 98 completed campaigns.

| cell | SPA p ≤ 0.05 | screened | finalists | median max DSR | largest max DSR |
|---|---|---|---|---|---|
| N2-s1 | 16/100 | 0 | 0 | 2.7e-12 | 1.3e-6 |
| N2-s2 | 32/100 | 0 | 0 | 1.3e-13 | 6.0e-6 |
| N2-s3 | 84/100 | 0 | 0 | 1.6e-19 | 2.1e-6 |
| N3-s1 | 15/100 | 0 | 0 | 8.0e-12 | 1.7e-4 |
| N3-s2 | 29/100 | 0 | 0 | 6.9e-12 | 1.4e-3 |
| N3-s3 (s = 2.5) | 51/100 | 0 | 0 | 1.3e-13 | 0.047 |
| N2-long | 94/98 | 0 | 0 | 1.0e-39 | 2.9e-9 |

**Diagnosis: a design defect in the screen's benchmark.** The frozen screen (criteria stage 2, Gate) sets
S0 = σ_S · Z_N, with σ_S the cross-sectional standard deviation of the N trials' observed per-period Sharpe ratios.
Under the null that spread estimates the Sharpe estimator's sampling spread; when the search finds a real edge, its
variants of both signs and every strength widen it, so the edge raises its own hurdle. In c25-N2-long-0 (T = 3,299
steps, N = 393): σ_S = 0.178, against the null sampling spread 1/√T = 0.017; S0 = 0.530, while the best trial's
per-step Sharpe is 0.295 (annualized 13.8). With the null spread, S0 = 0.052 and that trial's DSR is 1.0.

**What follows** (human decision, 2026-10-27, `audit/decisions.md`): the screen is re-derived, specified, implemented
independently by GPT, and stage 2 is rerun with fresh ids and judged only on evidence produced after the revision.
This failure stays recorded.
