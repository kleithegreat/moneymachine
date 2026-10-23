# U.S. Energy Information Administration bulk files (keyless data layer; stage 9 candidate)

The API's bulk downloads at `https://www.eia.gov/opendata/bulk/` need no key (the keyed API itself waits for the
human; Blockers). The manifest `manifest.txt` lists every dataset with its `last_updated` time and URL, and the
files update "twice daily at 5 a.m. and 3 p.m. eastern time".

In scope:
- the manifest, every 6 h;
- `PET.zip` (petroleum and other liquid fuels, about 56 MB), daily, stored only when it changes.

Not recorded: `EBA.zip` (U.S. electric system operating data, hourly grid) is about 699 MB and is refreshed twice
a day. Recording it daily would add about 250 GB a year, beyond this machine's free disk.

Timestamp classes:
- A series' period is a value. The manifest's `last_updated` is EIA's own claim about the file.
- A value is known no earlier than our first fetch of a file that contains it (prospective only).

## Terms: www.eia.gov/opendata/bulk/

- URL: https://www.eia.gov/opendata/bulkfiles.php
- Retrieved: 2026-10-23
- Basis: official API

> EIA data is provided free of charge and should be used in compliance with our Copyrights and Reuse Policy.

The Copyrights and Reuse Policy (https://www.eia.gov/about/copyrights_reuse.php, retrieved 2026-10-23): "U.S.
government publications are in the public domain and are not subject to copyright protection." and "You may use
and/or distribute any of our data, files, databases, reports, graphs, charts, and other information products".
EIA asks for an acknowledgment that includes the publication date.
