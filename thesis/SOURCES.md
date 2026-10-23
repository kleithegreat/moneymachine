# Retrieval allowlist (stage 10)

The retrieval proxy fetches only from the entries below. Each one has its terms certified (paper §5,
`ingest/terms.py`). A bare host admits the whole host; `host/prefix` admits only that path prefix. Every
other host is refused, and every redirect hop is checked again. robots.txt is still honored.

Human decision of 2026-10-23: certify, at minimum, SEC EDGAR, FRED/ALFRED, BLS, BEA, EIA, Federal Reserve
releases, Treasury, CFTC COT and GDELT. Those not below are not certified yet (PROGRESS.md, Blockers).

## Terms: api.gdeltproject.org

- URL: https://www.gdeltproject.org/about.html
- Retrieved: 2026-10-23
- Basis: permitting clause

> The GDELT Project is an open platform for research and analysis of global society and thus all datasets
> released by the GDELT Project are available for unlimited and unrestricted use for any academic, commercial,
> or governmental use of any kind without fee.

Any use must cite the GDELT Project and link to https://www.gdeltproject.org/.

## Terms: data.gdeltproject.org

- URL: https://www.gdeltproject.org/about.html
- Retrieved: 2026-10-23
- Basis: permitting clause

> all datasets released by the GDELT Project are available for unlimited and unrestricted use for any academic,
> commercial, or governmental use of any kind without fee.

## Terms: api.fiscaldata.treasury.gov

- URL: https://fiscaldata.treasury.gov/api-documentation/
- Retrieved: 2026-10-23
- Basis: official API

> Our API is open, meaning that it does not require a user account or registration for a token. To begin
> using our API, you can type the GET, R, or Python request below directly into a web browser (or script in a
> data analysis tool), which will return a JSON-formatted response.
>
> The data is offered free, without restriction, and available to copy, adapt, redistribute, or otherwise use
> for non-commercial or commercial purposes.

## Terms: publicreporting.cftc.gov

- URL: https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm
- Retrieved: 2026-10-23
- Basis: official API

> Currently, we are not providing tokens to use the Public Reporting APIs. People who are using the API are
> generally using it successfully without using a token. As long as you are not overusing the API, you should be
> able to use the API without a token.

## Terms: www.federalreserve.gov/feeds/

- URL: https://www.federalreserve.gov/feeds/feeds.htm
- Retrieved: 2026-10-23
- Basis: permitting clause

> Users can subscribe to RSS feeds using software such as readers, or aggregators, which display the links,
> headlines, and a brief summary of the feed. [...] You will need to use software that acts as a reader, or
> aggregator, to view the feed.

Only the feeds: the Board's site policy permits copying its public-domain information ("may be copied and
distributed without permission") but says nothing about automated access to its other pages.
