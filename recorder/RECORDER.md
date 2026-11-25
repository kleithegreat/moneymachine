# The Hyperliquid stream recorder

A spec for an independent implementer. It records Hyperliquid's public market data over its websocket, for every
market Hyperliquid lists: crypto perps on the main dex, and the builder-deployed (HIP-3) dexes' tokenized stocks,
commodities, indices, currencies and rates. It feeds kernel version 2 and study 2's forward test
(`audit/program/kernel-v2.md` and `architecture.md` section 6 on `rearchitecture`), and anything later: the human asked
for "recorders for anything we could possibly need" (`audit/decisions.md`, 2026-11-14). Nothing here is judged, but a
lost recording can't be refetched, so it is held to this spec (`CLAUDE.md`, Correctness).

The cluster's `hl` book-polling recorder (`ingest/record.py`) was retired on 2026-11-22.

## What it records

Coverage is set by Hyperliquid's own listings, re-read every hour, never by a hand-kept list.

1. **Listings, hourly,** by REST (`POST https://api.hyperliquid.xyz/info`): `perpDexs`; `meta` for each dex (`"dex": ""`
   is the main dex); `spotMeta`. Each whole response is stored verbatim. This is also the only history of lot sizes,
   leverage and margin tiers there will ever be: `meta` serves the current state only (fact pack, open question 6).
   A request not answered in full within 30 s of its start (connecting, the TLS handshake and the whole response) fails,
   and whatever it opened is closed: an `error` event, then the retry any failure gets.
   - **A response is whole, or the request failed.** HTTP/1.1 REST requests run through libcurl (`ocamlPackages.curl`,
     per-request fresh easy handle in an Async worker thread, zero shared handle state, `SIGPIPE` ignored). Each request
     opens a fresh connection and closes it when finished, enforcing TLS peer and hostname verification against
     `SSL_CERT_FILE`, `HTTP/1.1`, no redirects, no signals, and a 30 s total timeout. A request succeeds only on a final
     `200` whose body is whole and one strict JSON value:
     - **Framed.** The final `200` response announces its end via `Content-Length` or `Transfer-Encoding: chunked`,
       never both and no other transfer coding; unframed close-delimited responses fail at `head`.
     - **Bounded:** `CURLOPT_MAXFILESIZE_LARGE` rejects announced or overflowing lengths over 16 MiB before body bytes
       are read, and the streaming write callback aborts immediately before buffering past 16 MiB, so memory grows only
       with received bytes (within the pod's 512 MiB limit, `CLUSTER.md`).
     - **Informational replies** (status 100 to 199) are skipped by libcurl: the final reply is the first with status
       200 or more. Any final status other than `200` fails at `status`, and its body is not stored.
     - **Response `Date` header:** a single valid IMF-fixdate `Date` header on the final `200` response (ignoring any
       `1xx` headers) is stored in the response line as `"date"` (otherwise `null`).
     - **Strict JSON:** validated in two steps — an iterative nesting depth check bounded at 64 (preventing
       `Stack_overflow`) followed by `jsont` (`Jsont.ignore`): one RFC 8259 JSON value in valid UTF-8 with only
       whitespace around it (no BOM, no comments, no `NaN`/`Infinity`, no lone UTF-16 surrogates, no trailing tokens).

     A failed request writes an `error` event holding its request body as `request`, the stage it failed at as `stage`
     (`connect`, `tls`, `timeout`, `head`, `body`, `status`, `json`, or `shape` for listings), the bytes of the response
     received as `bytes`, and a fixed reason in the recorder's own words; it never quotes a byte of the response body.
     Nothing of the response is stored, and it gets the retry any failure gets.
   - **A listings read is whole, or it changes nothing.** Every response of the read must be whole and of the venue's
     shape: `perpDexs` an array whose first element is `null`, the main dex, so never empty, and whose later elements are
     objects each with a string `name`, the dex to ask `meta` of; each `meta` an object whose `universe` is an array of
     objects each with a string `name`, a coin of the dex asked, with no `:` on the main dex and beginning `<dex>:` on
     dex `<dex>`; `spotMeta` an object with arrays `universe` and `tokens`. A read with any other response (`[]`,
     `null`, a body cut short) writes an `error` event naming the request and why (quoting no coin or response bytes),
     subscribes nothing, unsubscribes nothing, and is retried as any failure; the listing in force stays. Responses that
     are whole are stored as received either way, each line holding its request (Storage). A builder dex's `meta`
     answered with another dex's universe fails the read.
   - **Only its flag delists a coin:** a whole read whose dex's `meta` marks it `isDelisted`. A coin missing from its
     dex's `universe`, or a dex missing from `perpDexs`, changes nothing.
   - **A failed read is retried with backoff.** A read stops at its first failed request. The next begins after a wait
     that starts at 60 s and doubles with each failed read in a row, never past the listings interval, with ±20 %
     jitter; a whole read resets it.
2. **One `allDexsAssetCtxs` subscription:** funding, mark, oracle, open interest and impact prices for every perp on
   every dex.
3. **For every perp that is listed and not delisted, on every dex:**
   - `trades`;
   - `l2Book` with `"fast": true`: 5 levels a side at full precision, about every 0.55 s for BTC (measured
     2026-11-14: 55 frames in 30 s), the archive's cadence before 2026-06-21.
4. **For every perp on the main dex** (`"dex": ""`): also `l2Book` with no optional fields, 20 levels a side, about
   every 10 s (3 frames in 30 s for BTC). Depth beyond five levels is for the pessimistic fill bound.
5. **Spot, and the builder-deployed dexes' 20-level books, are not recorded.** One IP admits 1,000 subscriptions;
   this recorder takes about 880 (350 perps' two, 179 main-dex books, one).

Coins are named as the API names them: `BTC` on the main dex, `xyz:TSLA` on dex `xyz`.

## Limits it keeps

From Hyperliquid's rate-limit page (certificate `venue/sources.toml` `[hyperliquid]`), per IP:
- at most 10 websocket connections, and 30 new ones a minute;
- at most 1,000 subscriptions;
- at most 2,000 messages sent a minute, across connections;
- the server closes a connection that has received no message for 60 s.

The recorder uses at most 8 connections, leaving 2 for reconnects, and at most 950 subscriptions. Its REST calls are
weight 20 each, about 8 an hour while reads succeed and at most two reads a minute while they fail (What it records,
item 1), inside the cluster address's request budget (`CLUSTER.md`).

**When a new listing would exceed 950,** the recorder subscribes nothing new for it, never drops an existing
subscription, and writes a `refused` event naming the coin.

## Behaviour

- **Planning.** Connections are of two kinds. Deep connections, a quarter of them rounded up (2 of 8), carry only the
  20-level books. Fast connections carry everything else: each coin's `trades` and fast `l2Book` together, spread so
  each fast connection holds about the same number of coins, and `allDexsAssetCtxs` on the first.
- **WebSocket handshake.** Each connection generates a standard 24-character padded Base64 `Sec-WebSocket-Key` and
  verifies that the server's `101` response carries a matching RFC 6455 `Sec-WebSocket-Accept` header
  (`Base64(SHA1(key ^ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))`); missing or mismatched values fail the handshake.
  The TLS context probe caches only verified success, so a failed probe never bricks subsequent reconnects.
- **Subscribing.** Each connection sends its subscriptions at most 10 a second, and stores each `subscriptionResponse`.
  One that is not acknowledged within 30 s is an `unacked` event, and it is retried on the next reconnect.
- **Heartbeat.** A connection that has received nothing for 30 s sends `{"method": "ping"}`.
- **Reconnecting.** A connection that closes, errors, or receives nothing for 45 s is closed and reopened. Backoff starts at 1 s and doubles to 60 s, with
  ±20 % jitter, and resets after 10 minutes up. On reopening it resubscribes everything it held.
- **Listings change.** Each hour's whole listings read is compared with the listing in force. A new perp is
  subscribed. A delisted one (What it records, item 1) is unsubscribed and stays recorded up to then.
- **Failures stay in their connection.** Anything raised while a connection connects, handshakes, subscribes, reads or
  writes is that connection's `error` event, with what was raised as its reason, and the connection reopens with
  backoff. No connection's failure ends the process (on 2026-11-14 a server closing during the websocket handshake
  raised `Failure "websocket handshake: eof"` and killed the recorder).
- **Stopping.** On SIGTERM it stops reading, flushes and closes every file, then exits with code 0 within 10 s. Every
  frame received before SIGTERM is on disk.

## Storage

Under one root, `data/ws/`:

```
<root>/<channel>/<YYYYMMDD>/<HH>.<run>.jsonl.zst     channel ∈ trades, l2Book, l2Book-fast, allDexsAssetCtxs, events
<root>/listings/<YYYYMMDD>/<HH>.<run>.jsonl.zst      one line per REST response
```

`<run>` is `max(now_ms, max_existing_run + 1)` across existing recording filenames under `<root>`: each run writes its
own new files (`O_CREAT | O_EXCL`), and `<run>` is strictly monotonic across restarts even if the wall clock steps
backwards. Recordings made before this rule are one `<HH>.jsonl.zst` per hour, read the same way.

The hour is the UTC hour of the receive time, or the latest hour this run has already opened if that is later: a clock
stepping back never reopens a closed file.

- **A line** is one received frame: `{"recv": <ms since epoch, receive time>, "conn": <k>, "msg": <frame>}`. A REST
  response's line is `{"recv": <ms>, "conn": null, "request": <the request body>, "date": <IMF-fixdate or null>, "msg": <the response>}`:
  no socket received it, and the request says which dex a `meta` describes. `<frame>` is the server's text, spliced in
  byte for byte, except that a raw CR or LF becomes a space. JSON forbids raw control characters inside strings, so
  this changes no value. Nothing is parsed into a different shape or dropped.
- **Routing.** A single-pass zero-AST scanner extracts the top-level `channel` field (validating RFC 8259 JSON syntax
  with depth <= 64, handling string escapes and skipping nested structures without allocating an AST). A frame goes to
  the file of its `channel` field, except that an `l2Book` frame received on a fast connection goes to `l2Book-fast`.
  `subscriptionResponse`, `pong`, `error`, anything unknown, and invalid JSON go to `events`.
- **Events** also record the recorder's own facts, one line each, with `"msg": {"event": ...}`:
  - `start` and `stop`;
  - `open`, `close` and `error` for each connection, with its reason: the actual error raised, never a timeout that
    hides it;
  - `subscribed`, `unacked` and `refused`;
  - `listing`: the first read after a start is one event with each dex's count of perps; each later read gives one
    event per coin added or delisted, with `coin`, `dex` and `change`.

  Recorder-wide events (`start`, `stop`, `listing`, `refused`) carry `"conn": null`. Fields are named `coin`, `dex`,
  `channel` and `reason` where they apply.

  Every gap is therefore readable from `events`. Missing data is recorded, never filled.
- **Compression.** A file is one zstd stream (level 9, with its checksum), flushed every second or every 1 MiB of
  lines, whichever comes first, and ended when the file closes.
  - Flushing keeps each second's context for the next, which halves the size against a zstd frame per second (measured on
    2026-11-14's hour 04 UTC: 73 against 161 MB), and a crash still loses at most the unflushed second.
  - Every recording stream has one of **four states** (`rearchitecture-s2` D369):
    - `complete`: clean zstd frame end with verified checksum and non-empty decompressed output ending in `\n`.
    - `cut`: 0-byte file or clean decompression prefix cut mid-frame/mid-line/mid-checksum at EOF without frame or
      checksum corruption; whole lines before the cut are kept (`mmrec cat` exits 0 with a cut note on stderr). Read
      cut files with `mmrec cat`, not the `zstd` tool, which (1.5.7) can stop up to 128 KiB short of a cut without
      saying so (2026-11-14: 3 of 40 random cuts).
    - `malformed`: clean zstd frame end whose decompressed output is empty or does not end in `\n` (`mmrec cat` exits 2
      with an error on stderr).
    - `corrupt`: zstd decompression error, bad checksum, or invalid magic header — **feeds zero lines** (`mmrec cat`
      writes nothing to stdout, prints an error on stderr, and exits 2).
- **Files are append-only.** Nothing rewrites, renames or deletes a recording. A file is written by one run only; at
  the hour's end, or when the run stops, it is closed and never opened again.

## The forward window

The recorder only writes. Recordings in [2026-11-01, 2027-01-31) are read for integrity only, never for prices or
returns: status, sizes, hashes, file and line counts, gaps (`CLAUDE.md`, Holdout). The integrity tool reports exactly
those, per channel and hour, and parses only the `channel` and `event` fields.

## Interface

- **`mmrec run <root> [--connections 8] [--max-subscriptions 950] [--ws-url wss://api.hyperliquid.xyz/ws]
  [--rest-url https://api.hyperliquid.xyz/info] [--listings-interval-s 3600]`.** The URLs and interval exist so tests
  can run against a local fake; production uses the defaults. `--connections` below 2 is refused, since a run needs one
  deep and one fast connection. Unsubscribing repeats the subscription exactly, `"fast": true` included. SIGTERM exits with code 0.
- **`mmrec check <root> <from YYYYMMDDHH> <to>`** prints tab-separated lines:
  - per channel and hour: `hour  channel  bytes  files  lines  state`, where bytes are the hour's files'
    compressed size, and `state` is the worst stream state across the hour's files: `complete`, `cut`, `malformed`, or
    `corrupt` (`corrupt` files contribute 0 lines);
  - then per gap: `gap  conn  from_ms  to_ms`. A gap runs from a connection's `close` or `error` (the earlier, if
    both), or, when a `start` finds it open (the run before was killed), from the last line with its `conn`, to its next
    `open`, or to the end of the range (`to_ms` empty).

  It reads only the envelope fields `recv` and `conn`, and the frame fields `channel` and `event`.
