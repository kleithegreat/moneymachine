# The research architecture, re-derived (revision 3)

Written 2026-11-11 17:59 UTC (12:59 EST) by Claude Fable 5.2 (`claude-fable-5-2`), session "architect: rederive", on branch `rearchitecture`. Revision 1 is at `git show 51fd365:audit/program/architecture.md` and revision 2 at `git show 35cf871:audit/program/architecture.md`. Two fix rounds have run (GPT on revision 1, Argon on revision 2) and the second still changed the design, so this is not a third fix round: it re-derives the program from its root (`CLAUDE.md`, Reviews). It is a design awaiting the advisor's decision; nothing here is decided until it is logged in `audit/decisions.md`.

**Read:** revision 2; Argon's round 2 (`audit/reviews/2026-11-11-argon-web-rearchitecture-r2.md`); `audit/decisions.md` from 2026-11-11 02:25 UTC (2026-11-10 21:25 EST) on; GPT's finding 3; the `[hyperliquid]` certificate; `argon-paper-findings.md`, `paper-changes.md`, the briefs and the criteria notes; the paper's line 645; the funding lines of `gate/markets.py`. **Not read:** any other code, any venue's terms beyond what the decisions quote, anything under `data/`. Counts of events and citations from memory are *leads*. **Run:** `audit/program/arithmetic.py.txt`, which prints every number here.

**The result, in five lines.**
1. The root cause is the event-contract premise: that some venue gives a reading agent enough independent bets to confirm a plausible edge within a model's lifetime.
2. No forward study of a reading agent has honest power on a certified venue within two years. Study 2 is withdrawn and nothing replaces it.
3. Study 1, the positive control, is the one study with honest power. It is kept, with discovery defined by the plant's effect on a pick's score and its power stated for every dependence between the arms.
4. The program answers Q1. Its answer to Q3 is the wall itself, with matched numbers. Q2 is not answered.
5. I recommend running study 1, writing the paper around that, and stopping until a named condition changes.

## 1. The root cause

**The assumption.** Revision 1 derived the confirmation wall: evidence grows as effect times the square root of the number of independent bets, a frontier model has few judged days, so an ordinary edge cannot be confirmed in time. It then listed ways the wall "moves" and took one as a door: binary contracts, whose worst loss is near their typical size, so that an exact test is not crippled by its cap. That property is true and it fixes only the cap. The count stays: an exact test needs about `11.8 / e²` independent bets for 80% power at a net edge `e` (section 2.2), which is 1,838 bets at 8 cents a dollar and 4,706 at 5. Both revisions reached "a year" by assuming the count: sixty independent purchases a week, all cash staked, 8 cents of net edge, on a venue whose terms nobody had read. None of the four was measured or certified.

**How two rounds trace to it.** Every finding on study 2 is one of two kinds. Either it removes one of those props: the venue (GPT 9, and now the terms of both exchanges), the count and the capital (GPT 7; Argon 2 and 3), full staking (Argon 5), a power figure reported at even odds (Argon 7). Or it breaks a device added to extract a verdict from a study that could not give one: first the Student statistic and weekly marks (GPT 1 and 2), then the mirror, the pause and the stake rule (Argon 1, 2 and 5). The mirror existed because "not confirmed" was the likely outcome and I wanted a negative. The pause existed because cash understates wealth. Each was a patch on missing power, written as if the power were there.

**What survived and what did not.** The validity arguments were re-derived after GPT and mostly stand: Argon accepts the account under Ville's inequality, and its one attack on it fails (section 8, finding 5). What failed in both rounds is power. It was computed each time for an idealization (a simultaneous batch, independent arms, a count from memory) and not for the procedure as specified on a venue that exists. Since "is this study worth its usage" is a question about power, the design was chosen on numbers its own rules could not reach.

**So yes, it is the event-contract premise itself.** With the terms read there is no venue. With the count at what anyone has estimated, 5 to 15 readable events a week, 80% power within two years needs 9 to 18 cents of net edge on every dollar staked, against published evidence of parity with the market before costs of 3 to 5 cents (section 4). Re-deriving does not produce a better study 2. It produces none.

