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
- **The gate's cap taken as a law.** The gate bets at most `1/L` with `L = 2`, a hundred standard deviations of a step. `L` is the rule's own worst loss. A rule whose worst step is within a few tens of ordinary steps can bet Kelly's fraction; study 2's dip-buying ladder cannot (section 6).

Study 1 carried a fourth instance: its measure was a mean estimated on one shared sample and described as a property with an error of 3·10⁻⁵.

**What stood.** The validity arguments again. Argon's one attack on the account's bound gives no failing example (section 9, finding 4), and the size of study 1's test held under every joint law. What moved is power, in both directions, and the meaning of study 1's claim.

## 2. The binding constraint

### 2.1 The yardstick

A claim tested on `n` independent observations with standardized effect `d` has evidence `z = d·√n`. A one-sided 5% test with 80% power needs `z* = 2.49`, so `n = 6.18 / d²`. For a strategy of annualized Sharpe `S` held `T` years, `T = 6.18 / S²` (Bailey and López de Prado 2012). It assumes independent, near-Gaussian observations and a fixed length. It is a planning reference, not a test.

### 2.2 The exact test and what it costs

A test that assumes only its null is a bet (Ville 1939; Kelly 1956; Shafer 2021; Waudby-Smith and Ramdas 2024; *leads*). If each bet's return is at least `−L` and has non-positive conditional mean under the null, wealth bet at a predictable fraction of at most `1/L` is a non-negative supermartingale and reaches 20 with probability at most 5%, under any dependence and any stopping rule.

- **What it costs.** For independent even bets with net edge `e`, staked at Kelly's fraction, log wealth is near a Brownian motion with drift `e²/2` and variance `e²` a bet. It reaches `log 20` before `N` bets with probability 0.80 when `N = 8.59 / e²` (the reflection formula; Argon wrote 8.67). That is 1.39 times the yardstick's 6.18. Every figure below is at 80% power.
- **The fraction must be chosen before the data.** A bet sized for Sharpe 2 has power 0.77 within two years at a true Sharpe of 2, 0.47 at 1.4 and 0.90 at 2.4. Averaging the bets for Sharpe 1, 2 and 3 is worse at each of those (0.71, 0.41, 0.86), so the fraction is one registered number.
- **The cap is the rule's own loss bound.** Kelly's fraction fits under `1/L` while a step's worst loss is at most `√2190 / S` standard deviations of a step: 23.4 at Sharpe 2, 33.4 at 1.4. The gate has 100, which is why it needs Sharpe 4.0 at two years. A bound must be a property of the tested rule, not a clip applied afterwards: clipping a loss raises the mean and breaks the null. And nothing bets more than the bound allows: against the null "mean at most zero, loss at most `L`", the only wealths that are exact are those betting a fraction of at most `1/L`. An account that cannot owe has `L = 1`, so the largest exact bet on it is the account itself (section 6).

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
| A reading agent's bracketed theses on perps | 5 | 0.178: a hit rate of 59% | |
| | 10 | 0.109 | 0.00, 0.16, 0.47 |
| | 15 | 0.084 | |
| | 33 | 0.053 | 0.21, 0.75, 0.99 |
| | 60 | 0.039 | |
| A frozen rule replayed on recordings | a return series | Sharpe 2.07 if its own loss bound allows Kelly's bet; 4.0 under the gate; section 6 for a rule that cannot | at Sharpe 1, 1.4, 2, 2.4, bet for 2: 0.28, 0.47, 0.77, 0.90 |

- **Settlement timing.** Paid before the next purchase, the edges are 0.170, 0.102, 0.078, 0.050 and 0.037. Paid at the week's end, revision 3's batch, they are 0.211, 0.139, 0.113, 0.084 and 0.071, counting as cash only what has been paid. Below 33 a week the 5% cap binds, which is why 5 a week needs more than the closed form's 0.129.
- **The size.** An account staking the cap on fair bets, 33 a week, reaches 20 within two years in 2.4% of paths. The bound is 5% over any horizon.
- **The law.** Where the cap does not bind: bets a week times `e²` is at least `8.59 / 104 = 0.083`. That is 92 a week at 0.03, 33 at 0.05 and 13 at 0.08.

**A reading agent.** No count is measured. Mine was 4 to 9 theses a week; Argon asserts 45 independent pairs. At my count the study needs a hit rate of 55% to 59% after costs on outcomes a market prices. At Argon's it has 90% power at the top of the prior and 46% at 0.03, for two years of daily sessions on a model that may be retired before the end. **So no forward study of a reading agent has honest power today, and the number that would have to change is the count:** at least 33 bets a week, measured, whose outcomes are near independent. Dependence between bets costs power and never validity. If the thesis track's ledger holds registered theses it already contains a count; I did not read it.

**A frozen rule.** The threshold is now a Sharpe of 2.07, not 4.0. I know no evidence that anything the pilot's agent proposes reaches it, and revision 3's judgment of the systematic line stands at Sharpe 1: power 0.28. A published rule with a live record near 2 is the one case with evidence at the threshold. That is study 2.

## 5. Study 1: the positive control of the search (Q1)

### 5.1 The claim, the measure and the test

Sections 5.1 to 5.5 were revised four times on 2026-11-12 by Claude Fable 5.2. Each earlier text is at `git show <commit>:audit/program/architecture.md`:
- after Argon's round 4 (`audit/reviews/2026-11-11-argon-web-rearchitecture-r4.md`, findings 3 and 6): `4273da5`;
- after the model fallback found in the pilot's sessions and Argon's round 5 (`audit/reviews/2026-11-12-argon-web-study1-r5.md`): `c46c786`;
- after the four facts from the pilot's transcripts (`audit/decisions.md`, 2026-11-12 15:13 UTC (10:13 EST)): `be96683`;
- at 22:19 UTC (17:19 EST), in session "architect: CS1.1 convergence", after Argon's round 6 (`audit/reviews/2026-11-12-argon-web-study1-r6.md`), for one session a market (5.2), the claim's scope (5.2, 5.4) and wall 5 (5.5): `54c11fb`.

