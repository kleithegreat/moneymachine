# Deletion list for the erasure pass of 2026-11-22 (draft, for the human)

**Reviewer:** Claude Opus 5.5, a fresh session that did not build the code it sweeps. It deletes nothing. A builder executes what the human approves.
**Written:** 2026-11-22 21:30 UTC (16:30 EST).
**Swept:** branch `erasure-g` at `bd5cd2f` (a copy of `main`).
**Read only:** `rearchitecture` `e71e67d`, `rearchitecture-s2` `2bf7ad4`, `kernel2-build` `b9492f5`, `kernel2-step5` `b94e128`, `recorder-urgent` `91bb08c`, tags `archive/study1-build` (`17b7184`) and `archive/study1-report` (`a2c8075`).
**Scope:** what `audit/decisions.md` of 2026-11-21 and 2026-11-22 made dead or only historical: study 1 done (CS1.1 met), `flake.lock` no longer pinned for it, the cluster's `hl` retired, the Oracle VM's recorders retired, the pilot's forward window without a finalist. Also the human's decision of 2026-11-14 (item 3): "`mm` (version 1): deleted, not kept as the pilot's instrument; a git tag keeps it", which the advisor tied to "study 1's last judged run" (architecture section 7: "lists what runs only on `mm`, the gate's search and campaign code included, since it goes to the tag too").
**Not read:** `data/holdout`, forward-window data, any price or return, any token or key file. `data/` was listed by name and size only.

## Method

