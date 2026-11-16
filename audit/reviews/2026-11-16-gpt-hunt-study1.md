# GPT's bug hunt of study 1 before its exit

Model `openai/gpt-6.1-sol#high` (opencode), read-only except for its `hunt/` folder, from a clean worktree of `study1-build` at `f125937`. The failing tests it wrote are in `2026-11-16-gpt-hunt-study1/`. The advisor ran them at that commit: all 9 tests of the 8 findings fail on the behaviour each names. The prompt follows the reply. The reply, verbatim:

## Findings, ranked by severity

**Eight findings; regression tests written but not run.** These are reachable failure cases, not evidence that the current calibration encountered them.

1. **High — A kill can count an unserved model’s pick as the agent’s win.**  
   `sandbox/session.py:126–134`; `gate/control/runner.py:154–158`.  
   Transcript writes are buffered. An unserved model can supply a response and complete an evaluation before its assistant line reaches disk. Kill the runner then: recovery sees no disallowed id, accepts `all([])`, and counts its earning pick. **Changes agent wins and potentially CS1.1 to Met.**

2. **High — Concurrent restarts can count one market twice and skip another.**  
   `gate/control/runner.py:209–230`.  
   Start two runners recovering the same launched session. Both read the same result prefix, judge the same ledger, and append that market. Subsequent indexing uses the number of lines rather than their identities, skipping a manifest market. **Changes market counts, outcomes entering the sequential test, and potentially its verdict.**

3. **High — Execution costs can change between arms without failing verification.**  
   `gate/control/manifest.py:65–76`; `gate/sweep.py:38–44`.  
   Freeze the manifest and run G100, then change `venue/hyperliquid/execution.json` before running the agent. The file is not hashed; verification passes while newly generated markets use different costs. **Changes picks and earning classifications; the arms need not search the same markets.**

4. **High — The agent’s DSL instructions remain outside both frozen identities.**  
   `gate/agent/harness.py:21–31`; `gate/control/manifest.py:50–62`.  
   Change `kernel/DSL.md` after freezing. The agent receives the changed instructions, but neither the harness hash nor the manifest detects them. G100 does not read them. **Can change only the agent’s search and therefore CS1.1.** This omission from the November 2 hunt remains present.

5. **High — `--end` can permanently discard an already-spent session.**  
   `gate/control/runner.py:234–239`, `213–215`.  
   After eight discordant wins, kill the ninth session after it has kept an earning pick, then invoke `--end`. It records an early end at eight markets without judging that ledger; subsequent starts return immediately. **Produces Inconclusive at eight instead of Met at nine, losing one started market.**

6. **Medium — A partial result line prevents all subsequent recovery.**  
   `gate/control/runner.py:62–73`, `213`.  
   Leave a partial ninth result append after eight wins, with the ninth session’s files intact. Every restart raises `JSONDecodeError` before recovering its pick; the report also cannot parse the file. **Blocks recording the ninth market and its otherwise-Met verdict.**

7. **Medium — Calibration merges are not crash-safe.**  
   `ops/jobs.py:488–498`, `539`; `gate/control/calibrate.py:127–136`.  
   Two triggers:
   - Kill after renaming a small share but before flushing the merged handle: its completed trials survive only in an archive that same-run recovery ignores.
   - Leave a partial merged line, then retry: new complete records append behind it, but parsing stops at that fragment forever.  
   **Loses completed trial records, repeats evaluations, and can prevent calibration from producing a strength/report.**

8. **Medium — A partial daemon-log line blocks judging an intact ledger.**  
   `gate/agent/campaigns.py:135–141`, `673–677`; `gate/control/runner.py:156–157`.  
   Kill during the daemon’s last log append after its evaluation committed. Evaluation counting parses the fragment and raises before consulting the final ledger or judging its pick. **Leaves the market unrecorded; the test’s ninth winning pick cannot establish Met.**

## Test files

Same order as the findings:

1. `hunt/test_killed_transcript_model.py`
2. `hunt/test_runner_concurrent_resume.py`
3. `hunt/test_manifest_execution_costs.py`
4. `hunt/test_harness_dsl_identity.py`
5. `hunt/test_end_with_kept_session.py`
6. `hunt/test_runner_torn_result.py`
7. `hunt/test_calibration_merge_crash.py`
8. `hunt/test_killed_daemon_log.py`

## Prompt

You are the fresh bug hunter for study 1 before its exit (CLAUDE.md, Correctness: "One fresh session hunts bugs in the code a stage rests on before its exit"; the failure this prevents is `audit/reviews/2026-11-02-gpt-hunt-*.md`). This worktree is branch `study1-build` at f125937, the code study 1's calibration is running on now. Its brief is `plan/1-positive-control.md`; its criterion is CS1.1 in `audit/criteria.md` (read from "criteria: study 1" to the end of that stage, with its definitions); `PROGRESS.md` gives the state. You did not build this code (Sonnet did; you wrote some of its tests).

Hunt for defects that could change CS1.1's verdict or any number it reads: the calibration (`gate/control/calibrate.py`, `ops/jobs.py` calibrate and its shares, merge and resume), the markets and the plant (`gate/control/`, `gate/markets.py`), G100's 100 evaluations and the agent's session as judged (`gate/control/judge.py`, `pick.py`, `pairs.py`, `measure.py`, `manifest.py`, and what of `gate/agent/` they call), and the judge's mapping from runs to Met, Not shown and Inconclusive. Priorities: (1) anything that biases the agent against G100 or the reverse; (2) anything that lets a run count twice, be lost, or be judged on the wrong markets or strength; (3) resume and crash paths (a kill mid-round, a partial last line, a retried round); (4) a mismatch between the brief or criterion and the code. Do not report style, and do not report a finding that cannot change an outcome; note those in one line at the end if at all.

For each finding: file and line; the concrete input or sequence that triggers it; the outcome it changes (CS1.1's verdict, the calibrated strength, a count); and a failing test, written as a pytest file under `hunt/` (one file per finding, importing the repo's modules as its existing tests do, no network, no real data, runnable with `pytest hunt/<file>` from the repo root in `nix develop`). You cannot run anything, so write each test carefully. If you find nothing that changes an outcome, say so plainly; a clean result is a good result. Reply: findings ranked by severity, then the list of test files.
