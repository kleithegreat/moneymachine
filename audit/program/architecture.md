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
- **The cap is the rule's own loss bound.** Kelly's fraction fits under `1/L` while a step's worst loss is at most `√2190 / S` standard deviations of a step: 23.4 at Sharpe 2, 33.4 at 1.4. The gate has 100, which is why it needs Sharpe 4.0 at two years. A bound must be a property of the tested rule, not a clip applied afterwards: clipping a loss raises the mean and breaks the null. And the bound is each step's own: against "mean at most zero, this step's loss at most `L_t`, known at its start", the exact wealths are those betting a fraction of at most `1/L_t` that step. For a long-only account `L_t` is what it has at risk, so the largest exact bet keeps the wealth fully staked and no more (section 6).

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

**Cost:** in kernel evaluations, 342 a study market to classify both picks and the reference, and 114 more for each earlier best of G100's, about five a market; about 8.0 million for the calibration, 10.1 million at most, and 0.25 million for wall 3. An evaluation is not what a trial costs. A calibration market at one strength takes 51 s of one core, most of it generating, writing and loading its 57 fresh pairs, so the calibration is 352 core-hours and at most 443 at that mean, measured on this PC (`arithmetic.py.txt`, `calibration_cost`). One probed market took 70.5 s there, and the nodes' cores are slower: as probed on 2026-11-15, the 27 cores of this PC, prodesk7 and gmktec take 3.53 s a market together, so the job is 12 hours at one strength, 25 at nine and 31 at 13. The projection is printed and stops nothing, since a run that keeps every trial and no market loses nothing by running (the plan, "The projection is not a wall"). The first costing, 20 core-hours, counted evaluations alone; as first built, with pairs written through the revision store, it was 1,223 to 1,439. A fresh pair is therefore written with only the columns the kernel reads, which gives the same score (the plan's L1.5), nothing is kept between trials, and the job spreads over hosts with a report that does not depend on them (the plan's step 5, L5.6). No definition, constant, wall or size changes, so nothing CS1.1 names does.

**Laws first.** Each step of the build has laws: properties that hold for every input, written by a session other than the builder and checked on random inputs before the code exists. The laws that the judged number rests on, the rule's bound and the sequential test's size, are also proved in Lean. They are in the build plan.

**Vertical slice:** the measure and its walls; the calibration; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change. PC1 to PC6 on `positive-controls` are replaced, and that branch is not merged. The build plan is `briefs/1-positive-control.md`.

## 6. Study 2: the positive control of the confirmer

**The place of a replication.** The human proposes replicating published Hyperliquid strategies, the example being a reverse-engineered vault: a long-only ladder that buys dips in large caps, with a reported Sharpe of 2.4 and about 1.4 recently. The program has a place for it, and it is not a search for edge. Study 1 asks whether the agent finds an edge that exists. A replication asks the matching question of the other half of the machinery: given a rule that plausibly has an edge, on evidence better than any backtest, can an exact confirmer confirm it within the calendar? It cannot establish that an agent has edge, or that the vault's record is skill: we know of the vault because it survived, so nothing recorded before our freeze judges anything. Replication of published predictors is an old design with a known finding: returns fall by about a quarter out of sample and by more than half after publication (McLean and Pontiff 2016; Hou, Xue and Zhang 2020; *leads*).

**Re-derived four times, and what each round found.** Revision 4 gave a return series a loss bound, a hedge and a bet from outside. Rounds 2, 3 and 4 on what replaced it, by Argon and GPT side by side, each found the same three confusions in a new place:
- **A benchmark taken for a null.** A ratio to a benchmark is a fair game for every rule without skill only when nothing the test's wealth can do beats the benchmark. An equal-weight basket was not that (round 2), nor a mix rebalanced daily under a wealth re-staked every step (round 3), nor a mix on the quotes' clock under a wealth whose stake moved at deciding ticks (round 4).
- **The account taken for the test.** The account's equity, its floor and its cash were each asked to make the test exact.
- **A state taken for a flow.** Orders that regained their targets; fills held out of the books until a later quote.

Three rounds of repairs moved the fault one clock down each time, which is what `CLAUDE.md` §1 calls a wrong design. Section 6.1 is derived again from the record's events, and it has no stake, no step and no mark of its own left to put on a second clock. Round 5 judged it a re-derivation at the cause and asked for no other; what it found were faults in the specification, each fixed where it arose (kernel part C). Round 6 confirmed those fixes and found four places where the specification admitted a market, or handed an instrument an input, that its own laws do not hold on; each is closed at the admission or the input, and the ledger, the bar and the claims are as they were (kernel part D). The literature had the parts: the growth-optimal portfolio as the one benchmark that makes every other wealth's ratio a supermartingale (Long 1990; Cover and Thomas 2006, theorem 16.2.1), the best constant mix in hindsight (Cover 1991), a test whose denominator is the null's best fit (Wasserman, Ramdas and Balakrishnan 2020), and a self-financing strategy as the only wealth process a market's null speaks of (Shafer and Vovk 2019). All are *leads*, cited from memory.

### 6.1 The test

**The account.** The frozen replica runs in the kernel as one account at a leverage of 1, long only, with constant sizes: a first buy of a registered notional, the ladder's multiples of it, and starting cash that covers every coin's full ladder at once, so no order is ever refused for margin. Its equity is never an input.

