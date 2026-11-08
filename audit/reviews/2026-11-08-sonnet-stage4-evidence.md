# Stage 4 exit evidence, fresh Claude (Sonnet) review, 2026-11-08

Recomputed from a /tmp copy of HEAD and of `data/agent`; cargo tests with a /tmp target; the repo untouched. Saved by the advisor (the reviewer was read-only).

**Verdict (reviewer):** stage 4 exits as written on C4.5 v3; C4.1–C4.4 hold on what was run, with a gap in C4.2's fresh-process clause.

## 1. Recomputed classes and verdict

`swarm_evidence` over the ten campaigns (`mm` from the log rows): N2-0 to N2-7 and N2-9 established, N2-8 unresolved; `swarm_verdict` pass, identical to `null-summary-v3.json` (0 promoted, 1 unresolved, 0 not established). All ten `decision.json` exist; every ledger kernel equals the series `mm` (3a732069…), the hash in the stage 3, v1 and v2 summaries. sha256 of `data/agent/swarm-null-3.jsonl` and `audit/stage4/null-v3.jsonl` is 8d9894ce05b37c209930da37b490de857baa0af98eb3b204439385578f363788, equal to the mirror's MANIFEST entry. Per campaign: 25–53 evaluations, 23–53 trials (the draft's "totals 23 to 53" conflates them); agent evaluations 0–17. Agents with no evaluation that received nothing (reported, not counted): N2-1 A1, N2-3 A3, N2-5 A1, N2-6 A2. N2-8's only failing check is A4's audit.

## 2. N2-8 A4

One tool use outside Read/Write/Bash: `Edit` on `/work/s1_xs_funding_carry.json` (message 101), answered "No such tool available: Edit. Edit is disabled for this session"; nothing changed, and A4 then rewrote the file with the permitted `Write`. `outside_permitted` = ['Edit'], so `audit_holds` is false; the daemon-to-ledger audit matched (21 calls, 21 rows). A4's two denials were Bash (`python3 -I -c` snippets parsing a spilled tool-results file), refused, not executed; its egress log shows only CONNECT to api.anthropic.com. No reading changes the verdict: as recorded (unresolved) promoted + unresolved = 1, pass; as benign (established) pass; as a crash after disclosures, unresolved, pass. Only a reading that also made another campaign unresolved could fail (the Bash denials, or N2-5 A3's refused `dangerouslyDisableSandbox`), and the frozen text defines unresolved narrowly; v3 deliberately dropped v2's denial rule.

## 3. C4.1–C4.4 runs

- `cargo test --release -p mm --test rules --test canon`: canon 3/3 (equivalent forms, rejected laws keep distinct keys, 21 hand-built pairs); rules 2/2 in 76.8 s. `every_rule_is_exact`: 16 rules × 1,000 programs × 3 markets; `rewritten_programs_share_a_key`: "C4.2: 0 of 1000 rewritten programs got a different key" (threshold ≤ 10). The whole kernel suite was not run.
- `pytest criteria gate/tests/test_sandbox.py gate/tests/test_agent_daemon.py`: 54 passed, 5 strict xfails (v1, v2 records), with the v3 summary copied to a scratch `audit/stage4/null-summary.json`. History replies match ledger rows; evaluations ≤ 400 and ≤ 100 per agent; cross-agent history true in all ten. C4.4's fields are present (`effective_n`, `zero_fill`, SPA, fragile flags). The full suite was not run, so C4.4's last clause (stage 1–3 invariant tests still pass) is unchecked beyond this subset.

## 4. Readings

Pass while the claim is false: no campaign produced a finalist, so the holdout, Holm and betting path never ran, and an over-promoting swarm would also pass (bound 0.22–0.39); "established" needs only one cross-agent receipt, two active agents and one filled trial; a promotion can't hide behind an unresolved class (promoted dominates); the −2 condition is unestablished (already qualified). Fail while the claim holds: two harness quirks like `Edit` give promoted + unresolved ≥ 2; a crash after a disclosure counts unresolved though the null claim is unaffected.

## 5. Still required (reviewer)

1. Write `audit/stage4/null-summary.json` from the v3 summary (`test_c45_swarm_smoke` reads it).
2. Record C4.1/C4.2's cargo output and a full invariant-suite run under `audit/stage4/`.
3. C4.2's fresh-process clause has no dedicated test (checked by hand: three separate `mm check kernel/strategies/w0.json` runs gave one key).
4. C4.1's targeted cases appear only through market variants and random windows; no named recompute-boundary case.
5. `lag(lag x) = lag(x, a + b)` is not in R (16 rules); CANONICAL.md should say it was dropped.
6. `audit/stage4/exit.md`, PROGRESS, the paper's findings with the audit link; the draft's evaluation/trial wording.
7. A GPT review of the same evidence.

## Advisor's adjudication of C4.1 against GPT's review

GPT (`2026-11-08-gpt-stage4-evidence.md`, §7) reads C4.1 as not met as written; this review reads it as holding. Checked against `kernel/mm/tests/rules.rs`: its three markets are built locally (`market(variant, seed)`), not by the N1, N2 and N3 generators the criterion names; it compares the `probe` node's stream and the outcome, not every node's stream; the rewrite is applied at the probe's root, not at a random matching position; no named listing/delisting or recompute-boundary case exists. The passing run above is real but does not evidence C4.1 as written. GPT's reading stands.
