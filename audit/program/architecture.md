# The research architecture (revision 4)

Written 2026-11-11 21:11 UTC (16:11 EST) by Claude Fable 5.2 (`claude-fable-5-2`), session "architect: revision 4", on branch `rearchitecture`. Earlier revisions: 1 at `git show 51fd365:audit/program/architecture.md`, 2 at `35cf871`, 3 at `337619f`. Revision 3 re-derived the program from its root; Argon reviewed it and said do not approve (`audit/reviews/2026-11-11-argon-web-rearchitecture-r3.md`). This is the first fix round of that re-derivation. It is a design awaiting the advisor's decision; nothing here is decided until it is logged in `audit/decisions.md`.

**Read:** revision 3; Argon's review of it; `audit/decisions.md` from 2026-11-11 20:41 UTC (15:41 EST); the advisor's brief with the human's direction of 2026-11-11; `gate/markets.py` lines 150 to 234; the fields of `audit/stage3/null-v3.jsonl`. **Not read:** the paper, any other code, the thesis track, anything under `data/`, any venue's terms. Citations from memory are *leads*. **Run:** `audit/program/arithmetic.py.txt`, which prints every derived number here; cited numbers carry their source.

**The result, in six lines.**
1. Argon is right that revision 3 overstated the wall, by about two. An exact test that stops at its threshold needs `8.59 / e²` bets, not 11.8, and the gate's Sharpe 4.0 at two years is its loss cap, not a law: with the rule's own loss bound it is 2.07, against the yardstick's 1.76.
2. No forward study of a reading agent has honest power yet. The number that would have to change is one product: independent bets a week times net edge squared, at least 0.083. That is 33 a week at 0.05. Nobody has measured the count.
3. A frozen rule with a forward Sharpe of 2.07 can now be confirmed in two years. The only rules with evidence near that are published ones with live records, so the replication the human proposes has a place: it is the positive control of the confirmer, as study 1 is of the search (section 6).
4. Study 1 is kept and fixed at six causes. Discovery is a majority over fresh twin pairs drawn for each market, which needs no estimate, no shared sample and no `K`.
5. The program is the wall with matched numbers and two positive controls: can the agent find an edge that exists (study 1), and can the confirmer confirm one that plausibly exists (study 2).
6. I do not recommend stopping after study 1. Study 2's first result needs no waiting, and its forward test costs replays of recordings that already run.

## 1. What this round traces to

Revision 3 found that two rounds failed on power computed for an idealization. It then did the same thing in the other direction, three times:
- **A terminal threshold for a stopped test.** It asked for wealth of 20 at the end. The test stops when wealth first reaches 20, which is likelier: the power at revision 3's count is 0.896, not 0.80.
- **One settlement timing taken as the design.** Its account paid every purchase at the week's end. That was revision 2's event calendar, not a property of bets on perps, and it starves the stake.
- **The gate's cap taken as a law.** The gate bets at most `1/L` with `L = 2`, a hundred standard deviations of a step. `L` is the rule's own worst loss, which a rule on isolated margin sets itself.

Study 1 carried a fourth instance: its measure was a mean estimated on one shared sample and described as a property with an error of 3·10⁻⁵.

**What stood.** The validity arguments again. Argon's one attack on the account's bound gives no failing example (section 9, finding 4), and the size of study 1's test held under every joint law. What moved is power, in both directions, and the meaning of study 1's claim.

## 2. The binding constraint

### 2.1 The yardstick

A claim tested on `n` independent observations with standardized effect `d` has evidence `z = d·√n`. A one-sided 5% test with 80% power needs `z* = 2.49`, so `n = 6.18 / d²`. For a strategy of annualized Sharpe `S` held `T` years, `T = 6.18 / S²` (Bailey and López de Prado 2012). It assumes independent, near-Gaussian observations and a fixed length. It is a planning reference, not a test.

### 2.2 The exact test and what it costs

