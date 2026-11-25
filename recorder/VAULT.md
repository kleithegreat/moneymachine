# The vault collector (`mmvault`)

What study 2's forward run needs of one account that the websocket recorder (`RECORDER.md`) does not record: the
account's own fills, its daily funding rows, its fee schedule, and its order history. The requirements are brief 3's
table "What the recorders must hold for the forward run" (`audit/program/briefs/3-kernel-v2.md`); this file says how
they are met, completely enough to implement from alone. Study 2's account is the vault
`0x53375ca9a649f337d83d0834fec0db97640a2a06`.

## Sources

All by REST, `POST https://api.hyperliquid.xyz/info`, public and read-only (`venue/sources.toml`, Hyperliquid):

| Kind | Request | Item cap | Paged by |
|---|---|---|---|
| `fills` | `{"type": "userFillsByTime", "user", "startTime", "endTime", "aggregateByTime": false}` | 2,000 | `time` |
| `funding` | `{"type": "userFunding", "user", "startTime"}` (no `endTime`: the API reads to now) | 500 | `time` |
| `fees` | `{"type": "userFees", "user"}` | none | not paged |
| `orders` | `{"type": "historicalOrders", "user"}` | 2,000 | not paged (the latest 2,000) |

## One run

`mmvault run <root> --user <address> [--rest-url URL] [--now-ms MS]` makes one pass and exits: 0 when every pull
completed, 1 otherwise. Production runs it once an hour (a CronJob); `--now-ms` exists so tests fix the clock. A run is
idempotent: two runs at the same `now` store nothing new the second time except its own events.

Each run, in this order:

1. **Fills, hourly.** From the watermark less an overlap of one hour, to `now`: request a page; store it; if it holds
   the cap, request the next starting at its last item's `time`, inclusive; stop at the first page under the cap. A
   page at the cap whose last item's `time` equals its start cannot be continued: the pull stops there, says so in an
   event, and the watermark does not move. Only when the pull completed does the watermark move to the request's end.
   The first run's watermark is `2026-11-01T00:00:00Z` less nothing.
2. **Fills and funding, daily.** The first run at or after each UTC midnight also re-reads:
   - fills over the 30 days before the watermark, paged as above;
   - funding over the 30 days before that midnight (the first such pull reaches back to `2026-11-01T00:00:00Z`), paged
     at its cap of 500 the same way.
   A daily pull that returns more than 5,000 fills raises an `alarm` event (half the 10,000 the API retains).
3. **Fees and orders, hourly:** one request each, stored as received.

**Duplicates** are dropped by identity: a fill by `tid`, a funding row by (`coin`, `time`). A run reads only these
identity fields and `time` of each item, to page and to deduplicate, and nothing else of any item. What a re-read adds
(items whose identity was not stored before) is counted in its event. The set of stored identities is rebuilt from the
stored files at every run, reading only `<kind>/<YYYYMMDD>/*.jsonl.zst` through the 4-state streaming reader
(`RECORDER.md`, Compression): a `cut` stream (a kill's truncated last line or frame) keeps its whole prefix lines
silently; a `corrupt` stream contributes zero identities and writes an `error` event naming the file; a `malformed`
stream or unparseable line writes an `error` event naming the file, and the run goes on without the unread identities,
whose items may then be stored again (readers merge by identity). Only explicit decode and parse failures are caught.
`state.json` holds only the watermark and the last daily re-read. A pull event's `items` counts distinct identities.

**The 30 days and the hour of overlap are choices** (brief 3; GPT's R6 on study 2's criteria): nothing says how late
the API can show a fill. Both are in each run's `start` event.

## Storage

Under `<root>/vault/<user>/`, append-only like the recorder's (with strictly monotonic `<run>` IDs per root across
restarts even if the wall clock steps backwards):

```
<kind>/<YYYYMMDD>/<HH>.<run>.jsonl.zst    kind ∈ fills, funding, fees, orders; one line per response
events/<YYYYMMDD>/<HH>.<run>.jsonl.zst    the run's own facts
state.json                                 the watermark and the last daily re-read; replaced atomically
```

- **A response line** is `{"recv": <ms>, "request": <the request body>, "date": <IMF-fixdate or null>, "msg": <the response>}`,
  the response spliced in byte for byte as the recorder's frames are. A fills or funding page whose items are all
  duplicates is still stored: the record is of what the API returned.
- **Events:** `start` (with `user`, `now`, the overlap and the 30 days), one `pull` per kind (`kind`, `from_ms`,
  `to_ms`, `pages`, `items`, `new`, `complete`), `stuck` (a page at the cap that cannot be continued), `alarm`, `error`
  (a request that failed, with `request`, `stage`, `bytes` and a reason as for the recorder's listings, quoting no
  byte of the response), `stop`.
  A request not answered in full within 30 s of its start (connecting, the TLS handshake and the whole response) is a
  timeout.
- **`state.json`** is written to a temporary file and renamed. A kill at any moment leaves either the old or the new
  state and every stored line whole, or one truncated last line that the reader reports and skips.

