# Thesis refreeze round six, review by Claude Opus, 2026-11-08 22:43 UTC (17:43 EST)

Reviewer: Claude Opus 5.5, a fresh session. This is the last review before the refreeze. It ran things in `/home/kevin/repos/mm-rv-rf6`, detached at `35e7efb` (`thesis-refreeze`), with no `data/`. Reviewed: round six by GPT, three-dot from `2229563` (`feff64c`..`85837ae` plus the build-record commit `35e7efb`; build record `audit/reviews/2026-11-08-gpt-refreeze-round6-build.md`), against Argon's `audit/reviews/2026-11-08-argon-web-refreeze-t3.md` and the human's 2026-11-08 21:44 UTC (16:44 EST) decisions on `main`. I made no venue call and read no protected data. The reproductions are in `2026-11-08-opus-thesis-refreeze-round6/` as `.py.txt`. To run them, rename them to `.py`, then run `PYTHONPATH=. TMPDIR=/tmp nix develop -c python -m pytest -p conftest -s <file>` from the worktree. They use real threads under a warped clock (`warp.py`), and the real `WeightLimit`, `MarkLimit`, `Exchange` and `Market` on a fake HTTP venue.

## Verdict: ready after fixes

Each of Argon's six findings is fixed at its cause, and I reproduced each construction against the new code. I found no deadlock, starvation or 429 regression in the FIFO limiter. Day-fixed readiness and the funding tail hold. The approved Monday rule's inputs are identical whether the batch registers at 05:00, 14:00 or 23:30 UTC (00:00, 09:00, 18:30 EST).

Two things should be settled before the freeze, because the freeze cannot be undone:
- F1 is a defect that the imminent freeze date would trigger.
- F6 is a set of wrong numbers in the text that is about to be committed as criteria.

F3 is a strongly recommended design fix: one expression turns the stress case from a miss into a fit. The rest are small.

## Argon's findings, checked against the new code

| Argon | Fixed at its cause? | Evidence |
|---|---|---|
| §4.1 resolution starvation under a saturating snapshot | Yes. Foreground admission is a FIFO ticket queue (`ingest/hl.py:56-80`) and marks keep their priority. | `test_repro_fifo`: a snapshot loops on 20- or 21-weight charges while ten resolution threads each need two 22-weight pages. All 20 pages are admitted within 243 s and the snapshot still progresses. GPT's deterministic `test_resolution_priority.py` passes. |
| §4.2 cohort pagination consumed retries; give-up came 70 s early | Yes (`thesis/market.py:421-432`). Cohorts run inside each error wave, and give-up comes at H + 290 s. | `test_repro_marks`, failing dex d7 in cohort 2: first sends at H + 5 s (d0-d4); one dex takes the freed slot; the rest go at H + 65 s. d7 gets 6 attempts (H + 65 s to H + 150 s), and the other nine seal. |
| Seal boundary | Yes (`market.py:145`). | A sample with `sent` or `recv` equal to H + 300 s is excluded, and one at H + 299.999 s is kept (`test_seal_boundary`, 5 cases). |
| §4.3 an unattested file after SIGKILL is reused | Yes (`runner.py:127-131`): only a ledger attestation with matching bytes is reused. | GPT's spawn-and-SIGKILL test passes in the suite. The path that reuses an existing file is unreachable in production; see F7. |
| §4.4 a late weekday acquisition runs past 05:00 UTC [00:00 EST] | Yes. Cancellation is threaded through `hold(cancel)` into every limiter wait, and `check()` runs between markets and pages (`runner.py:132-171`). | `test_repro_acquire`, weekday: queued in the mark-prep block from 04:59:05 UTC [23:59:05 EST]. It is cancelled 0.1 s after 05:00 UTC [00:00 EST] (00:00 EST), with holds 0 and an empty queue. No file is published and nothing is attested. Main and no-reading are recorded missed, and background admission resumes. |
| §3A/§3B Monday benchmark at 05:00/14:00/23:30 UTC [18:30 EST], and an attestation in [23:00, 24:00) | Yes. `t_r` is Monday midnight, `registered_at` is separate (`registry.py:173-180`), and inputs are fixed at Monday midnight (`runner.py:323-329`, `known_at`). | `test_repro_acquire`: BTC and ETH have identical `t_r`, `T`, `p` and window `N` at 05:00, 14:00 and 23:30 UTC [18:30 EST]; only `registered_at` differs. An attestation at 23:10 UTC [18:10 EST] (18:10 EST) registers at 23:10:15. One at 23:59:30 UTC [18:59:30 EST] (18:59:30 EST) is logged "run missed" (F4). |
| §3B Part A, cross-arm readiness on one day | Yes (`runner.py:108, 112, 158-163`). | `test_repro_acquire::cross_arm`, on a real snapshot: market C00 is acquired to 499.5 h before `readiness_at`. Main at 05:15 UTC (00:15 EST) is admitted while a live check says not ready. Main's own read then makes the live check true, and no-reading at 06:15 UTC (01:15 EST) is admitted from the same map. Neither arm misses an hour since acquisition. C01, cold at the snapshot, stays refused after the cache is warmed. |
| §1 and §3A, 252 vs 257 minutes | Reconciled: both figures are stated, and 257 is labelled tested. | Checked: 257 + 41 = 298 minutes, giving 05:03 UTC (00:03 EST); 252 + 41 gives 04:58 UTC (23:58 EST), 65 s before prep. |

