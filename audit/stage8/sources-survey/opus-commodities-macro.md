# Stage 8 data survey: commodities (futures) and macro/rates

Written 2026-10-26 16:49 UTC (12:49 EDT) by an Opus research agent. Sources: documentation, terms, pricing pages
and catalog metadata only. No price, return or market observation was fetched or looked at. Structural metadata
was read in two places: the OECD SDMX dataflow structure (codelists, `detail=referencepartial`) and the World Bank
source and indicator lists. Unverified items are marked **[unverified]**.

Fetcher notes: `cmegroup.com` timed out on every request, through WebFetch and plain curl alike. CME's own pages
are therefore quoted from search snippets, and their exact text is an open question. `oecd.org` returned 403. One
curl request that set a browser User-Agent was blocked by the harness as bot-check circumvention and was not
retried.

---

## 0. Headline finding (read first)

**CME now prohibits AI/ML/LLM use of its market data, and every futures source on CME contracts is derived from
that data.** The sources:

- CME's "CME DATA TERMS OF USE" (website data) require CME's prior written consent to use CME Data to build
  software, including training ML or AI systems. They also bar bots, scripts and crawlers
  (https://www.cmegroup.com/content/cmegroup/en/trading/market-data-explanation-disclaimer.html, read via search
  snippet). CME Clearing Advisory 23-364 says clients may use CME Data only "for personal use and for
  non-commercial purposes" (https://www.cmegroup.com/notices/clearing/2023/12/Chadv23-364.html).
