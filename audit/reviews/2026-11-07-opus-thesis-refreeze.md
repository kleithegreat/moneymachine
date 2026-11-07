# Fresh-Claude review of the thesis refreeze, round two (Opus)

Claude Opus 5.5, fresh read-only session, the sole independent review of round two: Argon's re-review hit its weekly quota before producing output (`audit/decisions.md`, see the advisor's entry of this date), and GPT built the branch. Worktree `mm-agy-rf` detached at `9991e4f`, no `data/`; no holdout, embargo or forward-window prices or returns read. Read: CLAUDE.md, PROGRESS.md, both diffs, Argon's review, GPT's dispositions, appendix T3, and `ingest/hl.py`, `ingest/live.py`, `ingest/record.py`, `thesis/{market,registry,daemon,runner}.py`, `sandbox/{canary,session}.py`.

**Tests:** `thesis/tests/test_{market,registry,daemon}.py`, `sandbox/tests/test_canary.py`, `ingest/tests/test_{hl,recorder_spec}.py`: 251 passed, 1 skipped. Two scenario tests written by the reviewer fail on this branch, reproducing findings 1 and 5: `2026-11-07-opus-thesis-refreeze/repro_hot_ledger.py` and `repro_probe_canary.py` (run with `PYTHONPATH=<worktree>`).

**Verdict: not ready to refreeze.** Finding 1 is a regression with a reproduced failing test that can lock the whole track out of its own ledger. Finding 2 changes a documented source-limit commitment without a recorded decision and leaves zero headroom on an IP the live recorder shares. Finding 3 leaks a thesis-motivated change into the recorders' shared client. Findings 4–7 are in hashed code, so leaving any means another refreeze later.

## Findings

### 1. High — read-only ledger reads stall the whole track after a writer dies mid-commit
- **Where:** `thesis/registry.py:62` (`sqlite3.connect(...?mode=ro, uri=True)`), from Argon finding 8, `ee145b8`.
- **Defect:** the ledger uses SQLite's default rollback journal (`kernel/mm/src/ledger.rs:69`). If `mm` is killed or loses power mid-commit, a hot journal remains. A `mode=ro` connection cannot roll it back and raises `OperationalError: attempt to write a readonly database`; main's read-write open rolled it back and read normally.
- **Scenario:** pod eviction, OOM kill or power loss while `mm disclose` commits (a `call` record per agent call, so commits are frequent). On restart every loop reads the ledger first — `schedule→close_interrupted` (runner.py:158), `deadlines`, `resolve`, `unbenchmarked`, `committed()` — and all fail. Nothing runs `mm` again, so nothing clears the journal; the track is stuck until a human opens it read-write.
- **Reproduced:** `repro_hot_ledger.py` forks a writer, spills a transaction, SIGKILLs it, then reads `Ledger(...).records`: fails on this branch, passes on main.
- **Outcome:** sessions lost; C10.5's two-hour resolution deadlines missed, and `deadlines` cannot even record "missing data".
- **Fix direction:** the live reader must be able to recover the journal: open read-write as main did. Read-only access for mirrors or audits belongs in the tool that needs it (e.g. `immutable=1` on a quiesced copy). Add the killed-mid-commit case as a test.

