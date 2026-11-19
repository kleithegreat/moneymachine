# Builder: three recorder defects (branch recorder-fixes)

Three failing tests describe three defects (`git log --oneline 1436d83..HEAD`): `recorder/test/e2e/item16_stalled_listings_e2e.ml`, `recorder/test/vault/vault_corrupt_stored_e2e.ml`, `recorder/test/e2e/item17_tls_fd_leak_e2e.ml`. The spec lines are in commit 492454c (`recorder/RECORDER.md` tests 16 and 17, `recorder/VAULT.md` test 10 and the paragraph on stored identities). Make the tests pass by fixing each cause in `recorder/src/`.

**Your quota is small.** Fix one defect, run the tests, commit; then the next. A cutoff then costs one fix.

**The three causes** (read the code to confirm before changing it):
1. `src/run.ml`'s `watch_listings` → `read_listings` → `Net.post` has no timeout. A listings request not answered in full within 30 s is a failed one (`RECORDER.md`, item 1). `mmvault` already bounds its requests with `Clock_ns.with_timeout`; reuse that pattern, do not invent a second one.
2. `src/vault.ml`'s `decoded` and `stored_identities` catch every exception (`with _ -> ()`, `exception _ -> ()`). Catch only what the spec names: a kill's truncated last frame or line is skipped silently; any other decode or parse failure is one `error` event naming the file, and the run goes on. No handler may catch every exception (`CLAUDE.md` §2).
3. `src/net.ml`'s `connect_tls`: when the TLS session or its host check fails, the TCP reader and writer are never closed. Close them on every failure path.

**Rules:**
- **Do not edit any test file, or the spec.** If a test is wrong, stop and report it with the exact error.
- **No patch around a wall** (`CLAUDE.md` §1): if the fix needs something the spec does not say, stop and report.
- Every warning is an error; `dune build @fmt @check @lint` holds (`ocamlformat` janestreet profile, `ppx_js_style`).
- Run all the recorder's tests: `mkdir -p $HOME/.cache/mm-rec-tests && cd recorder && TMPDIR=$HOME/.cache/mm-rec-tests nix develop ../ -c dune build @runtest @fmt @check @lint 2>&1 | tail -40`. Every test must pass, not only the three.
- Commit each fix on this branch; each message `recorder: ...` ends with the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Do not push. Never use `pkill -f`.

**Report** (your final message): the commits, the full test result, anything stopped with the exact obstacle.
