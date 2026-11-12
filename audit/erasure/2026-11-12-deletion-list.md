# Deletion list for the erasure pass of 2026-11-12

**Reviewer:** Claude Opus 5.5, a fresh session that did not build the code it sweeps (`audit/decisions.md`, 2026-10-28). It deletes nothing. A Sonnet builder executes this list.
**Written:** 2026-11-12 03:13 UTC (2026-11-11 22:13 EST).
**Swept:** branch `erasure` at `ab42e5e` (a copy of `main`).
**Read only:** `rearchitecture` `c46c786`, `thesis-refreeze` `9d8f6e2`, tag `archive/thesis-split`, and `../Homelab` at `477f2e0`.
**Scope:** the human's decisions of 2026-11-11 21:48 UTC (16:48 EST) and 2026-11-12 01:45, 01:46 and 01:51 UTC (2026-11-11 20:45, 20:46 and 20:51 EST) (`audit/decisions.md`). Also the open items of `audit/erasure/2026-11-09-deletion-list.md`.
**Not read:** `data/holdout`, forward-window data, any price or return, and any file on a homelab node.

## Method

- **Callers.** Every path below was checked with `git grep` over tracked files outside `audit/` and `docs/research/`. The commands and a summary of their output are given with each item.
- **Audit files.** A script checked each of the 371 files under `audit/` for its full path or its `audit/`-relative path. It searched the paper on `main` and on `rearchitecture`, `CLAUDE.md`, `PROGRESS.md`, `CLUSTER.md`, the code, `audit/criteria.md`, `audit/decisions.md`, the rest of `audit/`, and `rearchitecture`'s `audit/program/`.
  - 208 files have no citation by path. Most are judged evidence cited by directory or glob, and they stay.
  - Deletion is proposed only for a file that is neither evidence nor a live rule.
- **Frozen sets.** The identity functions themselves were run to list the frozen files: `harness_hash` with `session.identity` captured, `search.identity`, `events.derive`, and `thesis.harness.manifest_files` (output in item 1).
- **Nix.** A scratch flake that imports this worktree as an input built four check derivations in the Nix sandbox. The measurements are in the plan below. Nothing was configured on any machine.

## Totals

| | Items | Python | Rust | Shell | Other |
|---|---|---|---|---|---|
| Removable in this pass | 11 | −7,310, +≈60 | 0 | −78 (33 untracked), +≈45 | 5,265 audit lines; 201 thesis prose and data; ≈80 CLUSTER.md lines; Homelab −29 shell, −39 unit and role lines |
| Waiting on a decision or a commit | 2 | −≈1,000 (agent-real) | 0 | 0 | 285 criteria lines (stages 8 and 9) |

- **Rust:** nothing is removed. The kernel is frozen. `reference/mmdump` serves the reference tests. `ingest/dbnconv` waits on the human's ICE licence reading.
- **Python, removed:** thesis code and tests 6,121; `ops/shards.py` and its test 865; `ops/crossmachine.py` 132; the start-method test 58; `conftest.py`'s shard report 22; `ops/test_style.py` and `ops/test_progress.py` 80; `ops/live.py` and `ops/test_live.py` ≈33; `cli.py` 3.
- **Python, added:** the style check's file lister (≈30), annotations for the three files that leave the thesis exclusion (≈20), and the client test's inline spec (≈5).

## Order of execution

1. **Phase A** (items 1 to 5) needs nothing outside the repo.
2. **Phase B** (item 6) adds the flake checks and proves them locally.
3. **Phase C** (items 7 and 8) is the remote-builder configuration. The human applies it.
4. **Phase D** (item 9) deletes `ops/shards.py`, only after one full `nix flake check` has passed on the remote builders.
5. **Phase E** (items 10 and 11) moves the launchers and timers to Nix.
6. **Phase F** (items 12 and 13) waits on a decision or a commit.

Commit each item separately, with a `decisions.md` line where noted. Run the suite before each commit: `ops/shards.py` until item 9, the new commands after it.

---

## Phase A

### 1. The thesis track leaves `main` (6,322 lines, 6,121 of them Python; ≈45 more elsewhere)

**First, the tags.** These are reversible and need no push to be valid locally. The advisor pushes them.
- `git tag archive/thesis ab42e5e`: main's last state with `thesis/`.
- `git tag archive/thesis-refreeze thesis-refreeze`: `9d8f6e2`, the latest thesis code, 107 commits ahead of main.
- Then delete the branch `thesis-refreeze`, locally and on `origin`. This follows the precedent of `archive/thesis-split` and `archive/positive-controls`.
- The branch carries `audit/stage10/criteria-revision-draft.md` and `-round11-draft.md`, the superseded drafts the human named. They exist on no other branch (`git ls-tree` of `main`, `rearchitecture` and `stage7`), so they leave with the branch. Nothing is deleted on `main` for them.

**Paths:**
- `thesis/`: 29 files. That is 6,121 lines of Python, plus `SCORING.md`, three briefs (201 lines) and `tests/scoring_gen_states.json` (125 KB).
- `cli.py:177–179`: `thesis-freeze`, `thesis-run` and `thesis-report`.
- `ops/live.py`:
  - the `thesis` workload (`:89–97`);
  - `retrieval_reach` (`:561–571`) and its gate part `"retrieval"` (`:622`);
  - the `OnDelete` special case (`:223`);
  - "thesis" in the `pod_spec` docstring (`:153`) and "PERSONAL" in the `CORNELL` comment (`:38`).