### 2. Medium-High — 720 + 480 = 1,200/min uses the venue's hard per-IP limit with zero headroom and contradicts the source certificate
- **Where:** `thesis/market.py:34-35`; whitepaper T3 ("uses the real limit, not the earlier half-limit politeness choice"). `venue/sources.toml:13-16` unchanged.
- **Contradiction:** the certificate still says "Our processes share one IP and together stay at or below 600/min", and that `ingest/hl.py` charges item weight after each request (no longer true). Raising the shared IP to 1,200 changes the rate-limit commitment behind the terms reading: it needs the advisor's reviewed decision, logged, and the certificate updated in the same change.
- **"No other consumer" is already false:** `audit/cluster/handoff.md:28` shows the cluster's budget shared with this PC, so the PC (and prodesk5) share the egress IP; their `cli universe`/`rules`/`backfill` runs use `Info()` at 600/min. `thesis-report` (`runner.py:374-377`) builds a second `Track()` with its own 720/min limiter and no drain coordination. The live recorder still runs the old `hl.py`, which charges item weight after the response, so the venue can briefly see it above 480.
- **Scenario:** a builder runs `cli rules` on the desktop, or `thesis-report` runs, during the thesis's busy minute (cold backfill or the H+5 s wave): the IP exceeds 1,200 and gets 429s.
- **Outcome:** the live `hl` recorder's L2 and boundary polls are delayed or dropped (not refetchable); the hourly wave gets 429s with only bounded retries, so marks can be lost.
- **Fix direction:** derive the thesis allowance from what it needs (the initial wave of 20(1+d) for today's dex count, plus a backfill that fits the session), keep explicit headroom for named co-egress consumers, or make the number an explicit recorded terms decision. `COHOST_WEIGHT_PER_MIN = 480` duplicates `ops/live.py:47`'s `"480"`.

### 3. Medium — the shared `Info` change re-rates the recorders on their next image rebuild
- **Where:** `ingest/hl.py:59-60`, used by `ingest/record.py:47-51` and `ops/oci/cloud-init.yaml:22`.
- **Defect:** each paged call now reserves its ceiling before sending (45 for `fundingHistory`, 103 for `candleSnapshot`); the recorder's boundary polls actually use about 20 each. With 11 coins at the 360/min boundary budget, a 4h boundary needs 11·45 + 11·103 = 1,628 weight, about 4.5 minutes of first polls; main needs 440, already recorded as a deficit (`audit/decisions.md:546`).
- **Scenario:** the next recorder image built from main after this merges, or an OCI VM re-provision.
- **Outcome:** first polls at recorder boundaries land minutes late; latent now, certain on rebuild.
- **Fix direction:** keep reservation semantics in the thesis's limiter, or adopt them for the recorder deliberately with its own derivation and review.

### 4. Medium — the marks archive holds full payloads, and `Market.marks` parses all of it on every call
- **Where:** `thesis/market.py:193` (Sampler record carries `request`, `response`, `sha256`) and `:305-309` (`marks()` parses every row of every day file). Called per listed builder market with ≥90 daily bars in each snapshot (`runner.py:117-122`), and in every replay and resolve pass.
- **Estimate:** a 40-asset dex row ≈ 15.7 KB vs 0.7 KB legacy (~22×). 10 dexes × 30 days ≈ 113 MB ≈ 2.5 s per `marks()` call; ~7 s by the window's end (~85 days). A snapshot over a few hundred builder markets takes tens of minutes.
- **Outcome:** session start drifts from 00:10; replay and resolve slow down. No data loss.
- **Fix direction:** the criteria require archiving the response, not re-parsing it: index derived marks separately (same record id/sha), or parse incrementally.

### 5. Low-Medium — canary: a killed session is reported as "SANDBOX CONTRACT BROKEN"
- **Where:** `sandbox/canary.py:79-84` with `session.py:167-168`. Denials come only from the final `result` record; `session.run` kills the CLI at turn or wall limits, so that record is never written.
- **Defect:** round two moved the violation scan ahead of the exit-status check; with no `result`, `denied` is empty and every correctly denied step counts as unpermitted, raising `Broken`.
- **Reproduced:** `repro_probe_canary.py`: all seven steps correct, no result record, `exit=-9` → `Broken: ['w3','w4','r1','b2']`; main raised `Unavailable`.
- **Outcome:** false breach alarm; aborted `thesis-freeze`/`freeze-harness`. Scheduling unaffected (`passes()` retries both). The cost is the alarm's credibility or a human halting the track.
- **Fix direction:** with no result record, judge violations only from observed allowed outcomes (`ok`, or effects); missing denial evidence is inconclusive.
- No false pass found: every call and effect is checked, `..` normalized, compound Bash caught. Gap: a `~`-prefixed `file_path` is joined under `/work` rather than expanded as the CLI does; matters only if the model departs from the literal brief.

### 6. Low-Medium — more than 35 dexes stops all sampling instead of degrading
- **Where:** `thesis/market.py:279-280`, raising before any send.
- **Scenario:** the venue lists a 36th HIP-3 dex during the window.
- **Outcome:** from that hour every builder market loses every mark, including the benchmark's `xyz:XYZ100`, `xyz:GOLD`, `flx:OIL`; theses go unresolved (C10.5's resolved count); only a log line signals it; history is blocked from D to D+295 s each hour because `release` is never reached.
- **Fix direction:** record that "every dex at H+5 s" can't hold past the limit as a Blocker with an alarm, and still sample what fits.

