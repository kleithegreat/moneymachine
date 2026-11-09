# Thesis refreeze round seven, build by Claude Sonnet, 2026-11-09 (UTC)

Builder: Sonnet 5.5 on `thesis-refreeze` (`../mm-thesis-rf`). An earlier session of the same wake-up (2026-11-08 23:30 UTC (18:30 EST) to 23:38 UTC (18:38 EST)) left the code fixes uncommitted and no T3 or paper work; this one finished and tested them. Each finding of `2026-11-08-opus-thesis-refreeze-round6.md` is fixed at its cause, each from a test in `thesis/tests/test_refreeze_round7.py` (or the T3 tests).

| Finding | Fix |
|---|---|
| F1 | An absent listing observation has its own reason in `unbenchmarkable`; `freeze()` refuses while the window's first Monday midnight has no observation before it. |
| F2 | The Monday snapshot widens its scope only by `BENCHMARK` markets listed at midnight. |
| F3 | `_cached` never fetches past the last row `now` can show (`min(now, newest + step)`). Daily scopes send no terminal request. |
| F4 | `benchmarks` registers at the first pass after attestation, with no rounding or last-hour case; deleted `attested_at`. |
| F5 | `listings_at` returns `(at, listings)`; the snapshot stores `benchmark_listings_at` and each benchmark thesis records it as `listings_read`. |
| F6 | The miss table says 13 at r = 1.4. The budget is derived by a test that walks the timeline and counts the preparations the work reaches. |
| F7 | `Track.snapshot` only acquires; the unreachable reuse branch is deleted. Tests call `attested`. |
| F8 | A benchmark market not ready at the snapshot is skipped "funding not ready at the snapshot". |

## T3 re-derived under F3 (`test_snapshot_schedule.py`, `test_refreeze_t3.py`)

- Recorded behaviour: 620 requests, 16,996 weight, 153 packing minutes. Work 153 + 1 + 2 + 6 = 162 minutes reaches the 01:00, 02:00 and 03:00 UTC (20:00, 21:00, 22:00 EST) preparations: 186 minutes, **03:11 UTC (22:11 EST)**, 1 h 49 min before the start.
- Stress (venue omits the unclosed hourly candle): 796 requests, 20,692 weight, 188 packing minutes; 197 minutes of work plus three allowances is 221: **03:46 UTC (22:46 EST)**, 1 h 14 min before the start. It no longer misses.
- The 252-minute code-order figure is gone: the old text paired it with a different test; the new figure is the one test packs.
- Cold-cache envelope: 35,108 weight, 712 calls, 39/142 waiting envelope (no daily terminal request).
- Whitepaper, draft items 1 and 5, and the PDF are updated to match.

## For the human and the freeze

- Monday 2026-11-09 00:00 UTC (Sunday 19:00 EST) has passed with no new-code listing observation. Run new-code `thesis-prewarm` before Monday 2026-11-16 00:00 UTC (Sunday 19:00 EST), then freeze: `freeze()` now refuses otherwise.
- Not judged by me: this is a Claude-only build for Opus to review next.

## Suite

`ops/shards.py` on the final tree: 1,948 of 1,948 reported, 1,928 passed, 1 skipped, 19 xfailed, 0 missing. The first run found six failures, all tests of the old behaviour (hour-rounded registration, `listings_at` returning a dict, a snapshot without `ready`, a `freeze` double without `listings_at`) and one record line missing its Eastern time; each updated to the new rule.
