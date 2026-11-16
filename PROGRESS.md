# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli -h`. Criteria checks are tests in `criteria/` over evidence in `audit/`.

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; clock record: the kernel's bound, `CLUSTER.md`), `datalayer` (`venue/sources/datalayer.json`).
  - The mirror CronJobs on `sha256:5e81095e…` (`cb23337`).
  - prodesk7 builds test checks as a remote builder, inside `mmtest.slice` (`CLUSTER.md` §6).
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` (declared units) and the builder wake-ups run only while the human is logged in. Batch Jobs: study 1's calibration (above). `/tmp` is a 7.8 GB tmpfs that killed `nix develop` shells fill: set `CARGO_TARGET_DIR`/`TMPDIR` on disk for builds.
- **Accounts** (the human, 2026-11-11 and 12):
  - **Cornell and TAMU** are free for study 1 for about two weeks, to about 2026-11-25.
  - **The architect** is a fresh Opus 5.5 session at maximum reasoning after Fable's last session, 2026-11-16 (`CLAUDE.md`).
  - **Argon** runs through the web UI (the human) or `agy`.
- **Worktrees:** `main`; `../mm-program` (`rearchitecture`); `../mm-s1-build` (`study1-build`); `../mm-k2` (`kernel2-build`). Agents that edit at the same time get separate worktrees.

### Work in progress

Roles: the architect designs, Opus orchestrates, Sonnet builds; GPT and Argon review the architect adversarially until they converge, with a plain summary for the human after each round (`CLAUDE.md`). Laws (properties for every input) come before code, written by another agent; the steps a judged number depends on get Lean proofs. New code is maximal Lean plus OCaml (the human, 2026-11-12).

1. **The program** (`audit/program/` on `rearchitecture`; revision 4 approved by the human 2026-11-11; `ledger.md` lists what is agreed and disputed). The project is academic: no live trading, no stage 11.
   - **Study 1, the positive control of search:** does the agent find a planted edge more often than G100? At most 100 markets, on Cornell and TAMU.
     - **Steps 1 to 6 are built** (`c46c786`; 212 tests).
     - **Converged and committed:** CS1.1 is in `audit/criteria.md` (`criteria: study 1`, `10fedc5`), with definitions at `rearchitecture` `ce7ff38`.
       - Each market has one session, never rerun; a session with no pick, or not answered by Opus 5.5 or 4.8, is the agent's miss.
       - The subject is the agent as served (H8, approved by the human).
       - Wall 5 is 14 of 200.
     - **Built** on `study1-build` (`a3fc471`): 310 tests pass, plus one slow test over the 600 s timeout.
     - **Calibration is running** as `cal-3` (`ops/jobs.py calibrate`, unit `mm-calibrate`, log `~/.cache/mm-calibration/cal-3.log`, image `sha256:1199aa3d…`, `study1-build` `f125937`), carried from `cal-2`'s 4,714 lines on kernel `e6df2244…`. Shares follow each host's rate measured under load (Fable `1530f21`): 263, 164 and 64 markets an hour on this PC, prodesk7 and gmktec, about 3.2 h a strength, 64 h at most. The PC stays on: the batch's inputs are NFS from it. Worktree test runs never share the main checkout's `kernel/target` (decisions, 2026-11-15).
     - **Then:** G100 on the study markets, the first sessions (Cornell and TAMU).
   - **Study 2, the positive control of the confirmer:** the replication of vault `0x53375ca9…2a06` (FuturAI Labs; its fills read only before the forward window).
     - Fidelity first, then a frozen forward test (power 0.47 at Sharpe 1.4 and 0.90 at 2.4 within two years). Criteria committed (`criteria: study 2`, `a324059`; CS2.1 revised `a903317`).
     - **Kernel version 2** (`audit/program/kernel-v2.md`, brief 3; branch `kernel2-build`, worktree `../mm-k2`): steps 0 to 3 built and proved (Lean laws with only the three standard axioms); layer 1 clean on all 5,806 vault fills under the venue's printed arithmetic. Step 4: below.
     - **Data:** the archive for its 17 coins, 2026-04-03 to 10-31 (26 GB, `ingest/archive.py`); funding history (`data/study2/funding-history/`); the vault's own fills and funding before 11-01 (`data/study2/vault/`); the trade prints (`node_fills_by_block`, V22; `data/hl-archive/fills_by_block/`), complete with a continuous block stream (decisions 2026-11-16 20:27 UTC, 15:27 EST). The C6.4 reference streams are stored under a hash (`data/stage6/c64-reference/`, decisions 2026-11-16).
     - **The vault collector** (`recorder/VAULT.md`, `mmvault`) runs hourly as CronJob `vault` (`CLUSTER.md`).
   - **No reading-agent study:** the thesis track registered 0 theses in 6 sessions, against a threshold of 33 independent bets a week.
   - **The websocket recorder** (`recorder/RECORDER.md`): every perp on every Hyperliquid dex, crypto and builder-deployed stocks, commodities and indices. Built (`mmrec`, OCaml on Jane Street's stack), its tests written first by another session. **Running** since 2026-11-14 03:43 UTC (22:43 EST) as StatefulSet `ws` (image `5cbfbbd` since 06:12 UTC, 01:12 EST), one copy on prodesk7 (PVC `ws`, not mirrored, the human's choice): fast five-level books for all 350 perps, 20-level books for the main dex's 179, trades, asset contexts, listings. Measured 2026-11-15 03:00 UTC (22:00 EST), sizes only: about 2.0 GB a day since the fix (fast books 70%); 385 GB free fills about April to May 2027; two years are 1.5 to 1.75 TB a copy. The 04:17 UTC (23:17 EST) crash's gaps show in `events`, not `check` (`audit/decisions.md`).
2. **Erasure pass** (list `audit/erasure/2026-11-12-deletion-list.md`): phases A to E and F12 are done, `ops/shards.py` included.
   - Tests are 11 flake checks on the remote builders and `nix run .#test` (`CLUSTER.md` §6); the launcher is `nix run .#session`; the timers are `homeManagerModules.default`, imported by dotfiles.
   - Phase A: the thesis track and `ops/crossmachine.py` are gone, archived at `archive/thesis` and `archive/thesis-refreeze`.
   - **Next:** phase F's `agent-real` with study 1's criterion.
   - **Constraint:** `flake.lock` does not move while study 1 runs on the frozen harness.