### 7. Low — `due` computed from the wall clock when `record_marks` is called
- **Where:** `thesis/market.py:264`, `runner.py:304`.
- **Defect:** a call starting even 1 ms before D−60 s (e.g. after a backward clock step) resolves `due` to the previous hour; samples go out at once outside any seal window, hour H is lost, history blocked ~5 minutes. Main sampled at "now ≥ H+5 s" and was robust.
- **Fix direction:** pass `due` from the scheduler.

### 8. Low — T3's retry-margin claim does not match the code
- T3: "a retry wave is not started unless a full 60 s quota wait plus the 10 s timeout fits before H+300 s"; the check at `market.py:296` runs before the backoff sleep (up to 16 s). httpx's `timeout=10` is per phase, not per request.
- **Outcome:** late retries are not seal candidates, so only weight is wasted. Make the paper match the code, or include the sleep in the check.

### 9. Low — stale text
- `ingest/hl.py:1` ("held under half the documented rate limit"); `ingest/record.py:118-119` ("so the thesis track's 120 fits under half the documented limit"); `venue/sources.toml:13-16` (finding 2).

## Argon's findings: fixed at the cause?

| # | Status |
|---|---|
| 1 Impossible charge / full page | Fixed: weight reserved before sending; `charge` rejects over-budget weight; `test_an_impossible_charge…`, `test_a_full_cold_hourly_page…`. The reservation change reaches the recorders (finding 3). |
| 2 Canary breaches | Fixed, no false pass found; introduced a false `Broken` on killed sessions (finding 5). |
| 3 Branch base | Void, confirmed: main `3546781` is an ancestor; no deleted lines in `decisions.md`. |
| 4 429/5xx poisoning the seal | Fixed at its cause: `marks()` admits only status-200 rows that parsed valid; legacy rows default valid, correct for the deployed format. |
| 5 60/60 split | Fixed (one shared limiter, drain, concurrent waves); the 720 premise is finding 2. |
| 6 Malformed 200s | Fixed: one parser validates for archiving and retrying; every attempt archived first. |
| 7 Preflight | Fixed: `prerequisites` is safe at `now` (snapshot daily bars can't change within a session, `t_r ≥ now`); upper horizon and listing stay commit-time checks. |
| 8 Read-only open | Regressed (finding 1): always-read-only breaks hot-journal recovery. |
| Positions `0.1` | Sound; the differential agrees. |

## T3 against the code
Match: 1,200 − 480 = 720; reservations 20 + 500/20 = 45 and 20 + ⌊5,000/60⌋ = 103; 4,800 candles → weight 100; 1,125 days → 27,000 rows → 55 pages × 45 = 2,475, 4,950 for two legs (~6.9 min at 720); d ≤ 35; 60 s drain; six attempts with sleeps 1–16 s. Mismatch: the retry margin (finding 8). The 720 premise: finding 2.

## Manifest and frozen identities
- The thesis manifest hashes every loaded repo module, so `hl.py`, `live.py`, `market.py`, `registry.py`, `daemon.py`, `runner.py`, `positions.py`, `canary.py` all fork it, as intended.
- The stage 3 harness hash is unaffected: `canary.py` is not in `session.FILES`; `sandbox/session|server|client|egress` and `gate/agent` unchanged.
- Not covered by the new identity, so the refreeze must account for them: `data/thesis/market/` (marks archive and caches) shared across versions (new code reads legacy rows; `dexes.json` absent on first start); `ingest/hl.py` and `ingest/live.py` shared with the recorders (finding 3); the co-egress budget assumption outside the hash, in `ops/live.py`, CLUSTER.md and other consumers on the IP (finding 2).