**The derivation.** Each line needs only the ones before it.
1. **The record is a list of events in one order** (kernel A3). At a **price event** one coin's price moves, by a print or a quote, or a unit of it pays funding, or it settles. A coin's price is its latest quote's mid or a later print's.
2. **A test's wealth is a set of books:** cash and units of coins, neither ever negative. Valued at prices, it changes at a price event of a coin by its units of that coin times the move. The units were there before the event, so nothing the event reveals chose them.
3. **Every other change to the books is a trade,** and has a price. A trade at a price no better than the coin's price after its own event can only lower the wealth, whoever chose its size and whenever. A trade at any other price can raise it: an old mid, when a print since has said where the next quote will be, is such a price.
4. **Setting a stake is a trade.** Round 4's wealth was `V ← V × (1 + φ · pnl / a)`. Changing `a` between two quotes changed how much of `V` rode on a lot already held, at the old mid, for nothing. GPT's account did it with a wish that could not fill and gained 0.0087 of log a cycle with no skill; Argon's ladder did it by filling its next level (`arithmetic.py.txt`). No choice of clock for `a` removes this. A stake that can move without a fill is the fault.
5. **So the test trades only when the account does, at the account's prices.** The kernel proves that no fill beats the tape (law T1): a buy is at or above the coin's price after its event, a sale at or below. Then the stake needs no rule to be valid, and no reviewer's construction can reach it by timing one.

**The test ledger** (kernel A12). Cash starts at 1. At a buy of the account's, the ledger buys the same lots at the same price and fee rate, times a scale. At a sale it sells the fraction of its units that the account sold of its position. At a funding payment it pays on its own units. What the venue absorbed is not its. Its wealth `W` is its cash plus its units at prices. It trades in whole lots of its own, `10⁻³⁰` of a unit, so every number in it is exact: the size of a trade is the one thing it rounds, and a size is a scale. A fee rate is from 0 to 1 (kernel A8), so a buy cut to the cash and a sale, which brings the price times one less the rate, both leave the cash at or above zero.

**The stake rule** says what scale. It decides power and nothing else: every scale that is not negative and is fixed before the buy it scales is valid (law K1).
- **A scale for each cycle.** At a cycle's first buy its scale is `φ` of the ledger's cash then, over `d`. Cash is never negative, so no scale is.
- **A depth.** `d` is a registered sum in the account's money. The ledger follows the cycle's first `d` dollars of buys at that scale and nothing after, and every buy is cut to the cash there is.
- **Nothing is set aside.** Round 4's rule kept a budget for each open cycle and gave the next one `φ` of the cash not promised. A funding payment took cash and left the promises, so the cash not promised went below zero, and with it a scale (both reviewers, round 5; `arithmetic.py.txt`). A promise kept beside the cash it stands for is a state taken for a flow, and it is deleted and not clamped: a scale reads the cash and nothing else. The cost is that cycles which go deep together share the cash there is, first come first served, and a smaller `φ` leaves more for the later ones.
- **What the depth trades.** At a depth of the whole ladder the ledger is the account at a larger scale, and a first buy spends 3.6% of `φ` of its cash. At a depth of the first buy it spends `φ` of its cash at once, and sells that lot at the ladder's exit without the levels that lowered the exit. Round 3's figure of 51% invested, from resting one level at a time, was the stake moving without a fill. The replay before the freeze chooses `φ` and `d` (6.5).

**When the ledger ends.** At a funding payment its cash cannot pay, and at a fill that takes the account short. The event is counted first: the payment comes out of `W` as out of any holder's wealth, and since a unit pays at most its price (assumption V16), `W` is still not negative. From there the proof takes `W` as zero, which only lowers it. Nothing is confirmed after, and what was confirmed before stands. The 5% is under V16. A payment above the unit's price shows in its coin's least return, and then nothing is confirmed from that day on; but a path on which none came does not show that none could (GPT, round 5), and without V16 the size is at most `(1 + E[shortfall]) / 20`, the shortfall being how far below zero `W` went.

**Two rungs on one wealth.**

| Rung | Null | Rejected when | Passes without skill |
|---|---|---|---|
| **1, earned** | At every price event, given everything before it, the event's coin is expected to return at most nothing to one who holds it | `W ≥ 20` at a day's end | A market that rose; carry; any risk that is paid; standing as a maker where prints bounce |
| **2, outgrew** | There is a constant mix of the universe's coins and cash, long only and with no leverage, that no holding chosen before a price event can be expected to outgrow over that event | `W ≥ 20 × B̄` at a day's end, `B̄` a certified bound on the wealth of the best such mix in hindsight, and of any coin held | See "what rung 2 covers" |

