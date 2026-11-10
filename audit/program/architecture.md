# The research architecture, re-derived

Written 2026-11-10 21:04 UTC (16:04 EST) by Claude Fable 5.2 (`claude-fable-5-2`), session "architect: rearchitecture", on branch `rearchitecture`, cut from `main` at `1c6585e`. It is a design awaiting adversarial review (GPT, Argon); nothing here is decided until the advisor logs it in `audit/decisions.md`.

**Read:** `CLAUDE.md`, `PROGRESS.md`; the human's first session (`ctx` leaf 0); the paper's sections 1, 2, 8 to 17 and appendices S, D, T and O; my meta review of 2026-11-09 and the human's acceptance of it (`audit/decisions.md`, 2026-11-09 20:34 UTC (15:34 EST)) and the entry of 2026-11-10 03:10 UTC (2026-11-09 22:10 EST); `docs/future-work.md`; `thesis/brief.md`, `thesis/SCORING.md`; `venue/sources.toml` (every host; the Hyperliquid and Polymarket certificates in full) and the Polymarket feeds in `venue/sources/datalayer.json`; PC1 to PC6 on `positive-controls` at `8c7b7fa`. **Not read:** GPT's meta review again (I rely on my section 7), most of `audit/`, any code beyond four greps, anything under `data/`. **Run:** one script (the wall table and the exact operating characteristics in section 6); no model, cluster or campaign. **Web:** four searches; what they returned is marked *lead* and is unchecked against the papers themselves. Citations given from memory are marked *lead* too.

**Blind:** sections 1 to 9 were committed before I opened anything on `thesis-split`. One leak: `PROGRESS.md`, which every session reads first, summarizes that design in one line ("week unit, 4 theses a day, C10.7 paired Brier protocol, identity split, lazy acquisition, 14-step build plan"). Section 10 was added afterwards.

## 1. What the aim asks

The human's aim: use frontier agents' search and synthesis to find and test retail trading strategies and theses, rapidly and honestly, with statistics as the empirical standard and formalism as a means. It holds three questions, each needing the one before:

- **Q1, capability.** When an edge exists, do agents find it more often than cheap search at the same budget?
- **Q2, information.** Does an agent's reading change its forecasts for the better?
- **Q3, edge.** Does anything an agent proposes earn a positive expected net return?

"Rapidly and honestly" then means: each question gets a pre-registered test whose power is stated, in the least calendar time that arithmetic allows. A study is worth building only if its answer, either way, arrives while it can still change what the project does.

## 2. The binding constraint

### 2.1 One identity, three forms

A claim tested on `n` independent observations, each with standardized effect `d` (mean over standard deviation), has evidence `z = d·√n`. A one-sided 5% test with 80% power needs `z* = 1.645 + 0.842 = 2.49`, so

    n = 6.18 / d²        d = 0.05 → 2,473    0.06 → 1,717    0.1 → 618    0.2 → 155    0.3 → 69

- **Return series.** For a strategy of annualized Sharpe `S` held `T` years, `z = S·√T`. The decision frequency cancels: more periods a year mean a smaller per-period effect. So `T = 6.18 / S²` years: 24.7 at `S` = 0.5, 6.2 at 1, 2.75 at 1.5, 1.55 at 2, 0.69 (8.2 months) at 3, 0.25 (3 months) at 5. Even odds (`z` = 1.645) need 2.7 years at `S` = 1.
- **Bets.** Grinold's law `S = IC·√BR` is the same identity with `d = IC` and `n = BR·T`: skill per independent bet times the root of independent bets.
- **Rate.** Define a design's information rate as `I = d² · n_eff` per month, the `z²` it earns monthly at a stated effect. Months to 80% power are `6.18 / I`. Section 3 compares designs on `I`.

This is the minimum track record length of Bailey and López de Prado (2012) and the fundamental law of Grinold (1989); nothing here is new, and no test changes it. A cleverer test moves the constant 6.18 by tens of percent. Only `d` and `n` move the answer.

### 2.2 The cutoff makes T small for a frontier model

A model's proposals are selected on everything it read before its knowledge cutoff `c`: prices, and a literature that was itself fitted to those prices (published anomalies lose roughly half their return out of sample and after publication; McLean and Pontiff 2016, *lead*). That is an unlogged search over history up to `c`, which no null market can detect. Only data after `c` plus a margin `m` can judge what the model proposes (the human, 2026-10-23; `audit/criteria.md`, stage 3). So the judged span is `T = now − c − m`.

A frontier model is by definition recent: it reaches users months after `c` and is replaced within about a year, so while it is the frontier `T` is at most months. Today `c` is June 2026 and the holdout starts 2026-11-01: zero judged days exist, 91 will by 2027-01-31. At `T` = 0.25 years the smallest Sharpe with 80% power is 4.97 (3.29 for even odds); the gate's betting test needs about 4.9 (paper S4a). After a year it is still 2.49.

