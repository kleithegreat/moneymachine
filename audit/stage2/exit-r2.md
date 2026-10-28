# Stage 2 judged on round r2, as written (2026-10-28 12:28 UTC, 08:28 EDT)

Round r2: the revised DSR screen (criteria stage 2, Gate, revisions of 2026-10-27), fresh ids (`c24r2-`, `c25r2-`),
`mm` 3a732069 (cross-machine tests 7 and 8), fanned out over four hosts by committed plans (`fanout-null.json`,
`fanout-mixed.json` with its dated addendum), merged with every planned id once on the plan's kernel. Evidence:
`sweeps.json`, `c21-top5.json`, `null-hosts.json`, `mixed-hosts.json`; checks: `criteria/test_stage2.py`.

| Criterion | Result | Evidence |
|---|---|---|
| C2.1 nulls are null | **met** | fixed probes (`c21-fixed-probes.v3.json`, gate-independent, stands); r2's top-5 probes (`c21-top5.json`): every \|z\| < 3.7 |
| C2.2 independent null generators | **met** | standing evidence (gate-independent) |
| C2.3 independent DSR | **met** | GPT's implementation of the revised screen agrees to 1e-9 on every case (`gate/tests/test_dsr_differential.py`) |
| C2.4 complete null | **met** | every cell 0 of 300 promoted (upper bound 0.0099 ≤ 0.05) and 0 with SPA rejecting and finalists (0.0099 ≤ 0.10); one bankrupt evaluation (N3-G400) |
| C2.5 mixed sweep | **met** | FDR 0 in every Sharpe cell (Hoeffding upper 0.122 ≤ 0.20); N3's s = 3 cell at 2.5 (amendment); no crash |
| C2.6 power | **failed** | as written, N2-s3 power 0 (≥ 0.30 required); as amended, N2-long 0.05 (5 of 100; 95% CP 0.016 to 0.113) |

N2-long's 5 campaigns promoted 75 programs; 54 are true on C2.5's 200 fresh years, 21 false (FDR 0.006 over the
cell's markets, reported only). The Sharpe cells promote nothing: their finalists reach the holdout (r2's counts
below), and the holdout's bet cap (B = 1) leaves their per-step means undetectable (`bound-options.md`).

**Stage 2 does not exit on r2.** C2.1 to C2.5 hold; C2.6 fails as written and as amended. The human's decision on the
loss bound (`bound-options.md`; PROGRESS, decisions awaiting review) settles what follows: a round r3 under a new
bound, or a human-authorized waiver of C2.6 (option Q), never an exit as written.

## Additions after GPT's first review (2026-10-28 12:33 UTC, 08:33 EDT; `exit-review-gpt-1.md`)

- **Evidence supplied:** C2.1's fixed probes (`c21-fixed-probes.v3.json`); C2.2's (`c22.v2.json`); C2.3's run of GPT's
  spec-only implementation of the revised screen (`c23-differential.txt`: 1,000 random cases and the edge cases, the
  degenerate-variance, rescaling and nonfinite rules; `screen-impl-gpt-2.md`); the locked holdout calibration v3
  (`holdout-size-locked-v3.json`, checked by `test_holdout_test_locked_calibration`, met); the fan-out plans with the
  mixed plan's dated addendum (`fanout-null.json`, `fanout-mixed.json`), the host manifests and r2's truth file
  (`truth-r2.jsonl`: 75 N2-long promotions, 54 true on 200 fresh years).
- **r2's finalists** (`r2-finalists.json`, from r2's own records, replacing the preview's figures above): campaigns
  with finalists per cell: N2-long 100, N2-s1 13, N2-s2 25, N2-s3 76, N3-s1 3, N3-s2 28, N3-s3 47; null 0 in every
  cell. Fragility diagnostics (finalists at |ρ| ≥ 0.9 and 0.5 cluster counts; campaigns with fragile finalists) are there.
- **Test-alone power** (`test-alone-power.json`; the betting test alone, normal per-step returns, 2,000 series per
  cell): at 1,080 steps and 1% per-step volatility, 0 at means up to 0.3%, 0.02 at 0.5%, 0.39 at 0.55%, 0.92 at 0.6%,
  and 0 at annualized Sharpe 1, 2 and 3. **The pilot cannot confirm ordinary edges at this holdout length**: the test
  needs a mean near 0.55% net per 4h step, while an annualized Sharpe of 1 to 3 is a mean of 0.011% to 0.13% at per-step
volatility 0.5% to 2%, where its power is 0 at either holdout length.
- **N3's cell** is reported as "N3, s = 2.5 (amended from 3)"; `sweeps.json` keeps the key N3-s3.
- **Option Q** is not an exit under the frozen criteria: it would be a human-authorized waiver, never a pass as written.
