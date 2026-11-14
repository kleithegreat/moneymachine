# The Hyperliquid stream recorder

A spec for an independent implementer. It records Hyperliquid's public market data over its websocket, for every
market Hyperliquid lists: crypto perps on the main dex, and the builder-deployed (HIP-3) dexes' tokenized stocks,
commodities, indices, currencies and rates. It feeds kernel version 2 and study 2's forward test
(`audit/program/kernel-v2.md` and `architecture.md` section 6 on `rearchitecture`), and anything later: the human asked
for "recorders for anything we could possibly need" (`audit/decisions.md`, 2026-11-14). Nothing here is judged, but a
lost recording can't be refetched, so it is held to this spec (`CLAUDE.md`, Correctness).

It runs beside the `hl` recorder (`ingest/record.py`), which keeps polling until this one has run cleanly for 30 days
and the two agree where they overlap. Retiring `hl`'s book polling is then a separate decision.

## What it records

Coverage is set by Hyperliquid's own listings, re-read every hour, never by a hand-kept list.

1. **Listings, hourly,** by REST (`POST https://api.hyperliquid.xyz/info`): `perpDexs`; `meta` for each dex (`"dex": ""`
   is the main dex); `spotMeta`. Each response is stored verbatim. This is also the only history of lot sizes,
   leverage and margin tiers there will ever be: `meta` serves the current state only (fact pack, open question 6).
2. **One `allDexsAssetCtxs` subscription:** funding, mark, oracle, open interest and impact prices for every perp on
   every dex.
3. **For every perp that is listed and not delisted, on every dex:**
   - `trades`;
   - `l2Book` with `"fast": true`: 5 levels a side at full precision, about every 0.55 s for BTC (measured
     2026-11-14: 55 frames in 30 s), the archive's cadence before 2026-06-21.
4. **For every perp on the main dex** (`"dex": ""`): also `l2Book` with no optional fields, 20 levels a side, about
   every 10 s (3 frames in 30 s for BTC). Depth beyond five levels is for the pessimistic fill bound.
5. **Spot, and the builder-deployed dexes' 20-level books, are not in phase 1.** One IP admits 1,000 subscriptions;
   phase 1 takes about 880 (350 perps' two, 179 main-dex books, one). Phase 2 runs a second instance on the Oracle VM,
   with its own IP, for spot `trades` and `bbo` and the remaining 20-level books.

Coins are named as the API names them: `BTC` on the main dex, `xyz:TSLA` on dex `xyz`.

## Limits it keeps

From Hyperliquid's rate-limit page (certificate `venue/sources.toml` `[hyperliquid]`), per IP:
- at most 10 websocket connections, and 30 new ones a minute;
- at most 1,000 subscriptions;
- at most 2,000 messages sent a minute, across connections;
- the server closes a connection that has received no message for 60 s.

The recorder uses at most 8 connections, leaving 2 for reconnects, and at most 950 subscriptions. Its REST calls are
weight 20 each, about 8 an hour, inside `hl`'s share of the IP's budget (`CLUSTER.md`).

**When a new listing would exceed 950,** the recorder subscribes nothing new for it, never drops an existing
subscription, and writes a `refused` event naming the coin.

## Behaviour

- **Planning.** Connections are of two kinds. Deep connections, a quarter of them rounded up (2 of 8), carry only the
  20-level books. Fast connections carry everything else: each coin's `trades` and fast `l2Book` together, spread so
  each fast connection holds about the same number of coins, and `allDexsAssetCtxs` on the first.
- **Subscribing.** Each connection sends its subscriptions at most 10 a second, and stores each `subscriptionResponse`.
  One that is not acknowledged within 30 s is an `unacked` event, and it is retried on the next reconnect.
- **Heartbeat.** A connection that has received nothing for 30 s sends `{"method": "ping"}`.
- **Reconnecting.** A connection that closes, errors, or receives nothing for 45 s is closed and reopened. Backoff starts at 1 s and doubles to 60 s, with
  ±20 % jitter, and resets after 10 minutes up. On reopening it resubscribes everything it held.
- **Listings change.** Each hour's listings are compared with the last. A new perp is subscribed. A delisted one is
  unsubscribed and stays recorded up to then.
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

`<run>` is the run's start, in ms since epoch: each run writes its own files, and an hour's recording is every file of
that hour. Recordings made before this rule are one `<HH>.jsonl.zst` per hour, read the same way.

The hour is the UTC hour of the receive time, or the latest hour this run has already opened if that is later: a clock
stepping back never reopens a closed file.

- **A line** is one received frame: `{"recv": <ms since epoch, receive time>, "conn": <k>, "msg": <frame>}`. `<frame>`
  is the server's text, spliced in byte for byte, except that a raw CR or LF becomes a space. JSON forbids raw control
  characters inside strings, so this changes no value. Nothing is parsed into a different shape or dropped.
- **Routing.** A frame goes to the file of its `channel` field, except that an `l2Book` frame received on a fast
  connection goes to `l2Book-fast`. The server's frames do not say which subscription they answer; the connection's
  kind does. `subscriptionResponse`, `pong`, `error` and anything
  unknown go to `events`.
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
  - A file whose stream was never ended (the run was killed) is truncated: the reader reports it, and keeps every
    whole line before the cut.
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
  - per channel and hour: `hour  channel  bytes  files  lines  truncated`, where bytes are the hour's files'
    compressed size, and truncated is `yes` if any of them is;
  - then per gap: `gap  conn  from_ms  to_ms`. A gap runs from a connection's `close` or `error` (the earlier, if
    both), or, when a `start` finds it open (the run before was killed), from the last line with its `conn`, to its next
    `open`, or to the end of the range (`to_ms` empty).

  It reads only the envelope fields `recv` and `conn`, and the frame fields `channel` and `event`.
