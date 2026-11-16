# Findings index

One row per completed study: its question, its result in a line, its record and whether it stands. It holds no number that is not in the paper's Section 17 (`docs/whitepaper.tex`) or the record it links. Studies 1 and 2 get rows when they report.

| Study | Question | Result | Record | Stands |
|---|---|---|---|---|
| Stage 0, feasibility | Can funding dislocations be replayed point in time at known cost? | Supported the pilot; C0.7 failed coverage in 3 of 44 cost cells; exit by the human's authorization | `audit/stage0/criteria-result.txt` | Yes, with the cost qualification |
| Stage 1, kernel MVP | Does the evaluator hold its invariants? | C1.1 to C1.8 met; C1.7 detects gross lookahead only | `audit/stage1/` | Yes |
| Holdout-test studies | Does the holdout test hold its size? | Suites v1 and v2.1 failed; the betting test's v3 suite passed 99 pairs, certifying the tolerances | `audit/stage2/holdout-size-locked-v3.json` | Yes, as narrowed (finding 10) |
| Stage 2, calibration | Does the pipeline promote noise, and can it see a planted edge? | No promotion in 300 null campaigns a cell; C2.6 failed and was waived | `audit/stage2/exit-r2.md`, `audit/stage2/c26-failure.md` | Yes; C2.5 as narrowed (finding 6) |
| Historical-cost alternative | Can archive books replace the live cost table? | Failed coverage and agreement; the alternative lapsed | `audit/stage3/archive-equivalence.json` | Yes |
| Stage 3, single agent | Does the pipeline run end to end with an agent? | No promotion in 20 null campaigns; no finalist in either arm of the real run | `audit/stage3/exit.md` | Yes, as pipeline validation only |
| Stage 4, swarm | Does a swarm run without false promotion? | v1 and v2 failed; v3 passed, none promoted in ten | `audit/stage4/exit.md` | Yes; no pooled bound (finding 4) |
| Stage 5, data integration | Can text sources be bound point in time? | Prospective-only exit; unlocks blocked | `audit/stage5/gpt-exit-review.md` | Yes |
| Stage 6, reference kernels | Does a verified reference agree with the engine? | Lean adopted; 1,196 verdicts and 3,372 runs agreed exactly | `audit/stage6/report.md` | Yes |
| Thesis track | Does the implementation score correctly? | Implementation checks only; seven frozen versions, none completed its window | `audit/stage10/manifest.json` | Parked; no outcome |
| Bug hunts | Does the frozen pilot implement its spec? | Nine reproduced defects remain qualifications | `audit/reviews/2026-11-03-gpt-hunt-kernel.md`, `audit/reviews/2026-11-03-gpt-hunt-gate.md` | Yes |
| Reproducibility | Do the pilot's results reproduce across machines and after the erasure? | Cross-machine runs and the pre-freeze erasure reproduced the recorded results | `audit/crossmachine/freeze.md`, `audit/erasure/reproduce-null.json` | Yes |
| Operations | Do the recorders and the handoff retain what they record? | Overlapping evidence retained; boundary polls exceeded the completeness limit and the L2 clock acceptance was withdrawn | `audit/cluster/handoff.md` | Yes, as qualified |
| The paper's derivations | Does the paper's mathematics hold? | Thirteen of fourteen findings hold in substance; seven corrected, the rest in the defect table | `audit/program/argon-paper-findings.md` | Yes |
| The wall | Can an agent's proposal be confirmed within the calendar? | At 91 days: Sharpe 4.98 on the yardstick, 5.87 exact, 27.6 by the gate | `audit/program/architecture.md`, 2.3; paper, Section 10 | Yes |
