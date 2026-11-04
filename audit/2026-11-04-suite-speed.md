# Pytest suite speed, 2026-11-04

## Scheduler experiment

Full suite, 12 workers (`-n auto`), identical tests and build fixtures:

| Scheduler | Command's wall time | Pytest time | Result |
| --- | ---: | ---: | --- |
| Slow/fast interleaving, load, `--maxschedchunk=1` | 221.14 s | 220.38 s | 1,016 passed, 2 skipped, 24 xfailed |
| Plain worksteal, no chunk limit or collection reordering | 216.04 s | 215.30 s | 1,016 passed, 2 skipped, 24 xfailed |

Worksteal was 2.3% faster, within the human's 10% simpler-wins threshold. Deleted the collection hook, its three newly introduced scheduler-only test cases, and the chunk option. Kept the two new build-sharing regression tests.

Commands ran sequentially under `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=1G choom -n 1000 -- nix develop -c pytest`, with `-o 'addopts=-n auto --dist load --maxschedchunk=1'` or `-o 'addopts=-n auto --dist worksteal'`. Each used a fresh `--basetemp=/dev/shm/mms-<run>`, removed before the run. Compiler caches were retained; session build markers were not. Both runs produced exactly `kernel.built`, `mmdump.built`, and `lean.built`.

## Coverage and isolation audit

Compared all 19 changed existing test files against HEAD with Python ASTs: all 187 test functions retained every assertion (including helper assertions), decorator, parameter, seed and example count. Retained data fixtures have their original scopes; the earlier session-scope changes to `revised`, `market`, and `cases` were reverted. Session build fixtures expose only the binary path or completion, never a shared mutable market, ledger, daemon, campaign, or track. Per-test monkeypatches remain function-scoped; crash-worker replacements stay inside their subprocesses.

Files checked (test-function counts):

- `gate/tests/test_agent_campaigns.py` (28), `test_agent_daemon.py` (7), `test_agent_real.py` (24), `test_compute.py` (3), `test_gate.py` (12).
- `gate/tests/test_kernel_defects.py` (6), `test_markets.py` (5), `test_mechanism_defects.py` (4), `test_search.py` (1), `test_sweep.py` (9).
- `kernel/tests/cli/test_cli.py` (24), `test_differential.py` (1); `kernel/tests/timing/test_timing.py` (3).
- `reference/tests/test_lean_differential.py` (2), `test_resolution.py` (1).
- `thesis/tests/test_crash_recovery.py` (2), `test_daemon.py` (6), `test_registry.py` (8), `test_runner.py` (41).

Collected HEAD from a separate archive and compared node IDs: **1,037 original cases, none removed; 1,039 final cases**, adding only `ops/test_suite.py::test_builds_are_shared_across_processes_but_not_sessions` and `::test_a_failed_build_is_retried`.

Existing behavioral coverage changed: **none**. Setup now compiles each binary once under the cross-worker lock. `Track` still copies and hashes its own pinned binary; only its compiler callback returns the session-built executable. The nested read-only-root campaign runs the identical case with `-n0` rather than starting another parallel suite. The CLI module now explicitly requests the build for every case, removing its former dependency on another test initializing the market first. No production or frozen-identity source changed.

## Invalid runs and failure classification

- Abandoned an initial run after host `/tmp` filled (7.8 GiB tmpfs); ENOSPC failures are not a performance measurement. A duplicate builder was also active initially; it yielded before the valid experiments.
- Disk-backed temporary files avoided ENOSPC but exposed `sqlite3.OperationalError: no such table: disclosures` for the four `day` SIGKILL seeds (7, 29, 101, 307). Reran `day-7` alone: failed both the edited test and an untouched HEAD copy. The same case passed alone on tmpfs. This is a pre-existing, storage/timing-sensitive schema-initialization crash, not an assertion to relax or a seed to remove. No production fix or new xfail was introduced in this speed-only change.
- Two other failures were missing historical search data in this worktree. Linked only `data/store` to the main worktree's existing search store; no holdout was linked or read. Both scheduler runs then exercised the real witness and Lean differential successfully.
- `/dev/shm` is executable tmpfs on this host, matching `/tmp`'s original storage type without deleting anyone else's temporary files. Detailed local logs and command/timing JSON are in `/home/kevin/.cache/mms/`.

## Final configuration: two clean full runs

Default `pyproject.toml` options (`-n auto --dist worksteal`), no command-line scheduler override and no collection hook:

| Run | Command's wall time | Pytest time | Result |
| --- | ---: | ---: | --- |
| 1 | 227.09 s | 225.40 s | 1,013 passed, 2 skipped, 24 xfailed |
| 2 | 229.23 s | 228.49 s | 1,013 passed, 2 skipped, 24 xfailed |

Both full runs started after removing their entire session temporary directory, including build markers, and each produced exactly the three successful-build markers. No failures or flaky cases in either final run. Both reported the same nine existing multiprocessing/fork deprecation warnings. The two skips remain the not-yet-produced stage-4 summary and the opt-in paid model canary; no skip/xfail was added or relaxed. Relative to the earlier reported 581 s baseline, these wall times are about 61% lower (2.5× faster).
