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
   - `l2Book` with no optional fields: 20 levels a side at full precision.
4. **Spot is not in phase 1.** One IP admits 1,000 subscriptions; the perps take about 700 (350 perps on 2026-11-14,
   two each, plus one). Spot's 351 pairs need a second IP: phase 2 runs a second instance on the Oracle VM, recording
   spot `trades` and `bbo` there.

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

- **Planning.** Subscriptions are spread over the connections so that each carries about the same number of `l2Book`
  subscriptions. A coin's `trades` and `l2Book` share a connection, so one connection's loss is one gap per coin.
- **Subscribing.** Each connection sends its subscriptions at most 10 a second, and stores each `subscriptionResponse`.
  One that is not acknowledged within 30 s is an `unacked` event, and it is retried on the next reconnect.
- **Heartbeat.** A connection that has received nothing for 30 s sends `{"method": "ping"}`.
- **Reconnecting.** A connection that closes, errors, or receives nothing for 45 s is closed and reopened. Backoff starts at 1 s and doubles to 60 s, with
  ±20 % jitter, and resets after 10 minutes up. On reopening it resubscribes everything it held.
- **Listings change.** Each hour's listings are compared with the last. A new perp is subscribed. A delisted one is
  unsubscribed and stays recorded up to then.
- **Stopping.** On SIGTERM it stops reading, flushes and closes every file, then exits with code 0 within 10 s. Every
  frame received before SIGTERM is on disk.

## Storage

Under one root, `data/ws/`:

```
<root>/<channel>/<YYYYMMDD>/<HH>.jsonl.zst     channel ∈ trades, l2Book, allDexsAssetCtxs, events
<root>/listings/<YYYYMMDD>/<HH>.jsonl.zst      one line per REST response
```

The hour is the UTC hour of the receive time, or the latest hour already opened if that is later: a clock stepping back never reopens a closed hour.

- **A line** is one received frame: `{"recv": <ms since epoch, receive time>, "conn": <k>, "msg": <frame>}`. `<frame>`
  is the server's text, spliced in byte for byte, except that a raw CR or LF becomes a space. JSON forbids raw control
  characters inside strings, so this changes no value. Nothing is parsed into a different shape or dropped.
- **Routing.** A frame goes to the file of its `channel` field. `subscriptionResponse`, `pong`, `error` and anything
  unknown go to `events`.
- **Events** also record the recorder's own facts, one line each, with `"msg": {"event": ...}`:
  - `start` and `stop`;
  - `open`, `close` and `error` for each connection, with its reason;
  - `subscribed`, `unacked` and `refused`;
  - `listing`: the first read after a start is one event with each dex's count of perps; each later read gives one
    event per coin added or delisted, with `coin`, `dex` and `change`.

  Recorder-wide events (`start`, `stop`, `listing`, `refused`) carry `"conn": null`. Fields are named `coin`, `dex`,
  `channel` and `reason` where they apply.

  Every gap is therefore readable from `events`. Missing data is recorded, never filled.
- **Compression.** Lines are buffered and written as one zstd frame (level 3) every second or every 1 MiB, whichever
  comes first, and appended to the hour's file.
  - A file is a concatenation of complete frames, so it only grows.
  - A crash loses at most the unflushed second.
  - A truncated last frame is detectable, and the reader keeps every frame before it.
- **Files are append-only.** Nothing rewrites, renames or deletes a recording. At the hour's end its file is closed and
  never opened again; a restart in the same hour appends to it.

## The forward window

The recorder only writes. Recordings in [2026-11-01, 2027-01-31) are read for integrity only, never for prices or
returns: status, sizes, hashes, frame and line counts, gaps (`CLAUDE.md`, Holdout). The integrity tool reports exactly
those, per channel and hour, and parses only the `channel` and `event` fields.

## Interface

- **`mmrec run <root> [--connections 8] [--max-subscriptions 950] [--ws-url wss://api.hyperliquid.xyz/ws]
  [--rest-url https://api.hyperliquid.xyz/info] [--listings-interval-s 3600]`.** The URLs and interval exist so tests
  can run against a local fake; production uses the defaults. SIGTERM exits with code 0.