### Next, in order

1. **Kernel version 2, step 4** (`kernel2-step4-wip`, `../mm-k2`): built, L1a proved, B5 settled (D125 to D130, GPT converged); rates met on an isolated core (strings 8.7 s of 22, doubles 313 s of 470). Running: B4's full C6.4 comparison, six shards on prodesk5 (`/var/tmp/mm-b4/shard-*.log`, started 18:22 UTC, 13:22 EST). Then merge into `kernel2-build`, then step 5; then the OCaml and Lean style gates (ocamlformat `janestreet`, `@fmt @check @lint`, warnings as errors, `.mli` for exposed modules; the archive reader's catch-all becomes an explicit error).
2. **When calibration ends:** merge `s1-hunt-fixes` (accepted, decisions 2026-11-16 18:10 UTC, 13:10 EST) into `study1-build`; run step 4's whole-window batch on one idle core here; then study 1's manifest, G100, sessions.
3. **Python and Rust leave `main`** as study 1 reports and kernel version 2 lands. The recorders move to OCaml in a side-by-side switchover. Stage 7 stays parked; stages 8 and 9 are superseded.

### Finished

- Stages 0–6 exited (stage 4 on 2026-11-08: `audit/stage4/exit.md`); recorder handoff done. Findings and audit links: `docs/whitepaper.tex`, §17; current qualifications below.

## Blockers

None blocks the program. Source certificates that fail, with their clauses, are in `venue/sources.toml` and `audit/decisions.md`: Kalshi, Polymarket and Polymarket US; FRED and ALFRED; IMF; and stage 8's candidates.

## Decisions awaiting the human's review

- From 2026-11-08, the human away (`audit/decisions.md`): stage 4's exit; the research reviews' actions; the cluster runner not adopted.
- **The advisor's study 1 build decisions** (`audit/decisions.md`, 2026-11-12): `measure.scores` over several programs; the random-pair encoding, pending the architect.

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **The agent's model (stages 3 and 4):** many sessions fell back from Opus 5.5 to Opus 4.8 after a "cyber" safeguard flag: 9 of 20 stage 3 null sessions, the real campaign's search session, and 31 of 40 in stage 4's swarm (`audit/decisions.md`, 2026-11-12). No judged number changes. Reports name the model that answered.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells; every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (paper, Section 10). Its searchers state no mechanisms, so C2.2's power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed, so C0.7's, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B. C3.2 met only under v3 (0 of 20): v1 failed as written (20 of 20, crashes before any model call), v2 established no procedure (`audit/stage3/write-denied-2026-10-31.md`). The real campaign had zero finalists in both arms: C3.3 and C3.4 met under the zero-finalist revisions, the release path not exercised, the holdout unreleased.
- **Stage 4:** C4.5 v1 and v2 failed (strict xfails); v3 passes as written, N2-8 unresolved (A4's refused `Edit` fails `audit_holds`; calls equal ledger rows). A smoke test: no finalist, so the holdout and betting path never ran; the C4.5 qualifications stand. Pooled: 22 started, 21 known non-promotions (bound 0.133), v2's crashed N2-9 unknown (0.198 if counted); the series report reads only logs in `data/agent` and omits v2.
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (`criteria/test_stages3to5.py` enforces it); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run; L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after. `as_managed_mean` omits a spread with one leg entered, though the equity carries its P&L (strict xfail, audit/decisions.md, 2026-11-03); the thesis track is parked.
