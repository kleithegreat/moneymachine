# Progress

## Now

Commands are `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence under `audit/`; they skip until the evidence exists. Frozen criteria and their revisions: `audit/criteria.md`. Intent: `docs/whitepaper.tex`. Process rules: `CLAUDE.md`.

- **Stage 0: exited 2026-10-26 with C0.7's coverage failure as a recorded qualification** (human decision, `audit/decisions.md`). The cloud-only window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC was judged at 09:48 UTC (05:48 EDT) (`audit/stage0/criteria-result.txt`): C0.3 and C0.8 pass, C0.2, C0.4, C0.5 and C0.9 were met on the second fetch, and C0.7 failed coverage in 3 of 44 cells. `criteria/test_stage0.py::test_c07_execution_model` keeps failing, as it should: it reports the recorded result.
- **Fixes from GPT's whole-project review of 2026-10-24** (reply: `~/.cache/mm-gpt/project.XShA/reply.txt`; each finding checked against the code by a subagent). The fixes gating the sweeps, stage 3, stage 4 and the stage 10 start are done (`audit/decisions.md`, 2026-10-24 and 25). Still to do:
  - **Done:** branch `post-stage0`, merged 2026-10-26 (corrections known when fetched, `Store` reads its own `policy.json`, Rust skips tombstones, missing settlement data aborts, funding at the latest bar opened by its hour and only on listed hours, I5 relative). Before the merge, the stage 6 corpus differential on it agreed on all 1,196 verdicts and 3,372 runs. The frozen C6.4 corpus no longer covers delisting: the edge market's E2 has a deliberate 30-hour funding gap, which now aborts every run holding E2 before E3 delists (with the gap filled, 841 delistings and no aborts). A stage 7 corpus needs delisting in a market without a funding gap.
  - **Stages 7–9:** delisting becomes a record with its own knownAt (C8.1); the pilot's last-traded-bar rule is pre-registered and touches only FTM in the search period.
- **Reboots of this PC** need no manual step. At login, `mm-recorders-up.service` (`ops/recorders-up.sh`) restarts any local recorder whose pidfile names no live process, and the user timers (`mm-oci-pull`, `mm-diskguard`) resume (`Linger=no`, so they run only while the human is logged in). The cloud VM records throughout, and the next pull catches up.
- **After stage 0 is committed, in order** (priorities of CLAUDE.md §3 and the human's decisions of 2026-10-26):
  0. **The C0.7 regime diagnostic** (human-approved 2026-10-26, within the $20 budget; a labeled diagnostic that decides nothing; `python -m ingest.archive diagnostic` in the `cloud` shell): for each coin of U and every archive day it is listed, except stage 3's holdout [2026-08-01, 2026-09-30), hours 0, 6, 12 and 18 UTC of Hyperliquid's archived books, costed per C0.7 cell by C0.7's own function. Regimes are terciles of each coin's daily realized volatility, measured on those books' own mid prices, and calendar quarters. (Changed before any download from "our 4h bars": after 2026-04-03 those bars are in the holdout store, which only the gate reads.) Reported per coin, cell and regime: the share of snapshots costing more than the table, and the ratio of the regime's quantile to the table. A snapshot whose 20 levels cannot fill the order is counted as censored, never given a cost: the archive lacks the aggregated book C0.7 falls back to. About 8 GB, $0.75. Running since 2026-10-26 09:54 UTC (05:54 EDT), log `data/archive/diagnostic.log`.
  1. **Stage 2.** `data/tmp/after-c07.sh` (untracked, resumable, fail-closed: it starts once stage 0 has exited, by its criteria or by the human's acceptance of C0.7's qualification in `audit/decisions.md`, and its outputs are committed) skips C1.4 and C1.8, judged under stage 1, and runs `freeze-searcher`, then the sweeps (`sweep null`, `betas`, `sweep mixed`, `truth`, `probes-top5`, `sweep-summary`); estimated 2 h, in an 8 GB scope. Two checks come before reading the sweeps:
     - how often I10's loss cap binds in the null sweeps (`bankrupt` per campaign and in `null_summary`), since limited liability can give a leveraged strategy a positive expected return under a true null (NULLS.md);
     - the stage 2 report gives the power curve with intervals and the test-alone power, and states that the pilot cannot confirm ordinary edges at this holdout length (C2.6 amendment of 2026-10-26).

     Then the stage 2 exit is judged and reviewed.
  2. **Stage 3:** the archive cost table lapsed: its frozen equivalence check failed on 2026-10-26 (`audit/stage3/archive-equivalence.json`), so stage 3 uses C0.7's table with its qualification. Then `freeze-harness`; then `agent-null agent 20` (C3.2, paced one campaign per 5 h, about 4 days, holdout from day 670 of 730); then `agent-summary`; then the real two-arm campaign (`agent-real`, C3.3/C3.4) with one joint holdout release on [2026-08-01, 2026-09-30). It is a pipeline validation run, not a test for edge. Its promotions are qualified ("historical holdout, costs fitted after it") and confirmed only on [2026-11-01, 2027-01-31).
  3. **Stage 4:** `agent-null swarm 10` after stage 3's series.
- **Stages 1, 2, 5, 6, 10.**
  - **Stage 1:** done 2026-10-26. Every criterion's evidence ran at clean commit dbe192b (`audit/stage1/c1*.txt`), and GPT's five exit reviews (`audit/stage1/exit-review-gpt-1.md` to `-5.md`) found C1.1 to C1.8 met. Along the way: a second red-team round, admitted programs split from the rejection suite, complete hand-computed accounts, the full ordered trace compared in C1.4, GPT's checker reimplemented from the paper and INVARIANTS.md alone, and production costs in the canary.
  - **Stage 2:** done except the sweeps; calibration v3 passed.
  - **Stages 5 and 6:** done (Qualifications).
  - **Stage 10:** running since 2026-10-26 15:21 UTC (11:21 EDT) as track version `thesis-34a49c19a8f9` (`audit/stage10/manifest.json`; `thesis-run` detached, log `data/thesis/run.log`), on C0.7's committed table with its qualification (human-approved). The dry main session's audit matched after the transcript audit was fixed to count client invocations in commands that ran; the real track's market cache was seeded from the dry run's public-data cache and response archive.
- **GPT: unavailable since about 17:20 UTC (13:20 EDT), 2026-10-26 (ChatGPT usage limit).** Retry the probe every few hours. Queued for its return:
  - the live `execute` probes under the old and new configs (`audit/gpt-sandbox/findings.md`; directories `~/.cache/mm-gpt/probe-*`, canary in `~/.cache/mm-gpt-canary/`);
  - a clean reimplementation of the derived event counts from `derived.md` alone, differential-tested against ours (the C5.5 run `derived3` read PROGRESS.md);
  - GPT's review of the stage 8 scope manifest's revision of 2026-10-26.
- **Stage 8 data sources (human, 2026-10-26; below the critical path).** The documentation-only survey is in `audit/stage8/sources-survey/`, and the scope manifest has a dated revision from it (selection rule 1 superseded: accounts are fine under the human's name; the licensing boundary and a role rule, paper (Multi-asset research) and `audit/decisions.md`), reviewed by a fresh-context Opus agent with GPT's review queued. Next, as data-layer work, certify and record (no inspection beyond integrity until a class annex):
  - **done 2026-10-26:** the Federal Reserve Board's Data Download Program, certified (`fed-ddp`) and recorded by the data layer on this PC: 457 preformatted packages of H.15, H.10, G.17, Z.1 and policy rates (daily; Z.1 weekly) and each release's whole SDMX file (monthly; Z.1 quarterly), first pulled 17:4x UTC with every response 200;
  - NY Fed reference rates; the Treasury par yield XML feed, only if the terms rule is met; OECD STES revisions, after reading their terms; the ECB Real-Time Database and `includeHistory`; BLS and BEA archived releases and schedules.
- **Stages 7 to 9:** criteria frozen. Stage 7 is being built on branch `stage7`, worktree `../moneymachine-stage7` (human, 2026-10-26); its kernel changes stay off `main` until the pilot's judged runs are done.
  - **Done there:** the rule language spec (`kernel/RULES.md` v1, reviewed by GPT and a labeled Opus review) with its frozen C7.6 suite, implemented in Python (`ingest/knownat.py`) and Rust (`mm rules`); GPT's independent implementation agrees on all 2,118 cases (development run). Declarations (`kernel/SOURCES.md` v1, with evidence declarations) and certificates (`kernel/CERTIFICATES.md` v1), both revised from GPT's review; the declaration reader and registry (`mm::source`); the two venue feeds declared.
  - **Also done:** the C7.4 migration annex, revised from GPT's review and frozen later with its migration manifest; the resolver suite (C7.6: 30 hand cases and 1,200 generated queries, frozen first) with Python, Rust and GPT's independent resolvers agreeing on all 332 cases (development run). GPT's review of the draft certification policy (`audit/stage7/policy-review-gpt.md`) found it unfreezable as prose: its tests become verifier code, and the policy pins that code and its parameters, freezing with the verifier.
  - **Next:** after the rebase onto main, the kernel generalization, the verifier and its policy, and the event feeds' lineage.
  - **Judged runs** wait for the rebase onto the pilot's baseline commit. Stage 8's scope manifest is committed (`audit/stage8/scope-manifest.md`).
- **Recorders.** All are restarted only with `recorder-restart <out_dir> [budget]`.
  - **HL, local:** `data/live`, 600/min until the window closes, then 480/min.
  - **Stage 5 sources:** `data/sources_live`, delvingbitcoin.org, Snapshot and the clock log.
  - **Data layer:** `data/datalayer`, from 2026-10-23 18:39 UTC. Feeds are declared in `venue/sources/datalayer.json`, each certified in `venue/sources.toml`: ECB, BIS, CFTC, Treasury, GDELT, NWS, openFDA, EIA, Polymarket, BLS, BEA, SEC and the Philadelphia Fed's RTDSM. Keyed feeds read `.keys.env`, and a host without a feed's key skips it. Bodies are gzip-compressed under `raw/<sha256>.gz`. A source without past versions is prospective only.
- **Data.** `data/` is about 650 MB with 105 GB free, and the hourly `mm-diskguard.timer` (`ops/diskguard.sh`) adds a Blockers line below 20 GB. Regenerable and duplicate files were deleted with their hashes in `audit/data-deletions.json`. After stage 0: `live.read` learns `.jsonl.zst`, and closed day files (about 410 MB of polls) are compressed with zstd once their plain sha256s are recorded in `audit/`.
- **Keyed sources and cloud accounts (human, 2026-10-26).** `.keys.env` holds FRED, BLS, BEA, EIA and `SEC_USER_AGENT`; contact fields use the human's name and email (CLAUDE.md). BLS, BEA, EIA and SEC are certified and recorded; FRED is blocked (Blockers), and macro vintages come from the Philadelphia Fed's Real-Time Data Set. AWS (IAM user `hyperliquid-data`, S3 read-only, us-east-1, $20 a month, denied at 100%; spending approved up to $20 in total) is for Hyperliquid's requester-pays archives: list and report before any download. Google Cloud (project `moneymachine-512800`, BigQuery sandbox, no billing) is for `crypto_ethereum` and `crypto_bitcoin`.
- **Language plan (human, 2026-10-26).** The pilot (stages 0–3 and 10) stays on the current stack, and stage 7 finishes as specified. Between stages 7 and 8 comes a new stage: an executable Lean engine whose laws are proved on the running code, bit-identical to `mm` on the frozen corpus, with OCaml for untrusted plumbing. Parquet stays the data format, read from OCaml through DuckDB's C API or Arrow, and SQLite stays the ledger. Then `mm` and the Python are deleted, and stage 8's generalization is written once, in Lean. Its criteria and a paper revision are drafted when stage 7 nears its exit, not before. Feasibility diagnostic (branch `lean-bench`, 2026-10-26 05:27 UTC): a performance-oriented Lean engine, `fastmm`, runs W0 in 33.3 ms (mm 16.0, the Lean reference 660) and matches mm bit for bit on all 3,372 corpus runs. What it showed for the stage's criteria: the fast code is unproved, so laws need a refinement proof against the reference or a standing differential; bit-identity requires no fused multiply-add and mm's libm; in-place array updates silently become copies when an array is shared, so the criteria should bound speed, not just correctness.
- **Future option (human, 2026-10-23):** a research arm whose model has an earlier knowledge cutoff, which would free more historical holdout data than the current model's June 2026 cutoff allows.
- **Cloud VM (human, 2026-10-23): HL recorder since 21:57 UTC; data layer and stage 5 sources since 2026-10-24 01:43 UTC.** It is an Always Free `VM.Standard.E2.1.Micro` `mm-recorder` in us-ashburn-1 (150.230.168.87; A1 had no capacity), with a $1 budget (`mm-free-tier-guard`).
  - `mm-recorder.service` runs `nix develop .#recorder` at 600/min (the stage 0 budget, from its own IP; raised 2026-10-24 20:35 UTC (16:35 EDT)), capped at 600 MB. `mm-clock.timer` logs the VM's NTP offset every 5 min.
  - `mm-datalayer` and `mm-sources` duplicate this PC's data layer and stage 5 recorders, so a PC outage loses none of their data.
  - This PC pulls all four directories every 10 min (`mm-oci-pull.timer`) into `data/live-oci/<instance>/`; a failed pull adds a Blockers line.
  - Its snapshots count only for windows starting after the merge amendment's conditions hold (`audit/criteria.md`, C0.3/C0.7).
  - Setup and the idle-reclamation risk: `ops/oci/provision.sh`.

