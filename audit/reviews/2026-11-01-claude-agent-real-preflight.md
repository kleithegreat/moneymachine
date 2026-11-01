# Fresh Claude pre-flight: stage 3's real campaign (2026-11-01 06:40 UTC, 01:40 EST)

A fresh Claude Sonnet 5.5 subagent, read only, at `119afd3`, without the advisor's conclusion. Its reply, condensed by the advisor:

- **Verdict: GO AFTER three items; no blocker in the repo, criteria or code.**
- **Held:** clean tree at `119afd3`; `agent-series` Complete (lock free); no `stage3-real*` in `data/agent` (attempt 1, no voids); no `data/holdout/spent.jsonl`; the claim line matches `REAL_REPORT_FROM` 1785542400000 (2026-08-01) and `policy.json`'s `w_end` 1790726400000 (2026-09-30); `check_frozen` passes (`6a335714…`); local `mm` `3a732069…` is the summary's one kernel; 20 ids match the cohort, 0 counted, an audit for each; `audit/holdout.json`'s two hashes match; dataset version 1792613363942 exists and matches `ops/live.py:49`; from `c51f108` to HEAD `kernel/`, `gate/`, `sandbox/` and `harness.json` unchanged.
- **After:** (1) seed first, then append the claim line, as `CLUSTER.md` §2 orders it: a same-id claim seeded into the pod's store would make `real` skip the release and report every finalist missing, a spent window with no evaluation; (2) run `ops/live.py gate` on the digest first; (3) keep the accounts light while the Job runs, and treat an outside stop as the human's, never a fresh id.
- **Noted:** `audit/holdout.json` records 2 files while `data/holdout` has 4 subdirectories; `check_ready` checks only the two (existing behavior).
- (Its reading of the Job's 9,000 s as an active deadline was wrong: it is the termination grace; the Job has no deadline.)
