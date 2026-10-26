# Research brief: free or cheaply accessible data sources for multi-asset research

## Context

A private, non-commercial research project (one US-based individual, a university student) builds an auditable
quant research system. A small trusted kernel backtests strategies written as data, a statistical gate judges
them on untouched holdout periods, and AI research agents (LLMs) search for strategies by reading the stored
data. The next stage moves from crypto perpetuals to underlying assets with long histories: equities, equity
indices, commodities, and macro/rates. Nothing is traded; trading is out of scope.

We need a survey of data sources that are free, or cheap enough to fit a small budget (e.g. vendor free credits
such as Databento's USD 125 sign-up credit), and that are actually sufficient for the research described below.
A source that is free but fails the requirements (e.g. survivorship-biased, too short, terms forbid our use) must
be reported as such, not recommended.

## Hard requirements a source must meet to be useful

1. **Terms of use** must permit: automated, programmatic, read-only access; storing the data locally in a
   database/archive; non-commercial research use; and use by AI/LLM-based research agents that read the stored
   data (no model training). Some providers forbid exactly this. For example, FRED's API terms forbid "storing,
   caching, or archiving" and use "in connection with the development or training of any software program or
   system or machine learning, including ... large language models", so FRED/ALFRED are unusable for us. Quote
   the relevant clauses (with URL) for each recommended source. Silent or ambiguous terms are a risk to flag, not
   permission. Redistribution is not needed (the repository is private).
2. **No workarounds:** no scraping of sites whose terms forbid automation, no VPNs or proxies, no unofficial
   endpoints. Official APIs or documented bulk downloads only.
3. **Accounts and keys are acceptable** (the human will sign up with their own name and email), as are
   free tiers and free credits. Paid options may be listed separately with prices, as alternatives.
4. **Platform:** Linux (NixOS) only, about 100 GB of free disk, 15 GB RAM, ordinary home internet. Windows-only
   software (e.g. a vendor's Windows updater application) is a serious problem; say if a source needs it.
5. **Point-in-time correctness** (the central requirement). The system must know, at each historical decision
   time, exactly what was knowable then:
   - **Equities:** a survivorship-free universe that includes delisted companies (a historical listing registry,
     not just today's tickers); raw unadjusted prices as the execution basis; corporate actions (splits, cash
     dividends, mergers, spin-offs, delisting proceeds/returns) with their announcement, ex/effective and
     payment dates; stable security identifiers across ticker changes. Ideally 15+ years.
   - **Indices:** long index-level histories stating price vs. total return, currency; for constituent
     strategies, point-in-time index membership (who was in the index on each date).
   - **Commodities:** individual futures contracts (not just continuous series), with contract specifications
     (multiplier, tick size, currency, last trade date, delivery constraints), so that rolls can be simulated
     with explicit trades. Daily settlement/OHLCV is enough. Ideally 15+ years. Benchmark spot/monthly
     price series are a weaker fallback (usable only for "signal studies" that predict a named benchmark).
   - **Macro and rates:** data vintages (what each release said when first published, and each revision), actual
     publication timestamps, and a release calendar with revision history. Values must never be backdated.
6. **Size and cost realism:** estimate data volume and, for credit-based vendors, how far the credit goes for a
   concrete useful dataset (e.g. "daily OHLCV plus contract definitions for the 30 most liquid CME futures roots,
   2010 to now, costs about $X of the $125 credit"). Use the vendor's published pricing or cost calculator
   documentation; say when you could not verify a price.

## Already in hand or already ruled out (do not re-research except to correct us)

- **In use:** ECB Data Portal (FX reference rates, yield curves), BIS (policy rates, effective exchange rates),
  CFTC public reporting (commitments of traders), US Treasury Fiscal Data, GDELT, NWS, openFDA, EIA (API and
  bulk), BLS API, BEA API, SEC EDGAR (XBRL company facts and filings), the Philadelphia Fed's Real-Time Data Set
  for Macroeconomists (vintages of GDP, the GDP price index, CPI, payrolls, unemployment), Polymarket,
  Hyperliquid's own API and its S3 archive.
- **Ruled out:** FRED/ALFRED (terms above), IMF (forbids automated bulk download without permission), Yahoo
  Finance and Stooq (terms forbid automated access), World Bank Pink Sheet (file URL not stably linked; open
  question), ClinicalTrials.gov (no automation clause).
- **Under consideration but unverified:** Norgate Data (US stocks with delisted securities, about USD 630 a
  year; we believe its updater is Windows-only, so verify), Databento (USD 125 free credits), Tiingo, Alpha
  Vantage, Nasdaq Data Link, EODHD, Polygon.io/Massive, Alpaca market data, Kenneth French's data library,
  Robert Shiller's data, Cboe's free index histories (VIX etc.), NY Fed reference rates (SOFR, EFFR),
  Treasury.gov daily yield curves, OECD, Eurostat, CME's own free data, LBMA.
- **Institutional access:** the human is a student at a US university, which may give access to WRDS (CRSP,
  Compustat, TAQ, Refinitiv, etc.) or similar. Assess whether typical university/WRDS terms would permit this use
  (local storage, programmatic access, non-commercial research, AI agents reading the data). WRDS and some
  vendors have specific rules about AI tools; find and quote them if they exist.

## Rules for your research

- Use documentation, terms of service, pricing pages, schema and catalog metadata only. Do not download or look
  at any actual price, return or market observation data. This is a hard rule: the project pre-registers its
  data choices before seeing any observations.
- Do not sign up for anything.
- Cite every claim about terms, coverage or price with a URL. Mark anything you could not verify.

## Deliverable

1. For each asset class (equities, indices, commodities, macro/rates), a table of candidate sources:
   name; access (free / free tier / credits / institutional / paid with price); coverage (instruments, start
   year, delisted included?, contracts vs continuous, vintages?); point-in-time features; terms verdict with the
   quoted clause(s) and URL; Linux compatibility; data volume; and a verdict: **sufficient** (meets the
   requirements for that class), **partial** (say exactly what is missing), or **unusable** (say why).
2. A recommended plan: the smallest set of sources (free first, then the cheapest paid additions) that would make
   each class researchable, with total cost, and which tier it reaches (full backtest vs. benchmark-only signal
   study).
3. The key risks and open questions the human would need to resolve (e.g. a terms clause needing a written
   permission request), stated plainly.