- **Claim, on rejection:** on synthetic markets in which six coins carry a planted drift, set by each coin's lagged funding, the frozen pilot agent's session ends on a program that earns from the plant with a higher chance than G100's search does. The agent may use 100 evaluations and uses what it chooses; G100 uses all 100. Earning is the plant's effect on the program's score, whatever inputs the program reads.
- **Population.** A market is a draw from the pilot's generator at the calibrated plant strength, its seed fixed in the manifest. A session is one run of the frozen stage 3 harness and kernel (`harness_hash` `6a335714…`). Each market has one (5.2).
- **The agent** is that harness as the provider serves it while the study runs. The harness asks for `claude-opus-5-5`, and each response comes from `claude-opus-5-5` or from `claude-opus-4-8`, the client's fallback when the provider's safeguards refuse (5.2).
- **Arms.** A, the agent, with its brief and its 100-evaluation budget. B, G100, its search seed derived from the manifest's seed and the market's id. Both run on every study market.
- **A session's pick** is its evaluated program with the highest search-period score, read from the ledger the same way for both arms.
- **A market's fresh pairs.** For study market `m`, 57 markets with ids `m/fresh/0` to `m/fresh/56`, each generated twice: with the study's planted coins and strength, and with strength zero, its twin. The generator seeds every draw from the id, and the strength changes no draw (`gate/markets.py`, `generate`). So twins share funding, premium, innovations and volume, and their unplanted coins are identical. They differ in the planted coins' returns and, under N2, in those coins' variance paths, which feed on the planted return. A twin is the same world without the plant, not the planted world minus a term.
- **A program's effect on a pair** is its score on the planted market minus its score on the twin.
- **A pick earns from the plant** when, on at least 39 of its market's 57 pairs, its effect is at least half the locked reference program's effect on the same pair, and that effect is positive.
- **Null:** for a market drawn from that population, the chance that only the agent's pick earns from the plant is at most the chance that only G100's does. That is, the agent's chance is at most G100's.
- **Test:** Wald's sequential sign test on discordant markets, `θ ≤ 1/2` against `θ = 0.7`, nominal errors 5%, ending at 100 markets. The upper boundary is the claim. The lower boundary is a futility stop and claims nothing.

**What the plant is, and who earns from it.** Argon's finding 3 holds, and what it breaks is revision 4's wall 3, not the measure.
- **The plant is a drift.** It adds `strength × signal` to a planted coin's return each bar, the signal a clipped function of that coin's funding four hours earlier. Funding is persistent and is not centred on the signal's zero. So the drift persists and has a mean, and a program can earn from it three ways: by reading funding; by averaging the coin's past returns, which estimates the drift; by a constant position on the side of the drift's mean. For the second, the average's correlation with the drift is 0.43 at a drift of 0.12 step standard deviations and passes one half near 0.2. Argon's 0.516 is an arithmetic slip; its point stands.
- **All three are discoveries.** A twin is the same world without the plant, so a program's effect is what the plant does to its score. A program that wins most fresh pairs earns from the plant on markets it has never seen, and any honest confirmer in that world would confirm it. That is what a search is for. What the program reads is its route, which is reported and not judged.
- **So the claim changes and the measure does not.** Revision 4's wall 3 said that no funding-blind program may earn. That was a statement about routes, it was false, and a momentum program tripping it would have been the measure working. The claim now says "plant" where it said "funding edge" and does not imply that the pick reads funding. Making the plant invisible in prices, as Argon proposes, would change the frozen generator to defend a statement the study does not need.

**Why this measure.**
- **It is a test of a stated property, with an exact operating curve.** Let `q` be a pick's chance of beating half the reference on a fresh pair. The rule is the smallest that classes a pick at `q = 1/2` as earning with probability at most 0.005 and a pick at `q = 3/4` with probability at least 0.9: 39 of 57, which gives 0.0038 and 0.901, whatever the pick's variance or tails. Between the two the step is soft: 0.12 at 0.6, 0.48 at 0.671, 0.99 at 0.8. Revision 4's 24 of 32 passed a pick at `q = 3/4` only 0.59 of the time, which is the second half of Argon's finding 3. The reference is scored on the same pair, so its noise is inside the comparison.
- **A soft step cannot make a false claim.** Both arms are classed by one rule, and G100's rate is calibrated under it. A pick in the soft zone costs its arm some rate, so softness can cost the agent the claim and never give it. How many of G100's picks sit there is measured before any session (5.5).
- **It pays only an effect that keeps its sign from pair to pair,** and the plant's effect on a score has three parts. A score is a mean return over its standard deviation, and the plant moves both.
  - *The drift captured.* Negating every position negates it, and it keeps its sign across pairs. It is what the claim names.
  - *The plant's change in volatility,* which under N2 rescales the whole score. Negating every position negates this too: Argon's round 5 holds, and the earlier text was wrong to count it in the even part. For a program blind to the drift, its sign on a pair is set by the sign of the program's own score on the twin, a fresh coin on every pair. The rule bounds that at 0.0038 for any program, with no wall. It is second order in the drift.
  - *The even part,* what the plant does to a program and its mirror alike: fees against a changed volatility, liquidation, ruin. Argon's convexity is here. It can keep one sign across pairs, so the rule cannot bound it, and wall 3 measures it on mirror pairs of programs.

  With effects exactly opposite, a program and its mirror win disjoint pairs and never both earn, since twice 39 exceeds 57.
- **The reference holds all twelve coins,** and so does every pick. A DSL program is one weight expression applied to every coin (`kernel/DSL.md`), so no program can hold the planted six alone. Half the reference's effect is 0.354 of the effect of an oracle on the planted six, at equal variances. The oracle is not a program a search could return, and Argon's programs concentrated on the planted coins are not either.
- **Selection cannot act on it.** A session never sees its fresh pairs, so a pick fitted to its own market's noise carries nothing over.
- **Markets stay independent.** Each market's pairs derive from its own id. Nothing random is shared between two markets' classifications.
- **It is the thing the claim names.** Fees, liquidation, clipping and rounding are inside the score, so a program that holds the signal and is ruined does not count.

