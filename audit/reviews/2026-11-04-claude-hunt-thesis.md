# Bug hunt: the thesis track, the recorders and the mirror (Claude, fresh session)

2026-11-04 05:07 UTC (2026-11-04 00:07 EST). Branch `claude/thesis-recorders-bug-hunt-3egky7`, from `f591e3b`.

This is the fresh hunt CLAUDE.md requires before a thesis refreeze. The failure it guards against is in `audit/reviews/2026-11-02-gpt-hunt-*.md`. Scope: `thesis/` (runner, registry, daemon, market, positions, scoring against `thesis/SCORING.md`); the live recorders (`ingest/live.py`, `record.py`, `datalayer.py`, `sources_record.py`, `hl.py`); and `ops/live.py`'s mirror and verify. I judged them against `thesis/SCORING.md`, `CLUSTER.md`, stage 10 in `audit/criteria.md` (with its readings of 2026-11-02) and paper §5.

Static reading, plus synthetic tests. I accessed no recording, cluster, credential or `data/` file. Two defects already wait for the next refreeze, so I don't report them again: the recorder's torn UTF-8 record, and `as_managed_mean` dropping a partly entered spread. Each finding below has a failing test marked `xfail(strict=True)`, whose reason names this review and the finding number. I ran each test with `--runxfail` under `nix develop -c pytest` to confirm it fails at its own assertion; the failures are quoted below. The run of the three touched suites (`thesis/tests/test_market.py`, `thesis/tests/test_daemon.py`, `ops/test_live.py`) gave 162 passed and 5 xfailed.

**Frozen identities.** I changed only test files and this review. None of them is in the thesis manifest (`thesis/harness.py::manifest_files`: modules loaded by `thesis.runner` and `thesis.report`, plus the kernel, briefs and data files), the stage 3 harness or the kernel.
- Fixing findings 2, 3 or 4 changes `thesis/market.py` or `thesis/daemon.py`, so it waits for the next refreeze.
- Fixing finding 1 belongs in `ops/live.py`, which no frozen identity hashes, unless the fix changes the briefs instead.

## 1. A note an agent writes in its workspace can stop the mirror for good (medium-high)

**Path.**
- `ops/live.py:245–247` treats every `*.jsonl` file as an append-only day file, and `:255–259` treats every `*.sqlite` file as a ledger.
- `:263–264` refuses a day file that changed below its mirrored length.
- `:238` loops over `VOLUMES`, so any refusal or exception ends the whole run.
- Session workspaces sit inside mirrored volumes: `thesis/runner.py:142` puts them at `data/thesis/sessions/<version>/<session>/work`, `sandbox/session.py:108` binds that directory read-write as `/work`, and `gate/agent/campaigns.py:145,509` puts the series' workspaces under `data/agent`.
- `thesis/brief.md:59–60` and `thesis/brief-noread.md:51–52` tell the agent to "Write whatever notes you like in this directory. They are discarded after the session." Nothing discards them: `sandbox/session.py:145–146` removes only `home` and `tool`.

**Trigger.** During a session, an agent writes a note named `*.jsonl` (for example, a list of candidate theses). A mirror run copies it. The agent then rewrites the note with the Write tool, which replaces the whole file. A note named `*.sqlite` that isn't a SQLite database fails on its very first mirror run, with `sqlite3.DatabaseError`.

**Wrong result.**
- Every later mirror run refuses the thesis volume, because the old manifest still lists the note's prefix. The run then stops before the `agent` volume.
- Nothing repairs this, since workspaces are never cleaned up.
- A series agent's note stops only the `agent` volume, which comes last in the loop.
- CLUSTER §5's refusals are meant to catch a damaged recording. Here one fires on a file no recorder wrote. The run is meant to fail loudly, but its cause is a note.
- `ops/test_live.py::test_malformed_datalayer_lines_do_not_block_later_volumes` already states the intent that one volume's content should not block the volumes after it.

