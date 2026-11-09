# Review: thesis refreeze, round eleven (Opus, fresh session)

- **Reviewer:** Claude Opus 5.5, a fresh session. It had no part in rounds four to eleven or in Argon's round-ten review.
- **When:** 2026-11-09 11:42 to 11:56 UTC (06:42 to 06:56 EST).
- **Reviewed:** `thesis-refreeze` at `fa1d084`, round eleven (`ef20061`, `c7dc2f3`, `4a57c43`, `98c89bd`, `fa1d084`, built by GPT), three-dot from `dcfab51`. Inputs:
  - the build record's "Round eleven" section in `audit/reviews/2026-11-08-sonnet-refreeze-round7-build.md`;
  - the draft clauses `audit/stage10/criteria-revision-round11-draft.md`;
  - Argon's partial round-ten review, findings 1 to 4 (`audit/reviews/2026-11-09-argon-web-refreeze-round10.md`);
  - round ten's diff, `f4db799...dcfab51`, read for the kinds of defect Argon's lost findings 5 to 8 named.
- **Method:**
  - A clean detached worktree, `/home/kevin/repos/mm-rv-rf11`, with no `data/`.
  - Three reproductions in `2026-11-09-opus-thesis-refreeze-round11/`. Run each from a worktree root with `TMPDIR=/tmp nix develop -c python <file>`. p2 also ran on a `git archive` of `dcfab51`.
  - The 40 stage 4 C4.5 v3 transcripts (`data/agent/swarm-null-3-*`). These are synthetic null-market sessions with no holdout. Only the Bash `command` strings, the result error flags and the permission denials were read, plus one `ls` result to confirm that command ran.
  - The sharded suite.
  - No live recording, thesis transcript, holdout, embargo, forward-window data, cluster or venue endpoint was read.

## Verdict

**Not ready.** The C10.2 redesign is sound against bypass: I could construct no false match. But it fails closed on essentially every honest session. Under its own parser and grammar, all 40 recorded stage 4 sessions read `match: False` (R1). C10.2 would then fail while its claim holds. That is a design wall, not a tuning problem: the grammar is enforced after commands have run, while the sandbox runs more than single literal client calls. The redesign changes where enforcement lives, so it needs another round, on another model than this one.

Round eleven also introduces a Monday regression. A first pass interrupted by a core-listing failure makes every later pass a "retry" pass, so a healed outage cannot finish the date's first read (R2). Argon's findings 3 and 4 are fixed at their cause.

## Findings, ranked

### R1. C10.2 fails closed on honest sessions: 40 of 40 recorded sessions (high: fails C10.2 while its claim holds)

**Path.**
- `thesis/harness.py:69-70` and `:108-113`: every non-denied Bash call must match `EXECUTION`, or the session reads `match: False`.
- `sandbox/session.py:40-43`: the permission layer is `Bash(./thesis-agent:*)` in `dontAsk` mode.

**What actually runs in this sandbox.** The stage 4 transcripts used the same `session.tools` and the same CLI flags. Their brief already said "No other command or file is available … no pipes, `;` or `&&`" (`gate/agent/brief.md:33-34`). Even so, the CLI ran, without a denial:
- read-only commands it approves on its own: `ls -la /work`, `cat brief.md`, `grep … tool-results/…`, `… | head -100`;
- compounds whose parts are all allowed: `ls -la && ./mm-agent --help`, `./mm-agent check a.json; echo ---; ./mm-agent check b.json`, `./mm-agent budget 2>&1 | head -20`.

**Reproduction.**
- `p3_real_format.py.txt` runs ef20061's own `harness.results` and `EXECUTION` (client renamed) over the 40 real transcripts:
  - All 40 parse.
  - Of 902 non-denied Bash calls, 835 are literal and 67 are not. All 67 ran.
  - **All 40 sessions would read `match: False`.** The first or second Bash call of most sessions was a non-literal one.
- `p1_honest_sessions.py.txt` shows the same on thesis-shaped transcripts. In each case every client call has exactly one record, and each still reads `match: False`:
  - `ls -la` then `./thesis-agent markets`;
  - `ls -la && ./thesis-agent markets`;
  - `./thesis-agent markets 2>&1`;
  - `./thesis-agent prices BTC; ./thesis-agent prices ETH`;
  - `cat brief.md`.

  Only the all-literal control matches.

