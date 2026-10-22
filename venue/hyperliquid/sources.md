# Hyperliquid data sources (stage 0 manifest, C0.1)

All requests: `POST https://api.hyperliquid.xyz/info`, public, read-only, no auth.
Documented limit: 1200 weight/min per IP, shared by all REST requests
([rate limits](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/rate-limits-and-user-limits)).
Our processes share one IP and together stay at or below 600/min: the backfill is
held at 200/min, the recorder at 400/min, and one-off scripts at 600/min while
nothing else runs (`ingest/hl.py` charges weight before each request and again
for the item weight after it).

| Endpoint | Used for | Weight (documented) | Pagination (documented / observed) | Retention (documented / observed 2026-10-19) |
|---|---|---|---|---|
| `meta` | universe, delisted flags, szDecimals, margin tables | 20 | none | current state only; earlier rule values are not available |
| `fundingHistory` | settled hourly funding and premium | 20 + 1 per 20 items | 500 rows per response; continue from last `time` + 1 / same | not stated / BTC back to 2023-05-12, delisted coins included |
| `candleSnapshot` | 1d bars (universe rule), 4h bars | 20 + 1 per 60 items | "500 elements" / one response held 5000 candles | "most recent 5000 candles" / 4h back to 2024-07-08, a rolling window; 1d back to 2023 |
| `l2Book` | execution calibration (recorder) | 2 | none | snapshot only; 20 levels per side |

Field semantics:
- `fundingHistory.time` is the settlement stamp, usually a few ms after the hour, sometimes
  minutes late. Stored eventTime is the hour and reportedTime the stamp; the store computes
  knownAt = max(hour + 120 s, reportedTime + 60 s) (`ingest.store.known_at`). `fundingRate` is per hour, and
  positive means longs pay shorts ([funding](https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding)).
- `candleSnapshot` `t`/`T` are the bar's open and close (ms, `T = t + interval - 1`). The
  last bar returned may be unclosed. Stored eventTime is `t + interval`, known 120 s later, and
  only bars with `t + interval <= fetchedAt` are stored.
- Delisted coins: `fundingHistory` keeps their history. `candleSnapshot` coverage
  varies (MATIC and RNDR have no 4h bars after 2024-09-30, while FTM and MKR do).

Reproduce: `python -m cli universe data/universe.json`, then
`python -m cli backfill data 200`.

Rolling retention means the 4h bars at the start of W drop out of the API around
2027-01. Our first fetch is the only lasting copy, so the store is append-only.
