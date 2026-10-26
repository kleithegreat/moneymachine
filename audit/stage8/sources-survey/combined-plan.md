# Stage 8 data sources: combined findings (2026-10-26)

Documentation-only survey: terms, pricing, schemas and catalog metadata. No market observation was fetched or
inspected, and nothing was signed up for. Sources:
- `opus-equities-indices.md` (Opus 5.5, equities and indices)
- `opus-commodities-macro.md` (Opus 5.5, commodities and macro/rates)
- `gpt-partial.txt` (GPT 6.1 Sol, all classes; stopped before its report to save quota; its interim findings
  agree with both Opus reports)

All three files are in this directory. Every claim in them carries its URL. Items marked [unverified] in the
reports remain so.

## Cross-cutting findings

1. **AI-use clauses are the binding constraint, more than price.**
   - CME's January 2026 licence Schedule 5 and notice DS-45 (June 2026) prohibit ML, AI and LLM use, "including
     training models and generating output". Databento's User Agreement §1.5 passes CME's terms through. The CME
     texts were read only through search snippets (cmegroup.com timed out).
   - WRDS forbids loading WRDS data into LLMs except "protected" enterprise no-training instances, so CRSP and
     Compustat are out.
   - Norgate: the LLM provider must gain no independent rights to the data (EULA 2(iv), 8(iii)).
   - Nasdaq's Data AI Policy covers any Nasdaq-originated data.
2. **Deletion on termination:** Norgate, Massive, Tiingo, Sharadar, SimFin, Databento and WRDS require deleting or
   ceasing use of data when the subscription or account ends. The audit record must therefore never depend on
   holding vendor rows.
3. **Corrections to our earlier assumptions:**
   - Cboe's free index histories may not be stored without written consent.
   - Tiingo's free and trial plans forbid persistent storage.
   - Norgate is Windows-only, including its Python package; it needs a Windows VM.
   - Databento's equities history starts in 2018, and its corporate actions in May 2018.
   - The World Bank's commodity page now links the Pink Sheet's monthly and annual bulk workbooks.
4. **Time-critical:** the Federal Reserve Board's Data Download Program (H.15, H.10, G.17, Z.1, policy rates)
   explicitly allows automated download. Its "Build Your Package" tool goes the week of 9 November 2026, before the
   whole program's retirement, after which those series are only on FRED (ruled out).

## Per class

| Class | Best route | Cost | Tier reached | Main gaps |
|---|---|---|---|---|
| Macro and rates | Philadelphia Fed RTDSM (in use); OECD STES revisions (monthly editions since 1999, about 38 countries; terms unread, 403); ECB Real-Time Database and `includeHistory`; BLS and BEA archived releases and schedules (first prints, release times); NY Fed reference rates (terms explicitly allow automated access and storage); Treasury par yield XML feed (from 1990; terms silent); Fed DDP packages (archive now) | USD 0 | Signal study with real vintages; rates as features | Vintage-month granularity for OECD and ECB; actual-release evidence for reschedules comes from archives |
| Commodities | Databento GLBX.MDP3, June 2010 to now: monthly `definition` snapshots, `statistics` (settlements, open interest) and optional `ohlcv-1d` for about 35 roots. Exact cost from the free `metadata.get_cost` call before any pull | about USD 6–25 of the USD 125 credit; about 5 GB; Linux-native | Full backtest on individual contracts, if the CME AI clause is satisfied by the kernel-only boundary below | First notice days hand-encoded from rulebooks; arrival times before 2017-05-21 are synthetic; 16.4 years of history |
| Commodities, fallback | World Bank Pink Sheet (CC BY 4.0) | USD 0 | Benchmark signal study, prospective vintages only | No contracts, no past vintages |
| Equities | Norgate US Stocks Platinum (delisted from 1990, permanent ids, raw prices, splits and dividends) in a Windows VM, plus EDGAR form-type index (Form 25, 8-A12B, 15, 8-K acceptance times) for listing events and announcement times | USD 630/yr plus a Windows licence (unverified) | Full backtest from 1990 | No dividend declaration dates or delisting returns in Norgate; OTC prices after delisting missing |
| Equities, Linux-native alternative | Massive Stocks Advanced (2003+, delisted tickers with an as-of registry, dividends with declaration/ex/record/pay dates, FIGI and CIK) | USD 199/month | Full backtest from 2003 | No index constituents |
| Indices | Norgate's daily index membership (S&P 500 from 1957, Russell from 1990, Nasdaq-100 from 1993) and ETF proxies | in Norgate | Constituent strategies; index strategies through ETFs | Index levels themselves are licence-restricted (S&P, MSCI, FTSE Russell, Cboe, Nasdaq) |

Unusable: WRDS/CRSP (AI policy), LBMA (needs an IBA licence), Nasdaq CHRIS (deprecated), EODHD commodities
(sourced from FRED), Tiingo free (no storage), Cboe and index-provider levels (storage forbidden), Norgate futures
(Windows-only), Massive futures (about 7 years).
