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

## Round eight (2026-11-09 02:30 UTC (21:30 EST)), G1-G4 of the Opus round-seven review

Tests: `thesis/tests/test_refreeze_round8.py`, each failing on `c775fbb` first.
- G1: `benchmarks` runs a batch at any pass that finds it attested (the inputs are fixed at Monday midnight); "no attested snapshot" is decided from the date's end, under `self.attestation`; transient failures are given up at `BENCHMARK_GIVE_UP` (two days after Monday midnight, Tuesday 19:00 EST), logged "run missed". Attestations at 23:59:30 and 23:59:59 UTC (18:59:30 and 18:59:59 EST) register; the in-flight race waits. The old cut-off test now uses the give-up time.
- G2: draft item 2 now says a market skipped for an operational reason does not count and a batch with any operational skip is not executed (a tightening only); a text test.
- G3: the latency allowance is 0.45 s per stress request (796 * 0.45 = 358.2 s, six minutes), so every completion time is unchanged; PDF rebuilt.
- G4: `freeze` takes one `now` for the guard, the cold check and `frozen`.
- Suite (`ops/shards.py`): 1,956 of 1,956 reported, 1,936 passed, 1 skipped, 19 xfailed, 0 missing; the data-dependent tests ran on nodes with data.

## Round nine (2026-11-09 06:45 UTC (01:45 EST)), the Opus hunt of `cb21d7c` (audit/reviews/2026-11-09-opus-hunt-thesis.md)

Tests: `thesis/tests/test_refreeze_round9.py`, each built from the hunt's reproduction and failing on `d7448d2` first, except the bar-cache two-process test, which passed there (kept as a guard).
- F1 (`runner.snapshot`, `unbenchmarkable`, `benchmarks`): a market whose daily or hourly read, or readiness check, raises is recorded in the snapshot's `failed` ({market: reason}), left out of `markets` and `daily`, and `ready` is false for it; the rest of the snapshot is attested. A cancelled acquisition still raises out. The benchmark skips such a market "market read failed at the snapshot: <reason>" (an operational skip, so the batch is still not executed). The batch loop isolates each market (`register_benchmark`): a failing one is logged and retried next pass, and at `BENCHMARK_GIVE_UP` only it is "run missed". Four old tests expected the batch to stop at the first failure; updated.
- F2 (`daemon.handle`): a response is written through `registry.write_atomic` (own temp file, rename), and not at all when the file already holds those bytes.
- F3 (`registry.exclusive`, `write_atomic`): the bar cache, funding commit, dex list and snapshot use unique temp names, and the two read-modify-writes (`_cached`, `_funding_commit`) take a flock on a sibling `.lock` file, replacing the in-process lock dict entries for them. Two forked processes commit 2 x 150 funding ranges, all kept.
- F4 (`harness.audit`): the client stays unchanged (`sandbox/` is part of stage 3's harness identity). A call is refused locally when its argv fails the SPEC arity (the client prints usage) or a FILE result starts `{"ok": false, "error"` (no daemon reply has an `error` key); these are counted in `refused_locally` and not as daemon calls. The rest map to daemon records one to one by command and arguments (FILE arguments by count, shell-expanded arguments match any); the audit reports unmatched client calls and unmatched records, and `match` needs both zero. A loop in one command reads as unmatched (fails closed).
- Lower notes: a main missed because the model or canary was not ready gets its own reason (`NOT_READY`), no-reading and ablations after a missed main "main was missed"; `replicates_with_undefined_skill` is now per comparison; `run_session` closes its daemon in a `finally`.
- Benchmark cluster: SCORING.md links theses by session, catalyst_id or a shared market with intersecting intervals, so one Monday's five already share a session, and the four Mondays' 21-day intervals overlap on the same markets: the benchmark is one cluster by the spec's own rules whatever its catalyst_id. Left as is.
- SCORING.md: a missing anchor or D < 1 records p_ref null with m = x = 0; mark() before any bar has opened is outside the input contract (the entry bar exists).
- Suite (`ops/shards.py`): 1,977 of 1,977 reported, 1,957 passed, 1 skipped, 19 xfailed, 0 missing.

## Round ten (2026-11-09 07:25 UTC (02:25 EST)), N1-N5 of the Opus round-nine review (audit/reviews/2026-11-09-opus-thesis-refreeze-round9.md)

Tests: `thesis/tests/test_refreeze_round10.py`, run first against `f4db799` (11 of 15 fail there; the other four guard the fail-closed cases). The round-nine tests that expected a single failure to be final now run at the give-up time; fakes gained `universe`, `dexes`, `observe`.
- N1: `Track.snapshot` is one acquisition pass over a draft kept in memory for the cutoff (`self.draft`): the first pass reads everything, each later pass only what failed (a market's reads or readiness check, a builder dex's listing). It returns None, and `acquire` attests nothing, while a failure is present and the time is before `RETRY_UNTIL` (4 h 45 min, 04:45 UTC (23:45 EST the day before)); after it the failures are recorded and the snapshot attested. The same on Mondays. The core venue's listing read raises as before. `readiness_at` is the latest readiness check's time (a later start only narrows what a registration fetches).
- N5: `Market` splits `listings` into `universe`, `dexes`, `observe` (a discovery is observed only when every dex was read). A failing dex is recorded in `failed` as `<dex>:*`; `unbenchmarkable` reads that key for every market of the dex.
- N4: `failed` is in the `snapshot_ready` record, hence in the C10.6 report's `snapshots`.
- N2/N3: `harness.client_refusal` decides from the result alone: the call is the sole client call of its Bash command, is_error, "Exit code N" with N nonzero, and the whole output the usage line or one `{"ok": false, "error": text}`. The arity reasoning (`refused_locally`) is deleted; everything else maps one-to-one. The review's reproductions n1, n2 and n3 (b)-(d) now pass or fail closed; n3 (a) built its transcript without the `Exit code` line and now fails closed.
- Paper T3: the 04:45 UTC (23:45 EST) choice with its reason; the attestation fields include failed reads. PDF rebuilt. `PROGRESS.md` on main: the freeze runs on an image of the head frozen.
- Suite (`ops/shards.py`): 1,992 of 1,992 reported, 1,971 passed, 1 skipped, 19 xfailed, 1 failed (`gate/tests/test_compute.py::test_pool_does_not_copy_a_live_threads_lock`, a pool timeout under the shared load; untouched code, passes alone), 0 missing.
- The readiness-only note: a market whose readiness check fails is not ready and in `failed`, but stays in `markets` and `daily` (its reads succeeded); the benchmark checks `failed` first. Stated, unchanged.
