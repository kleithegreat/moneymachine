# Progress

Current state only; history is in git. The pilot's code is at `archive/pilot` (2026-11-22); `main` holds the live recorders, the mirror and guard, the archive reader, `reference/lean`, and the specs.

## Now
- **Overnight 2026-11-24 (the human asleep; up to two GPT reviews, everything else on Claude, no Neon; one Opus agent at a time after a usage cutoff at 00:20 to 05:20 EST, the Python review resuming after round 19):** study 2 round 19 → GPT reviews it (1 of 2) and a fresh Opus architects kernel round 18 (study 2's routed points and `audit/reviews/2026-11-24-opus-round17-kernel.md`); round 19's GPT review → study 2 round 20 → GPT's second review if one remains worth it, else a fresh Opus. A usage cutoff: resume the agent after the reset. Clean up worktrees, jails and Downloads after each.

### Running, and how to inspect it

- **Cluster, live** (prodesk7, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders: StatefulSets `ws` (OCaml `mmrec`, `recorder/RECORDER.md`: every Hyperliquid perp, about 2.0 GB a day, one copy on PVC `ws`), `sources`, `datalayer`; CronJob `vault` (`mmvault`, hourly). `hl` retired 2026-11-22 (its PVC kept).
  - The mirror CronJobs; prodesk7 also builds test checks as a remote builder (`CLUSTER.md` §6).
- **Oracle VM:** terminated 2026-11-22 after every file was verified here; its forward-window days are embargoed in `~/embargo/oci-forward-window/` (integrity only until the window ends).
- **This PC** records nothing; `data/live`, `data/sources_live`, `data/datalayer` and `data/live-oci` are closed hosts, kept as evidence. User timers run only while the human is logged in.
- **Models:** architect a fresh Opus 5.5 at maximum effort, or Neon through agy (`ops/agy-write.sh`); GPT through `ops/gpt.sh` (`gpt-6.2-sol`), its weekly budget kept for what matters (the human); Neon reviews through the web UI (bundles in `~/Downloads`).
- **Worktrees:** `main`; `../mm-program` (`rearchitecture`, the kernel half); `../mm-program-s2` (`rearchitecture-s2`, study 2's half); `../mm-k2` (`kernel2-build`); `../mm-k2-step5` (`kernel2-step5`); `../mm-rec-urgent` (`recorder-urgent`, held); `../mm-python-plan` (`python-extinction`); one per agent.

### Work in progress

Roles and laws: `CLAUDE.md`. The project is academic: no live trading.

1. **Study 2, the positive control of the confirmer:** the replication of vault `0x53375ca9…2a06`, frozen and tested forward (criteria committed, `criteria: study 2`, `a324059`; CS2.1 revised `a903317`; the program in `audit/program/`, `ledger.md` listing what is agreed and disputed).
   - **Kernel half:** round 18 done (a fresh Opus, `rearchitecture` `5dedbc6`, answering the fresh Opus's review of round 17 and folding in study 2's rounds 18 and 19): the run's records one list in A18's order (a millisecond's steps, then its tick, then its arrivals); the listing-end window closes before e + 1 h; the reader feeds items in A3's order; A18 the readers' one home; about 21 KB cut; `checks.mm2-tests` still failing its two timing tests from round 17. GPT's review (`audit/reviews/2026-11-24-gpt62-round18-kernel.md`, 2 of 2, the boundary out of scope): the one ordered record list accepted; not converged (the evaluator's inputs unbound to the view; each move's cause read from the millisecond's end market; F0's domain and funding after a same-time liquidation; bankruptcy and R1; the listing end discards boundary evidence and trusts flag-caused silence; the run id's tie-break across restarts; cut against corrupt streams). **Round 19, kernel:** a fresh Opus, running (`data/builder/architect-r19-kernel-report.md`), with study 2's round 20 kernel items.
   - **Study 2 half:** round 20 done (a fresh Opus, `rearchitecture-s2` `86aa583`, D361 to D370, answering GPT's round 19 and kernel round 18 reviews): a REST reply dated by its two clocks (a copy effective from the later, a pull dated by the earlier; the one-hour check deleted); silence counts only where a stored venue reply covers it (the funding end at E deleted; our failures still hold); a listing ends only on the flag, no unflagged copy within the hour, two hours' silence closed at both ends and the venue's replies covering it; four stream states; brief 4 85 to 86 KB. Not reviewed (GPT's two overnight reviews spent; Neon or GPT next). Owed before the freeze: `recorder/src/writer.ml`'s run id from the wall clock, `recording.ml`'s `exception _` treating corrupt streams as cut.
   - **Kernel version 2** (`audit/program/kernel-v2.md`, brief 3): steps 0 to 5 built; B4 passes on step 5 (3,120 of 3,120). Test 12 is too slow (15 days a host); step 5x (the incremental exact series, law X6) waits on the boundary converging. Step 5 merges after step 5x passes test 12 and B4.
   - **The urgent recorder fix** (`recorder-urgent`) waits for study 2's libcurl and `jsont` client to converge; GPT's review is kept for it.
2. **The paper** ("The Confirmation Wall in Agentic Trading Research"): free-standing, with study 1's section merged; each study's result is added as it reports.
3. **Python's extinction** (the human, 2026-11-22): about 4,600 lines remain (`ingest/{sources_record,datalayer,live,terms,archive,compute}.py`, `ops/{live,diskguard,style}.py` and their tests). Planned (`audit/program/python-extinction.md` on `python-extinction`, `59b6543`): retire `sources`, seal `hl`/`thesis`/`agent` off the mirror, port the datalayer (`mmdata`) and the mirror and guard (`mmops`) to OCaml in `recorder/`, the deployer into the flake; the archive reader goes with kernel version 2's K1. Revised after Neon's eight findings (`audit/reviews/2026-11-23-neon-python-extinction.md`; revision 2 `a524c1c`, four rows still disputed): a fresh Opus reviews it (running, `data/builder/opus-python-extinction-review.md`), steps 0 to 2 being untouched by the disputes. Nothing irreversible (retiring `sources`, the R1 review) before it converges. `mmdata` must retry GDELT's named files (about 40% recorded 404; they are still on GDELT's server, to backfill). `audit/program/arithmetic.py.txt` is frozen as a record at study 2's criteria commit; its ledger model leaves in round 17 (decisions, 2026-11-23).
4. **Owed:** the deployed recorder's six catch-all handlers (`recording.ml`, `route.ml`, `sub.ml`, `vault.ml`), fixed with the urgent recorder rebuild; B4's checksum check once per host; kernel version 2's efficiency fixes after step 5 merges; before study 2's build, that the venue still sends `Date`, and the GitHub credential the capture host pushes each month's capture with.

### Finished

- Stages 0–6 exited; study 1 done (CS1.1 met at market 43, 2026-11-22; `audit/control-1/`). Findings: the paper, linked to the record by `docs/findings.md`; qualifications below.
- Deletion phases A, B and C done 2026-11-22 (`audit/erasure/2026-11-22-deletion-list.md`), with the cluster's cleanup (Homelab `780be55`: `moneymachine-live` enforces `restricted`, the agent sandbox and batch namespace gone) and the desktop's (dotfiles: no longer a k3s agent, only the `mirror` export stays; active after the human's next `nixos-rebuild switch`); style gates on `recorder/` and `reference/lean`.

## Blockers

- **prodesk7 powered off** 2026-11-22 13:00 to 17:06 UTC (08:00 to 12:06 EST); the recorders are back, with a gap of about 4 h 07 min (`audit/decisions.md`). Its cause is unknown, for the human to read on the node.

None else blocks the program. Source certificates that fail, with their clauses, are in `venue/sources.toml` and `audit/decisions.md`: Kalshi, Polymarket and Polymarket US; FRED and ALFRED; IMF; and stage 8's candidates.

## Decisions awaiting the human's review

None.

## Qualifications

Failed criteria, labeled amendments and known limitations, each beside its criterion in `audit/criteria.md`; reports cite this list.

- **Study 1 (CS1.1 met):** every counted response from `claude-opus-5-5`, no fallback, so not the pilot's share; size 0.0431 (note under CS1.1; the test's statements proved in Lean, `Ref/Study1.lean`); the strategy guide's first example is a funding fade like the plant (search apart from prior is excluded); market 1's sandbox never started (a miss); bubblewrap 0.12.0 from market 2 on; fixed-sample intervals (`audit/decisions.md`, 2026-11-22).

- **The agent's model (stages 3 and 4):** many sessions fell back from Opus 5.5 to Opus 4.8 after a "cyber" safeguard flag: 9 of 20 stage 3 null sessions, the real campaign's search session, and 31 of 40 in stage 4's swarm (`audit/decisions.md`, 2026-11-12). No judged number changes. Reports name the model that answered.

- **Pilot (stages 0 to 5):** version 1's snapshot resolution, so a later correction can change what a decision saw (24 funding keys with several revisions); stage 7 resolves bitemporally.
- **Stage 0:** window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC spent (invalid C0.3 clock instrument; C0.7 over the 3 bps median-excess limit in 7 cells), so a pass under the 2026-10-21 revision passes only that amendment. The judged window [2026-10-25 09:35:29, 2026-10-26 09:35:29) UTC failed C0.7's coverage in 3 of 44 cells; every result using the cost table (stages 2, 3, 10) carries it.
- **Stage 1:** C1.7 met only under its amendment (2026-10-23: the canary market is a martingale); C1.6 judged against the experiment identity at its freeze (no certificate or extractor columns in the pilot); C1.3's hand values compared to 1e-9.
- **Stage 2:** C2.6 failed as written and as amended on both rounds and is waived by human decision, never a pass: the pilot cannot confirm ordinary edges at its holdout lengths (paper, "The confirmation wall"). Its searchers state no mechanisms, so C2.2's power overstates stage 3's.
- **Stage 3:** the archive cost table lapsed, so C0.7's, qualified. Its holdout [2026-08-01, 2026-09-30) has about zero power at 360 steps: a pipeline validation run, its promotions qualified "historical holdout, costs fitted after it" and confirmed only on [2026-11-01, 2027-01-31); each campaign reports evaluations reaching −B. C3.2 met only under v3 (0 of 20): v1 failed as written (20 of 20, crashes before any model call), v2 established no procedure (`audit/stage3/write-denied-2026-10-31.md`). The real campaign had zero finalists in both arms: C3.3 and C3.4 met under the zero-finalist revisions, the release path not exercised, the holdout unreleased.
- **Stage 4:** C4.5 v1 and v2 failed (strict xfails); v3 passes as written, N2-8 unresolved (A4's refused `Edit` fails `audit_holds`; calls equal ledger rows). A smoke test: no finalist, so the holdout and betting path never ran; the C4.5 qualifications stand. Pooled: 22 started, 21 known non-promotions (bound 0.133), v2's crashed N2-9 unknown (0.198 if counted); the series report reads only logs in `data/agent` and omits v2.
- **Stage 5:** C5.3 failed as written for Discourse, met under the 2026-10-22 amendment and its clarification; C5.6's calibration deferred, required before any search store carries an event dataset (enforced at `archive/pilot`; no search store remains on `main`); the 2026-10-19 migration's predecessor hash unrecorded; unlocks a blocked category (no free source).
- **Stage 6:** C6.1 judged for Lean only (amendment of 2026-10-23; Bend's L5 not accepted); C6.3 not met; C6.5's effort a recovered proxy and its thread configuration a known limitation; C6.4 met on its third judged run; L1, L3 and L4 false as frozen, revised before their proofs.
- **Stage 10:** C10.4's tolerance revised during its first differential run, after a one-ulp disagreement, and again on 2026-10-25 before live registration (missing funding had counted as zero); met on the run after. `as_managed_mean` omits a spread with one leg entered, though the equity carries its P&L (strict xfail, audit/decisions.md, 2026-11-03); the thesis track is parked.
