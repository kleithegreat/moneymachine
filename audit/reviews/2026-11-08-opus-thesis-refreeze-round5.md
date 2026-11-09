# Thesis refreeze round five, review by Claude Opus 5.5, 2026-11-08 21:01 UTC (16:01 EST)

Reviewed: Sonnet's round-five build on `thesis-refreeze`, three-dot `6e37e5e...b29eb06`. The round's own commits are `ed4faa5..b29eb06`: `8e1fb40`, `f786009`, `9c9feed`, `9513498`, `254444c`, `e293aa9`, `0aa3d74`, `b29eb06`. The rest of the three-dot diff is the merge of `main`. I worked in a detached worktree at `b29eb06` without `data/` (`../mm-rv-rf5`). Read with it: `CLAUDE.md`, `PROGRESS.md`, Sonnet's build record, my round-four review and Sonnet's T3 review, the 18:04 UTC (13:04 EST) and 18:47 UTC (13:47 EST) entries in `audit/decisions.md`, `audit/stage10/criteria-revision-draft.md`, stage 10 of `audit/criteria.md`, and T3 of `docs/whitepaper.tex`. **Claude-only:** Sonnet built this round. Argon's T3 check stays queued for its reset.

No exchange endpoint was called. The only `data/` reads were on pre-window files, as in round four:
- the 2026-10-28 snapshot (`data/thesis/snapshots/1793146261723.json`): listing ages only;
- `data/thesis/exchange/info-20261028.jsonl`: candle request bodies and response timestamps, no price.

Probes and scripts are in `2026-11-08-opus-thesis-refreeze-round5/` beside this file. They are renamed `.py.txt`, per the 06:20 UTC (01:20 EST) decision.

## Verdict

**Ready after fixes.** R1-R7 are fixed at their causes, and every constructed failure holds (table below). The decided schedule and the Monday rule are implemented as decided. Three things must change before the criteria revision is committed: the text that will be frozen (F1, F2) and the report's measurement of misses (F3). None of them changes code paths that decide a session. F1 strengthens the 05:00 choice rather than weakening it.

## R1-R7 at their causes

| Finding | Constructed failure | Result |
|---|---|---|
| R1 readiness at midnight | P1: real `Market` and `Track.inputs`. Funding filled at 03:00 on day D, no further fill. Registrations at D+1 05:00, D+1 23:00 and D+20. | Ready each time. Each sends exactly one funding page. Its comparator rows equal those of a market filled fresh at the registration time. A gap past one page (D+21) is refused. |
| R1, account markets | By reading the code: an account market's start is its earliest t_r, which overrides `now - FRESH`. | Safe. Ranges only grow, and the registration at t_r read from t_r - FRESH, so the history acquired reaches at least t_r. |
| R2 acquisition loop | P2: `schedule` blocked in a session from 23:59 across midnight on another thread, then `acquisitions` at 00:05. | The next date is attested while the session still runs. |
| R2, kills | P6: the acquisition SIGKILLed (a) mid-snapshot, before publication, and (b) after publication, before attestation; then restarted at 02:00. | (a) A new snapshot is attested. (b) The killed process's exact bytes are attested. Both are attested at 02:00. |
| R3 discovery body | By reading `universe` and Sonnet's test. | One body for both priorities: `{"type": "meta"}` for core. |
| R4 Monday benchmark | P4: `known_at(snapshot(00:05), Monday)` against the old `snapshot(Monday 00:00)`. The fixture market has 90 daily bars at 00:05 and 89 at midnight. | Daily bars and the eligible set are identical, and the 90th-bar market is excluded by both. No second snapshot is taken. |
| R5 listing time | Sonnet's test. | `listed_at` is recorded. It sits inside the attested bytes. |
| R6 leftovers | By reading the diff. | All four are done: `fill` is shared and one market's failure no longer ends a pass. |
| R7 dex count | Arithmetic. | d = 10: 240 per pass, 23,040 a day. |

**The decided schedule** is `SNAPSHOT_OFFSET` = 5 min and `SESSION_OFFSET` = 5 h:
- A non-Monday attestation is accepted only up to 05:00. A Monday's is accepted up to the end of the date (`last_acquisition`).
- `schedule` misses main and no-reading if no snapshot is attested by 05:00. It never snapshots.

