# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/`.

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; clock record: the kernel's bound, `CLUSTER.md`), `datalayer` (`venue/sources/datalayer.json`).
  - `thesis` stopped (0 replicas): `thesis-310449610583` got SIGTERM 2026-11-09 02:57 UTC (2026-11-08 21:57 EST), exited by itself 03:35 UTC (22:35 EST); its window incomplete, never pooled.
  - Job `thesis-prewarm` stopped by the human on 2026-11-11 (the perp instance is parked).
  - The mirror CronJobs on `sha256:5e81095e…` (`cb23337`). `agent-series` finished C4.5 v3 (`mirror/agent/`).
  - prodesk7 also runs test shards, only inside its isolated `mm-tests@` unit (Homelab `mm-test-node`; `CLUSTER.md` §7).
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` and the builder wake-ups run only while the human is logged in. Batch Jobs: none queued. `/tmp` is a 7.8 GB tmpfs that killed `nix develop` shells fill: set `CARGO_TARGET_DIR`/`TMPDIR` on disk for builds.
- **Budget.** No campaign runs. Fable runs on the personal account, one session at a time; GPT's one review is spent. Argon runs through the web UI; `agy` is spent until about 2026-11-14 00:25 UTC (11-13 19:25 EST).

### Work in progress

Roles: Fable architects, Opus orchestrates, Sonnet builds; GPT and Argon review Fable adversarially (`CLAUDE.md`). Fable 5.2 runs one session at a time through `data/builder/run-architect.sh`. The perp instance is parked (the human, 2026-11-11).

1. **Rearchitecture** (Fable 5.2, branch `rearchitecture`, `audit/program/`; reviews in `audit/reviews/2026-11-1*`; the human's decisions in `audit/decisions.md`, 2026-11-11).
   - **Revision 4** (`44fb5ae`, `9e5240b`; Argon's round 3 answered): two positive controls and no stop.
     - **Study 1:** can the agent find an edge that exists. Fixed at six causes; each market gets its own fresh twin pairs.
     - **Study 2:** can the confirmer confirm a published rule, the Astraeus vault replication. Fidelity against the vault's record first, then a frozen forward test with power 0.47 at Sharpe 1.4 and 0.90 at 2.4 within two years.
     - **No reading-agent study** until a measured count of at least 33 independent bets a week.
     - **`docs/findings.md`** indexes the earlier research.
     - **Approved by the human** (`audit/decisions.md`, 2026-11-11 21:26 UTC (16:26 EST)). Finished at `63e81cf`: `paper-changes.md` (parts A to D, every stale file), study 1's build plan (`briefs/1-positive-control.md`, nine steps) and `ledger.md` (14 agreed, 8 disputed).
     - **Study 2's vault** is identified: `0x53375ca9…2a06`. Its archive data for April 3 to October 31 is downloading, about 27 GB and $2.46.
   - **Built:** the archive reader and bars of any interval (`ingest/archive.py`, `4bcd768`).
   - **Study 1 build** (`rearchitecture`):
     - Tests for steps 1 to 6 are written before the code (`8c17b5d`, `07f0fc7`).
     - Steps 3 and 6 are built (`834c51e`, `4273da5`; 61 tests pass).
     - Steps 1, 2, 4 and 5 wait for Fable's fix of Argon's round 4 finding 3: session `7049e7c6`, started 2026-11-12 01:08 UTC (2026-11-11 20:08 EST). If it is cut off, commit its work and rerun the remainder.
     - Cornell and TAMU are free for about two weeks only.
   - **Archive:** all 80,845 raw files are on disk (26 GB). Snapshot parsing is resuming after a low-memory kill (`data/hl-archive/fetch-2026-11-11b.log`). Then check that every snapshot parquet reads, since the kill may have left a partial file.
   - **Next:** Fable designs kernel version 2 with study 2's hedge and margin (Argon round 4's findings 1, 2, 4 and 5). Sonnet applies `paper-changes.md`. Then one deletion pass of stale files, `audit/` included (the human's leave).
2. **Erasure** per the meta review's section 5. The round-named thesis tests go with the redesign. Stage 8 and 9 criteria are marked superseded when a study is defined.


### Next, in order

- **Paper erasure:** DSL.md's derivation prose leaves after the pilot.
1. **Stage 7, parked** (branch `stage7`, its plan there, and the Lean L1 branch): no gate, kernel, Lean, O1, nine-defect or delisting-corpus work until a study needs it; then it resumes as that study's vertical slice (the human, 2026-11-09).
2. **Stage 8 data** (below the critical path): recording only, integrity-only inspection. `audit/stage8/scope-manifest.md`: no class admitted, every blocker stays; the exposure inventory comes before any annex. Databento is complete for the plan, within its sign-up credit.
3. **Post-pilot ideas:** `docs/future-work.md`. Before O1's B, stage 8's screens, the C7.7/C8 corpora or the C8/C9 annexes are frozen: `audit/reviews/2026-11-06-gpt-assumption-sweep.md` (guessed numbers to derive first).

### Finished

- Stages 0–6 exited (stage 4 on 2026-11-08: `audit/stage4/exit.md`); recorder handoff done. Findings and audit links: `docs/whitepaper.tex`, §17; current qualifications below.

## Blockers

- **No US event-contract venue is certified for study 2** (`audit/decisions.md`, 2026-11-11). Kalshi's Developer Agreement (sections 3, 3.1, 3.5, 6.4) and Polymarket US's Participant Agreement (sections 19, 22) permit only trading use without written permission.
- **Derivations owed:** paper appendix A (`audit/reviews/2026-11-06-gpt-assumption-sweep.md`); risk-cap/power claims narrowed to the supported scope, judgments unchanged.
- **Nine-defect spec.** (1) No certified source states a delisting time yet, so a market whose rules mark a coin delisted is inadmissible (`R_MARKET`); the recorded venue marks FTM delisted, so no real-data market is admissible to the corrected engine until one exists. K1's provisional `store/delistings` adapter/certificate binding is undefined (§3). (2) `kernel/DSL.md` (hash-frozen) is revised with the harness fork that first runs agents on the corrected engine.

- **FRED and ALFRED: the API terms forbid our use; the human decides.** https://fred.stlouisfed.org/legal/ (read 2026-10-26): clause (l) forbids storing, caching or archiving FRED content or putting it in any database (our store is one), and (k) use in developing or training machine learning. Key unused; no permission request for now (human). Macro vintages come from the Philadelphia Fed's RTDSM.
- **IMF** "prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Stage 8 equities and index constituents:** no purchase, indefinitely (the human, `audit/decisions.md`); stage 8 reports its admitted scope.
- **ICE via Databento:** its non-display licence is unclear; ICE stays out until the human settles it.
- **On-chain: hardware.** A Hyperliquid node: 16 vCPUs, 128 GB RAM, 100 GB of logs a day; Ethereum or Polygon: 2–4 TB NVMe.
- **Not certifiable as they stand:** ClinicalTrials.gov (no automation clause); usda.gov (403); MarineCadastre AIS (no terms; GBs a day); World Bank Pink Sheet (per-release URL on a page forbidding automation; its Data Catalog API unchecked); EIA hourly grid (about 699 MB twice a day).
- **Stage 8 data gaps:** policy-rate announcement times (BIS: effective dates only), ECB YC series and revisions, CFTC TFF history, Treasury average rates' revisions, the ECB release calendar.

## Decisions awaiting the human's review

Round fifteen's design choices, reviewed by the advisor only (`audit/decisions.md`, 2026-11-10 02:52 UTC (2026-11-09 21:52 EST)): C10.2's audit fails closed; every call has one ledger record (effect rows carry their call); fetched bodies are stored by their hash.

From 2026-11-08, the human away (`audit/decisions.md`): stage 4's exit; the refreeze schedule (start 05:00 UTC (00:00 EST), not 19:00 UTC (14:00 EST)); the Monday benchmark rule (on `thesis-refreeze`); the research reviews' actions; the cluster runner not adopted.

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells; every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (the B = 1 bound is examined in stage 7). Its searchers state no mechanisms, so C2.2's power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed, so C0.7's, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B. C3.2 met only under v3 (0 of 20): v1 failed as written (20 of 20, crashes before any model call), v2 established no procedure (`audit/stage3/write-denied-2026-10-31.md`). The real campaign had zero finalists in both arms: C3.3 and C3.4 met under the zero-finalist revisions, the release path not exercised, the holdout unreleased.
- **Stage 4:** C4.5 v1 and v2 failed (strict xfails); v3 passes as written, N2-8 unresolved (A4's refused `Edit` fails `audit_holds`; calls equal ledger rows). A smoke test: no finalist, so the holdout and betting path never ran; the C4.5 qualifications stand. Pooled: 22 started, 21 known non-promotions (bound 0.133), v2's crashed N2-9 unknown (0.198 if counted); the series report reads only logs in `data/agent` and omits v2.
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (`criteria/test_stages3to5.py` enforces it); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run; L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after. `as_managed_mean` omits a spread with one leg entered, though the equity carries its P&L (strict xfail, audit/decisions.md, 2026-11-03), until the next refreeze.
