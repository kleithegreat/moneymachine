# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/`.

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; clock record: the kernel's bound, `CLUSTER.md`), `datalayer` (`venue/sources/datalayer.json`).
  - The thesis track is parked: StatefulSet `thesis` at 0 replicas, Job `thesis-prewarm` suspended (2026-11-11).
  - The mirror CronJobs on `sha256:5e81095e…` (`cb23337`). `agent-series` finished C4.5 v3 (`mirror/agent/`).
  - prodesk7 builds test checks as a remote builder, inside `mmtest.slice` (`CLUSTER.md` §6).
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` (declared units) and the builder wake-ups run only while the human is logged in. Batch Jobs: none queued. `/tmp` is a 7.8 GB tmpfs that killed `nix develop` shells fill: set `CARGO_TARGET_DIR`/`TMPDIR` on disk for builds.
- **Accounts** (the human, 2026-11-11 and 12):
  - **Cornell and TAMU** are free for study 1 for about two weeks, to about 2026-11-25.
  - **Fable** runs one session at a time, on whichever account is logged in, never two at once.
  - **GPT's** one review is spent.
  - **Argon** runs through the web UI (the human) or `agy`.
- **Worktrees:** `main`; `../mm-program` (`rearchitecture`); `../mm-s1-build` (`study1-build`). Agents that edit at the same time get separate worktrees.

### Work in progress

Roles: Fable architects, Opus orchestrates, Sonnet builds; Argon (and GPT, when available) review Fable adversarially until they converge, with a plain summary for the human after each round (`CLAUDE.md`). Laws (properties for every input) come before code, written by another agent; the steps a judged number depends on get Lean proofs. New code is maximal Lean plus OCaml (the human, 2026-11-12).

1. **The program** (`audit/program/` on `rearchitecture`; revision 4 approved by the human 2026-11-11; `ledger.md` lists what is agreed and disputed). The project is academic: no live trading, no stage 11.
   - **Study 1, the positive control of search:** does the agent find a planted edge more often than G100? At most 100 markets, on Cornell and TAMU.
     - **Steps 1 to 6 are built** (`c46c786`; 212 tests).
     - **Converged and committed:** CS1.1 is in `audit/criteria.md` (`criteria: study 1`, `10fedc5`), with definitions at `rearchitecture` `ce7ff38`.
       - Each market has one session, never rerun; a session with no pick, or not answered by Opus 5.5 or 4.8, is the agent's miss.
       - The subject is the agent as served (H8, approved by the human).
       - Wall 5 is 14 of 200.
     - **Built** on `study1-build` (`a3fc471`): 310 tests pass, plus one slow test over the 600 s timeout.
     - **Calibration's cost is fixed** (`study1-build` `bb4ec62`): fresh pairs are written with only the columns the kernel reads, at 0.30 s a pair against 3.56 s, and nothing is kept between trials. 316 tests pass. The run is about 350 to 440 core-hours, 12 to 15 hours across this PC and the nodes. Step 5's host-spreading rules are written (`4844762`, behaviours 7 and 8, L5.6, plus a cross-host probe that numpy's results agree bit for bit). Owed: L5.6's remaining tests by a model other than the builder's, then the build. A one-host run can start now.
     - **Then:** calibration, G100 on the study markets, the first sessions (Cornell and TAMU).
   - **Study 2, the positive control of the confirmer:** the replication of vault `0x53375ca9…2a06` (FuturAI Labs; its fills read only before the forward window).
     - Fidelity first, then a frozen forward test (power 0.47 at Sharpe 1.4 and 0.90 at 2.4 within two years).
     - **Kernel version 2:** semantics and the Lean/OCaml split with its laws are written (`rearchitecture` `c1a4421`, `a829c07`, `audit/program/kernel-v2.md`). Tasks 2b to 5 done on TAMU in 24 minutes (`f54d3db` to `2a4cd2a`; report `data/builder/architect-kernel-v2-report-2.md`): all seven of Argon's findings conceded and re-derived; study 2's wealth measured in its own basket; an eleven-step build plan. Not yet reviewed.
     - Data: the archive for its 17 coins, 2026-04-03 to 10-31, is on disk (26 GB raw, 3,379 coin-day snapshot tables, all readable, about $2.46; `ingest/archive.py`).
   - **No reading-agent study:** the thesis track registered 0 theses in 6 sessions, against a threshold of 33 independent bets a week.
   - **The websocket recorder** (`recorder/RECORDER.md`): every perp on every Hyperliquid dex, crypto and builder-deployed stocks, commodities and indices. Built (`mmrec`, OCaml on Jane Street's stack), its tests written first by another session. **Running** since 2026-11-14 03:43 UTC (22:43 EST) as StatefulSet `ws` (image `5cbfbbd` since 06:12 UTC, 01:12 EST), one copy on prodesk7 (PVC `ws`, not mirrored, the human's choice): fast five-level books for all 350 perps, 20-level books for the main dex's 179, trades, asset contexts, listings. Hour 04 UTC: 161 MB (3.9 GB a day), and a handshake failure killed the process (restarted in 1 s). Fixed (`5cbfbbd`): failures stay in their connection; one zstd stream per run and hour (73 MB for that hour); `check` streams and sees a killed run's gaps. Hour 07 UTC measures the new rate. Known: `check` misses the 04:17 UTC (23:17 EST) crash's gaps (both runs share pre-fix files); `events` shows it.
2. **Erasure pass** (list `audit/erasure/2026-11-12-deletion-list.md`): phases A to E and F12 are done, `ops/shards.py` included.
   - Tests are 11 flake checks on the remote builders and `nix run .#test` (`CLUSTER.md` §6); the launcher is `nix run .#session`; the timers are `homeManagerModules.default`, imported by dotfiles.
   - Phase A: the thesis track and `ops/crossmachine.py` are gone, archived at `archive/thesis` and `archive/thesis-refreeze`.
   - **For the human:** delete StatefulSet `thesis` and Job `thesis-prewarm` in `moneymachine-live`, keeping the PVC, and remove the key `PERSONAL` from Secret `claude-token`.
   - **Next:** phase F's `agent-real` with study 1's criterion.
   - **Constraint:** `flake.lock` does not move while study 1 runs on the frozen harness.

