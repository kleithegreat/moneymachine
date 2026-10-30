# Progress

Current state only; history is in git. Commands: `nix develop -c python -m cli <command>` (`-h` lists them). Criteria checks are tests in `criteria/` over evidence in `audit/` (frozen criteria `audit/criteria.md`, decisions `audit/decisions.md`).

## Now

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders (`sha256:97b2817f…`): StatefulSets `hl` (480/min), `sources` (delvingbitcoin.org, Snapshot; its clock log holds only errors, Blockers), `datalayer` (`venue/sources/datalayer.json`).
  - `thesis` (`sha256:a2f05c84…`, shared with `agent-series`): stage 10, track `thesis-62476ec60a1b` (`audit/stage10/manifest.json`); C10.5's 28-day window counts from its freeze, 2026-10-29 01:25 UTC (2026-10-28 21:25 EDT).
  - Job `agent-series`: stage 3's null series (C3.2), waiting in `wait_for_room` for a window (`a2f05c84…` uses Cornell only; the pool of Cornell and TAMU tokens, TAMU first is in `main` but undeployed, see Blockers); its log (`mirror/agent/agent-null.jsonl`) is empty until the first campaign.
  - CronJobs `mirror` (10 min) and `mirror-verify` (daily): each volume to `/srv/moneymachine/mirror/<volume>` on this PC, the only copy.
- **Oracle VM** `mm-recorder` (150.230.168.87; `ops/oci/`): Hyperliquid at 600/min, data layer, stage 5 sources, `mm-clock.timer`. `mm-oci-pull.timer` pulls it into `data/live-oci/` each 10 min.
- **This PC** records nothing; `data/live`, `data/sources_live` and `data/datalayer` are closed hosts, kept as stage 0's judged evidence. User timers `mm-oci-pull`, `mm-diskguard` (hourly; a Blockers line below 20 GB free) and the builder wake-ups run only while the human is logged in. Batch Jobs (`ops/jobs.py`, namespace `moneymachine`): none queued; node `desktop` (this PC) NotReady.
- **Budget.** Sessions on this PC run on the human's personal account (kevvinlei89@gmail.com), with no cap of ours. Agent campaigns start only when both windows of a pooled account (TAMU, else Cornell) have room under 0.8. Cornell read 0.92 (seven-day) at 2026-10-29 01:24 UTC (2026-10-28 21:24 EDT) (`audit/cluster/gate-unmasked.json`), resetting 2026-11-01 05:00 UTC (01:00 EDT).

### Next, in order