A test that assumes only its null is a bet (Ville 1939; Kelly 1956; Shafer 2021; Waudby-Smith and Ramdas 2024; *leads*). If each bet's return is at least `−L` and has non-positive conditional mean under the null, wealth bet at a predictable fraction of at most `1/L` is a non-negative supermartingale and reaches 20 with probability at most 5%, under any dependence and any stopping rule.

- **What it costs.** For independent even bets with net edge `e`, staked at Kelly's fraction, log wealth is near a Brownian motion with drift `e²/2` and variance `e²` a bet. It reaches `log 20` before `N` bets with probability 0.80 when `N = 8.59 / e²` (the reflection formula; Argon wrote 8.67). That is 1.39 times the yardstick's 6.18. Every figure below is at 80% power.
- **The fraction must be chosen before the data.** A bet sized for Sharpe 2 has power 0.77 within two years at a true Sharpe of 2, 0.47 at 1.4 and 0.90 at 2.4. Averaging the bets for Sharpe 1, 2 and 3 is worse at each of those (0.71, 0.41, 0.86), so the fraction is one registered number.
- **The cap is the rule's own loss bound.** Kelly's fraction fits under `1/L` while a step's worst loss is at most `√2190 / S` standard deviations of a step: 23.4 at Sharpe 2, 33.4 at 1.4. The gate has 100, which is why it needs Sharpe 4.0 at two years. A bound must be a property of the tested rule, not a clip applied afterwards: clipping a loss raises the mean and breaks the null. A rule on isolated margin has one, the margin it posts for the step.

### 2.3 The cutoff makes T small

A model's proposals are selected on everything it read before its cutoff `c`, so only data after `c` plus a margin can judge them (the human, 2026-10-23). Today `c` is June 2026 and the pilot's holdout holds 91 judged days by 2027-01-31.

**The wall, with matched power:**

| Length | Yardstick | Exact test at Kelly's fraction | The gate's test, `L = 2` |
|---|---|---|---|
| 91 days | 4.98 | 5.87 | 27.6 |
| One year | 2.49 | 2.93 | 7.4 |
| Two years | 1.76 | 2.07 | 4.0 |

An ordinary edge, Sharpe at most 1, takes 6.2 years on the yardstick and 8.6 under an exact test.

The wall moves only by more independent observations: a longer calendar, a faster source of independent bets, or synthetic markets, where observations are free and which answer Q1 only. **A rule that someone else froze is a longer calendar.** A model's cutoff binds what the model proposes. A published rule is bound by the date we freeze our copy of it, and the evidence that it is worth freezing is a live record, not a backtest.

### 2.4 The effect a forward study can expect

For an outcome a market prices, I take a net effect of 0.05 a bet as the top of what a skilled forecaster keeps, and 0.1 as implausible (a prior, not a derivation). The published evidence is weaker: LLM forecasters at or below the crowd (Halawi et al. 2024; ForecastBench, Karger et al. 2025), and Prophet Arena's best model within the error of the market's own Brier score (arXiv 2510.17638, Table 2, checked by GPT). That is parity before costs. For a frozen rule the best evidence is a live record: the vault the human names reports Sharpe 2.4, about 1.4 recently.

## 3. What is certified today

The project is academic (the human, 2026-11-11): a study of what can and cannot be confirmed about an agent's edge. A venue need not be tradeable by the human, and stage 11 is gone.

- **Hyperliquid, for reading:** its public info API, and its S3 archive with 5-second L2 books from 2023-04-15 (`venue/sources.toml`, `[hyperliquid]` and `[hyperliquid-archive]`). The certified recorders run.
- **The sources with `retrieval = true`:** public statistics, filings and forums.
- **No event-contract exchange** (`audit/decisions.md`, 2026-11-11 17:25 UTC (12:25 EST) and 17:39 UTC (12:39 EST)), and no search API.
- **Synthetic markets** need no certificate.

## 4. The aims against that ground