**The Monday rule** is implemented as the 18:47 UTC (13:47 EST) entry states. Waiting until the date ends is the conservative reading of C10.5's "4 executed benchmark batches", and I agree with it. The cost is a later t_r on a late Monday: same T, and an entry up to 23 h later. That is disclosed through t_r.

## Findings, ranked

**F1. Medium. The schedule's stated derivation counts the wrong terminal requests, and the recording settles the question it calls unverified.** Locations: T3 ("Daily snapshot and chosen schedule"), draft item 1, and `test_the_recorded_inventory_packs_inside_the_window_before_the_session`.
- **The error.** The 217 minutes is labelled "as if the venue omitted the unclosed candle", but it adds a terminal request only for the 348 daily scopes. A venue that omits the unclosed candle omits it from the 176 core hourly scopes as well: at a 00:05 cutoff, the 00:00 hourly bar is unclosed. The figure came from my round-four table ("a terminal empty for every listing"), which made the same omission.
- **The recording.** The pre-window 2026-10-28 archive (`count_terminals.py.txt`) shows the venue returned the unclosed candle in 514 of 524 scopes, including all 176 hourly ones. The 10 others were daily scopes whose current bar had no trade yet, and each was followed by one empty terminal request. `Info.candles` was the same loop then (`d28dcc4`).

Simulated with `sim_terminals.py.txt`, ten dexes:

| Case | Requests | Weight | Packed | With mark windows |
|---|---:|---:|---:|---|
| Recorded behaviour (10 daily terminals) | 630 | 17,206 | 155 min | 2 marks, done **02:54 UTC** (21:54 EST): 2 h 6 min to spare |
| T3's stated case (daily terminals only) | 968 | 24,304 | 217 min | 04:10 UTC (23:10 EST): inconsistent with its own label |
| Venue omits the unclosed candle (daily and hourly) | 1,144 | 28,000 | 252 min | 4 marks, done **04:45 UTC** (23:45 EST): 15 min to spare |

