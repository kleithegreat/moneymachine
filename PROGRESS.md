# Progress

## Now

Commands are `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence under `audit/`; they skip until the evidence exists. Frozen criteria and their revisions: `audit/criteria.md`. Intent: `docs/whitepaper.tex`. Process rules: `CLAUDE.md`.

- **Stage 0 (critical path).** The spent window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC failed C0.7 as written (Qualifications). C0.2, C0.4, C0.5 and C0.9 are met on the second fetch (version 1792613363942, `audit/stage0/ingest-1792613363942.json`). The local-only window that began 2026-10-24 20:13 UTC broke: this PC was off from 2026-10-25 03:00 to 23:22 UTC. Windows from the merge threshold on are merged (human-approved, including boundary polls); the local host drops out of any window its clock-log hole touches. Hyperliquid itself failed for about 2 minutes (502s and read timeouts on the cloud host, L2 gaps up to 112 s across every coin at 2026-10-25 09:32 to 09:35 UTC), so the earliest complete window is cloud-only, about **[2026-10-25 09:35, 2026-10-26 09:35) UTC**, if no gap over 60 s follows.
  - `mm-stage0.timer` (user timer, every 20 min) runs one `flock`-guarded pass of `data/tmp/stage0-close.sh` (untracked). From 2026-10-25 20:20 UTC (16:20 EDT) each pass pulls the cloud host's files and checks `availability.judgment`: the local-only window if it started before the merge threshold (2026-10-24 21:58:13 UTC (17:58 EDT)), else the merged window. Once one is complete it runs `availability` (C0.3), `execution` (C0.7), `witness` (C0.8) and `pytest criteria/test_stage0.py`, then writes `data/tmp/stage0-close.done`. This PC need not be up during the window, only at some time after it.
  - A failure of C0.2, C0.3 or C0.5 triggers the exit rule. The runner counts a skipped criterion as not passed.
  - Until the results are reviewed and committed, nothing changes in code the runner imports, and the HL recorder is not restarted (human, 2026-10-23).
- **Fixes from GPT's whole-project review of 2026-10-24** (reply: `~/.cache/mm-gpt/project.XShA/reply.txt`; each finding checked against the code by a subagent). The fixes gating the sweeps, stage 3, stage 4 and the stage 10 start are done (`audit/decisions.md`, 2026-10-24 and 25). Still to do, each before the step it gates:
  - **After stage 0 is committed, before C1.4 or any run that records the kernel hash** (human, 2026-10-25). The work is on branch `post-stage0`, kept off `main` because the store is runner-imported: the store and kernel changes and the resolution differential pass there, and the Lean proofs are partly updated (`Ref/Proof/View.lean` still fails). `data/tmp/after-c07.sh` refuses to start until the branch is merged.
    - a revision whose values differ from the key's first revision is known no earlier than its fetchedAt, in `store.py` and `market.rs`, with a differential test. Paper §5's "a later correction hides a value" is false until then, but no pilot store holds a changed value;
    - `Store` reads its own `policy.json`;
    - Rust skips tombstones;
    - a held position with no funding row aborts the replay instead of settling zero.
  - **Stages 7–9:** delisting becomes a record with its own knownAt (C8.1); the pilot's last-traded-bar rule is pre-registered and touches only FTM in the search period.
- **Reboots of this PC** need no manual step. At login, `mm-recorders-up.service` (`ops/recorders-up.sh`) restarts any local recorder whose pidfile names no live process, and the user timers (`mm-stage0`, `mm-oci-pull`, `mm-diskguard`) resume (`Linger=no`, so they run only while the human is logged in). The cloud VM records throughout, and the next pull catches up.
- **After stage 0 is committed, in order** (priorities of CLAUDE.md §3; order checked by GPT's critical-path review of 2026-10-24):
  1. **Stage 2.** `data/tmp/after-c07.sh` (untracked, resumable, fail-closed: it starts only once `data/tmp/stage0-close.done` records passed criteria and stage 0's outputs are committed). It runs C1.4 and C1.8 into `audit/stage1/`, `freeze-searcher`, then the sweeps (`sweep null`, `betas`, `sweep mixed`, `truth`, `probes-top5`, `sweep-summary`); estimated 2 h, in an 8 GB scope. Two checks come before reading the sweeps:
     - how often I10's loss cap binds in the null sweeps (`bankrupt` per campaign and in `null_summary`), since limited liability can give a leveraged strategy a positive expected return under a true null (NULLS.md);
     - C2.6's feasibility (Blockers).

     Then the stage 2 exit is judged and reviewed.
  2. **Stage 3:** `freeze-harness`; then `agent-null agent 20` (C3.2, paced one campaign per 5 h, about 4 days, holdout from day 670 of 730); then `agent-summary`; then the real two-arm campaign (`agent-real`, C3.3/C3.4) with one joint holdout release on [2026-08-01, 2026-09-30). It is a pipeline validation run, not a test for edge. Its promotions are qualified ("historical holdout, costs fitted after it") and confirmed only on [2026-11-01, 2027-01-31).
  3. **Stage 10 start** (alongside the paced stage 3 series, keeping agent sessions apart):
     - run `data/tmp/stage10-start.sh`: `recorder-restart data/live 480`, a check that the day's polls file parses, then one uncounted dry main session;
     - check `harness.audit` against its transcript;
     - run `thesis-freeze` (commit `audit/stage10/manifest.json`);
     - start `thesis-run` detached: `setsid systemd-run --user --scope --quiet --unit=mm-thesis-run-$(date +%s) nix develop -c python -m cli thesis-run >> data/thesis/run.log 2>&1 < /dev/null &`.
  4. **Stage 4:** `agent-null swarm 10` after stage 3's series.
  5. **Code cleanup** deferred by the human's timing rule:
     - misplaced scripts (`audit/stage6/effort.py`) and criterion- or version-named files;
     - PROGRESS.md citations in the runner-imported files (`criteria/`, the stage 0 `ingest` modules, `cli.py`);
     - `kernel/tests/timing/FORMAT.md` folded into its generator;
     - `oci-cli` into the flake and `duckdb` out of it;
     - the Python line-count report, and deletion of one-off scripts whose outputs are recorded.
- **Stages 1, 2, 5, 6, 10.**
  - **Stage 1:** done except C1.4 and C1.8.
  - **Stage 2:** done except the sweeps; calibration v3 passed.
  - **Stages 5 and 6:** done (Qualifications).
  - **Stage 10:** built and tested, C10.4 re-judged under the builder-market revision; waiting for the start sequence above.
- **Stages 7 to 9:** criteria frozen. Kernel changes wait for the pilot's judged runs (Decisions). Stage 8's scope manifest is committed (`audit/stage8/scope-manifest.md`).
- **Recorders.** All are restarted only with `recorder-restart <out_dir> [budget]`.
  - **HL, local:** `data/live`, 600/min until the window closes, then 480/min.
  - **Stage 5 sources:** `data/sources_live`, delvingbitcoin.org, Snapshot and the clock log.
  - **Keyless data layer:** `data/datalayer`, from 2026-10-23 18:39 UTC, about 30 MB a day. Feeds are declared in `venue/sources/datalayer.json`: ECB EXR, BIS, CFTC (3 reports), Treasury, GDELT events, NWS alerts, openFDA, EIA (manifest and petroleum), Polymarket (active and resolved). Bodies are gzip-compressed under `raw/<sha256>.gz`. ECB and every other source without past versions are prospective only.
- **Data.** `data/` is about 650 MB with 105 GB free, and the hourly `mm-diskguard.timer` (`ops/diskguard.sh`) adds a Blockers line below 20 GB. Regenerable and duplicate files were deleted with their hashes in `audit/data-deletions.json`. After stage 0: `live.read` learns `.jsonl.zst`, and closed day files (about 410 MB of polls) are compressed with zstd once their plain sha256s are recorded in `audit/`.
- **Future option (human, 2026-10-23):** a research arm whose model has an earlier knowledge cutoff, which would free more historical holdout data than the current model's June 2026 cutoff allows.
- **Cloud VM (human, 2026-10-23): HL recorder since 21:57 UTC; data layer and stage 5 sources since 2026-10-24 01:43 UTC.** It is an Always Free `VM.Standard.E2.1.Micro` `mm-recorder` in us-ashburn-1 (150.230.168.87; A1 had no capacity), with a $1 budget (`mm-free-tier-guard`).
  - `mm-recorder.service` runs `nix develop .#recorder` at 600/min (the stage 0 budget, from its own IP; raised 2026-10-24 20:35 UTC (16:35 EDT)), capped at 600 MB. `mm-clock.timer` logs the VM's NTP offset every 5 min.
  - `mm-datalayer` and `mm-sources` duplicate this PC's data layer and stage 5 recorders, so a PC outage loses none of their data.
  - This PC pulls all four directories every 10 min (`mm-oci-pull.timer`) into `data/live-oci/<instance>/`; a failed pull adds a Blockers line.
  - Its snapshots count only for windows starting after the merge amendment's conditions hold (`audit/criteria.md`, C0.3/C0.7).
  - Setup and the idle-reclamation risk: `ops/oci/provision.sh`.