### 5.2 Why the test is valid

- **Between markets.** The pairs of outcomes are independent: distinct seeds, no memory between sessions, fresh pairs of their own. G100's outcome on each study market is computed before the first session and is a fixed number by then. That changes nothing: the test conditions on nothing, and the manifest, with its seeds and their order, is committed before G100 runs. The null is about the population, not about each market, where G100's chance is 0 or 1.
- **Between the arms.** A discordant market is the agent's win with probability at most one half under the null, whatever the joint law. The size is at most 0.043: making an outcome better never undoes a claim, and removing concordant markets never does, so the worst null is every market discordant at one half, and that case is enumerated exactly.
- **The model.** The subject is the harness, and the model is something it asks for.
  - **What the pilot's sessions show.** The harness passes `--model claude-opus-5-5`. Of the pilot's 169 sessions, 60 were answered by `claude-opus-5-5` throughout, 106 by `claude-opus-4-8` throughout, and 3 by one response of the first and then by the second. No other id answered (`audit/decisions.md`, 2026-11-12 15:23 UTC (10:23 EST)). Each of the 109 holds one `model_refusal_fallback` event, and no `claude-opus-5-5` response after it. The share differs by campaign: 19 of stage 3's 40 null sessions, 89 of stage 4's 128 swarm sessions. The 41 sessions outside the swarm all finished with a zero exit.
  - **So the harness fixes no model.** What is frozen and hashed is a request, a client build and a brief. Which model answers is the provider's choice, made in each session and disclosed in each response. "The pinned model" named something the harness never fixed.
  - **The subject is the pilot's agent as it ran.** The study is a control of the pilot's search, and the pilot's search was this mixture: every one of its results came from it. A control of anything narrower would test an agent the pilot did not use.
  - **The share is the study's own.** The provider sets how often a session falls back, and the share moved between the pilot's campaigns, from 0.475 to 0.695. A rate at one share says nothing about another: if the two models earn at different rates, a study at a low share can reach a claim that the pilot's share would not (Argon's round 6). So the claim is of the agent at the shares the study met, and the report gives them (5.4).
  - **The alternatives fail.**
    - *A session with a fallback is run again.* At the pilot's shares, a counted market costs 1.9 to 3.3 sessions, so the 29 markets expected at the target cost 55 to 95, against a window of about 35. The counted sessions would also be the ones a classifier passed, which is a selection on what the agent wrote.
    - *Pin `claude-opus-4-8`.* The model's name is inside the harness hash, so this is a fork, and its subject is one part of the pilot's agent.
    - *Avoid the trigger.* The brief is inside the hash too, and the trigger is a classifier of the provider's that may change on any day.
  - **A session's model is read from its responses, and from nothing else.** The `message.model` of an assistant line is the provider's own statement of who wrote that response. The fallback event is the client's note of why, and it says nothing the ids do not: the 109 sessions with an event are the 109 that `claude-opus-4-8` answered.
    - **The event is not read.** The client writes it after the retried responses it explains (three of them, in `agent-null-3-N2-0`), so a rule that placed it before them would call every fallback a change of model. Its place is the client's bookkeeping, and no rule here depends on the order of a transcript's lines. The transcript is kept whole, with its hash in the run record, for anyone who wants the cause.
    - **What is recorded.** For each session: every id that answered, in order of first appearance, with its count of responses.
  - **What is fixed.** The manifest names the ids that may answer, `claude-opus-5-5` and `claude-opus-4-8`. A session whose every id is one of them is the agent's.
    - **A session answered by both** is the registered agent, and is judged like any other: three of the pilot's are such. The report gives the agent's rate for each set of ids. The sets are not arms. A refusal can come at any request, so a session that runs longer is likelier to hold both ids, and a search runs longer when it is finding less (Argon's round 6).
    - **A session answered by any other id** is not the agent's. Its market is the agent's miss, whatever its ledger holds, and the runner stops there for a person (one session a market, below). A study that met a passing fault goes on under the same manifest, and one whose provider has changed the agent is ended by hand (5.4). The text before this ended the study at the first such id, so one stray line could end it (Argon's round 6).
  - **The client's own lines.** When a request fails, the frozen client writes an assistant line of its own, under the id `<synthetic>` (`audit/decisions.md`, 2026-11-12 15:29 UTC (10:29 EST)). It is not a response. The manifest names that id as the client's, and the reader passes over its lines as it does over a line that does not parse. The probe made one kind of failure, a refused connection. A line of the client's under an id the probe did not show makes its session a miss, and costs one market.
  - **Validity.** The null is stated for each market's session: on every market, the chance that only the agent earns is at most the chance that only G100 does. The share of sessions answered by each id may drift during the study, and the size holds, because it is enumerated for every such sequence of markets (between the arms). A claim then says that the null failed on some of the study's markets. It is about the agent at the shares the study met, and not about their average or the pilot's.
  - **A change the provider does not disclose** is invisible to any study of a hosted model.
- **One session a market.** Each study market gets one session, and its line is written from what that session left, however it ended. The pick in its ledger is classified. A session with no pick is the agent's miss, and so is a session that is not the agent's. No session is run again.
  - **Why a miss is always safe.** Replacing a market's outcome by a worse one never makes a claim (step 6's dominance, L6.4), and a miss is the worst outcome the agent's arm has. So a rule that turns a session into a miss keeps the size at 0.043 whatever ended the session. A rule that runs it again keeps the size only if what ended the session says nothing of how it would have gone.
  - **Three things are wanted, and the frozen harness allows two.** No selection among sessions; no outage scored against the agent; no change to the harness, which cannot resume a session. The first is the one a criterion exists for, since it guards the claim. The second costs power, and is stated.
  - **A rerun after an evaluation selects.** A search that is losing runs longer, so it is cut off more often, and each rerun is a fresh draw that G100 never gets. In Argon's round 5 a rate of 0.15 becomes 0.187 and the size 0.114.
  - **A rerun before any evaluation selects too.** Such a session has seen no score, but which model answered can both end it early and change its chance of earning. In Argon's round 6, two models served half and half earn at 0.08 and 0.22, which matches G100's 0.15. If the first dies before its first evaluation half the time and is run again, the counted rate is 0.173. Were each rerun to hide a loss, the size would be 0.073 at one rerun, 0.117 at two and 0.338 at five, by exact enumeration (`reruns`).
  - **A second decision beside the reruns does not repair it.** The text before this ran such a session again, and reported a second decision in which each market that had a rerun counted as a miss. Argon's round 6 found two faults.
    - *The second decision could not claim.* The runner stopped where the first decision crossed. There its sum is below `log 19 + log 1.4`, and one earning market turned into a miss takes away at least `log 1.4`.
    - *The claim should need the second decision.* But that decision never reads a rerun. With it as the judge, each rerun spends a session, of about 35 in the window, on an outcome that nothing judges.

    So the second decision is the only one, and no session is run again. It claims on exactly the paths where Argon's gated rule would.
  - **What it costs.** A session cut off after an evaluation is judged on a search it did not finish, and one cut off before its first is a miss. The 41 pilot sessions outside the swarm all reached a designed end, which bounds the share that does not at 0.07. The power at that share, and at one session in five, is in 5.3. The report lists every such session.
  - **A person looks after each.** A designed end is a finish with a zero exit, the turn limit, or the wall time (`gate.agent.campaigns.crashed`, stage 3's definition). When a session reaches none, or is not the agent's, the runner writes the market's line and stops, and the next start goes on at the next market. One fault then costs one market. Without the stop an outage would spend a market with every failed launch, and a manifest's markets are never replaced.
- **The stopping rule** is applied in the manifest's order. Sessions run beyond the stop are reported and not counted.
- **An early end.** The study may be ended before a boundary, for any reason: it then ends undecided at its last judged market. The size holds, because a claim is made only at the upper boundary within the first 100 markets, and ending sooner only removes paths to it. For the same reason a stopped study may resume later, at its next market and under the same manifest, on any account.

### 5.3 Power, for the rule as specified

**The strength** is found without a model, in two parts on separate markets.
- **The search.** A bisection on one set of 1,600 markets, until G100's rate there is within 0.005 of 0.15, in at most 12 steps. The same markets at every step make the rate one function of strength.
- **The check.** G100's rate at that strength on 10,000 fresh markets must be between 0.12 and 0.18. Its standard error at 0.19 is 0.0039, so the true rate is between 0.11 and 0.19 unless the estimate is off by 2.5 standard errors.
- **Why these sizes.** Revision 4 searched on 400 markets and checked on 2,000 within 0.02. The search's own error, 0.018, then failed the check 31% of the time when a strength existed: the first part of Argon's finding 6 holds. Now a false stop has probability 0.005.

The target is 0.15 and not revision 3's 0.2 because the top of the band must still leave the study powered: at 0.25 it did not.

Chance of the claim, at least overlap; independent arms; most overlap (the arms succeed on as few, or as many, common markets as their rates allow):

| Agent's rate | G100 at 0.11 | G100 at 0.15 | G100 at 0.19 |
|---|---|---|---|
| 0.5 | 0.999; 1.000; 1.000 | 0.988; 0.999; 1.000 | 0.943; 0.993; 1.000 |
| 0.4 | 0.981; 0.996; 1.000 | 0.901; 0.968; 1.000 | 0.734; 0.871; 1.000 |
| 0.3 | 0.822; 0.888; 0.998 | 0.568; 0.667; 0.973 | 0.323; 0.396; 0.783 |
| equal to G100's, independent | 0.014 | 0.020 | 0.025 |

- **At the target of 0.5 the claim's chance is at least 0.943 across the band and every overlap,** in 41 markets expected at worst. At 0.4 it is 0.73 to 1.00.
- **At 0.3 the study is not powered.** The claim's chance falls to 0.32 at G100's 0.19, where the futility stop takes up to 0.24 and the undecided end up to 0.50. Revision 4 quoted these at 0.15 only; the fourth part of Argon's finding 6 holds.
- **Lost sessions.** A session that an outage ends is judged on what it left (5.2), which lowers the agent's rate by the share of sessions lost. At 0.07, the most the pilot's record allows, an agent at 0.5 claims with probability 0.997 against G100 at 0.15 with independent arms, and 0.896 on the worst powered row, against 0.999 and 0.943. At one session in five it is an agent at 0.4: 0.968 and 0.734.
- **The worst null,** every market discordant at `θ = 1/2`: claim 0.043, futility stop 0.936, 33 markets.
- **Argon's earlier rows.** G100 at 0.3 against 0.5, least overlap: 0.529. That is 31 standard errors of the check above the band's 0.18. Rates of 0.25 and 0.2 with 0.1875 in common: claim 0.083, undecided 0.917, since 100 markets hold 7.5 discordant ones and the claim needs nine wins, and three more for every two losses. The study is not powered for a gap of 0.05 and does not say it is.
- **The agent's rate is not known.** In all 20 of stage 3's null campaigns the agent stopped on its own after 6 to 22 evaluations, median 10.5. Those markets held nothing to find, so this says little about planted ones. If the agent stops as early there, the claim is the stronger for it and its chance the smaller. The futility boundary ends a study that is going nowhere: six straight discordant losses.

**Sessions and the window.** The sessions run on the Cornell and TAMU accounts, which are free until about 2026-11-25 (the human, 2026-11-11). At 22 sessions a week, an assumption, that is 44 sessions from 2026-11-11, and 3.1 fewer for each day before the first session. A fallback costs nothing, since its session counts (5.2). A session lost to an outage costs its market's chance of a win.

| Case (agent, G100, overlap) | Expected markets | Claim within 22 | 28 | 35 | 44 | 66 markets |
|---|---|---|---|---|---|---|
| 0.5, 0.15, independent: the target | 29 | 0.32 | 0.55 | 0.75 | 0.89 | 0.99 |
| 0.5, 0.19, least: the worst powered row | 41 | 0.23 | 0.37 | 0.51 | 0.65 | 0.84 |
| 0.4, 0.15, independent | 44 | 0.11 | 0.25 | 0.41 | 0.59 | 0.85 |
| Worst null: either boundary | 33 | 0.39 | 0.53 | 0.66 | 0.78 | 0.91 |
| Equal rates of 0.15, independent: either boundary | 82 | 0.01 | 0.03 | 0.06 | 0.11 | 0.26 |

- **Expected:** 29 markets at the target, 1.3 weeks. **Worst case:** 100 markets, 4.5 weeks, which the window does not hold.
- **The window is short for the study.** TAMU's week resets on 2026-11-14 04:00 UTC (2026-11-13 23:00 EST). If the first session runs that day, 35 sessions are left: the claim is reached with probability 0.75 at the target and 0.51 on the worst powered row. If it runs on 2026-11-16, 28 are left: 0.55 and 0.37. Every day saved before the first session is worth three markets.
- **If the window ends before a boundary,** the runner is stopped, which loses nothing (5.2), and the study resumes later on another account under the same manifest (the human, 2026-11-12 01:41 UTC (2026-11-11 20:41 EST)).

### 5.4 What a result may be called

The report prints the second column word for word.

| Result | Name | Reported with it | Consequence |
|---|---|---|---|
| Upper boundary | The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do | The models that answered, and the share of sessions that each set of ids answered: the claim is of the agent at those shares (5.2) | Search is not what the systematic line lacks. It lacks a rule with a Sharpe of 2 (section 2.3). The second cell, a plant with no economic story, becomes worth its sessions |
| Futility stop | Not shown | The power in 5.3, each arm's rate and exact intervals | Never "no better": an agent at 0.3 stops here up to 24% of the time and ends undecided up to 50%, both at G100's 0.19 |
| 100 markets, no boundary | Inconclusive | The same | As above |
| Ended early, no boundary | Inconclusive at the markets judged | The same | As above |

A study stopped between markets has no result yet, and the report says that it has not ended.

**Not claimed:** real edge; that agents search better in general; anything about `claude-opus-5-5` or `claude-opus-4-8` alone, or about one against the other; the agent at another share of fallback, the pilot's included; that the agent is better at an equal count of evaluations (reported, not judged); that a pick reads funding or names the plant's mechanism (the inputs each pick reads are reported); anything about the gate; search apart from prior, since the brief names the family the plant belongs to.

### 5.5 Before any session, and what is reported

**Five walls, all model-free. A failure sends the design back to the architect.**
1. **Twins.** Between a market and its twin, funding, premium, volume and every unplanted coin's prices are identical, and the planted coins' closes differ.
2. **The measure finds what is there.** The reference program's effect is positive on at least 95% of the check markets' pairs.
3. **The measure pays only the drift captured.** A locked set of five mirror pairs of programs, each the other with every position negated: constant long and short at the highest leverage the DSL allows; momentum and reversal; a position blind to the plant at three leverages, each with its negation. The blind position is long the coins whose week of volume is above the cross-section's mean and short the others. The generator draws volume apart from funding, returns and the plant, and twins share it, so the position is the same on a market and its twin. It also turns over, which a fixed position would not, and a position that never trades pays no fee for the even part to show. On a pair of markets, a mirror pair's even part is the mean of its two members' effects: what the plant does to both alike, so not the drift. Each mirror pair's even part is classified as if it were a pick on 200 calibration markets. For each mirror pair, at most 4 of its 200 classifications earn: under the rule's bound of 0.0038 each, some pair exceeding that has probability 0.005. The count was 9 of the 1,000 pooled, which let the one pair that trades often earn on 9 of its 200 (Argon's round 5). More means the score pays fees, liquidation or ruin on most pairs, and the measure is wrong.
4. **The strength exists.** The search ends within its 12 steps and the check is inside the band.
5. **The plant is not free.** Constant long and constant short read nothing, so an agent could submit one with no search. Each earns on at most 14 of wall 3's 200 markets. The wall has to show that such a program earns less often than G100 does, and G100's rate is at least 0.11 (5.3). A constant that earns at 0.11 or more passes with probability at most 0.039, and an agent that submits a constant earning less often than G100 is under the null. The count was 51, the upper tail of a program at the band's top. That tested the wrong direction: a constant earning at 0.255 passed it half the time, and an agent submitting that one claims with probability 0.40 against G100 at 0.15 (Argon's round 6). A constant at 0.03 passes with probability 0.999, one at 0.05 with 0.92, and one at 0.07 with 0.57. A stop near those rates may be the wall's 200 markets and not the plant, and the architect then measures the constant on more.