- **`mmrec cat <file>`** decompresses a recording's whole lines to stdout. Exits 0 on `complete` and `cut` (reporting
  the cut on stderr), and exits 2 on `malformed` and `corrupt` (writing zero lines to stdout on `corrupt`). Reading
  prices is the caller's act, under the rule above.
- **Both read as a stream:** their memory does not grow with a file's size (the first `check` of an hour of fast books
  needed 3.6 GB).

## Implementation

- **OCaml 5.4.1 with dune,** in `recorder/`, built by Nix as `packages.mmrec`, with its tests as a flake check. Every
  library comes from the pinned nixpkgs, so `flake.lock` does not move.
- **Jane Street's stack:**
  - `core`, `async`, `async_ssl` and `async_websocket` (v0.17);
  - `ppx_expect` and `base_quickcheck` for tests;
  - `ppx_jane` for derivers.
- **REST & JSON:** `curl` (`ocamlPackages.curl` / libcurl) handles HTTP/1.1 REST calls on fresh per-request handles;
  `jsont` validates strict RFC 8259 UTF-8 JSON (bounded to depth 64); a zero-AST scanner routes WebSocket frames;
  `yojson` parses listings, events, and subscription acks. Frames are written as received, not re-serialized.
- **zstd:** its streaming `ZSTD_compressStream2` and `ZSTD_decompressStream`, through one small C stub file using
  `caml_alloc_custom_mem` (`ZSTD_sizeof_CCtx` / `ZSTD_sizeof_DCtx`) and raising typed `Zstd.Error`.