**Study 1 shares the method's fault and not the premise's.** Its operating table assumed independent arms, and its measure of discovery was a proxy (an alignment of holdings) where the thing itself, the plant's effect on a program's score, can be computed at no cost. Its observations really are free, so it is kept and re-derived (section 5).

## 2. The binding constraint

### 2.1 The yardstick

A claim tested on `n` independent observations with standardized effect `d` has evidence `z = d·√n`. A one-sided 5% test with 80% power needs `z* = 2.49`, so `n = 6.18 / d²`. For a strategy of annualized Sharpe `S` held `T` years, `T = 6.18 / S²`: 6.2 years at Sharpe 1, 1.55 at 2, 0.25 at 5 (Bailey and López de Prado 2012). It assumes independent, near-Gaussian observations and a fixed length. It is a planning reference and a lower bound on what a valid test costs here, not a test.

### 2.2 The exact test, what it costs, and its cap

A test that assumes only its null is a bet (Ville 1939; Kelly 1956; Shafer 2021; Waudby-Smith and Ramdas 2024; *leads*). If each bet's return is at least `−L` and has non-positive conditional mean under the null, wealth bet at a predictable fraction of at most `1/L` is a non-negative supermartingale and reaches 20 with probability at most 5%, under any dependence and any stopping rule.

- **What it costs.** For independent even bets with net edge `e`, staked at Kelly's fraction, log wealth after `N` bets is near Gaussian with mean `N·e²/2` and standard deviation `e·√N`. Reaching 20 with 80% power needs `N = 11.8 / e²`, about twice the yardstick's 6.18, and 6.0 at even odds. Every figure below is at 80% power unless it says otherwise.
- **The cap.** That rate holds only when Kelly's fraction fits under `1/L`. The gate has `L = 2` against 2% a four-hour step: at Sharpe 4.9 Kelly's bet is 5.2 and the cap 0.5. Capped, 80% power over 546 steps needs Sharpe 27.7 (26.0 at even odds), and over two years 4.0. This is Argon's first paper finding with its power matched to the yardstick's (Argon's round 2, finding 7).

### 2.3 The cutoff makes T small

A model's proposals are selected on everything it read before its cutoff `c`, so only data after `c` plus a margin can judge them (the human, 2026-10-23). Today `c` is June 2026 and the pilot's holdout holds 91 judged days by 2027-01-31. **The wall, with matched power:** at 91 days a Gaussian test needs Sharpe 4.98 and the gate's capped test 27.7. At two years they need 1.76 and 4.0. An ordinary edge, Sharpe at most 1, takes more than six years under any test.

The wall moves only by more independent observations: a longer calendar, a faster source of independent bets, or synthetic markets, where observations are free and which answer Q1 only.

### 2.4 The effect a forward study can expect

- **The prior.** For an outcome a market prices, I take a net effect of 0.05 a bet as the top of what a skilled forecaster keeps, and 0.1 as implausible (a prior, not a derivation). The published evidence is weaker: LLM forecasters at or below the crowd (Halawi et al. 2024; ForecastBench, Karger et al. 2025), and Prophet Arena's best model at a Brier score of 0.184 ± 0.006 against the market's 0.187 ± 0.006 (arXiv 2510.17638, Table 2, checked by GPT). Parity before costs.
- **Costs on an event-contract exchange.** Kalshi's taker fee is 3.4% of the stake at an even price, 5.5% at 0.20 (its schedule of 2026-07-07). With a one-cent half spread, an assumption, a purchase at a mid of 0.50 breaks even only if the event is 2.7 points likelier than the mid says.
- **The bankroll.** $2,500 caps a purchase at $125: 250 contracts at 0.50. The account is in test units, so the bankroll changes no power figure. It removes the book walk Argon's finding 3 priced and leaves fee and spread.

## 3. What is certified today

- **Hyperliquid's public info API,** read-only, by the human's operator decision of 2026-10-23, recorded since October. The certificate records that the operator is a Restricted Person under clause 1.6 of the interface's terms. So nothing confirmed there is tradeable by the human, and stage 11 has no venue there.
- **The sources with `retrieval = true`:** public statistics, filings and forums. None carries a price of an event contract.
- **No event-contract exchange.** Kalshi's Developer Agreement limits API use to "facilitating a members own trading" and forbids storing the data otherwise, sharing it with third parties, benchmarking, and public statements without approval. Polymarket US's agreement makes its data usable "solely as permitted" and requires written approval for production API use (`audit/decisions.md`, 2026-11-11).
- **No search API.** The survey has not run.
- **Synthetic markets** need no certificate.

## 4. The aims against that ground

- **Q1, capability:** when an edge exists, do agents find it more often than cheap search at the same budget? Answered by study 1 on synthetic markets.
- **Q3, edge:** does anything an agent proposes earn a positive expected net return? Not answerable forward within two years. The table shows why.
- **Q2, information:** does reading change an agent's forecasts for the better? In the form that matters, better than the price, it is Q3 and meets the same wall. In the form that is cheap, an agent with search against the same agent without, on public releases, the answer is yes for a trivial reason (the arm without search does not know this month's data) and says nothing about edge. Not answered, and not cheap.

