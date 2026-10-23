# ECB Data Portal (keyless data layer; stage 8 signal-study tier)

SDMX 2.1 REST web service at `https://data-api.ecb.europa.eu/service/`, read-only, no key. Dataflows in scope
(`audit/stage8/scope-manifest.md`): EXR (euro foreign exchange reference rates, 44 daily series
`D.<CUR>.EUR.SP00.A`, discontinued and suspended currencies included) and YC (euro area yield curves).

Timestamp classes:
- `TIME_PERIOD` is the reference date, a value and never an availability time.
- The SDMX response carries no publication time. An observation is therefore known no earlier than our own
  fetch of it, unless a past-version query (below) establishes an earlier, server-set time.

Past versions: none recoverable through the API (checked 2026-10-23 on `D.USD.EUR.SP00.A`).
- With `includeHistory=true`, SDMX-ML returns a single dataset with `action="Replace"`.
- Its `validFromDate` is the response's own generation time: 18:25:15 and 18:47:54 UTC for requests made at
  those times. It is not a version timestamp.
- The full history came back as one version (7,183 observations).

For point-in-time use, every value is therefore known no earlier than our own first fetch of it (prospective
only). The full history serves to date the series, not as historical decision input, unless the ECB's revision
policy for reference rates is certified as "never revised" with evidence.

The fixing time is in the series' `TITLE_COMPL`: "ECB reference exchange rate, US dollar/Euro, 2.15 pm (C.E.T.)".
It is a reference time, not a publication time.

Series dates (2026-10-23, from each series' full history, fetched by the data layer into `data/datalayer/raw/`; dates
only, since the values are prospective). Except as listed, a series runs from 1999-01-04 to 2026-10-23 with 7,183
observations: AUD, CAD, CHF, CZK, DKK, GBP, HKD, HUF, IDR, JPY, KRW, MXN, MYR, NOK, NZD, PHP, PLN, SEK, SGD, THB, USD, ZAR.
- ARS: 2000-01-13 to 2020-10-30, 5383 observations
- BGN: 2000-07-19 to 2025-12-31, 6573 observations
- BRL: 2000-01-13 to 2026-10-23, 6915 observations
- CNY: 2000-01-13 to 2026-10-23, 6915 observations
- CYP: 1999-01-04 to 2007-12-31, 2346 observations
- DZD: 2000-01-13 to 2020-10-30, 5383 observations
- EEK: 1999-01-04 to 2010-12-31, 3130 observations
- GRD: 1999-01-04 to 2000-12-29, 520 observations
- HRK: 2000-01-13 to 2022-12-30, 5941 observations
- ILS: 2000-01-13 to 2026-10-23, 6915 observations
- INR: 2000-01-13 to 2026-10-23, 6915 observations
- ISK: 1999-01-04 to 2026-10-23, 4776 observations
- LTL: 1999-01-04 to 2014-12-31, 4159 observations
- LVL: 1999-01-04 to 2013-12-31, 3904 observations
- MAD: 2000-01-13 to 2020-10-30, 5383 observations
- MTL: 1999-01-04 to 2007-12-31, 2346 observations
- RON: 1999-01-04 to 2026-10-23, 7121 observations
- RUB: 1999-01-04 to 2022-03-01, 5994 observations
- SIT: 1999-01-04 to 2006-12-29, 2085 observations
- SKK: 1999-01-04 to 2008-12-31, 2608 observations
- TRY: 1999-01-04 to 2026-10-23, 7121 observations
- TWD: 2000-01-13 to 2020-10-30, 5383 observations

A short count over a full span means missing fixings within it (ISK 4,776, RON and TRY 7,121), whose dates come from the recorded files. A last date before 2026-10-23
means the series ceased: euro adoption, RUB's suspension from 2022-03-02, and the non-reference series ARS, DZD,
MAD and TWD at 2020-10-30.

Open items (PROGRESS.md, Now, data layer):
- the publication calendar and time;
- YC series and revision policy.

## Terms: data-api.ecb.europa.eu

- URL: https://www.ecb.europa.eu/stats/ecb_statistics/governance_and_quality_framework/html/usage_policy.en.html
- Retrieved: 2026-10-23
- Basis: official API

> The ESCB subscribes to a policy of free access and free reuse regarding its publicly released statistics
> All publicly available ESCB statistics may be reused free of charge on the condition that the source is quoted
> [and] the statistics (including metadata) are not modified.

The API is the ECB's documented distribution channel: "All disseminated data are available via the Statistical
Data and Metadata eXchange (SDMX) API. We implement the SDMX 2.1 standard."
(https://www.ecb.europa.eu/stats/ecb_statistics/accessing-our-data/html/index.en.html, retrieved 2026-10-23).
Conditions: quote the source ("Source: ECB statistics"), keep values unmodified, and expect revisions. The
policy also says access "may be restricted in exceptional circumstances ... if a user is acting in a manner
contrary to the interests of other users", so requests are paced.
