# The program's convergence ledger

Written 2026-11-11 21:40 UTC (16:40 EST) by Claude Fable 5.2, session "architect: revision 4, finish". `CLAUDE.md`'s Reviews section asks that each round of adversarial review end with a ledger: the points now agreed, and the disputes still open, each either settled by a derivation both sides accept or reduced to an assumption only the human can choose. This is the ledger after round four. Each later round appends a dated section; nothing above it is edited.

**Read for it:** `architecture.md` revision 4 with its section 9; the verdict tables of revisions 2 and 3 (`git show 35cf871`, section 10; `git show 337619f`, section 8); `audit/decisions.md` from 2026-11-11 20:41 UTC (15:41 EST). **Not reread:** the four reviews themselves. A reviewer's position is taken from the architect's own verdict tables, so where this ledger says a reviewer holds something, that is the architect's reading of the review.

## In plain words

- **What changed in round four.** The wall was overstated by about two and is now three numbers at matched power. A frozen rule with a forward Sharpe near 2 became confirmable in two years, which gives the replication its place as study 2. Study 1's measure became a majority over fresh twin pairs.
- **What is agreed.** That the calendar and the gate's loss cap are separate causes; what an exact test costs; that study 1 is a paired test whose size holds whatever the arms' dependence; that a non-rejection is never absence; that no event-contract venue is certified.
- **What is disputed.** Eight points, D1 to D8. Seven cannot change what is built or run. One can: whether a reading agent makes 33 independent bets a week. It is reduced to a measurement the human has already ordered.
- **Is the program converged?** No, for one reason: no reviewer has seen revision 4. Its two new designs, study 1's measure and study 2, are unreviewed. The round that is owed is the review `CLAUDE.md` already requires before study 1's criterion is committed, so it costs no extra round.

## Who has seen what

| Round | Reviewer | Reviewed | Record |
|---|---|---|---|
| 1 | GPT | Revision 1 | `audit/reviews/2026-11-10-gpt-rearchitecture.md` |
| 1 | Argon | The paper's mathematics | `audit/reviews/2026-11-10-argon-web-paper-math.md` |
| 2 | Argon | Revision 2 | `audit/reviews/2026-11-11-argon-web-rearchitecture-r2.md` |
| 3 | Argon | Revision 3 | `audit/reviews/2026-11-11-argon-web-rearchitecture-r3.md` |
| 4 | none yet | Revision 4 | owed |

GPT has seen nothing since revision 1. So "agreed" below means one of two things, and each row says which: the architect accepted a reviewer's finding and no reviewer has since objected to the answer (**conceded**), or a reviewer examined a claim and let it stand (**examined**).

## Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A1 | The wall has two causes, the calendar and the gate's loss cap, and each has its own number | Conceded to GPT (finding 6) and to Argon (paper finding 1; round 2, finding 7; round 3, finding 2) | Architecture 2.2, 2.3 |
| A2 | Thresholds are compared at matched power, 80% | Conceded to Argon, round 2, finding 7 | 2.3 |
| A3 | An exact test that stops at its threshold needs `8.59 / e²` bets. Argon wrote 8.67; the difference is 1% and changes no figure | Conceded to Argon, round 3, finding 2 | 2.2 |
| A4 | The cap `1/L` is a choice of the test. A loss bound must be a property of the tested rule | Conceded to Argon, round 3, finding 2 | 2.2 |
| A5 | A Student test on a weekly marked portfolio is not valid under a common shock. An edge claim is judged by the cash of one self-financing account | Conceded to GPT, finding 1 | Section 6 |
| A6 | There is no valid mirror test, and a non-rejection is "not confirmed", never absence | Conceded to GPT, finding 8, and to Argon, round 2, finding 1 | 5.4, section 6 |
| A7 | Study 1 runs the baseline on every market and tests discordant markets. No baseline rate is certified | Conceded to GPT, finding 5 | 5.1 |
| A8 | Study 1's size holds under every joint law of the arms. Its power depends on the overlap and on G100's rate, and every row is shown | Examined by Argon, rounds 2 and 3 (size); conceded (power) | 5.2, 5.3 |
| A9 | Discovery must be the thing the claim names, the plant's effect on the pick's score, and not an alignment of holdings or a mean on a shared sample | Conceded to GPT, finding 3, and to Argon, round 2, finding 6, and round 3, finding 1 | 5.1 |
| A10 | Twins are not additive: the plant feeds N2's variance path | Conceded to Argon, round 3, finding 1; confirmed by the advisor from the code | 5.1 |
| A11 | A session that fails before any evaluation is not an observation of the agent | Conceded to Argon, round 3, finding 5 | 5.2 |
| A12 | At 4 to 9 theses a week a reading agent's forward study has no honest power | Argon's own figure in round 2, finding 3 (499 weeks at 8 bets a week), which the architect reproduced. Round 3 disputes the count, not the arithmetic (D1) | Section 4 |
| A13 | Thirteen of Argon's fourteen paper findings hold in substance, finding 11 among them at a hedged book's funding share | Conceded, the last in round 3 | `argon-paper-findings.md` |
| A14 | Forward means an outcome unknown when the rule is frozen: a forward test reads only what follows its freeze | Conceded to GPT, finding 11 | Section 6 |

## Disputed

Each row gives both positions, then what settles it. "Changes" says whether the dispute could change what is built or run.

| | Dispute | Settled by | Changes |
|---|---|---|---|
| D1 | **The count.** Argon: a reading agent makes 45 independent pairs a week, so a forward study is powered. The architect: no count is measured; the threshold is 33 a week at a net edge of 0.05 | **A measurement.** The thesis track's ledger holds registered theses. The advisor counts them a week and estimates their dependence (the human, 2026-11-11 21:26 UTC (16:26 EST)). At 33 or more the reading-agent line reopens as a new design; below it the dispute is over | **Yes,** what is run |
| D2 | **Late records.** Argon (round 3, finding 4): delays that depend on outcomes break the account's 5% bound. The architect: they do not | **A derivation,** awaiting Argon's acceptance or a failing path. `V`, cash plus the conditional expected payout of unrecorded positions, is a non-negative supermartingale on the world's filtration, to which the recorder's delays are adapted (section 6). Argon's example is a Doob martingale throughout | No: no study uses the account |
| D3 | **The paired reading design.** Argon: pairing an agent with filings against one without gives Q2 power. The architect: it is fair and buys no power | **A derivation.** Where the arms agree the difference is zero, so only discordant forecasts count: 859 at five points of hit rate, 3,437 at two and a half (section 4) | No |
| D4 | **The locked suite's confidence level.** Argon: the Bonferroni level is applied in the wrong direction. The architect: it is not | **A derivation.** A higher confidence widens the upper bound, so each cell is harder to pass. What does hold is that the suite certifies the tolerance: a true 0.056 passes 72% of the time (`argon_paper`, item 10) | No: one sentence of the paper, written either way as "certifies the tolerance" |
| D5 | **The deflated Sharpe ratio.** Argon: it fails Sharpe 3.5 over 91 days, and its radicand can be negative. The architect: the first is the wall, the second cannot happen | **A derivation.** Against a threshold of 2, `z ≤ 0.75` on any test. A sample's kurtosis is at least its skewness squared plus one, so the radicand is at least `(1 − skewness·S/2)²` | No: parked machinery |
| D6 | **Stage 4's count.** Argon: the pooled bound should use 13. The architect: v2's "two counted campaigns" are the two with no evaluation | **A fact in the record,** `audit/stage4/`. Either way the pooled bound is withdrawn, which both sides want | No |
| D7 | **The `funding × leak` example.** Argon: a program can earn the twin difference through funding. The architect: funding is drawn before the plant and is identical between twins | **A fact in the code,** now a test: `briefs/1-positive-control.md`, step 1, behaviour 4 | No, unless that test fails; then it is a wall |
| D8 | **The row at rates 0.25 and 0.2.** Argon: the claim's chance is 0.321. The architect: 0.083 | **A computation,** exact enumeration (`sign_test`). The study claims no power there on either figure | No |

Three of Argon's points are moot and stay recorded: "no API can license page text" (no study uses a search API), the depth of a $2,500 purchase (no event-contract study), and the mirror's arithmetic (no mirror).

## Assumptions only the human can choose

| | Assumption | Status |
|---|---|---|
| H1 | "Honest power" means 80% within two years | Used throughout; never put to the human as a choice. A year, or 50%, moves every threshold: at one year the frozen rule needs Sharpe 2.93 |
| H2 | A skilled forecaster keeps a net effect of at most 0.05 a bet on a priced outcome | A prior, not a derivation (architecture 2.4). With D1 it decides whether the reading-agent line ever reopens |
| H3 | Study 2 runs although its power is 0.47 at the vault's recent Sharpe | Chosen: the human, 2026-11-11 21:26 UTC (16:26 EST) |
| H4 | Study 1 ends at 100 markets, G100's target is 0.15, and the claim reads "more often than G100's 100 evaluations" | Chosen: the same decision |
| H5 | The project is academic and stage 11 is gone | Chosen: the human, 2026-11-11 20:41 UTC (15:41 EST) |

## Not yet reviewed

Round three's findings changed the design, so a round is owed, on another model (`CLAUDE.md`, Reviews). No reviewer has seen:

1. **Study 1's measure** (architecture 5.1): the majority over fresh pairs, the bound of 0.0035, and the four model-free walls.
2. **Study 1's band and void rule** (5.2, 5.3).
3. **Study 2** entire (section 6): the hedge, isolated margin as the loss bound, the registered fraction, the walls.
4. **The forward law** `bets a week × e² ≥ 0.083` and the three settlement timings (section 4).
5. **The figure 2.07** and the registered-fraction power rows (2.2). Argon proposed the direction; the numbers are the architect's.

**Where a reviewer should attack first.** Study 1's measure has changed in every round: exact capture, then alignment, then a mean effect with a calibrated `K`, now a majority. Three replacements in three rounds is the pattern `CLAUDE.md` calls patching. The architect's case that this one is a re-derivation: the first three were estimates of a quantity, each broken by how it was estimated; the fourth is a stated property with an exact bound, and walls 2 and 3 test it on known programs before any session. If the round breaks it again, the measure is not the problem and the claim is: the question "does the pick earn from the plant" should then be replaced, not the measure patched.

**The cheapest way to hold the round.** Study 1's criterion must be reviewed before it is committed (`briefs/1-positive-control.md`, step 0). Give that review items 1 and 2. Items 3 to 5 go to the review of the kernel version 2 and study 2 design. GPT has seen nothing since revision 1 and is the other model; if it is unavailable, a fresh Opus session reviews, labeled, with GPT queued.

## Convergence

**Not converged.** The test is that no open dispute would change what is built or run.
- D2 to D8 pass it.
- D1 fails it, and is reduced to a measurement already ordered.
- The five unreviewed items are not disputes, and until a round returns no finding on them that changes the build, nothing can be said either way.

Steps 1 to 6 of study 1's plan are model-free tooling and reversible, so they may be built while the round runs. The criterion's commit, G100's run on study markets and the first session wait for it.

## After Argon's round four on revision 4

Appended 2026-11-12 01:26 UTC (20:26 EST) by Claude Fable 5.2, session "architect: study 1 fix". **Read for it:** Argon's round 4 (`audit/reviews/2026-11-11-argon-web-rearchitecture-r4.md`), findings 3 and 6 in full and its ledger; `architecture.md` 5.1 to 5.5; the build plan; `gate/markets.py`, `generate`. **Not read:** findings 1, 2, 4, 5 and 7, which are study 2's and section 6's. They are entered below from Argon's own ledger table and wait for the kernel version 2 session.

### In plain words

- **What changed.** Study 1's claim, not its measure. The plant is a drift in six coins' returns, and a program earns from it by any route: funding, the coin's own momentum, or a constant position. Wall 3 had said that funding-blind programs cannot earn, which was false. It now tests the one thing the measure must not pay, the part of an effect that is the same for a program and its mirror. The rule is 39 of 57 pairs. The calibration is sized so that its own noise does not fail it. A session that crashes is void whatever it had evaluated.
- **What is agreed.** Argon agrees eight points of revision 4, three of them study 1's. The architect accepts findings 3 and 6 in every part, and declines two of their remedies.
- **What is disputed.** For study 1, the two declined remedies, each answered by a derivation Argon has not seen (D9, D10). For study 2, five findings, two of them critical, not yet answered.
- **Is the program converged?** No. Study 1's design changed, so it is owed one round on another model, which is again the review of its criterion. Study 2 has open critical disputes.

### Who has seen what

| Round | Reviewer | Reviewed | Record |
|---|---|---|---|
| 4 | Argon | Revision 4 | `audit/reviews/2026-11-11-argon-web-rearchitecture-r4.md` |
| 5 | none yet | Study 1 as revised here | owed, on another model |

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A15 | The stopping constant `8.59 / e²` and the Sharpe of 2.07 over two years | Examined by Argon, round 4, point 1. Of "not yet reviewed" item 5 this closes the figure; its power rows are D13 | 2.2 |
| A16 | The reading-agent threshold of 33 bets a week at a net edge of 0.05, and parking the track until the count is measured | Examined, point 2. D1 is now a measurement both sides accept | Section 4 |
| A17 | The paired reading design's power scales with discordant forecasts | Examined, point 3. D3 closes | Section 4 |
| A18 | Each study market's own fresh pairs remove the dependence between markets | Examined, point 4 | 5.1 |
| A19 | The null over the population and the pinned model id | Examined, point 5 | 5.1, 5.2 |
| A20 | A session that crashes before any evaluation is void | Examined, point 6. The rule is now wider (A24) | 5.2 |
| A21 | The account's validity on the world's filtration, for binary contracts of fixed cost | Examined, point 7. D2 closes for that case; finding 7 reopens it for perp brackets | Section 6 |
| A22 | The dispositions of paper findings 7, 10 and 11 | Examined, point 8. D4 and D5 close | `argon-paper-findings.md` |
| A23 | A persistent plant can be earned from prices alone, and a rule of 24 of 32 passes a pick with a chance of 3/4 on a pair only 0.59 of the time | Conceded to Argon, round 4, finding 3. Its 0.516 is 0.43 by its own formula; the point stands | 5.1 |
| A24 | A search on 400 markets fails a check within 0.02 by its own noise 31% of the time; a crash after an evaluation is not an observation of the agent; the rows at 0.3 against 0.19 belong in 5.4 | Conceded to Argon, round 4, finding 6 | 5.2, 5.3, 5.4 |

### Disputed

| | Dispute | Settled by | Changes |
|---|---|---|---|
| D9 | **The plant.** Argon: make it invisible in prices, by demeaning or randomising the planted sign or orthogonalising against past returns. The architect: leave the generator and change the claim | **A derivation,** not yet seen by Argon. A twin is the same world without the plant, so an effect is what the plant does to a score, and a program that wins most fresh pairs has an edge on unseen markets by any route. Wall 3 then needs no statement about routes: a program's and its mirror's effects differ in sign in the drift captured and agree in everything else, so the even part is what the measure must not pay, and it is measured (5.1, 5.5) | **Yes,** what is built |
| D10 | **A cut-off session.** Argon: resume it from its last turn. The architect: void it and run the market again | **A fact and a derivation.** The frozen harness does not resume. A void rule that reads only how a session ended selects on no score; its cost, counted sessions that lean short, is reported with the decision under revision 4's rule (5.2) | **Yes,** what is run |
| D11 | **Study 2's margin.** Argon, finding 1, critical: the bound of 23.4 step standard deviations needs leverage that liquidates the replica, and a margin on each leg is a convex position | Open. Waits for the kernel version 2 session | **Yes** |
| D12 | **Study 2's hedge.** Argon, finding 2, critical: a short fixed before the freeze leaves market drift in the tested series | Open. Waits for the same session. Architecture 11, item 4, already names it as unsure | **Yes** |
| D13 | **Study 2's bet.** Argon, finding 4, high: a Kelly fraction frozen on earlier volatility, and 6.13 years, not 4.4, at a Sharpe of 1.4 | Open. Waits for the same session | **Yes** |
| D14 | **Study 2's fidelity wall.** Argon, finding 5, high: fitted and checked on the same dates, and snapshots miss wicks | Open. Waits for the same session | **Yes** |
| D15 | **Perp brackets in the account.** Argon, finding 7, low: the null indexed at fill time, and pending payouts counted as cash at the end | Open. No study uses the account | No |

D6, D7 and D8 stand as they were. Round 4 did not return to them.

### Did the measure break?

The ledger above said that if round four broke the measure again, the claim should be replaced and not the measure. Round four did not break the measure. It broke a wall beside it, and the wall was wrong for a reason that lay in the claim: "a planted funding edge" implied that only a reader of funding could earn, and the plant is a drift that prices also show. So the claim changed, by one phrase and one sentence, and the measure's definition did not, apart from its two sizes, which now have a derivation on both sides (0.005 at a chance of 1/2, 0.9 at 3/4) where 24 of 32 had one.

**Where a reviewer should attack first.**
1. **Wall 3 on even parts.** It rests on a program's and its mirror's effects being opposite in what the drift pays. Fees and liquidation are not opposite, which is the point of the wall, but a reviewer should look for a way to earn from the plant's sign that the mirror also earns from.
2. **The void rule.** The counted session is the first to reach a designed end. Look for a way the agent's own behaviour makes a crash likelier on markets it would lose.
3. **Constant positions.** If the signal's mean is far from zero, a constant short earns from the plant, and G100 may reach its 0.15 at a strength where the agent has little left to find beyond it. The mirror set's own rates, reported with the walls, show this before any session.

### Assumptions only the human can choose

| | Assumption | Status |
|---|---|---|
| H6 | When the accounts' window ends before a boundary, study 1 resumes on another account, or ends as inconclusive | Open: architecture, section 12, question 6. The architect recommends resuming |
| H7 | A pick with a chance of 3/4 on a fresh pair should be classed as earning nine times in ten | Chosen by the architect as the rule's second requirement; it sets 57 pairs. A stricter choice costs calibration time in proportion |

### Convergence

**Not converged.**
- **Study 1:** D9 and D10 would change what is built or run, and Argon has not seen their derivations. They go to the round owed on another model, with the three points above. Steps 1 to 6 remain model-free and reversible and may be built meanwhile; the criterion's commit, G100's arm and the first session wait for that round, as before. Given the accounts' window, the round should be asked for now.
- **Study 2:** D11 to D14 are open and unanswered.

## After Argon's round five on study 1, and the agent as served

Appended 2026-11-12 15:21 UTC (10:21 EST) by Claude Fable 5.2, session "architect: study 1 reader of ids". **Read for it:** Argon's round 5 (`audit/reviews/2026-11-12-argon-web-study1-r5.md`), its verdict, its own ledger and its finding on the void rule; `architecture.md` 5.2; the build plan's change table, step 0 and steps 7 to 9; `audit/decisions.md`, 2026-11-12 07:10 UTC (02:10 EST) and 15:13 UTC (10:13 EST); the tests of steps 7 to 9 as written at `fffed7e`. **Not reread:** round 5's other findings in full, which are entered from its ledger and from the architect's commits `b12ce44` to `be96683`.

### In plain words

- **What changed.**
  - **From round 5:** wall 3 is judged for each mirror pair. A new wall 5 bounds what a constant position earns. A session cut off after an evaluation is judged on its pick again, and only a session with no evaluation and no designed end is void.
  - **From the pilot's transcripts:** the agent is the frozen harness as the provider serves it. About half the pilot's sessions were answered by `claude-opus-4-8`, the client's fallback, so the study's subject is that agent and not "the pinned model".
  - **From the four facts:** a session's model is read from the ids of its responses alone. The fallback event is not read, because the client writes it after the responses it explains.
- **What is agreed.** Argon agrees four more points: the claim by any route, the rule of 39 of 57, the calibration's sizes, and the sequential test. The architect accepts every round 5 finding, and goes further than Argon asked on the void rule.
- **What is disputed.** Nothing is contested, but three settlements have not been seen by Argon (D9-a, D9-b, D10), and three designs have been seen by no reviewer (the agent as served, the reader of ids, the void rule as it now stands).
- **Is the program converged?** No. Study 1 owes one round, which is again the review of its criterion. Study 2 is as it was.

### Who has seen what