**Reported with the walls, never judged:**
- each mirror-set program's own rate of earning at the study's strength, which is how much of the plant can be earned without reading funding;
- the count of pairs won by each of G100's picks on the check markets, which shows how many picks sit in the rule's soft zone.

**Reported with the result, never judged:** each pick's count of pairs won, by arm; each pick's median effect and the reference's; the inputs each pick reads; G100's pick among its first `k` evaluations, `k` being the agent's count on that market, classified the same way; evaluations used and why each session stopped; the sessions that reached no designed end, with their evaluations and how they ended; the sessions that an unnamed id answered; each arm's rate with exact intervals; each session's model ids with their counts of responses; the agent's rate for each set of ids that answered a session, and each set's share of the sessions.

**Cost in kernel evaluations:** 342 a study market to classify both picks and the reference, and 114 more for each earlier best of G100's, about five a market; about 8.0 million for the calibration, 10.1 million at most, and 0.25 million for wall 3. One evaluation took about 9 ms here (100 in 0.88 s, `gate/control/tests/test_pick.py`), so about 20 core-hours. The builder times it first.

**Laws first.** Each step of the build has laws: properties that hold for every input, written by a session other than the builder and checked on random inputs before the code exists. The laws that the judged number rests on, the rule's bound and the sequential test's size, are also proved in Lean. They are in the build plan.