- **The mix, on the same events.** At a price event of a coin with return `r`, a mix with weight `b` in it multiplies by `1 + b · r`. Weights are not negative and sum to at most 1. A funding event is a return of minus what a unit paid over the price, and a settlement is the coin's last return. When a universe coin's listing ends a new **span** begins and the mix may be chosen anew, over the coins still listed: the ended coin was settled into cash, and admission refuses any event of it after (kernel A3). `B°` is the product over spans of the best mix's wealth in each; cash is a mix, so `B° ≥ 1`.
- **Validity.** At a price event `W` multiplies by `1 + w · r`, with `w` the share of `W` in the event's coin before it: a number between 0 and 1, because cash and units are never negative. Under rung 1's null that factor has mean at most 1. Under rung 2's, its ratio to the mix's factor has. The event's fills then lower `W` or leave it (T1). No fee is negative, and none is more than its notional. So `W`, and `W / B(b)` with the null's mix, is a supermartingale that is never negative, at every event and so at every day's end; `B̄ ≥ B° ≥ B(b)`. Each rung is reached on some day with probability at most 5%, under any dependence and any stopping (Ville; law K3).
- **Nothing is compressed but what telescopes.** Between two of its own trades the ledger's units are constant, so the product of its factors is the change in their value, and `W` at a day's end needs the cash-flow rows and that day's prices, no more (law K1). The mix's product over every event is bounded through three sums a coin (law K2).
- **Both at 5%, together.** `B̄ ≥ 1`, so rung 2's rejection implies rung 1's. If rung 1's null is true, any claim needs `W ≥ 20`; if only rung 2's is, the false claim is "outgrew". Either has chance at most 5%. The nulls need not be nested, only the rejections.
- **Rung 1's null on real prints.** A print at the bid is followed by a higher price more often than not, so the null as written is false of a real book, whatever the rule. Both reviewers looked for a rule that is no maker and gains from that bounce, and found none in a standing book: a take is filled at a quote, after the price is back at the mid, and what was held before the print took it down and back. That is an argument about fills. It does not make the null true, and a maker paid to stand passes "earned", as the table says.
- **What rung 2 covers.**
  - **On every path, with no null: a holding never traded.** One bought at the start from its starting cash, whose cash pays its funding, is a mean of cash and of each coin held alone, weighted by what went into each. So it is at most the best of those, and `B̄` holds the best of those by construction: the report gives, a coin and a span, its first price and the funding a unit paid, and a span's bar is the greater of the mixes' bound and the best of the span's coins held alone. A holding that crosses a span's end is, from there, cash and the coins still listed, so the same holds span by span. Round 4 compared a holding with the one-coin mix and called the difference second order. It is not bounded. A mix pays funding by selling units and a holder from cash, and a coin that charges 4% of its price for 73 hours and then rises a hundredfold leaves a solvent holder at 25.5 and the best mix at 5.1 to 12.8 (GPT, round 5; `arithmetic.py.txt`).
  - **Under the null: every rule.** The null holds when each price event as a whole (which coin it is, what it returns and when it comes) has one law whatever came before. Then the best holding is a constant mix (the lead above), and no rule passes with chance above 5%: not a rising market, a high-beta coin, carry, the choice of coins, or rebalancing at any clock. Round 4 asked this of each return alone, which is not enough: two coins that move in turn, each up 1% at its event, have returns that depend on nothing, and a holder of whichever is due grows 2.01% a pair against the mix's 1.0025% (GPT's finding 5, round 5).
  - **Not covered, and this is the claim's limit.** Where what came before tells of the next event (its coin, its sign or its time) the null is false, and a pass need not mean the rule used anything. Argon's market of round 4 is the case: two coins quoted in turn, the second always against the first. An account that holds half in each and only rebalances grows 1.05 a pair; the best constant mix at every event grows 1.0406, because it must rebalance between the two quotes (`arithmetic.py.txt`). No clock repairs this. On a slower clock the same account is a mix, and a ladder that trades inside the day passes instead. So round 3's sentence, that nothing a constant holding earns at any clock can pass, is **withdrawn**, and so is the name "timed".
  - **Which way real books lean.** Coins there follow each other in the same direction. Then the mix's rebalance between two quotes buys the follower before it moves, and the bar rises above what a holder gets; a print's bounce between bid and ask raises it too. Both make rung 2 harder to pass, and both are measurements, not theorems.
