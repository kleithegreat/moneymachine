GPT (opencode, openai/gpt-6.1-sol#high), 2026-10-31 ~07:00 UTC (03:00 EDT), from a clean worktree of main at 471a502: one review round of (1) the draft C3.2 v2 revision, (2) its code (5deda82, 1813e6a), (3) stage 3's real campaign (the review queued since 2026-10-30). Prompt in the advisor's transcript.

Acted on before v2 starts (1a3ae63): section 2 findings 1 and 3. Section 2 finding 2 and section 3 go to a builder before agent-real.

**The draft revision is sound. The code is not ready to run unchanged.** Findings below are ranked by consequence within each execution step.

## 1. C3.2 revision

**Fine as written.** It preserves v1’s failure, fixes v2’s cohort before execution, excludes v1 from judgment and pacing, retains crash accounting, and binds the real campaign to v2’s kernel. It does not turn fresh evidence into a retrospective pass.

No outcome-changing wording finding.

## 2. C3.2 implementation

1. **High — a crashed session can count as a non-promotion.**  
   `gate/agent/campaigns.py:122–129` counts exceptions and missing `daemon.log`, but ignores the returned session’s terminal status. The harness returns nonzero or signal exits as ordinary records (`gate/agent/harness.py:39–46`; `sandbox/session.py:146–148`). Thus a session killed after one daemon call can leave no promotions and count as successful smoke evidence.  
   **Outcome:** three or more null crashes can incorrectly become a C3.2 pass. Classify actual session crashes explicitly; do not import the real-only “complete with whatever it evaluated” exception.

2. **High — failed null-run audits do not block the real release.**  
   `gate/agent/campaigns.py:128–129` records audit failures without enforcing them. `summary` drops those audits (`:484–489`), and `check_ready` checks only cohort, kernels and promotion count (`:291–294`).  
   **Outcome:** the real campaign can start despite unmet C3.1, including unreconciled disclosures. Preserve every campaign’s accounting, but require the null-run audits to establish C3.1 before release.

3. **Medium — recovery loses kernel provenance and silently accepts the omission.**  
   Interrupted campaigns receive rows without `mm` (`gate/campaign.py:72–74`). The summary excludes missing hashes (`gate/agent/campaigns.py:485`), so one or two such rows can coexist with an accepted same-kernel summary.  
   **Outcome:** the draft’s kernel prerequisite can be reported satisfied without evidence for every campaign. Persist kernel provenance before campaign work and recover it; unresolved provenance must not silently disappear.

**Fine:** the shared hash-verified funding loader preserves the existing blob representation (`gate/markets.py:78–101`; `ops/jobs.py:107–114,168–170`). Input preflight, directory-before-generation, the common cohort/log definition, seeding command and pod-view regression test address the demonstrated v1 failure. Ignoring tokenless rows implements the human’s pacing decision.

## 3. Real campaign

1. **High — an externally killed child can still become a repeatable void.**  
   `gate/agent/campaigns.py:352–356` distinguishes external stops only through `run["crashed"]`, which `run_record` supplies when the record is missing. But killing the session child while its runner survives produces a normal `run.json` containing a signal/nonzero exit (`sandbox/session.py:126–148`; `gate/agent/harness.py:39–45`). With zero evaluations, that attempt is voided automatically.  
   **Outcome:** the operator-stop selection channel prohibited by `audit/criteria.md:370` remains open. A surviving run record is not sufficient evidence of a session-owned exit; unresolved external/signal deaths must go to the human.

2. **High — recovery can change the dataset version without failing the input check.**  
   `both_arms` overwrites `m/version` on every entry (`gate/agent/campaigns.py:344`). The immutable input receipt hashes files, not the selected version (`:277–282,305–309`). After A ends but before `pre-release.json`, resuming with another version can therefore combine A’s old-version evaluations with new-version mechanism checks, B and holdout evaluation.  
   **Outcome:** an invalid mixed-version campaign can consume the sole release and change finalists or promotions. Freeze the version before A and reject recovery arguments or ledger identities that differ.

3. **Medium — an interrupted run-record disclosure can be skipped permanently.**  
   A valid `run.json` is returned without checking its ledger disclosure (`gate/agent/campaigns.py:321–330`). Both normal and reconstructed paths write the file before disclosing it (`gate/agent/harness.py:43–45`; `campaigns.py:329–330`). A death between those operations leaves a receipt that recovery accepts, while `audit_run` excludes run disclosures (`campaigns.py:78–80`).  
   **Outcome:** release can proceed without C3.3’s required ledger-held transcript/run evidence. Reconcile the receipt with the ledger before proceeding.

**Fine:** claimed batches are never completed by reevaluation; missing finalists retain p = 1 and return 0 in their original Holm families; promotions are committed before diagnostics are parsed; zero finalists leave the holdout unspent; and reports are recoverable on writable storage. The registered mechanism-reporting exception does not reopen promotion decisions.

Read-only review; no tests, workloads, edits or deployments were started.

COMMIT (as is)