Every forward design, with the sequential rule simulated: each purchase stakes Kelly's fraction for the true edge, capped at 5% of the cash left at that moment, and pays before the next week's purchases. That is the best a perfectly calibrated agent can do; half of Kelly's fraction is slower at small edges.

| Design | Venue | Independent bets a week | Net edge for 80% power within two years | Power within two years at net 0.04, and at 0.08 |
|---|---|---|---|---|
| A reading agent's theses on perps (the parked instance) | Hyperliquid: certified to read, not tradeable by the human | 4 to 9 (my estimate) | 0.183 at 5 a week, 0.115 at 10: a hit rate of 59% or 56% on a return's sign | 0.00 and 0.07 at 5; 0.03 and 0.40 at 10 |
| A reading agent's account in event contracts (revision 2's study 2) | none certifiable | 5 to 15 (Argon's estimate) | 0.183, 0.115, 0.090 at 5, 10, 15: at an even mid, the event 12.4, 8.8 or 7.5 points likelier than the mid, on every purchase | 0.10 and 0.67 at 15 |
| The same, at counts nobody has claimed | none | 30; 60 | 0.065; 0.055 | 0.29 and 0.95; 0.50 and 0.99 |
| A frozen systematic strategy replayed on recordings (the pilot) | Hyperliquid, no session needed | a return series | Sharpe 4.0 under the gate's test, 1.76 on the yardstick | none at Sharpe 1 |

No count in the table is measured. The conclusion does not need them to be exact: at the plausible ceiling of 0.05 the smallest count with 80% power is above 60 independent bets a week, sustained for two years, and under the null the same simulation crosses 20 in 1% of paths.

**No forward study of a reading agent has honest power on a certified venue within two years.** On the one certified venue it needs a hit rate no forecaster of priced outcomes is known to hold, at a session a day on the personal account, for a result the human could not trade. On an event-contract exchange it needs written permission first and then the same.

## 5. Study 1: the positive control (Q1)

### 5.1 The claim, the measure and the test

- **Claim, on rejection:** on synthetic markets carrying a planted funding edge, the pilot agent's session ends on a program that earns from the plant with a higher chance than G100's search does, at the same evaluation budget.
- **Arms.** A, the pilot's agent under the frozen stage 3 harness and kernel (`harness_hash` `6a335714…`), with its brief and its 100-evaluation budget. B, G100, with a seed fixed in the manifest. Both run on every study market.
- **A session's pick** is its evaluated program with the highest search-period score, read from the ledger the same way for both arms. A session with no evaluation has no pick.
- **A pick earns from the plant** when the plant's effect on its score is at least half the plant's effect on the locked reference program's score. The effect is the program's mean score over `K` fresh planted markets minus its mean score over their twins, which share every seed and have plant strength zero. The fresh markets' seeds are fixed in the manifest and shared by all picks.
- **Why this measure.** It is the thing the claim names, not a proxy. Fees, liquidation, clipping and rounding are inside the score, so a program that holds the signal and is ruined does not count unless the plant still raises its score (GPT 3; Argon 6). Whatever the frozen kernel pays that is not the plant, a defect or a leak, it pays on both twins, and the difference removes it. It costs kernel evaluations and no model session.
- **Null:** on every study market, the agent's chance of a pick that earns from the plant is at most G100's.
- **Test:** Wald's sequential sign test on discordant markets (exactly one arm's pick earns from the plant), `θ ≤ 1/2` against `θ = 0.7`, nominal errors 5%, ending at 100 markets. The upper boundary is the claim. The lower boundary is a futility stop and claims nothing.

