# Thesis refreeze round four, review by Claude Opus 5.5, 2026-11-08 18:10 UTC (13:10 EST)

Reviewed: GPT's round-four build on `thesis-refreeze`, three-dot `e04b8d4...1160c7b` (`6bfe069`, `77ae9e7`, `b13fe40`, `8500523`, `1160c7b`), in a detached worktree at `1160c7b` without `data/`. Read with it: `CLAUDE.md`, `main:PROGRESS.md`, GPT's build record, `main:audit/reviews/2026-11-08-gpt-prewarm-build.md` (findings 1-7), `main:audit/reviews/2026-11-08-sonnet-research-hyperliquid.md`, `main:audit/reviews/2026-11-08-opus-thesis-refreeze-round3.md`, `audit/stage10/criteria-revision-draft.md`, stage 10 of `audit/criteria.md`, T3 of `docs/whitepaper.tex`. No exchange endpoint was called. The only `data/` read was integrity and counts on pre-window files (`data/thesis/snapshots/1793146261723.json`, the 2026-10-28 00:11 UTC (2026-10-27 19:11 EDT) snapshot: listing counts and daily-bar counts per market, no price; `data/thesis/exchange/info-20261028.jsonl`: request types and retrieval times, no response). Reproductions are in `2026-11-08-opus-thesis-refreeze-round4/` beside this file.

## Verdict

**Not ready to refreeze.** Findings 1-7 are fixed at their causes, and the snapshot attestation and recovery hold under every kill, cache-loss and late-publication case I built. But the schedule rests on a worst-case envelope that the recorded inventory does not support, and it hides two defects that any earlier start exposes (R1, R2). The bound it is sized to does not protect the session either: in the bound's own worst case, the session starts with most markets refused by R1. I recommend a 05:00 UTC start (00:00 EST), after R1-R3 are fixed and the benchmark reads the day's snapshot (R4). The derivation is below.

## Findings, ranked

