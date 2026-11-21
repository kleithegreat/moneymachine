# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli -h`. Criteria checks are tests in `criteria/` over evidence in `audit/`.

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources`, `datalayer` (`CLUSTER.md`).
  - The mirror CronJobs on `sha256:5e81095e…` (`cb23337`).
  - prodesk7 builds test checks as a remote builder, inside `mmtest.slice` (`CLUSTER.md` §6).
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers run only while the human is logged in. `/tmp` is a small tmpfs: set `CARGO_TARGET_DIR`/`TMPDIR` on disk for builds.
- **Accounts** (the human, 2026-11-11 and 12):
  - **Cornell and TAMU** are free for study 1 for about two weeks, to about 2026-11-25.
  - **The architect** is a fresh Opus 5.5 session at maximum reasoning after Fable's last session, 2026-11-16 (`CLAUDE.md`).
  - **Neon** (`gemini-4-neon-xhigh`, `agy`) is the Gemini reviewer, and architected rounds 8 to 11 while Claude was short. Opus subagents on this account are allowed again (the human, 2026-11-21). agy builds go through `ops/agy-write.sh on DIR | off`; no review runs while it is on.
- **Worktrees:** `main`; `../mm-program` (`rearchitecture`); `../mm-s1-arms` (study 1's arms, at the manifest's commit); `../mm-k2` (`kernel2-build`); `../mm-k2-step5` (`kernel2-step5`); `../mm-review-cs2` (the CS2 reviewer's); one per agent.

### Work in progress

Roles and laws: `CLAUDE.md`. New code is maximal Lean plus OCaml (the human, 2026-11-12).

1. **The program** (`audit/program/` on `rearchitecture`; revision 4 approved by the human 2026-11-11; `ledger.md` lists what is agreed and disputed). The project is academic: no live trading, no stage 11.
   - **Study 1, the positive control of search:** does the agent find a planted edge more often than G100? At most 100 markets, on Cornell and TAMU.
     - **Converged and committed:** CS1.1 is in `audit/criteria.md` (`criteria: study 1`, `10fedc5`), with definitions at `rearchitecture` `ce7ff38`.
       - Each market has one session, never rerun; a session with no pick, or not answered by Opus 5.5 or 4.8, is the agent's miss.
       - The subject is the agent as served (H8, approved by the human).
       - Wall 5 is 14 of 200.
     - **Calibration done** (`cal-3`, strength 0.0021875, all walls pass); **manifest** committed (`c5d95db`, seed by rule); **G100's arm** done, 15 of 100 earn (`51e0e4c`). Arms run from `../mm-s1-arms` with the frozen kernel via `CARGO_TARGET_DIR=~/.cache/mm-study1/k`.
     - **Now:** runner `mm-study1` on Cornell alone since 2026-11-21 20:15 UTC (15:15 EST; the human), from Cornell's weekly reset 2026-11-22 05:00 UTC (00:00 EST); 32 markets judged. If Cornell's 30% runs out first, TAMU rejoins after the human's reset (`audit/decisions.md`).
   - **Study 2, the positive control of the confirmer:** the replication of vault `0x53375ca9…2a06` (FuturAI Labs; its fills read only before the forward window).
     - Fidelity first, then a frozen forward test (its operating power is not yet derived: GPT-6.2, `audit/reviews/2026-11-21-gpt62-study2-whole.md`, finding 2). Criteria committed (`criteria: study 2`, `a324059`; CS2.1 revised `a903317`).
     - **Kernel version 2** (`audit/program/kernel-v2.md`, brief 3; branch `kernel2-build`, worktree `../mm-k2`): steps 0 to 3 built and proved (Lean laws with only the three standard axioms); layer 1 clean on all 5,806 vault fills under the venue's printed arithmetic. Step 4: below.
     - **Data:** the archive for its 17 coins, 2026-04-03 to 10-31 (26 GB, `ingest/archive.py`); funding history (`data/study2/funding-history/`); the vault's own fills and funding before 11-01 (`data/study2/vault/`); the trade prints (`node_fills_by_block`, V22; `data/hl-archive/fills_by_block/`), with a continuous block stream. The C6.4 reference streams are stored under a hash (`data/stage6/c64-reference/`, decisions 2026-11-16).
     - **The vault collector** (`recorder/VAULT.md`, `mmvault`) runs hourly as CronJob `vault` (`CLUSTER.md`).
   - **No reading-agent study:** the thesis track registered 0 theses in 6 sessions, against a threshold of 33 independent bets a week.
   - **The websocket recorder** (`recorder/RECORDER.md`): every perp on every Hyperliquid dex, crypto and builder-deployed stocks, commodities and indices. **Running** since 2026-11-14 03:43 UTC (22:43 EST) as StatefulSet `ws` (image `851fc77`, `sha256:9a6e0b2a…` since 2026-11-20 14:57 UTC, 09:57 EST; `vault` likewise), one copy on prodesk7 (PVC `ws`, not mirrored, the human's choice): fast five-level books for all 350 perps, 20-level books for the main dex's 179, trades, asset contexts, listings. About 2.0 GB a day (sizes only); its volume fills about April to May 2027.
2. **Erasure pass** (list `audit/erasure/2026-11-12-deletion-list.md`): phases A to E and F12 are done, `ops/shards.py` included.
   - Tests are 11 flake checks on the remote builders and `nix run .#test` (`CLUSTER.md` §6); the launcher is `nix run .#session`; the timers are `homeManagerModules.default`, imported by dotfiles.
   - Phase A: the thesis track and `ops/crossmachine.py` are gone, archived at `archive/thesis` and `archive/thesis-refreeze`.
   - **Next:** phase F's `agent-real` with study 1's criterion.
   - **Constraint:** `flake.lock` does not move while study 1 runs on the frozen harness.

