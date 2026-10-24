# Progress

## Now

Commands are `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence under `audit/`; they skip until the evidence exists. Frozen criteria and their revisions: `audit/criteria.md`. Intent: `docs/whitepaper.tex`. Process rules: `CLAUDE.md`.

- **Stage 0 (critical path).** The spent window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC failed C0.7 as written (Qualifications). The window has restarted three times: a recorder outage on 2026-10-22, a host DNS fault at 2026-10-23 06:08 UTC (L2 stalls up to 77 s), and the human's reboot. The local recorders were down from about 2026-10-24 01:45 to 20:13 UTC; the cloud VM recorded HL, the data layer and the stage 5 sources throughout. The new local-only window starts at about 20:13 UTC and ends about **2026-10-25 20:13 UTC**, unless another gap restarts it. `window()` gives the exact end. C0.2, C0.4, C0.5 and C0.9 are met on the second fetch (version 1792613363942, `audit/stage0/ingest-1792613363942.json`).
  - `mm-stage0.timer` (user timer, every 20 min) runs one `flock`-guarded pass of `data/tmp/stage0-close.sh` (untracked). From 2026-10-25 20:20 UTC (16:20 EDT) each pass pulls the cloud host's files and checks `availability.judgment`: the local-only window if it started before the merge threshold (2026-10-24 21:58:13 UTC (17:58 EDT)), else the merged window. Once one is complete it runs `availability` (C0.3), `execution` (C0.7), `witness` (C0.8) and `pytest criteria/test_stage0.py`, then writes `data/tmp/stage0-close.done`. This PC need not be up during the window, only at some time after it.
  - This window starts before the merge amendment's threshold (the VM's clock log reaches 24 h at about 2026-10-24 21:58 UTC), so it is judged on the local recorder alone, exactly as frozen. A failure of C0.2, C0.3 or C0.5 triggers the exit rule.
  - Until the results are reviewed and committed, nothing changes in code the runner imports, and the HL recorder is not restarted (human, 2026-10-23).
- **Reboots of this PC** need no manual step. At login, `mm-recorders-up.service` (`ops/recorders-up.sh`) restarts any local recorder whose pidfile names no live process, and the user timers (`mm-stage0`, `mm-oci-pull`, `mm-diskguard`) resume (`Linger=no`, so they run only while the human is logged in). The cloud VM records throughout, and the next pull catches up.
- **After stage 0 is committed, in order:**
  1. `data/tmp/after-c07.sh` (untracked, resumable): C1.4 and C1.8 into `audit/stage1/`, `freeze-searcher`, then the stage 2 sweeps (`sweep null`, `betas`, `sweep mixed`, `truth`, `probes-top5`, `sweep-summary`). Estimated 2 h, in an 8 GB scope.
  2. `data/tmp/stage10-start.sh`: `recorder-restart data/live 480` (the HL client's 10 s timeout takes effect then; check that the day's polls file still parses), then one uncounted dry main session. Check `harness.audit` against its transcript, then `thesis-freeze` (commit `audit/stage10/manifest.json`), then `thesis-run` detached in its own scope: `setsid systemd-run --user --scope --quiet --unit=mm-thesis-run-$(date +%s) nix develop -c python -m cli thesis-run >> data/thesis/run.log 2>&1 < /dev/null &`. Builder (HIP-3) marks are recorded from then on.
  3. Stage 3: `freeze-harness`, `agent-null agent 20` (paced one campaign per 5 h), `agent-summary`. Stage 4's `agent-null swarm 10` after stage 3's series.
  4. **Stage 3** (revision of 2026-10-23, human decision): the holdout is [2026-08-01, 2026-09-30), 60 days from the reserved `data/holdout/`, and the real campaign is labeled a pipeline validation run, not a test for edge. Expected power is about zero (stated in the criteria). C3.2 mirrors it (holdout from day 670 of 730). The forward window [2026-11-01, 2027-01-31) is a later, separate confirmation for anything promoted.

  5. Code cleanup deferred by the human's timing rule: misplaced scripts (`audit/stage6/effort.py`), criterion- or version-named files, PROGRESS.md citations in the runner-imported files (`criteria/`, the stage 0 `ingest` modules, `cli.py`), `kernel/tests/timing/FORMAT.md` folded into its generator, `oci-cli` into the flake, `duckdb` out of it.
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
- **Redundant recording.** Only the HL recorder is getting a second host. The data layer and the stage 5 sources keep no past versions upstream and run on this PC alone; extending the cloud host to them follows once its HL recorder is stable.
- **Cloud VM (human, 2026-10-23): HL recorder since 21:57 UTC; data layer and stage 5 sources since 2026-10-24 01:43 UTC.** It is an Always Free `VM.Standard.E2.1.Micro` `mm-recorder` in us-ashburn-1 (150.230.168.87; A1 had no capacity), with a $1 budget (`mm-free-tier-guard`).
  - `mm-recorder.service` runs `nix develop .#recorder` at 480/min, capped at 600 MB. `mm-clock.timer` logs the VM's NTP offset every 5 min.
  - `mm-datalayer` and `mm-sources` duplicate this PC's data layer and stage 5 recorders, so a PC outage loses none of their data.
  - This PC pulls all four directories every 10 min (`mm-oci-pull.timer`) into `data/live-oci/<instance>/`; a failed pull adds a Blockers line.
  - Its snapshots count only for windows starting after the merge amendment's conditions hold (`audit/criteria.md`, C0.3/C0.7).
  - Setup and the idle-reclamation risk: `ops/oci/provision.sh`.

## Blockers

- **Free sources that need the human's registration (stages 8 and 10).** Keys go in `.keys.env` (gitignored), one `NAME=value` per line.
  - `FRED_API_KEY` (FRED/ALFRED): macro and rates at the backtest tier's data bar (C8.2), since ALFRED gives each value's vintage and release dates.
  - `BLS_API_KEY`: labor and prices, and the BLS release calendar.
  - `BEA_API_KEY`: NIPA and GDP with release metadata.
  - `EIA_API_KEY`: the keyed EIA API (the bulk files are already recorded).
  - `SEC_USER_AGENT` (a name and contact email the human chooses): EDGAR filings and the financial statement data sets, point in time by acceptance time.
  - **Wikimedia pageviews:** its User-Agent policy asks for contact information.
  - **IMF:** "The IMF prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Paid data (human's choice, after the free tier).** Norgate Data US Stocks Platinum (USD 630 a year, confirmed) is the planned purchase for equities and indices (delisted securities, historical constituents). Norgate futures (price unconfirmed) or Databento (usage-based, USD 125 of free credits) would cover commodity contracts. Permission questions for vendors whose terms are silent are drafted in `docs/permission-requests.md`, for the human to send.
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

- **2026-10-24 20:40 UTC (16:40 EDT): the merge amendment extended to boundary polls, and the cloud recorder raised to 600/min** (`audit/criteria.md`, C0.3/C0.7).
  - **Why:** the human's direction that stage 0 not depend on this PC. The approved merge covered only L2 snapshots, so an outage of this PC at any boundary would still fail C0.3. At 480/min the cloud host's boundary polls fall behind at 4h boundaries.
  - **The rule:** one host per boundary, chosen by completeness, never by which saw the value first, so C0.3's lateness measure is not biased.
  - **GPT:** not asked; the conditions follow the approved merge.
  - **Reverse:** a revision before the merged window is judged, keeping boundary polls local-only.

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
