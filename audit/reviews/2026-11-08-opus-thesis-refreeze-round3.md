# Fresh-Claude review of the thesis refreeze, round three, and the pre-refreeze bug hunt (Opus)

Claude Opus 5.5, fresh session, finished 2026-11-08 05:45 UTC (00:45 EST); worktree `mm-rv-rf` detached at `e0a69a8`, no `data/`; no holdout, embargo or forward-window prices or returns read; the cluster untouched. Read: the round-two review, GPT's round-three dispositions, `git log 228cf5a..HEAD`, paper T3, `thesis/{market,registry,runner,daemon,positions,harness}.py`, `sandbox/{canary,session,server}.py`, `ingest/{hl,live,record}.py`, and GPT's funding-fill design review (only to avoid restating it). Reproductions beside this file: `repro_snapshot_capacity.py.txt`, `repro_market_oldapi.py.txt`, `failfirst.sh.txt` (renamed from `.py`/`.sh` so the repository's code checks don't read them as code) (run with `PYTHONPATH=<worktree> nix develop -c pytest -s`).

**Verdict: not ready to refreeze, even after finding 2's prewarming lands.** Round three fixes findings 1 and 3–9 at their causes, each with a test failing on the code before its fix (finding 9 except one sentence), and adds no correctness defect. But the page reservations it keeps (103 per candle request, 45 per funding request, against 120/min) make the everyday warm workload infeasible too (finding A, reproduced); prewarming doesn't touch it.

## Round-two findings

Fail-first: each fix commit's non-test sources reverted to the parent, its new tests run; every new test failed on the reverted tree and passed as committed (finding 7 caveat below).

| # | Status | Evidence |
|---|---|---|
| 1 Hot journal | Fixed (`ac31ca2`) | The live read opens read-write. The test SIGKILLs a writer that has spilled; on the parent it fails with "attempt to write a readonly database". The kernel writer's 60 s busy timeout keeps the reader from starving it. |
| 2 Allowance / terms | Commitment restored; capacity blocked, as recorded (`5a9b6f3`) | Allowance 600 − `RECORDER_WEIGHT_PER_MIN` (480) = 120, and `ops/live.py` reads the same constant; three tests fail on the parent, where the strict xfail passes unexpectedly at 720. The recorded blocker covers only cold registrations; finding A widens it. |
| 3 Shared client re-rated | Fixed (`8b2007f`, `b09073d`) | `Info` charges 20 before the request and returned items after; the page reservation lives only in `Exchange.post`; the thesis-only malformed-response retry moved into `Exchange._send` (`RemoteProtocolError`). Four tests fail on the parents. The recorder's path is otherwise as deployed (one thread per `Info`). |
| 4 Marks parsed in full | Fixed (`9b6871b`) | `MarkIndex` keeps byte offsets of complete lines per file; on the parent the test sees 20 decodes where 2 suffice. Incomplete lines wait for the next read; a torn line is skipped once; order matches the old `read()`. |
| 5 Killed canary reads Broken | Fixed (`576383b`, `3a0d398`) | The kill and `~` cases fail on the parent. No false pass: without a final result a denial probe returns None (Unavailable, nonzero exit); an observed forbidden success or the `x` effect still raises Broken. |
| 6 More than 35 dexes | Fixed; limitation recorded (`a364804`) | Cohorts of 5 within the quota, alarm instead of abort; the parent also never released the history reservation on a failed discovery, fixed too. |
| 7 `due` from the wall clock | Fixed (`e6bc37b`) | On the parent both tests fail with a `TypeError` from the signature change; against the old no-argument API the market test fails on behaviour (sends in the previous hour): `repro_market_oldapi.py`. |
| 8 Retry margin | Fixed (`d4c6d6b`) | Admission checked after the backoff sleep; T3 says so; the test fails on the parent. |
| 9 Stale text | Mostly fixed (`22c8b6a`) | Left: `ingest/record.py:7-8`, "The recorder spends the client's whole budget, so nothing else may query the venue while it runs", false under co-egress. |

## New findings

### A. High: everyday thesis reads can't fit 120/min with page-ceiling reservations; the daily snapshot takes hours

