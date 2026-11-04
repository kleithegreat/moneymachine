# GPT review, round 2: the candidate harness fix, `harness-fix` 0b0364a (2026-10-31 10:30 UTC, 06:30 EDT)

GPT (opencode `openai/gpt-6.1-sol#high`), independent of the Claude builder, read only, from a clean worktree at 0b0364a, after the builder addressed round 1 (`audit/reviews/2026-10-31-gpt-harness-fix.md`). Reply verbatim:

## Verdict: ADOPTABLE WITH CHANGES

Reviewed `0b0364a` against `e305422` and `main`; no files edited.

### First-round findings

1. **Restart loop — resolved for ordinary canary failures.** Thesis no longer runs the canary before acquiring its lock and starting operational loops (`thesis/runner.py:220–231`). Readiness retries using shutdown-aware waits (`thesis/runner.py:133–145`); unavailable service and broken contract have distinct diagnostics (`sandbox/canary.py:82–91`). Shutdown edge cases remain below.

2. **What the canary checks — partially resolved.** It now matches Write inputs, the exact client Bash command and receipt, explicit outside-write/read permission denials, and unexpected tools (`sandbox/canary.py:60–78`). Its description correctly limits it to a sampled smoke test (`sandbox/canary.py:1–5`).
   
   However, `succeeded` means **no recorded failure**, not a recorded successful result (`sandbox/canary.py:63`; `sandbox/session.py:161–169`). A matching tool request with no result passes that predicate. Final nonce bytes cannot independently establish the initial `draft` Write. **Require affirmative successful results and a missing-result counterexample test.**

3. **Staleness/account/session-boundary placement — partially resolved.** Null campaigns select the account before preflight and create their campaign directory afterward (`gate/agent/campaigns.py:207–235,263–270`). Thus ordinary preflight failures neither start nor count a campaign; completed series perform no canary. Thesis checks before each session disclosure (`thesis/runner.py:147–159,108–113`).
   
   **The real-campaign path still bypasses the canary:** `both_arms` calls `wait_for_room`, then directly starts the agent (`gate/agent/campaigns.py:380–384`). **Apply readiness there too, before committing its start/accounting state.**

4. **Denial count — resolved.** Denial entries remain a list and reporting counts entries, including duplicates (`sandbox/session.py:155,168–179`), with regression coverage (`sandbox/tests/test_session.py:12–15`).

5. **Blanket xfail — unresolved.** Only its explanation changed; it still masks any failure inside the pod-view test (`gate/tests/test_agent_real.py:487–501`). **Remove it at adoption/refreeze, or narrowly recognize only the expected freeze mismatch.**

### New outcome-relevant defects

- **SIGTERM during a passing canary can still start a campaign/session.** Neither readiness function rechecks its stop event after the canary returns (`gate/agent/campaigns.py:233–235`; `thesis/runner.py:137–139`). A potentially ten-minute probe can therefore finish after shutdown was requested and launch production work. Forced termination can then consume a thesis date or count an interrupted null campaign as a promotion (`gate/campaign.py:72–74`). **Recheck stop immediately before committing a start.**

- **Interrupted readiness can silently abandon the remainder of a thesis day.** After main runs, SIGTERM during a failed ablation/noread preflight returns without a missed-session disclosure (`thesis/runner.py:137–159`). Restart cannot resume those sessions because scheduling excludes dates whose main session already started (`thesis/runner.py:244–245`). **Resume remaining sessions independently, or explicitly disclose every abandoned session.**

- **The new inter-session waits can launch expired-date sessions.** Success returns before checking the day deadline (`thesis/runner.py:138–143`). Recovery after midnight can therefore start yesterday’s ablation/noread session using its earlier snapshot (`thesis/runner.py:154–159`). **Check deadline before accepting readiness, including after a long probe.**

In-memory checks reproduced the missing-result acceptance and both shutdown failures. No paid CLI calls were made.
