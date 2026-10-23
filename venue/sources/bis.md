# BIS data portal (keyless data layer; stage 8 signal-study tier)

SDMX REST at `https://stats.bis.org/api/v1/`, read-only, no key. Dataflows in scope: `BIS:WS_CBPOL(1.0)`
(central bank policy rates, 49 daily series by REF_AREA) and `BIS:WS_EER(1.0)` (effective exchange rates).

Timestamp classes:
- `TIME_PERIOD` is the reference date. For a policy rate it is the effective date, which comes after the
  announcement, so it is never an availability time.
- The series carry no announcement times and no vintages. Historical use needs release evidence, or the series
  are prospective only from our first recording (open item: policy-rate announcement times).

## Terms: stats.bis.org

- URL: https://data.bis.org/help/legal
- Retrieved: 2026-10-23
- Basis: official API

> The use of the statistics is unrestricted, provided that: if the statistics are reproduced, the BIS must be
> cited in your publication or product as the source of the statistics
> Use of the APIs constitutes agreement by users of the APIs ("Users") with the following terms and conditions:
> APIs are made available on an "as-is" basis.

Conditions: cite the BIS, do not imply endorsement, and use the most up-to-date API version. "The BIS reserves the
right to limit or suspend any User's IP address access to the APIs at any time", so requests are paced.
