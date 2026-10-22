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

## Terms: api.hyperliquid.xyz

- URL: https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api
- Retrieved: 2026-10-22
- Basis: official API

> Documentation for the Hyperliquid public API
>
> The following rate limits apply per IP address: REST requests share an aggregated weight limit of 1200 per minute.

The API docs carry no terms of their own. The Terms of Use (https://app.hyperliquid.xyz/terms, "Last updated
on June 15, 2026", read from the app's `TermsOfUse` bundle on 2026-10-22) govern the web Interface:

> 1.1 The Interface facilitates interaction with Hyperliquid, a decentralized, permissionless, and
> community-driven blockchain ("Hyperliquid"). [...] The Interface is not the exclusive means of accessing Hyperliquid.
>
> 1.6 The Interface is not available to "Restricted Persons." For the purposes of these Terms, Restricted
> Persons include: (a) persons or entities who reside in, are located in, are incorporated in, or have a
> registered office in the United States of America or Ontario, Canada; [...] Restricted Persons are strictly
> prohibited from accessing or using the Interface described herein.
>
> 3.1.5 Circumvention of Restrictions. Activity that attempts to bypass, evade, or circumvent any restrictions
> imposed by the Interface or the Company. This includes but is not limited to: (a) using technologies such as
> VPNs, proxies, or other methods to conceal your location; [...]
>
> 3.1.8 Automated or High-Frequency Abuses. Activity that employs bots, scripts, or other automated methods to
> interact with the Interface in ways that exceed reasonable usage, bypass rate limits, cause denial-of-service
> conditions, or disrupt the normal functioning of Hyperliquid or related systems.

The operator is in the United States. Whether 1.6 reaches read-only use of the public info API is open,
awaiting a human decision (Blockers). We never use the Interface, a VPN or a proxy.