**R1. High. Readiness lapses at every UTC midnight, and a registration read cannot restore it.** `thesis/market.py:509-512` (`ready`: coverage to `now // DAY * DAY`), `thesis/runner.py:107-110` (`inputs`), `thesis/runner.py:112` (new markets read from `start = now`).
- *Failure.* A market whose whole funding history was acquired at 03:00 on day D is "not ready" from D+1 00:00 until the background fill reaches it again. `prewarm()` skips ready markets, so the fill runs once a day per market, after midnight. Background admissions wait while a snapshot or a session holds the limiter (`ingest/hl.py:61`). The registration's own read starts at `now`, so it never fetches the hours between the last fill and midnight. `inputs` then raises "funding history is not ready" for a market whose history is complete. Probe P1 (`test_round4_probes.py.txt`) reproduces this with the real `Market` and `Track.inputs`.
- *Under the proposed 19:00 start* the fault is hidden only while acquisition is quick, since the fill then has about 16 hours to cover the roughly 20,166 weight/day of upkeep. In GPT's own worst case (acquisition done at 18:18:51), the fill has 41 minutes before 19:00, and the session holds it off from then on. Most registrations of that session would be refused. The Monday benchmark is refused until the acquisition holds release and a fill pass re-readies its markets, so its t_r, and with it its entry hour, drifts by the acquisition's duration (below, R4).
- *Under any earlier start* (the recommendation below), the session often begins before the day's fill has finished, holds it off for up to four hours, and refuses most markets.
- *Cause.* `ready` conflates two things: history the venue was never asked for (the human's decision: such a market is unavailable that session) and the hours since the last daily fill, which one registration-time page fetches. Hypothesis for the builder, to be confirmed from a failing test: the registration read covers its comparator scope to `now`, so a gap shorter than a page is fetched in the foreground, and only then is readiness judged. A market whose uncovered part needs more than that stays cold and unavailable.
- *At stake:* C10.5's accepted main theses, information returned to the agents (failed-call disclosures), the benchmark's t_r and entry.

**R2. Medium. Acquisition shares the serial schedule loop with the sessions.** `thesis/runner.py:384-403`.
- *Failure.* `ready()` admits a session until the date ends, so a no-reading session started at 23:59 after a model outage holds the loop until 00:59. The next date's `acquire` starts about 54 minutes after its cutoff. The draft says acquisition is "due independently of model availability at the cutoff", and T3's bound assumes it starts at the cutoff: 00:05 + 18:13:51 + 0:54 is past 19:00. Probe P2 reproduces the delay.
- *Fix hypothesis.* Acquisition on its own loop, as the benchmark, marks and resolutions already are.
- *At stake:* missed main and no-reading sessions, and the stated bound.

**R3. Medium (unverified against the venue). Background discovery sends a request body never sent before.** `thesis/market.py:326-330`.
- *The difference.* `universe(background=True)` asks core meta as `{"type": "meta", "dex": null}`. The foreground, and every request ever recorded, sends `{"type": "meta"}` (probe P3). The docs say `dex` "defaults to the empty string"; whether `null` is accepted is unknown, and the fakes accept anything.
- *If the venue rejects it:* every `warm_order()` raises, no fill pass runs, `thesis-prewarm` fails at its first request so the bootstrap is impossible, and with R1 every market goes unready after the first midnight.
- *Fix at the cause:* one request body for both priorities. Only the admission flag differs.

**R4. Medium. Mondays acquire two full snapshots at once, and the bound excludes them by its own terms.** `thesis/runner.py:277-297`, `373-382`.
- *The duplicate.* `benchmark()` builds `snapshot(monday)` at 00:00 under a hold, while `schedule` builds the 00:05 snapshot. Both are foreground and share 120/min. The 00:00 one does the full repair-mode request set (prefixes and tails) and the 00:05 one adds a tail per market, so Monday is about 1.7 days' work: 4 of C10.5's 28 days lie outside the conditional bound T3 states.
- *The benchmark already has what it needs in the 00:05 snapshot.* Its closes are the bar opening Saturday 00:00 and the one 20 days earlier, both in that snapshot. Projecting the daily bars to those known at Monday 00:00 (`t + DAY + DELTA <= monday`) reproduces its daily content exactly. Only the listing read is five minutes later, and the 90-bar eligibility can differ only at a market's 90th day.
- *Proposal for the dated revision:* the benchmark reads that Monday's attested snapshot so projected. One acquisition a day, no Monday exception. Its t_r becomes "after that day's acquisition", which the revision should state, since today it is set, unstated, by R1's readiness.
- *At stake:* missed Monday sessions under any start earlier than about 09:00, and the benchmark's entry hour.

**R5. Low. A late acquisition's listings are not as of its cutoff.** `thesis/runner.py:131`.
- *Failure.* Bars are filtered to the cutoff, but `listings()` is read at wall time. After a restart, acquisition may begin up to 18:55 after the cutoff: a market delisted in between is dropped from a snapshot labelled 00:05.
- *Consequence.* The draft's "all snapshot reads are as of the fixed cutoff" is not literally true. Registration re-reads the listing at commit (reading 10), so no thesis is admitted on a stale listing; the effect is on the `markets` universe shown.
- *Fix:* record the listing read's time in the snapshot, and state it in the revision.

**R6. Low. Leftovers to erase.** Four items:
- `thesis/tests/test_market.py:746-754`: the former strict xfail now asserts that 524 tails fit before 19:00, which is vacuous: they need about 105 minutes of a 19-hour gap. `test_snapshot_schedule.py` pins the real envelope, so delete this test.
- `PROGRESS.md:44-45` on the branch: "paper correction pending" and "the snapshot schedule still fails strictly" are both stale after `b13fe40`.
- `runner.prewarm()` (`runner.py:465-477`) duplicates `Track.prewarm` without its per-market error handling, so one failing market ends the pass.
- The `audit/decisions.md` line has no time (the others pair UTC and EST).

**R7. Low. T3's envelope assumes d ≤ 5.** Sonnet's research (item 33, third-party and unverified) lists 10 registered dexes, which makes discovery 240 weight, not 140. This is immaterial to the time, but T3 should say so where it cites `d ≤ 5`.

### The seven findings and the human's decisions: checked

| Finding | Fix | Checked |
|---|---|---|
| 1 partial comparator | registration refuses a market without acquired history (`runner.py:107-110`) | at its cause, but over-broad: it also refuses markets whose only gap is today's (R1) |
| 2 range-aware repair | `funding_repaired` keeps (interval, time) per priority, and only checked or fetched intervals renew (`market.py:491-507`) | at its cause; GPT's starvation and frequent-read regressions pass; restart forgets freshness, which is conservative |
| 3 actual workload | gaps, repairs and tail planned once and merged before fetching; T3 rederived with ceiling rounding | at its cause; the envelope is correct as an envelope but loose (schedule, below) |
| 4 held discovery | `listings(background=True)` through to every meta | at its cause, but see R3 |
| 5 bootstrap | `thesis-prewarm` under the root lock, SIGTERM-stoppable | works; see R6 |
| 6 legacy `funding.json` | legacy rows merged on load, win conflicts, certify no range | as decided and logged |
| 7 excess charge | `ceil(n/q) - ceil(r/q)` | correct |
| Decision 1 | as finding 1 | over-broad (R1) |
| Decision 2 | cutoff 00:05, attested `snapshot_ready` (cutoff, completion, sha256), late or missing means main and no-reading missed, no replacement | holds: kill after publication and before attestation re-attests the same bytes only before the deadline; changed or lost bytes before main fail closed; lost bytes after main miss only the rest; SIGTERM leaves the date; 429 storms leave progress in the caches and retry each minute until the deadline |

## The schedule

### What the 50,590-weight envelope is made of

T3: 7 discovery calls (140), 278 daily prefixes (39 each, 10,842), a daily tail and a terminal empty request for all 348 listings (14,616), and a prefix, tail and terminal request for all 176 core hourly scopes (24,992). That is 56% prefix probes (rule 12 of the 2026-11-02 readings retries "rows before the first cached one" every hour, and the daily snapshot is the only read of most daily caches) and 22% terminal empties (`Info.candles` asks again when the current bar has no trade yet). The 18:13:51 bound adds 701 limiter-minutes for that envelope, 133 minutes of mark windows, and a 10-second service allowance for each of 1,514 attempts (4.2 h), counted in addition to the waiting. But the run is limiter-bound: HTTP time overlaps the minute-expiry waits. The simulation below gives the same minutes at 0, 0.7 and 2 s per request.

The recorded inventory (2026-10-28 counts) does not fill that envelope:
- Only **3** of the 176 eligible core markets are younger than the 200-day hourly scope, not 176.
- Of the 278 live markets younger than the 1,125-day daily scope, **197** are younger than 500 days. `holes()` joins their prefix and tail into one 39-weight request, so neither a separate prefix nor a separate tail is sent.
- No eligible market had an interior daily gap.

Simulated with the limiter's own admission rule at 120/min (`sim_acquisition.py.txt`; it reproduces GPT's 632 minutes for the envelope):

