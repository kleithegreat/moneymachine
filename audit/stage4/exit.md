# Stage 4 exit: C4.1 to C4.5 judged as written

Commit under test: `8dea9c6` (C4.1 merged at `54213e9`). Runs: `runs-v3.txt` (full suite, kernel cargo suite). Criteria: `audit/criteria.md`, stage 4, with the C4.5 v3 revision (2026-11-02 12:54 UTC (07:54 EST)). The exit decision: `audit/decisions.md`, 2026-11-08 advisor entry "stage 4 exits".

| Criterion | Status |
|---|---|
| C4.1 Rules are exact | met as written |
| C4.2 Canonicalization works | met as written |
| C4.3 Swarm isolation and accounting | met as written (for established campaigns) |
| C4.4 Effective-N report | met as written |
| C4.5 Swarm null smoke test | v1 and v2 failed; v3 met as written |

No criterion is under amendment. C4.5 v1 and v2 stay failed (strict xfails in `criteria/test_stages3to5.py`); v3 is a new version on fresh evidence, never a pass of either.

- **C4.1: met.** `kernel/mm/tests/rules.rs` takes each rewrite from `canon::rules()` (no copy of R): 16 rules x 1,000 random programs x markets N1, N2, N3, every shared node's stream bitwise and the run compared, plus the named signed-zero, undefined-condition, warm-up, listing/delisting and recompute-boundary cases, each asserted to match. Every inexact mutant tried fails it alone (`audit/reviews/2026-11-08-opus-stage4-c41.md`, finding 3); the review's earlier m1 is an equivalent mutant (finding 2). Build and mutants: `c41-rebuild.md`, `cargo-c41-rebuild.txt`. Reviewed by a fresh Opus: items 1 to 3 of `audit/reviews/2026-11-08-opus-stage4-exit.md` met; its item 5 fixed and rerun.
- **C4.2: met.** `kernel/mm/tests/keys.rs`, `canon.rs`: 1,000 rewritten pairs (the generator applies `sub-zero`), 0 unmerged (bound 10); 20 hand-built pairs (at least 20 required); the 11 rejected laws, min and max commutativity included, have distinct keys; fresh processes agree on every key of the pairs, hand-built and rejected programs.
- **C4.3: met.** 40 agent audits, daemon calls equal ledger rows in all; 39 satisfy `audit_holds`, N2-8 A4's does not (it attempted `Edit`, which the CLI refused; no breach), which is why N2-8 is unresolved, and the test checks `audit_holds` for established campaigns only. Isolation and injection tests: `gate/tests/test_sandbox.py`, `gate/tests/test_agent_daemon.py`. Evaluations 23 to 53 per campaign (total at most 400), at most 17 per agent (at most 100); cross-agent history received in all ten.
- **C4.4: met.** Every campaign records N_raw, clusters at 0.9 and 0.5, zero-fill evaluations, SPA p, screen and StepM at each N and fragility flags (`null-summary-v3.json`). The stage 1 to 3 invariant tests pass with the key in use (full suite, `runs-v3.txt`).
- **C4.5 v3: met as written.** Ten campaigns recorded (`null-v3.jsonl`, sha256 `8d9894ce…`); promoted 0, unresolved 1 (N2-8), not established 0; verdict `pass` (`null-summary-v3.json`, copied to `null-summary.json` for the test). N2-8 stays unresolved, never reclassified; it would not change the verdict. Pooled over versions: 22 started, 21 known non-promotions (bound 0.133), one unknown (v2's crashed N2-9; 0.198 if counted a promotion); the frozen summary's "0 of 12, 0.221" omitted v2 (`audit/decisions.md`, 2026-11-08 06:10 UTC (01:10 EST)).

**Reviews of the evidence:** GPT and Sonnet (`audit/reviews/2026-11-08-{gpt,sonnet}-stage4-evidence.md`), Opus's exit review and C4.1 review (`audit/reviews/2026-11-08-opus-stage4-{exit,c41}.md`).

**Qualification (also PROGRESS.md):** C4.5 v1 and v2 failed; v3 passes as written, N2-8 unresolved (A4's refused `Edit` fails `audit_holds`). A smoke test with no finalist in any campaign, so the holdout and betting path never ran; the 2026-11-03 and 2026-11-04 mechanism-check qualifications stand. Neither swarm error control nor power is shown. The series report reads only logs in `data/agent` and omits v2.
