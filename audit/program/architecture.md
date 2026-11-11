# The research architecture, re-derived (revision 2)

Revision 1 was written 2026-11-10 21:04 UTC (16:04 EST) by Claude Fable 5.2 (`claude-fable-5-2`) and is kept at `git show 51fd365:audit/program/architecture.md`. This revision was written 2026-11-11 03:51 UTC (2026-11-10 22:51 EST) by the same model, session "architect: revision", on branch `rearchitecture`. It answers GPT's adversarial review (`audit/reviews/2026-11-10-gpt-rearchitecture.md` on `main`), Argon's check of the paper (`audit/reviews/2026-11-10-argon-web-paper-math.md` on `main`), and the human's pause of all Polymarket collection (`audit/decisions.md`, 2026-11-11). It is a design awaiting the advisor's decision; nothing here is decided until it is logged in `audit/decisions.md`. This is the first of at most two fix rounds.

**Read for this revision:** revision 1, the two reviews, the two briefs, the criteria notes, the arithmetic script, and the paper's wall section, roadmap, S4a and T4 (to write `paper-changes.md`). **Not read:** any code, `audit/decisions.md`, `venue/sources.toml`, any venue's terms or API documentation, anything under `data/`. Every venue fact below is a *lead* for the certificate. Citations from memory are *leads* too. **Run:** `audit/program/arithmetic.py.txt`, which reproduces every number here.

**What changed, in five lines.**
1. Study 2 is judged by the cash of a self-financing paper account, an exact test, and not by a Student statistic. Marks, looks, critical values and the price and category rules leave the test.
2. Study 2's venue is a CFTC-designated exchange under a certificate, the one stage 11 could trade on. Fills walk the recorded order book.
3. Study 1 compares the agent with the baseline on the same markets. Nothing is calibrated into a null, and discovery claims no expectation.
4. The wall is two numbers: Sharpe 5 on a Gaussian yardstick and 26 for the gate's own test.
5. No result is called "absent", and the program does not answer Q2.

Section 10 disposes of each of GPT's findings. `argon-paper-findings.md` gives my opinion on Argon's, and `paper-changes.md` lists the paper edits this revision needs.

## 1. What the aim asks

The human's aim: use frontier agents' search and synthesis to find and test retail trading strategies and theses, rapidly and honestly, with statistics as the empirical standard and formalism as a means. It holds three questions:

- **Q1, capability.** When an edge exists, do agents find it more often than cheap search at the same budget?
- **Q2, information.** Does an agent's reading change its forecasts for the better?
- **Q3, edge.** Does anything an agent proposes earn a positive expected net return?

"Rapidly and honestly" means: each question gets a pre-registered test, valid under the null it names, whose power is stated, in the least calendar time arithmetic allows. The program below answers Q1 in a narrow form and Q3 for one frozen procedure. It does not answer Q2 (section 5.2).

## 2. The binding constraint

### 2.1 The yardstick

A claim tested on `n` independent observations, each with standardized effect `d`, has evidence `z = d·√n`. A one-sided 5% test with 80% power needs `z* = 2.49`, so `n = 6.18 / d²`. For a strategy of annualized Sharpe `S` held `T` years, `z = S·√T` and `T = 6.18 / S²`: 6.2 years at Sharpe 1, 1.55 at 2, 0.69 at 3, 0.25 at 5. Grinold's law `S = IC·√BR` is the same identity. This is the minimum track record length of Bailey and López de Prado (2012).

It is a planning reference, not a limit: it assumes observations independent and near enough to Gaussian for a fixed-length test to hold its level. A test that assumes less pays more (section 2.2). Revision 1's "no test changes it" and "a cleverer test moves the constant by tens of percent" are withdrawn.

### 2.2 The exact test and its cap

A test that assumes only its null is a bet. This has been studied at length: Ville (1939), Kelly (1956), Shafer and Vovk's game-theoretic probability, Shafer's "Testing by betting" (2021), Waudby-Smith and Ramdas (2024) (*leads*). If each period's return `r` is at least `−L` and has non-positive conditional mean under the null, the wealth `K = Π(1 + λr)`, with `0 ≤ λ ≤ 1/L` set before each period, is a non-negative supermartingale. It reaches `1/α` with probability at most `α`, under any dependence, any skew and any stopping rule.

Its expected log growth a period at a constant bet is `λμ − λ²(σ² + μ²)/2`. At Kelly's bet `λ* ≈ μ/σ²` that is `(μ/σ)²/2`, so wealth reaches 20 in expectation at `z² = 2·log 20 = 6.0`, the yardstick's own scale. **The exact test is as fast as the yardstick only when Kelly's bet fits under the cap, `μ/σ² ≤ 1/L`.** When the worst loss is many standard deviations, growth is at most `μ/L`: linear in the mean, however small the variance.

- **The gate.** `L = 2` and `σ` = 2% a four-hour step. At Sharpe 4.9 Kelly's bet is 5.2 and the cap is 0.5. Capped, wealth reaches 20 in expectation over 546 steps only at Sharpe 26 (39 at 360 steps, 13 at 1,080, 3.4 at two years, 2.8 at 5,400). This is Argon's finding 1, reproduced.
- **An event contract** bought at an even price loses at most its stake, which is one standard deviation. A pool of `m` such bets with edge `e` per dollar has Kelly bet `m·e`; the cap binds once `m > 1/e`, and each turnover of the stake then adds about `e − 1/(2m)` to log wealth.