- **Q1, capability:** when an edge exists, does the agent find it more often than cheap search? Study 1.
- **Q3, edge:** does anything an agent proposes earn a positive expected net return? The table below.
- **Q2, information:** does reading change an agent's forecasts for the better? Argon proposes pairing an agent that reads filings with the same agent without them, on the same contracts and prices. The pairing is fair, and it removes revision 3's objection that the arm without text lacks current data. It does not buy power. Where the two arms agree the difference is zero and carries nothing; where they disagree it is a full bet. So Q2 obeys the same law in discordant forecasts: 859 if reading adds five points of hit rate, 3,437 if it adds two and a half, and two sessions a forecast.

Every forward design on Hyperliquid, with the account simulated as specified: each purchase stakes Kelly's fraction for the true edge, at most 5% of the cash left at that moment, and is paid a day's purchases later.

| Design | Independent bets a week | Net edge for 80% power within two years | Power within two years at net 0.03, 0.05, 0.08 |
|---|---|---|---|
| A reading agent's bracketed theses on perps | 5 | 0.177: a hit rate of 59% | |
| | 10 | 0.108 | 0.00, 0.16, 0.48 |
| | 15 | 0.083 | |
| | 33 | 0.052 | 0.21, 0.76, 0.99 |
| | 60 | 0.039 | |
| A frozen rule replayed on recordings | a return series | Sharpe 2.07 with its own loss bound; 4.0 under the gate | at Sharpe 1, 1.4, 2, 2.4, bet for 2: 0.28, 0.47, 0.77, 0.90 |

- **Settlement timing.** Paid before the next purchase, the edges are 0.170, 0.102, 0.078, 0.050 and 0.037. Paid at the week's end, revision 3's batch, they are 0.202, 0.130, 0.104, 0.071 and 0.056. Below 33 a week the 5% cap binds, which is why 5 a week needs more than the closed form's 0.129.
- **The size.** An account staking the cap on fair bets, 33 a week, reaches 20 within two years in 2.4% of paths. The bound is 5% over any horizon.
- **The law.** Where the cap does not bind: bets a week times `e²` is at least `8.59 / 104 = 0.083`. That is 92 a week at 0.03, 33 at 0.05 and 13 at 0.08.

**A reading agent.** No count is measured. Mine was 4 to 9 theses a week; Argon asserts 45 independent pairs. At my count the study needs a hit rate of 55% to 59% after costs on outcomes a market prices. At Argon's it has 90% power at the top of the prior and 46% at 0.03, for two years of daily sessions on a model that may be retired before the end. **So no forward study of a reading agent has honest power today, and the number that would have to change is the count:** at least 33 bets a week, measured, whose outcomes are near independent. Dependence between bets costs power and never validity. If the thesis track's ledger holds registered theses it already contains a count; I did not read it.

**A frozen rule.** The threshold is now a Sharpe of 2.07, not 4.0. I know no evidence that anything the pilot's agent proposes reaches it, and revision 3's judgment of the systematic line stands at Sharpe 1: power 0.28. A published rule with a live record near 2 is the one case with evidence at the threshold. That is study 2.

## 5. Study 1: the positive control of the search (Q1)

### 5.1 The claim, the measure and the test