## Blockers

- **C2.6: the approved amendment is infeasible as written; the human chooses its replacement (2026-10-25).** The amendment (power ≥ 0.30 at an N2 oracle mean of 0.7% per 4h step) was committed, then suspended by a dated revision before any sweep (`audit/criteria.md`, C2.6).
  - **The wall:** the betting test needs a mean near ln 20 / (0.5 × 1,080) ≈ 0.55% per step at stage 2's holdout length. The planted generator cannot produce that while the kernel runs. The frozen oracle (0.1 per coin) reaches 0.1% per step at β = 0.2 (Sharpe 9); at the gross cap of 2 it reaches 0.16% at β = 0.1 with 2% to 3% volatility; at β = 0.2 the kernel aborts (I5 numerics, below). A mean also needs a stated leverage, which the amendment left open.
  - **Options:**
    1. **Report only** (recommended): the full power curve over the Sharpe cells with Clopper-Pearson intervals and the test-alone curve, no minimum, and the stage 2 report states that the pilot cannot confirm ordinary edges at this holdout length.
    2. **A long-holdout diagnostic cell:** simulated markets can have any holdout length at no cost. A cell with a 900-day holdout (5,400 steps, detectable mean about 0.11%) at a planted strength the generator reaches (the oracle at the gross cap, β about 0.07), with power ≥ 0.30 required there. It shows the machinery detects a planted edge when the data suffice, which the pilot's real holdout cannot.
    3. **Both.**
  - **Blocks:** stage 2's exit. The sweeps run as frozen (Sharpe cells); C2.6 as written is judged and reported either way.

