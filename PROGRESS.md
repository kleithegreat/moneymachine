# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/`.

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; clock record: the kernel's bound, `CLUSTER.md`), `datalayer` (`venue/sources/datalayer.json`).
  - `thesis` (`sha256:8ad0b655…`, commit `29a25cb`): stage 10, track `thesis-310449610583` (`audit/stage10/manifest.json`); C10.5's 28-day window counts from its freeze, 2026-11-03 00:02 UTC (2026-11-02 19:02 EST). A canary runs before each session; a failure prints `SANDBOX CONTRACT BROKEN` or waits on availability.
  - The mirror CronJobs on `sha256:5e81095e…` (`cb23337`). `agent-series` finished C4.5 v3 (`mirror/agent/`).
  - CronJobs `mirror` (10 min) and `mirror-verify` (daily): each volume to `/srv/moneymachine/mirror/<volume>` on this PC, the only copy.
  - prodesk7 also runs test shards, only inside its isolated `mm-tests@` unit (Homelab `mm-test-node`; `CLUSTER.md` §7).
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` and the builder wake-ups run only while the human is logged in. Batch Jobs: none queued. `/tmp` is a 7.8 GB tmpfs that killed `nix develop` shells fill: set `CARGO_TARGET_DIR`/`TMPDIR` on disk for builds.
- **Budget.** No campaign runs. GPT's weekly allowance is nearly spent until about 2026-11-13; Argon's is spent until about 2026-11-14 00:25 UTC (11-13 19:25 EST). Claude builds and reviews meanwhile, labeled Claude-only.

### Wake-ups (2026-11-08, fallbacks if the advisor's session has closed)

- **refreeze round six review** (Opus, 23:30 UTC (18:30 EST)): skip if `audit/reviews/2026-11-08-opus-thesis-refreeze-round6.md` is committed on `main`. Otherwise the last review before the refreeze: `thesis-refreeze` three-dot from `2229563` (round six, `audit/reviews/2026-11-08-gpt-refreeze-round6-build.md` there), answering `audit/reviews/2026-11-08-argon-web-refreeze-t3.md`, in a fresh worktree without `data/`: reproduce each Argon construction against the new code, hunt regressions near round six's fixes, check T3 and the criteria draft against the code and the human's decisions (`audit/decisions.md`, 2026-11-08), run the sharded suite; write and commit the review there (ready / after fixes / not ready). No freeze or deploy.
- **stage7 slice 4 fixes** (Opus, after the review): skip if `slice4` is pushed with its fixes rechecked. Otherwise finish the fixes to `audit/stage7/slice4-review-argon.md` on `slice4` (`../mm-slice4`; fixes at `b94cba6`, `SEMANTICS.md` edit uncommitted): rerun `cargo test --release`, the C6.4 harness and the byte comparison against `933b3f4` and `794860d` on N1-N3, explain any newly differing run, commit, push. Do not merge: Argon rechecks it.

### Next, in order

- **Paper erasure:** SCORING.md's derivation prose leaves at the refreeze, DSL.md's after the pilot, stage 7's specs when it lands.
- **Thesis refreeze** on `thesis-refreeze` (`../mm-thesis-rf`, pushed): round five (`b29eb06`, Sonnet) reviewed by Opus: ready after fixes (`audit/reviews/2026-11-08-opus-thesis-refreeze-round5.md`): R1-R7 hold; F1 T3's schedule derivation miscounts terminal requests (recorded behaviour: done 02:54 UTC (21:54 EST); omit-unclosed stress: 04:45 UTC (23:45 EST)), F2 a Monday attested after 23:00 UTC (18:00 EST), F3 the report lacks `snapshot_ready`, F4 a deadline race, F5 erasure. Next: a builder fixes F1-F5; the advisor decides whether the revision restates the ten-dex mark send time; then the criteria revision alone, then the freeze (new identity and window). Argon's T3 check queued.
- **Lean L1 for the corrected engine** parked on `claude/lean-l1-kernel-defects-h273e5`, with stage 7.
- **Stage 7: parked after slice 4** (the human, 2026-11-08, `audit/decisions.md`). Slice 4 built and checked on `slice4` (`../mm-slice4`, `4452591`; rust-port-plan §2 item 4: C6.4's 3,372 runs agree, N1-N3 byte-identical to `933b3f4`, edge to its parent); not merged: Argon reviews it after its reset (~2026-11-14). No slice 6 or other C7 work. The Lean engine stage is deferred.
- **Next research step, after the refreeze:** the positive-control study (`audit/decisions.md`, 2026-11-08): its criteria first, reviewed by GPT and a Claude session.

1. **Stage 7, parked** (branch `stage7`, worktree `../moneymachine-stage7`; plan `audit/stage7/rust-port-plan.md` there): resumes as a vertical slice for a study. Still owed when the gate or corpora next change: a delisting corpus in a market without a funding gap (C6.4's lost it); before O1 (per-step loss cap B = 0.2, provisional, decision of 2026-10-28), a better-powered B = 1 betting test (candidates and rejected fixes: `audit/reviews/2026-11-08-opus-research-statistical-gates.md`; O1 must not reuse 1/(2B)).
2. **Stage 8 data** (below the critical path): recording only, integrity-only inspection. `audit/stage8/scope-manifest.md`: no class admitted, every blocker stays; the exposure inventory comes before any annex. Databento is complete for the plan, within its sign-up credit.
3. **Post-pilot ideas:** `docs/future-work.md`. Before O1's B, stage 8's screens, the C7.7/C8 corpora or the C8/C9 annexes are frozen: `audit/reviews/2026-11-06-gpt-assumption-sweep.md` (guessed numbers to derive first).

Open, status unclear: a research arm whose model has an earlier knowledge cutoff, freeing more historical holdout (the human, 2026-10-23).

Open research question (the human), unblocked now that stage 4 has exited: does memory across campaigns help agents without raising false discoveries? Pre-register first.

### Finished

- Stages 0–6 exited (stage 4 on 2026-11-08: `audit/stage4/exit.md`); recorder handoff done. Findings and audit links: `docs/whitepaper.tex`, §17; current qualifications below.

## Blockers

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
