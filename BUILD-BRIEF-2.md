# Builder, round 2: a timed-out request's connection is closed (branch recorder-fixes)

Same rules as `BUILD-BRIEF.md`: do not edit tests or the spec, no patch around a wall, commit each fix, small quota.

**The defect.** `run.ml`'s `read_listings` and `vault.ml`'s `post` each wrap `Net.post`/`Net.post_status` in their own `with_timeout`. On a timeout the request is abandoned but its connection stays open until the server closes it, so a sustained stall leaks a socket at every retry. Spec: `RECORDER.md` item 1 and test 18, `VAULT.md`'s events and test 11 (commit c7f9866). The failing tests are the latest `recorder tests:` commits.

**The fix, at its cause:** the 30 s deadline belongs in `Net` itself: a request not answered in full within it fails and its connection is closed. Then **delete both callers' own timeout wrappers** (`run.ml` `read_listings`, `vault.ml` `post` and its `timeout_s` if nothing else uses it), so one mechanism remains (`CLAUDE.md` §2). The vault's event must still say `timeout` for a timeout.

**Run** `nix build --no-link -L .#checks.x86_64-linux.mmrec-tests 2>&1 | tail -40`; every test must pass.

**Report:** commits, the result, anything stopped with its exact obstacle.