### 5.2 Why the test is valid

- **Dependence between the arms.** Whatever the joint law of the two arms on one market, the null makes a discordant market the agent's win with probability at most one half, so the size holds for every joint law: at most 0.043, by exact enumeration. Argon's finding 4 is about power, and power is now stated across the joint laws (5.3).
- **Dependence between markets.** Seeds are distinct and fixed, sessions share no memory, and calibration markets share no seed with the study's. The null is stated market by market, so a change in the served model mid-study changes the claim's population and not the size. The report states the model id each response carried.
- **Operational failures.**
  - An agent session that crashes or evaluates nothing is a miss for the agent and is never replaced. This can only lower the agent's rate.
  - G100's picks on all 100 study markets are computed and classified before the first session and kept from the sessions. No failure of G100 can occur during the study.
  - The stopping rule is applied in the manifest's market order. Sessions run beyond the stop are reported and not counted.
- **The frozen kernel's defects** (bankruptcy resurrection among them) act on both arms' picks alike and cancel between twins. They can lower both rates. They cannot manufacture the claim, which is literal: this pick's score rises with the plant.

### 5.3 Power, for the rule as specified

Difficulty is one plant strength, chosen without a model on 400 calibration markets a grid value: the one at which G100's rate is nearest 0.2, inside 0.15 to 0.25 (standard error 0.02). The agent's target rate is 0.5.

| Agent, G100 | Overlap between the arms | Claim | Futility stop | Undecided | Markets expected |
|---|---|---|---|---|---|
| every market discordant, `θ` = 1/2 (worst null) | | 0.043 | 0.936 | 0.021 | 33 |
| 0.2, 0.2 | independent | 0.026 | 0.580 | 0.393 | 75 |
| 0.5, 0.2 | least; independent; most | 0.922; 0.989; 1.000 | 0.024; 0.001; 0 | 0.054; 0.010; 0 | 43; 37; 30 |
| 0.5, 0.25 | least; independent | 0.758; 0.932 | 0.099; 0.006 | 0.143; 0.061 | 52; 47 |
| 0.5, 0.15 | least | 0.988 | 0.003 | 0.009 | 33 |
| 0.35, 0.2 | independent | 0.610 | 0.047 | 0.343 | 71 |
| 0.3, 0.2 | independent | 0.336 | 0.137 | 0.527 | 81 |

"Least overlap" is the joint law in which the arms succeed on as few common markets as their rates allow, the worst case for power. Revision 2's design (`θ` = 0.8, 60 markets) had power 0.676 there at the target, and 0.521 at G100's rate of 0.3 with independent arms (Argon wrote 0.685). At about 22 sessions a week the study takes under five weeks at most and about two at the target.

### 5.4 What a result may be called

| Result | What it is called | Consequence |
|---|---|---|
| Upper boundary | The agent's sessions end on a program that earns from the planted edge more often than G100's | Search is not what the systematic line lacks. It lacks a confirmer and a calendar (section 2.3), so it stays parked. The second cell, a plant with no economic story, becomes worth its sessions |
| Futility stop | Not shown, at the power in 5.3, with each arm's rate and exact intervals | Never "no better": an agent at 0.3 against 0.2 stops here 14% of the time and ends undecided 53% |
| 100 markets, no boundary | Inconclusive, with the same report | As above |

**Not claimed:** real edge; that agents search better in general; anything about the gate; search apart from prior, since the brief names the family the plant belongs to.

