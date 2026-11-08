# Thesis refreeze round six — GPT build

Starting point: `2229563`, branch `thesis-refreeze`. Answers Argon's web T3 review and Opus's round-five review read from `main`, with the human's 2026-11-08 21:44 UTC (16:44 EST) approvals. No exchange request, protected observation, freeze, deployment or push is authorized or used. Frozen `audit/criteria.md` is untouched.

## Design readings before implementation

- Monday's approved fixed holding window requires an effective forecast time distinct from the actual registration receipt. The benchmark will retain Monday midnight as `t_r`, record `registered_at` separately, and use only bars, funding and listing observations known by Monday 00:00 UTC (Sunday 19:00 EST). This is a deterministic paper benchmark, not a claim of executable delayed entry at an earlier price. Missing historical listing observations cannot be reconstructed from later live metadata.
- Same-day readiness must be a saved fact, not just a fixed timestamp applied to a mutable cache: another arm's funding read could otherwise improve it. The snapshot will save the readiness map and its evaluation time; all arms use that map. Agent registration-time equity, hourly bars, funding and commit listings still differ by design.
- The stress packing is order-dependent. The reviewed code-order figure is 252 minutes, the sorted histogram test is 257; neither bounds arbitrary inventories or request orders. The completion budget must include prewarm debt, foreground resolutions, ten-dex sampling and latency, and acknowledge the next mark-prep cutoff rather than claim a universal pre-start guarantee.

## Failing-first evidence

- `test_refreeze_t3.py`: both tests fail on `2229563` (missing stress-budget/cutoff disclosure and approved revision language). Log: `/tmp/opencode/round6-baseline-t3.log`.
- Separate source-blind test-writing sessions produced `test_resolution_priority.py`, `test_mark_cohorts.py`, `test_snapshot_integrity.py` and `test_refreeze_round6_inputs.py`, without reading production code. Their baseline logs are `/tmp/opencode/round6-baseline-{core,inputs}.log`. The input suite had 29 failures and two controls passing. The saturated-limiter cases both published a false missing-data status before eventually resolving on the baseline.

## Completed steps

- FIFO foreground admission replaces racing foreground counters; sampling retains priority. `test_fifo_snapshot_cannot_starve_the_0005_resolution[20-6,21-5]` now resolves the real due thesis before the 90-minute status bound, despite adversarial snapshot-favored wakeups. Priority/funding-fill tests: 22 passed (`/tmp/opencode/round6-priority.log`).
- Cohort pagination is inside each error wave, no longer an error attempt. The second-cohort failing dex retains six attempts; tests separately cover sends at H + 250 s and H + 289.999 s, and refusal at H + 290 s. Both send and receipt at the seal are excluded. Removed the obsolete capacity alarm and replaced the old 70-second give-up expectation. Mark/market tests: 140 passed (`/tmp/opencode/round6-marks.log`).