- `ops/test_live.py`: the retrieval stubs and the `"retrieval"` failure case (`:277, 288, 310–311`); `"thesis"` in the runner set (`:706`); the `OnDelete` assertion (`:707`).
- `sandbox/tests/test_client.py:12, 30, 37–39`: replace `thesis.daemon.SPEC` with an inline spec of the same shape, `{"usage": …, "commands": {"pair": [2], "load": [1, "file"]}}`, and keep the three assertions. They test the shared client's arity forms, which the research spec alone does not cover.
- `pyproject.toml:3`: drop `"thesis"` from `testpaths`.
- `ops/test_style.py`: drop the thesis import and exclusion (item 6 then replaces the whole file).
- Stale comments:
  - `gate/agent/campaigns.py:92`, "the thesis track also draws on Cornell";
  - `ingest/fallback.py:1`, the "stage 10: any listed coin outside U" clause.
- `CLUSTER.md`:
  - the `:51` row;
  - the thesis clauses at `:4, 58, 60, 64, 66–67, 70, 82, 87, 88, 104, 106, 132`;
  - `:30`'s `PERSONAL` key, after item 3 removes it.
  - Keep `:25`'s `thesis` PVC: it exists and holds recordings.

**Evidence:**
- `git grep -n -E 'from thesis|import thesis|"thesis\.' -- ':!thesis' ':!audit'` finds four importers: `cli.py:177–179`, `ops/live.py:565`, `ops/test_style.py:27` and `sandbox/tests/test_client.py:12`. All four are handled above.
- The track is parked by the human (2026-11-11 17:25 UTC (12:25 EST)): StatefulSet at 0 replicas, Job `thesis-prewarm` stopped.
- Revision 4 parks "the thesis track entire" (`rearchitecture:audit/program/architecture.md` §10).
- Durations in `~/.cache/mm-shards/durations.json`: thesis tests are 3,404 of 5,201 recorded test-seconds (65%).

**The style rule after the thesis manifest goes.** Running the identity functions shows that 13 non-thesis files were frozen only by the thesis manifest: `gate/__init__.py`, `gate/kernel.py`, `ingest/{__init__,datalayer,fallback,hl,live,policy,terms}.py`, `sandbox/{__init__,canary}.py`.
- Today, `ruff format --check` fails on 6 of them and `mypy` finds 21 errors in 5.
- Four of them are live recorder code, which this pass may not touch (the hard constraint): `ingest/datalayer.py`, `hl.py`, `live.py` and `terms.py`.
- Importing `ingest.record`, `ingest.sources_record` and `ingest.datalayer` loads `ingest/{__init__,datalayer,hl,live,policy,record,sources_record,terms,units}.py`.
- **Re-derived exclusion:** code a frozen identity hashes, together with code the deployed recorder image loads, each joining at its next fork or image. The style check computes the second set the way `test_style.py` computes the first, by importing those three modules.
- The three non-recorder files that leave the exclusion get formatted and annotated in this commit: `gate/kernel.py` (2 mypy errors), `ingest/fallback.py` (1) and `sandbox/canary.py` (10).
  - `gate/kernel.py` is not hashed by anything. A study 1 test asserts `harness_hash()` begins `6a335714`, which these files do not enter.
  - Its `MM` and `build()` keep their behaviour exactly: study 1 runs on them.

**Risk:** low.
- The tags keep every byte. `data/thesis` and the `thesis` PVC are untouched.
- The `retrieval` gate part guarded only the thesis's reading arm, so a later runner gate no longer requires a certified fetch to return 200.
- The paper on `rearchitecture` cites `\record{thesis/SCORING.md}` (Appendix T1, line 730). It will point at a path absent from `main` until the paper step changes it to `archive/thesis:thesis/SCORING.md` (see "Collisions").

**Replaces it:** the tags.

