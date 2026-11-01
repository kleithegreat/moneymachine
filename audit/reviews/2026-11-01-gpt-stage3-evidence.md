# GPT review: stage 3's evidence before exit (2026-11-01 07:33 UTC, 02:33 EST)

GPT (opencode `openai/gpt-6.1-sol#high`), read only, from a clean worktree at `bc419f4`. Its reply from its verdict, verbatim:

**Not yet: the supplied evidence does not establish every exit requirement. Zero finalists are permitted; exercising the holdout is not the missing requirement.** No files were edited.

### C3.1 — Not fully established as written

The positive evidence is substantial:

- `audit/cluster/gate-unmasked.json` records six passing sandbox tests and matching frozen/deployed harness hashes.
- All 20 v3 audits match their ledger-row sequences, with no permitted-boundary violations (`audit/stage3/null-v3.jsonl`, `null-summary.json`).
- The real campaign records 20 daemon calls matching 20 ledger rows, with no outside-permitted calls (`audit/stage3/real.json:31–42`).
- Recorded denials are not themselves failures, as the 2026-10-31 23:12 decision explains.

**Missing:** demonstrated daemon-test results covering every required override, the **101st evaluation**, and the disclosure restriction. The cluster receipt runs only `gate/tests/test_sandbox.py` (`ops/live.py:304–308`). `gate/tests/test_agent_daemon.py:25–44` tests a three-evaluation budget and store/ledger override attempts; that is not evidence of the entire frozen checklist.

### C3.2 — Met only under C3.2 v3

Under the **2026-10-31 23:31 UTC (19:31 EDT) revision**, all 20 declared fresh v3 IDs are present exactly once. Each completed cleanly, made 6–22 evaluations, and recorded no promotion, crash or zero-evaluation outcome: **0 counted promotions ≤ 2**. Harness and kernel identities agree across the cohort and real report.

`null-summary.json:315–355` supplies SPA, maximum-DSR and screened-count summaries beside G100’s N2 baseline, and explicitly labels the result a smoke test—not general error-control evidence. The applicable geometry is the revised day-670, 360-step holdout, not original day 640.

The earlier records remain:
- **v1 failed:** 20 counted crashes.
- **v2 established no procedure:** zero evaluations throughout; its numerical 1/20 is not a pass.

### C3.3 — Permitted under revisions, but not fully evidenced

`real.json` records one nonvoid real attempt, A’s nine evaluations, B’s 100, the matching kernel/harness, and zero finalists in both arms.

The **2026-10-31 00:05 and 00:22 UTC (2026-10-30 20:05 and 20:22 EDT) revisions** expressly allow no batch and empty release-dependent items here. Missing holdout returns, mechanism differences and diagnostics are therefore **not deficiencies**.

However, the supplied report does not demonstrate the remaining ledger requirements: the agent’s recorded selection, candidate predictions, and both committed finalist freezes. `campaigns.py` shows the intended write path, not the actual ledger contents. Ledger inspection or an auditable extraction is needed to substantiate those obligations.

### C3.4 — Met under the zero-finalist revision

`real.json:159–182` reports every applicable comparison field. Distinct canonical counts and N are correctly separate: A **7/7**, B **96/94**. Finalist-specific quantities are legitimately empty. The report explicitly disclaims generator superiority; I find no unsupported comparative claim.

**Does `released: false` suffice? Yes.** Together with both empty finalist sets, it states in structured form that release was not exercised. The criterion prescribes neither a particular field nor an exact prose sentence. Requiring magic wording would add a criterion. An explicit sentence would nevertheless improve clarity.

### Required exit reporting

Before marking done, substantiate C3.1’s daemon checks and C3.3’s ledger obligations. Do not rerun either research arm or release the holdout merely to fill empty items.

The stage report and `PROGRESS.md` Qualifications should state:

- **C3.2 v1 failed; v2 established no procedure; met only under v3, 0/20.**
- C3.3/C3.4 use the dated zero-finalist revisions: **no finalists, no promotions, release path unexercised, holdout unreleased**. Preserve the local reservation; this authorizes no reuse.
- Pipeline validation only—not evidence of edge, absence of edge, or generator superiority; mechanism/holdout branches were unexercised.
- Retain near-zero power, historical/post-holdout cost fitting, C0.7’s coverage qualification, and bankruptcy reporting: none recorded in v3 or the real campaign.

The decision log’s claim that launching necessarily spent the holdout must not be repeated as the observed outcome.