**Vertical slice:** the measure and its walls; the calibration; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change. PC1 to PC6 on `positive-controls` are replaced, and that branch is not merged. The build plan is `briefs/1-positive-control.md`.

## 6. Study 2: the positive control of the confirmer

**The place of a replication.** The human proposes replicating published Hyperliquid strategies, the example being a reverse-engineered vault: a long-only ladder that buys dips in large caps, with a reported Sharpe of 2.4 and about 1.4 recently. The program has a place for it, and it is not a search for edge. Study 1 asks whether the agent finds an edge that exists. A replication asks the matching question of the other half of the machinery: given a rule that plausibly has an edge, on evidence better than any backtest, can an exact confirmer confirm it within the calendar? It cannot establish that an agent has edge, or that the vault's record is skill: we know of the vault because it survived, so nothing recorded before our freeze judges anything. Replication of published predictors is an old design with a known finding: returns fall by about a quarter out of sample and by more than half after publication (McLean and Pontiff 2016; Hou, Xue and Zhang 2020; *leads*).

**Re-derived on kernel version 2** (`kernel-v2.md`), after Argon's round 4 (D11 to D15) and round 1 on the kernel (findings 4 and 5). Revision 4 took the replica's return series as given and then tried to give it, from outside, a loss bound (isolated margin a step), a hedge (a fixed short) and a bet (a frozen Kelly fraction). Each attack landed on one of the three, and each fix I conceded last session (one cross account with a hedge leg, a threshold of `20(1 + ε̄)`) was attacked again. The cause is one: a loss bound, an exposure and a bet size are properties of an account, so the tested wealth must be an account.

