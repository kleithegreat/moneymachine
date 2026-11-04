Fresh-context Claude session, 2026-10-31, standing in for GPT (usage limit); a GPT review stays queued.

# Review of the six `agent-real` revisions to `audit/criteria.md`

Scope: the uncommitted diff in `/home/kevin/.cache/mm-gpt/agent-real-rev`, base `b8b3579`. Line numbers refer to that worktree's diffed `audit/criteria.md`, unless a file is named.

I edited no repo file. I read no holdout material, real data or token files. I built the worktree's kernel into a scratch directory and ran it only on a synthetic N1 null market written there.

The six rules are not reargued. Where a wording could raise false discoveries or leak, the finding says so explicitly.

## Findings, ranked by consequence

### 1. FALSE-DISCOVERY RISK (`:365`): "whatever the session's exit" lets an operator's stop produce a repeatable void

- **The change:** the old rule was "early stop ends the arm", with no rerun (`:364`). Under the new text, an operator who kills a session before its first evaluation gets a void and a fresh attempt, with no limit.
- **The channel:** the claim "Nothing from the data reached the agent or the operator" is true of the ledger. It does not cover what the operator already knows. The holdout [2026-08-01, 2026-09-30) is in the past and its prices are public. A pre-evaluation transcript shows the agent's plan. Killing plans the operator expects to do badly in that window selects finalists on holdout-period knowledge. Paper §8's fixed-strategy argument assumes no such channel.
- **Size:** small, given the near-zero power and the pipeline-validation label, but it is new and it is created by this wording. "Whatever the session's exit" is not in item 4.
- **Automatic exits:** void attempts ending by rate limit, auth failure or crash are safe in any number. They are independent of the data and leave the holdout untouched. Repeating them without limit is not itself a problem.
- **Fix, replacing "whatever the session's exit":** "whether the session crashed, timed out, was refused by the provider or exited by itself. An attempt stopped by an operator is not void and goes to the human. No one who could stop an attempt reads its transcript until it has ended. The report gives each void attempt's exit cause." This narrows item 4, so show the human.

### 2. FALSE-DISCOVERY RISK IF MISREAD (`:365`, `:384`, against `:377`): nothing confines the void and "complete" rules to the real run

- C3.2 says "Every started campaign counts, and a crash counts as a promotion". It runs "arm A's frozen procedure", and the audit in `:376` covers "null and real".
- Read onto the null series, the void rule removes zero-evaluation crashes from C3.2's count, and the "complete" rule stops counting a crash as a promotion. Either loosens a frozen smoke test. The Opus review warned about the same loosening (`audit/reviews/2026-10-30-opus-agent-real-l5-text.md:81`).
- **Fix, one sentence in each revision:** "This applies to the real campaign only; C3.2's accounting is unchanged."

### 3. FALSE-DISCOVERY RISK, AND THREE GAPS (`:384`): the added sentence on what blocks release

**Judgment:** the sentence is not in item 4, which says only that "complete" means ended under One attempt. It should stay in some form, because a run under a changed kernel must not spend the holdout, and refusing a release cannot itself create a false discovery. As written it has four defects, and the human should see it as an addition.

a. **Stop option without a no-rerun clause (false-discovery risk).**
- By the time this block can fire, arm A's search results exist and are visible to the operator.
- "The holdout stays unspent, and the case goes to the human" reads as if the holdout remains available. Abandoning a campaign on its search-stage look and retrying on the same holdout would raise the campaign's chance of a false discovery.
- `:364` still forbids this, but `:298` restates its limit and this revision does not.
- **Fix, add:** "This authorizes no further arm A attempt on that holdout: One attempt's rerun rule stands."

b. **It collides with the crash rule.**
- "A failed C3.1 audit" blocks release, and C3.1 requires log and ledger to match one to one (`:376`).
- A crash can break that match in the two paths below, though the same revision says a crash ends the arm normally. As written, an ordinary pod death sends the case to the human.
  - The kernel dies with a line in flight: `daemon.py:63-64` returns `KERNEL`, a log line is written, and there is no ledger row. `audit_run` counts this as an evaluation (`campaigns.py:55`).
  - The daemon dies after the kernel's commit and before `self.log` (`daemon.py:126`): a row exists with no log line.