## Regressions round six could have introduced

- **The FIFO limiter.** There is no deadlock. A ticket is held only inside `charge`, which takes only the limiter lock.
  - A cancelled head ticket leaves the queue, and the request behind it is admitted (`test_cancel_releases_the_queue_head_and_the_hold`).
  - Background work waits through a hold and through a non-empty queue, then runs within 7 s of the hold ending.
  - A request backing off after a 429 holds no ticket while it sleeps (`test_a_retrying_caller_releases_its_ticket_while_it_backs_off`: five attempts, queue length 0 throughout).
  - The cancel predicate is thread-local and composes with nested holds, and sessions' holds carry none.
- **Day-fixed readiness and funding tails.** Both are sound for agents. For the benchmark they turn one failure into a permanent one; see F8.
- **The attestation byte check.** `attested` now hashes and decodes one read (`runner.py:182-183`). A changed file makes the snapshot unusable: main and no-reading are missed.

## Findings, ranked

**F1 (medium; the imminent freeze date triggers it). The first Monday of a window frozen after Monday 00:00 UTC [19:00 EST] records every benchmark market as "not listed".**
- **Where.** `runner.py:144` (`listings_at(date)`), `market.py:349-353`, `runner.py:50-51`.
- **How it happens.** Listing observations are a new archive, written only by new-code `listings()` calls. Suppose the first new-code call on the track root comes after a Monday's midnight. This happens when the freeze, the runner start or `thesis-prewarm` falls on that Monday. Then `benchmark_listings == {}`, and `unbenchmarkable` names each of the five markets "not listed" (reproduced: `test_first_monday_without_a_listing_observation_before_midnight`).
- **Why it matters now.** It is now Sunday 22:43 UTC (17:43 EST), so the earliest realistic freeze is Monday 2026-11-09, which is exactly this case.
- **Outcome at stake.**
  - C10.5's "4 executed benchmark batches, each listing every market as registered or skipped with its reason". That batch either counts with false reasons or does not count.
  - C10.6's honesty about the batch's reasons.
- **Fix.**
  - An absent observation gets its own reason, "no listing observation by Monday 00:00 UTC [19:00 EST]".
  - The freeze runbook (or `freeze()`) ensures a new-code observation exists before the window's first Monday midnight. In practice: do not freeze on 2026-11-09 after 00:00 UTC [19:00 EST], or run new-code `thesis-prewarm` before that midnight.