- **Callers.** Every path below was checked with `git grep` over tracked files outside `audit/` and `docs/research/`, on `main` and on the five branches above. The command and its result are given with each item.
- **Import closure.** A scratch AST script computed each module's transitive imports over the tracked Python. It gives the set that survives once the pilot leaves: the live recorders (`ingest/sources_record.py`, `ingest/datalayer.py`, with `live.py`, `terms.py`), the mirror and the guard (`ops/live.py`, `ops/diskguard.py`, `ops/oci/publish.py`), the archive reader (`ingest/archive.py`, which imports `gate/compute.py`), and `criteria/`.
- **What still runs.** `ops/live.py`'s `WORKLOADS` and `CLUSTER.md` §2; `flake.nix`'s checks; `kernel2/`'s tests on `kernel2-step5`; study 2's specs on `rearchitecture-s2`; `criteria/`'s imports.
- **Frozen sets.** `CLAUDE.md` names three: the stage 3 harness (`harness_hash`: `gate/agent/{brief,research,swarm}.md`, `daemon.py`, `harness.py`, `sandbox/{session,server,client,egress}.py`, and `claude`'s store path), the kernel of the pilot's judged runs (`kernel/`), and the thesis manifest at `archive/thesis`. `ops/style.py` adds two modules that hash their own bytes into records: `gate/search.py` (`search.identity`) and `ingest/events.py` (`code_sha256`).
- **Sizes.** Line counts by `wc -l`, and AST spans for blocks inside files, rounded.

## Totals

| Phase | What | Python | Rust | Other |
|---|---|---|---|---|
| A, now, no call | the agent runners on the cluster; prose the retirements made false | −≈555 | 0 | ≈65 `CLUSTER.md` lines, ≈5 `flake.nix`, 4 prose |
| B, on the tag `archive/pilot` | the pilot: `mm`, the gate, the harness, the sandbox, the store pipeline, the `hl` recorder | −≈14,700, +≈70 | −5,047, plus 2,562 `Cargo.lock` lines | ≈2,000 fixtures, JSON and specs; ≈95 `flake.nix`; ≈12 `CLUSTER.md`; 5 `CLAUDE.md` lines rewritten |
| C, on 2027-02-01 | the Oracle VM's pull, its alarm, its setup files | −≈400 | 0 | ≈180 shell, YAML, Nix and prose |

Python on `main` goes from 20,378 lines to about 5,200: the two live Python recorders, the mirror, the guard, the archive reader, `criteria/` and their tests. Rust goes to none. Phase C then removes about 400 more.

## Order of execution

1. **Phase A** (items 1 to 3). Each is independent of the rest.
2. **Phase B** (items 4 to 9), on the human's approval. The tag first, then the criteria port alone, then the deletion, then the flake, then the prose.
3. **Phase C** (item 10), on 2027-02-01, after the last pull is verified and the VM is terminated.

Commit each item separately with a one-line `audit/decisions.md` entry. Run `nix run .#test` before each commit.

---

## Phase A: now, no call

### 1. The agent runners on the cluster (≈555 Python lines, ≈65 `CLUSTER.md` lines)

Stage 4's series ended on 2026-11-08 and study 1 ran its arms from this PC (`../mm-s1-arms`), never in a runner pod. With study 1 done, no study runs an agent session, and none can rerun a declared cohort (`CLAUDE.md`, Frozen identities: a fork needs fresh ids). Every runner mechanism is therefore historical.

- **Paths:**
  - `ops/live.py` (≈270 of 672): the `agent-series` workload (`:81–89`); `token`, `POOL`, `PROC`, `CORNELL`, `SECCOMP`, `APPARMOR` (`:37–56`); the runner branches of `pod_spec` (`hostUsers`, the Localhost profiles, `procMount`, the token env) and the `runner` field of `Workload`, which is then `False` everywhere and goes from the tuple; `run_pod` (`:242–263`); `seed_paths`, `seed`, `seed_run` (`:266–348`); `VIEW`, `view` (`:496–538`); `reach`, `gate_run`, `TARGETS`, `gate` (`:541–652`); their docstring lines (`:4–10`) and command-table entries.
  - `ops/test_live.py` (≈285 of 875): the seed tests and `local_seed_runner` (`:50–220`), `test_helper_after_killed_client_cannot_reuse_completed_pod` (`:223–262`), `passing_gate` and the five gate tests (`:265–353`), and the runner assertions of the manifest test (`:694–708`). `killed_at` (`:24`) stays: the mirror tests and `ops/test_jobs.py` use it.
  - `CLUSTER.md`: `:7–8` (agent sessions); §1's PSA rationale for `procMount` (`:14–16`), node profiles and the userns sysctl (`:17–22`), the `claude-token` secret (`:29`); §2's `agent-series` row (`:49`) and the series clauses at `:58–59, 62, 64–65, 83`; the image's claude-code, bubblewrap and Nix database clauses and the harness-hash sentence (`:72–77`); Seeding (`:79–82`); the `agent-series` runbook (`:88–95`); §3 and §4 whole (`:97–126`).
  - `flake.nix`, `packages.image`: `self.packages.${system}.claude-code`, `bubblewrap` and `nix` leave `tools`; `buildLayeredImageWithNixDb` becomes `buildLayeredImage`, and the `share/tools` file and the two Nix environment lines go. This takes effect with the next image.
- **Evidence:** `git grep -n -E "agent-series|agent-null|live.py seed|seed-run|live.py gate|live.py view|gate-run" -- ':!audit' ':!docs/research'` finds only these lines, `cli.py:163` (item 6) and `gate/` itself (item 5). No other workload names a runner: `ops/test_live.py:708` asserts `agent-series` is the only one. No study 2 spec on `rearchitecture-s2` names a runner pod.
- **Frozen:** nothing. `gate_run` compares the harness hash with `audit/stage3/harness.json`, which stays as a record; `harness_hash` is computed on this PC from the dev shell's `claude`, not the image's.
- **Until kernel version 2:** nothing. **Until 2027-02-01:** nothing.
- **Archive:** the commit before the deletion; also inside `archive/pilot` (item 4).
- **Outside the repo (the human, Homelab repo and cluster):** delete Secret `claude-token` (two subscription tokens no workload reads); remove the node profiles from prodesk7; revert prodesk7's `kernel.apparmor_restrict_unprivileged_userns=0` to Ubuntu's default; set namespace `moneymachine-live` to `enforce: restricted` (baseline existed only for `procMount: Unmasked`). The last two tighten the host that holds every live recording. Delete Job `agent-series` if it still exists. Keep the `agent` and `thesis` PVCs: they hold ledgers and recordings, and the mirror copies them.
- **Recommendation:** remove. The image change rides the next recorder image (the urgent recorder fix's), so the recorders restart only once.

### 2. Prose the retirements made false (4 lines)

- `recorder/RECORDER.md:10`: "the Oracle VM still polls". It stopped at 21:16 UTC (16:16 EST).
- `CLUSTER.md:70`: "The Oracle VM keeps its own timesyncd offset log (`ops/oci/clocklog.py`)". Its timer is disabled.
- `CLUSTER.md:85–86`, Availability: "The Oracle VM is the only independent recorder, and only for Hyperliquid." There is now no independent recorder. The sentence becomes "No second host records."
- **Evidence:** `audit/decisions.md`, 2026-11-22 21:16 UTC (16:16 EST).
- **Recommendation:** rewrite now.

### 3. `docs/future-work.md`: conditions that study 1 resolved (3 lines)

- `:12`, "A DSL designed for agents": "worth running if that study ends at its futility stop or undecided". Study 1 ended at its upper boundary, so by its own condition it is not worth running. It moves to "Rejected, and why" with that reason.
- `:11` ("once that study has reported") and `:15` ("worth its sessions only after an upper boundary"): both conditions now hold. Each loses its condition clause and says so.
- **Recommendation:** edit now.

---

## Phase B: the pilot to the tag `archive/pilot`

The human decided on 2026-11-14 that `mm` leaves `main` under a git tag once study 1's last judged run is done; architecture section 7 sends with it "what runs only on `mm`, the gate's search and campaign code included". That run was market 43 (2026-11-22 12:53 UTC (07:53 EST)). The C6.4 reference streams that kernel version 2's B4 needs instead of `mm` are stored under a hash (`data/stage6/c64-reference/`, decisions 2026-11-16). No test on `kernel2-step5` runs `mm` (`git grep -n -E "target/release|cargo|gate\.|\.py\b" kernel2-step5 -- kernel2` finds only `archive_local.ml`'s `from ingest.archive import parse`).

**Frozen identities.** The stage 3 harness and the pilot kernel leave `main` the way the thesis manifest did: whole, under a tag, never edited, so nothing forks. `CLAUDE.md`'s Frozen identities line then names them "at `archive/pilot`" (item 9). The recorded hashes stay reproducible from the tag with the tag's own `flake.lock`.

### 4. The tag

- `git tag archive/pilot <main before item 6>`, pushed by the advisor. This is the precedent of `archive/thesis` (2026-11-12).
- Delete the branches `study1-build` and `study1-report`, locally and on `origin`. `archive/study1-build` and `archive/study1-report` hold the same commits (`17b7184`, `a2c8075`). First remove their worktrees `../mm-s1-arms` and `../mm-s1-report`, and `~/.cache/mm-study1` (6.4 MB, the arms' cargo target).

### 5. What must stay on `main` (kept by this phase)

None of these is deleted in Phase B. They are listed first so that the deletion in item 6 can be checked against them.

| Path | Lines | Why it stays | Until |
|---|---|---|---|
| `kernel/CANONICAL.md` | 46 | `kernel2/lean/Engine/Lang/Rewrite.lean:4` and `Num.lean:49` cite "R version 1 (kernel/CANONICAL.md)" by path | kernel version 2 lands; then it moves beside `kernel2/` with the citations |
| `kernel/DSL.md`, `kernel/INVARIANTS.md` | 218 | `reference/SEMANTICS.md` resolves them, and B4 converts DSL version 1 programs to version 2 (`kernel2/ocaml/test/b4_local.ml:28`) | kernel version 2 lands |
| `kernel/tests/adversarial/`, `kernel/tests/admitted/` | 216 (94 files) | C1.2's red-team programs: "after which the program stays in the suite", and `CLAUDE.md` makes every red-team success a permanent test. They test DSL version 1, and nothing on the kernel version 2 branches mentions them. | kernel version 2's architect says which have a version 2 counterpart; those without one are written before they leave |
| `reference/lean/`, `reference/SEMANTICS.md` | 8,857 Lean, 323 | `refmm` is X4's reference: `kernel2/ocaml/test/scripts/x4-reference.sh` builds it. The `lean-proofs` check. | while kernel version 2's suite builds `refmm` |
| `ingest/archive.py`, `ingest/ARCHIVE.md`, `ingest/tests/test_archive.py` | 630 | Study 2's archive reader and kernel version 2's oracle (`archive_local.ml:49`); "stays, as a test's oracle" (architecture section 7) | beyond kernel version 2 |
| `gate/compute.py` → `ingest/compute.py` | 24 | `ingest/archive.py:14` imports `Pool` and `workers`; `CLAUDE.md:123` cites it. It is the only `gate/` module anything live imports, so it moves with its one importer and `gate/` ends. | beyond |
| `ingest/{sources_record,datalayer,live,terms}.py` and their tests | ≈1,300 | The deployed `sources` and `datalayer` StatefulSets (`ops/live.py:58–75`) | ported to OCaml |
| `venue/` | | Certificates (`ingest/terms.py`), `rules.json` (read by `criteria/test_stage0.py:13`), `meta-2026-11-16.json` (`kernel2/ocaml/test/layer1.ml:305`) | beyond |
| `flake.lock` | | `kernel2/tests/flake-lock.sh` (step 0, test 2) | the Waiting item 1 |

### 6. The deletion (≈14,700 Python lines, 5,047 Rust, ≈4,500 other with the `Cargo.lock` files)

- **Paths, wholly:**
  - `kernel/` except item 5's rows: the Rust workspace (`mm/src`, `mm/tests` with the `c41/*.f64` fixtures, 4,860 lines of Rust, `Cargo.lock` 1,051), `kernel/tests/{cli,timing,test_rust.py,test_mutants_*.py}`, `kernel/mutants/`, `kernel/strategies/`. About 8,940 lines.
  - `gate/` except `compute.py`: 7,333 lines of Python and 406 of specs and JSON (`NULLS.md`, `nulls.json`, `strategies/oracle.json`, the agent's `brief.md`, `research.md`, `swarm.md`).
  - `sandbox/` (665).
  - `reference/` except item 5's rows: `differential.py`, `edge_markets.py`, `tests/`, `__init__.py` (870 Python) and `mmdump/` (157 Rust, 1,059 `Cargo.lock`).
  - `ingest/`, the pilot's store pipeline: `universe`, `rules`, `backfill`, `availability`, `execution`, `witness`, `holdout`, `store`, `checks`, `fallback`, `events`, `labels`, `sources_backfill`, `sources_avail`, `sources_coverage`, `databento`, `hl`, `record`, `policy`, `units` (2,245); their tests `test_{mapping,execution,hl,witness,derived,checks,databento,events,store,sources_avail,availability}.py` and `tests/derived/` (1,102); `dbnconv/` (30 Rust, 452 `Cargo.lock`).
  - `ops/jobs.py`'s sweeps (`campaign_specs` through `leave`, ≈337 of 372), `ops/test_jobs.py` (110), `ops/runaway.py` and `ops/test_guard.py` (74, the sandbox canary's runaway target), `ops/test_session_build.py` (50, which tests `conftest.py`'s `build_once`).
  - `policy.json` (7; read only by `ingest/policy.py`).
- **Paths, in part:**
  - `ops/jobs.py`'s `REGISTRY`, `kubectl`, `sha256` and `push` (≈35 lines) move into `ops/live.py`, their only remaining caller (`ops/live.py:32, 130, 181, 658`), and the file goes.
  - `ingest/tests/test_live.py`: the `record` tests (`recorder_clock` and five tests, `:18–27, 43–135, 179–196`) and the availability merge test (`:138–176`), about 154 lines. `ingest/tests/test_recorder_spec.py`: the `recorder` fixture and four tests (`:140–211`, 64). `ingest/tests/test_crash_recovery.py`: the `record` mode (≈10). `ingest/tests/test_terms.py:13`: the `hyperliquid` row reads `hl.URL`, so it names the host as a literal or leaves for the OCaml recorders' own certificate test (the builder decides, one line).
  - `cli.py`: every command but `sources-record`, `datalayer-record` and `archive-fetch` (≈170 of 199). The pods run `python -m cli sources-record` and `datalayer-record`, and the names stay.
  - `conftest.py`: `build_once`, `session_build`, `built_kernel` (≈28). The memory watcher stays.
  - `pyproject.toml`: `testpaths` becomes `["ingest", "criteria", "ops"]`; the mypy override drops `pandas`, `statsmodels`, `arch`, `pyarrow` if nothing kept imports them.
  - `ops/style.py` (≈15): the stage 3 harness, `gate.search` and `ingest.events` leave its exclusion; only the code the deployed recorder image loads stays excluded.
- **The `hl` recorder is here, not in Phase A.** `ingest/record.py` (159), its tests and `cli record` have no caller since `hl`'s StatefulSet was deleted (`git grep -n -E "ingest\.record|cli\", \"record"` finds only `cli.py:24–28`, `ops/style.py:9, 30` and the tests). But `ops/style.py` excludes `ingest/hl.py` only because `record` imports it. Removing `record` alone would pull `hl.py` into the style check, which item 6 deletes anyway. The VM's own checkout keeps its copy, so its retirement stays reversible.
- **Evidence:**
  - Every importer of the deleted modules is itself deleted, or is item 7 (`criteria/`) or the `compute` move (scratch import-closure script, Method).
  - No workload in `ops/live.py` runs any of them: `sources` and `datalayer` import only `ingest/{live,terms}.py`; `ws` and `vault` are OCaml; `mirror` and `mirror-verify` are `ops/live.py` and `ops/diskguard.py`.
  - Study 2 reads `ws`, the archive, `mmvault` and `data/study2/` (`PROGRESS.md`, Data); its specs on `rearchitecture-s2` name `gate/markets.py`, `gate/search.py` and `gate/campaign.py` only as study 1's infrastructure (architecture section 10, "Used, until study 1's last judged run").
  - Databento: `ingest/databento.py` and `dbnconv` feed only the pilot's kernel-only store (`git grep -l -i "databento\|dbnconv"` finds only these, their test, `cli.py`, `CLUSTER.md:31` and `venue/sources.toml`). Stage 8 is superseded and its criteria are gone. The certificate stays in `venue/sources.toml`, and `data/databento` stays.
- **Frozen:** the stage 3 harness, `search.identity`, `events.derive`'s `code_sha256`, and the kernel all leave whole, under the tag.
- **Until 2027-02-01:** nothing here.
- **Risk:**
  - The pilot's judged results are reproduced from the tag, never rerun (architecture section 7). Reproducing a stage 2 sweep or a C6.4 run needs `git worktree add <dir> archive/pilot` and that commit's `flake.lock`.
  - Six checks stop running; they were cached on the builders, since the kernel is frozen.
  - `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` and `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit` are `local` tests on real `data/`, and they go too. Their judged runs are recorded in `audit/stage1/` and `audit/stage6/`.
- **Recommendation:** delete after item 7, in one commit per directory, each with the suite passing.

### 7. `criteria/` without the gate (−≈10, +≈35 lines): waits on item 4's approval and on a review

`criteria/` must keep judging the recorded criteria. Today it imports the gate for eight names: `campaigns.cohort`, `SMOKE`, `NO_CLAIM`, `audit_holds`, `swarm_verdict` and `SWARM_AGENTS` (`criteria/test_stages3to5.py`, `test_evidence_guards.py`); `null_suite.GENERATORS` and `LENGTHS`, and `sweep.cp_upper` (`test_stage2.py`); and `ingest.policy.DAY` (`test_stage0.py:10`). Through them it imports most of `gate/` and `sandbox/` (import closure).

- **Re-derived:** a criterion's test reads the criterion and the evidence, not the code it judged. Each of these names is a frozen declaration of a finished stage: the declared cohort ids (`agent-null-3-N2-0..19`, `swarm-null-3-N2-0..9`), the two smoke statements, the no-claim statement, C3.1's audit rule, C4.5 v3's verdict rule, the null grid's size, Clopper-Pearson's upper bound (`scipy.stats.beta.ppf`) and a day in milliseconds.
- **Proposal:** one module, `criteria/pilot.py` (≈35 lines), holds them, each citing its criterion in `audit/criteria.md`. The criteria tests import it and nothing of the gate.
- **Check that it changes no reading:** before the move, one run prints the tag's values next to the module's and the commit records them equal. The criteria check's pass and strict-xfail outcomes are the same before and after on the same evidence. This port could hide a failing criterion, so it gets one fresh reviewer who did not write it (`CLAUDE.md`, Decisions).
- **Alternative rejected:** keeping `gate/agent/campaigns.py` and its imports on `main` keeps nearly all of `gate/` and `sandbox/` alive for eight constants.

### 8. `flake.nix` (≈95 lines)

- **Checks go:** `kernel-cargo`, `kernel-mutants`, `kernel-py`, `gate`, `reference`, `sandbox`.
- **Their scaffolding goes:** `srcKernel`, `srcMutants`, `kernelOnly`, `cargoDeps`, `cargoTools`, `kernelTarget`, `fundingInputs` (the `requireFile` of the stage 2 funding blob), and `pytestCheck`'s `kernel`, `prebuilt` and `vendor` arguments.
- **The pinned `claude-code` goes:** `packages.claude-code`, the dev shell's `tools.claude-code`, and `claude` in the checks' `tools`. It existed for `harness_hash` and the runner image. The sessions run the host's `claude` (`ops/session.sh:80`, `$(command -v claude)`).
- **The Rust toolchain leaves the dev shell:** `cargo`, `rustc`, `clippy`, `rustfmt`, `rust-analyzer`, `pkg-config`, `RUST_SRC_PATH`.
- **`pythonFor`:** the `arch` override with its StepM patch goes. So do `scipy`'s companions that nothing kept imports (`pandas`, `statsmodels`, `pyarrow`, `numpy`, checked by import at the time). `scipy` stays for `criteria/pilot.py`'s bound, and `polars`, `lz4` and `boto3` stay for the archive reader.
- **Stays:** `bubblewrap` in the dev shell, because `ops/gpt.sh` jails GPT with it (`audit/decisions.md`, 2026-11-21 15:56 UTC (10:56 EST)).
- **The lock:** none of this moves `flake.lock`. Removing outputs changes no remaining derivation. Check after the commit that `nix eval --raw .#packages.x86_64-linux.mmrec.outPath` is unchanged.

### 9. Prose (the advisor applies `CLAUDE.md` and `PROGRESS.md`)

- `CLAUDE.md:53`: "(the stage 3 harness, the kernel of the pilot's judged runs, and the parked thesis track's manifest at `archive/thesis`)" becomes "(the stage 3 harness and the kernel of the pilot's judged runs at `archive/pilot`, the parked thesis track's manifest at `archive/thesis`)". The sentence "Check first: `gate/agent/harness.py`'s `harness_hash` (which hashes the `claude` store path, so `flake.lock` does not move while a study runs on it)" goes. The rule it served now belongs to kernel version 2's build identity (Waiting item 1).
- `CLAUDE.md:122`: "batches run on the cluster (`ops/jobs.py`)". Nothing on `main` submits a batch after item 6. Kernel version 2 runs its hosts over SSH (`kernel2/tests/x4-hosts.sh`). The line keeps only `nix run .#heavy`.
- `CLAUDE.md:123`: `gate/compute.py` becomes `ingest/compute.py`.
- `CLAUDE.md:48`: the example `kernel/DSL.md` becomes `recorder/RECORDER.md`.
- `CLAUDE.md:131`: "Today the engine is Rust (`kernel/`), the rest Python (`gate/`, using `arch.bootstrap` for SPA and StepM), and the proofs Lean (`reference/lean`, …). Every judged pilot result, and study 1, come from one frozen kernel." This becomes the state after the tag: the pilot's engine, gate and harness at `archive/pilot`, from which every judged pilot result and study 1 come; on `main`, Lean (`reference/lean`, kernel version 2 on its branch) and OCaml (`recorder/`), with Python only in the two live recorders, the mirror and guard, the archive reader and `criteria/`.
- `CLUSTER.md:4–5` (Batch Jobs in namespace `moneymachine`) and §6's check list, the "funding blob" bullet and the "Rust" bullet (`:205–206, 216–221`): about 12 lines.
- `PROGRESS.md`: "Python and Rust leave `main`…" (Next 4), the erasure item's "`flake.lock` does not move while study 1 runs", study 1's worktree and accounts lines.
- **Outside the repo:**
  - The builders' registration of the funding blob (`nix-store --add-fixed …`) and this PC's GC root `data/.gcroot-funding` are no longer needed. The blob in `/srv/moneymachine/inputs/` stays, as stage 2's frozen input.
  - Homelab: namespace `moneymachine` (Batch), the `results` NFS export, and the desktop node's `join` and `leave` have no user once `ops/jobs.py` is gone. The human decides whether to keep them for kernel version 2.

---

## Phase C: on 2027-02-01

### 10. The Oracle VM (≈585 lines)

The VM holds the only copy of the forward window's Hyperliquid day files until the window ends. After the last pull it is terminated (`audit/decisions.md`, 2026-11-22 21:16 UTC (16:16 EST)).

- **Paths:**
  - `ops/oci/`: `pull.sh` (27), `publish.py` (40), `forward-window.exclude` (5), `clocklog.py` (23), `cloud-init.yaml` (91), `provision.sh` (39);
  - `ops/test_oci_pull.py` (280);
  - `ops/diskguard.py`'s last-pull check (`:65–74`, ≈15) and its tests in `ops/test_diskguard.py` (≈45);
  - `ops/units.nix`'s `mm-oci-pull` service and timer;
  - `flake.nix`'s `apps.oci-pull`, `ociPull` in `homeManagerModules`, and the `recorder` and `cloud` dev shells;
  - `CLUSTER.md:5, 171–173`;
  - `PROGRESS.md`'s Oracle bullet;
  - this PC's `data/live-oci/host.env` and `~/.ssh/mm_oci_ed25519`. The pulled files under `data/live-oci/` are recordings and stay.
- **Why they wait:** `pull.sh`, `publish.py`, the exclude, the timer and the alarm guard that copy. The alarm is also the only sign that the VM has gone. `provision.sh` names what termination must remove (`mm-vcn`, `mm-igw`, `mm-subnet`, the budget `mm-free-tier-guard`), and the `cloud` shell carries `oci-cli`. `cloud-init.yaml`, `clocklog.py` and the `recorder` shell describe the four units whose re-enabling is the retirement's stated reversal.
- **On the day:**
  1. Run one pull without `forward-window.exclude`. The files arrive as protected material: integrity only, sizes and hashes (`CLAUDE.md`, Holdout). Kernel version 2's `protected-windows.json` keeps [2026-11-01, 2027-01-31) unreleased.
  2. Verify their hashes against the VM's.
  3. Terminate the instance and the resources `provision.sh` created.
  4. Disable the timer.
  5. Delete the paths above.
- **Archive:** git history. Tag the commit before the deletion `archive/oci`, if the human wants a name for it.
- **Recommendation:** as above.

---

## Kept, and why

| What | Why |
|---|---|
| `audit/` (including `audit/control-1/`, `audit/stage3/harness.json`, `audit/cluster/gate*.json`), `docs/research/` | The audit record, append-only. |
| Recordings: `data/live`, `data/sources_live`, `data/datalayer`, `data/live-oci`, the PVCs `hl`, `sources`, `datalayer`, `ws`, `thesis` and `agent`, and the mirror | Never deleted. `ops/live.py`'s `VOLUMES` and `LEDGERS` keep mirroring the closed `hl`, `thesis` and `agent` volumes. |
| The forward-window embargo (`CLAUDE.md`, Holdout) | It is not obsolete: kernel version 2 compiles the same window as unreleased (`kernel2/protected-windows.json`, `[1793491200000, 1801353600000)`), and study 2 reads the vault's fills only before it. |
| `ops/live.py`'s mirror and verify, `ops/diskguard.py`, their tests | The live data's only copy and its alarm. |
| The `ws` and `vault` workloads, `recorder/` | Study 2's forward data. |
| `docs/whitepaper.tex` and `.pdf`, `docs/findings.md` | The paper names no file, and `findings.md` links only into `audit/` (checked: its one other link is to `whitepaper.tex`). Nothing here changes them. |
| `.githooks/`, `ops/commitcheck.py`, `ops/session.sh`, `ops/gpt.sh`, `ops/agy-write.sh` | Current process tools. |
| Item 5's table | Kernel version 2, study 2 and the live recorders still read them. |

## Collisions with branches

| Branch | What it carries | Resolution |
|---|---|---|
| `rearchitecture`, `rearchitecture-s2`, `kernel2-build`, `kernel2-step5` | An earlier `gate/control/` (36 files, about 6,600 lines with its tests) and `ops/jobs.py`'s study 1 calibration (`cal_weights` to `cal_step`, +189, and +9 in `ops/test_jobs.py`) | Study 1's code is archived, not merged (decisions, 2026-11-22 17:23 UTC (12:23 EST)). Each of these merges must take `main`'s side and leave both out. The simplest way is to delete them on the branches first, one commit each. |
| The same four | `flake.nix` with `main`'s pilot checks beside the kernel version 2 checks | After item 8 their merge drops the pilot checks. Expect a textual conflict in `checks.x86_64-linux`. |
| `kernel2-*` | `kernel2/tests/flake-lock.sh` compares the lock with `main`'s | Unaffected: Phase B moves no lock. |
| `recorder-urgent` | `recorder/` only | No collision. The image change of item 1 rides its deploy. |

## Waiting on a decision

### 1. `flake.lock`: do not update it now (the advisor and kernel version 2's architect)

**Study 1's reason is gone.** The lock was pinned because `harness_hash` hashes `claude`'s store path, which depends on nixpkgs: the derivation's `stdenvNoCC`, `fetchurl`, `makeBinaryWrapper`, `zstd`, `autoPatchelfHook` and the `alsa-lib`, `procps`, `ripgrep`, `bubblewrap` and `socat` it wraps. Moved today, it would give `main` a different harness hash, a fork on paper that no campaign can use. After Phase B the harness is only at the tag, with the tag's lock, and the lock cannot reach it.

**What an update would rebuild:** everything in the closure.
- The Python environment. The `arch` patch uses `--replace-fail`, so it fails the build if upstream changed that line (moot after item 8).
- The Rust toolchain and `mm` (moot after item 6).
- `claude-code`'s wrapper.
- Lean's patched tarball and `refmm`: the version stays 4.34.0, but the store paths are new.
- OCaml with dune and Jane Street's v0.17, and `ocamlformat` and `ppx_js_style`. A new version can reformat code or warn, and every warning is an error.
- `mmrec`, and with it the cluster image. The next push restarts `ws`, `vault`, `sources`, `datalayer` and the mirror on new libraries, with a recording gap.
- texlive, which changes `whitepaper.pdf`'s bytes.
- The MPFR, GMP and glibc that kernel version 2's X4 tests use. Test 12's host attestation records glibc's version.

**What it could change:**
- No recorded result of the pilot or of study 1. Each is reproduced from its tag and lock, never rerun.
- Kernel version 2's readiness evidence. B4's 3,120 bit-identical streams and test 12's inputs were made on the current toolchain, and `kernel2/tests/flake-lock.sh` fails by design.
- After study 2 registers its build: the engine's identity is "Nix's hash of the derivation", "its compilers and libraries" included (`audit/program/kernel-v2.md` A13; ledger D94, "a two-year test would refuse its own engine"). Any nixpkgs move then forks the engine for up to two years.

**Recommendation:**
- Leave it now. Nothing needs a newer nixpkgs, and a move would invalidate kernel version 2's evidence while it is being built.
- Move it once, on purpose, after Phase B (no Rust or pilot Python left to rebuild) and before study 2's freeze. Then rerun B4 and test 12 on the new toolchain, and update the lock test with a dated decision.
- This is a step for kernel version 2's plan, not erasure.

**A wall for the architect** (`CLAUDE.md` §1): one lock pins both the engine, which is frozen for up to two years, and the internet-facing recorders' TLS stack (`async_ssl`). The recorders would get no security update during study 2's forward test unless the engine's toolchain becomes an input of its own. The brief rules out a new flake input ("no new flake input", brief 3). Which gives way is the architect's question, or the human's.

### 2. When `mm` leaves (the human)

The decision of 2026-11-14 says after study 1's last judged run. `PROGRESS.md`'s Next 4 says "Python and Rust leave `main` as study 1 reports and kernel version 2 lands". This list found nothing on the kernel version 2 branches that runs `mm` (item 5). **Recommendation:** now, with the rest of Phase B. If the human prefers to wait for kernel version 2, only Phase B's Rust part waits (`kernel/`, `reference/mmdump`, `ingest/dbnconv`, the cargo checks). That costs nothing but cached checks.

### 3. Item 7's port: the advisor, with one fresh reviewer

It changes how recorded criteria are judged, so it gets a reviewer who did not write it.

### 4. The Homelab and cluster hardening of item 1 (the human)

The `claude-token` Secret, the node profiles, prodesk7's userns sysctl, and the namespace's PSA level.

### 5. The forward window's only copy on an idle VM (the human; not a deletion)

A lead from memory, to check against Oracle's current terms before relying on it: Oracle may reclaim an idle Always Free compute instance. The VM is an Always Free `VM.Standard.E2.1.Micro` (decisions, 2026-10-23). With its recorders stopped, it may fall under the idle thresholds well before 2027-02-01, and a reclaimed VM loses the files `forward-window.exclude` keeps off this PC. If the lead holds, the choice is the human's:
- pull them now, into a place nothing reads (integrity checks only, as `CLAUDE.md`'s Holdout rule allows), and terminate early;
- or keep the VM busy enough to stay.

The 10-minute pull's alarm only reports the loss after it happens. Moving protected data is a leakage boundary, so either route is reviewed.

## Outside the repo

- **Git refs and worktrees:** item 4.
- **The cluster and Homelab:** items 1 and 9.
- **This PC:** `~/.cache/mm-study1`, `data/.gcroot-funding`. The ignored token files `.TAMU_TOKEN` and `.CLAUDE_CODE_OAUTH_TOKEN*` served the agent series' pacing and study 1. Not read here, and the human may delete them. Six empty `data/tmp*` directories from 2026-11-09 (8 KB each) are scratch.
- **The advisor's memory:** `tamu-shared-with-series.md` describes a campaign series, and none remains. The advisor decides.

## Unsure

1. **`seed`'s future.** It is generic (it copies hashed files into any volume), but its only use was the agent volume. If study 2's runner is ever a cluster workload needing seeded inputs, it returns from history.
2. **Which kernel/ specs kernel version 2 still needs once it lands.** The citations found are `CANONICAL.md` (by path) and `DSL.md`/`INVARIANTS.md` (through `SEMANTICS.md`). A search by concept rather than path may find more.
3. **The red-team cases' fate** (item 5) is a question for kernel version 2's architect. This list only refuses to delete them unasked.
4. **The Python packages that leave in item 8** were inferred from the kept files' imports. They must be checked by building the suite without them.
5. **Oracle's idle-reclamation rule** (Waiting item 5) is from memory and unverified.
6. **Whether the batch namespace and NFS exports have a later use** (item 9) for kernel version 2's host runs, which today go over SSH.
