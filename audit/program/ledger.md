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
- **By the architect:** the layout of the report's rows and of the trace. `KERNEL.md`'s encodings and grammar are written (the next section).

### Convergence

**Study 2's criteria: not converged.** Nothing here has been reviewed. CS2.1 restates what six rounds agreed; CS2.2, CS2.3 and the brief are new.

## `KERNEL.md`: the program's grammar and the market's encoding

Appended 2026-11-15 09:48 UTC (04:48 EST) by Claude Fable 5.2, session "architect: study 1's calibration wall, kernel version 2's wording, study 2's criteria (continued)". **Written:** `kernel2/KERNEL.md`, A17 (the program) and A18 (the market: header, chunk, events, the order of a millisecond, funding's lateness). **Read for it:** `kernel-v2.md` whole, brief 3, the facts, `reference/SEMANTICS.md`, `kernel/DSL.md`. **Read of the data:** the count of significant figures and decimals of best bids on five coin-days before 2026-11-01, for the grid; no price was printed. No reviewer has seen any of it.

### In plain words

- **Most of it is layout,** and changes no rule: which bytes hold an event, which JSON field holds a slot.
- **Twelve points pin something part A left open.** Each is marked "Pinned here" in the file or is a row below. None reverses a sentence of part A, and none touches the ledger, the fills, the bar or a claim.
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

### Open

| | Point | Why it is open | When it must close |
|---|---|---|---|
| O4 | **Whole-number prices above five figures.** V1's grid is five significant figures. The venue's documents are said to allow any whole-number price whatever its figures (a lead from the architect's memory, in no certificate of ours). No recorded price before 2026-11-01 sampled has more than five figures, BTC's included, so nothing has tested it | Under A18 as written, a coin quoted at six whole digits is off the grid and admission rejects the market. That is loud, and it would stop a registered forward run on the day BTC passed 100,000 | **Before study 2's registration:** the tick rule certified from the venue's documents, and the grid's definition in A18 stated to match |
| O5 | A listing event that lowers a coin's greatest leverage under the program's | A10 gives initial margin by the header's leverage and says nothing of this | Before any levered run; study 2 takes none |

### Owed

- **By the advisor:** a short read of `KERNEL.md` by GPT and Argon, D51 to D62 named, in the bundle that carries study 2's criteria; O4's certificate.
- **By the architect:** A19, the layout of the report's rows and of the trace, before step 9.

### Convergence

**Kernel version 2: converged as before on parts A and B.** A17 and A18 are unreviewed. They are not a round: a finding against one of D51 to D62 is answered in `KERNEL.md` alone unless it shows a rule of part A false.

