# openFDA (keyless data layer; stage 9 candidate)

`https://api.fda.gov`, read-only, no key for low volume. In scope: drug enforcement reports (recalls),
`/drug/enforcement.json`, the latest 100 by `report_date`, recorded daily as a stage 9 cross-domain source.

Timestamp classes:
- `report_date`, `recall_initiation_date` and `center_classification_date` are values, not availability times.
- openFDA republishes its data weekly, and a record is known no earlier than our first fetch that contains it
  (prospective only).

## Terms: api.fda.gov

- URL: https://open.fda.gov/terms/
- Retrieved: 2026-10-23
- Basis: permitting clause

> Use of the data made available via openFDA is generally unrestricted
> You can copy, modify, distribute, and perform the work, even for commercial purposes, all without asking permission.

Use may be limited to manage load ("Your use of openFDA may be subject to certain limitations on access, calls, or
use"). We make one request a day. FDA asks, without requiring it, that credit be given.
