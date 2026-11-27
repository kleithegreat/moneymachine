# Progress

Current state only; history is in git. `moneymachine` has pivoted to an open, polyglot **Unified Multi-Modal Quantitative Data Fabric & Agentic Quant Experiment Platform** (`fabric/`, `pods/`), while the original confirmation-wall and A18 Bar Market verification program plugs in as [`subprojects/confirmation-wall/`](subprojects/confirmation-wall/README.md) (`archive/pilot` holds the retired v1 code).

## Now

### Running, and how to inspect it

- **Cluster, live** (`prodesk7`, namespace `moneymachine-live`; `KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs`; `CLUSTER.md`):
  - Recorders: StatefulSets `ws` (OCaml `mmrec`, `recorder/RECORDER.md`) and `datalayer`, plus CronJob `vault` (`mmvault`, hourly) **deployed live at `d8bbc35`** (`sha256:a30690f1b9f7a24f5c74c8dac22d0538ffaa333c0d00beeb549a9ca17695c430`, pushed & applied `2026-11-25 21:22 UTC (16:22 EST)` via `nix run .#push` / `.#apply`, `ws-0` & `datalayer-0` `1/1 Running`); `sources` (`sha256:8ad0b655...`), `mirror`, and `mirror-verify` (`sha256:5e81095e...`) remain unchanged and healthy. `hl` retired 2026-11-22 (PVC kept).
  - The mirror CronJobs; `prodesk7` also acts as a remote Nix builder (`CLUSTER.md` §6; pass `--max-jobs 1` or `--builders ""` locally when needed).
- **Oracle VM:** terminated 2026-11-22 after verification; forward-window days embargoed in `~/embargo/oci-forward-window/` (integrity only until window ends).
- **This PC** records nothing; `data/live`, `data/sources_live`, `data/datalayer`, `data/live-oci` are closed hosts kept as evidence. Clean checkout on `main` synced with `origin/main` (legacy worktrees & 6 merged branches removed `2026-11-25 21:23 UTC (16:23 EST)`).
- **Process & Language Roles ([`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md), [`wiki/index.md`](wiki/index.md)):** Open hypothesis generation backed by strict causal hygiene; **OCaml 5** default for systems/collectors/CAS/wiki (`recorder/`, `fabric/ocaml/`, `wiki/server/` `mmwiki`); **Lean 4** for compact critical proofs without rabbit holes (`fabric/lean/`, `subprojects/confirmation-wall/`); **Python 3.13** scoped to ML/stats, DuckDB/PyArrow analytics, Tantivy bindings, and MCP agent pods (`fabric/`, `pods/`); pragmatic `license_class` metadata tagging in `ingest/terms.py`. No root `README.md`; docs live in `wiki/` and are served offline via `nix run .#wiki`.

### Work in progress

Roles and laws: [`CLAUDE.md`](CLAUDE.md), [`AGENTS.md`](AGENTS.md). Academic/R&D platform: [`audit/decisions.md`](audit/decisions.md).

1. **Unified Multi-Modal Data Fabric & Wiki (`fabric/`, `pods/`, `wiki/`, `docs/quantitative_multi_modal_data_fabric_architecture.md`, `docs/Data Fabric Source Implementation.pdf`):**
   - **Phase 0 landed:** `fabric/ocaml/` (`mmfabric` Zstd CAS + PIT core), `fabric/lean/` (`Fabric.Causal` causal/non-resurrection/ASOF/PodView proofs), `fabric/manifests/` (5 declarative source manifests), DuckDB PIT catalog (`fabric/catalog.py`), Tantivy PIT lexical search (`fabric/search.py`), `PodView` entity blinding (`fabric/views.py`), 6-tool FastMCP service (`fabric/mcp_server.py`), hash-chained SQLite `ForecastLedger` (`fabric/ledger.py`), adapters (`fabric/adapters/`), and OCaml markdown wiki server (`wiki/` + `wiki/server/` `mmwiki`).
   - **Unblocked tooling & licensing:** retired `ops/test-python-left.sh`; replaced `ingest/terms.py` & `ingest/datalayer.py` permission walls with descriptive `license_class` tagging; added `fabricPythonFor` (`numpy`, `scipy`, `duckdb`, `pyarrow`, `pydantic`, `zstandard`, `tantivy`, `mcp`, `xarray`), `mmfabric`, and `fabric-proofs` checks in `flake.nix`.
   - **Next pickup:** bridge local `data/datalayer` & `data/snapshots` captures into a working Pod and launch the first end-to-end exploratory Strategy Pod (`docs/future-work.md`, `pods/README.md`).
2. **Plug-in Verification Subproject (`subprojects/confirmation-wall/` — `kernel2/`, `reference/`, `kernel-v1/`):**
   - **Specs & Steps 0–5 (`kernel2/`):** decoupled sub-flake (`subprojects/confirmation-wall/kernel2/flake.nix`, pinned MPFR `exp`/`log`, `check-proofs.sh`). Graduates discrete-bar strategies from `fabric` via `fabric.adapters.kernel2_pod`. Remaining build steps (5a–10) & Study 2 follow-on (`audit/program/briefs/`) run independently as subproject work.
3. **Urgent live capture hardening (DEPLOYED LIVE `2026-11-25 21:22 UTC (16:22 EST)`):**
   - Hardened `recorder/` (`libcurl` + `jsont`, RFC 6455, 3-state TLS probe, `zstd` GC accounting) and `ingest/datalayer.py` (GDELT retry + `last_polls` fix) running live on `prodesk7`.
4. **The whitepaper (`docs/whitepaper.tex`, `docs/whitepaper.pdf`):** preserved intact for the confirmation-wall subproject (`docs/findings.md`).

### Finished

- Stages 0–6 exited; study 1 done (CS1.1 met at market 43, 2026-11-22; `audit/control-1/`). Findings: [`docs/whitepaper.pdf`](docs/whitepaper.pdf), indexed in [`docs/findings.md`](docs/findings.md); qualifications below.
- Deletion phases A, B and C done 2026-11-22 (`audit/erasure/2026-11-22-deletion-list.md`) plus cluster hardening cleanup (`780be55`).

## Blockers

- **prodesk7 powered off** 2026-11-22 13:00 to 17:06 UTC (08:00 to 12:06 EST); recorders are back, ~4 h 07 min gap (`audit/decisions.md`). Cause unknown — requires human physical/hardware check on the node.

## Decisions awaiting the human's review

- **Hardware checklist (`prodesk7`):** inspect the 2026-11-22 power-loss root cause, enable BIOS AC-power-recovery auto-boot, verify PSU/UPS, and provision 2 TB NVMe storage before the 300 GiB recorder volume fills (~April 2027).
- **Retire `ops/live.py`'s deployer half (step 1c):** unblocked after `d8bbc35` live rollout via `nix run .#push` / `.#apply` (porting mirror/ops to OCaml can happen opportunistically without blocking experiments).
- **Select first live Strategy Pod vertical (`docs/future-work.md`):** choose which of Pods A–E to populate first beyond the existing `datalayer` + Hyperliquid feeds.

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
