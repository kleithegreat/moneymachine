# Stage 4 exit check against C4.1 to C4.5 (DRAFT, awaiting independent review)

Drafted 2026-11-08 05:30 UTC (00:30 EST). **Not an exit.** Stage 4 is not done until a fresh Claude and GPT review this evidence (`audit/criteria.md`: evidence reviewed before a stage is marked done) and the advisor records the exit. Judged as written, including the C4.5 v3 revision and its qualifications.

- **C4.1 Rules are exact: to be confirmed by the reviewers.** Test: `kernel/mm/tests/rules.rs` (header: C4.1), plus the targeted cases there. Evidence of a passing run on the frozen kernel is not recorded under `audit/stage4/`; the reviewers or exit session run it and attach the output.
- **C4.2 Canonicalization works: to be confirmed.** `kernel/mm/tests/rules.rs` (1,000 rewritten pairs, failures printed) and `kernel/mm/tests/canon.rs` (20+ hand-built pairs, rejected-law counterexamples distinct keys). Same note: attach a run.
- **C4.3 Swarm isolation and accounting: met on the face of the summary, to be confirmed.**
  - Each agent passes the C3.1 audit: all 40 audits `match` (daemon calls equal ledger rows) and `audit_holds` (`criteria/test_stages3to5.py::test_c45_swarm_smoke`, run against `null-summary-v3.json` copied to the test's `null-summary.json`: passes). One audit lists `Edit` outside the permitted set (N2-8 A4; the CLI refused it, no breach), the cause of N2-8's class.
  - Sandbox and socket isolation, history text as data: `gate/tests/test_sandbox.py`, `gate/tests/test_agent_daemon.py`.
  - Evaluations at most 400 and 100 per agent: totals 23 to 53, maximum per agent 17. History replies match ledger rows: enforced by the audit evidence.
  - At least one agent per campaign received another's evaluations: true in all ten (`history`).
- **C4.4 Effective-N report: met.** Every campaign records N_raw, cluster counts at 0.9 and 0.5, zero-fill evaluations, SPA p, screen and StepM at each N and fragility flags (`null-summary-v3.json`: `effective_n`, `zero_fill`). The stage 1 to 3 invariant tests with the key in use are in the suite; attach a run.
- **C4.5 Swarm null smoke test (v3): met as written.** All ten recorded (`null-v3.jsonl`, sha256 `8d9894ce…`); promoted 0, unresolved 1 (N2-8), not established 0; verdict `pass`, computed by `swarm_verdict` (`null-summary-v3.json`, `audit/decisions.md` 2026-11-08 05:30 UTC (00:30 EST)). Reporting items present, diagnostics empty (no finalists). N2-8's unresolved class does not change the verdict whether kept or counted established. Pooled over versions: 0 of 12 promoted, bound 0.221.

**Open before exit:** reviews of this evidence; runs of C4.1, C4.2 and the invariant tests recorded; `audit/stage4/null-summary.json` (the file the criteria test reads) written from the v3 summary at exit; the strict-xfail pattern for v1 and v2 stays; stage 4 line in `PROGRESS.md` and `audit/stage4/exit.md` at exit. The qualifications of C4.5 v3 (mechanism-check departures, the unestablished −2 condition) are reported with any exit.