- **Where:** `thesis/market.py:126-127` reserves 20 + ⌊5000/60⌋ = 103 per candle request and 45 per funding request whatever range is asked, so one candle request per rolling minute. `thesis/runner.py:110-121`: the daily snapshot reads every listed market's daily bars and every core market's hourly bars; the repair interval forces at least one request per market. `thesis/runner.py:93`: every registration, `positions` and `exit` replays every market the account ever held, closed ones included.
- **Reproduced** (`repro_snapshot_capacity.py`, real `Track.snapshot` and `Track.data` over caches warm to the last increment, fake clock): 186 core + 166 builder markets (inventory estimates, unverified) take 583 min (95 min charging base weight only, the deployed client's cost for these increments); 30 + 10 markets, 75 min; a registration read over 10 held markets 19 min, over 40 held markets 84 min, past the session's 1 h wall.
- **Scenario:** `day()` (`runner.py:194`) takes the snapshot after `ready()`, so the main session starts about 10 h after 00:10 with hours-stale prices and an hours-old canary. On Mondays the benchmark registers hours after 00:00, moving its entry hour. As the main account accumulates markets, one registration read outlasts the session wall: the daemon holds its lock, the CLI is killed, and the thesis commits after the agent can no longer see it.
- **Outcomes:** the frozen schedule (sessions daily at 00:10 UTC, 19:10 EST); what agents see and register; the benchmark's entries and outcomes; missed sessions after a late start; resolution reads competing in the same budget against C10.5's 90-minute grace.
- **Why prewarming doesn't cover it:** warm increments, a cost per request; the recorded blocker and strict xfail cover cold registrations only.
- **Direction (hypothesis):** bound each reservation by the most items the request can return, ⌈(end − start)/interval⌉ + 1, capped at the page ceiling, keeping "no later debt" and bringing short increments to about 20. Even then about 95 min at the estimated inventory, so the snapshot's scope or schedule needs a T3 derivation (cost per market × listing count from discovery), recorded in the blocker.

### B. Low: lexical cohorts spend the H+5 s cohort on dexes whose markets are all delisted

`thesis/market.py:342`. Per the research lead (unverified), 10 registered dexes, 6 fully delisted; the first cohort is abcd, cash, flx, hyna, io, and xyz (the benchmark's markets, most builder volume) goes at about H+60 s every hour. Within the seal window, so no marks lost, but every builder reference becomes M(H+60 s) and the recorded criterion failure applies hourly. Direction: drop a dex with no listed market by a general rule, only if a delisted market's marks aren't needed for resolution.

### C. Low, pre-existing, latent: a second `Track` (thesis-report) can corrupt shared caches

`thesis/market.py:296-301`, `runner.py:389`. The report builds its own `Track` on the same root; locks are per process and both write the same `<kind>.tmp`. If one `os.replace`s while the other still writes the tmp, the cache becomes truncated JSON, every read raises, nothing rewrites it: every snapshot fails, every session missed, resolutions fall to missing data. Only if the report runs against the live root; no deployment found that does; no reproduction. Direction: a per-process tmp name, or the report reads a quiesced copy (which also removes its separate 120/min limiter).

### D. Refreeze procedure note, pre-existing

`schedule` and `benchmarks` start from `frozen // DAY * DAY` (`runner.py:315`, `:327`): a mid-day freeze runs that date's main session at once, off the 00:10 schedule; a Monday freeze runs that Monday's benchmark from the 00:00 snapshot. Freeze just before 00:10 UTC (19:10 EST), as the last freeze did at 00:02 UTC (19:02 EST).

No other defects found in round three: seal and selection; `MarkIndex` under torn and concurrent appends; the drain arithmetic (discovery at D−60 s plus 5 × 20 = 120 at D); `hourly_marks` deadline selection; release on every exit path; malformed 200s archived before retry; canary normalization; the ledger busy-timeout interplay.

## Suite

`ops/shards.py` could not run this tree (it predates the `--shard-report` conftest option; every shard exited 4). Full local `nix develop -c pytest -n auto` in a memory-capped scope: 1,282 passed, 3 failed, 2 skipped, 20 strict xfails (1,307 collected, 898 s). The 3 failures are the data-bound `LOCAL_ONLY` tests (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`, two in `reference/tests/test_lean_differential.py`) failing on missing `data/store` in a data-less worktree; GPT's run with the store linked reported 1,285 passed. `repro_snapshot_capacity.py` fails 4 of 6 on this branch (the 2 base-weight reference cases pass by design).