- **What it changes.** The 05:00 start holds under both consistent cases, and the recorded one gives it a margin of over two hours. But the text that would be frozen states a margin of 50 minutes for a scenario that really leaves 15, and calls "unverified" a behaviour the recording shows.
- **Fix.** Derive from the recorded behaviour (155 min, done 02:54 UTC (21:54 EST)). State the omit-unclosed case as a stress case (252 min, done 04:45 UTC (23:45 EST)). Drop the "222 to 231 in other orders" (the code's order is the one that runs). Rewrite or delete the packing test, which pins the inconsistent 968 / 24,304 histogram.
- **At stake:** the derivation frozen with the criteria revision, and the margin that the miss tolerance rests on.

**F2. Low. A Monday snapshot attested after 23:00 UTC (18:00 EST) leaves the batch "run missed".** Locations: `runner.py` `benchmarks`; draft item 5; the 18:47 UTC (13:47 EST) entry.
- **The behaviour.** The first whole hour at or after a 23:30 attestation is 24:00, which is outside the date. The batch never runs, and on Tuesday each market is recorded "run missed" (probe P5 passes on `b29eb06`).
- **The contradiction.** The draft says the registration hour can move "up to 23:00", and that "only a snapshot missing for the whole date leaves the batch unexecuted".
- **Fix:** one sentence in the draft: an attestation after 23:00 UTC (18:00 EST) leaves the batch run missed. Keeping whole hours is simpler than registering at the attestation. The case needs an acquisition of nearly 23 hours.
- **At stake:** whether one of C10.5's four batches counts as executed, and the honesty of the stated rule.

**F3. Low-medium. The report does not carry the miss measurement the draft promises.** Locations: draft item 2; `thesis/report.py:77-90`.
- **The gap.** Draft item 2 (round four's list, item 2) says each date's `taken`, `acquired` and request count go in the C10.6 report, "so the miss distribution is measured". `report.write` never reads `snapshot_ready`, and no request count is recorded anywhere.
- **Fix:** the report lists the `snapshot_ready` records, including `listed_at`. Then either record the snapshot's request count in its attestation, or derive the count from the exchange archive (counts only), or drop it from the text. Each option needs one test.
- **At stake:** the evidence that the 05:00 choice is judged on (F1's margin), and C10.6's enumeration of skips.

**F4. Low. A thread race at the deadline can record both an on-time attestation and two misses.** Locations: `runner.py` `acquire` and `schedule`.
- **The race.** `acquire` stamps `acquired` and then discloses through the kernel, which takes milliseconds. `schedule` on the other thread may read the ledger at 05:00 in between. It then records main and no-reading missed for "no attested snapshot before the completion deadline", beside a `snapshot_ready` whose `acquired` is before 05:00.
- **Consequence.** It fails closed, but the record contradicts itself. It needs completion within about 100 ms of 05:00.
- **Fix hypothesis:** one writer decides the date. For example, the acquisition loop records the date's misses when its window closes unattested, and `schedule` waits for either record.
- **At stake:** two sessions on a date that rarely exists, and the record's consistency.

**F5. Low. Erasure.** Four items:
- **Three near-identical late-attestation tests:**
  - `test_acquisition_that_misses_its_completion_deadline_cannot_start_a_session`;
  - `test_snapshot_publication_must_finish_before_the_deadline`;
  - `test_a_late_attestation_misses_main_and_noread_and_takes_no_replacement`.

  All three run on `MONDAY`, whose acquisition window runs to the date's end. So none exercises a non-Monday attestation refused by `acquire` itself. Keep one, on a non-Monday, asserting that no `snapshot_ready` is written. Delete the other two.
- `test_the_recorded_inventory_completes_with_margin_before_the_start` asserts arithmetic on literals and duplicates `test_the_schedule_is_cutoff_0005_and_start_and_deadline_0500`. Delete it.
- T3's "worst-case envelope, kept as a qualification" paragraph re-derives a rejected bound at length. Its derivation already lives in round four's two reviews. Make it one sentence citing them and the 18:04 entry. Then delete the second half of `test_the_paper_snapshot_envelope_includes_real_prefix_tail_and_empty_requests`, which pins the 1,509 / 50,590 / 632 envelope. Its first half pins real request costs and stays.

**Noted, not acted on.** An acquisition past its last moment is not abandoned: `snapshot()` runs to completion, holding the limiter. If it ran past the next cutoff it would delay that date's acquisition, which needs an acquisition of over 24 hours. It changes no outcome inside any case above.

## The criteria draft against round four's list

| Round four's item | Draft | Check |
|---|---|---|
| 1 schedule as a choice, with times paired | item 1 | as listed, but the numbers are wrong (F1) |
| 2 misses; taken, acquired and count reported; changing the start is a new identity | item 2 | the text is there; the report is not (F3) |
| 3 acquisition independent | item 3 | implemented (R2, P2, P6) |
| 4 readiness | item 4 | implemented, with "more than one page" added. This is benign: the daily fill keeps the gap under about 29 hours. |
| 5 benchmark on that Monday's snapshot | item 5 | implemented, with the 18:47 UTC (13:47 EST) Monday rule (F2) |
| 6 listing read time | item 6 | implemented |
| 7 what it changes; new identity | item 7 | as listed |

**Before the freeze, not from this round.** The draft leaves ten dexes "not cleared". Stage 10's sampling clause says "for every builder dex and hour boundary H, a request is sent at H + 5 s". At 120 per minute, discovery plus ten dex calls is 220 weight, so dexes six to ten are sent in the next cohort, about H + 60 s. Those samples are still candidates in [H, H + 5 min), so marks are unaffected. Only the stated send time fails, every hour. The running version carries the same failure. The dated revision being written is the natural place to restate the send time as quota-sized cohorts within [H, H + 5 min), rather than freeze a known failure into a new identity. That is the advisor's call, with its own review. Shared-IP coordination and the unbounded foreground service bound stay as stated.

## Suite

`python3 ops/shards.py /home/kevin/repos/mm-rv-rf5`: **1,880 of 1,880 reported, 1,856 passed, 3 failed, 2 skipped, 19 xfailed**, wall 330 s.

The three failures need `data/`, which this worktree lacks. They are the same three as in round four:
- `kernel/tests/cli/test_differential.py::test_kernel_matches_witness`;
- `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped`;
- `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`.

Every `thesis/` test passed. My six probes pass on `b29eb06` (`test_round5_probes.py.txt`):
- P1, P2, P4 and P6 (both cases) because R1, R2 and R4 hold;
- P5 because F2 is present.

The probe file was not committed to the branch.