1. **Stage 3 series** (critical path). Trigger: the Cornell reset; `agent-series` then starts by itself. No wake-up is scheduled (human, 2026-10-30): the human resumes after it; then confirm the first campaign started and estimate the series' end. When it ends: `agent-summary`, then the real two-arm campaign `agent-real` (C3.3, C3.4), one joint holdout release on [2026-08-01, 2026-09-30); only `agent-series` is a cluster workload, so `agent-real` needs one there to run on the Cornell token.
2. **Stage 4 smoke**: `agent-null swarm 10`. Trigger: stage 3's series done.
4. **The next thesis refreeze.** Trigger: any change that forks the track version anyway (each fork restarts C10.5's window). Bundle: delete `ingest/live.py`'s `restart`, `alive` and pidfile (dead since the move); log the benchmark's skips by cause (xyz:XYZ100, xyz:GOLD: no reference prices before launch; flx:OIL: delisted), not "missing daily close".
5. **Stage 7** (branch `stage7`, worktree `../moneymachine-stage7`; off `main` until the pilot's judged runs are done). Unblocked, below the critical path:
   1. Proofs of the frozen statements (`audit/stage7/laws-frozen.md` there): L5_shape, the L8 resolver laws, L6, then L1–L4 and L7.
   2. The Rust kernel to the same definitions, with the loader rewrite, under the corpus differential.
   3. Then: the store's resolver through `knownat` (C7.6); the verifier, policy v2, `mm certify`, `mm bind`, preflight (C7.2, C7.3); event feeds as derived sources and C7.4's baseline; new-feed demonstrations (C7.5) and GPT's declaration red team (C7.7).
   - Judged runs wait for the rebase onto the pilot's baseline commit.
   - Also: a delisting corpus in a market without a funding gap (C6.4's lost it); before O1 (per-step loss cap B = 0.2, provisional, decision of 2026-10-28), a better-powered B = 1 betting test.
   -
6. **Stage 8 data** (below the critical path): recording only, integrity-only inspection. `audit/stage8/scope-manifest.md` authorizes research use only after GPT's findings B1 and B3–B5 (`manifest-review-gpt-2.md`) close. Its re-review (`manifest-review-gpt-3.md`, 2026-10-30): all four still partly closed; not yet evaluated. Databento GLBX.MDP3 is complete for the plan (USD 34.48 spent; only the sign-up credit, at most USD 100, is allowed); ICE (also Databento) only if credit remains, after its licence (Blockers). Unblocked: recording OECD's STES revisions (certified; about 357 MB of CSV per country quarterly). Open: `includeHistory` (needs a class annex); BLS and BEA archived release pages need terms quotes.
7. **When stage 7 nears its exit**: the Lean engine stage's criteria and paper revision (decision of 2026-10-30 01:30 UTC (2026-10-29 21:30 EDT)). **When stage 7 lands on `main`**: the repo-wide erasure pass (same entry).

Open, status unclear: a research arm whose model has an earlier knowledge cutoff, freeing more historical holdout (the human, 2026-10-23).

### Finished

- Stage 0: exited 2026-10-26 with C0.7 qualified, by human decision (`audit/stage0/criteria-result.txt`). Stage 1: done 2026-10-26 (`audit/stage1/`).
- Stage 2: exited 2026-10-28 with C2.6 waived, by human decision (`audit/stage2/exit-r2.md`).
- Two criteria tests fail by design, reporting those failures: `criteria/test_stage0.py::test_c07_execution_model` and `criteria/test_stage2.py::test_c26_power_amended`.
- Stage 3's preparation: erasure pass, harness freeze, C0.7 regime diagnostic (`audit/erasure/`, `audit/diagnostics/`).
- Stage 5: exited under C5.3's amendment (`audit/stage5/`). Stage 6: exited 2026-10-23 with Lean adopted, human-reviewed (`audit/stage6/report.md`).
- The move to the cluster: recorders handed off 2026-10-29 (`audit/cluster/handoff.md`).

## Blockers

- **The TAMU token is not deployed.** `gate/agent/campaigns.py` and `ops/live.py` now give the series both tokens (secret `claude-token` key `TAMU`; `deployer` cannot read Secrets, so unverified). When the human has added it: build the image, `python ops/live.py` apply `agent-series` only (not `thesis`),, confirm `harness_hash()` is still `c0565744d6ca`.
- **The cluster's clock log holds only errors.** `ingest/sources_record.py`'s clock job calls `timedatectl`, which the image lacks, and a pod may not read the node's NTP state. Deriving the record from Hyperliquid L2 polls (snapshot `time` against the send/receive midpoint) would change what C0.3's clock check measures: it is the instrument `audit/criteria.md` rejected in C0.3's 2026-10-22 revision (it mixes snapshot age, offset and network timing), and the 2026-10-23 merged-window clause requires "each host's NTP record". Not built. Needs a reviewed amendment of C0.3's clock instrument, or an NTP state a pod can read (a node-side sidecar); then point `ntp_readings`' consumers (`availability.merge`, `sources_avail`) at the new record, delete the `timesyncd` job and `ops/oci/clocklog.py` (stop the VM's `mm-clock.timer` first). Until then a merge including the cluster as a host drops all its polls. No frozen manifest hashes these files.
- **FRED and ALFRED: the API terms forbid our use; the human decides.** https://fred.stlouisfed.org/legal/ (read 2026-10-26): clause (l) forbids "storing, caching, or archiving" FRED content or "incorporating any FRED® Content in any database", and (k) use "in connection with the development or training of ... machine learning, including ... large language models". Our store is a database agents read. Key unused; no permission request for now (human). Macro vintages come from the Philadelphia Fed's RTDSM.
- **IMF** "prohibits bulk download of information by automated technology without explicit permission" (https://www.imf.org/en/About/copyright-and-terms, 2026-10-23).
- **Stage 8 purchases, the human decides** (`audit/stage8/sources-survey/combined-plan.md`; kernel-only): Norgate US Stocks Platinum (USD 630 a year plus a Windows VM, licence unverified) or Massive Stocks Advanced (USD 199 a month, no index constituents).
- **ICE via Databento:** its non-display licence is unclear; ICE stays out until the human settles it.
- **On-chain: hardware.** A Hyperliquid node: 16 vCPUs, 128 GB RAM, about 100 GB of logs a day; Ethereum or Polygon: 2–4 TB NVMe.
- **Not certifiable as they stand:** ClinicalTrials.gov (no automation clause); usda.gov (403); MarineCadastre AIS (no terms; GBs a day); World Bank Pink Sheet (per-release URL on a page forbidding automation; its Data Catalog API unchecked); EIA hourly grid (about 699 MB twice a day).
- **Stage 8 data gaps:** policy-rate announcement times (BIS: effective dates only), ECB YC series and revisions, CFTC TFF history, Treasury average rates' revisions, the ECB release calendar.
- **Paper vs language plan:** paper §6 keeps the production engine; the plan is a Lean engine with OCaml (`audit/decisions.md`, 2026-10-26; human, 2026-10-30). Revise the paper.

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