| Round | Reviewer | Reviewed | Record |
|---|---|---|---|
| 5 | Argon | Study 1 as revised after round 4 | `audit/reviews/2026-11-12-argon-web-study1-r5.md` |
| 6 | none yet | Study 1 at this commit, CS1.1's text included | owed: Argon on D9-a, D9-b and D10; another model on the agent as served, the reader of ids and the void rule (a fresh Opus session, labeled, while GPT is spent) |

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A25 | The claim is earning from the plant by any route, with the generator unchanged and the inputs reported. D9 closes on the claim | Examined by Argon, round 5 | 5.1 |
| A26 | The rule of 39 of 57 pairs: 0.00384 at a chance of 1/2 on a pair, 0.901 at 3/4 | Examined, round 5 | 5.1 |
| A27 | The calibration's sizes: 1,600 search markets at a tolerance of 0.005, 10,000 check markets in the band | Examined, round 5 | 5.3 |
| A28 | The sequential sign test, laws L6.1 to L6.7, the power table and the window table | Examined, round 5 | 5.2, 5.3 |
| A29 | CS1.1 states the population, the test, the size of 0.043, the naming of a non-rejection and the region without power | Examined, round 5, on the draft. The text has since changed (D10, and the agent's line) | Step 0 |
| A30 | The frozen harness cannot resume a session | Examined, round 5 | 5.2 |
| A31 | Wall 3 pooled over the mirror pairs can pass while one pair fails. The even part measures fees and ruin, not N2's variance path | Conceded to Argon, round 5, D9-a | 5.1, 5.5 |
| A32 | A constant position can earn from the plant, and the walls did not bound it | Conceded to Argon, round 5, D9-b | 5.5 |
| A33 | Rerunning a session that has seen a score is a selection: a losing search runs longer and is cut off more often. Argon's example takes a rate of 0.15 to 0.187 and the size to 0.114 | Conceded to Argon, round 5, D10 | 5.2 |
| A34 | Step 2's laws need exact inputs, the measure scores a pick and the reference together, the tolerance includes its ends, and a twin at strength 0 is made once | Conceded to Argon, round 5, build fixes. `scores(programs, pairs)` as the advisor adopted it (`audit/decisions.md`, 2026-11-12 02:58 UTC (2026-11-11 21:58 EST)) | Steps 2, 5 |

A24 held three things, and its middle one is withdrawn by A33: "a crash after an evaluation is not an observation of the agent" cannot be kept together with A33 on a harness that does not resume (5.2, "three things are wanted").

### Disputed, or settled without the reviewer

| | Point | Settled by | Changes |
|---|---|---|---|
| D9-a | **Wall 3's count.** Argon: at most 3 of 200 for each pair. The architect: at most 4 | **A computation,** not yet seen by Argon: with five pairs, some pair above 4 has probability 0.005 under the rule's bound (`EVEN_ALLOWED`; `arithmetic.py.txt`, `walls`) | **Yes,** what is built: `constants.py`, `calibrate.py` |
| D9-b | **Constant positions.** Argon: a wall at half the blind markets, or a reference on the planted coins only. The architect: wall 5, at most 51 of 200, and the reference unchanged | **A computation and a fact,** not yet seen: a program at the band's top, 0.18, passes 51 with probability 0.003, so the wall is tighter than Argon's; the DSL cannot hold a reference on six coins | **Yes,** what is built |
| D10 | **Voids that hide losses.** Argon: say so in CS1.1, and cap the study's voids or flag a claim that the first sessions undo. The architect: no cap repairs it, so no session with an evaluation is void | **A derivation,** not yet seen: were each void to hide a loss, the size is 0.073 at one void, 0.117 at two and 0.338 at five (`voids`). A session with no evaluation has seen no score. The report also gives the decision with every void counted as a miss, and CS1.1 names a claim it does not reach | **Yes,** what is run. Its cost is power where outages are common, and is stated |

D6, D7, D8 and D11 to D15 stand as they were.

### Not yet reviewed

1. **The agent as served** (5.1, 5.2, CS1.1's agent line): the subject is the pilot's mixture of two models; nothing is claimed of either alone; an id outside the manifest's ends the study.
2. **The reader of ids** (5.2; step 8, behaviour 4 and L8.7): ids alone, the event unread, a session answered by both judged, the client's own lines passed over by a named id.
3. **The void rule as it stands,** and the decision with every void counted as a miss (5.2, 5.4; step 9, item 4).
4. **Walls 3 and 5** at their new counts (5.5).
5. **Steps 7 to 9:** the manifest hashes the judged path only; the lines carry each pick's inputs and G100's earlier bests, so the report reads no ledger; no fsync.

Items 3 to 5 of the first list above, which are study 2's and section 4's, are still unreviewed.

**Where a reviewer should attack first.**
1. **The mixture.** The share of sessions answered by `claude-opus-4-8` may drift, and no one can reproduce it. The size holds for any sequence (5.2). Look for a claim the result's name makes that a drifting mixture does not support.
2. **Voids and the model.** A void has seen no score, but which model answered could both end a session before its first evaluation and change its chance of earning. The decision with voids as misses is the bound. Look for a path it misses.
3. **The passed-over id.** A line under the client's own id is not read. Look for a way a model's response could carry it.
4. **A session answered by both ids** is judged though the pilot holds none. Look for a reason it is not the registered agent.

### What each change obsoletes in the tests

The plan's change table and its list of tests by name are the record (`briefs/1-positive-control.md`, "What changed"). By file:

| Test file | Step | Obsoleted by |
|---|---|---|
| `test_measure.py` | 2 | A34, where a law draws inputs that are not exact; the note that 5.1 quotes "0.67", which is 0.671 |
| `test_calibrate.py` | 5 | D9-a (wall 3's pooled count), D9-b (wall 5, new), A34 (the tolerance's ends, the timing of a whole market, twins made once) |
| `test_programs.py` | 4 | Stale words only: "fixed pseudo-random position" |
| `test_manifest.py` | 7 | The judged path (`test_files_name_everything_the_plan_hashes`); `SERVED` and `NOTICE` among the constants; the searcher's line with its pick's inputs and earlier bests |
| `fakes.py` | 7 to 9 | The agent as served (`FOREIGN`); the reader of ids (`transcript`, the kinds of session, "models" with counts); D10 (which sessions are void); the lines' new fields |
| `test_runner.py` | 8 | D10 (three tests and the checks behind L8.5 and L8.6); the agent as served and the reader of ids (two tests deleted, three changed, L8.7 new) |
| `test_report.py` | 9 | D10 (the three tests of the void rule, and the `judge` argument: the report reads no ledger); "model changed" as an end; "models" with counts, and the rate by set of ids |

`test_pairs.py`, `test_pick.py` and `test_sequential.py` are untouched.

### Assumptions only the human can choose

| | Assumption | Status |
|---|---|---|
| H6 | Study 1 after the window | Chosen: it resumes on another account under the same manifest (the human, 2026-11-12 01:41 UTC (2026-11-11 20:41 EST)) |
| H8 | The control's subject is the pilot's agent as served, and not a fork pinned to `claude-opus-4-8` | Decided by the architect, as `audit/decisions.md` (2026-11-12 07:10 UTC (02:10 EST)) assigned, for the human's review. A fork would be a new harness and would control one part of the pilot's agent |

### Owed before the manifest, by the advisor

- **The client's own id.** Whether the frozen client writes an assistant line of its own when a request fails, and under which id (5.2). Without it `NOTICE` is empty, and a failed request that writes such a line ends the study.
- **The swarm's count.** The test writer counted a fallback in 31 of stage 4's 40 swarm sessions; the advisor's facts cover 41 sessions in all, 20 with a fallback. 5.2 quotes both. The difference changes no rule, only the cost of an alternative that fails at either share.

### Convergence

**Not converged.**
- **Study 1:** D9-a, D9-b and D10 change what is built or run and Argon has not seen their settlements; the five unreviewed items have had no round. All of it goes to one round, the review of CS1.1 before its commit. Nothing found since round 4 has landed on the measure or the test: round 5's findings were on walls beside the measure and on which sessions count, and the facts were on how a transcript is read.
- **What may be built meanwhile:** the changes to `constants.py` and `calibrate.py`, the calibration run, the rewritten tests of steps 7 to 9 and their builds. **What waits for the round:** the criterion's commit, the manifest, G100's arm and the first session.
- **Study 2:** D11 to D14 are open and unanswered.

## After Argon's round six on CS1.1

Appended 2026-11-12 22:22 UTC (17:22 EST) by Claude Fable 5.2, session "architect: CS1.1 convergence". **Read for it:** Argon's round 6 in full (`audit/reviews/2026-11-12-argon-web-study1-r6.md`); `architecture.md` section 5; the build plan's step 0 and steps 5 to 9; `audit/decisions.md`, 2026-11-12 15:13 UTC (10:13 EST), 15:23 UTC (10:23 EST) and 15:29 UTC (10:29 EST); how the frozen harness starts its processes (`gate/agent/daemon.py`, `sandbox/session.py`); the names of the tests at `6e626e6` and `1da9870`, and `test_manifest.py`'s judged-path helpers. **Not read:** the other test bodies, and the code under `gate/control/`. So where the list of obsolete tests below turns on a test's body, it says so.

### In plain words

- **What changed.**
  - **One session a market.** No session is run again, and there is no void. A session that leaves no pick is the agent's miss, whatever ended it. Round 6 asked for a second decision, with each void counted as a miss, to gate the claim. That decision never reads a rerun, so it is now the only decision and the reruns are gone.
  - **An unnamed id** makes its session a miss and stops the runner for a person. It no longer ends the study.
  - **Wall 5** allows a constant position 14 of 200 markets, for 51.
  - **The claim** is of the agent at the shares of fallback the study met.
  - **Two gaps from the test writer.** A restart reads a killed session's ledger only after its kernel process has exited. The manifest hashes every file of the repository that an arm imports, and `flake.lock`.
- **What is agreed.** Argon agrees four more points (A35 to A38). The architect accepts all four of its findings.
- **What is disputed.** Nothing. One settlement, D10, is in a form Argon has not seen. Its judged decision is the one Argon's own rule gives on every path, by the derivation below.
- **Is study 1 converged?** Yes: no open dispute would change what is built or run. What remains is a review that was always owed and is not a dispute: Opus's last review of CS1.1's final text before its commit. Study 2 is as it was.

### Who has seen what

| Round | Reviewer | Reviewed | Record |
|---|---|---|---|
| 6 | Argon | Study 1 at `54c11fb`, CS1.1's text included | `audit/reviews/2026-11-12-argon-web-study1-r6.md` |
| Last review | Opus, owed | CS1.1's final text, and one session a market | Before the criteria commit (`CLAUDE.md`, Orchestration) |

The section above also owed a fresh Opus review of the agent as served, the reader of ids and the void rule. Its record is not among the files read for this section. Argon's round 6 examined the first two (A37), and the third no longer exists.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A35 | Wall 3 for each mirror pair at 4 of 200: some pair is stopped falsely with probability 0.005, and a pair whose even part earns on 4.5% of markets is stopped 95% of the time. D9-a closes | Examined by Argon, round 6 | 5.5, step 5 |
| A36 | Judging a session cut off after an evaluation on its kept ledger closes the selection that a score informs, and the sizes 0.073, 0.117 and 0.338 are exact | Examined, round 6 | 5.2, `reruns` |
| A37 | Reading a session's models from its responses' ids alone is exact, and the agent as served keeps the size of 0.043 | Examined, round 6 | 5.1, 5.2, step 8 |
| A38 | The manifest's hashes, and lines that carry what the report needs | Examined, round 6. The judged path has since widened (G2) | Steps 7 to 9 |
| A39 | Wall 5 must show that a constant position earns less often than G100, and 51 of 200 tested the other direction | Conceded to Argon, round 6, D9-b. Its figures for an agent with no search, 0.538, 0.768 and 0.284, are 0.400, 0.622 and 0.168 by exact enumeration (`walls`); the point stands | 5.5 |
| A40 | A second decision cannot claim on markets that the first decision's boundary stopped, once one earning market is turned into a miss | Conceded to Argon, round 6, D10-a: its algebra is exact | 5.2 |
| A41 | A rerun before any evaluation can select on which model answered | Conceded to Argon, round 6, point 2a. With A33 this withdraws A20, and the rule drawn from A11: such a session is still no observation of the agent, and a miss needs none | 5.2 |
| A42 | The claim is of the agent at the shares of fallback the study met, and the rate for each set of ids is confounded by how long a session runs | Conceded to Argon, round 6, D10-b | 5.2, 5.4, CS1.1 |
| A43 | One stray id must not end the study | Conceded to Argon, round 6, D16 | 5.2, step 8 |

### Settled

| | Point | Settled by | Changes |
|---|---|---|---|
| D9-b | **Wall 5's count.** Argon: 14 of 200 | **A computation,** Argon's count with a derivation of its own: 14 is the largest count that a constant earning at 0.11, the least G100's rate can be, stays within with probability at most 0.05 (0.039; `walls`). An agent that submits a constant earning less often than G100 is under the null. The wall passes a constant at 0.05 with probability 0.92 and one at 0.07 with 0.57, so a stop near those rates goes to the architect as a question about 200 markets | **Yes:** `CONSTANT_ALLOWED` |
| D10-a | **The stopping rule.** Argon: run on until the second decision leaves "continue" | **A derivation,** not yet seen by Argon. Write `S` for the first decision's sum and `S'` for the second's. A market with a rerun is a miss in `S'`, so `S' ≤ S` at every market. If `S'` crosses the upper boundary first at market `K'`, then `S` has stayed above the lower boundary and is at or above the upper one at `K'`: the first decision claimed too. So a claim that needs both decisions is a claim of the second alone, and the second never reads a rerun's outcome. Under Argon's rule each rerun is a session, of about 35 in the window, spent on an outcome nothing judges. The cause was two decisions on one stopping rule. Now there is one decision, the second, and no rerun | **Yes:** step 8, `MAX_VOIDS`, `voids.jsonl` |
| D10-b | **What "Met" needs, and what the claim covers.** Argon: gate it on the second decision; state the share and the confound | **The same derivation** for the gate: "Met" is that decision, on every path Argon's rule would claim. The two statements are adopted in 5.2, 5.4 and CS1.1 | **Yes:** CS1.1, step 9 |
| D16 | **An id the manifest does not name.** Argon: check for a void first, probe more failures, pause | **A derivation.** A miss in place of any outcome never makes a claim (L6.4), so a session with such an id is a miss, and the runner stops for a person. No order of checks is left to choose. `NOTICE` is `<synthetic>` (`audit/decisions.md`, 2026-11-12 15:29 UTC (10:29 EST)). An id that the probe did not show costs one market, so no further probe is owed | **Yes:** step 8; the state "model changed" goes |
| G1 | **A killed session's ledger.** The test writer: the daemon's kernel process outlives the runner and may commit an evaluation in flight | **A fact and a rule.** The session's `claude` dies with the runner (`sandbox/session.py`, `--die-with-parent`). The kernel process does not, and its command line names the ledger. A restart waits until no process's command line names a kept ledger before it reads it. Tested by killing the runner under a process that commits late | **Yes:** step 8, behaviour 6 |
| G2 | **The judged path.** The test writer: both arms run code outside `gate/control/` that neither the harness hash nor the manifest covers | **A definition.** The judged path is every file of the repository that an arm imports, whatever its directory, with no exception for what the harness hash also covers, and the manifest hashes `flake.lock`. The tests at `6e626e6` walk `gate/control/` only, and are amended | **Yes:** step 7, L7.3 |

**The cost of one session a market** is power where sessions are lost. The 41 pilot sessions outside the swarm all reached a designed end, which bounds the share lost at 0.07. There an agent at 0.5 claims with probability 0.896 on the worst powered row, for 0.943. At one session in five it is 0.734. The runner stops after each such session, so an outage costs one market.

D6, D7, D8 and D11 to D15 stand as they were.

### Tests and constants that become obsolete

The plan lists them with what replaces each (`briefs/1-positive-control.md`, "What is built, and what this text changes"). Names are as at `6e626e6`, and `test_calibrate.py`'s as at `1da9870`.

| Test file | Deleted | Rewritten |
|---|---|---|
| `test_runner.py` | `test_a_void_is_rerun_on_the_same_market_and_has_no_result_line`; `test_a_void_session_is_kept_under_its_market`; `test_the_third_void_on_a_market_pauses_the_runner_and_a_restart_resumes_at_that_market`; `test_a_restart_after_a_pause_gives_the_market_three_more_sessions` | `test_a_crash_after_an_evaluation_is_judged_a_crash_before_one_is_void_and_a_zero_exit_without_one_is_a_miss`; `test_an_id_outside_served_ends_the_study_and_its_market_has_no_result_line_and_no_void_line`; `test_killed_during_a_session_without_an_evaluation_is_a_void_and_the_market_is_run_again`; `test_l8_5_a_kill_outside_a_session_changes_nothing_and_one_during_it_gives_a_void_or_its_ledgers_line`; `test_l8_6_a_void_adds_no_result_line_and_every_session_is_a_line_a_void_or_the_model_change`. `test_killed_during_a_session_with_an_evaluation_is_judged_from_its_kept_ledger_and_not_rerun` gains G1's late commit. The module's note and its imports of `MAX_VOIDS` and `project_void` |
| `test_report.py` | `NOT_REACHED`; `test_a_claim_that_voids_counted_as_misses_do_not_reach_carries_the_sentence`; `test_voids_counted_as_misses_can_still_claim`; `test_a_model_change_is_an_end_inconclusive_at_the_markets_judged_with_its_cause` | `test_a_paused_or_unfinished_study_is_reported_as_not_ended`; `test_a_claim_names_the_models_that_answered`; `test_the_agents_rate_for_each_set_of_ids`; `test_cut_off_sessions_and_every_market_model_id_and_ending_appear`, if its body reads `voids.jsonl` |
| `test_manifest.py` | `MAX_VOIDS` in `NAMES` | `test_files_name_the_inputs_and_exactly_the_judged_path`; `test_l7_3_a_new_module_an_arm_imports_is_hashed_and_a_new_test_is_not`; the helpers `imported`, `judged_path`, `hashed_under` and `check_judged` |
| `fakes.py` | `project_void`; `Drive.voids`; "model changed" in `ENDING_STATES` | `simulate`; `KINDS`, which gains a crash with no evaluation and an unnamed id as sessions that count; a stand-in for the kernel process, new |
| `test_calibrate.py` | None | `test_the_constants_the_search_rests_on` and the module's note: 51 becomes 14 |
| `test_sequential.py` | None | None |

The tests that stand on changed fakes, without a change of their own, are `test_l8_4_no_session_starts_after_a_line_that_ends_the_study`, `test_l8_laws_hold_under_kills_at_random_moments` and `test_report.py`'s three laws.

**Constants and names.**
- `CONSTANT_ALLOWED`: 14, for 51.
- `MAX_VOIDS`: deleted.
- `NOTICE`: `<synthetic>`, for "the id the advisor records, or none".
- `EVEN_ALLOWED` (4) and `SERVED` are as they were at `54c11fb`. `constants.py` on every branch still holds `EVEN_ALLOWED = 9` and neither `CONSTANT_ALLOWED`, `SERVED` nor `NOTICE`.
- Gone with the void: the file `voids.jsonl`, the states "paused" and "model changed", and the report's sentence "With its void sessions counted as misses, the claim is not reached".
- New: law L8.8; the report's sentence "The sets are not arms: which ids answer a session depends on how long it runs"; `flake.lock`'s hash in the manifest.
- `arithmetic.py.txt`: `voids` is now `reruns`, and `sign_test` prints from `sign_path`.

### Assumptions only the human can choose

None is open.

| | Assumption | Status |
|---|---|---|
| H9 | A session that an outage ends before its first evaluation is the agent's miss, and is not run again | Decided by the architect, for the human's review. The other choice keeps the reruns beside a decision that does not read them. It protects no claim, and it spends a session for each rerun |

### Owed before the manifest, by the advisor

- **Opus's last review** of CS1.1's final text, then its commit alone.
- **`audit/decisions.md`:** one entry for this round's settlements and H9.
- **Closed from the section above:** the client's own id is recorded, and the swarm's count is 89 of 128 by the advisor's scan, which 5.2 now quotes.

### Convergence

**Study 1 and CS1.1: converged.**
- Every dispute of rounds 4 to 6 on study 1 is closed by a point Argon examined (A25 to A38), by a finding the architect accepted (A39 to A43), or by a derivation above.
- D10's form, one session a market, goes further than Argon asked. It cannot reopen the dispute on the judged result, because its decision is Argon's on every path. If Opus's last review finds a path where the two differ, that is a finding that changes the design, and one more round is owed.
- **What may be built now:** `constants.py`, `calibrate.py`, the calibration run, the rewritten tests of steps 7 to 9 and their builds. **What waits for the criteria commit:** the manifest, G100's arm and the first session.

**Study 2:** D11 to D14 are open and unanswered.

## After the calibration's cost wall, study 1

Written 2026-11-14 00:14 UTC (2026-11-13 19:14 EST) by Claude Fable 5.2, sessions "architect: study 1 calibration cost" and "architect: kernel version 2 and study 2". No outside model has seen this revision.

### In plain words

- **What happened.** Step 5 was costed by its kernel evaluations, 20 core-hours. Built, it cost 1,223 to 1,439, because a fresh pair went through the recorders' revision store, whose row hash the kernel never reads.
- **What changed.** A fresh pair is written with the columns the kernel reads. Nothing is kept between trials. The job spreads over hosts by its own resumption. It now costs 352 to 443 core-hours (`arithmetic.py.txt`, `calibration_cost`).
- **What did not.** Every definition, constant, wall and size, so every word of CS1.1.

### Agreed, by derivation; not yet reviewed

| # | Point | Rests on | Could it change a judged result? |
|---|---|---|---|
| A44 | A market written for scoring scores as the market does | The plan's L1.5, tested by another model (`16483b5`): the frozen kernel skips the two columns as it reads | **Yes** if false. The law's test is the evidence |
| A45 | A trial is a function of its market and its strength alone | Step 5, behaviour 7, tested (`16483b5`) | Yes, through the strength |
| A46 | The report does not depend on the hosts, their weights or the order of merging | The plan's L5.6. Its merged-log half is tested (`16483b5`); the partition, repeated and differing lines, and the probe are not yet | Yes, through the strength |
| A47 | Hosts may differ in the last bit of a generated market | numpy chooses its transcendental functions by CPU. The probe compares one whole trial across hosts before the search, and differing lines of one trial stop the run | Yes. If the probe differs, the calibration runs on hosts of one CPU kind, and the manifest names them |

### Tests that become obsolete

| File | Obsolete | In its place |
|---|---|---|
| `test_calibrate.py` | `test_a_twin_is_made_once_across_strengths`; the module note's "Twins are made once" (A34's "twins made once", above) | `test_a_trial_makes_its_own_pairs_and_keeps_no_market` (`16483b5`) |
| any test passing `twins` to `judge`, `fresh_scores` or `g100_trial` | the argument | none |

### Owed

- **L5.6's remaining tests,** by a model other than the builder's, before the calibration runs on more than one host. On one host the built resumption is enough, and the run may start there.
- **Opus's last review** before the manifest reads A44 to A47 with the calibration's report.

### Convergence

**Study 1: converged, as after round six.** The revision changes cost and not the claim. A44 is the one point on which a judged number rests, and it is a tested law, not an argument.

## After Argon's round 1 on kernel version 2, and study 2 re-derived

Appended 2026-11-14 07:52 UTC (02:52 EST) by Claude Fable 5.2, session "architect: kernel version 2, study 2 and the build plan". **Read for it:** `facts-kernel-v2.md`; Argon's round 1 in full (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r1.md`); `architecture.md` sections 2 and 6; the last session's report; the human's five answers of 2026-11-14. **Not read:** any price, any code of version 1 or of stage 7, `SEMANTICS.md` itself (its content through the fact pack and Argon's citations). Numbering continues after A47 on `study1-build`.

