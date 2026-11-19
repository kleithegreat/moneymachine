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

**Identities.** A fill's is (`coin`, `tid`, `oid`), the key the replay of its fills holds it to (a self-trade is two
fills of one `tid`); a funding row's is (`coin`, `time`). Nothing is dropped: every response is stored whole, and an
item whose identity was stored before is only not counted as new. A run reads only these identity fields and `time` of
each item, to page and to count, and nothing else of any item. What a re-read adds (items whose identity was not stored
before) is counted in its event. The set of stored identities is rebuilt from the stored files at every run; `state.json` holds only the watermark and
the last daily re-read. A pull event's `items` counts distinct identities.

**The 30 days and the hour of overlap are choices** (brief 3; GPT's R6 on study 2's criteria): nothing says how late
the API can show a fill. Both are in each run's `start` event.

## Storage

Under `<root>/vault/<user>/`, append-only like the recorder's:

```
<kind>/<YYYYMMDD>/<HH>.<run>.jsonl.zst    kind ∈ fills, funding, fees, orders; one line per response
events/<YYYYMMDD>/<HH>.<run>.jsonl.zst    the run's own facts
state.json                                 the watermark and the last daily re-read; replaced atomically
```

- **A response line** is `{"recv": <ms>, "request": <the request body>, "msg": <the response>}`, the response spliced
  in byte for byte as the recorder's frames are. A fills or funding page whose items are all duplicates is still
  stored: the record is of what the API returned.
- **Events:** `start` (with `user`, `now`, the overlap and the 30 days), one `pull` per kind (`kind`, `from_ms`,
  `to_ms`, `pages`, `items`, `new`, `complete`), `stuck` (a page at the cap that cannot be continued), `alarm`, `error`
  (an HTTP status, a timeout, an unreadable body, with the request), `stop`.
- **Atomic pull staging (round 8):** each kind's pull writes its response lines into `<root>/vault/<user>/.tmp/<run>.<kind>.jsonl.zst`, ends the zstd stream cleanly, `fsync`s it, and atomically renames it to `<kind>/<YYYYMMDD>/<HH>.<run>.jsonl.zst` only after that kind's pull completes (and before `state.json` is updated). Events still stream live to `events/`. A kill or failure mid-pull therefore leaves zero partial multi-page files in `<kind>/` for a concurrent capture to snapshot.
- **`state.json`** is written to a temporary file and renamed. A kill at any moment leaves either the old or the new
  state, every file in `<kind>/` complete and stream-ended, and every event line whole or one truncated last line that
  the reader reports and skips.

## Limits

A run stops at its first failed pull: later pulls would meet the same failure. A run makes at most a few dozen requests: the hourly pull's pages, two daily re-reads of at most a few pages each, and
two single requests. Requests are paced at least 1 s apart, and an HTTP 429 waits and retries with backoff up to 5
times before it is an `error`. The weight stays far under the recorder's share of 1,200 per minute.

## The forward window

The collector only writes. What it stores in [2026-11-01, 2027-01-31) is read for integrity only (`CLAUDE.md`,
Holdout): status, sizes, hashes, counts and gaps, which its own events carry. No price, size, fee or rate is printed by
the collector, its tests' output, or any integrity check.

## Tests

Offline, against a fake REST server, written by a session that does not build the collector:

1. **Paging:** 4,500 fills in a range come back as pages of 2,000, 2,000 and a shorter third (502, since each page repeats the last item of the one before), each starting at the last `time`,
   inclusive; every fill is counted once; the watermark moves to `now` only after the last page.
2. **Overlap:** a fill dated 30 minutes before the watermark, first indexed after the last run, is stored by the next.
3. **Late fill:** a fill first indexed 29 days after its `time` is stored by the next daily re-read, counted as new in
   its `pull` event; one indexed 31 days late is not (assumption V18).
4. **Stuck page:** 2,001 fills at one millisecond stop the pull with `stuck`; the watermark does not move; the run
   exits 1.
5. **Funding:** a re-read over 30 days counts each (`coin`, `time`) once, and the first daily pull starts at
   2026-11-01; a row present in two re-reads is counted once, and both responses are stored.
6. **Idempotence and kills:** two runs at one `now` add nothing but events; a kill (SIGKILL) at random moments during a
   run, then a run, leaves zero partial files in `<kind>/`, every file in `<kind>/` complete and stream-ended, a valid
   `state.json`, and no fill lost or duplicated by identity.
7. **Errors:** a 429 retried then answered stores the answer once; five 429s give an `error` and exit 1 with the
   watermark unmoved; a 500 or an unreadable body likewise.
