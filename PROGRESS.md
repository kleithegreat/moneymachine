# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/` (frozen criteria `audit/criteria.md`, decisions `audit/decisions.md`).

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; its clock log holds only errors, Blockers), `datalayer` (`venue/sources/datalayer.json`).
  - `thesis` (`sha256:a2f05c84…`): stage 10, track `thesis-62476ec60a1b` (`audit/stage10/manifest.json`); C10.5's 28-day window counts from its freeze, 2026-10-29 01:25 UTC (2026-10-28 21:25 EDT).
  - Job `agent-series`: stage 3's null series (C3.2), image `sha256:57495a64…`, the pool of TAMU and Cornell tokens, TAMU first, waiting in `wait_for_room` (silent); its log, `mirror/agent/agent-null.jsonl`, is empty until the first campaign.
  - CronJobs `mirror` (10 min) and `mirror-verify` (daily): each volume to `/srv/moneymachine/mirror/<volume>` on this PC, the only copy.
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min, but not Hyperliquid day files in [2026-11-01, 2027-01-31) (`forward-window.exclude`): the VM keeps the only copy (30 GB free, 0.14 GB/day).
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` and the builder wake-ups run only while the human is logged in. Batch Jobs (`ops/jobs.py`, namespace `moneymachine`): none queued; node `desktop` (this PC) NotReady.
- **Budget.** Agent campaigns start only when both windows of a pooled account (TAMU, else Cornell) have room under 0.8.

### Next, in order

1. **Stage 3 series** (critical path). Trigger: room on TAMU (reset about 2026-10-31 04:00 UTC (00:00 EDT)) or Cornell (2026-11-01 05:00 UTC (01:00 EDT)); `agent-series` then starts by itself, and no line in its log after both means a token is failing. No wake-up is scheduled (human, 2026-10-30): on resuming, confirm the first campaign started and estimate the series' end. When it ends: (1) `agent-summary` on this PC (`CLUSTER.md` §2; not a workload); (2) `agent-real`, defined in `ops/live.py` (one attempt, the series' pool and image) but blocked (first Blocker). Once cleared: `python ops/live.py seed sha256:57495a64c33dfaef485ce423749fb65f710e1fbf7a2bbaa3294c93a743db11d4 agent data/store:real/store data/holdout:real/holdout` (safe while the series runs); after the Job `agent-series` completes, `python ops/live.py apply <that digest> agent-real`. One joint holdout release, [2026-08-01, 2026-09-30).
2. **Stage 4 smoke**: `agent-null swarm 10`. Trigger: stage 3's series done.
4. **The next thesis refreeze.** Trigger: any change that forks the track version anyway (each fork restarts C10.5's window). Bundle: delete `ingest/live.py`'s `restart`, `alive` and pidfile (dead since the move); log the benchmark's skips by cause (no reference prices before launch: xyz:XYZ100, xyz:GOLD; delisted: flx:OIL).
5. **Stage 7** (branch `stage7`, worktree `../moneymachine-stage7`; off `main` until the pilot's judged runs are done). Unblocked, below the critical path:
   1. Proofs of the frozen statements (`audit/stage7/laws-frozen.md` there): L5_shape, the L8 resolver laws, L6, then L1–L4 and L7.
   2. The Rust kernel to the same definitions, with the loader rewrite, under the corpus differential.
   3. Then C7.6 (the store's resolver through `knownat`), C7.2 and C7.3 (verifier, policy v2, `mm certify`, `mm bind`, preflight), C7.4 (event feeds as derived sources, baseline), C7.5 (new-feed demonstrations), C7.7 (GPT's declaration red team).
   - Judged runs wait for the rebase onto the pilot's baseline commit.
   - Also: a delisting corpus in a market without a funding gap (C6.4's lost it); before O1 (per-step loss cap B = 0.2, provisional, decision of 2026-10-28), a better-powered B = 1 betting test.
6. **Stage 8 data** (below the critical path): recording only, integrity-only inspection. `audit/stage8/scope-manifest.md` revised 2026-10-31 00:05 UTC (2026-10-30 20:05 EDT; GPT's third review, B1 and B3–B5, with its corrections): no class admitted, every blocker stays; the exposure inventory must be complete before any annex. Databento GLBX.MDP3 is complete for the plan (USD 34.48 spent; only the sign-up credit, at most USD 100, is allowed); ICE (also Databento) only if credit remains, after its licence (Blockers). Unblocked: recording OECD's STES revisions (certified; about 357 MB a country quarterly). Open: `includeHistory` (needs a class annex); BLS and BEA archived release pages need terms quotes.
7. **When stage 7 nears its exit**: the Lean engine stage's criteria (decision of 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT)). **When stage 7 lands on `main`**: the repo-wide erasure pass (same entry).
8. **Parked (human):** a meta-process review: does the project's execution follow the intent of the first web chat? (`ctx`, its origin import.)

Open, status unclear: a research arm whose model has an earlier knowledge cutoff, freeing more historical holdout (the human, 2026-10-23).

### Finished

- Stage 0: exited 2026-10-26 with C0.7 qualified, by human decision (`audit/stage0/criteria-result.txt`). Stage 1: done 2026-10-26 (`audit/stage1/`).
- Stage 2: exited 2026-10-28 with C2.6 waived, by human decision (`audit/stage2/exit-r2.md`).
- Stage 3's preparation: erasure pass, harness freeze, C0.7 regime diagnostic (`audit/erasure/`, `audit/diagnostics/`).
- Stage 5: exited under C5.3's amendment (`audit/stage5/`). Stage 6: exited 2026-10-23 with Lean adopted, human-reviewed (`audit/stage6/report.md`).
- The move to the cluster: recorders handed off 2026-10-29 (`audit/cluster/handoff.md`).

## Blockers

- **`agent-real` can spend the holdout without a valid result** (found 2026-10-30; five cases and the redesign in `audit/stage3/real-blockers.md`): the report path is read-only in the pod, after the claim; arm A's run is unchecked before a joint release; a crash after the claim has no recovery; the claim is per store, not seen by this PC's copy. Do not start it until fixed.
- **The cluster's clock log holds only errors.** `ingest/sources_record.py`'s clock job calls `timedatectl`, which the image lacks, and a pod may not read the node's NTP state. Deriving the record from Hyperliquid L2 polls (snapshot `time` against the send/receive midpoint) would change what C0.3's clock check measures: it is the instrument `audit/criteria.md` rejected in C0.3's 2026-10-22 revision (it mixes snapshot age, offset and network timing), and the 2026-10-23 merged-window clause requires "each host's NTP record". Not built. Needs a reviewed amendment of C0.3's clock instrument, or an NTP state a pod can read (a node-side sidecar); then point `ntp_readings`' consumers (`availability.merge`, `sources_avail`) at the new record, delete the `timesyncd` job and `ops/oci/clocklog.py` (stop the VM's `mm-clock.timer` first). Until then a merge including the cluster as a host drops all its polls. No frozen manifest hashes these files.
- **FRED and ALFRED: the API terms forbid our use; the human decides.** https://fred.stlouisfed.org/legal/ (read 2026-10-26): clause (l) forbids "storing, caching, or archiving" FRED content or "incorporating any FRED® Content in any database", and (k) use "in connection with the development or training of ... machine learning, including ... large language models". Our store is a database agents read. Key unused; no permission request for now (human). Macro vintages come from the Philadelphia Fed's RTDSM.
- **IMF** "prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Stage 8 purchases, the human decides** (`audit/stage8/sources-survey/combined-plan.md`; kernel-only): Norgate US Stocks Platinum (USD 630 a year plus a Windows VM, licence unverified) or Massive Stocks Advanced (USD 199 a month, no index constituents).
- **ICE via Databento:** its non-display licence is unclear; ICE stays out until the human settles it.
- **On-chain: hardware.** A Hyperliquid node: 16 vCPUs, 128 GB RAM, 100 GB of logs a day; Ethereum or Polygon: 2–4 TB NVMe.
- **Not certifiable as they stand:** ClinicalTrials.gov (no automation clause); usda.gov (403); MarineCadastre AIS (no terms; GBs a day); World Bank Pink Sheet (per-release URL on a page forbidding automation; its Data Catalog API unchecked); EIA hourly grid (about 699 MB twice a day).
- **Stage 8 data gaps:** policy-rate announcement times (BIS: effective dates only), ECB YC series and revisions, CFTC TFF history, Treasury average rates' revisions, the ECB release calendar.

## Decisions awaiting the human's review

None.

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. Amendments: C0.4 (2026-10-22: knownAt from each revision's fields, `as_of` takes the latest revision before the availability filter); C0.3/C0.7 (2026-10-23: a clock-log gap over 10 minutes restarts the window). The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells (BTC sell $1k 0.894, SUI sell $10k 0.882, kPEPE sell $10k 0.817); every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (the B = 1 bound is examined in stage 7). Locked calibrations v1 and v2.1 failed; v3, the betting test, adopted by human decision, passed a fresh suite. C2.2's first comparison failed from two generator errors, fixed before the pass. Its searchers state no mechanisms, so its power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed (about 30% of snapshots matched within 1 s, 50% required), so C0.7's table, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B.
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (`criteria/test_stages3to5.py` enforces it); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run (the first two: incomplete corpus; digests, not streams); L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after.
