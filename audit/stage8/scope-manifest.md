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

## Revision 2026-10-26 (human decisions of 2026-10-26; before any stage 8 inspection of the sources it adds)

RTDSM, BLS, BEA, EDGAR and ECB observations have been fetched for stage 10 and the data layer; the class annex records
which of them any agent has seen and places them accordingly. This revision was written from the documentation-only
survey of 2026-10-26 (`sources-survey/`: `combined-plan.md`, two Opus 5.5 reports and GPT 6.1 Sol's partial report,
each claim with its URL; no observation fetched, nothing signed up for), and reviewed by a fresh-context Opus agent
while GPT was unavailable (GPT's review queued). The text above stays as committed; where this revision differs, it
governs.

**Selection rule 1 is replaced** (human decision: accounts and keys are acceptable under the human's name and email,
CLAUDE.md §3): *the source is an official publisher's or licensed vendor's documented API or machine-readable download;
a key, an account or a contact field under the human's name and email is acceptable; purchases are the human's
decision.* Rules 2 to 4 stand, rule 3 (15 years per proposed series) included.

**Rule 2 is read with the licensing boundary** (human decision; paper, Multi-asset research). Each source's declaration
records its role:
- **agent-readable** only if its terms record quotes a grant covering reuse (public domain, CC BY, or equivalent);
- **kernel-only** otherwise, if the record quotes clauses permitting storage and deterministic processing. Its rows
  enter only deterministic code (ingestion, certification tests, kernel and gate). Research agents and reviewers see
  only its permitted reports; the operator's coding sessions may see small amounts while debugging, preferring
  counts, hashes, schemas and test results (human decision). Any field the terms name as restricted, metadata
  included, does not cross;
- **excluded** where its terms forbid even kernel-only use.

The human classified CME data through Databento, Norgate and Nasdaq-originated data as kernel-only, and makes no
permission requests. Two survey cautions are recorded against that reading: CME's Schedule 5 and notice DS-45, read
only through search snippets, name "Information, including metadata" and "generating output"; and Nasdaq's Data AI
Policy asks for "appropriate permission or license to use Nasdaq Information in the AI tool". Before any pull, each
such source's full terms are read and quoted in its record.

**Integrity**, wherever this manifest allows inspection only for integrity, means schema, row counts, hashes, key
uniqueness, knownAt ordering and missingness counts, computed by deterministic code: no value distributions, returns,
plots or row samples.

### Sources reconsidered

| Source | Route | Terms | Role | Status |
|---|---|---|---|---|
| Federal Reserve Board Data Download Program | `Output.aspx` direct downloads: preformatted packages and whole-release SDMX files of H.15, H.10, G.17, Z.1 and policy rates | automated retrieval permitted (help page); site information public domain, "may be copied and distributed without permission"; current vintage only; Build Your Package removed the week of 2026-11-09 | agent-readable | proposed: certified and recorded from 2026-10-26 (`venue/sources.toml`, `fed-ddp`); point-in-time only from our own recording |
| NY Fed reference rates | markets API | automated access and storage explicitly allowed | agent-readable | proposed for series with at least 15 years in catalog metadata (EFFR, if verified); SOFR, OBFR, TGCR and BGCR are prospective recording only |
| Treasury par yield curve | XML feed, from 1990 | silent | — | blocked on terms: admitted only once a permitting clause or official API terms are quoted |
| OECD STES revisions | SDMX, monthly editions since 1999, about 38 countries | unread (403 to the survey) | — | blocked on terms (Blockers); never worked around |
| ECB Real-Time Database, `includeHistory` | ECB SDMX | ECB reuse policy (certified, `ecb`) | agent-readable | proposed |
| BLS | API and release schedules (certified, `bls`); archived releases | public domain; schedule pages certified; archived release pages to be certified | agent-readable | proposed for first prints and release times |
| BEA | API (certified, `bea`); schedules and release archives | API terms certified; archive pages' terms not yet read | agent-readable (API) | API proposed; schedules and archives pending their terms |
| EIA | bulk files and API (certified, `eia`) | EIA-originated series certified; its NYMEX futures prices are CME-sourced | agent-readable (EIA-originated) | EIA-originated series proposed; NYMEX-sourced series as CME below |
| Philadelphia Fed RTDSM | vintages | certified (`philadelphia-fed-rtdsm`) | per its record | proposed; the stage 10 certificate is reused only where its coverage matches the stage 8 use |
| SEC EDGAR | form-type index (Form 25, 8-A12B, 15, 8-K acceptance times) | certified (`sec`) | agent-readable | proposed for listing events and announcement times; certificate reused only where its coverage matches |
| World Bank Pink Sheet | monthly and annual bulk workbooks | CC BY 4.0 | agent-readable | proposed (signal-study tier, as above); the Indicators API route is dropped, since it no longer carries the commodity series |
| Databento GLBX.MDP3 | `definition`, `statistics`, optional `ohlcv-1d`, about 35 roots from June 2010; exact cost from `metadata.get_cost` before any pull | CME licence Schedule 5 and DS-45 (read through search snippets) prohibit ML/AI/LLM use; User Agreement §1.5 passes them through; §9.3 ends all use on termination | kernel-only (human decision), no CME field or metadata crossing | purchase pending (Blockers): about USD 6–25 of the USD 125 credit; full CME texts quoted before any pull |
| Norgate US Stocks Platinum | prices from 1990 with delisted securities, permanent ids, splits and dividends on an ex-date basis (no declaration dates, delisting returns or merger terms), daily index membership (S&P 500 from 1957, prices from 1990) | EULA 2(iv), 8(iii): the LLM provider gains no rights to the data; cl. 21 permits Derived Data; Windows-only | kernel-only (human decision) | purchase pending (Blockers): USD 630 a year plus a Windows VM |
| Massive Stocks Advanced | from 2003: delisted tickers with an as-of registry, dividends with declaration dates, FIGI and CIK; no index constituents | Market Data Terms (2024-10-09): personal, non-commercial use; delete on account termination; silent on AI | kernel-only | purchase pending (Blockers): USD 199 a month |
| Portara/CQG | futures history | the only explicit AI grant found, but CME's terms pass through | kernel-only at best | excluded for now: about USD 7.7–11.6k for 35 roots, behind the CME question |
| Tiingo (paid); Nasdaq Data Link and Sharadar | — | terms not retrievable (403) or not read; Nasdaq's AI policy applies to Sharadar | — | blocked on terms (Blockers) |
| Alpha Vantage | — | not surveyed | — | excluded pending its terms |
| FRED/ALFRED | API | storing and ML use forbidden | — | excluded |
| WRDS (CRSP, Compustat) | — | data may not be loaded into LLMs except enterprise no-training instances | — | excluded |
| LBMA; Nasdaq CHRIS; EODHD commodities; Tiingo free; Cboe and index-provider levels; Norgate futures; Massive futures | — | needs an IBA licence; deprecated; sourced from FRED; no storage; storage forbidden; CME-derived; about 7 years | — | excluded |

Vendors that require deleting their data when an account ends (Norgate, Massive, Tiingo, Sharadar, SimFin, Databento,
WRDS) make the audit record independent of vendor rows. Whether hashes and kernel outputs may be kept after
termination is open for every vendor except Norgate (cl. 21 permits Derived Data); replaying a kernel-only result is
possible only while subscribed.

### Classes under this revision

- **Equities:** blocked until the human decides a purchase. With Norgate, a universe rule from its delisted-inclusive
  registry becomes possible, frozen in a reviewed class annex before any observation is inspected.
- **Indices:** blocked as above. Index levels stay licence-restricted, so the class would change its instruments to
  listed ETFs, labelled "ETF proxy for <index>" and never index-level; the proxy list and each ETF's start date (rule 3)
  are frozen in the class annex. Norgate's index membership has no independent source, and is recorded as a
  qualification; listings are audited against EDGAR Forms 25 and 8-A12B.
- **Commodities:** the backtest tier stays blocked until the human decides on Databento and the CME terms are quoted.
  The signal-study tier on the World Bank Pink Sheet stands.
- **Macro and rates:** the signal-study tier is extended with the free sources proposed above, each certified and
  recorded as data-layer work, inspected only for integrity until a class annex is frozen.

## Revision 2026-10-26 22:04 UTC (18:04 EDT): integrity is the frozen list again (GPT review B2)

GPT's review of the revision above (`audit/stage8/manifest-review-gpt.md`) found that its definition of
**integrity** (adding row counts, key uniqueness, knownAt ordering and missingness counts) relaxes the frozen
criteria revision of 2026-10-23, which allows only HTTP status, sizes, hashes, poll times and parse success before a
class annex. That definition is withdrawn: wherever this manifest allows inspection only for integrity, integrity is
exactly the criteria's list. Checks beyond it run only after the applicable annex choices are frozen. What was
already seen beyond the list is recorded in `audit/stage8/exposure.md`, and each class annex accounts for it
(GPT B1). GPT's findings B1 and B3 to B9 are answered in a further revision before this manifest authorizes any
research use; until then it authorizes recording only.

## Revision 2026-10-26 22:18 UTC (18:18 EDT): answers to GPT's review B1 and B3 to B9

Each answer narrows what this manifest authorizes; none widens it. Recording stays authorized; research use of any
source or class needs every gate below met and a class annex frozen and reviewed.

- **Status of every source and class** (N4). Four states, and a source moves forward only with the evidence named:
  *recording authorized* (certified for automated retrieval and storage: the data-layer feeds, Databento's pulls);
  *research proposed* (named below with a role); *annex blocked* (a gate below unmet); *admitted* (a frozen,
  reviewed class annex). Nothing is admitted today.
- **Exposure first** (B1). Prior exposure is judged by information, not by stage: any observation, diagnostic or
  derived figure a participant or process that could influence a campaign has seen is listed in
  `audit/stage8/exposure.md` before any selection it could influence, with the earlier sessions' data-layer work
  compiled from their transcripts. A class annex places exposed evidence as search or spent and never as fresh.
- **Permission per operation** (B3, B4). Admission of a kernel-only source needs a permissions record quoting the
  governing clauses, upstream terms included (CME's for Databento, EIA's NYMEX series and Portara/CQG), for each
  intended operation: acquisition, storage, deterministic transformation, generator fitting and calibration, kernel
  evaluation, each report shown to an agent or reviewer, recipients, and retention or deletion at termination. A role
  label or a quotation of a prohibition is not a permission. Databento's certification (operator decision,
  2026-10-26) covers acquisition, storage and deterministic kernel processing; outputs shown to agents need their
  own determination, which is the human's (`PROGRESS.md`, decisions awaiting review).
- **Disclosure boundary** (B5). The operator's coding sessions are AI recipients. Their debugging allowance is the
  human's rule and stands as written; this manifest adds that pre-annex disclosures from any recording stay within
  the criteria's integrity list, and that each class annex freezes its report schema before reports exist.
- **Norgate retention** (B6). Open, like every other vendor's, until the full clause 21, its definitions and its
  survival terms are read; retention, disclosure, reuse and reproduction are judged artifact by artifact.
- **Selection rules for proposed series** (B7). A research-proposed series meets rules 3 and 4 from catalog
  metadata. Recording-only series (SOFR, OBFR, TGCR, BGCR and any series under fifteen catalog years) are labelled
  as such and cannot enter research through recording alone. Dating a series from its first and last observations
  does not replace catalog metadata unless a reviewed revision of this manifest allows it before the affected
  evidence is accessed.
- **Macro extension** (B8). Research proposed only for series named by stable identity with a target or feature
  role, or chosen by a metadata-only population and eligibility rule frozen in a reviewed revision before any
  selection-relevant diagnostic exists. Until then the extension is recording only; the ECB FX population and rule
  stand unchanged.
- **Index membership** (B9). Constituent-universe admission is blocked until independent historical membership or
  listing evidence meets C8.1 with zero unexplained errors; Norgate checked against itself is not that evidence. An
  ETF proxy study needs a metadata-only proxy-selection rule and stable identities frozen first (N2), audits the ETFs'
  own population and lifecycle, and discharges no index-level or constituent claim.
- **Purchases** (N1). A purchase is one prerequisite of a class, not its admission; certification, lifecycle,
  accounting and audit gates remain.
- **Exclusion reasons** (N3). Each exclusion points to its terms record, and the record says whether the source is
  prohibited, not verified, or not selected.

These answers go to GPT for review before this manifest authorizes any research use.

## Revision 2026-10-31 00:05 UTC (2026-10-30 20:05 EDT): answers to GPT's third review (B1, B3 to B5), adopted with GPT's wording corrections

GPT's review of the draft is `audit/reviews/2026-10-30-gpt-stage8-draft.md`; the human accepted its corrections
(`audit/decisions.md`, 2026-10-31 00:00 UTC (2026-10-30 20:00 EDT)). Written before any stage 8 inspection of what it
affects. Each change narrows what this manifest authorizes; none widens it. Nothing is admitted, and every existing
blocker stays. Where this revision differs from the text above, this revision stands.

- **Exposure inventory before affected selection** (B1). Before the first class annex, and before any selection it
  could influence (source, population, feature, window, transformation), `audit/stage8/exposure.md` is completed and
  frozen as a campaign-relevant inventory. It incorporates every read recorded in the stage 10 thesis series' ledger
  and every other recipient (sessions, subagents, GPT runs), by artifact, interval and recipient, and traces indirect
  disclosures (a registry, a prompt attachment, a summary) and overlaps across sources. Without that inventory a class
  stays annex blocked. The inventory is not needed to adopt this rule, only before the affected selection or annex
  proceeds.
- **Placement is not a prospective freeze** (B1). Placing exposed evidence as search or spent keeps freshness
  accounting honest; it does not satisfy any requirement that a choice precede inspection. Each annex lists which of
  its choices were made after exposure to evidence bearing on them, and the claims so blocked. The ECB
  candidate-population and 750-date eligibility rules were committed in c2b0811 before the recorded ECB observation
  disclosures and remain unchanged. This establishes chronology only for those rules, not prospective compliance for
  other choices. Each annex adjudicates already-made and still-unmade choices against prior exposure and the
  applicable freeze requirements; unsupported claims remain blocked. Search/spent placement supplies no retrospective
  exemption.
- **Permission before each operation, not only before admission** (B3, B4). Recording authorization is conditional on
  acquisition and storage rights established by the source's certificate or permissions record before the fetch.
  Every later operation (deterministic transformation, generator fitting and calibration, kernel evaluation, any
  report shown to an agent or reviewer, retention after termination) needs its applicable source-specific permission
  first. Coverage is source- and operation-specific. Databento GLBX.MDP3's acquisition, storage and deterministic
  kernel processing rest on the recorded operator determination of 2026-10-26; ICE is excluded. No other operation is
  deemed covered merely because it is deterministic. Aggregate AI-facing reports are human-approved in principle under
  the decisions of 2026-10-26 17:25 UTC (13:25 EDT) and 23:19 UTC (19:19 EDT), but remain operationally blocked until
  the applicable permissions record, frozen report schema and disclosure-safety prerequisites are satisfied.
  Retention of vendor-derived artifacts after termination is not covered. If a source's terms prohibit an intended
  operation and no permission will be sought, the operation is excluded. This replaces the pointer to "decisions
  awaiting review", which is empty: the human decided the AI-output question on 2026-10-26 (`audit/decisions.md`).
- **Disclosure to coding sessions** (B5). The debugging allowance is replaced. Before an annex freezes: the criteria's
  integrity list only. After: schemas, counts, hashes and test results; row samples only from agent-readable sources
  and only from search periods, each logged in `exposure.md`; never from a kernel-only source. Schemas, counts, hashes
  and test results are disclosures subject to the applicable source permissions, phase restrictions and frozen
  disclosure boundary; debugging creates no exception. Nothing derived from a holdout reaches the research process,
  including integrity checks (C8.6).