## Limits

A run stops at its first failed pull and sends no request after it: later pulls would meet the same failure. A pull
that completed before it keeps what it did: its responses stay stored and the watermark it moved stays. A run makes at
most a few dozen requests: the hourly pull's pages, two daily re-reads of at most a few pages each, and two single
requests. Requests are paced at least 1 s apart, and a request answered with an HTTP 429 is asked again, with backoff,
up to 5 times: a sixth 429 in a row is an `error`. The weight stays far under the recorder's share of 1,200 per minute.

**A response is whole, or the request failed,** using the same libcurl + `jsont` client as the recorder's listings
(`RECORDER.md`, What it records, item 1): TLS-verified HTTP/1.1 with `Content-Length` or `Transfer-Encoding: chunked`
(never both or neither), at most 16 MiB, informational replies skipped, a final `200`, optional IMF-fixdate `Date`
captured, and one strict RFC 8259 UTF-8 JSON value of depth at most 64. Anything else is an `error` naming the request,
the stage and the bytes received, quoting no byte of the response, and nothing of it is stored; a 429 is asked again as
above, and any other failure fails the pull.

## The forward window

The collector only writes. What it stores in [2026-11-01, 2027-01-31) is read for integrity only (`CLAUDE.md`,
Holdout): status, sizes, hashes, counts and gaps, which its own events carry. No price, size, fee or rate is printed by
the collector, its tests' output, or any integrity check.

## Tests

Offline, against a fake REST server:

1. **Paging:** 4,500 fills in a range come back as pages of 2,000, 2,000 and a shorter third (502, since each page repeats the last item of the one before), each starting at the last `time`,
   inclusive; every fill is stored once; the watermark moves to `now` only after the last page.
2. **Overlap:** a fill dated 30 minutes before the watermark, first indexed after the last run, is stored by the next.
3. **Late fill:** a fill first indexed 29 days after its `time` is stored by the next daily re-read, counted as new in
   its `pull` event; one indexed 31 days late is not (assumption V18).
4. **Stuck page:** 2,001 fills at one millisecond stop the pull with `stuck`; the watermark does not move; the run
   exits 1.
5. **Funding:** a re-read over 30 days stores each (`coin`, `time`) once, and the first daily pull starts at
   2026-11-01; a row present in two re-reads is stored once.
6. **Idempotence and kills:** two runs at one `now` add nothing but events; a kill (SIGKILL) at random moments during a
   run, then a run, leaves every response line whole or one truncated last line, a valid `state.json`, and no fill lost
   or duplicated by identity.
7. **Errors:** a 429 retried then answered stores the answer once; a 429 to the first ask and to each of its five
   retries, six requests in all, gives an `error` and exit 1 with the watermark unmoved; a 500 or a body that is not
   JSON likewise, storing nothing of it.
   - **Framing and strict JSON,** on a one-page fills pull whose body is otherwise a valid page: a `Content-Length`
     longer than the bytes sent before the close; a chunked body without its zero-size chunk or closed after it before
     the final CRLF; an overflowing `Content-Length`; two `Content-Length` fields that differ; a body announcing
     neither, over plain HTTP and over TLS; a body with a lone surrogate (`\ud800`); and a body with a comment after
     the page, each give an `error` naming the fills request and quoting no byte of the page, exit 1, nothing stored
     under `fills` and the watermark unmoved. A chunked body with trailer fields, `Content-Length: N, N`, a `103` before
     the `200`, a framed body whose server keeps the connection open, and a page of 2,000 fills sent in 1 KiB pieces,
     each complete the pull.
   - **A later page:** on a pull of 4,500 fills whose second page is cut short, or answered 500, the run exits 1 with
     an `error`, stores nothing of that page, leaves the watermark unmoved, and sends no request after it; the next
     run, answered whole, stores all 4,500 and moves the watermark.
   - **Fees:** a fees request answered 500, or with a comment after its object, gives an `error` naming it and exit 1,
     with no orders request after it; the fills pull before it stays stored and its watermark stays moved.
8. **Alarm:** a daily re-read of 5,001 fills raises `alarm`.
9. **Nothing printed:** no test's output and no event holds an item's price, size, fee or rate.
10. **Corrupt stored file:** a stored fills file with a corrupt frame gives one `error` event naming it, contributes
    zero identities, and the run still pulls and stores all fills; a kill's truncated last line gives no event.
11. **Stalled handshake:** a request whose server accepts the connection and never completes the TLS handshake gives one
    `error` with `timeout` within 35 s.
12. **Stray entries:** a subdirectory or a file not named `*.jsonl.zst` under a stored day changes nothing.

## Deployment

A CronJob `vault` in `moneymachine-live`, hourly at minute 7, on the recorder's image, mounting the `ws` PVC at the
recorder's root, with `concurrencyPolicy: Forbid` (`CLUSTER.md`). It does not restart or touch the `ws` StatefulSet.
