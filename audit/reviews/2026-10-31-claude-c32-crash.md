Fresh-context Claude session (Opus), 2026-10-31 ~05:00 UTC (01:00 EDT), consulted before the C3.2 v2 decision, without the advisor's plan. GPT was asked the same questions separately.

# Review: C3.2 series crash (agent-null-N2-0..19)

I didn't edit, commit, deploy or start anything. My only writes were in my scratchpad: a pod-faithful simulation. It used bwrap with a read-only root, `data/` hidden except a scratch `data/agent`, and `CARGO_TARGET_DIR=data/agent/kernel` holding the seeded mm (3a732069, the same as the mirror's copy). The only market data it read was synthetic null-market output, and the search-store funding was read only to hash it.

## 1. Root cause: confirmed, and nothing else fails before the model session
- **Cause.** `gate/nulls.json:70` sets N2 funding to `store: "data/store"`. The chain is `markets.funding_source` (markets.py:78-84), then `store_funding` (markets.py:59-62), then `Store.as_of`, which returns None silently when the dataset is absent (ingest/store.py:114-116). The `agent-series` pod mounts only `agent` (ops/live.py:47-48, 66-68). The simulation reproduces the exact traceback and `AttributeError`.
- **Why there are no campaign directories.** `generate` runs before `markets.write` creates `OUT/cid` (campaigns.py:105), so no directory exists for any of the 20. The mirror confirms only `agent-null.jsonl` and `kernel/`. `resume` therefore adds no "interrupted" rows. The 20 rows are the whole v1 record.
- **The rest of the path works in the pod's view.** I ran the simulation again with the N2 arrays loaded from the staged blob, which I verified against nulls.json's sha256 `d07162b8…`. The full non-model path ran end to end: `check_frozen`, market write, daemon `mm eval` x3, the real `search_decision` (SPA), `mechanism_check`, freeze, `holdout_decision`, and `audit_run` (match true).
- **Other inputs are all in the image or the volume:** `sweep.cost_cells` (repo `venue/`), DSL.md and brief.md, `audit/stage3/harness.json`, `audit/stage2/searcher.json`, and mm at `data/agent/kernel`. Temp files go to `/tmp`, which is an emptyDir. `check_frozen` passed in the pod in v1, so the pod's harness identity matches the frozen one. The sandboxed session, `nix-store -qR` and the token were already proven by `gate_run` and by the thesis track.
- **What I couldn't check here:** memory under the 6Gi limit (a campaign has been measured at 0.5–0.7 GiB) and a real 2 h session in this pod.
- **The local hash still reproduces.** `store_funding` from this PC's `data/store` gives `d07162b8…`, so a blob-fed N2 is byte-identical to the frozen null model. The fix does not change C3.2's null design.

## 2. Simplest fix, reusing the batch mechanism
Batch Jobs already solve this. `ops/jobs.py:107-117` (`stage_funding`) stages the arrays under their frozen sha256. `ops/jobs.py:169-182` (`task`) loads them into `spec["arrays"]`, which `funding_source` already accepts. The blob already exists at `/srv/moneymachine/inputs/d07162b80359580d73d78934aa2cba4a47d6e0ce7c14153d6f32ca2adf295c39` (2.3 MB).
- **Move `task`'s inline blob loading into `markets`** as one function (verify the sha256, reshape, return `(F, P)`). Call it from `jobs.task` (directory `/inputs`) and from `campaigns.null_market` (directory `OUT / "inputs"`).
- **Seed the blob:** `ops/live.py seed <digest> agent /srv/moneymachine/inputs/d07162b8…:inputs/d07162b8…`.
- **Fail loudly at the source:**
  - `store_funding` raises when `as_of` returns None.
  - `funding_source` checks the frozen sha256 on every path. Today only the batch path checks it; the PC path never has.
  - The hash checks in `stage_funding` and `task` then become redundant; delete them.
- **Don't edit nulls.json.** NULLS.md:129 freezes it by sha256, and seeding into the volume can't make the relative path `data/store` resolve anyway.
- **None of these files are in `harness_hash`** (harness.py:26-31 covers brief, research and swarm .md, daemon.py, harness.py, and sandbox/{session,server,client,egress}.py). Keep it that way.

## 3. Prevention that leaves crash counting unchanged
- **The test gap.** The only `agent_null` test stubs `null_market` (gate/tests/test_agent_real.py:358-369). `test_under_a_read_only_root` (same file, :378-383) uses `--ro-bind / /`, so it still sees `data/store`. No null campaign has run end to end since the Oct 19 local dry run (`data/stage3/c32-N2-dryrun-2`), and none ever ran in a pod.
  - **Fix:** a test in that bwrap pattern that adds `--tmpfs REPO/data` with a tmp `data/agent`, and runs `agent_null` without stubbing `null_market` (session stubbed through the real daemon, as in `Campaign.session`). My simulation shows this catches the bug.
  - **Outcome it protects:** any pod-only missing input showing up as counted promotions.
- **A precondition before the first id**, of the same kind as `check_frozen` at campaigns.py:222. Resolve the N2 funding blob, compute `sweep.cost_cells()` and check mm exists, all before `campaign.resume` hands out ids. A failure exits with nothing started, so nothing is counted.
- **Optional:** stop the series once counted promotions reach 3. The verdict is then fixed, so this saves usage without changing what counts. v1 burned all 20 ids in seconds.