### Next, in order

1. **After Fable's report:** Argon (or GPT) reviews kernel version 2's revision; the advisor summarizes for the human.
2. **Sonnet applies `audit/program/paper-changes.md`** (the paper, `docs/findings.md`, the stale files). It is checked against the erasure list for overlaps.
3. **Python and Rust leave `main`** as study 1 reports and kernel version 2 lands. The recorders move to OCaml in a side-by-side switchover. Stage 7 stays parked; stages 8 and 9 are superseded.

### Finished

- Stages 0–6 exited (stage 4 on 2026-11-08: `audit/stage4/exit.md`); recorder handoff done. Findings and audit links: `docs/whitepaper.tex`, §17; current qualifications below.

## Blockers

None blocks the program. Source certificates that fail, with their clauses, are in `venue/sources.toml` and `audit/decisions.md`: Kalshi, Polymarket and Polymarket US; FRED and ALFRED; IMF; and stage 8's candidates.

## Decisions awaiting the human's review

- From 2026-11-08, the human away (`audit/decisions.md`): stage 4's exit; the research reviews' actions; the cluster runner not adopted.
- **The advisor's study 1 build decisions** (`audit/decisions.md`, 2026-11-12): `measure.scores` over several programs; the random-pair encoding, pending Fable.
- **Fable's four new questions** (`data/builder/architect-kernel-v2-report-2.md`): may "earned" (`W`) ever be study 2's claim; leverage in the judged account if a certificate quotes the no-debt rule; `mm` stays as the pilot's instrument; run a forward test expected to end "not confirmed".

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **The agent's model (stages 3 and 4):** many sessions fell back from Opus 5.5 to Opus 4.8 after a "cyber" safeguard flag: 9 of 20 stage 3 null sessions, the real campaign's search session, and 31 of 40 in stage 4's swarm (`audit/decisions.md`, 2026-11-12). No judged number changes. Reports name the model that answered.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells; every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (the B = 1 bound is examined in stage 7). Its searchers state no mechanisms, so C2.2's power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed, so C0.7's, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B. C3.2 met only under v3 (0 of 20): v1 failed as written (20 of 20, crashes before any model call), v2 established no procedure (`audit/stage3/write-denied-2026-10-31.md`). The real campaign had zero finalists in both arms: C3.3 and C3.4 met under the zero-finalist revisions, the release path not exercised, the holdout unreleased.
- **Stage 4:** C4.5 v1 and v2 failed (strict xfails); v3 passes as written, N2-8 unresolved (A4's refused `Edit` fails `audit_holds`; calls equal ledger rows). A smoke test: no finalist, so the holdout and betting path never ran; the C4.5 qualifications stand. Pooled: 22 started, 21 known non-promotions (bound 0.133), v2's crashed N2-9 unknown (0.198 if counted); the series report reads only logs in `data/agent` and omits v2.
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (`criteria/test_stages3to5.py` enforces it); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run; L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after. `as_managed_mean` omits a spread with one leg entered, though the equity carries its P&L (strict xfail, audit/decisions.md, 2026-11-03); the thesis track is parked.