### 5.5 Before any session, and what is reported

- **Two walls, both model-free. A failure sends the design back to the architect:**
  1. On calibration seeds, the reference program's plant effect is positive, and `K` is the smallest count at which half of it is at least four standard errors of a pick's estimated effect, for the reference program and for G100's calibration picks. A pick whose true effect is zero or the reference's is then misclassified with probability 3·10⁻⁵. If the generator cannot produce twins that share every seed, that is a wall too.
  2. Some grid strength puts G100's rate inside 0.15 to 0.25.
- **Reported, never judged:** each pick's mean score on the planted fresh markets and on their twins, by arm, with standard errors (a positive mean on the twins is a defect or a leak paying); whether each session evaluated any program that earns from the plant; evaluations used and why the agent stopped; each arm's rate with exact intervals.
- **Free, first:** each arm's search-period scores in the stage 3 ledgers, and why that agent stopped at 9 of 100 evaluations.
- **Vertical slice:** the measure and its calibration; a sequential runner on the frozen harness and kernel; a report. No kernel, DSL, gate or harness change. PC1 to PC6 on `positive-controls` are replaced, and that branch is not merged.

## 6. Q3: no study, and what to do instead

### 6.1 Recommendation

1. **Run study 1.** It costs TAMU and Cornell sessions and nothing on the personal account.
2. **Run no forward study.** Study 2 is withdrawn. The perp instance stays parked. The search API survey is not needed.
3. **Keep the certified recorders running.** Calendar time is the only thing that moves the wall, and recording costs no plan usage. Recorded days nobody has read are the holdout of any later campaign.
4. **Write the result.** On Q3 the project's finding is the wall: what a retail operator with certified sources can and cannot confirm about an agent's edge within its model's lifetime, with the pilot's calibrated null and study 1's answer on capability. `paper-changes.md` lists the edits.
5. **Then stop,** until one of the conditions in 6.2 holds. The frozen instruments stay: a new model is a rerun of study 1, not a rebuild.

### 6.2 What would reopen a forward study

- **Written permission from an event-contract exchange.** The request must name each use, because each is forbidden by a clause:
  - *Kalshi:* an automated program reading market data that places no order (Developer Agreement section 3); storing every response indefinitely, and sending market data to a third party's language model (3.1); scoring a model's forecasts against Kalshi's prices (3.5); publishing aggregate results that name Kalshi (6.4).
  - *Polymarket US:* production API use (Participant Agreement section 19); the same storage, model and research uses, and publication of aggregates (section 22).

  Permission alone is not enough: the table of section 4 still applies. I recommend not asking for the study's sake.
- **An earlier-cutoff campaign** (the human's idea, 2026-10-23): when study 1 reaches its claim for the frontier agent and for a model at least two years past its cutoff, and a confirmer has been re-derived whose stated 80% power at that length reaches the edge it is meant to see. At two years the yardstick itself asks Sharpe 1.76.
- **A measured count** of more than 60 independent readable bets a week on a certified venue.

### 6.3 The account, if a forward study is ever reopened

Kept as a specification because its validity argument is what two rounds established.

- **Claim, on rejection:** not every purchase the frozen procedure made was at a non-positive expected net return.
- **The account** starts with cash 1. A purchase pays a stake the agent registers, at most 5% of cash, at the all-in cost `c < 1` of buying the reference stake from the recorded asks, and holds `stake/c` units. A recorded settlement `x` in [0, 1] pays `(stake/c)·x` into cash. Nothing else moves cash. The null is rejected when cash reaches 20.
- **Null:** for every purchase, `E[x | everything recorded up to its registration] ≤ c`.
- **Validity.** Cash plus the conditional expected payout of every position not yet recorded as paid is a non-negative supermartingale on the record's own filtration, and cash never exceeds it. A payout recorded late, or never, is a position still open in that sum. No assumption is made about when records arrive: a delay may depend on outcomes already realized, because every stake is fixed before its own outcome, and a null stated on a finer filtration implies the one on the record. So the 5% bound holds under any dependence between contracts and any recording failure (Argon's finding 5, section 8).
- **Gone, each a patch on power:** the mirror, the pause, the stake rule computed from a registered probability, and revision 2's second tested property, which was false as worded.
- **A non-rejection** is "not confirmed", with the realized net return per dollar staked and the power row for the realized count. There is no negative verdict.
- **Power:** section 4's table.