### 6.1 The test

- **The account.** The frozen replica runs in the kernel as one cross-margined account, long only, every size a fraction of its current equity. `W` is its equity at mids over its starting equity, read at the end of every five-minute step.
- **The loss bound (D11, conceded and re-derived).** An account that cannot owe has `W ≥ 0` (law L6), and that is the whole bound: no margin a leg, no threshold to correct. At a leverage of 1 it needs nothing of the venue, since a long bought with cash is not liquidated by any price; only funding can take cash below zero, and the kernel's liquidation covers that. Above 1 it rests on the venue bearing a shortfall (assumption V7), so a certificate of that comes first. The test ends, not confirmed, at the first liquidation.
- **What the bound costs.** No exact test bets more than the account does (2.2). Kelly's bet needs a worst step within 23.4 ordinary ones. A ladder's is far outside: a full ladder holds 27.6 first buys, the vault's cycles held 1.99 on average, and 78% never passed the first. An account with room for its own worst case is nearly idle on an ordinary day. Isolated margin bought a tighter bound only by turning the rule into one that liquidates through its own ladder (round 4, finding 1), which is a different rule with no live record.
- **The benchmark (D12, conceded and re-derived).** A null that holds for every rule without skill, whatever the market's drift, must give the benchmark the rule's own exposure at every step: with exposure `e` and benchmark exposure `ē`, a step's expected excess is `(e − ē)` times the drift, which no one knows. So the benchmark is not a position. It is the unit wealth is measured in:
  - `B` is a basket's wealth: over each step it earns `e · r`, with `e` the account's long notional over its equity at the step's start, and `r` the equal-weight mean of the listed coins' mid returns over the step.
  - **The tested wealth is `M = W / B`.** The null: at every step, the expected ratio of the account's growth to the basket's, given the past, is at most 1. Then `M` is a non-negative supermartingale from 1, and reaches 20 with probability at most 5% under any dependence and any stopping.
  - It needs no short, no order, no margin, no funding on a hedge and no hedge delay, so the 10 USD minimum and the initial-margin findings of round 1 have nothing to land on. It is a ratio of two columns of the kernel's report (A12).
  - A step whose basket factor `1 + e · r` is not positive ends the test, not confirmed. At a leverage of 1 that takes every coin going to zero.