- **Claim, on rejection:** on synthetic markets carrying a planted funding edge, the frozen pilot agent's session ends on a program that earns from the plant with a higher chance than G100's search does. The agent may use 100 evaluations and uses what it chooses; G100 uses all 100.
- **Population.** A market is a draw from the pilot's generator at the calibrated plant strength, its seed fixed in the manifest. A session is one run of the pinned model under the frozen stage 3 harness and kernel (`harness_hash` `6a335714…`).
- **Arms.** A, the agent, with its brief and its 100-evaluation budget. B, G100, its search seed derived from the manifest's seed and the market's id. Both run on every study market.
- **A session's pick** is its evaluated program with the highest search-period score, read from the ledger the same way for both arms.
- **A market's fresh pairs.** For study market `m`, 32 markets with ids `m/fresh/0` to `m/fresh/31`, each generated twice: with the study's planted coins and strength, and with strength zero, its twin. The generator seeds every draw from the id, and the strength changes no draw (`gate/markets.py`, `generate`). So twins share funding, premium, innovations and volume, and their unplanted coins are identical. They differ in the planted coins' returns and, under N2, in those coins' variance paths, which feed on the planted return. A twin is the same world without the plant, not the planted world minus a term.
- **A program's effect on a pair** is its score on the planted market minus its score on the twin.
- **A pick earns from the plant** when, on at least 24 of its market's 32 pairs, its effect is at least half the locked reference program's effect on the same pair, and that effect is positive.
- **Null:** for a market drawn from that population, the chance that only the agent's pick earns from the plant is at most the chance that only G100's does. That is, the agent's chance is at most G100's.
- **Test:** Wald's sequential sign test on discordant markets, `θ ≤ 1/2` against `θ = 0.7`, nominal errors 5%, ending at 100 markets. The upper boundary is the claim. The lower boundary is a futility stop and claims nothing.

**Why this measure.**
- **It is a stated property, not an estimate.** There is no mean, no standard error and no `K`. A pick whose chance of beating half the reference on a fresh pair is at most one half passes with probability at most 0.0035, exactly, whatever its variance or tails. At a chance of 0.9 it passes with probability 0.997. The reference is scored on the same pair, so its noise is inside the comparison.
- **It reads the median, and convexity moves the mean.** Argon's construction is a floor under losses: a term of mean zero added above a floor raises the expected score of a program that knows nothing. It does not raise that program's chance of beating half the reference on a given pair above one half. The same holds for a program near bankruptcy, whose twin difference is large and of either sign.
- **Selection cannot act on it.** A session never sees its fresh pairs, so a pick fitted to its own market's noise carries nothing over.
- **Markets stay independent.** Each market's pairs derive from its own id. Nothing random is shared between two markets' classifications.
- **It is the thing the claim names.** Fees, liquidation, clipping and rounding are inside the score, so a program that holds the signal and is ruined does not count.

### 5.2 Why the test is valid

- **Between markets.** The pairs of outcomes are independent: distinct seeds, no memory between sessions, fresh pairs of their own. G100's outcome on each study market is computed before the first session and is a fixed number by then. That changes nothing: the test conditions on nothing, and the manifest, with its seeds and their order, is committed before G100 runs. The null is about the population, not about each market, where G100's chance is 0 or 1.
- **Between the arms.** A discordant market is the agent's win with probability at most one half under the null, whatever the joint law. The size is at most 0.043, by exact enumeration.
- **The model.** The manifest pins the model's id, and every response's id is recorded. A session that carries another id is not counted; the study stops there and reports what it has, for the pinned model. A change the provider does not disclose is invisible to any study of a hosted model, and this one lasts two to five weeks.
- **Operational failures.** A session is void when the harness exits non-zero with no evaluation in the ledger. It is rerun on the same market before the next market is read. The rule is decided before any score of that session exists, so it cannot select on an outcome, and an outage is not an observation of the agent. Three voids on one market pause the study, which resumes at that market. Every other session counts: one that ends by its own choice with no evaluation is a miss, and one cut off after an evaluation is judged on its pick.
- **The stopping rule** is applied in the manifest's order. Sessions run beyond the stop are reported and not counted.

### 5.3 Power, for the rule as specified

The plant's strength is found without a model, by bisection: the strength at which G100's rate on 2,000 calibration markets is between 0.13 and 0.17. The standard error there is 0.008, so the true rate is between 0.11 and 0.19 unless the estimate is off by 2.5 standard errors. The target is 0.15 and not revision 3's 0.2 because the top of the band must still leave the study powered: at 0.25 it did not.

Chance of the claim, at least overlap; independent arms; most overlap (the arms succeed on as few, or as many, common markets as their rates allow):

