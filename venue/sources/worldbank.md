# World Bank (keyless data layer; stage 8 signal-study tier)

Commodity Price Data (the Pink Sheet): monthly benchmark prices, with each month's release published as files.
The exact distribution URLs and their catalog metadata are open items, to be verified before any fetch. The
Indicators API (`api.worldbank.org/v2`) is used only if it carries the same series.

Distribution (checked 2026-10-23):
- The monthly workbook sits at `thedocs.worldbank.org/en/doc/<hash>/related/CMO-Historical-Data-Monthly.xlsx`,
  and the hash changes with each release.
- The only link to it found so far is on the Commodity Markets page, and reading that page automatically rests on
  site terms that permit only "lawful, personal and non-commercial" use. So it is not fetched yet.
- Past monthly releases look archived as PDFs on `thedocs.worldbank.org` (for example "CMO-Pink-Sheet-August-2023.pdf").
  If their terms and coverage hold up, they could give the past versions (vintages) the workbook lacks.

Timestamp classes:
- A monthly value's reference month is a value, not an availability time.
- Recent months are revised, and no historical vintages were found. Each value is known no earlier than our
  first fetch of the release that carries it (prospective only), unless an archive of past releases is found and
  certified.

## Terms: api.worldbank.org

- URL: https://www.worldbank.org/ext/en/legal/terms-conditions/datasets
- Retrieved: 2026-10-23
- Basis: permitting clause

> Unless specifically labeled otherwise, these Datasets are provided to you under a Creative Commons Attribution
> 4.0 International License (CC BY 4.0), with the additional terms below. You may use our application
> programming interfaces ("APIs") to facilitate access to the Datasets.

The World Bank's general terms (https://www.worldbank.org/en/about/legal/terms-of-use-for-datasets, retrieved
2026-10-23) limit API use to "non-commercial uses of the Materials". They also forbid using the APIs "in a manner
that exceeds reasonable request volume". Our use is non-commercial research at a few requests a day. Any stage 11
use needs these terms read again.