- **Style and handlers:** `ocamlformat` (`janestreet` profile) and `ppx_js_style`, every warning an error (`recorder-style`
  flake check). No wildcard exception handlers (`with _ ->` or `exception _ ->`) exist in `recorder/src/`.
- **Deployment:** StatefulSet `ws` in `moneymachine-live` (`ops/live.py`, `CLUSTER.md` section 2):
  - its own local-path PVC `ws` on prodesk7;
  - requests 250m and 512Mi;
  - the cluster image, with `mmrec` added.
- **No mirror, for now:** the PVC `ws` is the recordings' only copy, by the human's choice (2026-11-14). A second copy
  waits for a disk with room.

## Storage budget

Hour 04 UTC of 2026-11-14, a quiet Saturday hour, measured 1.27 GB of lines, 161 MB as a zstd frame per second, and 73 MB as
one stream flushed each second: about 1.8 GB a day. The 300 GiB PVC (prodesk7 had 392 GB free) then lasts months
even if busy days run three times that. Nothing alarms on the PVC's fill while it is not mirrored: the advisor checks
it by hand.

## The behaviour its tests must show

Tests run offline against a local fake websocket server (no TLS) and a fake REST client. Kill tests kill the process.

1. **Lines.** A frame is written byte for byte inside its line, except CR and LF, which become spaces. A frame with a raw
   newline between tokens round-trips to an equal JSON value.