**Call:** a builder decides, with one `decisions.md` line (the human's decision of 2026-11-11 and 2026-11-12 covers it).

### 2. `ops/crossmachine.py` and its one test caller (190 lines)

- **Paths:**
  - `ops/crossmachine.py` (132 lines);
  - in `gate/tests/test_compute.py`, `from ops.crossmachine import rows` (`:16`) and `test_campaign_results_and_ledgers_agree_across_start_methods` (`:60–117`, 3 cases, 53 recorded seconds).
- **Evidence:**
  - `git grep -n -E 'ops\.crossmachine|crossmachine import' -- ':!audit'` finds only `gate/tests/test_compute.py:16`.
  - `git grep -n crossmachine.py -- docs/whitepaper.tex` finds nothing, on `main` or on `rearchitecture`. The paper cites only the record `audit/crossmachine/freeze.md` (`:547`, rearchitecture `:597`), so there is no paper reference to the tool to remove.
  - Every recorded bit-identity check is in `audit/crossmachine/` (28 files) and `audit/erasure/reproduce-*.json`. They stay.
- **Risk:** low.
  - The deleted test also checked that `compute.Pool`'s forkserver gives the same campaign results and ledgers as fork. The two tests above it in the file still cover the pool's lock and start method.
  - Re-running a historical reproduction afterwards needs `git show ab42e5e:ops/crossmachine.py`.
- **Call:** a builder decides (the human, 2026-11-12 01:51 UTC (2026-11-11 20:51 EST)).

### 3. Cluster objects of the parked track (no repo lines; the human runs these)

- **Delete** StatefulSet `thesis` (0 replicas) and Job `thesis-prewarm` (stopped) in `moneymachine-live`. Deleting a StatefulSet leaves its PVC, so the `thesis` PVC stays: it holds recordings, and the mirror copies it.
- **Remove** the key `PERSONAL` from Secret `claude-token`. After item 1 no workload names it (`git grep -n PERSONAL -- ops` finds only `ops/live.py:93` and the comment at `:38`). An unused credential in the cluster serves nothing.
- **Why the human:** the advisor's `kubectl` was refused when the prewarm Job was stopped (2026-11-11 17:25 UTC (12:25 EST)).
- **Reverse:** `python ops/live.py apply <digest> thesis` from `archive/thesis`, and re-create the key.

### 4. Stale audit files (5,265 lines on `main`, 84 on `rearchitecture`)

None of these is evidence behind a recorded result, a judged campaign record, a spent holdout or a file study 1 uses.

| Path | Lines | Why it is stale | Citations |
|---|---|---|---|
| `audit/coldstart/2026-10-30.md` | 37 | A one-off cold-start check of PROGRESS.md. Its own text says each finding was resolved by the rewrite after `342b9fd`. | none |
| `audit/diagnostics/c07-regimes.json` | 5,210 | The archive regime diagnostic, which "decides nothing" (human-approved as such on 2026-10-26). Written by the first `ingest/archive.py`, which the 2026-11-09 pass deleted. | none |
| `audit/stage8/databento-{definition,ohlcv-1d,statistics}-monthly-price.json` | 18 | Earlier price quotes, superseded by `databento-pricing.json`, which `venue/sources.toml:535` cites and which stays. | none |
| `rearchitecture:audit/program/briefs/2-thesis-track.md` | 84 | The brief for the withdrawn event-contract study. `paper-changes.md` D5 says nothing may be built from it and left deletion to the human, who has since allowed it (2026-11-11 21:48 UTC (16:48 EST)). | D5 only |

- **Evidence:** the citation script in Method. `git grep -n 'coldstart\|c07-regimes\|monthly-price'` finds no citing file.
- **Risk:** none. Git keeps them.
- **On `rearchitecture`:** delete the brief and the D5 row about it in the same commit.

### 5. `CLUSTER.md` §6, "Cut-over" (5 lines)

- **What:** `:193–197`, the history of the move of 2026-10-30.
- **Evidence:** the record is `audit/cluster/handoff.md`. The previous list's item 3 proposed the same cut, and it was not applied.
- **Kept:** the rollback rule, "a rollback never reruns a consumed campaign or date". Move it to §2's "Retries".
- **Risk:** none.

---

## Phase B

### 6. Tests become flake checks (the plan is below), and the `local` marker replaces `LOCAL_ONLY`

**Adds:**
- `checks.x86_64-linux.*` and `apps.x86_64-linux.test` in `flake.nix`;
- a pytest marker `local` declared in `pyproject.toml` and applied in the files listed in the plan;
- `ops/style.py` (≈30 lines), which prints the covered files.

**Deletes:**
- `ops/test_style.py` (71 lines), replaced by the `style` check;
- `ops/test_progress.py` (9 lines), replaced by the `progress-cap` check.

**Also changes:**
- `.githooks/pre-commit:4` runs `nix build --no-link .#checks.x86_64-linux.progress-cap` and keeps `ops/test_commitcheck.py`, which needs git history.
- `CLAUDE.md:43`: "(`ops/test_progress.py`)" becomes "(the flake check `progress-cap`)". The advisor applies this (see the `CLAUDE.md` row under Collisions).

**Must not change:**
- `flake.lock`. Do not run `nix flake update`.
- The `claude-code` derivation.
- `harness_hash` contains `claude_binary()`, the resolved store path of the pinned `claude`, so a new nixpkgs revision would fork the frozen harness.
- Adding outputs leaves existing derivations unchanged. Check it after the commit: `nix eval --raw .#packages.x86_64-linux.claude-code.outPath` must be unchanged, and `harness_hash()` must still begin `6a335714`.

**Done when:**
- `nix flake check -L` passes, built on this PC if no remote builder exists yet;
- `nix develop -c pytest -m local` passes in a worktree with `data/store` linked.

**Call:** the advisor, because it changes the suite process that `CLAUDE.md` names. It is reversible and changes no judged result.

---

## The Nix plan

### Flake outputs

- **`checks.x86_64-linux.<name>`**, one derivation per test group (table below). Use x86_64-linux only, since the nodes and this PC are all x86_64. `nix flake check` builds the current system's checks.
- **Shared, not outputs:**
  - `src`: a `lib.fileset` of the tracked tree minus prose: `docs/`, `audit/reviews/`, `audit/decisions.md`, `audit/erasure/`, `audit/program/`, root `*.md`. A docs- or decisions-only commit then leaves every check cached. A test that reads excluded prose fails in its check, which is how a missed dependency shows. Nothing goes stale silently.
  - `kernelSrc`: `kernel/` plus `venue/hyperliquid/`.
  - `cargoDeps = rustPlatform.importCargoLock { lockFile = ./kernel/Cargo.lock; }`: 118 vendored crates, so cargo works offline in the sandbox.
  - `kernelTarget`: one derivation running `cargo build --release --offline` and outputting `kernel/target`.
  - `pytestCheck { name, paths, kernel ? false }`. It uses `src`, the dev shell's Python (`pythonFor`, factored out unchanged), `sqlite`, `git`, and the pinned `claude-code`, so `harness_hash()` matches. With `kernel`, it adds `cargo`, `rustc`, `cargoSetupHook` and a writable copy of `kernelTarget` at `kernel/target`. It runs `pytest -m "not local" -n $NIX_BUILD_CORES -p no:cacheprovider <paths>` with `HOME=$TMPDIR`.
- **`apps.x86_64-linux.test`:** `nix flake check -L "$@"`, then `nix develop -c pytest -m local`. This is the one command a session runs.
- **`apps.x86_64-linux.{session,heavy,diskguard,oci-pull}`:** items 10 and 11.
- **`homeManagerModules.default`:** item 11.

### Check derivations

| Check | Runs | Kernel | Measured in the sandbox (scratch flake, this PC, 2026-11-12) |
|---|---|---|---|
| `progress-cap` | `PROGRESS.md` ≤ 12,288 bytes | no | built in 0.6 s |
| `style` | `ruff format --check`, `ruff check` and `mypy` on `ops/style.py`'s list; the exclusion of item 1 | no | not built |
| `kernel-cargo` | `cargo test --release --offline` in `kernel/` (reads `venue/hyperliquid`, `kernel/tests/{adversarial,admitted}`, `kernel/strategies`) | builds it | 5 min 14 s cold, all 118 crates compiled offline from vendored sources; 11 test binaries, 42 passed |
| `kernel-mutants` | `kernel/tests/test_rust.py -k mutant`: 17 mutants, slots from free memory as now | yes | not built; 1,208 recorded test-seconds, cargo test included |
| `kernel-py` | `kernel/tests/cli`, `kernel/tests/timing`, `kernel/tests/test_mutants_*.py` | yes | not built |
| `gate` | `gate/tests` | yes | a subset (`test_markets`, `test_gate`, `test_series_spec`): 67 passed in 18 s, plus 1 min 3 s of recompilation (below) |
| `ingest` | `ingest/tests` | no | not built |
| `criteria` | `criteria/`; its `src` adds `audit/` back | no | 40 passed, 1 skipped (`data/store`), 5 xfailed in 6.1 s |
| `ops` | `ops/test_*.py` | no | five files: 283 passed in 5.5 s; the one failure was `test_commitcheck`'s history test (marked `local`) |
| `sandbox` | `sandbox/tests` | no | not built |
| `reference` | `reference/tests` with `packages.lean` and `reference/mmdump`'s vendored crates | yes | not built; Lean took a node 6 to 12 minutes cold (`CLUSTER.md` §7). A `refmm` derivation holding `.lake` (Lake's traces are hashes, not mtimes) would make it a one-time cost; measure first |
| `gate-control` | `gate/control/tests`, once `rearchitecture` merges | yes | n/a |

