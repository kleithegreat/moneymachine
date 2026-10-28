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
cell's markets, reported only). The Sharpe cells promote nothing: their finalists reach the holdout (6 to 84
campaigns per cell), and the holdout's bet cap (B = 1) leaves their per-step means undetectable
(`bound-options.md`).

**Stage 2 does not exit on r2.** C2.1 to C2.5 hold; C2.6 fails as written and as amended. The human's decision on the
loss bound (`bound-options.md`; PROGRESS, decisions awaiting review) settles what follows: a round r3 under a new
bound, or an exit with C2.6's failure as a recorded qualification (option Q).