2. **Routing.** Each channel's frames land in its file; an `l2Book` frame on a fast connection lands in `l2Book-fast`,
   one on a deep connection in `l2Book`. Acks, pongs, errors, unknown channels, and malformed JSON land in `events`.
   The zero-AST router agrees with strict-JSON + Yojson across escaped keys/values, nested `"channel"` fields,
   whitespace, and malformed inputs, allocating zero minor words on normal frames.
3. **Hours and monotonic runs.** A frame received at 10:59:59.999 UTC goes to hour 10, and one at 11:00:00.000 to hour
   11. A restart within an hour (even in the same ms or with the wall clock stepped backwards) chooses a strictly larger
   `<run>` and writes a new file without modifying earlier files.
4. **Compression and stream states:**
   - a closed file decompresses, with the `zstd` tool, to exactly the lines written, its checksum verifies, and `check`
     reports `complete`;
   - a file cut at any byte (including 0 bytes or 1–3 bytes into the trailing checksum) yields whole lines only, a
     prefix of those written, exits 0 on `cat` with a stderr note, and `check` reports `cut`; cut where a flush ended,
     it yields exactly the lines flushed before the cut;
   - a stream ended cleanly without a trailing `\n` (or an empty zstd frame) is reported `malformed` by `check` and
     exits 2 on `cat`;
   - a stream with a flipped block byte, flipped checksum bit, or bad magic header is reported `corrupt` with 0 lines by
     `check`, writes 0 bytes to stdout and exits 2 on `cat`;
   - after `kill -9` during writing, every line received more than 2 s before the kill is read back.