**F6 (medium for the criteria commit; no judged result yet). Two numbers in T3 and the draft are wrong.**
- **Recorded-behaviour budget.** It is not "two marks, 03:05 UTC (22:05 EST), 1 h 55 min".
  - The work, 155 + 1 + 2 + 6 = 164 minutes from 00:05 UTC [19:05 EST], still runs past 02:59:05 UTC [21:59:05 EST] after the 01:00 and 02:00 pauses (it would end at 03:05 UTC [22:05 EST]).
  - So the 03:00 pause applies too, and completion is **03:13 UTC (22:13 EST), 1 h 47 min of margin** (`docs/whitepaper.tex:713`, draft item 1).
  - `test_refreeze_t3.py` hard-codes `4 * 8` rather than counting the pauses the timeline crosses, which is how this slipped.
- **The miss table.** It states "14 at r = 1.4" (`whitepaper.tex:721`, from `f786009`). In fact 28 − 20/1.4 = 13.71, so **at most 13** sessions may be missed.
- **Outcome at stake.** The revision is about to be committed as dated criteria, and its numbers then cannot be edited.

**F3 (medium; a design fix recommended before the irreversible freeze). The stress case is mostly requests whose answers the code throws away.**
- **Where.** `market.py:375-379`. `_cached` asks for rows up to `now`, but a daily row cannot be shown until t + DAY + δ (`SHOWN["1d"]`). The current day's candle is always discarded at line 379.
- **The waste.** When the venue omits that candle, `Info.candles` sends a terminal empty request for it. In the stress case that is 348 of the 514 terminal requests.
- **The fix.** One expression for every kind: cap the fetch end at `min(now, (now - SHOWN[kind]) // step * step + step)`, so the code never asks for a row it cannot show. Hourly scopes are unchanged, because the current hour's open is shown at δ.
- **Effect, measured with the round-six test's own inventory and packing (`test_repro_daily_cap`).**
  - Stress: 1,144 requests, 28,000 weight, 257 minutes becomes **796 requests, 20,692 weight, 188 minutes**. With T3's allowances and three pauses, completion is **03:46 UTC (22:46 EST)**, which fits.
  - Recorded behaviour: 620 requests, 16,996 weight, 153 minutes.
- **Outcome at stake.** C10.5 under a venue that omits unclosed candles. Today that case misses every day (fail while the machinery works).
- **Cost.** The T3 counts must be re-derived.

**F2 (low to medium; depends on venue behaviour that is unrecorded). Monday's widened scope requests markets absent from the current universe.**
- **Where.** `runner.py:145-150`. On a Monday the snapshot iterates `listings ∪ benchmark_listings`, so it asks for candles of markets the venue listed at midnight but no longer lists.
- **The risk.** The venue's answer for a coin absent from `meta` is not recorded. If it is an HTTP error, `Info.post` retries and then raises, the whole Monday snapshot fails, and `acquire` retries it every minute. Main, no-reading and the benchmark all miss.
- **Fix.** The benchmark needs only `BENCHMARK`, so widen the scope by `BENCHMARK` markets listed at midnight only.

**F8 (low). A benchmark market not ready at the Monday snapshot now blocks the rest of its batch.**
- **Where.** `runner.py:323`. `inputs` raises `TransportError` from the day-fixed map, and `benchmark()` stops at that market on every pass.
- **Effect.** At 24:00 UTC [19:00 EST] that market and every market after it are logged "run missed" (reproduced: `test_repro_benchmark_cold`, ETH cold leaves only BTC registered). Before round six, a later pass could succeed once the benchmark-first fill warmed it. A deterministic condition should not use the transient-retry path.
- **Fix.** Skip the market with the reason "funding not ready at the snapshot".
- **Plausibility.** Low: the freeze requires every market ready.

