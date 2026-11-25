# Progress

Current state only; history is in git. The pilot's code is at `archive/pilot` (2026-11-22); `main` holds the live hardened recorders and datalayer retry fix, the mirror and guard, `reference/lean`, the decoupled `kernel2/` sub-flake (Steps 0–5 with pinned MPFR), and the frozen Study 2 / reopened follow-on specs.

## Now

### Running, and how to inspect it

- **Cluster, live** (`prodesk7`, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders: StatefulSets `ws` (OCaml `mmrec`, `recorder/RECORDER.md`), `sources`, `datalayer`; CronJob `vault` (`mmvault`, hourly). `hl` retired 2026-11-22 (PVC kept). **No live deploy ran in the 2026-11-25 18:18 UTC (13:18 EST) Project Reset** — local `main` holds hardened `mmrec`/`mmvault` and `datalayer.py` ready to push and apply.
  - The mirror CronJobs; `prodesk7` also acts as a remote Nix builder (`CLUSTER.md` §6; use `--max-jobs 1` for heavy `kernel2/` Lean+OCaml checks to avoid overloading builders).
- **Oracle VM:** terminated 2026-11-22 after verification; forward-window days embargoed in `~/embargo/oci-forward-window/` (integrity only until window ends).
- **This PC** records nothing; `data/live`, `data/sources_live`, `data/datalayer`, `data/live-oci` are closed hosts kept as evidence.
- **Process (`CLAUDE.md`):** Stateless coordinator sessions (never long-lived multi-compaction advisor threads), **honest-but-buggy** threat model, **Bounded Review Protocol** (< 50 KB bundles, Blocker vs Non-Blocker grading, max 2 rounds, Prototype-Before-Spec), and functional-first stack (Lean 4, OCaml, Nix, pinned MPFR; zero new Python).
- **Legacy worktrees:** `../mm-program`, `../mm-program-s2` (had stalled R21 merge of `e9f2e8c`, superseded by freeze), `../mm-k2-step5`, `../mm-rec-urgent`, `../mm-python-plan` remain outside `main` for optional human cleanup.

### Work in progress

Roles and laws: [`CLAUDE.md`](CLAUDE.md). Academic research system: no live trading. Project Reset recorded at `2026-11-25 18:18 UTC (13:18 EST)` (`audit/decisions.md`).

1. **Kernel v2 & Study 2 (`audit/program/kernel-v2.md`, `kernel2/`, `briefs/3-kernel-v2.md`, `briefs/4-study-2.md`):**
   - **Specs FROZEN:** 20-round specification loop closed cleanly (`audit/program/ledger.md` Project Reset entry); compiler-replay sandbox dropped in favor of `kernel2/lean/check-proofs.sh` under the honest-but-buggy threat model; Round 20 midnight-end / registration-fixed `meta` (`TON` excluded) and single-host deterministic monthly replay folded into `4-study-2.md` and `kernel2/KERNEL.md` (committed `CS2.1`–`CS2.3` untouched).
   - **Kernel v2 Steps 0–5 landed on `main` (`kernel2/`):** decoupled sub-flake (`kernel2/flake.nix` + `kernel2/flake.lock`, sha256 `415c302c...`), pinned `pkgs.mpfr` `exp`/`log` (`c/mpfr_ops.c`; `test12` in 1m 16.3s vs 15 CPU-days), `check-proofs.sh` + negative fixtures. **Next:** execute Kernel v2 Steps 5a → 6 → 7 → 8 → 9 → 10, then Study 2 Steps 1–6 and freeze.
2. **Urgent live capture hardening (on `main`, pending human deploy):**
   - `recorder/` hardened (`libcurl` + `jsont`, RFC 6455 `Sec-WebSocket-Accept`, 3-state TLS probe cache, zero-alloc `route.ml`, D369 4-state streams, monotonic run IDs, `zstd` GC tracking, zero wildcard `with _`/`exception _` catch-alls).
   - `ingest/datalayer.py` fixed in-place for GDELT ~40% 404 misses (up to 10 fixed-tick retries without shifting `every_h`, plus `last_polls` `/index` restart fix).
3. **Parallel reopened research tracks (active, not blocked behind Study 2):**
   - **Earlier-Cutoff LLM Arm (`audit/program/briefs/5-earlier-cutoff.md`):** cutoff `<= 2024-06-30` unlocking 760-day pre-embargo holdout (`[2024-10-01, 2026-10-31)`), 80%-power Sharpe ~2.07; Prototype 0 (archive coverage, 0/20 canary probe, `libcurl` + `bwrap` OCaml harness) next.
   - **Study 1 Diagnostic, Unhinted Cell 2 & Agent DSL (`audit/program/briefs/6-unhinted-search-dsl.md`):** zero-cost OCaml offline diagnostic of Study 1's 24/42 failures (`median 9.5` evals), followed by microbenchmark + Cell 2 A/B.
4. **The paper (`docs/whitepaper.tex`, `docs/whitepaper.pdf`):** updated for write-denied reading-agent defect, honest-but-buggy MPFR Kernel v2, and active earlier cutoffs; PDF rebuilt cleanly.
5. **Python's extinction (`audit/program/python-extinction.md`):** Revision 3 on `main` + Reset Sequencing (**Phase 2**: `mmdata`, `mmops`, and deployer retirement `1c` follow live deploy and Study 2 freeze; `python-left` ratchet active).

### Finished

- Stages 0–6 exited; study 1 done (CS1.1 met at market 43, 2026-11-22; `audit/control-1/`). Findings: the paper, linked to the record by `docs/findings.md`; qualifications below.
- Deletion phases A, B and C done 2026-11-22 (`audit/erasure/2026-11-22-deletion-list.md`), with the cluster's cleanup (Homelab `780be55`: `moneymachine-live` enforces `restricted`, the agent sandbox and batch namespace gone) and the desktop's (dotfiles: no longer a k3s agent, only the `mirror` export stays; active after the human's next `nixos-rebuild switch`); style gates on `recorder/` and `reference/lean`.

## Blockers

- **prodesk7 powered off** 2026-11-22 13:00 to 17:06 UTC (08:00 to 12:06 EST); the recorders are back, with a gap of about 4 h 07 min (`audit/decisions.md`). Cause unknown — requires human physical/hardware check on the node.

None else blocks the program. Failed source certificates stay in `venue/sources.toml` and `audit/decisions.md` (Kalshi, Polymarket, FRED/ALFRED, IMF, stage 8).

## Decisions awaiting the human's review

- **Ready to deploy live fixes (no cluster mutations ran):** verify image + rollout on `prodesk7` when ready via `nix run .#push` then `nix run .#apply`, then retire `ops/live.py`'s deployer half (`python-extinction` step 1c).
- **Hardware checklist (`prodesk7`):** inspect power-loss root cause, enable BIOS AC-power-recovery auto-boot, verify PSU/UPS, and provision 2 TB NVMe storage before the 300 GiB recorder volume fills (~April 2027).
- **Optional cleanup:** remove legacy sibling worktrees (`../mm-program`, `../mm-program-s2`, `../mm-k2-step5`, `../mm-rec-urgent`, `../mm-python-plan`) once satisfied with `main`.

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
