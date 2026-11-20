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
before) is counted in its event. The set of stored identities is rebuilt from the stored files at every run, reading
only `<kind>/<YYYYMMDD>/*.jsonl.zst`. A stored file is read up to its first unreadable point: a truncated last line or
frame, as a kill leaves, is skipped silently; any other failure to decode or parse is an `error` event naming the file,
and the run goes on without that file's unread identities, whose items may then be stored again (readers merge by
identity). Only those failures are caught. `state.json` holds only the watermark and
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
  A request not answered in full within 30 s of its start (connecting, the TLS handshake and the whole response) is a
  timeout.
- **Atomic pull staging (round 8, fsync directory round 9):** each kind's pull writes its response lines into `<root>/vault/<user>/.tmp/<run>.<kind>.jsonl.zst`, ends the zstd stream cleanly, `fsync`s it, atomically renames it to `<kind>/<YYYYMMDD>/<HH>.<run>.jsonl.zst` only after that kind's pull completes, and `fsync`s the destination directory `<kind>/<YYYYMMDD>/` before `state.json` is updated. Events still stream live to `events/`. A kill or failure mid-pull therefore leaves zero partial multi-page files in `<kind>/` for a concurrent capture to snapshot.
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
10. **Corrupt stored file:** a stored fills file with a corrupt frame before its end gives one `error` event naming it, and
    the run still pulls and stores; a kill's truncated last line gives no event.
11. **Stalled handshake:** a request whose server accepts the connection and never completes the TLS handshake gives one
    `error` with `timeout` within 35 s.
