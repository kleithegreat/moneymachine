# Test writer, round 3: item 18's baseline (branch recorder-fixes)

You correct one test. **Do not open anything under `recorder/src/` or `recorder/bin/`**; read `recorder/RECORDER.md` (Storage, and tests 17 and 18), `CLAUDE.md`, and `recorder/test/`.

**The defect in the test.** `recorder/test/e2e/item18_stall_closes_e2e.ml` takes its `before` descriptor count as soon as the first listings read and a stream on each connection are seen, about half a second into the run. By `RECORDER.md` (Storage), a route's hourly file is written at the per-second flush, so the recording's own files may open after `before` is taken. Its `after` count then includes them, and a recorder that leaks nothing fails the test (`open file count 12 after 5 stalled listings requests failed, against 9 before the first`). The builder confirmed that all five timed-out sockets are closed and that the three extra descriptors are the `events`, `listings` and `trades` hourly files.

**The correction.** Take `before` only once the recording's files for those channels exist under the run's root, so that the baseline already holds every file the steady state holds, and still before the first stalled request (keep the existing check on that). Change nothing else about what the test asserts. Do not touch any other test, nor the spec.

**Run** `nix build --no-link -L .#checks.x86_64-linux.mmrec-tests 2>&1 | tail -30` (about 5 minutes). Item 18 should now pass on the current code. If it does not, report the failure line; do not change anything else to make it pass.

**Commit** once, message `recorder tests: item 18 takes its baseline after the hourly files open`, ending with the line `Co-Authored-By: Gemini 4 Hydrogen <noreply@google.com>`. Do not push. Never use `pkill -f`.

**Report:** the commit, and the test result.
