# Stage 8 scope manifest (2026-10-23)

Written from documentation, terms, schemas and catalog metadata only, and revised once after GPT's review
(`gpt-scope-review.md`). No market observation from any source below had been fetched or inspected when it was
committed.

Human decisions of 2026-10-23:
- Start with as much free data as possible, designed for extension.
- Stage 8 has a signal-study tier (criteria amendment).
- The keyless sources are certified and ingested now as background data-layer work. The manifest is therefore
  committed before that ingestion, with its open verification items carried into the data-layer work, where they
  gate the class annexes rather than this manifest.

Ingestion records raw data, its fetch times and its past versions. Nothing inspects returns or signals before the
class annexes are frozen. Kernel generalization, and stage 8 implementation beyond the data layer, still wait for
stage 7's exit and the pilot's judged runs.

## Source-selection procedure

A source is proposed only if all of these hold, judged from documentation, terms and catalog metadata captured
before any observation is fetched:

1. It is an official publisher's documented API or documented machine-readable download, reachable without a key, an account or the operator's identity.
2. Its terms permit our automated, read-only, non-commercial research use. Each proposed source is referenced by its terms record (URL, retrieval date, quoted clause; paper §5, `ingest/terms.py`), and later by its certificate identity. A prior certification (stage 10) is reused only where its coverage matches the stage 8 endpoint, fields and historical use.
3. Each proposed series, at its proposed frequency, has at least 15 years of history in its catalog metadata, and documented point-in-time availability is assessed separately for it (C8.2).
4. Its catalog gives series-level metadata (identifiers, frequency, units, start and end dates) without observations.

All sources considered are listed below with the reason for inclusion or exclusion. No ranking is used.

A failed certification or annex prerequisite is recorded as a failure or blocker. Any replacement source,
universe-rule change or class-scope change gets a dated, reviewed revision before affected evidence is
inspected. Returns, signals and calibration outcomes never decide those revisions.

Current venue listings (Hyperliquid HIP-3) never select a historical research universe, benchmark or window.
They are projection targets only.

## Sources considered

| Source | Endpoint | Terms record | Proposed use | Status |
|---|---|---|---|---|
| ECB Data Portal | SDMX 2.1 REST (`data-api.ecb.europa.eu`), dataflow EXR; the reference-rate history file | ECB statistics reuse policy (free reuse, source quoted, unmodified), read 2026-10-23 | FX reference rates, daily | proposed |
| ECB Data Portal | dataflow YC (euro area yield curves) | as above | feature | proposed |
| BIS data portal | SDMX REST (`stats.bis.org/api`), dataflows WS_CBPOL, WS_EER | BIS terms of permitted use ("unrestricted", with citation) and API terms, read 2026-10-23 | features | proposed |
| CFTC public reporting | `publicreporting.cftc.gov`, traders in financial futures | certified for stage 10 (coverage to be matched) | feature (FX futures positioning) | proposed |
| Treasury Fiscal Data | `api.fiscaldata.treasury.gov`, average interest rates | certified for stage 10 (coverage to be matched) | feature | proposed |
| World Bank Pink Sheet | CMO monthly files; Indicators API | CC BY 4.0, API for non-commercial use, read 2026-10-23 | commodity benchmarks | proposed for the signal-study tier |
| GDELT | `api.gdeltproject.org`, `data.gdeltproject.org` | certified for stage 10 (coverage to be matched) | event features | proposed |
| IMF data | SDMX and portal | "prohibits bulk download of information by automated technology without explicit permission" | — | excluded: needs a permission request (Blockers) |
| FRED/ALFRED, EIA, BEA | their APIs | registered key required | — | excluded (Blockers) |
| BLS, SEC EDGAR | their APIs | User-Agent with the operator's contact email; 403 to our agent | — | excluded (Blockers) |
| Tiingo, Alpha Vantage, Nasdaq Data Link | their APIs | registered key required | — | excluded (Blockers) |
| Yahoo Finance, Stooq | web pages | terms forbid automated access (Stooq likely) | — | excluded |
| Hyperliquid info API | `api.hyperliquid.xyz` | read-only public API (human decision 2026-10-23) | projection targets | proposed for C8.7 only |

Among the sources considered, none satisfies the access, terms and historical-data requirements for equities,
indices or commodity contracts at the backtest tier. This is not a claim that every possible keyless source has been exhausted.

## Classes

### Equities: blocked

- **Intended role:** underlying equity signal studies.
- **Universe rule:** unresolved. No certified historical candidate population (listing registry) or point-in-time eligibility inputs were found among the sources considered.
- **Jurisdictions and venues considered:** US listed equities (NYSE, Nasdaq). Possible later projection: HIP-3 equity perps.
- **Unmet requirements:** a historical listing, and raw and adjusted price histories with corporate actions, from a source meeting the selection procedure.
- **No equity observations are fetched under this scope.**

### Indices: blocked

- **Intended role:** index-level signal studies. Constituent strategies would also need point-in-time membership evidence, and none is in scope.
- **Universe rule:** unresolved. There is no keyless source of long index-level histories whose terms permit automated access.
- **Jurisdictions and venues considered:** US and euro area equity indices. Possible later projection: HIP-3 index perps, whose histories are months long.
- **No index observations are fetched under this scope.**

### Commodities: backtest tier blocked; signal-study tier proposed

