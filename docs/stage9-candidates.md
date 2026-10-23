# Stage 9 cross-domain candidates: terms status

Human decision of 2026-10-23: add public-domain cross-domain sources to stage 9's candidates, certifying terms
as usual. A source is fetched only after its terms record is certified (`ingest/terms.py`) and its feed is
declared in `venue/sources/datalayer.json`. Stage 9 implementation still follows stage 8's exit.

| Source | Terms found (2026-10-23) | Identity needed | Status |
|---|---|---|---|
| NOAA/NWS API (`api.weather.gov`) | "All of the information presented via the API is intended to be open data, free to use for any purpose." | A User-Agent is required, but "any value is accepted"; contact details are optional | certifiable: next terms record |
| openFDA (`api.fda.gov`) | "Use of the data made available via openFDA is generally unrestricted"; "You can copy, modify, distribute, and perform the work, even for commercial purposes, all without asking permission." Access may be rate-limited | none for low volume | certifiable: next terms record |
| ClinicalTrials.gov API v2 | the site's terms page has no data or API clause; its policy pages are still to read | none expected | open |
| EIA hourly grid and energy | the API needs a key; the bulk files' terms are still to read | none for bulk files, if their terms permit | open |
| NOAA/BOEM AIS (MarineCadastre.gov) | still to read | — | open |
| USDA crop reports (NASS, WASDE) | still to read; Quick Stats needs a key | — | open |
| Census international trade API | still to read; keyless calls are limited | — | open |
| EDGAR financial statement data sets (point in time by acceptance time) | sec.gov requires a User-Agent with contact details | the human's contact | waits for the human (Blockers) |
| Wikimedia pageviews API | its User-Agent policy asks for contact information | the human's contact, or the project's public URL, which the human decides on | waits for the human |
