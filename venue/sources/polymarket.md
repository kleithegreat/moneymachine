# Polymarket (keyless data layer; stage 10 market-implied baseline)

Gamma markets API at `https://gamma-api.polymarket.com`, read-only, with no key or account. Recorded every 3 h:
- active markets, top 500 by 24 h volume, with `outcomePrices`, `lastTradePrice`, `bestBid`, `bestAsk` and
  `updatedAt`;
- the 500 most recently closed markets, with their resolved `outcomePrices`, `closedTime` and
  `umaResolutionStatus`.

They serve as the stage 10 baseline: market-implied probabilities where a market matches a thesis, and its
resolution.

Timestamp classes:
- `updatedAt`, `closedTime` and `endDate` are the server's values, not availability times.
- A price or resolution is known no earlier than our first fetch that contains it. Nothing is backfilled, so the
  source is prospective only.

## Terms: gamma-api.polymarket.com

- URL: https://polymarket.com/tos
- Retrieved: 2026-10-23
- Basis: official API

> Trading is blocked in the United States on polymarket.com.

That banner is the only text the terms page gave our fetcher; no API terms were found. Secondary sources say the
terms bar US persons from the international product. The developer documentation
(https://docs.polymarket.com/, retrieved 2026-10-23) shows the markets API read with no credentials
(`curl https://gamma-api.polymarket.com/markets/keyset?closed=false&limit=5`).

The operator is in the United States. Human decision of 2026-10-23, on the same basis as Hyperliquid's: use the
read-only public data API, with no account, no trading, a US IP and no VPN. Revisit if Polymarket publishes API
terms, or before any step toward trading.