- Neither case disclosed anything, because the kernel commits before it prints and the daemon logs before it answers the agent. The daemon's lock allows at most one such call.
- **Fix, a dated line under C3.1, for the human because it edits a frozen check's reading:** "On the real run, a single unanswered final call (a `KERNEL` log entry with no row, or a last row with no log entry) is not a mismatch; it is reported, and a row counts toward N."

c. **"Unfinished selection" is ambiguous.**
- `:363` and `brief.md` step 4 make "selection" the agent's `./mm-agent select`. A session that times out before selecting would then block release, contradicting "ends an arm with whatever it evaluated". The agent could also block it by simply not selecting.
- The gate never reads the agent's selection. Finalists come from `search_decision`, then the mechanism check, then `gate.freeze` (`gate.py:76`, `gate.py:176`; `campaigns.py:236-237`).
- **Fix, replace with:** "a finalist freeze not committed". Add to the "reported as absent" sentence: "or an agent selection".

d. **"Changed" and timing have no measure.**
- **Fix:** "Established before the claim, against `audit/stage3/harness.json`, `audit/stage2/searcher.json`, the `kernel` and `data_hash` columns of the attempt's rows, and the dataset version."
- A check made after the claim cannot block anything. `campaigns.py:241` currently audits after the batch.

### 4. MECHANISM METHOD (`:368`): well defined only with an exact end point, and not obtainable as literally described

No false-discovery or leakage risk, since it feeds no decision, but as worded it computes the wrong number.

**Can a replay end at the reported window's start?** Yes, but only through `mm holdout` over scratch inputs.
- `--holdout-from` moves only `report_after`; the run's end is always `policy.w_end` (`main.rs:258-264`).
- `mm eval` stops at `holdout_start` (`main.rs:266`), which is 2026-04-03 and of no use here.
- A short replay therefore needs a scratch `--store` directory with an edited `policy.json`, whose `w_end` changes the replay's end. It keeps the same parquet files, so `data_hash` should be unchanged by the code (not printed in my run). `conventions`, and so `identity`, differ, as expected.
- The real holdout store refuses both replays with `R_HOLDOUT_SPENT` (`main.rs:283-284`; reproduced). Each replay therefore needs its own scratch holdout directory holding the same files and no `spent.jsonl`. One shared scratch directory refuses the second replay (reproduced).
- Each scratch ledger needs `mm select <trial key>` first (`main.rs:430`).
- `--mechanism on` is accepted by `holdout` (`main.rs:481`).
- The step deliberately routes around the one-use guard, so the revision should say so rather than leave it to the implementer.

**Prefix property.** Let the run end at E.
- The loop's last step is b = E − 8h (`sim.rs:323`), so the last equity time is E − 4h.
- Exposures are pushed at the equity mark (`sim.rs:371-379`), before that step's fills.
- Fills are withheld only from b + 12h > E (`sim.rs:395`), and decision eligibility differs only from a decision at E − 4h (`sim.rs:435`). Neither reaches an exposure already pushed.
- The market is loaded whole and delivered by tick. Delisting closeouts cannot fire early, because `intervals` is cut at E and the last b + 4h is below E (`sim.rs:352`; `market.rs:419-427`).
- So the short run's exposures are an exact prefix of the long run's, on the same market.

**End-boundary effect: the literal wording is off by one step.** `reported(run, R)` keeps equity times t > R (`main.rs:109`). A replay ending at E = R stops at t = R − 4h, so the difference includes the step (R − 4h, R], which lies before the reported window. The correct short replay ends at **E = R + 4h**.

**Measured** on a 120-day synthetic market with 12 coins, a constant-weight strategy and a lagged-close condition, with R 20 days after holdout start:

