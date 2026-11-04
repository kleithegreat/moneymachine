# Stage 8 exposure ledger (GPT manifest review B1)

Everything derived from stage 8 recordings that a model or a person saw beyond the criteria's integrity list (HTTP
status, sizes, hashes, poll times, parse success), with when, who and what. Append-only. Each class annex places
the affected evidence (search or spent) before it selects anything that evidence could influence.

| When (UTC) | Who | Source | What was seen |
|---|---|---|---|
| 2026-10-26 about 20:50 | this Claude session | Databento GLBX.MDP3 monthly definitions | per-snapshot counts of outright futures (641 to 830 for 2010–2015 snapshots; zero for snapshots on a Saturday), from definition metadata; no symbols, prices or other values |
| 2026-10-23 18:25 (14:25 EDT) | Claude session 9afc784d (main) | ECB EXR, `D.USD.EUR.SP00.A` | Three observation values: USD/EUR reference rates for 2026-10-21, 10-22 and 10-23, printed from an ad hoc `lastNObservations=3&includeHistory=true` CSV fetch into `data/tmp/stage8/meta/exr-hist.csv`. The fetch tested whether past versions exist. |
| 2026-10-23 18:47 (14:47 EDT) | Claude session 9afc784d (main) | ECB EXR, `D.USD.EUR.SP00.A` full history (`includeHistory=true`) | Observation count (7,183) and the fact that the whole history comes back as a single version. Written into the ECB certificate, now `venue/sources.toml` line 175. |
| 2026-10-23 18:50 to 18:52 (14:50 to 14:52 EDT) | Claude session 9afc784d (main) | ECB EXR, all 44 daily series. Full histories fetched with `datalayer.get` as feed `ecb-exr/full` into `data/datalayer/raw/` (script `data/tmp/stage8/ecb-dates.py`) | For every series: first and last observation dates and observation counts. 22 series run 1999-01-04 to 2026-10-23 with 7,183 observations. Shorter counts within a full span reveal missing fixings (ISK 4,776; RON and TRY 7,121). End dates reveal cessations (euro adoptions; RUB 2022-03-01; ARS, DZD, MAD and TWD 2020-10-30). Shown in tool output and in the assistant's summary to the user, then committed to `venue/sources/ecb.md` (7c45b27). Still in `venue/sources.toml` lines 184–208, so any later reader of the registry sees it. |
| 2026-10-23 21:17 (17:17 EDT) | Claude session 9afc784d (main) | Polymarket Gamma API (ad hoc fetch before the recorder feed existed) | Two sample markets. The top active market by 24 h volume: outcome prices, 24 h volume and end date. The most recently closed market: resolved outcome prices, closed time and 24 h volume. |
| 2026-10-24 21:05 (17:05 EDT) | GPT run `~/.cache/mm-gpt/project.XShA` (whole-project review) | ECB EXR | Given `sources.toml` as an attachment. It contains the per-series dates, counts and missing-fixing table from the 18:50 row and the 7,183 count. |
| 2026-10-26 01:25 (21:25 EDT, 10-25) | Claude session 9afc784d (main) | BLS API, CPI-U `CUUR0000SA0` | The first 180 characters of the probe's response body. They show the latest observation's period (2026 M09) but not its value. Minor. |
| 2026-10-26 01:39 (21:39 EDT, 10-25) | Claude session 9be30ecb (main) | FRED `fred/series?series_id=GDP` (API key test) | Series metadata showing `observation_start` 1947-01-01 and `observation_end` 2026-04-01 (realtime 2026-10-21). It is catalog metadata, but it gives first and last observation dates. FRED itself is not recorded (its terms rule it out). Borderline. |
| 2026-10-26 13:44 (09:44 EDT) | Claude session 0a9f8f5e (main) | ECB EXR | Re-read `venue/sources.toml` lines 208–220: TWD's dates and count (2000-01-13 to 2020-10-30, 5,383), the missing-fixing counts (ISK 4,776; RON and TRY 7,121), and the cessation dates. |
| 2026-10-26 18:27 (14:27 EDT) | Claude session 0a9f8f5e (main) | OECD STES revisions (`DSD_STES_REVISIONS@DF_STES_REVISIONS`), every USA series, ad hoc full download (357 MB, deleted at once) | Row count (3,368,634 lines) and the CSV header. No values. |
| 2026-10-26 23:05 (19:05 EDT) | GPT run `~/.cache/mm-gpt/manifest2.SdG9` (second manifest review) | Databento GLBX.MDP3 monthly definitions | Given `exposure.md` as an attachment, including the outright counts from the 20:52 row. |

Compiled 2026-10-26 from every session transcript, its subagents and every GPT run (`~/.cache/mm-gpt/*`, the opencode
store for the one run with web access), by a fresh-context Opus agent. No exposure was found for RTDSM, BEA, EIA, EDGAR,
BIS, CFTC, Treasury, Fed DDP, NY Fed, World Bank, GDELT, NWS or openFDA (statuses, sizes, hashes and documentation
only). Not counted, though a strict reading might: catalog listings (ECB RTD's 556 series keys, the ECB EXR population
of 44 series, BIS's 49 policy-rate areas, OECD codelists). Not compiled here: the stage 10 thesis agents' reads, which
their own ledger records. The ECB series dates and counts were removed from `venue/sources.toml` on 2026-10-26, so the
registry no longer exposes its readers; git history keeps them.

Kernel-only sources (human decision of 2026-10-26): coding sessions default to integrity-only views, and any
accidental disclosure of rows is logged here.
