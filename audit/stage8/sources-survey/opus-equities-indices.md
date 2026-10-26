# Stage 8 data survey: equities and equity indices

Prepared 2026-10-26 16:40 UTC (12:40 EDT). Scope: equities and equity indices only. Commodities and macro/rates are
covered by the other agent's report.

Method: vendor documentation, terms, pricing pages and catalog metadata only. No price, return or other market
observation was downloaded or looked at. Nothing was signed up for. Every claim below about terms, coverage or price has
a URL. "Unverified" means I could not confirm it from a primary source. Where a vendor's terms page returned HTTP 403, I
did not work around it; those sources are marked "terms not retrievable", which is a blocker for certification under
CLAUDE.md, not a pass.

## 0. Findings that change the brief's assumptions

1. **Norgate is Windows-only on the official route (confirmed).** The `norgatedata` package needs the Norgate Data
   Updater (NDU) running. The PyPI page says "NDU must be running for this Python package to work". Supported OSes are
   Windows 10/11 and Server 2019/2022/2025. For Mac/Linux, the page says to run NDU and Python inside a Windows VM, and
   that "Norgate has medium-term plans to offer a native Mac / Linux version"
   (https://pypi.org/project/norgatedata/). The free-trial page repeats: "Only Python running on Windows is currently
   supported" (https://norgatedata.com/subscribe/freetrial.php).
2. **Norgate's EULA (dated 20261002) requires deleting all Content when the subscription expires**, including copies,
   exports and backups in any environment. Derived Data (backtests, statistics, trading rules) may be kept
   (https://norgatedata.com/subscribe/eula.php, clause 21). This conflicts with an audit record that holds raw inputs
   permanently.
3. **The WRDS AI policy bans loading WRDS data into LLMs.** The only exception is "protected versions": enterprise-level
   instances with a no-training data-protection agreement. CRSP and S&P are among the vendors that allow that exception;
   TAQ is not listed
   (https://wrds-www.wharton.upenn.edu/pages/about/ai-policy-on-chatgpt-and-other-generative-ai-tools/). A consumer
   Claude or ChatGPT subscription is not an enterprise instance. So WRDS/CRSP, the best data on paper, cannot be read by
   our agents as the project currently runs.
4. **Cboe's free index histories cannot be stored.** Cboe's website terms allow only "view, print and download one copy
   of the Materials for your personal non-commercial use". They forbid storing "in an electronic retrieval system" without
   Cboe's prior written consent (https://www.cboe.com/terms, last updated 2022-11-16). VIX and other Cboe index CSVs
   therefore need a written permission request ("Request to Use Cboe Content", same page).
5. **Nasdaq has a Data AI Policy that reaches any Nasdaq-originated data** (Nasdaq exchange feeds, Nasdaq indices, and
   therefore Databento's XNAS.* and EQUS.SUMMARY, which is built from Nasdaq NLS+). It says: "When using a third party AI
   tool, recipients must make sure they have the appropriate permission or license to use Nasdaq Information in the AI
   tool for that use case", and that LLM/RAG dissemination "must be controlled through a technical entitlement system that
   can be interrogated for audit and compliance purposes"
   (https://www.nasdaqtrader.com/content/AdministrationSupport/AgreementsData/Data_AI_Policy.pdf; notice DN2025-2,
   2025-02-26, https://www.nasdaqtrader.com/TraderNews.aspx?id=DN2025-2).
6. **No free source is sufficient for survivorship-free US equities.** Every source that has delisted names plus
   corporate actions is paid, institutional, or has terms that forbid persistent storage on its free tier.
7. **Nearly every paid vendor requires deleting the data when the subscription or account ends.** This holds for
   Norgate, Massive/Polygon, Tiingo, Sharadar (via QuantRocket), SimFin, WRDS (when the affiliation ends) and Databento
   (no further use). The design consequence is the same everywhere: raw vendor data cannot outlive the subscription, so
   audit replays of raw inputs are possible only while subscribed. What can stay permanently is derived results and
   content hashes. Whether hashes count as "Content" is not addressed by any of these terms (open question).

## 1. Equities: candidate sources

Legend: PIT = point-in-time features. "Delisted" = delisted securities included with their price history.

| Source | Access / price | Coverage | PIT features | Terms verdict (quoted, URL) | Linux | Volume (est.) | Verdict |
|---|---|---|---|---|---|---|---|
| **Norgate Data, US Stocks Platinum** | Paid: USD 630 / 12 mo, USD 346.50 / 6 mo (https://norgatedata.com/stockmarketpackages.php). Diamond (back to 1950) USD 787.50/yr. 3-week trial limited to 2 years of history (https://norgatedata.com/subscribe/freetrial.php) | US major-exchange listed; Platinum history and delisted "Back to 1990" (stockmarketpackages.php). Delisted DB: "25222 delisted securities from the start of 1950 to Sep 2022", with "no claim that the database for Delisted is 'complete'" for the 1950s/60s. Excludes OTC-only stocks, warrants, rights, preferreds (https://norgatedata.com/data-content-tables.php) | Permanent `assetid`, "a unique unchanging ID generated by Norgate". Adjustment `NONE` gives raw prices. Capital events (splits, reverse splits, stock dividends, reorganisations) effective "on the day prior to the ex-date". Dividends shown on the ex-date basis. `last_quoted_date` for delisted names. Historical index constituents (Platinum/Diamond) (https://pypi.org/project/norgatedata/). **Missing:** dividend announcement/declaration and payment dates (no such function documented), merger consideration or delisting proceeds/returns, and post-delisting OTC prices (OTC excluded) | EULA 20261002 (https://norgatedata.com/subscribe/eula.php). Use: "use of the Content solely by the Licensee for the Licensee's own non-commercial purposes". Storage and processing: may "export, extract, copy, transmit, store and process Content in any Processing Environment for Personal Use"; "The restrictions concern the purpose and users of the Content rather than the particular technology". Third-party/AI processing: may "use third-party software, computing, storage, hosting or analysis services to process the Content on the Licensee's behalf, provided that the Content remains solely for the Licensee's Personal Use and the provider is not granted any right to use the Content for any independent purpose" (2(iv)); see also 8(iii). Expiry: "must cease using the Content … and delete all Content … including copies, exports, extracts and backups"; "The Licensee is permitted to retain Derived Data" (cl. 21). Derived Data includes "trading results, simulated trading (backtests), and statistics". No AI/ML clause by name. **Verdict: permits our use if (a) the LLM providers get no training rights, and (b) raw Content is deleted at expiry** | **No native support.** Needs a Windows VM (or a Windows host with WSL2) running NDU. Export to Parquet on Linux is permitted by 2(iii) | ~35k securities × avg ~8 yr × 252 d ≈ 70M rows: roughly 3-4 GB raw, 1-2 GB Parquet (my estimate) | **Partial, closest to sufficient.** Missing: announcement dates, delisting proceeds, OTC tail, Linux; deletion on expiry |
| **WRDS: CRSP US Stock (CIZ), CRSP indexes, Compustat, TAQ** | Institutional (free to the student if the university subscribes and grants an account) | CRSP: NYSE from 1925-12-31, AMEX from 1962, Nasdaq from 1972, Arca from 2006 (library summaries, e.g. https://business.uc3m.es/en/databases/crsp/; CRSP release notes list a daily calendar from 1925-12-31, https://crsp.org/crsp_pdf/crsp-us-stock-database-release-notes-2023-06-monthly). Delisted included with delisting codes and returns (https://datacenter.safe-frankfurt.de/_tutorials/slides/Introduction_CRSP_Stock_Market_Database.pdf) | **The gold standard.** PERMNO is a permanent identifier. Distributions carry a declaration date (`dclrdt`), ex, record and payment dates (https://crsp.org/crsp_pdf/june-2014-monthly-release-notes-0; CIZ edits add declaration dates per distribution, https://www.crsp.org/crsp_pdf/crsp-us-stock-database-release-notes-2025-12-annual). Raw prices, delisting returns, S&P 500 daily membership `dsp500list(_v2)` with `mbrstartdt`/`mbrenddt` (https://library.smu.edu.sg/topics-insights/notes-and-thoughts-retrieving-historical-members-sp-500-wrds). Compustat lost S&P constituents in July 2020 "due to SPDJI direct licensing" (same URL). Caveat: CRSP revises history (corrections), so its files are not vintage-PIT | WRDS ToU (https://wrds-www.wharton.upenn.edu/users/tou/): "The WRDS services are for academic and non-commercial research purposes only"; "Users may not use data downloaded from the WRDS database for any non-academic or commercial endeavor"; "Users are not permitted to script or otherwise automate the login to the WRDS website" (website); "Automation is permitted on the WRDS Cloud server". Download policy: "Researchers may also download data to process elsewhere"; store "such that only you have access"; delete "when your affiliation with the subscribing institution concludes" or "when the subscription with the data vendor ends" (https://wrds-www.wharton.upenn.edu/pages/about/data-download-and-analysis-policy/). AI: "loading Data retrieved from WRDS into LLMs and other Generative A.I. tools is prohibited", with an exception only for "enterprise-level instances of an LLM that include a data-protection agreement that the tool vendor (e.g., Anthropic, Gemini) will not use data in queries for any training purposes" (CRSP, S&P, LSEG, MSCI listed; TAQ not) (AI policy URL above). **Verdict: unusable for LLM agents unless the human has an enterprise/edu no-training LLM agreement. "Academic" use is also ambiguous for a private project** | Yes: `wrds` Python package / PostgreSQL (https://pypi.org/project/wrds/); MFA via Duo (https://wrds-www.wharton.upenn.edu/pages/about/log-in-to-wrds-using-two-factor-authentication/) | CRSP daily stock file ~100M rows: ~5-10 GB Parquet (estimate) | **Data sufficient; terms unusable as the project runs today** (AI policy). Could become sufficient only with an enterprise LLM instance and written confirmation that this project counts as "academic" |
| **Massive (formerly Polygon.io), Stocks Advanced** | USD 199/mo for "20+ Years Historical Data", flat files included. Developer USD 79 (10 yr), Starter USD 29 (5 yr), Basic free (2 yr, 5 calls/min) (https://massive.com/pricing) | All US equities. Day-aggregate flat files from 2003-09-10 (https://massive.com/docs/flat-files/stocks/day-aggregates/2003/09). Tickers endpoint returns delisted names: `active` "False means the asset has been delisted", `delisted_utc`, and a `date` parameter for "tickers available on that date" (https://massive.com/docs/rest/stocks/tickers/all-tickers) | Dividends with `declaration_date`, `ex_dividend_date`, `record_date`, `pay_date`, back to 2000-01-15 (https://massive.com/docs/rest/stocks/corporate-actions/dividends). Splits. IDs: `composite_figi`, `share_class_figi`, `cik` (tickers doc). **Missing:** merger/spin-off terms, delisting proceeds, index constituents. Whether the flat files include delisted names is claimed in marketing but not confirmed in docs | Market Data Terms (2024-10-09) (https://massive.com/terms/market_data_terms.pdf): license "exclusively for your personal, non-business, and non-commercial purposes"; "you may not use the Market Data to build an application intended for use by end users other than you"; on termination: "if the Agreement or your account are terminated or suspended for any reason, you agree to cease all use of the Market Data and delete all Market Data in your possession". Individuals ToS (2025-07-18): use "solely for your own personal, non-commercial, and non-business purposes"; no AI/ML clause (https://massive.com/legal/individuals-terms-of-service). **Verdict: silent on AI (risk, not permission). Storage is not forbidden while the account exists. Deletion is triggered by account termination; whether downgrading to the free tier keeps the right to retain is ambiguous** | Native (S3 flat files, REST) | 2003-2026 day aggregates: ~5,800 daily files, ~60M rows, ~2 GB (estimate) | **Partial.** Best Linux-native option: raw prices, delisted tickers, dividend declaration dates, FIGI. Missing: index constituents, merger/delisting proceeds, pre-2003 history. AI clause silent |
| **Databento US Equities** (XNAS.ITCH, EQUS.SUMMARY etc.) + corporate actions / security master | Usage-based, billed "per byte consumed" on uncompressed size; USD 125 credits expire after 6 months (https://databento.com/docs/knowledge-base/new-users/usage-based-pricing-and-data-credits). Equities Standard plan USD 199/mo with "7 years of OHLCV history" (https://databento.com/blog/introducing-databento-us-equities). Reference-data (corporate actions) prices are not published, "Contact sales" (https://databento.com/corporate-actions, https://databento.com/pricing) | XNAS.ITCH "available from 2018-05-01". Daily backfill "to at least 2010" is a roadmap item, not delivered (https://roadmap.databento.com/b/n0o5prm6/feature-ideas/nasdaq-totalview-itch-extended-coverage-before-2018-05-01). Corporate actions: "listed and delisted securities", "8 years" PIT history, 215 venues (https://databento.com/docs/schemas-and-data-formats/corporate-actions; https://databento.com/corporate-actions). Security master from 2005 (https://databento.com/security-master) | Corporate-action records carry `event_date`, `ex_date`, `record_date`, `payment_date`, `effective_date`, `listing_date`, `delisting_date`, `notification_date`, and `ts_created`/`ts_record` (a revision trail). This is the best PIT design surveyed, but there is no dedicated announcement timestamp (schema URL above) | User Agreement (effective 2024-01-31; https://databento.com/legal/terms, section text from the page's own HTML): licence "solely for its internal business purposes … for so long as Customer has a Customer Account … in good standing"; on termination "Customer may no longer download, access, or use any Third-Party Data" (9.3). No AI/ML clause. Nasdaq-sourced datasets also fall under the Nasdaq AI Policy (finding 5). **Verdict: permissive on storage while the account exists; AI risk via the Nasdaq policy** | Native | OHLCV-1d record = 56 B. ~12k symbols × 252 × 8.5 yr ≈ 26M records ≈ 1.4 GB uncompressed (estimate) | **Partial / not for the 15-year requirement.** History starts 2018 (2010 only if the backfill ships). Corporate-actions pricing is unpublished. **Cost of daily bars for the whole universe: could not be verified.** Databento shows $/GB rates only inside the portal; `metadata.get_cost` (needs an API key) returns the exact quote before purchase. Keep the USD 125 for futures |
| **Tiingo** | Free Starter; Power USD 30/mo or USD 300/yr individual (https://www.tiingo.com/about/pricing) | "30+ years" price history; 49,595 US & Chinese stocks (pricing page). Delisted: partial per user reports (https://www.elitetrader.com/et/threads/bring-back-yahoo-api.313050/post-4517537), unverified | Ticker metadata with start/end dates; dividends and splits in the EOD rows. No documented announcement dates | Pricing page: "Internal use means you may only use the data for your own personal use". ToS (https://app.tiingo.com/tos/, "Last Updated October 6th, 2026", seen via search snippets only; direct fetch returned **HTTP 403**). Starter/trial plans: "you may not write, save, archive, back up, or otherwise retain Tiingo Data in any persistent or durable storage". Paid plans may persist "solely to the extent permitted by that Paid Plan"; on cancellation or downgrade "you must promptly and permanently delete all Tiingo Data". **Free tier unusable (no persistent storage). Paid tier: terms not fully retrievable (403)** | Native | small | **Unusable on the free tier. Paid tier: partial and uncertifiable** (403 on the terms, weak delisted coverage, no announcement dates) |
| **EODHD** | EOD All-World USD 19.99/mo or USD 199/yr; All-in-One USD 99.99/mo; students 50% off for 12 months (https://eodhd.com/pricing) | Paid plans "30+ yrs". Delisted list via `exchange-symbol-list/US?delisted=1`. Names delisted **before 2018: "EOD only"** (no dividends/splits); after 2018, EOD, fundamentals, dividends and splits (https://eodhd.com/financial-apis/delisted-stock-companies-data-2) | OHLC raw: "OHLC we provide in raw adjusted neither to splits nor to dividends" (https://eodhd.com/knowledgebase/api-for-). Dividends with `declarationDate`, `recordDate`, `paymentDate`; US "complete" (https://eodhd.com/financial-apis/api-splits-dividends). Symbol-change history (US only). Ticker-keyed; ticker reuse not addressed | T&C (https://eodhd.com/financial-apis/terms-conditions): non-professional users "are permitted to store, manipulate, and analyze the data for private, non-commercial purposes". Non-professional is defined as "solely in a personal capacity for their own personal investment activities" (a research project is arguably outside that). No AI/ML clause. No retention-after-cancel clause. No date on the terms | Native | small | **Partial.** Raw prices and good dividend dates after 2018, but pre-2018 delisted names lack corporate actions, so the universe is not survivorship-correct before 2018. No stable IDs. AI clause silent |
| **Alpha Vantage** | Free key; premium tiers (price not checked) | `LISTING_STATUS` with `state=delisted` and a `date` snapshot parameter (https://www.macroption.com/alpha-vantage-delisted-stocks/, third party). Price history for delisted names unverified | Ticker-keyed. DIVIDENDS endpoint fields unverified | ToS (https://www.alphavantage.co/terms_of_service/, PDF): licence "for personal, non-commercial use". Commercial use includes purposes "beyond investment analysis, research, testing, monitoring, and any other activities that are private and individual in nature". No storage, AI or deletion clause. **Permissive-silent** | Native | small | **Partial / unverified.** Delisted price coverage, adjustment and history depth not documented in primary sources. Fine as a cross-check, not as the base |
| **Nasdaq Data Link: Sharadar (SEP, TICKERS, ACTIONS, SP500)** | Paid. "USD 39/mo personal" is unverified (third-party aggregator). Through QuantRocket: non-pro licence, usable only inside QuantRocket (https://www.quantrocket.com/pricing/data/sharadar) | Prices "since 1998", active and delisted; S&P 500 additions/removals "since 1957" (https://www.quantrocket.com/docs/data/fundamental/sharadar/) | Field-level docs not retrievable (the Nasdaq Data Link site renders client-side). Permaticker, unadjusted close and ACTIONS types unverified | Nasdaq Data Link terms page (https://data.nasdaq.com/terms) renders client-side and was not retrievable. Via QuantRocket: delete "all copies of the data, derived datasets, and software" within 30 days of termination (QuantRocket pricing URL). Nasdaq AI Policy may apply to Nasdaq-distributed data (finding 5) | Native API | ~1-3 GB | **Partial / unverified.** Promising (1998+, delisted, SP500 history, Linux-native) but the terms could not be read. Worth a human look at the Data Link licence before ruling it in or out |
| **Financial Modeling Prep** | Paid tiers (https://site.financialmodelingprep.com/developer/docs/pricing) | Has a delisted-companies endpoint (search results) | Unverified | ToS returned **HTTP 403**. An older enterprise agreement requires deleting "all Data … including data cached" after termination (search snippet) | Native | small | **Uncertifiable (403)** |
| **Intrinio** | EOD prices USD 3,100/yr (https://intrinio.com/products/stock-prices-eod). Individual Starter Plan price not published | Active names from 1967; **delisted only from 2007** (https://intrinio.com/guides/starter-plan) | Unverified | Not reviewed (price and coverage already disqualify it) | Native | — | **Unusable** (cost; delisted only from 2007) |
| **SimFin** | Free (5 yr), Start USD 180/yr, Basic USD 420/yr (students 50% off), Pro USD 852/yr (https://www.simfin.com/en/prices/) | "5,000 US Stocks" (free). Delisted not stated | Fundamentals-oriented | Subscribers must "delete all downloaded data from your devices and clean-up backups" when they stop; use only with a valid subscription (pricing page) | Native | small | **Unusable** for the universe (no documented delisted coverage) |
| **Alpaca Market Data** | Free with an Alpaca (brokerage) account | History "back to 2016" (staff forum reply, https://forum.alpaca.markets/t/missing-historic-data-for-daily-timeframe/14567). Exchange-listed only; delisted bars end at exchange exit | `asof` symbol mapping across renames; mapping errors on reused tickers reported (https://forum.alpaca.markets/t/fixing-data-historical-bars-of-symbol-q-are-comprised-of-two-different-stocks/18184) | Not reviewed in depth. Sign-up is a brokerage account (a new account the human must decide on; no orders are ever placed) | Native | — | **Unusable** (10 years < 15; brokerage-account sign-up) |
| **QuantConnect** (US Equity Security Master + daily data for local LEAN) | Security Master USD 600/yr (Researcher tier) plus daily historical data USD 3,480 (https://www.quantconnect.com/docs/v2/lean-cli/datasets/quantconnect/us-equity) | ~27,500 US equities from Jan 1998; splits, dividends, delistings, mergers, ticker changes (https://www.quantconnect.com/data/quantconnect-us-equity-security-master) | Good (security master) | Not reviewed (cost) | Native (LEAN CLI) | — | **Paid alternative, too expensive** (≈ USD 4,000+) |
| **MarketParquet** | USD 79 one-time archive; USD 15/mo updates (https://marketparquet.com/llms-full.txt) | Stocks/ETFs from Jan 2000; ~8,500 of 16,000+ tickers delisted | **Split-adjusted only, no raw prices, no dividends field, no stable IDs**, upstream vendor unnamed (llms-full.txt) | Licence explicitly allows "Feed the data to AI/ML models and coding agents you operate" and storing copies (https://marketparquet.com/license). Undisclosed provenance is a chain-of-title risk | Native Parquet | small | **Unusable** as an execution basis (no raw prices or dividends; unknown provenance) |
| **SEC EDGAR** (already ingested) | Free | All SEC registrants. Index files "from 1994Q3 through the present" (https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data) | **Issuer-level listing registry, no prices.** Form 25 (exchange delisting notice), filed on EDGAR since the 2005 Rule 12d2-2 amendments; delisting is effective 10 days after filing (https://www.sec.gov/files/rules/final/34-52029fr.pdf; https://www.willkie.com/publications/2005/08/sec-adopts-rule-regarding-delisting-and-withdraw__). Also Form 8-A12B (exchange registration, i.e. listing) and Form 15 (deregistration), from the form type in the index files. 8-K filings carry announcement timestamps (acceptance time) for dividends, M&A and spin-offs, but unstructured. Ticker and exchange are XBRL-tagged on cover pages only for periods ending on or after 2019-06-15 (large accelerated filers), 2020 and 2021 for the rest (https://cache.xbrl.us/wp-content/uploads/2020/05/inline-coverpage-factsheet.pdf). `company_tickers_exchange.json` is current-only and "not guaranteed accurate" | Already certified in `venue/sources.toml` [sec]: "Information presented on sec.gov is considered public information and may be copied or further distributed by users of the web site without the SEC's permission" (https://www.sec.gov/privacy). Rate ≤ 10 req/s with a contact User-Agent | Native | Form-index metadata < 1 GB | **Partial (supplement).** Gives CIK-stable issuer identity, delisting/listing events since ~2006, and announcement timestamps. No prices, no ex/pay dates in structured form, no ticker history before 2019 |
| **Nasdaq Trader symbol directory** (nasdaqlisted.txt, otherlisted.txt) | Free FTP | **Current snapshots only**, "updated periodically through-out each day" (https://www.nasdaqtrader.com/trader.aspx?id=symboldirdefs) | Forward-only registry if archived daily | Site copyright: only "one temporary copy in a single computer's memory and one unaltered permanent copy", "for personal and non-commercial use only"; other use "requires the prior written consent of Nasdaq" (https://www.nasdaqtrader.com/Trader.aspx?id=CopyDisclaimMain). A daily archive is more than one copy | Native | tiny | **Unusable without written consent**; and no history anyway |
| **Nasdaq Daily List** (listings, delistings, symbol changes, dividends, splits since 1999) | Paid monthly subscription; needs Nasdaq approval and the Global Data Agreement (https://nasdaqtrader.com/Trader.aspx?id=DailyListPD) | Nasdaq-listed only; history from 1999 | Effective dates for events | Institutional agreement | — | — | **Unusable** (Nasdaq-only; institutional contracting) |

## 2. Equity indices: candidate sources

| Source | Access / price | Coverage | PIT features | Terms verdict (quoted, URL) | Linux | Verdict |
|---|---|---|---|---|---|---|
| **Norgate (Platinum)**: index levels + historical constituents | Included in USD 630/yr | Constituents: S&P 500 from Mar 1957, S&P 100 from Sep 1989, MidCap 400 from Jun 1991, SmallCap 600 from Oct 1994, Russell 1000/2000/3000 from Jul 1990, Nasdaq-100 from Oct 1993, DJIA from Jan 1950, and others. "Essentially complete back to the Constituents Start date" (https://norgatedata.com/data-content-tables.php). Index levels: price indices. **Total-return variants for US indices not found** on the content page (only commodity TR indices are listed); unverified | `index_constituent_timeseries` gives daily membership (https://pypi.org/project/norgatedata/). Membership is as of the effective date; announcement dates not documented | As for Norgate equities (EULA) | Windows VM | **Partial → sufficient for constituent strategies** (membership from 1990 for most indices within Platinum's 1990 price window). TR levels unverified; derive TR from constituents or ETF distributions |
| **CRSP indexes via WRDS** | Institutional | CRSP market indices "with and without dividends" and "Composite Indices for S&P 500 and NASDAQ"; S&P 500 membership daily from 1957/1958 (https://library.smu.edu.sg/topics-insights/notes-and-thoughts-retrieving-historical-members-sp-500-wrds; https://wrds-www.wharton.upenn.edu/pages/grid-items/downloading-the-sp-500-constituents/) | Daily membership start/end dates; price and total-return pairs | WRDS AI policy (finding 3) | Yes | **Data sufficient; terms unusable** for LLM agents as the project runs today |
| **Kenneth French data library** | Free download | Market, size, value, momentum and industry portfolios, daily/weekly/monthly. Built from CRSP (CIZ since Jan 2025) (https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html) | **Not vintage-PIT:** "We reconstruct the full history of returns each month"; "Historical returns can change, for example, if CRSP revises its database". Archived vintages exist for some factor files (same URL). Market factor = CRSP value-weighted total return minus T-bill | No terms of use; only "Copyright Eugene F. Fama and Kenneth R. French" (same URL). **Silent: a risk, not permission.** Derived from licensed CRSP data | Yes | **Partial: benchmark-only signal studies** (predict the published market or factor return). Not an investable index; revisions; terms silent |
| **Shiller (shillerdata.com)** | Free | Monthly S&P Composite price, dividends, earnings and CPI from Jan 1871. "Stock price data are monthly averages of daily closing prices"; dividends and earnings interpolated (https://shillerdata.com/) | No vintages or revision policy; "not obliged to inform the recipients" of changes | No licence or copyright statement; disclaimer only (same URL). **Silent** | Yes | **Partial: benchmark-only, low-frequency.** Monthly averages are not tradable prints |
| **Cboe index histories** (VIX etc.) | Free CSV on the website | Long VIX history | Daily | "You may not otherwise copy, reproduce, alter, store either in hard copy or in an electronic retrieval system … without Cboe's prior written consent" (https://www.cboe.com/terms) | Yes | **Unusable without written consent** (corrects the brief) |
| **S&P Dow Jones Indices** (website levels; SPICE) | Website; SPICE is paid | Index levels and constituents via SPICE subscription ("Daily constituent and index level data are available via subscription", https://www.spglobal.com/spdji/en/documents/methodologies/methodology-sp-us-indices.pdf) | — | The spglobal.com terms page returned **HTTP 403**. A third-party copy of the S&P DJI terms says index data may be used "only for your personal, non-commercial purposes" and restricts storing (https://act.webull.com/policy/dowjones?hl=en) | — | **Unusable** (terms not retrievable; restrictive copy) |
| **MSCI** (end-of-day index search) | Website | 270,000+ indexes | — | "for informational, non-commercial purposes only"; copying without "prior written consent" prohibited (https://www.msci.com/accept-terms-and-conditions, per search snippet) | — | **Unusable** |
| **FTSE Russell** | Licensed data products | Russell US indices | — | Website terms not found. End-user terms (via Wilshire) allow internal viewing only under a services contract (https://wilshire.com/index-vendor-terms/ftse-russell-end-user-terms-2021) | — | **Unusable** without a licence |
| **Nasdaq Global Indexes** | Website | Nasdaq indices | — | Nasdaq copyright terms plus the Nasdaq Data AI Policy (findings 5, Nasdaq Trader row) | — | **Unusable** without a licence |
| **EODHD S&P/DJ constituents add-on** | "USD 29.99/mo" promotional (https://eodhd.com/lp/spglobal) | 100+ indices; S&P constituent changes with dates: "12 years of history", Dow Jones 2 years; full snapshots "will be added … later this year". TR and net TR variants exist but "might not have same depth" | Dated additions/exclusions | EODHD T&C as above; claims "a direct contract with S&P Global" | Native | **Partial** (12 years < 15; AI silent) |
| **ETF proxies** (SPY, IVV, IWM, QQQ, sector SPDRs) from the equity vendor | Comes with the equity source | e.g. SPY since 1993 inside Norgate's or Massive's window | Raw prices plus distributions with dates give an **investable total-return series** with explicit dividends | The equity vendor's terms | — | **Sufficient for index-level full backtests**, given an equity source. Recommended over vendor index levels |

## 3. Recommended plan (equities and indices)

**Free-only result:** no free combination is sufficient for full-backtest equities. EDGAR (already certified) gives the
issuer/listing event registry, and Ken French gives benchmark-only factor series (terms silent, so it needs a decision).
Together they reach only the benchmark-only signal-study tier for indices, and nothing tradeable for single stocks.

**Smallest set reaching the full-backtest tier:**

1. **Norgate US Stocks Platinum, USD 630/yr** (the purchase PROGRESS.md already plans), run in a capped Windows VM on the
   NixOS host. NDU and the `norgatedata` export script run inside the VM, which exports Parquet to the Linux side; EULA
   2(iii) and 14 permit this. It covers:
   - a survivorship-free universe from 1990 with permanent `assetid`;
   - raw prices (`NONE`);
   - split and dividend events on the ex-date basis;
   - daily historical membership of S&P 500/400/600, Russell 1000/2000/3000, Nasdaq-100 and DJIA from 1990 or earlier;
   - ETF proxies for index strategies.

   Extra cost: a Windows licence, price not verified. The VM also needs about 4 GB of the 15 GB RAM while NDU runs.
2. **SEC EDGAR (free, in hand), extended** to the form-type index (Form 25, 8-A12B, 15, 8-K acceptance timestamps),
   keyed by CIK. It fills Norgate's gaps:
   - delisting and listing event dates since ~2006;
   - announcement timestamps for M&A, spin-offs and dividends (8-K acceptance time);
   - a CIK↔assetid crosswalk built from names and dates. No vendor ships that crosswalk; it would be our own derived
     table.

   Delisting proceeds for cash mergers can be bounded from the deal terms in the 8-K and DEFM14A filings, but this is
   manual and unstructured. Recommend treating delisting proceeds as the last raw price, recorded as a known
   qualification with a pre-registered sensitivity bound.
3. **Ken French and Shiller (free)**, only for benchmark-only signal studies, after a recorded decision that silent terms
   are acceptable. That decision must not be taken alone if it could affect leakage; it cannot, so it is a reversible
   `audit/decisions.md` item. Note that French data derives from CRSP.

**Total: USD 630/yr plus a Windows licence.** Tier reached:
- US equities: full backtest from 1990, with membership-correct index-constituent universes.
- Indices: full backtest through ETF proxies from their inception (1993+). Benchmark-only before that.

Known qualifications:
- no dividend declaration dates in Norgate (EDGAR 8-K is a partial substitute);
- no delisting returns;
- post-delisting OTC prices missing, which biases results for bankruptcies and must be pre-registered as a limitation.

**Linux-native alternative, if the Windows VM is rejected:** Massive Stocks Advanced, USD 199/mo (one month of bulk
flat files and reference data = USD 199; a year = USD 2,388). It covers:
- 2003+, delisted tickers with a `date`-as-of registry;
- raw daily bars;
- dividends with declaration/ex/record/pay dates;
- FIGI and CIK.

It lacks index constituents, so constituent strategies would need EODHD's 12-year S&P add-on or nothing. It ties
deletion to account termination, so ask Massive in writing whether a downgraded free account may retain the data.

**Not recommended for equities:**
- Databento: history from 2018, and the cost of daily bars for the whole universe could not be verified. Spend the
  USD 125 on futures, and run `metadata.get_cost` after sign-up before any equities pull.
- WRDS/CRSP: blocked by the AI policy unless the university provides an enterprise no-training LLM.
- Tiingo free: no persistent storage.
- Cboe, S&P DJI, MSCI, FTSE Russell, Nasdaq index levels: storage or terms forbid it without a licence.

## 4. Risks and open questions for the human

1. **LLM providers and "no independent rights" (Norgate 2(iv)/8(iii); WRDS; Nasdaq AI Policy).** Agents reading stored
   data send it to Anthropic (Claude Code) and OpenAI (GPT reviews). Anthropic's consumer terms (Free/Pro/Max, including
   Claude Code) allow training on sessions unless the user opts out; commercial/API plans are excluded
   (https://www.anthropic.com/news/updates-to-our-consumer-terms). Before any licensed data reaches an agent, the human
   should:
   - confirm the "help improve Claude" setting is off (and the OpenAI equivalent), or move agent traffic to API or
     commercial terms;
   - preferably also adopt the design option below.

   **Design option (§1-style, removes the risk at the root):** agents never read raw vendor Content. They read only
   kernel outputs: backtest results and statistics, which Norgate's EULA defines as Derived Data, retainable and not
   restricted to Personal Use processing. This needs a stage 8 design decision. It also determines what the ledger may
   store.
2. **Deletion on expiry vs. the append-only audit record.** Norgate (cl. 21), Massive (§10), Tiingo, Sharadar,
   SimFin, Databento (9.3) and WRDS all require deletion or end of use when the subscription, account or affiliation
   ends. The ledger and evidence files must then hold only Derived Data and hashes, never raw rows. Otherwise a lapsed
   subscription forces deleting audit records, which CLAUDE.md forbids. Open question: is a content hash "Content"?
   Ask Norgate in writing.
3. **Windows dependency (Norgate).** Needs a Windows VM and licence on NixOS, and NDU must run for any update.
   Norgate's native Linux is only "medium-term plans". This is the brief's "serious problem", confirmed. The human must
   accept it, or choose Massive (a coverage trade-off).
4. **Norgate data gaps:**
   - no announcement or payment dates;
   - no delisting returns or merger consideration;
   - OTC-only securities excluded, so prices after a move to OTC are absent;
   - delisted history starts 1990 on Platinum (1950 needs Diamond, USD 787.50).

   These must be pre-registered as limitations or filled from EDGAR.
5. **WRDS eligibility and wording.** WRDS offers individual accounts to undergraduates "at Subscriber institutions",
   but master's and undergraduate accounts can expire each semester (library guides). Website automation is forbidden;
   whether the `wrds` PostgreSQL route with Duo MFA can run unattended is unverified. "Academic" use of a private
   project is ambiguous. Ask the university library which CRSP products are licensed, and whether the university has an
   enterprise LLM agreement that WRDS would accept.
6. **Terms that could not be retrieved (HTTP 403 or client-side rendering; not worked around):** Tiingo ToS, FMP ToS,
   S&P Global terms, Nasdaq Data Link terms. Each belongs under Blockers if a source is to be certified. Sharadar via
   Nasdaq Data Link is the one worth a manual read (1998+, delisted, S&P 500 since 1957, Linux-native).
7. **Unverified prices:** Databento equities $/GB and corporate-actions licence; the Windows licence; Sharadar
   personal tier; Alpha Vantage premium.
8. **Point-in-time caveat common to all vendors:** vendor histories are restated (corrections, back-adjustments). None
   of the equity vendors publishes vintages, except Databento's corporate actions (`ts_created`/`ts_record`). Our
   kernel should hash and freeze the exported snapshot at download time and treat the vendor's later revisions as new
   vintages.