| Short replay end | Exposures in the difference | Reported steps × coins | Sum of exposures minus sum of reported returns |
|---|---|---|---|
| E = R | 1,440 | 119 × 12 = 1,428 | 0.00367, exactly one step's return |
| E = R + 4h | 1,428 | 119 × 12 = 1,428 | 0 to 12 decimals |

- Twelve consecutive end points, each 4h apart, each added 12 exposures, and their sum equalled the long run's return at that step to 10 decimals. Because coin attribution sums to the step return for this strategy, this confirms the prefix directly.
- Returns of each short replay were a byte-exact prefix of the long replay's.
- The long replay with `--holdout-from R` had the same `identity` and byte-identical returns as the batch row, which gives a free integrity check. `result_hash` differs, because the summary then carries `mechanism`.
- A short replay given `--holdout-from R` also works, with 0 reported steps, and its mechanism report is unaffected.

**Other details**
- The kernel reports counts and means, not sums (`main.rs:315`). Sums are count × mean, exactly round-tripped by JSON, with immaterial rounding. A branch with no exposures has mean `null`, since NaN serializes to null.
- The run's last interval (w_end − 4h, w_end] is in neither the campaign's returns nor the exposures. So the reported window has 359 return steps, against "360 decision steps" at `:325`. The batch and the replay agree on this. It is a labelling point for the report, not a defect in this revision.

**Fix, replace the method sentences:**

"With the same kernel and dataset version, each arm A finalist with a committed holdout result is replayed by `mm holdout --mechanism on`, each replay with its own scratch ledger and a scratch holdout directory holding the same files and no `spent.jsonl`. The long replay uses the store's policy and `--holdout-from` R, R being the reported window's start. It must reproduce the committed row's `identity` and returns byte for byte, or the step counts as not run. The short replay uses a scratch store with the same files and `w_end` = R + 4h, so its last equity time is R. Over the reported window, each branch's count is the difference of the counts, and its sum the difference of count × mean. A branch with no exposures there leaves the difference undefined, and the report says so. No pass or fail is applied. The scratch ledgers are kept with the campaign."

### 5. Contradiction between revisions (`:368` against `:385`)

"Each arm A finalist is replayed" includes a finalist with no committed result. `:385` says "no finalist is evaluated later under the campaign". A replay would evaluate it and produce its holdout return. The fix is in finding 4's wording ("with a committed holdout result"). Others are reported as absent.

### 6. Gap on the likeliest outcome (`:298` against `:383`, `:404`)

- Zero finalists means no batch. C3.3 requires "one holdout batch" and the "holdout result" of each candidate. C3.4 requires the holdout fields. The revision does not say whether C3.3 and C3.4 hold, and stage exit depends on it.
- If they do not hold, stage 3 deadlocks, since `:364` forbids a rerun. If they do, the release path was never exercised, which falls short of the "end to end" purpose at `:335`.
- An implementer must not decide this, because it defines done. **It needs one sentence from the human.** My suggestion: "C3.3 and C3.4 then hold with those items empty, and the report states that the release path was not exercised."
- `:410` ("Stage 3 spends the only real holdout") and `:466` ("Stage 3 spent the real holdout") become false in this case. `:297` is covered by the revision. **Add:** "Lines elsewhere saying that stage 3 spent the holdout describe a released batch; this changes no later stage's plan."

### 7. Crash cases left to the implementation (`:384`, `:385`)

- **A refusal before the claim.** `:385` covers "aborted or the batch stopped" and says "the claim stays spent", which presupposes a claim. A kernel exit before the claim (load error, `R_HOLDOUT_FAMILY`, `main.rs:431-439`) leaves no claim, no result and no rule. **Fix:** "If no claim was written, nothing was released and the batch may be retried unchanged; once a claim exists, this rule applies."
- **Deterministic gate steps.** `campaigns.py:231-237` shows that the search decision, mechanism check and freeze can crash after the arm has ended. `:384` then leaves "blocked" as the only reading, though these are functions of the ledger. **Fix:** "Gate steps between the end of an arm and the claim may be rerun; they are deterministic given the ledger."
- **Arm B.** `:384` says "ends an arm", but One attempt (`:364`) is written for arm A. That extends One attempt to G100 silently, with no resume. It raises no false-discovery risk through the holdout, but it goes beyond the literal rule. State it: "either arm". The operator's option to stop arm A or arm B partway, after seeing results, shrinks N, but it exists today for arm A and stays covered by the holdout. Holdout error control does not rest on the search-stage N.