| Request set | Requests | Weight | Packed minutes |
|---|---:|---:|---:|
| T3 envelope | 1,509 | 50,590 | 632 |
| this code, recorded inventory | 615 | 16,896 | 152 |
| same, 100 terminal empties | 715 | 18,996 | 173 |
| same, a terminal empty for every listing | 963 | 24,204 | 217 |
| tails only (rule-12 prefixes off the session path) | 531 | 11,144 | 105 |

Measured, not simulated: the running track's 2026-10-28 00:11 UTC (2026-10-27 20:11 EDT) snapshot (old code, floor rounding: six 20-weight requests a minute) sent 557 requests, 358 daily and 176 hourly candle reads, in **92 minutes**. That is one request per market and interval, which matches the model (534 × 20 / 120 = 89 min).

What remains outside every row of the table: interior no-trade hours of illiquid core markets (rule 12 retries them each snapshot, up to about 100 weight per market, unmeasured), retries, and resolution reads at midnight. Two items can be moved off the session path but need not be:
- The rule-12 prefix probes could become a daily background retry of answered pre-listing ranges. That is a change to a frozen reading's cadence, so a human decision.
- At a 00:05 cutoff the last 1h close of a market that traded in the last hour equals its daily close. Dropping the 176 hourly tails changes the `markets` definition, and the equality is uncertified.

### Worst-case sizing against a high quantile

**Sizing to a worst-case bound** (19:00) buys protection only in the band between about 4 h and 18 h of acquisition. That band needs mass retries, unmeasured holes or contention. Beyond 18 h GPT agrees there is no guarantee, and inside the band R1 refuses the session's registrations anyway. The cost is paid every day:
- **Information timing.** Daily bars, eligibility and base-rate anchors are identical for any start in (00:02, 24:00). What changes is that `markets` shows a last 1h close 18 h 55 min old, and the entry is at about 20:00, some 20 h after the last price the agents saw. Only the main arm can learn those hours through `fetch`, so main's advantage over the no-reading and ablation arms includes a staleness artefact that the 00:10 design did not have.
- **Session window.** Four one-hour sessions share five hours. A model outage just over an hour at 19:00 costs the no-reading session; over four hours, main.
- **Entry hours.** About 20:00 UTC (15:00 EST) for main, against an unstated post-acquisition hour for the benchmark (R1, R4). The old design had both near 01:00 UTC (20:00 EST). The cost cells are not by hour, so costs are unchanged; HIP-3 equity perps are then in US cash hours, which is a difference to report, not a defect.

**Sizing to a high quantile, with a late snapshot counted as missed** (the miss policy already in the build), costs only misses. C10.5 tolerates them: it needs 20 accepted main theses in 28 days with at most two a session, and a missed no-reading session reported as missed meets its clause. Every miss is disclosed, so nothing is excused.

### Recommendation

