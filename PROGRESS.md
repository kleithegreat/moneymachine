# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/` (frozen criteria `audit/criteria.md`, decisions `audit/decisions.md`).

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; clock record: the kernel's bound, `CLUSTER.md`), `datalayer` (`venue/sources/datalayer.json`).
  - `thesis` (`sha256:8ad0b655…`, commit `29a25cb`): stage 10, track `thesis-310449610583` (`audit/stage10/manifest.json`); C10.5's 28-day window counts from its freeze, 2026-11-03 00:02 UTC (2026-11-02 19:02 EST). A canary runs before each session; a failure prints `SANDBOX CONTRACT BROKEN` or waits on availability. The pod gate's `retrieval` part fetches each certified retrieval entry (at least one 200 means main sessions can read).
  - `agent-series` (`sha256:5d59960e…`, `fb220cc`, since 2026-11-04 00:41 UTC (2026-11-03 19:41 EST)); the mirror CronJobs on `sha256:17764092…` (`44a2b45`) since 2026-11-04 05:50 UTC (00:50 EST): C4.5 v3's ten swarm campaigns `swarm-null-3-N2-0..9`. Logs and reports in `mirror/agent/`.
  - CronJobs `mirror` (10 min) and `mirror-verify` (daily): each volume to `/srv/moneymachine/mirror/<volume>` on this PC, the only copy.
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` and the builder wake-ups run only while the human is logged in. Batch Jobs (`ops/jobs.py`, namespace `moneymachine`): none queued.
- **Budget.** Campaigns start on the first account (TAMU, then Cornell) with every window at most 0.8 after the most a campaign has used (`need`, measured across accounts). Claude work on an account during its campaign can exhaust it, a counted crash: none then.

- **Nine defects specced** on main, two review rounds; stage 7 implements them after its byte-identical tag.

### Next, in order

- **Paper erasure:** SCORING.md's derivation prose leaves at the next thesis refreeze, DSL.md's after the pilot, and stage 7's specs when stage 7 lands; rationale: paper appendix A.
- **Thesis** `thesis-310449610583`, frozen 2026-11-03 00:02 UTC (2026-11-02 19:02 EST); sessions record and register. Refreeze fixes ready, undeployed: `thesis-fixes` (GPT: six fixes) and `thesis-positions` (Sonnet: one-leg spread). Before the human's refreeze: Argon reviews both, re-deriving the C10.3 value the positions fix changed.
- **Lean L1 for the corrected engine** parked on `claude/lean-l1-kernel-defects-h273e5` (no `sorry`), with its stage 6 criteria revision; lands after stage 7's byte-identical tag.
- **B3 frozen** on `stage7` (`7bf79df`). **Slice 5 built** on `stage7` (`eff52b0`, Sonnet): Python, Rust and GPT's sealed resolver equal Lean on every frozen case; Argon's review (ten findings) and re-review (sound) in `audit/stage7/slice5-*review-argon.md`. Development runs only; C7.6 is judged after the rebase. Next: slices 3, 4 and 6 (Sonnet builds, Argon reviews; GPT never, as C7.7's red team).


2. **Stage 4: C4.5 v3 running**, 3 of 10 campaigns (the last 2026-11-04 09:48 UTC (04:48 EST)), waiting on the accounts' Claude usage (the human, 2026-11-06); TAMU's reset is 2026-11-07 04:00 UTC (2026-11-06 23:00 EST).
5. **Stage 7** (branch `stage7`, worktree `../moneymachine-stage7`; off `main` until the pilot's judged runs are done). Unblocked, below the critical path:
   1. Done: all 18 frozen laws proved; `refmm` builds and agrees with `mm`.
   2. The Rust kernel to the same definitions, with the loader rewrite, under the corpus differential: plan and status `audit/stage7/rust-port-plan.md` there; B2 frozen (`7997257`). When stage 7 merges, the paper's snapshot-only point-in-time paragraph (`docs/whitepaper.tex`) changes with it. The fresh C7.7 corpus needs a market exporter emitting revisions, a registry and certificates (`mmdump` can't).
   3. Then C7.6 (the store's resolver through `knownat`), C7.2 and C7.3 (verifier, policy v2, `mm certify`, `mm bind`, preflight), C7.4 (event feeds as derived sources, baseline), C7.5 (new-feed demonstrations), C7.7 (GPT's declaration red team).
   - Judged runs wait for the rebase onto the pilot's baseline commit.
   - Also: a delisting corpus in a market without a funding gap (C6.4's lost it); before O1 (per-step loss cap B = 0.2, provisional, decision of 2026-10-28), a better-powered B = 1 betting test.
6. **Stage 8 data** (below the critical path): recording only, integrity-only inspection. `audit/stage8/scope-manifest.md`: no class admitted, every blocker stays; the exposure inventory comes before any annex. Databento is complete for the plan, within its sign-up credit; Unblocked: recording OECD's STES revisions (certified; about 357 MB a country quarterly).
7. **When stage 7 nears its exit**: the Lean engine stage's criteria (decision of 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT)). **When stage 7 lands on `main`**: the repo-wide erasure pass (same entry).
8. **Post-pilot ideas:** `docs/future-work.md`. Before O1's B, stage 8's screens, the C7.7/C8 corpora or the C8/C9 annexes are frozen: `audit/reviews/2026-11-06-gpt-assumption-sweep.md` (guessed numbers to derive first).
9. **Parked (human):** a meta-process review: does the project's execution follow the intent of the first web chat? (`ctx`, its origin import.)

Open, status unclear: a research arm whose model has an earlier knowledge cutoff, freeing more historical holdout (the human, 2026-10-23).

Open research question, after stage 4 (the human): does memory across campaigns help agents without raising false discoveries? Pre-register first.

### Finished

- K1 fixture amended per both reviews; strict xfail (`gate/tests/test_kernel_defects.py`).
- Pytest: 1,171 passed, 25 strict xfails, 2 skips; PDF rebuilt.
- Stages 0–3, 5 and 6 exited; recorder handoff done. Findings and audit links: `docs/whitepaper.tex`, §17; current qualifications below.

## Blockers

- **Derivations owed:** paper appendix A (`audit/reviews/2026-11-06-gpt-assumption-sweep.md`); risk-cap/power claims narrowed to the supported scope, judgments unchanged.
- **Capacity guard not deployed:** rollout and visible synthetic desktop alarm check in `CLUSTER.md` §5. O2 states the chosen reserve and offline limitation, not a response-time guarantee.
- **Nine-defect spec.** (1) No certified source states a delisting time yet, so a market whose rules mark a coin delisted is inadmissible (`R_MARKET`); the recorded venue marks FTM delisted, so no real-data market is admissible to the corrected engine until one exists. K1's provisional `store/delistings` adapter/certificate binding is undefined (§3). (2) `kernel/DSL.md` (hash-frozen) is revised with the harness fork that first runs agents on the corrected engine.

- **FRED and ALFRED: the API terms forbid our use; the human decides.** https://fred.stlouisfed.org/legal/ (read 2026-10-26): clause (l) forbids storing, caching or archiving FRED content or putting it in any database (our store is one), and (k) use in developing or training machine learning. Key unused; no permission request for now (human). Macro vintages come from the Philadelphia Fed's RTDSM.
- **IMF** "prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Stage 8 equities and index constituents:** no purchase, indefinitely (the human, `audit/decisions.md`); stage 8 reports its admitted scope.
- **ICE via Databento:** its non-display licence is unclear; ICE stays out until the human settles it.
- **On-chain: hardware.** A Hyperliquid node: 16 vCPUs, 128 GB RAM, 100 GB of logs a day; Ethereum or Polygon: 2–4 TB NVMe.
- **Not certifiable as they stand:** ClinicalTrials.gov (no automation clause); usda.gov (403); MarineCadastre AIS (no terms; GBs a day); World Bank Pink Sheet (per-release URL on a page forbidding automation; its Data Catalog API unchecked); EIA hourly grid (about 699 MB twice a day).
- **Stage 8 data gaps:** policy-rate announcement times (BIS: effective dates only), ECB YC series and revisions, CFTC TFF history, Treasury average rates' revisions, the ECB release calendar.

## Decisions awaiting the human's review

None.

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. Amendments C0.4 (2026-10-22) and C0.3/C0.7 (2026-10-23). The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells; every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (the B = 1 bound is examined in stage 7). Locked calibrations v1 and v2.1 failed; v3, the betting test, adopted by human decision, passed a fresh suite. C2.2's first comparison failed from two generator errors, fixed before the pass. Its searchers state no mechanisms, so its power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed (about 30% of snapshots matched within 1 s, 50% required), so C0.7's, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B. C3.2 met only under v3 (0 of 20): v1 failed as written (20 of 20, crashes before any model call), v2 established no procedure (`audit/stage3/write-denied-2026-10-31.md`). The real campaign had zero finalists in both arms: C3.3 and C3.4 met under the zero-finalist revisions, the release path not exercised, the holdout unreleased (this PC's claim line stays).
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (`criteria/test_stages3to5.py` enforces it); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run (the first two: incomplete corpus; digests, not streams); L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after. `as_managed_mean` omits a spread with one leg entered, though the equity carries its P&L (strict xfail, audit/decisions.md, 2026-11-03), until the next refreeze.