| Agent's rate | G100 at 0.11 | G100 at 0.15 | G100 at 0.19 |
|---|---|---|---|
| 0.5 | 0.999; 1.000; 1.000 | 0.988; 0.999; 1.000 | 0.943; 0.993; 1.000 |
| 0.4 | 0.981; 0.996; 1.000 | 0.901; 0.968; 1.000 | 0.734; 0.871; 1.000 |
| 0.3 | 0.822; 0.888; 0.998 | 0.568; 0.667; 0.973 | 0.323; 0.396; 0.783 |
| equal to G100's, independent | 0.014 | 0.020 | 0.025 |

- **At the target of 0.5 the claim's chance is at least 0.943 across the band and every overlap,** in 41 markets expected at worst. At 0.4 it is 0.73 to 1.00. At 0.3 the study is not powered.
- **The worst null,** every market discordant at `θ = 1/2`: claim 0.043, futility stop 0.936, 33 markets.
- **Argon's rows.** G100 at 0.3 against 0.5, least overlap: 0.529. That is 16 standard errors of the calibration above the band's 0.17. Rates of 0.25 and 0.2 with 0.1875 in common: claim 0.083, undecided 0.917, since 100 markets hold 7.5 discordant ones and the claim needs nine wins, and three more for every two losses. The study is not powered for a gap of 0.05 and does not say it is.
- **The agent's rate is not known.** In all 20 of stage 3's null campaigns the agent stopped on its own after 6 to 22 evaluations, median 10.5. Those markets held nothing to find, so this says little about planted ones. If the agent stops as early there, the claim is the stronger for it and its chance the smaller. The futility boundary ends a study that is going nowhere: six straight discordant losses.
- **Length.** At 22 sessions a week, an assumption, 100 markets take 4.5 weeks and 41 take 1.9.

### 5.4 What a result may be called

| Result | What it is called | Consequence |
|---|---|---|
| Upper boundary | The agent's sessions end on a program that earns from the planted edge more often than G100's 100 evaluations do | Search is not what the systematic line lacks. It lacks a rule with a Sharpe of 2 (section 2.3). The second cell, a plant with no economic story, becomes worth its sessions |
| Futility stop | Not shown, at the power in 5.3, with each arm's rate and exact intervals | Never "no better": an agent at 0.3 against 0.15 stops here up to 8% of the time and ends undecided up to 36% |
| 100 markets, no boundary | Inconclusive, with the same report | As above |

**Not claimed:** real edge; that agents search better in general; that the agent is better at an equal count of evaluations (reported, not judged); anything about the gate; search apart from prior, since the brief names the family the plant belongs to.

### 5.5 Before any session, and what is reported

**Four walls, all model-free. A failure sends the design back to the architect.**
1. **Twins.** Between a market and its twin, funding, premium, volume and every unplanted coin's prices are identical, and the planted coins' closes differ.
2. **The measure finds what is there.** The reference program's effect is positive on at least 95% of calibration pairs.
3. **The measure pays nothing else.** A locked set of programs that cannot read funding (constant long and short, each at the highest leverage the DSL allows; momentum; reversal; a fixed random position at three leverages) is classified on 200 calibration markets each. At most 1% of those classifications earn from the plant. More means the score pays convexity on most pairs, and the measure is wrong.
4. **The strength exists.** The bisection ends inside the band within eight steps.

**Reported, never judged:** each pick's count of pairs won, by arm; each pick's median effect and the reference's; G100's pick among its first `k` evaluations, `k` being the agent's count on that market, classified the same way; evaluations used and why each session stopped; void sessions and their causes; each arm's rate with exact intervals; every response's model id.

**Cost in kernel evaluations:** 192 a study market to classify both picks and the reference; about 1.2 million for the calibration. The builder times one evaluation first.