- **Schedule 5 to the CME Information License Agreement (January 2026)**, the terms distributors pass on to their
  subscribers, prohibits using Information, including metadata, for machine learning or AI purposes, "including
  training models and generating output", and calls this "expressly prohibited"
  (https://www.cmegroup.com/market-data/files/schedule-5-to-the-ila-january-2026.pdf, snippet only).
- **CME notice DS-45 (June 18, 2026; most changes effective September 17, 2026)** says ML, AI and LLM uses are
  "strictly prohibited". It also announces bot detection and IP rate-limiting, and treats circumventing them to
  harvest data for AI as a material violation
  (https://www.cmegroup.com/market-data/files/market-data-license-agreement-updates-june-2026.pdf, snippet only).
- Databento's User Agreement passes provider terms through. §1.5 says use of Third-Party Data is subject "not only
  to this Agreement but also to any terms of use ... established or required by the relevant Third-Party
  Provider", and §1.5(e) bars use "for any purpose prohibited by the relevant Third-Party Provider"
  (https://databento.com/legal/04-00-00-user-agreement.html, effective January 31, 2024).

Our design has LLM research agents read the stored data, and possibly generate output from it. That falls
squarely inside the words "using those tools or models to generate output". Some evidence points the other way:

- CME DataMine's FAQ says "CME does not currently restrict the distribution of historical End of Day or Time and
  Sales data either internally or externally"
  (https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457319709/CME+DataMine+Support).
- CME defines "historical" as data taken more than 8 hours after publication (WatersTechnology,
  https://www.waterstechnology.com/data-management/7952957/cme-rankles-market-data-users-with-licensing-changes).

Whether the AI prohibition reaches historical data delivered by a vendor is **unverified**. Until CME or the vendor
confirms in writing that it does not, the commodity backtest tier on CME contracts should be treated as
**blocked on terms**. That holds for Databento, Norgate, Portara/CQG, FirstRate, Massive, Barchart, Kibot, CSI and
CME DataMine alike. It also touches the EIA "NYMEX futures price" series, if those are ingested (see §1.3).

The narrow exception is Portara/CQG. Its own license grants "Research, backtesting, model and AI training", but
whether CQG can grant that over CME's terms is unverified. A written-permission request is a human decision, and
vendor permission requests are currently on hold (PROGRESS.md, human, 2026-10-25).

---

## 1. Commodities

### 1.1 Futures contract sources

| Source | Access | Coverage | Point-in-time features | Terms verdict (quoted, URL) | Linux | Volume | Verdict |
|---|---|---|---|---|---|---|---|
| **Databento GLBX.MDP3** (CME, CBOT, NYMEX, COMEX) | Credits: USD 125 on sign-up, usable on historical data or "towards the cost of the first month of a subscription plan"; they "expire after 6 months" (https://databento.com/docs/faqs/usage-pricing-and-data-credits). Usage-based $/GB, metered on uncompressed binary size (https://databento.com/docs/knowledge-base/new-users/usage-based-pricing-and-data-credits). Standard plan USD 199/month includes "16+ years" of L0 history (OHLCV-1s/1m/1h/1d, Definition, Statistics, Status) (https://databento.com/pricing, https://databento.com/catalog/cme/GLBX.MDP3). | "full coverage of all futures and options on futures beginning in June 2010" (https://databento.com/docs/venues-and-datasets/glbx-mdp3); the ohlcv-1d and definition schemas start 2010-06-06 (third-party probe, https://github.com/chris-mulligan-50/futures-project/issues/8). Individual contracts, including all listed expirations and futures-only spreads under the parent symbol (`ES.FUT`). 650,000+ symbols. | `definition`: one record per instrument, timestamped and replayable ("avoids lookahead and survivorship bias"); a snapshot of all active definitions at UTC midnight on weekdays. Fields: `unit_of_measure_qty`, `contract_multiplier`, `min_price_increment`, `currency`, `settl_currency`, `expiration` (last eligible trade time), `activation`, maturity components, price limits (https://databento.com/docs/schemas-and-data-formats/instrument-definitions). **No first-notice-day or delivery fields.** `statistics`: the venue's official settlement (preliminary and final), cleared volume, open interest, and session open/high/low, with `ts_ref`; later publications supersede earlier ones (https://databento.com/docs/schemas-and-data-formats/statistics). Caveats: before 2017-05-21 (MDP 2) "`ts_recv` ... is set to the same value as `ts_event`" with `F_BAD_TS_RECV` set; "Settlement prices before 2015-11-20 follow different rules"; "The CME does not publish settlement prices on their MDP feed for instruments without open interest or volume" (glbx-mdp3 page). `ohlcv-1d` "is based on UTC dates" and emits no bar on no-trade days (https://databento.com/docs/schemas-and-data-formats/ohlcv). | Databento §1.1: license "solely for its internal business purposes ... for so long as Customer has a Customer Account ... in good standing". §9.3: "Upon termination ... Customer may no longer download, access, or use any Third-Party Data". No AI clause of Databento's own, but §1.5 incorporates CME's terms (see §0). Historical data needs no exchange license: "You do NOT need a license to access historical (T+1) data" (https://databento.com/blog/introduction-market-data-licensing). **Verdict: blocked on the CME AI clause until clarified.** | Yes: Python, Rust and C++ clients, HTTP API, DBN format. | Estimated in §1.4: about 1–5 GB uncompressed for the recommended pull. | **Sufficient on coverage, history (16.4 years) and specs, except first notice day. Partial overall: the terms (CME AI) are unresolved.** |
| Databento ICE Futures US / ICE Europe Commodities / ICE Endex | Credits; "from $10.00/GB" (IFUS), "$1.75/GB" (ICE Europe Commodities) (https://databento.com/futures). The 2024 rate sheet gives IFEU.IMPACT `OHLCV-1d` at $2.40/MB, `Statistics` $25/GB, `Definition` $8/GB (http://databento-media.s3-website-us-east-1.amazonaws.com/media/unit-pricing-draft-2024-04-01.pdf). | All "Since 2018" (https://databento.com/futures). Brent and gasoil (IFEU); softs, DXY and MSCI (IFUS). | Same schemas. | Same Databento terms; ICE's own AI terms **[unverified]**. | Yes | Small | **Partial: about 8 years, short of the 15-year goal.** |
| Databento Eurex | Credits | "Since 2025" | — | — | Yes | — | **Unusable: too short.** |
| Norgate Data futures | USD 148.50 for 6 months, USD 270 for 12 months (https://norgatedata.com/futurespackage.php). The same figures appear for a stock tier, so a copy error is possible **[unverified]**. | "around 100 Futures markets drawn from 11 worldwide exchanges"; "back to around 1980"; individual contracts and continuous series. | Python metadata: tick size, point value, first notice date, last quoted date per contract (https://pypi.org/project/norgatedata/). Revision history **[unverified]**. | Not read in depth; the data is CME-derived (§0). | **No.** The updater (NDU) runs on Windows 10/11/Server only (https://norgatedata.com/ndu-installation.php); the Python package says NDU "must be running for this Python package to work" and suggests a Windows VM or WSL2 (https://pypi.org/project/norgatedata/). | up to 63 GB (all entitlements) | **Unusable as it stands: needs Windows, which is a serious problem.** It has the best spec metadata (first notice day). |
| **Portara (CQG Data Factory)** | One-off "$330, or $220 on special" per commodity, full history, individual or continuous; subscriptions by quote (https://portaracqg.com/pricing/). | "127 years of historical daily, intraday and tick futures data from 1899"; individual contracts available (https://www.portaracqg.com/). Daily bars from "Settle or reported Last Price". | Contract specs **[unverified]**. Vendor-built bars, with no publication timestamps. | License (https://portaracqg.com/license/): "Perpetual, non-exclusive, non-transferable"; use "Within your organization, by up to five people, on your own computers, servers or cloud instances"; permitted: "Research, backtesting, model and AI training, live trading". **This is the only explicit AI grant found**, but CME pass-through applies (§0). | Yes: CSV/ASCII by FTP, "platform-neutral" (one-off). Subscriptions use their Windows-like "Data Powerhouse" software **[unverified]**. | Small (daily) | **Sufficient on terms and coverage if CME pass-through is cleared. Cost about USD 7,700–11,600 for 35 roots. Specs unverified.** |
| FirstRate Data futures | One-off bundle price not shown on the page; about USD 299 per a third party (https://nexusfi.com/d/data-providers/firstrate-data/) **[unverified]**; updates "$59.95 per month" (https://firstratedata.com/b/29/futures-most-active). | "most active 130 contracts", from 2008; "both individual futures contracts as well as a continuous futures series" (https://firstratedata.com/). | Bars from trades; no settlements or specs stated. | "It may be stored on your own servers and used in perpetuity"; "the Data is for the private use of the Subscriber only"; derivative use includes "incorporating the Data into its internal models"; AI not mentioned (https://firstratedata.com/about/license). CME pass-through applies. | Yes (files) | Small | **Partial: no settlements or contract specs, history from 2008.** |
| Kibot | Price not on page (https://www.kibot.com/futures_historical_data.aspx) | 83 futures (CME, CBOT, NYMEX, COMEX, CFE); individual months "back to inception" | — | License page not read **[unverified]** | Yes (files) | — | **Unverified.** |
| CSI Data (Unfair Advantage) | Old listing about USD 313 a year for North American futures (https://store.traders.com/stcov315prre2.html) **[unverified, dated]** | Long individual-contract histories | — | — | **Windows software** | — | **Unusable (Windows), unverified.** |
| CME DataMine | Pricing behind login. Historical figures: USD 105/month per dataset, USD 2,173/month for EOD Premium Plus (HealthyMarkets letter, https://healthymarkets.org/wp-content/uploads/2024/11/Ltr-to-CFTC-re-CME-Data-and-Fees-11-19-24-1.pdf). The education discount exists ("Do you offer discounts for university students and employees? Yes we do"; contact sales) (https://cmegroupclientsite.atlassian.net/wiki/spaces/EPICSANDBOX/pages/457319709/CME+DataMine+Support). | EOD from "1/1/1982 or contract inception"; all official closing information (OHLC, settlement, volume, OI). | Official source; publication timestamps **[unverified]**. | "CME does not currently restrict the distribution of historical End of Day ... data". AI terms per §0. | API delivery (Linux OK) | — | **Partial: likely the cleanest licensing route (direct with CME), but the price is unknown and probably high.** |
| CME website (settlements pages, Daily Bulletin) | Free display | Current day only | — | Bots, scripts and crawlers barred; ML/AI training needs written consent (§0). | — | — | **Unusable.** |
| Massive (formerly Polygon) futures | Basic USD 0 (2 years), Starter USD 29, Developer USD 79 (5 years), Advanced USD 199/month (7+ years), all "Individual use" (https://massive.com/pricing?product=futures) | CME, CBOT, NYMEX, COMEX; a Contracts endpoint with "first and last trade dates, settlement date, tick sizes" (https://www.massive.com/blog/futures-data-has-arrived) | Good specs | Not read (the equities agent covers Massive's terms); CME pass-through applies. | Yes | — | **Partial: at most about 7 years of history.** |
| Barchart (website and OnDemand) | OnDemand pricing unpublished | Daily from 1980 (Excel add-in) | — | Website: "You may not use any data mining, robots, or similar data gathering and extraction tools"; downloads "for personal use only" (https://www.barchart.com/terms, https://www.barchart.com/solutions/legal/terms). OnDemand license **[unverified]**. | — | — | **Website unusable; OnDemand unverified (enterprise sales).** |
| Nasdaq Data Link CHRIS (Quandl wiki futures) | — | Continuous series only | — | Nasdaq told a user the CHRIS database "has been deprecated and is no longer updated", with no alternate feed (https://github.com/PacktPublishing/Python-for-Algorithmic-Trading-Cookbook/issues/5). No live individual-contract futures product found on Nasdaq Data Link. | — | — | **Unusable.** |
| Tiingo | — | No futures or commodities listed (https://www.tiingo.com/documentation/general/overview) | — | — | — | — | **Unusable (no coverage).** |
| EODHD commodities | Free tier | Spot/benchmark series only, **sourced from FRED** (https://eodhd.com/financial-apis/commodities-api) | — | Inherits FRED's terms, which are ruled out. | — | — | **Unusable.** |

### 1.2 Benchmark (fallback, signal-study tier)

| Source | Access | Coverage | Point-in-time | Terms | Verdict |
|---|---|---|---|---|---|
| **World Bank Pink Sheet** | Free files | About 70 monthly series from 1960 | Monthly averages; the workbook is overwritten in place, so it has no vintages. Next update: "November 3, 2026" (https://www.worldbank.org/en/research/commodity-markets). | Data Catalog CC BY 4.0: "allows users to copy, modify and distribute data in any format for any purpose, including commercial use" (https://datacatalog.worldbank.org/public-licenses). The Commodity Markets page labels the data CC-BY. | **Partial (benchmark tier).** See notes below. |
| EIA spot prices (in use) | — | Daily energy spot prices | — | Public domain except "materials ... contributed or licensed by private individuals, companies, or organizations that may be protected" (https://www.eia.gov/about/copyrights_reuse.php). | **Check:** EIA's daily spot and NYMEX futures price series (Contract 1–4) are vendor- or CME-sourced; if ingested, they may carry CME's AI restriction **[unverified]**. |
| LBMA gold/silver/PGM prices | — | — | — | "A licence from IBA is required in order to obtain, use or redistribute real-time or historical benchmark data"; historical tables are on the MyLBMA portal and need an IBA licence (https://www.lbma.org.uk/prices-and-data/lbma-precious-metal-prices); the website shows only a delayed figure "to midnight on the day of the auction" (https://www.lbma.org.uk/prices-and-data/lbma-gold-price/lbma-gold-price). | **Unusable.** |
| IMF PCPS | — | — | — | Ruled out (bulk automation forbidden). | **Unusable.** |
| USDA (AMS, NASS, ERS) | — | — | — | usda.gov returns 403 to our fetcher (recorded blocker); not worked around. | **Unusable as it stands.** |

Notes on the Pink Sheet:

- Its URL looks stable within a calendar year. The October 2026 workbook sits under doc id
  `74e8be41ceb20fa0da750cda2f6b9e4e-0050012026`, the same id as a "2/3/2026" catalog entry. The 2025 id ends
  `-0050012025` (search results). This contradicts our registry note that "the hash changes with each release"
  **[inference, verify]**.
- Monthly PDFs (`CMO-Pink-Sheet-<Month>-<Year>.pdf`) sit in the same doc folder and give as-published values.
  Whether every past month survives is **[unverified]**.
- The Indicators API no longer carries the series: source 15 (GEM) has 36 indicators and no commodity prices
  (https://api.worldbank.org/v2/source/15/indicators).
- The CMO report archive holds Commodity Markets Outlook issues, not Pink Sheet files
  (https://www.worldbank.org/en/research/commodity-markets/report-archive).
- Reading the Commodity Markets page automatically rests on site terms our registry records as "lawful, personal
  and non-commercial".

### 1.3 Volume and cost estimate (Databento, the concrete case)

Unit prices: Databento's published May-2024 historical rates for GLBX.MDP3 are `OHLCV-1d` $190/GB, `Definition`
$1.70/GB and `Statistics` $1.00/GB. The previous rates were $175, $1.66 and $0.80 (2024 rate sheet above; also
Databento's quickstart notebook, https://github.com/databento/databento-python/blob/main/notebooks/quickstart.ipynb).
The current rates are **unverified**. `metadata.list_unit_prices` and `metadata.get_cost` are free metadata calls,
and the exact figure should come from them before any pull.

Record sizes come from DBN: OHLCV 56 B, StatMsg 80 B, InstrumentDefMsg 520 B (`size_of` assertions in
https://github.com/databento/dbn/blob/main/rust/dbn/src/record.rs).

Universe: 35 roots, 2010-06-06 to 2026-10-26, about 4,130 sessions and about 4,300 UTC-day bars. The roots:

- Equity index: ES, NQ, YM, RTY.
- Rates: ZT, ZF, ZN, ZB, UB, SR3/GE.
- FX: 6E, 6J, 6B, 6A, 6C, 6S.
- Energy: CL, NG, RB, HO, BZ.
- Metals: GC, SI, HG, PL, PA.
- Grains: ZC, ZS, ZW, KE, ZM, ZL.
- Livestock: LE, HE, GF.

Instrument counts per day are assumptions, so a range is given:

| Pull | Assumption | Uncompressed | Cost at 2024 rates |
|---|---|---|---|
| `definition`, one UTC-midnight snapshot per month (catches every contract, since contracts are listed for months to years) | 197 months × 35 roots × ~300 instruments (spreads included) × 520 B | ~1.1 GB | **~$2** (daily snapshots instead: ~22 GB, ~$38) |
| `statistics`, outright contracts only (raw symbols taken from the definitions) | 35 × ~40 listed outrights × ~8 records/day × 4,130 days × 80 B | ~3.7 GB | **~$4** (all spreads under the parent symbol: ~14 GB, ~$14; worst case ~$45) |
| `ohlcv-1d`, outrights only | 35 × ~12 traded outrights/day × 4,300 × 56 B | ~0.1 GB | **~$19** (spreads included: ~$48) |
| **Recommended total** | definitions monthly + statistics (outrights) + ohlcv-1d (outrights) | **~5 GB** (less as Parquet) | **~$25 of the $125** |

What USD 125 buys: the full 35-root set at about $25, with room for 2–4 times more roots, or the spreads, before
the credit runs out. Statistics alone gives settlement, open interest, volume and the official session OHLC, so a
settlement-based backtest needs only definitions plus statistics, about $6. ICE Brent and gasoil (IFEU, from 2018)
would add roughly $15–20 (`OHLCV-1d` at $2.40/MB is the expensive part).

The alternative is one month of the Standard plan: $199 less the $125 credit, so $74 out of pocket, for all CME L0
history. Usage-based billing is cheaper for this set. Batch downloads can be fetched again free for 30 days, and
the credits expire 6 months after sign-up, so pull soon after signing up.

### 1.4 Gaps that remain even with Databento

1. **No first notice or first delivery day** in definitions. Physically delivered contracts (CL, NG, GC, ZC and so
   on) need roll rules from the exchange rulebooks. Each root's rule ("FND = last business day before the delivery
   month", and so on) could be encoded once by hand, with citations, as specs data. CME's website cannot be
   fetched automatically.
2. **Before 2017-05-21, arrival times are synthetic** (`ts_recv` = `ts_event`). knownAt for settlements in that era
   needs a conservative rule, for example "final settlement known at the next session's open". Settlement-type
   semantics change at 2015-11-20.
3. Contracts with no open interest or volume have no settlement on MDP.
4. **History is 16.4 years**, enough for the 15-year goal, but only just.

---

## 2. Macro and rates

| Source | Access | Coverage | Vintages / release times | Terms (quoted, URL) | Linux | Verdict |
|---|---|---|---|---|---|---|
| Philadelphia Fed RTDSM (in use) | Free files | GDP, prices, payrolls, unemployment and more | Monthly vintages (mid-month snapshot dates, not exact release times) | Certified 2026-10-26 (`venue/sources.toml`) | Yes | **Sufficient for its variables (vintage-date granularity).** |
| **OECD STES revisions** (`OECD.SDD.STES, DSD_STES_REVISIONS@DF_STES_REVISIONS`) | SDMX API, keyless | 22 measures: GDP and its components (volume, current prices, deflator), production, retail volume, CLI, consumer prices, unemployment, employment, hourly earnings, ULC, M3, current account, trade. Dimensions REF_AREA, FREQ, MEASURE, UNIT_MEASURE, ACTIVITY, EDITION (structure read from https://sdmx.oecd.org/public/rest/dataflow/OECD.SDD.STES/DSD_STES_REVISIONS@DF_STES_REVISIONS/latest). | **Monthly editions from February 1999** (CL_EDITION 199902…); "monthly data snapshots of published short term economic statistics". An edition is the MEI publication month, not a release timestamp. | The terms page returned 403 to the fetcher. Search snippets: written content since 1 July 2024 is CC BY 4.0; data "may be subject to restrictions" (https://www.oecd.org/en/about/terms-conditions.html) **[unverified]**. API limits: "60 data downloads per hour" or "20 queries per minute and 20 data download per hour" (conflicting versions); the OECD recommends "caching results locally" and blocks VPN traffic (https://www.oecd.org/en/data/insights/data-explainers/2024/11/Api-best-practices-and-recommendations.html). | Yes | **Partial: real vintages for about 38 countries since 1999, but monthly edition dates only, and the terms need a clean read.** |
| ECB Real-Time Database (RTD), in the ECB Data Portal (in use) | SDMX API | Euro area series from the Economic Bulletin | Vintages from January 2001; 2015+ through the web service, 2001–2014 as bulk files; updated semi-annually (https://data.ecb.europa.eu/data/datasets/RTD/data-information, via search; the page returned 503) | ECB reuse policy already certified | Yes | **Partial (euro area, vintage-month granularity).** |
| ECB Data Portal `includeHistory` | SDMX parameter | Any series | "true returns that version plus all previous versions" (https://data.ecb.europa.eu/help/api/data; CRAN `ecb` docs). How far back history goes **[unverified]**. | Certified | Yes | **Promising for ECB YC and EXR revision evidence; verify.** |
| BLS archived news releases and schedules | Free, public domain: "everything that we publish ... is in the public domain" (https://www.bls.gov/bls/linksite.htm) | CPI archive 1994–present: TXT 1994–2007, PDF 2002+, HTML 2008+ (https://www.bls.gov/bls/news-release/cpi.htm). Schedules 2000–2025 per year plus a 1957–2000 PDF (https://www.bls.gov/bls/archived_sched.htm). Current schedule with times ("All times on calendar are Eastern Time") and an ICS feed (https://www.bls.gov/schedule/news_release/bls.ics). | **First prints** come from the archived release text, which carries an embargo time; scheduled **dates and times** come from the archived schedules. | Robots: "BLS will block robots that access the website in any way that BLS considers excessive ... also reserves the right to block robots that do not contain information that can be used to contact the owner" (https://www.bls.gov/bls/pss.htm). Use the human's contact User-Agent, per CLAUDE.md. | Yes | **Sufficient for BLS series' first releases and release times (parsing needed).** |
| BEA schedule, archive and data archive | Free | Schedule with times, ICS and JSON (https://www.bea.gov/news/schedule, https://apps.bea.gov/API/signup/release_dates.json); news-release archive; data archive of previously published tables (https://apps.bea.gov/histdata/; range **[unverified]**) | Release dates and times; past published tables by release **[unverified]** | BEA API ToS already certified; the archive pages' terms are not separately read. | Yes | **Partial.** |
| Census economic indicators | Free | Calendar with "Release Date", "Time" (8:30 / 10:00 AM), "Period Covered" (https://www.census.gov/economic-indicators/calendar-listview.html) | Calendar; archive of past releases **[unverified]** | API ToS: no storage clause, unstated limits, attribution notice required (https://www.census.gov/data/developers/about/terms-of-service.html) | Yes | **Partial (calendar only verified).** |
| Eurostat | Free API | Euro indicators | Release calendar in ICS, Europe/Luxembourg time (https://ec.europa.eu/eurostat/en/news/euro-indicators); **no vintage database found** | "Reuse of statistical data ... for commercial or non-commercial purposes" with credit; non-Eurostat-source data excluded from commercial reuse (https://ec.europa.eu/eurostat/help/copyright-notice) | Yes | **Partial: calendar, plus prospective recording only.** |
| **NY Fed reference rates** (SOFR, EFFR, OBFR, TGCR, BGCR) | Free API (markets.newyorkfed.org) | SOFR from April 2018; EFFR start on NY Fed **[unverified]** | Published about 8:00 a.m. ET; "revisions are only effected on the same day as initial publication" (https://www.newyorkfed.org/markets/opolicy/operating_policy_180416, via search) | **Clean:** "Access the Content, manually or through an automated process or device"; "Download, store, and use Content in any format or media"; attribution "Content from the New York Fed subject to the Terms of Use at newyorkfed.org" plus the reference-rate disclaimer; no AI clause (https://www.newyorkfed.org/privacy/termsofuse) | Yes | **Sufficient (SOFR history is short, about 8.5 years).** |
| Treasury daily par yield curve (XML feed) | Free, documented developer feed | Par curve from 1990, bills 2002, long-term 2000, real curve 2003 (https://home.treasury.gov/treasury-daily-interest-rate-xml-feed) | Usually "by 6:00 PM Eastern Time"; inputs taken near 3:30 PM; method changed 2021-12-06 (monotone convex) (https://home.treasury.gov/policy-issues/financing-the-government/interest-rate-statistics/treasury-yield-curve-methodology). No vintages; corrections policy **[unverified]**. | The feed page and "Site Policies and Notices" are silent on reuse (https://home.treasury.gov/subfooter/site-policies-and-notices). It is a US government work and an official documented feed. | Yes | **Sufficient on coverage; terms silent (flag).** |
| **Federal Reserve Board Data Download Program** (H.15, H.10, G.17, Z.1, policy rates) | Free | Full histories, current vintage only: "Data are only available as currently published" | H.15 is posted at 4:15 p.m. (https://www.federalreserve.gov/releases/h15/) | **Explicit automation:** the "Direct download for automated systems" link "is the URL that can be used by computer programs to retrieve the contents of the data package" (https://www.federalreserve.gov/datadownload/help/default.htm). **The DDP is being retired:** "Build Your Package" is to be removed "during the week of November 9 ... in preparation for the eventual retirement of the DDP", and users are pointed to FRED (release pages, e.g. https://www.federalreserve.gov/releases/g5/). | Yes | **Sufficient now, but time-critical:** once retired, only FRED remains, and FRED is ruled out. |
| FOMC decision times | Fed press releases | Statements about 2:15 p.m. ET before 2013 (https://www.federalreserve.gov/newsevents/pressreleases/monetary20090213a.htm); 2:00 p.m. ET for all scheduled meetings from 2013-03-13 (https://www.federalreserve.gov/newsevents/press/monetary/20130313a.htm) | Unscheduled moves (e.g. 2008, 2020) have their own times and need per-event evidence. | Fed RSS certified; other pages may be "copied and distributed without permission", but automation is not addressed (registry note). | Yes | **Partial: a rule plus per-event exceptions.** |
| ECB decision times | ECB press releases | 13:45 CET until July 2022; **14:15 CET from 21 July 2022** (https://www.ecb.europa.eu/press/pr/date/2022/html/ecb.pr220627~73acedf868.en.html) | Rule plus unscheduled exceptions (e.g. 8 October 2008) | ECB reuse policy certified | Yes | **Partial (as for the Fed).** |
| Bank of England database | Free | Bank Rate and more | Vintages: none found | "Reproduction of data in the Database is subject to the terms of the UK Open Government Licence", with "selected exchange rate data" and LSEG data excluded; access may be restricted for "excessive use" (https://www.bankofengland.co.uk/legal) | Yes | **Partial (no vintages; announcement times not researched).** |
| Bank of Canada (Valet API) | Free | Policy rate and more | Announcements at "09:45 (Eastern Time)" in 2025–2026 (https://www.bankofcanada.ca/2025/04/fad-announcement-release-mpr-april-16-2025/); earlier times **[unverified]** | "permits you to freely use, copy, distribute and transmit its website content", with attribution; do not circumvent request limits; no AI clause (https://www.bankofcanada.ca/terms/) | Yes | **Partial.** |

Release calendars with historical actual times, free:

- BLS: archived schedules for 2000–2025, plus each release's embargo line.
- BEA and Census: the current-year calendar with times; for history, their news-release archives.
- Fed and ECB: press-release archives.

No free consolidated calendar with revision history (rescheduled releases) was found. A shutdown-era reschedule
appears in BLS's notes (October 2025 CPI not published), so reschedules exist and must come from the archives.

---

## 3. Recommended plan

**Free, now:**

1. **Fed DDP (time-critical):** certify and archive the preformatted H.15, H.10, policy-rate and G.17 packages
   through the "direct download for automated systems" URLs before the DDP is retired. "Build Your Package" goes
   the week of 9 November 2026.
2. **NY Fed reference rates** and the **Treasury par yield-curve XML feed**: certify (the Treasury terms are
   silent) and record them prospectively, so we have our own vintages.
3. **OECD STES revisions** (1999+, 22 measures, about 38 countries) and **ECB RTD / `includeHistory`**: verify the
   terms (the OECD page returned 403) and certify. These give macro vintages beyond the RTDSM at edition-month
   granularity.
4. **BLS (and BEA) release archives and schedules:** the first-print values and the scheduled release times, which
   give the actual timestamps the RTDSM lacks.
5. **World Bank Pink Sheet:** the benchmark tier only, prospective vintages, plus the monthly PDFs if a check shows
   past months survive.

**Cheapest paid addition for commodity contracts:** Databento GLBX.MDP3: monthly definitions plus outright
statistics, optionally ohlcv-1d, for 35 roots from 2010-06 to now. About $6–25 of the $125 credit, about 5 GB,
Linux-native. **This is conditional on written confirmation** from Databento or CME that LLM agents may read
historical CME data (§0). Without it, commodities stay at the benchmark signal-study tier.

**Fallback if Databento or CME says no:** Portara one-off files (an explicit AI-training grant), at about
USD 220–330 per root, so about $2.2k for the 10 most important roots. CME pass-through still needs confirming.

| Class | Tier reached | Cost |
|---|---|---|
| Macro/rates | Signal study with real vintages (RTDSM, OECD, ECB RTD) and release times (BLS, BEA, Fed/ECB rules); rates as features, from the NY Fed, Treasury and DDP | USD 0 |
| Commodities, terms cleared | Full backtest on individual contracts, 2010+ (first notice days hand-encoded) | ~USD 25 (inside the credit) |
| Commodities, terms not cleared | Benchmark-only signal study (Pink Sheet, prospective vintages) | USD 0 |

---

## 4. Risks and open questions (for the human)

1. **CME's AI/ML/LLM prohibition** (Schedule 5, January 2026; DS-45, effective 17 September 2026; CME website
   terms). Does it cover historical data more than 8 hours old, delivered by a vendor and read by LLM research
   agents? This needs a written answer from Databento (and probably CME Data Sales). It is a permission request,
   which the human has on hold. CME pages could not be fetched here (timeouts), so the full text should be read by
   the human or on a later retry.
2. **Databento §9.3:** our local archive stays usable only while the account is "in good standing". Closing the
   account ends the right to use the data already downloaded.
3. **Unit prices** are from the May-2024 rate sheet. Re-check them with the free `metadata.get_cost` before any
   pull. Credits expire 6 months after sign-up.
4. **Fed DDP retirement:** after it, Fed Board series are reachable only through FRED, which is ruled out. Decide
   quickly whether to archive the DDP now.
5. **OECD terms** (403 to our fetcher) and the API limits (20 or 60 an hour) need a clean read.
6. **Treasury's XML feed terms are silent.** Does "an official documented feed of a US government work" meet our
   certification basis?
7. **EIA's NYMEX futures series** (if any are ingested) may be CME-licensed content.
8. **Pink Sheet:** confirm that the doc id is per-year, and whether past monthly PDFs survive (a HEAD-only check).
9. **First notice days** for physical contracts must be encoded by hand from the rulebooks: a one-time manual data
   entry with citations.
10. **Unverified:** current Norgate futures price; Kibot and FirstRate licenses and prices; Barchart OnDemand; the
    CME DataMine education price; the start of EFFR history on the NY Fed API; the BEA data-archive range; earlier
    Bank of Canada and Bank of England announcement times; ICE's own AI terms.
