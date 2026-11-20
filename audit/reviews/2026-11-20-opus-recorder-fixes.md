# A fresh Claude Opus session on branch recorder-fixes at 045b4fb, before deployment

Independent review: the reviewer built none of it, ran the full `mmrec-tests` suite in its own worktree (twice, once fresh), and read the three-dot diff from `main`. Verdict: deploy as is. The review, verbatim:

# Opus review of `recorder-fixes` at 045b4fb, before deployment

Fresh Claude Opus 5.5 session; built none of it. Own worktree (`~/.cache/mm-rec-review`, detached at 045b4fb, removed
after). Read: `git diff main...045b4fb -- recorder`, the Neon review of round 2, and the library code the fixes lean
on (async_kernel 0.17 `Monitor.try_with`/`send_exn`, async_unix 0.17 `Writer.transfer`, async_ssl 0.17 `Ssl.client`,
its handshake loop and `with_cleanup`). Ran the suite: as committed (`nix build .#checks.x86_64-linux.mmrec-tests`,
exit 0); again with print lines added to items 19 and 20 (a full fresh run, exit 0); and one reproduction test of my own,
built and run locally in the check's environment (1.1).

## 1. Consequential findings

None. One suspected finding did not survive a reproduction; it is recorded here so the next reviewer need not
re-derive it.

### 1.1 (withdrawn) Could a probe closed by its own deadline leave `tls_context` empty?

- **Suspicion.** `tls_context` (`src/net.ml` 46-72, 83-90) is filled `Ok` only by `to_net`, when `Writer.transfer`
  hands the ClientHello to the TCP writer. This branch registers the TCP transport (`connected tcp`) before TLS and
  puts the handshake under the 30 s deadline, so a deadline can now close the TCP writer mid-handshake. Read from the
  library code: if that happens while the first connect (the probe) is still loading the CA file, `Writer.transfer`
  closes `ssl_to_net_r`, the ClientHello is never written, the handshake reads `Eof`, `Ssl.client` returns
  `Ok session`, the host check fails with "No Peer Certificate", and nothing fills `tls_context`: every later TLS
  connect would wait on it until its deadline, forever.
- **Reproduction** (my own e2e test, not committed): `SSL_CERT_FILE` a FIFO, so the probe's CA load blocks; the
  certificate is written into it at 32 s, after both websocket deadlines and the listings deadline are due. Result:
  the deadlines fire only when the load returns (all three `error` events carry the write's millisecond: the CA load
  holds the OCaml runtime lock, so no timer can fire during it), and a connection opens 1.0 s later (`PASS`). The
  window I described does not exist; at worst it is the few jobs between the load returning and the ClientHello's
  transfer, and the overdue-deadline case above is that window's worst timing.
- **Residual note.** The probe still infers "the context loaded" from a network write. Filling `tls_context (Ok ())`
  also in the `Ok session` branch would state the fact directly (a session exists only after `context_exn`
  succeeded). Hardening, not a fix.

## 2. The two questions asked

### 2.1 `connect_tls`'s `upon (Monitor.get_next_error (Monitor.current ()))`

- **Correct for what it guards.** In async_kernel 0.17 `send_exn` fills the monitor's `next_error` on every error,
  detached (try_with) or not, so the handler runs on the first error raised to the caller's monitor after it is
  installed. The only calls between installation and `opened := true` are `Reader.of_pipe` and `Writer.of_pipe`; the
  case it covers is one of them raising (EMFILE), where it closes the session and `app_reader`.
- **No accumulation today.** `Monitor.current ()` is, in both callers, a monitor made per request or per attempt
  (`post_status`'s `try_with`, `Run.attempt`'s `try_with`). One handler per connection, alive as long as that
  monitor, run at most once. A future caller on a long-lived monitor (main) would accumulate one closure per
  connection that never fires: a slow leak, not reachable now.
- **Cannot close a connection in use.** It acts only while `opened` is false, i.e. before `connect_tls` returns. If
  an error races `opened := true`, the same error has already failed the caller's `try_with`, so the connection is
  being abandoned anyway.
- **Simpler shape (recommended, not blocking).** There are now three cleanup channels for one connection:
  `close_and_raise`'s `close_tcp`, this handler, and the callers' `connected` transport. Since `connect` hands the
  TCP transport to `connected` before TLS, the caller already owns closing it. One channel would do: `connect_tls`
  reports each stage's closer through `connected` (TCP; then session + TCP; then the full close), the callers close
  whatever they last received, and the handler and `close_and_raise`'s `close_tcp` go. `connected` should then be
  required: its `ignore` default silently leaks for any caller that forgets it (both callers pass it).

### 2.2 `post_status`'s `try_with ~extract_exn:true ~rest:(\`Call ignore)`

- **Load-bearing, and correct.** In async_kernel 0.17 `try_with`'s default `rest` is `` `Raise `` (not `` `Log `` as
  the earlier review assumed). Without `` `Call ignore ``, the orphaned request's late failures after a timeout
  (`rest: eof`, `chunked body: eof` when the reader is closed under it) would be raised to the caller's monitor;
  `Run.watch_listings`'s own `try_with` (default `` `Raise ``) would pass them to the main monitor and end mmrec.