## 4. `need()` / `wait_for_room` and the crash rows
- **The crash rows replace the default.** `need(log, "TAMU")` (campaigns.py:157-169) now returns `{five_hour: 0.01, seven_day: 0.0}`, because row 0 went 0 to 0.01 and the others 0.01 to 0.01. These are measured values, so they replace `FIRST_NEED` 0.5.
  - **Effect:** a rerun appending to this log would start a 2 h Opus session on TAMU at up to 0.79 utilization, so the subscription can run out mid-session.
  - **Outcome:** a counted crash or a truncated arm A in C3.2 v2. `max()` corrects it only after a real TAMU row exists.
- **The real campaign reads the same log.** `both_arms` paces on the literal `OUT / "agent-null.jsonl"` (campaigns.py:323). If v2 writes elsewhere, arm A of the one real attempt is still paced by the 0.01 crash rows.
  - **Outcome:** the one real attempt's arm A cut off mid-session. If that happens with zero evaluations, the session reached its own end, so the attempt is void; otherwise it stands truncated.
- **Mutual exclusion is tied to the same literal name.** `real()` locks `OUT / "agent-null.jsonl"` (campaigns.py:399). A v2 series writing another log would not exclude `agent-real`.
  - **Outcome:** the series and the real campaign could overlap and drain the same subscription.
- **Fix:** derive the series log path in one place and use it in `run_series` (:215), `summary` (:458), `both_arms` (:323) and `real` (:399). A fresh log for v2 then removes the crash rows from `need` with no special case.

## 5. Constraints on naming, recording and judging
- **v1 failed as written.** C3.2 (criteria.md:382) counts every started campaign and a crash as a promotion: 20 > 2. Under CLAUDE.md the remedy is a new version on fresh evidence. That means a dated revision beneath C3.2, labelled as a new version, never a pass of v1. It names the v2 campaign ids and log, and states v2 is judged on those alone. It is reviewed, then committed alone as `criteria: stage 3` before v2 starts. It also needs a `decisions.md` entry (what, why, reviewers, how to reverse) and a Stage 3 line in PROGRESS Qualifications ("C3.2 v1 failed: 20 crashes, N2 input missing in the pod; met only under v2", if it passes).
- **Ids must differ.** `resume` (campaign.py:63-78) treats all of `agent-null-N2-0..19` as done, so rerunning the current Job does nothing. Market seeds are `seed(cid)`, so fresh ids also mean fresh null markets. Use a versioned prefix with its own log, e.g. `agent-null-2-N2-{i}` and `agent-null-2.jsonl`. Never delete or move v1's log.
- **Evidence and gate files are hard-wired to n == 20.** `check_ready` (campaigns.py:269-271) and `test_c32_smoke_calibration` (criteria/test_stages3to5.py:11-13) both read `audit/stage3/null-summary.json` and require n == 20 and ≤ 2.
  - Commit v1's record, i.e. the mirror log (sha256 `9f7d88b6…` per MANIFEST) and its summary, under a v1 name, with a `xfail(strict=True)` test whose reason names the record.
  - v2's summary takes the file the gate reads. If v2 appended to the same log, `summary` would report n=40 and v2 would be unjudgeable.
- **Harness.** If the fix stays out of the hashed files, the frozen harness holds and fresh ids are needed only by the human's decision. A latent defect: `freeze_harness`'s "a campaign started" guard (campaigns.py:43-50) inspects this PC's `data/agent`, where the log is empty, not the cluster's. A refreeze would pass here despite v1.
  - **Outcome:** a harness change slipping past the fresh-id rule. Fix it if any harness file is touched; otherwise note it.
- **Kernel.** v1 and the planned real campaign both use mm 3a732069. The series rows don't record mm's sha256, while `inputs()` does for the real campaign. Adding it to v2 rows, or once at series start, makes C3.2's kernel identity auditable. This can't change a verdict.
- **Image.** v2 needs a new image digest, and its record should name it. This doesn't conflict with "never push for the series": that rule is about one series' image, and v2 is a new series. The real campaign's preconditions (C3.2 "recorded and passed", same harness, searcher, kernel and inputs) are met by v2's summary. Holdout claims are not touched.

## Recommended plan
1. Write the C3.2 v2 revision (ids `agent-null-2-N2-0..19`, log `agent-null-2.jsonl`, judged on those alone), get one review round, then the human commits it as `criteria: stage 3`. Log it in decisions.md and add the Qualification.
2. Commit v1's evidence (log plus summary under a v1 name) with an `xfail(strict)` test naming it.
3. Code, all outside the harness hash:
   - the shared blob loader in `markets`, used by `jobs.task` and `null_market`;
   - `store_funding` raising on None and the hash check inside `funding_source`, with the duplicate checks deleted;
   - one series-log path used by `run_series`, `summary`, `both_arms` and `real`;
   - the input precondition before the first id;
   - mm sha256 in each row;
   - the bwrap test with `data/` hidden.
   Update the CLUSTER.md `agent-series` and `agent-summary` lines (CLUSTER.md:54, 112-114).
4. Seed the blob into `agent`, push the new image, delete the old `agent-series` Job and apply. Confirm the first v2 campaign reaches a session.
5. After v2: summary, commit it, then `agent-real`, which locks and paces on v2's log.