## 7. Stop rules

- **Study 1** ends at a boundary or at 100 markets, with no extension. It does not start if a wall of 5.5 fails. Five consecutive sessions lost to one operational cause pause it; they still count.
- **The program** pauses for the human when study 1 has reported. Nothing is rescued by lowering a threshold, by reading the forward window, or by calling a non-rejection absence.

## 8. Argon's ten findings

| | Finding | Verdict | Reason, and where it is answered |
|---|---|---|---|
| 1 | The mirror tests the wrong null and convicts a profitable procedure | Holds | Rejecting "every purchase had non-negative return" is not "the procedure loses". Its example is worse than written: the account grows 0.0152 a week (197 weeks; Argon wrote 0.0201 and 149) while the mirror reaches 20 in 20.3. There is no mirror and no negative verdict (6.3) |
| 2 | Half Kelly is improper, under-deploys, and the pause deadlocks | Holds | Reporting 0.54 for a true 0.52 grows 0.00080 a bet against 0.00060; sixty purchases at 1.25% stake 53% of cash. The agent registers its stake, the pause is gone, and power is simulated for the sequential rule (section 4, 6.3). `c ≥ 1` was already refused by `p > c`; it broke only the mirror |
| 3 | $2,500 a purchase collapses breadth and edge | Partly | Depth: void at the human's $125 (250 contracts at 0.50). Count and costs: hold, and are the root cause; its 499 weeks at 8 bets a week reproduces (sections 1, 2.4, 4) |
| 4 | Study 1's table assumes independent arms | Holds for power, not for size | The size holds under every joint law. Power did depend on the overlap and on G100's band: 0.521 at (0.5, 0.3), below Argon's 0.685. Section 5.3 states power across joint laws on a narrower band; the lower boundary claims nothing, so its (0.25, 0.20) case is a true rejection |
| 5 | Late records inflate cash; polling must be independent of outcomes; the script simulated a batch | Partly | The path arithmetic is right (8.10 against 20.29) and revision 2's second property was false as worded. The 5% bound is not broken: no independence of polling is needed (6.3), and under a fair null recorded cash reaches 20 in 3.7% of paths on time and 1.4% with every payout 20 purchases late. The batch simulation: holds, replaced |
| 6 | The pick and the alignment are corrupted by the kernel's defects, scale invariance, and a masked leak check | Holds, except one clause | A single aligned step does not match a full path's cosine. The rest stands, including my wrong sentence that study 1 "reads no return". Discovery is now the plant's effect on the pick's score between twins, and the leak check is a reported number (5.1, 5.5) |
| 7 | The wall compares 80% power with even odds, and so did row G | Holds | 27.7 against 4.98 at 91 days, 4.0 against 1.76 at two years (2.2, 2.3). Every forward figure is at 80% power (section 4) |
| 8 | My dispositions of its paper findings 4, 7, 10 and 11 | 11 holds in part; 4 in part; 7 and 10 do not | 11: I withdraw "martingale differences"; the understatement depends on funding's share of a step's variance, 1.002 at a share of 2.5·10⁻⁵, 4.9 at Argon's 0.10. 4: the count should say two campaigns had no evaluation; no bound uses them. 7: the DSR's limit in its own example is `z` = 11.3, so there is no ceiling; its examples show a Sharpe failing, which is the test working. 10: the 0.05/99 is the suite's own rule (paper, line 645), not mine; the sentence now names it. All in `argon-paper-findings.md` |
| 9 | `paper-changes.md` carries four errors into the paper | Holds on three, moot on one | The growth formula, row G and the mirror edit are withdrawn with study 2. The suite's bound is now named. `paper-changes.md` is rewritten for this revision |
| 10 | Search-API copyright, the Polymarket recordings, the perp instance | Partly | No study uses a search API now. "No API can license page text" is an untested universal and would be a condition of any certificate. The recordings are sealed and the perp instance parked by the human's decisions of 2026-11-11 |