**Soundness, checked and holding.**
- In an accepted session, every Bash call is one process of the read-only, `-I` client (`sandbox/session.py:109`, its ro-bind over `/work/thesis-agent`).
- The client sends exactly one request per execution, refusals included (`sandbox/client.py:23-36`).
- The daemon discloses before it replies (`thesis/daemon.py:119-143`).
- `Write` is limited to `/work`, so the agent can reach no shell profile, client or module.
- A false match would need one execution with no record and another with two. The fixed client cannot make two, and no other process in the sandbox can reach the socket.
- Argon's findings 1 and 2 are therefore subsumed. Their inputs are permanent tests (`thesis/tests/test_refreeze_round11.py:20-33`).

**Why it is a wall.** The criterion's clause "no tool call outside Read, Write and `./thesis-agent`" was never checked except by tool name. Round eleven is the first audit to read it literally, and real sessions break it routinely. A sentence in the brief does not change that: stage 4's brief said the same.

**Fix at the cause.** Enforce the grammar before execution, not after:
- A frozen pre-execution filter in the session's configuration blocks every Bash command that is not one literal client execution. For example, a PreToolUse hook running `/tool`'s Python, if the CLI honours it under `--setting-sources ""`.
- The canary shows two things on a real session: a blocked command does not run, and what its block looks like in the transcript.
- The audit recomputes the same grammar: a literal call with a result counts one, and a non-literal call counts zero only when its result is the filter's block.

Honest agents then get a denial and retry, as they already do 65 times in the stage 4 record. The check fails closed only on a real anomaly. Until that filter exists and the canary passes, no wording for (b) should be adopted.

### R2. A first pass cut short by a core-listing failure turns every later pass into a retry pass (high: can fail C10.5, contradicts (a) and T3)

**Path.** `thesis/runner.py:140`: `retrying = self.draft is not None and self.draft[0] == now`.
- The draft is created before the core listing is read (`:150-152`).
- If `universe()` or `dexes()` raises (`:199`), the draft survives with `listings: None`.
- From then on, `check()` (`:147`) and the limiter's cancel (`:157`) apply the 04:45 UTC (23:45 EST) cutoff to what is in fact the date's first complete read.

**Reproduction.** `p2_monday_core_listing.py.txt`, on a Monday:
- (a) The core listing fails from 00:05 to 04:46 UTC (19:05 to 23:46 EST), then heals.
  - `fa1d084`: no snapshot is ever returned before 24:00 UTC (19:00 EST). Every pass hits `check()` at once and returns `None`. Every benchmark market is then skipped "no attested snapshot".
  - `dcfab51`: attested at minute 286, 04:46 UTC (23:46 EST).
- (b) The outage heals at 04:30 UTC (23:30 EST), and reads take time.
  - `fa1d084`: the pass is cut at 04:45 UTC (23:45 EST), and all five benchmark markets are attested failed "retry deadline reached before acquisition completed". They are skipped operationally, so the batch is not executed.
  - `dcfab51`: no failure.

**Outcome changed.**
- The revision of 2026-11-09 requires exactly four executed batches, so one Monday core-listing outage that heals after about 02:00 to 03:15 UTC (21:00 to 22:15 EST Sunday) fails C10.5. T3 puts the initial read at 92 to 188 minutes of packing, and the builder-dex benchmark markets sort last.
- On other dates, a late heal attests a mostly-failed snapshot where round ten would have kept reading until 05:00 UTC (00:00 EST).
- Draft (a) says the opposite: "Initial acquisition remains subject to the existing acquisition deadlines … Monday acquisition allowed until D + 24:00 UTC (19:00 EST) for its benchmark." So does T3 (`docs/whitepaper.tex:725`): "Monday initial acquisition may continue for the benchmark".

**Fix.** A pass is a retry pass only once the draft's first pass has attempted the whole scope. Set a flag where `read_pass` returns, and test it from p2. The wording below defines "first pass" that way.

### R3. A session the runner stops at its turn limit or wall time fails C10.2 (medium: fails C10.2 while its claim holds)

**Path.**
- `sandbox/session.py:129-139` kills the CLI once more than `MAX_TURNS` assistant events arrive, or at `WALL_SECONDS`.
- The transcript then has no `result` line, and `results` raises "incomplete or unattributable transcript" (`thesis/harness.py:91-92`).

