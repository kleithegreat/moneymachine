# ECB Data Portal (keyless data layer; stage 8 signal-study tier)

SDMX 2.1 REST web service at `https://data-api.ecb.europa.eu/service/`, read-only, no key. Dataflows in scope
(`audit/stage8/scope-manifest.md`): EXR (euro foreign exchange reference rates, 44 daily series
`D.<CUR>.EUR.SP00.A`, discontinued and suspended currencies included) and YC (euro area yield curves).

Timestamp classes:
- `TIME_PERIOD` is the reference date, a value and never an availability time.
- The SDMX response carries no publication time. An observation is therefore known no earlier than our own
  fetch of it, unless a past-version query (below) establishes an earlier, server-set time.

Past versions (checked 2026-10-23 on `D.USD.EUR.SP00.A`, two observations): with `includeHistory=true`, SDMX-ML
(generic data) returns each version as a dataset with `action="Replace"` and a server-set `validFromDate`. The CSV
format ignores the parameter. The two latest observations were both stamped `2026-10-23T20:25:15.583+02:00`,
after that day's fixing, so a version's `validFromDate` can be a reload time rather than first publication. It is
a candidate knownAt witness only after a live test compares it with our own observation times (paper §5); until
then the series are prospective from our first recording.

The fixing time is in the series' `TITLE_COMPL`: "ECB reference exchange rate, US dollar/Euro, 2.15 pm (C.E.T.)".
It is a reference time, not a publication time.

Open items (PROGRESS.md, Now, data layer):
- series start and end dates: the service has no `availableconstraint` endpoint;
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