**Outcome it could change.**
- After that point, the thesis ledger, the thesis track's market and exchange archives and the agent series' logs and ledgers have no second copy. The mirror is their only copy (CLUSTER §1, §5).
- prodesk7's volumes are local-path and not backed up. A disk loss would then lose the thesis's evidence (C10.5, C10.6) and stage 4's records.

**Likelihood.** It depends on what an agent chooses to call its notes. The brief invites notes, about three thesis sessions run a day, and the swarm runs many agent sessions per campaign. Sessions last up to an hour and the mirror runs every 10 minutes, so a run between two writes is likely.

**Reproduction.** `ops/test_live.py::test_a_note_an_agent_rewrites_in_its_workspace_never_stops_the_mirror[notes.jsonl|notes.sqlite]`:
- jsonl: `SystemExit: thesis/sessions/thesis-0/main-0/work/notes.jsonl changed below its mirrored length 17`.
- sqlite: `sqlite3.DatabaseError: file is not a database` at `ops/live.py:257`.
- In both cases the `agent` volume's `swarm-null-3.jsonl` is never mirrored.

## 2. One builder dex's failed request costs every later dex its hourly mark (medium)

**Path.** `thesis/market.py:160–167`. `record_marks` loops over `perpDexs` and calls `self.x.post(metaAndAssetCtxs)` for each dex. The archive append comes after the call, and nothing catches an exception.

**Trigger.** One dex's request fails. That can be a 4xx, which `ingest/hl.py:51` raises at once, or five failed retries over about 31 s (`hl.py:39–50`). The `marks` loop logs the exception and waits for the next hour (`thesis/runner.py:303–304,338–344`).

**Wrong result.**
- No sample is sent that hour for any dex after the failing one. A dex that fails every hour (one `perpDexs` lists but `metaAndAssetCtxs` refuses) costs the later dexes every reference.
- The failed attempt isn't archived either. The criteria require "Every attempt is archived append-only with its dex, send time, complete-receipt time and the response" (stage 10, revision of 2026-10-23, Sampling).

**Outcome it could change.**
- M_m(H) goes missing for every market of the later dexes, and a sealed reference never changes. Those markets lose their hourly bars for that hour.
- Entries, horizon and discretionary exits move to the next reference, and funding marks fall back to earlier references. A thesis's as-registered R_net and o can change, or the thesis can become unresolved (e ≥ x).
- Managed returns, equity and later sizes change.
- `markets` drops those markets from the snapshot when their latest close is missing.
- This is the same pattern as the 2026-11-02 recorder hunt's finding 5, here in the thesis's own sampler.

**Reproduction.** `thesis/tests/test_market.py::test_one_dex_failing_never_costs_another_dex_its_sample` sets `perpDexs` to `[None, bad, xyz]`, and `bad` raises. The test fails with `assert [] == [(5000, 5000, 2400.5)]`: xyz has no sample.

## 3. The hourly mark sample waits behind every other venue read (medium)

**Path.**
- `thesis/runner.py:66`: one `Exchange`, which `thesis/market.py:82–97` defines, serves every venue read: snapshots, registrations, replays, resolutions, benchmarks and the mark samples.
- `ingest/hl.py:26–34`: its limiter allows `BUDGET_PER_MIN = 120` weight over any 60 s. A request waits, holding the limiter's lock, until the budget has room.
- `thesis/market.py:164–167`: `sent = now_ms()` is taken before `post`, so it records the time before that wait, not when the request went out.

**Trigger.** Other reads have spent the minute's budget when the marks loop wakes at H + 5 s. Each request costs 20, plus 1 per 60 candles or 20 funding rows. Some sizes:
- First-time funding for a market (3 years and 30 days) is about 54 pages of 500 rows at 45 weight each, about 2,400 weight. That is about 20 minutes of the whole budget, and a registration on a market not yet cached makes that read.
- The daily snapshot reads every listed market's daily bars, and every core market's hourly bars, once its repair interval has passed. At roughly 1–2 requests per market over a few hundred markets, that is thousands of weight, so tens of minutes at 120/min.
- The marks loop itself needs (1 + number of builder dexes) × 20.