These are thresholds on expected log wealth, not 80% power, and a bet that starts at zero and learns its size pays more.

### 2.3 The cutoff makes T small for a frontier model

A model's proposals are selected on everything it read before its knowledge cutoff `c`: prices, and a literature fitted to those prices (published anomalies lose roughly half their return out of sample; McLean and Pontiff 2016, *lead*). No null market detects that search. Only data after `c` plus a margin can judge what the model proposes (the human, 2026-10-23), so `T = now − c − m`, and a frontier model is recent by definition. Today `c` is June 2026 and the holdout starts 2026-11-01: 91 judged days will exist by 2027-01-31.

**The confirmation wall.** At `T` = 0.25 years a test that trusts the Gaussian approximation has 80% power only at Sharpe 4.98, and the gate's exact test needs about 26. After a year the yardstick still asks 2.49. An ordinary edge (Sharpe at most 1) takes six years on the yardstick. The pilot's C2.6 failures are both things: the calendar, which no test removes, and the gate's cap, which is a property of that test on that return series. Revision 1 called the second "arithmetic, not a defect of the gate" and wrote "under any valid test"; both are withdrawn.

The wall moves in three ways:

1. **A larger `T`:** an older model, or waiting.
2. **A return whose worst case is near its typical size,** so that the exact test runs near the yardstick. Bars of a leveraged perpetual are not such a return. Stakes in binary contracts are.
3. **A different observation:** synthetic markets, where observations are free, answer Q1.

### 2.4 Market efficiency caps the edge

For an outcome a market prices, what an outsider can forecast beyond the price is small. I take `d` between 0.05 and 0.1 per independent bet as the range a skilled forecaster reaches, and 0.2 as implausibly large (A3, a prior). On the yardstick and under that prior, an edge claim needs 600 to 2,500 independent bets.

The reading contrast is bound the same way where the outcome is a return's sign. For true probability `q`, main forecast `p` and no-reading forecast `a`, the paired Brier difference has standardized effect `sign(u)·(2e − u) / (2√(q(1 − q)))` with `e = q − a` and `u = p − a`. When the main forecast is exactly right that is `|e| / (2√(q(1 − q)))`: `|e|` at `q` = 1/2, and 0.25 at `q` = 0.01 with `|e|` = 0.05. Revision 1 stated the bound `|e|` without its condition. It holds for a return's sign, where `q` is near 1/2, and is not general. So the correction to my meta review stands for the thesis track on perps: a 0.03 Brier difference there needs reading to move a return-direction probability from 0.50 to 0.67.

### 2.5 Dependence: one account, and an exact test on it

Overlapping bets on common factors are dependent, and the frozen thesis rule tried to model that with a cluster graph, which percolates. Revision 1 replaced it with a weekly marked portfolio and a Student test, and claimed that dependence "cannot invalidate the test". That was wrong for the test it named. The null gives the portfolio's returns a non-positive conditional mean and nothing else, and a Student statistic also needs them near Gaussian. GPT's null: 60 events a week at price 0.50; with probability 30/31 exactly 31 pay, otherwise none. Every event has probability one half, the weekly profit is +1 or −30 with mean zero, and no losing week occurs in 26 with probability 0.43, in 52 with 0.18. No rule on prices or categories excludes it, and a critical value set at the worst admissible null would be infinite.

The cause is the test, so the test changes. A self-financing paper account's wealth needs only the null and the fact that a stake cannot lose more than itself. Against the same null the account needs 92 winning weeks in a row to reach 20, which has probability 0.049.

**In every study that claims edge, the judged statistic is the cash of one pre-registered, self-financing paper account, and the yardstick is used for planning only.**

### 2.6 What is scarce

- **Forward calendar days under a frozen protocol.** They cannot be bought later. The thesis track ran fourteen days across seven frozen versions and banked none.
- **Plan usage and the human's attention,** which is why the program is two small studies in order and not a platform.

### 2.7 Assumptions, stated for attack

- **A1.** The yardstick is the right planning scale. The judged tests do not rest on it.
- **A2.** A model's knowledge contaminates all history before `c + m`, for systematic strategies as much as for discretionary ones.
- **A3.** `d` ≤ 0.1 per independent bet for priced outcomes: a prior, not a derivation. If it is too pessimistic, every forward study finishes sooner and none is harmed.
- **A4.** In study 2, a purchase's recorded cost is one at which the reference stake could have been bought. The account's validity rests on this and on the null, and on nothing about dependence, marks or timing.
- **A5.** Forward days are unrecoverable, and an operational defect cannot raise a judged statistic (section 5.7 makes the second half a tested property).

## 3. Candidate designs compared

Months are `6.18 / (d²·n)` on the yardstick unless marked exact. Every count of observations is my estimate. No price or return was read to make them.

