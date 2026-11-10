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

- **Forward calendar days under a frozen protocol.** They cannot be bought later. The thesis track has run 23 days and banked none; the forward window has run ten days with nothing registered to confirm in it. A day spent perfecting plumbing before a freeze costs exactly as much as a day lost to an outage.
- **Plan usage and the human's attention,** which is why the program below is three small studies in order and not a platform.

### 2.6 Assumptions, stated for attack

- **A1.** `z = d·√n` with a 5% one-sided level and 80% power is the right yardstick. Multiplicity across `k` finalists (Holm) raises `z*` to 2.97 at `k` = 3; sequential looks cost a few percent.
- **A2.** A model's knowledge contaminates all history before `c + m`, for systematic strategies as much as for discretionary ones. If a reviewer can show a class of strategy for which the model's reading could not have selected on pre-cutoff returns, the wall does not bind that class.
- **A3.** `d` ≤ 0.1 per independent bet for priced outcomes. It is a prior from the forecasting and active-management literature, not a derivation. If it is too pessimistic, every forward study below finishes sooner than stated and none is harmed.
- **A4.** Period returns of a predictable portfolio are martingale differences under the null. Stale marks break this for short periods (builder markets over closed hours), which is why the period is a week.
- **A5.** Forward days are unrecoverable and plumbing defects do not change scores. The second half is the identity split's premise (section 5) and is false exactly where an acquisition failure changes what the agent is shown.