- **I5's absolute tolerance breaks at huge equity (kernel numerics, found 2026-10-25).** I5 compares two equity computations within an absolute $1e-5. Rounding exceeds that near $1e10 of equity, which only absurd compounding reaches. The mixed sweep's truth check, which runs promoted strategies for 10 years, could hit it, and would fail loudly. The fix is a tolerance relative to equity, in `sim.rs`, `reference/SEMANTICS.md` and the Lean model (`Sim.lean`, whose L6 proof uses the constant), with the proof rechecked. It is not taken now: stage 6's evidence covers the current constant.

- **Free sources that need the human's registration (stages 8 and 10).** Keys go in `.keys.env` (gitignored), one `NAME=value` per line.
  - `FRED_API_KEY` (FRED/ALFRED): macro and rates at the backtest tier's data bar (C8.2), since ALFRED gives each value's vintage and release dates.
  - `BLS_API_KEY`: labor and prices, and the BLS release calendar.
  - `BEA_API_KEY`: NIPA and GDP with release metadata.
  - `EIA_API_KEY`: the keyed EIA API (the bulk files are already recorded).
  - `SEC_USER_AGENT` (a name and contact email the human chooses): EDGAR filings and the financial statement data sets, point in time by acceptance time.
  - **Wikimedia pageviews:** its User-Agent policy asks for contact information.
  - **IMF:** "The IMF prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Paid data (human's choice, after the free tier).** Norgate Data US Stocks Platinum (USD 630 a year, confirmed) is the planned purchase for equities and indices (delisted securities, historical constituents). Norgate futures (price unconfirmed) or Databento (usage-based, USD 125 of free credits) would cover commodity contracts. Vendor permission requests are on hold (human, 2026-10-25); the human adds the free API keys to `.keys.env`.
