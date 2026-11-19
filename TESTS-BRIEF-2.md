# Test writer, round 2: a timed-out request's connection is closed (branch recorder-fixes)

Same rules as `TESTS-BRIEF.md`: write from the spec only, **never open `recorder/src/` or `recorder/bin/`**, commit after each test, small quota.

**What to test**, the spec lines of commit c7f9866 (`git show c7f9866`):
1. `RECORDER.md` test 18, **stalled requests close:** five stalled listings requests in a row leave the recorder's open file count where it was before the first. File: `recorder/test/e2e/item18_stall_closes_e2e.ml`. Reuse the fake's `rest_stall` (round 1 added it) and item 17's way of counting descriptors.
2. `VAULT.md` test 11, **stalled request:** a request the fake accepts and never finishes answering gives one `error` with `timeout` after 30 s, and the fake sees its connection closed. Beside the vault tests in `recorder/test/vault/`; extend the vault fake minimally if it cannot stall or report a close.

**Run** the flake's check, which the round 1 builder found is the working command: `nix build --no-link -L .#checks.x86_64-linux.mmrec-tests 2>&1 | tail -40` (run `git add` on new files first; a flake sees only tracked files). Both tests must fail on the current code; say why each fails.

**Report:** commits; each test's failure line.
