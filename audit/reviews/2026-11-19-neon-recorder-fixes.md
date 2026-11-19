# Neon on branch recorder-fixes at b63e289, before deployment

Model `gemini-4-neon-xhigh` through agy, read-only, from a clean folder holding the branch's `recorder/`, `CLAUDE.md` and the three-dot diff from `main`. Neon built none of it: Claude Sonnet (round 1), Gemini 4 Argon (round 2's fix), Gemini 4 Hydrogen (item 18's baseline). Prompt: `REVIEW.md` in that folder. Reply verbatim:

## 1. Consequential findings (ordered by impact)

### 1.1 `connect_tls` detaches TLS readers, writers, and SSL loops from the caller's monitor (lost recordings / swallowed errors)
- **Where:** [net.ml](recorder/src/net.ml#L101-L107) (`connect_tls`), breaking [net.ml](recorder/src/net.ml#L161-L163) and [run.ml](recorder/src/run.ml#L146-L147).
- **Failure scenario:** `connect_tls` now runs `establish_tls` inside `Monitor.try_with` with default `~rest:`Log`. Inside that child monitor (`M_tls`), `establish_tls` creates `Writer.transfer` ([net.ml](recorder/src/net.ml#L60)), `Async_ssl.Ssl.client` ([net.ml](recorder/src/net.ml#L69-L78)), `app_reader` via `Reader.of_pipe` ([net.ml](recorder/src/net.ml#L88)), and `app_writer` via `Writer.of_pipe` ([net.ml](recorder/src/net.ml#L89-L91)). Once `connect_tls` returns `Ok net`, `try_with`'s deferred is already determined, so `M_tls` switches to its `~rest:`Log` handler and stops propagating exceptions to `Run.attempt`'s `try_with ~rest:(`Call fail) life`.
  On a live `wss://api.hyperliquid.xyz/ws` connection:
  1. A TLS fatal alert / corrupt record causes `Async_ssl` to close `app_to_ssl_r`; `Writer.of_pipe` closes its pipe read end, and the next write (`subscribe` / `ping` / `pong`) raises `Unix_error EPIPE` (or `Writer`'s 2-minute `buffer_age_limit` triggers under backpressure) to `app_writer`'s monitor (`M_tls`).
  2. `M_tls` logs `"Exception raised to Monitor.try_with that already returned"` to stderr and swallows it; `Run.attempt`'s `fail` callback is never invoked.
- **Outcome:**
  - **Lost recordings & wrong event:** If incoming frames also stop, the connection does not fail immediately; it sits dead up to 45 s until `Conn_health` logs `close: "nothing received for 45 s"` (losing up to 45 s of frames on that connection) or waits 5 s in `close_outcome` for `"connection lost: no close"` (hiding the real error behind a timeout, violating [RECORDER.md](recorder/RECORDER.md#L62-L65) and [RECORDER.md](recorder/RECORDER.md#L93-L94)).
  - **Silent write death:** If `app_writer` fails while the server continues streaming existing subscriptions on `app_reader`, `Conn_health.received` keeps resetting the 45 s timer; the connection never reopens, and newly listed coins routed to it are silently never subscribed.

### 1.2 `Net.post_status` puts `connect url` outside the 30 s timeout (hang in `mmrec`; **regression** hanging `mmvault` CronJob)
- **Where:** [net.ml](recorder/src/net.ml#L197-L224) (`let%bind net = connect url` at L199 vs `Clock_ns.with_timeout` at L222) and [vault.ml](recorder/src/vault.ml#L156) (deletion of outer `Clock.with_timeout`).
- **Failure scenario:** Both production binaries call `https://api.hyperliquid.xyz/info`. `connect url` runs `Tcp.connect` (10 s TCP connect timeout; DNS lookup unbounded by it) followed by `connect_tls` -> `Async_ssl.Ssl.client`, which has **no timeout**.
  1. `mmrec` (`watch_listings`) or `mmvault` (`Vault.post`) completes TCP SYN-ACK at `t = 0.05 s` and sends TLS ClientHello; Hyperliquid/Cloudflare/proxy ACKs the TCP segment and stalls before ServerHello (or stalls mid-TLS-handshake).
  2. Because TCP ACKed ClientHello and no TCP keepalive is set, `Async_ssl.Ssl.client` waits on `net_to_ssl` indefinitely and `post_status` never reaches `Clock_ns.with_timeout`.
  3. Even without an infinite stall, e.g. a 9 s TCP connect + 15 s TLS handshake + 20 s HTTP read takes 44 s and succeeds (or 54 s before timing out), exceeding 30 s.
- **Outcome:**
  - **`mmvault` regression (hang & lost hourly snapshots):** Before this diff, `vault.ml` wrapped all of `Net.post_status` in `Clock.with_timeout (30s)`, so a stalled TLS handshake timed out and exited 1. Now `mmvault` **hangs forever**. Because the `vault` CronJob runs with `concurrencyPolicy: Forbid` ([VAULT.md](recorder/VAULT.md#L105-L106)), one hung run permanently blocks all subsequent hourly runs until manually killed, losing hourly `fees` and `orders` snapshots (and eventually fills if left unnoticed).
  - **`mmrec` hang & lost listings:** `watch_listings` **hangs forever**. Hourly `listings` snapshots stop permanently (irrecoverable: [RECORDER.md](recorder/RECORDER.md#L17-L21)), and newly listed/delisted perps are never subscribed/unsubscribed. (Existing WS channels keep recording and SIGTERM still exits via the 8 s shutdown cap in [run.ml](recorder/src/run.ml#L238).)
  - *(Note when fixing: putting `connect` inside the timeout must also close the TCP socket if the timeout fires during `connect_tls`, or a TLS-handshake timeout will leak a descriptor.)*

### 1.3 `Net.post_status` timeout closes `net.reader` while `request ()` is still running (late unhandled exceptions)
- **Where:** [net.ml](recorder/src/net.ml#L200-L224).
- **Failure scenario:** The server accepts a POST and stalls before sending the status line (suspended in `Reader.read_line` at L209), mid-headers (`read_headers` at L212), or mid-chunked body (`read_chunks` at L216, common behind Cloudflare). At `t = 30 s`, `Clock_ns.with_timeout` returns `` `Timeout `` without cancelling `request ()`, and `Monitor.protect` runs `~finally:net.close`. Closing `net.reader` wakes the orphaned `request ()` with `` `Eof ``, which executes `failwith "rest: eof"` or `failwith "chunked body: eof"` (or `status_code` failure on a partial status line) into `Monitor.protect`'s monitor **after** it has already returned.
- **Outcome:** Does not crash `mmrec` or `mmvault` (default `~rest:`Log`), and does not lose data, but emits spurious `"Exception raised to Monitor.try_with that already returned"` errors + stack traces to stderr on every pre-header or chunked timeout. Tests 16 and 18 missed this because [fake_hl.ml](recorder/test/support/fake_hl.ml#L86) sends complete non-chunked headers (`Content-Length: 100000`) plus `[`, suspending `request ()` in `Reader.contents` (L217), which returns `"["` without raising on close.

### 1.4 `vault.ml` `stored_identities` now lets `Sys_error` escape while iterating unfiltered directory entries
- **Where:** [vault.ml](recorder/src/vault.ml#L102), [vault.ml](recorder/src/vault.ml#L127-L130).
- **Failure scenario:** Previously `try ... with _ -> ()` swallowed `Sys_error` from `In_channel.read_all`. Now `Sys_error` escapes (which matches [VAULT.md](recorder/VAULT.md#L42) *"Only those failures are caught"* for genuine I/O/permission failures), **but** unlike [integrity.ml](recorder/src/integrity.ml#L56-L58) and [harness.ml](recorder/test/support/harness.ml#L68-L70), `stored_identities` does not filter for `.jsonl.zst` files or skip subdirectories in `<kind>/<date>/`. If any subdirectory (or stray non-recording file) is ever placed under `fills/<date>/` or `funding/<date>/`, `In_channel.read_all` raises `Sys_error "...: Is a directory"`.
- **Outcome:** `mmvault` crashes on startup before pulling anything (and before `File_writer.close`, losing even the buffered `start` event), failing every hourly run until the entry is removed.

---

## 2. Spec match & test soundness

### Fixes vs. spec lines
- **Change 1 ([RECORDER.md](recorder/RECORDER.md#L20-L21), [VAULT.md](recorder/VAULT.md#L64)):** **Does not match spec** because `connect url` (TCP + TLS handshake) is outside the 30 s deadline (Finding 1.2). Post-connect stalls match spec.
- **Change 2 ([VAULT.md](recorder/VAULT.md#L40-L43)):** Mostly matches spec (including not echoing JSON payloads in `error` events, preserving test 9). One minor spec mismatch: `mmrec_zstd_decompress_step` raises `caml_failwith("zstd: out of memory")` on `malloc == NULL` ([zstd_stubs.c](recorder/src/zstd_stubs.c#L83)), which [vault.ml](recorder/src/vault.ml#L104) (`exception Failure reason`) catches and misreports as a corrupt-file `error` event instead of letting OOM escape (*"Only those failures are caught"*).
- **Change 3 ([RECORDER.md](recorder/RECORDER.md#L216)):** Closes the TCP socket on TLS session/host-check failure, **but** violates [RECORDER.md](recorder/RECORDER.md#L62-L65) and [RECORDER.md](recorder/RECORDER.md#L93-L94) on live TLS connections via monitor severing (Finding 1.1).

### New tests: false-pass / false-fail defects
1. **[vault_corrupt_stored_e2e.ml](recorder/test/vault/vault_corrupt_stored_e2e.ml#L49-L98) (VAULT test 10) — passes while core defects remain:**
   - **Never tests a truncated last line** (despite [VAULT.md](recorder/VAULT.md#L101)): `frame_bytes ~tids:[4; 5; 6]` ([L87-L89](recorder/test/vault/vault_corrupt_stored_e2e.ml#L87-L89)) is ~750 B uncompressed, fitting in one zstd block (<128 KiB). Cutting it in half yields **0 decompressed bytes** from frame 2, so `Buffer.contents out` ends with `\n` from frame 1; the `List.drop_last` branch in [vault.ml](recorder/src/vault.ml#L109) is never executed. A bug that emitted an `error` event on a >128 KiB multi-block page killed mid-line would still pass both test 10 and `vault_kill_e2e` (which never asserts zero `error` events).
   - **Never checks preserved prefix identities (`new` count):** `pulled_and_stored` ([L49-L61](recorder/test/vault/vault_corrupt_stored_e2e.ml#L49-L61)) checks `V.stored_tids ~root = [1..6]`, which the fresh pull from `fake` satisfies on its own even if the planted file's `[1; 2; 3]` were completely ignored (`new = 6` instead of `3`). It also discards `_outcome` ([L70](recorder/test/vault/vault_corrupt_stored_e2e.ml#L70), [L90](recorder/test/vault/vault_corrupt_stored_e2e.ml#L90)) without checking exit code 0, and never tests JSON parse/shape errors inside a valid zstd frame ([vault.ml](recorder/src/vault.ml#L120-L121)).
2. **[item16_stalled_listings_e2e.ml](recorder/test/e2e/item16_stalled_listings_e2e.ml#L46-L78) & [item18_stall_closes_e2e.ml](recorder/test/e2e/item18_stall_closes_e2e.ml#L61-L93) — pass while production TLS stalls remain broken:**
   - [fake_hl.ml](recorder/test/support/fake_hl.ml#L83-L87) and [fake_hl.ml](recorder/test/support/fake_hl.ml#L232) serve REST only over plain HTTP and stall only after full non-chunked headers. Neither test exercises HTTPS/TLS (5 fds per REST connection in prod: TCP + 2 `Reader.of_pipe` + 2 `Writer.of_pipe`), a TLS handshake stall (Finding 1.2), or a pre-header/chunked stall (Finding 1.3).
   - Item 16's `error_events ()` ([L46-L64](recorder/test/e2e/item16_stalled_listings_e2e.ml#L46-L64)) does not filter by `conn = None` or timeout reason, so any unrelated WS error within 35 s plus a 60–85 s REST timeout still passes the 90 s retry check ([L67](recorder/test/e2e/item16_stalled_listings_e2e.ml#L67)). Its recording check ([L76-L78](recorder/test/e2e/item16_stalled_listings_e2e.ml#L76-L78)) is satisfied by frames written before the stall.
3. **[item17_tls_fd_leak_e2e.ml](recorder/test/e2e/item17_tls_fd_leak_e2e.ml#L48-L83) — vacuous pass risk & slow-host flake risk:**
   - **False pass:** [L64](recorder/test/e2e/item17_tls_fd_leak_e2e.ml#L64) counts all `"error"` events without checking that their `reason` is a host-check mismatch (and runs no control). If `localhost` failed before `connect_tls` (e.g., `ECONNREFUSED` or CA error), `errors >= 20`, `accepts = []`, and `many_fds <= few_fds + 3` all pass even with the host-check leak unfixed.
   - **False fail (loaded host):** [L59](recorder/test/e2e/item17_tls_fd_leak_e2e.ml#L59) uses a fixed 5 s sleep rather than waiting for 20+ connects to settle; on a heavily loaded machine where 30 TLS handshakes take >5 s, `settled_fds` can sample >3 in-flight sockets and fail when fixed.

---

## 3. Other issues in the changed code

- **Partial-failure fd leak in `establish_tls`:** [net.ml](recorder/src/net.ml#L88-L91) and [L101-L107](recorder/src/net.ml#L101-L107) — if `Reader.of_pipe` succeeds and `Writer.of_pipe` raises (e.g., `EMFILE`), `connect_tls` closes only TCP (`close_tcp`), leaking `session` and `app_reader`'s two pipe descriptors.
- **Double-wrapped exception reason:** [net.ml](recorder/src/net.ml#L102) uses `try_with` with default `~extract_exn:false` and re-raises `exn` ([L106](recorder/src/net.ml#L106)), nesting TLS errors in a second `monitor.ml.Error` wrapper in `events` (harmless to `item14`'s substring check, noisy in logs).

---

## 4. What I accept

- **`mmvault` storing behavior & flush/open ordering ([vault.ml](recorder/src/vault.ml#L269-L278)):** Moving `stored_identities` after `event t "start"` does not self-read (`events` is never read by `stored_identities`, and `File_writer.add` does not open files until flush/close). `mmvault` always stores every pulled page ([vault.ml](recorder/src/vault.ml#L202)) regardless of `seen`, so `mmvault` cannot store less than before; stopping at the first bad line in `add_identities` and dropping a final non-`\n`-terminated line in `decoded_lines` match [VAULT.md](recorder/VAULT.md#L42) and align with `Recording.fold_lines` and `Harness.whole_lines`.
- **`mmvault` sentinel secrecy ([vault.ml](recorder/src/vault.ml#L104), [L120-L121](recorder/src/vault.ml#L120-L121), [L136](recorder/src/vault.ml#L136)):** Static reason strings (`"unparseable line"`, `"unexpected shape"`, libzstd error names) prevent `U.Type_error` / `Yojson.Json_error` from leaking item prices, sizes, fees, or rates into `events`.
- **`check_peer_certificate_host` socket cleanup ([net.ml](recorder/src/net.ml#L83-L87)):** Closing `session` and then running `close_tcp` cleanly releases the TCP socket and stops `Writer.transfer` / `Reader.pipe` on host-check failure (once fixed without breaking monitor ownership).
- **Item 18 stability ([item18_stall_closes_e2e.ml](recorder/test/e2e/item18_stall_closes_e2e.ml#L58-L96)):** Baseline checks, 10 s retry gap sampling, and hour-rollover behavior are sound against false failures (its gap is strictly coverage of HTTPS/TLS and pre-header/chunked stalls).