## Blockers

- **FRED and ALFRED: the API terms forbid our use; the human decides (2026-10-26).** The key is in `.keys.env` but unused. The "Additional Terms of Use for the FRED® API" (https://fred.stlouisfed.org/legal/, read 2026-10-26) say you may not "(l) Use the FRED® API in connection with storing, caching, or archiving any portion of the FRED® Services or FRED® Content; ... or incorporating any FRED® Content in any database, compilation, archive, cache, or other medium", nor "(k) ... in connection with the development or training of any software program or system or machine learning, including, but not limited to, large language models ...". Our point-in-time store is a database, and research agents read it. ALFRED's vintages would have given macro series the backtest tier's data bar (C8.2); no permission request for now (human, 2026-10-26). Macro vintages come instead from the Philadelphia Fed's Real-Time Data Set (certified 2026-10-26, research use; `venue/sources.toml`).
- **IMF:** "The IMF prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Purchases for stage 8: the human decides which, if any (2026-10-26).** From the source survey (`audit/stage8/sources-survey/combined-plan.md`); each is kernel-only under the licensing boundary (`audit/decisions.md`, 2026-10-26).
  - **Databento** (CME futures, GLBX.MDP3 from June 2010: definitions, settlements and open interest, optional daily bars, about 35 roots): about USD 6–25 of the USD 125 sign-up credit, about 5 GB, Linux-native. The exact cost comes from the free `metadata.get_cost` call before any pull.
  - **Norgate US Stocks Platinum** (delisted from 1990, permanent ids, raw prices, corporate actions, daily index membership): USD 630 a year, plus a Windows VM (licence unverified), since its software and Python package are Windows-only.
  - **Massive Stocks Advanced** (from 2003, delisted tickers with an as-of registry, dividend declaration dates, FIGI and CIK; no index constituents): USD 199 a month.
- **On-chain (priority family): hardware.** A Hyperliquid node needs 16 vCPUs, 128 GB of RAM and about 100 GB of logs a day (this PC has 12 threads and 15 GB); an Ethereum or Polygon node needs a 2–4 TB NVMe.
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
  - The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells (BTC sell $1k 0.894, SUI sell $10k 0.882, kPEPE sell $10k 0.817). Stage 0 exited with it as a qualification, by human decision; every result that uses the cost table, stage 2's sweeps, stage 3 and stage 10 included, carries it.
- **Stage 1.**
  - C1.7 amendment (2026-10-23, after a chance failure on a drawn seed): the canary market is a martingale. C1.7 is met only under it.
  - C1.6 is judged against the paper's experiment identity as it stood at C1.6's freeze; certificate and extractor versions, added to the paper later that day for stage 5's sources, have no ledger columns in the pilot kernel.
  - C1.3's hand-computed values are compared to 1e-9, since decimal hand arithmetic is not exactly representable in binary floating point.
- **Stage 2.**
  - The locked holdout calibrations v1 and v2.1 failed and stay recorded. v3, the betting test, was adopted by human decision and passed a fresh locked suite.
  - C2.2's first comparison failed on N2 kurtosis because of two errors in my generator. Both were fixed before the passing comparison.
  - The stage 2 searchers state no mechanisms, so the mechanism check is skipped there. Stage 2's power figures therefore overstate what stage 3 will see.
- **Stage 3.**
  - The archive cost table (revision of 2026-10-26) lapsed: its frozen equivalence check matched about 30% of each coin's live snapshots within 1 s, against 50% required, because the archive's books are 5.4 s apart. Stage 3 uses C0.7's table, qualified.
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
