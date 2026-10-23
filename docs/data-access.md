# Data access for stage 8: options for the human's decision

Prepared 2026-10-23, while stage 8 is parked until the pilot's judged runs are done. Each option lists what it
would unlock against the frozen stage 8 criteria (PROGRESS.md, Criteria, Stage 8), what it needs from the
human, and its cost.

Prices were found by web search on 2026-10-23. "Confirmed" means the vendor's own page states the price;
anything else must be checked before buying. Nothing here has been signed up for, and no key has been requested.

Every option still has to pass certification (C8.2 under C7.3): terms quoted, point-in-time availability, and
revisions. A source that gives only today's adjusted history fails C8.2 for decision inputs, whatever it costs.

## What is blocked today, and why

| Class | Blocking requirement | Criterion |
|---|---|---|
| Equities | A certified historical listing (the candidate population), raw prices, and corporate actions with announcement and ex dates | C8.1, C8.2 |
| Indices | Long index-level histories with their basis (price or total return); point-in-time constituents for constituent strategies | C8.1, C8.2 |
| Commodities | Individual futures contracts with multipliers, ticks, last-trade dates, and roll decisions made on information then available | C8.2 |
| Macro and rates | Vintages and actual publication times for each observation, and a certified release calendar with revision history | C8.2 |

The keyless sources (ECB, BIS, CFTC, Treasury Fiscal Data) cover only FX reference-rate signal studies, and even
those lack series dates and announcement times (Blockers).

## Options

### A. Free keys or accounts (no money; each needs a registration in the human's name)

| Option | Unlocks | Gaps that remain | Needs |
|---|---|---|---|
| **FRED + ALFRED API** (St. Louis Fed) | **Macro and rates, C8.2.** ALFRED records each value's real-time period (first release and revisions), so "the latest vintage then available" is answerable for most US macro series. Release dates come from the same API. | Vintages give the release *date*, not the time of day, so C8.2's actual publication time needs a frozen rule or the agencies' release calendars. Third-party-owned series need their owners' permission beyond personal use. | A free API key. The terms bind the key holder. |
| **BLS API v2** | Labor and price series and the BLS release schedule (C8.2 calendar). | Revisions are only partly archived (ALFRED covers the main ones). | A free registration key, or v1 with a contact email in the User-Agent. |
| **BEA API** | NIPA and GDP with release metadata. | Vintages mostly via ALFRED instead. | A free key. |
| **EIA API** | Energy spot prices, inventories (weekly petroleum status), and NYMEX front-month settles as features. | Its futures series are continuous front months, not individual contracts, so commodity PnL under C8.2 stays blocked. | A free key. |
| **SEC EDGAR** | Filing acceptance timestamps (point-in-time fundamentals and corporate-action announcements, C8.2) and company identifiers (C8.1 lifecycle evidence). | No prices. No full historical listing by itself. | No key, but a User-Agent with the human's contact email. |
| **Tiingo free tier** | US end-of-day prices with splits and dividends (C8.2 inputs). | Third-party reports cite 500 unique symbols a month and 1,000 requests a day, too little for a broad universe. Delisted coverage is unconfirmed, so it is not a certified C8.1 population. Personal use only. | A free account and key. |

FRED/ALFRED alone would likely move macro and rates from "FX signal studies only" to a full C8.2 class. It is the
largest unlock per unit of effort, and it costs nothing.

### B. University access (no money; the human's institutional identity)

| Option | Unlocks | Gaps | Needs |
|---|---|---|---|
| **WRDS: CRSP and Compustat** (if available through the human's university) | **Equities and indices, C8.1 and C8.2.** CRSP is survivorship-free, with delisting returns, distributions with declaration and ex dates, and permanent identifiers (PERMNO). Compustat point-in-time fundamentals and index constituents depend on the subscription. | Licensed for academic research. Use outside that, and any later stage 11 use, would need its own terms. Automated access through WRDS's own tools must be checked against its terms. | The human's WRDS account, which is their identity, so it is the human's call. |

This is the strongest equity option, if the institution licenses it and the use fits its terms.

### C. Paid vendors

| Option | Unlocks | Gaps | Cost |
|---|---|---|---|
| **Norgate Data, US Stocks Platinum** | **Equities and indices, C8.1 and C8.2:** delisted securities and historical index constituents (Platinum and Diamond only). | Corporate-action timestamps (announcement versus ex) must be checked against C8.2. Index levels are features only. Data is delivered through its updater software, so automated access must be checked against its terms. | **Confirmed:** USD 630 a year (Platinum), 787.50 a year (Diamond); 6 months 346.50 or 433.13. |
| **Norgate Data, Futures** | **Commodities, C8.2:** 30+ years of individual-contract history and prebuilt continuous contracts. | The roll rule must be ours, using only information then available; continuous series are features only. | Not confirmed (no price on its page; a third-party listing says USD 30 a month, possibly outdated). |
| **Databento (CME Globex and others)** | **Commodities, C8.2:** individual contracts with instrument definitions (multipliers, ticks, expirations) since 2010, via an API. Also US equities. | History starts in 2010 for CME. Corporate-action timing for equities must be checked. | **Usage-based:** from USD 0.50/GB historical (confirmed on its pricing page), with USD 125 of free credits for new accounts. Daily bars for a few hundred contracts likely fit within the credit. A third-party report of USD 4,000 a month for unlimited access is unconfirmed. |
| **Sharadar (via Nasdaq Data Link)** | **Equities, C8.1 and C8.2:** prices and fundamentals including delisted tickers. | Point-in-time handling of revised fundamentals must be checked. | Not confirmed (no current price found). |
| **Tiingo Power** | Wider end-of-day coverage than the free tier. | Delisted coverage unconfirmed, so not a C8.1 population on its own. | Not confirmed (third-party sources say USD 10 or 30 a month). |

## Combinations

| Choice | Classes that could be admitted | Money |
|---|---|---|
| FRED/ALFRED key only | macro and rates (full), plus the ECB FX studies | 0 |
| + EDGAR (email in UA) | adds point-in-time fundamentals and event timestamps as features | 0 |
| + WRDS (CRSP) | equities and indices | 0, if the institution licenses it |
| + Norgate Platinum | equities and indices | USD 630 a year |
| + Databento credits or Norgate Futures | commodities | about USD 0 within the credits, or Norgate's unconfirmed futures price |

Every choice still requires the C8.3 feasibility checks, the class annexes, and the stage 7 exit before any
observation is fetched.

## Not options

- **IMF data:** its terms prohibit automated bulk download without explicit permission. Asking for that permission is the human's call, but the IMF is not needed for any class above.
- **Yahoo Finance and Stooq:** their terms forbid automated access to their pages.
- **Scraping, VPNs or shared keys:** excluded by the hard limits.