12. **Stray entries:** a subdirectory or a file not named `*.jsonl.zst` under a stored day changes nothing.
13. **Identity:** a self-trade, two fills of one `tid` and two `oid`, is two fills, each counted as new; one fill in two
    pulls is counted once (the last pass's round 7).

## Deployment

A CronJob `vault` in `moneymachine-live`, hourly at minute 7, on the recorder's image, mounting the `ws` PVC at the
recorder's root, with `concurrencyPolicy: Forbid` (`CLUSTER.md`). It does not restart or touch the `ws` StatefulSet.

## Settled funding (`mmvault funding`)

What the forward run needs of the market that the recorder does not hold: each universe coin's settled hourly funding
(brief 3's table; `audit/program/briefs/4-study-2.md`, step 7, wall 3). Same tool, storage form, retries and
forward-window rule as above, with **fetch-once per `(coin, hour)` + gap backfill** (human decision H16,
`audit/decisions.md` 2026-11-20; matching the committed spec `e691341`, *"fetches settled funding for the judged days it
does not yet hold"*), weight-aware pacing, a shared single-instance lock, and atomic pull staging.

**Why fetch-once + gap backfill, and its one cost.** Every `(coin, hour)` already stored in `<root>/settled/funding/`
is never queried again, by either the daily job or the monthly timer. That gives settled funding the same capture-once
semantics as the websocket `l2Book-fast` and `trades` recordings, keeps monthly pulls to ~30 s (~30 KB), keeps Step 1
decoupled from Step 2 (reading only `<root>/settled/funding/`, never publication state), backfills any missing
historical hour regardless of age, and lets study 2 survive benign venue changes to historical `fundingHistory` rows
(such as more significant digits) without ending at Day 1. **Its one cost:** a retroactive venue correction of an
already-fetched funding hour is never fetched or seen (zero differing value restatements have been observed on
Hyperliquid; the pilot's 24 revisions held identical values). If two stored files in `<root>/settled/funding/` ever
hold differing rows for one `(coin, hour)`, `KERNEL.md` A18 still rejects the second.

- **Invocation and floor:** `mmvault funding <root> --coins <file> [--from-ms MS] [--rest-url URL] [--now-ms MS]`
  processes every coin in `<file>` (plain text, one coin name per non-empty trimmed line, in file order; an empty list
  exits 1). `--from-ms MS` (non-negative integer epoch ms) sets the whole-hour lower bound
  `floor_ms = from_ms - (from_ms mod 3_600_000)`. Without `--from-ms` (the daily `settled` CronJob), `floor_ms`
  defaults to `2026-11-01T00:00:00Z` (`1_793_491_200_000`). The replay's monthly timer passes `--from-ms` fixed at
  `w_start` (the first judged midnight, constant for the entire study). `--now-ms` fixes only the event/filename clock
  for tests and never sets any API query bound. Exit 0 when every coin's gap spans and open tail completed and the
  staged file was atomically renamed and directory-`fsync`ed; exit 1 otherwise.
- **Shared lock:** before scanning disk or making any request, `mmvault funding` acquires an exclusive `flock` on
  `<root>/settled/.lock` and holds it until after the atomic rename and destination directory `fsync` (released on exit
  or crash). Overlapping daily and monthly runs serialize automatically: the second waits for the first to finish
  committing, then scans the updated disk so it never double-spends the weight budget or re-fetches hours the first
  just stored.
- **Disk scan (`S_c^disk`, fail-closed):** under the lock, `mmvault funding` reads every completed file in
  `<root>/settled/funding/<YYYYMMDD>/<HH>.<run>.jsonl.zst` (sorted by path). If any existing file fails clean zstd
  decompression or holds malformed JSON or a non-array `msg`, the run logs an `error` event, writes nothing to
  `<root>/settled/funding/`, and exits 1 (never silently skipping a corrupt file to re-fetch stored hours). For each
  element of each `msg` array, it reads `"coin"` (string) and `"time"` (non-negative integer ms) and checks that
  `"fundingRate"` is a string (never printing or logging it), records `(coin, time)` in the stored-identity set (for
  counting `new`), and for every coin `c` in `--coins` adds `H = time - (time mod 3_600_000)` to `S_c^disk` whenever
  `H >= floor_ms`.
- **Per-coin query plan (gap backfill + open tail):** for each coin `c` in `--coins`, in file order:
  1. If `S_c^disk` is empty: issue no gap queries, and run the **open-tail** query starting at `startTime = floor_ms`
     with **no `endTime`**.
  2. If `S_c^disk` is non-empty: let `H_max(c) = max(S_c^disk)` and let the missing historical hours be
     `M_c = { H in [floor_ms, H_max(c)) : H is a whole UTC hour and H not in S_c^disk }`, partitioned into maximal
     contiguous whole-hour spans `[H_a, H_b]` in ascending order of `H_a`.
     - **Gap backfill:** for each span `[H_a, H_b]` in ascending order, paginate
       `{"type": "fundingHistory", "coin": c, "startTime": start, "endTime": H_b + 3_599_999}` from `start = H_a`.
       Because every valid settlement for hour `H` has `time in [H, H + 3_599_999]` (`KERNEL.md` A18, `late < 1 h`) and
       Hyperliquid's `startTime` and `endTime` are inclusive, `[H_a, H_b + 3_599_999]` covers every row flooring to
       `[H_a, H_b]` (exact hour edges and late stamps alike) with zero overlap with `H_a - 1 h` or `H_b + 1 h`.
     - **Open tail:** after all gap spans, paginate `{"type": "fundingHistory", "coin": c, "startTime": start}` (with
       **no `endTime`**: the API reads through venue `now`, immune to host wall-clock skew) from
       `start = H_max(c) + 3_600_000`. Even if a wild future row ever landed in `S_c^disk`, the maximal missing span
       `[next_real_hour, H_wild - 1 h]` fetches every real new hour through venue `now` and stops at the first page
       under 500 without looping over future hours, and the open tail returns `[]` in one request.
- **Pagination and validation:** each page holds at most 500 rows. Every response must be a JSON array whose rows each
  have `"coin" = c`, integer `"time" >= start` (and `<= endTime` on a gap span), and string `"fundingRate"`; any HTTP
  error (after up to 5 retries with backoff on 429), timeout, unreadable body, or row-validation failure logs an
  `error` event, stops immediately, leaves zero files in `<root>/settled/funding/`, and exits 1. Every valid response
  (even `[]`) is spliced byte for byte into the staged file. Pagination of a span or open tail stops at its first page
  under 500 rows (this is the pagination stop rule only; actual per-coin funding coverage through the replay horizon is
  verified directly from captured rows by `study2 forward`, `audit/program/briefs/4-study-2.md` step 7 wall 3, so a
  short API page holds the horizon back conservatively and the next run's open tail or gap backfill fetches the rest).
  On a 500-row page whose last row has timestamp `last_time`: if `last_time <= start`, the pull emits a `stuck` event,
  stops immediately, leaves zero files in `<root>/settled/funding/`, and exits 1; otherwise the next page starts at
  `last_time`, inclusive (keeping the same `endTime` on a gap span, or no `endTime` on the open tail).
- **Weight pacing and timeout:** by `venue/sources.toml`, `fundingHistory` costs `20 + ceil(items / 20)` weight (45 per
  full 500-row page, 20 per empty page, 22 per 24-row daily page) under the shared 1,200 weight/min IP limit.
  `mmvault funding` paces consecutive requests to at most **750 weight/min** (waiting `(20 + ceil(prev_items / 20)) / 12.5`
  seconds after the previous response: 3.6 s after a 500-row page, 1.6 s after a 0-row page), leaving 450 weight/min
  for `mmrec` and `mmvault`. A normal daily or monthly pull of 17 coins is 17 single-page requests (~30 s, ~30 KB; a
  full 31-day month with no prior daily pulls is 34 pages, ~2 min). The replay's timer kills `mmvault funding` at
  **15 minutes** (covering ~250 full pages, ~10 months of missed backfill plus 429 backoff, while always clearing before
  the next whole-hour firing; a pull's timing moves the capture, so the limit is fixed here).
- **Storage and atomic staging:** responses of one pull are written into `<root>/settled/.tmp/<run>.funding.jsonl.zst`,
  stream-ended cleanly and `fsync`ed, and atomically renamed to `<root>/settled/funding/<YYYYMMDD>/<HH>.<run>.jsonl.zst`
  **only when every coin's gap spans and open tail completed**, followed by `fsync` of the destination directory
  `<root>/settled/funding/<YYYYMMDD>/` before `mmvault funding` exits 0 (so the rename is durable across power cuts on
  any filesystem before `Capture_k` lists the file). Events stream live to
  `<root>/settled/events/<YYYYMMDD>/<HH>.<run>.jsonl.zst` for every attempt (completed, failed, stuck or killed) so
  failed pulls remain auditable. The `start` event holds `now`, `floor_ms` and `coins`; one `pull` event per coin holds
  `coin`, `gaps` (count of gap spans queried), `pages`, `items`, `new` and `complete`; `stuck` and `error` record
  failures; `stop` ends the attempt (`ok`). A failed, stuck or killed pull leaves zero files in
  `<root>/settled/funding/`.
- **Identity:** `(coin, time)`, for counting `items` and `new` only, as above. What a replay makes of a row is
  `KERNEL.md` A18's (what a reader puts in a record): nothing of the envelope reaches it.

**Tests,** offline against a fake REST server, written by a session that does not build the collector:
1. **Cold start, paging and no `endTime` on open tail:** with an empty `settled/funding/` directory and `--from-ms` at
   `w_start` (and separately without `--from-ms`, verifying default floor `2026-11-01T00:00:00Z`), 1,200 hourly rows of
   one coin come back as pages of 500, 500 and 202, starting at `floor_ms` and then each page's last `time`, inclusive,
   with **no `endTime`** in the request body; every row is counted once (`items = 1200`, `new = 1200`).
2. **Fetch-once and open-tail advance:** after a run stores hours `H_0 .. H_23` (including rows stamped on exact hour
   edges and late at `H_23 + 3_599_999`), a second run sends only `startTime = H_24` (with no `endTime`) and never
   re-queries `H_0 .. H_23`. If the fake server changes the rate or adds precision digits to `H_0 .. H_23` between runs,
   the second run never queries them, stores only `H_24 ..`, and leaves `H_0 .. H_23` untouched on disk.
3. **Contiguous gap backfill, exact boundaries, short pages and wild future row:** given stored files holding
   `H_0 .. H_4`, `H_8 .. H_10` and `H_14 .. H_15` (and also a >30-day-old gap when `H_max > floor_ms + 720 h`, plus a
   case where `floor_ms` itself is missing while `floor_ms + 1 h` is stored), the next run issues exact gap requests
   `[H_5, H_7 + 3_599_999]` (receiving rows stamped at `H_5` exact and `H_7 + 3_599_999` late) and
   `[H_11, H_13 + 3_599_999]`, followed by open tail `startTime = H_16` (no `endTime`), and zero requests touching
   already-stored hours; a subsequent run sends only the new open tail. A >500-hour gap paginates inside
   `[H_a, H_b + 3_599_999]` cleanly; a short page (`< 500`) inside a gap or open tail leaves the unreturned hours for the
   next run to fetch; a single wild future row (e.g., year 2030) in `settled/funding/` still lets the missing span
   `[H_today, H_wild - 1 h]` fetch every real new hour through venue `now` in one paginated call and stop.
4. **Weight pacing:** consecutive 500-row pages keep ≤ 750 weight/min (≥ 3.6 s spacing) and empty pages keep ≥ 1.6 s
   spacing (testable with a fake clock or recorded inter-request delays).
5. **Complete, atomic staging, fail-closed errors and shared lock:** a pull killed (`SIGKILL`) after some coins leaves
   their `pull` events in `events/` and **zero files in `settled/funding/`**, and is incomplete; five 429s, a 500, an
   out-of-range/wrong-coin row, or a stuck 500-row page (`last_time <= start`) writes an `error` or `stuck` event, exits
   1, and leaves zero files in `settled/funding/`; a corrupt/truncated file already in `settled/funding/` fails closed
   (`error` event, exits 1, zero new files) rather than silently re-fetching stored hours; a completed pull atomically
   places one stream-ended file in `settled/funding/` and `fsync`s the destination directory before exiting 0; two
   concurrent `mmvault funding` runs on the same `<root>` serialize on `<root>/settled/.lock` so the second waits for
   the first to commit and does not re-query hours the first already fetched.
6. **Nothing printed:** no output and no event holds a rate.

**Deployment:** a CronJob `settled` beside `vault`, daily at 00:17 UTC (19:17 EST) (no `--from-ms`, default floor
`2026-11-01T00:00:00Z`), mounting `ws` as `vault` does (`concurrencyPolicy: Forbid`); the replay's timer runs the same
image on the same volume with `--from-ms <w_start>` and a 15-minute kill limit. Both serialize on `<root>/settled/.lock`
(`flock`) so an hourly retry overlapping 00:17 never double-spends the 750 weight/min budget or double-fetches a missing
hour.