**F4 (low; erasure). The hour rounding and the [23:00, 24:00) special case are vestigial.**
- **Where.** `runner.py:416-421`. With `t_r` and all inputs fixed at Monday midnight, nothing depends on when the batch registers.
- **What the code does.** It rounds up to the hour, then special-cases the last hour, and still logs an attestation in the final pass interval as "run missed" (reproduced at 23:59:30 UTC [18:59:30 EST]). That contradicts the approval's "registers at attestation rather than missing the batch".
- **Fix.** Register at the first pass that finds a snapshot attested before 24:00 UTC [19:00 EST], with no rounding and no `elapsed < DAY` gate for it. Draft item 5 then reads simply.

**F5 (low). The benchmark's listing observation time is recorded nowhere.**
- **Where.** `registry.py:171-180` with `runner.py:324`. A benchmark thesis records `listings_read` as its registration wall times, but its `listings` are the latest observation by midnight. `listings_at` drops that observation's `at`, and the snapshot does not store it.
- **Outcome at stake.** C10.6's statement of "the listing read and its times" is false for every benchmark thesis.
- **Fix.** `listings_at` returns `(at, listings)`; the snapshot and the thesis record that `at`.

**F7 (low; erasure).** The reuse branch in `Track.snapshot` (`runner.py:127-131`) is unreachable in production: `acquire` returns first whenever a record exists. It duplicates `attested`, and only tests reach it. Delete it and let `snapshot` only acquire.

**Notes, not acted on, since none changes a judged outcome:**
- When every dex times out, waves begun before H + 290 s can wait for quota and send at H + 305-317 s (`test_all_ten_dexes_timing_out`). These samples are archived and never sealed. Release comes at H + 327 s, inside the 8-minute allowance.
- The benchmark's "no hourly close" membership comes from the 00:05 UTC [19:05 EST] read, not from midnight.
- `listings_at` parses every observation ever saved, about 1.4 MB/day. It could read only the newest day file up to `at`.

## T3 and the draft

The draft agrees with the code and with the human's 21:44 UTC (16:44 EST) decisions on every item except F4's wording ("registers at attestation"). The stress case is stated honestly as a projected miss that the miss rule handles, not as a bound.

**Constructions.**
- **Passes while the claim is false.** Freeze on Monday 2026-11-09 at 10:00 UTC (05:00 EST). The first batch then lists all five markets as skipped "not listed" (F1). It meets "each listing every market as registered or skipped with its reason", yet no market was actually not listed and no benchmark comparison exists for that week.
- **Fails while the claim holds.**
  - The fourth Monday's snapshot is attested at 23:59:30 UTC [18:59:30 EST]. The batch is logged "run missed" (F4), and C10.5 fails although the inputs were attested and fixed.
  - Separately, a venue that omits unclosed candles makes every day a miss (F3), failing C10.5 while forecasts, attestation and misses all work as designed.

**Ready to be committed alone as a dated revision?** Not yet. First correct F6's numbers. Then either fix F1, F4 and F5 in code and state them, or state F1's freeze-date precondition and F4's last-pass miss as written rules. If F3 is adopted, re-derive the item 1 counts.

## Full suite

`ops/shards.py` at `35e7efb`: 1,934 of 1,934 reported in 475 s. Results: 1,910 passed, 3 failed, 2 skipped, 19 xfailed, 0 missing (`2026-11-08-opus-thesis-refreeze-round6/suite-summary.txt`).

All three failures depend on `data/`, which is absent from this worktree:
- `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` (`data/store/policy.json`);
- `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped` (`data/store/funding: no revisions`);
- `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit` (cannot create a temporary directory under `data/`).

Every thesis test passed. My reproductions, outside the suite, report 23 passed. Each finding's assertion encodes the observed defect: the false "not listed" reason, the "run missed" at 23:59:30 UTC [18:59:30 EST], and the cold benchmark market.