**Vertical slice:** the measure and its walls; the calibration; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change. PC1 to PC6 on `positive-controls` are replaced, and that branch is not merged. The build plan is `briefs/1-positive-control.md`.

## 6. Study 2: the positive control of the confirmer

**The place of a replication.** The human proposes replicating published Hyperliquid strategies, the example being a reverse-engineered vault: a long-only ladder that buys dips in large caps, with a reported Sharpe of 2.4 and about 1.4 recently. The program has a place for it, and it is not a search for edge. Study 1 asks whether the agent finds an edge that exists. A replication asks the matching question of the other half of the machinery: given a rule that plausibly has an edge, on evidence better than any backtest, can the confirmer confirm it within the calendar? It can establish three things, in order of cost. **Fidelity, with no waiting:** the replica run by the kernel over the archive, against the vault's own public record over the same dates. This is the first check of the kernel's fills, fees and funding against an account that really traded, and it is a result about the machinery whatever the edge. **Decomposition, with no waiting, descriptive only:** how much of the reported Sharpe is the return of holding the vault's average exposure, and how much is timing. A long-only dip buyer in a rising market earns the market. **Forward confirmation:** the frozen replica under the exact test of 2.2, from the freeze date on. It cannot establish that an agent has edge, or that the vault's record is skill: we know of the vault because it survived, so nothing recorded before our freeze judges anything. Replication of published predictors is an old design with a known finding: returns fall by about a quarter out of sample and by more than half after publication (McLean and Pontiff 2016; Hou, Xue and Zhang 2020; *leads*). The reported decay from 2.4 to 1.4 is in line with it. The advisor plans feasibility; what follows is the design that plan must meet.

- **Claim, on rejection:** from the freeze on, not every four-hour step of the frozen replica, hedged, had a non-positive expected net return given its past.
- **The tested series.** The replica's net return a step, minus a fixed short of its universe sized to its average exposure before the freeze, every leg on isolated margin posted at the step's start. The step's loss cannot exceed the margin posted, and that bound must be at most 23.4 standard deviations of a step. The unhedged series is reported.
- **Test.** Wealth starts at 1 and bets Kelly's fraction for a Sharpe of 2, computed from the replay before the freeze and registered. The claim is wealth of 20. It reads only steps after the freeze.
- **Power within one year and two:** 0.12 and 0.28 at Sharpe 1; 0.22 and 0.47 at 1.4; 0.42 and 0.77 at 2; 0.57 and 0.90 at 2.4. Under no edge, 0.04. Eighty percent takes 1.5 years at 2.4 and 4.4 at 1.4. **So it has honest power only if the forward Sharpe is about 2 or more, and at the vault's recent figure it has less than even odds.**
- **A non-rejection** is "not confirmed", with the realized Sharpe, its standard error (0.71 at two years) and the power row.
- **Why run it at those odds.** The fidelity result stands alone. After it, the forward test costs a replay each month of recordings that already run. And either outcome measures the wall on a real rule, which is the paper's subject.
- **Walls before any forward step:** the archive's dates cover the vault's record; the replica reproduces the vault's daily returns within a tolerance registered before the comparison; the kernel can post isolated margin a step on recorded books. If the kernel cannot, the bound is not real and the test is not exact: back to the architect.

**The account, if a reading-agent study is ever opened.** Cash starts at 1. A purchase pays a stake the agent registers, at most 5% of cash, at the recorded all-in cost `c < 1`, and holds `stake/c` units. A recorded settlement `x` in [0, 1] pays `(stake/c)·x` into cash. The null is rejected when cash reaches 20. **Null:** for every purchase, `E[x | everything that has happened by its registration, recorded or not] ≤ c`. **Validity,** on the world's filtration, to which the recorder's own delays are adapted: let `V` be cash plus, for every position not yet recorded as paid, `stake/c` times the conditional expectation of `x`. A registration lowers cash by the stake and adds at most the stake to the sum, by the null. Between events each term is a martingale. A recording moves a realized payout from the sum into cash and changes nothing. So `V` is a non-negative supermartingale starting at 1, cash never exceeds it, and cash reaches 20 with probability at most 5%, whenever and in whatever order records arrive.