- **Recompilation.** A check that copies `kernelTarget` still recompiled `zstd`, `parquet`, `rusqlite` and `mm` (1 min 3 s), with identical inputs on both sides. Cargo's freshness check is mtime-based, and the store zeroes mtimes. That cost is paid once per kernel-using check, run in parallel on the builders.
  - The alternative, a Nix-built `mm` placed where the tests read it, means changing `gate/kernel.py`'s `MM`/`build()`. Study 1 runs on those, so this pass leaves them alone.
- **Caching.** `kernel-cargo` and `kernel-mutants` depend only on `kernelSrc`. The kernel is frozen, so they build once and stay cached until it forks. Today's runner reruns them every time.

### Kept local

These are marked `local` and run by `nix develop -c pytest -m local` on this PC.

| Need | Tests |
|---|---|
| Real `data/` | `kernel/tests/cli/test_differential.py::test_kernel_matches_witness`; `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`; the store part of `criteria/test_stages3to5.py` (it skips today where `data/store` is missing, so in a check it would pass silently) |
| User namespaces (bubblewrap) | `gate/tests/test_sandbox.py`; the bubblewrap pod-view tests in `gate/tests/test_agent_real.py` (`:651–700`, until item 13) |
| Kill-the-process storage behaviour | `gate/tests/test_crash_recovery.py`, `gate/tests/test_campaign_recovery.py`, `ingest/tests/test_crash_recovery.py`, and the tests that kill a writer and inspect what it left in `ingest/tests/{test_datalayer,test_live,test_recorder_spec}.py`, `gate/tests/test_series_spec.py`, `ops/{test_live,test_live_churn,test_diskguard,test_oci_pull}.py` (`git grep -l 'SIGKILL\|kill('`). These passed in the sandbox (the `ops` row), but the human kept them local. |
| Git history | `ops/test_commitcheck.py::test_added_lines_pair_their_times` |

The marker is one concept with two selections. It replaces `LOCAL_ONLY`, the node-skip rerun and the Ubuntu-layout caveat of `CLUSTER.md` §7.

### Remote-builder configuration