- **The guard is rung 2's own test, run on rules that have no skill.** A null is a statement about laws and a record is one path, so no record shows the null. Round 4 registered rung 2 only where the bar stood above the best hourly and daily mixes, and read a pass as the record being safe. Both reviewers built markets that pass it while a rebalancer at the pairs' own clock outgrows the bar, by 1.0169 a block and 20 times after 178 (`arithmetic.py.txt`). That reading is withdrawn, and this is what is left of it, derived:
  - **What it is.** A constant mix rebalanced at a clock slower than the events' is a rule of the ledger's own kind: never short, paying for what it holds, trading at prices, and using nothing. Under rung 2's null the ratio of any one such rule to the null's mix is a supermartingale as the ledger's is, and the bar is at least that mix, so the rule reaches `x` times the bar with chance at most `1/x`. The ratio to the bar itself need not be one (GPT, round 6). Where one does outgrow the bar, the record has rejected the null by a rule without skill. It is a negative control. The family is the best mix an optimizer finds at each of four registered clocks: a minute, five minutes, an hour and a day. Any mix found is a witness and needs no certificate; being the best in hindsight, as the bar is, it has no level of its own. Lean carries each in the test ledger's books: cash and whole test lots, traded back to the mix at the clock's times at prices and at no cost, each funding event paid from the cash on the units held into it, and ended by the first payment the cash cannot meet. The prices at ticks and the funding events are the engine's own, in its own order, from the trace of a run with no slots at a tick of a minute (kernel A12, B1), so nothing outside the engine says what a coin's price was or which payment came first. Round 5 gave the rule a tick's total of funding. Two coins that pay and charge the same sum within a minute end the rule in one order and not in the other, and a charge at a tick ends it or not as it is taken before the rebalance or after (both reviewers, round 6; `arithmetic.py.txt`).
  - **What it can do.** Refuse: if on the replay before the freeze one of them outgrew the bar at a rate that reaches 20 times within the forward test's two years, rung 2 is not registered (6.5). And be quoted: beside every use of "outgrew" stands the most any of them reached over the bar on the judged record, and where that is itself 20 or more, the report says the record rejected the null without the rule.
  - **What it cannot do.** Show a record safe. The family is finite, a pair's clock need not be in it, and a holder of the coin due to move is no mix at all. A pair astride every minute's end, one coin moving just before it and the other just after, shows all four clocks two coins that move together, and none of their mixes comes near the bar, while a mix traded between the pairs gains 1.0119 of the bar a minute (`arithmetic.py.txt`, on round 6's pair of a quarter up and a fifth down, whose prices the engine admits). A guard that did not refuse says nothing, and nothing is written as if it did.
- **What does pass rung 2.** A rule that used how the next move depends on the past, at any scale. A rule that holds less when volatility is high. Fills better than later prices, net of fees: a maker paid to stand, if `pessimistic` fills are real. And, where the null fails as above, a rule that did none of these.
- **What the events' clock costs.** The benchmark pays no fee and no spread, and in hindsight it gains from each coin's noise from one print to the next. That raises the bar and can only fail to confirm. Its size is the coins' realized variance at that scale, unread until the replay.
- **What was refused.** Argon's `M*`, a benchmark that holds the account's own coins over its own intervals: it removes everything the rule does and leaves its fees. Argon's paired statistic: for a rule that buys after a fall it has a positive mean on independent returns. GPT's permutation test: valid under a null like rung 2's, but it needs the rule replayed on reordered books, which no recording is. Both reviewers' two starting points of round 4, one clock for stake and benchmark: a shared clock still lets the stake move without a fill.
- **The certificate.** `B°` is a maximum over mixes of a product over every price event. The kernel trusts no optimizer and keeps no history. Since `log(1 + x) ≤ x − x²/2 + x³/3` for every `x ≥ −1`, a mix's log wealth in a span is at most `Σ b_c S1_c − b_c² Q_c`, with `Q_c = S2_c / 2 − max(S3_c, 0) / 3` and `S1`, `S2`, `S3` the report's three sums for the coin. For any multiplier `μ ≥ 0`, the largest of that over mixes is at most `D(μ) = μ + Σ_c m_c`, where `m_c` is the largest of `(S1_c − μ) b − Q_c b²` over `b` in [0, 1]: at `b = (S1_c − μ) / 2Q_c` cut to [0, 1] when `Q_c > 0`, and otherwise at an end, `max(0, S1_c − μ − Q_c)`. OCaml proposes a multiplier for each day and span; the least `D` lies at one no larger than the greatest `S1_c − min(Q_c, 0)`. Lean computes `D` and the mixes' bound `(1 − D/n)⁻ⁿ ≥ e^D`, with `n` the product of `2⁴⁰` and the least of 1, 2, 4, … at or above `D`, so that `D < n` always, at `D = 0` too, and the bound's log is within `D / 2⁴⁰` of `D`. A span's bar is the greater of that bound and the best coin held alone, and `B̄` is the product over spans. A worse multiplier can only fail to confirm. The inequality needs every return to be at least minus one; on a record with one below, the bound is not claimed and nothing is confirmed (law K2). The slack is a quarter of each return's fourth power: 0.003 of log in simulation, 0.036 with seventeen crashes of 30%, and large only at returns no book has, where one return of 2 gives a bar of 14.4 against a best mix of 3 (`arithmetic.py.txt`).

**The venue.** `pessimistic`, at registered `λ` and `δ`: a maker fill is credited only on a seller's print through the price. The `optimistic` run is reported beside it. Neither bounds the other (kernel A7).

**Claims.** "Earned": from the freeze on, a ledger that copied the frozen replica's fills at a registered stake, paid for from its own cash and filled only on sells through its prices, multiplied 20 times. "Outgrew": and 20 times more than every constant mix of its coins did, rebalanced at every price event at no cost, and than any of them held. Neither says skill. **The limit of "outgrew" is said beside every use of it** (the human, 6.8): where one price event tells of the next, a rule that knows nothing can outgrow every such mix too, and on this record the most a mechanical rebalancer of the guard's reached was so many times the bar. Both claims say "assuming our orders move nobody" (V10).

**A non-rejection** is "not confirmed", with `W`, `B̄` and its multipliers, the guard's figures, the wealth of the equal-weight basket and of BTC for reference, `W`'s realized volatility and Sharpe, and the power row. A ledger that ended, and a return below minus one, are reported as that.

### 6.2 Leverage

The human allows leverage above 1 if a certificate quotes the venue's rule that an account cannot owe. Three statements, kept apart:

- **A test whose wealth is a floored account's equity is not exact.** Let `A` be what the venue absorbs when the account goes bankrupt before reaching 20, in units of starting equity. Without the floor the equity is a supermartingale under fair prices, negative by `A` at a bankruptcy. Stopping at 20 or at bankruptcy gives `20 · P(reach 20) − E[A] ≤ 1`, so `P(false confirmation) ≤ (1 + E[A]) / 20`, and GPT's construction of round 2 comes within a tenth of it (0.1250 against 0.1372).
- **The test ledger is not that test, at any leverage of the account.** It reads no equity, no cash and no `absorbed` of the account's: only its fills and its funding. A liquidation's close is a sale like any other, booked when it happens. What the ledger buys it pays for from its own cash, so the account's borrowing does not lever it.
- **So leverage buys the test nothing.** The ledger is at most fully invested whatever the account borrows, and that is the wall of 6.3.

The judged account takes a leverage of 1 because leverage adds liquidations and nothing else, not because it is forbidden. No certificate of V7 is needed. The kernel builds cross margin, liquidation and the floor for programs that want them, and reports `absorbed`.

### 6.3 Power, said in advance

For Gaussian increments (`arithmetic.py.txt`, `study2`), power within two years and the years to 80%, by the judged wealth's own volatility and Sharpe:

| Yearly volatility | Sharpe 1.4 | Sharpe 2 | Sharpe 2.4 |
|---|---|---|---|
| 0.25 | 0.00; 11.3 | 0.00; 7.5 | 0.00; 6.1 |
| 0.5 | 0.01; 6.7 | 0.05; 4.2 | 0.14; 3.4 |
| 1.0 | 0.28; 4.6 | 0.59; 2.6 | 0.78; 2.0 |
| 2.0 | 0.48; 5.3 | 0.77; 2.1 | 0.90; 1.5 |

- **Where `W` sits.** That depends on the depth `d`, and round 3's answer, about half invested, came from the stake that moved without a fill. A ledger that copies the whole ladder at `φ = 1` has 3.6% of its cash in the market after a cycle's first buy and 7.2% after two, and 78% of the vault's cycles never pass the first; one that copies the first buy alone is fully in from the start and leaves the ladder's averaging behind (`arithmetic.py.txt`). A coin's yearly volatility is 0.8 to 1 (an assumption until the replay). So `W`'s volatility is in the table's first two rows at the best depth and under them at a faithful one. I have read no price, and the replay says which.
- **Rung 2 costs more.** In a simulated market of 16 coins with no drift, the best mix ends two years at 2.6 times its start at the median and 8.6 at the 0.9 quantile; with every coin drifting 0.5 a year, 7.1 and 23. At the driftless median, a ratio of volatility 1.0 and Sharpe 2 has power 0.31, against 0.59. A real book adds each coin's noise from one price event to the next to the bar (6.1).
- **The last two rows are above full investment,** which no leverage gives the test (6.2). So **the wall for a long-only rule is full investment:** an exact test cannot see a Sharpe of 2 in two years unless the rule's fully staked profit is as volatile as a coin, all the time.
- **The forward test is therefore expected to end "not confirmed".** The table is an upper reference: a dip buyer's returns are skewed against it. The real figure is a block bootstrap of the replay before the freeze, which also chooses `φ` and `d` (`briefs/4-study-2.md`, step 5).

### 6.4 Fidelity, from what can be read

The vault's equity history cannot be read before 2027-01-31, so fidelity is defined on its 5,806 fills to 2026-10-31. Round 2 broke the wall of the last revision: a sum of profits lets a flattered class of cycles hide behind a starved one, and no number about the past shows a rule will not flatter later. The wall is deleted. What replaces it is not a sum:

1. **The ledger, against the venue's own arithmetic.** The fills are fed to the ledger as given. It must give every fill's fee and `closedPnl` as the venue prints them, under one rounding of our exact value to the printed decimals, the mode found for each field on the first hundred fills and then fixed, every `startPosition` exactly, every price on the assumed grid and every size in whole lots, and every `userFunding` payment from A9. A test suite: the step is done at no difference.
2. **The fill rules, against the vault's own fills.** A real maker fill proves one thing with no assumption: at its time an order stood at its price, and a print took it. It does not say since when the order stood, and a level the constants imply that never filled may never have been placed. So nothing is replayed and nothing implied is a wall.
   - **The wall is a statement about the record, not a run.** For each of the 4,956 real maker fills, the trade record holds its print: the same coin and trade id, the same price, the aggressor on the other side, a size at least the sum of the fills matched to it, and the engine's own mark that the coin was not stale at it. The join computes no staleness: a print in the millisecond of the first quote after a gap comes before that quote in the engine's order and is stale there, and a second rule in the join called it fresh (Argon's finding 5, round 5; kernel A3). Where a source has no trade id the match is by coin, time, price and size. A fill with no such print is a print missing from the record, and each is examined; a fill inside a stale span is counted as that (V13) and is not a failure. Then law F0 says `optimistic` fills an order that is live and eligible there. It does not say a history of placements exists that puts one there: an order placed and filled in one millisecond has none (GPT, round 5). Round 3's wall ran each fill as an order of its own, and so met what an order meets and a fill does not: the 10 USD minimum on a partial fill of 2, an arrival quote already through the price, a stale book (GPT's findings 9 and 10, Argon's 7). This is a test, not a criterion.
   - **The measurement runs orders, and has no pass mark.** For each real maker order, its fills joined by order id, one witness order at the fills' price and their total size is placed a registered delay before the first fill, with no other order beside it. It is classed by what happens: refused at arrival because the book was already through its price; under the minimum; stale at the real fill's time; filled by `pessimistic` at the real time, later, or not before the real cycle ended. By role (first buy, level, take-profit), by size, by the archive's cadence period, and by whether the market was falling. This is how late the judged rule is on fills known to be real, and the claim quotes it.
   - **Counted under an assumption, named:** that the vault rested every level its constants imply from its cycle's first fill to its exit. Under it, a `pessimistic` fill of an implied order before the real one, or of one that never really filled, refutes either the assumption for that order or the rule, and the record cannot say which. So these are counts, reported by the same classes.
   - **Also counted:** the cycles that went deeper than `d`, which is what a depth costs; and the vault's fills after their cycle's exit, which the kernel's cancel at a cycle's end leaves out (kernel V17).

3. **The trigger, where nothing was fitted.** The trigger is the one part reverse-engineered through data, so no fidelity is claimed for it before the freeze. After 2027-01-31 the replica's first buys are compared with the vault's in the released window, within six minutes, the time by which a tenth of the vault's cycles have ended (CS2.3, drafted in `criteria-notes.md`). Before the freeze the trigger is fitted on the fills before 2026-09-01 and checked the same way on the two months held back, as a wall (`briefs/4-study-2.md`, step 3). The forward test does not depend on it; the reading "a rule with a live record" does.

**What stays unknown, and is said in the claim.** How the rules treat an order where the vault had none: the replica's own entries. Only the forward comparison of layer 3 bears on it, which is why both claims name the venue's rule and neither says the fills are real.

**Trades are now required** (kernel A7): `pessimistic` fills on prints alone. `s3://hl-mainnet-node-data` is certified first, as a terms decision the advisor has reviewed; its sizes are listed before any read; `node_trades` is read slow period first, stopping at 12 USD of the 17.54 left. If it cannot be certified or afforded, layer 2 and the replay before the freeze cannot run under the judged rule, and that is a blocker, not a reason to fill on snapshots.

### 6.5 Walls before the freeze

- The kernel's build plan is complete and its laws proved (`briefs/3-kernel-v2.md`).
- Layer 1 has no difference, and layer 2's wall no failure.
- The replay before the freeze gives, for each `φ` and depth, `W`'s volatility and Sharpe and the bootstrap's power at each rung; the days on which a ledger ended; the least return of any settlement, against V16; the bar, and beside it the guard's four rules; and the count of taker fills near an earlier one. `φ`, `d`, `λ`, `δ`, the universe, the first buy's notional and the guard's clocks are registered. The rungs and their nulls go to `audit/criteria.md` with their review.
- **The guard can refuse rung 2, and cannot pass it** (6.1). If one of its rules outgrew the bar over the replay at a rate that reaches 20 times within two years, which over 212 days is 2.39 times, then a rule with no skill is on course to pass by itself, and "outgrew" would be a claim about the market. Study 2 then freezes with rung 1 alone and says why. The refusal is a rule fixed in advance and not a test at a level: a mix chosen beforehand gets that far under the null with chance at most 0.42, and the best in hindsight more often. A wrong refusal costs a rung whose power is low (6.3), and never the size of anything; a wrong registration costs a claim about the market. If none did, rung 2 is registered as the narrow comparison it is, with the guard's figures quoted. That they were small is not evidence that the null holds.
- If a wall fails: back to the architect.

### 6.6 The forward test: run it, as a measurement

The human was unsure whether to run a test expected to end "not confirmed". Both reviewers say run it, as prospective validation with a stated budget and reading. I decide the same, for what it measures that nothing else can:
- `W`'s volatility and Sharpe on dates nobody fitted, which says whether the bootstrap's forecast of the wall transports;
- the fill rules against the vault's forward fills on the recorder's books and prints, the best record there will be (layer 2, forward);
- the trigger (layer 3).

**Its budget.** One replay a month from February 2027 (an hour of one core and one builder session); the hourly copies below; and disk. The recorder writes about 1.6 GB a day for every perp, so its 300 Gi volume is full about 2027-05-20; what two years take is to be measured on the volume itself. The human has deferred that choice (6.8), and it is the one cost still open.

**Its reading, registered with the criteria.** It ends at "outgrew", or two years after the freeze. "Not confirmed" is the expected end and is not evidence of absence. Study 2's result is the pair: the wall, measured before the freeze as the volatility a fully staked rule reaches and the years that implies, and the forward measurement of whether that forecast held: the ledger's forward volatility within half a row of the table above, a factor of `√2`, of the replay's (CS2.2, drafted in `criteria-notes.md`). The bootstrap's own interval is not the judge, because where variance persists it covers the forward volatility as rarely as 0.56 of the time at a nominal 0.95 (`arithmetic.py.txt`, `study2_criteria`). Nothing is rescued by reading the window early or by a third rung.

**Forward data.**
- **From when.** The websocket recorder (`recorder/RECORDER.md`) has run since 2026-11-14 03:43 UTC (2026-11-13 22:43 EST): `trades` and five-level books about every 0.55 s for every perp, 20-level books about every 10 s on the main dex, asset contexts and hourly listings. Judged steps start at the freeze, which is later: the vault's public record up to the freeze can influence the decision to freeze.
- **What it lacks** is in the build plan's table: settled funding, fetched at replay time; hourly dated copies of coin rules and fees; the vault's fills, pulled hourly with overlap.
- **Reading it.** The first replay runs after 2027-01-31, and the kernel itself refuses the dates before their release (kernel A13).

### 6.7 The human's four answers of 2026-11-14 14:59 UTC (09:59 EST), in the design

| Answer | What the reviewers said | Decided | Where |
|---|---|---|---|
| 1. `M` or `W`: whatever is most informative | Argon: report `W`, judge a corrected `M*`. GPT: report both, judge one named hypothesis, consider a timing test | Neither alone, and no choice is needed: two nulls on one wealth, "earned" then "outgrew", 5% for the pair. `M*` is refused (it removes the rule); the timing test became rung 2, whose claim round 4 narrowed and the human then chose as "outgrew" (6.8) | 6.1 |
| 2. Leverage above 1 under a certificate: yes | Both: the rule gives a non-negative account, not an exact test | The permission stands for the kernel, which builds leverage and reports `absorbed`. The judged test takes none: its ledger pays for what it holds from its own cash, so the account's leverage cannot raise it above full investment. No certificate of V7 is needed for study 2 | 6.2, kernel A11 |
| 3. `mm` deleted, under a tag, after study 1's last judged run | Both: version 2 then cannot run a market of bars | Version 2 becomes the only kernel, so bars belong in it: as a source whose bars the engine turns into two prints and a quote under four registered assumptions (spread, depth, path, that the extremes traded). No second fill rule, no cost table, no comparison with `mm`. A later cell of study 1 would run there | kernel A16, B4; section 7 |
| 4. The forward test, expected "not confirmed": unsure | Both: run it as prospective validation with a budget and a reading | Run it. It measures the wall's forecast, the fill rules and the trigger on dates nobody fitted. Its budget is a replay a month and disk, and its reading is registered beforehand | 6.6 |

**The account, if a reading-agent study is ever opened (D15, conceded).** Cash starts at 1. A purchase pays a stake the agent registers, at most 5% of cash, at the all-in cost `c < 1` of its fill, and holds `stake/c` units. A recorded settlement `x` in [0, 1] pays `(stake/c)·x` into cash. The null is rejected when cash reaches 20; a payout not yet paid is never cash. **Null:** for every purchase, `E[x | everything that has happened by its fill, recorded or not] ≤ c`, the cost being known at the fill and not at the registration. A perp bracket is such a purchase only on isolated margin equal to the stake, with funding deducted, which kernel version 2 does not build until a study needs it. **Validity,** on the world's filtration, to which the recorder's own delays are adapted: let `V` be cash plus, for every position not yet recorded as paid, `stake/c` times the conditional expectation of `x`. A fill lowers cash by the stake and adds at most the stake to the sum, by the null. Between events each term is a martingale. A recording moves a realized payout from the sum into cash and changes nothing. So `V` is a non-negative supermartingale starting at 1, cash never exceeds it, and cash reaches 20 with probability at most 5%, whenever and in whatever order records arrive.

### 6.8 The human's decisions of 2026-11-14 20:29 UTC (15:29 EST)

Rounds 3 and 4 reduced what no derivation settles to three choices. The human made two and deferred the third (`audit/decisions.md`). Both reviewers of round 5 agree with all three as recommended.

| Choice | Decided | Where it is in the design | To reverse |
|---|---|---|---|
| **1. What rung 2 claims** | **"Outgrew":** the test ledger outgrew every constant mix of its coins at every price event. Never "timed". Its limit is said beside every use, and the guard is measured before the freeze | The claim's words and the limit's sentence, with the guard's figure in it (6.1). The guard, which can refuse rung 2 and cannot clear it (6.1, 6.5). The decision makes rung 2 a narrow comparison, so nothing in the design reads it as more: round 5 withdrew the guard's reading as a record being safe | Register rung 1 alone; nothing else changes. A claim of timing the mean would need another test, and I know of none that is exact at any stopping time without a model of the market |
| **2. Replenishment (V10)** | **Accepted, as a named assumption** in both claims: "assuming our orders move nobody". The count of takes near an earlier one is a diagnostic only | Kernel A7 and A14; the claims (6.1) | A book that remembers what the account took: new state, a second hypothesis about how books refill, a new law and a review round |
| **3. Disk for two years of recordings** | **Deferred:** the human decides later | Nothing is bought or built for it. The forward test's budget names it as the cost still open (6.6) | |

**One thing round 5 added under decision 1, for the human's review.** The bar now also holds each coin held alone with its funding paid in cash (6.1). It can only raise the bar, so "outgrew every constant mix" stays true as worded, and it makes the one statement rung 2 has on every path, that a holding never traded cannot pass, true of perps, which all pay funding. To reverse: drop that term from the bar and say again that a holding's funding is not covered.

**What the deferred decision is about.** One 300 GiB volume on prodesk7, one copy, filling at about 1.6 GB a day for every perp, so full about 2027-05-20, some four months after a freeze. Both reviewers want the size taken from the volume and not from that rate: what is already on it, every stream the recorder writes, and its growth over a measured month, with a margin. That measurement is the advisor's and has not been made.

| Choice | What a run looks like | What is lost |
|---|---|---|
| **a. Add disk before 2027-05-20, sized from the measurement, with a second copy on another node** | The recorder goes on for every perp. New hours are written to the new volume and copied to the second; nothing recorded is moved or deleted (`CLUSTER.md`). The forward test runs its two years on gapless books and prints | Money: on the rate above about 1.2 TB a copy, to be corrected by the measurement |
| **b. Keep 300 GiB, and from a named date record only study 2's 17 coins** | About 150 MB a day (Argon's figure, unchecked), so the volume lasts the two years. Study 2 runs whole, still on one copy | Every other perp's record from that date; and one disk's failure still loses the forward window |
| **c. Neither** | The volume fills about 2027-05-20 and the recorder stops. The forward test ends there, "not confirmed", after four months at a power near zero; it is ended by a dated decision, never run on over a gap | The forward measurement, which is most of what study 2 still offers |

My recommendation stands: a, decided by 2027-03-01 so both volumes are in place with weeks to spare, the second copy being part of the choice because one copy on one node is one failure from losing recordings that cannot be fetched again.

## 7. The program

1. **Run study 1.** It costs TAMU and Cornell sessions and nothing on the personal account.
2. **Plan study 2,** fidelity first. The advisor settles feasibility: the vault's public record, the archive's cost, the kernel on recorded books.
3. **Run no reading-agent study.** Reopen it on a measured count of 33 independent bets a week or more on a certified venue.
4. **Keep the certified recorders running.** They are study 2's forward data and the holdout of any later campaign.
5. **Write the result.** The paper's finding on Q3 is the wall with the three columns of 2.3. `paper-changes.md` lists every edit.
6. **Present the earlier research in one index,** `docs/findings.md`: a row for each completed study with its question, its result in a line, its audit record, and whether it stands. It holds no number that is not in the paper or the record (`paper-changes.md`, last section).

**What is machinery and what is result.** The confirmer of 2.2 with a rule's own loss bound is a specification now and is built with study 2. The frozen gate and version 1 of the kernel (`mm`) stay as the pilot's instrument until study 1's last judged run. Then `mm` is deleted under a git tag, from which the pilot's judged results stay reproducible and are not rerun (the human, 2026-11-14). From then kernel version 2 is the only kernel. Before the deletion the advisor stores the reference evaluator's streams on the C6.4 corpus under a hash (kernel B4) and lists what runs only on `mm`, the gate's search and campaign code included, since it goes to the tag too. `ingest/archive.py` stays, as a test's oracle.

## 8. Stop rules

- **Study 1** ends at a boundary or at 100 markets, with no extension. It does not start if a wall of 5.5 fails.
- **Study 2** does not freeze if a wall of section 6 fails, and its forward test ends at its second rung or at two years from the freeze.
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

- **Used, until study 1's last judged run:** the frozen pilot kernel, `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger; pre-registration of statistical criteria; fresh-session bug hunts; the two-round rule.
- **Running, with no work done on it:** the certified recorders.
- **To build:** study 1's slice; for study 2, kernel version 2 (`kernel-v2.md`, `briefs/3-kernel-v2.md`), the replica as a program in its language, and the confirmer of section 6, a function of the kernel's report.
- **Parked:** the thesis track entire (`thesis/`, branches `thesis-refreeze` and `thesis-split`, Job `thesis-prewarm`), until a measured count; stage 7, the Lean engine, `reference/lean`; the swarm; stages 8 and 9, superseded. The stage 3 forward window lapses on 2027-01-31 with nothing registered in it, and its prices stay unread.
- **Gone:** stage 11.
- **Every stale file and rule** is listed with its edit in `paper-changes.md`.

## 11. Unsure, and where to attack

1. **The score's behaviour on a pair.** I have not read how the score treats a bankrupt program. Wall 3 exists because I cannot argue from the code that the even part of an effect, which knows nothing of the plant's sign, stays under half the reference on most pairs.
2. **The reference's effect a pair.** If it is small against a pair's noise, an honest pick sits in the rule's soft zone and both rates fall. Wall 2 catches the reference; the count of pairs won by G100's picks, reported with the walls, shows the soft zone before any session. I expect it to be thin, because twins share their noise, and I have not measured it.
3. **Least overlap** is the worst case for power and I think it unlikely: easy seeds should be easy for both arms.
4. **Rung 2's null.** It is exact as stated and false wherever one price event foretells the next, which is every real book to some degree. I argue the real direction raises the bar. The guard measures, from below, what a rule without skill gets on the record; it can refuse rung 2 and can never clear it (6.1). A reviewer should build a rule with no forecast that passes on a market shaped like a real one, and say whether a refusal at a rate that reaches 20 in two years is the right line.
5. **No fill beats the tape (kernel T1)** is the one thing the test's validity rests on in the kernel. A reviewer should look for a fill of any kind, under either rule, at a price better than the coin's price after its event, for any way the ledger's units change without one, and for a scale that reads anything but the ledger's cash.
6. **The wealth's volatility.** I have read no price, so the power table's row is unknown until the replay. I expect 0.25 to 0.5 at the best depth and less at a faithful one, which makes the forward test a measurement and not a confirmation, and section 6 says so in advance.
7. **The count.** 33 a week is a threshold, not an estimate. Someone who has read the thesis track's ledger knows more than I do.
8. **The prior of 0.05.** The benchmarks test forecasting on given questions, not selection among perps.

## 12. Open questions for the human

1. **Study 2.** A replication as the positive control of the confirmer: fidelity first, then a frozen forward test. Re-derived after round 4 and corrected after round 5 (section 6): two claims, "earned" and "outgrew", on a ledger that copies the replica's fills and is never more than fully invested. I expect "not confirmed" and have decided to run it as a measurement (6.6). Two of its three choices you have made (6.8): rung 2 claims "outgrew", with its limit said beside every use, and both claims assume our orders move nobody. The third you deferred: disk before 2027-05-20. I still recommend measuring the volume first, then adding capacity for two years with a second copy, decided by 2027-03-01.
2. **Study 1's changes.** G100's target rate falls from 0.2 to 0.15, the calibration grows to 2,000 markets, and the claim says "more often than G100's 100 evaluations", not "at the same budget". Still at most 100 markets. I recommend yes.
3. **The findings index,** `docs/findings.md`, as the organized presentation of earlier research, with the paper as the home of every number. I recommend yes.
4. **A count for the reading agent.** Reading the thesis track's ledger for theses a week costs nothing and decides whether that line is ever reopened. I recommend the advisor does it, and that no sessions are spent on a count.
5. **The archive's cost.** If Hyperliquid's S3 archive bills the requester (a lead), study 2 spends money. That is yours to approve once the advisor has a figure.
6. **Study 1 after the window.** Answered: it resumes on another account (the human, 2026-11-12 01:41 UTC (2026-11-11 20:41 EST)), under the same manifest (5.2).
