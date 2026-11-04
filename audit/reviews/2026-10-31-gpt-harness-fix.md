# GPT review: the candidate harness fix, `harness-fix` e305422 (2026-10-31 10:25 UTC, 06:25 EDT)

GPT (opencode `openai/gpt-6.1-sol#high`), independent of the Claude builder, read only, from a clean worktree at e305422. Reply verbatim:

## Verdict: ADOPTABLE WITH CHANGES

The scoped permission repair is reasonable. The new canary’s verification and lifecycle need changes before adoption.

### Findings, ranked

1. **HIGH — Paid restart loop can consume subscriptions and interrupt C10.5 operation.**  
   `thesis/runner.py:207–219`; `sandbox/canary.py:40,54–55`; `ops/live.py:46,98–100`.

   A transient API failure, exhausted subscription, or model skipping a requested probe makes the canary raise. The thesis StatefulSet then restarts indefinitely, running another paid canary each time. This happens before acquiring the runner lock, installing its shutdown handler, or starting resolutions, marks and scheduling. It can therefore lose operational evidence as well as budget.

   **Required:** acquire the lock first; handle canary failure inside a bounded, shutdown-aware wait/park path rather than relying on container restarts. Reuse existing availability/backoff concepts, and distinguish service unavailability from a demonstrated contract failure.

2. **MEDIUM — The canary does not establish several capabilities it claims to establish.**  
   `sandbox/canary.py:43–54`; `sandbox/tests/test_canary.py:18–33`.

   `write` checks final bytes, not successful Write calls. `client` checks receipt, not the requested Bash invocation. The scripted “passing” test supplies neither a successful Write result nor a client Bash call. I also confirmed that adding a workspace-Write permission denial to that scripted transcript still passes.

   The fresh workspace and nonce should catch the original, otherwise-isolated “all writes denied” failure. However, an alternate writer introduced by an isolation regression could satisfy these checks while Write remains denied. Outside writes need only report *some* error, not a permission refusal. Outside Reads and unexpected tools are unchecked; denying one `touch` does not establish that **any** non-client Bash is denied.

   **Required:** verify the intended create/overwrite and client calls against their inputs and successful results; add counterexample tests. Check meaningful outside-read/permission boundaries and unexpected tools, while describing this as a sampled contract smoke test—not complete isolation proof.

3. **MEDIUM — Startup success can become stale before production sessions.**  
   `gate/agent/campaigns.py:251–260`; `thesis/runner.py:133–146,207`.

   The series canary runs before pacing selects an account, potentially hours before the first campaign. It uses the generic token even when TAMU will run the campaign. Thesis checks only once per potentially month-long process. Consequently, a canary can pass while later production sessions cannot write, recreating zero-evaluation null runs or absent registrations if remotely controlled CLI behavior changes.

   **Required:** put readiness checking at the actual session boundary, after account selection and before recording a new campaign/session as started. Avoid additional paid checks for completed/no-op series. A failed preflight must remain outside campaign accounting.

### Other requested checks

- **Permissions:** `sandbox/session.py:38–42` exposes only Read, Write and Bash; Edit remains unavailable. Replacing inert `Write(//work/**)` authorization with scoped `Edit(//work/**)` does not appear to widen the **intended** frozen contract (`audit/criteria.md:356–358,693`). No mounts, client execution mechanism, network access or daemon disclosures are expanded. This repairs the permission expression rather than adding a second writing channel.

- **Freeze guard:** `gate/agent/campaigns.py:43–52,445–451` sensibly checks declared cohorts and the first non-void real attempt. Earlier void attempts remain preserved. Current v2 IDs correctly prevent freezing until successor IDs are declared. The initial series canary failure creates no campaign directory and is not counted as a campaign.

- **Audit refactor:** ordinary, unique-ID transcripts retain tool names and client-invocation counts. One reporting difference exists: `sandbox/session.py:168,179` counts **unique denied IDs**, whereas the old implementation counted denial entries. Duplicate entries therefore change the reported number. C3.1’s daemon/ledger matching is untouched, and its verdict ignores denial counts. Preserve the old reporting definition or explicitly document and test the change.

- **Simplicity:** the shared parser is appropriate. Remove the temporary blanket `xfail` at `gate/tests/test_agent_real.py:487–488` when adopting/refreezing; do not leave unrelated pod-view failures masked.

**Validation:** 16 focused tests passed; the paid real-CLI test was skipped. No repository files changed. Adoption still requires the human’s dated revision, fresh null IDs, successor harness freeze and new thesis window—not rehabilitation of earlier evidence.