**This PC** (dotfiles, `hosts/desktop/system.nix`; the human applies it with `nixos-rebuild switch`):
```nix
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
nix.settings.secret-key-files = [ "/etc/nix/desktop-builds.sec" ];  # nix key generate-secret --key-name desktop-builds-1
nix.buildMachines = map (m: m // {
  protocol = "ssh-ng"; sshUser = "nixremote"; sshKey = "/etc/nix/remote-builder_ed25519";
  systems = [ "x86_64-linux" ]; supportedFeatures = [ "big-parallel" ];
}) [
  { hostName = "192.168.8.229"; maxJobs = 2; speedFactor = 1; }   # prodesk5, 6 cores
  { hostName = "192.168.8.153"; maxJobs = 2; speedFactor = 2; }   # gmktec, 8 cores, also runs game servers
  { hostName = "192.168.8.222"; maxJobs = 1; speedFactor = 1; }   # prodesk7, inside mmtest.slice
];
programs.ssh.knownHosts = {
  # each node's /etc/ssh/ssh_host_ed25519_key.pub, filled in by the human (not read here)
};
```
- `max-jobs = 2` stays as `docs/nix.md` sets it deliberately.
- The root key is generated by the human: `ssh-keygen -t ed25519 -N '' -f /etc/nix/remote-builder_ed25519`.

**Homelab** (a new role, `nix-remote-builder`, in `playbooks/nodes.yml` for prodesk5, gmktec and prodesk7):
- **User:** system user `nixremote`, home `/var/lib/nixremote`, with one `authorized_keys` line:
  `restrict,command="/nix/var/nix/profiles/default/bin/nix-daemon --stdio" ssh-ed25519 <desktop root key>`.
- **`/etc/nix/nix.custom.conf`:** `extra-trusted-public-keys = desktop-builds-1:<public key>`, plus `max-jobs` and `cores`: prodesk5 2 and 3, gmktec 2 and 4, prodesk7 1 and 4.
- **`nixremote` is not a trusted user.** A trusted user can set `sandbox = false` or `extra-sandbox-paths` and so read prodesk7's PVCs, which hold the forward window's recordings. An untrusted user cannot. Signed paths from this PC replace the trust a remote build otherwise needs.
- **Verify on deploy (prodesk7):**
  - a build appears under `mmtest.slice` (`systemd-cgls /mmtest.slice`): ssh-ng's `nix-daemon --stdio` proxies to the system daemon, whose builds run in its slice;
  - `nix build --option sandbox false …` as `nixremote` is refused.
- **`mm-test-node`, reduced to the cap:**
  - **keep:** the image, the `/nix` bind, the Determinate install, `nix.custom.conf`, the daemon drop-in into `mmtest.slice` and `mmtest.slice.j2`, and the GC service and timer;
  - **add** to the daemon drop-in the `InaccessiblePaths=` list now in `mm-tests@.service.j2:28`, and `ProtectHome=yes`. The isolation `CLUSTER.md` promised the test unit ("sees none of k3s, the PVCs or `/home`") then holds for the daemon that now runs the builds;
  - **delete:** `files/mm-tests` (21 lines), `files/mm-tests-run` (8), `templates/mm-tests@.service.j2` (28), the `stage` and `runner` directories, and their tasks.
- **Delete** `roles/moneymachine-test-worker` (11 lines). The new role installs Nix on gmktec.
- **Fix** `docs/moneymachine.md:19–24`: it names `ops/remote_test.py`, already stale. One sentence on the builders replaces it.
- **Node checkouts:**
  - the human or the builder runs `rm -rf ~/.cache/mm-runner` on prodesk5 and gmktec, after `ops/shards.py` is deleted;
  - prodesk7's `/var/lib/mmtest/{stage,runner}` leave with the role, as `state: absent`;
  - this PC's `~/.cache/mm-shards/` is deleted.

### How a session runs the suite afterwards

1. `git add` any new file: a flake sees only tracked files.
2. `nix run .#test`, from the worktree:
   - first, the checks: evaluated here, built on the three nodes and here, skipped where cached;
   - then the `local` tests here.
   - `nix build -L .#checks.x86_64-linux.gate` runs one group.
   - `nix log <drv>` shows a failure's full output.
3. Before a commit, the hook runs `progress-cap` and the commit-time test.

---

## Phase C

### 7. The Homelab change

- **What:** the role, the reduction, the deletions and the docs line of the plan.
- **Who:** the builder writes them on a Homelab branch. The human runs `ansible-playbook` (the operator).
- **Risk:** prodesk7 holds every live recording.
  - The cap is the existing `mmtest.slice`: 5 GiB, CPUs 0 to 9, idle CPU weight, and I/O caps on the image's device. The daemon's builds already sit in it.
  - The isolation for the PVCs moves from the deleted unit to the daemon drop-in and Nix's sandbox. Both verifications above are required before item 9.

### 8. This PC's builder configuration

- **What:** the dotfiles lines of the plan.
- **Who:** the human applies them with `nixos-rebuild switch`.
- **Done when:** `nix build --max-jobs 0 -L .#checks.x86_64-linux.kernel-cargo` completes on a remote builder.

---

## Phase D

### 9. `ops/shards.py`, its test, cache and node checkouts (865 lines, plus 22 in `conftest.py`)