**Reproduction.** p1: "turn-limit kill" reads `match: False` with every call recorded, with or without a call in flight.

**Likelihood.** The thesis limit is 100 events (`thesis/harness.py:18`). Stage 4 sessions reached 108 of their 200. Round ten would have matched such a transcript's completed calls.

**Fix.**
- End sessions at a boundary the CLI records, for example its own turn limit, so the transcript completes.
- State the wall-time kill in (b) as a known fail-closed case. Do not make it a tolerance: a dangling call counted as "0 or 1" could mask a missing record.

### R4. Under the fork, research agents get "bad request" in place of the usage line (medium-low: research harness behaviour, unrecorded)

**Path.** Refusals now reach `gate/agent/daemon.py:109-127` as `{"cmd": None, …, "refusal": usage}`. That daemon ignores `refusal` and answers `{"ok": false, "message": "bad request"}`. Before the fork, the client printed the usage line or the OS error itself.

**Outcome changed.**
- 31 of the 40 stage 4 sessions ran `./mm-agent --help`. Under the fork they would learn nothing from it, and nothing from a FILE error either.
- This changes what the next research campaigns (the positive controls) can do.
- The fork's decision entry names the identity change but not this behaviour. The thesis daemon handles `refusal` (`thesis/daemon.py:124-125`).

**Fix.** One rule in one place: the shared `sandbox/server.py` (or both daemons by the same function) answers a request carrying `refusal` with that text. Then record it with the fork.

### R5. Record and erasure (low)

- **The fork's decision entry.** `audit/decisions.md`, 2026-11-09 08:18 UTC (03:18 EST), contains two problems:
  - It says "the human authorizes a fork" without saying where. I found no such authorization on main.
  - It says Argon's review "is truncated during finding 2". The build record corrects this to finding 5, but the decisions log does not.

  Both want an appended correction line. The entry is append-only.
- **`harness.audit` returns `client_calls` equal to `daemon_calls`** (`thesis/harness.py:115`): a duplicate field under a misleading name. Delete it.
- The old shell-tokenizing fields are fully gone, and `session.calls` and `session.tool_use` are still used by the research audit. Nothing else to erase.

### R6. Wording precision (low)

`thesis/runner.py:199` treats a failure of the builder-dex list (`perpDexs`) like a failure of the core listing. (a) names only "the core venue's listing read".

## Argon's findings 3 and 4, and new sequences

**Finding 3 is fixed at its cause.**
- The cutoff is checked before each read in a retry pass and at every limiter admission, through `hold(cancel=…)` (`ingest/hl.py:39-74`).
- After the cutoff, at most one HTTP attempt, its backoff sleep and an uncancellable flock wait can finish. Then the next admission raises.
- I reran the exact-scale tests (`test_refreeze_round11_argon_exact.py`):
  - Eleven 91-second failures from 04:44 UTC (23:44 EST), on a Monday and on a Tuesday: one read is in flight, it ends at 04:45:31 UTC (23:45:31 EST), and all eleven are attested failed.
  - A first failure on an initial pass at or after the cutoff is final.

**Finding 4 is fixed at its cause.**
- `readiness_at` is fixed when the draft is created (`thesis/runner.py:152`), and every readiness check uses it (`:241`).
- `ready(m, R)` means `acquired_to(m) ≥ R − 500 h`, and registration asks the venue from `R − 500 h` (`:122`). The two meet with no gap, for every ready market, whenever it was checked.

**New sequences tried.**
- A restart mid-pass makes a new draft with a new anchor. Nothing had been attested, so that is fine.
- A market on a builder dex that heals at 04:40 UTC (23:40 EST) is checked at the 00:05 anchor. That is correct.
- A market first filled after the anchor is cold under the early anchor. That is correct and day-fixed.
- A readiness exception now removes the market from both views and the daily bars (`:179-185`), as (a) says.
- The only new failure found is R2.

## What Argon's lost findings 5 to 8 likely covered

Argon's finding 5 was headed "N1/N5 / Check 1 & …": retry semantics at the dex level, or at the level of the whole pass. R2 is that class: a pass whose core read failed is mistaken for a retry pass.

