# Bug hunt: the thesis track before its refreeze (Opus, fresh session)

- **Hunter:** Claude Opus 5.5, a fresh session with no part in rounds four to eight.
- **When:** 2026-11-09 05:57 to 06:20 UTC (2026-11-09 00:57 to 01:20 EST).
- **Commit hunted:** `cb21d7c` (`thesis-refreeze`'s head when the hunt began). Since then `d7448d2` changed only `thesis/SCORING.md`'s prose and the paper, nothing below.
- **Scope:** everything `thesis.runner` and `thesis.report` load. That is the registry, positions, scoring, market and acquisition, ledger writes through the kernel, daemon, sandbox session and client, and report. Each was read against `thesis/SCORING.md`, stage 10 of `audit/criteria.md` (with the readings of 2026-11-02 and the revision of 2026-11-09 02:31 UTC (2026-11-08 21:31 EST)) and paper appendices T1 to T3.
- **Method:** reading, then a synthetic reproduction for each finding, run under `nix develop` with `TMPDIR=/tmp`. They are in `2026-11-09-opus-hunt-thesis/` as `.py.txt` and are run from the worktree root. No `data/`, recording, cluster or venue endpoint was read. Nothing in the repository was edited.
- **Sharded suite** (`ops/shards.py` on the hunt worktree): 1,964 tests collected; 1,940 passed, 2 skipped, 19 xfailed and 3 failed. The three failures are `LOCAL_ONLY` tests that need `data/store` (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`, `reference/tests/test_differential.py::test_an_interrupted_run_resumes_where_it_stopped` and `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`), and the hunt worktree has no `data/` by design. Every thesis test passed.

Every fix below touches a file the manifest hashes, so it belongs to this refreeze or a later one.

## Findings, ranked

### 1. One market's persistent failure costs a whole date, or a whole Monday batch (medium)

**Path.**
- `thesis/runner.py:147-158`: `snapshot` reads every listed market's daily and hourly bars, and readiness, in one loop with no per-market isolation.
- `:192-195`: `acquire` catches only `TimeoutError`.
- `:501-507`: `forever` logs the exception and repeats the whole acquisition a minute later.
- `:313-327`: `benchmark` loops over the five markets the same way.

**Failure.**
- If one listed market's read raises on every attempt, no snapshot is ever attested for the date, so main and no-reading are missed. The market need not be eligible or a benchmark market. A read raises on every attempt for a 4xx, for `Info.post` retries exhausted on each pass, or for a cache file that no longer parses (finding 3).
- On a Monday, all five benchmark markets are then skipped "no attested snapshot".
- If the first benchmark market's input read keeps failing, the four after it are never tried. After `BENCHMARK_GIVE_UP` all five are logged "run missed". That includes flx:OIL, which would otherwise have been skipped for a property of the market.

**Outcome changed.**
- Missed main sessions count against C10.5's 20 accepted theses (the revision tolerates 13 misses at r = 1.4).
- A single Monday lost this way fails C10.5 outright. The revision of 2026-11-09 requires exactly four executed batches, and a batch with any operational skip is not executed.

**Likelihood.** No trigger has been observed: transient errors are retried and heal. The blast radius is about 350 independent reads for each date's snapshot, plus each market of each batch.

**Reproductions.**
- `r3_one_market_aborts_snapshot.py.txt` adds one listed, never-eligible market whose candle read raises 500. Output: "acquisition passes that raised: 19 of 19; attestations: 0", main and noread missed "no attested snapshot before the completion deadline", and all five benchmark markets skipped "no attested snapshot".
- `r3b_one_market_blocks_the_batch.py.txt` makes BTC's funding read time out. Output: registered `[]`, and all five markets skipped "run missed".

### 2. A response file rewritten in place can destroy bytes an earlier call record cites (medium-low)

**Path.** `thesis/daemon.py:132-138` writes `responses/<sha256>.json` with `Path.write_bytes` and no existence check. That call truncates the file, then writes.

**Failure.**
- Identical responses recur every day. Main's and no-reading's `markets` share one snapshot and `taken`, so their bytes match, and so do common errors and empty `positions`.
- A later session therefore rewrites a file that an earlier call record already cites. A SIGKILL (pod eviction, node loss, OOM) or an `ENOSPC` during that rewrite leaves the file truncated.
- With `ENOSPC` the new call record is never written, but the old one still cites bytes that are gone.

**Outcome changed.**
- C10.5: "every disclosure to its response bytes".
- Criteria, Disclosure log: "Those bytes are retained".
- A recording is lost, and it cannot be refetched.

**Reproduction.** `r1_response_rewrite.py.txt` simulates the kill point inside `write_bytes`, after one third of the body. Output: "main's disclosed response intact: 142023 bytes", then "after SIGKILL during the no-reading session's identical write: 47341 bytes", and "main's call record still says 97cccdd3d29b0797; the file now hashes to 98b32c46d9b53aca".

### 3. Two processes on one thesis root lose each other's cache commits (medium-low)

**Path.**
- `thesis/market.py:475-484` (`_funding_commit`), `:391-396` (`_cached`) and `thesis/runner.py:169-172` all write through one fixed `.tmp` name per file, then `os.replace`.
- Only in-process locks guard them.
- `prewarm` takes `run.lock` (`runner.py:554-555`), but `report` (`:568-571`) and `freeze` (`:525`) do not. `report` builds its own `Track` and replays through the venue.

**Trigger.** `thesis-report` run against the live root while the runner runs. C10.6 and "the track keeps running after exit" make that the expected way to produce the report.

**Failure.**
- In two 20-second runs, two processes committing one funding file collided on the shared temporary name: 3 and then 11 commits raised `FileNotFoundError`.
- The second run also added a reader: 5 of its reads saw unparsable JSON.
- Of 925 returned commits, only 471 acquired ranges survived on disk. Each process's load-merge-replace overwrote the other's.

**Outcome changed.**
- A failed or unparsable read fails that attempt's registration, resolution or snapshot.
- Lost acquired ranges lower `_acquired_to`. If the next snapshot's readiness map is computed before the fill repairs it, a market is not ready that day: registrations in it are refused, and a benchmark market is skipped "funding not ready at the snapshot", an operational skip (finding 1's outcome).
- The paper's T3 already lists a second report process as a shared-IP budget blocker. This is a separate hazard of the same cause.

**Reproduction.** `r4_two_processes_one_cache.py.txt`. Output: "commits attempted: 936 | raised in the writers: 11", "reads ... that failed to parse while both wrote: 5", "acquired ranges on disk: 471 of 925 commits that returned".

### 4. C10.2's per-session check counts calls the client refused itself (low-medium)

**Path.**
- `sandbox/client.py:23-34` answers a wrong arity (usage, exit 2) or an unreadable `register FILE` (exit 1) without contacting the daemon.
- `sandbox/session.py:172-179` counts every `./thesis-agent` in a Bash command that ran.
- `thesis/harness.py:63-67` compares that count to the daemon's records.

**Failure.**
- An honest session with one mistyped call reads `match: False`.
- Because the check compares counts and maps nothing, a session that has one locally refused call and one daemon record without a transcript call reads `match: True`.

**Outcome changed.** C10.2 ("every transcript client call maps to exactly one daemon call record"): a false failure, and a construction that passes while the claim is false.

**Reproduction.** `r2_usage_mismatch.py.txt`. `['prices'] -> 2 usage: ...` and `['register', 'missing.json'] -> 1 {"ok": false, ...}`, neither reaching a socket. Then `audit: {'client_calls': 2, 'daemon_calls': 1, 'match': False, ...}`.

### Lower-consequence notes (read, not reproduced)

- **Miss reasons.** `runner.py:271,286,304`: a session missed because the model or canary never became ready before the date's end is recorded "snapshot or readiness unavailable before the start deadline". So are no-reading and ablations missed after a missed main. C10.6 lists these reasons, and this one names neither the true cause nor the true deadline.
- **Undefined-skill count.** `scoring.py:140`: `replicates_with_undefined_skill` counts a replicate if either comparison's skill is undefined. For no-reading and benchmark, which have no ablation pairs, it is always 10,000, which hides the base-rate count.
- **One benchmark cluster.** Every benchmark thesis shares `catalyst_id` "benchmark", so the account is one cluster. That cluster resolves only when every member has, so the report never gives the benchmark intervals. The benchmark is descriptive, so nothing is judged on this.
- **Daemon not closed.** `harness.py:58-59` closes the daemon only if `session.run` returns. On an exception, the server thread and socket stay up until the process exits. Nothing is judged on this.

## Areas checked with nothing found

- **Positions** (`positions.py`): fills and cost cells; funding before exits before entries; invalidation timing and its lag; partly entered spreads; suppression and release of reservations; reconciliation stopping and E_r at a cutoff inside an hour's lag; sizing from the record.
- **Scoring** against SCORING.md: outcome, base rate, Brier, pairs and clusters.
- **Snapshots and sessions:** attestation and the miss decision under `self.attestation`, including the race in which an acquisition finishes at the deadline; crash recovery through `close_interrupted` and once-per-session settling.
- **Day-fixed readiness:** the funding-tail lower bound, and the contiguity of acquired ranges across registrations, resolutions and the fill.
- **The cache's rule-6 cutoffs:** pending rows, their expiry, and reads at past cutoffs.
- **Limiters and marks:** the FIFO limiter, hold and cancel; the drain minute and release of `MarkLimit`; mark cohorts, give-up and the strict seal; `MarkIndex` on torn lines and archives from older versions.
- **The Monday benchmark:** `known_at`, its last close, `listings_at` and its observation time, its `t_r` and `registered_at`, and the give-up.
- **Registration:** retries, commit order, eligibility at the commit, and form checked before any venue read.
- **Earlier hunts:** every finding of `2026-11-02-gpt-hunt-thesis.md` and every thesis finding of `2026-11-04-claude-hunt-thesis.md` is fixed in the code as read.