5. **Planning:**
   - with N perps on D dexes, every non-delisted perp gets `trades` and fast `l2Book`, every main-dex perp also gets
     20-level `l2Book`, and there is one `allDexsAssetCtxs`;
   - subscriptions never exceed the maximum; a coin's `trades` and fast `l2Book` share a fast connection; a deep
     connection carries only 20-level books;
   - past the maximum, a new listing is `refused` and nothing existing is dropped.
6. **Listings.** A coin added between two hourly reads is subscribed; one marked `isDelisted` is unsubscribed; both
   are events. Every listings line holds its request. **A read that is not whole changes nothing:** after a healthy
   catalog, a `200 []` for `perpDexs`, a `null`, and a `spotMeta` cut short each give one `error` event, send no
   `unsubscribe`, and leave every subscription in place; so does a whole main-dex `meta` that omits a subscribed coin
   followed by a `spotMeta` that fails; the next whole read applies its changes as usual. **Absence changes nothing:**
   a whole read whose `perpDexs` is `[null]` after a catalog of several dexes, or whose main-dex `universe` omits a
   subscribed coin or is `[]`, sends no `unsubscribe` and writes no `listing` event.
   - **Nothing early, nothing cut:** the bytes of a cut response that were sent are not stored; the next whole read
     changes nothing while its `spotMeta` is held back (no `subscribe`, no `unsubscribe`, no `listing` event); and the
     listings lines are exactly the whole `200` responses sent, in order, each with its request and `"conn": null`.
   - **A foreign catalog:** a builder dex's `meta` answering with main-dex coins, one of them flagged, fails its read
     like the others, and unsubscribes nothing.
   - **Retries:** with `spotMeta` failing every read, reads begin 60 s and then 120 s apart, within the jitter, and
     never two within 48 s; after a whole read, the next failure's wait is 60 s again.
7. **Reconnecting:**
   - the fake server closing a connection gives `close`, then `open` after the backoff, and every subscription
     re-sent;
   - backoff follows 1, 2, 4 … 60 s within jitter;
   - no more than 30 connections are opened in any minute, even when every connection fails repeatedly.
