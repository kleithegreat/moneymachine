# Stage 9 cross-domain candidates: terms status

Human decision of 2026-10-23: add public-domain cross-domain sources to stage 9's candidates, certifying terms
as usual. A source is fetched only after its terms record is certified (`ingest/terms.py`) and its feed is
declared in `venue/sources/datalayer.json`. Stage 9 implementation still follows stage 8's exit.

| Source | Terms found (2026-10-23) | Identity needed | Status |
|---|---|---|---|
| NOAA/NWS API (`api.weather.gov`) | "All of the information presented via the API is intended to be open data, free to use for any purpose." | A User-Agent is required, but "any value is accepted"; contact details are optional | certified; recording active alerts every 3 h (`venue/sources/nws.md`) |
| openFDA (`api.fda.gov`) | "Use of the data made available via openFDA is generally unrestricted"; "You can copy, modify, distribute, and perform the work, even for commercial purposes, all without asking permission." Access may be rate-limited | none for low volume | certified; recording drug enforcement reports daily (`venue/sources/openfda.md`) |
| ClinicalTrials.gov API v2 | neither its terms page nor NLM's web policies has an API or automated-access clause; NLM pages are public domain ("may be freely used or reproduced without permission") | none | open: silent on automation, so not certified (the rule of 2026-10-22) |
| EIA hourly grid and energy | bulk files: "provided free of charge" under a reuse policy permitting use and distribution; the API needs a key | none for bulk files | certified; recording the manifest (6 h) and petroleum (daily); the hourly grid file (699 MB, twice daily) exceeds the disk (`venue/sources/eia.md`) |
| NOAA/BOEM AIS (MarineCadastre.gov) | still to read | — | open |
| USDA crop reports (NASS, WASDE) | still to read; Quick Stats needs a key | — | open |
| Census international trade API | "You may use the Census Bureau API to develop a service or service to search, display, analyze, retrieve, view"; use may be limited | none | certifiable; series to choose with stage 9's scope |
| EDGAR financial statement data sets (point in time by acceptance time) | sec.gov requires a User-Agent with contact details | the human's contact | waits for the human (Blockers) |
| Wikimedia pageviews API | its User-Agent policy asks for contact information | the human's contact, or the project's public URL, which the human decides on | waits for the human |