| | Design | Observation | Stated effect | Months |
|---|---|---|---|---|
| A | The pilot: a frontier model's strategy, confirmed forward on perps | year of returns | Sharpe 1; 2; 3; 5 | 74; 18.5; 8.2; 3.0. Exact, the gate's test: Sharpe 26 within its 91 days |
| B | The same, with a model about two years past its cutoff | year of returns; 1.3 to 2.2 years exist | Sharpe 1.7 to 2.2 | none, on the yardstick. Exact: Sharpe about 3.4 over two years |
| C | Events on returns: releases, earnings, governance | event, 20 to 40 a month | `d` = 0.1; 0.2 | 15 to 31; 4 to 8 |
| D | Breadth: a weekly cross-sectional rule over about 20 independent bets | year of returns | `IC` = 0.03; 0.05 | 79; 29 |
| E | The thesis track as frozen: perp theses, return-sign outcome | thesis, 15 to 40 a month | `d` = 0.05; 0.1 | 62 to 165; 15 to 41 |
| F | The positive control: agent against baseline on planted synthetic markets | market, about 22 a week | agent finds it in 0.5 of markets, baseline in 0.2 | exact: 30 markets expected, 60 at most, so under three weeks |
| G | A paper account in exactly settled event contracts | turnover of the account's cash, about one a week | net edge per dollar staked 0.04; 0.08; 0.12; 0.16 | exact: 22; 10; 6.5; 5 (expected weeks to 20: 95; 43; 28; 21) |

**A, the pilot's design.** The baseline. No null promotion occurred in any calibration cell, and at its lengths it cannot see an ordinary edge, for the two reasons of section 2.3.