**The confirmation wall:** a frontier model's strategy, judged as a return series, can be confirmed within a quarter only at Sharpe near 5, and an ordinary edge (Sharpe at most 1) takes six years of forward time on any venue, with any kernel, under any valid test. The pilot's C2.6 failures and stage 3's zero finalists are this arithmetic, met from the inside.

The wall moves in three ways only:

1. **A larger `T`:** an older model, whose post-cutoff history already exists (section 3, design B), or waiting.
2. **A larger `S` through breadth:** many independent bets per period under one pre-registered rule, so the pooled series has a high Sharpe though no single bet does.
3. **A different observation:** questions whose observations are not return periods. Synthetic markets, where `n` is free, answer Q1. Event questions with exact resolution answer Q2.

### 2.3 Market efficiency caps d

For any outcome a market prices, the part an outsider can forecast beyond the price is small. I take `d` between 0.05 and 0.1 per independent bet as the range a skilled forecaster reaches (a hit rate of 52.5% to 55% on even bets, an information coefficient of 0.05 to 0.1), and 0.2 (60%) as implausibly large. So **every edge claim needs 600 to 2,500 independent bets, however it is framed**, and a design is rapid only if it collects about a thousand independent bets rapidly.

The same cap binds the reading contrast when the outcome is a return's sign. For a thesis with true probability `q`, main forecast `p` and no-reading forecast `a`, the paired Brier difference is `(p − a)(p + a − 2o)`, with mean `(p − q)² − (a − q)²` and standard deviation `2|p − a|√(q(1 − q))`. Writing `e = q − a` and `u = p − a`, the per-pair effect is `sign(u)·(2e − u) / (2√(q(1 − q)))`: `|e|` when the main forecast is exactly right, at most `2|e|` when it is timid. Reading cannot move the true probability that a liquid exposure's net return is positive by more than a few points, so at `|e|` = 0.05 the paired test needs 618 to 2,473 independent pairs.

**This corrects my meta review** (section 3 there: "about 180 pairs in 13 weeks, a 0.03 Brier difference is detectable"). The arithmetic stands, but a 0.03 difference needs `|e|` near 0.17: reading would have to move a return-direction probability from 0.50 to 0.67. Halawi et al. found differences of that size on general event questions, where truth ranges from 0.05 to 0.95 and news often settles it. The thesis track's outcome has no such variance to explain. The reading contrast is fast only on outcomes reading can move.

### 2.4 Dependence: aggregate over it

Overlapping bets on common factors are dependent, and the frozen thesis rule tried to model that with a cluster graph, which percolates (meta review, section 3). The classical answer is not to model it. Mark a rule-sized paper portfolio to market each period. Under the null that no position has positive conditional expected return, the portfolio's period returns are martingale differences whatever the overlap, horizons or common factors, because the positions are fixed before each period's return. Dependence then lowers the portfolio's Sharpe; it cannot invalidate the test. This is the calendar-time portfolio of event studies (Jaffe 1974; Mandelker 1974; Fama 1998, *leads*), and it is the null the gate's holdout test already states (paper, section 8, the displayed hypothesis).

So **in every study that claims edge, the unit of inference is the period return of one pre-registered paper portfolio**, `z = S·√T` applies again, and breadth enters only through `S`. There is no cluster rule and no cluster floor: the floor becomes a number of periods derived from power.

### 2.5 What is scarce

Compute and ideas are not scarce: the one real campaign cost $1.50. Two things are:

- **Forward calendar days under a frozen protocol.** They cannot be bought later. The thesis track ran fourteen days across seven frozen versions, banked none, and has been stopped since 2026-11-09; the forward window has run ten days with nothing registered to confirm in it. A day spent perfecting plumbing before a freeze costs exactly as much as a day lost to an outage.
- **Plan usage and the human's attention,** which is why the program below is two small studies in order and not a platform.

### 2.6 Assumptions, stated for attack

- **A1.** `z = d·√n` with a 5% one-sided level and 80% power is the right yardstick. Multiplicity across `k` finalists (Holm) raises `z*` to 2.97 at `k` = 3; sequential looks cost a few percent.
- **A2.** A model's knowledge contaminates all history before `c + m`, for systematic strategies as much as for discretionary ones. If a reviewer can show a class of strategy for which the model's reading could not have selected on pre-cutoff returns, the wall does not bind that class.
- **A3.** `d` ≤ 0.1 per independent bet for priced outcomes. It is a prior from the forecasting and active-management literature, not a derivation. If it is too pessimistic, every forward study below finishes sooner than stated and none is harmed.
- **A4.** Period returns of a predictable portfolio are martingale differences under the null. Stale marks break this for short periods (builder markets over closed hours), which is why the period is a week.
- **A5.** Forward days are unrecoverable and plumbing defects do not change scores. The second half is the identity split's premise (section 5) and is false exactly where an acquisition failure changes what the agent is shown.

