# GPT pre-flight: stage 3's real campaign (2026-11-01 06:40 UTC, 01:40 EST)

GPT (opencode `openai/gpt-6.1-sol#high`), read only, from a clean worktree at `119afd3`, without the advisor's conclusion. Its reply from its verdict, verbatim:

## Verdict: GO AFTER the checks below—not an unconditional GO.

**The committed prerequisite evidence is sound.** At HEAD `119afd3`, I reconciled `null-summary.json` with `null-v3.jsonl`: exactly 20 unique v3 campaigns, zero counted promotions, 6–22 evaluations each, matching audits, one kernel (`3a732069…`) and the frozen harness (`6a335714…`). Earlier failures remain failures (`audit/criteria.md:394–399`). This review checkout has **no `data/`**, so it cannot establish this PC’s actual input or spent-state readiness.

### Must verify before the local claim/apply

1. **Correct initial inputs—not merely unchanged inputs.**  
   `gate/agent/campaigns.py:329–340` records the initial input hashes, version and report start, but does not establish that the initial policy/version/store are the registered ones. Its holdout check verifies listed manifest entries, not an exhaustive inventory.

   On this PC, compare the store policy with `policy.json:2–6`; verify dataset version **1792613363942**, the frozen universe/venue files, and report interval **[1785542400000,1790726400000)**. Hash every eligible input; reconcile all holdout Parquet paths against `audit/holdout.json:1–12`, investigating unrecorded additions. Confirm no uncalibrated event dataset (`criteria/test_stages3to5.py:72–83`).

   **Outcome:** leakage, changed finalists/false discoveries, or an invalid attempt.

2. **No prior attempt or claim, including the same campaign ID.**  
   Inspect claim records and attempt-file inventories on this PC and the authoritative agent volume: `stage3-real*`, `void.json`, `pre-release.json`, run records and ledger integrity/counts. Confirm no concurrent real runner and that the series has ended.

   This matters because `check_ready` excludes same-ID claims (`campaigns.py:330`), while `real` interprets one as a release already attempted and skips evaluation (`:485–490`).

   **Outcome:** a doubly spent holdout, or a fresh campaign incorrectly reported as an incomplete prior release.

3. **Preserve the exact seed/claim sequence.**  
   Follow `CLUSTER.md:105–119`: successfully seed and verify the **unclaimed** cluster copy first; durably append the PC reservation second; apply third. Verify destination inventory too: seeding checks copied files but does not reject unrelated extra files (`ops/live.py:169–178`). Never reseed from the now-claimed PC copy or remove its reservation after a void/zero-finalist outcome (`audit/decisions.md:395`).

   **Outcome:** a wasted release, skipped evaluation, or second-release opportunity.

4. **Deployment identity and capacity.**  
   Before reserving locally, verify the pushed digest contains committed HEAD and its summary; compare deployed harness/searcher pins and seeded kernel SHA-256 with the committed evidence. Record commit, digest, input hashes and attempt ID. Check PVC/scratch space, permissions, mirror health, account/model availability and pacing; let `ready` perform its canary (`campaigns.py:231–238`).

   **Outcome:** an avoidable void/crash or unaccountable attempt.

### Execution constraints

Do **not** invoke `real` as a dry run; even `check_ready` writes state (`campaigns.py:326–340`). Inspect metadata, hashes, claims and ledger integrity only—no holdout prices/returns, and no running arm-A transcript (`audit/criteria.md:370`).

Only a qualifying zero-evaluation attempt may advance IDs. An unresolved outside stop goes to the human, not an autonomous retry (`campaigns.py:397–405`). Missing released finalists remain p=1; never complete them later (`audit/criteria.md:402`).

The acknowledged near-zero power and historical-cost qualifications are **not new blockers**. No files were edited.