**B, an earlier-cutoff research arm** (the human's idea, 2026-10-23). History between an old model's cutoff and now is a holdout that already exists. The oldest cutoffs a subscription still serves are, I believe, about two years back (*lead*; one probe per model id settles it). What the cutoff does not close: the designer chose the brief, family and universe knowing 2024 to 2026; the cost table was fitted after the holdout; a stated cutoff is fuzzy; Hyperliquid's four-hour bars begin 2024-07-08, leaving such an arm almost no search period. The inference is one-sided: an old model's failure says nothing about a frontier model. And the gate's test would still need Sharpe near 3.4, so B needs a re-derived confirmer as well as a model. Parked (section 4).

**C, events on returns.** The certified sources carry perhaps 40 to 70 dated events a month, of which 20 to 30 move a market. A release moves rates, the dollar, equities and crypto together, so one release is about one bet. This is what the thesis track on perps is.

**D, breadth across markets.** For `N` markets with mean pairwise correlation `ρ`, the effective number of bets is `N / (1 + (N − 1)ρ)`, which tends to `1/ρ`: the 347 perp listings are about two directional bets, perhaps twenty once the common factor is hedged (from the literature, unmeasured here). A weekly cross-sectional rule then has Sharpe 0.97 at `IC` = 0.03. Long histories of many asset classes help only the search period, which for a language model lies before the cutoff.

**E, the thesis track as frozen.** At most two theses a day on perps, scored on a return's sign. Its cluster floor is unreachable, and by section 2.4 its reading contrast needs 618 to 2,473 independent pairs. A multi-year record.

**F, the positive control.** Synthetic markets are where observations are free: no model has seen them and the truth is known. It says nothing about real markets, which is its strength: it isolates capability from the wall.

**G, a paper account in event contracts.**
- *Why it is the fastest exact forward design.* A binary contract's worst loss is its stake, about one standard deviation at an even price, so the exact test is not crippled by its cap (section 2.2). Each turnover of the account's cash adds about the net edge per dollar to log wealth, and wealth must gain log 20 = 3.0. Speed is edge times turnover: contracts that settle within days, and cheap contracts, where a point of probability is a larger return (two points at a price of 0.20 are worth as much as five at 0.50).
- *It is the paper's own hypothesis about retail edge:* cheap reading over many small catalysts, at sizes no fund wants.
- *The venue is one the human could trade on,* so a rejection is a candidate and not an untradeable record.
- *This has been studied, and the prior is against a rejection.* Halawi et al. (2024) and ForecastBench (Karger et al. 2025) find LLM forecasters near or below crowds. Prophet Arena (arXiv 2510.17638, Table 2, checked by GPT) reports its best model's Brier score at 0.184 ± 0.006 against the market's 0.187 ± 0.006, and a gross payout ratio of 0.943 ± 0.042 for a rule that buys every market it is given. Parity before costs, a loss after. What those benchmarks do not test is an agent that chooses where to bet, among thin markets, after reading. A Kelly bettor's log wealth against market prices is the log likelihood ratio of its forecasts against the market's (Kelly 1956), so the account is also the classical test of that comparison.
- *Threats.* A displayed book is not a fill. Capacity is not tested at a reference stake. A venue's terms can change, as Polymarket's did.
- *A retrospective variant* (forecasting already-settled events with reading restricted by date) leaks through retrieval and only flatters the forecaster. It could screen for futility and cannot support a claim. Not built.

## 4. The recommended program

Two studies, in this order, then the human's stage 11. Nothing else is built until one of them reports.

### Study 1: the positive control (Q1)

- **Claim, on its upper decision:** on synthetic markets that carry a planted funding edge, the pilot agent's session ends on a program that carries the plant more often than the baseline G100's does, at the same evaluation budget.
- **Unit:** one market, run by both arms. Only markets where exactly one arm succeeds carry evidence.
- **Test:** a sequential sign test, exact by enumeration: size at most 0.037; with the agent at 0.5 and G100 at 0.2 the upper decision has probability 0.89 and takes 30 markets on average; 60 at most.
- **Vertical slice:** the measure and a model-free calibration; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change.
- **Calendar:** a result about four weeks after its build starts.

### Study 2: a paper account in event contracts (Q3)

- **Claim, on rejection:** at the 5% level, not every purchase the frozen procedure made was at a non-positive expected net return: its paper account, buying at recorded executable cost, multiplied its cash twentyfold.
- **Unit:** the purchase. There is no period, no mark and no look.
- **Power, for planning:** with weekly turnover at even prices and 60 purchases a week, cash reaches 20 within 52 weeks with probability 0.79 at a net edge of 8 cents per dollar staked, and 0.08 at 4 cents (0.65 within 104 weeks). A rejection inside a year needs an edge near the top of what section 2.4 thinks plausible, or faster turnover.
- **Vertical slice:** a venue certificate; a census of settled events; a venue adapter with two scientific functions (order book to cost, settlement to payout); the account, specified for an independent implementation; one search API under the human's certificate; the existing registry, daemon, sandbox and record-before-reply.
- **Calendar:** certificate, count, design and build during study 1; a shakedown week that is not evidence; then the freeze.

### Why this order

Study 1 finishes soonest, and its answer prices the systematic side. Study 2's clock starts only at its freeze, and its first step, the venue certificate, is the human's and the advisor's, so it starts now. The studies do not compete for accounts: study 1 runs on TAMU and Cornell, study 2 on the personal account.

### What each result changes

| Result | What it is called | Consequence |
|---|---|---|
| Study 1, upper decision | The agent's sessions end on the planted edge more often than G100's | Search is not what the systematic line lacks. It still lacks a confirmer with power, so it stays parked. The second cell (section 6) becomes worth its sessions |
| Study 1, lower decision | The target advantage, four of five discordant markets, is rejected | Nothing is claimed about equality with G100. The systematic line stays parked; the open question is whether the DSL hides the agent's ability (`docs/future-work.md`) |
| Study 1, undecided at 60 markets | Inconclusive, with each arm's rate and exact intervals | As the lower decision, stated as weaker |
| Study 2, cash reaches 20 | The procedure's purchases had positive expected net return, on paper at a reference stake | Stage 11 has a candidate on the same venue. The claim is about the procedure, not about reading |
| Study 2, the mirror reaches 20 | The procedure's purchases lose net of costs | The instrument is kept for the next model |
| Study 2, neither | Not confirmed, with realized growth and the edges the study could have seen | The human decides whether to continue; continuing costs no validity |

### Parked, each with the condition that revives it

- **The perp instance of the thesis track** (`thesis-refreeze`): when study 2 rejects its null, or when the human wants the multi-year record for its own sake.
- **An earlier-cutoff campaign (B):** when study 1 reaches its upper decision for the frontier agent and for a model at least two years past its cutoff, and a confirmer has been re-derived whose stated power at that length reaches an ordinary edge. The gate's capped bet does not.
- **Stages 8 and 9 as written:** superseded. A multi-asset study returns only as B's vertical slice, and not before the licensing boundary defeats tracker attacks (`argon-paper-findings.md`, finding 12).
- **Stage 7, the Lean engine and the gate's holdout machinery:** until a study needs them. Each carries known defects that are cleared first (`argon-paper-findings.md`).

### Where this departs from what was decided, and why

1. **The paired main-versus-ablation Brier protocol** (my meta review, accepted 2026-11-09) is dropped: on a return's sign its effect is bounded (section 2.4), and it does not answer Q3.
2. **"Freeze the current head, then simplify"** is dropped for the perp design: a freeze that sticks would still inform in years.
3. **The 200-cluster floor and the cluster graph** are replaced by one account and one threshold.
4. **The positive control's anchor** is the baseline itself, run on every study market, in place of a rate of 0.2.
5. **Stages 8 and 9** are superseded, not deferred.
6. **Polymarket** is no part of the design: neither its hosts nor its recorded history.

## 5. Study 2, decided at the level of choices

### 5.1 The account and the test

- **The account** starts with cash 1, a unit of test wealth and not of dollars.
- **A purchase.** At registration the daemon records the venue's order book for the contract. The cost `c` per unit, in (0, 1), is the average all-in price, fees included, of buying a fixed reference stake by walking the recorded asks. The account pays a stake `s`, set by a frozen rule from what is recorded at that instant, never more than its cash, and holds `s/c` units.
- **A payout.** When the venue's settlement value `x` in [0, 1] is recorded, the account receives `(s/c)·x`. Nothing else moves cash. There are no marks, no exits and no deadlines: a payout not yet recorded is simply not in cash.
- **Null:** for every purchase, `E[x | everything recorded up to its registration] ≤ c`. No purchase the procedure makes, at its recorded cost, has positive conditional expected net return.
- **Validity.** Under the null, cash plus the conditional expected payout of the open positions is a non-negative supermartingale that starts at 1: each purchase replaces `s` of cash with a claim worth at most `s`, and between purchases a conditional expectation is a martingale. Cash never exceeds it. By Ville's inequality cash reaches 20 with probability at most 5%, under any dependence between contracts, any price mix, any pattern of missing records and any stopping rule.
- **Judged statistic:** the maximum of cash. The null is rejected when it reaches 20.
- **The claim on rejection** is the negation of that null and no more (section 4). Not that the edge persists, not that size could trade, not that reading produced it.

### 5.2 What a result may be called

- **The mirror.** A second account, computed from the same record, buys for each purchase the complementary claim, which pays `1 − x`, at `1 − c`, staking the fraction of its own cash that the account staked of its cash. Under the hypothesis that every purchase had non-negative expected net return it is a non-negative supermartingale. If it reaches 20, that hypothesis is rejected at 5% and the procedure is said to lose net of costs. It is the same accounting run from the other side, and it is the only way a result is called negative.
- **Neither account reaches 20:** "not confirmed". The report gives both accounts' paths, the realized net return per dollar staked, and the planning table's row for the realized turnover, so a reader sees which edges the study could have detected. It is never called absence of edge, and never a statement about a model generation.
- **Q2 is not answered.** A rejection shows that the procedure's purchases had edge. A rule that reads nothing and buys a known premium would show the same. Attribution to reading needs a no-reading account over the same weeks, not a later one (open question 3).
- **Reruns.** Each instance tests its own procedure at 5%, and twenty null instances have a 64% chance of one rejection. So a rejection is a candidate for stage 11, whose live record is the replication, and each report states how many instances were frozen before it.

### 5.3 Rules that are part of the experiment

Validity needs none of them. Each is a scientific parameter kept for power or for what the claim means, and the detailed design derives or drops it.

- **The market is open for trading at the recorded book,** and the registration's time is that record's time. No backdating and no catch-up. A contract whose event has already happened but which still trades at a stale price is a legitimate purchase, since the price is executable, and is reported apart.
- **The reference stake fills** from the recorded asks. Otherwise the registration is refused.
- **The contract's scheduled end is within a horizon cap.** Turnover is the study's speed (section 3 G). Seven days is the starting point.
- **One open position per event,** by the venue's own event grouping, so that a ladder of thresholds is one bet.
- **The stake rule.** Recommended start: half of Kelly's fraction from the agent's own registered probability `p`, `(p − c) / (2(1 − c))` of cash, capped at 5% of cash, and no purchase unless `p > c`. Log wealth under Kelly's rule is a proper score, so the agent's honest probability is its best report. The cap is a choice against overconfidence.
- **The pause.** When cash plus the cost of open positions reaches 20, the account stops buying until they settle. Cash understates wealth while stakes are open; the pause lets it catch up.

The price band, the category cap and the weekly portfolio of revision 1 are gone. They existed to shore up a test that is no longer used.

### 5.4 Power and throughput

For planning only: purchases independent, cash fully staked each week in equal parts, all settled within the week (`arithmetic.py.txt`). Probability that cash reaches 20 by week 26, 52, 104:

| Purchases a week, price | Net edge per dollar | Expected weeks | By 26 | By 52 | By 104 |
|---|---|---|---|---|---|
| 60 at 0.50 | 0.04 (2 points of probability) | 95 | 0.00 | 0.08 | 0.65 |
| 60 at 0.50 | 0.08 (4 points) | 43 | 0.03 | 0.79 | 1.00 |
| 60 at 0.50 | 0.12 | 28 | 0.37 | 1.00 | 1.00 |
| 30 at 0.50 | 0.08 | 48 | 0.07 | 0.63 | 0.98 |
| 60 at 0.20 | 0.10 (2 points) | 47 | 0.19 | 0.66 | 0.95 |
| 60 at 0.20 | 0.20 (4 points) | 19 | 0.83 | 1.00 | 1.00 |
| 60 at 0.80 | 0.05 (4 points) | 63 | 0.00 | 0.10 | 1.00 |

- Staking half the cash doubles the time (edge 0.08, 60 a week: 80 weeks expected).
- Favorites are slow: a real four-point edge at a price of 0.80 takes over a year. That is the price of a test that cannot be fooled by steady small wins before a rare total loss.
- There is no throughput quota. The agent registers what it believes in, since a quota dilutes a sparse edge. Thirty purchases at the 5% cap stake 79% of cash, so fewer than about thirty a turnover leaves cash idle.
- **Before the freeze,** the design returns to the architect if the census finds fewer than 30 distinct admitted events settling a week, or if the shakedown week stakes less than half the account's cash. After the freeze a shortfall is reported and the instance runs on.

### 5.5 The venue and its certificate

The venue is one exchange whose terms permit automated use: Kalshi or Polymarket US, both CFTC-designated (GPT read the CFTC's directory: Kalshi designated 2020-11-03, QCX LLC doing business as Polymarket US 2025-07-09). I recommend certifying Kalshi first: from memory it publishes an API with an order book, a fee schedule and a demo environment (*leads*), and I know nothing checked about Polymarket US's API or listings. One venue per instance.

The certificate must establish, each by a quoted clause or an official document:

1. **Which entity and which hosts.** The designated exchange's own API host. Polymarket's international hosts are a different venue and stay closed.
2. **Automated access to market data is permitted,** for which endpoints, with or without an account. If a key is needed, the account agreement's clause on API use, in the human's name (`CLAUDE.md`, Sources).
3. **The uses the design makes:** storing every response verbatim by hash, showing market data to a language model, and publishing aggregate results. Any clause on redistribution, derived works or AI use is quoted and read.
4. **The data the design needs is officially exposed:** the order book with a size at each level, on production markets; market status; event grouping, category and scheduled end; the rules text; the settlement value, including a void or a split; and the fee schedule with its rounding and per-market exceptions. Fees are read from the schedule and recorded with each purchase, never remembered. Kalshi's fee schedule page returned a 429 to GPT's fetch; that is a restriction, and the human reads the page by hand.
5. **Rate limits** against the design's volume: a book per registration and one a fixed delay later, a settlement poll per open position, a weekly census, and the agent's own browsing of markets.
6. **Paper use.** The study places no order. Whether holding a key without trading is permitted, and that the demo environment is not used for prices.
7. **For stage 11, recorded now:** the human's eligibility on the venue, and whether placing orders through the API is permitted.
8. **The terms' effective date and a copy.** They are re-read before the freeze and whenever the venue announces a change. If permission is withdrawn, collection stops and the instance ends not confirmed, its record standing.

### 5.6 What the agent may read

- The hosts with `retrieval = true` in `venue/sources.toml`. Polymarket's is no longer one.
- The venue's market data, through the daemon, under the certificate above.
- One web search API under the human's certificate, which must show:
  1. an official API whose terms permit automated queries and the use of results as input to a language model;
  2. no clause against storing responses (FRED's clause (l) is the failure this names);
  3. page content returned by the API itself, since the daemon never fetches a result's URL from an uncertified host;
  4. calls made only by the daemon, which records query and response before it replies;
  5. a publication date on each result where the API has one;
  6. a price or free tier the human approves, at about 600 queries a day;
  7. no per-account personalization.
- The model provider's own server-side search fails requirement 4 as C10.2 stands. I recommend against it unless no API meets the list.

### 5.7 The identity split

As the human accepted on 2026-11-09, with the boundary made testable.

- **Scientific manifest:** the immutable model snapshot id, the brief, the tools and limits, the venue, the two adapter functions (book to cost, settlement to payout), the rules of section 5.3, the reference stake, the fee rule, the threshold.
- **Operational layer:** fetching, retries, the limiter, scheduling, storage, the report's rendering.
- **Three tested properties make the split honest:**
  1. Both accounts are pure functions of the recorded bytes and the manifest: a replay under two operational commits gives identical cash paths.
  2. Removing any settlement record never raises the account's cash at any time. So no failure after a registration can create a rejection; it can only delay or lose a payout, and a payout recorded late still counts when it is recorded.
  3. A registration's book is committed before the agent sees a reply (C10.2).
- **What a failure before registration does.** It removes a purchase before its outcome exists, or changes what the agent is shown. Both are decided before any outcome, and the null's supermartingale survives any such choice. What each session was shown is a recorded disclosure and a report line.
- **What remains a qualification.** A recorded book may be stale, or gone before an order could reach it. The report costs the same purchases at the delayed book, and stage 11 is the test.

### 5.8 What of the acquisition machinery stays

- **Stays:** the daemon and record-before-reply; bodies stored by hash; the retrieval log; the per-host limiter; the terms allowlist.
- **New, and small:** the venue adapter's fetches (a book at registration and one a fixed delay later, a settlement poll, the census).
- **Goes:** weekly marks; every dependence on Polymarket; and, with the perp instance to the parked branch, the snapshot state machine, readiness, the prewarm Job, funding scopes, the live Monday benchmark, C10.5's counts as gates, and the test files named for review rounds.

## 6. Study 1, decided at the level of choices

- **Arms.** A, the pilot's agent under the frozen stage 3 harness and kernel (`harness_hash` `6a335714…`), with its brief and its 100-evaluation budget. B, G100, run on every study market with a seed fixed in the manifest.
- **A session's pick** is its evaluated program with the highest search-period score, the quantity G100 maximizes, read from the ledger the same way for both arms. A session with no evaluation has no pick. Judging the pick, and not any evaluated program, is what stops an arm from scoring by evaluating a remembered answer and discarding it, and it removes the hundred chances a session otherwise has.
- **The pick carries the plant** when the alignment of its holdings with the planted signal is at least half the locked reference program's on the same market. Holdings are rebuilt from the trace's fills; an order is not a holding. The measure is a pathwise fact about what was held. It claims no expected return, so the generator's clipping, liquidation and costs do not enter it. Recommended start: the cosine between dollar holdings and the signal over all coins and steps, the signal being zero off the planted coins.
- **Difficulty** is one plant strength, chosen without a model on calibration markets that share no seed with the study's: the grid value at which G100's rate is nearest 0.2, inside 0.1 to 0.3. That is a choice for power: the baseline sometimes finds the plant and usually does not, so discordant markets are common. Its error moves the study's power and never its size, since the null compares the arms on the same markets.
- **Null:** the agent's pick carries the plant no more often than G100's. Then a discordant market is the agent's win with probability `θ ≤ 1/2`.
- **Test:** Wald's sequential test of `θ ≤ 1/2` against `θ = 0.8` (the agent at 0.5 against G100 at 0.2), nominal errors 5%, ending undecided at 60 markets. By exact enumeration:

  | Agent, G100 | Upper | Lower | Undecided | Markets expected |
  |---|---|---|---|---|
  | every market discordant, `θ` = 1/2 (the worst null) | 0.037 | 0.960 | 0.003 | 14 |
  | 0.2, 0.2 | 0.025 | 0.758 | 0.217 | 36 |
  | 0.3, 0.2 | 0.203 | 0.407 | 0.390 | 43 |
  | 0.35, 0.2 | 0.382 | 0.253 | 0.366 | 43 |
  | 0.5, 0.2 | 0.888 | 0.033 | 0.079 | 30 |
  | 0.6, 0.2 | 0.985 | 0.006 | 0.009 | 21 |

- **What each decision establishes.** Upper: the agent's rate exceeds G100's, at a level of 5%. Lower: the hypothesis `θ ≥ 0.8` is rejected, with error at most 0.036; a modestly better agent (0.3 against 0.2) gets this decision 41% of the time, so it is never called "no better". Undecided: inconclusive.
- **A crash** is a non-discovery for its arm and is never replaced, so the claim includes the agent's reliability.
- **Model-free checks before any session. Each is a wall, not a criterion:**
  1. Some grid strength puts G100's rate inside 0.1 to 0.3.
  2. On zero-plant markets, scored against the signal that would have been planted, G100's rate is at most a quarter of its rate at the chosen strength. Otherwise the measure is not detecting the plant.
  3. G100's picks from zero-plant markets, re-run on fresh zero-plant markets, average a net score at or below zero. An excess is a leak in the evaluator. The stage 1 canary would miss one worth Sharpe 2 in 99% of runs (Argon's finding 14).
- **Reported, never judged:** whether each session evaluated any plant-carrying program (search apart from selection); evaluations used and why the agent stopped; the picks' net scores on the study market and on fresh markets with the same plant; each arm's rate with exact intervals.
- **Free, first:** each arm's search-period score distribution from the stage 3 ledgers, and a reading of why that agent stopped at 9 of 100.
- **Not claimed:** real edge; that agents search better in general; anything about the gate. And not search apart from prior: the brief names the family the plant belongs to, so the agent's prior is inside the claim. A second cell, with a plant that has no economic story, separates them, and runs only after an upper decision.
- **Cut:** a certified baseline rate, its confidence bound and the 1% false-discovery criterion; "expected net return" from the definition of discovery; and, as before, the twin-market truth bank, the Student intervals, the selected-recovery test, and the release and kill tests as criteria. PC1 to PC6 on `positive-controls` are replaced, and that branch is not merged.

## 7. Infrastructure: what stays, what is parked, what is deleted

### Stays, and is used

- **Study 1:** the frozen pilot kernel, `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger.
- **Study 2:** `thesis/registry.py`, `thesis/daemon.py`, `thesis/retrieval.py`, `thesis/harness.py`, the runner's session loop, `sandbox/`, `ingest/terms.py`, `venue/sources.toml`.
- **Recording:** the recorders run on untouched, except those the human has paused. Post-cutoff prices that nobody has read are the holdout of any later campaign. No work is done on them.
- **Process:** pre-registration of statistical criteria; fresh-session bug hunts; the two-round stop rule; the roles.

### Parked: no work until the named condition (section 4)

- Branches `stage7` and `claude/lean-l1-kernel-defects-h273e5`; `reference/lean`; the Lean engine; the nine-defect engine; O1's bound; the delisting corpus; C5.6's calibration.
- The gate's holdout test and search screens, with the defects Argon found.
- Branches `thesis-refreeze` and `thesis-split`, and on `main` the perp-specific `thesis/market.py`, `thesis/positions.py`, `thesis/scoring.py` and `thesis/SCORING.md`, which are hash-frozen and leave only with a fork.
- The swarm (stage 4), agent memory, and the DSL-for-agents study.
- The stage 3 forward window: it lapses on 2027-01-31 with nothing registered in it. Its prices stay unread.

### Deleted

- **Code, when study 2's build forks the thesis track:** the Monday benchmark, the snapshot state machine, readiness, the prewarm, the ablation and no-reading arms and their briefs, the cluster graph, the round-named tests.
- **Criteria scope,** by dated revision and never by edit (`criteria-notes.md`).
- **Paper:** `paper-changes.md`.
- **`CLAUDE.md` rules,** proposed for the advisor's decision, each because its failure can no longer happen:
  - "a source-blind red team after each kernel milestone" (Reviewers): no kernel milestone is scheduled.
  - "the Lean engine with OCaml plumbing is deferred with stage 7" (Tech): say "parked" once, under Frozen identities.
  - "Before any work on stage N" (Pre-registered criteria): read "study" for "stage".
  - "The thesis track's forward use is its own design" (Holdout): becomes "a forward study's evidence starts at its freeze".

## 8. Stop rules

**Study 1.**
- It ends at a boundary or at 60 markets. There is no extension.
- It does not start if a model-free check of section 6 fails. That sends the design back to the architect.
- Five consecutive sessions lost to one operational cause pause it; they still count.

**Study 2.**
- It ends with the claim when cash reaches 20, and as a loss when the mirror does.
- Otherwise it ends not confirmed: at week 52 unless the human continues it, when the model snapshot is retired, when the venue withdraws permission, or whenever the human stops it for cost. None of these can create a rejection, because the bound holds at every stopping time. Continuing past week 52 is free of statistical cost for the same reason.
- A scientific change is a new instance with a new account. Instances are never pooled.

**The program** pauses for the human's decision when study 1 has ended without its upper decision and study 2 has ended without a rejection. That state means neither capability was shown at the stated power for this model on a retail budget. It is published as that, with the bounds, and not as absence. What survives is the pair of frozen instruments: a new frontier model is a rerun of two protocols, not a rebuild.

Nothing is rescued by lowering a threshold, pooling instances, or reading the forward window.

## 9. Unsure, and where to attack

1. **The edge.** The prior is parity before costs. At 4 cents a dollar the study takes two years. Whether that is worth the personal account's usage is the human's call (open question 1).
2. **The count.** How many distinct events an agent can read about settle within seven days on the certified venue, outside sports and ladders on prices. I have not counted, and the supply may be mostly ladders.
3. **Displayed depth.** Walking a recorded book assumes it was there to hit. Thin books refill slowly and a snapshot may be cached.
4. **The stake rule.** Half Kelly from the agent's probability rewards calibration and punishes overconfidence up to the cap. A fixed fraction is simpler and ignores variance. Simulation under miscalibrated probabilities decides.
5. **Cash as the statistic.** It understates wealth by the open stakes. The pause repairs the end of the path and not the middle.
6. **The mirror.** With costs near 3% of stake and no skill it grows about that much a turnover, so "loses" also takes years.
7. **The pick as the discovery event.** An agent that finds the plant and ranks an overfit program above it scores a miss. So does G100. The reported any-evaluation rate shows how often.
8. **Independence across markets in study 1.** Sessions are isolated and seeds fixed, but a silent change of the served model within three weeks would break identical distribution. The harness pins the id; the provider may not.
9. **Whether an older model is reachable at all,** and its cutoff.
10. **The yardstick rows of section 3** rest on counts I estimated.
11. **Venue facts** are from memory or from GPT's fetches, and none is certified.

## 10. Disposition of GPT's findings

| | Finding | Disposition | What changed |
|---|---|---|---|
| 1 | A common-shock null defeats the Student protocol | Accept | The cause is the test, not the admission rules. Study 2 is judged by an account's cash under Ville's inequality (sections 2.5, 5.1). The null and the claim are now negations of each other |
| 2 | Missing marks and unexecutable fills | Accept; the fix differs from the one proposed | No marks exist. A stake leaves cash at registration and a payout enters when recorded, so a missing record can only lower the statistic (5.7, property 2). Acquisition is not frozen; it is shown unable to raise the statistic. Fills walk the recorded book at a reference stake; staleness stays a named qualification |
| 3 | "Exact capture" is not expected net return | Accept | Discovery claims no expectation: it is a pathwise alignment of holdings rebuilt from fills, on the session's pick (section 6) |
| 4 | The SPRT establishes neither endpoint | Accept | The decisions are renamed for what they establish, with the exact table; a crash is named as part of the estimand; judging the pick closes evaluate-and-discard |
| 5 | Calibration does not make a known null | Accept | The baseline runs on every study market and the test is paired. No rate is certified. 0.2 is a stated choice for power |
| 6 | The wall confuses the gate with an information limit | Accept | Two numbers, 4.98 and 26 (sections 2.1 to 2.3). "Lacks only a confirmer" is withdrawn; B also needs a re-derived test |
| 7 | Counts, weighting and capital | Accept | Stakes are fractions of cash, so capital binds by construction. The breadth ratio and the throughput quota are gone. Power is simulated across prices. The count comes from the certified venue's own census, as an upper bound |
| 8 | Non-rejection is not absence | Accept; partly on lifetime error | Three named outcomes, with the mirror as the only negative (5.2). Q2 is declared unanswered. No error budget is spent across instances: a rejection is a candidate, stage 11 is its replication, and each report states its ordinal |
| 9 | Venue portability and the certificate | Accept | The venue is a designated exchange the human could trade on, certified first (5.5) |
| 10 | The market price is not an exact comparator | Accept | Edge is net return per dollar of all-in cost. The Brier bound carries its condition (2.4). The coin-flip replay is dropped as a control; the midpoint is a diagnostic only |
| 11 | Forward means unknown outcome | Accept | Open market at the recorded book, registration at that record's time, no backdating, an immutable model snapshot (5.3, 5.7) |

Its numerical notes: the noncentral-t figures are moot with the Student test; A3 is now stated as a prior wherever it is used; section 3's table is labelled as the yardstick.

## 11. What survives from the Fable 5.1 design on `thesis-split`

Revision 1's section 10 compared the two designs blind and is in git. Study 2 still carries from it: C10.2 as two guarantees, with the transcript audit failing closed as a report line and a failed session's purchases kept; each session's shown universe as a recorded disclosure; the search API conditions, and its route of reading result pages directly (open question 4). For the parked perp instance: lazy reads of immutable history, the base rate computed at report time, and the deletions in its build plan's steps 5 to 12. The two Bonferroni looks and the week as the unit, which revision 1 adopted from it, are superseded by the account. Its claim, the paired contrast on perps, stays discarded for the reason in section 2.4.

## 12. Open questions for the human

1. **Whether study 2 runs, given its honest odds.** Under an exact test a rejection within a year needs about 8 cents of net edge per dollar staked at weekly turnover, the prior from published benchmarks is parity before costs, and at 4 cents it takes two years. I recommend running it: it is the only forward design here whose test cannot be fooled and whose result you could trade, and it costs about one account. But it is your usage.
2. **The venue.** Kalshi or Polymarket US, certified as section 5.5 lists. It needs your account if the API needs a key, and it is where stage 11 would trade, so your eligibility there is part of the certificate.
3. **Q2.** The program no longer claims to test whether reading helps. A no-reading account over the same weeks would, at about twice the usage. I recommend against it until an edge exists.
4. **Reading result pages directly:** one public GET per result page under `robots.txt`, by your operator decision. Section 5.6 assumes no.
5. **A search API certificate.** Study 2 does not freeze without it.
6. **The perp instance as a multi-year record.** It costs about a session a day and cannot inform before 2028 at a plausible effect. I recommend against.
7. **The Polymarket recordings already made.** The design reads none of them. Whether they are kept, and whether anything may ever read them, is a terms reading and yours.
8. **Argon's findings on the paper:** `argon-paper-findings.md` ends with a recommendation for you to decide.