## 3. Candidate designs compared

Months to 80% power are `6.18 / I` with `I = d²·n_eff` per month (section 2.1). Every `n_eff` below is my estimate and is marked where a count would settle it. No price or return was read to make them.

| | Design | Unit of observation | Independent observations a month | Stated effect | Months to 80% power |
|---|---|---|---|---|---|
| A | The pilot: a frontier model's strategy, confirmed forward on perps | year of returns | 1/12 year | Sharpe 1; 2; 3; 5 | 74; 18.5; 8.2; 3.0 |
| B | The same, with a model whose cutoff is about two years old | year of returns | none needed: `T` ≈ 1.3 to 2.2 years already exist | Sharpe 1.7 to 2.2 (2.0 to 2.6 with three finalists) | 0, but see threats |
| C | Events on returns: releases, earnings, governance | event | 20 to 40 | `d` = 0.1; 0.2 | 15 to 31; 4 to 8 |
| D | Breadth: a cross-sectional rule over all listed perps, forward | year of returns | 1/12 year, at Sharpe `IC·√(52·N_eff)` | `IC` = 0.03; 0.05 at `N_eff` = 20 | 79; 29 |
| E | The thesis track as frozen: perp theses, return-sign outcome | thesis, after overlap | 15 to 40 | `d` = 0.05; 0.1 | 62 to 165; 15 to 41 |
| F | The positive control: planted edges in synthetic markets | market (one session) | about 90 on two accounts | discovery in half of markets against a fifth | 0.5 |
| G | Theses on exactly resolved event contracts | event | 100 to 400 | `d` = 0.05; 0.07; 0.1 | 6 to 25; 3 to 13; 1.5 to 6 |

### A. The pilot's design, kept

It is the baseline. Its machinery is honest (no null promotion in any calibration cell) and blind at its lengths. Nothing about the kernel, the gate or the DSL changes the first row.

### B. An earlier-cutoff research arm (the human's idea, 2026-10-23)

**What it buys.** History between the old model's cutoff and now becomes a holdout that already exists, so `T` jumps from a quarter to as much as two years without waiting.

**Which models the plans reach.** I was barred from probing models, so this is from memory and the advisor must check it with one probe per id. A provider retires a model about a year after its successor ships, so anything still served is at most about two years old. The oldest cutoffs I believe a subscription can still reach are near the third quarter of 2024 through GPT's plan and early to mid 2025 through Claude's and Gemini's (*leads*). After the four-month margin the project already adopted for a June cutoff, that leaves `T` between 1.3 and 2.2 years: 80% power at Sharpe 2.2 to 1.7 for one finalist, 2.6 to 2.0 with Holm across three. An open-weight model with a 2022 or 2023 cutoff would give four years (Sharpe 1.2), but it is not on the plans, has no harness, and could not do this research.

**Leakage that the model's cutoff does not close.**
1. *The designer.* The brief, the DSL's inputs, the family (funding dislocations) and the universe were chosen in October 2026 by people and models who know 2024 to 2026. That is a search over the holdout by the designer. It cannot be removed, only labelled.
2. *Costs.* The cost table was fitted in October 2026, after the holdout. Stage 3 already carries this qualification.
3. *The cutoff itself.* A stated cutoff is not a boundary: later fine-tuning data and thin coverage of the last months make it fuzzy, hence the margin.
4. *History.* Hyperliquid's 4-hour bars begin 2024-07-08 (`venue/sources.toml`). An arm with a mid-2024 cutoff would have a holdout and almost no search period on the pilot's own grid.

**What skill found by a weaker model says.** The inference is one-sided. If an older model finds an edge that its post-cutoff history confirms, a frontier model can probably do at least as well, and the method works; but the edge is two years old and may have decayed. If it finds nothing, that says nothing about a frontier model. And "confirmed" would still mean Sharpe near 2, which no ordinary edge reaches.

**Verdict:** parked, with a condition (section 4). It moves the wall from Sharpe 5 to Sharpe 2, at the price of a forked harness, fresh null campaigns, and a result that reads only one way.

### C. Event-level designs on returns

**Events a month from sources already certified** (my count from the agencies' calendars, from memory; a builder can count them from `venue/sources.toml`'s hosts): BLS about 9 scheduled releases; BEA 3 to 4; the Federal Reserve's meetings, 8 a year; Treasury auctions 25 to 30, mostly routine; EIA's weekly petroleum and gas reports, 8 to 9; the CFTC's weekly report, 4; SEC filings for the few dozen companies with builder markets, about 10 earnings dates a month on average, bunched into four seasons; Snapshot votes, a handful, for one protocol. About 40 to 70 dated events a month, of which perhaps 20 to 30 move a market.