- **Paths:**
  - `ops/shards.py` (468 lines);
  - `ops/test_shards.py` (397 lines);
  - `conftest.py:29–31` (`--shard-report`) and `:47–64` (`ROWS`, `pytest_runtest_logreport`, `pytest_sessionfinish`), with `json`/`Any` imports if unused;
  - `~/.cache/mm-shards/`, and the node checkouts of item 7;
  - `CLUSTER.md` §7 (`:199–244`), rewritten as "§7. Tests": the plan's check table in one paragraph, the `local` set, and the builders' caps;
  - `CLAUDE.md:123` (advisor): "**Full test suites:** `nix run .#test` from the worktree (`CLUSTER.md` §7): the flake checks build on the remote builders, cached by their inputs, then the tests marked `local` run here. A flake sees only tracked files, so `git add` new ones first."
- **Advisor's PROGRESS line:** `PROGRESS.md:14` ("prodesk7 also runs test shards …") goes.
- **Evidence:** `git grep -n -E 'ops\.shards|ops/shards|shard-report'` finds only `CLAUDE.md:123`, `CLUSTER.md:203–238`, `conftest.py:30, 51` and `ops/test_shards.py:13`. `gate/compute.py` stays: `ops/jobs.py`, `reference/differential.py` and `kernel/tests/test_rust.py` use `workers()`.
- **Order:** only after one full `nix flake check` has passed with the remote builders configured (items 6 to 8). Until then, `shards.py` is the working runner.
- **Risk:** low once the order holds. The decision of 2026-11-12 01:51 UTC (2026-11-11 20:51 EST) names this deletion.

---

## Phase E

### 10. The launchers become one script behind flake apps (shell −78, of which 33 untracked; +≈45)

`ops/builder.sh` (41 lines) and `data/builder/run-architect.sh` (33, untracked, in the main checkout) duplicate one mechanism:
- a uuid;
- a `log.tsv` start and exit line;
- a `/tmp/<x><id>` directory for `TMPDIR` and `CLAUDE_CODE_TMPDIR`, removed at exit;
- a `systemd-run` unit capped at `MemoryMax=11G`, `MemorySwapMax=2G`, `OOMPolicy=continue`;
- `nix develop -c claude -p --name '<role>: <task>'`.

They differ only in data: the role name, model, effort, the prompt (a fixed wake-up line, or a header file plus a brief), `--resume`, the working directory, and whether the call waits (a scope) or detaches (a service). Add to that `CLAUDE.md:121`'s ad hoc recipe, `systemd-run --user --scope -p MemoryMax=… -p MemorySwapMax=1G choom -n 1000 -- nix develop -c …`.

- **Replacement:** one script, `ops/session.sh`, packaged by `writeShellApplication` with pinned `runtimeInputs` (`coreutils`, `util-linux` for `flock`, `procps`). `systemd-run`, `claude` and `nix` stay the host's, as now.
  - `apps.session`: `at <when> <role> <task> [model] [stop]` and `run <role> <task> [model] [stop] [--brief <file>] [--resume <id>] [--dir <worktree>] [--effort <e>]`. Role `builder` keeps the busy-defer rule. Role `architect` defaults to `claude-fable-5-2[1m]` and effort `xhigh`, reads `data/builder/architect-header.txt`, and detaches.
  - `apps.heavy`: `<memory> <command…>`, CLAUDE.md's recipe.
- **Tests:** `ops/test_builder.py` (64 lines) is rewritten against the new script with the same stubs. A session that has not read the script writes it from these behaviours:
  - a named session with its id logged at start and exit;
  - a private temporary directory removed at exit;
  - a stop time bounding the scope;
  - deferral while a builder runs;
  - an architect session that detaches and logs its model.
- **Deletes:**
  - `ops/builder.sh`;
  - `data/builder/run-architect.sh`, only when no `mm-architect-*` unit is active (`systemctl --user list-units 'mm-architect-*'`). Session `7049e7c6` was started by it at 01:08 UTC (2026-11-11 20:08 EST). The script itself exits at launch, but `data/builder/log.tsv` and the `.out` files stay.
- **Docs:**
  - `CLAUDE.md:121, 124` (advisor): `nix run .#heavy -- <memory> <command>` and `nix run .#session -- at <when> builder <task> [model]`;
  - `PROGRESS.md:21` (advisor): "through `nix run .#session -- run architect …`".
- **The human's decision lists "builder wake-ups" among the units to declare. That is a divergence, recorded here (CLAUDE.md §1):** a wake-up is a time chosen at runtime by a session. A declared unit holds a fixed schedule and changes only by a rebuild. The wake-ups stay transient `systemd-run --on-calendar` timers, created by the app, which is already systemd's own mechanism for them.

### 11. The user timers become declared units (32 unit-file lines and 4 shell lines become a ≈30-line module)

- **Paths:**
  - `ops/mm-diskguard.service` and `.timer`;
  - `ops/oci/mm-oci-pull.service` and `.timer`;
  - `ops/diskguard.sh`.
  - Today they are symlinked into `~/.config/systemd/user/` from the main checkout (`ls -la ~/.config/systemd/user`), and both timers are active (`systemctl --user list-timers`).
- **Replacement:**
  - `ops/units.nix`, exported as `homeManagerModules.default`: `systemd.user.services` and `timers` with the same schedules (`hourly`, `*:0/10`, `Persistent=true`).
  - Two apps:
    - `apps.diskguard`: `cd` to the checkout and `exec python ops/diskguard.py` with the flake's Python;
    - `apps.oci-pull`: the same for `ops/oci/pull.sh`, with `rsync`, `openssh` and Python as `runtimeInputs`.
  - Each runs the main checkout's files, so `CLUSTER.md` §5's rule holds: change the guard by merging into the main checkout.
  - dotfiles imports the module through an input `git+file:///home/kevin/repos/moneymachine`. A schedule change then needs a lock update there. The alternative, the same module in dotfiles' `home/`, is equally small. It is the human's choice, since dotfiles is the human's repo.
