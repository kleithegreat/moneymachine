# Builder, round 4 (branch recorder-fixes)

Rules as in `BUILD-BRIEF.md`: do not edit tests or the spec; no patch around a wall (`CLAUDE.md` §1); commit each fix; run `nix build --no-link -L .#checks.x86_64-linux.mmrec-tests 2>&1 | tail -40`, every test passing. End each commit message with the line `Co-Authored-By: Gemini 4 Argon <noreply@google.com>`. Do not push. Never `pkill -f`.

Read Neon's review (`../moneymachine/audit/reviews/2026-11-19-neon-recorder-fixes.md`) and the spec lines of commit f111468. The failing tests are the latest `recorder tests:` commits. **The design** (the advisor's, re-derived after two rounds of patches; build exactly this):
1. **`connect_tls` uses no `try_with`.** `Async_ssl.Ssl.client` and `check_peer_certificate_host` already return results: match on each, and on `Error` close everything opened so far (the session, then the TCP reader and writer) and raise. Every reader, writer and SSL loop stays in the caller's monitor, so an error after connecting reaches the connection's own handling (Neon 1.1). Close `app_reader` too if `Writer.of_pipe` fails (Neon §3).
2. **One deadline in `Net.post_status`** covers `connect`, the TLS handshake and the whole response. On a timeout, close whatever is open; if `connect` completes after the deadline, close what it returns. A late `Eof` from the abandoned read must not raise into a finished monitor (Neon 1.3). `post` and both callers keep no timeout of their own.
3. **`stored_identities`** lists only `*.jsonl.zst` files under each `<kind>/<YYYYMMDD>/`, as `integrity.ml` does: reuse its filter, do not write a second one.

**Report:** commits, the full result, anything stopped with its exact obstacle.

**Resuming (2026-11-19).** Hydrogen committed round 4's tests (2c78d16 to ea24827). The first builder session was stopped for the night before changing any file: start the design from the beginning.
