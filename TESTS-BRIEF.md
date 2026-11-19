# Test writer: three recorder defects (branch recorder-fixes)

You write failing tests from the specification only. **Do not open anything under `recorder/src/` or `recorder/bin/`**: tests are written from the spec without reading the code (`CLAUDE.md`, Correctness). You may read `recorder/RECORDER.md`, `recorder/VAULT.md`, `CLAUDE.md`, and everything under `recorder/test/` (the fake server `support/fake_hl.mli`, `support/harness.mli`, and the existing tests as examples of style).

**Your quota is small.** Commit after each test file, so a cutoff costs one file. Read only what each test needs.

**What to test**, the spec lines added in commit 492454c (`git show 492454c`):
1. `RECORDER.md` test 16, **stalled listings:** a fake REST server that accepts a listings request and never finishes answering gives an `error` event within 35 s, and the process keeps recording and retries. File: `recorder/test/e2e/item16_stalled_listings_e2e.ml`. Extend the fake server only if its interface lacks a stall; keep any extension minimal and in `support/`.
2. `VAULT.md` test 10, **corrupt stored file:** a stored fills file with a corrupt frame before its end gives exactly one `error` event naming it, and the run still pulls and stores; a kill's truncated last line gives no event. Put it beside the existing vault tests in `recorder/test/vault/`.
3. `RECORDER.md` test 17, **no leaked sockets:** twenty connects that fail TLS's host check leave the recorder process's open file count (`/proc/<pid>/fd`) where it was. File: `recorder/test/e2e/item17_tls_fd_leak_e2e.ml`. `item14_connect_error_e2e.ml` shows how a TLS failure is provoked.

**Rules:**
- Register each test in its directory's `dune` so `@runtest` runs it.
- Tests must **fail** on the current code (they describe defects) and compile cleanly: every warning is an error; `ocamlformat` (janestreet profile) and `ppx_js_style` hold (`dune build @fmt @check @lint`); no handler catches every exception.
- Run: `mkdir -p $HOME/.cache/mm-rec-tests && cd recorder && TMPDIR=$HOME/.cache/mm-rec-tests nix develop ../ -c dune build @runtest 2>&1 | tail -40`. Report which of your tests fail and why; any other test failing is a problem to report, not fix.
- Commit on this branch, each message `recorder tests: ...` ending with the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Do not push. Never use `pkill -f`.
- If the spec is ambiguous or untestable as written, stop and say exactly what is unclear.

**Report** (your final message): the commits, and for each test whether it fails on the current code, with the failure line.