### 8. Void evidence is not fully decidable (`:365`)

"By the daemon's log and the ledger" does not say what happens when they disagree or when the log is missing. `daemon.log` does not exist until the first call (`daemon.py:52`).

**Fix:** "Void only if the log, or its absence, and a readable ledger both show no `mm eval` call. Any evidence of one in either means the attempt stands. A ledger that cannot be read goes to the human."

The rule is safe when no evidence exists despite a line in flight, because the kernel commits before it prints, so the agent saw nothing. An `E_*` rejection counts as an evaluation, consistent with `:297`.

### 9. The fresh id is unconstrained (`:365`)

The id seeds G100 (`campaigns.py:233`) and the SPA and StepM bootstraps (`gate.py:88`). A freely chosen id could be ground offline against the search data. The holdout still protects the claim, so this is minor. **Fix:** a fixed sequence, `agent-real-1`, `agent-real-2`, and so on. `campaigns.py:217` also still defaults to `stage3-real`.

### 10. Minor

- **`:368`:** a difference that cannot be computed should be stated not to fail C3.3 or C3.4. "The promotion decisions stand" does not cover stage exit.
- **`CLAUDE.md`, Holdout:** "Only the gate's holdout step reads `data/holdout/`, once per campaign" now has an exception. Name it in a clause, or the reporting step breaks the process file.
- **`:402`:** "no process reads them" is achievable, but the current code breaks it.
  - Stdout carries the diagnostics (confirmed).
  - `gate.py:216` keeps them.
  - `gate.py:210` prints them in an exception on any abort, into the pod's logs before promotions are committed.
  - The implementation should discard stdout and read `results` from the ledger.
- **`:402`:** "Every promotion decision" should cover every frozen finalist, promoted or not, including an arm with none promoted.
- **`:385`:** "by finalist identity" needs the batch order recorded before the claim. Abort rows carry no strategy (`main.rs:493`), and the batch file is deleted (`gate.py:203-208`). The report must show "absent, counted as 0", not a plain return of 0.
- **`:384`:** a transcript that survives a crash should still be hashed. "Absent" fits only a file that does not exist.

## The questions asked

1. **Faithfulness.**
   - Zero finalists, missing finalist and diagnostics state the human's rule.
   - The mechanism revision is faithful but imprecise on method.
   - The void revision is faithful except "whatever the session's exit", which overreaches (finding 1).
   - "Complete" is faithful in its first two sentences. The third is an addition to keep, repaired (finding 3).
2. **False discoveries and leaks.** Three wording risks: findings 1, 2 and 3a. Void attempts repeated without limit are otherwise harmless. Counting a missing finalist as p = 1 is conservative and valid: stopping a batch only loses power. The holdout reporting step feeds no decision and is safe once the holdout is spent.
3. **Measurability and crash cases.** Gaps are in findings 3b to 3d, 6, 7 and 8.
4. **Mechanism method.** Well defined with no kernel change, with the exact prefix property, if the short replay ends at R + 4h through a scratch policy and scratch holdout directories (finding 4).
5. **Existing lines.**
   - `:376` and `:377` collide if the revisions are misread or applied literally.
   - `:410` and `:466` are false in the zero-finalist case.
   - `:383` is unresolved in the same case.
   - `:364` is correctly carved out.
   - `:321` agrees with the diagnostics revision.

Verdict: commit with listed wording fixes, after one line to the human on the three that go beyond item 4 (the operator-stop exclusion in finding 1, the blocking sentence with its in-flight C3.1 reading in finding 3, and C3.3's status with zero finalists in finding 6).