### In plain words

- **What changed in the kernel.** Argon's seven findings all hold in substance, and I patched none of them. Three causes carried them:
  - **Floats computed orders, and money sat on a grid.** Now a float decides whether, exact arithmetic decides where and how much, and the ledger is rational and never rounds. Findings 1 and 2 have nothing to land on.
  - **A fill rule was about one order.** Now a fill is an allotment of recorded evidence over all the account's orders, each lot once, and trades are built. Finding 3.
  - **Version 2 carried version 1's venue only to be compared with it.** Under the human's clean-room answer the `table` venue, the target slot and the decision comparison are deleted; what is compared with `mm` is the float evaluator, bit for bit. Finding 6.
  - Also deleted: legs, isolated margin, the rounding law, the single-order monotonicity law.
- **What changed in study 2.** The tested wealth is the replica's own account, long only and compounding, measured in units of a basket of its universe held at the account's own exposure. That one object answers the margin, the hedge and the bet (D11 to D13) and round 1's findings 4 and 5. Fidelity is defined on the vault's fills in four layers (D14).
- **What it costs.** No exact test bets more than an account that cannot owe. A dip-buying ladder keeps room for 27.6 first buys and holds 2 on average, so its account is nearly idle, and the forward test is expected to end "not confirmed". The table of years by account volatility says so in advance. This is study 2's finding, not its failure.
- **What is disputed.** Nothing I have refused. Everything below is unexamined by Argon in its new form.

### Who has seen what

- **Argon:** parts A and B at `a829c07` and my notes on D11 to D15. It has not seen this revision.
- **GPT, Opus:** neither has seen kernel version 2 or the re-derived study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A48 | One event-driven machine; venues are records of what varies | Examined by Argon, round 1, ledger point 1 | kernel A1, A3 |
| A49 | Own-state inputs arrive with the observation delay; no order fills on evidence the program saw | Examined by Argon, round 1, point 2 | kernel A5, L1, L1b |
| A50 | Lean holds what decides a number, behind four pure functions; OCaml holds the world | Examined by Argon, round 1, point 3 | kernel B1, B2 |
| A51 | Version 2 is a clean-room design | The human, 2026-11-14; Argon, point 4 | kernel B4 |
| A52 | D14's layers on the vault's fills, and D15 | Examined by Argon, round 1, point 5. The fourth layer and the wall on layer 3 are new since | architecture 6.3 |
| A53 | The threshold `20(1 + ε̄)` is wrong under compounding | Conceded to Argon, finding 4: 0.0550 at 21 (`study2`) | architecture 6.1 |
| A54 | A hedge made of orders fails the minimum order and initial margin | Conceded to Argon, finding 5 | architecture 6.1 |
| A55 | Single-order laws say nothing of runs, and a rule about one order counts a seller once a rung | Conceded to Argon, finding 3 | kernel A7 |
| A56 | A list of excused differences excuses a broken engine | Conceded to Argon, finding 6 | kernel B4 |
| A57 | Properties alone are met by an engine that does nothing; funding and cycles had no law | Conceded to Argon, finding 7 | kernel B3 |

### Settled by a derivation Argon has not seen

