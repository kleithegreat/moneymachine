# Test writer, round 4 (branch recorder-fixes)

Rules as in `TESTS-BRIEF.md`: write from the spec only, **never open `recorder/src/` or `recorder/bin/`**; read `RECORDER.md`, `VAULT.md`, `CLAUDE.md`, `recorder/test/`. Commit after each test. Run `nix build --no-link -L .#checks.x86_64-linux.mmrec-tests 2>&1 | tail -40` (`git add` new files first). End each commit message with the line `Co-Authored-By: Gemini 4 Hydrogen <noreply@google.com>`. Do not push. Never `pkill -f`.

Read Neon's review first (`../moneymachine/audit/reviews/2026-11-19-neon-recorder-fixes.md`): it explains what the current tests miss. The new spec lines are in commit f111468.

**Write, each failing on the current code where the defect exists:**
1. `RECORDER.md` 19, **TLS stalls:** extend the fake to serve REST over HTTPS (item 14's certificate) and to stall (a) in the TLS handshake, (b) before the status line, (c) inside a chunked body. Each gives an `error` event within 35 s and leaves the open file count where it was (take the baseline as item 18 now does, after the hourly files exist).
2. `RECORDER.md` 20, **errors after connecting stay reported:** a websocket connection whose TLS session fails after the handshake (the fake sends a fatal alert, or closes the TLS layer) gives an `error` event naming it and reopens within 5 s.
3. `VAULT.md` 11, **stalled handshake:** `mmvault`'s request to a server that accepts the connection and never completes the TLS handshake gives one `error` with `timeout` within 35 s, and the run exits.
4. `VAULT.md` 12, **stray entries:** a subdirectory and a file not named `*.jsonl.zst` under a stored day change nothing: the run succeeds and its events are as without them.
5. **Strengthen vault test 10** as Neon describes: a truncated last line that spans more than one zstd block (a page above 128 KiB cut mid-line) gives no event; the planted file's identities count (`new` is 3, not 6); the run exits 0.
6. **Strengthen item 17:** require each counted `error` to name the host-check failure, and wait for the connects to settle rather than a fixed 5 s.

**Report:** commits; each test's failure line on the current code, or why it passes.