- **Order:** these timers guard the only copy of the forward window's Hyperliquid days (on the VM) and the mirror's capacity.
  1. The human switches dotfiles with the module.
  2. `systemctl --user disable --now` the two old timers, removing their symlinks.
  3. Confirm one run of each new unit in the journal, and `data/live-oci/last-pull` advancing.
  4. Only then delete the repo files.
  - `pull.sh` alarms through `diskguard` after an hour, so a gap of minutes is safe.
- **Docs:** `CLUSTER.md:163` ("the existing `mm-diskguard.timer` through `ops/diskguard.sh`") and `PROGRESS.md:15–16` (advisor).
- **Not in this pass:** the Oracle VM's move to NixOS. The decision orders it last, and the VM keeps the only copy of forward-window days until the pull includes them after 2027-01-31.

---

## Phase F

### 12. Stages 8 and 9 in `audit/criteria.md` (285 lines): the advisor's decision

- **What:** `audit/criteria.md:1135–1420`, stage 8 (C8) and stage 9 (C9). No stage 11 section exists. Stage 11's one mention (`:1142`) is inside C8.
- **Evidence:**
  - Neither stage judged anything. No `audit/stage9/` exists.
  - `PROGRESS.md:46` says stage 8 is recording only and admits no class.
  - The human allowed deleting their criteria (2026-11-11 21:48 UTC (16:48 EST)).
- **The collision:** `paper-changes.md` D5 and `rearchitecture:audit/program/criteria-notes.md` plan the opposite, appending "superseded" notes beneath C8 and C9. They were written at 21:36 UTC (16:36 EST), before the human's leave.
- **Recommendation:** delete both sections, leaving one dated line in their place: "Stages 8 and 9 were deleted on <date>, superseded before anything was judged (`audit/program/architecture.md`, revision 4). Their frozen text is at `ab42e5e:audit/criteria.md`. What would revive them is in the paper's roadmap."
  - Then, on `rearchitecture`, cut `criteria-notes.md` to its stage 1, 2 and 4 qualifications.
  - Its stage 10 note is for the withdrawn event-contract instance, its positive-control note for the withdrawn draft, and its stage 7 note says "No note", so all three are stale.
  - D5's row for it changes to match.
- **Kept regardless:** `audit/stage8/scope-manifest.md`, `exposure.md` and `databento-pricing.json`.
  - `venue/sources.toml:163, 185, 535` cite them in live certificates.
  - `CLAUDE.md:80` and the 2026-10-26 licensing decision rest on the manifest's debugging views.
  - `scope-manifest.md:117` cites `sources-survey/`, so the survey stays with it.
- **Risk:** none to any result. It is reversible by git.

### 13. The stage 3 `agent-real` mechanism (≈1,000 lines), on the commit `criteria: study 1`

- **Paths:**
  - `gate/agent/campaigns.py`'s real-only functions, `claims` (`:600`) through `comparison` (`:870–899`), with `REAL_REPORT_FROM` and `HOLDOUT_RECORD`. That is about 260 lines.
  - **Keep:** `evaluations` and `evaluations_made`, which study 1 uses, and `NO_CLAIM`, `audit_holds` and `cohort`, which `criteria/test_stages3to5.py` uses.
  - `gate/tests/test_agent_real.py` (713 lines);
  - `ops/live.py:107–115` and its `"once"` handling (`:226–228`), and the matching `ops/test_live.py` assertions;
  - `cli.py`'s `agent-real`;
  - `CLUSTER.md:53, 69–70`.
- **Evidence:**
  - The human's rule of 2026-11-09 ties this to whether the positive control's criteria reuse the release path.
  - Study 1's plan (`rearchitecture:audit/program/briefs/1-positive-control.md`) uses `run_agent`, `series_inputs`, `crashed`, `evaluations_made`, `wait_for_room` and `windows`, and "reads nothing under `data/holdout/`".
  - `grep -n 'release\|both_arms\|real('` on the plan finds no release path.
  - `gate/control/` on `rearchitecture` imports `campaigns` for those functions only.
- **Call:** delete in the same commit as `criteria: study 1`, or right after it, if the committed criteria still have no release path.

---

## Kept, and why