**Wrong result.**
- The sample isn't "sent at H + 5 s" (stage 10, revision of 2026-10-23, Sampling).
- When the wait passes H + 5 min, the sample is received after the seal, and M_m(H) is missing for every builder market at once.
- The archived `sent` understates the send time by the wait. Selection still holds, because a sample received by the seal was also sent inside the window, but the archive does not say when the request went out.

**Outcome it could change.** The same as finding 2, for all builder markets in an hour whose sample is starved. A registration on a new market during a session, or a slow snapshot overlapping an hour boundary, is enough.

**Likelihood.** Plausible on any day a session registers a market not yet cached or a snapshot runs past an hour boundary. I can't measure it without the recordings: the archived `recv` minus H would show it (integrity only, no prices).

**Reproduction.** `thesis/tests/test_market.py::test_the_mark_sample_is_sent_at_its_time_whatever_other_reads_spent` uses a fake clock, with the minute's budget spent just before H + 5 s. The first request goes out at H + 65 s: `assert 3665000 <= ((3600000 + 5000) + 1000)`. Its second assertion (`sent` equals the post time) also fails on the current code.

## 4. Registration reads the venue before it checks the request's form (low-medium)

**Path.** `thesis/daemon.py:250–255`. `register` calls `self.register_inputs(account, markets_of(request), now)` before `registry.register` runs `validate`. Through `thesis/runner.py:90–95` that call reads the 1h bars and funding of every market the request names, and of every market the account holds. Readings rule 10 says: "A request's form is checked before the venue is read." `f4afe25` moved the listing read behind validation inside `registry.register`, but the daemon's input read still comes first.

**Trigger.** An agent submits a request that fails `validate`, for example with p outside [0.01, 0.99], three legs, or a mistyped market name.

**Wrong result.**
- The venue is read for every requested market anyway. For a market never read before, that is the full funding history (finding 3's 2,400 weight).
- For a name the venue doesn't know, the read raises after `Info.post`'s retries (about 31 s on 5xx). The agent then receives `daemon error: HTTPStatusError` instead of the form's errors.

**Outcome it could change.**
- It spends the shared budget, which can starve finding 3's mark sample.
- It delays the session's daemon.
- An agent told "daemon error" instead of what was wrong may abandon a thesis it would have fixed, which counts against C10.5's 20 accepted main theses.

**Reproduction.** `thesis/tests/test_daemon.py::test_a_malformed_request_is_refused_before_any_market_is_read` sends p = 5 with three legs. `register_inputs` is called with `['X', 'Y', 'Z']`, failing on `reads == []`.

## Considered, not reported as defects

- **The positions command.** The no-reading agent's `positions` (`thesis/runner.py:132`) replays at the call's time, not at the snapshot's. An exit of one of its own earlier theses between the snapshot and the call shows that exit's reference price. "It sees the same market and price snapshot" governs snapshots, and `positions` is a listed command that reports only the account's own fills, so this is a question for the advisor, not a defect.
- **Session start time.** A day's snapshot that runs long under the 120/min budget delays the main session past 00:10 UTC (19:10 EST the day before). The criteria make sessions start "at 00:10 UTC" (19:10 EST) but count only missed sessions. Not judged here.
- **The forward window.** The mirror copies forward-window Hyperliquid day files to this PC (`/srv/moneymachine/mirror/hl`), unlike the Oracle pull, which excludes them. No code reads `mirror/hl` into research today (I searched for consumers). CLUSTER §5's "staged into batch inputs by hash as today" would need the same exclusion before anything reads it.
- **Base rates.** `thesis/scoring.py`'s outcome, base rate, Brier, pairing, clusters and bootstrap match SCORING.md as written. The anchor comes from the snapshot's completed daily bars, consistent with "Daily closes are never null".
- **Positions.** `thesis/positions.py`'s replay matches readings 1 to 8, apart from the known partly entered spread.
- **Recorders.** `ingest/record.py`, `datalayer.py` and `sources_record.py` raise nothing new beyond the 2026-11-02 recorder hunt's findings.