- **Intended role:** commodity signal studies.
- **Why blocked:** C8.2 requires individual contracts, contract metadata, roll decisions and held-contract PnL, and paper §9 describes futures with explicit roll rules. The only keyless long history found, the World Bank's monthly benchmark prices, has no contracts or rolls. Benchmark-only studies would need a reviewed, frozen criteria revision. That revision is not proposed here, since it relaxes a frozen requirement.
- **Point-in-time gap:** recent Pink Sheet months are revised, and no historical vintages were identified.
- **Signal-study tier (criteria amendment of 2026-10-23):** the World Bank's monthly benchmark prices are proposed as signal-study targets, labeled "signal study: predicts <benchmark>; no execution claim". Where their past versions cannot be recovered, they are usable only from the start of our own recording of each monthly release. CFTC positioning (as known at publication) and GDELT events are inputs. The universe is the benchmark-series identities in the historical catalog as known at each decision. Discontinued series are included, and replacements are never joined without a certified transformation.
- **Jurisdictions and venues considered:** global benchmark prices; CFTC-reported US futures; HIP-3 commodity perps (`xyz:GOLD`, `flx:OIL`) as possible projection targets.
- **No commodity contract observations are fetched under this scope.**

### Macro and rates: proposed for admission at the signal-study tier (ECB FX reference rates); annex and certification prerequisites outstanding

- **Instruments:** euro FX reference rates (signal studies on underlyings). A reference fixing is not an executable quote, and no trading result on an FX or rate instrument is claimed.
- **Features:** euro area yield curves (ECB), central bank policy rates and effective exchange rates (BIS), CFTC traders-in-financial-futures positioning in currency futures, and average Treasury interest rates (Fiscal Data). Each is known no earlier than its certified availability rule allows, never at its reference date.
- **Candidate population:** the currency identities in the ECB's historical reference-rate series, including currencies whose publication was suspended or ceased. They are taken from series-level catalog metadata with start and end dates, not from the current currency list, so euro adoptions and suspensions are lifecycle events in the population.
- **Universe rule:** eligibility is evaluated at the annex's frozen decision cutoff. A currency qualifies with a published fixing on each of the preceding 750 publication dates of the certified ECB calendar (TARGET days on which fixings are scheduled), counting only fixings available by that cutoff. No ranking is used; membership is a set of stable series identifiers.
- **Lifecycle:** a missing expected fixing, a suspension or a cessation affects eligibility only once that fact is known under the certified availability rule. It never causes a retroactive close at an earlier fixing. Exposure stays explicitly represented until the annex's frozen lifecycle and valuation rules resolve it. A missing price creates no fill, and an unresolved outcome is reported under the frozen missing-terminal-price policy. Entry, suspension, cessation and re-entry policies are frozen in the annex before observation access.
- **Historical point-in-time use:** each feature is usable historically only where recoverable publication and revision evidence satisfies certification. Prospective recording establishes evidence only from its certified start and never validates earlier vintages. A feature without such evidence is blocked for historical use.
- **Jurisdictions:** euro area (ECB), international (BIS), US (CFTC, Treasury).

## Reporting

- If the admitted scope meets its frozen criteria, completion is reported for it explicitly , with its tier ("stage 8 completed for ECB FX reference rates and World Bank commodity benchmarks as signal studies; equities and indices blocked, commodity backtests blocked").
- Venue projections are reported separately: each stays model-dependent under C8.7, and where no eligible mapping is certified, execution mapping stays blocked.
- No signal-study result is described as venue validation or trading readiness.

## Open verification items (carried into the data-layer work; they gate the class annexes)

- ECB EXR: the series identifiers, frequency, units and start and end dates, including discontinued currencies.
  - *Done 2026-10-23 (`detail=nodata`, no observations):* 44 daily series `D.<CUR>.EUR.SP00.A`. The catalog keeps discontinued currencies (CYP, EEK, GRD, HRK, LTL, LVL, MTL, SIT, SKK) and suspended ones (RUB), so a historical candidate population exists. Some series are not reference rates (titles without "ECB reference exchange rate": ARS, DZD, MAD, TWD, RUB, and the pre-euro legacy currencies). The population rule must name the reference-rate series by attribute, not by title text.
  - *Open:* the API has no availability endpoint (`availableconstraint` returns 404), so start and end dates are not obtainable as metadata. Dating each series by its first and last observation is observation access. It needs a reviewed procedure in the annex, or the ECB's documented history of the reference-rate list. Also the publication time convention (rate determination at 14:10 CET versus publication) and whether published fixings are ever revised.
- ECB YC: the exact series, start dates (expected 2004-09) and revision policy.
- BIS: the supported API version and dataflow identifiers, and for WS_CBPOL and WS_EER their series frequencies, histories and revision metadata.
  - *Done 2026-10-23 (dataflow metadata, `detail=nodata`):* `stats.bis.org/api/v1`, dataflows `BIS:WS_CBPOL(1.0)` ("Central bank policy rates", structure BIS_CBPOL) and `BIS:WS_EER(1.0)`. WS_CBPOL has 49 daily series by REF_AREA, including XM (euro area) and RU; its attributes document compilation and breaks (`COMPILATION`, `SUPP_INFO_BREAKS`).
  - *Open:* the catalog gives no vintages or revision history, so historical point-in-time use of policy rates needs release evidence or is blocked. A policy rate is announced before its effective date, so knownAt needs the announcement time, which the series does not carry.
- CFTC traders in financial futures: the API dataset's history and its currency contract identifiers, and the publication schedule as a schedule to verify against release evidence, not an availability rule.
- Treasury average interest rates: the endpoint, categories, units, history and revision behavior.
- The ECB reference-rate calendar source for "publication dates".
