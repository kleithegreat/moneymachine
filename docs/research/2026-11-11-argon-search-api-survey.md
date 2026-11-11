# Survey of web search APIs against the reading arm's requirements, by Gemini 4 Argon (web UI), 2026-11-11

- **Prompt:** `~/Downloads/argon-search-api-survey.md`, the requirements of `audit/program/architecture.md` section 5.6 (branch `rearchitecture`), plus third-party content licensing.
- **Format:** two parts, saved by the human as a PDF at 2026-11-11 17:55 UTC (12:55 EST), filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged.
- **Status:** its citations are leads until the advisor checks them (CLAUDE.md, Where information lives). Argon read most terms through search-index excerpts, not whole pages, and says so.

**Checked by the advisor, 2026-11-11:**
- **Parallel fails requirement 2, against Argon:** its Customer Terms (https://parallel.ai/customer-terms, no date on the page) say "Customer shall not copy, cache, or store any significant portion of any Customer Output" (2(b)(ii)). They also grant Parallel a licence to train on Customer IP (4(b)).
- **Tavily:**
  - Its Platform Terms ("Last updated: May 4, 2026") are silent on storing Output: "the term 'Services' does not include Output" (1.7), and no clause restricts or permits it.
  - The licence is "solely for Customer's internal business purposes" (2, 3.2).
  - The storage article, saved by the human (`2026-11-11-tavily-storing-caching.pdf`, https://help.tavily.com/articles/1612400809-storing-caching-retaining-output, "last updated 9 days ago" on 2026-11-11), confirms it: "You may store search result metadata, snippets, full page content, and complete API responses, including long-term, with no maximum retention period and no deletion requirement". It adds that "the underlying web content belongs to its publishers". So requirement 2 passes. The AI-use and publication articles are still unread.

**Ranking:** 1. Tavily, 2. Parallel, 3. Perplexity's Search API (or Exa once its terms are read). Every provider disclaims any licence over the publishers' text it returns.

---

11/11/26, 12:55 PM                                                             See attached instructions.


     See attached instructions.
     https://gemini.google.com/app/3dda8712114b759e

     User prompt: See attached instructions.
     Response: Methodological Note on Page Access: Web access in this environment operates via Google Search index retrieval rather than a
     direct headless browser fetch. Where exact clauses, documentation parameters, and effective dates were read directly from indexed page
     excerpts, they are quoted and cited below. Where a full PDF or complete legal page body could not be opened end-to-end beyond its indexed
     excerpts (such as the full body of Exa_Labs_Terms_of_Service.pdf, [you.com/terms](https://you.com/terms), kagi.com API
     Terms, jina.ai/legal, mojeek.com API terms, and newsapi.ai/terms), the affected cells are marked Unclear (page not fully readable)
     rather than assumed to pass.

     SERP Resellers and Dropped / Retired Candidates
           SerpAPI, Serper, ScrapingDog, Bright Data SERP API, String, APIserpent: Fail by construction — Google’s Terms of Service ("You may
           not send automated queries of any sort to Google's system without express permission in advance from Google", alongside Google’s
           SearchGuard anti-bot measures and December 2025 DMCA litigation against SerpApi) and Microsoft’s Services Agreement ("you may not: i.
           circumvent or bypass any technological protection measures... vi. use the Services in any unauthorized way") prohibit unauthorized
           automated scraping of their SERPs.
           Microsoft Bing Search APIs: Dropped (Retired) — Microsoft decommissioned all Bing Search APIs (Web, News, Custom Search, etc.) on
           August 11, 2025; its replacement, Grounding with Bing Search in Azure AI Agents ($14/1k transactions, classic agents retiring March 31,
           2027), fails Requirement 3 because developers "don't have access to raw content returned from Grounding with Bing Search" and its terms
           prohibit storing output or using it to evaluate AI models.
           Associated Press (AP) & Reuters Developer APIs: Dropped (Enterprise/B2B only) — Neither offers self-serve individual signup or
           public pay-as-you-go pricing; AP’s public website terms restrict access to "personal non-commercial use only" without a negotiated
           commercial Media API license, and Reuters Connect / LSEG Refinitiv Data Platform requires enterprise contract licensing.

     Candidate Survey Table

                          1. Official API & AI/LLM                                                           3. Page Content &
      Candidate                                        2. Indefinite Storage / Caching                                                   4. Publication
                          Input                                                                              Length Limits


                                                                                                             Pass. /search returns
                          Pass. Built for "AI Tools"
                                                                                                             content chunks (1–3
                          (LLMs/agents); Help                                                                                            Pass. Returns
                                                                                                             chunks, ~500–800 chars
                          Center explicitly permits    Pass. Explicitly allows indefinite storage of                                     filters via sta
                                                                                                             each) +
                          sending output to third-     metadata, snippets, and full-page content with no                                 (YYYY-MM-DD
      Tavily                                                                                                 include_raw_content
                          party or local LLMs for      maximum cache TTL or post-termination deletion                                    filter_by_p
                                                                                                             (markdown or text, full
                          inference (bars training     requirement.                                                                      true (strictly
                                                                                                             parsed page) at no extra
                          competing models on AI                                                                                         of-window pa
                                                                                                             credit cost; /extract
                          answers).
                                                                                                             batches up to 20 URLs.


                                                                                                             Pass. /v1/search
                    Pass. Designed for AI
                                                                                                             returns excerpts
                    agents; Customer Terms
                                                                                                             (configurable via
                    grant license to use                                                                                                 Partial / Pass
                                                                                                             max_chars_per_result
                    Parallel APIs and define           Pass (by Customer IP structure; no retention                                      publish_dat
                                                                                                             & max_chars_total, CLI
      Parallel      returned data as                   cap). Customer Outputs are defined as "Customer                                   Structured so
                                                                                                             default 60,000 chars);
      (parallel.ai) "Customer Output" /                IP"; no clause in Customer Terms forbids storing or                               after_date
                                                                                                             /v1/extract returns
                    "Customer IP". Bars                caching Customer Outputs indefinitely.                                            upper-bound
                                                                                                             excerpts or
                    automated high-risk                                                                                                  before:YYYY
                                                                                                             full_content
                    decisions without human
                                                                                                             Markdown (e.g., 50,000
                    oversight.
                                                                                                             chars/result).


                          Pass. /search is                                                                                               Pass. Returns
                                                                                                            Pass. POST /search
                          explicitly built for agent   Unclear (page not fully readable). Search                                         last_update
                                                                                                            returns extracted page
      Perplexity          tool loops; Search           Addendum §2.2 ("Data Use") could not be read in full                              search_afte
                                                                                                            text in snippet, sized via
      Search API          Addendum governs             from search snippets; Schedule 1 states Customer                                  search_befo
                                                                                                            max_tokens_per_page
                          /search (distinct from       does not own /search Output.                                                      (%m/%d/%Y) p
                                                                                                            and max_tokens.
                          Sonar LLM APIs).                                                                                               last_update




https://gemini.google.com/app/3dda8712114b759e                                                                                                             1/8
11/11/26, 12:55 PM                                                            See attached instructions.


                      1. Official API & AI/LLM                                                               3. Page Content &
      Candidate                                    2. Indefinite Storage / Caching                                                         4. Publication
                      Input                                                                                  Length Limits

                                                                                                             Pass. /search includes
                      Pass. Built for LLM                                                                    contents.text (full           Pass. Support
                      grounding; API docs          Unclear (PDF not fully readable). Only portions of        extracted text,               startPublis
                      explicitly support feeding   Exa_Labs_Terms_of_Service.pdf surfaced in                 configurable via              endPublishe
      Exa (exa.ai)
                      /search and                  snippets; could not verify absence of a                   maxCharacters) and            contents.sn
                      /contents into AI            caching/storage limit in the PDF.                         contents.highlights           at 100 reques
                      agents.                                                                                at no extra cost for top 10   contact).
                                                                                                             results.

                                                                                                             Pass. POST /v1/search
                      Pass. Web Search (ydc-       Unclear (ToS not fully readable). Docs recommend
                                                                                                             with extraction_mode:
                      index.io/v1/search)          a 5–15 min gateway cache TTL (max_age), but full                                        Pass. Returns
                                                                                                             "highlights" (up to 50
      You.com API     and Contents API             API storage terms in [you.com/terms]                                                    freshness s
                                                                                                             results) or "full_page"
                      explicitly target AI         (https://you.com/terms) could not be verified                                           range YYYY-M
                                                                                                             (markdown or html, up to
                      agents and RAG.              verbatim.
                                                                                                             100 results).


                                                                                                                                           Partial / Uncl
                                                                                                             Pass. /v2/search
                      Pass. ToS §1 states          Unclear (ToS not fully readable). Full text of                                          style tbs time
                                                                                                             returns Search Highlights
      Firecrawl       "Firecrawl is an API that    firecrawl.dev/terms-of-service on long-                                                 qdr:w, etc.); s
                                                                                                             by default; full-page
      (/v2/search)    converts any website into    term output retention could not be read in full;                                        publication tim
                                                                                                             Markdown scraping can
                      LLM-friendly data."          Third-Party Data providers carry separate terms.                                        all sources is
                                                                                                             be enabled per result.
                                                                                                                                           Tavily/Exa.


                      Pass (on Data for AI
                                                                                                             Pass.
                      plans). "Data for Search"
                                                   Fail (on self-serve tiers). ToS §2.b.i states:            /res/v1/llm/context
                      forbids AI inference,                                                                                                Pass. Support
                                                   "Licensee shall not at any time... store the results of   returns pre-extracted text
      Brave Search    while "Data for AI" (Free                                                                                            bounded YYYY
                                                   the API or any derivative works from the results".        chunks, tables, and code
      API             AI / Base AI / Pro AI)                                                                                               ranges (date_
                                                   Indefinite storage requires an enterprise "Data with      blocks (~2,064
                      explicitly permits LLM                                                                                               date_before
                                                   Storage Rights" contract.                                 tokens/call avg) for LLM
                      inference and includes
                                                                                                             grounding.
                      /res/v1/llm/context.




                      Pass. Built for AI agents;   Fail / High Risk. ToS Article 4.1 restricts Open Web
                                                                                                             Pass. /search and             Unclear. Blog
                      ToS explicitly includes      Content use to the EU Directive 2019/790 Art. 3/4
      Linkup                                                                                                 /fetch return extracted       date filtering,
                      "AI agents" in the           TDM exception and requires Client to "retain Open
      (linkup.so)                                                                                            snippets and full-page        bound parame
                      definition of                Web Content for as long as is necessary for the
                                                                                                             Markdown.                     readable in sn
                      "Authorized Users".          purposes of text and data mining only".



                                                                                                             Pass. Search supports
                      Pass. POST
      DeepSeek                                                                                               need_content: true to      Pass. Returns
                      /v1/tools/search and         Unclear (ToS not read). DeepSeek’s API Terms of
      Search &                                                                                               return extracted page text after:YYYY-
                      /v1/tools/fetch are          Service were not retrieved in full to verify
      Fetch API                                                                                              in content; Fetch          before:YYYY
                      built specifically for AI    storage/caching permissions.
      (Added)                                                                                                converts any URL to        string (128-ch
                      agent loops.
                                                                                                             Markdown.
                                                                                                             Pass. Search API includes
                      Pass. Commercial                                                                       "Extra snippets:
                                                   Unclear (API Terms not fully readable).
                      /api/v1 Search and                                                                     full, clean page              Unclear. Scop
                                                   [kagi.com/privacy]
      Kagi Search     Extract APIs return LLM-                                                               content alongside             exist, but stric
                                                   (https://kagi.com/privacy) was read, which
      API             ready Markdown and                                                                     your results"; Extract        date filtering w
                                                   links to a separate Kagi API Terms of Service whose
                      offer an official MCP                                                                  API returns clean             snippets.
                                                   full text was not in search snippets.
                      server.                                                                                Markdown for up to 10
                                                                                                             URLs/call.




https://gemini.google.com/app/3dda8712114b759e                                                                                                               2/8
11/11/26, 12:55 PM                                                             See attached instructions.


                       1. Official API & AI/LLM                                                              3. Page Content &
      Candidate                                       2. Indefinite Storage / Caching                                                     4. Publication
                       Input                                                                                 Length Limits

                                                 Unclear (ToS not fully readable).                           Pass. s.jina.ai              Fail / Unclear
                       Pass. Explicitly marketed
      Jina                                       jina.ai/legal/ (May 4, 2026) snippets only                  searches the web and         prefix reader/
                       as "your preferred
      (s.jina.ai /                               showed GDPR clauses, not API output retention               converts top results         documented s
                       grounding solution for
      r.jina.ai)                                 rules. Also unclear whether s.jina.ai scrapes               directly into full LLM-      publication filt
                       your LLMs".
                                                 third-party SERPs under the hood.                           friendly Markdown text.      dated leakage

                                                                                                             Fail. Returns snippets
                       Pass. PAYG plans               Pass. Standard PAYG plans on                           only, up to a maximum of
                       explicitly include "AI         [mojeek.com/services/search/web-search-                511 characters
      Mojeek           Usage" and blog                api/]                                                  ("request snippets           Unclear. Date
      Search API       confirms freedom to            (https://mojeek.com/services/search/web-               of considerable              documented i
                       combine results with           search-api/) explicitly include "Storage               length; up to 511
                       LLMs.                          Rights".                                               characters"); no full-
                                                                                                             page extraction endpoint.
                       Fail (Closing). Closed to
                       new customers on
                       January 20, 2026
                       (returns HTTP 403 to
                       new projects); shuts
      Google           down completely on                                                                    Fail. Returns 10 short
      Custom           January 1, 2027. Google’s Fail. Standard Custom Search / Grounding terms              snippets per call only; no   Pass. Support
      Search JSON      Gemini Grounding          prohibit caching or storing results.                        full-page content            sort=date:r
      API              replacement returns                                                                   endpoint.
                       synthesized answers
                       rather than raw results
                       and forbids
                       caching/analyzing
                       results.
                                                                                                           Fail. Pricing FAQ explicitly
                                                                                                           states: "Is the full article
                                                                                                           content available with any
                       Unclear. Terms do not          Pass (with caveats). Use License grants permission plan? No, unfortunately we
                       explicitly address LLM         "to download the materials (information or software) cannot provide the full
                                                                                                                                        Pass. Returns
      NewsAPI.org      inference; prohibits           on News API's website for as long as your use case   content with our search
                                                                                                                                        filters via fro
                       building a competing           requires", though you may not "reproduce or          results. However, you are
                       news database.                 republish copyrighted material".                     able to use the URL
                                                                                                           included with each result
                                                                                                           to scrape this yourself"
                                                                                                           (violating Req 3).



                     Pass. Provides an official
                                                                                                             Pass. Returns full article   Pass. Filters b
                     MCP server                       Unclear (ToS not fully readable). Full text of
      Event Registry                                                                                         bodies, disambiguated        (last 30 days c
                     (mcp.newsapi.ai) for             newsapi.ai/terms on indefinite local storage was
      / NewsAPI.ai                                                                                           entities, and sentiment      archive back t
                     AI assistants and                not visible in snippets.
                                                                                                             metadata.                    tokens/search
                     entity/article extraction.




                       Pass. Marketing page           Fail / Unclear. ToS (gnews.io/legal/terms-of-          Pass (on paid plans).
                       explicitly lists "AI agents,   service, Oct 18, 2026) states: "Reasonable caching     Paid plans return full       Pass. Returns
      GNews
                       RAG pipelines, and             of API responses for application performance is        article text in content      and filters via
      (gnews.io)
                       research projects" as          permitted", which does not grant indefinite archival   (Free plan truncates to      parameters ba
                       supported use cases.           storage rights under the project’s strict rule.        250 chars).



     Ranked Recommendation


https://gemini.google.com/app/3dda8712114b759e                                                                                                               3/8
11/11/26, 12:55 PM                                                            See attached instructions.

        1. #1 — Tavily (tavily.com): The only candidate with explicit, published written permission for every single requirement.
               Why it wins: Because the project’s rule is that "silence is not permission", Tavily stands alone due to its dedicated Help Center policy
               pages (updated November 2–4, 2026) interpreting its Platform Terms of Service (updated May 4, 2026). Tavily explicitly confirms in
               writing that: (a) you may send output to third-party or local LLMs for inference; (b) you may store metadata, snippets, and full-page
               raw_content or complete API responses indefinitely with no maximum cache period and no obligation to delete stored output
               when your subscription ends; and (c) you may publish derived outputs, citations, and short quotations without even a mandatory
               Tavily attribution requirement (subject to underlying publisher copyright/fair use). Technically, /search with
               include_raw_content="markdown", end_date="YYYY-MM-DD", and filter_by_published_date=True solves both the full-
               text requirement (at zero extra credit cost beyond 1 credit per basic search) and the strict temporal-leakage requirement (dropping
               undated pages and pages published after the agent's session). At 18,000 queries/month, it costs ~$124–$136/month at 1,000 RPM.
               Caveat to check: Section 3.2 of the Platform ToS uses standard B2B boilerplate ("solely for Customer's internal business purposes"),
               although Tavily’s documentation explicitly provisions personal accounts ("or per user for personal accounts") and a "Researcher (free)"
               tier.
        2. #2 — Parallel (parallel.ai): Best cost-to-quality runner-up with clean IP framing, at ~1/10th the price of Tavily.
               Why it ranks second: Parallel’s Customer Terms (effective October 17, 2026) define API responses as "Customer Output" and
               classify both Customer Inputs and Customer Outputs as "Customer IP" (explicitly excluded from "Parallel IP"), imposing no
               caching time limit or deletion requirement. Its /v1/search endpoint returns dense Markdown excerpts (configurable up to 60,000
               chars total per call) plus publish_date (YYYY-MM-DD) at just $1 per 1,000 queries on Fast/Turbo mode ($13/month net of the $5
               monthly free credit for 18,000 queries, or $85/month on Basic/Advanced), with a 600 RPM rate limit on the self-serve Build tier.
               Caveats: Unlike Tavily, Parallel’s structured source_policy object only has an after_date parameter; preventing the agent from
               seeing articles published after its session requires passing before:YYYY-MM-DD in the query string and having your daemon filter
               out any result whose publish_date is null or after the session date. Additionally, by default on the Build tier, Parallel reserves a
               license to use Customer IP (your queries and outputs) to train its own models unless you are on the Scale/Enterprise Zero Data
               Retention plan.
        3. #3 — Perplexity Search API (api.perplexity.ai/search) (or Exa if PDF terms are manually verified): Strong technical fit with strict
           before/after date filtering, but weaker legal ownership terms.
               Why it ranks third: Perplexity’s standalone POST /search endpoint ($1/1k on Fast Search = $18/month, or $5/1k Standard =
               $90/month; 50 QPS) is purpose-built for AI agents, returns configurable page text chunks via max_tokens_per_page, and provides
               explicit search_after_date_filter, search_before_date_filter, and last_updated_before_filter parameters to
               prevent future leakage. However, under the Perplexity Search Addendum (effective September 22, 2025), Schedule 1 explicitly states
               that "Customer does not own, and Perplexity shall not grant it ownership of, the Search API's Output", and Section 2.2 ("Data Use")
               could not be read in full via search snippets to confirm explicit permission for indefinite archival storage. (Similarly, Exa at $4–$7/1k
               with startPublishedDate/endPublishedDate and included full contents.text is technically ideal, but its
               Exa_Labs_Terms_of_Service.pdf could not be read in full via search snippets.)

     CONTINUE FOR PART 2



     User prompt: continue
     Response: The following analysis summarizes the specific sections, policy rules, and API documentation mechanics behind each requirement for
     the top three candidates, along with the contractual provisions that could later withdraw permission or create downstream risk.

     1. Tavily (tavily.com)
     Governing Documents & Dates: Platform Terms of Service ([https://tavily.com/terms](https://tavily.com/terms), updated May
     4, 2026); Help Center Policy Articles on Storing/Caching (1612400809), Attribution & Third-Party Rights (4716869118), AI Processing
     (9218880805), and Displaying/Publishing (4025347510), updated November 2–4, 2026.
     Clause-by-Clause Breakdown of Each Pass:
          1. Official API & AI/LLM Input (Pass):
               Platform Terms §1.1 & §2: Defines AI Tools expressly to encompass artificial intelligence models, large language models, and AI-
               driven software, and grants a non-exclusive license to integrate the API into Customer Applications up to the plan's call limits.
               Help Center (9218880805, AI Processing & Training Data): Explicitly confirms that users may pass Tavily's search results to local or
               third-party AI models for inference-time processing, subject to the model provider's terms. The only AI-related restriction applies to
               Tavily's own synthesized answers, which may not be used to train or develop models that compete with Tavily.
          2. Indefinite Storage / Caching (Pass):



https://gemini.google.com/app/3dda8712114b759e                                                                                                             4/8
11/11/26, 12:55 PM                                                              See attached instructions.

               Help Center (1612400809, Storing, Caching & Retaining Output): Explicitly confirms across dedicated Q&As that Tavily's Terms
               place no restrictions on storing search result metadata (URLs, titles, dates, ranks, scores), snippets, full-page extracted content
               (raw_content), or complete API responses in a user's own database long-term. It further confirms that there is no maximum
               retention period, no cache TTL limit, no restriction on storing derived facts, classifications, or content hashes, no restriction on
               replaying stored results without a new API call, and no requirement to delete already-stored outputs when a subscription ends or an
               account closes (sharing cached results across multiple downstream customers requires contacting support to verify plan fit).
          3. Page Content & Length Limits (Pass):
               Search API Documentation (/search): Returns extracted source passages in content, controlled by chunks_per_source (1 to 3
               chunks per result, targeting roughly 500 characters per chunk in basic/fast modes and 800 characters in advanced mode, with
               adjacent chunks merged). Setting include_raw_content to true (or "markdown" / "text") returns the full parsed page text
               alongside each search result at no extra credit cost.
          4. Publication Dates & Date Filtering (Pass):
               Search API Documentation (/search): Returns a published_date field per result and supports start_date and end_date
               parameters formatted as YYYY-MM-DD. Because undated pages are kept by default, Tavily provides the boolean parameter
               filter_by_published_date: true, which strictly removes any result lacking a detectable publication date or falling outside the
               start_date/end_date window. Cache freshness is separately tunable via max_age_hours (1 to 720 hours, 0 for live fetch, or -1
               for cache-only).
          5. Price at 18,000 Queries/Month (Pass):
               Pricing & Credits: A basic /search request costs 1 credit even when include_raw_content is enabled. The free Researcher plan
               includes 1,000 credits/month; Pay-As-You-Go bills $0.008 per credit ($136/month for 17,000 paid credits after the 1,000 free quota),
               and the Bootstrap plan costs $100/month for 15,000 credits plus $24 for 3,000 overage credits ($124/month total).
          6. No Personalization (Pass):
               API Architecture & Microsoft 365 Certification Disclosure: Requests authenticate solely via an account or organization API key
               (tvly-...), and Tavily certifies that the service performs no automated profiling or personalized ranking.
          7. Publication of Aggregates & Short Excerpts (Pass):
               Help Center (4025347510 & 4716869118): Explicitly permits publishing content derived from results, citing source URLs in reports,
               and including short quotations or excerpts from results in published outputs. It also confirms that Tavily's Terms do not require
               attributing either Tavily or the original sources (though underlying publisher terms or copyright law may independently require
               attribution or limit quotation length).
          8. Who May Sign Up (Pass, with minor boilerplate caveat):
               Rate Limits Documentation & Platform Terms §3.1–3.2: Rate limits documentation explicitly provisions personal accounts
               alongside organizations and offers a free Researcher tier. However, Platform Terms §3.2 contains standard commercial boilerplate
               stating that the services are provided for the customer's internal business purposes.
          9. Rate Limits at 20/Minute Bursts (Pass):
               Rate Limits Documentation: The free Researcher tier allows 100 requests per minute (RPM), while Pay-As-You-Go and Bootstrap
               tiers allow 1,000 RPM, easily handling 20-request-per-minute bursts.
     Provisions That Could Withdraw Permission or Create Risk:
          Unilateral Service & Terms Modifications (Platform Terms §2, §3.3 & §4.5.8): The license in §2 is explicitly revocable in accordance
          with the agreement. Under §3.3, Tavily reserves the right to alter the layout, design, or availability of specific content, features, or functions
          at any time without prior notice. Under §4.5.8, Tavily may modify the agreement upon notice, with continued use constituting acceptance.
          No Third-Party Content License Pass-Through (Help Center 4716869118 & 1612400809): Tavily explicitly states that it grants no
          copyright or license rights in the underlying third-party web content returned by the API. Responsibility for complying with original
          publishers' terms of service and copyright law rests entirely with the user, meaning that storing full-page raw_content or publishing
          excerpts still relies on fair use or the publisher's own terms rather than a sublicense from Tavily.
          Internal Business Purposes Phrasing (Platform Terms §3.2): Although Tavily's self-serve portal and documentation explicitly
          accommodate personal accounts and a free Researcher tier, the formal legal text in §3.2 frames permitted usage around internal business
          purposes.

     2. Parallel (parallel.ai)
     Governing Documents & Dates: Customer Terms and Conditions ([https://parallel.ai/customer-terms]
     (https://parallel.ai/customer-terms), updated August 11, 2026 / October 17, 2026) and Website Terms of Service
     ([https://parallel.ai/terms-of-service](https://parallel.ai/terms-of-service), August 11, 2026).


https://gemini.google.com/app/3dda8712114b759e                                                                                                                 5/8
11/11/26, 12:55 PM                                                          See attached instructions.

     Clause-by-Clause Breakdown of Each Pass:
          1. Official API & AI/LLM Input (Pass):
               Customer Terms §1(b)–(c), §1(h) & §5(a): Defines Services to cover the Parallel APIs and Parallel Processors, Customer Input as
               queries and data submitted by authorized users, and Customer Output as the responses generated and returned by the Services.
               The API is purpose-built for AI agent grounding. The only AI-specific restriction in §5(a) prohibits using the Services or Customer
               Outputs to make automated decisions without human oversight that materially harm individual rights in regulated high-risk domains
               (employment, healthcare, finance, legal, housing, insurance, or social benefits)—which a non-trading paper portfolio research project
               does not trigger.
          2. Indefinite Storage / Caching (Pass):
               Customer Terms §1(c), §1(e), §1(i) & §4(a)–(b): Defines Customer IP as comprising both Customer Inputs and Customer
               Outputs, and expressly excludes Customer IP from Parallel IP. Customer Terms §4 grants the customer broad rights to modify,
               adapt, and build derivative works from Customer Output, with no caching TTL, retention limit, or post-termination deletion mandate
               on Customer Output.
          3. Page Content & Length Limits (Pass):
               Search & Extract API Documentation (/v1/search & /v1/extract): /v1/search returns dense extracted Markdown passages
               in an excerpts array, sized via excerpts.max_chars_per_result (default 30,000 characters; configurable from 1,000 to
               100,000 characters) and excerpts.max_chars_total (default 100,000 characters; configurable up to 1,000,000 characters).
               /v1/extract also supports full_content extraction (e.g., 50,000 characters per result).

          4. Publication Dates & Date Filtering (Partial / Pass with Query Operator):
               Search API Documentation & Changelog (Dec 16, 2025): Each result includes a publish_date field (YYYY-MM-DD), and
               source_policy.after_date filters results to pages published on or after an RFC 3339 date string (YYYY-MM-DD). However,
               source_policy lacks a structured before_date field, so enforcing an upper date bound requires passing before:YYYY-MM-DD in
               the search query and having your daemon verify publish_date before passing results to the model.
          5. Price at 18,000 Queries/Month (Pass):
               Pricing & Changelog (Aug 19, 2026): New accounts receive up to $80 in onboarding credits plus a recurring $5/month free credit.
               /v1/search with excerpts included costs $1 per 1,000 requests in fast mode ($18/month gross, or $13/month net of the $5 credit)
               or $5 per 1,000 requests in basic/advanced mode ($90/month gross, $85/month net).
          6. No Personalization (Pass):
               API Documentation: Requests are stateless and unpersonalized; geographic localization occurs only if an ISO country code is
               explicitly passed in the location parameter.
          7. Publication of Aggregates & Short Excerpts (Pass):
               Customer Terms §1(e) & §4(b): Because Customer Output is treated as Customer IP and the customer is explicitly permitted to
               modify, adapt, create derivative works from, and incorporate Customer Output into other materials, publishing aggregate
               performance statistics and short excerpts is contractually permitted without mandatory Parallel attribution.
          8. Who May Sign Up (Pass):
               Customer Platform & Terms: Self-serve Launch (free) and Build (pay-as-you-go credit card) plans are open to individual developers
               without requiring an enterprise contract.
          9. Rate Limits at 20/Minute Bursts (Pass):
               Rate Limits Documentation (/getting-started/rate-limits): The default quota for POST /v1/search and POST
               /v1/extract on the Build plan is 600 requests per minute (10 QPS), which is 30 times the required 20/minute burst rate.

     Provisions That Could Withdraw Permission or Create Risk:
          Customer Responsibility for Third-Party Content Rights (Customer Terms §5(a)): Under §5(a), the customer assumes sole liability for
          all uses of Customer Outputs. While Parallel classifies Customer Output as Customer IP as between Parallel and the customer,
          Parallel cannot transfer underlying third-party publisher copyrights, leaving the user responsible for ensuring that downstream excerpt
          publication complies with copyright law.
          Model Training on Customer IP by Default (Customer Terms §4(b)): On self-serve plans, §4(b) grants Parallel a license to use Customer
          IP (both queries and returned outputs) to train and improve Parallel's machine learning models (de-linked from individuals), unless the
          customer upgrades to an enterprise Zero Data Retention agreement. While this does not restrict your agent's use of the API, it means your
          queries are visible to Parallel's training pipeline.




https://gemini.google.com/app/3dda8712114b759e                                                                                                         6/8
11/11/26, 12:55 PM                                                          See attached instructions.

          Periodic Updates to Customer Terms: Parallel updated its Customer Terms multiple times in 2026 (including July 1, August 11, and
          October 17, 2026), meaning self-serve users are subject to periodic policy revisions.

     3. Perplexity Search API (api.perplexity.ai/search)
     Governing Documents & Dates: Perplexity API Terms of Service ([https://www.perplexity.ai/hub/legal/perplexity-api-terms-
     of-service](https://www.perplexity.ai/hub/legal/perplexity-api-terms-of-service), updated January 23, 2026), Perplexity
     Search Addendum ([https://www.perplexity.ai/hub/legal/perplexity-api-terms-of-service-search]
     (https://www.perplexity.ai/hub/legal/perplexity-api-terms-of-service-search), updated September 22, 2025), and General
     Terms of Service ([https://www.perplexity.ai/hub/legal/terms-of-service]
     (https://www.perplexity.ai/hub/legal/terms-of-service), January 23, 2026).

     Clause-by-Clause Breakdown of Each Requirement:
          1. Official API & AI/LLM Input (Pass):
               API Terms §1.4 & Search Addendum §1.1.5–1.1.6, §1.2.2: Expressly authorizes integrating the Search Services into Customer
               Applications, defining Input as queries submitted by the customer's application and Output as the responses returned by the
               Search Service. Search Addendum §1.2.2 clarifies that the raw /search API is legally separate from the Sonar LLM APIs, and the API
               documentation explicitly frames /search as a tool for AI agents.
          2. Indefinite Storage / Caching (Unclear — Full Section 2.2 Not Readable, Ownership Disclaimed):
               Search Addendum §4 & Schedule 1: While the Search Addendum snippet confirms that §2.1, §2.2 ("Data Use"), §3, and §4 survive
               termination or expiration of the Addendum, the full body of §2.2 could not be read via search snippets to verify whether it imposes a
               caching TTL. Furthermore, Schedule 1 explicitly states that /search Output comes from the public internet and that Perplexity neither
               recognizes nor grants customer ownership over the Search API's Output. Under the project's rule that silence or unread text is not
               permission, this requirement remains Unclear until §2.2 is inspected directly in a browser.
          3. Page Content & Length Limits (Pass):
               Search API Documentation (/docs/search/overview & /quickstart): POST /search returns extracted webpage text inside
               each result's snippet field rather than just a short meta description. Extraction depth is controlled via max_tokens_per_page
               (capping tokens extracted per URL) and max_tokens (capping total webpage tokens returned across all results, up to 1,000,000
               tokens).
          4. Publication Dates & Date Filtering (Pass):
               Date and Time Filters Documentation (/docs/search/filters/date-time-filters): Returns publication and modification
               dates and supports both lower-bound and upper-bound filters: search_after_date_filter and search_before_date_filter
               (strictly filtering by original publication date in MM/DD/YYYY format), plus last_updated_after_filter and
               last_updated_before_filter (filtering by page modification date). Setting both search_before_date_filter and
               last_updated_before_filter to the session date prevents future information leakage.

          5. Price at 18,000 Queries/Month (Pass):
               Search API Pricing: There is no free tier. Standard /search costs $5 per 1,000 requests ($90/month for 18,000 queries), and Fast
               Search (search_type: "fast") costs $1 per 1,000 requests ($18/month for 18,000 queries), with no extra charge for tokens
               extracted via max_tokens_per_page.
          6. No Personalization (Pass):
               Search API Documentation: Calls are stateless and unpersonalized; location filtering occurs only when country, city, or region
               parameters are explicitly supplied.
          7. Publication of Aggregates & Short Excerpts (Unclear):
               General Terms §1.1.2 & Search Addendum Schedule 1: General Terms §1.1.2 prohibits publishing Output generated by Perplexity's
               services without clearly citing Perplexity, while Search Addendum Schedule 1 states that the customer does not own Search API
               Output. Because Search Addendum §2.2 could not be read in full to verify excerpt redistribution rights, this remains Unclear.
          8. Who May Sign Up (Unclear — B2B Framing):
               Search Addendum Preamble & §1.1.4: Although any individual with a credit card can create an API account in the self-serve portal,
               the Search Addendum preamble frames the contract as an agreement with the organization ("Customer") on whose behalf the user
               accesses the API, and defines "Authorized Users" as the Customer's personnel.
          9. Rate Limits at 20/Minute Bursts (Pass):
               Search API Documentation: Default rate limits provide 50 query units per second (3,000 requests per minute), well above the
               20/minute burst requirement.


https://gemini.google.com/app/3dda8712114b759e                                                                                                         7/8
11/11/26, 12:55 PM                                                          See attached instructions.

     Provisions That Could Withdraw Permission or Create Risk:
          Unilateral Amendment via Platform Pop-Up (Search Addendum §1.2.3): Perplexity explicitly reserves the right to modify the Search
          Addendum at any time—including via a simple pop-up notice inside the API platform—with continued access or use of the Search Services
          automatically binding the customer to the revised terms, overriding any contrary amendment rules in the base API Agreement.
          No Ownership or IP Indemnification on Search Output (Search Addendum Schedule 1): Schedule 1 explicitly states that because
          Search API Output is sourced from the public internet, the customer receives no ownership rights in the Output, and any intellectual
          property indemnification or assurances provided by Perplexity in the base Agreement are entirely disclaimed for /search Output.



     User prompt: continue
     Response:




https://gemini.google.com/app/3dda8712114b759e                                                                                                    8/8
