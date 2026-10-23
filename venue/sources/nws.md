# NOAA National Weather Service API (keyless data layer; stage 9 candidate)

`https://api.weather.gov`, read-only, no key. In scope: active weather alerts (`/alerts/active`, GeoJSON),
recorded every 3 hours (about 2 MB a poll) as a cross-domain event source (`docs/stage9-candidates.md`).

Timestamp classes:
- Each alert carries `sent`, `effective`, `onset` and `expires`. These are values set by the issuing office, not
  availability times.
- An alert is known no earlier than our first fetch that contains it. No history is backfilled, so the source is
  prospective only.

## Terms: api.weather.gov

- URL: https://www.weather.gov/documentation/services-web-api
- Retrieved: 2026-10-23
- Basis: official API

> All of the information presented via the API is intended to be open data, free to use for any purpose.
> A User Agent is required to identify your application.

The page also says that any User-Agent value is accepted, and that the rate limit "is not public information, but
allows a generous amount for typical use". We send our recorder's agent string, with no personal contact, every
3 hours.