- **Cutoff 00:05 UTC** (19:05 EST the day before), as drafted.
- **Acquisition** begins at the cutoff on its own loop (R2), one a day; the Monday benchmark reads it (R4).
- **Completion deadline and session start: 05:00 UTC (00:00 EST).** The derivation:
  - 217 packed minutes for the recorded inventory with a terminal request for every listing;
  - plus four mark windows of 7 minutes (01:00 through 04:00), 28 minutes, finishing at 04:10;
  - plus 50 minutes of margin for five extra attempts (5 min), ten registered dexes (1 min), and the unmeasured interior hourly holes and midnight resolution reads.
  - The on-time snapshot age at start is 4 h 55 min; the maximum start-age stays strictly under 23 h 55 min.
- If the human moves rule-12 prefixes off the session path, the same derivation gives 105 + 21 + 50 minutes, done before 03:00. Start no earlier than 04:00 regardless, until measured acquisition times exist.
- **Preconditions:** R1 fixed (else a 05:00 session often precedes the day's funding fill and is refused), R2, R3 and R4. Without R4, Monday needs about 09:00.

### What the dated revision must say

1. Cutoff, acquisition start, completion deadline and session start as above, each as a time paired with Eastern. The derivation is T3's table above (inventory counts, packing, mark windows, margin), stated as a choice from a recorded inventory, not a bound. Larger inventories, holes, retries or outages may cause a miss, which is reported, never relaxed.
2. A late or missing attested snapshot makes main and no-reading missed for the date, with that reason. There is no late snapshot and no other date's snapshot; recovery uses only the attested bytes. Each date's `taken`, `acquired` and request count go in the C10.6 report, so the miss distribution is measured. Changing the start after seeing it is a new identity.
3. Acquisition is independent of sessions and model readiness. Sessions may wait for the model until the date ends.
4. Readiness: history the venue was never asked for makes a market unavailable that session (the human's decision). The hours since the last fill are fetched by the registration's own read and are not unavailability.
5. The benchmark reads that Monday's attested snapshot projected to bars known at Monday 00:00. Its t_r follows the acquisition.
6. The snapshot records when its listings were read (R5).
7. What it changes: `markets` shows the last 1h close as of 00:05; entry about 06:00 UTC (01:00 EST); daily bars and base-rate anchors unchanged. It is a new identity and window, never a pass of the 00:10 rule.

## Crash recovery ("no such table: disclosures")

**Confirmed, and already fixed on this branch before this round, not by it.**
- *The state.* SIGKILL of `mm disclose` the moment its ledger file appears left a zero-byte file with no schema in 200 of 200 tries (`repro_kill_disclose.py.txt`, using main's `mm`; the kernel opens the file before `execute_batch(SCHEMA)`).
- *The readers.* On it, `main`'s `Ledger.records()` (`thesis/registry.py:59` there) raises `no such table: disclosures`; this branch's returns `[]` (`repro_empty_ledger.py.txt`). The branch's schema check came with `2281a3b` (2026-11-07 02:13 UTC (2026-11-06 21:13 EST)), with a unit test (`test_a_killed_schema_transaction_reads_empty_and_the_next_write_recovers`). The next disclosure creates the schema (`CREATE TABLE IF NOT EXISTS`).
- *The failures in PROGRESS* are therefore main's tree: there, the day test's first disclosure comes after the `day` checkpoint.
- *Coverage now.* This round attests the snapshot before that checkpoint, so the day kills no longer reach a first write; the unit test still covers it. The live track's ledger already has its schema, so it is not exposed.

## Suite

**The sharded runner could not run this branch.** `python3 ops/shards.py /home/kevin/repos/mm-rv-rf4` failed in 33 s, with every shard exiting 4 on `unrecognized arguments: --shard-report`: the branch's `conftest.py` predates main's `--shard-report` hook, and that will resolve when the branch is rebased onto `main`.

**A local run instead:** `nix develop -c pytest -n 8` in a scope capped at 7 GB, scratch on disk, without `data/`, and with other sessions loading the PC. Result: **1,330 passed, 4 failed, 2 skipped, 19 xfailed**, 959 s.

The four failures:
- Three need `data/`, which this worktree lacks:
  - `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` (`data/store/policy.json`);
  - `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit` (`data/store` funding);
  - `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped` (makes its scratch under `data/`).
- One xdist worker crashed during `reference/tests/test_lean_differential.py::test_verdicts_agree`, under concurrent load. Rerun alone, it passed in 13 s.

Every `thesis/` test passed, including the day SIGKILL cases in `test_crash_recovery.py`. My probes P1-P3 (`test_round4_probes.py.txt`, written to pass when each defect is present) all pass on `1160c7b`.

## What else could change a judged result or lose a recording

Beyond R1-R7, nothing found. Snapshots are stored per cutoff and not per version (`snapshots/<cutoff>.json`): a version frozen on a Monday after the old one took its 00:00 benchmark snapshot would reuse the old bytes. That is harmless if the format is unchanged; R4 removes the 00:00 file entirely. No recording path is touched by this diff.