GPT's eleven findings were disposed of in revision 2's section 10 (`git show 35cf871`). Its findings 1, 2, 7, 9, 10 and 11 concern study 2 and end with it; 3, 4 and 5 are answered by section 5; 6 by section 2; 8 by sections 5.4 and 6.3.

## 9. Infrastructure

- **Used:** the frozen pilot kernel, `gate/markets.py`, `gate/search.py`, `gate/campaign.py`, `gate/agent/` under its frozen hash, `sandbox/`, the ledger; pre-registration of statistical criteria; fresh-session bug hunts; the two-round rule.
- **Running, with no work done on it:** the certified recorders.
- **Parked, each until a condition of 6.2:** the thesis track entire (`thesis/`, branches `thesis-refreeze` and `thesis-split`, Job `thesis-prewarm`); the gate's holdout test and screens with the defects in the paper's table; stage 7, the Lean engine, `reference/lean`; the swarm; stages 8 and 9, superseded. The stage 3 forward window lapses on 2027-01-31 with nothing registered in it, and its prices stay unread.
- **Not built:** a venue adapter, an account, a search API certificate.
- **`CLAUDE.md` rules proposed for removal,** each because its failure can no longer happen: "a source-blind red team after each kernel milestone" (none is scheduled); "The thesis track's forward use is its own design" (no forward study runs); "Before any work on stage N" reads "study" for "stage".

## 10. Unsure, and where to attack

1. **The counts.** Every count of independent bets is an estimate, mine or Argon's. The conclusion needs fewer than about 60 a week; a certified venue with several times that would reopen it.
2. **The prior on the effect.** If an agent that chooses where to bet keeps more than 0.1 net, section 4 is too pessimistic. The published benchmarks test forecasting on given questions, not selection among thin markets.
3. **Twin markets.** I have not read whether N2 can produce a zero-strength twin that shares every innovation. If it cannot, unpaired fresh markets and a larger `K` give the same measure with more noise.
4. **The reference program's effect** may be small against its standard error at the calibrated strength, making `K` large. It is kernel time only.
5. **Least overlap** is the worst case for study 1's power and I think it unlikely: easy seeds should be easy for both arms.
6. **Independence across study 1's markets** if the provider changes the served model silently.
7. **A lead I did not check:** whether Hyperliquid's certified API now lists exactly settled outcome contracts (its HIP-4, from memory). One request by the advisor would show it. It would give the account of 6.3 a certified venue, still not tradeable by the human and still short of the count.
8. **Whether stopping is right.** It follows from the arithmetic and from the human's own constraints. A larger tolerance for unconfirmed risk is the human's to state, not a result.

## 11. Open questions for the human

1. **Stop the forward line.** No reading-agent study has honest power within two years on anything certifiable. I recommend: study 1, the paper, then a stop until a condition of 6.2 holds. This reverses your decision of 2026-11-11 15:16 UTC (10:16 EST) that study 2 runs.
2. **Whether to ask Kalshi or Polymarket US for written permission.** I recommend no. Granted in full, it buys a study that needs the event 7.5 to 12.4 points likelier than the mid on every purchase.
3. **Stage 11.** It has no venue: Hyperliquid's terms exclude a US operator, and the exchanges permit your own trading but not an agent that reads their API. I recommend removing it from the roadmap. A $2,500 live account confirms nothing sooner than paper does.
4. **Study 1 at up to 100 markets** in place of 60, about five weeks of TAMU and Cornell sessions at most. I recommend yes: it holds 92% power at the target under every dependence between the arms.
5. **The paper.** Rewrite the roadmap around the wall as the finding on Q3 and study 1 as the remaining experiment (`paper-changes.md`). I recommend yes, with Argon's finding 11 added to the defect table.
6. **The recorders.** I recommend they run on: they are what a later model's campaign would be judged on, and they cost no plan usage.