8. **Alarm:** a daily re-read of 5,001 fills raises `alarm`.
9. **Nothing printed:** no test's output and no event holds an item's price, size, fee or rate.
10. **Identity:** a self-trade, two fills of one `tid` and two `oid`, is two fills, each counted as new; one fill in two
    pulls is counted once (the last pass's round 7).

## Deployment

A CronJob `vault` in `moneymachine-live`, hourly at minute 7, on the recorder's image, mounting the `ws` PVC at the
recorder's root, with `concurrencyPolicy: Forbid` (`CLUSTER.md`). It does not restart or touch the `ws` StatefulSet.

## Settled funding (`mmvault funding`)

What the forward run needs of the market that the recorder does not hold: each universe coin's settled hourly funding
(brief 3's table; `audit/program/briefs/4-study-2.md`, step 7, wall 3). Same tool, storage form, retries and
forward-window rule as above, with weight-aware pacing and atomic pull staging (round 8).

- **Request:** `{"type": "fundingHistory", "coin", "startTime"}` (no `endTime`: the API reads through venue `now`,
  immune to host wall-clock skew), one coin at a time. A page holds at most 500 rows; the next starts at the last row's
  `time`, inclusive. A coin's pull is complete at its first page under 500.
- **Weight pacing:** by `venue/sources.toml`, `fundingHistory` costs `20 + ceil(items / 20)` weight (45 per full 500-row
  page) under the shared 1,200 weight/min IP limit. `mmvault funding` paces requests to at most **750 weight/min**
  (3.6 s after a 500-row page, 1.6 s after a small/empty page), leaving 450 weight/min for `mmrec` and `mmvault`.
- **`mmvault funding <root> --coins <file> [--from-ms MS] [--rest-url URL] [--now-ms MS]`** pulls every coin of the
  file, in its order, from `from` through venue `now`. Without `--from-ms`, it is the daily pull: 30 days before the
  last UTC midnight, the first reaching back to `2026-11-01T00:00:00Z`; production runs it once a day. The replay's
  timer runs it with **`--from-ms` fixed at `w_start`** (the first judged midnight, constant for the entire study so no
  step-2 failure changes a pull range and every >30-day-late unheld row or restatement is caught), and kills it at
  **90 minutes** (a Month-24 full pull of 17 coins × 36 pages is ~39 min at 750 weight/min): a pull's timing moves the
  capture, so the limit is fixed here. Exit 0 when every coin's pull completed, 1 otherwise.
- **Storage and atomic staging:** responses of one pull are written into `<root>/settled/.tmp/<run>.funding.jsonl.zst`,
  stream-ended and `fsync`ed, and atomically renamed to `<root>/settled/funding/<YYYYMMDD>/<HH>.<run>.jsonl.zst` **only
  when every coin's pull completed**. Events stream live to `<root>/settled/events/<YYYYMMDD>/<HH>.<run>.jsonl.zst` for
  every attempt (completed, failed or killed) so failed pulls remain auditable. The `start` event holds `now`, the range
  and coins; one `pull` event per coin holds `complete`; the `stop` event holds `elapsed_ms` measured by
  `CLOCK_BOOTTIME`. A failed or killed pull leaves zero files in `<root>/settled/funding/`.
- **Identity:** (`coin`, `time`), for counting only, as above. What a replay makes of a row is `KERNEL.md` A18's
  (what a reader puts in a record): nothing of the envelope reaches it.

**Tests,** offline as above:
1. **Paging and no `endTime`:** 1,200 rows of one coin come back as pages of 500, 500 and 202, each starting at the last
   `time`, inclusive, with no `endTime` in the request body, and every row is counted once.
2. **Range and pacing:** `--from-ms` at `w_start` pulls every coin from `w_start`, and the daily pull from 30 days
   before the last midnight; consecutive 500-row pages keep ≤ 750 weight/min (≥ 3.6 s spacing; testable with a fake clock
   or recorded inter-request delays).
3. **Complete and atomic staging:** a pull killed (SIGKILL) after some coins leaves their `pull` events in `events/` and
   **zero files in `settled/funding/`**, and is incomplete; a 429 five times writes an `error` event, exits 1, and leaves
   zero files in `settled/funding/`. A completed pull atomically places one stream-ended file in `settled/funding/` and
   records `CLOCK_BOOTTIME` `elapsed_ms` in `stop`.
4. **Nothing printed:** no output and no event holds a rate.

**Deployment:** a CronJob `settled` beside `vault`, daily at 00:17 UTC, mounting `ws` as `vault` does; the replay's
timer runs the same image on the same volume with a single-instance capture lock (`Forbid`).