- **`mmrec cat <file>`** decompresses a recording to stdout. Reading prices is the caller's act, under the rule above.
- **Both read as a stream:** their memory does not grow with a file's size (the first `check` of an hour of fast books
  needed 3.6 GB).

## Implementation

- **OCaml 5.4.1 with dune,** in `recorder/`, built by Nix as `packages.mmrec`, with its tests as a flake check. Every
  library comes from the pinned nixpkgs, so `flake.lock` does not move.
- **Jane Street's stack:**
  - `core`, `async`, `async_ssl` and `async_websocket` (v0.17);
  - `ppx_expect` and `base_quickcheck` for tests;
  - `ppx_jane` for derivers.
- **JSON:** `yojson` reads only `channel`, the listings and the subscription acks. Frames are written as received, not
  re-serialized.
- **zstd:** its streaming `ZSTD_compressStream2` and `ZSTD_decompressStream`, through one small C stub file. No OCaml
  zstd library is in nixpkgs.
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

Tests run offline against a local fake websocket server (no TLS) and a fake REST client. They are written by a session
that has not read the code. Kill tests kill the process.

1. **Lines.** A frame is written byte for byte inside its line, except CR and LF, which become spaces. A frame with a raw
   newline between tokens round-trips to an equal JSON value.
2. **Routing.** Each channel's frames land in its file; an `l2Book` frame on a fast connection lands in `l2Book-fast`,
   one on a deep connection in `l2Book`. Acks, pongs, errors and unknown channels land in `events`.
3. **Hours.** A frame received at 10:59:59.999 UTC goes to hour 10, and one at 11:00:00.000 to hour 11. A restart
   within an hour writes a new file of that hour, and the earlier file's bytes do not change.
4. **Compression:**
   - a closed file decompresses, with the `zstd` tool, to exactly the lines written, and its checksum verifies;
   - a file cut at any byte yields whole lines only, a prefix of those written, and reports the cut; cut where a flush
     ended, it yields exactly the lines flushed before the cut;
   - after `kill -9` during writing, every line received more than 2 s before the kill is read back.
5. **Planning:**
   - with N perps on D dexes, every non-delisted perp gets `trades` and fast `l2Book`, every main-dex perp also gets
     20-level `l2Book`, and there is one `allDexsAssetCtxs`;
   - subscriptions never exceed the maximum; a coin's `trades` and fast `l2Book` share a fast connection; a deep
     connection carries only 20-level books;
   - past the maximum, a new listing is `refused` and nothing existing is dropped.
6. **Listings.** A coin added between two hourly reads is subscribed; one delisted is unsubscribed; both are events.
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
    - `check` gives the right byte, file and line counts and gaps on a synthetic root, including an hour of two runs'
      files and a file in the earlier `<HH>.jsonl.zst` form;
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
    answers the upgrade with something other than `101`, or resets a connection in the middle of a frame, that
    connection gives an `error` event naming what happened and reopens, and the process keeps running and recording on
    the others. A handshake that has not completed within 30 s is such a failure.