- **What the null removes, and what no test can see.** It removes drift along any path of exposure: round 4's shift from 0.25 to 0.65 in a rising market gives a ratio of 1. With it goes market-wide dip timing: a rule that raises its exposure before the market rises is, step by step, the same event as drift, so no test valid under every drift can credit it. What is credited is held coins that outgrow the basket, and fills better than the mid. Two residuals are stated, not removed: a coin whose beta to the basket is not 1 keeps `(β − 1)` of the drift, and coins that are not exchangeable leave a term of second order in a step's return.
- **Earned, and timed.** `W` alone tests "the account earned", which a rising market can satisfy without skill; it is reported and never called a confirmation. `log W = log B + log M` is the decomposition, before the freeze and after. Only `M` is judged (the advisor's decision of 2026-11-14 on my lean).
- **The bet (D13, conceded).** The bet is the account's own sizing: a first buy's notional is the equity times `b / σ̂`, `σ̂` being the coin's own trailing volatility known at the tick, a float the program computes and crosses with `exact(·)`, under a gross cap `G`, the header's leverage. A shift in volatility moves the size with it, so nothing frozen on old volatility remains. `b` is the value that maximizes two-year power in a block bootstrap of the replay before the freeze; `G` is 1 unless V7 is certified. Both are registered at the freeze.
- **The venue.** `pessimistic`, with trades, at registered `λ` and `δ`: every fill it credits is a lot the record shows was offered through the price. The `optimistic` run is reported beside it. Neither bounds the other (kernel A7).
- **Claim, on rejection:** from the freeze on, the frozen replica's account, filled only on flow through its prices, did not grow at most as fast as a basket of its universe held at its own exposure.
- **A non-rejection** is "not confirmed", with `M`, `W`, `B`, the account's realized volatility and Sharpe, and the power row.

### 6.2 Power, said in advance

With the account as the wealth, the bet is the account's volatility. For Gaussian steps (`arithmetic.py.txt`, `study2`), power within two years and the years to 80%:

| Account's yearly volatility | Sharpe 1.4 | Sharpe 2 | Sharpe 2.4 |
|---|---|---|---|
| 0.25 | 0.00; 11.3 | 0.00; 7.5 | 0.00; 6.1 |
| 0.5 | 0.01; 6.7 | 0.05; 4.2 | 0.14; 3.4 |
| 1.0 | 0.28; 4.6 | 0.59; 2.6 | 0.78; 2.0 |
| 2.0 (revision 4's bet) | 0.48; 5.3 | 0.77; 2.1 | 0.90; 1.5 |

- The table is an upper reference: a dip buyer's returns are skewed against it, and the figures are for `W` at the stated Sharpe, where `M` has what is left after the basket. The real figure is the bootstrap's.
- **Revision 4's row is not reachable.** A long-only account without leverage has at most the basket's volatility, and one that keeps room for its ladder far less. I have read no price, so I do not know the row; I expect 0.5 or under.
- **So the forward test is expected to end "not confirmed" at two years, and the result of study 2 that matters is available at the freeze:** the wall for a real rule, as the account volatility an exact test can reach and the years it implies. That is the paper's subject, measured.
- **D13's figure.** A bet of 2 at a Sharpe of 1.4 takes 5.32 years by this document's reflection formula, not revision 4's 4.4; Argon's 6.13 is not reproduced by it. A fraction frozen on old volatility, at 1.5 times the volatility, has a log drift of −0.30 a year.
- **Why run the forward test anyway.** It costs a replay a month of recordings that already run, and its "not confirmed" comes with a measured volatility and Sharpe on dates nobody fitted.

### 6.3 Fidelity, from what can be read (D14)

The vault's equity history cannot be read before 2027-01-31 (`vaultDetails` and `portfolio` take no end time), so fidelity is defined on its 5,806 fills to 2026-10-31. Argon's objection was that a ladder fitted and checked on the same dates absorbs the fill model's errors into its thresholds. The answer is to check each part against something that was not fitted through the kernel.

1. **The ledger, against the venue's own arithmetic.** The fills are fed to the ledger as given. It must give every fill's fee and `closedPnl` to the digits the venue prints, every `startPosition` exactly, every price on the assumed grid and every size in whole lots (V1, V3), and every `userFunding` payment in the period from A9 (that the endpoint takes a start and an end is a lead to check). Any difference is a defect or a wrong assumption. This is a test suite, not a criterion.
2. **The fill rules, against real maker fills.** For each of the 4,956 maker fills, an order of its price and size resting from before: does each rule fill it, and how long before or after the real time? Reported by rule, by the archive's three cadence periods, with and without trades, and on the fast period decimated to 5.4 s. Nothing here was fitted.
3. **The ladder, given the real first buys.** For each of the 2,019 cycles the published ladder and take-profit are started from the real first fill. Under each rule: which levels fill against which really filled, when the cycle closes, and its profit against the real one. The ladder's constants were read off the fills' own prices (facts §7), not tuned through the kernel, so a wrong fill rule cannot hide in them.
4. **The trigger, where nothing was fitted.** The trigger is the one part reverse-engineered through data, so no fidelity is claimed for it before the freeze. After 2027-01-31 the whole replica is compared with the vault's fills in the released window: first buys matched within a registered time. The forward test does not depend on it; the reading "a rule with a live record" does.

**The trades bucket (H11, settled).** `s3://hl-mainnet-node-data` is certified first, as a terms decision the advisor has reviewed. Its sizes are listed before any read. `node_trades` is read for the slow period first (2026-06-21 on, where a wick leaves no trace in the snapshots), then the rest, stopping at 12 USD of the 17.54 left.

### 6.4 Walls before the freeze

- The kernel's build plan is complete and its laws proved (`briefs/3-kernel-v2.md`).
- Layer 1 has no unexplained difference.
- Layers 2 and 3 are reported. For the judged venue, the sum of layer 3's cycle profits is at most the vault's real sum in each cadence period, within a tolerance registered before the comparison: the venue the claim is about does not flatter. This one is a number, so it goes to `audit/criteria.md` with its review.
- The replay before the freeze gives the account's volatility, the bootstrap's power and the share of ladder orders refused for margin, and `b`, `G`, `λ`, `δ` are registered.
- If a wall fails: back to the architect.

### 6.5 Forward data

- **From when.** The websocket recorder (`recorder/RECORDER.md`) has run since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST): `trades` and five-level books about every 0.55 s for every perp, 20-level books about every 10 s on the main dex, asset contexts and hourly listings. Judged steps start at the freeze, which is later.
- **What it lacks.** Settled hourly funding rows, which `fundingHistory` gives for any past range, so they are fetched at replay time. Books deeper than five levels between the ten-second ones: the policy's order cap keeps every order inside five levels, and a liquidation's remainder closes at the last level, against the account. A dated copy of the fee schedule and of each coin's margin tiers, to be recorded daily from now.
- **Reading it.** The first replay runs after 2027-01-31 and monthly from then, so nothing of the pilot's forward window is read before its release. The vault's fills for layer 4 are read then, at once, since the API keeps only the latest 10,000.

**The account, if a reading-agent study is ever opened (D15, conceded).** Cash starts at 1. A purchase pays a stake the agent registers, at most 5% of cash, at the all-in cost `c < 1` of its fill, and holds `stake/c` units. A recorded settlement `x` in [0, 1] pays `(stake/c)·x` into cash. The null is rejected when cash reaches 20; a payout not yet paid is never cash. **Null:** for every purchase, `E[x | everything that has happened by its fill, recorded or not] ≤ c`, the cost being known at the fill and not at the registration. A perp bracket is such a purchase only on isolated margin equal to the stake, with funding deducted, which kernel version 2 does not build until a study needs it. **Validity,** on the world's filtration, to which the recorder's own delays are adapted: let `V` be cash plus, for every position not yet recorded as paid, `stake/c` times the conditional expectation of `x`. A fill lowers cash by the stake and adds at most the stake to the sum, by the null. Between events each term is a martingale. A recording moves a realized payout from the sum into cash and changes nothing. So `V` is a non-negative supermartingale starting at 1, cash never exceeds it, and cash reaches 20 with probability at most 5%, whenever and in whatever order records arrive.

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
| 3 | "92% under every dependence" is false across the band, and rows were computed and not shown | Holds | 0.758 at the band's edge. The band is now 0.11 to 0.19 from the check's calibration markets (5.3), every row is in 5.3, and the least figure is quoted: 0.943. Its (0.25, 0.2) row gives a claim of 0.083, not 0.321, and the study does not claim power there |
| 4 | Outcome-dependent delays break the account's bound; `late_records` is an artifact | First half does not hold; second holds | No path or law is given on which the bound fails: its example is a Doob martingale throughout. An agent that reads news of an unrecorded outcome and buys at a stale price is the alternative, not a failure. The proof is restated on the world's filtration, where the null lives (section 6). The simulation compared two deployments and proved nothing; it is deleted |
| 5 | G100 is deterministic on a fixed market; the null is an intersection; five crashes can force a futility stop | Holds | The null is about the population of markets and the agent as served (5.1, 5.2). A crash on a market G100 won costs 0.51 of 2.94. Revision 4 answered with a rerun fixed before any score exists, which selects on the model (round 6). So a crash is a miss again, its cost in power is stated (5.3), and the runner stops after each one: five crashes need five restarts by a person (5.2) |
| 6 | Four inconsistencies between the text and the script | Holds on all four | The event-contract rows and their two cost bases are gone with the venue. "Costs of 3 to 5 cents" was a percentage of the stake and is gone. The null line now names its rule (section 4). The script prints every derived number and reads stage 3's counts from the record |
| 7 | The dispositions of paper findings 7, 10 and 11 | 11 holds; 10 in part; 7 does not | 11: at funding shares of 0.05 to 0.25 the bootstrap understates the variance of the mean by 3.6 to 6.8, and it enters the defect table at that share. 10: an upper bound under the tolerance at a Bonferroni level makes each cell harder to pass, so the direction is right; but the suite certifies the tolerance, and a true 0.056 passes 72% of the time because it is inside 0.0625. The paper must quote the tolerance as the certified size. 7: Sharpe 3.5 over 91 days against a threshold of 2 has `z = 0.75` on any test, which is the wall; and a sample's kurtosis is at least its skewness squared plus one, so the radicand is at least `(1 − skewness·S/2)²` and cannot be negative. All in `argon-paper-findings.md` |

Earlier rounds: GPT's eleven findings in revision 2's section 10 (`git show 35cf871`), Argon's ten in revision 3's section 8 (`git show 337619f`).

## 10. Infrastructure

- **Used:** the frozen pilot kernel, `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger; pre-registration of statistical criteria; fresh-session bug hunts; the two-round rule.
- **Running, with no work done on it:** the certified recorders.
- **To build:** study 1's slice; for study 2, kernel version 2 (`kernel-v2.md`, `briefs/3-kernel-v2.md`), the replica as a program in its language, and the confirmer of section 6, which is a ratio of two columns of the kernel's report.
- **Parked:** the thesis track entire (`thesis/`, branches `thesis-refreeze` and `thesis-split`, Job `thesis-prewarm`), until a measured count; stage 7, the Lean engine, `reference/lean`; the swarm; stages 8 and 9, superseded. The stage 3 forward window lapses on 2027-01-31 with nothing registered in it, and its prices stay unread.
- **Gone:** stage 11.
- **Every stale file and rule** is listed with its edit in `paper-changes.md`.

## 11. Unsure, and where to attack

1. **The score's behaviour on a pair.** I have not read how the score treats a bankrupt program. Wall 3 exists because I cannot argue from the code that the even part of an effect, which knows nothing of the plant's sign, stays under half the reference on most pairs.
2. **The reference's effect a pair.** If it is small against a pair's noise, an honest pick sits in the rule's soft zone and both rates fall. Wall 2 catches the reference; the count of pairs won by G100's picks, reported with the walls, shows the soft zone before any session. I expect it to be thin, because twins share their noise, and I have not measured it.
3. **Least overlap** is the worst case for power and I think it unlikely: easy seeds should be easy for both arms.
4. **Study 2's claim is narrow.** Measured against a basket at its own exposure, a rule whose whole edge is buying market-wide dips shows nothing, by construction. I derive that no exact test can do better under unknown drift; Argon should try to build one.
5. **Study 2's account volatility.** I have read no price, so the power table's row is unknown until the replay. If it is under 0.5 a year the forward test is a formality, and section 6 says so in advance.
6. **The count.** 33 a week is a threshold, not an estimate. Someone who has read the thesis track's ledger knows more than I do.
7. **The prior of 0.05.** The benchmarks test forecasting on given questions, not selection among perps.

## 12. Open questions for the human

1. **Study 2.** A replication as the positive control of the confirmer: fidelity first, then a frozen forward test. Re-derived on kernel version 2 (section 6), its power depends on the replica account's volatility, which the replay will measure; without leverage I expect it to be low. I still recommend yes: fidelity and the measured wall stand alone, and nothing before the freeze is judged.
2. **Study 1's changes.** G100's target rate falls from 0.2 to 0.15, the calibration grows to 2,000 markets, and the claim says "more often than G100's 100 evaluations", not "at the same budget". Still at most 100 markets. I recommend yes.
3. **The findings index,** `docs/findings.md`, as the organized presentation of earlier research, with the paper as the home of every number. I recommend yes.
4. **A count for the reading agent.** Reading the thesis track's ledger for theses a week costs nothing and decides whether that line is ever reopened. I recommend the advisor does it, and that no sessions are spent on a count.
5. **The archive's cost.** If Hyperliquid's S3 archive bills the requester (a lead), study 2 spends money. That is yours to approve once the advisor has a figure.
6. **Study 1 after the window.** Answered: it resumes on another account (the human, 2026-11-12 01:41 UTC (2026-11-11 20:41 EST)), under the same manifest (5.2).