8. **Heartbeat.** After 30 s with nothing received, a ping is sent. After 45 s with nothing received, the connection is
   reopened.
9. **Sent-message limits.** Over any minute, the messages sent across connections stay at or below 2,000, at any rate
   of listing changes and reconnects.
10. **Stopping.** SIGTERM flushes every buffer and exits within 10 s, and every file decompresses whole.
11. **Integrity tool.**
    - `check` gives the right byte, file and line counts, stream states, and gaps on a synthetic root, including an hour
      of two runs' files and a file in the earlier `<HH>.jsonl.zst` form;
    - after a `kill -9` and a restart, it gives a gap for every connection open at the kill, from that connection's
      last line;
    - for two roots that differ only in the values of fields other than `recv`, `conn`, `channel` and `event`, its
      output is identical apart from the byte counts;
    - `check` and `cat` on a file of 1 GiB of lines peak below 128 MiB resident.
12. **Acknowledgements.** A subscription the fake never acknowledges gives one `unacked` event 30 s after it was sent,
    and is re-sent on that connection's next reconnect.
13. **Hour end.** At the first frame of a new hour, the previous hour's file is closed and its stream ended: its bytes
    never change again, even across a restart later in the new hour.
14. **Connect errors.** A TLS failure (the fake presents a certificate the CA file does not trust) is an `error` event
    whose reason names the TLS failure, on every connection that meets it, within 5 s.
15. **Failures stay in their connection.** When the fake server closes a connection during the websocket handshake,
    answers the upgrade with something other than `101`, omits or mismatches `Sec-WebSocket-Accept`, or resets a
    connection in the middle of a frame, that connection gives an `error` event naming what happened and reopens, and
    the process keeps running and recording on the others. A handshake that has not completed within 30 s is such a
    failure.
16. **Stalled listings.** A fake REST server that accepts a listings request and never finishes its answer gives an
    `error` event within 35 s; the process keeps recording and retries.
17. **No leaked sockets.** Twenty connects that fail TLS's host check leave the process's open file count where it was.
18. **Stalled requests close.** Five stalled listings requests in a row leave the recorder's open file count where it was
    before the first.
19. **TLS stalls.** Over HTTPS, a listings request whose server stalls in the TLS handshake, before the status line, or
    in a chunked body gives an `error` event within 35 s and leaves the open file count where it was.
20. **Errors after connecting stay reported.** A websocket connection whose TLS session fails after its handshake (the
    fake sends a fatal alert) gives an `error` event naming it and reopens, within 5 s.
21. **Whole responses.** Each fixture's body is otherwise a valid response of the venue's shape, so only what is
    tested can fail it. Each failure gives one `error` event naming the request and the `stage` given here, quoting no
    byte of the response; stores nothing of it; and is retried.
    - **These fail:** a `Content-Length` longer than the bytes sent before the close (`body`, with `bytes` all that was
      sent); a chunked body without its zero-size chunk or closed after it before the final CRLF (`body`); a chunk size
      line `0_` before the final chunk (`json`); two `Content-Length` fields that differ, a value `+N`, an overflowing
      `Content-Length`, both a `Content-Length` and chunking, neither (over plain HTTP, and over TLS closed without
      `close_notify`), and a `103` followed by the close (`head`); a `Content-Length` of 1 GiB, at `head` within 5 s; a
      chunked body that streams on past 16 MiB, before the 30 s timeout, peak resident memory staying under 256 MiB; a
      final `500` (`status`); a body with a comment, a `NaN`, a second value after the first, a non-UTF-8 byte, a UTF-8
      BOM, a lone surrogate (`\ud800`), 65 nested arrays, or 1 MiB of `[` (`json`).
    - **These are whole:** a chunked body with trailer fields; `Content-Length: N, N`; a `100` and a `103` before the
      `200` (preserving the final `200`'s `Date` header as `"date"` while discarding `103`'s); whitespace around the
      value; a 4 MiB body sent in 1 KiB pieces, by length and chunked; a framed response whose server keeps the
      connection open, by length and chunked, stored within 5 s and with no error.