| | Dispute | Settled by | Changes |
|---|---|---|---|
| D11 | **Margin and the loss bound.** | The wealth is an account that cannot owe, so it is non-negative with nothing added. Against "mean at most zero, loss at most `L`" the exact wealths are those betting at most `1/L`, so nothing bets more than the account. Leverage above 1 waits for a certificate of V7 | **Yes** |
| D12 | **The hedge, against changing exposure.** | A null true for every rule without skill under unknown drift needs the benchmark at the rule's exposure at every step. So the benchmark is the unit of wealth, `M = W / B`, not a position. Market-wide timing is then invisible, and no exact test can see it | **Yes** |
| D13 | **The frozen bet.** | The bet is the account's sizing, `b / σ̂` of equity with `σ̂` trailing, under a cap. 5.32 years at a bet of 2 and Sharpe 1.4 by this program's formula; Argon's 6.13 is not reproduced, and neither is 4.4 right | **Yes** |
| D14 | **Fidelity on fitted dates.** | Each part is checked against what was not fitted through the kernel: the ledger against the venue's own arithmetic, the rules against real maker fills, the ladder given real first buys with constants read off fill prices. The trigger, the one fitted part, is checked only after 2027-01-31 | **Yes** |
| D15 | **Perp brackets in the account.** | Conceded: the null at the fill, pending payouts never cash (`account`; section 4's week-end column moved by up to 0.015) | No study uses it |
| D17 | **Binary64 and directed rounding.** | Conceded; two sorts with total crossings, decimals recovered or rejected, no tolerance | **Yes** |
| D18 | **The integer ledger's laws contradict.** | Conceded; a rational ledger that never rounds | **Yes** |
| D19 | **The overlap with version 1.** | Conceded; the `table` venue is deleted and the evaluator alone is compared | **Yes** |
| D20 | **Specification gaps and missing laws.** | Conceded; `time` and `known`, a horizon, one admission order, latest-known inputs, and a characterization for every rule | **Yes** |
| H10 | **Physical or statistical hedge and sizing.** Argon gave it to the human; the human gave it back | Neither as posed. Sizing is physical, because only an account has a loss bound. The benchmark is neither an order nor a subtraction: it is the numeraire. A subtraction has no lower bound when the basket rallies, so it is not exact | **Yes** |
| H11 | **Trades now or later.** | Now. The forward recorder carries them, the judged venue needs them, and the bucket is read slow period first within 12 USD | **Yes** |

### What Argon should attack first

1. **`M = W / B` as the claim.** Build a rule with no skill that makes `M` drift up: by beta, by coins that are not exchangeable, by steps of five minutes, by the basket's membership changing. And build an exact test that credits market-wide timing under unknown drift, which I say cannot exist.
2. **"Nothing bets more than the account."** Find an exact wealth on a ladder's returns that grows faster than the account, without a bound the rule does not have.
3. **Evidence allotment.** Find a path where `pessimistic` credits a lot that no seller offered through the price: across successive snapshots, between a print and a quote, at an arrival and a resting fill on one quote.
4. **The decimal reading.** A recorded double that is read as a decimal the venue never wrote, within 15 digits.
5. **Layer 3's wall.** A fill rule that flatters forward and still sums under the vault's profit before the freeze.
6. **What the deletion of the `table` venue loses,** if anything a later study would need that two `market` slots do not give.

### Assumptions only the human can choose

- **Whether "earned" may ever be the claim.** The judged wealth is `M`, on the advisor's decision. If the vault's edge is buying market-wide dips, `M` shows nothing by construction, and `W`, which a rising market can satisfy, is the only wealth that would show it.
- **Leverage in a judged account.** Above 1 the test's exactness rests on the venue's own rule that an account cannot owe. A certificate can quote it; whether a quoted rule is enough is a terms reading.

### Convergence

**Kernel version 2: not converged.** Every finding of round 1 is conceded and re-derived, but the re-derivation is new design that no reviewer has seen: the two sorts, the rational ledger, the allotment, and three deletions. A second round is owed, on another model than the first where one is available.

**Study 2: not converged.** D11 to D15 are settled by derivations Argon has not seen, and the claim's object changed. Nothing of study 2 may be registered before a round on section 6.

**Study 1** is as the section above leaves it.

## After round 2 on kernel version 2 and study 2, by Argon and GPT side by side

Appended 2026-11-14 15:40 UTC (10:40 EST) by Claude Fable 5.2, session "architect: kernel version 2, round 2". **Read for it:** both reviews in full (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r2.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r2.md`); the human's answers of 2026-11-14 14:59 UTC (09:59 EST); my own `kernel-v2.md`, `architecture.md` sections 2.2 and 6, the build plan, `arithmetic.py.txt`'s study 2 part, and five lines of the fact pack (funding's cap, the fills cap). **Not read:** any price, any code, `SEMANTICS.md`. Numbering continues.

### In plain words

- **The reviewers were right that round 1's causes had survived.** Both said so, and named where. I found three confusions under their findings, each of which I had carried from one representation to the next:
  - **A state taken for a flow.** A quote shows who is standing; I counted it as a sale, once an event, so one seller filled five levels in five snapshots. The same confusion made the program's late copy of `filled` decide what the world still owed an order, and made one law speak of a single "machine state". Now only a seller's print fills a resting order, an order is a target whose remainder the world computes, and the world and the program's view are two states with a law each.
  - **The account taken for the test.** The account gives a loss bound; the test is a bet on the account. Merged, they gave "nothing bets more than the account", an account that had to compound and size itself by volatility, and a floor that looked like a bound. Now the bet is the account's profit over what it has at risk each step. The account's size cancels. Leverage cannot be exact, and the reason is a formula.
  - **A benchmark taken for a null.** `M = W / B` and layer 3's wall were the same move: pick a comparison, then say what passing it means. A ratio to a benchmark is fair only against the best holding, and a sum on the past says nothing of flattery later. Now the claim is two nested nulls, each named for exactly what it says, and fidelity is order by order with no wall.
- **What was deleted:** `M` and `B`, the sizing `b / σ̂` and the cap `G`, the certificate of V7 as a wall of study 2, layer 3's wall and one fidelity layer, quote evidence, the market order, the old L1, F1 as a law.
- **What was added:** the report's `at_risk`; a certificate that Lean checks for the best mix in hindsight; a bar source; protected dates and recorded-before-published in the kernel.
- **What I refused:** Argon's `M*`, his paired statistic, and his reading of notional sizing as a defect. Each by a derivation in `kernel-v2.md` part C and `architecture.md` 6.1, the second by a number in `arithmetic.py.txt`.

### Who has seen what

- **Argon and GPT:** `2a4cd2a`, from the same bundle. Neither has seen this revision (`c4b9d77` to this commit).
- **Opus:** has not reviewed kernel version 2 or study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A58 | One event-driven account and an exact rational ledger; the Lean and OCaml split | Examined by both in round 2 (Argon's agreed points 1 and 2; GPT's 1 and 2) | kernel A1, A2, B1, B2 |
| A59 | Neither fill rule bounds a run | Both (GPT's point 3) | kernel A7 |
| A60 | A ratio to a benchmark is a valid test of its own stated null, and that null is not "no skill" | GPT's point 4, conceded by me | architecture 6.1 |
| A61 | A floor gives a non-negative account, not a supermartingale under fair prices | Both (Argon's finding 2, GPT's 5), conceded | architecture 6.2 |
| A62 | The account is not the fastest exact wealth on its returns; the bound is a step's own | Both (Argon's finding 2, GPT's 4), conceded | architecture 6.1 |
| A63 | Evidence allotted once an event still spends one seller across events | Both (Argon's 3, GPT's 6), conceded | kernel A7 |
| A64 | A sum of profits on the past does not show a rule will not flatter | Both (Argon's 5, GPT's 8), conceded | architecture 6.4 |
| A65 | L1, S1, the funding convention and conservation contradicted the transitions | Both (Argon's 7, GPT's 9 to 13), conceded | kernel B3 |
| A66 | The forward test should run as prospective validation, with a budget and a reading; a non-confirmation is not absence | Both recommended it; decided | architecture 6.6 |
| A67 | Deleting `mm` under a tag keeps the pilot's results reproducible, and leaves version 2 unable to run bars unless it is given them | Both; the human's answer 3 | kernel A16 |
| A68 | Protected dates, metered disclosure and effective-dated rules were work instructions, not contracts | GPT's 16 to 18, conceded | kernel A13; the build plan's table |

### Settled by a derivation the reviewers have not seen

| | Dispute (the reviewers' names) | Settled by | Changes what is built |
|---|---|---|---|
| D12-v3 | `M = W / B` leaks drift five ways | Deleted. Two nested nulls on one wealth; rung 2 measures against the best constant mix in hindsight, so every constant holding is inside the null. Exact by Ville on the null's own mix, 5% for the pair by nesting | **Yes** |
| D12-v3b | An exact test that credits market timing | Conceded that one exists; it is rung 2. GPT's permutation test is valid under the same reading and needs reordered books; Argon's pairing is not a null statistic (435 standard errors above zero on independent returns) | **Yes** |
| D11-v3 | The bet at a leverage of 1; the floor above it | The wealth bets a step's profit over its `at_risk` (law Q1, assumption V16). Leverage: `P ≤ (1 + E[absorbed]) / 20`, so no exact test takes it. Argon's 0.59 to 0.80 of power is not reached: 13.9 times an idle account is a fully staked one, with volatility near 0.25 to 0.5 | **Yes** |
| D14-v3 | Double counting across events; layer 3's wall | Only sell-aggressor prints through the price fill a resting order. The wall is deleted; layer 2 is order by order with a one-sided property | **Yes** |
| D17-v2 | The decimal bound | Strings enter as integers; doubles are read only from the archive; the range is a range; X2 is a theorem; the grid catches a double that was never a decimal | **Yes** |
| D19-v2 | Bars and target weights after `mm` | A bar source derives a quote and two prints under four registered assumptions; a target weight is two `ioc` slots under target semantics | **Yes** |
| D20-v2 | Laws against transitions; missing laws | Two states; L1, L1a, S1, U1, A1, X1 restated from the transitions; P1, Q1, K1, K2 added | **Yes** |
| D21 | GPT's 11: a later quote decides an earlier gap | Staleness is causal | **Yes** |
| D22 | GPT's 16 and 17: dates and the meter | The windows compiled in and checked at admission; an attempt row before the engine starts and a result row before anything is published | **Yes** |
| D23 | GPT's 18: polling | Hourly copies; a missed change of grid fails admission; the vault's own fills witness the fee schedule; overlapping pulls prove none was lost | **Yes**, the recorder |
| H12 | Which claim study 2 judges (Argon gave it to the human; the human gave it back) | Both rungs, with no choice to make | **Yes** |
| H13 | A leverage of 1 with a predictable bet, or physical leverage | The first, by 6.2 | **Yes** |

**Still open in substance, by my own account:** the program's grammar, the chunk's layout and the events' encodings are not written (GPT's finding 15). They are owed before the build's steps 3 and 4 and need no review round of their own unless they change a rule.

### What the next round should attack first

1. **Rung 2.** Build a rule that knows nothing of when, and gets no fill better than a mid, yet reaches 20 times the best constant mix more than one time in twenty. Try volatility that clusters, patterns inside the day, the daily step against steps of a minute, a mark carried through staleness, a coin leaving the universe. Try to break the nesting, and the certificate.
2. **Q1 and V16.** Find a path where a step loses more than its `at_risk × (1 + ρ̄)`: an order pending across steps, a replaced order and its replacement both filling, a delay `λ` longer than a step, funding at an oracle price far from the mid.
3. **6.2's bound.** Find an exact test that takes leverage, or a hole in `(1 + E[absorbed]) / 20`.
4. **Sells through the price.** A path where `pessimistic` credits a lot no seller offered; a sound rule that breaks layer 2's one-sided property (a hidden order, an aggressor flag that is wrong, an order the vault moved).
5. **Two states and targets.** Whether L1a is provable as written; an effect the view should not have, or lacks; a program that `close` or a target strands.
6. **Bars.** A contradiction between A16 and A7, or a fifth assumption hiding in the four.

### Assumptions only the human can choose

- **The reading of "timed".** Its null is exact as stated. It means "no knowledge of when" only in a market whose days are alike; a rule that holds less when volatility is high also passes it. GPT lists the choice of such an assumption as the human's.
- **Replenishment (V10).** A taker's fill does not thin the next snapshot. The cap keeps this small; it is a hypothesis and not evidence.
- **Disk for two years of recordings.** The forward test's one cost beyond a replay a month.

### Owed

- **By the advisor:** the trades bucket's certificate, now a requirement and not an option; the vault's pre-freeze fill responses stored under `data/` with a hash; the recorder's hourly copies of rules and fees and the hourly, overlapping pull of the vault's fills; before `mm` is deleted, the reference evaluator's streams on the C6.4 corpus under a hash, and the list of what runs only on `mm`.
- **By the architect:** `KERNEL.md`'s encodings and grammar; study 2's criteria (the two rungs and their nulls), after the next round.

### Convergence

**Not converged, on kernel version 2 or on study 2.** Every finding of round 2 is conceded and re-derived or refuted, but six pieces are new design that no reviewer has seen: the two rungs, the bet on what is at risk, fills on prints alone, orders as targets, the two states, and the bar source. Nothing of study 2 may be registered before a round on `architecture.md` 6.1 and 6.2.

**The test of whether this was patching.** Round 1's causes came back in round 2 because I had changed their representation and kept the confusion. If round 3's findings land again on a state counted as a flow, on the account standing in for the test, or on a comparison standing in for a null, the design is still wrong there and is re-derived again, not amended. Findings on the six new pieces are the ordinary cost of new design.

**The next round** goes to both outside models again, since each caught what the other missed (Argon the ladder's own numbers, GPT the laws and the three leaks), with the six attacks above; a fresh Opus session if either is out.

**Study 1** is as the earlier section leaves it.

## After round 3 on kernel version 2 and study 2, by Argon and GPT side by side

Appended 2026-11-14 17:50 UTC (12:50 EST) by Claude Fable 5.2, session "architect: kernel version 2, round 3" and its continuation (the first session hit its usage limit in task 3). **Read for it:** both reviews in full by the first session (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r3.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r3.md`); by the continuation, my own `kernel-v2.md`, `architecture.md` section 6, the build plan and this ledger's last section, and not the reviews again. **Not read:** any price, any code. Numbering continues. The findings, cause by cause, are in `kernel-v2.md` part C.

### In plain words

- **All three of round 2's confusions came back.** Neither reviewer said so; I do, by the test this ledger set for itself.
  - **A benchmark taken for a null, a third time.** The best mix rebalanced daily while the wealth re-staked every step, so the test's own arithmetic beat it. A benchmark is a null only if it is the best any wealth with the test's own opportunities can do, its clock included. It now trades at every quote, the record's own clock.
  - **A state taken for a flow.** An order outlived the cycle its target was a quantity of, and got its target back. An order now ends with its cycle.
  - **The account taken for the test.** I asked the account to take no leverage and keep cash. The test needs only a loss known at a step's start. Profit is taken before absorption, and the categorical "leverage cannot be exact" is withdrawn.
- **What was deleted:** the daily benchmark, its proposed mix and the inequality of means; the void of an uncovered run; the cash law at a leverage of 1; the replay of the vault's cycles in layer 2; a bar's own times and `known` rule, and the claim that bars are read classically; quote evidence under `optimistic` on `b ≤ p`.
- **What was added:** three sums a coin in the report; `fundable`; spans; one wish a slot a tick; the view's own staleness; the report's counting of fills.
- **One finding is mine and unreviewed.** The report valued a fill at a mid older than the fill. At steps near the quote interval an account with no skill gained from it (`arithmetic.py.txt`). The report now counts a fill from its coin's next quote.
- **What I refused:** Argon's stranded target weight, the 10 USD remainder, and undefined inputs at the first tick, each by a line in `kernel-v2.md` part C.

### Who has seen what

- **Argon and GPT:** `d014b87`, from the same bundle. Neither has seen this revision (`7c3ffe3` to this commit).
- **Opus:** has not reviewed kernel version 2 or study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A69 | Round 2's causes are largely removed at the cause: two states, fills on prints, a bet on what is at risk | Both, round 3 | kernel A1, A7; architecture 6.1 |
| A70 | A benchmark that trades slower than the wealth, or in a wider domain, is not a null: rung 2 passed without timing, and the certificate was false for a non-positive factor | Both (GPT's 1, 2; Argon's 1.1 to 1.3, 1.5), conceded | architecture 6.1 |
| A71 | An order that outlives its cycle regains its target; fills during the delay break the step's bound | Both (GPT's 3, 10; Argon's 2.1, 2.2), conceded | kernel A6, S1, Q1 |
| A72 | A cap on a rate is not a cap on a payment; voiding a run truncates a loss | Both (GPT's 4; Argon's 2.3), conceded | kernel V16; architecture 6.1 |
| A73 | The delivery law is provable only if staleness belongs to the delayed view | Both (GPT's 9; Argon's 5.1, 5.2), conceded | kernel A3, L1a |
| A74 | Targets and `close` need the semantics of a pending action and of an order's status | Both (GPT's 10; Argon's 5), conceded | kernel A1, A6, R1 |
| A75 | The bar source contradicted the fill rules and its classical readings | Both (GPT's 11; Argon's 6), conceded | kernel A16 |
| A76 | Laws bounded from one side admit a confirmer that never confirms | Both, conceded | kernel K1, K2 |
| A77 | `optimistic` must read `a ≤ p`; `absorbed` must not be in `pnl`; grid rounding broke the replayed layer 2 | Argon alone, conceded | kernel A7, A12; architecture 6.4 |
| A78 | The leverage prohibition was sound only conditionally; funding can take reserved cash; layer 2 did not know when a real order stood; copies at intervals and overlapping pulls do not prove completeness; a global set of trade IDs breaks the memory wall | GPT alone, conceded | architecture 6.2, 6.4; kernel A6, B1; the build plan's table |

### Settled by a derivation the reviewers have not seen

| | Dispute | Settled by | Changes what is built |
|---|---|---|---|
| D12-v4 | Rung 2 passes without timing; the certificate | The benchmark on the quotes' clock, a mix for each span, the rung ending at a payment at or above the mid. The certificate is `log(1 + x) ≤ x − x²/2 + x³/3`, three sums a coin and a multiplier's dual bound, checked in Lean | **Yes** |
| D11-v4 | Q1 and V16; leverage | `at_risk` counts the live order and the wishes on their way; `fundable` gives funding room only where a settlement is due; an uncovered step ends the test in step order. `V` is exact at any leverage once profit is before absorption | **Yes** |
| D24 | Orders across cycles | An order belongs to one cycle and is cancelled at its end; one wish a slot a tick, compared on arrival | **Yes** |
| D14-v4 | The two fill rules; layer 2 | One principle, the burden of proof. Each real maker fill is one order alone at its own price; `optimistic` must fill it by its real time, and `pessimistic`'s lateness is measured | **Yes** |
| D19-v3 | Bars | Three ordinary events at a bar's end; the classical equivalence withdrawn | **Yes** |
| D20-v3 | The laws | L1a's two premises; K1 and K2 as "exactly when"; fills of three kinds; the mirror for sells defined once | **Yes** |
| D23-v2 | Completeness of the forward record | Paged pulls to an unsaturated page; V3 and V4 say what no copy sees | **Yes**, the recorder |
| D25 | A fill valued at a price older than itself (the architect's) | The report counts a fill from its coin's next price; `at_risk` carries uncounted buys at cost; Q1 keeps its form | **Yes** |
| D26 | Argon's 1.4: a rule that holds less in turbulent days passes rung 2 | Not a defect; the reading of "timed", the human's | No, unless the human chooses otherwise |
| D27 | Argon's 4.1: one seller taken twice | Conceded as V10 and not removed: removing it is a model of how books refill | No, unless the human chooses otherwise |
| D28 | Argon's 5.3 and 7.2 | Refuted: a controller reading late reaches its weight at the next tick that sees the sale; the venue's minimum; nothing is known at the first tick | No |

### Disputed, still open

| | Dispute | State | Would change what is built |
|---|---|---|---|
| O1 | Rung 2's null where prints lead quotes: given the prints since a coin's last quote, its next mid is predictable | I argue it cannot favour an account without skill, since its stake in held lots was fixed at that quote. An argument, not a proof (architecture 6.1) | **Yes**, if it fails: the report's prices |
| O2 | The reviewers' "not converged" on round 3 | Answered in full, unseen by them | Unknown until round 4 |

### What the next round should attack first

1. **O1.** A market whose prints lead its quotes, coins quoted in turn, and an account without skill whose `V / B̄` drifts up. Try to make the stake in held lots depend on prints through fills.
2. **The counting of fills (D25).** A coin never quoted again; a bankruptcy whose closes are not yet counted; a sale counted late; whether Q1 as restated is the transitions'.
3. **The certificate (D12-v4).** A coin whose `Q` is negative; a return above 1; a span of one quote; the multiplier's bound against a mix an optimizer finds.
4. **Orders that end with their cycle (D24).** A fill that ends a cycle while a wish is in flight; a liquidation inside a step; `at_risk` with `λ` longer than two steps.
5. **The uncovered step and V16.** Whether stopping in step order keeps the size; a payment inside the room that still takes `V` below zero.
6. **Bars (D19-v3).** Three events a millisecond apart against `δ`, `λ` and a tick of one second; an order arriving at a derived quote.
7. **Layer 2 (D14-v4).** A real maker fill that `optimistic` cannot fill by its time though the record is complete.

### Assumptions only the human can choose

Each with its runs and my recommendation in `architecture.md` 6.8.
- **The reading of "timed".** I recommend the constant mix on the record's own clock, claimed as "not a constant holding's".
- **Replenishment (V10).** I recommend accepting it, named and counted; and a judged run with a non-zero count having no result, if the replay's count is zero.
- **Disk for two years.** I recommend more disk with a second copy on another node, decided by 2027-03-01. The 300 GiB volume is full about 2027-05-20.

### Owed

- **By the advisor:** the trades bucket's certificate; the vault's pre-freeze fills and `userFunding` rows stored under `data/` with a hash; the recorder's hourly copies of rules and fees and the paged pull of the vault's fills; `historicalOrders` if it can be certified; before `mm` is deleted, the reference evaluator's streams on the C6.4 corpus under a hash.
- **By the architect:** `KERNEL.md`'s encodings and grammar; the rounding at 128 bits; study 2's criteria, after convergence.

### Convergence

**Not converged.** No finding of round 3 is left unanswered, and under my three recommendations the human's choices change nothing that is built. But O1 would change what is built if it fails, and five pieces are new design no reviewer has seen: the benchmark on the quotes' clock with its certificate, orders that end with their cycle, the funding room with the uncovered step, bars as three events, and the counting of fills.

**The test of whether this was patching.** Round 3's findings did land on all three named confusions. Each was re-derived and not amended: the daily benchmark, the order that survives its cycle and the cash law are deleted, not guarded. The clock is now the cause to watch: it was the benchmark's in round 3 and the report's in my own finding. If round 4 finds a third clock on which something trades finer than what judges it, the wealth's construction is wrong and is re-derived from the record's events, not given another rule.

**The next round** goes to Argon and GPT from one bundle, with the seven attacks above; a fresh Opus session if either is out.

**Study 1** is as the earlier section leaves it.

## After round 4 on kernel version 2 and study 2: the test wealth re-derived

Appended 2026-11-14 20:20 UTC (15:20 EST) by Claude Fable 5.2, session "architect: kernel version 2, the test wealth re-derived" and its continuation (the first session committed tasks 1 to 4 and hit its usage limit before the report). **Read for it:** both reviews in full by the first session (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r4.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r4.md`); by the continuation, `kernel-v2.md` A12 and part C, `architecture.md` section 6 and this ledger's last section, with `arithmetic.py.txt` rerun whole, and not the reviews again. **Not read:** any price, any code. Numbering continues. The findings, cause by cause, are in `kernel-v2.md` part C.

### In plain words

- **Round 4 found the third clock, and the rule this ledger set was applied.** The stake `at_risk` moved at deciding ticks while lots were marked at quotes, so a print between the two let a wish or a fill resize the stake on a lot whose next move was known. All three confusions were back. `V` was not given another rule. It is gone.
- **The test is now a ledger of its own.** Cash and units, never negative. It trades only when the account fills, at the account's prices, from its own cash. A coin has one price, which a print moves. No fill beats the tape (law T1), so no trade of the test's can raise its wealth, and a stake cannot move without a fill.
- **The comparator is the same line of the derivation:** at a price event the wealth multiplies by `1 + w·r` and a constant mix by `1 + b·r`.
- **The claim narrowed.** Where one price event foretells the next, an account that only rebalances outgrows every constant mix. No clock repairs that. Rung 2 claims "outgrew", not "timed", and is registered only if the replay shows the bar above the hourly and daily mixes.
- **What was deleted:** `at_risk`, `fundable`, the step and its row, law Q1, the deferred counting of fills (D25, my own find of round 3), the uncovered step, O1 as an argument, and layer 2's run of each real fill as an order.
- **Nothing of round 4 was refuted.**

### Who has seen what

- **Argon and GPT:** `99f8fd5`, from the same bundle. Neither has seen this revision (`1f6a3f8` to this commit).
- **Opus:** has not reviewed kernel version 2 or study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A79 | What is sound and kept: the exact rational ledger, the world and view states, cycle-bound orders, prints as evidence, profit before absorption, the Lean and OCaml split | Both, round 4 | kernel A1, A2, A6, A7; B1, B2 |
| A80 | A stake that moves on one clock while held lots are marked on another is a trade at an old price: `V` over `at_risk` gains with no skill | Both (GPT's 1; Argon's 1.1), conceded; O1 failed | architecture 6.1, lines 3 and 4 |
| A81 | A fill held out of the report until a later quote is a state taken for a flow: a sale still open, a loss never booked, `absorbed` and its close in different steps | Both (GPT's 2, 3; Argon's 2), conceded; D25 withdrawn | kernel A12, P1 |
| A82 | The test is re-derived from one self-financing ledger on every event, the comparator from the same factorization, and compressed only afterwards | Both asked for it; done | architecture 6.1; kernel A12, K1, K2 |
| A83 | The bar's formula had a domain, its accuracy is relative, and the confirmer must see a return at or below minus one | Both (GPT's 4, 12, 13; Argon's 3), conceded | kernel A12, K1, K2; architecture 6.1 |
| A84 | A cycle ends at its closing fill, a liquidation's included; `close` is what of the position an order would reduce | Argon alone (4, 2.2), conceded | kernel A5, A6, A10, S1 |
| A85 | A wish must not carry a grid across a change of rules | GPT alone (5), conceded | kernel A6, X1 |
| A86 | A bar's three events a millisecond apart, a locked quote, an open known early and unsized depth each broke a rule | Both (GPT's 7, 8; Argon's 6), conceded | kernel A3, A16 |
| A87 | A real fill replayed as an order meets what an order meets and a fill does not | Both (GPT's 9, 10; Argon's 7), conceded | architecture 6.4 |
| A88 | An unsaturated page shows only what the API had indexed | GPT alone (11), conceded as V18 | kernel A14 |
| A89 | Rung 2 is worded "outgrew every constant mix"; a zero count of V10's takes certifies nothing; disk is sized from the measured volume, with a second copy | Both agree with the three recommendations, with these qualifications, taken | architecture 6.8 |

### Settled by a derivation the reviewers have not seen

| | Dispute | Settled by | Changes what is built |
|---|---|---|---|
| D29 | The test wealth (replaces D11-v4, D25 and O1) | The test ledger: units and cash never negative, trades only at the account's fills at their prices, one price a coin that a print moves, law T1. `W` is a supermartingale under either null for every scale that is not negative | **Yes** |
| D12-v5 | The comparator and its certificate | The mix at the same price events; spans; three fixed-point sums and the least return a coin; `n` growing with `D`; the branch for `Q ≤ 0` | **Yes** |
| D30 | What rung 2 can claim (Argon's 1.2) | Conceded as a limit: the null is false where price events foretell each other. On every path a holding never traded cannot pass, apart from funding's second-order term. The name "timed" and round 3's sentence are withdrawn; rung 2 is registered only if the bar is the highest of three | **Yes**, the replay's wall |
| D31 | The stake rule | A budget a cycle, `φ` of free cash, over a registered depth `d`. It decides power only; the replay chooses both | **Yes** |
| D32 | Funding (replaces the funding room and the uncovered step) | Paid at its event from the test's cash; one it cannot pay ends the test at a stopping time; V16 is only that a settlement charges a unit less than its price | **Yes** |
| D33 | Leverage | The ledger pays for what it holds, so the account's leverage cannot lever it; the judged account takes 1 and needs no certificate of V7 | **Yes** |
| D14-v5 | Layer 2 | The wall is a join: each real maker fill's own print is in the record, and F0 then says `optimistic` fills an order resting there. Orders are run only for a measurement by classes | **Yes** |
| D19-v4 | Bars | One time, the bar's end; prints before a quote of their millisecond; bid down and ask up; a registered depth | **Yes** |
| D23-v3 | Completeness of the forward record | V18: a registered delay, re-read whole each day | **Yes**, the recorder |

### Disputed, still open

| | Dispute | State | Would change what is built |
|---|---|---|---|
| O1 | Rung 2 where prints lead quotes | **Closed: it failed** (A80) | |
| O2 | The reviewers' "not converged" on round 3 | **Closed:** they were right | |
| O3 | Rung 1's null on prices that prints move. A real book's prints bounce between bid and ask, so that null is false there whatever the rule | I argue only a maker's fill can gain from the bounce: lots held before a print take it down and back, and a take is filled at a quote after the price has moved. A maker paid to stand is a pass the claim already names. An argument, the architect's, seen by nobody | **Yes**, if a rule that is no maker gains: the price a print moves |
| O4 | The guard on rung 2: the bar highest of the event, hourly and daily mixes | A measurement I chose, not a derived condition. A record could pass it and still let a rebalancer through at another scale | **Yes**, if a sharper condition exists; else rung 2's limit is only said |
| O5 | What the test borrows from the account: a cycle's end, a sale's fraction, never short; and its own state, the unspent budgets | I believe each touches power and not size, since any scale that is not negative is valid. Unreviewed | **Yes**, if one is a trade without a fill |

### What the next round should attack first

1. **The test ledger (D29).** A change in its units or cash that is not a fill at the fill's price: through the scale, the budget's return at a cycle's end, a sale's fraction when the ledger followed less than the account, or the cut when cash is short. One such move, with an account without skill whose `W` drifts up, breaks it.
2. **Law T1.** A fill of any of the three kinds better than its coin's price after its event: a resting order on a quote, a print at the price exactly, a settlement, a bar's two prints, `optimistic`.
3. **O3.** A book whose prints bounce, and an account that is no maker and gains.
4. **Rung 2's limit and its guard (D30, O4).** A market that passes the guard where a rebalancer still passes "outgrew"; whether a condition on the record exists under which no holding passes.
5. **The certificate (D12-v5).** A coin whose least return is at or below minus one; `Q ≤ 0` in several coins at once; a span of one event; the fixed-point rounding against a mix an optimizer finds.
6. **The end of the test (D32).** Whether ending at a payment the cash cannot pay keeps the size; a payment above the unit's price.
7. **Layer 2's join (D14-v5).** A real maker fill whose print is in the record and which `optimistic` still would not fill.

### Assumptions only the human can choose

Each with its runs and my recommendation in `architecture.md` 6.8.
- **What rung 2 is to claim.** I recommend "outgrew every constant mix, at every price event", with its limit said beside every use.
- **Replenishment (V10).** I recommend accepting it, named in both claims; the count is a diagnostic and certifies nothing.
- **Disk for two years.** I recommend more disk with a second copy on another node, sized from a measured month of the volume, decided by 2027-03-01. The 300 GiB volume is full about 2027-05-20.

### Owed

- **By the advisor:** as the last section lists, and the measurement of the recorder's volume.
- **By the architect:** `KERNEL.md`'s encodings and grammar; study 2's criteria, after convergence.

### Convergence

**Not converged.** No finding of round 4 is left unanswered, and under my three recommendations the human's choices change nothing that is built. But the test itself is new and unseen, and O3, O4 and O5 would each change what is built if they fail.

**The test of whether this was patching.** Round 4's findings landed on all three confusions, on the clock the last section named. The answer has fewer parts than what it replaced: no stake, no step, no second account of when a fill counts. The cause to watch is no longer a clock, since the test has none of its own. It is **a move in the test's books that is not a fill**. If round 5 finds one, the fault is in the ledger's rules and is fixed there. If round 5 instead finds a market where rung 2 passes without skill that the guard does not catch, the claim narrows again or rung 2 goes, and no rule is added to save it.

**The next round** goes to Argon and GPT from one bundle, with the seven attacks above; a fresh Opus session if either is out.

**Study 1** is as the earlier section leaves it.

## After round 5 on kernel version 2 and study 2: the specification's faults

Appended 2026-11-15 02:18 UTC (2026-11-14 21:18 EST) by Claude Fable 5.2, session "architect: kernel version 2, round 5" and its continuation (the first session committed tasks 1 and 2 and was paused for usage; the continuation revised the build plan and wrote this). **Read for it:** both reviews in full by the first session (`audit/reviews/2026-11-14-argon-cli-kernel-v2-r5.md`, `audit/reviews/2026-11-14-gpt-kernel-v2-r5.md`); by the continuation, their closing ledgers, `kernel-v2.md` whole, `architecture.md` section 6, the build plan and this ledger's last section, with `arithmetic.py.txt` rerun whole. **Not read:** any price, any code. Numbering continues. The findings, cause by cause, are in `kernel-v2.md` part C.

### In plain words

- **Round 5 kept the test.** Both reviewers judge the test ledger a re-derivation at the cause, and neither asks for the wealth to be built again. Their round-4 constructions no longer work.
- **What it found were faults in the specification,** most by both reviewers: a budget kept beside the cash it stood for, a rounded ledger called a bound, a liquidation written for one side, a guard read as clearing a record, a null's condition stated on too little, and edges of the certificate and of layer 2's join.
- **Every finding is conceded, and none needed a rule added to save another.** The budget and the rounded ledger are deleted. The guard's reading is withdrawn.
- **The human decided two of the three choices** and deferred the third (`audit/decisions.md`, 2026-11-14 20:29 UTC (15:29 EST)): "outgrew", V10 as a named assumption, disk later.
- **One gap was mine and found by nobody:** the design did not say where the guard's prices come from. It reads the engine's own trace (D38).

### Who has seen what

- **Argon and GPT:** `f2f7c45`, from the same bundle. Neither has seen round 5's answers (`111cf55` to this commit).
- **Opus:** has not reviewed kernel version 2 or study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A90 | The test ledger removes the three confusions at their cause and is kept: units and cash never negative, trades only at the account's fills at their prices, one price a coin that a print moves | Both, round 5 (closes D29) | architecture 6.1; kernel A12 |
| A91 | Ending the ledger at a payment its cash cannot meet keeps the size under V16; V16 is an assumption that a path which confirms cannot establish | Both; GPT's qualification taken (closes D32) | architecture 6.1; kernel A14 |
| A92 | A taker in a standing book does not gain from the bounce of prints between bid and ask. Rung 1's null is still false of real prints, and a maker paid to stand passes "earned" | Both examined it (closes O3) | architecture 6.1 |
| A93 | What the ledger borrows from the account (a cycle's end, a sale's fraction, a cut to cash) selects valid trades and imports no equity | Both (closes O5, apart from the budgets, which are D34) | kernel A12 |
| A94 | The cubic envelope, the dual bound and the direction of every rounding are sound where every return is at least minus one | Both (GPT's notes, Argon's 4) | kernel K2 |
| A95 | A budget set aside beside the cash lets funding make a scale negative | Both (GPT's 1; Argon's 1.2), conceded | kernel A12, K1 |
| A96 | A ledger whose stored balances are rounded down is another ledger, not a lower bound | Both (GPT's 2; Argon's 1.1), conceded | kernel A2, A12, K1 |
| A97 | A liquidated short was bought back under the tape; a settlement must move the price; T1 must bound fees | Both; Argon; GPT (3; 2), conceded | kernel A3, A8, A10, A12, T1 |
| A98 | An hourly and daily guard passes markets where a mechanical rebalancer outgrows the bar, and no finite list of clocks repairs that | Both (GPT's 4; Argon's 3), conceded (closes O4) | architecture 6.1, 6.5 |
| A99 | One law for each return alone does not give rung 2's null: which coin moves next can be known | GPT alone (5), conceded | architecture 6.1 |
| A100 | A holding's funding is not second order and no mix bounds it | GPT alone, conceded | architecture 6.1; kernel K2 |
| A101 | A span ending inside a day lost events; the veto must read every span; `n` at `D = 0`; the search's bound when several `Q < 0` | Argon alone (4), conceded | kernel A12, K1, K2 |
| A102 | The join must not decide staleness a second time; a print's size covers the sum of its fills; a matching print shows no placement history | Argon (5) and GPT (a note), conceded | kernel A3; architecture 6.4 |
| A103 | The human's three choices as recommended: both reviewers agree with each | Both, round 5; the human decided two (A104) | architecture 6.8 |
| A104 | Rung 2 claims "outgrew" with its limit beside every use; V10 is a named assumption of both claims; disk is deferred | The human, 2026-11-14 | architecture 6.1, 6.8; kernel A7, A14 |

### Settled by a derivation the reviewers have not seen

Each answers a finding both sides agree on. What is unseen is the fix.

| | Dispute | Settled by | Changes what is built |
|---|---|---|---|
| D34 | The stake rule (replaces D31) | A cycle's scale is `φ` of the ledger's cash at its first buy, over `d`. Nothing is set aside or returned. Argon proposed a clamp; the promise is deleted instead, since a number kept beside the cash it stands for is a state taken for a flow. Cycles deep together share the cash, which is power | **Yes** |
| D35 | The ledger's arithmetic (replaces the rounding at 128 bits) | Trades in whole test lots of `10⁻³⁰`, a size being a scale the test may choose. Cash is then a whole multiple of half of `10⁻⁵⁰`, exact, and bounded. K1 promises cash and units after every event and wealth at a day's end | **Yes** |
| D36 | What rung 2's bar holds (extends D12-v5) | Beside the mixes' bound, each coin held alone with its funding paid in cash, from two exact numbers a coin and span. A holding never traded is a mean of those and of cash. Rows at a span's end; K2 stated on records with no return below minus one | **Yes** |
| D37 | What the guard is for (replaces D30's wall) | Rung 2's own test run on rules without skill, at four registered clocks. It can refuse a registration, at a rate that reaches 20 times in two years, and is quoted beside the claim. It cannot clear a record, and a test asserts its silence on a market where a rebalancer wins | **Yes**, the replay's wall |
| D38 | Where the guard's numbers come from | The engine's trace holds each coin's price and unit funding at every tick. Lean carries each rule in the test ledger's books, from the trace of a run with no slots at a tick of a minute. Found by the architect while writing the build plan | **Yes** |
| D39 | Rung 2's null, as a sufficient condition | Each price event as a whole (its coin, its return, its time) has one law whatever came before. Where it fails the claim's limit applies, and the claim says so | No: wording and criteria |
| D40 | T1 | Every fill of the three kinds, a short's buying back and a settlement included, and no fee negative | **Yes** |
| D14-v6 | Layer 2's join | Reads the engine's mark on each print | **Yes** |

### Disputed, still open

| | Dispute | State | Would change what is built |
|---|---|---|---|
| O3 | Rung 1's null where prints bounce | **Closed** (A92) | |
| O4 | The guard as a condition on the record | **Closed: it failed** (A98); replaced by D37 | |
| O5 | What the test borrows, and its own state | **Closed** (A93), the budgets by deletion (D34) | |

**No dispute is open.** The architect refuted nothing in round 5, and the reviewers have not yet seen D34 to D40.

### What the confirming round should check

1. **D34.** A scale or balance below zero; a change in the ledger's books that is not a fill or a funding payment; whether first come first served touches anything but power.
2. **D35.** A price, rate or fraction that takes cash or units off the grid, or a number that grows with the run.
3. **D40.** A fill of any kind better than the coin's price after its event: a short at a settlement, a liquidation's tail beyond the levels.
4. **D36.** A holding with funding that still beats the bar; an event no span's last row holds; the veto across spans.
5. **D37 and D38.** A sentence that still reads the guard as clearing a record; the refusal's threshold; whether a rule in the ledger's books, traded at the trace's prices, is of the null's own kind.
6. **D39,** and the two claims with their limits.
7. **The build plan's steps 9 and 10.** A test that an empty or constant instrument passes.

### Assumptions only the human can choose

- **What rung 2 claims, and V10:** decided (A104).
- **Disk for two years:** deferred by the human. The recommendation stands: more disk with a second copy on another node, sized from a measured month of the volume, decided by 2027-03-01.
- **For the human's review, not a new choice:** the bar's term of D36, which can only raise the bar (`architecture.md` 6.8).

### Owed

- **By the advisor:** as the earlier sections list, and the measurement of the recorder's volume.
- **By the architect:** `KERNEL.md`'s encodings and grammar; the layout of the report's rows and of the trace; study 2's criteria, after the confirming round. The rounding at 128 bits is no longer owed: the ledger has none.

### Convergence

**Converged in the architect's judgment, and not yet confirmed.** No dispute is open, so none would change what is built or run. But eight settlements are fixes no reviewer has seen, and four of them (D34, D35, D36, D38) are new design and not a correction in place. Convergence is the design's and its reviewers' together, so one confirming round is owed before study 2's criteria are written.

**The test of whether this was patching.** Round 5's findings did not land on the three confusions again, with one exception that the last section named: the unspent budgets were a state taken for a flow, and they are deleted, not clamped. The other fixes each removed something or stated a domain: the rounded ledger, the guard's reading, K2 outside its record. Two things were added, the bar's term for a coin held alone and the guard's books, and each reuses what exists: two exact numbers in a coin's row that already existed, and the test ledger's own books. If the confirming round finds a move in the ledger's books that is not a fill, the ledger's rules are wrong and are fixed there. If it finds the guard still read as more than a refusal and a quoted figure, the guard goes, and rung 2 with it if the claim cannot stand without.

**The next round** goes to Argon and GPT from one bundle, with the seven checks above; a fresh Opus session if either is out.

**Study 1** is as the earlier section leaves it.

## After round 6 on kernel version 2 and study 2: what the specification admits

Appended 2026-11-15 02:49 UTC (2026-11-14 21:49 EST) by Claude Fable 5.2, session "architect: kernel version 2, round 6", the third of its brief (the first two answered the round and committed `95cf489`). **Read for it:** both reviews in full (`audit/reviews/2026-11-15-argon-cli-kernel-v2-r6.md`, `audit/reviews/2026-11-15-gpt-kernel-v2-r6.md`); commit `95cf489` word by word against them; `kernel-v2.md` A3, A8, A9, A12, B1, the laws T1 to K2 and part D; `architecture.md` 6.1's bar and guard; the build plan's steps 2, 9 and 10; this ledger's last section; `arithmetic.py.txt` rerun whole, exit 0. **Not read:** any price, any code, the rest of the design. Numbering continues. The findings, cause by cause, are in `kernel-v2.md` part D.

### In plain words

- **Round 6 confirmed round 5's answers.** Both reviewers find every round-5 finding fixed at its cause, and both keep the test ledger and the narrowed claims. Neither found a move in the ledger's books that is not a fill.
- **What it found was the specification's domain.** Argon calls the design converged with two edits to step 10. GPT calls it not converged on four gaps, each a market the engine admits, or an input an instrument is handed, that a law does not hold on. GPT asks for no change of design.
- **All six are conceded, each by the change its reviewer named as the smallest that removes the cause.** A fee rate is from 0 to 1. An ended coin leaves the spans after it. The guard reads every funding event in the machine's order. Its fixtures are a market the engine admits. The decimation is deleted and the bootstrap goes to study 2's brief.
- **One answer was incomplete and I completed it.** The answer to GPT's second finding said an ended coin has no event after its end, and no rule made that so. Admission now refuses one (D42).
- **The design did not change.** No finding touched the ledger's rules, the bar or a claim, and none needed a second clock, a deferred count or a stake that moves without a fill.

### Who has seen what

- **Argon and GPT:** `8106078`, from one bundle each. Both have now seen and confirmed D34 to D40 and D14-v6. Neither has seen round 6's answers (`95cf489`, `2dff3ba`).
- **Opus:** has not reviewed kernel version 2 or study 2.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A105 | Every finding of round 5 is fixed at its cause: the stake rule, the ledger's grid, T1 on every fill, the bar's term and K2's domain, the guard as a refusal only, the null on the whole event, the join | Both, round 6 (confirms D34 to D40 and D14-v6) | kernel A12, T1, K1, K2; architecture 6.1, 6.4 |
| A106 | The test ledger and the narrowed claims are kept | Both, round 6 | architecture 6.1 |
| A107 | A fee rate bounded only below lets a sale cost cash: a dated tier of 2 takes the ledger's cash from 0 to −1 | GPT alone (F1), conceded | kernel A8, K1, T1 |
| A108 | A coin whose listing ended was still a coin of the next span, and settled at zero it was a first price of zero | GPT alone (F2), conceded | kernel A3, A12, K2, P1 |
| A109 | A tick's total of funding loses the order that decides whether a rule's cash runs out: two payments in a minute, and a payment and a rebalance at one tick | Both (GPT's F3; Argon's finding 1), conceded as one cause | kernel A12, B1 |
| A110 | The guard's fixtures were markets the engine refuses, with a bar typed in | GPT alone (F4), conceded | build plan, step 10 |
| A111 | Step 10 listed a decimation and a bootstrap that no test of it calls | Argon alone (finding 2), conceded | build plan, step 10 |
| A112 | Denominators do not grow and numerators can; the ratio to the null's mix is the supermartingale, not the ratio to the bar | GPT's two notes, conceded as wording | kernel A12; architecture 6.1 |

### Settled by a derivation the reviewers have not seen

Each answers a finding its reviewer and the architect agree on. What is unseen is the fix. None changes the design: each narrows what is admitted, changes what an instrument is handed, or replaces a fixture.

| | Dispute | Settled by | As the reviewer named it | Changes what is built |
|---|---|---|---|---|
| D41 | The range of a fee rate | 0 to 1, at `start` and in the replay of given fills. A sale then brings at least nothing, so K1 holds for every admitted schedule | **Yes** (GPT's own bound) | **Yes** |
| D42 | Which coins a span has | The universe coins still listed at its start. Every quote's and print's price is above zero, so no first price is zero and nothing tests for one. **And admission refuses any event of a coin after its listing's end,** a funding event at the end's own millisecond included: without it P1 was false of an admitted market | **Yes** for the first two (GPT's). **The refusal is the architect's,** found while writing this, named by nobody | **Yes** |
| D43 | What the guard reads of funding, and in what order | The trace holds every funding event of a universe coin, held or not, and no total. The guard folds them in the machine's order: at one timestamp a span's end, then funding, then the tick | **Yes** for the events (GPT's). **The order differs from Argon's sentence in one place:** Argon put funding before a span's end. The machine's order (A3) puts a listing first. The ended coin has no funding there (D42), and another coin's is paid on the next span's mix, as the engine's own account pays it | **Yes** |
| D44 | The guard's fixtures | A pair of a quarter up and a fifth down, at 100, 125 and 80 for ever, from admitted events through the engine, the trace and both instruments, with the bar from the same report. The five-minute rule stands 30.5 times over the bar at the first day's end; all four clocks are silent on the astride market while a rebalancer gains 1.0119 of the bar a minute | **Yes** (GPT's own pair) | **Yes**, the tests |
| D45 | Step 10's two untested builds | The decimation is deleted, since layer 2 reads the archive's cadence as a class. The bootstrap is built under study 2's brief with the replay it resamples; it chooses `φ` and `d` and forecasts power, and decides no result | **Yes** (Argon's first alternative) | **Yes**, where it is built |

### Disputed, still open

**None.** The architect refuted nothing in round 6. Two places are not what a reviewer wrote and no reviewer has answered them: the refusal in D42 and the order in D43. Neither is a dispute until someone disagrees, and each is a question in the read below.

### What the short read should check

Not a round: by this project's rule a review repeats only when a finding changed the design, and none did. One short read of `git diff 716d382...rearchitecture` by GPT, whose four findings these are, or by a fresh Opus session labeled as such if GPT is out:

1. Is there still an admitted input on which the ledger's cash or units go below zero without the ledger ending?
2. Does the guard's fold, as kernel B1 writes it, decide every order it depends on from the trace alone?
3. At one timestamp, is a span's end before funding right for the guard (D43)?
4. Is refusing every event of a coin after its listing's end right, a funding event at the end's own millisecond included (D42)?

### Assumptions only the human can choose

- **None new.** Disk for two years stays deferred, as the last section leaves it.

### Owed

- **By the advisor:** the check of `95cf489` and `2dff3ba` against the reviews, and the short read. A count, taken without reading a price, of archive rows of a universe coin at or after its listing's end: if there is one, the engine now refuses that market, and what the reader does with it is a question for the architect. The earlier sections' items stand.
- **By the architect:** `KERNEL.md`'s encodings and grammar; the layout of the report's rows and of the trace, which now has a row for each funding event; study 2's criteria and its brief, which now carries the bootstrap, its block and its test.

### Convergence

**Converged: no open dispute would change what is built or run.** Round 5's settlements, which were the new design, have been seen by both reviewers and confirmed. Round 6's six items are closed by the changes their reviewers named, and none is design. Argon said converged given its two edits, and both are made. GPT said not converged until F1 to F4 were closed, and they are, by its own changes; its word on that is the short read. Study 2's criteria may be drafted now. They are committed only after the read and after their own review.

**The test of whether this was patching.** None of round 6's findings landed on the three confusions, and the last section's two tripwires did not fire: no move in the ledger's books that is not a fill was found, and no sentence still reads the guard as clearing a record. But four of the six items, and the one I found, share a cause, and it is a pattern to name: **admission is a list of refusals, each law states its own domain, and the two can differ at an edge.** Fees were bounded on one side in round 5 and on the other in round 6. I found one more edge in a few minutes of reading, so I do not claim the list is complete. More review rounds are the wrong instrument for the rest. Every starred law is proved in Lean over every admitted market, so an edge that admission misses is a goal that does not close. That wall comes back to the architect as a question and is never patched around, and its answer narrows admission or states the law's domain. If such a wall instead needs a rule in the ledger, the bar or a claim, this convergence is void for that part and it is re-derived.

**The next step** is the short read, then study 2's criteria. No round 7 is asked for.

**Study 1** is as the earlier section leaves it.

## After the calibration's time limit, study 1

Appended 2026-11-15 09:19 UTC (04:19 EST) by Claude Fable 5.2, session "architect: study 1's calibration wall, kernel version 2's wording, study 2's criteria". No outside model has seen it, and none is owed: it changes no trial and no judged number.

| # | Point | Rests on | Could it change a judged result? |
|---|---|---|---|
| A113 | The calibration's projection is printed and stops nothing. The 24 hours were never derived, and no limit can be: a run that keeps every trial and no market loses nothing by running, and the window's cost is linear in time | The plan, "The projection is not a wall"; behaviour 7, L5.3 | No. The strength and the report are the same trials |

**Study 1: converged, as before.**

## After GPT's short read on kernel version 2

Appended 2026-11-15 09:20 UTC (04:20 EST) by Claude Fable 5.2, session "architect: study 1's calibration wall, kernel version 2's wording, study 2's criteria". The read is `audit/reviews/2026-11-15-gpt-kernel-v2-r6-confirm.md`: three of round 6's four questions answered, and its word "converged".

| # | Point | How it was agreed | Where |
|---|---|---|---|
| A114 | No admitted input takes the ledger's cash or units below zero without ending it | GPT's read, answer 1, with a boundary construction | kernel A8, K1 |
| A115 | The guard's fold is decided by the trace and the report's coin rows together, and not by the trace alone as question 2 asked. The trace holds every listing's end of a universe coin | GPT's read, answer 2; conceded as wording, with the one row | kernel A12, B1; build plan, step 9 |
| A116 | At one timestamp a span's end comes before funding (D43) | GPT's read, answer 3 | kernel B1 |
| A117 | A coin whose listing ended leaves the later spans (D42) | GPT's read, "F2: closed at cause". Question 4's own case, a funding event at the end's millisecond, was not answered by name | kernel A3, A12 |

**Kernel version 2: converged.** No dispute is open. Study 2's criteria and brief are drafted next (`criteria-notes.md`, `briefs/4-study-2.md`) and go to Argon and GPT before anything is committed to `audit/criteria.md`.

## Study 2's criteria and brief, drafted

Appended 2026-11-15 09:35 UTC (04:35 EST) by Claude Fable 5.2, the same session. **Written:** CS2.1 to CS2.3 as notes (`criteria-notes.md`) and `briefs/4-study-2.md`. **Read for it:** `architecture.md` section 6, `kernel-v2.md` A6, A7, A12 to A14 and B1, the facts' section 7, brief 3's step 10 and its recorders' table. **Not read:** any price. No reviewer has seen any of it.

### In plain words

- **Three conditions, one for each statement someone could bend:** what the forward test confirmed (CS2.1, architecture 6.1 as converged), whether the wall held (CS2.2), and whether the replica's entries were the vault's (CS2.3). Fidelity's layers 1 and 2 stay tests and walls.
- **Two things are new design,** and both came from walls met while deriving a number.
  - **The forecast is not judged by the bootstrap's interval.** From 212 days it covers the next two years' volatility 0.56 of the time where variance persists. The judge is half a row of the power table, which is what the wall is read by.
  - **The trigger is fitted before 2026-09-01 and checked on two months held back,** by the statistic that judges it forward.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D46 | What "the forecast held" means | The ledger's forward mean square of daily returns is from half the replay's to twice it: half a row of the table, `√2` in volatility. Not judged under 212 days | **Yes** (`held`) |
| D47 | What "the trigger is the vault's" means | Entries matched one to one within six minutes, more than half of each side's, under `optimistic`, on [2026-11-15, 2027-01-31) | **Yes** (`matched`) |
| D48 | How `φ` and `d` are chosen | Of 30 pairs, the greatest bootstrap share at the top registered rung. Blocks of 14 days, the same draws for every pair, the bar `confirm`'s own on chained rows | **Yes** |
| D49 | The guard's refusal, exactly | A rule's wealth over the bar at the replay's last day's end, to the 730th power, at least 20 to the replay's days | **Yes** (`refused`) |
| D50 | The delays | Each the first whole second at or above the forward record's slowest cadence of quotes | The registration |

### Open, and asked of the reviewers

The four doubts at the end of the notes: whether CS2.3's half is a derivation; whether entries should be matched on fills; whether CS2.2 should be in the basket's units; and the defence against a quote that never stood.

### Assumptions only the human can choose

- **None new.** Disk for two years stays deferred.

### Owed

- **By the advisor:** the review of the notes and the brief by Argon and GPT; then `criteria: study 2`, alone.
- **By the architect:** nothing. `KERNEL.md`'s encodings, grammar and rows are written (the next section).

### Convergence

**Study 2's criteria: not converged.** Nothing here has been reviewed. CS2.1 restates what six rounds agreed; CS2.2, CS2.3 and the brief are new.

## `KERNEL.md`: the program's grammar and the market's encoding

Appended 2026-11-15 09:48 UTC (04:48 EST) by Claude Fable 5.2, session "architect: study 1's calibration wall, kernel version 2's wording, study 2's criteria (continued)". **Written:** `kernel2/KERNEL.md`, A17 (the program), A18 (the market: header, chunk, events, the order of a millisecond, funding's lateness) and, at 09:52 UTC (04:52 EST), A19 (the report's rows, the trace, `finish`'s summary). **Read for it:** `kernel-v2.md` whole, brief 3, the facts, `reference/SEMANTICS.md`, `kernel/DSL.md`. **Read of the data:** the count of significant figures and decimals of best bids on five coin-days before 2026-11-01, for the grid; no price was printed. No reviewer has seen any of it.

### In plain words

- **Most of it is layout,** and changes no rule: which bytes hold an event, which JSON field holds a slot.
- **Sixteen points pin something part A left open.** Each is marked "Pinned here" in the file or is a row below. None reverses a sentence of part A, and none touches the ledger, the fills, the bar or a claim.
- **Part A changed in wording at four places** to agree: a field has its scale and a source only its encoding (A2); the "policy's cap" is the venue's (A6, A7, B1), since A1 already puts the cap in the venue; `known` is never sooner than a registered `lag` (A3); A5 points at A17 and A18.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D51 | How a program says which sort a number is | By its form: `exact` holds a decimal in a string, `const` a JSON number. An operator takes one sort, and only `exact` and `float` cross. No exact `if`, as A5 lists none: a choice between two prices is two slots | **Yes** |
| D52 | What "version 2 counts ticks" is in units | One more base unit, `tick`. `ticks_since` and `age` have it, a window's length is `ticks`, and `convert` is stage 6's unchanged: a program that wants hours multiplies by its own constant of `h/tick`. At a tick of an hour that constant is one, which is B4 | **Yes** |
| D53 | How long a window may be | The `ticks` of a program's windows sum to at most 2²⁰: under 0.2 GB of B5's 2 GB at 17 coins, 12 days at a second, 728 days at a minute. A choice, with that reason | **Yes** |
| D54 | How `check` types a program with no market | The program names the sources it reads, with their units; `start` holds the market to them | **Yes** |
| D55 | Who puts a decimal string at its scale | The engine. The reader gives the digits and the count after the point and knows no scale and no coin's rules, so a size's scale, which a listing event changes, is never the reader's to get wrong. A zero at a string's end is not a decimal more than the scale | **Yes** (brief 3, step 1) |
| D56 | What happens within one millisecond, in what order | The fed events in A3's order; the tick; the wishes that arrive; funding's check. An order is admitted against the world of its own arrival. A7's "first quote with `time > ℓ`" and L1b need the wishes after the events, and `λ = 0` needs them after the tick | **Yes** |
| D57 | The order in which the view takes what became known | By `known`, and within one `known` the order the world met or made it | **Yes** |
| D58 | What the engine holds a `known` to | Exactly `time + δ` for a quote, a trade and a bar; at least `time + lag` for the rest, `lag` registered for each source in the header. Above that floor it is the reader's reading of the source, inside the trust boundary like any content | **Yes** |
| D59 | Funding's lateness | An hour is due when `H + late` is inside the horizon; a coin held into a due hour with no event naming it aborts the run at `H + late`. An event outside `[H, H + late]`, or a second for its coin and hour, is refused by `feed`: a longer lateness is registered, never paid around | **Yes** |
| D60 | What the header's coins are | The universe, in the order every "coin order" means, each with its rules at the horizon's start. There is no coin outside it | **Yes** |
| D61 | Three inputs' edges | A slot with no live order has `resting` of zero and no `resting_price`. A slot whose price or target is undefined is inactive. `leverage` is a whole number, as the venue takes them | **Yes** |
| D62 | Two roundings' edges | A buy priced under the least grid price rounds to zero and is A6's to refuse like any order; no fourth condition of admission is added, so R1 stands. A bar's print at a tie rounds to the higher | **Yes** |
| D63 | Who writes the rows | The engine, as text: a line a row, tabs, an exact number as its rational in lowest terms, a float as its bits. OCaml moves bytes and formats nothing, and `confirm` and `guard` read the same text back, so no judged row is printed or parsed outside Lean | **Yes** |
| D64 | When a day ends, and the last span | A day's end is the midnight itself, and its rows show the world after every event before it. The last span ends at the horizon's end, so P1's "exactly one span's last row" has a row there | **Yes** |
| D65 | A cash-flow row's price and fee rate | Not fields. They are `−(cash + fee) / units` and the fee over the notional, and a funding row's unit payment is `−cash / before`: A12 lists the cash, and a second copy could disagree with it | **Yes** |
| D66 | A coin's stale share in the account's row | Of that day's milliseconds, with a mark for a position or an order open in any of them | **Yes** |

### Open

| | Point | Why it is open | When it must close |
|---|---|---|---|
| O6 | **Whole-number prices above five figures.** V1's grid is five significant figures. The venue's documents are said to allow any whole-number price whatever its figures (a lead from the architect's memory, in no certificate of ours). No recorded price before 2026-11-01 sampled has more than five figures, BTC's included, so nothing has tested it | Under A18 as written, a coin quoted at six whole digits is off the grid and admission rejects the market. That is loud, and it would stop a registered forward run on the day BTC passed 100,000 | **Before study 2's registration:** the tick rule certified from the venue's documents, and the grid's definition in A18 stated to match |
| O7 | A listing event that lowers a coin's greatest leverage under the program's | A10 gives initial margin by the header's leverage and says nothing of this | Before any levered run; study 2 takes none |

### Owed

- **By the advisor:** a short read of `KERNEL.md` by GPT and Argon, D51 to D66 named, in the bundle that carries study 2's criteria; O6's certificate.
- **By the architect:** nothing for the build's steps 0 to 10.

### Convergence

**Kernel version 2: converged as before on parts A and B.** A17 to A19 are unreviewed. They are not a round: a finding against one of D51 to D66 is answered in `KERNEL.md` alone unless it shows a rule of part A false.


## After round 1 on study 2's criteria, its brief and `KERNEL.md`

Appended 2026-11-15 19:23 UTC (14:23 EST) by Claude Fable 5.2, session "architect: study 2's criteria, round 1", the second of its brief (the first stopped at its usage limit with the answers uncommitted; they were checked against both reviews and finished here, `56e6b45`, `8ab434b`). **Read for it:** both reviews in full (`audit/reviews/2026-11-15-gpt-study2-criteria-r1.md`, `2026-11-15-argon-cli-study2-criteria-r1.md`); the Study 2 notes, brief 4, `KERNEL.md` A18 and A19, `architecture.md` section 6, `kernel-v2.md` A6, A13, B1 and the laws, brief 3's steps 1, 3, 5, 6, 9 and 10, `venue/hyperliquid/rules.json` and the facts' section on the venue's rules. **Not read:** any price. `arithmetic.py.txt` runs clean with the new tests.

### In plain words

- **Both reviewers said not ready, and both said the converged ledger and benchmark stand.** Every finding is conceded. One proposal of mine, the veto on taker fills without a print, both reviewers rejected, and it is withdrawn with a derivation.
- **Most findings had one cause:** a number, a window or a search that someone would settle after a price was read. The delays came from the forward record, the guard's mixes and the bar's multiplier from a search of any effort, the first buy and the bootstrap's seed from nowhere yet, CS2.3's window from a calendar date the freeze would pass, and CS2.2's span from whenever the record stopped. Each is now a constant in the notes or the brief, or a function Lean computes from the run's own rows.
- **The wealth, the bar, the rungs and the guard's role did not change.** Three things around them did: `confirm` computes its multiplier and takes none; the guard's family is two fixed mixes and not a search; the engine's build leaves the protected-windows file out.
- **One finding I could not close without changing the converged ledger,** so I stopped: a book with its ask pulled far up has a mid far over its bid, and the ledger's coins are valued at the mid (O8).
- **O6 cannot be closed from the documents on record,** and must close before brief 3's step 1, earlier than I had written.

### Who has seen what

- **Argon and GPT:** `bf2064d` and `211bceb`, from one bundle each. Neither has seen the answers.
- **Opus:** has not reviewed study 2's criteria.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A118 | Nothing in the round reopens the test ledger, the bar, the two rungs, the threshold of 20 or the guard as a refusal and a quoted control | Both, round 1 | architecture 6.1 |
| A119 | CS2.1's sentence was not its condition: "filled only on sells through its prices" is false of a taker's entry, and "multiplied 20 times" is true of a wealth that fell back before midnight | GPT alone (F1), conceded | CS2.1 |
| A120 | A mean square is not a variance, and a ledger that never moved made 0/0 "held" | Both (GPT's F2 and F3; Argon's 2), conceded | CS2.2; brief 4, step 1 |
| A121 | A span that ends when the record stops lets a stop choose CS2.2's verdict, and an early "outgrew" left it unjudged | Argon alone (2), conceded | CS2.2; brief 4, step 7 |
| A122 | Matched times of first fills show neither the same cycle nor the same rule; the gate of 100 entries rested on independence, and 0.0047 bounds nothing for two rules that buy falls | GPT (F4, the number audit) and Argon (CS2.3, B), conceded | CS2.3 |
| A123 | A search's effort decided the guard's refusal: a poor mix or a poor multiplier lowers a rule's wealth over the bar. A rule with no cash ends at its first charge. The refusal read one day | Both (GPT's F5; Argon's 1), conceded as one cause | CS2.1; kernel B1, K2 |
| A124 | Protected or unfrozen information reached a judged number four ways: the delays read off the forward record; CS2.3's window beginning before the freeze; "whole days" chosen by someone; a split enforced by file names | Both (GPT's F6 to F9; Argon's 3), conceded as one cause | CS2.3; brief 4, steps 3 and 6 |
| A125 | A release changed the hash the registration pinned, so no registered run could read the released days | GPT alone (F10), conceded | kernel A13; brief 4, step 6 |
| A126 | A run of a whole month loses an earlier crossing to a later failure | GPT alone (F11), conceded | CS2.1, "the days run" |
| A127 | The veto on taker fills without a print is not adopted: a print says what traded then, not what stood later, and a paper order that lifts a true ask leaves no print | Both (GPT's F12; Argon's answer 4) | CS2.1 |
| A128 | The bootstrap's blocks keep neither every cycle nor the weekday; its seed, its funding scaling and the choice's tie-break were open | GPT (F13) and Argon (4), conceded | brief 4, step 5 |
| A129 | An unfixed first buy can put a full ladder's close over the venue's cap, and tests of steps 2 and 3 passed a replica that does nothing | Argon alone (4), conceded | brief 4, steps 2 and 3 |
| A130 | `KERNEL.md`: arrivals "in the order sent" against A6's order; a fee rate of 0/0 at a settlement at zero; the last span's two rows at one midnight; L1a at `δ = 0` | Both on the first two, Argon on the others, conceded | `KERNEL.md` A18, A19; L1a |
| A131 | The four questions: a half is the word "most" and no test; entries are matched on fills; CS2.2 stays in the ledger's own units, the basket's ratio beside it; no veto | Both | CS2.2, CS2.3 |

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D67 | What "the volatility held" means (replaces D46) | The variance of daily returns about their mean, divided by their count, over the first 212 judged days, from half the replay's to twice it, judged once. Not judged under 212 days run, on an ended ledger or on a replay of no variance. A stop can make "not judged" and never "held" | **Yes** (`held`) |
| D68 | What CS2.3 counts, and where (replaces D47) | The first 61 judged days, the length of the months held back. Entries are fills that find the position at zero, read from the engine's rows of the judged run and of the vault's fills through the ledger. No gate and no day left out. `optimistic` beside, judging nothing | **Yes** (`entries`, `matched`) |
| D69 | The guard's family and its refusal (replaces D49; narrows D37) | At each of four clocks, equal weights and the bar's own mix, each times 24/25. Refused on 20 times the bar at any day's end of the replay, or on the last day's rate. Nothing searches | **Yes** (`rules`, `refused`) |
| D70 | Who finds the bar's multiplier | Lean: `D` is convex and a quadratic between the points where a coin's term changes form, so its least is among zero, those points and the zeros of its slope between them. `confirm` takes no multiplier. K2 still holds at any | **Yes** (`confirm`; brief 3, step 10) |
| D71 | The venue and the account (replaces D50) | Delays of 1,000 ms from the recorder's written design; staleness 60,000 ms; first buy 100 USD, inside the minimum and the cap for a full ladder; cash 50,000 USD. All in the notes, from no record | **Yes** |
| D72 | What a failure late in a record does to an earlier day | Nothing: the replay is cut back to the last midnight at or before the failure, and by L1 a day's end is the same in every replay that reaches it | **Yes** (brief 4, step 7) |
| D73 | What a registration pins of the engine | The build, which hashes every source but the protected-windows file, and the windows that file held. `study2 forward` runs when the file differs by a release alone | **Yes** (kernel A13; brief 3, step 3) |
| D74 | What a quote that never stood can add | About the stake of the one buy it fills, since the buy's size was fixed by its limit: 1.94 times at the whole of the cash. Reported as a case the claim does not exclude | No |
| D75 | The bootstrap's draws (amends D48) | A block's start is a BLAKE2b digest of fixed text, modulo the replay's days: no seed exists to register. One span of the coins with a row every day; a day's funding scaled by the path's price, the same at its start and its end | **Yes** |
| D76 | How the fit is kept from the months held back | It reads an export cut by each record's time through the engine's admission, in a sandbox that cannot open the archive or the fills. It has its own wall on its own span before the months are read | **Yes** (brief 4, step 3) |
| D56-v2 | The order of one millisecond | Arrivals of one millisecond place their orders in A6's order, reduce-only first. An effect made after a tick in the tick's own millisecond is in the next view, which is seen only at `δ = 0`; L1a's premise says so. `start` rejects a venue's negative delays and bad limits | **Yes** |
| D64-v2 | The last span at the horizon's end | A span is read from one row a coin: a span that ended from its `span` rows before the day's, the open one from the day's. The day's rows, the account's, then the span's | **Yes** |
| D65-v2 | What the ledger reads of a fill's row | Its cost a unit, `−cash / units`, and a buy's notional before the fee. Nothing divides by a notional | **Yes** |

### Disputed, still open

| | Point | State | Would change what is built |
|---|---|---|---|
| O6 | Whole-number prices above five figures | **Open, and the advisor's.** The documents on record hold no price rule: `rules.json` cites the venue's tick and lot size page for size rounding alone. To certify, word for word from that page: the most significant figures of a price; the most decimals of a perp's price as a function of `szDecimals`; whether a whole-number price is allowed whatever its figures. If the third is there, a price is on the grid when it has at most `figures` significant figures or is a whole number, and the step in `[10ᵉ, 10ᵉ⁺¹)` is `10^max(min(e − figures + 1, 0), −decimals)`. If not, A18 stands and a six-figure price ends the forward run | **Yes**, and before brief 3's step 1, since the rule's form is code the build hashes |
| O8 | The ledger's coins are valued at a mid nobody may be able to sell at (Argon's construction A: 427 against a bar of 18.5, worth 1 at the bid) | **Reduced to a choice** below. As committed the claim says "valued at their prices" and lists the case | **Yes**, if chosen: K1's wealth, A12, the report's coin rows |
| O7 | A listing event that lowers a coin's greatest leverage | As before; study 2 takes no leverage | Not for study 2 |

### What the confirming read should check

1. **D67.** A pair of wealth lists that `held` judges wrongly; anything about the 212 days that someone still chooses.
2. **D68.** Whether reading entries off the judged run, under `pessimistic`, makes "not shown" the likely end for a faithful trigger, and whether the sentence licensed says no more than the count.
3. **D69.** A record on which the bar's own mix is undefined or its rule ends despite the cash kept; whether two fixed mixes can still refuse the pairs every five minutes (brief 4, step 4, test 3) and stay silent astride the minute.
4. **D70.** A set of sums on which the least of `D` is not in the list; a tie.
5. **D72.** Whether a replay cut back to an earlier midnight can differ at a day's end from the longer one: funding due near the horizon's end (`KERNEL.md`, funding's lateness), and `finish`'s rows.
6. **D73.** A change to the protected-windows file that is not a release and still runs; a change of computation that the build misses.
7. **D76.** A path by which the fit reads September or October.
8. **D56-v2, D64-v2, D65-v2,** against part A.
9. **O8,** blind: whether the claim as worded is honest without the change.

### Assumptions only the human can choose

- **O8, what "worth 20" means.** At prices, as six rounds converged, or at what the top of the book would pay.
  - **Recommended:** for the two comparisons only, value the coins at the lesser of the latest bid and the price. That wealth is never above `W`, so it reaches 20 no more often and the 5% holds; it costs half a spread; and a pass then needs a bid that stood, where today one wrong ask at one midnight is enough.
  - **Its cost:** it changes the test ledger the brief bound me to keep, so it is a design round of its own with a confirming read: K1's wealth, A12's "no mark but the price", and a bid in the report's coin rows.
  - **If refused,** nothing changes: the claim stands as worded.
- **Disk for two years:** deferred by the human, as before.

### Owed

- **By the advisor:** O6's certificate, before brief 3's step 1; the confirming read by GPT and Argon from one bundle, with the nine checks above (a fresh Opus session if either is out); the human's answer on O8; then `criteria: study 2`, alone, before any step of brief 4.
- **By the architect:** O8's round, if chosen.

### Convergence

**Study 2's criteria: not converged, and ready for a confirming read.** No finding is disputed. But thirteen settlements are fixes no reviewer has seen, and four of them (D67 to D70) replace a statistic, a window, a family and an interface, so they are new design in the criteria and not corrections in place.

**The test of whether this was patching.** The findings did not land on patches of round 6: they landed on the three conditions and the brief, which no reviewer had seen. And the fixes share one move, which removes things: a search, a proposer, a seed, a gate, an exclusion rule, a veto and a discretionary span are gone, and what replaced them is a constant or a function of the run's rows. Two things were added: the cash a guard's rule keeps, and the build's leaving one file out. If the confirming read finds a choice still made after a price is read, the cause was not removed and the notes are re-derived, not amended.

**Kernel version 2: converged as before on parts A and B,** with A13's build, L1a's premise and K2's multiplier reworded to agree. `KERNEL.md`'s D56, D64 and D65 are answered in place.

## Study 1's calibration: a share is by the host's measured rate

Appended 2026-11-15 19:36 UTC (14:36 EST) by Claude Fable 5.2, session "architect: study 1's calibration shares". No outside model has seen it. It changes no trial and no judged number, but its build touches `main`, which the strength rests on: L5.6's tests are another model's, as the plan already says.

### In plain words

- Run `cal-2` split each round by the hosts' cores and projected from one idle core. Both rested on one assumption, that a host's rate is its cores over an idle core's time. It is not: the cores are logical, and a loaded market takes 1.7 to 2.2 times the idle one, differently on each host.
- A round ends with its last host, so it is shortest when shares are in proportion to the rates under load. The probe now measures that rate directly, and the shares and the projection are both made from it.
- Every host stays: by rate, each one shortens every round.
- `cal-2` runs until the new build has passed its tests. Then it is stopped and run `cal-3` starts from its lines, all of them kept.

| # | Point | Rests on | Could it change a judged result? |
|---|---|---|---|
| A120 | A host's share is in proportion to its rate with all its workers busy. A round lasts the greatest `n_k / r_k`, least when every host ends together, at the set over the sum of the rates | The plan, "A share is by the host's measured rate"; `arithmetic.py.txt`, `calibration_cost` | No (A46) |
| A121 | The rate is measured by the probe run as a round runs: one market on every worker at once. On this PC that gave 279 markets an hour against the rounds' 279 and 284, and no host's rate moved by more than 4% between two rounds, so nothing re-measures | The same; measured 2026-11-15 19:28 UTC (14:28 EST) on `cal-2`'s kernel. Not yet measured on prodesk7 and gmktec, which were busy | No |
| A122 | The projection is the work over the sum of those rates, which is the job's time only under A120's split: 63 hours at most, where shares by cores take 119 and the idle probes said 34 | The same | No (A113) |
| A123 | What a round splits is what the merged log lacks of its set, so a retried or resumed round is balanced too | The plan, behaviour 8 | No (A46) |
| A124 | A host is in the job while its weight's error is below `f / (1 − f)`, `f` its part of the rate: 13% for gmktec. By cores gmktec's was 89% and the job was slower with it; by a measured rate all three belong | The plan; `calibration_cost` | No |
| A125 | A run on the same kernel may start from another's lines, under any build and split. The probe's trial is the log's first, so every host tests the new build against the old before the search, and a trial evaluated again must agree | Behaviour 7; A46; the plan, "Another run's lines" | Yes, if a build's trial differed: the probe and the repeated-trial wall are what would stop it |

### Disputed

Nothing. No reviewer has been asked.

### Owed

- **By the advisor:** the build, from the plan's table: tests first, L5.6's by a model other than the builder's; then `cal-3` from `cal-2`. `merge_shares`' defect starts as a failing test. After `cal-3`'s probes, compare prodesk7's and gmktec's rates with `cal-2`'s rounds (164 to 168, 59 to 61): A121 is measured on one host of three.
- **By the architect:** nothing.

**Study 1: converged, as before.**

## The wealth at the bid, and the certified grid

Appended 2026-11-15 20:00 UTC (15:00 EST) by Claude Fable 5.2, session "architect: study 2's wealth at the bid, and the grid", in two sessions of one brief (`ac1f9ea`, `152f13a`). It follows two decisions of 2026-11-15 (`audit/decisions.md`): the human's on O8, and the advisor's certificate for O6. No outside model has seen either change, nor the answers to round 1 in the section before the last. Numbers here start at A132: the calibration's section above reused A120 to A125, which stay as written.

### In plain words

- **The rungs compare the wealth at the bid, `Wᵇ`:** the ledger's cash plus its units of each coin at the lesser of its latest quote's best bid and its price. `W`, the books, the bar, the guard's rules and the proof are as six rounds left them.
- **`Wᵇ` is never above `W`,** so it reaches 20, or 20 times the bar, only where `W` does, and each rung's 5% stands with nothing added to its proof. Nothing in the books reads a bid, so there is no second clock and no stake that moves without a fill.
- **Construction A no longer passes:** 426.7 at prices against a bar of 18.64, and 0.9995 at the bid.
- **One reading went past the human's words.** The decision says "for the two comparisons only". The bootstrap and CS2.2's volatility read `Wᵇ` as well, since one forecasts the rungs and the other checks that forecast. No trade, scale, bar or guard's rule reads a bid.
- **The grid is the venue's certified rule,** whole numbers included, in one step. Brief 3's step 1 waits for nothing.

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A132 | "Worth 20" values the ledger's coins at the lesser of the latest bid and the price | The human, 2026-11-15, on O8 | `audit/decisions.md` |
| A133 | The venue's price rule: at most 5 significant figures, at most `6 − szDecimals` decimals for a perp, and a whole-number price whatever its figures | The advisor's certificate, 2026-11-15, on O6 | `venue/sources.toml`, "Price grid" |

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D77 | What the bid price is, and whether the machine gains a valuation | The lesser of the latest quote's best bid and the price, which is A10's adverse price of a long. A print under the bid has spent that bid. A quote is never one-sided (A3), so a quoted coin has a bid | **Yes** (`confirm`) |
| D78 | Whether `Wᵇ` can be above `W` | No: units are never negative (K1) and a bid price is at most the price. A coin with no quote is not held, since nothing fills before a coin's first quote. A stale bid, a bid a print has passed and a listing's end are each the lesser of two numbers one of which is the price | No (a line of K1) |
| D79 | Whether a comparison needs a second clock or a stake that moves without a fill | Neither. A scale reads the cash, a trade its row, the ledger's end a payment and the cash. `Wᵇ` is a valuation at a day's end and no state | No |
| D80 | What else reads a bid | The bootstrap and CS2.2's `held`, because they forecast and check what the rungs compare. The bar does not: it bounds mixes that trade at prices, and a lower bar is the unsafe side. The guard's rules do not: they ask whether the record rejected the null, which speaks of prices, and at the bid they could only refuse less | **Yes** (brief 4, steps 1 and 5) |
| D81 | What the report's coin rows carry | `bid` and `quoted`: the latest quote's best bid and that quote's time, moved by no print and no listing's end. The bid price is not a field, since a copy could disagree with `bid` and `price`. `quoted` judges nothing: a claim says when the record last showed the bid it was valued at | **Yes** (`KERNEL.md` A19; P1) |
| D82 | What the bid costs | `Wᵇ ≥ W × (1 − h)`, `h` the widest gap from price to bid among the coins held: 0.001 of log against 3.0 at ten basis points, and no cell of the power table moves by more than 0.0003 | No |
| D83 | What still passes without a buyer | A bid of one lot, which values every unit; a bid last shown before a gap; a bid that stepped over the replica's own resting sale with no print. The claim says how the coins are valued and gives each bid's time, and says nothing of size | No (the claim's words) |
| D84 | The grid as one step (closes O6) | A price is on the grid when it is above zero, a whole multiple of `10^−decimals`, and of at most `figures` significant figures or a whole number. In `[10ᵉ, 10ᵉ⁺¹)` those are the multiples of `10^max(min(e − figures + 1, 0), −decimals)`: the two sets of multiples are nested each time. Checked against a count of digits on 336,000 prices (`arithmetic.py.txt`, `price_grid`) | **Yes** (`Engine.Exact`; brief 3, step 1) |
| D85 | Where the venue enters the grid | In the market's writer: `figures` of 5 and `decimals` of `6 − szDecimals`, stopping at a `szDecimals` above 6, of which the page says nothing. The engine takes the two numbers and knows no venue; `rules.json` is untouched. `feed` rejects `figures` of zero, where the step is no grid | **Yes** (brief 3, step 3) |
| D86 | What witnesses the grid | Admission on every recorded price, and every price of the vault's fills (brief 3, step 2). Both see a grid too narrow. Nothing sees one too wide, which rests on the page; and the page was read on 2026-11-15, so its rule before then is V1's assumption | No |

### Disputed, still open

| | Point | State | Would change what is built |
|---|---|---|---|
| O6 | Whole-number prices above five figures | **Closed** by A133 and D84 | |
| O8 | The ledger's coins valued at a mid nobody may sell at | **Closed** by A132; D77 to D83 are its derivation, unseen | |
| O7 | A listing event that lowers a coin's greatest leverage | As before; study 2 takes no leverage | Not for study 2 |

### What the confirming read should check

Checks 1 to 8 of the section "After round 1" stand as written. Its check 9 is replaced by 9 to 13 here, and 14 is new.

9. **D78.** A market the engine admits on which a coin the ledger holds has a bid price above its price, or none: a coin held with no row in a day's rows, a span that ends at a midnight, a listing's end in a day's last millisecond.
10. **D79.** Anything in the books, the bar, the guard or `confirm`'s other outputs that reads a bid, or two markets equal but for their bids that leave the ledger different cash or units.
11. **D80.** Whether the bootstrap and CS2.2 must read `Wᵇ`, as I say, or whether that passes the human's "for the two comparisons only"; and any place where a forecast is still of `W` and its rung of `Wᵇ`.
12. **D81.** A12, K1, K2, P1 and `KERNEL.md` A19 against each other: one meaning of `bid` and `quoted`, at a span's end and after a settlement.
13. **D83,** blind: whether the claim, with its coins "valued at the lesser of its price and the last bid the record showed", is honest about the three cases left, and whether a fourth exists.
14. **D84 to D86.** A price at which the step and the sentence differ, or a rounding that lands off the grid; A18's words against the certificate's; whether stopping at a `szDecimals` above 6 is the right reading of the page's silence.

### Assumptions only the human can choose

- **Whether D80 is what "for the two comparisons only" meant.** I read "only" as: no trade, scale, bar or guard's rule reads a bid. If the human meant the bootstrap and CS2.2 to stay on `W`, `held` and the bootstrap read `W`: one sentence in CS2.2 and one in brief 4. In an ordinary book the two series differ by a few basis points and no verdict moves; the cost of leaving them on `W` is a forecast of one quantity checked against another.
- **Disk for two years:** deferred by the human, as before.

### Owed

- **By the advisor:** the confirming read by GPT and Argon from one bundle, with checks 1 to 14 (a fresh Opus session if either is out); then `criteria: study 2`, alone, before any step of brief 4. Brief 3's step 1 may start.
- **By the architect:** nothing, unless the read finds a design change.

### Convergence

**Study 2's criteria: not converged, and ready for a confirming read,** as before, now with twenty-three settlements unseen: the thirteen of round 1 and D77 to D86.

**Whether this was patching.** The bid is not a case added to the ledger. The fault was in what the rungs compared, and the change is there and nowhere else: one valuation, which the kernel already had as a long's adverse price, read by `confirm` at a day's end. No law of the books changed, and K1 gained one line. The grid's change is one `min` in one formula, from a certificate.

**Kernel version 2: converged as before on parts A and B,** with A12, K1, K2 and P1 reworded for the bid and V1 for the certificate. `KERNEL.md` A18's grid and A19's two fields are unreviewed.

## After the confirming read of study 2's criteria

Appended 2026-11-16 01:32 UTC (2026-11-15 20:32 EST) by Claude Fable 5.2, session "architect: study 2's criteria, confirming read" (`0a39b45`). It answers `audit/reviews/2026-11-15-gpt-study2-criteria-r2.md` (R1 to R6) and `2026-11-15-argon-cli-study2-criteria-r2.md` (F1 to F3, N1 to N3), and applies the human's decision of 2026-11-16 01:16 UTC (2026-11-15 20:16 EST) on R4 (`audit/decisions.md`). No outside model has seen these answers.

### In plain words

- **Argon said ready to commit, GPT not ready with six items, and neither asked for a redesign.** Both judged the wealth at the bid sound.
- **CS2.2 reads the wealth at prices** (the human). The bid is in the two rungs and in the bootstrap that forecasts them, and nowhere else.
- **The guard had a day's end of its own,** after its midnight's events. It now has the report's, before them. Both reviewers found this independently.
- **The bootstrap was under-defined in two places.** A day's sums are now slices of the report's running sums, and a path's wealth at the bid is its wealth times that day's own share at the bid, so it is never above the wealth.
- **The freeze reads nothing dated from 2026-11-01 on,** beyond whether the recorders run and where their gaps are. The sentence that let the vault's public record influence it is gone.
- **The collector re-reads 30 days,** a choice, and CS2.3 is worded as of the fills on record.
- **No change needed a second clock, a deferred count or a stake that moves without a fill.**

### Agreed

| | Point | How it was agreed | Where |
|---|---|---|---|
| A134 | CS2.2 judges the ledger's wealth at prices; the bid valuation is in the two rungs' comparisons only | The human, on GPT's R4 | `audit/decisions.md`; CS2.2 |
| A135 | `Wᵇ` is never above `W` on any admitted market; nothing in the books, the bar or the guard reads a bid; `bid` and `quoted` have one meaning in A12, K1, K2, P1 and A19 | Both reviewers, checks 9, 10 and 12 | architecture 6.1; `KERNEL.md` A19 |
| A136 | Round 1's findings are closed at their causes: D67 to D76, D56-v2, D64-v2, D65-v2; and the grid, D84 to D86 | Both reviewers, section 1 and checks 1 to 8 and 14 | the section "After round 1" |
| A137 | The guard's wealth at a day's end must stand before that midnight's events, as the report's rows do | Both, independently (R1; F2) | kernel B1 |
| A138 | The engine's build must name what compiles the sources, and the protected-windows file must be data | Both (F3; GPT's check 6) | kernel A13 |
| A139 | A report of the months held back must not reach the trigger's fit as a tracked file | Both (N3; GPT's check 7) | brief 4, step 3 |
| A140 | The bootstrap forecasts the rungs at the bid | Both, and the human's decision | brief 4, step 5 |

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D80-v2 | What else reads a bid | The bootstrap alone. D80's half on CS2.2 is withdrawn by A134. GPT's R4 construction is run: at the bid, two records with one price and one buy "did not hold" | **Yes** (`held` reads `W`) |
| D87 | Where the guard's day ends (R1, F2) | At the report's day's end: its books as every event and tick before the midnight left them, at that day's `day` rows' prices. Order at one timestamp: a day's end, a span's end, funding, the tick. The fault reproduced on the old oracle, 22.2 against the cut-back run's 23.0. The horizon's last day needs no tick | **Yes** (`guard`; brief 3, step 10; brief 4, step 4) |
| D88 | What a day's sums are (R2) | A row adds its figure less the coin's previous row's in the same span; a day's slice is what the rows after the day before's `day` row, up to its own, added. Exact, since each term was rounded before it was summed. A span's row at a midnight belongs to the next day, and one after the last day adds nothing | **Yes** (the bootstrap) |
| D89 | A path's wealth at the bid (R3) | Its `W`, the product of its days' `W` factors, times that day's own `Wᵇ / W`. Never above the path's `W`. Multiplying `Wᵇ`'s factors reached 20 on 0.197 of paths of a book that never moved | **Yes** (the bootstrap) |
| D90 | The least return on a path | Not chained. `least` is a running minimum and has no slice. A replay with a return below minus one has no bar (K2) and makes no path: a wall for the architect | **Yes** (one wall for one chained field) |
| D91 | Which end of a ledger `held` reads (F1) | Only one within the days it reads: the forward run's first 212, the replay's all | **Yes** (one line of `held`) |
| D92 | What the freeze reads (R5) | Its walls, all dated before 2026-11-01, and of later recordings only whether each recorder runs and where its gaps are. No count of the vault's later fills and no page of its public record. `inspect` prints the Holdout rule's list, and that rule says where the lines go | No code. A check for the registration's reviewers |
| D93 | The collector's re-read (R6) | 30 days, a choice: 822 fills at the vault's rate, one page, a twelfth of the retention. The overlap is an hour. CS2.3 is of the fills on record | **Yes** (the collector) |
| D94 | What the build hashes (F3) | The sources, the windows file left out, and the store paths of the compilers and libraries. Not `flake.lock`: it moves for unrelated inputs, and a two-year test would refuse its own engine | **Yes** (brief 3, step 3) |
| D95 | A fourth bid nobody could sell to (N1) | One a sale has taken, with a later print at or above it before the next quote. Listed in CS2.1; the claim's words already hold | No |

### Disputed, still open

| | Point | State | Would change what is built |
|---|---|---|---|
| O9 | GPT's R5 asks for an integrity role: protected diagnostics sealed from anyone on unfrozen work until release, and a sandbox test of it | **Refuted in part, unseen by GPT.** `CLAUDE.md`'s Holdout rule lets exactly those people inspect recordings for integrity (status, sizes, hashes, gaps). Every judged day of study 2 is after the registration, so nothing known at the freeze moves a rung's 5%, CS2.2's window or CS2.3's. What the rule forbids, the vault's later fills and public record as an input to the freeze, is now written (D92) | No. It is the human's Holdout rule, not the design |

### What a further read should check

1. **D87.** A market on which the guard's figure at a day's end still differs between a run cut back to that midnight and a longer one; the last day of a horizon.
2. **D88.** A layout of rows whose slices do not sum to the spans' own figures: a span ending at a midnight, two spans ending in one day, a coin first quoted inside the first day.
3. **D89.** A record on which a path's `Wᵇ` is above its `W`, or on which the day's share at the bid forecasts the rungs worse than `W` alone would.
4. **D90.** Whether stopping for the architect is right for a replay with a return below minus one.
5. **CS2.2.** Whether its sentence now says what it measures, and whether anything in `held` or its tests still reads a bid.
6. **O9 and D92.** Whether anything dated from 2026-11-01 on still reaches the decision to freeze.

### Assumptions only the human can choose

- **O9:** whether the Holdout rule's integrity inspection should be closed to whoever decides the freeze. I recommend leaving the rule as it is.
- **Disk for two years:** deferred by the human, as before.

### Owed

- **By the advisor:** GPT's confirmation of R1 to R3, R5 and R6 on the diff `04b7d9d..0a39b45`, which is a read of the fixes and not a new round; then `criteria: study 2`, alone, before any step of brief 4.
- **By the architect:** nothing, unless that read finds a design change.

### Convergence

**Study 2's criteria: converged with Argon, and one confirmation short with GPT.** No open dispute would change what is built or run: O9 is a question about the human's process rule. Ten settlements are unseen, D80-v2 and D87 to D95. R4 and R6 took GPT's own smallest fix, and R1 to R3 took its fix in substance.

**Whether this was patching.** No finding landed on an earlier patch. R1 was a second definition of a day's end, and it is deleted in favour of the report's. R2 and R3 were a step of the bootstrap that had been written in a sentence and never defined. R5's sentence was a leftover from before the Holdout rule was applied to this study. The converged design, the ledger, the bar, the guard's family and the two rungs, is as it was.

**Kernel version 2: converged as before on parts A and B,** with B1's guard, A13 and V18 reworded and a part E for this read.

## Layer 1's wall: the venue's printed arithmetic

Appended 2026-11-16 03:33 UTC (2026-11-15 22:33 EST) by Claude Fable 5.2, session "architect: layer 1's closedPnl" (`c4280f1`). It answers the wall of brief 3, step 2, test 4, met at the build (`kernel2-build` `8aee427`; `audit/decisions.md`, 2026-11-16 03:10 UTC (2026-11-15 22:10 EST)). No reviewer has seen it. The vault's fills before 2026-11-01 were read whole, and nothing dated from 2026-11-01 on.

### In plain words

- **The test was wrong and the ledger is not.** The test asked that the venue's printed fee and `closedPnl` be one rounding of our exact value. The venue rounds nothing exact: it keeps whole numbers (lots, price units, millionths of a USDC) and, where it scales one, multiplies it by a double and drops the fraction.
- **The fee** is that cut of the notional by the rate. It is the exact fee's floor, except that 44 of the 58 fees that are exactly a whole millionth print one millionth less.
- **`closedPnl`** uses an entry price that is the venue's entry notional divided by the lots with the remainder dropped, and at each partial close the entry notional is cut by the fraction of lots left. That reproduces all 2,508 closes; the exact average misses 547.
- **Both rules leave nothing over on the whole record,** and each is tied to the ledger: the printed fee is within a millionth under the ledger's fee on every fill, and the venue's entry notional is the ledger's cost on all 2,019 closes before a partial close and never above it after.
- **The ledger keeps charging the exact fee.** It pays at most a millionth of a USDC a fill more than the venue and never less. `closedPnl` is a printed figure nothing judged reads; a long's is 0.35 USDC above its exact profit over the record.
- **The rule to be found on the first hundred fills is withdrawn.** Those fills hold neither kind of deviation. The arithmetic was found on the whole record, so these fills no longer test it; the forward window's do, at their replay.
- **No change needed a second clock, a deferred count or a stake that moves without a fill.** No state, law or event of the kernel changed.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D96 | What the venue's printed fee is | The double product of the notional in millionths and the double nearest the rate, its fraction dropped. 0 of 5,806 differ; the exact floor misses 44, a product from decimal doubles 31 (facts §7; `arithmetic.py.txt`, `venue_prints`) | **Yes** (layer 1's test) |
| D97 | What `closedPnl` is | `s · (P − E div p)`, with `E` the entry notional in millionths, added to by buys and cut by the double nearest the ratio of lots left at a partial close. 0 of 2,508 differ; sixteen other ways to reduce `E` leave 14 to 107 (facts §7) | **Yes** (layer 1's test) |
| D98 | Whether the ledger cuts its fee as the venue does | No: A8 stands, and A1's "no operation of the ledger rounds". The difference is V19's, one-sided and bounded by derivation at the base tier for notionals under 137,000 USDC. A cut in the ledger would put a double's rounding into the cash and the conservation law for a millionth a fill, and leave funding, whose cut is not on record, exact beside it | No |
| D99 | Whether `closedPnl` moves cash | Assumed not (V20): the account moves by trades, fees and funding. The fills carry no balance, so nothing here shows it; the bound if wrong is stated, and nothing judged reads the figure | No |
| D100 | How the test fixes its rule | Not on a sample. Rates are the base tier's and the arithmetic is facts §7's, with made-up cases that an exact floor fails. The record's own deviations begin past the first hundred fills, so the sample could not have found them | **Yes** (the discovery of modes and rates is deleted from the test) |
| D101 | What ties the venue's figures to the ledger | The fee: `0 ≤ ledger − printed ≤ 1` millionth. The entry notional: equal to the ledger's cost until a partial close, then `cost − m ≤ E ≤ cost` after `m` of them. Both hold on every fill | **Yes** (two assertions of the test) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O10 | Whether a simulated account should pay the venue's cut fee, which `Engine.Exact`'s nearest double could express exactly | **The architect says no** (D98). A reviewer who holds otherwise must show a judged figure that a millionth a fill, always against the replica, can move | Only then |
| O11 | V20 rests on a sentence of the venue's documents that nobody here has certified | **Owed by the advisor:** the page, quoted in `venue/sources.toml` as the price grid's was. Until then V20 is an assumption with a bound | No |
| O12 | The stored `userFunding` rows are one a coin a day: 1,121 rows, all at a UTC midnight, each a sum of up to 24 payments with a mean size and rate. Step 5's check, "each payment is A9's from its own size and rate", has no single payment to read | **Open, for the architect before step 5.** Whether the API gives hourly rows for a shorter range is a lead for the advisor | Yes (step 5's funding test, and V8's witness) |

### What a read should check

1. **D96 and D97.** A fill of the record, or a made-up one, where the stated arithmetic and the printed figure differ; an order of operations that also leaves nothing over and differs on some input the record lacks.
2. **D98.** A judged figure of study 2 that a fee a millionth higher a fill can move; whether funding should be read the same way once its hourly payments are on record.
3. **D99.** Whether anything in the kernel, the briefs or study 2's criteria reads the venue's `closedPnl` or entry price as profit or as state.
4. **D101.** Whether the two inequalities can hold for a ledger whose cost or fee is wrong; a short, which the record does not hold.
5. **The withdrawn sample rule.** Whether a rule found on the whole record and then tested on it claims more than "it leaves nothing over and has no fitted number".

### Assumptions only the human can choose

None new.

### Owed

- **By the advisor:** the test writer rewrites `kernel2/ocaml/test/layer1.ml` from brief 3, step 2, test 4 as it now stands (its header quotes the old test), without reading the code; the builder changes nothing in `Engine.Ledger`; O11's certificate; O12's lead.
- **By the architect:** O12, before step 5.

### Convergence

**Not a review round: a wall answered.** Nothing of the converged design changed: no state, event, law or criterion. Brief 3's step 2 has a different test 4, two rows joined A14 (V19, V20), and V4's witness is reworded. The settlements D96 to D101 are unseen by any reviewer. The architect's reading is that none can change a judged figure, so the step's test can be rewritten now and the settlements go to the reviewers with the step's build; whether that is so under `CLAUDE.md`'s Decisions rule is the advisor's to decide and log.

## The vault's funding: O12

Appended 2026-11-16 04:41 UTC (2026-11-15 23:41 EST) by Claude Fable 5.2, session "architect: the vault's funding, O12" (`7268700`). It answers O12 of "Layer 1's wall", after the advisor's check of the API (`audit/decisions.md`, 2026-11-16 03:36 UTC (2026-11-15 22:36 EST)). No reviewer has seen it. Read: the vault's fills and `userFunding` rows before 2026-11-01, and `fundingHistory` for four coins to 2026-05-31; nothing dated from 2026-11-01 on.

### In plain words

- **A row is a day, and a day can be tested exactly.** Its `nSamples` is the hours held, its `szi` their mean size, its `fundingRate` the hourly rates weighted by size. The fills give the first two on all 1,121 rows, and the hourly rates the third on the 104 rows whose rates were read.
- **The claim is narrowed to the day.** The test compares those three figures and that every held day has a row. It compares no cash.
- **The cash is measured.** `usdc` is at oracle prices no source gives for the past. The replay reports it against our run's payments, by coin and day, as V8's size.
- **Every run pays at the coin's price, the forward run included.** `fundingHistory` has no oracle price, and the judged run does not take one from the recorder's asset contexts.
- **Nothing needed a second clock, a deferred count or a stake that moves without a fill.** No state, law or event of the kernel changed.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D102 | What a `userFunding` row of the vault is | One coin and UTC day from the row's midnight: the count of hours held, the mean size held, the size-weighted mean of `fundingHistory`'s rates, the payments summed. 0 of 1,121 differ in count or size, 0 of 104 in rate; 1,121 held days and 1,121 rows (facts §7; `arithmetic.py.txt`, `venue_funding`) | **Yes** (step 7's test 3) |
| D103 | What layer 1's funding tests | The day: those three figures within the print's last decimal, and a row for each held day and no other. Not one payment, which the venue does not give. It is the witness of a new row, V21: the rate, the hour, the size held into the settlement, and funding before a fill of its millisecond (one real case, DOGE, 2026-06-25) | **Yes** |
| D104 | What witnesses the cash, V8 | Nothing tests it. `usdc` over the day's size times rate is a mean of oracle prices; the replay before the freeze and each forward replay report `usdc` against the fills' sizes times what a unit paid in the run. A measurement with no pass mark | **Yes** (brief 4, steps 4 and 7) |
| D105 | What a funding event of a judged run carries | `fundingHistory`'s hour, stamp and rate, and no oracle price, before the freeze and after. The asset contexts' oracle price is not read: it would make the forward run pay by another rule than the replay that chose `φ` and `d`, and need a rule for an hour with no context. The basis is of the order of 0.05% of a funding that was 53 USDC in seven months | No (the kernel's rule for history, now said of every run; the recorder table's "and oracle price" was wrong) |
| D106 | What the collector holds of the vault's funding | A daily pull of the 30 days before the last midnight, with the fills' re-read; the forward report reads the row with `nSamples` from the latest pull. No hourly pull | **Yes** (the collector, owed by the advisor) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O13 | Whether a recent day's funding comes hour by hour before the venue sums it | **Not known,** and no forward row was read to learn it. Rows without `nSamples` are counted and not interpreted, and the 30 days of re-reading pull each day again once summed (a row was summed 15 days after its day) | Only if rows are still not summed after 30 days |
| O14 | D102's rate on the 13 coins and five months not read, and a settlement stamped late with a fill before the stamp | **For the build's test,** which reads every rate. A difference is a finding about V21 or A9's "held into", to the architect | Only then |

### What a read should check

1. **D102, D103.** A set of fills and rates that gives a row's three figures while the ledger pays on a wrong size at some hour; whether a size-weighted rate and a mean size together leave two hours' sizes free to trade places.
2. **D104.** Whether any judged figure of study 2 can move by the basis; whether a day's sum can hide a basis that a single payment would show and that matters.
3. **D105.** A judged figure that differs between the coin's price and the oracle price by more than its own reporting precision.
4. **D106.** A forward day whose row is never on record in its summed form.

### Assumptions only the human can choose

None new.

### Owed

- **By the advisor:** `fundingHistory` for the 17 coins over [2026-04-03, 2026-11-01), stored raw with its hash; the collector's daily funding pull in place of the hourly one; step 7's test 3 written from the brief as it now stands.
- **By the architect:** nothing open.

### Convergence

**Not a review round: a wall answered.** O12 is closed. One assumption was made explicit (V21) and one widened to every run (V8); no state, event, law or criterion changed. D102 to D106 are unseen by any reviewer. The architect's reading is that none can change a judged figure, since no judged run reads `userFunding` and D105 keeps the rule the kernel already had; whether that is so under `CLAUDE.md`'s Decisions rule is the advisor's to decide and log.

## GPT's read of layer 1 and O12, the trades source, and B5's wall

Appended 2026-11-16 08:29 UTC (03:29 EST) by Claude Fable 5.2, session "architect: GPT's read of layer 1 and O12" (`1dd7a0c`, `107e715`, `5e0da26`). It answers `audit/reviews/2026-11-16-gpt-kernel-v2-layer1-funding.md` (not accepted, no redesign asked), decides what replaces `node_trades`, and answers the speed wall step 3 met at `kernel2-build` `4616aed`. Read: the review, the listing's sizes, and the built `Exact.lean` and `Machine.lean`. No market data, and nothing dated from 2026-11-01 on.

### In plain words

- **GPT is right on all five points, and no design changed.** I had said that the funding price and the exact fee could not move a judged figure. They can: a wealth just over 20, or a cash that just meets a payment, falls on the other side. Both stay as they were, now as choices of model that every claim says, and the reason given for each is one that holds.
- **Two checks were called stronger than they are.** The two ties of the venue's figures to the ledger pass for a wrong ledger, and a day's funding row does not give its hours. Both are narrowed to what they show, and the suite gains the cases that the narrower checks miss.
- **Trades come from fills.** The bucket's `node_trades` stops in 2025. The files that reach our dates hold every fill, and a trade is the two fills that share a trade id. They are read newest day first; the 12 USD approved reach 2026-06-08.
- **The engine is too slow because of how two functions compute, and the 20 minutes were never derived.** Both are answered: the wall is now what a run needs (no run over a day), and the two functions get twins proved equal to them.
- **Nothing needed a second clock, a deferred count or a stake that moves without a fill.** One case could ask for a second clock later and is named (O14).

### Agreed after this round (GPT's five findings, each conceded)

| | Point | Settled by | Changes what is built |
|---|---|---|---|
| D107 | Whether the funding price can move a judged figure (D105) | It can. D105's rule stays, the coin's price in every run, as a choice of model said with every claim (V8); the claim of invariance is withdrawn. The 5% is untouched: it is a theorem of the ledger and null as modelled. The oracle's alternative is stated and refused: two sources, and a missed context that cannot be fetched again | **Yes:** a dated revision of CS2.1's "said with every claim", drafted in `criteria-notes.md`, the advisor's to commit |
| D108 | Whether the exact fee can move a judged figure (D98, O10) | It can, and a fee a fill bounds no run. The exact fee stays because it is the one fee that scales with a trade, which the test ledger's copy at a scale needs (A8); "conservation" was no reason. Said with every claim (V19). O10 is closed | The same revision |
| D109 | What the two ties show (D101) | Compatibility of the venue's figures with the ledger, and no more. The suite holds two wrong ledgers, shows both ties accept them, and asserts the exact fee (15), cost (3,702) and realized profit (2,298) that reject them. The cost tie is asserted as arithmetic gives it, `c − 2m < E < c + m`; the record's narrower interval is a printed count, since a double's product can round up | **Yes** (step 2, test 4) |
| D110 | What a day's funding row shows (D103) | The day's sums. Each hour's size is held by U1 and by three made-up days asserted payment by payment: the collision (0.24 against 0.20 on one row), equal rates, a late stamp. The replay lists every settlement with a fill between its hour and its stamp | **Yes** (step 7, test 3) |
| D111 | The test of V8's measurement | Each input moved alone, a day not held, a zero rate; a day with no event is listed as not measured | **Yes** (brief 4, step 4, test 5) |

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D112 | What a trade print is on the archive's dates | A pair of rows of `node_fills_by_block`: one coin, `tid` and `time`, one price and size, opposite sides, one `crossed`. Its side is the crossed row's. A row in no pair is no print and is counted by class. It is the websocket's `trades` row by construction, not by a comparison | **Yes** (step 6: the reader and test 10) |
| D113 | What is assumed of a non-validating node's stream | That an hour's file is every fill of that hour, once (V22). Witnessed where the vault traded: each of its fills in the hours read has its print. Nothing shows a block lost whole elsewhere | **Yes** (V22; the witness in test 10) |
| D114 | Which days are read, and what a run does with the rest | Newest day first, whole days. The market before the freeze begins at the first day read; no horizon holds an hour without its file, so no rule exists for a day without prints. 11.93 USD reach 2026-06-08 | **Yes** (the advisor's download; brief 4's horizon) |
| D115 | What B5 is for | No run takes more than a day. A run is one thread, so hosts buy runs and not speed. The forward record at two years is 2.1 of the archive's window in numbers, so the window has 8 hours with fills and 4 for admission. The 20 minutes and the hour were choices | **Yes** (step 3, test 6; step 6, test 11) |
| D116 | How the engine meets it | Twins of `Exact.readBits` and `Exact.onGrid` on whole numbers, proved equal on every input (law X3 ★) and put in by the compiler's `@[csimp]`, so every law stays about the plain functions. The builder profiles first: the twins suffice only if the two are nine tenths of the time | **Yes** (step 3) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O13 | Whether a recent day's funding comes by the hour first | As before | Only if rows are not summed after 30 days |
| O14 | D102's rate on the rates not read, and **a settlement stamped late with a fill before the stamp** | A9 pays on the size at the stamp. If the venue pays on the size at the hour, the fix would be a second clock; nothing on record shows the case, and the replay's list is where it would | Only then, and as a redesign |
| O15 | The layout of a line of `node_fills_by_block`, and which rows form no pair | Not on the certified page. The builder reads the layout off one hour; a class of unpaired rows I did not expect goes to the architect | Only if a field is missing |
| O16 | Whether the twins reach the wall | My estimate is 15 to 19 times on admission against the 9 needed, from the code and no profile. The builder's profile decides | A second profile, if not |

### What a read should check

1. **D107, D108.** That the 5% really does not depend on the funding price or the fee function; that the drafted words say enough.
2. **D109.** A wrong ledger the exact assertions also pass. A chain of closes outside `c − 2m < E < c + m` with `E` under `2⁵¹`.
3. **D112.** A book trade that is not such a pair, and a pair that is no book trade (a liquidation taken by the backstop, a deleveraging), and what each does to a `pessimistic` fill.
4. **D114.** A run before the freeze whose horizon could hold an hour with no file.
5. **D115.** A run of study 2 that the day does not cover: the fit's count of trials, a forward record denser than five levels at 0.55 s.
6. **X3.** That an equality of the two constants leaves nothing for a twin to differ on, and that `@[csimp]` on it changes compiled code alone.

### Assumptions only the human can choose

| | Choice | The architect's recommendation |
|---|---|---|
| H14 | Whether to read the trades of 2026-04-03 to 06-07 as well: 4.40 USD more, 16.34 in all, of the 17.54 left under the approved 20 | **Yes.** CS2.2 is written for a replay of 212 days ("the replay's own length"), and the fit and the bootstrap were sized on them. At 12 USD the replay is 146 days, and CS2.2 then needs a dated revision before the freeze. It leaves 1.20 USD, so a failed transfer is counted before it is retried |

### Owed

- **By the advisor:** the dated revision of CS2.1's words (D107, D108); the download, newest day first (D114); step 2's test 4, step 7's test 3 and brief 4's step 4 test 5 rewritten by their test writers from the briefs as they stand; step 3's tests 6 and 7 and X3's statement before the twins; whether these settlements need a review round.
- **By the architect:** nothing open.

### Convergence

**GPT's round is answered and not yet re-read.** Every finding is conceded; none asked for a redesign and none got one, so by `CLAUDE.md`'s rule a repeat is owed only if the advisor judges that a finding changed the design. D112 to D116 are new and unseen. No open dispute would change what is built except O14's late stamp, which waits on a record that does not yet show it.

## GPT's read of the trades source: the vault witness and a match's identity (V22)

Appended 2026-11-16 09:06 UTC (04:06 EST) by Claude Fable 5.2, session "architect: GPT's read of the trades source (V22)". It answers `audit/reviews/2026-11-16-gpt-kernel-v2-trades-b5.md`: X3 and `@[csimp]` accepted as a design, V22 not accepted on two findings. Read: the review; the three whole days of `node_fills_by_block` on disk when the session began (2026-10-29 to 31, as kept by the advisor's pull, each block's line whole for the 17 coins), counts and times only, no price printed; the vault's stored fills for the same span. The counting script is `~/.cache/mm-v22/counts.py`, not in the repo.

### In plain words

- **GPT is right on both findings.** The witness was weaker than its sentence, and a trade id's uniqueness over a coin-day was the wrong identity. Both are fixed at the cause, and neither by a wider version of the old check.
- **The witness is now equality.** The stream holds the vault's own rows under its address. They are compared with the API's record of its fills, each way and in every field, time and size included. On three days: 205 and 205, nothing differing.
- **A print's time is its block's.** Every row carries its block's time, so the reader stops on a row that does not. A pair is two rows of one block.
- **A match is identified by its two orders,** not by its trade id: a match fills one of them whole, so the same two never meet again. That refuses a match written twice anywhere in the record. The coin-day check of trade ids is deleted: it missed a repeat on another day, and it would have refused honest records, since a trade id has only 50 bits.
- **Nothing is repaired.** Rows equal in every field were to be counted once; now a block written twice stops the reader.
- **What stays unseen is listed, and is not called conservative:** where the vault did not trade, a missing block, a wrong size on both rows, a wrong block time still in order, an invented pair.
- **Nothing needed a second clock, a deferred count or a stake that moves without a fill.** The block's time is the row's own time, read twice.

### What was counted (2026-10-29 to 31)

| Count | Value |
|---|---|
| Blocks kept, rows | 1,170,976 and 11,867,966 |
| Pairs by the derivation; rows in no pair; rows equal in every field within a block | 5,933,983; 0; 0 |
| Rows whose `time` is not their block's time cut to the millisecond | 0 |
| Blocks whose number does not rise, or whose time falls or equals the last in milliseconds | 0 |
| Pairs whose two orders had already paired; trade ids paired a second time, at any time | 0; 0 |
| Pairs whose rows differ in `hash`; pairs with one address on both sides | 0; 0 |
| Bits of the largest `tid` | 50 |
| The vault's fills on the API's record in the span; rows under its address in the stream; equal in every field; fields on one side only | 205; 205; 205; none |
| Links of one address and coin from a row's `startPosition` and size to its next row's `startPosition`; links that break | 11,692,803; 18,876 |

### Agreed after this round (GPT's two findings, each conceded)

| | Point | Settled by | Changes what is built |
|---|---|---|---|
| D117 | What the vault witness establishes (finding 1) | Equality, at the vault's rows and only there: the stream's rows under its address and the API's fills are the same rows each way, equal in every field, and each is a row of a print. "A size at least the fills'" came from layer 2's join for a source with no id and was never what this record offers | **Yes** (step 6, test 10's witness; layer 2's join and step 10's test 15 take the print's time and size as equal) |
| D118 | A print's time (finding 1) | Its block's. Block numbers ascend, block times never descend, a row's `time` is its block's: the reader stops otherwise. GPT's two rows moved together now need a block stamped wrong and still in order | **Yes** (step 6's reader; test 10) |
| D119 | What identifies a match over the record (finding 2) | Its coin and its two orders: a match fills one order whole, so two orders meet once. No two prints of a coin share both over the days read, exactly, on disk, before `start`. A trade id is an identity only with its coin and time, where C2 holds it | **Yes** (step 6's reader and test 10; step 3's reader loses its coin-day check, `kernel2/ocaml/archive/reader.ml`'s `seen` table in `trade_file`, with its test) |
| D120 | Rows equal in every field | Not counted once: the scope of "once" was never stated, which is finding 2 again. A block written twice stops the reader; a row twice in a block is rows in no pair | **Yes** (test 10) |
| D121 | What V22 leaves unseen, and its direction | Listed in architecture 6.4 and V22: a block missing whole, a wrong price or size on both rows, a block time wrong and in order, a pair the chain never made, each only where the vault did not trade. None is conservative over a run (GPT) | No (words) |
| D122 | A pair proves two parties and not a book (GPT's remark) | Prints are counted by their two rows' `dir`, beside the rows in no pair; both lists go to the architect before a run is trusted | **Yes** (a count; test 10) |
| D123 | X3 and `@[csimp]` | Accepted by GPT as a design. A profile share of nine tenths is necessary and not enough: at exactly that the twins must be 81 times faster. Step 4's measurement decides | No (words in step 3) |
| D124 | Where the record ends | Files are cut by the node's clock: the last block on disk for 2026-10-31 is stamped 23:59:59.659, and later blocks are in a file of the protected window, not read. The last third of a second may lack prints | No (named under V22) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O15 | The layout of a line | **Closed:** a block with `local_time`, `block_time`, `block_number` and `events`, each an address and a fill with the API's fields (brief 3's table). The classes of rows in no pair are still to be seen on the whole record; three days show none | No |
| O17 | Whether a raw file holds every block, with numbers that rise by one | Not known: the copy on disk keeps only blocks with a fill of the 17 coins (about 4.5 of the chain's 14 a second). If it does, a block missing whole shows as a step in the numbers and V22's first unseen failure goes. It costs three numbers a file in `done.tsv` (blocks in the raw file, first and last number, steps other than one), which only the running download can write for the hours not yet fetched | **Yes**, if they rise by one: the form gains it |
| O18 | What the venue says a `tid` is | I recall the websocket page: a 50-bit hash of the buyer's and seller's order ids, unique with the block's time and the coin. A lead until the advisor reads the page. The counts agree (50 bits, no repeat in 5.9 million). Nothing built depends on it: D119 is derived from matching | No |
| O19 | Each party's `startPosition` as a witness of sizes for every address | Tried and not adopted: 18,876 of 11,692,803 links break, shown on rows whose `dir` is `Open Short`, `Close Short` or `Close Long` and never `Open Long`, and I have not found why. A check I cannot explain is not a witness | Only if explained |
| O20 | A match repeated at another time in the recorder's `trades` (the forward run) | Not detected: those rows carry no order id, and a print's identity there is its coin, time and id (C2). The coin-day check that is deleted did not detect it across days either, and, if O18 holds, would have refused an honest two-year record more often than the archive's. `users` and `hash` could carry a check; none is designed, and no forward row was read | Only if one is designed |

### What a read should check

1. **D119.** Two orders that honestly meet twice (a modified order that keeps its id; a time-weighted order's slices), and what the check does then: it refuses, which is seen. A repeat that changes an order id is an invented pair, under D121.
2. **D117.** A stream wrong at a vault's row that the equality passes; whether the API and the bucket are one reading and not two.
3. **D118.** A wrong time that keeps the form.
4. **D120.** A real stream whose blocks repeat, which now stops and once passed with a count.

### Assumptions only the human can choose

None new.

### Owed

- **By the advisor:** O17's three numbers in the running download, soon, since each hour fetched without them would have to be fetched again; O18's page; step 3's reader without the coin-day check; test 10 and test 15 rewritten by their test writer from the brief as it stands; whether these settlements go back to GPT (both findings changed what is built, so by `CLAUDE.md`'s rule a repeat on another model is due).
- **By the architect:** the two lists of D122 and the classes of O15, when the whole record is derived.

### Convergence

**Both findings are conceded and re-derived, not yet re-read.** No open dispute would change what is built except O17, which can only add a check.

## B5's profile and step 4's wall on L1a

Appended 2026-11-16 13:55 UTC (08:55 EST) by Claude Fable 5.2, session "architect: B5's profile and L1a's wall". It answers the profile O16 asked for (`kernel2-build` `85b727d`; `~/.cache/mm-k2-tmp/profile/`) and the step 4 builder's stop before L1a (`kernel2-step4-wip` `536cc6c`). Read: the profile's flat and callgrind files, `Machine.lean`, `Exact.lean` and `Laws.lean` on that branch. No market data. No reviewer has seen this.

### In plain words

- **The twins were not enough, and the wall was derived wrongly.** With both readings free the day's admission is about 6 times faster where 9.7 was asked. And the 4 hours came from scaling the forward record to the archive by its count of numbers, as if both were doubles. The forward record's numbers are decimal strings: it never reads a double, and nothing had costed it.
- **The wall is each run's own day.** Admission of the forward record at 45,000 quotes a second, of the archive's window at 5,300; half that with prints and a ladder.
- **The machine threw away what it read.** Admission read every number, checked it and dropped it; the best prices were then read twice more, and each reading was made a fraction to be compared once. Now admission hands on what it read, as whole numbers, and nothing after it reads a number. That is one machine changed, not a second one beside it.
- **One twin stays,** of the reading of a double, which only the archive needs.
- **Step 4's wall needed no change to the machine.** The builder sought a lemma stronger than L1a, and it is false. L1a has a second premise, and it already gives both markets every listing a known quote was read under. The view keeps what admission read and has no rules of its own.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.** The builder's first option, a view that reads at release by the listings it knows, would have been a second clock for the rules, and is refused for that.

### What the profile showed (callgrind, inclusive, `feed` as 100%; BTC's first 3,000 quotes)

| Part | Share | A call |
|---|---|---|
| `Exact.readBits` | 75.9% | 5.3 µs |
| `Exact.onGrid` | 12.8% | 1.9 µs |
| The division that makes a reading a `Rat` (`readRat` less `readBits`) | 9.2% | 0.65 µs |
| The chunk's decoding | 1.2% | |
| Every comparison of two `Rat` | 1.0% | |
| `lean_nat_pow`, inside the rows above | 14.1% | |

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D125 | What B5's wall is (D115's figures withdrawn) | No run over a day, admission alone half of it, each kind of run by its own numbers. The forward record: 1.95 billion quotes of 20 decimal strings, 45,000 a second, 22,500 with prints and a ladder. The archive's window: 229 million quotes of 80 doubles, 5,300 and 2,650. D115 took the forward record's strings for doubles | **Yes** (step 3, test 6; step 6, test 11) |
| D126 | How the engine meets it (D116 replaced) | The machine keeps what it reads: `admit` returns the fault or the event's readings, integers at their fields' scales; its checks are of integers; `applyPayload` reads nothing, so `readRat`, `crossed`, `midOf`, `levelRats` and every default for a failed reading go. A `Rat` is made only where arithmetic leaves the scale. Twins of the admission functions were refused: they would keep the second and third readings, which no twin removes | **Yes** (step 3, item 2) |
| D127 | X3 | Two equalities. `readBits` equals its twin as constants, put in by `@[csimp]`. `onGridAt figures decimals scale n` equals `onGrid figures decimals (n / 10ˢᶜᵃˡᵉ)`, and admission calls it. C1's, C2's and X2's statements stand: C2 speaks of rational readings and `onGrid` and is proved through the second. Sign and order of two readings at one scale have no second form to equal | **Yes** (step 3, items 1, 2 and 4; test 8) |
| D128 | L1a where a listing is not yet known | The law as it stands. A quote or print known by `τ` has `time ≤ τ − δ`; every listing in force at it is no later, so the second premise gives it to both markets. The proof splits an admitted stream at `τ − δ`: the prefix is shared, and in a tail no event known by `τ` is a quote or a print, so what the view takes of it is the event's own. Dropping the events not yet known is not a lemma: the market without the listing can fail admission | **Yes** (step 4: the proof's five lemmas; test 6) |
| D129 | Whether the view reads | It does not. It holds what admission read by the world's rules at the event's time. A value does not depend on the scale it was read at (a corollary of X2, held as a property, not a law), so a listing the view has not seen can change whether a quote is admitted and never what the view holds of it | **Yes** (step 4, test 7; `KERNEL.md` A18) |
| D130 | The order of the build | X3's statement; the machine; L1a, on the machine that item leaves; the twin; the two rates. On the tip of `kernel2-step4-wip` | **Yes** (step 3's list) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O16 | Whether the twins reach the wall | **Closed:** they do not. About 6 times of the 9.7 asked, and my 15 to 19 was wrong | |
| O21 | Whether the rates are met | Estimates from the shares: the string day at about 12 µs a quote against the 22 allowed, the window's admission at about 4 hours against 12 with a twin at a tenth of `readBits`. Test 6 decides. A miss brings a new profile to the architect; I expect `Nat.pow` through the runtime's general routine, and the chunk's lists | A second answer, if missed |
| O22 | The recorder's reader inside 22,500 a second | Not measured: the reader is step 6's, and step 3's string rate is on `feed` alone | Step 6's reader, if it is most of 44 µs |
| O23 | The trigger's fit at the new wall | A trial on its 151 days may now take 17 hours where D115 gave 7. Trials run side by side, so a fit is still a day; a fit of many rounds is days | The fit's plan, if it has rounds |

### What a read should check

1. **D125.** A run of study 2 that is neither kind; a number of the forward record that is a double.
2. **D126.** A value after admission that differs from reading the number again. I hold there is none: one integer, one scale.
3. **D127.** The second equality at a `decimals` above the scale, below zero, and at `figures` of zero; that C2 as stated still binds the integer checks.
4. **D128.** Two markets that meet both premises and differ in a view at `τ`; a field of the tick's record that reads the world; an event of a tail, known by `τ`, whose view data reads the coin's rules. I found none: an end and a funding event read at the fixed scales 8 and 12, and an observation is its bits.
5. **D129.** Whether a program can learn of a listing before its `known` through a quote's size. It learns the size the venue published in a quote it may see.

### Assumptions only the human can choose

None new. D125 loosens no frozen threshold: B5's wall is in no criterion and no judged number reads a time.

### Owed

- **By the advisor:** X3's statement replaced by its writer, with the one parked on `b5-pending`; step 3's tests 6, 7 and 8 and step 4's tests 6 and 7 written from the brief by their test writers; the builder on `kernel2-step4-wip` in D130's order; Opus's read of `Machine.lean` against step 3's item 2; a read of D125 to D129 by an outside model, since D126 changes the machine every judged run will admit by.
- **By the architect:** the next profile, if a rate is missed.

### Convergence

**Answered by derivation and not yet read.** D115 and D116 are replaced, O16 is closed. No open dispute would change what is built; O21 and O22 wait on measurements.

### After GPT's read of D125 to D129 (2026-11-16 14:06 UTC, 09:06 EST; `audit/reviews/2026-11-16-gpt-kernel-v2-b5-l1a.md` on `main`)

The advisor's ledger. No counterexample to L1a under its premises; no finding changes what is built, so the round is converged.
- **Agreed:** D126 to D129 as semantics. D128's proof holds by admission's `known = time + δ` for quotes and prints. Reading once keeps the built machine's values, since no tick between admission and `applyPayload` changes `s.rules`. X3's two equalities suffice for C1, C2 and X2 unchanged.
- **D125, text:** "no run over a day" and "admission alone half of it" are choices, not derived. They change no criterion and no judged number, and they never license a shorter record or fewer trials.
- **D128, text:** its last sentence shows only that deleting a listing need not keep admission. It does not refute a law without the second premise.
- **Added to the test writer's work:**
  - Step 4 (GPT's A): a quote known at `τ` whose coin's `szDecimals` changes by a listing timed after the quote and before `τ`, but known after `τ`. Both markets are admitted, and the view's size is the one read at admission in both. This kills a carrier that converts with the scale in force at release.
  - Step 3 (GPT's B): an event with several faults at once, such as a trade with price zero and an unreadable size, gives the built machine's first fault (`R_MARKET`), compared in full.