- **On-chain (priority family): hardware and accounts.**
  - **Hyperliquid node:** needs 16 vCPUs, 128 GB of RAM and about 100 GB of logs a day; this PC has 12 threads and 15 GB.
  - **Hyperliquid's archives (`s3://hyperliquid-archive`, `s3://hl-mainnet-node-data`):** requester-pays, so an AWS account and transfer costs.
  - **Ethereum and Polygon on BigQuery:** a Google Cloud account.
  - **Ethereum or Polygon node:** a 2–4 TB NVMe.
- **Sources not certifiable as they stand.**
  - **ClinicalTrials.gov:** no API or automation clause, and silent terms are not enough.
  - **usda.gov:** 403 to our fetcher, not worked around.
  - **MarineCadastre AIS:** its page renders no terms to our fetcher, and its files are GBs a day.
  - **World Bank Pink Sheet:** its file URL changes each release and is linked only from a page whose terms permit no automation; the Data Catalog API and the archived monthly PDFs are to be checked.
  - **EIA hourly grid:** about 699 MB twice a day, beyond the disk.
- **Stage 8 data items:** policy-rate announcement times (BIS series carry effective dates only), ECB YC series and revision policy, the CFTC TFF dataset's history, Treasury average rates' revisions, and the ECB publication calendar.

## Decisions awaiting the human's review

Only decisions that could affect a statistical result or leakage, or that touch the hard limits. Others go straight to `audit/decisions.md`.

None.

## Qualifications

Every criterion failed as written, every labeled amendment and every known limitation, by stage. The text of each, beside its criterion, is in `audit/criteria.md`. Every stage report and the final report cite this list.

- **Stage 0.**
  - The window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC is spent. C0.3 found no late value but its clock instrument was invalid, so the window does not qualify. C0.7 met coverage but exceeded the 3 bps median-excess limit in 7 cells, a failure as written. The revision of 2026-10-21, a post-result amendment, replaced the instrument and the limit. A pass under it is a pass of the amendment.
  - C0.4 amendment (2026-10-22, after a dry C1.4 failed): knownAt is computed from each revision's fields, and `as_of` takes the latest revision before the availability filter.
  - C0.3/C0.7 amendment (2026-10-23): a clock-log gap over 10 minutes restarts the window.
- **Stage 1.**
  - C1.7 amendment (2026-10-23, after a chance failure on a drawn seed): the canary market is a martingale. C1.7 is met only under it.
- **Stage 2.**
  - The locked holdout calibrations v1 and v2.1 failed and stay recorded. v3, the betting test, was adopted by human decision and passed a fresh locked suite.
  - C2.2's first comparison failed on N2 kurtosis because of two errors in my generator. Both were fixed before the passing comparison.
  - The stage 2 searchers state no mechanisms, so the mechanism check is skipped there. Stage 2's power figures therefore overstate what stage 3 will see.
- **Stage 3.**
  - The holdout is [2026-08-01, 2026-09-30), one month after the agent model's June 2026 cutoff (revision of 2026-10-23), and expected power at its 360 steps is about zero. The real campaign is therefore a pipeline validation run, not a test for edge; anything it promotes is confirmed on [2026-11-01, 2027-01-31).
- **Stage 5.**
  - C5.3 failed as written for Discourse. The exit is met under the amendment of 2026-10-22 and its clarification.
  - C5.6's calibration is deferred. It must pass before any search store carries an event dataset, and `criteria/test_stages3to5.py` fails otherwise.
  - The 2026-10-19 migration's predecessor hash was never recorded.
  - Unlocks are a blocked category (no free source).
- **Stage 6.**
  - C6.1 is judged for Lean only, under the amendment of 2026-10-23; Bend's L5 is reported but is not an accepted law.
  - C6.3 is not met.
  - C6.5's effort is a proxy recovered afterwards (same amendment).
  - C6.5's frozen thread configuration is a known limitation under autonomy rule 3, not a pass.
  - C6.4's first two judged runs agreed everywhere but did not qualify: the first corpus was incomplete, and the second compared digests rather than exact streams.
  - L1, L3 and L4 were false as frozen and were revised before their proofs.
- **Stage 10.**
  - C10.4's tolerance was revised during its first differential run, after a one-ulp disagreement was seen.
  - C10.4 was revised on 2026-10-25, before live registration: missing funding had counted as zero in both implementations. It is met on the run after that revision.
