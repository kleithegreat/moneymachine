# Thesis refreeze round five, build record by Claude Sonnet 5.5, 2026-11-08 18:42 UTC (13:42 EST)

Branch `thesis-refreeze` (`../mm-thesis-rf`), main merged first (`ed4faa5`) so the sharded runner works. Inputs: Opus's round-four review (R1-R7), Sonnet's T3 review, the schedule decided at 18:04 UTC (13:04 EST) (`audit/decisions.md`). No exchange endpoint was called; the only `data/` read was counts and ages of the pre-window 2026-10-28 snapshot (listing names, daily-bar ages: no price). Nothing frozen, deployed or pushed; `audit/criteria.md` untouched.

## Fixes, each starting as a failing test (`thesis/tests/test_refreeze_round5.py`; 11 of 12 failed before the fix, the twelfth, history never asked for, already held)

- **R1.** `Market.ready` is now "history acquired to within `FRESH` = one page (500 hours) of now" (`_acquired_to`: the end of the fetched range holding the scope start). A registration's read for a market not in the account starts `FRESH` back, so the hours since the last fill are its own read. Tests: a market acquired at 03:00 is ready and registers at 05:00 the next day with the tail request `(acquired + 1, now + 1)`; never-asked history stays unavailable; a gap of one page is ready, one hour more is not. The cause was `ready` conflating history never asked for with the hours since the last daily fill. `prewarm` keeps filling to the last UTC midnight.
- **R2.** `Track.acquisitions` on its own loop (`acquire` thread in `run`); `schedule` only reads `attested(date)` and never snapshots. Tests: a due date is acquired while a long session is irrelevant; `schedule` takes no snapshot; `run` starts an `acquire` loop.
- **R3.** `Market.universe` sends `{"type": "meta"}` or `{"type": "meta", "dex": d}` in both priorities (only `background=` differs); `Exchange.meta()` is no longer used there. Test: the three bodies are identical foreground and background.
- **R4.** `benchmark(monday)` reads `attested(monday)` through `known_at` (daily bars with `t + DAY + DELTA <= monday`, markets still having 90 bars); no `snapshot(monday)` call. `benchmarks` records "no attested snapshot" for each unprocessed market once 05:00 UTC (00:00 EST) has passed without one, and "run missed" as before for an attested day left unprocessed. Tests: no second snapshot, the data the registration sees is known at midnight while the 00:05 file holds Sunday's bar, no `monday.json`; the missing-snapshot skip.
- **R5.** The snapshot records `listed_at`, the time of its listing read. Test: a snapshot taken at 03:00 for the 00:05 cutoff says so.
- **R6.** Deleted: the assert-nothing ex-xfail test (`test_the_session_snapshot_tails_fit_between...`), `test_a_snapshot_that_outlasts_the_day_starts_nothing` (a duplicate of the deadline test), the module-level `runner.prewarm`'s own loop (now `fill`, shared with `Track.prewarm`, so one failing market no longer ends the bootstrap pass), `Info.meta()` in discovery, the 19:00 text. PROGRESS's stale lines rewritten. The round-four decisions entry has no time; a correction line was appended (its commit is 16:40 UTC (11:40 EST)).
- **R7.** T3 takes d from the recorded listings: ten dexes (xyz, flx, vntl, hyna, km, abcd, cash, para, mkts, io), so discovery is 240 per pass, 23,040 a day.

## The schedule and its tests

`SESSION_OFFSET = 5 * HOUR`, `SNAPSHOT_OFFSET = 5 min`. Pinned in `test_refreeze_round5.py` (the two constants; 5 + 217 + 28 + 50 minutes = 05:00) and `test_snapshot_schedule.py` (late or missing attestation misses main and no-reading, no replacement snapshot, SIGKILL recovery, the recorded inventory packing in the limiter at 222 minutes in sorted order, inside the window with 40 minutes spare). The crash-recovery and runner tests were ported to `acquire` then `schedule`.

## T3's numbers

On the recorded inventory (ten dexes): the code's plan is 620 requests, 16,996 weight, 153 minutes; with a terminal request for every listing 968, 24,304, **217 minutes** (222 to 231 in other orders; the running track's real snapshot took 92 minutes for 557 requests). Completion 00:05 + 217 + 4 x 7 = 04:10 UTC (23:10 EST); start 05:00 UTC (00:00 EST); margin 50 minutes. The funding allowance is 348 x 22 = 7,656 a day (5.32 a minute), the 278 x 45 withdrawn; 18 mark intervals not 19; 278 prefixes justified as listings younger than the daily scope; the old envelope (1,509 requests, 50,590 weight, 632 minutes, C = 65,211 s = 18:06:51) stays as a stated qualification. Miss budget m = 28 - 20/r (8 at r = 1, 14 at r = 1.4, 18 at r = 2).

## Open for the advisor

- **C10.5 holds exactly four Mondays.** Decided by the advisor (18:47 UTC (13:47 EST), `audit/decisions.md`): a batch of five skips does not count as executed. The benchmark waits for the day's attested snapshot until the date ends and registers at the first whole hour at or after max(05:00 UTC (00:00 EST), the attestation), its information set unchanged. A Monday's snapshot may be attested after the session deadline (`last_acquisition`) and serves only the benchmark; sessions still miss. Tests: `test_the_benchmark_waits_for_its_days_snapshot...`, `test_a_snapshot_attested_after_the_deadline_serves_only_the_benchmark`, `test_only_a_snapshot_missing_the_whole_date...`. Also `test_the_series_in_its_pods_view` now skips when `bwrap` is absent.
- The ten dexes exceed the five of the initial mark wave (an existing blocker, now with a count).
- The 217 minutes assumes a terminal request for every listing; the typical figure is 153.

## Suite

Sharded runner after the Monday rule: 1,880 of 1,880 reported, 1 failed (`test_under_a_read_only_root`, bwrap absent on prodesk7; now skips on a capability check like `test_the_series_in_its_pods_view`, passes here), 1,859 passed, 1 skipped, 19 xfailed, 143 s. Mypy strict passes.