## 7. The program

1. **Run study 1.** It costs TAMU and Cornell sessions and nothing on the personal account.
2. **Plan study 2,** fidelity first. The advisor settles feasibility: the vault's public record, the archive's cost, the kernel on recorded books.
3. **Run no reading-agent study.** Reopen it on a measured count of 33 independent bets a week or more on a certified venue.
4. **Keep the certified recorders running.** They are study 2's forward data and the holdout of any later campaign.
5. **Write the result.** The paper's finding on Q3 is the wall with the three columns of 2.3. `paper-changes.md` lists every edit.
6. **Present the earlier research in one index,** `docs/findings.md`: a row for each completed study with its question, its result in a line, its audit record, and whether it stands. It holds no number that is not in the paper or the record (`paper-changes.md`, last section).

**What is machinery and what is result.** The confirmer of 2.2 with a rule's own loss bound is a specification now and is built with study 2. The frozen gate stays as the pilot's instrument: its judged results came from it and are not rerun.

## 8. Stop rules

- **Study 1** ends at a boundary or at 100 markets, with no extension. It does not start if a wall of 5.5 fails.
- **Study 2** does not freeze if a wall of section 6 fails, and its forward test ends at wealth 20 or at two years from the freeze.
- **The program** pauses for the human when study 1 has reported and study 2's fidelity result is in. Nothing is rescued by lowering a threshold, by reading the forward window, or by calling a non-rejection absence.

## 9. Argon's seven findings

| | Finding | Verdict | Reason, and where it is answered |
|---|---|---|---|
| 1 | Shared `K` couples the markets; twins do not cancel convexity; the 3·10⁻⁵ is false | Holds, except two clauses | Given the manifest's fixed sample the classification was a fixed function, so the size held; but the claim then rested on one draw, on a mean that tails can move, and on a `K` calibrated on one arm. Each market now has its own fresh pairs and the rule is a majority with an exact bound (5.1). The advisor confirmed that twins are not additive. Its `funding * leak` example fails: funding is drawn before the plant and is identical between twins |
| 2 | The negative conclusion rests on batch lock-up, terminal power and the gate's cap | Holds on all three; its two constructions do not follow | 8.59 for 11.8; three settlement timings simulated; 2.07 for 4.0 (2.2, 2.3, section 4). Its 45 independent bets a week are asserted, not measured, and its paired design for Q2 has no power where the arms agree (section 4). The reading-agent conclusion stands with its threshold near halved. The frozen-rule conclusion changes: study 2 |
| 3 | "92% under every dependence" is false across the band, and rows were computed and not shown | Holds | 0.758 at the band's edge. The band is now 0.11 to 0.19 from 2,000 calibration markets, every row is in 5.3, and the least figure is quoted: 0.943. Its (0.25, 0.2) row gives a claim of 0.083, not 0.321, and the study does not claim power there |
| 4 | Outcome-dependent delays break the account's bound; `late_records` is an artifact | First half does not hold; second holds | No path or law is given on which the bound fails: its example is a Doob martingale throughout. An agent that reads news of an unrecorded outcome and buys at a stale price is the alternative, not a failure. The proof is restated on the world's filtration, where the null lives (section 6). The simulation compared two deployments and proved nothing; it is deleted |
| 5 | G100 is deterministic on a fixed market; the null is an intersection; five crashes can force a futility stop | Holds | The null is about the population of markets and the pinned model, and a change of model id stops the study (5.1, 5.2). A crash on a market G100 won cost 0.51 of 2.94. A session that fails before any evaluation is now void and rerun, by a rule fixed before any score exists (5.2) |
| 6 | Four inconsistencies between the text and the script | Holds on all four | The event-contract rows and their two cost bases are gone with the venue. "Costs of 3 to 5 cents" was a percentage of the stake and is gone. The null line now names its rule (section 4). The script prints every derived number and reads stage 3's counts from the record |
| 7 | The dispositions of paper findings 7, 10 and 11 | 11 holds; 10 in part; 7 does not | 11: at funding shares of 0.05 to 0.25 the bootstrap understates the variance of the mean by 3.6 to 6.8, and it enters the defect table at that share. 10: an upper bound under the tolerance at a Bonferroni level makes each cell harder to pass, so the direction is right; but the suite certifies the tolerance, and a true 0.056 passes 72% of the time because it is inside 0.0625. The paper must quote the tolerance as the certified size. 7: Sharpe 3.5 over 91 days against a threshold of 2 has `z = 0.75` on any test, which is the wall; and a sample's kurtosis is at least its skewness squared plus one, so the radicand is at least `(1 − skewness·S/2)²` and cannot be negative. All in `argon-paper-findings.md` |