I also checked the rest of rounds ten and eleven for the kinds Argon was finding:
- **Attestation.** `failed` is in the snapshot and in the `snapshot_ready` record (`:276`), and the report lists those records (`thesis/report.py:83`).
- **Dex failures.** A failed dex surfaces as `dex:*`, and `unbenchmarkable` checks it before "not listed" (`:55`).
- **Data consistency.** Every bar read across passes is as of the cutoff (`now`), so the reads of a draft that spans passes are consistent.
- **Listing status from late passes.** A builder-dex listing read on a late pass can show a delisting after 00:05 UTC (19:05 EST). That only removes a market, before any session starts.
- **Stray output in transcripts.** No stage 4 transcript has a non-JSON line, so the merged stderr does not trip the stricter parser in practice.

None of these changes an outcome.

## Sharded suite

`python3 ops/shards.py /home/kevin/repos/mm-rv-rf11`: 2,031 of 2,031 reported, 0 missing, wall 353 s.
- 2,007 passed, 2 skipped, 19 xfailed, 3 failed.
- The three failures are the `LOCAL_ONLY` tests that need `data/store` (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`, `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped`, `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`). They fail because this worktree has no `data/`, as in rounds nine and ten.
- Every thesis, sandbox and gate test passed.

**The fork's identity.** `harness_hash()` on `fa1d084` is `3d2e6a72…0a34`, as recorded. `audit/stage3/harness.json` is unchanged (`6a335714…2397`), so `check_frozen()` refuses the fork, which is correct. The test pin's temporary record (`gate/tests/test_agent_real.py:488-491`) is a fixture, not a freeze.

## Criteria wording

**Is the draft exact to the code?**
- (a) is exact except for R2, where the code applies the retry cutoff to an unfinished first pass, and R6.
- (b) is exact to the code: every sentence checked against `harness.audit`, `client.main` and `daemon.handle`.

**Is anything loosened?** No. C10.5's counts, the operational-skip rule and the miss tolerance are unchanged. (b) narrows what the audit accepts.

**Can a run pass while its claim is false?**
- Under (b), no: see R1's soundness paragraph.
- Under (a), no: a final failure only removes markets, and every arm shares the one attested snapshot.

The draft's fault runs the other way. Under (b), runs fail while their claim holds (R1, R3), and under (a), Monday batches fail operationally on an outage the date could have recovered from (R2).

**I endorse (a) as follows, with R2 fixed to match.**

> **(a) Item 2, operational skips, and item 4, readiness.** The operational reasons also include "market read failed at the snapshot". A date's first pass is complete once it has read the core venue's listing and builder-dex list and attempted every builder-dex listing, market read and readiness check in scope. Until then every pass is initial, subject only to the acquisition deadlines: strictly before D + 05:00 UTC (00:00 EST) for the agents, and on a Monday until D + 24:00 UTC (19:00 EST) for its benchmark only. A failure of the core listing or of the builder-dex list that lasts to that deadline leaves the date with no attested snapshot. After the first pass is complete, later passes retry only failed market reads, failed readiness checks and failed builder-dex listings. No such retry pass, retry read or network admission within a retry pass starts at or after D + 04:45 UTC (23:45 EST the day before). The cutoff is checked within the pass and while waiting for quota. An in-flight request may finish. Before the cutoff, an outstanding failure prevents attestation. A failure is final for the snapshot if it remains at the cutoff, if it is first observed at or after it, or if its retry was left incomplete there. Final failures and their reasons are recorded in the attested snapshot and in its attestation record, and listed in C10.6. They make only the affected market, or every market of the failing builder dex, unavailable for that date: absent from the agent and benchmark market views and daily bars, and not ready. Main and no-reading still run on the identical attested snapshot, failures included. The Monday batch skips such a market operationally ("market read failed at the snapshot: <reason>"), so that batch is not executed. One `readiness_at`, fixed when the draft is created, is used by every readiness check of that draft. Registration of a newly used market reads funding from this `readiness_at` minus 500 hours through its own cutoff, and existing positions read from their earliest registration. A completed readiness check returning false is day-fixed cold status, not a read failure.

**I endorse no wording for (b) yet.** It should be written after the pre-execution filter of R1 exists and the canary has shown its behaviour. Its claim should then read:
- a Bash call that is not one literal `./thesis-agent` execution under the grammar is blocked before it runs, and counts zero;
- every literal execution with a result counts one;
- the count equals the session's daemon call records, which carry each execution's `argv` and refusal;
- a session the runner kills at wall time fails closed, a known cost.

The grammar block of the draft can stay as written.