- **`mmrec check <root> <from YYYYMMDDHH> <to>`** prints tab-separated lines:
  - per channel and hour: `hour  channel  bytes  frames  lines  truncated`, where bytes are the file's compressed
    size and truncated is `yes` or `no`;
  - then per gap: `gap  conn  from_ms  to_ms`, where a gap runs from a connection's `close` or `error` (the earlier,
    if both) to its next `open`, or to the end of the range (`to_ms` empty).

  It reads only the envelope fields `recv` and `conn`, and the frame fields `channel` and `event`.
- **`mmrec cat <file>`** decompresses a recording to stdout. Reading prices is the caller's act, under the rule above.

## Implementation

- **OCaml 5.4.1 with dune,** in `recorder/`, built by Nix as `packages.mmrec`, with its tests as a flake check. Every
  library comes from the pinned nixpkgs, so `flake.lock` does not move.
- **Jane Street's stack:**
  - `core`, `async`, `async_ssl` and `async_websocket` (v0.17);
  - `ppx_expect` and `base_quickcheck` for tests;
  - `ppx_jane` for derivers.
- **JSON:** `yojson` reads only `channel`, the listings and the subscription acks. Frames are written as received, not
  re-serialized.
- **zstd:** its one-shot `ZSTD_compress`, the frame-size query and `ZSTD_decompress`, through one small C stub file. No OCaml zstd library
  is in nixpkgs.
- **Deployment:** StatefulSet `ws` in `moneymachine-live` (`ops/live.py`, `CLUSTER.md` section 2):
  - its own local-path PVC `ws` on prodesk7;
  - requests 250m and 512Mi;
  - the cluster image, with `mmrec` added.
- **The mirror** treats `*.jsonl.zst` under `data/ws` as files that only grow, as it treats day files. Until it does, it
  copies them whole whenever their size changes.

## Storage budget

This is an estimate to be replaced by a measurement. The archive's `l2Book` files average about 7.5 MB a coin-day
(lz4) for the vault's 17 large coins. Most of the 350 perps update far less often. The first day's measured bytes set
the projection, and `ops/diskguard.py` alarms when the PVC's projected time to full falls under 60 days.

prodesk7 has about 370 GB free. This PC, which holds the mirror, has about 65 GB free: **where the second copy lives
is a question for the human** (PROGRESS, Blockers).

## The behaviour its tests must show

Tests run offline against a local fake websocket server (no TLS) and a fake REST client. They are written by a session
that has not read the code. Kill tests kill the process.

1. **Lines.** A frame is written byte for byte inside its line, except CR and LF, which become spaces. A frame with a raw
   newline between tokens round-trips to an equal JSON value.
2. **Routing.** Each channel's frames land in its file. Acks, pongs, errors and unknown channels land in `events`.
3. **Hours.** A frame received at 10:59:59.999 UTC goes to hour 10, and one at 11:00:00.000 to hour 11. A restart
   within an hour appends to its file.
4. **Compression:**
   - a file of flushed frames decompresses to exactly the lines written;
   - a file cut at any byte yields every complete frame before the cut, and reports the cut;
   - `kill -9` during writing leaves a file whose complete frames all decompress.
5. **Planning:**
   - with N perps on D dexes, every non-delisted perp gets `trades` and `l2Book`, and there is one `allDexsAssetCtxs`;
   - subscriptions never exceed the maximum, and a coin's two subscriptions share a connection;
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
11. **Integrity tool.** `check` gives the right byte, frame and line counts and gaps on a synthetic root. For two roots
    that differ only in the values of fields other than `recv`, `conn`, `channel` and `event`, its output is identical
    apart from the byte counts.
12. **Acknowledgements.** A subscription the fake never acknowledges gives one `unacked` event 30 s after it was sent,
    and is re-sent on that connection's next reconnect.
13. **Hour end.** At the first frame of a new hour, the previous hour's file is closed: its bytes never change again,
    even across a restart later in the new hour.