- **What it swallows:** only errors after the outcome is fixed: the abandoned request after a timeout, writer and
  TLS teardown errors after a complete response or after a first error. The first error before the outcome is the
  outcome and is re-raised. None of the swallowed ones can change what is recorded or reported: the request's result
  is already decided. Accepted.
- **Bounded:** the outcome comes by 30 s; the close after it is bounded by the two 2 s `force_close`s (TLS) or one
  (plain). Item 19's run: all three HTTPS stalls report `rest: timed out` and leave the descriptor count at 12
  before and 12 after.

## 3. Spec match

- RECORDER.md item 1 (30 s from the start, connecting and handshake included, close what was opened, error, retry):
  matches; item 19 confirms for all three stall points.
- VAULT.md timeout line, test 11: matches (the outer `Clock.with_timeout` correctly removed: `post_status` always
  returns).
- VAULT.md stored identities, tests 10 and 12: matches. `decoded_lines` drops a cut last line, stops at the first
  decode failure and reports it; `add_identities` stops at the first unparseable line; only `Failure`,
  `Json_error`, `Type_error` are caught; only `HH[.run].jsonl.zst` names are read.
- **RECORDER.md item 20 / "the actual error raised": not met as worded (a wrong event reason; no recording
  lost).** The fresh run's error reason for the fatal alert is
  `connection lost: (monitor.ml.Error (Unix.Unix_error "Broken pipe" Writer.of_pipe tls) ...)`. The TLS alert itself
  is caught inside async_ssl (`with_cleanup`, its own `try_with ~rest:\`Log`) and only stored in
  `Ssl.Connection.closed session`, which nothing reads. The event comes 1 ms after the alert and the connection
  reopens, so the outcome the item protects (no 45 s silence) holds; the reason names a broken internal pipe.
  Surfacing `Ssl.Connection.closed session`'s `Error` into the caller's monitor would name it.

## 4. Could each new test pass while its defect remains?

- **Item 20: yes, for "naming it".** `names_tls_failure` accepts the substring `tls`, which the reason carries only
  because `Writer.of_pipe` was given `Info.of_string "tls"`. Any broken pipe on that writer passes. The timing and
  reopen checks are sound.
- **Item 16:** counts any `error` event, websocket ones included (Neon noted it); item 19 filters `conn = None` and
  covers the same path over HTTPS, so the gap is covered elsewhere. Note.
- **Item 17:** strengthened as Neon asked (host-check reason, settled count, control run); a per-failure leak gives
  at least 18 descriptors against a slack of 3. Sound.
- **Item 18/19:** a leak of one descriptor per stall exceeds the `+1` slack (3 stalls). Sound. Item 19 checks only
  a non-empty reason, not `timed out`; the fresh run shows `rest: timed out` in all three. Note.
- **Vault 10:** now cuts a >128 KiB multi-block stream mid-line, checks `new = 3` (the planted prefix is kept),
  exit 0, and the JSON/shape cases. Sound.
- **Vault 11:** asserts a ClientHello reached the fake, one `timeout` error, ≤ 35 s, exit 1, watermark unmoved, with
  an HTTPS control. Sound.
- **Vault 12:** a stray subdirectory, a `.txt` and a `.tmp` change nothing. Sound for those; a directory named like
  a recording (`05.jsonl.zst/`) would still crash `mmvault` with `Sys_error` (pathological; note).

## 5. Notes (no outcome changed)

- `mmvault` lets `Sys_error` from an unreadable stored file escape, as VAULT.md says ("only those failures are
  caught"); the run then dies before flushing its buffered `start` event. Loud, per spec.
- `post_status`'s `over`/`transport`/`connected` triple repeats `Run.attempt`'s. One concept, two copies.
- A response cut by the peer mid-body without `Content-Length` checks is returned as complete by `Reader.contents`
  (pre-existing, not in this diff): mmrec stores the cut listings line, fails to parse it and retries in 10 s.

## 6. What I accept

Round 4 answers Neon's 1.1 to 1.4: the transport's reader, writer and transfer report to the caller's monitor (item
20 shows the reopen within 1 ms); one deadline covers DNS, connect, handshake and response; late errors no longer
reach a monitor that can crash; stored files are filtered by name. The vault changes match VAULT.md and store
nothing less than before (every pulled page is stored regardless of `seen`).

## Verdict

**Deploy as is.** Nothing found can lose or corrupt a recording, hang or stop `mmrec`, or make `mmvault` store less
or hang. Full suite passed twice (once as committed, once fresh with print lines). Worth doing after deployment, in
order: name the TLS failure in item 20's event and tighten its test (section 3, 4); collapse `connect_tls`'s three
cleanup channels into the one `connected` already provides and make `connected` required (2.1); the 1.1 hardening.
