GPT (gpt-6.1-sol, high), fresh read-only review of stage 4's exit evidence at main 1bde59c, in a clean worktree without the campaign directories, 2026-11-08 05:45 UTC (00:45 EST).

# Stage 4 exit-evidence review

**The recorded v3 campaign tally passes its numerical acceptance rule. Stage 4 is not yet ready to exit:** required reporting is incomplete, C4.1–C4.4 are not fully evidenced, and the independent-review and exit-recording process remains unfinished.

This is a read-only review of committed evidence and code. Campaign directories, transcripts and ledgers were unavailable; their reported reconciliation and hashes were not independently recomputed.

## 1. The actual v3 tally passes under either establishment reading

**Outcome affected: C4.5’s numerical verdict. No change for this cohort.**

`audit/stage4/null-v3.jsonl` contains the ten declared campaigns, `swarm-null-3-N2-0..9`. The summary reports:

| Class | Count |
|---|---:|
| Established | 9 |
| Promoted | 0 |
| Unresolved | 1 |
| Not established | 0 |

Thus:

- **All ten recorded:** satisfied by the supplied log, not merely inferred from the summary’s `n`.
- **Promoted plus unresolved ≤ 1:** \(0+1=1\), satisfied.
- **At most one not established:** satisfied whether this means the exclusive class named `not established`, or every campaign lacking demonstrated establishment. Under the latter reading, N2-8 is the sole exception.

`swarm_verdict` therefore returns the correct numerical result for these records. `counted_promotions: 1` denotes the unresolved campaign, **not an observed promotion**.

The earlier failures remain failures: v1 failed its 200-evaluation floor; v2 failed its per-agent zero-evaluation rule. The human-authorized, prospectively committed v3 revision permits a different judgment on fresh identities—not a retrospective pass of either predecessor.

## 2. N2-8 must remain unresolved

**Outcome affected: N2-8’s class and the truth of the C4.3 exit statement; not the current numerical verdict.**

N2-8 A4 attempted `Edit`; the CLI refused it. That establishes neither a successful forbidden operation nor a sandbox breach.

Nevertheless, the frozen audit counts attempted tool names. `session.tool_use` includes all tool-use names, and `audit_holds` requires `outside_permitted` to be empty. Consequently:

1. A4’s daemon/ledger sequence matches: 21 calls and 21 rows.
2. Its audit nevertheless does **not** hold because `outside_permitted == ["Edit"]`.
3. `agent_evidence` consequently reports `holds: false`.
4. `swarm_class` correctly returns `unresolved`.

The draft’s assertion that **all 40 audits `audit_holds`** is false (`audit/stage4/exit-v3.md:8`). All 40 report matching call sequences; only 39 satisfy `audit_holds`.

V3 requires C4.3 for every **established** campaign, so this does not independently disqualify the cohort. Keeping N2-8 unresolved, treating it as established under a successful-use-only interpretation, or placing it in the named not-established class would each leave this cohort numerically passing. That robustness is not authorization to reclassify it.

## 3. The four non-evaluating agents are permitted by v3

**Outcome affected: establishment classification. No adverse change on the supplied evidence.**

The four agents are:

- N2-1 A1;
- N2-3 A3;
- N2-5 A1;
- N2-6 A2.

Each has zero evaluations, zero history calls, `received: false`, intact evidence, and a clean finished exit. Every affected campaign still has three evaluating agents, filled trials, and cross-agent history receipt.

V3 explicitly reports such inactive agents without counting them against acceptance. Applying v2’s per-agent requirement—or restoring v1’s search-volume floor—would redefine the applicable criterion. Conversely, these records establish partial participation in a four-agent procedure, not successful evaluation by all four agents.

## 4. Constructed false-pass and false-fail readings

### False pass: establishment hidden by exclusive classes

**Outcome affected: a possible future `pass` versus `not established`; not this cohort.**

Consider eight established campaigns, one promoted campaign that fails establishment requirements, and one campaign classified `not established`.

`swarm_verdict` accepts this configuration: one promoted, no unresolved, one named not-established class. But **two campaigns lack establishment**. Reading “at most 1 campaign not established” as an independent establishment requirement rejects it.

The 2026-11-04 qualification explicitly acknowledges promotion masking non-establishment and requires reporting it without changing classification or thresholds. The code exposes, but does not close, that channel; `test_v3_exposes_the_masking_false_pass_channel_but_does_not_repair_it` demonstrates it.

This is a real qualification of the acceptance rule, not grounds to invent a retrospective veto. No promotion occurred here, so the channel is inactive.

### False pass: directory count substituted for recorded campaigns

**Outcome affected: “all ten recorded” in another evidence configuration; not this supplied log.**

`swarm_report` counts declared campaign directories, then overwrites the summary’s `n` and `ids` with that evidence inventory. A tenth directory without its series-log row can become the single permitted unresolved campaign and still yield `pass`.

Therefore `swarm_verdict` alone does not establish “all ten recorded” in the required log. The actual supplied log supplies the missing check here.

### False pass: smoke acceptance mistaken for an error guarantee

**Outcome affected: scientific interpretation, not the registered numerical verdict.**

A procedure with invalid holdout assumptions can nevertheless produce ten non-promotions and pass. The frozen kernel does not establish the almost-sure **pre-absorption −2 bound**. Neither zero bankruptcies nor observed absorbed returns certifies that premise.

Likewise, these campaigns produced no screened candidates or finalists. They cannot demonstrate successful execution of candidate-bearing mechanism and holdout paths. They can satisfy the registered smoke criterion because finalist production is not required.

Any claim of calibrated swarm error control, power, full-budget-search safety, or complete downstream-path validation would therefore be false or unsupported despite this pass.