Earlier rounds: GPT's eleven findings in revision 2's section 10 (`git show 35cf871`), Argon's ten in revision 3's section 8 (`git show 337619f`).

## 10. Infrastructure

- **Used:** the frozen pilot kernel, `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger; pre-registration of statistical criteria; fresh-session bug hunts; the two-round rule.
- **Running, with no work done on it:** the certified recorders.
- **To build:** study 1's slice; for study 2, an archive reader, the replica, and the confirmer of 2.2.
- **Parked:** the thesis track entire (`thesis/`, branches `thesis-refreeze` and `thesis-split`, Job `thesis-prewarm`), until a measured count; stage 7, the Lean engine, `reference/lean`; the swarm; stages 8 and 9, superseded. The stage 3 forward window lapses on 2027-01-31 with nothing registered in it, and its prices stay unread.
- **Gone:** stage 11.
- **Every stale file and rule** is listed with its edit in `paper-changes.md`.

## 11. Unsure, and where to attack

1. **The score's behaviour on a pair.** I have not read how the score treats a bankrupt program. Wall 3 exists because I cannot argue from the code that no funding-blind program beats half the reference on most pairs.
2. **The reference's effect a pair.** If it is small against a pair's noise, an honest pick fails the majority and both rates fall. Wall 2 catches the reference; a pick with 70% of its effect is not checked before the study.
3. **Least overlap** is the worst case for power and I think it unlikely: easy seeds should be easy for both arms.
4. **The hedge in study 2.** A fixed short sized before the freeze is my choice. A wrong size leaves market return in the tested series, and a rising market would then be confirmed as edge. The decomposition result is the check, and it is descriptive.
5. **Isolated margin on recorded books.** If a step's loss can exceed the margin in the replay, the test is not exact.
6. **The count.** 33 a week is a threshold, not an estimate. Someone who has read the thesis track's ledger knows more than I do.
7. **The prior of 0.05.** The benchmarks test forecasting on given questions, not selection among perps.

## 12. Open questions for the human

1. **Study 2.** A replication as the positive control of the confirmer: fidelity first, then a frozen forward test whose power is 0.47 at the vault's recent Sharpe and 0.90 at its reported one. I recommend yes, subject to the advisor's feasibility plan, with nothing before the freeze judged.
2. **Study 1's changes.** G100's target rate falls from 0.2 to 0.15, the calibration grows to 2,000 markets, and the claim says "more often than G100's 100 evaluations", not "at the same budget". Still at most 100 markets. I recommend yes.
3. **The findings index,** `docs/findings.md`, as the organized presentation of earlier research, with the paper as the home of every number. I recommend yes.
4. **A count for the reading agent.** Reading the thesis track's ledger for theses a week costs nothing and decides whether that line is ever reopened. I recommend the advisor does it, and that no sessions are spent on a count.
5. **The archive's cost.** If Hyperliquid's S3 archive bills the requester (a lead), study 2 spends money. That is yours to approve once the advisor has a figure.