**The clustering problem.** A release moves rates, the dollar, equities, gold and crypto together, and several releases share a week. Events times markets is not a count of bets: on a release day the first principal component carries most of the variance, so one release is about one bet. Positions opened on different events overlap in calendar time. So `n_eff` is 20 to 40 a month, and the cure is section 2.4's portfolio, not a cluster rule.

**Verdict:** this is what the thesis track on perps is, and row E gives its rate. At `d` = 0.1 it needs one to three years.

### D. Breadth across markets

Breadth is a multiplier on Sharpe, not a design of its own. For `N` markets with mean pairwise correlation `ρ`, the effective number of independent bets is `N / (1 + (N − 1)ρ)`, which tends to `1/ρ`. Crypto perps co-move at `ρ` near 0.5 to 0.7 (from the literature, unmeasured here), so the 347 listings are about two directional bets. After the common factor is hedged out, residual correlation near 0.05 gives about 20, and the builder markets on equities, commodities and currencies add perhaps 5 to 10 more. A weekly cross-sectional rule then has `S = IC·√(52·N_eff)`: 0.97 at `IC` = 0.03, 1.6 at 0.05, and forward confirmation in 79 or 29 months. Breadth helps and does not make a frontier model's systematic strategy confirmable within a year.

Breadth through long histories of many asset classes (the paper's stage 8) helps only the search period. For an LLM researcher those histories lie before the cutoff, on the wrong side of the wall. Combined with B it would need `IC` near 0.06 across 20 independent bets to reach Sharpe 2.

**To measure before relying on it:** the participation ratio `(Σλ)² / Σλ²` of the residual return covariance, on search-period data only.

### E. Forward-only forecasting: the thesis track as frozen

It registers at most two theses a day on perps, each a probability that a position's net return is positive, scored by Brier against a base rate and a no-reading ablation, with a floor of 200 resolved clusters.

**What it can show, and when.**
- *Edge (Q3):* the calendar-time portfolio's Sharpe is `d·√(bets a year)`. At 180 to 480 independent theses a year it is 1.3 to 2.2 for `d` = 0.1, so 15 to 41 months; at `d` = 0.05, five to fourteen years.
- *Reading (Q2):* by section 2.3 the paired contrast against the ablation has effect at most `2|e|` with `|e|` ≤ 0.05 on a return's sign, so 618 to 2,473 independent pairs: 15 months at best. At the sizes it can reach, the paired test detects harm, not help: an agent that reading makes overconfident (`|u|` = 0.15 with `e` = 0) shows `d` = −0.15, visible in 275 pairs.
- *The cluster floor:* unreachable, as my meta review showed.

**Verdict:** as frozen, it is a multi-year record. The registry, the daemon and record-before-reply are sound; the outcome it scores is the wrong one for speed.

### F. The positive control

Synthetic markets are the one place where observations are free: no model has seen them, their length is a parameter, and the truth is known. So Q1 can be answered in about sixteen sessions (section 6). It says nothing about real markets, and that is its strength: it isolates capability from the wall.

### G. Anything better: theses on exactly resolved event contracts

**The design.** A thesis is a paper position in an exchange-traded event contract (a Polymarket or Kalshi market that pays 1 if a stated event happens), with the agent's probability. It fills at the recorded ask, is marked weekly at the recorded bid, and resolves exactly.

**Why its rate is the highest of the forward designs.**
- Distinct events are close to independent by construction, and several hundred resolve every month across economics, policy, companies, crypto, weather and culture. `n_eff` is bounded by how many the agent registers, not by how many factors a market has.
- The outcome is one that reading can move, and the comparator is free and exact: the market's own price. Buying at ask `a` an event of true probability `q` has per-bet effect `d = (q − a) / √(q(1 − q))`, so a three-point net edge at an even price is `d` = 0.06.
- It is the paper's own hypothesis about retail edge (section 13 there): cheap reading over many small catalysts that no analyst is paid to cover, at sizes no fund wants.
- Kalshi is a regulated venue that a United States resident may trade on (*lead*, the advisor checks), which Hyperliquid's interface is not (`venue/sources.toml`, clause 1.6).

**This has been studied.** Halawi et al. (2024) and ForecastBench (Karger et al. 2025) score LLM forecasters against crowds and markets and find them near, not above, the crowd. Prophet Arena (2025, arXiv 2510.17638) does almost this on Kalshi events: its best model's Brier score is 0.184 against the market's 0.187, and its average return is 0.943 against a break-even of 1 (*leads*, from search summaries; the paper is unread). So the prior is parity before costs and a loss after them. What those benchmarks do not test is the hypothesis above: an agent that chooses where to bet, among thin markets, after reading. They forecast every question they are given.

**Threats.** Paper fills in thin books overstate what size could trade. Favorites priced near 1 give many small gains and rare total losses, which breaks a t-test (section 5.5). Ladders of contracts on one underlying are one bet. Resolutions are sometimes disputed. Polymarket's certificate is an operator decision for read-only data and excludes trading.

**A retrospective variant, rejected as evidence.** The frontier model's post-cutoff months already hold thousands of resolved events, so one could forecast them now with reading restricted to earlier documents. Retrieval leaks: date filters are unreliable and pages are edited after the fact, which is why the benchmarks above went forward-only. Leakage only flatters the forecaster, so a retrospective null would be informative and a positive would not. It is a possible futility screen, not a study; I do not recommend building it now.

## 4. The recommended program

Two studies, in this order, then the human's stage 11. Nothing else is built until one of them reports.

### Study 1: the positive control (Q1)

- **Claim:** at a planted edge that the cheap searcher G100 discovers in a fifth of markets, the pilot's agent discovers it in at least half.
- **Unit:** one synthetic market, one isolated agent session.
- **Count:** about 22 sessions a week on the two approved accounts.
- **Power:** a sequential test of 0.2 against 0.5 at 5%: size 0.041, power 0.949, 15 markets expected under either hypothesis, at most 33 (section 6).
- **Vertical slice:** a model-free calibration of the plant's strength on the baseline; exact capture from the kernel's existing trace; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change.
- **Calendar:** a result about three weeks after its build starts.

### Study 2: the thesis track, on event contracts (Q3)

- **Claim:** the paper portfolio of the agent's registered positions, sized by rule and priced at recorded quotes with fees, has a positive mean weekly net return.
- **Unit:** the portfolio's return over one calendar week.
- **Count:** 4.3 a month, each carrying about 60 registered positions.
- **Power:** 80% at 26 weeks if the per-bet effect is 0.063 with 60 independent bets a week (0.089 with 30; 0.049 with 100); at 52 weeks, 0.045 with 60. In Sharpe terms the portfolio needs 3.5 annualized to finish in 26 weeks and 2.5 in 52. Breadth is what makes that reachable: 3,000 independent bets a year at `d` = 0.063.
- **Vertical slice:** a market adapter with three functions (quote at registration, weekly mark, resolution) for Polymarket's certified host; admission rules; the weekly accounting, specified for an independent implementation; one search API under the human's certificate; the existing registry, daemon, sandbox and record-before-reply; the scientific manifest and the operational layer.
- **Calendar:** design, criteria and build in parallel with study 1; a shakedown week that is not evidence; then the freeze. Looks at weeks 13, 26, 39 and 52.

### Why this order

Study 1 is first because it finishes soonest and its answer prices everything on the systematic side. Study 2 is built during study 1's sessions because its clock starts only at its freeze and each week before that is lost. They do not compete for accounts: study 1 runs on TAMU and Cornell, the thesis track on the personal account.

### What each result changes

| Result | Consequence |
|---|---|
| Study 1 accepts 0.5 | Agents add search capability. The systematic line then lacks only a confirmer, and B's condition is half met. |
| Study 1 accepts 0.2 | At this budget and in this DSL the agent searches no better than G100. The systematic line stays parked. The one question worth reopening is whether the DSL hides the agent's ability (`docs/future-work.md`). |
| Study 2 rejects its null | The human's stage 11 has a candidate: the same procedure at small live size, on a venue the human may use. Then, and only then, a no-reading instance runs to attribute the edge. |
| Study 2 reaches futility or week 52 | Reading agents of this generation do not beat event markets net of costs at retail size. The instrument is kept for the next model. |

### Parked, each with the condition that revives it

- **The perp instance of the thesis track** (the frozen design, `thesis-refreeze`): when study 2 rejects its null, or when the human wants the multi-year record for its own sake (open question 1).
- **An earlier-cutoff campaign (B):** when study 1 accepts 0.5 for the frontier agent, and the same control run on a model with a cutoff at least two years old also accepts 0.5.
- **Stages 8 and 9 as written:** superseded (section 7). A multi-asset or cross-domain study returns only as B's vertical slice.
- **Stage 7 and the Lean engine:** as the human decided on 2026-11-09, until a study needs them. Neither study does.

### Where this departs from what was decided, and why

1. **The paired main-versus-ablation Brier protocol** (my meta review's recommendation 2, accepted 2026-11-09) is dropped. On a return's sign its effect is bounded by `2|e|` (section 2.3), and on an event contract the market price is already the no-reading comparator.
2. **"Freeze the current head, then simplify"** (the same review, section 1) is dropped for the perp design. A freeze that sticks would still yield a record that informs in years (row E).
3. **The 200-cluster floor and the cluster graph** are replaced by a horizon in weeks derived from power.
4. **The positive control's rarity anchor** of 0.2 was a utility choice. It becomes a derived quantity: the baseline's own discovery rate, set by calibrating the plant on the baseline.
5. **Stages 8 and 9** are superseded, not deferred: long histories do not lengthen a frontier model's holdout.

## 5. The thesis track, decided at the level of choices

### 5.1 Arms

One: the reading agent. Three comparisons are replayed without a model at report time, from recorded bytes:
- the market's price at registration as a forecast (the Brier comparator);
- a coin-flip side on the agent's own markets at the same quotes, which must lose the spread and the fee (the negative control for the accounting);
- the same positions held from the next recorded quote, which measures how much of any result is quote timing.

The conditional ablation, the full no-reading arm and the Monday benchmark are cut, with `thesis/brief-ablation.md` and `thesis/brief-noread.md`. A no-reading arm answers "where does the edge come from", which has no subject until an edge exists; it can then run as its own instance over its own weeks.

### 5.2 The dependence unit

The calendar week of the marked-to-market paper portfolio (section 2.4). No clusters. Three admission rules keep bets distinct, and they are scientific parameters:
- one open position per event (the venue's own event grouping);
- a cap on open positions per category;
- an entry-price band (section 5.5).

Realized breadth is reported as the ratio of the summed per-position weekly variances to the portfolio's weekly variance.

### 5.3 Throughput

Derived from power, not from cost: about 60 admitted positions a week, so 8 to 9 a day, over two to four sessions a day. A fixed stake of about 0.5% of initial equity keeps the roughly 180 open stakes inside the equity. I am unsure of the usage per session; the shakedown week measures it, and the cap is what the personal account's 0.8 ceiling admits. If that is below 30 a week, the design goes back to the architect before any freeze (section 8).

### 5.4 What the agent may read

- The six hosts already open to retrieval (`venue/sources.toml`, `retrieval = true`), Polymarket's among them.
- One web search API under the human's certificate. Requirements the certificate must be able to quote or show:
  1. An official API whose terms permit automated queries and the use of results as input to a language model.
  2. No clause against storing responses: every body is kept by hash in an append-only record. (FRED's clause (l) is the failure this names.)
  3. Page content returned by the API itself, under its own terms. The daemon never fetches a result's URL from an uncertified host, so "search" without "contents" opens nothing.
  4. Called only by the daemon, which records the query and the full response before it replies. The sandbox keeps no network route but the model's.
  5. A publication date on each result where the API has one.
  6. A fixed price or free tier that the human approves, with a rate that covers about 600 queries a day.
  7. No per-account personalization, and a key held like the others in `.keys.env`.
- The model provider's own server-side web search is the cheapest candidate and fails requirement 4 as C10.2 now stands: its results reach the model without passing the daemon. Whether a transcript is record enough is a re-derivation of C10.2, not a patch. I recommend against it unless no API meets the list.

### 5.5 The one pre-registered protocol

- **Null:** in every week, the portfolio's net return has non-positive mean given everything before that week. This is the gate's holdout null (paper, section 8).
- **Statistic:** the one-sided Student statistic of the weekly net returns.
- **Looks:** weeks 13, 26, 39 and 52, with an alpha-spending boundary of O'Brien and Fleming's shape and total level 5%.
- **The gameable part, and its guard.** A portfolio of favorites bought near 1 wins a little most weeks and loses everything rarely. With one cluster a week bought at 0.95, a mean-zero portfolio passes a 5% Student test 26% of the time at 26 weeks, because no loss has yet occurred (my simulation, 200,000 runs; 59% at 0.98). With 20 independent clusters a week and entry prices capped at 0.90 the size is 6.4% at 26 weeks and 6.1% at 52; capped at 0.80, 5.7% and 5.4%. So the entry-price band and the category cap are part of the test, and the critical values are set by simulation at the worst null the admission rules allow, so that the size is at most 5% there. The gate's betting test would be exactly valid under any skew, but its bound is the whole stake at risk, which breadth does not shrink, so it has no power here; it is reported, not judged.
- **Accounting.** A position fills at the ask in the daemon's own quote fetched at registration, plus the venue's fee. It is marked at the recorded bid. A missing mark carries the last one forward, which moves return between weeks and never changes the total. A position whose resolution is never obtained loses its stake. No registered position ever leaves the portfolio.
- **The claim on rejection:** this frozen procedure's paper portfolio earned a positive mean weekly net return over its window at recorded quotes. Not that it will, and not that size could trade: that is stage 11.
- **Reported, never judged:** Brier against the market price, calibration, results by category and by price and liquidity bucket, the three replays, the betting test's wealth.

### 5.6 The identity split

As the human accepted on 2026-11-09, with the boundary made testable.
- **Scientific manifest:** the model id, the brief, the tools and limits, the universe and admission rules, the stake, the fill, mark, fee and resolution rules, the protocol.
- **Operational layer:** acquisition, retries, the limiter, scheduling, storage, the report's rendering.
- **The invariant that makes the split honest:** scoring is a pure function of the recorded bytes and the scientific manifest. An operational patch may change which bytes exist. It can never change what a recorded quote, mark or resolution is worth. A test replays the whole record under two operational commits and requires identical scores.
- **Where it still leaks:** an acquisition failure changes what the agent is shown. That is predictable information, decided before any outcome, so it cannot bias a test of the portfolio's mean. Failures after registration could: hence "no position leaves the portfolio" and the lost-stake rule.

### 5.7 What of the acquisition machinery stays

- **Stays:** the daemon and record-before-reply; bodies stored by hash; the retrieval log; the per-host limiter as a politeness limit; the terms allowlist; the data layer's three-hourly Polymarket recording, as an independent witness that the daemon's quotes were real.
- **New, and small:** one quote fetch per registration; one mark per open position per week; one lazy resolution fetch per position.
- **Goes, with the perp instance, to the parked branch:** the snapshot state machine, readiness, the prewarm Job, funding scopes, the live Monday benchmark, C10.5's counts as gates, and the eleven test files named for review rounds.

## 6. The positive control, decided at the level of choices

The starting point is my meta review's recommendation 4: discovery only, exact capture, a sequential test. Two things change.

**The difficulty is calibrated on the baseline.** G100's discovery rate as a function of the plant's strength costs no model use. So, before any agent session, the strength is set where G100 discovers in a fifth of markets, with the 95% upper bound of that rate at most 0.2 on at least 1,000 calibration markets. The study's null is then "the agent is no better than the baseline" by construction, and a plant that every searcher or no searcher finds is ruled out before it costs a session. The reference program's net Sharpe at that strength is reported, not targeted.

**One claim, one level.** With selected recovery gone, the whole 5% goes to discovery.

- **Arms:** A, the pilot's agent under the frozen stage 3 harness and kernel (`harness_hash` `6a335714…`), with its original brief and its 100-evaluation budget. B, G100, run on every study market for the paired table and on the calibration markets for the rate. The locked reference R defines "material".
- **Discovery:** the session evaluated at least one program that carries at least half the reference's share of the plant, with positive expected net return. In a synthetic market the plant's expected gross return for a predictable position is the plant's strength times the sum of position times signal over the planted coins (`gate/markets.py`: `eps = clip(σ·x + mask·β·signal)`), and the trace `mm eval --trace` already writes (`Decision`, `Fill`, `Funding`) gives the positions and the realized costs. So capture is computed, not estimated. The measure must be invariant to position size. Its false-discovery rate is measured where it is known to be chance: the baseline's programs in zero-plant markets, scored against the plant that would have been there.
- **Test:** Wald's sequential test of 0.2 against 0.5 with both error rates 5%, truncated at 33 markets with the terminal cutoff 12. Computed exactly by enumeration: size 0.041, power 0.949; expected markets 15.3 at 0.2, 13.3 at 0.5, 20.0 at worst (0.35); power 0.30 at a true 0.3.
- **A crash** stays in the denominator as a non-discovery and is never replaced.
- **Reported, never judged:** B's discovery on the same markets; how many evaluations A used and why it stopped (the real campaign's agent stopped at 9 of 100); whether discovered programs read funding; the gate's selection of what was discovered.
- **Free, first:** each arm's search-period score distribution from the existing stage 3 ledgers, and a reading of why that agent stopped.
- **Cut:** the twin-market truth bank and its 964,476 replays, the Student intervals, the selected-recovery test, the forced release and the kill tests as criteria (they are tests of the release code and need no model), the account criterion down to one identity check. The paper's PC1 to PC6 on `positive-controls` are replaced by this study's design, and that branch is not merged.
- **Not claimed:** real edge, agent superiority in general, or anything about the gate's power.
- **A second cell, only after an acceptance of 0.5:** the same test with a plant that has no economic story, which separates the model's prior from its search. It doubles the sessions, so it waits for a reason.

## 7. Infrastructure: what stays, what is parked, what is deleted

### Stays, and is used

- **Study 1:** the frozen pilot kernel (`kernel/mm`, the judged binary), `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger.
- **Study 2:** `thesis/registry.py`, `thesis/daemon.py`, `thesis/retrieval.py`, `thesis/harness.py`, the runner's session loop, `sandbox/`, `ingest/terms.py`, `venue/sources.toml`, the data layer's Polymarket feeds.
- **Recording:** every recorder runs on untouched (`CLUSTER.md`). Recordings cannot be refetched, and post-cutoff prices that nobody has read are the scarcest asset in the project: they are the holdout of any later campaign. No work is done on them.
- **Process:** pre-registration of statistical criteria; fresh-session bug hunts; the two-round stop rule; the roles.

### Parked: no work until the named condition (section 4)

- Branches `stage7` and `claude/lean-l1-kernel-defects-h273e5`; `reference/lean`; the Lean engine; the nine-defect engine; O1's bound; the delisting corpus; C5.6's calibration.
- Branches `thesis-refreeze` and `thesis-split` (the perp instance), and on `main` the perp-specific `thesis/market.py`, `thesis/positions.py`, `thesis/scoring.py` and `thesis/SCORING.md`, which are hash-frozen and leave only with a fork.
- The swarm (stage 4), agent memory, and the DSL-for-agents study.
- The stage 3 forward window: it lapses on 2027-01-31 with nothing registered in it. Its prices stay unread.

### Deleted

- **Code, when study 2's build forks the thesis track:** the Monday benchmark, the snapshot state machine, readiness, the prewarm, the ablation and no-reading arms and their briefs, the cluster graph, the round-named tests. The Job `thesis-prewarm` warms a design that will not be frozen: the advisor stops it.
- **Positive-control design:** as listed in section 6.
- **Criteria scope**, by dated revision and never by edit (`audit/program/criteria-notes.md`): stages 8 and 9 superseded; C10.5's counts and deadlines become report lines; the 200-cluster floor is replaced by the protocol; the criteria draft on `positive-controls` is withdrawn.
- **Paper:** section 10 (exploration across domains) is replaced by the pilot's finding; stage 8's and 9's roadmap items become one line each; the thesis section's sample-size paragraph and cluster sentence go; T2's cluster floor and T3's quotas are marked historical.
- **`CLAUDE.md` rules**, proposed for the advisor's decision, each because its failure can no longer happen:
  - "a source-blind red team after each kernel milestone" (Reviewers): no kernel milestone is scheduled.
  - "the Lean engine with OCaml plumbing is deferred with stage 7" (Tech): say "parked" once, under Frozen identities.
  - "Before any work on stage N" (Pre-registered criteria): read "study" for "stage"; the roadmap no longer adds stages.
  - "The thesis track's forward use is its own design" (Holdout): becomes one clause, "a forward study's evidence starts at its freeze".
  - Add nothing. The identity invariant of section 5.6 is a test, not a rule.
- **`docs/future-work.md`:** the items the program absorbs or the wall rules out (rewritten in this branch).

## 8. Stop rules

**Study 1.**
- It ends at its sequential boundary or at 33 markets. There is no extension.
- It is abandoned before any session if no strength in the generator's range gives the baseline a rate of 0.2, or if the discovery measure's false-discovery rate on zero-plant markets exceeds 1%. Either sends the design back to the architect.
- Five consecutive sessions lost to one operational cause pause it; they still count.

**Study 2.**
- Efficacy at a look ends it with the claim.
- Futility: at week 26, a Student statistic below zero ends it; at week 52 it ends regardless.
- Before the freeze: if the shakedown cannot sustain 30 positions a week, or realized breadth is under half the admitted count, the throughput and admission rules are re-derived. After the freeze the same shortfall is reported and the protocol runs to its looks: a forward test is never rescued by a change.
- A scientific change is a new instance with a new window. Instances are never pooled.

**The program.** It is abandoned when both are true:
1. study 1 accepts 0.2, and
2. study 2 ends without rejecting.

Then both capabilities the aim rests on, search and reading, have been tested at stated power and found absent for this model generation on a retail budget. That is a finding, and it is published as one. What survives is the pair of frozen instruments: each new frontier model is a rerun of two protocols, not a rebuild. The program is also suspended, not abandoned, if plan usage cannot carry study 2's throughput.

It is never rescued by lowering a threshold, pooling instances, or reading the forward window.

## 9. Unsure, and where to attack

1. **`d` ≤ 0.1 (A3).** Everything about speed rests on it. If reading agents reach `d` = 0.15 on thin event markets, study 2 finishes at its first look.
2. **Independent events a month.** I have not counted them. If admitted, independent positions cannot reach 30 a week outside sports and price ladders, study 2's row falls to row C's. The detailed design counts resolved events by category from the closed-market feed before anything is built.
3. **Paper fills.** Gamma's best ask has no size. A liquidity floor and a small stake are a qualification, not a proof. Order-book depth lives on a host the certificate does not name (open question 3).
4. **The Student test under dependence I did not model:** a week in which one headline resolves positions in several categories. The simulation that sets the critical values must include such weeks, and I have not specified them.
5. **Whether an older model is reachable at all,** and its cutoff.
6. **The calendar-time null with stale bids.** A bid that does not move is not a martingale increment. Weekly marks soften this; they do not remove it.
7. **Prophet Arena's and ForecastBench's numbers** are from search summaries.
8. **Whether "discovery by evaluation" is the right event** for study 1, since an arm that evaluates more programs has more chances. Budgets are equal by construction, and the agent may choose to use less.
9. **The baseline as the anchor.** Calibrating the plant on G100 makes the claim relative to G100. A reviewer may prefer a fixed economic strength; then the anchor is a choice again.
10. **Venue facts** (Kalshi's status, its fee formula, Polymarket's fees) are from memory.