| What | Why |
|---|---|
| `gate/agent/{brief,research,swarm}.md`, `daemon.py`, `harness.py`; `sandbox/{session,server,client,egress}.py`; `flake.lock` and the `claude-code` derivation | `harness_hash`'s inputs, including `claude`'s store path. `sandbox/session.py:1–2` still says the client is shared with "the thesis agents". It is fixed at the next harness fork. |
| `gate/search.py`, `ingest/events.py` | `search.identity`, and the `code_sha256` of derived versions |
| `kernel/` (sources, `Cargo.lock`, `DSL.md`, `mm/tests/c41/*.f64`), `kernel/mutants/` | The kernel of the pilot's judged runs. `DSL.md` is pinned by `gate/tests/test_agent_dsl.py`. |
| `audit/stage10/manifest.json` | The record of the seven frozen versions. The paper (`rearchitecture`) and `docs/findings.md`'s planned row cite it. |
| `ingest/{record,sources_record,datalayer,hl,live,policy,terms,units}.py` | The deployed recorders' code. `ingest/record.py:150`'s "thesis track's 120" and `terms.allowlist`'s `retrieval` keyword are inert without the thesis, and go with the next recorder image. |
| `venue/sources/`, `venue/sources.toml` | Live certificates. The `retrieval = true` flags (6) and the stage 10 comments record operator decisions and go with the next certificate revision. |
| The mirror: `ops/live.py`'s `mirror`, `verify`, `LEDGERS = ("thesis", "agent")`; `ops/diskguard.py`'s `VOLUMES`; their tests' `"thesis"` volume fixtures | The `thesis` PVC still holds recordings, which the mirror copies and checks daily. |
| `data/thesis`, the `thesis` PVC, `data/builder/log.tsv` and `*.out` | Recordings and logs. |
| Study 1's stack: `gate/{markets,search,campaign,sweep,compute,kernel}.py`, `gate/agent/`, `sandbox/`, `ops/jobs.py` | Revision 4 §10, "Used". Study 1's tests check `harness_hash()` begins `6a335714`. |
| `ingest/archive.py`, `ingest/ARCHIVE.md`, `lz4`, `boto3` | Study 2's archive reader (the human, 2026-11-11). |
| `ops/oci/*`, the `recorder` and `cloud` shells | The VM keeps the only copy of forward-window days. Its move to NixOS is last. |
| `conftest.py`'s `build_once`, memory watcher; `ops/test_guard.py`, `ops/runaway.py` | They are still needed under the checks: shared kernel builds within a run, and runaway limits inside a build. `audit/2026-11-04-suite-speed.md` stays, as the record behind `build_once`. |
| `audit/crossmachine/`, `audit/erasure/{differential,reproduce-*}.json`, all stage 0 to 6 evidence | Judged or recorded results. The paper cites `freeze.md`. |
| The thesis reviews (59 files under `audit/reviews/`) | The record behind C10's revisions and decisions (`audit/criteria.md` cites four). The track is parked, not retired. Moving them to the archive is the human's choice when the track is retired. |
| Stage 7: `audit/stage7/`, C7 in `audit/criteria.md`, the `stage7` branch | Parked, not superseded. Fable's kernel version 2 design (next) may reuse its nine-defect specs. Decide after that design. |
| `docs/future-work.md` | On `main` it has three thesis lines. `rearchitecture` already rewrote the file, and its one remaining mention (`:33`) is rewritten by `paper-changes.md` D2. An edit here would only conflict. |
| `docs/whitepaper.tex` | The paper step's. |
| `ingest/dbnconv` (Rust), Databento modules | The ICE licence reading is pending with the human. |

## Collisions with `paper-changes.md` (`rearchitecture`)

| File | `paper-changes.md` | This list | Resolution |
|---|---|---|---|
| `CLAUDE.md` | D1: lines 31, 47, 52 ("operational layer"), 76, the Tech line, the new findings-index line | Lines 43, 121, 123, 124; "the thesis track's scientific manifest" in line 52's identity list once the track has left `main` | Different lines. The advisor applies both in one pass after `rearchitecture` merges. |
| `PROGRESS.md` | D4 | Lines 14, 15–16, 21 | The advisor's file in both. |
| `CLUSTER.md` | D3: no edit; "the thesis rows … leave with the manifests if the human retires the track" | Items 1, 5, 9, 11, 13 | The track has left `main`, so the rows go. D3's note is superseded. |
| `audit/criteria.md`, `criteria-notes.md` | D5: append notes beneath C8 and C9 | Item 12: delete C8 and C9 | The advisor decides. |
| `briefs/2-thesis-track.md` | D5: add a "Withdrawn" line | Item 4: delete | Delete. Drop D5's row. |
| `docs/whitepaper.tex` | A to C | None | Add to the paper step: `\record{thesis/SCORING.md}` (T1) becomes `archive/thesis:thesis/SCORING.md`. |
| `docs/future-work.md` | D2 | None | No conflict. |
| `gate/NULLS.md` | D5: one sentence | None | No conflict. |

## Outside the repo

- **Homelab:** item 7.
- **dotfiles:** items 8 and 11.
- **The cluster:** item 3.
- **The advisor's auto-memory:** `suite-hang-orphan.md` and `use-idle-capacity.md` describe `ops/shards.py` and the nodes' checkouts. After item 9, rewrite them for `nix run .#test` or delete them. The quota notes `argon-quota-2026-11-07` and `gpt-weekly-low-2026-11-08` expire on 2026-11-13 and 2026-11-14. This reviewer edits none of these files.

## Decisions this list could not make

1. **C8 and C9:** delete, or append superseded notes (item 12). Recommendation: delete.
2. **Whether `nixremote` is untrusted on the nodes.** Recommendation: untrusted, with signed paths. This is a leakage boundary, because a trusted user on prodesk7 could read the PVCs, so it goes to review as `CLAUDE.md`'s Reviews section requires.
3. **The timers' module home:** a flake output imported by dotfiles, or a module in dotfiles itself. The human's repo, the human's choice.
4. **Builder wake-ups as declared units:** not done, a divergence recorded in item 10.
5. **`agent-real`:** waits on `criteria: study 1` (item 13).