### False fail: conservative evidence failure without an operational breach

**Outcome affected: a hypothetical `failed` verdict while the substantive safety claim holds.**

Two otherwise clean campaigns each attempting an unavailable `Edit` tool would be unresolved and fail v3, even if both refusals preserved isolation and both gates completed without promotions. Similarly, two missing audit records could fail acceptance despite correct underlying execution.

These are deliberate conservative evidence failures. They do not justify relaxing the frozen rule. Nor would two actual null promotions alone logically disprove conditional error control: a finite smoke test can fail by chance while a probabilistic guarantee holds.

## 5. Required pooled reporting omits v2

**Outcome affected: compliance with C4.5’s reporting requirement and the reported bound; not v3’s class tally.**

The summary, draft and newest decision report **0 promotions among 12 campaigns**, upper bound **0.221**, with zero unknown outcomes.

But the audit record contains:

- v1: 2 started campaigns;
- v2: 10 started campaigns;
- v3: 10 started campaigns.

That is **22 started campaigns**, not 12. V2 recorded nine completed gate outcomes without promotions; N2-9’s crash row contains no promotion outcome. On the available records, the inventory is therefore **21 known non-promotions and one unknown**, unless separately documented committed evidence establishes the latter outcome.

`swarm_report` discovers earlier versions from logs currently present under `OUT`, rather than the complete archived audit inventory. Its result here omits v2.

The pooled report must include every version and identify the unknown campaign. A zero-success binomial calculation over the 21 known outcomes would give approximately **0.133**, but that is not an uncertainty bound resolving the omitted outcome, nor a calibrated common-rate guarantee across versions. The current **0/12 “across versions”** claim is incomplete.

## 6. The finalist-specific qualifications are satisfied vacuously, not validated

**Outcome affected: qualification compliance and interpretation; no class change.**

All campaigns report zero screened candidates and zero finalists. Accordingly:

- No candidate reached the qualified mechanism check.
- Empty finalist turnover and minimum-return diagnostics are appropriate.
- No finalist result needs an unavailable-evidence label.
- No promoted campaign requires establishment-absent-promotion reporting.

The result must still carry the qualifications explicitly:

- Closing-fill costs are omitted from the mechanism comparison, and undefined conditions are excluded from its coverage denominator.
- Holdout validity remains conditional on the stated predictability, integrability, conditional-mean and pre-absorption loss assumptions; the frozen kernel does not establish the −2 condition.
- Turnover and absorbed-return minima would not certify that condition.

The summary’s qualification pointer names a **stage 4 entry that is absent from `PROGRESS.md`’s Qualifications section**. The final exit report needs a valid qualification reference, not that dangling pointer.

## 7. C4.1–C4.4 are not fully evidenced

**Outcome affected: stage 4 exit independently of C4.5’s tally.**

| Criterion | Assessment |
|---|---|
| **C4.1** | **Not established by the cited test or recorded execution evidence.** |
| **C4.2** | **Relevant implementation tests exist; complete criterion evidence remains missing.** |
| **C4.3** | **Campaign-level support for the nine established campaigns; isolation/injection test execution still needs evidence.** |
| **C4.4** | **Required campaign reports are present; invariant-test passage remains unconfirmed.** |

Important distinctions:

- **C4.1:** `kernel/mm/tests/rules.rs` uses three locally constructed market variants, not the specified N1, N2 and N3 generators. `streams` compares the designated probe’s values, not every corresponding node stream; `outcome` compares returns, trace and exposures, but not the required summary. Listing intervals all start at zero, so there is no targeted later-listing case. A passing run of this test alone would not meet C4.1 as written.
- **C4.2:** The 1,000 rewritten pairs and 20 hand-built pairs are implemented. However, the cited fresh-process test covers 40 separately generated programs, not every program in the criterion’s corpus. The random-pair test prints at most five failures; any actual failures still require individual explanations. No qualifying execution record is supplied.
- **C4.3:** The nine established campaigns report holding agent evidence, reconciled audits, cross-agent history and budgets within limits. The sandbox-isolation and history-injection tests exist, but their existence is not a passing execution record.
- **C4.4:** Raw and clustered N, zero-fill counts, SPA, screen/StepM decisions and fragility flags are present for all ten campaigns. The separate requirement that stage 1–3 invariant tests still pass is not established by these JSON reports.

These are not requests for stronger thresholds. They are gaps against the criteria already written.

## 8. Remaining exit obligations

**Outcome affected: whether stage 4 may be marked done.**

Before exit:

1. Complete or locate qualifying C4.1–C4.4 evidence, addressing the test-coverage mismatches rather than merely running the currently cited tests.
2. Correct the pooled inventory, the “all 40 audits hold” statement, and the qualification reference through append-only corrections.
3. Complete the required independent Claude/GPT evidence reviews and advisor adjudication, including the final Opus review required by `CLAUDE.md`.
4. Publish the final exit record and status, retaining v1/v2’s failures and strict xfails. Wire the v3 evidence into `audit/stage4/null-summary.json`, which the committed criterion test currently reads.

No campaign needs padding, replacement or rerunning merely because agents stopped early or finalists were absent. The qualified frozen-kernel defects are not additional retrospective vetoes. Any genuinely changed research procedure requires the prescribed fresh identities.

The newest decision’s suggested reversal by deleting audit evidence conflicts with the append-only rule; reversal should be recorded as a superseding decision, not erasure.

**Verdict: not yet. V3’s numerical smoke-test acceptance passes as written for this cohort, but required reporting and C4.1–C4.4 evidence remain incomplete, and the mandatory independent-review and exit-recording process is unfinished.**
