# Review of fast-tests by a fresh Sonnet, 2026-11-07

The review as relayed by the coordinator (the reviewer's own text was not passed to the builder; this is the message received):

> A fresh Sonnet reviewed fast-tests: no blocking finding (no false-success path, chunked evidence equivalent or stricter). Please fix these on fast-tests, each from a failing test where it's behaviour:
> 1. shards.py:44 / :141-145: a remote report.json from an earlier run is fetched when ssh died before the rm; it pollutes counts and durations.json. Use a per-run report name (or don't fetch on ssh failure) — pick the simplest that kills the cause.
> 2. No ServerAliveInterval and nothing kills the remote tree on local Ctrl-C/ssh death: orphaned remote pytest holds the node's flock up to 3600 s, and a node going dark hangs subprocess.run forever. Add ServerAlive options and make the remote run die with its ssh session, and an overall bound.
> 3. Skips count as acceptable: a node lacking something the desktop has could skip silently where the desktop would run the test. Make a skip on a node visible and failing-safe.
> 5. durations.json: `took` includes packaging/nix startup so a cold node's slowness inflates and it can starve; stale ids never pruned (unbounded growth); non-atomic write. Measure slowness from pytest's own test durations, prune ids not in the current collection, write atomically.
> Also: test_scoring_differential.py `judge` calls `reached()` only for its hidden asserts — make that explicit. Skip 4, 6, 7, 8.

## Dispositions

1. Done. Each node run has an id; the remote report is `report.<id>.json`, fetched by that name only, and older reports are deleted under the lock.
2. Done. `ServerAliveInterval=15`, `ServerAliveCountMax=4`; the remote script starts a watchdog that kills the session's processes when its parent (the sshd session) is gone, before it waits for the lock; the node run is bounded at 3900 s and the report fetch at 60 s. Test: a launcher is SIGKILLed and the remote test process must die and the lock be free.
3. Done, by the simplest sound rule: every test a node skipped, or gave no result for, is rerun here, and the local result stands.
5. Done. Slowness is the ratio of a machine's measured test seconds to the stored durations of the same tests (those over 0.5 s); stored durations are in this PC's seconds. A full collection (no selection arguments) prunes ids that are gone; a selected run keeps the rest. The file is written by temp file and rename.
- `judge` now asserts the two kinds' outcome explicitly; `reached` no longer asserts.
- 4, 6, 7, 8: not acted on; they cannot change an outcome.