### Next, in order

1. **Kernel version 2:** step 5 built; B4 passes on it (3,120 of 3,120, rerun with the hardened stub); test 12's inputs are `data/x4-inputs/test12/` (root `7bab5c43…`).
   - **Test 12 is too slow** (15 days a host, exact `exp`/`log`). Round 11 (Neon, answering Opus's review) plans step 5x: X4's series carried incrementally, proved equal (law X6), about 1 hour a host; GPT reviews it. Step 5 merges after step 5x passes test 12 and B4.
   - **Rounds 9 to 11** (Neon): GPT did not converge on either (`audit/reviews/2026-11-21-gpt-*`). **Round 12** (fresh Opus on TAMU's spare usage, session `999da091`): kernel item done, GPT's read open on three points; study 2's record next; then Neon and GPT. CS2.1's note and CS2.2's revision: then a fresh Opus, then the commit.
   - **TAMU** (the human, 2026-11-21) runs the queued Opus work in every window (`audit/decisions.md`).
   - **Recorder:** the lint gate and the six catch-alls.
2. **Study 1:** runs to its end (about 2026-11-23), then its report.
   - **After a reboot**, restart the runner: `systemd-run --user --unit mm-study1` from `../mm-s1-arms`, running `nix develop -c python -m gate.control.runner` with bubblewrap (`nix build --inputs-from . nixpkgs#bubblewrap`) first on `PATH`, `CARGO_TARGET_DIR=~/.cache/mm-study1/k`, `TMPDIR=~/.cache/mm-study1/tmp`, `CLAUDE_CODE_OAUTH_TOKEN_CORNELL`, output appended to `~/.cache/mm-study1/runner.log`.
3. **The paper, free-standing and academic** (the human, 2026-11-16): deferred until the human says; written by Opus, reviewed for accuracy only.
4. **Python and Rust leave `main`** as study 1 reports and kernel version 2 lands. Stage 7 parked; stages 8 and 9 superseded.

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
