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

## The last pass

Appended 2026-11-16 21:14 UTC (16:14 EST) by Claude Fable 5.2, sessions "architect: the last pass" and its continuation after a cut. Fable's last session: the architect after it is a fresh Opus 5.5 session at maximum reasoning (the human, 2026-11-16). It read brief 3's steps 5 to 10 against the machine step 4 built (`kernel2-step4-wip`: `Machine.lean`, `Laws.lean`, `Ledger.lean`, `Lang/`), named each wall a builder would meet, and answered it in the brief under its step. No market data. No reviewer has seen this.

### In plain words

- **The steps after 4 were written before the machine existed, and several could not be built as written.** Step 5's tests spoke of fills, and nothing fills until step 6. A law's text became false once a tick carries exact inputs. A test asked for a speed with no tick named.
- **Each answer removes a choice and adds no mechanism.** One move by which an order fills, used by every rule. One function that applies an effect, called by the world and, `δ` later, by the view. One mark a coin in a check. An identity of inputs alone.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.**

### Settled by a derivation the reviewers have not seen (brief 3)

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D131 | Where A7's cut lives, when step 5 has no fills | The cut (the least of what is offered, the remainder and, for `reduce_only`, the position) is the same at arrival and under both rules. It is one move of the world, `offer`, built at step 5; step 6 builds what is offered and when, and writes no cut. An order whose own fill took its remainder to zero is not live | **Yes** (step 5, wall 1; step 6, wall 1; A6, A7) |
| D132 | What S1, R1 and X1 are stated of | Every sequence of events and offers from a `start`; S1's witness is a cycle an offer ends. Later steps add moves and cases, and no statement changes. Offers are given by Lean fixtures; `mm2` has no command and no export for one (B2) | **Yes** (step 5, walls 2 and 3) |
| D133 | The exact sort in the evaluator the laws stand on | One pass in index order, exact values in a second array; the tick gives the view's exact inputs; `NumOps` gains the two crossings. N1's frozen text becomes false (two runs may differ in `bid`): its writer restates it with the ticks' exact inputs equal, and N1 and L3 claim both arrays; L2's units gain the exact half. No other frozen statement changes | **Yes** (step 5, wall 4) |
| D134 | The view's account | The world's function, called at the effect's `known`, which is its time plus `δ` whatever its event's `known`. The view works out no remainder. Its `equity` and `free_margin` are no price inputs, so staleness leaves them defined | **Yes** (step 5, wall 5; test 10) |
| D135 | A6's and A10's margin | A check has one mark a coin, its adverse price, for equity and every notional, maintenance's too. An order's requirement is what it opens, at its limit price, times one over the leverage plus the taker rate. What it opens is its own and not summed over its side (V11). The world keeps the latest quote's best bid and ask from step 5 | **Yes** (step 5, wall 6; step 7, wall 1; A6, A10) |
| D136 | A listing's events and orders | A change cancels the coin's orders when lots, grid or tiers differ, and a restatement cancels nothing. A wish for an ended coin places nothing | **Yes** (step 5, wall 7; A6) |
| D137 | What a wish is | Two rationals, or a price and `close`; a notional is divided at the tick by the slot's exact price, and a price of zero leaves the slot inactive. Arrival rounds. `first_price` is the opening order's cost over its size; the opening order is the one whose fill took the position from zero | **Yes** (step 5, wall 8) |
| D138 | The clock's kinds of time | Ticks, arrivals at `τ + λ` and, from step 9, days' ends, in time order and in A18's order within a millisecond, before the first fed event of a later time. Step 4's fifth lemma is proved of all | **Yes** (step 5, wall 9; step 9, wall 4) |
| D139 | What a quote's reading keeps | Every level, as integers beside the lots they were read at. The world's book is the latest quote's, and a level is made a `Rat` when an order takes from it | **Yes** (step 6, wall 2) |
| D140 | Whether a print fills an `ioc` | Never: an `ioc` never rests. `optimistic`'s credit before arrival is of a `gtc` or an `alo` | **Yes** (step 6, wall 3; A7) |
| D141 | V10's count | An order's taker fill at a quote that came less than `G` after an earlier quote at which an order of the account took on that coin and side. Fills at one quote are not earlier than each other; a liquidation's closes are not counted | **Yes** (step 6, wall 4; A7) |
| D142 | Step 6's speed test's tick | One second, deciding at every tick: the replica's clock. A minute's tick would be B5's wall from the wrong run again | **Yes** (step 6, test 11) |
| D143 | A settlement in the ledger | The ledger's own event: the whole position closed at a price at or above zero, with no fee. The fill's guard, a price above zero, stays. A1 and U1 keep their text | **Yes** (step 7, wall 2) |
| D144 | L1a and L1 once a run can abort | `snapshots` is `none` for a run that rejects or aborts, so L1a's text stands. L1 is stated of what `feed` and `finish` return through `t`, since a run rejected later publishes no row | **Yes** (step 7, wall 3) |
| D145 | L1a's proof for the whole machine | Step 4's five lemmas. The view's part gains the view's account and the pending effects known by `τ`; a wish's arrival after `τ − δ` is a step of one side whose effects are not known by `τ` | **Yes** (step 7, wall 4) |
| D146 | A bar market's staleness length | `Δ < G ≤ 2Δ`, or `start` refuses: at `G ≤ Δ` every bar's prints find the coin stale, and above `2Δ` a missing bar does not make it stale. A bar's print rounds to the nearest grid price and to the least where none is below. Test 6 measures and has no wall | **Yes** (step 8; A16's B5, A18) |
| D147 | What an identity hashes | Inputs alone, all known before the run: the readers' dropped counts are outputs, in the result row and the summary. One canonical JSON text of named fields, the windows and the build two of them. Aliases rename and do not reorder | **Yes** (step 9, walls 1 to 3; A13) |
| D148 | K2 in Lean, and test 13's paths | The pin has no Mathlib and no input is added: K2's Lean statement is the arithmetic, and the two real inequalities stay on paper with K3, held by test 9. A null with one law an event leaves every decimal grid, so test 13's paths are rows given to `confirm` | **Yes** (step 10, walls) |

### Settled by a derivation the reviewers have not seen (brief 4)

Read against `kernel-v2.md` part A, `KERNEL.md` A17 to A19 and CS2.1 to CS2.3 as committed. Data read: the times and `dir` of the vault's TON fills and the stamps of the stored `fundingHistory` rows, all before 2026-11-01; no price.

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D149 | The replica's clock | `tick` of 1 s, `decide_every` of 1: with `λ` and `δ` at a second a coarser clock is a third, unregistered delay. It is the ladder's and not the fit's | **Yes** (brief 4, the venue's table) |
| D150 | Funding's `late` and `lag`, the listings' `lag` | `late` of 3,599,999 ms, the longest admitted: an event's hour is its stamp's floor, so a shorter one catches nothing and one late stamp would end the forward test; every hour of a day run is still due within that day. `lag` of `δ`. Listings an hour, the copy's cadence. The stamps on record are at most 139 ms late (86,496 rows) | **Yes** (the venue's table; the registration holds them) |
| D151 | Who judges the vault's chain | Lean: `chained` (law M4), from the `flow` rows the replay of given fills now writes and each fill's `startPosition`. CS2.3's "not judged" rested on an OCaml test's check | **Yes** (step 1; brief 3's replay of given fills) |
| D152 | M1's proof | Sorted lists for one coin; an exchange lemma on the two earliest entries; an induction on the lengths. No Mathlib | **Yes** (step 1, wall 2) |
| D153 | Where the ladder ends and the trigger begins | Two `let`s, `anchor` and `unit`. Step 2 writes the levels and the exit over them; step 3 writes the entry's slots and those two, and nothing else. A first buy filled in part is the fit's to settle | **Yes** (step 2, wall 1; step 3, wall 1) |
| D154 | The anchor, the rounding, the kind of order | `first_price`: a fill's row holds no limit and the language no input for one. The engine's rounding: a program cannot round, and one-step misses in one direction are reported, not hidden. `gtc`: the vault's levels and exits took in 1 to 2% of their fills, which no post-only order does | **Yes** (step 2, walls 2 and 3) |
| D155 | Refusals at a second's tick | A refused slot writes a row a tick, so a level's `when` holds the venue's minimum. Step 2's test 3 forbids `margin` and `cap` refusals and any refusal of a level or the exit; an entry's dust remainder is refused by A6 as designed. The tests enter by a declared source held for one tick; test 5's entry is a literal size and price | **Yes** (step 2, walls 4 and 5; tests 3 and 5) |
| D156 | The fit's cost and plan (O23) | Rounds: many trials on August 2026, a quarter of an hour of admission each, then the survivors on the whole span, 7 to 17 hours each, side by side | **Yes** (step 3, wall 2) |
| D157 | The record's holes | Stale, so nothing fills and a held position stays; the price follows prints and funding is paid. The fit and the check count the vault's entries in a hole against the match, as CS2.3 does. Step 4's table names each coin's stale days and whether it was open in them | **Yes** (step 3, wall 4; step 4, test 6) |
| D158 | A path's arithmetic | Lean's: one pure function from the replay's rows, a pair and 730 days. The pin gives OCaml no exact rationals. The digest is `digestif`'s | **Yes** (step 5, wall 1) |
| D159 | What `study2 forward` holds itself to | Every registered field of the header, read from the registration. The registered build is the engine's; `study2`'s own OCaml is outside it and may be fixed | **Yes** (step 6, test and wall 1) |
| D160 | The forward universe | The vault's 17 coins, each listed at the first judged midnight by the listings copy; one that is not is named and is in no market | **Yes** (step 6, wall 2) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O21 | Whether step 3's rates are met | **Closed, met.** On one isolated core the strings day took 8.7 s of 22 and the doubles day 313 s of 470. At the measured 126 µs a quote the window's admission is 8.0 hours of the 12 allowed; the batch runs when calibration ends and is a record of time and memory, not a decision | |
| O22 | The recorder's reader inside 22,500 a second | Open until step 6's test 11. `feed` alone takes 8.7 of the 44 µs a quote allowed there, so the reader, the prints and the ladder's ticks have 35 | Step 6's reader, if the profile shows it most of them |
| O23 | The trigger's fit at the new wall | **Closed** by D156 | |
| O24 | The replica's own trace at a second's tick | 311 million `tick` rows a replay, some 15 GB a run, and a billion over the forward years, rewritten monthly. Nothing judged reads them. Not derived: I have not found the form that removes them without a switch in the engine or a second kind of trace. Test 11's time with rows written, and the first whole day's bytes, decide whether it is a wall at all | The trace's `tick` rows, if a wall |
| O25 | A position held into a hole of the record | TON's quotes stop on 2026-06-15 and the coin stays listed; every coin is silent for a week in July. If the replica holds a coin there, the replay's variance, which CS2.2 reads and the bootstrap resamples, carries a holding the rule could not sell. Step 4's table decides whether it happens | CS2.2's reading or a dated revision before any judged day, if it happens (H15) |

### What a read should check

1. **D150.** A stamp the longest `late` admits and a shorter one should have refused; an hour of a run's last day that is not due.
2. **D151, D152.** A vault record that `chained` passes with a fill missing (a round trip missing whole passes: V18 says so); a pair of sorted lists on which the recursion is not the largest matching.
3. **D153 to D155.** A ladder the two `let`s cannot say; a refusal the restated test 3 lets through that Argon's finding 4 was about.
4. **D157, O25.** Whether TON traded after 2026-06-16, from the trade record's counts; a coin stale in a hole whose price a print moves, and what `Wᵇ` values it at.
5. **D159.** A field of the forward header a result moves with that the registration does not hold.
6. **The earlier rows, D131 to D148:** each against the step it names. The ones I would attack first are D133 (N1's restatement), D135 (one mark a check) and D146 (bars).

### Assumptions only the human can choose

| | Choice | My recommendation |
|---|---|---|
| H15 | Only if step 4's table shows the replica holding a coin through a hole of more than a day: whether CS2.2 is read against that replay as it stands, with the holding named as a qualification, or revised with a date before any judged day is run | Read it as it stands. A revision that picks the replay's days or coins after the table was read is a choice made after a price |

### Owed

- **By the advisor:** this section's rows read by GPT and Argon, D133, D135, D150 and D151 first, since each changes what a judged run does; the count of TON's rows in the trade record by day from 2026-06-16; N1's, L3's and L2's restatements by their writer before step 5's build; step 5's test list as the first report gives it; the fit's sandbox and its test (brief 4, step 3, wall 5).
- **By the next architect:** O24 and O25 when their measurements come; the profile if step 6's rate is missed.

### Convergence

**Answered by derivation and not yet read.** O21 and O23 are closed. No open dispute would change what is built before step 6's test 11 (O22, O24) and brief 4's step 4 (O25).

### Handover to the next architect

Written 2026-11-16 21:28 UTC (16:28 EST) by Claude Fable 5.2, in its last session, for the Opus 5.5 session that takes the role. It restates no brief.

**What is settled, and where its derivation lives.**
- **What the machine does and why:** `kernel-v2.md` part A is the contract, and parts C to G hold the reason for each rule a review changed. `kernel2/KERNEL.md` A17 to A19 pin every encoding, and each "Pinned here" is a choice a builder once had to make.
- **The laws:** their statements are `kernel2/lean/Engine/Laws.lean`, committed before their proofs; part B3 says what each is for. Proved today: steps 0 to 4.
- **Study 2's test:** architecture 6.1 to 6.3 (why 20, the bar, the wealth at the bid, the power), 6.4 (what fidelity can be read) and 6.5 (what the freeze reads). The criteria are on `main` and are never edited.
- **Every number:** `arithmetic.py.txt`. A number in a brief that is not computed there is a defect.
- **The walls foreseen:** under each step of briefs 3 and 4, and rows D131 to D160 above. No reviewer has read any of them: that read is the next round, and it should start at D133, D135, D150 and D151.
- **What the human chose:** the H rows of this ledger, and `audit/decisions.md`.

**What is open, and what would decide it.**
- **O22, O24:** brief 3's step 6, test 11, with its profile. For O24 I would first compress the spool and measure; I found no form of the trace that drops its `tick` rows without a switch in the engine, and would not build one before a measurement asks.
- **O25, H15:** brief 4's step 4, test 6, once the trigger exists.
- **O17 to O20:** the trade record's counts and the venue's page, the advisor's.
- **Before step 5's build:** N1, L3 and L2's units restated by their writer (D133); the list for the test writer in the first report of this pass.
- **Running:** B4's comparison on prodesk5; the whole-window batch after calibration.

**How I would approach the next wall.**
1. **Find the sentence the builder had to choose a reading of.** A wall shows one level below where the design is wrong. L1a's builder sought a lemma, and the answer was the law's own second premise. B5's wall came from costing the wrong record. The fix is to that sentence of part A, never to the step.
2. **Ask what the machine already holds.** Every answer of this pass removed a choice by pointing at something already there: what admission read, the ledger's fold, the order of a millisecond, the view as the world `δ` late. An answer that needs a new state, a second clock, a deferred count or a stake that moves without a fill is wrong, and the human has said to stop there.
3. **Read the code as built, not the brief.** `Machine.lean`'s `admit`, `advanceRec`, `staleAt` and `snapshots`; `Ledger.step`'s guards; the statements as they stand in `Laws.lean`. Two walls of this pass were a frozen statement whose text a later step makes false (N1) and a guard the brief contradicted (a settlement at zero).
4. **Read the facts against every step that touches the record.** The archive's holes and TON's empty book were in `facts-kernel-v2.md` §6 and in no design.
5. **Derive a number from the run that will be made.** One with no run behind it is measured and reported, and is no wall (brief 3, step 8, test 6).
6. **For each new law, try the engine that does nothing and the one that answers a constant,** and state it over the world's moves, not over `feed` alone (S1 at step 5).
7. **Write tests for a writer who sees only the brief.** A test that needs a fill, a trigger or a first buy says where it comes from.
8. **A wall in a committed criterion is reported.** A dated revision comes before the evidence it judges, and only where it cannot add a false discovery.
9. **When a review's findings keep landing on patches, re-derive.** That was the thesis refreeze's fourteen rounds.

## The last pass, round 1: Argon's part 1 and GPT's part 2, answered

Appended 2026-11-16 22:32 UTC (17:32 EST) by the Opus 5.5 architect, session "architect: the last pass, round 1" (brief `data/builder/architect-last-pass-r1.txt`). Reviews: `audit/reviews/2026-11-16-argon-cli-last-pass-part1.md` (Argon, priorities 1 and 2) and `audit/reviews/2026-11-16-gpt-last-pass-part2.md` (GPT, priorities 3 and 4, in Argon's place), with the advisor's facts from `kernel2-step4-wip`. Commits `177428d` to `f47a137`. No market data read.

### In plain words

- **Three of Argon's findings had one cause: the move by which an order fills was cut too fine.** The last pass made each level of a book its own fill. So an order selling through its position ended its own cycle when a level happened to match the position's size, a `reduce_only` order cut to nothing became a fill of no units, and a print's next order could not know what the one before took. The contract already said an order's fill at an event is one fill at the levels' prices. The move now takes all an event offers an order, and the `reduce_only` bound moves into the remainder, where `close`'s already was: the cut, its cancel and its cause go.
- **Two laws claimed the wrong thing.** L1 was restated of rows a rejected run never makes, and spoke of one horizon where the study's monthly replays each end at their own midnight: it is now of runs that complete, across horizon ends. R1's "two equal wishes do what one does" added nothing to A6 and read across events was false: it goes.
- **The freeze had a hole.** The runner that picks the files, builds the header and hands rows to the verdicts sat outside the registered build. It is inside now, with the readers; what writes the record stays outside.
- **The record's holes are decided now, before any replay:** the replay is read as it stands. Every other answer would choose its days or coins after a price.
- Nothing needed a second clock, a deferred count or a stake that moves without a fill.

### Who has seen what

- Argon and GPT read the last pass at `59ff545`. Neither has read this section or its commits.
- GPT's step 5 tests and laws (`kernel2-step5`, `b1689bc`) were written from the last pass's brief and report, and no other model has read them. What changes in them is in this round's report (`data/builder/architect-last-pass-r1-report.md`), item by item; brief 3's step 5 holds the tests as they now stand.

### Agreed

- **Conceded, each at its cause (rows below):** Argon's 1.1, 1.2 (all four parts), 1.3 (all three), 2.1 (both parts), 2.2 (the built gap, and N1 and L3 silent on the wishes) and 2.3; GPT's 1 to 5.
- **GPT's two qualifications of Argon's part 1, accepted.** 1.1 is a defect because A7 and F0 define an order's fill at an event as one fill and the last pass's step 6 wall split it, not because the machine owes invariance to every split: across orders at one event the cycle's end still cancels the next order, as A6 means it to. 2.2's second rewrite does not break L3: every rule keeps every node, and its value, where it was.
- **Stands as each reviewer accepted it.** Argon: the offer as a move given in Lean and no export (D131, D132, as revised by D161), the one-pass evaluator (D133), the view's account (D134), the clock's kinds of time (D138), `snapshots` of none on an abort (D144's half on L1a), L1a's proof (D145). GPT: the fee on what an order opens, an `ioc` that never rests, V10's count, bars at `Δ < G ≤ 2Δ`, an identity of inputs with counts as outputs, and no day or coin dropped after a table is read.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D161 | What an order's fill is when an event offers it several prices (Argon 1.1, 1.2b) | **One fill an order an event.** `offer` takes the list of lots and prices an event offers one order, in order, up to its remainder: one fee, one change of the position and of `filled`, one row at the fill's notional over its units, one test of the cycle's end. A7 and F0 said so; the last pass's step 6 wall offered a level at a time and so let an order's own walk end its cycle. Across orders at one event, and across events, a cycle still ends at the fill that makes the position zero | **Yes** (step 5, wall 1, tests 2 and 11; step 6, wall 1, test 12; A7, A12, F0, T1; A19's `fill` row) |
| D162 | Where `reduce_only` is held (Argon 1.2a) | **In the remainder:** at most what of the position the order would reduce, as `close`'s is exactly that. Nothing is cut at a fill, so there is no fill of no units for the ledger to refuse, no cancel for a cut, and no `reduce_only` cause. An order that cannot reduce is not placed, or, placed, rests and takes nothing | **Yes** (A5, A6, A7, S1, V2, A19; step 5, test 11; step 6, test 5) |
| D163 | What the move does at a stale coin | Nothing, as at a coin with no quote yet, which is the same case: a coin is stale before its first quote (A3). One guard, in the one move, for both rules | **Yes** (step 5, wall 1, test 11) |
| D164 | Step 6's wall on `alo` and on `optimistic` at a quote (Argon 1.2c, d) | A marketable `alo` is refused and offered nothing, before any walk; under `optimistic` the quote then offers each order resting since before it, whose price its ask meets, its whole remainder (A7's table) | **Yes** (step 6, wall 1, test 12) |
| D165 | Test 8's order of slots; R1's equal wishes (Argon 1.3a, b) | A fixture that offers sets the order itself, so the clause on the slots' written order is step 6's, through a quote; test 7 holds admission's order now. R1's "two equal wishes arriving in turn do what one does" is A6's second case when nothing comes between, and false across events at step 6 (an `ioc`'s cancel at its arrival): it is deleted | **Yes** (step 5, test 8; R1) |
| D166 | What X1's second sentence quantifies over (Argon 1.3c) | The rational each `exact(·)` gives, not the float it reads: each evaluator's crossing is its own. So stated it is true, and not empty | **Yes** (X1; step 5, test 1) |
| D167 | L1 (Argon 2.1) | Of two runs that **complete**, of one header **but for the horizon's end**: the rows before `t`, and a day's end's rows at `t`. A run rejected after `t` publishes nothing and, as built, never made its earlier rows, since admission is checked before the clock runs up to an event; and CS2.1's replays each end at their own midnight, which a law of one horizon did not cover | **Yes** (L1; step 7, wall 3, tests 6 and 7; step 9, test 10 and its laws) |
| D168 | Aliases, and what N1 and L3 claim (Argon 2.2) | The sources table renames the header's observations by `Config.rename` at `parseHeader` (step 9), so an aliased run is N1's renamed run; until then it fails closed. N1 and L3 claim the wishes as well as both arrays. `Program.redirect` need not touch slots | **Yes** (step 5, wall 4; step 9, wall 3; L3, N1) |
| D169 | L2's exact half (Argon 2.3) | Sorts and units, with a witness that an exact value is defined. The crossings are definitions (`Exact.decode`, `Exact.nearestBits`), held by test 1 and no clause of L2; `bitsOps.finite` is `decode`'s test on the bits, IEEE 754's definition, so no proof reads `Float.isFinite` | **Yes** (step 5, wall 4) |
| D170 | What one adverse mark a check claims (GPT 1) | A choice and no bound: the venue's one mark for equity and maintenance, at a mark V6 leaves unwitnessed. Across a tier's step it can be the lenient one. Study 2's account meets that step only once funding has taken its cash below minus half its long notional | No (step 5, wall 6; V6) |
| D171 | What the registered build holds (GPT 2; the advisor's fact on `identity/gen.ml`) | Every source compiled into what a judged run executes, the Lean engine, `mm2` with its readers and `study2`, taken from the trees as compiled and not from a list, and the store paths of what compiles them and what they call. What writes the record stays outside: the recorders, the vault's collector, and the pull of settled funding, now a collector's. The one-line fix to `gen.ml` restores D147's premise; D159 also needed the runner inside, and is replaced | **Yes** (A13; brief 4, step 6, wall 1; brief 3, step 9, test 10, and the recorders' table; architecture 6.6) |
| D172 | The record's holes (GPT 3, 4; O25, H15) | **Decided before any replay:** the replay as it stands, holes included, for the forecast, the choice of `φ` and `d` and CS2.2's variance. After test 6's table any other answer chooses after a price; a revision now would hold a replay cleaned of its gaps against a forward run that keeps its own (CS2.3). A19's `open` is the account's exposure while stale, as A3 says | **Yes** (brief 4, step 4, wall 1, test 6; step 5, wall 2; A19) |
| D173 | What layer 2's "no failure" covers (GPT 5) | Only the fills it judged. Its report counts the vault's maker fills judged, failed and in stale spans by role and cadence period, and a class with more in stale spans than judged goes to the architect before the trigger is fitted | **Yes** (brief 4, what it rests on; brief 3, step 10, test 15) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged: step 6's test 11 and the first whole day's bytes | The trace's `tick` rows, if a wall |
| O25 | A position held into a hole | **Closed** by D172 | |

### What the next read should attack first

1. **D161 and D163:** a split of a record, across orders or events, that moves a judged number where it should not; the trace's one price for a fill at several levels.
2. **D162:** a `reduce_only` order whose position flips and flips back inside one cycle; a statement of steps 5 to 7 whose case the remainder's bound changes.
3. **D167:** `finish`'s rows at a horizon's end (the last span's rows, funding's due hours, the last day's stale share) against a longer run's.
4. **D171:** anything that still turns a record into a verdict outside the build.
5. **D172:** whether a revision fixed now, before any replay, from integrity data alone, would serve CS2.2 better than the record as it stands.

### Committed criteria: reported, not edited

- **CS2.1's definitions** cite L1 for "what a day's end showed stands in every later replay". L1 as frozen did not reach replays of different horizons; restated (D167), it does. The words stand; no human choice.
- **CS2.1's registration** names "the engine's build". That build now holds `study2` and the readers (D171), so the registration names more than the words ask and nothing less. The words stand; no human choice.
- **CS2.2** is read as committed, against the replay as it stands (D172). The alternatives were a revision after the table, which the process bars, or one now, which would treat the replay's gaps unlike the forward run's. No human choice.
- **CS2.3** is untouched: GPT's finding 5 is of a readiness wall (D173).

### Assumptions only the human can choose

None new. H15 is withdrawn (D172): the one answer it could lead to without a choice after a price is the one decided now.

### Owed

- **By the test writer (GPT):** the changes to `b1689bc`, as this round's report lists them, before step 5's build; step 7's writer restates L1 (D167).
- **By the advisor:** `gen.ml`'s failing test and fix, the test changing a byte in each compiled directory (D171); the collector of settled funding beside `mmvault`; this section read by Argon (its queued part 2, since the design changed) and GPT, D161, D162, D167 and D171 first.
- **By the next architect:** O22 and O24 when step 6's test 11 reports.

### Convergence

**Answered by derivation, and not yet read.** The design changed in D161, D162, D167, D171 and D172, so the next round is due. No open dispute would change what step 5 builds, once its tests and laws carry the changes listed in the report.

## The last pass, round 2: GPT's read of round 1, answered

Appended 2026-11-16 23:24 UTC (18:24 EST) by the Opus 5.5 architect, session "architect: the last pass, round 2" (brief `data/builder/architect-last-pass-r2.txt`). Review: `audit/reviews/2026-11-16-gpt-last-pass-r1.md`, not converged on four points. Commits `635f748` to the one that appends this. Data read: the vault's fills before 2026-11-01, counts only and no price; this host's libm. No market data.

### In plain words

- **The test's books never needed a fixed grid.** Round 5 derived one from every price being a decimal. A fill that takes several prices costs a unit their mean, which is not a decimal, so the claim goes and the books stay exact. What it costs is measured: copying all of the vault's fills of several prices adds 213 bits to a denominator of 168 over seven months.
- **A monthly replay reads the whole record again, and the record could change under it.** A later pull of funding can restate an hour already judged, and the venue does restate: the pilot's store held 24 funding keys with several revisions. Now each replay reads the first row recorded for each hour, runs only the days the record has closed, and publishes nothing that differs from the replay before it. So "what a day's end showed stands" is true of everything published.
- **Our lists of what the engine's build is were short three times.** The build is now what Nix says it is, the hash of its derivation, compile and link options included. The host matters too, and no build holds it: one executable computes `exp` differently with FMA and without (2,446 of 4 million arguments, measured), so the executables check their host at start.
- **Keeping the replay's holes was right, for another reason than round 1 gave.** The test's wealth lives through both periods' holes. Each alternative measures a wealth the test does not run on, or needs a revision of a committed criterion.
- Nothing needed a second clock, a deferred count or a stake that moves without a fill.

### Who has seen what

- GPT read round 1 (D161 to D173) at `c8449eb`. Nobody has read this section or its commits.
- Argon read the last pass at `59ff545` and none of rounds 1 and 2: its read of both comes next, from a bundle in the Gemini web UI.

### Agreed

- **GPT's acceptances of round 1, standing:** D161's one fill an order an event and D163's stale guard; D162's remainder, a `reduce_only` order resting at zero reducible included; D164 to D170 as GPT qualified them; D171's readers and `study2` inside the build; D172's decision, read as narrowing the claim; D173's limited coverage.
- **GPT's four findings, each conceded at its cause** (rows below).

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D174 | What the test ledger's cash and its proofs rest on (GPT 1) | **Exact rationals on no fixed grid.** The grid of half of `10⁻⁵⁰` came from every price being a decimal; a fill at several prices costs a unit their mean (A7, D161), and a liquidation's close at several levels did so before D161. No proof rested on the grid, and K1 could not have held it for every row `confirm` takes: step 10's simulated nulls already leave every grid. K1's conjunct and A12's sentence go. A denominator grows only at a fill of several prices, by at most a factor of its units in lots: the vault's 46 such fills of 748 takes add 213 bits to 168. Keeping a grid would trade the ledger at a price that is not the account's, which is not the copy CS2.1 judges, or copy each level, a second record beside the fill's cash (A19). `W` as committed (the row's `−cash / units`) is unchanged | **Yes** (A12, K1; step 10, tests 3 and 14; brief 4, step 5's wall on the bootstrap's factors) |
| D175 | What makes every replay read the same events before a day's end (GPT 3) | **The record, read one way.** Files are recordings, never rewritten, and each pull is a new file. An hour's settlement is the earliest pull's row; a later pull's other row is a revision, counted and never read. A replay runs only through the last midnight every source has closed: the recorder once it has opened an hour past it, a copy once it holds one taken after it, the settled funding once every universe coin then listed has every hour before it, held or not. So no later pull can add to or change a day already run. The pilot's snapshot and stage 7's delivery at known time each let a later revision change a past run, and a test that names a day once cannot | **Yes** (brief 4, step 7, wall 3, tests 2 and 10; brief 3, the recorders' table; L1's text) |
| D176 | Whether that is enough | **Each replay checks the rows themselves.** Its report and trace, up to the replay before it's last `day` rows, must be byte for byte that replay's; otherwise it publishes nothing and goes to the architect, and if the cause cannot be undone the test ends at the day before, as a record that stops ends it. D175's premises are a list, and GPT's finding 4 of this round showed what a list misses | **Yes** (brief 4, step 7, wall 3, test 10) |
| D177 | What the engine's build is (GPT 4) | **Nix's hash of the derivation** that builds the executables a judged run executes, with the protected-windows file at a fixed stand-in; the build reads its windows and this hash as data. A derivation holds every input of a build, options included, and Nix builds it in a sandbox. `gen.ml`'s list, the sources it embeds and its hash are deleted. The build was a list four times (the sources; part E's toolchain; `gen.ml`'s three directories; D171's trees), each short: the design was wrong in the list, not in what it left out | **Yes** (A13; step 9, wall 5, test 10; brief 4, step 6; replaces D171's mechanism, keeps its scope) |
| D178 | What a build cannot hold | **The host.** glibc's `exp` and `log` take one path with FMA and another without, differing at 2,446 of 4 million arguments of `exp` and 1 of `log` by one unit in the last place (glibc 2.42, `arithmetic.py.txt`, `last_pass_r2`). The executables compute both at start, at arguments where the paths differ and no compiler folds them, with a subnormal product, and refuse a host that gives other bits (`E_HOST`). The bits are those of the path B4 passed on. D1 is of the hosts that pass | **Yes** (A13, B2, D1; step 9, test 8; brief 4, step 6) |
| D179 | D172's derivation (GPT 5) | **The decision stands, and its reason is replaced.** Answers fixed now from integrity data, or one treatment of both periods, also choose before a price. The record as it stands is chosen because the test's wealth lives through both periods' holes: dropped days measure a wealth the test does not run on, a coin dropped for its silence is another replica, and a treatment of both periods revises what CS2.2 reads. Its cost: CS2.2 can say "did not hold" for recording conditions alone (GPT: a record traded on a third of the time against one traded throughout gives a ratio near three). The report gives each period's stale share beside the ratio | No (brief 4, step 4, wall 1; step 5, wall 2: text, and the stale shares reported) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged: step 6's test 11 and the first whole day's bytes | The trace's `tick` rows, if a wall |

### What Argon should attack first (rounds 1 and 2)

1. **D175 and D176:** a change to a day's events between two replays that the closure, the earliest row and the check all let through; and an honest record on which the check fires, or the closure never comes, and ends the test for nothing.
2. **D177:** two executables with one build hash that compute differently: a build that reads outside its inputs, a program found on `PATH`, something the environment of a run changes. And whether the stand-in for the windows file can be given without changing what the derivation does with the real one.
3. **D178:** a host that passes the probe and computes another `exp` or `log` elsewhere, and anything else of a host that reaches a judged number.
4. **D174:** a proof, test or resource bound that still leans on the grid; where an exact denominator could grow past what was measured (the bootstrap's paths, the guard, step 10's simulated nulls).
5. **Round 1, which Argon has not read:** D161 to D163 (one fill an order an event), D167 (L1 across horizons), D172 with D179.

### Committed criteria: reported, not edited

- **CS2.1's definitions:** "No later event changes a row of an earlier day (law L1), so what a day's end showed stands in every later replay." The inference needs replays that read the same events, which D175 makes so and D176 checks. The words stand. A replay that cannot reproduce an earlier day publishes nothing, and if the cause cannot be undone the test ends at the day before: read as "a record that stops ... ends it at the last day run". That can only end the test early, never confirm. No human choice: the alternative, results that admit revisions, would make the committed sentence false.
- **"The last midnight the record reaches"** is now defined (D175), and "the record" is the record as first written, with revisions counted beside. The words stand. No human choice.
- **CS2.1's registration** names the engine's build, now Nix's hash of the derivation (D177), and the executables refuse another host's libm (D178): more than the words ask, nothing less. No human choice.
- **CS2.2:** D179 replaces a reason and keeps the decision. Read of the record, CS2.2 can fail for recording conditions; the stale shares are reported beside. No human choice.
- **`W`:** unchanged; only a false claim about its denominators goes (D174). CS2.3 is untouched.

### Assumptions only the human can choose

None new.

### Owed

- **By the test writer (GPT):** nothing in `kernel2-step5` `b1689bc` beyond round 1's list. No answer of this round touches step 5's statements or fixtures.
- **By the advisor:**
  - step 9's wall 5 and tests 8 and 10 as failing tests, then the change: the derivation's hash in place of `gen.ml`, and the probe at start. This replaces round 1's `gen.ml` test, which becomes the first case of test 10;
  - the sandbox checked on every host that builds a judged executable;
  - the collector of settled funding writing each pull as a new file named by its time (D175);
  - Argon's read of rounds 1 and 2, in the order above.
- **By the next architect:** O22 and O24 when step 6's test 11 reports.

### Convergence

**Answered by derivation, and not yet read.** D174 deletes a false claim; D175 to D178 change what the runner and the build are; D179 is text. No open dispute would change what step 5 builds.

## The last pass, round 3: Argon's read of rounds 1 and 2, answered

Appended 2026-11-17 04:04 UTC (2026-11-16 23:04 EST) by the Opus 5.5 architect, session "architect: the last pass, round 3" (brief `data/builder/architect-last-pass-r3.txt`). Review: `audit/reviews/2026-11-16-argon-web-last-pass-r1r2.md` (Argon in the web UI, on rounds 1 and 2 at `d7a9ba2`), not converged on D162, D167 with D176, D172, D174, D175, D177 and D178; and the human's decision of 2026-11-16 23:33 UTC (18:33 EST) that the engine computes `exp` and `log` itself (`audit/decisions.md`). Commits `71b01b5` to the one that appends this. No market data read; this host's libm against Python's decimal module (`arithmetic.py.txt`, `last_pass_r3`).

### In plain words

- **Round 2's closure of the forward record was wrong in kind.** It asked each source to show that it was complete, which none can: a coin with no settlement wedged every later day, a print received just after a midnight was read by one replay and not the one before, and a fill indexed late fell outside the copy that closed its day. Now a day's record is what was written by 30 days after it, the first of each key's items, and a replay runs only the days 31 days past. Nothing waits, every replay of a day reads the same events, and each result comes a month after its day.
- **The engine computes `exp` and `log` itself (the human's decision), so the probe of the host goes.** What no build holds is the environment a run starts in: a loader variable can change what the executable runs, and the floating-point control register can change every float operation. So each executable re-executes itself with an empty environment, and the stub that calls the engine checks the control register at every call.
- **Two premises of the build's hash are now tested:** that the windows file and the hash enter the derivation as data alone, and that one derivation gives one output.
- **B4 lists every argument at which glibc was not the nearest** (about 720 a million for `exp` on this host, none of 200,000 for `log`) and compares every item such an argument does not reach.
- **The rest was text,** now exact: A6's exemption is the venue's, an offer to an order of remainder zero does nothing, a millisecond's staleness is the world's after everything in it, L1 and the check name the account row, and step 10's tests lose the grid. The exact rationals were sized: no stall.
- **Nothing needed a second clock, a deferred count or a stake that moves without a fill.** The 30 days delay when a replay runs a day; the engine's clock, counts and stakes are untouched.

### Who has seen what

- Argon read rounds 1 and 2 at `d7a9ba2`. GPT read round 1 at `c8449eb`. Nobody has read this section or its commits.
- GPT's step 5 tests (`kernel2-step5`, `b1689bc`) predate rounds 1 to 3; what changes in them beyond round 1's list is in this round's report (`data/builder/architect-last-pass-r3-report.md`).

### Agreed

- **Argon's acceptances, standing:** D161, D163 to D166, D168 to D171 (scope), D173 and D179, with GPT's two qualifications of its part 1; and, in the points it disputed, D175's append-only pulls and first row of a key, D176's fail-closed check, D177's derivation in place of a list, D174's deletion of the grid and D162's remainder.
- **Argon's thirteen findings, each answered at its cause** (rows below): 1.1 to 1.4, 2.1, 2.2, 3.1, 3.2, 4.1 and 5.1 to 5.3 conceded; 4.2 conceded as a measurement and refuted as a stall.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D180 | What the forward record is, and which days a replay runs (Argon 1.1 to 1.3) | **A day's record is what was written by 30 days after it ends, and a replay runs the days that ended 31 days or more before it starts.** An item is a recorder's line, by its `recv`, or a pull's or a copy's file, by the time it was finished, written whole before it is named. Of one key's items the first written is read; a later one is a revision, and one written after the 30 days is late, each counted and neither read. Every collector re-reads its last 30 days daily. Nothing waits for a source to be complete: a silent source leaves its day as it is (a recorder's gap is staleness, a held coin's hour with no settlement aborts every replay at that hour and ends the test, an hour of a coin not held is read by nothing). 30 days are V18's, one window for every source. Round 2 closed each source by a rule of its own, and Argon's three findings land on those three rules: the design was wrong in asking for completeness, so the rules are deleted, and D175's file rule and first-of-a-key stay | **Yes** (brief 4, step 7, builds, wall 3, tests 5 and 10; step 1, wall 1; brief 3, the recorders; architecture 6.6) |
| D181 | The check's slice and L1's day's end (Argon 1.4, 5.2) | At a midnight `T`: the report's rows of a time before `T` and, at `T`, the day's `coin` rows and its `account` row (A19); the trace's rows of a time before `T`; the vault's replay's report likewise. A run's `span` rows and summary at its horizon's end, and rows of events at `T`, are not among them. L1 names the same rows | **Yes** (L1; brief 3, step 7, wall 3; step 9, test 10; brief 4, step 7, wall 3, test 10) |
| D182 | Whether the derivation's hash is the build (Argon 2.1) | **Two premises, each tested.** The real derivation, with the windows file and the hash put back at their stand-ins, is the stand-in byte for byte, which a flake that reads either as more than data fails; and the executables built on two hosts, each in its sandbox, are one output, since a hash names a build's inputs and not its output. D177 stands | **Yes** (A13; brief 3, step 9, wall 5, test 10) |
| D183 | What fixes a run's environment, the floating-point one included (Argon 2.2, 3.2) | **A run reads no environment:** each executable re-executes itself with an empty one before it reads anything, and gives one to what it calls. **The control register is the default, and checked:** a process starts there, nothing in the build sets it, and the stub reads it before and after every call into the engine and aborts (`E_FPENV`) unless it rounds to nearest with no flush to zero, no denormals as zero and every exception masked. `leanc` compiles with `-ffp-contract=off` and no fast-math option, in the derivation. Then `+ − × ÷` and `sqrt` are IEEE 754's on every host | **Yes** (A13, B2, D1; brief 3, step 9, test 8) |
| D184 | D178, under the human's decision (Argon 3.1) | **`exp` and `log` are the engine's own** (the human, 2026-11-16 23:33 UTC, 18:33 EST): of the rational a double is, by a series' bounds at 64, 128 and then 256 bits, the result the bounds' one nearest binary64, and where none decides the lower bound's nearest (X4 ★, total and pinned to the bit, so a constant engine fails it). The probe and `E_HOST` are deleted: one argument of each function tells two of glibc's paths apart and no more, and a probe cannot see the control register. The probe was a list again, of hosts, and its cause is gone. D1 holds on every host | **Yes** (A2, A13, B1, B2, D1, X4; `KERNEL.md` A17; brief 3, step 5, wall 11, tests 12 and 13; step 9; brief 4, step 6) |
| D185 | How B4 treats an argument glibc rounded wrong (the human's question) | **It is listed, and what it reaches is counted and not compared.** At every `exp` and `log` node and tick whose argument is the reference's, the engine's result is the reference's, or the argument is listed with both results, the engine's equal to MPFR's and one unit in the last place from glibc's. Every other item is bit-identical, but those that read a listed result through A17's windows. Step 4's run with glibc, on hosts of the reference's path, is the evaluator's check in full before the change, and no second entry into the engine gives it glibc's results. Stage 6's results stand as computed | **Yes** (B4; brief 3, step 4, test 1; step 5, test 13) |
| D186 | A6's minimum, and an offer at remainder zero (Argon 5.1) | **The exemption is the venue's:** an order that only reduces (`reduce_only`, or of size `close`) and whose remainder closes the position exactly (`venue/hyperliquid/rules.json`). "Opens nothing" was wider than that and "closes dust with `close`" narrower. An offer to an order of remainder zero does nothing and writes no row; a `reduce_only` order there stays live and takes again once the position gives it something | **Yes** (A6; brief 3, step 5, wall 1, test 7; R1's statement) |
| D187 | A millisecond's staleness; the guard through the holes (Argon 5.3) | A millisecond's state is the world's after everything in it: the millisecond of the quote that ends a gap is not stale, and `open` reads positions and orders at the end of stale milliseconds. The guard's rules trade through holes at the trace's prices, as CS2.1 commits them; that is disclosed beside its figures | **Yes** (`KERNEL.md` A19; brief 4, step 4, test 6 and wall 1) |
| D188 | The grid's traces, and the sizes of exact rationals (Argon 4.1, 4.2) | Step 10's test 14 loses the grid of the guard's cash and test 3 its rule of divisibility: neither holds a judged number, and the second fails where a listing changes lots. **No stall, derived and measured:** a sum's denominator is an lcm, about 900 bits after two years at the vault's rate of fills of several prices and at most 5,540; `held`'s variance is 378,000 bits at 900, under a minute in Python's own integers; a bootstrap path telescopes within its blocks, 48,000 bits; step 10's null is drawn on the lattice of 5/4, where a path's denominators grow with its farthest power, at most 3,081 bits | **Yes** (A12; brief 3, step 10, tests 3, 13 and 14; brief 4, steps 1 and 5) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged: step 6's test 11 and the first whole day's bytes | The trace's `tick` rows, if a wall |
| O26 | `exp` and `log` at B5's walls | Open until step 5's build measures them. The ladder takes neither; a trigger that takes them at every tick and coin is the fit's to cost (brief 4, step 3) | A twin proved equal (X3's pattern), if a rate is missed |

### What GPT should attack first

1. **D180:** a change to a day's events between two replays that the rule lets through (a file named before it was whole, a clock that steps, a key that two sources share); an honest record on which the check still fires; whether the first of a key's items, rather than the last within the window, can move a judged number; the 31 days against CS2.2's and CS2.3's "first replay after".
2. **D183:** anything else of a host or a process that reaches a judged number with an empty environment and the default control register (a thread that calls the engine outside the checked stub, a library's own choice of path in an exact function).
3. **D184:** X4's statement against an engine that is wrong and passes it; the paper half's claim that a precision always decides; IEEE's special cases at overflow and underflow.
4. **D185:** an item the reach does not cover that differs, or a reach so wide that the evaluator's check compares nothing that matters.
5. **D186, D187:** a case where the venue's exemption and A6 still differ; a staleness boundary in a millisecond with a liquidation.

### Committed criteria: reported, not edited

- **CS2.1's definitions:** "the last midnight the record reaches" is now the last 31 days or more before the replay starts, and "the record" each day's items written by 30 days after it, the first of a key (D180). The words stand. No human choice: the alternatives were round 2's closure, which wedges on a silent source and trips on an honest one, or each replay's own snapshot, which makes the record depend on when the operator ran it.
- **CS2.1's monthly replay:** "each time the end of every day run so far is examined" holds, and every result comes a month after its day. The words stand.
- **CS2.3:** the vault's fills of the 61 days are closed when it is judged, since the 61st day is run 31 days after it ends; "shown more than 30 days late, or after the judging" now names one case. The words stand. No human choice.
- **CS2.1's registration:** the build as before; brief 4's test of a host on another path is deleted with the probe (D184). No human choice.
- **CS2.1's guard:** as committed; its trading through holes is disclosed (D187). No human choice. **CS2.2** is untouched.

### Assumptions only the human can choose

None new.

### Owed

- **By the test writer (GPT):** the changes to `b1689bc` this round's report lists beyond round 1's, before step 5's build.
- **By the advisor:** the funding collector's 30-day re-read and whole-then-named files (D180); step 9's tests 8 and 10 as failing tests, then the re-execution, the stub's check and the derivation's two checks (D182, D183); MPFR into the test stub's inputs only, which moves no lock; the worst-case lead for X4's paper half certified; this section read by GPT, D180 and D183 first.
- **By the next architect:** O22, O24 and O26 when their measurements come.

### Convergence

**Answered by derivation, and not yet read.** The design changed in D180 (the record), D183 (the environment) and D184 (the human's `exp` and `log`), so the next round is due, on GPT, since Argon read these points' earlier forms. No open dispute would change what step 5 builds once its tests carry this round's list.

## The last pass, round 4: GPT's read of round 3, answered

Appended 2026-11-17 08:58 UTC (03:58 EST) by the Opus 5.5 architect, session "architect: the last pass, round 4". Review: `audit/reviews/2026-11-17-gpt-last-pass-r3.md` (GPT, read-only, on round 3 at `428e9e2`), not converged on D180's availability, specification and scope, the criteria's reconciliation, the loader, X4's enclosure and ceiling, and B4's reach. Commits `ba9ffd5` to the one that appends this. No market data read; `arithmetic.py.txt`'s new `last_pass_r4` checks X4's formulas against Python's decimal module. Report: `data/builder/architect-last-pass-r4-report.md`, which holds the dated revision's draft text and the test writer's list.

### In plain words

- **D180 and B4's reach were each on their third fix, so both were re-derived, not patched.**
- **The record.** Rounds 2 and 3 made a day's record stable by something its writers did: being complete, or being on disk by a deadline they stamped. No reader can see either. What the runner controls is what it reads. So **a day is read once**: the first replay to reach it records every file's length and hash before it runs, and every later replay reads the day within those bytes. A suspended recorder, a slow disk or a stepped clock can no longer change a day already read.
- **`exp` and `log`.** The law now writes each function out: a textbook series, a bound on what it leaves out, a fixed number of terms. The result is the nearest binary64 when both ends of that interval agree, and NaN when they do not.
  - The true value is inside the interval by textbook math, so no branch can round wrong.
  - The published worst cases put the NaN far out of reach.
  - Round 3 instead let the engine supply its own bounds and, at 256 bits, guessed.
- **B4.** The reference now computes what version 2 must compute: stage 6's evaluator with correctly rounded `exp` and `log` (MPFR's). Every item is compared, and the exemption rule is gone.
- **The rest is text.**
  - The criteria get a dated revision beneath their definitions, drafted, which cannot add a false discovery.
  - The re-execution protects against an honest launch's leftovers, not against injected code, so the launch is trusted.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.**

### Who has seen what

- GPT read round 3 at `428e9e2`. Nobody has read this section or its commits.
- GPT's step 5 tests (`kernel2-step5`, `b1689bc`) predate rounds 1 to 4. This round's report lists what changes in them beyond rounds 1 and 3.

### Agreed

- **GPT's acceptances, standing:** first-observation record semantics; no source-completeness requirement; D181's slice; the derivation-based identity with explicit premises; trusted-entry floating-point checks; engine-owned `exp` and `log`; the grid's deletion; A6's exemption; the zero-remainder rule; D187.
- **GPT's nine disputes, each answered at its cause:**
  - conceded and re-derived: 1.1 to 1.3, 3.1, 3.2, 4.1 and 4.2;
  - conceded as text: 2, and the criteria's reconciliation.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D189 | What a replay reads of a day (GPT 1.1 to 1.3) | **A day is read once.** Before the engine starts, an attempt records in its attempt row every file's length and the hash of those bytes, its cut. A day's record is its items within the cut of the first attempt whose horizon reached it; a killed attempt binds too. Every later replay reads the day so, and an item outside is late, counted and never read. **Keys:** a settlement's coin and hour; a print's coin, time and id; a vault fill's coin, trade id and order id. **The record's order:** by writer, then the file's path, then place in the file, with the copy of the vault's fills before 2026-11-01 first. **Writers:** every forward writer writes about a day only within its 30 days. The 31-day lag and the first of a key stay. **Why re-derived:** round 2 asked sources to be complete and round 3 asked items to be on disk by a stamped deadline. Both rested on writers, which no reader sees, so D180's eligibility by writing time is deleted. The historical chain is read whole, since no deadline exists | **Yes** (brief 4, step 7, builds, wall 3, tests 5 and 10; step 1, wall 1; brief 3, the recorders; architecture 6.6; A13's identity) |
| D190 | The committed criteria (GPT's reconciliation) | **A dated revision beneath the shared definitions** (draft in the report). It defines what the committed words left open, the record once it grows and the last midnight a replay runs to, and restates why a day's end stands. **It cannot add a false discovery:** it is fixed before any judged day, reads no outcome, and removes the one way two replays could name different days. No threshold moves, so it is the advisor's to commit after review, not the human's | The criteria's text, after review |
| D191 | The loader (GPT 2) | **The re-execution removes what an honest launch carries,** and resets the control register. It does not remove preloaded code, which runs before `main` and which no process contains. **So the launch is trusted,** as the recordings and the build are. Two hosts' builds are evidence for an assumed premise. The design is unchanged and the claim is narrowed | Text (A13, D1; brief 3, step 9, wall 5, test 8) |
| D192 | X4 (GPT 3.1, 3.2) | **The law writes each function out:** the series, the bound of what it omits, the terms (`⌈2a⌉ + 260` for `exp`, 90 for `log`), `log`'s split, and `exp`'s range clauses at 710 and −746. **The result** is the nearest of both ends when they agree, and the quiet NaN otherwise. Also stated: each interval is at most `2⁻²⁵⁶` of its end wide, and the intervals nest, so the engine may stop early. **On paper:** textbook remainders put the true value inside, so no branch rounds wrong. **Cited:** the NaN is never the result, since the worst cases come no nearer than about `2⁻¹²⁰`; `exp`'s subnormal results may be uncovered, and are uncertified there. **Measured:** the widest intervals at the cap are `2⁻⁴⁷⁷` (`exp`) and `2⁻²⁹⁴` (`log`) on 811 arguments, all correctly rounded. **Deleted:** round 3's precisions, its bounds functions and its fallback | **Yes** (X4, A2; brief 3, step 5, wall 11, test 12; `arithmetic.py.txt`, `last_pass_r4`) |
| D193 | B4's reach (GPT 4.1, 4.2) | **The reference computes the human's function:** stage 6's evaluator with MPFR's `exp` and `log` and nothing else changed, its streams stored under a hash. Every item is compared, with no exception. Stage 6's streams stand as its record, and their difference is counted once. **The reach rule is deleted:** it came of comparing two functions | **Yes** (B4; brief 3, step 4, test 1; step 5, test 13, wall 4; `KERNEL.md` A17) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged: step 6's test 11 and the first whole day's bytes | The trace's `tick` rows, if a wall |
| O26 | `exp` and `log` at B5's walls | Open until step 5's build measures them. In Python, X4's formulas take 26 ms an `exp` (most at `|x|` near 700) and 10 ms a `log`. Lean's GMP is faster, and an integer twin proved equal is X3's pattern | A twin, if a rate is missed |

### What the next read should attack first

1. **D189:** a way two replays read one day differently despite the cut (a prefix that reads two ways, a reader that reads past its cut, a cut recorded after reading starts); a lever an honest operator's timing still has; the keys (a print resent across a reconnect, a fill restated); whether first or last within a cut can move a judged number now.
2. **D192:** an engine that is wrong and passes X4 as written; an error in the law's own formulas (the tail's condition, `log`'s split, the two clauses); a NaN reachable at the overflow threshold or at a subnormal midpoint.
3. **D193:** a way the evaluator is wrong and passes B4 (a fault shared by test 12's stub and the reference; a reference build that is not stage 6's evaluator).
4. **D190:** a run that the revision judges otherwise than the committed words; a way it adds a false discovery.
5. **D191:** anything of an honest launch that still reaches a judged number.

### Committed criteria: a dated revision, drafted

- **Beneath the definitions the three criteria share** ("The days run"): the draft is in this round's report. It defines the record a replay reads of a day (read once, within the first attempt's cut, the first of each key) and the last midnight it runs to (31 days or more before it starts). It says why a day's end stands: L1 and the one reading of each day.
- **It cannot add a false discovery,** and it moves no threshold, judged day or engine rule. So no human choice is needed.
- **The advisor has it reviewed, as a criterion is, and commits it alone.**
- CS2.2's and CS2.3's "first replay after" the 212th or 61st day is run is the first whose horizon reaches it, as GPT read it, and needs no revision.

### Assumptions only the human can choose

None new.

### Owed

- **By the test writer (GPT):** the changes to `b1689bc` this round's report lists, beyond rounds 1 and 3.
- **By the advisor:**
  - the criteria revision, reviewed and committed alone (D190);
  - `mmvault`'s pulls reaching back at most 30 days before the last midnight, where its daily re-read now reaches 30 days behind its watermark (D189; `recorder/VAULT.md`);
  - the settled-funding collector stored as `mmvault` stores its pulls;
  - the worst-case lead certified: Lefèvre and Muller's tables and the ranges they cover, `exp`'s subnormal results and the overflow threshold among them, and the hardest arguments for test 12 (D192);
  - B4's new reference streams, run on a host and stored under a hash (D193);
  - this section read, on Argon once its quota returns, D189 and D192 first.
- **By the next architect:** O22, O24 and O26 when their measurements come.

### Convergence

**Answered by derivation, and not yet read.** The design changed in D189 (the record), D192 (X4) and D193 (B4), each a re-derivation of a part on its third fix. So the next round is due, on another model than GPT, which found them: Argon, once its quota returns, or a fresh Opus session labeled as such if it does not. No open dispute would change what step 5 builds once its tests carry this round's list.

## The last pass, round 5: the record re-derived, and Argon's read of rounds 3 and 4 answered

Appended 2026-11-17 20:36 UTC (15:36 EST) by the Opus 5.5 architect, session "architect: the last pass, round 5". Reviews answered: `audit/reviews/2026-11-17-gpt-cs21-revision.md` (do not commit), `audit/reviews/2026-11-17-opus-cs21-revision.md` (commit with changes) and `audit/reviews/2026-11-17-argon-web-last-pass-r3r4.md` (not converged). Commits `516bf25` to the one that appends this. No market data read. Report: `data/builder/architect-last-pass-r5-report.md`, which holds the derivation, the rejected answers and the test writer's list.

### In plain words

- **How a replay reads a day was on its fifth fix, so it was re-derived from the criteria, not from D189.**
- **What CS2.1 needs:** one sequence of days' ends, never a second version of a day already shown. The committed text already says so: "what a day's end showed stands in every later replay".
- **The four rounds tried to make the record of a day fixed.** Each added a rule (a lag, a deadline, a binding, a choice of value), and each rule let a replay read a day otherwise than the committed text reads it.
- **Now the record is read as it is, with no lag, no cut and no choice.**
  - A replay runs at a fixed time, to the last midnight its recorder reached.
  - It publishes only what reproduces what was published.
  - If the record behind a published day ever changed, the test ends before that day. That can only take a crossing away.
  - The price: an item that late ends the test early. Under this design it takes a writer's fault, and the venue was never seen to restate a settled rate.
- **The criteria need no revision,** and D190's draft is withdrawn.
- **Argon's other points are answered at their causes.**
  - X4 now states the function the engine computes (the least count of terms that decides), so step 5 needs no extra proof.
  - The evaluator's binding is a clause of X4, not a comment.
  - `nearestBits` is tested at every binade, and the MPFR stub subnormalizes.
  - The floating-point check reads the control bits alone, and the re-execution runs once.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.**

### Who has seen what

- GPT and a fresh Opus read the drafted revision, and Argon read rounds 3 and 4 at `3f911d1`. Nobody has read this section or its commits.
- GPT's step 5 tests (`kernel2-step5`, `b1689bc`) predate rounds 1 to 5. The report lists what this round changes in them.

### Agreed

- **Argon's acceptances, standing:** D181, D182, D186 to D188; the trusted launch (D191); X4's series, remainders and edges (D192, its 3.2); B4's full comparison (D193).
- **The reviews' common ground, kept:** a replay must not run past a recorder that stopped (Opus 1); a day is read once (Opus); the check of the rows themselves (wall 3); D181's slice.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D194 | What a replay reads of the record (replaces D189; GPT 1 to 6, Opus 1 to 4, Argon 1.1 to 1.3) | **The record as it is, with its early ends.** A replay at 12:00 UTC (07:00 EST) on the first of each month, once the settled-funding collector has completed a pull begun after both that time and the midnight, does the following. That pull is `e691341`'s own fetch. It reads every registered writer's files as they are, every attempt of that month to its first attempt's lengths. Lines holding one event are one item, and two different items of one event both reach the engine (A18 and C2 reject) or the vault's chain (it fails). It runs to the last midnight at or before the last quote the recorder's files hold. It publishes only rows that reproduce those published. If its rows differ and a second host's run differs alike, the test ends at the last midnight before the first row that differs. The vault's fills are ordered by their chain within a millisecond, and CS2.3 and CS2.2 are judged once and stored. **Deleted:** the cut and its binding, the 31-day lag, the writers' 30-day window, the keys, the record's order, and "the venue does restate", which misread C0.3's 24 identical revisions. **Why:** each deleted rule was a way to read a day otherwise than the committed text. This design is that text read at fixed times, and is pathwise no more permissive than it: where nothing behind a published day changes the two are one run, and where something does, this one stops | **Yes** (brief 4, step 7: builds, tests 5 and 10, wall 3; step 1, wall 1; brief 3, the recorders; architecture 6.6) |
| D195 | The criteria (replaces D190) | **No revision.** Every term the reviews found open is the committed words read at fixed times (the report, 1.7). The one consequence they leave implicit, the early end where a published day cannot be reproduced, can only remove a discovery; the report gives a sentence for it if the advisor wants it pinned. D190's draft is withdrawn | No |
| D196 | X4's form and binding (Argon 3.1, 6.1) | **X4 states the engine's function:** the least count from `⌈2|x|⌉` (from none for `log`) to the cap at which both ends round alike, and NaN if none. The bits are the cap's, since the intervals nest and rounding is monotone. `bitsOps.exp = Exact.exp ∧ bitsOps.log = Exact.log` is a clause. (width) and (nesting) move to paper. **Why:** at the cap the engine's early stop needed a Lean proof of nesting and monotonicity, or hours of test 12 | **Yes** (X4; brief 3, step 5, wall 11; the test writer's Laws.lean) |
| D197 | `nearestBits` beyond X2's decimals (Argon 3.1.2, 3.1.3) | **Test 12 holds it on its own** against MPFR's rounding of the same rational. It covers every binade from below `2⁻¹⁰⁷⁴` to `2¹⁰²⁴` at both signs, the midpoints (which round to even), both sides of the overflow threshold, and value order across signs. It stays a definition held by a test (D169); the gap was the test's coverage | **Yes** (brief 3, step 5, test 12) |
| D198 | The MPFR stub and B4's printout (Argon 4.1) | The stub sets binary64's exponent range and `mpfr_subnormalize`s before `mpfr_get_d`, and is checked at subnormal results. Test 13 prints the arguments at which glibc is not MPFR at that argument, apart from the count of items that differ | **Yes** (brief 3, step 5, tests 12 and 13; B4) |
| D199 | The floating-point check and the re-execution (Argon 5.1) | The check reads `(MXCSR & 0xFFC0) == 0x1F80`, and the sticky flags choose nothing. A process re-executes by `/proc/self/exe` unless its environment is already empty, which is what the re-execution makes. x87 is not read | **Yes** (A13; brief 3, step 9, test 8) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged: step 6's test 11 and the first whole day's bytes | The trace's `tick` rows, if a wall |
| O26 | `exp` and `log` at B5's walls | **Narrowed:** step 5 has no proof fork (D196). Open for B5's rates at step 6; test 12's own time is reported at step 5 | A twin (X3's pattern), if a rate is missed |

### What the next read should attack first

1. **D194's pathwise claim:** a run on which this design names a crossing that the committed text, run at the same scheduled times, does not. Also any lever left in the time, the collector's wait, a month's attempts, or the second host.
2. **D194's cost:** a source of items about a published day, written after the replay that published it, that is not a writer's fault. That is where the test would end early on an honest record.
3. **A published replay whose host was wrong.** Its rows are wrong, and a final "outgrew" named on them stands, because every later replay only ends the test. The premise is D1's two-host determinism, and the gap is noted, not acted on.
4. **D196:** an engine that is wrong and passes X4 as now stated, and a start for `exp`'s count at which the tail's bound fails.
5. **D197:** a `nearestBits` that passes the extended test and is not round-to-nearest-even.

### Committed criteria: reported, not edited

None needs a revision (D195). D190's draft, never committed, is withdrawn.

### Assumptions only the human can choose

None new.

### Owed

- **By the test writer (GPT):** the changes to `b1689bc` the report lists, beyond rounds 1, 3 and 4.
- **By step 7's and step 9's writers:** test 10 as now written, and test 8's two new cases.
- **By the advisor:**
  - this section read on a model other than GPT and Argon's last, D194 first;
  - **withdrawn:** round 4's owed change to `mmvault`'s reach and D190's review and commit;
  - **still owed:** the settled-funding collector, stored as `mmvault` stores its pulls (it now gates each replay's start), and the worst-case lead's certification for test 12.
- **By the next architect:** O22, O24 and O26 when their measurements come.

### Convergence

**Answered by derivation, and not yet read.** The record is re-derived from the criteria, not patched a fifth time. Its design changed, so the next round is due on another model. No open dispute would change what step 5 builds once its tests carry this round's list.

## The last pass, round 6: GPT's read of round 5, answered

Appended 2026-11-17 21:07 UTC (16:07 EST) by the Opus 5.5 architect, session "architect: the last pass, round 6". Review answered: `audit/reviews/2026-11-17-gpt-last-pass-r5.md`. Commits `52536d2` to the one that appends this. No market data read. Report: `data/builder/architect-last-pass-r6-report.md`, which holds the derivations, X5's statement and the test writers' lists.

### In plain words

- **A killed replay now counts for nothing,** and the next one reads the record as it then is. Round 5 had it reread the killed one's file lengths, the last piece of the deleted cut, and GPT showed that could name a crossing the committed text does not.
- **A late row from an honest venue can end the test early.** That cost stays, and is now said plainly. What a replay reads is fixed mechanically: an hourly timer from the first of the month, a pull of settled funding, then the attempt, reading the files as they are at that moment.
- **Every replay runs on two machines, and publishes only what both compute.** One faulty machine could otherwise have named a final verdict that nothing later could withdraw.
- **The rounding every `exp` and `log` result rests on is now proved correct for every input, not tested on samples** (law X5). Writing it found that the rounding gave +0 where IEEE gives −0, which the round-5 test would have failed on; the fix deletes a special case.
- **Two different versions of one vault fill now make CS2.3 "not judged",** as intended. The position chain alone let them through.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.** No criterion is edited, and the human has no new choice.

### Who has seen what

- GPT read round 5 at `a0f5c06`. Nobody has read this section or its commits.
- GPT's step 5 tests (`kernel2-step5`, `b1689bc`) predate rounds 1 to 6. The report lists this round's two changes to them.

### Agreed

- **GPT's acceptances of round 5:** the cash grid's removal, L1 and the midnight slice, the build identity, B4's full comparison, D198, D199, reading the record with no lag and no revision, and conservative stopping on a changed published prefix.
- **GPT's five points,** each conceded at its cause (D200 to D204).

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D200 | A killed attempt's reading (GPT 1) | **It produced nothing** (A13: nothing published before its result row), so the next attempt reads the files as they are when it starts, as the committed text at the same attempt times does. **Deleted:** the inheritance of the first attempt's lengths (round 5's remnant of the cut), the pilot sentence arguing for fixing what a run read, and L1's "the record's and the runner's to make so". Test 10's round-4 case no longer has a later replay abort on a row it holds | **Yes** (brief 4, step 7: wall 3, test 10; part B's L1 text) |
| D201 | Late honest data, and the capture (GPT 2) | **The early end is a cost an honest record can incur:** a row the venue served late, with every writer to its specification, ends the test before its day. The 887 s bounds no serving time. **The capture:** a timer fires at 12:00 UTC (07:00 EST) on the first and then hourly until the month's replay publishes or ends the test. Each firing pulls the settled funding (complete when every page is stored, the last under the cap, as `mmvault`'s); if the pull completed on the UTC day it began, the firing starts an attempt at once, whose row records the bytes it reads. The check is not narrowed: a late row of a coin not held moves the guard's funding too | **Yes** (brief 4, step 7: builds, wall 3, test 10; brief 3, the recorders) |
| D202 | A faulty host (GPT 3) | **Validate, not assume.** Every attempt runs on two hosts from one identity, and its rows are those both give. A disagreement is resolved on the same identity by the next host of a fixed list; where none agree, nothing is published and the runs go to the architect. A host fault is a wrong computation of a reading the comparator made, so it gets no new reading; a kill computed nothing, so it does. Round 5's "second host when the rows differ" is deleted. **Assumed:** two hosts that err alike. **Cost:** twice each replay's core-hours, and a second host reading the recorder's volume | **Yes** (brief 4, step 7: builds, wall 3, test 10; architecture 6.6) |
| D203 | X4's reliance on `nearestBits` (GPT 4) | **X5, a universal law:** `nearestBits` is IEEE 754's roundTiesToEven at every rational, stated over `Exact.decode` (nearest finite, ties to an even last bit, overflow at `(2 − 2⁻⁵³) 2¹⁰²³`, the sign `q`'s). X4 and X5 prove that the engine computes the stated function and rounds as IEEE does. On paper: each interval holds the true value. **Found:** `nearestBits` gave `+0` for a negative rational that rounds to zero, where IEEE and MPFR give `−0`, so round 5's test 12 would have failed. The case is deleted. Test 12's order sample is deleted, since X5 implies it | **Yes** (step 5: X5 in Laws.lean, its proof, `nearestBits`, test 12) |
| D204 | Two versions of one vault event (GPT 5) | **One fill, one item.** The reader merges identical lines, and the replay of given fills rejects a fill whose trade and order ids an earlier fill holds, as admission rejects a repeated print id (C2). CS2.3 is then "not judged": its fills fail their replay, as committed. No version is preferred | **Yes** (A13; brief 3, step 2, test 5; brief 4, step 1, wall 1, and step 7, wall 3, test 5) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged: step 6's test 11 | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged | The trace's `tick` rows, if a wall |
| O26 | `exp` and `log` at B5's walls | Open, unchanged: B5's rates at step 6 | A twin, if a rate is missed |

### What the next read should attack first

1. **D202:** a run on which resolving a host disagreement on the same identity names a crossing that the committed text, computed right at the same attempt times, does not; any lever in the host list.
2. **D201:** a lever left in the hourly firings, the same-day rule, or an outage repaired by hand.
3. **D203:** a binary64 rounding IEEE 754 forbids that X5 allows, or the reverse, at the subnormals, the overflow threshold and the sign of zero.
4. **D204:** two versions of one vault event that share no trade and order id and still both reach the chain.

### Committed criteria: reported, not edited

- **CS2.1's "Fails while the claim holds"** does not list the honest early end of D201. It can only remove a discovery. The report gives a sentence; the advisor's to pin, and I recommend it.
- **CS2.1 to CS2.3's "Passes while the claim is false"** do not list a computation two hosts got wrong alike (D202). It is the premise every judged number shares, as the build's sandbox is, and I recommend no revision.

### Assumptions only the human can choose

None new.

### Owed

- **By the test writer (GPT):** X5's statement in Laws.lean, and test 12's `−0` case with its order sample deleted (the report, item 4), beyond rounds 1, 3, 4 and 5.
- **By step 2's writer:** test 5's case of one fill's two versions, before its fix.
- **By step 7's writer:** test 10's killed attempt, capture and two-host cases, and test 5's case of two versions.
- **By the advisor:** this section read on a model other than GPT, D202 and D203 first; a list of at least two hosts that can read the recorder's volume; and the settled-funding collector, still owed, now run by the replay's timer as well as daily.
- **By the next architect:** O22, O24 and O26 when their measurements come.

### Convergence

**Answered at the causes, and not yet read.** Each of GPT's five points is conceded and answered at its cause, not patched. D202 and D203 change the design, so the next round is due on another model. No open dispute would change what step 5 builds once its tests carry this round's two items.

## The last pass, round 7: Argon's read of rounds 5 and 6, answered for steps 6 and 7

Appended 2026-11-18 22:06 UTC (17:06 EST) by the Opus 5.5 architect, session "architect: steps 6 and 7's specifications (round 7)". Review answered: `audit/reviews/2026-11-17-argon-web-last-pass-r5r6.md`. Commits `1210fd9` to the one that appends this. No market data read. Report: `data/builder/architect-r7-report.md`, which holds the derivations, CS2.1's note with its argument, the test writers' lists and the host list.

### In plain words

- **Each month's replay now reads the record once, at a fixed moment, and nothing that goes wrong afterwards changes what it read.** If a computer crashes, is killed, runs out of time or gives a wrong answer, the same reading is computed again on another computer. Round 6 had a killed run read the record afresh, so a kill could change what was read. A run that crashed on one computer and finished on another fell under two rules at once.
- **The two computers now compare everything a verdict rests on,** not just the engine's rows: the error a run stopped with, every verdict, the vault's fills, the matching and the report.
- **There must be at least three computers,** so that one fault resolves without a person. Agreement must come from two different machines, never the same machine twice.
- **The replay cannot run past what the funding pull covered.** A pull that began before midnight could otherwise let the replay run into a day whose last settlement it lacked, falsely ending the test.
- **The pull now reaches back to the last published day,** however long ago that was. Pulls have time limits, and no step waits on a run.
- **What a replay reads of a line is now pinned:** only the venue's message, never when or how it was fetched. One row fetched several times is then one row. Each file is read to the length recorded at the moment of reading, and only events inside the replay's span go in.
- **One vault fill is identified by its coin, trade and order,** and two copies are the same fill when every field the replay reads is equal.
- **The note to CS2.1 that an honest late row can end the test early is drafted,** with the argument that it can only remove a discovery.
- **Nothing needs a second clock, a deferred count or a stake that moves without a fill.** No criterion is edited, and the human has no new choice.

### Who has seen what

- Argon read rounds 5 and 6 at `57ce8b9`. Nobody has read this section or its commits.
- D205 reverses D200, which GPT's round-5 finding 1 produced. GPT has not seen why.

### Agreed

- **Argon's acceptances, standing:**
  - D195 to D199;
  - D200's closing of GPT's finding as a pathwise claim, now restated by D205;
  - D202's two-host architecture;
  - D203 and X5;
  - D204's detection;
  - the CS2.1 note as safe.
- **Argon's findings 1.1, 3.1, 3.2 and 4.1,** each conceded at its cause (D206 to D209). **Its finding 1.2,** conceded at a wider cause (D205).
- **Its finding 2.1** is step 5's, taken by the advisor (`audit/decisions.md`, 2026-11-17).
- **Its common modes** (the capture's own host, one volume, one build) are assumed, and wall 3 now says so.

### Settled by a derivation the reviewers have not seen

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D205 | A host that crashes or aborts, against one that disagrees (Argon 1.2.1 to 1.2.3); a killed attempt (D200, GPT's round-5 finding 1) | **One reading a month.** A timer captures the month's identity once, after a complete pull. Every failure to compute it is answered on it, by the next host of the list: a kill, a crash, a timeout, a host's refusal, a file not the identity's, or an output no other host gives. The identity computes to the same output at any later time, since the files are only appended to and it holds every length and hash. So waiting loses nothing, and reading again would let a failure choose the reading. The truncated rerun after an agreed abort is part of each run, at once, on the same bytes. Months publish in capture order. **Replaces** D200's "a killed attempt produced nothing" and D202's separate rule for faults. **GPT's construction** is now the honest late row of D201: the print appended after the capture is read by the next month. Its comparator was killed alike, so a kill chose its reading. The committed text, replayed once a month and computed right, is this design run for run | **Yes** (brief 4, step 7: builds, wall 3, test 10) |
| D206 | What two hosts compare (Argon 1.1.1 to 1.1.3) | **Everything a run computes from its identity:** the horizon, the engine's summary with its error and time, the truncated rerun, the report and trace, `confirm`, `guard`, `held`, CS2.3's chain, replay and matching, layer 2, the readers' counts and the report's text; not the host or its times. Runs that give no output are failures and agree on nothing. **The identity holds every file a run reads,** `mmvault`'s and the copy before 2026-11-01 included (A13: "every file the run reads" for "the market's every file") | **Yes** (brief 4, step 7, wall 3, test 10; brief 3, step 9, wall 2 and test 11; A13) |
| D207 | The capture (Argon 3.1.1 to 3.1.3) | **The horizon is the last midnight at or before both the pull's start and the recorder's last quote.** Each run reads the start from the pull's own `start` event. **The firing's pull covers every universe coin from the last published horizon,** and is killed at 30 minutes. **No firing waits on a run;** a run's timeout is the operator's, 7 days, and moves nothing (D205). **Deleted:** the same-day rule, its "starts none" case, and "a firing while one runs does nothing". The cap reads the clock the same-day rule read, and sets a midnight, never an event's time | **Yes** (brief 4, step 7: wall 3, test 10; `recorder/VAULT.md`, settled funding) |
| D208 | The reader (Argon 3.2.1 to 3.2.3) | **A quote, a trade and a funding row take nothing from their line's envelope.** Funding's `known` is `time + lag`, and a settlement is (coin, `time`, rate). A listing, whose source states no time, stays timed at the first copy that shows it. **Each file is read to the identity's length** (`mmrec cat <file> <length>`): whole lines only, a cut frame not read, the file counted as cut. **Only events in `[w_start, w_end)` are fed,** the rest counted. Files before the hour before `w_start` are not read | **Yes** (A3; `KERNEL.md` A18; brief 3, step 6, test 13 and step 7, test 8; `recorder/RECORDER.md`) |
| D209 | A vault fill's identity (Argon 4.1) | **(coin, `tid`, `oid`)**, and an item is the fields the replay reads, parsed (A18's placed decimals), nothing of the envelope or of unread fields. The coin adds nothing on the venue's data and keeps every identity coin-scoped. `mmvault`'s count used `tid` alone, which counted a self-trade's second fill as a duplicate; it now uses the same key | **Yes** (brief 3, step 2, test 5; A13; `recorder/VAULT.md`) |
| D210 | CS2.1's dated note (Argon 5) | **Drafted, with its argument** (the report, item 4). Against any procedure that agrees through the replay before the changed row and keeps every published day as shown, the end's rejections are a subset. Its finals were named by common replays, and its "earned" stands on a day that procedure keeps. So the 5% of any such reading holds | No (the advisor's to review and commit) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D205 | GPT's comparator (killed alike) against "replayed once a month, computed right" | Settled here by derivation; GPT has not read it | Step 7's timer and runner, if GPT's comparator is shown to be the committed text's |
| O22 | The recorder's reader inside 22,500 a second | Open, unchanged | Step 6's reader |
| O24 | The replica's own trace at a second's tick | Open, unchanged | The trace's `tick` rows, if a wall |
| O26 | `exp` and `log` at B5's walls | Open, unchanged | A twin, if a rate is missed |

### What the next read should attack first

1. **D205:**
   - a run on which the outcome depends on a failure of computation;
   - a reading the committed text makes that D205 never makes;
   - a lever in the capture's moment, the months' order, or the architect's power to rerun an identity.
2. **D207:** a due hour the pull can lack while the horizon is at or before its start; a pull whose completion a person can time.
3. **D206:** anything a verdict or the report's sentences rest on outside the compared output; a part of the output two right runs give differently.
4. **D208:** an event of the horizon in a file the reader skips; a cut at which two hosts' `mmrec cat` can differ.

### Committed criteria: reported, not edited

- **CS2.1's "Fails while the claim holds"** does not list the honest early end. The note is drafted in the report for the advisor, with its argument. Both of the round's readers called it safe.
- **CS2.1 to CS2.3's "Passes while the claim is false"** still do not list two hosts erring alike. As round 6 said, no revision is recommended.

### Assumptions only the human can choose

None new.

### Owed

- **By the advisor:**
  - a host list of at least three distinct x86-64 machines (the report, item 2c);
  - `mmvault`'s fill identity, with VAULT.md's test 10;
  - `mmrec cat`'s length, with RECORDER.md's test 4 case;
  - the settled-funding collector as VAULT.md now specifies;
  - CS2.1's note, reviewed and committed;
  - this section read on GPT first (D205), then Argon.
- **By step 2's writer:** test 5's new cases, before the fix.
- **By steps 6, 7 and 9's writers:** brief 3's step 6 test 13, step 7 test 8 and step 9 test 11; brief 4's step 7 tests 5 and 10 as rewritten.
- **By the next architect:** O22, O24 and O26 when their measurements come.

### Convergence

**Answered at the causes, and not yet read.** Argon's points are specifications, each conceded. D205 changes the design by reversing a point GPT's own finding produced, so the next round is due on GPT. No open dispute would change what step 5 builds. Steps 6 and 7 wait on D205's read.


## The last pass, round 8: steps 6 and 7 re-derived, closed-hour seekable packs, kernel v2 open questions, and test 12 hardening

Appended 2026-11-19 03:40 UTC (2026-11-18 22:40 EST) by the Gemini 4 Neon architect (`CLAUDE.md`, `audit/decisions.md` `81a47aa`). Reviews answered: `audit/reviews/2026-11-18-neon-round7.md`, `audit/reviews/2026-11-18-neon-efficiency-recorder.md`, `audit/reviews/2026-11-18-neon-efficiency-kernel2.md`, `audit/reviews/2026-11-18-neon-efficiency-study1.md`, `audit/reviews/2026-11-18-neon-x4-inputs.md`, and `data/builder/queued-after-step4.md` items 10 and 12. Commits `2ad4b33` (item 1), `e7fb8d7` (item 2), `6eed7d8` (item 3), `3d7992e` (item 4), plus this ledger commit. No market data from 2026-11-01 on, no `data/holdout/`, and no token/key files read. Report: `data/builder/architect-r8-report.md`.

### In plain words

- **Round 7's five disputes are conceded and re-derived at their causes (D211 to D215):**
  - The monthly settled-funding pull now always starts from `w_start` (with no `endTime`, weight-paced at ≤ 750 weight/min, 90-minute timeout, staged atomically), severing Step 1 from Step 2's publication latency and catching both >30-day-late unheld rows and historical restatements.
  - The host wall clock is **deleted** from the horizon formula: the horizon uses strictly the venue clock minus the `CLOCK_BOOTTIME` capture duration and a fixed 1-hour indexing margin (`floor_midnight(last_quote_universe − D_capture − 1 h)`), making it invariant to arbitrary host clock skew and closing `00:00` zero-margin retries.
  - Both `mmvault` and `mmvault funding` stage each pull atomically into `.tmp/` and rename only on completion; Step 1 holds a single-instance lock (`Forbid`) and reuses verified closed-file hashes (cutting capture hashing from 40–100 min to ~1–2 s while strengthening bitrot detection).
  - Transient execution failures (crash, kill, OOM, timeout, stream drop) retry automatically without consuming disagreement slots (lone outputs sealed hash-only); computational disagreements resolve deterministically by 2-of-3 across distinct hosts (retiring the lone faulty host), and a 3-way split halts the study unconditionally (zero post-outcome architect lever).
  - Step 2 runs on `RunInput_k = (Capture_k, State_{k-1})`, putting every runtime input (registration file, prior settled state + published report/trace, all `mmvault` files `fills`/`funding`/`fees`/[`orders`], hourly fee copy, `D_capture`) and every decision (prefix check, exact cutoff midnight $T^*$, `"Earned"` withdrawal, carry-forward of prior final `"Outgrew"`/CS2.2/CS2.3, Layer-1 fee-schedule witness halt) inside the two-host byte-for-byte compared output.
  - `mmrec cat` specifies stdin `-`, exact-length short-read looping, full `ZSTD_decompressStream` draining (chunk-size invariant across local files and pipes), and `L = 0` / partial-checksum cuts; forward `listings` initialize from the latest copy with `recv ≤ w_start`; D208 extends placed-decimal equality; CS2.1's drafted note defines $T^*$ unambiguously on the matched `account` row and states survival of prior final `"Outgrew"`/CS2.2/CS2.3 vs. withdrawal of later non-final `"Earned"`.
- **Replay size solved cleanly (D216):** Study 2 forward replays read only `l2Book-fast` and `trades` (`l2Book`, `allDexsAssetCtxs`, `events` excluded unconditionally; `last_quote_universe` scoped to the 17 universe coins). Live `mmrec` files stay untouched. Strictly post-release and after an hour file is provably closed, two distinct hosts run frozen `mm2 pack` (inside the registered Nix derivation, A13) to pack it 1-to-1 off the `ws` PVC into a standard Zstd Seekable Format `.packed.zst` (one continuous frame per coin + `_other` + RFC 8878 skippable `_order` for byte-exact `mm2 unpack-verify` + skippable coin-index metadata + EOF seek table). Month-24 replay reads drop from ~1.2–1.5 TB (~21–26 TB uncompressed) to **~55–78 GB (~1.0 TB uncompressed)**, fitting B5's 24-hour wall and cutting `ws` PVC disk reads ~15×.
- **Float windows and kernel v2 efficiency settled (D217 to D219):** `sum`, `mean`, and `std` move from stage 6's drifting running-subtraction sums to a **two-stack SWAG queue with Chan's parallel variance formula** over `NumOps α` (zero subtractions, zero post-eviction pollution, centered `M2`, compact memory), splitting B4 cleanly with zero tolerances (non-`sum`/`mean`/`std` programs bit-identical to stage 6 + MPFR; full C6.4 corpus bit-identical to B4's v2 reference = stage 6 + MPFR + SWAG/Chan). Parameter/identifier names are verified already restricted to `[a-z][a-z0-9_]{0,31}` in `Syntax.lean` (regression tests added). **Step 5a** is planned after Step 5 merges (rolling windows, mark reuse + `quotes` FIFO + `fireNoRec`, pending binary min-heap, streaming `mm2 finish`, identifier tests; zero frozen law statement changes; before/after speedups measured). Fast `exp`/`log` is answered (not planned; `O26` open pending `x4_local` / trigger timing; 4-theorem algebraic `@[csimp]` proof sketch given).
- **Test 12 inputs and hardening (D220):** `emit_x4_draws` added to `audit/program/arithmetic.py.txt` (verified 1,000,000 draws bit-identical on the 200,000 prefix), and all seven loopholes from `2026-11-18-neon-x4-inputs.md` specified in Brief 3 Step 5 Test 12.
- **Stop-condition check:** Nothing requires a second clock (the host wall clock is deleted from D207), a deferred count, or a stake that moves without a fill. No committed criterion in `audit/criteria.md` was edited.

### Who has seen what

- No adversarial reviewer (fresh Claude Opus session or GPT) has seen this round yet. Both are due to review D211–D220 adversarially before Step 5a, Step 6, and Step 7 proceed.

### Agreed

- **Standing from rounds 6–7:** D205's core reversal of D200 ("one reading a month", subject to GPT reading the reversal); D206's full-output two-host comparison and ≥ 3 distinct hosts; D207's deletion of the same-day rule; D208's message-only event rule and `[w_start, w_end)` filtering; D209's `(coin, tid, oid)` vault fill identity; D210's core statistical safety (cannot add a false discovery relative to published-day-preserving procedures); Argon's common-mode assumptions.

### Settled by derivation in round 8 (not yet adversarially reviewed)

| | Question | Settled by | Changes what is built |
|---|---|---|---|
| D211 | D205 disputes: pull coupled to publication, capture non-atomicity, host exhaustion lever, state-machine deadlock (`neon-round7` 1.1–1.3, 2.2) | Pull from constant `w_start` (decoupled from Step 2; catches >30 d late unheld rows & restatements); single-instance Step 1 capture lock (`Forbid`); atomic pull staging (`.tmp/` + `fsync` + rename on completion) in `mmvault` and `mmvault funding`; closed-file hash reuse at capture (size check + reuse prior verified hash; ~1–2 s capture, stronger bitrot detection); transient execution failures auto-retried without burning disagreement slots (lone outputs sealed hash-only); 2-of-3 settlement across distinct machines retiring lone faulty host, and unconditional `halt_non_deterministic` on 3-way split (zero architect lever); Step 2 runs `"earliest capture not yet settled"` with explicit timer stop on `ended_study` or `halt_*` | **Yes** (brief 4 step 7, `recorder/VAULT.md`, brief 3 recorders) |
| D212 | D207 positive host clock skew & `00:00` zero-margin retry (`neon-round7` 2.1) | **Host wall clock deleted from horizon.** `mmvault funding` omits `endTime` and paces by weight (≤ 750 weight/min, 90-min kill). Capture measures `D_capture` via `CLOCK_BOOTTIME` (immune to wall jumps & S3 suspend) from pull start until strictly after snapshotting open `l2Book-fast` length. Horizon `T = min(floor_midnight(last_quote_universe − D_capture − 3,600,000 ms), w_start + 730 d)` uses strictly one clock (the venue's), proving `t_0 ≥ T + 1 h > H + late` for every due hour regardless of host wall-clock offset | **Yes** (brief 4 step 7, `recorder/VAULT.md`, brief 3 recorders) |
| D213 | D206 prefix check, verdicts, unpinned inputs & fill fallback outside two-host comparison (`neon-round7` 3.1–3.2) | Step 2 forms `RunInput_k = (Capture_k, State_{k-1})` once Month `k−1` settles, pinning registration file, `State_{k-1}` (state JSON + prior published report & trace), all `mmvault` files (`fills`/`funding`/`fees`/[`orders`]), hourly fee copy, and `D_capture`. Prefix check, exact cutoff $T^*$, `"Earned"` withdrawal, carry-forward of prior `"Outgrew"`/CS2.2/CS2.3, and Layer-1 fee-schedule witness check (`halt_fee_witness`) all execute inside `study2 forward`'s two-host compared output; each host records `output_sha256` in the ledger; unchainable millisecond fills fall back to `(tid, oid)` ascending | **Yes** (brief 4 step 7, brief 3 step 9 & recorders, `kernel-v2.md` A13) |
| D214 | D208 `mmrec cat` flush-cut/pipe divergence, edge cuts, freeze-to-midnight `listings`, skip scope, decimals (`neon-round7` 4.1–4.2) | `mmrec cat` supports `-` stdin, exact-length short-read loop, complete `ZSTD_decompressStream` drain invariant to chunk size, `L = 0` and 1–3 byte partial-checksum cuts as `cut` (exit 0); zero-TOCTOU in-memory per-file/frame SHA-256 verification before feeding; registration pins 17 coin names and `study2 forward` initializes coin rules from latest pinned `listings` copy with `recv ≤ w_start`; `w_start − 24 h` skip scoped to `l2Book-fast`/`trades` only; placed-decimal equality extended across D208 | **Yes** (`recorder/RECORDER.md` interface & test 4, `KERNEL.md` A18, brief 3 steps 6–7, brief 4 steps 6–7) |
| D215 | D210 CS2.1 drafted note contradiction & midnight boundary (`neon-round7` 5.1–5.2) | Unambiguous cutoff $T^*$ = last published midnight whose `day` coin rows, `account` row, and all prior report/trace rows match byte-for-byte (or `w_start` if day 1 differs), so a late `23:59:59.995` quote differing first at midnight `coin`/`account` row ends at `T − 1 d`. Drafted CS2.1 note explicitly states prior final `"Outgrew"` and once-judged CS2.2/CS2.3 stand while later non-final `"Earned"` is withdrawn, and replaces `"would name every verdict"` with `"would confirm every rung this end leaves confirmed"` | **Yes (minor)** (drafted CS2.1 note for advisor review/commit; brief 4 step 7 prefix cutoff & test 10) |
| D216 | Replay size (1.2 TB / ~21 TB uncompressed at Month 24), forward channels & 17-coin extract (`neon-round7` 6.1, `neon-efficiency-recorder` finding 1) | Forward replays read only `l2Book-fast` and `trades` (`l2Book`, `allDexsAssetCtxs`, `events` excluded; `last_quote_universe` scoped to 17 universe coins). Live `mmrec` unchanged. Post-release closed raw files packed 1-to-1 off `ws` PVC by two distinct hosts running frozen `mm2 pack` (A13) into `.packed.zst` (1 frame/coin + `_other` + skippable `_order` `0x184D2A5D` for lossless `mm2 unpack-verify` + skippable coin-index `0x184D2A5F` + EOF seek table `0x184D2A5E`). `Capture_k` pins per-frame hashes for the 17 coins + `_other`; replay asserts coin-frame purity; open/unpacked files read raw. Cuts Month-24 replay read to ~55–78 GB (~1.0 TB uncompressed), 2-year `ws` reads ~15×, capture hashing to ~1–2 s | **Yes** (brief 3 step 6 test 14 & step 9, brief 4 step 7, `recorder/RECORDER.md`, `KERNEL.md` A18, `kernel-v2.md` A13) |
| D217 | Float window (`sum`, `mean`, `std`) semantics & B4 split (`neon-efficiency-study1` finding 1) | Two-stack SWAG queue + Chan's parallel variance formula over `NumOps α` (zero subtractions, zero post-eviction pollution, centered `M2`, overflow-safe `mean` fallback on non-finite `μ_b − μ_a`, compact memory ~160–427 MB at max window × 17 coins). B4 stays zero-tolerance: non-`sum`/`mean`/`std` C6.4 programs bit-identical to stage 6 + MPFR; full C6.4 corpus bit-identical to B4's v2 reference (stage 6 + MPFR + SWAG/Chan), plus direct exact-oracle tests on extreme/eviction cases | **Yes** (`KERNEL.md` A17, `kernel-v2.md` A2 & B4, brief 3 steps 4 & 5a) |
| D218 | Parameter name restriction (`neon-efficiency-study1` finding 2) | Verified already enforced in `KERNEL.md` A17 and `kernel2-step5:Syntax.lean` (`validName`: `[a-z][a-z0-9_]{0,31}` across all 5 name kinds); explicit `E_PARSE` regression test added in Step 5a (v1 Rust `dsl.rs` note stays for any future v1 fork) | **Yes (test only)** (brief 3 step 5a test 5) |
| D219 | Kernel v2 efficiency build step & fast `exp`/`log` (`neon-efficiency-kernel2` findings 1, 3, 6, 8 & 2) | Planned **Step 5a** (after Step 5 merges, before Step 6): rolling windows (SWAG/Chan + ring buffer + circular monotone deque + linear `Mach.step`), `marks` reuse + `quotes` FIFO + `fireNoRec`, pending binary min-heap, streaming `mm2 finish`, identifier tests; zero frozen law statement changes; before/after speedups & peak RSS measured. Fast `exp`/`log` answered only (not planned; `O26` open pending `x4_local`/trigger timing; 4-theorem algebraic `@[csimp]` proof sketch for X4) | **Yes** (brief 3 step 5a) |
| D220 | Test 12 inputs & seven loopholes (`neon-x4-inputs`) | Added `_x4_draw_pairs` + `emit_x4_draws` to `audit/program/arithmetic.py.txt` (`--emit-x4-draws OUT_DIR`, 1,000,000 draws verified bit-identical on 200k prefix); specified all seven loophole hardenings in Brief 3 Step 5 Test 12 (`x4_local.ml`, `x4-hosts.sh`, `x4-specials.lean`, `x4-counts.lean`, `x4_mpfr_stubs.c`) | **Yes** (`audit/program/arithmetic.py.txt`, brief 3 step 5 test 12) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D205 / D211–D216 | Round 7–8 Study 2 capture, single-clock horizon, `RunInput_k`, 2-of-3 halt, and closed-hour `.packed.zst` | Settled by derivation; awaiting fresh Claude Opus and GPT adversarial review (GPT has also not yet read D205's reversal of D200) | **Yes**, if a reviewer breaks D211–D216 (Steps 6, 7, 9, `RECORDER.md`, `VAULT.md`) |
| D217 / D219 | SWAG + Chan float windows, B4 v2 reference split, and Step 5a plan | Settled by derivation; awaiting fresh Claude Opus and GPT adversarial review | **Yes**, if a reviewer finds a flaw in SWAG/Chan or Step 5a |
| O22 | The recorder's reader (now with `.packed.zst`) inside 22,500 quotes/s | Open until Step 6's test 11 measurement (greatly eased by D216) | Step 6's reader, if missed |
| O24 | The replica's own trace at a 1-second tick (~3–5 GB zstd at Month 24) | Open until Step 6's test 11 measurement | Trace storage / compression, if a wall |
| O26 | `exp` and `log` wall time on `x4_local` and Study 2's trigger | Open until Step 5's `x4_local` and Step 3's trigger run; D219 gives the 4-theorem algebraic proof sketch if needed | A fast `@[csimp]` twin, only if a wall is hit |

### Committed criteria: reported, not edited

- **CS2.1's *Fails while the claim holds*:** revised drafted note is in `data/builder/architect-r8-report.md` §1e (fixing Finding 5.1's survival/withdrawal wording and Finding 5.2's midnight `coin`/`account` boundary). Ready for the advisor's two-reviewer check and commit; `audit/criteria.md` untouched.
- **CS2.1 to CS2.3's *Passes while the claim is false*:** two hosts erring alike remains an assumed premise (no revision recommended).

### Assumptions only the human can choose

None new. (Disk volume for 2-year retention and off-`ws` `.packed.zst` storage remains the existing deferred choice of `architecture.md` 6.8; Months 1–3 of `.packed.zst` take ~65–110 GB on an existing replay host.)

### Owed

- **By the adversarial reviewers (fresh Claude Opus session and GPT):** attack D211–D220 (and GPT on D205's reversal of D200), starting with the targets below.
- **By the advisor:**
  - host list of at least three distinct x86-64 machines (with packed Month-24 reads of ~55–78 GB, even the laptop at 11 MB/s streams in ~1.4–2.0 h);
  - `mmrec cat` (`-` stdin, short-read loop, full `ZSTD_decompressStream` drain, `L = 0` & partial-checksum cuts) with `RECORDER.md` test 4 additions;
  - `mmvault` atomic pull staging + fill identity `(coin, tid, oid)` with `VAULT.md` tests 6 & 10;
  - `mmvault funding` (no `endTime`, ≤ 750 weight/min pacing, `--from-ms = w_start`, 90-min timeout, atomic staging, `CLOCK_BOOTTIME` `elapsed_ms`) with `VAULT.md` settled-funding tests 1–4;
  - CS2.1's revised drafted note, reviewed by two fresh reviewers and committed alone;
  - test 12's input bundle generated from `arithmetic.py.txt --emit-x4-draws`, pinned nixpkgs glibc + `GLIBC_TUNABLES`, CORE-MATH `1851882b` conversion, `boundaries.txt`, `manifest.json`, and root `SHA256SUMS` hash;
  - B4's v2 reference run (combining D198's MPFR `exp`/`log` and D217's SWAG + Chan `Win.sums` in one queued multi-host run, once Step 5a's design converges).
- **By the test writers:**
  - Step 5 test 12 (hardening all 7 loopholes in `x4_local.ml`, `x4-hosts.sh`, `x4-specials.lean`, `x4-counts.lean`, `x4_mpfr_stubs.c`);
  - Step 5a (all 7 test items in `briefs/3-kernel-v2.md`);
  - Steps 6, 7, and 9 of brief 3 (Step 6 tests 13–14, Step 7 test 8, Step 9 test 11) and Steps 6–7 of brief 4 (Step 6 listings init test, Step 7 tests 5 and 10).

### What the next reviewers should attack first

1. **D212 (single-clock horizon `last_quote_universe − D_capture − 1 h`):** look for a venue/recorder scenario where `last_quote_universe` exceeds capture end $t_2$ (e.g., an out-of-order future-stamped quote, or `CLOCK_BOOTTIME` drift/wrap/VM pause), or where a dead recorder loses a valid last day unnecessarily, or where `mmvault funding` without `endTime` hits an unexpected API cap/default range.
2. **D211 (pull from `w_start`, atomic staging, closed-file hash reuse, 2-of-3 halt):** look for a timing attack in the 90-minute Month-24 pull (weight contention with `mmrec`/`mmvault`/429 storms), a crash window between `mmvault funding` atomic rename and `Capture_k` commit, a subtle interaction when a file was open (`cut`) at Month `m−1` and closed at Month `m`, or any remaining post-outcome discretion in replacing permanently dead hardware during a 2-of-3 tie.
3. **D213 (`RunInput_k = (Capture_k, State_{k-1})`):** look for any file still opened by `study2 forward` outside `RunInput_k`, any difference in how two hosts read `State_{k-1}`'s compressed report/trace, or any gap in `halt_fee_witness` or `no_op`/`ended_study` state transitions.
4. **D216 (closed-hour `.packed.zst`):** look for a line-routing edge case in `l2Book-fast`/`trades` (`_other`, unicode/escaped `"coin"`, empty/mixed arrays), a race in the provably-closed condition on `mmrec` crash/restart, a holdout leak path if `mm2 pack` sees a file spanning a protected-window boundary (e.g. a quote at `2027-01-31 00:00:01` inside `20270130/23` or vice versa!), or a flaw in `Capture_k`'s per-frame hash pinning vs. full-pack verification.
5. **D217 (SWAG + Chan float windows & B4 split):** look for NaN/overflow/signed-zero edge cases in `combine` (especially `δ = μ_b − μ_a` overflow fallback, subnormal underflow in `m2`, `k_a * w`, or `frontGoodLen` off-by-one when `none` is pushed at index 0 or `n`), phase-dependence implications of the `front`/`back` split for L3/N1/determinism, or any hole in the two-part B4 comparison.
6. **D220 (`emit_x4_draws` & test 12 hardening):** look for any remaining loophole in the 7 hardenings that still lets a wrong `exp`/`log`/`nearestBits` pass test 12, or a portability/reproducibility pitfall in `GLIBC_TUNABLES` verification on `x4-hosts.sh`.

### Convergence

**Re-derived at every cause; not yet read by adversarial reviewers.** Every round 7 dispute, the replay sizing problem, kernel v2's window semantics and efficiency step, and test 12's inputs and loopholes are settled cleanly with zero patches and zero second clocks. Adversarial review by a fresh Claude Opus session and GPT is required before Step 5a, Step 6, and Step 7 proceed (and before Step 5's test 12 hardening is finalized).


## The last pass, round 9: Opus's read of round 8 answered — dual-channel coverage horizon, packing equivalence, refusal states, funding-pull human choice, and CS2.2/SWAG text fixes

Appended 2026-11-20 05:30 UTC (00:30 EST) by Gemini 4 Neon acting as the architect (`CLAUDE.md`, Orchestration; the human, 2026-11-19). Review answered: `audit/reviews/2026-11-20-opus-round8.md` (fresh Claude Opus 5.5 at maximum effort, not converged). Commits `f4aff27`, `051194d`, `ed8cd59`, `be23a7a`, and the one that appends this. No market data from 2026-11-01 on, no `data/holdout/`, no token/key files read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r9-report.md`.

### In plain words

- **D212's inferred-clock horizon is deleted and re-derived from capture coverage (D221).** Opus broke D212 four ways (a wild future quote, a stopped recorder with growing `D_capture`, unbounded/multi-boot `D_capture`, and a short `< 500` funding page). `T = min(T_raw, w_start + 730 d)` is now read directly from `Capture_k`: the largest UTC midnight `T` whose bounded 24-hour witness window `[T + 1 h, T + 25 h)` is covered by **every** still-listed universe coin in `settled/funding` (plus a pre-delisting coverage check for delisted coins) and at least `⌈|U(T)|/2⌉` still-listed coins in `l2Book-fast`. `D_capture` and `CLOCK_BOOTTIME` are gone; `T_k ≥ T_{k−1}` holds by construction; a single wild quote, a short page, a quiet coin like `TON`, or a delisting cannot break it.
- **Packing is simplified and made raw ≡ packed by construction (D222–D223).** Host-clock `<run>` ids no longer declare a file closed: only cleanly stream-ended zstd files (valid xxHash32 + exact EOF) are packed (`raw_cut` deleted; cut files stay raw). One shared JSON routing function (`Coin_route.classify_line`) skips non-universe lines unread in raw mode too, `_order` restores exact A3 tie order whenever `_other` is non-empty, `mm2 unpack-verify` checks purity on every frame `0..K`, and Step 1 packs cleanly closed hours before `Capture_k` (never flipping a previously published closed file from raw to packed).
- **Agreed refusals stop silently stalling the study, and windows/environment are pinned (D224–D225).** Deterministic refusals (`E_HASH`, `E_HEADER`, `R_PURITY`, `R_MALFORMED_FRAME`, `R_HORIZON_REGRESSION`, `R_PROTECTED`, `R_WINDOWS_INVALID`) participate in 2-of-3 settlement and transition to `halt_refused(code)` or `halt_storage_corrupt` (stopping the monthly timer permanently; Step 1 closed-file size mismatches likewise record `halt_storage_corrupt`). `Capture_k` pins `protected_windows_sha256` (stale host builds exit operationally as `R_HOST_WINDOWS_MISMATCH` without emitting a ballot); `mm2`/`study2` ban `localtime()`/`/etc/localtime` and host CPU-count dependence completely.
- **Pulling funding from `w_start` reduces to a plain human choice (D226).** Fetch-once per `(coin, hour)` + gap backfill (Option 1, literal `e691341`, recommended) closes round 7 Findings 1.1 and 2.2, keeps Ville's 5% bound, cuts Month-24 pulls from ~39 min to ~30 s, and survives venue precision changes — at the cost of not seeing retroactive corrections to already-fetched rates. Option 2 (`--from-ms = w_start`, current default until the human picks) catches retroactive rate corrections at the cost of ending the whole study at Day 1 on any benign precision change.
- **CS2.2 revision drafted and SWAG/B4 text fixed (D227–D228).** CS2.2 gets its own drafted dated revision (reported, never edited in `audit/criteria.md`); D217's false $O(1)$-ULP phase claim is corrected (defects 1–2 fixed, not defect 3; zero Study 2 outcome impact); `KERNEL.md` A17 now holds the complete bit-exact SWAG + Chan spec so a **different model** than Sonnet builds B4's v2 reference from A17 alone without reading `Eval.lean`; Step 5a Test 2 has zero tolerances and exact verified 64-bit hex words.

### Who has seen what

- Fresh Claude Opus 5.5 (maximum effort) reviewed round 8 (`cc984da`, `audit/reviews/2026-11-20-opus-round8.md`).
- Neither GPT nor Opus has read round 9 (`f4aff27` through this commit). GPT reads round 9 next (and has not yet reviewed D205's reversal of D200 or D211–D228).

### Agreed (accepted by Opus in round 8)

- **D211 (parts):** atomic staging (`mmvault` & `mmvault funding`, plus destination directory `fsync` in round 9), single-instance Step 1 capture lock, closed-file hash reuse for stream-ended files, 2-of-3 settlement with sealed lone ballots (zero post-outcome lever; common-mode fault stays assumed), and open-at-`m−1` → closed-at-`m` re-hashing.
- **D213 (parts):** completeness of compared outputs for verdicts, in-memory hash verification before decode, `(tid, oid)` fallback for unchainable millisecond fills.
- **D214:** `mmrec cat` drain/short-read/edge-cut spec, listings initialization from latest copy `≤ w_start`, placed-decimal equality across D208.
- **D215 (parts):** exact cutoff `T*` (last matching `account` row), survival of prior final `"Outgrew"`/CS2.2/CS2.3 vs. withdrawal of later non-final `"Earned"` adding no discovery against first reading (premise now holds under D221).
- **D216 (parts):** forward channels `l2Book-fast` + `trades` only, 1-to-1 `.packed.zst` off `ws` PVC, reconstruction via `_order`, per-frame pins from `Capture_k`.
- **D217 (parts):** SWAG + Chan fixes Stage 6 defects 1 and 2, is specified to the bit, cannot produce `NaN` in `m2`, has exact `frontGoodLen` boundaries, and preserves `L3` and `N1`.
- **D218:** `validName` identifier restriction verified in `Syntax.lean` + regression test.
- **D219:** Step 5a's four efficiency builds and unchanged frozen laws; fast `exp`/`log` proof sketch (`O26` open).
- **D220:** `emit_x4_draws` and all seven Test 12 hardenings (Opus found no eighth loophole; N7.1 peak-size bands and N7.2 linked engine store-path check added in round 9).

### Settled by derivation in round 9 (not yet reviewed by GPT or Opus)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D221 | Horizon re-derived from capture coverage (replaces D212; Opus F1.1–F1.4, F6.2, N1.1, N2.1) | `T = min(T_raw, w_start + 730 d)` where `T_raw` is the largest UTC midnight `≥ w_start` with `U(T) ≠ ∅`, every `c ∈ U(T)` having a valid `settled/funding` row in `[T + 1 h, T + 25 h)`, every delisted `c` (`t_prev_listed > w_start`) having a row in `[max(w_start, t_prev_listed − 24 h), t_delist)`, and `≥ ⌈|U(T)|/2⌉` coins in `U(T)` having a valid non-crossed two-sided `l2Book-fast` quote in `[T + 1 h, T + 25 h)`. Deletes `D_capture`, `last_quote_universe`, and `CLOCK_BOOTTIME`. Provably monotone (`T_k ≥ T_{k−1}`); `T_k == T_{k−1}` runs prefix check → `no_op` or `end_study`; `T_k < T_{k−1}` refuses `R_HORIZON_REGRESSION` (never a prefix divergence). `VAULT.md` adds destination directory `fsync` after rename | **Yes** (`briefs/4-study-2.md` step 7, `briefs/3-kernel-v2.md` step 9, `kernel-v2.md` A13, `architecture.md` 6.6, `recorder/VAULT.md`) |
| D222 | Packing closed condition & safety (Opus F4.1, N4.1, N4.2) | Deleted host-clock `<run'> > <run>` clause (b) and `raw_cut` completely: a raw file is provably closed iff its zstd stream ended cleanly (valid xxHash32 + exact EOF; `mm2 pack` refuses truncated/open files with `R_UNCLOSED`; cut files stay raw). `mm2 pack`'s `R_PROTECTED` emits code and file path only (no line/timestamp/coin/count). Two-host re-packing of a lost `.packed.zst` from the hash-verified raw file on `ws` counts as a byte-identical mirror | **Yes** (`recorder/RECORDER.md`, `KERNEL.md` A18, `kernel-v2.md` A13, `briefs/3-kernel-v2.md` step 6 test 14 & step 9, `briefs/4-study-2.md` step 7) |
| D223 | Raw ≡ packed equivalence by construction + no published switch (Opus F4.2) | Single shared RFC 8259 routing function `Coin_route.classify_line` skips non-universe lines unread in raw mode too; when `_other` is non-empty, `Capture_k` pins `_order` and packed reading restores exact raw line indices for A3 ties; `mm2 unpack-verify` verifies purity on every frame `0..K` (not just read frames); Step 1 two-host packs cleanly closed hours before `Capture_k` and preserves prior published closed hours' pinned representation | **Yes** (`recorder/RECORDER.md`, `KERNEL.md` A18, `kernel-v2.md` A13, `briefs/3-kernel-v2.md` step 6 test 14 & step 9, `briefs/4-study-2.md` step 7) |
| D224 | Agreed refusals & Step 1 corruption state (Opus F2.1) | 3-way attempt classification: transient/host-local no-ballot (`E_FPENV`, `R_HOST_WINDOWS_MISMATCH`, crashes/timeouts) vs. deterministic refusal ballot (`E_HASH`, `E_HEADER`, `R_PURITY`, `R_MALFORMED_FRAME`, `R_HORIZON_REGRESSION`, `R_PROTECTED`, `R_WINDOWS_INVALID`) vs. normal output ballot. Two-host agreed refusal settles as `halt_storage_corrupt` (`E_HASH`) or `halt_refused(code)` and stops the monthly timer permanently; Step 1 `stat(f).size != L_prev` likewise records `halt_storage_corrupt` and stops the timer | **Yes** (`briefs/4-study-2.md` step 7) |
| D225 | Pinned protected windows & host environment (Opus F3.1, F3.2, N3.1) | `Capture_k` pins `protected_windows_sha256`; Step 1 waits until every date the replay reads is released; `study2 forward` asserts `self.compiled_windows_sha256 == Capture_k.protected_windows_sha256` on startup (`R_HOST_WINDOWS_MISMATCH` operational exit if stale binary, no ballot/retirement/halt). `mm2`/`study2` keep A13 empty-env re-exec, ban `localtime()`/`/etc/localtime` (pure UTC integer calendar math), enforce CPU-count-independent execution, and test `TZ`/`LC_ALL`/`OCAMLRUNPARAM=R`/`taskset` byte-identity. Failed-pull list from pinned `settled/events` enters compared output | **Yes** (`kernel-v2.md` A13, `briefs/3-kernel-v2.md` step 9 tests 8 & 11, `briefs/4-study-2.md` steps 6 & 7) |
| D226 | Settled-funding pull survival cost & pending human choice (Opus F2.2, N2.2) | Priced full-history precision-change exposure of `--from-ms = w_start` (Option 2, current spec default until human picks) and derived Option 1 (fetch-once per `(coin, hour)` + contiguous gap backfill, literal `e691341`, closing Round 7 F1.1 & F2.2, keeping 5% bound, ~30 s Month-24 pull, surviving precision changes at the cost of keeping first readings of restated rates — architect's recommendation). Daily `00:17 UTC (19:17 EST)` `settled` job and monthly timer share one single-instance `settled` lock | **Yes, once human chooses** (`recorder/VAULT.md`, `briefs/4-study-2.md` step 7) |
| D227 | Drafted dated revision for CS2.2 (Opus F6.1) | Drafted CS2.2's own dated revision in `data/builder/architect-r9-report.md` §4a: a prefix-divergence early end at `T*` counts as the record stopping at `T*` for CS2.2, superseding *"goes on to that day whatever CS2.1 has named by then"* before day 212 (conservative; reviewed beside D215's CS2.1 revision by two fresh reviewers before advisor commits; `audit/criteria.md` untouched) | Advisor criteria commit only |
| D228 | D217 SWAG + Chan text, independent B4 v2 reference, zero-tolerance Test 2, & Test 12 cleanups (Opus F5.1, F5.2, N5.1, N5.2, N7.1, N7.2) | Retracted false $O(1)$-ULP phase claim (SWAG + Chan fixes Stage 6 defects 1–2, not defect 3; real reason against exactness is `NumOps α` parametricity; zero Study 2 outcome depends on split phase); documented `mean([-0.0, -0.0]) = +0.0`; put complete bit-exact SWAG + Chan equations in `KERNEL.md` A17; mandated a **different model** than Sonnet writes B4 v2 reference windows from A17 alone without reading `Eval.lean` (in its own multi-host run after `d91e14b`); replaced Step 5a Test 2 tolerances with exact dyadic oracle + verified 64-bit hex words; unconfounded Test 3 baseline; added Test 12 peak-size bands and linked engine store-path check | **Yes** (`kernel-v2.md` A2 & B4, `KERNEL.md` A17, `briefs/3-kernel-v2.md` steps 4, 5 test 12, and 5a) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D221–D228 (+ D205, D211–D220 for GPT) | Round 9 re-derivations (and round 7–8 changes GPT has not yet reviewed) | Settled by derivation; awaiting GPT adversarial review (and Opus confirmation of round 9 if needed) | **Yes**, if GPT breaks D221–D228 (Steps 5 test 12, 5a, 6, 7, 9, `RECORDER.md`, `VAULT.md`) |
| H16 (D226) | Settled-funding pull policy: Option 1 (fetch-once + gap backfill, recommended) vs. Option 2 (`--from-ms = w_start`, current default) | **Reduced to a human choice** — both preserve Ville's 5% bound and close Round 7 F1.1 & F2.2; differs only on what record the claim is about vs. survival against venue precision changes | **Yes** (`mmvault funding` pull query logic in `VAULT.md` and `4-study-2.md` step 7 test 10) |
| O22 | The recorder's reader (now with `.packed.zst`) inside 22,500 quotes/s | Open until Step 6's test 11 measurement | Step 6's reader, if missed |
| O24 | The replica's own trace at a 1-second tick (~3–5 GB zstd at Month 24) | Open until Step 6's test 11 measurement | Trace storage / compression, if a wall |
| O26 | `exp` and `log` wall time on `x4_local` and Study 2's trigger | Open until Step 5's `x4_local` and Step 3's trigger run | Fast `@[csimp]` twin (D219 sketch), only if a wall is hit |

**Would any open point change what is built?** **Yes:** (1) **H16** (the human's choice between Option 1 fetch-once + gap backfill vs. Option 2 `--from-ms = w_start`) directly determines `mmvault funding`'s pull query logic before it is built; and (2) **GPT's adversarial review** of round 9 (plus round 7–8 changes GPT has not yet seen) could still find a break in D221–D228 that changes Steps 5a, 6, 7, 9, or the recorders. Step 5's Test 12 hardening (D220 + N7.1/N7.2) was accepted by Opus with no eighth loophole and needs only GPT's confirmation.

### Committed criteria: reported, not edited

- **CS2.1's *Fails while the claim holds*:** D215's drafted note (`data/builder/architect-r8-report.md` §1e; its premise now holds under D221).
- **CS2.2's *A record that stops before the 212th day*:** D227's companion drafted revision (`data/builder/architect-r9-report.md` §4a).
- Both are reported for the advisor's two-reviewer check and commit; `audit/criteria.md` is untouched.

### Assumptions only the human can choose

- **H16 (D226 — settled-funding pull policy):**
  - **Option 1 (Fetch-once + gap backfill, architect's recommendation):** `mmvault funding` queries only `(coin, hour)` pairs not yet stored in `<root>/settled/funding/` (missing historical spans + new tail; daily and monthly). Matches `e691341` literally (*"for the judged days it does not yet hold"*), preserves Ville's 5% bound, closes Round 7 F1.1 & F2.2, runs in ~30 s at Month 24, and survives benign venue precision changes unscathed — at the cost of keeping first readings if the venue ever substantively corrects an already-fetched funding rate (zero rate-value restatements have ever been observed on Hyperliquid).
  - **Option 2 (`--from-ms = w_start`, current default in specs):** every monthly firing re-pulls all funding history from `w_start` (~39 min at Month 24). Catches retroactive rate corrections conservatively — at the cost of ending the entire study at Day 1 (`T* = w_start`) if Hyperliquid ever changes historical precision (e.g., 8 → 10 digits) or any old row's decimal value.
- *(Existing deferred choice unchanged:)* Disk volume for 2-year retention and off-`ws` `.packed.zst` storage (`architecture.md` 6.8).

### Owed

- **By the human:** pick Option 1 or Option 2 for **H16** (settled-funding pull policy) before `mmvault funding` is built.
- **By GPT (the next adversarial reviewer):** attack round 9 (D221–D228) plus round 7–8 changes GPT has not yet reviewed (especially D205's reversal of D200), starting with the targets below.
- **By the advisor (once converged):**
  - host list of ≥ 3 distinct x86-64 machines;
  - `mmrec cat`, `mmvault` (with destination directory `fsync`), and `mmvault funding` (under the human's H16 pick, with shared `settled` lock and destination directory `fsync`);
  - CS2.1 (D215) + CS2.2 (D227) companion dated revisions reviewed together by two fresh reviewers and committed alone;
  - Test 12's input bundle + Step 5 test 12 hardening (including N7.1 peak-size bands and N7.2 linked engine store-path check);
  - B4's v2 reference (SWAG + Chan written by a **different model** than Sonnet from `KERNEL.md` A17 alone without reading `Eval.lean`, then run as its own multi-host job after `d91e14b`).
- **By the test writers:** Step 5 test 12 (with N7.1/N7.2), Step 5a (zero-tolerance Test 2 with verified hex words, unconfounded Test 3), Steps 6 (test 14 with `R_UNCLOSED`, `_other`/`_order` tie order, non-universe malformed skip, whole-pack purity, silent `R_PROTECTED`), 7 (test 8), and 9 (tests 8 & 11 with `TZ`/`LC_ALL`/`OCAMLRUNPARAM=R`/`taskset` and `protected_windows_sha256`), and Brief 4 steps 6–7 (tests 5 and 10).

### What GPT, the next reviewer, should attack first

1. **D221 (dual-channel capture-coverage horizon):** try to construct (a) a capture where `T_k < T_{k−1}` despite append-only files (e.g., via a `listings` delisting or `recv` edge case changing `U(T_{k−1})`, or a packed-vs-raw quote validity mismatch); (b) a false overshoot (either via `settled/funding` + `l2Book-fast` boundary timing around `[T + 1 h, T + 25 h)`, or via `trades` lagging `l2Book-fast` by > 1 h, or via a delisted coin's `[max(w_start, t_prev_listed − 24 h), t_delist)` check passing on a truncated pull or freezing on an honest delisting); (c) a permanent freeze on an honest record (e.g., > half of active coins losing two-sided quotes simultaneously, or a 24-hour `settled/funding` outage across `T_max`); or (d) an early-exit bug in the newest-first `l2Book-fast` scan when host receive hours are skewed relative to venue timestamps.
2. **D222 & D223 (stream-ended packing & raw ≡ packed by construction):** try to construct (a) a case where a cleanly stream-ended file is still modified, or where `mm2 pack` accepts a truncated stream; (b) a raw vs. packed divergence that survives shared `Coin_route.classify_line`, `_order` tie restoration, and whole-pack `mm2 unpack-verify` (e.g., a file open at `Capture_{k−1}` containing an event `< T_{k−1}` that later closes and packs at `Capture_k`, or `_other` holding a malformed JSON line that changes reader counts or error order, or a mixed-coin `trades` line containing two events for the same coin at the same timestamp); (c) a holdout leakage channel in `mm2 pack` or `Capture_k` at the `2027-01-31 00:00 UTC (19:00 EST)` boundary.
3. **D224 & D225 (agreed refusals, pinned `protected_windows_sha256`, environment):** try to construct (a) a refusal path that still stalls silently or accidentally halts the whole study on a transient/deployment fault (check the boundary between `R_HOST_WINDOWS_MISMATCH` [no ballot] vs. `R_WINDOWS_INVALID` / `R_PROTECTED` [ballot]); (b) a residual host-environment leak that still causes `halt_non_deterministic` across three NixOS machines even with empty `envp`, no `localtime()`, and fixed core-count execution (e.g., `/etc/hosts`, locale tables, filesystem `readdir` order, or zstd dictionary/SIMD behavior).
4. **D226 (H16 — Option 1 fetch-once + gap backfill vs. Option 2 `w_start`):** attack Option 1's claim that it does not reopen Round 7 Findings 1.1 or 2.2 and keeps Ville's 5% bound (e.g., check whether a daily `00:17 UTC (19:17 EST)` pull failing/succeeding on different days can interact with a venue restatement or short page to move a verdict, or whether `Gaps_c` pagination with `endTime = H_b + 3,599,999` can miss or duplicate a boundary row stamped late or on an exact hour edge).
5. **D205's reversal of D200 (round 7–8, not yet reviewed by GPT):** verify whether decoupling Step 1 (`Capture_k`) from Step 2 (`RunInput_k`) with 2-of-3 sealed ballots and unconditional 3-way halt leaves any residual optional-stopping lever (e.g., hardware replacement rules, Step 1 capture failure/retry timing, or CS2.1/CS2.2 companion revisions D215 & D227).
6. **D228 (SWAG + Chan & independent B4 v2 reference):** check `KERNEL.md` A17 for any remaining ambiguity where two independent models implementing A17 without reading each other's code could disagree by 1 bit (e.g., `N.ofNat` conversion, `front` empty vs. non-empty at `n = 1`, `N.keep` placement on `s`/`μ`/`m2`, or `NaN` handling in `N.finite δ`).

### Convergence

**Re-derived at every cause; not yet read by GPT (or confirmed by Opus).** All 14 of Opus's round 8 findings (F1.1–F1.4, F2.1, F2.2, F3.1, F3.2, F4.1, F4.2, F5.1, F5.2, F6.1, F6.2) and all cheap notes (N1.1, N2.1, N2.2, N3.1, N4.1, N4.2, N5.1, N5.2, N7.1, N7.2) are answered at their causes with zero patches and zero clocks in the horizon. Two gates remain before convergence: **GPT's adversarial review** of round 9 (plus round 7–8 changes GPT has not yet read), and the **human's choice on H16** (Option 1 fetch-once + gap backfill vs. Option 2 `--from-ms = w_start`).

- **Round 9b (2026-11-20 07:09 UTC (02:09 EST), Gemini 4 Neon):** **H16 (D226) settled by the human** (`audit/decisions.md`, 2026-11-20 06:58 UTC (01:58 EST)): Option 1 (`mmvault funding` fetches each `(coin, hour)` once, then backfills missing gaps); `recorder/VAULT.md`, `audit/program/briefs/4-study-2.md` step 7, `audit/program/briefs/3-kernel-v2.md`, and `audit/program/architecture.md` rewritten to Option 1 alone with Option 2 and pending-choice text deleted; only GPT's adversarial review of round 9 remains before convergence.


## The last pass, round 10: O26's measurement answered — fast `exp`, `log`, and `nearestBits` twins (Step 5x, law `X6`)

Appended 2026-11-20 14:29 UTC (09:29 EST) by Gemini 4 Neon acting as the architect (`CLAUDE.md`, Orchestration; the human, 2026-11-19); **revised 2026-11-20 15:08 UTC (10:08 EST) in Round 11** after fresh Opus's review (`audit/reviews/2026-11-20-opus-round10.md`), deleting the replaced integer-ball design, wrong speed claims, vacuous self-comparison tests, and non-`CLAUDE.md` model governance (see Round 11 below for full derivations). Trigger: O26's measurement on `kernel2-step5` (`b94e128`), where `x4_local` finished ~73,000 of 3,265,488 arguments in 8 h 15 min single-threaded (~0.407 s/argument, ~15 CPU-days per single-host run) while B4 took 2.7–8 h per node on 4–5 workers (~75 CPU-hours total). `kernel2/KERNEL.md` needs no edit (zero semantic change). Report: `/home/kevin/repos/moneymachine/data/builder/architect-r10-report.md` (superseded by `architect-r11-report.md` on F1–F7 and governance).

### Settled in round 10 (standing after Opus's review, with Round 11 replacements noted)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D229 | O26 wall confirmed on `kernel2-step5` `b94e128` (`x4_local` ~0.407 s/arg ≈ 15 CPU-days/run, ~45+ CPU-days across `x4-hosts.sh`'s 3 runs, months for `x4-counts.lean`, ~75 CPU-hours B4) | Direct code inspection (`Exact.lean:1492–1573`, `x4_local.ml`, `x4-hosts.sh`, `x4-counts.lean`, `c64-corpus.jsonl`) and compiled Lean measurements (Round 11: ~99% of the 0.407 s/arg wall is `Exact.exp` at large `|x|`; `log` and `nearestBits` are `< 1%`). Sharding test 12 as it is patches around a recomputation loop (`CLAUDE.md` §1); stop the slow run as sunk cost and build the proved-equal `@[csimp]` twin. *(Round 10's choice of the integer ball over the incremental exact series is **replaced by D232** in Round 11.)* | **Yes** (`kernel-v2.md` B1/B3/Part G, `briefs/3-kernel-v2.md` Step 5x) |
| D230 | Step 5x (`◆`, law `X6 ★`): fast `exp`, `log`, and `nearestBits` twins between Step 5 and Step 5a, `X4`/`X5` zero-diff, compiled `x4-counts`, full Test 12 + B4 rerun | **Superseded in Round 11 by D232–D235:** Round 10's integer-ball / Ziv / sandwich / nesting / CAF / stage design, its `< 15 min` gate, its vacuous self-comparison tests, and its Argon/Hydrogen/self-reviewing-GPT governance are **deleted** and replaced by the 5-substep incremental exact twin (D232), F5/F7 bypass & compiled-IR guards for X3 and X6 (D233), F6 independent-only test contract (D234), and `CLAUDE.md`-strict governance (D235). | **Yes** (see D232–D235) |
| D231 | Step 5 merge gate into `kernel2-build` (**accepted by fresh Opus**) | **Do not merge before Step 5x.** `X4`/`X5` do not prove X4's paper half and B4 covers only small `exp` (`[-3, 3]`) and 2 `log` streams; Test 12 is the sole full-domain check of X4's paper half (`CLAUDE.md`, Correctness). Build Step 5x directly on `kernel2-step5`, pass full Test 12 + B4 rerun (reusing stored `data/stage6/c64-reference-mpfr/`), then merge green into `kernel2-build` before Step 5a. | **Yes** (build & merge order in `briefs/3-kernel-v2.md` Steps 5, 5x, 5a) |

---

## The last pass, round 11: answering fresh Opus's review of round 10 (incremental exact twin, bypass & IR guards for X3/X6, governance)

Appended 2026-11-20 15:08 UTC (10:08 EST) by Gemini 4 Neon acting as the architect (`CLAUDE.md`, Orchestration; the human, 2026-11-19), answering fresh Claude Opus 5.5's adversarial review of round 10 (`audit/reviews/2026-11-20-opus-round10.md`). Re-ran and extended the reviewer's compiled Lean 4.34.0 timing and compiler-IR experiments under `~/.cache/mm-r10-review/`. Revisions on `rearchitecture`: Item 1 (`8dd30df`, `kernel-v2.md` X6/B1/Part G), Item 2 (`e0bca23`, `kernel-v2.md` B2/X3 and `briefs/3-kernel-v2.md` Steps 0 & 3), and Item 3 (`briefs/3-kernel-v2.md` Step 5 Test 12 & Step 5x rewrite, plus this ledger commit). `kernel2/KERNEL.md` unchanged (zero semantic change). No market data from 2026-11-01 on, nothing under `data/holdout/`, and no token or key file read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r11-report.md`.

### In plain words

- **Conceded F1 & F2 — replace the integer ball with the incremental exact series twin, deleting the ball completely (D232).** Compiled Lean 4.34.0 timings over the true Test 12, B4, and 1-second trigger workloads show the wall's cause is X4's recomputation (`a^k`, `k!`, and GMP `gcd`s from scratch at every term and every count), not exact arithmetic:
  - Incremental exact `exp` + gcd-free incremental exact `log` + `Nat.log2`/`roundDiv` `nearestBitsFast` measure **12.9 µs** (`exp` at `|x| ≤ 0.011`) and **14.6 µs** (`log` at `1 ± 1.4e-3`) at 1-second trigger scale (**3× faster** than Round 10's fixed-`extra=60` ball at `38.0 µs`), **35–39 µs** at B4's `|x| < 3` (faster than the ball's `38–43 µs`), **0.10–0.11 ms** on `log_draws` (`0.35 ms` at worst-case `n = 42`), **0.007 ms** for `exp` on `log_draws`, and **2.64 ms** for `exp` on `Uniform(-700, 700)`.
  - That drops single-threaded `x4_local.exe` from **15 days** to **~50–75 min** on desktop (**~1.5–2 h** on slower homelab nodes; Test 12 gate (viii) corrected from `< 15 min` to **`< 3 hours` per host**), drops B4 from **~75 CPU-hours** to **~5–6 CPU-hours** (~25–35 min across 3 nodes), and drops compiled `x4-counts` from **months** to **~1 hour** while preserving X4's **exact** least deciding `(n*, first)` across all 3,265,488+ inputs (proved directly in `X6`).
  - Its proof needs only `nearestBitsRatio_eq`, two elementary recurrence invariants, `logSplit_pos` (5 lines), and one loop-fusion lemma — **deleting** `nearestBits_sandwich`, `nearestBitsDyadic`/`Int`, `exp_interval_nested`, `logSplit_bounds`, `log_interval_nested`, `firstDeciding_of_enclosure`, `expBallNat`/`expBallTry`, `atanhBallNat`/`logBallTry`, `ln2Ball1`/`ln2Ball2`, `logSplitBits`/`expStartBits`, and all Stage 0/1/2/3 machinery.
  - Study 2's ladder uses neither `exp` nor `log`; its trigger (Brief 4, Step 3) is not yet fitted (and even 1 call/coin-tick takes ~1.2 h over the 212-day archive and ~4.0 h over the 2-year forward run). **O26 stays open solely for a fitted Study 2 trigger that later misses B5 on `exp`/`log`.**
- **Conceded F5 & F7 — mechanical bypass ban and compiled-IR `@[csimp]` verification for BOTH X3 and X6 (D233).** Verified live on Lean 4.34.0: `checks.engine-proofs` (`check-proofs.sh`) now checks (1) `Engine`'s transitive import boundary (`Engine.*`, `Init.*`, `Std.*` only), (2) all constants (`.thmInfo`, `.defnInfo`, `.opaqueInfo`, public or `private`) and module attribute tables for zero `@[implemented_by]` (`getImplementedBy?`), zero `@[extern]` (`isExtern`; `@[export]` passes), zero `unsafe` (`ConstantInfo.isUnsafe`), and allowed-three axioms only, and (3) compiled IR (`Lean.IR.declMapExt`) for both X3 (`readBits`) and X6 (`nearestBits`, `exp`, `log`): registered in `CSimp.ext`, production caller roots present (`Engine.Machine.readInt`, `Engine.Exact.call`, `Engine.Lang.bitsOps`), zero `.fap`/`.pap` references matching `S` or `Name.isPrefixOf S` (catching `._boxed`/`.spec_*`) in any `Engine` module outside `Engine.Exact` or reachable from the twins inside `Engine.Exact`, and positive twin reachability (handling one-line wrapper inlining). `checks.engine-proofs-fixtures` (`engine-proofs.sh`) tests every rejection (`ImplementedBy` incl. `rfl`-proved fake twin, `Extern` `opaque`+`def`, `Unsafe`, `SorryDef`, stripped `@[csimp]` for X3 and each X6 twin, and an IR-only leak test with `CSimp.ext` still populated). Flaky wall-time bounds in `checks.mm2-tests` are deleted (`x6_speed_test.ml` → `x6_mpfr_test.ml`).
- **Conceded F6 — delete every vacuous self-comparison test (D234).** Once `@[csimp]` is active, comparing `expFast`/`logFast`/`nearestBitsFast`/`readBitsFast` to their originals in compiled or `#eval` code compares the twin with itself. All such planned checks are deleted from `x6-fast.lean` and `x4-counts.lean`, replaced exclusively by independent checks: `decide +kernel` (kernel never applies `@[csimp]`), MPFR (`x6_mpfr_test.ml`, `x4_local.exe`), `Engine.Laws` series formulas (`expLoAt`/`logLoAt`), and literal IEEE 754 bit constants.
- **Conceded F3, F4, contract gaps, and model governance (D235).** F3 (impossible Stage 2 width `< 2⁻⁵¹²` vs. X4 cap tail `2⁻⁴⁸¹`), F4 (`expBallNat` off-by-one `k` vs. `k + 1`, missing `nearestBitsDyadicInt`), and all `stage`/`terms_m`/`expBallTry` ambiguities vanish cleanly with the ball's deletion; `X6`'s new `expFastCount`/`logFastCount` contract is total and exact on every `UInt64`. Governance is rewritten strictly from `CLAUDE.md` roles (deleting Argon-as-builder, Hydrogen, "Opus strictly forbidden", and GPT reviewing its own tests): Sonnet builds, Opus gives commit check & last review (neither building nor writing tests), Neon is Rounds 10–11 architect (neither building nor reviewing Rounds 10–11), and GPT is either test writer OR outside build reviewer (mutually exclusive — if the advisor substitutes an `agy` Gemini model under `ops/agy-write.sh`, the advisor logs it in `audit/decisions.md` and that model never reviews its own work).

### Who has seen what

- **Fresh Claude Opus 5.5** reviewed Round 10 (`audit/reviews/2026-11-20-opus-round10.md`) and raised F1–F7 + governance; all seven findings and every governance point are conceded and re-derived here in Round 11.
- **GPT** has not yet reviewed Round 11 (`D229`, `D231`, `D232–D235`) — **GPT is the next adversarial reviewer** (`CLAUDE.md`: a review repeats on another model when findings changed the design).
- **GPT** also has not yet reviewed Round 9 (`D221–D228`) or D205's reversal of D200.

### Agreed (standing with fresh Claude Opus)

- O26's wall on `kernel2-step5` is real (~99% `Exact.exp` at large `|x|`; `log` and `nearestBits` `< 1%`); `x4-counts.lean` over `Engine.Laws` is infeasible as written; sharding Test 12 is rejected (`CLAUDE.md` §1).
- A `@[csimp]` twin in `Engine.Exact`, proved equal on every input with `X4` and `X5` byte-identical, is the right pattern.
- **D231:** Hold `kernel2-step5` unmerged until Step 5x passes `X6`, full Test 12, and full B4 rerun (reusing stored `data/stage6/c64-reference-mpfr/`).
- **Standing from rounds 6–9b:** H16 settled by the human as Option 1 (`audit/decisions.md` 2026-11-20 06:58 UTC (01:58 EST)); Opus's round 8 acceptances (`D218`–`D220`, accepted parts of `D211`, `D213`–`D217`).

### Settled by derivation in round 11 (awaiting GPT review)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D232 | Which twin for X6 (F1, F2): incremental exact series vs. integer ball, plus corrected Test 12 speed gate and narrowed O26 | Compiled Lean 4.34.0 benchmarks (`r11_bench.lean`, `r11_bench2.lean`) across Test 12, B4, and 1-s trigger scales + `CLAUDE.md` §1–§2: incremental exact `expFastCount`/`expFast` + gcd-free `logFastCount`/`logFast` + `nearestBitsFast` (reusing `roundDiv`) clears Test 12 (~50–75 min desktop / ~1.5–2 h homelab; gate (viii) **`< 3 hours`/host**), B4 (~5–6 CPU-h, 35–39 µs/arg), and compiled `x4-counts` (~1 h, preserving X4's exact least deciding `(n*, first)`), and is **3× faster** than Round 10's ball at 1-s trigger scale (12.9–14.6 µs vs. 38 µs) with a strict-subset proof. Integer ball deleted completely; O26 narrowed and left open only for a fitted Study 2 trigger that misses B5. | **Yes** (`kernel-v2.md` B1/B3/Part G, `briefs/3-kernel-v2.md` Step 5 Test 12 & Step 5x) |
| D233 | Mechanical guards against bypasses and silent non-firing `@[csimp]` for BOTH X3 and X6 (F5, F7) | Verified live on Lean 4.34.0: `checks.engine-proofs` (`check-proofs.sh`) adds import-graph boundary check, all-constant (`thmInfo`/`defnInfo`/`opaqueInfo`) axiom check, ban on `@[implemented_by]`/`@[extern]`/`unsafe` (`@[export]` allowed), and deterministic compiled-IR `@[csimp]` verification (`CSimp.ext` + caller roots `Engine.Machine.readInt`/`Engine.Exact.call`/`Engine.Lang.bitsOps` + zero slow `S`/`Name.isPrefixOf S` refs outside `Engine.Exact` or reachable from twins inside `Engine.Exact` + positive twin reachability); `checks.engine-proofs-fixtures` (`engine-proofs.sh`) adds negative fixtures (`ImplementedBy`, `Extern`, `Unsafe`, `SorryDef`, stripped `@[csimp]` for X3 and each X6 twin, and IR-only leak with `CSimp.ext` populated). Wall-time assertions deleted from `checks.mm2-tests` (`x6_speed_test.ml` → `x6_mpfr_test.ml`). | **Yes** (`kernel-v2.md` B2/B3, `briefs/3-kernel-v2.md` Steps 0, 3, 5x; `check-proofs.sh`, `engine-proofs.sh`, `test-fixtures/`) |
| D234 | Delete vacuous compiled/`#eval` self-comparisons (F6) | Once `@[csimp]` is active, comparing a twin to its original compares it with itself. Deleted all such checks from `x6-fast.lean` and `x4-counts.lean`; contract mandates exclusively independent references: `decide +kernel` (kernel never runs `@[csimp]`), MPFR (`x6_mpfr_test.ml`, `x4_local.exe`), `Engine.Laws` series formulas (`expLoAt`/`logLoAt`), and literal IEEE 754 bit constants. | **Yes** (`briefs/3-kernel-v2.md` Step 5x tests & contract) |
| D235 | F3, F4, contract completeness, and `CLAUDE.md`-strict governance | F3/F4 and all `stage`/`terms_m`/`expBallTry` gaps erased with the ball; `expFastCount`/`logFastCount` fully specified in `X6` and the test writer's contract. Governance names only `CLAUDE.md` roles (Sonnet builds, Opus gives commit check & last review, Neon is architect and does not build/review, GPT is test writer OR build reviewer — mutually exclusive; any `agy` substitution under `ops/agy-write.sh` is advisor-logged; Argon retired as reviewer; Hydrogen deleted; 4-point Lean build-review checklist stated). | **Text & routing** (`briefs/3-kernel-v2.md` Step 5x) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D231, D232–D235 | Round 11 Step 5x design (incremental exact `X6`, F5/F7 bypass & IR guards for X3/X6, F6 independent-only tests, `< 3 h` Test 12 gate, governance) | Settled by derivation answering fresh Opus's review; awaiting **GPT** adversarial review | **Yes**, if GPT breaks a recurrence/edge case, finds an unguarded bypass or IR false positive/negative in `check-proofs.sh`, or finds a gap in the test contract |
| D221–D228 (+ D205, D211–D220 for GPT) | Round 9 re-derivations (and round 7–8 changes GPT has not yet reviewed; H16 already closed by human in 9b) | Settled by derivation; awaiting **GPT** adversarial review | **Yes**, if GPT breaks D221–D228 (Steps 5a, 6, 7, 9, `RECORDER.md`, `VAULT.md`) |
| O22 | Recorder reader (with `.packed.zst`) inside 22,500 quotes/s | Open until Step 6 test 11 measurement | Step 6's reader, if missed |
| O24 | Replica trace size at 1-second tick (~3–5 GB zstd at Month 24) | Open until Step 6 test 11 measurement | Trace storage/compression, if a wall |
| O26 | `exp` and `log` wall time on Study 2's fitted trigger (Brief 4, Step 3) | **Narrowed in Round 11:** Step 5x's incremental exact twin clears Test 12 (~50–75 min desktop / `< 3 h` gate) and B4 (~5–6 CPU-h). O26 stays open solely for Brief 4 Step 3's trigger fit (not yet fitted): if a fitted 1-second trigger calls `exp`/`log` at a rate that misses B5's 24-hour wall, a faster measured twin replaces `expFast`/`logFast` behind the same `X6` | Only if Step 5x misses its `< 3 h` Test 12 gate, OR if a fitted Study 2 trigger misses B5 on `exp`/`log` |

**Would any open point change what is built?** **Yes:** (1) **GPT's adversarial review of Round 11 (`D232–D235`)** gates Step 5x before it is built; and (2) **GPT's pending review of Round 9 (`D221–D228` + `D205`)** still gates Steps 5a, 6, 7, 9, and the recorders. Among measurement opens (`O22`, `O24`, narrowed `O26`), none changes what is built today unless a future measured run misses its wall.

### Committed criteria: reported, not edited

None touched in Round 11. (D215's CS2.1 note and D227's CS2.2 companion revision remain queued for the advisor's two-reviewer check and commit.)

### Assumptions only the human can choose

None new in Round 11. (H16 was settled by the human as Option 1 in Round 9b; disk volume for 2-year retention / off-`ws` `.packed.zst` remains the existing deferred choice of `architecture.md` 6.8.)

### Owed

- **By GPT (the next adversarial reviewer):** attack Round 11 (`D232–D235`) — targets below; also complete its pending review of Round 9 (`D221–D228` + `D205`).
- **By the advisor (once Round 11 converges with GPT):**
  - pick Governance Option A (GPT writes Step 5x's tests; Opus + mechanical checks review the build) or Option B (advisor-logged non-Neon `agy` Gemini model under `ops/agy-write.sh` writes Step 5x's tests; Opus + GPT review the build) so no model reviews its own work;
  - route Step 5x's implementation & proofs to **Claude Sonnet** (or advisor-logged non-reviewer/non-test-writer fallback);
  - verify Opus's four-point Lean build checklist (`X6` statement, `X4`/`X5` zero-diff, `checks.engine-proofs` + `checks.engine-proofs-fixtures` passing for X3 & X6, full Test 12 + full B4 rerun), then merge `kernel2-step5` into `kernel2-build` before starting Step 5a.

### What GPT, the next reviewer, should attack first (Round 11)

1. **Can a wrong twin still pass `checks.engine-proofs` + `checks.engine-proofs-fixtures` (D233 / F5 & F7)?**
   - Try to construct a Lean 4.34.0 module in `Engine` that executes unproved/foreign code while passing: `import` boundary check, `implementedByAttr`/`externAttr` module-entry checks, `getImplementedBy?`, `isExtern`, `ConstantInfo.isUnsafe`, and `collectAxioms` on every `.thmInfo`/`.defnInfo`/`.opaqueInfo` (for example: `partial def` inside a proof-irrelevant helper, `@[macro_inline]`/`@[inline]`/`@[specialize]` quirks, `noncomputable`, `opaque` with a default value, `Lean.Compiler.CSimp` pointing to an unexpected target, or an attribute applied inside a `section`/`namespace` or metaprogramming macro).
   - Try to break the compiled-IR `@[csimp]` check in either direction: (a) a false negative where `@[csimp]` fails to fire (e.g., via higher-order closure, typeclass dictionary `Numbers UInt64`, partial application, or `Wire.lean`/`MachineCore.lean` specialization) yet passes the IR scan; or (b) a false positive where valid `Engine` code (e.g., `Engine.Laws.firstDeciding`, `Engine.Exact.readBitsFast`, or inlined `nearestBitsFast`/`expFast`) fails the IR scan.
   - Check whether `checks.engine-proofs-fixtures`'s IR-only negative scratch test actually exercises the IR scan independently of the `CSimp.ext` registry check.
2. **Exactness & edge cases of the incremental exact recurrences and `X6` (D232):**
   - Check `nearestBitsRatio` / `nearestBitsIntRatio` / `nearestBitsInvIntRatio` at every boundary: `A = 0`, `B = 0` (`1 / 0 = 0` matching Lean's `Rat` division when `s1 = t1` in `expFastCount` for `x < 0`), `e = -1075` exact tie (`-2⁻¹⁰⁷⁵ → -0`, `-(2⁻¹⁰⁷⁵ + ε) → -2⁻¹⁰⁷⁴`), `e = -1076` signed zero preservation, `e = -1022` subnormal→normal carry, `e = 52 → 53` shift-direction switch, `e = 1023` rounding up to `m = 2⁵³` (`infBits`), and `e ≥ 1024`.
   - Check `logFastCount`'s unified gcd-free recurrence for every `y > 0`: verify `logSplit_pos` holds for subnormals (`2⁻¹⁰⁷⁴`) and `DBL_MAX`, verify `z = (m - 1)/(m + 1)` always satisfies `v² - u² > 0` (including `y = 1`, where `e = 0, u = 0, v = 1, bGap = 1, D > 0`), and verify `cNum ± rNum` matches `logLoAt y n` and `logHiAt y n` exactly for both `e < 0`, `e = 0`, `e > 0`, and `z < 0`, `z = 0`, `z > 0`.
   - Check `X6`'s exact `.2` count clauses against `Engine.Laws.expLoAt`/`expHiAt`/`logLoAt`/`logHiAt`: confirm `Engine.Laws`' definitions are definitionally equal to `Engine.Exact`'s, confirm `expFastCount`/`logFastCount` return `none` on cutoffs/specials/non-finite and `some (n*, first)` on the interior (including `x = 0 → some (0, 0)` and `y = 1 → some (0, 0)`), and check whether any input in `hardest.txt` or N7.1 peak-size bands could blow up `expFastCount` or `logFastCount` past the `< 3 hours` Test 12 gate on slower homelab CPUs (`prodesk5`/`prodesk7`).
3. **Vacuous-test audit (D234 / F6) and `x4-counts` compilation:**
   - Check whether ANY remaining planned test in `x6-fast.lean`, `x6_mpfr_test.ml`, or `x4-counts.lean` still compares a `@[csimp]`-replaced function with itself, or whether `Engine.Laws.firstDeciding` calling `Engine.Exact.nearestBits` creates any subtle blind spot in `x4-counts`' bounded cross-check that `x4_local` + `x6-fast.lean` (`decide +kernel`) + `x6_mpfr_test.ml` does not close.
   - Check whether compiling `x4-counts.lean` via `lake env lean -c` + `leanc` against `$MM2_ENGINE_LIB` in `x4-hosts.sh` has any Nix/Lake toolchain or initialization hazard (e.g., module initializers, `LEAN_PATH`, GMP linkage, or differing optimization flags vs. `packages.mm2`).
4. **The O26 scoping call (D232) and governance (D235):**
   - Challenge whether leaving O26 open for Study 2's trigger fit could cause avoidable rework if a Study 2 trigger turns out to need multiple `exp`/`log` calls per 1-second tick, vs. the cost of building and proving an unmeasured ball today.
   - Check D235's governance options A and B against `CLAUDE.md` (Reviewers & Orchestration) for any residual self-review loophole.

### Convergence

**Re-derived at every cause; fresh Opus's Round 10 findings all conceded; awaiting GPT.** Round 11 (`D232–D235`, with Opus-accepted `D231`) now goes to **GPT** for adversarial review before Step 5x is built; Round 9 (`D221–D228` + `D205`) also awaits GPT before Steps 5a, 6, 7, 9, and the recorders proceed.

## The last pass, round 12, kernel: GPT's reads of rounds 10 and 11 and of round 12's first answer

Appended 2026-11-21 21:06 UTC (16:06 EST) by Claude Opus 5.5 at maximum effort, the architect for round 12's kernel half (item 1 by a first session, item 1b by a second), answering `audit/reviews/2026-11-21-gpt-round10-11.md` (findings 1 to 3 and governance) and `audit/reviews/2026-11-21-gpt-round12-kernel.md` (its three open points). Revisions on `rearchitecture`: `kernel-v2.md` B2, B3 and part G and brief 3's step 5x (`9590d3f`, `f19ffb8`, then `9e6795b` to `bddb435` and this commit). Experiments on the pinned Lean 4.34.0 under `~/.cache/mm-r12/`. Study 2's half of round 12 is the other architect's, on `rearchitecture-s2`. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r12-report.md`.

### In plain words

- **The guard stopped patching.** Rounds 10, 11 and 12 each closed one way the compiled engine could differ from the proved one, and GPT found the next (a local macro that runs code while the library builds). The guard now stands where every such way must pass: before the build, it reads the library's source against a list of the forms the engine already uses, each reviewed to give the compiler no unproved direction and to run nothing with an effect. Anything new fails until the architect lists it. The one way a listed form can run the project's own code, native reduction, runs code that on the pinned toolchain cannot touch a file, and any proof using it is rejected. Round 12's first guard, a list of four mechanisms inspected after the build, is deleted.
- **A law's meaning is frozen by what it is, not by where it is written.** Every constant a law reaches is either engine code the law constrains (its body may change; the law must be proved again) or the vocabulary the law is stated in (frozen, wherever it lives). Applying that to every law found that R1, S1, L1a and C2 read the clock, horizon, delays and rules from the machine's own start state, so a new law, L0, ties that state to the program and header as read. It also found three functions R1 is stated in that the first draft had left free.
- **What only tests hold is now said plainly:** that `Float`'s arithmetic is IEEE's, that the readings of the inputs are their specs, that the machine's log and state are what they record (until P1 ties the log's fills to the report), and that the evaluator's values are `SEMANTICS.md`'s.

### Who has seen what

- **GPT** read rounds 10 and 11 (accepting the incremental twin), and round 12's first answer (accepting artifact provenance, the export-rooted walk, the two-reviewer routing and the timing as a measurement, and disputing three points). It has not seen item 1b.
- **Neon** has not reviewed round 12.

### Agreed (GPT, `2026-11-21-gpt-round12-kernel.md`)

- The incremental exact twins, their recurrences and rounding, `nearestBitsRatio`'s contract and X6's count clauses; no ball twin.
- `@[init]` is a real bypass of round 11's guard. An allowlist beats a list of known attributes.
- The production walk starts at the exports and covers every module (speed only).
- Every ◆ build gets two fresh reviewers (brief 3, How every step runs, item 4). Test 12's wall time is a recorded measurement, not a gate.
- `nearestBits`'s body stays free under X5.

### Settled by derivation in round 12 (awaiting GPT)

| Point | Settled by | Changes what is built |
|---|---|---|
| GPT's point 1: code run while the build elaborates | The boundary moved to what the build may execute and what the shipped engine is built from (kernel B2, first clause). Before the build, the toolchain's own parser checks every syntax kind and keyed name of the library against lists from `b94e128`, reviewed form by form; the check runs in the flake's shared engine build. It fails closed for any spelling, because a departure needs a form, the check's parse is the build's (the library declares no syntax and stays inside `Engine`), and only reviewed forms pass. Native reduction is the one remaining route, and runs pure code (4.34.0: an `IO` action needs a `Void IO.RealWorld`, unobtainable by computable code; `~/.cache/mm-r12/purity/`); its proofs rest on `Lean.trustCompiler`, which the axiom clause rejects. Round 12's first guard (provenance, extension list, `unsafe` ban, `#eval`/`skipKernelTC` searches, reserve replay) is deleted. | **Yes:** `check-source.lean`, `syntax.txt`, the shared build step, and the source fixtures (`LocalMacroEval`, `Partial`, `OpenOutside`, `DisguisedCore`, `NativeReduce`, …) |
| GPT's point 2: specification by meaning, not by file | Subjects (engine code a law constrains, or functions a law determines) are printed by type; specification (inputs' readings, laws' vocabulary, observers, `bitsOps`, record types, export bindings) is printed in full wherever defined. There is one subject list in `frozen.txt`, and unlisted means specification. The roots are the laws and the exports. Applied to every law, this added L0 ★ (`start`'s `cfg`, `prog` and `rules` are `Machine.prepare`'s reading of the inputs; proved on `b94e128`'s build under the three axioms, `~/.cache/mm-r12/l0/`) and made `Orders.cancelSlot`, `install` and `admission` specification. Reads of the machine's own record (its log, the coins in view, its rules after a listing) are listed as held by tests until P1 ties the log's fills to the report. | **Yes:** `frozen.txt`'s rule and list, L0 and its proof in sub-step 1, fixtures `MovedClock`, `AdmissionEquity`, `NewSubject` |
| GPT's point 3: `bitsOps` beyond X4's four bindings | `bitsOps` is specification, frozen in full, and the exported machine runs on it (frozen export body and instance; X1's rows clause). That `Float`'s operations are binary64's rests on the trust boundary, B4 and review, as kernel B2 says. Item 1's "holds by definition under the laws" is retracted. | **Yes:** fixture `BitsOpsAdd`; text in kernel B2 |
| Step 5x's order | L0's statement goes with sub-step 1's tests, and X6's with sub-step 4's (the twins do not exist before), so each sub-step ends with the library passing. | **Yes:** commit order within step 5x |

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| Item 1b as a whole | Settled by derivation; awaiting GPT | **Yes**, if GPT breaks parse equivalence, finds a listed form that directs compilation or runs project code with an effect, finds a computable world on 4.34.0, or finds a misclassified constant |
| The machine's own records (log, coins in view, rules after a listing, the books admissions read) | Stated as held by tests, not laws. P1 (step 9) closes the fills; no law yet closes the rest | Not before step 9; a law that ties one would be added at its step |
| O26 | Open only for study 2's fitted trigger (unchanged) | Only if that trigger misses B5 |

**Would any open point change what is built?** Yes, only through GPT's review of item 1b: step 5x is not built before it. No dispute with GPT is open on the arithmetic, the walk or the routing.

### Committed criteria: reported, not edited

None touched by the kernel half.

### Assumptions only the human can choose

None.

### Owed

- **By GPT:** the attack below, on item 1b.
- **By the advisor:** once it converges, route step 5x as brief 3 says, with the review of `syntax.txt`'s kinds and of `frozen.txt`'s subject list made part of sub-step 1's reading.

### What GPT, the next reviewer, should attack

1. **Parse equivalence and the listed forms.** Find a library file that the check parses one way and the build another (scoped syntax, a header, an option, a `choice` node), or a form on `b94e128`'s list whose elaboration by 4.34.0 gives the compiler a direction other than `@[csimp]` and an `mm2_` export, or runs project code by a route other than `Lean.reduceBool` and `Lean.reduceNat`.
2. **Purity.** Find a safe, computable way on 4.34.0 to obtain an `IO.RealWorld` or a `Void IO.RealWorld`, or a pure-typed `Init` function with a file effect, so that code run by native reduction rewrites an artifact.
3. **The classification.** Find a constant the subject categories free that a law only uses to state what another subject must do (as `admission` was in the draft), a free observer, or a further read of the machine's own record, not listed in kernel B2, that could change CS2.1 to CS2.3 before P1.
4. **L0.** Find anything else a law reads from the start state.

### Convergence

**Not yet converged.** Item 1b answers GPT's three points at their cause, and none of the answers is a patch: the guard's boundary no longer depends on the next spelling, and the frozen surface no longer depends on a file. It goes to GPT.

## The last pass, round 13, kernel: GPT-6.2's read of item 1b, Neon's read of round 12, and study 2's routed changes

Appended 2026-11-22 02:10 UTC (2026-11-21 21:10 EST) by Claude Opus 5.5 at maximum effort, the architect for round 13's kernel half, answering `audit/reviews/2026-11-21-gpt62-round12-kernel-1b.md` (parts A and B) and `audit/reviews/2026-11-21-neon-round12-kernel.md` (Neon's web UI truncated its bundle: it saw neither GPT's round 12 review, the round 12 report nor the step 5 Lean), and folding in the kernel changes study 2's round 13 routes (`architect-r13-s2-report.md`, "Kernel changes", `rearchitecture-s2` `d79a8ca`), which replace round 12's list. Revisions on `rearchitecture`: `b4d6a8a` to this commit. Experiments on the pinned Lean 4.34.0 under `~/.cache/mm-r13/`. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r13-kernel-report.md`.

### In plain words

- **Round 12's guard could be walked around with the forms step 5 already uses.** Lean's elaborator runs the library's own code when a binder's type is `autoParam`, and then compiles whatever syntax that code returns, which is in no file. Built on the pinned toolchain with nothing but `b94e128`'s 25 kinds: the kernel proves `g = 4` and the compiled `g` returns 999; the same route can plant an initializer that runs IO when the next module is built. Neither reviewer named it; GPT-6.2's `include_str` coercion and Neon's world taken from `sorryAx` were two more of its kind.
- **So the question changed from "which forms run code" to "when does this toolchain run code at all".** Read from its source: at three entry points only, each reached by a form, by `autoParam`, or by naming `Lean.reduceBool`/`reduceNat`. The check now refuses forms off its lists and any name under `Lean` or named `autoParam`, so the build runs none of the library's code, native reduction included. Lean's module system would have refused it by the toolchain's own rule, but modules hide `Init`'s bodies from the kernel, which the laws' witnesses need (round 13's conversion of step 5 failed there).
- **The build reads exactly what the check read:** the check writes the tree Lake builds, and the policy as a literal; `include_str` is gone.
- **The frozen surface now holds the start, the evaluator and the export bindings.** A function is left free only where every build re-establishes it: a law determines it, or the suite reruns on it. L0 now says that every run that completes is observed and ticks on its clock, which R1 needed.
- **Study 2's changes are in:** the listings copy, V13, the recorders' table and the ledger's reserve for funding.

### Who has seen what

- **GPT-6.2** read item 1b (parts A and B), accepting the pre-build allowlist, the semantic split, frozen `bitsOps` and the local macro's rejection. It has not seen round 13.
- **Neon** read round 12's kernel bundle without GPT's round 12 review, the report or the step 5 Lean. It has not seen round 13.

### Agreed

- A boundary before the build, fail-closed on forms, replacing round 12's first guard (GPT-6.2, Neon).
- The frozen surface by meaning, not by file; `bitsOps` and `cancelSlot`, `install`, `admission` as specification (GPT-6.2, Neon).
- The export-rooted IR walk, the incremental twins, X6's counts, test 12's time as a measurement, step 5x's commit order (Neon; GPT earlier).
- Export bindings printed as symbol–constant pairs (GPT-6.2 and Neon proposed it; done).
- `include_str` leaves the library (GPT-6.2 and Neon).

### Settled by derivation in round 13 (awaiting GPT and Neon)

| Point | Settled by | Changes what is built |
|---|---|---|
| Round 13's own finding: an `autoParam` binder makes the elaborator run library code and compile syntax no file holds (`F3.lean`; `let rec` attributes carry `implemented_by` and `init`, `B.lean`, `M2.lean`) | The routes read from the pinned toolchain: compiled code runs while building only at `evalConst`, the kernel's native reduction and imported initializers, reached by forms, `autoParam` or `Lean.reduceBool`/`reduceNat`. Forms by the lists; names by one rule (nothing under `Lean`, no `autoParam`). The build runs none of the library's code (kernel B2) | **Yes:** the name rule in `check-source.lean`; fixtures `AutoParam`, `AutoParamInit` |
| GPT-6.2 B1: `include_str` through a coercion; the "sole route" claim | Off the list; the check writes `Engine/PolicyText.lean` from the file and requires the literal to be its bytes; the purity argument deleted (nothing rests on it) | **Yes:** generated policy module, `lakefile.lean` without `input_file`; `IncludeStr`, `PolicyModule` |
| GPT-6.2 B2: checker and Lake reading the same files | The check reads the import closure by Lake's module paths and writes the tree Lake builds, nowhere else | **Yes:** `SymlinkedDir` |
| GPT-6.2 B3: atom variants | An atom is checked with its kind | **Yes:** `NoncomputableSection` |
| GPT-6.2 B4 and Neon 1: purity wording; a world from `sorryAx` | Conceded: the premise was false (`sorryAx IO.RealWorld true` is safe and computable). Closed at the cause: native reduction needs `Lean.reduceBool`, which the name rule refuses; `sorryAx` needs no ban, since nothing runs it during the build and the axiom clause rejects it after. Neon's ban list is replaced by the derived rule | **Yes:** `NativeReduce` now a source fixture; `SorryWorld` |
| GPT-6.2 A1: the first tick; R1's schedule read from the log | The start (`start`, `startAdmission`, `initialState`) is specification, whole; round 12's L0 deleted. L0 restated: a completed run is observed, and its ticks are each multiple of the tick in the horizon, once, in order (`tickTimes`) | **Yes:** L0's statement and proof in sub-step 1; `FirstTick` |
| GPT-6.2 A2: C symbol bindings | Printed as pairs (`b4d6a8a`) | **Yes:** `ExportSwap` |
| GPT-6.2 A3: the stated limits incomplete | The list derived from the statements: the log after the start, the cycle records, coins in view, C2's running fields, the evaluator's values, the toolchain reading; IEEE: bit casts, `trunc`'s direction, `ofNat`/`ofInt`, comparisons | Text |
| Neon 2: the evaluator a subject though only invariances constrain it | Conceded; the subject rule re-derived: free only where every build re-establishes it (a law determines it, or the machine under its laws and the suite). The evaluator is specification, its values resting on B4 on the build that froze it | **Yes:** `frozen.txt`'s subject list; `EvalBranch` |
| Neon 3: `policyText` could filter future windows; `startAdmission` and the start's fields unbound; a shadow field | The policy literal is written by the check and `windows` reads it directly (a filter changes the print); the start is specification; the state's constructor is printed (through `recast` and `initialState`), so any added field changes the print | **Yes:** `PolicyFilter`, `ShadowField` |
| Neon 5: usability | Roots at the laws B3 names, not every theorem of `Laws.lean` (conceded). The constructor coupling is the stated cost of observers that build the state. The tactic list stays the forms in use, reviewed as walls arrive: with evaluation closed by the name rule, a new form's review is only whether it directs compilation | **Yes:** roots |
| Study 2's routing (round 13 list, replacing round 12's) | KERNEL.md A18: a copy is a whole main-dex `meta` with its request, rules only from a whole entry, an end only by the flag; `R_SETTLEMENT_MISSING` kept distinct. V13: an acknowledged `trades` subscription delivers every print, books paired at routing. Brief 3's recorders table. A12, K1 and step 10: the funding's reserve. Withdrawn by study 2's architect: round 12's reader liveness rule and A13's identity holding `events` | **Yes:** the forward reader's listings rule; `confirm`'s cut of a buy |

**Refuted:** Neon's remark that L5 only constrains `bind` (its two clauses fix every result `bind` returns); Neon's shadow field (the constructor was already printed, through `recast`).

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| The toolchain reading (three entry points; each `evalConst` call site's trigger) | Derived from the source and experiments; awaiting GPT and Neon | **Yes**, if a trigger is missed: the name rule or the lists change |
| The machine as a subject | Kept: its laws and suite rerun on every build. Neon's principle, read strictly, would freeze it too, and make each later step a restatement | **Yes**, `frozen.txt`'s scope, if a reviewer shows a judged path the suite cannot rerun |
| The machine's records after the start (log, coins in view, cycle records, C2's running fields) | Stated as held by tests; P1 (step 9) closes the fills | Not before step 9 |
| Study 2's reserve and listings rule | Under review on study 2's side; the kernel follows | Only if that review changes them |
| O26 | Open only for study 2's fitted trigger (unchanged) | Only if that trigger misses B5 |

**Would any open point change what is built?** Yes: step 5x waits for GPT's and Neon's reads of this round, since round 13 changed the design at the boundary.

### Committed criteria: reported, not edited

None touched by the kernel half. The reserve needs CS2.1's dated revision, which study 2's half drafts.

### Assumptions only the human can choose

None.

### Owed

- **By GPT and Neon (Neon with the step 5 Lean in its bundle):** the checks below.
- **By the advisor:** once this converges, route step 5x as brief 3 says.

### What GPT and Neon should check next

1. **The toolchain reading.** Another way the pinned 4.34.0 runs compiled code while it builds (an `evalConst` call, the interpreter, the kernel's native reduction, an initializer, a process) that a listed form, or a name the rule admits, reaches.
2. **The name rule.** A way to reach a constant under `Lean`, or `autoParam`, without writing it: dot notation, an `Init` abbreviation, unification, instance resolution, a structure field's default.
3. **The tree the check writes.** A file Lake reads that the check did not write (the manifest, the toolchain file, a build directory), or a module the check and Lake resolve differently.
4. **L0.** A completed run that is not observed, or whose ticks differ from the clock, under L0 as stated; whether `finish` of `runMoves` is the run X1 ties.
5. **The subject rule.** A subject whose law does not determine it everywhere it is called (`Ledger.step` outside A1's premises, `admit`'s reason when two conditions fail), and whether the machine should stay one.
6. **Study 2's changes as specified:** the listings copy, and the reserve in K1 and step 10's test 2 figures.

### Convergence

**Not yet converged.** Round 13 re-derived the boundary from the toolchain's own entry points after a construction no reviewer had named, so another round on another model is due.

## The last pass, round 14, kernel: the fresh Opus review of round 13's build boundary, and GPT-6.2's part B

Appended 2026-11-22 07:59 UTC (02:59 EST) by Claude Opus 5.5 at maximum effort, the architect for round 14's kernel half, answering `audit/reviews/2026-11-22-opus-round13-kernel-boundary.md` (a fresh Opus session in GPT's place, labeled as `CLAUDE.md`'s fallback, since OpenAI's filter refused part A three times) and part B of `audit/reviews/2026-11-22-gpt62-round13-kernel.md`. Revisions on `rearchitecture`: `9fb48c5` (the boundary), `c59a67c` and `b1e7573` (part B), and this commit, revising `kernel-v2.md` (A3, A12, V13, B1, B2, B3, part G), `kernel2/KERNEL.md` (A19) and brief 3 (steps 5x, 5a, 6, 10, the recorders table). Computations under `~/.cache/mm-r14k/`. Study 2's half of round 14 is the other architect's, on `rearchitecture-s2`. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r14-kernel-report.md`.

### In plain words

- **The build boundary's reasoning held under a fresh adversarial review, with one real hole.** The reviewer built a library that kept its own copy of the protected-dates list, one day short, and left the generated copy unused: every check passed and the compiled engine had the hole. The cause was that round 13 tied the dates to a file when what matters is the value the engine reads. Now the check, after the build, requires that value to be the file's bytes exactly. Two smaller points are closed with it: a module's name must be plain, so that a name and its file are one-to-one, and the check and the build start from an empty environment, so no inherited search path can put another standard library ahead of the pinned one.
- **The laws now read the engine only through what it did.** The laws about orders observe a run through a log the engine writes about itself. GPT-6.2 found three places where a law read the engine's own account instead of its deeds: the check that a run completed read the summary's text one way while the program that publishes read it another; the wishes the engine owed at a deciding tick were counted from the coins its own log said were in view, so an engine that marked none and skipped the tick owed none; and the record of an arrival held the book a function returned, not the book the engine then held. One cause, three rules: what a law requires comes from the inputs and the specification; what it checks is the state the engine actually moved to; and "the run completed" is one typed value, read alike by the publisher and the law.
- **The test ledger's law now says exactly what it buys.** It had stated only bounds (never overdrawn, keeps its reserve), which a confirmer that bought too little would also meet. K1 now writes the whole calculation out, and step 10's examples are recomputed under the reserve: the verdicts do not change, the figures do (a few had been computed before the reserve existed, one more than GPT named).
- **Smaller fixes:** the reader brief now defers to the market spec on listings (a coin missing from one copy keeps its rules), and the record's completeness assumption says plainly that after a trades subscription drops, the last book is still read for up to `G` while prints are not recorded.

### Who has seen what

- **The fresh Opus reviewer** read round 13's boundary at `828a971` and built its constructions on the pinned 4.34.0. It has not seen round 14.
- **GPT-6.2** read part B of round 13 (part A refused by its provider's filter), and has not seen round 14.
- **Neon**'s read of round 13 is queued with the human (web bundle); it has seen neither round 13's answers nor round 14.

### Agreed

- The boundary's derivation (the fresh Opus review): compiled code runs while building only at `evalConst` (with `[init]`), at the kernel's reduction of `Lean.reduceBool`/`reduceNat`, and at imported initializers; every `evalConst` site is reached by a form, by an `autoParam` type or by a name under `Lean`; the name rule suffices for 4.34.0; `include_str` off the list; the tree the check writes as the build's only source; modules rejected for the reason round 13 gave.
- The frozen start, evaluator, observers, numerical vocabulary and C symbol bindings; the subject fix route (a reviewed restatement for specification, a law proved again for a subject); the machine kept editable under its laws and suite (GPT-6.2, settling round 13's open point).
- The funding's reserve and step 10's test 2 (0.464 of B, 0.036 of cash); A18's per-coin listings and V13's routing assumption (GPT-6.2).

### Settled by derivation in round 14 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| Opus 1: the policy literal bound a file, not the constant `windows` reads (built: a one-day hole, frozen print byte-identical) | After the build, the frozen-surface clause requires `Engine.Machine.policyText` to be a definition whose value is the string literal of the policy file's bytes, wherever declared; the generated module stays as the literal's way into the build (kernel B2) | **Yes:** one comparison in the frozen-surface clause; fixture `PolicyShadow` |
| Opus 2: `.`/`..` import components (no outcome found) | Adopted: each component ASCII letters, digits and `_`, beginning with a letter, so a name and Lake's path are one-to-one and "a module of that name" is exact | **Yes:** one rule; fixture `DotComponent` |
| Opus 3: wording | "No compiled code" (the kernel's reduction is what proofs are); the inline `evalConst` site list deleted rather than completed, since every site is reached through the three triggers; `native_decide`, `decide +native` and `bv_decide` are forms through `evalConst` in 4.34.0; the check and Lake start from an empty environment with named variables only | **Yes**, the environment: the build step's `env -i`; a behaviour test under a scratch `LEAN_PATH`/`LEAN_SYSROOT` |
| GPT-6.2 B, the common cause of its three design findings: the laws read the machine's account of itself | Three rules (kernel B2): a law's obligations are the inputs' and the specification's; a record a law checks is the projection of the state the run continues from; completion is one typed value. Applied to every read of R1, S1, X1, L0 and L1a; what remains the machine's word is listed (a step's kind and a fill's units, the evaluator's values and so the wishes' values, C2's four running fields) | **Yes**, as below; step 5x gains sub-step 2, the observation (six sub-steps) |
| GPT-6.2: L0's completion predicate disagreed with production's | `finish` returns `Except Fault Summary`; `FinishResult` carries `ok` beside A19's JSON of it, written by one function; OCaml publishes by `ok`; `orderRun` and L0 read it (KERNEL.md A19) | **Yes:** the outcome type, the flag, the C stub, `mm2 finish`, step 5a's spool rename; fixture `SummaryText` |
| GPT-6.2: a logged tick not tied to a decision | `slotKeysAt` reads the moves (A17: a coin is in view until its listing's end is known), so R1 alone holds every deciding tick to its wishes and no law reads the log's ticks; L0's clock clause binds `snapshots`, the records L1a compares; round 13's `tickTimes` deleted, unbuilt | **Yes:** `slotKeysAt`'s restatement and R1's first clause proved again through the view; L0 restated; fixtures `ViewSkip`, `SnapshotDrop` |
| GPT-6.2: `Orders.arrive`'s effects not pinned | Neither of GPT's options as offered: freezing `arrive`, or making R1 fix its tags, leaves the same gap one function over (`arrivalEffects`, the machine's, reads the tags). The arrival's record holds the world's book after the effects, so R1's existing clause binds what production did; `arrive` is reclassified as a transition of the machine | **Yes:** the record's `after`; R1's arrival clause proved again by one lemma (the effects applied to the account give `arrive`'s book); fixture `ArriveTags` |
| GPT-6.2: K1 an inequality | K1's first clause is A12's fold written out; its old clauses follow from it; A12's text exact (the least of the scale's units and the reserve's room, then whole lots; a sale lowers what was paid by the fraction of its units actually sold) | **Yes:** K1's statement at step 10 |
| GPT-6.2: step 10's pre-reserve figures | Test 1: 0.04 and 0.04. Construction A: wealth 409.6, at the bid 0.9995; with bids following 409.2 (bar 18.64, verdicts unchanged). Test 5, which GPT did not name, was a wholly invested ledger the reserve forbids: restated at `φ = 1/2` (1.00981 and 0.99010; 1.00250 and 0.99502). Exact, `~/.cache/mm-r14k/` | **Yes:** test expectations |
| GPT-6.2: brief 3 step 6 against A18; V13's wording | Step 6's test 13 defers to A18 and tests the per-coin fallback; kernel A3 points to A18; V13 and the recorders table: pairing decides which books are recorded, and the last paired book is read until `G` passes | **Yes**, step 6's tests; V13 is text |

**Noted, not pressed (GPT-6.2):** X2 leaves scales above 12 open on the generic wire; R1 admits either reason when margin and cap both fail. Neither can change a judged result.

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| The observation's three rules and their application | Derived here; no reviewer has seen them | **Yes**, if a reviewer finds a law obligation still taken from the machine's record, or a checked record that is no projection of the continuing state, beyond the listed ones |
| The boundary after round 14 | The derivation confirmed by the fresh Opus review (a fallback, labeled); the outside review queued (Neon: GPT's filter refuses the subject) | **Yes**, if a trigger or an aliasing route is missed |
| What remains the machine's word (a step's kind and a fill's units; the evaluator's values and the wishes' values; C2's running fields) | Listed as held by review, tests and fixtures; P1 (step 9) ties the fills to the report's rows | Not before step 9; a law that ties one would be added at its step |
| `arithmetic.py.txt`'s `TestLedger` and `construction_a` | Predate the reserve on both branches; not edited here, since study 2's half edits the same file in parallel. `~/.cache/mm-r14k/k1_fold.py` is K1's fold, exact | No: test 6a's figures are stated in brief 3 from the exact fold; owed, below |
| O26 | Open only for study 2's fitted trigger (unchanged) | Only if that trigger misses B5 |

**Would any open point change what is built?** Yes: step 5x waits for the next reviewers' reads of round 14, since the observation's design changed (R1's first clause restated, a typed completion, an arrival lemma). No dispute with GPT-6.2 remains open on the reserve, the frozen surface or the subject route.

### Committed criteria: reported, not edited

None touched by the kernel half. K1's exact fold restates A12 and changes no criterion's meaning; the reserve's dated revision of CS2.1 is study 2's half's, as round 13 said.

### Owed

- **By the next reviewers:** the checks below.
- **By the advisor:** once this converges, route step 5x as brief 3 says (now six sub-steps); have `arithmetic.py.txt`'s `TestLedger` follow K1's fold, with `construction_a`'s printed figures, at the next edit that both halves' branches have merged.
- **By study 2's half:** `study2` decides publication by `FinishResult`'s flag, as `mm2` does, never by the summary's text (`KERNEL.md` A19); it reads `R_SETTLEMENT_MISSING` from the outcome's fault as before.
- **Routing:** the boundary (checks 1 and 2 below) goes to Neon or a fresh Opus, since GPT's filter refuses the subject; the observation (checks 3 to 6) changed the design, so it goes to a model other than GPT-6.2 first (Neon), and to GPT-6.2 after if Neon is short.

### What the next reviewers should check

1. **The policy constant** (Neon, or a fresh Opus): a value `windows` reaches other than `Engine.Machine.policyText`'s literal, such as a literal under metadata, a coercion, or a second constant the print shows by type alone.
2. **Names and the environment** (the same): a name and a path still two-to-one under the plain-component rule; a variable the build step must name for C compilation that also redirects Lean's or Lake's search.
3. **The three rules** (GPT on part B, and Neon): a law whose obligation still comes from the machine's record beyond C2's running fields; a checked record that is not a projection of the state the run continues from; a published run that L0's flag does not observe.
4. **R1 restated:** a run on which the inputs' coins in view (an ending known exactly at a tick, an ending among offers) differ from the machine's under A17, so that R1 is false of a correct machine; and whether the arrival lemma holds on `b94e128`'s `Acct.apply` (order of orders, remainders).
5. **L0 over `snapshots`:** a dropped or doubled tick that the clause misses; whether a run that aborts at step 7 (`R_SETTLEMENT_MISSING`) needs the clause stated otherwise.
6. **K1's fold** against A12, step 10's tests and study 2's `dip()` (`round13_study2`); step 10's recomputed figures.

### Open questions

None that only the human can decide. Judgments a reviewer may contest: binding an arrival through its record rather than freezing `arrive`; L0's clock clause read from `snapshots` rather than the log; restating R1 at step 5x rather than at a later step; leaving `arithmetic.py.txt`'s `TestLedger` to the advisor because both halves edit that file at once.

### Convergence

**Not yet converged.** The boundary's derivation stands, with one built hole closed at its cause; the observation was re-derived at the cause GPT-6.2's three findings share, which changes what is built, so another round on another model is due.

## The last pass, round 15, kernel: GPT-6.2's and Neon's reads of round 14, and study 2's routed changes

Appended 2026-11-22 09:12 UTC (04:12 EST) by Claude Opus 5.5 at maximum effort, the architect for round 15's kernel half, answering `audit/reviews/2026-11-22-gpt62-round14-kernel.md` and `audit/reviews/2026-11-22-neon-round14-kernel.md` (Neon's bundle whole), and folding in the kernel changes study 2's round 14 routes (`architect-r14-s2-report.md`, "Kernel changes", `rearchitecture-s2` `be858e5`). Revisions on `rearchitecture`: `cd1cb2e` to this commit. Experiments on the pinned Lean 4.34.0 under `~/.cache/mm-r15k/`. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read; `PROGRESS.md` and `audit/criteria.md` untouched. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r15-kernel-report.md`.

### In plain words

- **The build boundary had a real hole, and Neon found it.** The rule that keeps the build from running the library's own code refused two kinds of name, and a third kind reached the same machinery: Lean makes some names on demand, such as an equation lemma of `autoParam`, which appear in no file, and through one of them a library could again compile code no file holds. Built on the pinned toolchain, the proof says 4 and the compiled program says 999. The rule now refuses those names wherever they appear in a name, and the check no longer trusts a reading of the toolchain for which names are dangerous: it lists them from the toolchain itself, on every build. Neon also found that the release binary skipped the checks that run after the build; it now runs all of them.
- **The laws now read the run as one run.** Both reviewers found ways for the engine to do something wrong that no law sees, and they share one cause: the laws read separate records of single steps (a second copy of the clock's fold, an arrival's effect on the world without its effect on what the strategy sees, arrivals without their order, wishes without their content), never the run those steps make up. Now there is one observation, made by the code production runs, and the laws read it whole: what production publishes is exactly what the laws observe; the arrivals of one millisecond are checked in order, each from where the last left the book; each wish is checked against what the strategy computed at its tick; and a new law says that what the strategy sees of its own account is exactly the account one delay earlier.
- **"The run completed" is read the same way everywhere,** by three older laws too, which still read the text and would not have compiled against the typed result. The callers and tests that change with it are listed.
- **The test ledger's rule for a sale that flips the account short is fixed** (it sold twice what it held), its ending row is defined, and the reserve's guarantee is stated only of buys that buy.
- **Study 2's changes are in:** a delisted coin ends where its settlements stop and settles at its own price; listing copies are taken in the order they were fetched; prices off the rules get a stop code of their own; one JSON decoder.

### Who has seen what

- **GPT-6.2** read round 14's observation (its filter refuses the boundary). It has not seen round 15.
- **Neon** read round 14 whole, boundary and observation. It has not seen round 15.

### Agreed

- The typed completion flag, the world's book after an arrival, `slotKeysAt` from the inputs (GPT-6.2, Neon); K1's recurrence (GPT-6.2); step 10's recomputed figures, each reviewer by its own exact arithmetic; step 6's per-coin fallback and V13's wording.
- The policy constant bound as the constant `windows` reads, plain import components, the build's empty environment, and the frozen-surface split (Neon).

### Settled by derivation in round 15 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| Neon 1: the name rule admitted `autoParam.eq_def` | Built on 4.34.0 (`~/.cache/mm-r15k/autoparam/N1.lean`), with `b94e128`'s forms and dot constructors: no identifier with `Lean` first or `autoParam` last; the kernel proves `g = 4`, the compiled `g` returns 999. The cause: the rule read the names written, while a trigger is reached through any constant whose statement holds one with an argument a binder chooses, a reserved name realized on demand included. The rule refuses `Lean` or `autoParam` as any component; the source check walks the environment it imports (types, definitions' values, aliases) and fails unless every constant exposing an open trigger is refused. On 4.34.0: 66,152 constants and 139 aliases, finding only `Lean.ofReduceBool` and `Lean.ofReduceNat` beside the triggers (`audit.lean`, `aliases.lean`) | **Yes:** the rule; the walk; fixtures `EqDef`, `ExposedTrigger` |
| Neon 6: the release binary skipped the clauses after the build | The shared engine build runs all four clauses in one derivation, and `checks.engine-proofs` is that build; it names no `LEAN_CC` or `LEAN_AR` | **Yes:** `mm2For`'s build |
| The cause GPT-6.2's and Neon's observation findings share | A fourth rule (kernel B2): one observation, `orderRun`, whose records the transitions make as they run, read as one run | **Yes**, below |
| GPT-6.2, Neon 2: L0's clock and L1a on `snapshots`, a second fold | Each tick records itself in the run's records; L0 ties production's flag to the observation both ways and reads the clock off `run.ticks`; L1a over `orderRun`; `snapshots` and step 5a's `fireNoRec` twin deleted; an abort is unobserved and unpublished (step 7, wall 3) | **Yes:** `TickRecord` in the records; L0, L1a restated; fixtures `TickDrop`, `NonDecidingSkip` |
| GPT-6.2: R1 over raw `known`, which `pack` cuts to 64 bits | C1's wire premise on R1 and L1a | **Yes:** two premises |
| GPT-6.2, Neon 3b: the effects queued for the view | **L1c ★, new:** at every tick the world's account is the view's with the queued effects applied in order, each known `δ` after it was made and after the tick | **Yes:** L1c; the record's account, world and queue; fixtures `QueueDrop`, `LateRelease`; `tickWorlds`, `history`, `sampleAt` deleted |
| GPT-6.2: the order of one millisecond's arrivals | R1: they are in A6's order and chain, each one's book before the last one's after; R1's clauses on the order of admissions and of placements, the chain's consequences, deleted | **Yes:** R1 restated; fixture `ArrivalOrder` |
| Neon 3a: wish payloads free; B2's claim that B4 held them | R1: each wish is `wishAt` of its tick's record (the evaluator's reading of the slot, the program's side, `reduce_only` and `tif`, the view account's cycle). B2's claim was false (B4's programs have no slots) and is corrected | **Yes:** `wishAt`; fixtures `WishInactive`, `WishCycle` |
| GPT-6.2, Neon 5: the typed `finish` against frozen C1, C2 and L1a | All three restated in sub-step 2, each reading the flag; C2's rejected run has it false, whatever earlier chunks spooled; every caller and test to migrate named | **Yes:** the restatements and the migration |
| GPT-6.2: the headline | B2's list of what is the machine's word: a step's kind and a fill's units, an effect's time stamp, the evaluator's stepping on the view's inputs, C2's four running fields, and which stop a run is, with the admission of valid events | Text |
| GPT-6.2, Neon 4: K1 | A sale of more than the position sells all the ledger holds; the ending row counted first, as architecture 6.1 counts it; the reserve after a buy that buys | **Yes:** K1's statement at step 10 |
| GPT-6.2: step 10's ask | 3,411.1, recomputed | Text |
| Study 2's routed changes | A18: the end where settlements stop, settling at the coin's price, the record holding none, later events cut, its hour not due; copies in acquisition order; `R_OFF_RULES`, admission's rule-free checks first; `jsont`; the reserve's wording; the recorders' table. Settlement at zero is unreachable, so its tests and clauses are deleted | **Yes:** the ending's payload (in C2's restatement), step 6's reader and admission, step 7's settlement |

**Noted, not pressed (Neon):** a fault for `known < time` in C2: admission rejects `known < time + lag` already, and R1 and L1a, proved on every build, fail on a machine that admits one, so the clause adds no assurance. Rejecting compiler-internal prefixes: the walk decides, and on 4.34.0 it finds none. `w.cycle > b.cycle` in `arrive`: with R1's payload clause and L1c a wish's cycle is the view's, never above the world's.

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| The fourth rule and its application (one observation, L1c, R1's payload and chain) | Derived here; no reviewer has seen it | **Yes**, if a reviewer finds a law reading a second record of one step, or a value production carries from one step to a later one that no law reads at both ends, beyond B2's list |
| The boundary after round 15 | Built and audited here; no reviewer has seen it | **Yes**, if a trigger is reached in a way the walk does not see |
| A stop's code | Held by tests (`KERNEL.md` A18; step 6's test 15, step 7). A law could pin it in C2's restatement: an event rejected with `R_OFF_RULES` exactly when rules a listing could give would admit it | **Yes**, if a reviewer shows a mislabel that changes a verdict: C2 gains that clause in sub-step 2 |
| The ending record's `known` | Derived here: the later of its hour plus the listings' lag and the flagging copy's time | **Yes**, if study 2's half dates it otherwise |
| `arithmetic.py.txt`'s `TestLedger` and `construction_a` | Predate the reserve and the sale's fix; `~/.cache/mm-r15k/k1_fold.py` is K1's fold | No |
| O26 | Open only for study 2's fitted trigger (unchanged) | Only if that trigger misses B5 |

**Would any open point change what is built?** Yes: step 5x waits for the next reads, since the observation's design changed again (one observation, L1c, R1's payload and chain) and so did the boundary's rule.

### Committed criteria: reported, not edited

None touched by the kernel half. Study 2's routed end rule and its stop codes change what stops a forward run, which study 2's criteria and their dated revisions answer.

### Owed

- **By the next reviewers:** the checks below.
- **By the advisor:** once this converges, route step 5x as brief 3 says (sub-step 2 now adds L0 and L1c and restates R1, L1a, C1 and C2); have `arithmetic.py.txt`'s `TestLedger` follow K1's fold, the reserve and the sale of more than the position both, at the next edit both branches have merged.
- **By study 2's half:** confirm the ending record's `known` as A18 now dates it; a fold of study 2's that sells by fraction sells all at a sale of more than the position; the runner reads the stop codes as A18 lists them; any "settled at zero" case left in study 2's texts is unreachable now that a listing settles at the coin's price.
- **Routing:** the boundary (checks 1 and 2) to Neon, or a fresh Opus, since GPT's filter refuses it; the observation (checks 3 to 6) to GPT-6.2 and Neon, neither of which has seen round 15.

### What the next reviewers should check

1. **The walk.** A constant or alias it misses that reaches `autoParam`, `Lean.reduceBool` or `Lean.reduceNat`: a reserved-name family (`.eq_N`, `.induct`, `.fun_cases`, a matcher's splitter) whose statement exposes an open trigger that its realizing constant's type and value do not hold; an elaborator path that evaluates at a binder type other than `autoParam`.
2. **The shared build.** A derivation that links the engine without the clauses after the build.
3. **One observation.** A law still reading a record not made by the transition it records; a value production carries from one step to a later one that no law reads at both ends, beyond B2's list.
4. **L1c.** A run whose view account differs from the world's `δ` earlier while L1c holds, beyond an effect stamped late.
5. **R1 restated.** A wrong order of one millisecond's arrivals that passes the chain; `wishAt` against the machine's `wishFor` and `slotEvalAt`; whether the payload clause is provable from what the record holds.
6. **The stop codes.** Whether `R_OFF_RULES` and admission's order can change a verdict, and so belong in C2.
7. **Study 2's ending.** Its hour not due, its settlement at the coin's price, its `known`.

### Open questions

None that only the human can decide. Judgments a reviewer may contest: L1c as a ★ law rather than a test; deleting R1's clauses on the order of admissions and placements as the chain's consequences; leaving a stop's code to tests; the ending record's `known`; the walk run on every build rather than read once per toolchain.

### Convergence

**Not yet converged.** The boundary had a built hole, closed at its cause by a rule the build now checks against the toolchain itself; the observation was re-derived at the cause both reviewers' findings share, which changes what is built, so another round is due.

## The last pass, round 16, kernel: two-stage clean-compile boundary, unified effect-log & `marketAt` observation, and study 2's round 15 changes

Appended 2026-11-22 23:04 UTC (18:04 EST) by Gemini 4 Neon through agy, the architect for round 16's kernel half, answering `audit/reviews/2026-11-22-opus-round15-kernel.md` (fresh Opus 5.5 fallback reviewer), `audit/reviews/2026-11-22-neon-round15-kernel.md` (Neon on round 15's kernel half), and study 2's round 15 kernel changes (`/home/kevin/repos/moneymachine/data/builder/architect-r15-s2-report.md`, "Kernel changes"). Revisions on `rearchitecture`: `e71e67d` (merge `main`), `a503574` (study 2 round 15 changes, `R_OFF_RULES` erasure, Opus finding 3 and minor #3), `dfe0ae2` (two-stage clean-compile boundary, deleting the source guard), `14b1ab7` (unified effect-log & `marketAt` observation), and this commit. Experiments on pinned Lean 4.34.0 under `~/.cache/mm-r16k/`. Study 2's round 16 is the other architect's (Opus) on `rearchitecture-s2`; brief 4, `recorder/`, study 2's criteria texts, `PROGRESS.md` and `audit/criteria.md` untouched. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r16-kernel-report.md`.

### In plain words

- **The source-level build guard is deleted and replaced by a two-stage clean-compile boundary that fails closed on Lean 4.34.0.** Five consecutive reviews defeated the source syntax/name guard, ending with Opus's `N2.lean` showing command elaboration's `foApprox := true` opens all 220 `Init` constants holding a closed `autoParam` via field notation `@xs.insertionSort` (beside Neon's 2-hop wrappers and dot-methods on `Lean.<Type>`). A post-build attribute check alone is also unsound on 4.34.0 (`ToDecl.getDeclInfo?` prefers `declName._unsafe_rec` with zero attributes and zero kernel check against `declName`, built in `forged_unsafe_rec.lean`; plus `@[cpass]`, `@[cfold]` and `.olean` IR). The shared engine build now splits into two sandboxed Nix derivations under `env -i`: **Stage 1** runs untrusted `lake build` and exports only a plain UTF-8 hash-consed DAG of pure safe kernel declarations (`engine.kexp`, no `.olean`/`.ir`/`.c`/`.o`/`._unsafe_rec`); **Stage 2** starts from pristine `Init` + 12-line `CleanPrelude` alone (never importing Stage 1 `.olean`s), rejects reserved compiler suffixes (`_unsafe_rec`, `_redArg`, `_boxed`, `_closed*`, `_spec*`, `_lam*`, `_jp*`, `_override`, `_impl`, `main`) and forbidden constants, replays all declarations through Lean 4.34.0's C++ kernel (`Kernel.Environment.addDeclCore`), checks axioms, `policyText` against read-only `protected-windows.json`, and `frozen.txt`, regenerates inductive auxiliaries and `_sparseCasesOn` (modulo `mdata`), derives `projFn`/match-inline hints, synthesizes and **kernel-proves** structural `T.brecOn` recursions (with call-by-value strict-descent checking), validates `@[csimp]`/`@[export]`, clean-compiles from scratch (`Compiler.compile`, `LCNF.impureExt` reachability walk, `LCNF.emitC`, `leanc -O3`), and archives the sole Lean library linked into `mm2`. Verified end-to-end on `b94e128`: all 4,747 declarations kernel-replayed from pure text, 1,396 export-closure declarations clean-compiled in 5.2 s (compile+emit 2.9 s), all OCaml tests pass unedited (`strings_scale_test` 88,637 q/s; `scale_test` 6,655 q/s, 42.2 MiB RSS), and `N2.lean`, `ForgedUnsafeRec`, `SafeUnsafeRec`, `BadReservedRedArg` and `DuplicateDecl` are neutralized or rejected.
- **All four remaining observation gaps close at one root cause.** Recording the single chronological world effect log `run.effects` in `emitOne` and reading the world's market state (`rules`, `ended`, `bid`, `ask`, `price`, adverse marks) from the input moves via specification `marketAt` closes Neon finding 1 (`EarlyViewApply`: L1c now requires an exact `l.time + δ ≤ r.time` / `r.time < l.time + δ` prefix split of `run.effects`), Neon finding 2 (`EmptyAdmissions`: R1 binds `run.admissions` directly to `run.arrivals.filterMap` via `arrivalAdmission`), Neon finding 4 (`UnnecessaryReplace`: R1 binds `a.before`/`a.after` to `bookFrom` of `marketAt` and `acctAt` over `run.effects`, binds `[a.effectStart, a.effectEnd)` to `arrivalEffectsOf` stamped at `a.time`, and requires every effect in `run.effects` to belong to an arrival slice, a rule-changing `.listing` move via `rulesChangedAt`, or a `CycleStep` fill/cycle-end matching `acctAt`), and Opus finding 2 (`StaleMark`: `a.before`'s market state is `marketAt`, never the machine's word).
- **Study 2's round 15 changes folded in and `R_OFF_RULES` erased.** Study 2 deleted the hold class so every stop ends the test via `FinishResult.ok = false`; `R_OFF_RULES` and admission's rule-free-first check order are deleted (`CLAUDE.md` §2), closing Neon finding 5 without adding a stop-code clause to C2. A18 adopts reach `R`, `ending.known = max(R, t_F) + listings.lag` (Opus finding 3), `recv` copy timing, the three-pass `jsont` decoder, unreadable-print withholding, and vault/funding page rechecks.

### Who has seen what

- **Fresh Opus** reviewed round 15's kernel half (`78a35a3`); it has not seen round 16.
- **Neon** reviewed round 15's kernel half and architected round 16's kernel half (so Neon will **not** review round 16; a fresh Opus will, plus GPT on the observation if available).
- **GPT-6.2** has not seen rounds 15 or 16.

### Agreed

- Round 15's closures confirmed by both reviewers: typed `FinishResult.ok` across L0, C1, C2, L1a and OCaml; `orderRun` as the single observation with `snapshots` and `fireNoRec` deleted; L0's clock coverage; `wishAt` in R1; K1's flip-to-short sale, ending row counted first, and reserve invariant on positive buys; shared engine build derivation under `env -i` excluding `LEAN_CC` and `LEAN_AR`; A18's delisting at where settlements stop, settling at the coin's price with no price in `Payload.ending`.
- Study 2's round 15 deletion of the hold class (`R_OFF_RULES` erased, closing Neon finding 5 at its cause), reach `R` with qualifying flagging copy `e`, `recv` copy timing, three-pass `jsont` decoder, unreadable prints, and vault/funding page rechecks.

### Settled by derivation in round 16 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| Opus 1; Neon 3, 6: source guard defeated a fifth time (`N2.lean`, `foApprox := true` opening 220 `Init` `autoParam` constants via `@xs.insertionSort`; 2-hop wrappers; `Lean.<Type>` dot-methods) and post-build attribute check defeated by `forged_unsafe_rec.lean` | Source guard (`check-source.lean`, `syntax.txt`, `Init` trigger walk, generated `Engine/PolicyText.lean`) deleted (`CLAUDE.md` §1, §2). Replaced by two-stage Nix-sandboxed clean-compile boundary (`engineExport` -> plain UTF-8 DAG `engine.kexp` -> `engineClean` starting from pristine `Init` + 12-line `CleanPrelude`, rejecting reserved compiler suffixes and forbidden constants, full `Kernel.Environment.addDeclCore` replay, axiom/policy/`frozen.txt` checks, regenerated auxiliaries + `_sparseCasesOn` modulo `mdata`, derived `projFn`/match inlines, synthesized + call-by-value strict-descent checked + kernel-proved `T.brecOn`, validated `@[csimp]`/`@[export]`, `Compiler.compile`, `LCNF.impureExt` reachability walk, `LCNF.emitC`, `leanc -O3`). Empirically verified end-to-end on `b94e128` (`~/.cache/mm-r16k/clean_compile/`) | **Yes:** `kernel2/clean-build/` (`CleanPrelude.lean`, `stage1-export.lean`, `stage2-clean.lean`), two-stage `mm2For` derivations, and updated `checks.engine-proofs-fixtures` (sub-step 1) |
| Neon 1: L1c allowed early view delivery (`EarlyViewApply`) | `emitOne` logs every effect to `run.effects : List Logged`; `TickRecord` gains `effectCount`; L1c enforces monotone `run.effects`, `l.known = l.time + δ`, and exact split of `run.effects.take r.effectCount` at `l.time + δ ≤ r.time` into `r.account` and `r.queue`, with `r.world = acctAt initial run.effects r.effectCount` | **Yes:** `Log.effects`, `Run.effects`, `TickRecord.effectCount`, L1c restated, fixture `EarlyViewApply` (sub-step 2) |
| Neon 2: `run.admissions` and `run.placed` untied to `run.arrivals` (`EmptyAdmissions`); redundant `w.cycle ≤ b.cycle` premise on `arrive` | R1 binds `run.admissions = run.arrivals.filterMap (fun a => arrivalAdmission a.before a.wish)` alongside `run.admissions.filterMap (admit ·).toOption = run.placed.map (·.order)`, making both deleted `Pairwise` clauses genuine corollaries; drops `w.cycle ≤ b.cycle w.coin` from `arrive`'s characterization | **Yes:** `arrivalAdmission`, R1 restated, fixture `EmptyAdmissions` (sub-step 2) |
| Neon 4: `a.before` untied across timestamps (`UnnecessaryReplace`) | `Arrival` and `CycleStep` gain `effectStart`/`effectEnd` (`applyPayload (.listing)` also logs a `.other` `CycleStep` on rule-change cancels); R1 binds `a.before`/`a.after` to `bookFrom` of `marketAt` and `acctAt` at `effectStart`/`effectEnd`, binds `[a.effectStart, a.effectEnd)` to `arrivalEffectsOf a.before a.wish` stamped at `a.time`, chains `a.effectEnd ≤ b.effectStart` (`=` on equal time), and requires every effect in `run.effects` to belong to an arrival slice, a rule-changing `.listing` move (`rulesChangedAt`), or a `CycleStep` fill/cycle-end matching `acctAt` (`bookMatchesAcct`) | **Yes:** `Arrival`/`CycleStep` indices, `acctAt`, `rulesChangedAt`, `arrivalEffectsOf`, `bookMatchesAcct`, R1 restated, fixture `UnnecessaryReplace` (sub-step 2) |
| Opus 2: `a.before`'s market state (adverse marks, rules, ended coins) unbound (`StaleMark`) | Bound in R1 by specification `WorldMarket`/`marketAt`/`bookFrom` over the input moves (`rules`, `ended`, `bids`, `asks`, `prices`, adverse marks), matching `worldBook` identically at every arrival time | **Yes:** `WorldMarket`/`marketInit`/`marketEvent`/`marketAt`/`bookFrom`, R1 restated, fixture `StaleMark` (sub-step 2) |
| Neon 5 & Study 2 #4: `R_OFF_RULES` stop code in C2 | Study 2 round 15 deleted the hold class (every stop ends the test via `FinishResult.ok = false`), so no stop code changes a verdict; `R_OFF_RULES` and admission's rule-free-first order erased from `KERNEL.md` A18, `kernel-v2.md` B2 and brief 3 step 6 | **Yes:** `R_OFF_RULES` deleted from step 6's admission |
| Opus 3 & Study 2 #1–#3, #5–#9: A18 listing end `R`, `ending.known`, copy timing, three-pass `jsont`, unreadable prints, vault/funding rechecks, recorders' table | Adopted reach `R` with qualifying flagging copy `e`, `ending.known = max(R, t_F) + listings.lag` (guarding `t_F` against host-clock skew and matching every other copy-carried change), `recv` copy timing, three-pass `jsont`, unreadable-print withholding, and vault/funding page rechecks across `KERNEL.md` A18, `kernel-v2.md` A3/V13/B2 and brief 3 steps 2, 6, 7 and recorders' table | **Yes:** step 6 reader and step 7 settlement |
| Opus minors #1, #2, #3 | B2 names `age`/`vage` explicitly in the evaluator-input exception; B2 clarifies C1 and C2 read `feed`/`finish` directly while order/tick/delivery laws read `orderRun`; brief 3 step 10 line 575 updated to "all or more" | Text only |

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| Two-stage clean-compile boundary (`engineExport` -> `engine.kexp` -> `engineClean`) | Derived and empirically verified on `b94e128` here; no reviewer has seen it | **Yes**, if a reviewer finds a compiler input, name collision, recursion edge case, or Stage 2 soundness gap |
| Unified observation (`run.effects`, `marketAt`, `bookFrom`, `rulesChangedAt`, `arrivalAdmission`, `arrivalEffectsOf`, L1c & R1 restated) | Derived here; no reviewer has seen it | **Yes**, if a reviewer finds a valid run where an arrival's market state or effect ordering disagrees with `marketAt` / `run.effects`, or an unbound mutation that still evades R1/L1c/S1 |
| Study 2 half adoption of `ending.known = max(R, t_F) + listings.lag` | Routed back to study 2's half (Opus finding 3) | Reader only (`briefs/4-study-2.md` / `recorder/` consistency) |
| Residual Nix sandbox limits (unsandboxed local `lake build`, Stage 1 resource DoS inside Nix build, under-constrained subject body passing all laws/frozen spec/tests, Stage 2 TCB) | Documented explicitly in `kernel-v2.md` B2 | No (inherent trust boundary) |
| `arithmetic.py.txt`'s `TestLedger` and `construction_a` | Still predates reserve/sale fixes; owed to advisor after branch merge | No |
| O26 | Open only for study 2's fitted trigger (unchanged) | Only if that trigger misses B5 |

**Would any open point change what is built?** Yes: both the two-stage clean-compile boundary (sub-step 1) and the unified effect-log/`marketAt` observation (sub-step 2) are newly designed in round 16 and await adversarial review by a fresh Opus session (and GPT-6.2 on the observation if routed) before step 5x is built.

### Committed criteria: reported, not edited

None touched by the kernel half (`audit/criteria.md` untouched).

### Owed

- **By the next reviewers:** the checks below (fresh Opus on both boundary and observation; Neon architected round 16 and does not review it).
- **By study 2's half:** confirm the one-line `ending.known = max(R, t_F) + listings.lag` update (Opus finding 3, adopted in `KERNEL.md` A18).
- **By the advisor:** once round 16 converges, route step 5x (now with two-stage clean-compile in sub-step 1 and unified effect-log/`marketAt` observation in sub-step 2), and update `arithmetic.py.txt`'s `TestLedger` after branch merge.

### What the next reviewers should check

1. **Stage 2 clean-compile soundness (fresh Opus):**
   - Any Lean 4.34.0 compiler input, environment extension, `mdata` tag, or magic name suffix not covered by Stage 2's pristine `Init` + `CleanPrelude` environment, `mdata` stripping, and reserved-suffix pre-replay filter.
   - `synthAndVerifyBrecOn`: try to construct a malicious `T.brecOn` (higher-order/curried recursion, dead strict-evaluation argument, nested/reflexive inductive, `_sparseCasesOn` mismatch, universe polymorphism) that passes `checkStrictDescent` and the kernel unfolding theorem while diverging or returning a wrong value in compiled C.
   - `@[csimp]` and `@[export]` validation: try to construct a Stage-1 `@[csimp]` or `@[export]` payload that creates a cycle, overrides `Init`/`CleanPrelude`, breaks topological compilation order, or collides with a C/Lean runtime symbol.
   - `stage2-clean`'s `engine.kexp` parser and `Kernel.Environment.addDeclCore` replay: check `InductiveVal` (`isRec`, `isReflexive`, `numNested`, mutual inductives), `RecursorVal` verification, and `policyText` kernel literal check.
2. **Unified observation — L1c & R1 (fresh Opus, and GPT-6.2 if routed):**
   - `marketAt initial moves a.time` vs `worldBook s a.time`: try to construct a valid run (including same-millisecond events, `λ = 0`, `δ = 0`, offers between events, listings/endings/trades/quotes) where `marketAt` disagrees with `worldBook` at an arrival time, or where `rulesChangedAt` misses/mislabels a rule-change cancel.
   - `run.effects` monotonicity (`Pairwise (· ≤ ·)`) and L1c's `emitted` prefix split: check `δ = 0`, `λ = 0`, and `EarlyViewApply`.
   - `UnnecessaryReplace` and effect provenance in R1: try to construct a rogue order cancel, drop, or reorder that passes R1, L1c, S1, X1, L0, L1a, and `frozen.txt`.
   - `run.admissions = run.arrivals.filterMap (arrivalAdmission · ·)`: check that every admitted/refused arrival matches `arriveWish` exactly and no edge case breaks provability.
3. **Study 2 round 15 fold-in:** verify `KERNEL.md` A18's `ending.known = max(R, t_F) + listings.lag`, reach `R`, `R_OFF_RULES` erasure, and brief 3 step 6/7 wording against `architect-r15-s2-report.md`.

### Open questions

None that only the human can decide. Design judgments a reviewer may contest:
- Accepting the ~4.5 min Stage 2 single-threaded full kernel replay time on `b94e128` (dominated by `Engine.Laws`'s `decide +kernel` witness proofs, cached by Nix per source input; compile+emit itself is 2.9 s) rather than refactoring the `decide +kernel` witnesses.
- Synthesizing and kernel-proving `T.brecOn` recursions inside `stage2-clean.lean` (keeping `b94e128` 100% unedited) rather than forbidding structural `brecOn` recursion in library code.
- Keeping `Engine/Policy.lean`'s `include_str "../protected-windows.json"` (relying on Stage 2's kernel literal check against read-only `protected-windows.json` and Nix's Stage 1 sandbox) rather than maintaining a generated `Engine/PolicyText.lean`.
- Keeping `s.time` of fill/cycle-end effects and `vage` (`age`) in B2's test/review-held exception list before step 6 F0.

### Convergence

**Not yet converged.** Round 16 re-derived the build boundary from scratch (deleting the source guard in favor of the two-stage clean-compile boundary) and unified the observation laws around `run.effects` and `marketAt` — both change what is built in step 5x sub-steps 1 and 2, so a fresh Opus adversarial review is due.

## The last pass, round 17, kernel: the boundary on constructions, R1 for the whole machine, and study 2's round 16 changes

Appended 2026-11-23 by a fresh Claude Opus 5.5 at maximum effort, the architect for round 17's kernel half, answering the fresh Opus's review of round 16 (`audit/reviews/2026-11-22-opus-round16-kernel.md`, findings 1 to 6) and folding in study 2's round 16 kernel changes (`/home/kevin/repos/moneymachine/data/builder/architect-r16-s2-report.md`, "Kernel changes"). Revisions on `rearchitecture`: `85f3489` (`gate/control/` deleted, study 1's code being archived and not merged), `ffe72cf` (merge of `main` at `b2515f0`), `66c593b` (the boundary), `bbd4652` and `40c0540` (R1's partition for the whole machine; S1 restated), `753cbd0` (study 2's round 16 changes), `66a1c1e` (the deletion of `arithmetic.py.txt`'s ledger model, the human, 2026-11-22), and this commit. Experiments under `~/.cache/mm-r17k/` on pinned Lean 4.34.0. Brief 4, `recorder/`, study 2's criteria texts, `PROGRESS.md` and `audit/criteria.md` untouched. No market data from 2026-11-01 on, nothing under `data/holdout/`, no token or key file read. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r17-kernel-report.md`.

### In plain words

- **The build boundary now rests on constructions, not on lists.** Round 16's second stage still trusted lists of the compiler's conventions (attributes, reserved names, suffixes), and the fresh Opus found two holes the lists missed, the fourth and fifth since the guard began: a subject keeping a hidden counter through Lean's `ST` primitives, which the laws proved constant and the binary incremented; and a library name equal to one the compiler's specializer makes, which swapped two functions' code. Round 17 replaces the lists with things that need no knowledge of the compiler's conventions. The compiler reads an environment whose every name Stage 2 gives (each library name with a final component `#`, which ends no name the compiler makes or looks up). What the compiled code reaches may hold no opaque primitive outside a short reviewed list, ten for the current engine and all pure (two `Float` roundings, five string operations, three fixpoints of `Init`), which shuts out every token of `ST` or `IO` state. The kernel runs no code while it checks, and the compiler's output is checked: panics are fatal and every declaration is recorded once. **What remains is said plainly:** that Lean 4.34.0's compiler, runtime and `Init` compute each kernel definition's value. No check here can establish that, and it is now the only trust, tried by B4's 3,120 streams, test 12 and the suites.
- **R1 now accounts for every effect of the whole machine, once.** Round 16's clause listed step 5's effects and ended in `False`, so step 6 would have broken it, and it allowed a rule change's cancels without requiring them. Round 17 states it for the whole machine: every effect has exactly one owner, a wish's arrival or a step; each kind of step has a fixed form (what it does, and to which orders and coins), written from A6, A7, A9 to A12 and A19; and a rule change's step exists exactly at each listing that changes a coin's rules. When each other kind of step happens is its own law's, stated over the run's steps both ways: F0 at step 6, and M1, L6, U1 for the machine and a new M2 (listing ends) at step 7, so R1 is not restated again. Until M1, a liquidation of a flat account written in the liquidation's form is not caught; no judged run comes before step 7, and step 7's review checks it.
- **Study 2's round 16 kernel changes are in:** copies timed by the venue's own clock (the reply's `Date`); a coin read by the entries of its name; only a flag dated from the forward start ends a listing; an event off the rules in force is dropped and counted instead of stopping the run, in one place, admission; the reader's print rule deleted for the recorder's pairing; prints and fills read one by one; the page rechecks; depth 65; the recorders' table.
- **The ending's knowledge time** (finding 6) is study 2's to decide: my view is below, routed.
- **`arithmetic.py.txt`'s model of the test ledger and the guard is deleted** (the human, 2026-11-22), with the parts of round 5, round 6, study 2's criteria and the confirming read that ran it; the file still runs to its end, and the documents that cited the deleted figures say so. Its run line is the human's with one change, said here as a divergence (`CLAUDE.md` §1): the flake is named `git+file:`. As written, `getFlake (toString ./.)` names a `path:` flake, which copies the whole directory into the store, `data/` (120 GB) included when run from the main worktree, and the disk filled while it ran there on 2026-11-23; `git+file:` copies tracked files only and gives the same pinned Python, numpy 2.4.4 and scipy 1.17.1. Test 12 identified its draw recipe by the whole file's hash, which the deletion moved, so `x4-hosts.sh` now reads the file as it stood at `3d7992e`, the commit that generated the corpus.

### Who has seen what

- **The fresh Opus** reviewed round 16's kernel half; it has not seen round 17.
- **Neon** architected round 16's kernel half and reviewed study 2's round 16; it has not seen round 17.
- **GPT-6.2** has seen none of rounds 15 to 17 (its filter refused the boundary).
- **This architect** built round 17 and does not review it.

### Agreed

- The fresh Opus's confirmations on round 16: `marketAt` is `worldBook`'s market at every arrival; L1c's split is `releaseEffects` with both bounds; `arrivalAdmission` and `arrivalEffectsOf` are `arriveWish`'s; the `brecOn` synthesis cannot change a value; `_sparseCasesOn` is compared with a real regeneration; `@[csimp]` replaces only by kernel-proved equalities; two derivations and a text DAG are needed; `R_OFF_RULES` is gone; the reach rule matches A12 and K2.

### Settled by derivation in round 17 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| Finding 2: names collide (`f._at_.g.spec_k`), and the compiler's lookups (`n._unsafe_rec`, `T._impl`, `main`) are names a library could take | **Stage 2 names the compile environment** (kernel B2, step 5): every library constant under its `engine.kexp` name with one final component `#` appended, constructors included; a library inductive's kernel recursors and regenerated auxiliaries under its new name. Read in 4.34.0's source (`ReduceArity`, `Types`, `ExtractClosed`, `LambdaLifting`, `Specialize`, `ToDecl`, `ToLCNF`, `ToMono`, `Main`): the compiler makes, and looks up, other declarations' names only by extending a name with components of its own, so no library-chosen name can be one of them. The reserved-suffix list and its two filters are deleted. The fresh Opus's uniqueness check alone would not have closed a consulted name (a safe `foo._unsafe_rec` beside `foo` is compiled once and recorded once) | **Yes:** sub-step 1's renaming map; fixtures `SpecName`, `SpecNameFirst`, `MainName`; `SafeUnsafeRec` neutralized instead of rejected |
| Finding 2: Stage 2 carried on after 120 to 198 panics | Panics fatal (`LEAN_ABORT_ON_PANIC=1` inside `env -i`), error messages fail, and the compiler's record checked: each declaration once, no auxiliary with the name of an environment constant it was not asked to compile | **Yes:** fixtures `CompilerPanic`, `CompiledTwice` |
| Finding 1: a safe subject keeps hidden state through `Void.mk` and the `ST.Prim` operations | **What the closure may reach** (kernel B2, step 5): walking kernel values from the exports and the `@[csimp]` targets, every opaque reached must be on the reviewed `primitives.txt`. An opaque is exactly where the kernel holds no definition for compiled code to be faithful to. Measured on `b94e128`'s build: 3,265 constants reached, ten opaques (`Float.ceil`, `Float.floor`, `String.Internal.append`, `.foldl`, `.isEmpty`, `.length`, `.pushn`, `Std.Format.be`, `Std.Internal.idOpaque`, `WellFounded.opaqueFix`), none stateful. The fresh Opus's allowlist of the 1,344 constants `b94.kexp` names would not do: `ST.Ref.get` is a definition, and its value reaches `ST.Prim.Ref.get` | **Yes:** the walk and `primitives.txt` in sub-step 1; fixtures `STToken`, `RunSTToken`, `LibmExp` |
| The kernel's native evaluation during replay | The pre-replay filter narrows to the four constants whose checking runs compiled code (`Lean.reduceBool`, `.reduceNat`, `.ofReduceBool`, `.ofReduceNat`); `trustCompiler` and `sorryAx` are left to the axiom check | Text and one filter |
| What remains | Said plainly in B2: the toolchain computing each kernel definition's value, and the ten primitives being the functions reviewed; no check here can establish it | No |
| A test linking the clean archive by Lean names | Nothing links it but through its exports (two compilations need not agree on a function's compiled signature, and Stage 2's names are its own): `x4-counts`, the diagnostic of the counts X6 proves, links Stage 1's archive; test 12's MPFR sweep runs through `mm2_lean`'s exports | **Yes:** `x4-hosts.sh` |
| Finding 3: R1's partition listed step 5's effects and closed with `False` | **The whole machine's partition** (kernel B3 R1; brief 3 step 5x): `Effect` takes A19's effects and `Trigger` A12's causes now (`fill`, `quote`, `rules`, `ending`, `funding`, `liquidation`); each effect has exactly one owner; a step's slice is `stepForm` of its trigger from the account it began at; steps 6 and 7 add laws and restate R1 not at all. Step 6's "R1 needs no new proof" is corrected | **Yes:** sub-step 2's types, `stepForm`, the one-owner clause; S1 restated in its match on triggers; fixtures `HiddenEffect`, `SharedEffect` |
| Finding 4: a fabricated liquidation of a flat account | Its `cycle_end` cancels fail the liquidation's form now; one written in the form passes until M1, which step 7 states over the run's `.liquidation` steps both ways. Round 16 closed Neon's `UnnecessaryReplace` for arrivals at 5x and for steps only when F0 and M1 bind their occasions | Fixture `LiquidationForm`; M1's statement at step 7 |
| Finding 5: no law required a rule change's cancels | A `.rules` step at every listing that changes a coin's rules, both ways (`ruleChanges`, in place of `rulesChangedAt`), its slice the cancels of every order of the coin | **Yes:** fixtures `RulesKeep`, `RulesSkip` |
| An inactive slot's cancel was written `replaced` | `inactive` when the wish holds no value (A19) | Fixture `InactiveCause` |
| Study 2's round 16 kernel changes | `KERNEL.md` A18 and A19; `kernel-v2.md` A3, C2 (three outcomes), V3, V13, B2; brief 3 steps 3, 5x, 6, 7 and the recorders' table. A quote's level order and level sizes are drops too (D325's principle: an event's own content; study 2 listed four cases). A dropped event still counts as admission's last event and among its timestamp's ids, so disorder or a repeated id after it still rejects; `marketAt` skips it through `dropCause`, the one function admission applies | **Yes:** step 6's reader, step 7's finality, sub-step 2's `dropCause` and C2; fixtures `DropKeeps`, `DropDisorder` |
| `arithmetic.py.txt`'s ledger model (the human, 2026-11-22) | Deleted: `Books`, `TestLedger`, `GuardRule`, `whole_lots`, `reach`, `guard_fold`, `guard_reach`, `pairs_market`, `bar_log`, `construction_a`, `ledger_fuzz` and their constants, with the parts of `study2_criteria`, `confirming_read`, `round5` and `round6` that ran them. The file runs to its end (2 min 55 s); `kernel-v2.md` parts C and D, architecture 6 and brief 3 step 10 say the deleted figures were the model's and the Lean laws are the reference | No (a record) |
| Test 12's draw recipe pinned by the whole file's SHA-256 (`x4-hosts.sh` read the working tree's file), which any edit of another derivation moves | The recipe is the file as it stood at `3d7992e`, whose `emit_x4_draws` generated the corpus and whose SHA-256 `x4_local.ml` pins (`5e6c95e9…`), read with `git show`, never from the working tree | **Yes:** one comparison in `x4-hosts.sh` (sub-step 6) |

### My view of finding 6, routed to study 2's half

Agreed that the ending's `known` comes before the last fact its rule reads. An ending reads two sources: the flag, through the listings copies, and the absence of a settlement in `B(e)`, through the settled funding. A settlement of an hour has its stamp at most `late` after the hour and is known `funding.lag` after its stamp (A18), so the funding source shows no settlement of `B(e)` at `B(e) + late + funding.lag`. Taking each fact at its own source's time, and never before `R + listings.lag`, which `feed` checks of a listings event: `known = max(max(R, t_F) + listings.lag, B(t_F) + late + funding.lag)`; `R` drops from the second term since `R ≤ B(e)` (D324). The fresh Opus's `max(R, t_F, B(e) + late) + listings.lag` charges the listings lag on the funding fact: later than needed when the listings lag exceeds the funding lag, and not causal when the funding lag exceeds it. With A18's example header the current rule lets the view learn an end 10 to 70 minutes before its last fact exists; the ladder reads no cross-coin input and moves no verdict (the fresh Opus), but L1a's premise is only as causal as the `known` the reader assigns. `KERNEL.md` A18 takes the line study 2 decides.

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| Stage 2's names | Derived and read in the source. The compiler's side is measured (`~/.cache/mm-r17k/tag/`): a file whose types, functions and exports all end in `«#»`, with a structure, an inductive, structural and well-founded recursion, a matcher and `List.foldl` specialized at a tagged caller, compiles with no panic and runs to its kernel values; an impostor named exactly as the specializer names its copy (`List.foldl._at_.Engine.Orders.weighted.«#».spec_0`) panics the compiler as the fresh Opus found, and the same impostor tagged (`….spec_0.«#»`) compiles beside the specialization, each returning its own body. Not built: the renaming of a whole `engine.kexp` in Stage 2, and constructors tagged at the kernel (the elaborator cannot name them so) | **Yes**, if Stage 2's map or a generator it calls reads a name's structure in a way the tag breaks |
| `primitives.txt` | Measured on Stage 1's environment; Stage 2's walk adds `CleanPrelude`'s `natFix` path, and the builder writes the list from Stage 2's own walk | **Yes**, by its entries |
| The whole machine's forms fix steps 6 and 7's effect order (a liquidation: `liquidated`, cancels, closes, cycle ends, bankruptcy) and fields (an order fill's print) now | Derived from A6, A7, A10 to A12 and A19 | **Yes**, if step 6 or 7 meets a wall in them: R1 reopens there |
| A quote's level order and level sizes as drops | This architect's reading of D325 | **Yes** (C2's cases) |
| D325 itself | Neon's finding 1 on study 2's round 16 (drops at a fixed midnight; fresh books while prints drop) contests it; study 2's round 17 may revise the drop | **Yes**, C2's dropped outcome follows study 2 |
| Finding 6's formula | Routed | Reader only |
| O26 | Unchanged | Only if study 2's fitted trigger misses B5 |

**Would any open point change what is built?** Yes: sub-step 1's names, reach walk and output checks, and sub-step 2's partition, forms, rule-change steps and drops are new in round 17 and unreviewed.

### Committed criteria: reported, not edited

None touched by the kernel half.

### Routed and owed

- **To study 2's half:** finding 6 (above); its copy of `arithmetic.py.txt` holds `round12_study2`, `dip` and `round13_study2`, which `kernel-v2.md` A12 and brief 3 step 10 cite for the reserve, and its `criteria-notes.md` cites the never-stood quote's 1.94, computed by the deleted model: the deletion reaches them when the branches meet; and C2's dropped outcome follows its answer to Neon's finding 1.
- **To the advisor:** the owed item "`arithmetic.py.txt`'s ledger model to K1's fold" is closed by deletion; `checks.mm2-tests` fails its two timing tests on the builder on this branch, before and after the merge (derivation `n14by4mq`); the human's run line for `arithmetic.py.txt` names a `path:` flake, whose copy of the main worktree, `data/` included, filled the root filesystem on 2026-11-23 from about 01:46 to 01:57 UTC (20:46 to 20:57 EST); the file now carries the `git+file:` form, and the human may want to know the line as given is unsafe there.

### What the next reviewers should check

1. **Stage 2's names:** a path in 4.34.0's compiler or in a generator Stage 2 calls that makes or looks up another declaration's name otherwise than by extending it, or reads a name's structure in a way the tag breaks; whether one map renames every reference (`Expr.const`, `Expr.proj`'s structure, an inductive's constructors and `all`, a recursor's rules); and, built on `b94e128`, that the thirteen exports behave as before.
2. **What the closure may reach:** a subject whose compiled behaviour departs from its kernel value without reaching an unlisted opaque (through an `Init` definition whose `@[extern]` or `@[implemented_by]` code is not its value, `Thunk`, `Task`, `dbgTraceIfShared`); and each of the ten primitives' reason.
3. **The compiler's output:** a collision the record check misses.
4. **R1's partition:** a run in which every effect has one owner and every step its form while an order is lost or an effect is unbound before its law's step; the forms against A6, A7, A10 to A12 and A19 for steps 6 and 7; S1's restated match.
5. **The drops:** C2's three outcomes against `marketAt`, L1a and C1; a contradiction that a dropped event's bookkeeping lets through.
6. **Study 2's fold-in** against `architect-r16-s2-report.md`, "Kernel changes".

### Open questions

None that only the human can decide. Judgments a reviewer may contest: Stage 2's names against the fresh Opus's uniqueness check alone; the list of opaques against his list of every toolchain constant; fixing steps 6 and 7's effects and forms now against restating R1 at each; a quote's level order and sizes as drops; M2 as a new law, and U1 stated again for the machine at step 7.

### Convergence

**Not converged.** Both halves of step 5x are re-derived (the boundary on constructions, R1 for the whole machine), so a reviewer who did not build them follows.

### Addendum, the same round: study 2's round 17 kernel changes

Written 2026-11-23 03:32 UTC (2026-11-22 22:32 EST) by the same architect, after the section above, on the advisor's routing of study 2's round 17 (`/home/kevin/repos/moneymachine/data/builder/architect-r17-s2-report.md`, "Kernel changes", D337 to D342). `172f5af` folded them in; `d773bbe`, `854fa4b` and `5691b26` correct that fold-in after a re-check against the built engine (`b94e128`) and against Neon's review of study 2's round 17 (`audit/reviews/2026-11-23-neon-round17-study2.md`), whose finding 5 is on these changes. Nothing above is edited: what it says that no longer holds is listed below. Experiments: `~/.cache/mm-r17k/contract/`. No market data, nothing under `data/holdout/`, no token or key file read.

**In plain words**

- **A recorded trade or quote is never read against its coin's rules: not when it is admitted, and not when it fills an order.** The rules (lot size, price steps) are the venue's for orders, and the engine rounds the replica's orders by them and nothing else. A size is read at six decimals, which every perp's lots fit; what the model has no price in (a crossed or one-sided book, a price of zero) is counted by the reader and never fed, and rejects the run if it is. Each event off our copy of the rules is admitted and counted.
- **Study 2 proposed one more use of the rules, rounding what a trade offers an order to whole lots of our copy; it is not taken.** A recorded size is finer than our copy's lots only when the venue's lots are, and there the venue would have filled the order by it. Rounding would leave resting orders unfilled by small trades for an hour while books keep filling takers, which is what study 2's change set out to remove, and would break the law of fills at a trade smaller than one lot (Neon).
- **The archive's stored doubles keep the one check they had:** a stored price off its coin's grid is taken as no decimal of the venue's, and rejects the market, as it did; the engine alone looks.
- **A listing's end is known when the last fact its rule reads is,** at the greater of the two sources' lags, so it is early under no header.
- **The checks of the statements on the pinned compiler found two errors in the text the builder was to copy** (a notation core Lean lacks; a trade id typed as a natural number), now fixed.

**Settled by derivation (awaiting the next reviewers)**

| Point | Settled by | Changes what is built |
|---|---|---|
| D337, the size's scale | **6.** A perp's lots are `10^−szDecimals` with `szDecimals` at most 6, so each lot is a whole multiple of `10⁻⁶` and every size the venue writes places exactly; the range leaves a size under `10⁹` units (at a price of 0.05 USD, 50 million USD at one level). `sz_decimals` above 6 is refused in a header and rejects in a listing. B4 reads no size or price (its markets hold observations alone, at `sz_decimals` of 3), so its 3,120 streams cannot move | **Yes:** `checkSize`, `Reading`, `parseCoin` |
| D337, admission | Two outcomes; no rule of a coin's is read but a `double` price's grid. The reader counts, and feeds nothing of, a quote crossed, one-sided or not strictly best first, a price or a size not above zero, a `string` number its scale cannot place; one fed rejects. An admitted event off the copied rules has one `off_rules` row (V1's and V3's witness, counted) | **Yes:** sub-step 2; readers |
| D337, what an order is offered: **not taken as routed** | The recorded size, as recorded. T1 reads prices alone; E1 and L4 hold of any sizes; F0, A7 and A2's roundings are round 16's again, where `172f5af` had restated F0 with the rounding. An offer's parts are in units of `10⁻⁶`, so `offerPlan` reads no rules. Positions are whole multiples of `10⁻⁶`, not of the copied lots, which no law asked and a change of rules broke already. Answers Neon's finding 5 on F0 and on a sweep over a level under one lot: there is no such case | **Yes:** an offer's unit (`walk`, `step5Moves`, fixtures) |
| The archive's grid (study 2's proposal) | Adopted, in A2's reading of a `double` price, and the engine's alone: a reader passes a double untouched and has no second copy of the grid. `X3`'s `onGridAt` is reached by that reading and by the `off_rules` rows; an order's rounding never called it (`172f5af` said it did) | **Yes:** C2's `priceBad` |
| C2 | Restated and written out in the contract: `priceBad` at scale 8 with the grid for `.bits` alone, `sizeBad` at 6, the listing's bound 6. Its text now claims what its statement holds: faults to rejection, one way; admission of the rest, and A18's other checks, are the tests' (`172f5af`'s text listed a second settlement and levels out of order, which the statement has never held) | **Yes** |
| L1a | Statement unchanged. Its second premise was explained by a quote read under rules not yet known; it holds the world's effects (a listing not yet known cancels an order, and the view holds that cancel first). Step 4's test 6 restated, test 7 (one value at two scales) deleted | Tests |
| D341, finding 6 | Known at `B(t_F) + late + max(listings.lag, funding.lag)`: study 2's formula on its header, and causal on any (Neon's finding 5). My own formula above, which takes each fact at its own source's lag, is at most an hour earlier on study 2's header and moves only when the view drops the coin; one `max` is the simpler line | Reader |
| D338, D340 | A18: a copy's, a pull's and a query's date counts only within an hour of its line's `recv`; every pinned file is read; the print rule of the router and the reader is one, with its scales; a funding query is defined, and proves an end only with every element read, in order and none in the hours asked (`172f5af` left out that last clause, and what delimits a query) | Reader; brief 3 steps 2, 6 and 7 |
| D342, and the recorders' table in brief 3 | No writer reads this host's clock; their budget is 205, 410 under kills. The table keeps what must be held and what a loss shows, and loses its copies of `RECORDER.md`'s, `VAULT.md`'s and A18's rules, which each round of study 2 had to fold in again and which `172f5af` left stale in two places | No |
| The contract, elaborated against `b94e128` on 4.34.0 | Every statement of step 5x type-checks but for `stepForm`'s `\|u\|`, which core Lean lacks, now `Engine.Orders.absQ u`. Read beside A18: an order fill's `print` is an `Int`. `S1`'s restated match is written out. A `refused` effect drops its slot's live order, or a `post_only` refusal at step 6 would leave the order in the account (`Acct.apply`'s `refused` case is the identity as built) | **Yes:** sub-step 2, step 6 |

**What the section above says that no longer holds**

- *In plain words*, "an event off the rules in force is dropped and counted": admitted and counted.
- *Settled*, the row of study 2's round 16 kernel changes: C2's three outcomes, the drops, `dropCause` and the fixtures `DropKeeps` and `DropDisorder` are deleted, the cause they answered being gone.
- *Finding 6's view* and its row under *Disputed*: settled above. *Disputed*, "a quote's level order and level sizes as drops" and "D325 itself": gone with the drop.
- *What the next reviewers should check*, item 5: the list below. *Routed*, "C2's dropped outcome follows its answer": it did.

**Conflicts, as the advisor asked to have said**

1. With what this round had decided: the D325 fold-in and its reading that level order and sizes are drops, deleted.
2. With the routed text: D337's offered whole lots (not taken), and D341's `listings.lag` (the greater of the two lags).

**Open, or disputed**

| Point | State | Would change what is built |
|---|---|---|
| Two lines of A18 that are study 2's rules: an open-tail page's range in finality (Neon's finding 4 on study 2's round 17), and reading stream files from before `w_start` (its finding 6) | A18 follows study 2's round 18 | Reader |
| The recorded size offered as recorded, against D337's rounding | Derived above; study 2's half has not seen it | **Yes**, an offer's unit |
| The `off_rules` rows in the engine, against a count made outside it | The grid is proved in Lean and nowhere else; a count outside would be a second copy | Rows only |
| The readers' rules live in three places (A18, brief 4's "What the reader rechecks", `VAULT.md`'s "What the reader trusts") | For round 18's cut: A18 is the implementer's; the other two would cite it | No |

**What the next reviewers should check** (in place of item 5 above; item 6 is "study 2's fold-in" of both rounds)

1. A market event whose content, off the copied rules or not, breaks T1, E1, F0, L4, S1 or C2 as restated, or a fill of a finer size the venue could not have made; a position no order of the venue's could close, and whether it matters.
2. C2's restated statement against A3, and what it leaves to tests; an event with no fault that the built admission would still reject (`known`, horizon, encoding) on a forward record.
3. `off_rules`: an event off its rules with no row, or with one when it is on them; its place and count among the trace's lines.
4. A18's query and finality, word for word, against `4-study-2.md` step 7 and `VAULT.md`; the print rule against `RECORDER.md`'s router.
5. The ending's `known` under any header; `Acct.apply`'s `refused` case at admission and at a first quote.

**Routed to study 2's half:** brief 4, step 7 says in three places that a resting order is offered a print's whole lots of the copied rules (test 10 "What stops a run", wall 2, wall 3 "What stops a run"): it is offered the recorded size, so Neon's construction's prints of 0.15 fill 0.15. Test 10's held delisting names 08:59:59.999: with study 2's header the end is known at 07:59:59.999, 3 h 20 min after the flag (Neon). `KERNEL.md` A18 now gives the print rule's scales, which recorder build step 1 waits for (`px` at most 8 decimals and below `10⁷`, `sz` at most 6 and below `10⁹`). The other routed items above stand. **To the advisor:** architecture 7 and 10 are pruned of the deleted pilot (`854fa4b`), as study 2's report asked.

**Open questions:** none that only the human can decide.

**Convergence:** not converged, as above: a reviewer who did not build round 17 follows, on the section and this addendum together.

**Added 2026-11-23 03:41 UTC (2026-11-22 22:41 EST): Stage 2's names, built.** The section above left one part of the boundary unbuilt, the renaming of a whole `engine.kexp`, constructors included. Built now on `b94e128`'s closure, on the pinned toolchain, from round 16's Stage 2 prototype (`~/.cache/mm-r17k/stage2tag/`: `Regen.lean` lists what the generators regenerate, `tag_kexp.py` applies the map, `Stage2Tag.lean` compiles with panics fatal):

- 4,747 constants renamed (91 inductives, 218 constructors, 59 recursors, 120 regenerated auxiliaries), replayed under the kernel and compiled with no panic: 1,396 compile calls, 3,535 auxiliaries, 5,040 declarations recorded once each. The untagged build's 67 sparse `casesOn`, 256 projections, 266 matchers and 18 kernel-proved recursions are found again, the C has the same 7,035 exported symbols, and the archive passes the OCaml suite through its thirteen exports (`state`, `exact`, `ledger`, `venue`, `events`, `archive_reader`, `eval`, `readings`, `strings_scale` at 90,800 quotes a second; `scale_test`, B4 and test 12 not run).
- The fresh Opus's two impostors, and a safe `foo._unsafe_rec := 999` beside `foo := 4`, each return their kernel values beside the function they imitate. With the same text untagged, the output check names the last one (`compiling Engine.foo._unsafe_rec recorded the environment constant Engine.foo`).
- **The output check as written would have failed on the library itself:** Stage 2's own generators compile each inductive's `ctorIdx` and `ctorElim` and each constructor's `elim`, 186 environment constants Stage 2 never asked the compiler for. It is now per call: a call to compile a declaration records no other constant of the environment (kernel B2, step 6; brief 3).
- `primitives.txt`, walked inside Stage 2's own environment (values, and the `@[csimp]` replacement of each constant reached, `Init`'s and `CleanPrelude`'s among them): 3,362 constants and the same ten opaques, so that row under *Disputed, or open* is closed too.
- **A claim of the section above is refuted:** that the fresh Opus's uniqueness check alone would not have closed a consulted name. With the names left untagged and that check alone, the same `foo._unsafe_rec` fails as `recorded twice: Engine.foo`, the compiler recording it under `foo`. So each guard closes every impostor built so far by itself: the names by construction, whatever the compiler's conventions, and the output checks by the compiler's record. Both stay, since each is short and neither rests on the other.
- Two details a builder needs, now in the brief: the regenerated auxiliaries are learned by running the generators, not from a list, and Stage 2 reads a matcher's, a sparse `casesOn`'s, `brecOn`'s and `below`'s form from the `engine.kexp` name.

So *Disputed, or open*'s row on Stage 2's names is closed but for the reviewers' eyes: item 1 of what they check stands, on this build.

## The last pass, round 18, kernel: the run's one order, what each guard closes, the trust stated exactly, and study 2's rounds 18 and 19

Appended 2026-11-24 by a fresh Claude Opus 5.5 at maximum effort, the architect for round 18's kernel half, answering the fresh Opus's review of round 17 (`audit/reviews/2026-11-24-opus-round17-kernel.md`: findings 1 to 3, the `STToken` fixture, the contract's namespaces), folding in study 2's rounds 18 and 19 kernel changes (`/home/kevin/repos/moneymachine/data/builder/architect-r18-s2-report.md`, "Kernel changes", and `architect-r19-s2-report.md`, its kernel list, round 19 superseding round 18 where they differ), and settling the side of the listing end's window that GPT-6.2's review of study 2's round 19 asked about (`audit/reviews/2026-11-24-gpt62-round19-study2.md`, section 2, first paragraph; with its section 1's second paragraph, which names the reader). Revisions on `rearchitecture`: `09bf9c0` (merge of `main`), `e958f32`, `2e23a76`, `436e8b1`, `32a39c5`, `875e85f`, `4cd4517`, `9e2e808`, `c34cf68` and this commit. Experiments under `~/.cache/mm-r18k/` on pinned Lean 4.34.0 against `b94e128`'s build. Brief 4, `recorder/`, study 2's criteria texts, `PROGRESS.md` and `audit/criteria.md` untouched. No market data, nothing under `data/holdout/`, no token or key file read. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r18-kernel-report.md`.

### In plain words

- **Everything the engine does in one millisecond now has one order, and its laws hold it there.** The fresh Opus showed that the laws let the machine do a millisecond's work in any order: a change of a coin's rules could cancel the order a wish had just placed in that millisecond, a trade could fill an order at the old price steps before that order's cancel, and a fill could come before the hour's funding payment. Study 2 now times every rule change on a whole second, which is a tick's millisecond, so this would have met every rule change. The run's records are now one list in the machine's own order (each millisecond's events with what they cause, then the clock's tick, then the wishes that arrive), and the world's effects are those records' effects in that order. Three pieces of bookkeeping the laws carried go with it: where each record's effects sat in the log, a count that each effect had one owner, and the chaining of neighbouring records.
- **Both guards on the compiler's names are needed.** One keeps a name the library chose from being taken for one the compiler makes; the other, a check that the compiler records each declaration once, catches two of the compiler's own names meeting, which the fresh Opus made happen from library names. Round 17's addendum said each guard was enough alone; that was wrong, and neither may be cut.
- **What the build still trusts is said exactly:** that the compiler compiles each definition to its value; that the 112 runtime implementations from Lean's standard library the engine reaches (integer, float, string and array operations) compute their definitions' values; and that the ten listed primitives are what they were reviewed as. Lean's floats were called opaque to its kernel; they are not, and what is trusted is that the machine's float instructions equal Lean's own model of them.
- **A delisted coin ends in two records:** its funding ends at the first hour it went quiet, so no later hour is owed, and its listing ends an hour after the delisting notice, settling any holding. The quiet window that decides it now closes just before that end, so the end is decided only by what came before it in the engine's order (GPT's finding on study 2's round 19).
- **The reader takes the record in one fixed order,** by the venue's stamps, whatever order the files hold them in, so a month's replay and a longer one read the same events before any time (GPT's other finding on that round, which named the reader).
- **Study 2's other changes are in:** each day's record fixed by the calendar, each machine's kept copy of a file under its own checksum, the two-machine packing scheme deleted, the forward run's identity by the month's table, and the vault's fills replayed from each coin's first position.
- **How the record is read now has one home,** `KERNEL.md` A18; the copies in brief 4 and `recorder/VAULT.md` are routed to study 2's half to be cut to citations.
- **The round ends shorter:** about 22 KB less across `kernel2/KERNEL.md`, `kernel-v2.md` and brief 3, most of it answered-review tables that copied this ledger.

### Who has seen what

- **The fresh Opus** reviewed round 17's kernel half; he has not seen round 18.
- **GPT-6.2** reviewed study 2's round 19 (two of its points answered here); it has seen none of the kernel half's rounds 15 to 18.
- **Neon** architected round 16's kernel half and reviewed study 2's rounds 16 to 18; it has not seen kernel rounds 17 or 18.
- **This architect** built round 18 and does not review it.

### Agreed

- The fresh Opus's confirmations on round 17: round 16's constructions neutralized or failed under round 17's boundary (`spec/`, `spec2/`, `elam/` return their kernel values; `st/` fails at the walk); the walk on `b94e128` (3,265 constants, the same ten opaques, each a fixed function of its arguments; `Float.exp` an opaque, so `LibmExp` fails); the boundary proportionate, each piece answering a construction and failing closed; the forms (`stepForm`) against A6, A7, A10 to A12 and A19, effect for effect, and `refused` at both places; S1's restated match; the size scale of 6, the recorded size offered as recorded and admission's two outcomes; C2's text; step 5x's statements type-checking; X6 against X4.

### Settled by derivation in round 18 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| Finding 1: R1 left the order inside a millisecond to the machine (a rule change's cancel after its arrival, an offer on the old grid before its cancel, a fill before its hour's payment, an arrival before its tick at `δ = 0`) | **The run's records are one list in A18's order of a millisecond** (kernel B3 R1; brief 3 step 5x; `KERNEL.md` A18): `Record` is a step, a tick or an arrival, each holding the effects it made, a step also its move's index; `run.records.Pairwise Record.precedes` (a millisecond's steps by their moves, then its tick, then its arrivals); `run.effects` is the records' effects in that order; a record's account is the fold of the effects before it; a step's time is its move's (`moveTime`); `ruleChanges` returns the listing's move. The fresh Opus's fix, three clauses over three lists, held one way only: an arrival with no effects placed after a later step's slice read a future account and passed them (round 17's L1c held a tick's place against other times' effects, and nothing held an empty arrival's). One list orders both ways by construction, and deletes the indices `effectStart`, `effectEnd` and `effectCount`, the count of owners, the chaining of consecutive arrivals and steps, and L1c's five clauses of order. The statements type-check against `b94e128` with stand-ins for what sub-step 2 restates (`~/.cache/mm-r18k/contract/`, `Contract.lean` and the brief's own blocks extracted, `Brief.lean`) | **Yes:** sub-step 2's `Log.records`, `Run`, `Record`, R1's clauses, L1c; fixtures `RulesAfterArrival`, `OfferBeforeRules`, `ArrivalBeforeTick`, and `HiddenEffect`, `SharedEffect` restated on the log; a behaviour test that the order an arrival places at a rule change's millisecond stands |
| Which move a step belongs to | The machine's word for steps other than a rule change's until F0, M1, L6, U1 and M2, which steps 6 and 7 state over the steps by their moves, both ways (B2's exceptions; brief 3 steps 6 and 7); R1's order then puts a print's fills after its millisecond's listings and payments, and U1's position is the funding step's account | Steps 6 and 7's statements |
| Finding 2: Stage 2's names do not make the compiler's names unique | B2 says what each guard closes: the names, a library name taken for a compiler name or looked up as one; the record check, the compiler's names meeting each other, which a join of two library names (`f._at_.g.spec_k`) can make. Both are load-bearing. Round 17's addendum's "each guard closes every impostor built so far by itself" is refuted by `coll/` | Fixture `SpecCollision` (the fresh Opus's `coll/`), which triggers the record check from a real library; the scratch `CompiledTwice` it replaces is deleted |
| Finding 3: `Float` is not opaque to the kernel on 4.34.0 | B2 states the trust exactly: the compiler compiles each reached definition to code computing its value; each `Init` implementation the closure reaches computes its definition's value (112 for `b94e128`, measured by round 17's walk, `~/.cache/mm-r17k/reach/`); each listed primitive is the function reviewed. `Float`'s operations are definitions over `Float.Model`, which the kernel evaluates, and the trust is that the C operations equal the model under A13's environment. The list holds opaques alone because none of `Init`'s 491 safe definitions with an implementation keeps state the walk does not see (the fresh Opus: the 11 stateful ones are faithful or reach an `ST` opaque) | No (text) |
| `STToken` must assert the failure | Stage 2 exits non-zero naming the opaque and its path, and writes no archive; `STToken` and `RunSTToken` assert it (round 16's prototype printed the walk and built the archive, whose counter ran) | The walk's exit; the fixtures' assertion |
| The test writer's contract named X4's formulas in `Engine.Exact` | `Engine.Laws`, the frozen copies a count test uses; the engine's copies in `Engine.Exact` are no test's | Tests |
| Study 2's round 19, item 2: the listing's end | Two records of the listing class, each known at `τ = e + 1 h` plus the greatest of the two lags and `δ`: the funding's end at `E`, from which no hour of the coin is due, moving nothing; the listing's end at `τ`, settling at the coin's price. `Payload.fundingEnd` (`a` = 2) is new; `marketEvent` and `slotKeysAt` read it not; C2's key puts it in the listing's class; the due-hour rule reads it. The reach `R`, `B(e)`, the ending's `known` at `B(t_F)`, and the finality query with its pages, rechecks and date are deleted | **Yes:** the payload, `decodeChunk`, `pack`, C2's key and fields, the reader, step 6's test 15, step 7's test 8 |
| The window's side (GPT on study 2's round 19, section 2) | **It closes before `τ`:** the silence is of books, prints and settlements stamped at or after `e − 1 h` and before `e + 1 h`. The end is of the listing class, so first in its millisecond, and an event of the machine's order may be decided only by what precedes it; a window holding `τ` would end the coin by the absence of a book later in its own millisecond, after the settlement had released the cash that millisecond's other fills spend. The coin's events at `τ` come after the end and are counted like every later event of an ended coin; a coin settled every hour is never silent for two hours, so only a coin the record shows silent around its flag loses its event at `τ`. Moving the end after the millisecond's events (GPT's remedy) is the same rule one millisecond later, with a new place in the order; cash, the span's end and the guard are then at one instant, first in `τ`'s millisecond, before its funding, its prints and its tick, as the guard's own order at a timestamp has it (a day's end, a span's end, funding, the tick) | Reader; brief 4's wall 4 and test 12 (routed) |
| GPT's finding 1 on study 2's round 19, second paragraph: one ordered prefix | The reader feeds the record's items in A3's order, ties in the order acquired (run, hour file, line, place in the line), whatever order its files hold them in, so the events a replay feeds before a time are the same at every horizon, and a file's disorder is no fault; the round-19 record of a time already makes the reader place items received months after their stamps, so this states the order it places them in | Reader; step 6's test 13 |
| Study 2's round 19, items 3 and 6: the record of a time; kept lines under their own checksum; every hashed file read whole; a failed checksum feeding nothing | `KERNEL.md` A18; brief 3 step 6 test 13, step 9 test 11 and wall 2, the recorders' table | Reader; tests |
| Study 2's round 18, item 5: the seekable packs | `mm2 pack`, `mm2 unpack-verify`, the seekable reader and test 14 deleted, with A13's and step 9's pins of packed hours | **Yes:** three builds fewer |
| Study 2's round 19, item 4: the forward identity | The registration, the start, the capture's table (whose rows hash every file read and give its `since`), the build and the windows (kernel A13; step 9's test 11 and wall 2) | Identity text |
| Study 2's round 19, item 5: the replay of given fills from a position | Brief 3 step 2: from a starting position for each coin, layer 1's at zero; `chained` is brief 4's | **Yes:** step 2's entry point |
| One home for the readers' rules | `KERNEL.md` A18 states them all, the vault's fills pull (a fill's identity, one whole pull, unreadable elements with their time or place) moved there from `recorder/VAULT.md`'s "What the reader trusts of a pull": the reader that applies them is the kernel's (brief 3, step 2), and A18 is the spec beside it. Brief 4 keeps the derivations and CS2.3's judging rule, which pull judges and what withholds it | Reader spec; routed |
| `kernel-v2.md` parts C to G | Deleted as copies of this ledger's sections of the same names (round 5, round 6, the confirming read, layer 1's wall, GPT's read of layer 1 and O12), with their three notes on walls since answered; each changed lines of parts A and B, which say it; citations re-pointed or dropped where the reason stands inline | No |
| A19's `bid` row said a listing's end moves the price | It moves none, holding no price (study 2's round 14) | No |

### Deleted this round, and why each claim survives

| Deleted | Why the claim survives |
|---|---|
| `effectStart`, `effectEnd`, `effectCount`; R1's count of owners, its chaining of consecutive arrivals and of steps and its clause on a step's effects' times; L1c's clauses on the log's order and on each tick's prefix | The one list in A18's order with the log as its effects gives each: every effect one record's, a record's account the fold before it, consecutive arrivals of a millisecond adjacent records, every effect before a tick of an earlier time or its millisecond's steps |
| The reach `R`, `B(e)`, the ending's `known` at `B(t_F)`, the finality query and step 7's finality cases | An end is decided by the fixed record's silence around the flag, which study 2's calendar fixes before any replay uses it, and it removes no event but those after it |
| The seekable packs, `mm2 pack`, `mm2 unpack-verify`, test 14 and their pins | Each host reads a hashed file once and keeps what some run reads under a checksum of its own, read as the file is |
| Reading a file to a length | Files are hashed only once at rest and read whole |
| `CompiledTwice` | `SpecCollision` reaches the record check from a real library |
| `kernel-v2.md` parts C to G | This ledger holds each answer; parts A and B hold what changed |
| The forward identity's packed hours, `State_{k−1}`, `settled/events`, fee copy and pull events | The capture's table hashes every file read and gives its `since`; no replay reads an earlier one's state (study 2's round 19) |
| B2's history of the source guard and of the observation's rules, round 16's untagged measurement, R1's narrative | The arguments stay; the history is in this ledger and in git |

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| The one list of records, against the fresh Opus's indices with three clauses | Derived above; his clauses held one way only | **Yes**, the observation's shape, before sub-step 2's statements are committed |
| The window closing before `τ`, and the reader's one order | Derived; study 2's round 20 takes them | Reader |
| A18 as the one home, the whole pull moved there | Routed; study 2's half has not seen it | Reader spec, text |
| GPT's other points on study 2's round 19 that reach the reader: copies backdated within the hour, a pull's request time, duplicates in the 10,000 count, the same-millisecond chain | Study 2's round 20 decides them; A18 follows | Reader, once decided |
| The funding's end writes no trace row | A judgment: it moves nothing, and the listing's end that pairs with it has its row | Rows only |
| O26 | Unchanged | Only if study 2's fitted trigger misses B5 |

**Would any open point change what is built?** Yes: sub-step 2's observation is re-derived again and unreviewed, and the reader's end rule and order are new.

### Committed criteria: reported, not edited

None touched by the kernel half.

### Routed and owed

- **To study 2's half (round 20):**
  1. Brief 4, step 7, wall 4: the listing's silence window closes before `e + 1 h` (`KERNEL.md` A18, with the reason above); test 12 gains a book stamped exactly at the end, which stops nothing and is counted.
  2. The reader's one order (A18): brief 4's wall 3 lists "an event out of order" among the stops of a run, which an honest reader no longer makes; GPT's finding 1, second paragraph, is answered by it.
  3. One home: `recorder/VAULT.md`'s "What the reader trusts of a pull" becomes a line citing `KERNEL.md` A18 (its paging premise, the collector's, stays); brief 4's walls 2, 4 and 5 keep their derivations and cite A18 for the rules they restate (the record of a time, kept lines, a copy's two clocks, the end, a whole pull).
  4. Brief 4, step 4's V8 measurement cites "kernel part G", deleted: its record is this ledger's "GPT's read of layer 1 and O12".
- **To the advisor:** `checks.mm2-tests` failing its two timing tests on the builder (round 17's note) was not rerun this round.

### What the next reviewers should check

1. **R1's one order:** a run that meets `Record.precedes`, the log clause and every record's form while an order is lost, an effect is misplaced, or a step precedes its millisecond's tick wrongly; whether the honest machine's records are sorted under every interleaving of offers, ticks and arrivals; whether any step can follow an arrival in a millisecond; the order within one move's steps, left to F0 and M1.
2. **L1c over the records:** a view early or late that the split over the records' prefix admits.
3. **The two guards:** a collision of compiler names that neither the names nor the record check catches.
4. **The trust as stated:** an `Init` implementation or a path through `Float.Model` by which compiled code departs from its kernel value without reaching an unlisted opaque.
5. **The listing's end:** wealth, a bar or a guard state set at or before `τ` by anything after it in the order; a live coin ended within the clocks' premise; the funding's end moving anything; its `known`.
6. **The reader's one order:** two replays feeding different events before a time; ties across files; the cost of placing items by stamp against B5.
7. **A18 as the one home:** a rule of brief 4 or `VAULT.md` that A18 lacks or states otherwise.
8. **Study 2's fold-in** against both reports' kernel lists.

### Open questions

None that only the human can decide. Judgments a reviewer may contest: one list of records against indices with order clauses; the window closing before the end against GPT's batch-closing remedy; the reader's canonical order against a stop at a file's disorder; the vault's fills pull read by A18 against `VAULT.md`; the deletion of `kernel-v2.md`'s parts C to G.

### Convergence

**Not converged.** Sub-step 2's observation is re-derived and the reader's listing end and order are new, so a reviewer who did not build them follows; Neon or GPT, since the fresh Opus has reviewed the last two rounds.

## The last pass, round 19, kernel: the machine is specification and the laws its properties, GPT-6.2's read of round 18 at its cause, and study 2's round 20

Appended 2026-11-24 by a fresh Claude Opus 5.5 at maximum effort, the architect for round 19's kernel half, answering GPT-6.2's review of round 18 (`audit/reviews/2026-11-24-gpt62-round18-kernel.md`: points 1 to 4 of "What the laws still permit or prohibit"; its listing-end, run-id and stream-state points as study 2's round 20 answered them) and folding in study 2's round 20 kernel items (`/home/kevin/repos/moneymachine/data/builder/architect-r20-s2-report.md`, "Kernel changes this half needs", items 1 to 9; `rearchitecture-s2` at `86aa583`). Revisions on `rearchitecture`: `23a890b` (merge of `main`), `0a7ecaa`, `e2004ee`, `e217db9`, `f36a130`, `9a7e46c`, `419f755`, `bbfef25`, `88ff82a`, `148c0e8`, `9fdbba1`, `98b8611` (this section), `95c5de9`, `c130916`, `572ea90`, `586f26d` and the commit of this line. Experiment: the restated contract (records, R1's order, L1c, L0's clock, S1's match, C2's key with the unsettled hour) type-checks against `b94e128`'s build with stand-ins for what sub-step 2 restates, and `moveTime` past the moves is proved `none` (`~/.cache/mm-r19k/contract/Contract.lean`, pinned Lean 4.34.0, no message). Brief 4, `recorder/`, study 2's criteria texts, `PROGRESS.md` and `audit/criteria.md` untouched. No market data, nothing under `data/holdout/`, no token or key file read. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r19-kernel-report.md`.

### In plain words

- **The engine's rules are now its own code, frozen and reviewed, and the laws prove what the study's claims need of that code.** For six rounds the design tried to pin the engine down from outside: each round added a law checking one more part of what the engine recorded about itself against a second, hand-written description of what it should have done (the book at each order's arrival, the effects of each step, each rule change), and each next reviewer found a run that passed every law while the engine did something else. GPT's read of round 18 found three more such runs (a strategy handed a missing first-fill price, a liquidation "rescued" by a later quote of the same millisecond, a funding line dropped from the trace) and proposed the next patch: describe every move's effects from scratch. Finishing that description means writing the engine twice. Instead the engine's code is now the specification itself, printed in full and frozen, so nothing it does can change without a reviewed restatement, and its rules are checked against the design by review and by tests written from the design by a session that has not read the code, as the strategy language, the readers and the evaluator already are. This is what the paper already says the kernel is: an executable Lean program whose every computational law a judged number depends on is a theorem about the code that runs.
- **The laws keep what the study's 5% rests on:** nothing decides on what it could not know (no look-ahead; the view's account the world's, a delay late; every order a strategy's wish arriving a delay after it was sent), no fill beats the tape, cash is conserved, the floor holds, the report is the world's books, cutting the input into chunks changes nothing, a faulty market publishes nothing, and the confirmer's ledger and bar are exact.
- **What goes:** the second description and the laws over it (the market at each arrival, each step's form, the causes of rule changes, laws F0 for fills, M1 for margin, M2 for listing ends, and the machine's versions of U1 and L6); ten fixtures that attacked them, whose cases become ordinary tests; round 18's separate effect log; and, at step 6, the test-only way of handing the engine a fill, so the fill laws speak only of fills the record caused.
- **What stays from round 18:** the one ordered list of what the engine did in each millisecond, which GPT accepted, and the law already proved that every order is a wish sent by the strategy a delay earlier.
- **GPT's smaller points:** after a bankruptcy no wish places anything, a zero-price order included; a funding payment in the millisecond of an earlier liquidation is on the position the liquidation left, so a coin it closed pays nothing; a step's move index past the moves names no time.
- **Study 2's round 20, folded in:** a reply placed by its two clocks; what a funding reply covers; an hour the venue's replies show unsettled pays nothing and holds nothing; a delisting ends only on the venue's evidence, after the last millisecond of its two-hour span; a corrupt stream feeds nothing; a duplicate's place in the one order; and the assumption V23, that the venue's funding history leaves out no settlement it made.
- **The round ends shorter:** about 11.5 KB less across `kernel2/KERNEL.md`, `kernel-v2.md` and brief 3, though `KERNEL.md` grew 2.6 KB with study 2's new reader rules.

### Who has seen what

- **GPT-6.2** reviewed round 18's kernel half and study 2's round 19; it has not seen round 19's kernel half or study 2's round 20.
- **The fresh Opus** reviewed round 17's kernel half; not rounds 18 or 19.
- **Neon** architected round 16's kernel half and reviewed study 2's rounds 16 to 18; it has seen none of kernel rounds 17 to 19.
- **This architect** built round 19's kernel half and does not review it.

### Agreed (GPT-6.2 on round 18)

- The single ordered record list: R1's rule-change and arrival ordering, an extra or dropped effect failing, L1c's prefix split (kept: R1's order and L1c); deleting the slices, ownership counts and chaining; the test writer's use of `Engine.Laws`' frozen formulas.
- Whole-file capture hashes, the kept-lines checksum, the calendar cutoff, the forward identity and the packs' removal; A18 as the home of the readers' rules; a starting position for each coin of the given fills; the end's cash and span at one instant.

### Settled by derivation in round 19 (awaiting the next reviewers)

| Point | Settled by | Changes what is built |
|---|---|---|
| **The cause of GPT's points 1 and 2:** the laws constrained the machine without determining it | **The machine is specification** (kernel B2): `feed`, `finish`, `offer`, the transitions, the clock, the view and its inputs, `arrive`, `Acct.apply`, the state and the records leave `frozen.txt`'s subject list and are printed in full, so no machine does otherwise than its text unseen. A subject is now only a function a law determines at every argument (the numeric readings and twins, `prepare` and `admit`, `Ledger.step`, `bind`, `check`). The laws are the properties the claims rest on, each with its witness, and those characterizations; a law reads any specification, records included. Rounds 13 to 18 bound record after record to a second, partial machine and each review found a run outside it; GPT's remedy, each move's effects bound to the transition from its own market and account, completes that second machine, whose union is a reference transition no simpler than the machine. One transition is smaller, and it is the one B1 already says the engine is. That its rules are part A's rests on review of each restatement and on the tests each step writes from part A, as for the readings and the evaluator; a restatement of the tick, the view or the evaluator's inputs reruns B4. A faster form of any part of the machine is a twin proved equal, as X3's and X6's are | **Yes:** sub-step 2's frozen surface and contract; steps 6 and 7's laws |
| GPT 1: a tick hands the evaluator an undefined `first_price` and skips an exit while every law holds | The tick's inputs are the machine's text (A5's table, printed in full), so that trace is a restatement, which the print shows and step 5's test 2 fails (a first fill at 10 gives the ladder's five wishes at their prices); fixture `FirstPrice`. B2's exception "the evaluator state a tick records ... the machine's word" is deleted with the rest of that list | **Yes:** fixture |
| GPT 2: each cause read from the millisecond's end market (a liquidation rescued by a later quote); the span boundary and trace rows unbound | No law reads a millisecond's end market: `marketAt` and the per-move cause laws (F0, M1, M2, U1's and L6's machine statements) are deleted unbuilt. Each cause is the machine's sequential text, every check of its own event on what came before it (A10, A12), and step 7's test 1 gains GPT's case (cash −95, maintenance 5%, an adverse mark of 98, then 105 in the same millisecond: liquidated). The span change and the `end` and `funding` trace rows are A19's text, which step 9's tests 4 and 5 hold, a never-held coin's settlement row included; P1's span clause stands | **Yes:** steps 6 and 7's laws; tests |
| GPT 3a: F0's domain (the step 5 witness's `Move.offer` gives lots no tape awards) | F0 deleted. From step 6 a run is its fed events: `Move.offer` is deleted with the step 5 tests and fixtures that offered a fill, which run through prints and quotes (step 6, test 12), `step5Moves` and so R1's and S1's witnesses restated; the fill laws E1, L4, T1 and L1b speak only of fills events caused | **Yes:** step 6 |
| GPT 3b: funding after a same-time liquidation (A9 and B3 against step 7's move prefix) | A9: the position the world holds at the event, after every earlier event of A3's order and all each caused, so before the fills of its millisecond's prints and quotes and after a liquidation an earlier funding event of it caused; "before any fill at that time" read a liquidation's closes, which are fills, the wrong way. The due-hour check stays A18's, on events before the hour. U1 is the ledger's law; V21's text; step 7's test 3 gains GPT's case | Text; a test |
| GPT 4a: R1's forced arrival against A11 (a zero-price order after bankruptcy at a minimum of zero) | A6: an arrival does nothing for a bankrupt account, one decision with its other cases. `arrive`'s four-clause characterization, which forced the arrival through A6's conditions, is deleted; R1 keeps `prepare`'s and `admit`'s, which speak of admission alone | **Yes:** `arrive` at step 7; R1's statement |
| GPT 4b: `moveTime`'s out-of-range index read as the last event's time | `moveTime` is `none` past the moves (proved in the experiment) | **Yes:** contract |
| What of R1 stays | `b94e128`'s universal clause, proved: at each deciding tick one wish a slot and coin in view (`slotKeysAt`), none between, each arriving `λ` later, once, a slot's in order, and the admitted orders the placed ones; it is the bridge from L1a's views to the world's orders. With it, round 18's order of the records (`Record.precedes`, each step at its move's time), which GPT accepted. Fixtures `ViewSkip`, `ArriveTags`, `RulesAfterArrival`, `OfferBeforeRules` and `ArrivalBeforeTick` stay with them | **Yes:** R1's restatement adds the order clauses |
| Round 18's separate effect log | Deleted unbuilt: each effect `emitOne` makes is appended to the record being made, one path, which is GPT's own condition for dropping the equality; L1c's `r.world` holds what it held | **Yes:** sub-step 2 |
| Study 2's items 1 to 7 (A18) | A reply's two clocks (made after `min(date, recv) − 30 s` and before `max(date + 1 s, recv)`; a copy in force from the later; its reach the earlier less 30 s; the hour check deleted); what a `fundingHistory` reply covers; an **unsettled hour** (`Payload.unsettled`, funding's class and kind, `a` = 2, timed `H + late`), replacing round 19's `Payload.fundingEnd`, which pays nothing, is no price event, writes no `funding` row and names its hour for funding's lateness; a listing's end at `e + 1 h + 1 ms` on the venue's evidence over `[e − 1 h, e + 1 h]`; four stream states, a corrupt one feeding nothing; duplicates' place and the reader's own records in the order; the vault's pull judged and counted as brief 4 says | **Yes:** reader, payload, C2's key, tests 13 and 15, step 7 test 8 |
| Study 2's item 8 (V23, V18) | V23 new; V18's assumed pull is the earliest whole one asked 30 days after the 61 days by its first reply's clocks, under 10,000 distinct fills | Text |
| Study 2's item 9 (brief 3) | Step 2's replay in `chained`'s order, each row's `before` its fill's `startPosition` (GPT's `0→1`, `0→2`, `2→0`); test 13's corrupt and malformed streams and a duplicate's place; test 15 restated; the recorders' table | Tests |

### Deleted this round, and why each claim survives

| Deleted | Why the claim survives |
|---|---|
| R1's content clauses of rounds 15 to 18 (an arrival's books by `marketAt`, `marketInit`, `marketEvent`, `WorldMarket`, `bookFrom`, `bookMatchesAcct`; its effects by `arrivalEffectsOf` and admissions by `arrivalAdmission`; each step's effects by `stepForm`; the rule changes' steps by `ruleChanges`), all unbuilt | The machine is specification: what each arrival and step does is its text, printed in full. Their protection was always partial (B2's list of "the machine's word"), and every gap it left was already review's and the tests'; the cases their fixtures built are behaviour tests (sub-step 2) |
| `arrive`'s four-clause characterization, built at `b94e128` | It forced an arrival A11 forbids; `arrive` is specification, R1 keeps admission's conditions (`admit`) and the schedule |
| F0, M1, M2, and U1's and L6's statements for the machine, unbuilt | Their content is A7's, A10's and A12's text in the machine, tried by steps 6 and 7's tests (each sell written out, the threshold by one unit, GPT's cases); E1, L4, T1 and L1b keep what the 5% needs of fills, L6 the floor, A1 and U1 the ledger |
| Round 18's `Log.effects` and its equality with the records' effects | One emission path into the records; L1c's `r.world` |
| 10 fixtures (`EmptyAdmissions`, `UnnecessaryReplace`, `StaleMark`, `RulesKeep`, `RulesSkip`, `InactiveCause`, `LiquidationForm`, `ArrivalOrder`, `WishInactive`, `WishCycle`) | Each changes the machine, which the print refuses; each one's case is a behaviour test of sub-step 2 or of steps 5 to 7 |
| `Move.offer`, at step 6 | A device for a machine without fill rules; from step 6 every fill is an event's, and the fill laws are of those |
| B2's four rules and its list of exceptions "each the machine's word alone" | Nothing is the machine's word: two lines remain, completion one typed value and the laws' moves those that survive the wire |
| `Payload.fundingEnd` and the funding's end at `E` (round 19 of study 2), unbuilt | Each hour is settled or shown unsettled on its own (study 2's round 20; V23) |
| The hour check between a copy's `Date` and `recv` | A copy is in force from the later clock, so an off clock only delays it |
| B2's copy of the decoder's three passes; a chunk row; history clauses in A18's listing bullets | A18 holds the decoder; the unsettled hour's row replaces the funding's end's |
| `kernel-v2.md`'s tombstone of parts C to G, and its header's promise of them | Round 18 moved their answers to this ledger, which the header now names |

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| The machine as specification, against laws per effect, and against a reference transition with a refinement proof (the paper's table names one as what would close the second level for a conventionally written engine) | Derived above. A refinement proof is the way to a second, independent formalization if one is wanted; it is not needed while the engine is its own plain specification and speed comes from twins | **Yes:** sub-step 2, steps 6 and 7 |
| Keeping R1's schedule and the records' order as laws while deleting the content bindings | A judgment: the schedule is the bridge from the view to the world's orders, which the 5% rests on, and the order GPT accepted is a cheap property of the text; the content bindings were the second machine | R1's statement |
| The unsettled hour writes no trace row | A judgment: it pays nothing, the guard folds nothing for it, and the reader counts it | Rows only |
| A restatement of the tick, the view or the inputs reruns B4 | A rule for the failure it names: a restated machine feeding the evaluator otherwise than the build B4 judged | B4's schedule |
| GPT-6.2's "derive the order-fill and placement projections from the records where possible" | Not done: `run.placed`, `run.admissions` and `run.fills` are made by the transition that makes the record, as specification, so they cannot disagree with it unseen; deriving them restates S1 and P1, which read their indices and books, for no protection. A later cut, the builder's to propose | No |
| O26 | Unchanged | Only if study 2's fitted trigger misses B5 |

**Would any open point change what is built?** Yes: sub-step 2's frozen surface and contract, and steps 6 and 7's laws, which no reviewer has read.

### Committed criteria: reported, not edited

None touched by the kernel half.

### Routed and owed

- **The merge of `rearchitecture` and `rearchitecture-s2`, before a builder reads either alone.** Brief 4 and `recorder/VAULT.md` cite `KERNEL.md` A18 as round 18 left it, and this round's A18 states study 2's round 20 rules they rely on. `git merge-tree` of the two tips shows one conflict, `audit/program/ledger.md`, where each branch appended its own half's sections after round 11 (the kernel half's rounds 12 to 19, study 2's rounds 12 to 20); every other file merges cleanly, `architecture.md` included (6.4's citation here, 6.6 and 6.8 there). Resolve it by keeping both sides' sections whole, editing no line of either, the audit record being append-only.
- **To study 2's half:** nothing in brief 4 rests on a deleted law (it cites none); an unsettled hour writes no `funding` trace row, which the guard's fold needs nothing from; architecture 6.4 now cites A7's `optimistic` rule where it cited F0.
- **To the advisor:** `checks.mm2-tests` failing its two timing tests (round 17's note) was not rerun; the recorder build's run numbering and four stream states are owed before the freeze (study 2's round 20); a later cut could make brief 3's step 5x sub-step 1 a citation of kernel B2's boundary, which it nearly restates (not done: out of this round's points).

### What the next reviewers should check

1. **The machine as specification:** a claim of study 2 that rested on a deleted law and now rests on nothing; a restatement that every remaining law and test admits while it breaks A6, A7, A10 or A12 in a way that changes a verdict; a property law that reads a record the machine's text could make unfaithful while the law holds.
2. **R1:** whether its kept schedule and the records' order hold of steps 6 and 7's machine, and whether the move index can be set wrongly while `moveTime` agrees.
3. **GPT's cases:** the bankrupt arrival, funding after a same-millisecond liquidation, the two-quote liquidation, `moveTime` past the moves.
4. **`Move.offer`'s deletion:** a step 5 test or fixture that prints and quotes cannot reproduce.
5. **The fold-in** against study 2's nine items: the two clocks' bound, a reply's cover at 500 rows and across files, the unsettled hour's place in the order, the end's span at both ends, a corrupt stream's kept form, a duplicate's place, V23.
6. **The B4 rule** and the unsettled hour without a trace row.

Neon first, which has seen none of kernel rounds 17 to 19, then GPT; findings in parts.

### Open questions

None that only the human can decide. Judgments a reviewer may contest: the machine as specification against laws per effect or a refinement proof; keeping R1's schedule and order; deleting `Move.offer` at step 6; the unsettled hour without a trace row; B4's rerun at a restatement of the tick, the view or the inputs.

### Convergence

**Not converged.** The design changed at its cause, so reviewers who did not build it follow.

## The last pass, round 20, kernel: a listing's end at a midnight on a day that paid nothing, the coins' rules the registration's, hours shown unsettled a day past, and Neon's two reads answered at their causes

Appended 2026-11-25 01:45 UTC (2026-11-24 20:45 EST) by a fresh Claude Opus 5.5 at maximum effort, the architect for round 20's kernel half, answering Neon's read of kernel round 19 (`audit/reviews/2026-11-24-neon-round19-kernel.md`, findings 1 to 6) and its read of study 2's round 20 (`audit/reviews/2026-11-24-neon-round20-study2.md`, findings 1 to 8, most of them of A18). The listing ends, funding lateness, the copies' clocks and the replies' coverage are treated as one region and re-derived, findings on it having landed on patches since round 15 (`CLAUDE.md` §1). Revisions on `rearchitecture`: `2f672b0` (merge of `main`), `e128c6d`, `7687c0f`, `f34ebe3` and the commits of this section. K1 to K6 are the findings of Neon's read of kernel round 19, S1 to S8 those of its read of study 2's round 20. Experiments under `~/.cache/mm-r20k/` (scratch, left there: its removal was refused by a safety check on this host). A model of the new reader rules on random records (deaths whose rows go to zero, or stop; relistings; skipped hours; venue-wide halts; collector outages of up to 50 days; files listed late; clock errors up to 60 days), 250 records and 1,000 monthly replays, and 300 records before the rows could go to zero: no hour read differently by two replays whose tables differ, the fed end the same in every replay whose horizon is past it and fed by none whose horizon is it, the horizon never moving back, the end the first midnight after the first whole day that paid nothing with nothing of the coin read and another coin's book, computed from the truth, no settled hour shown unsettled while V24 holds, every due hour below the horizon named and nothing fed after an end. It is not vacuous: with ends only on a row missing, the premise of rounds 14 to 20, 44 of 80 ends do not come (the deaths whose rows went to zero); dropping the calendar cut breaks the first property 38 times in 100 records; dropping the other-coin clause ends coins in venue-wide halts; both clocks 40 days ahead break the settled hours 5,810 times in 15 records; and, worked by hand, the old month gate feeds an end in one replay and not the next, and a margin of an hour with both clocks three hours fast shows hours the engine had not finished. (A first model had given every replay the same replies and was too weak; it is replaced, and the sentence above is what ran.) A reproduction of the reviewers' constructions: an hour due while its record falls after its end (1 in 6 of the flags at a lateness of 10 minutes, all but one millisecond of the hour at 59:59.999), the stale copy's rollback and 8.5227%. The restated trigger, S1's match and U1's machine clause type-check against `b94e128`'s build on Lean 4.34.0 (statements only, unproved). Brief 4, `recorder/`, study 2's criteria texts, architecture 6.6 and 6.8, `PROGRESS.md` and `audit/criteria.md` untouched. No market data, nothing under `data/holdout/`, no token or key file read, no request to the venue. Report: `/home/kevin/repos/moneymachine/data/builder/architect-r20-kernel-report.md`.

### In plain words

- **No reading of the venue's listing page enters a judged run any more.** The coins' lot sizes, price steps and leverage tiers are fixed in the registration, the same copy the replay before the freeze used, and a delisting is recognised by what the venue charges the coin, never by a flag. Every round since 15 had tried to place these hourly copies among market events by some pair of clocks, and every review found a third clock or a boundary.
- **A coin ends at a midnight:** the first one after a whole UTC day in which the record holds no book and no print of it, another coin traded, and each of the coin's 24 hours paid nothing. All of that is over before the midnight, so no decision looks ahead, no month has to be named, and no two monthly replays can read it differently.
- **What rounds 14 to 20 assumed of a delisting is false on this venue, and the project's record has said so since 2026-10-19.** A delisted coin does not stop settling: its hourly funding rows go on at a rate of zero and its book is empty (`audit/criteria.md`, stage 0, its revision of 2026-10-19; the pilot cut a delisted coin's interval at its last traded bar because of it, commit `7d65e5f`; FTM, delisted 2025-01, has none of its 17,520 hours missing in `audit/stage0/ingest-1792385868856.json`). So 'the venue's replies are silent of it', on which those rounds ended a coin, never happens, and no end they define would ever have come; and my own first cut of this round had the same fault. TON, one of the seventeen, is the case in our data: its book is empty from 2026-06-16 and its rows run to 2026-10-31 (facts §6), which rounds 9 to 20 took for a coin that stays listed, and the catalog of 2026-11-16 flags it.
- **An hour is the venue's word only a day after it:** a reply counts as saying "not settled" when both of its clocks, ours and the venue's, are a day past the hour. So clocks can disagree by hours in any direction and nothing changes.
- **A dead coin's holding is closed at its last bid or price, whichever is less,** as the study's wealth is valued, and not at a price one side of a thin book had made.
- **A held coin's funding payment is now a law of the engine, not only of its ledger,** because a payment left out, with the coin's return kept, would have passed every other law and given the copied strategy free carry.
- **Smaller:** a coin with no quote yet pays no funding and enters no sum (it has no price); the law about the order of records no longer claims to keep a rule change before an arrival, a promise it never proved; a rule change of a coin, which no reader made, is deleted from the engine; two versions of one of the vault's fills are reported as that before any chain is checked.

### Who has seen what

- **Neon** read kernel round 19 and study 2's round 20; GPT read the rounds before. Nobody has read this round.
- **This architect** built round 20's kernel half and does not review it; a fresh session wrote round 19's and study 2's 20.

### Agreed (Neon on kernel round 19)

- The machine as its own frozen specification, with the content bindings, `marketAt`, F0, M1 and M2 deleted; R1's schedule and L1c's prefix split; `Move.offer` deleted at step 6; funding on the world's position at the event; `moveTime` none past the moves; four stream states and a duplicate's place; the calendar cutoff; B4's rerun rule; the unsettled hour without a trace row. One thing added where it was missing: U1's machine clause (below).

### Settled by derivation in round 20 (not yet reviewed)

| Point | Settled by | Changes what is built |
|---|---|---|
| The region (K1, K2, K3, K4; S1, S2, S3, S4, S5, S7): what each claim needs of it | **CS2.1** needs that nothing in the run be set by what the venue did after it, in the engine's order, and that every later replay of a day be fed the same events; **CS2.2** and **CS2.3** need the second and fidelity; nothing needs a rule change or an end before it can be known, and everything may be late; a hole of ours may hold the test | Text |
| **Rules:** a copy of the listings in force from its clocks (K4; S4, S5; S3.1's `E_HEADER`) | **No copy is read.** The header's rules are the registration's copy of `meta`, taken at the freeze, for the whole run, as the replay before the freeze runs on one; the same copy says which of the universe's coins are in the market, those it lists unflagged. **TON, one of the seventeen, is flagged in the tracked copy of 2026-11-16** (`venue/hyperliquid/meta-2026-11-16.json`: names, lots, leverage and the flag, no price), so S3.1's day-0 refusal was certain and not a rare case, and a design that asked the venue about a coin already dead would have rested on its answer. A18's copies bullet, `E_HEADER` at `w_start`, the two-clock placement of copies, the `+1 s`, the null date of a copy and the engine's rule-change event are deleted. A change of the venue's is seen as `off_rules` rows (V3). Fidelity: at most what a stale lot rounds | **Yes:** A18; the engine loses `Payload.listing`, the `rules` trigger and cause |
| **Ends:** at `e + 1 h + 1 ms` on a window of copies, books, prints and replies (K1 to K3; S1, S2; the month gate; the two clocks on flags) | **At a midnight `M`** whose day before holds in the record no book or print of the coin, a book or print of another coin, and 24 hours each of which paid nothing: settled at a rate of zero, as the venue writes them after a delisting (above), or shown unsettled (A18; V25 is the assumption). The evidence is wholly before `M`; it reads no copy, no flag and no clock; it is fed only past `M` (`M < w_end`) and first in its millisecond, so a run cut at `M` and one that runs on agree on every day; the last-whole-month input, the `copy's day and the next` gate, the hour window and the flag are deleted. The archive's record takes the same rule (TON). A rate other than zero keeps a coin listed whatever its book shows, which TON's empty book through a listed spell would have ended by silence alone. The engine's due hour stands by `H + late`, so an end inside an hour's lateness leaves it undue wherever an end stands | **Yes** |
| **What a hole is, and coverage by partial hours** (S3.2, S7.1; `date` null) | An hour is settled, shown unsettled by a whole reply, or a hole. Only a missing whole hour needs a reply, which the collector asks for again every day: a settled hour, a 500-row page's edge and the 00:17 pull leave nothing to show. A reply with an unreadable `Date` shows nothing | **Yes** (A18); none in the collector |
| **The third clock** (S4) | Copies gone, no reply's content orders an event. The reach is deleted: a reply shows an hour when both its clocks are a day past it, so the remaining assumption is one sentence, V24: the host's clock and the venue's `Date` are not both a day ahead of the matching engine's | **Yes** (V24; A18) |
| **K3, S6.1's T_730 and the kept form** | The end reads no pre-`w_start` line. The kept form holds every universe coin's item stamped at or after `w_start` in the record of its time, whatever horizon reads it, so a witness past the last midnight is in it, and a witness is an item (routed) | **Yes** (A18; brief 4's wall 3) |
| **S2, K1: an end and the hour it stood in** | `R_SETTLEMENT_MISSING` is of hours whose coin's listing has not ended by `H + late` (A18) | **Yes** (the engine's check) |
| **K5:** funding or an end before a coin's first quote | It is no price event and enters no sum; its `funding` row's `unit` is `-`; the coin's end row `-`; K2 takes the coins that have a first price | Text; step 9 and step 10's tests |
| **K6A:** a machine that skips a held coin's payment keeps every law | **U1's machine clause** (kernel B3; brief 3, step 7): over an observed run a fed settlement with `q ≠ 0` has one step of its event, with `paid c q (−q·u)` and the cash-flow row, one with `q = 0` none, and no other step pays; the move index it reads is why R1 keeps one. Fixture `PaymentSkip` | **Yes** (step 7) |
| **K6B:** R1's prose, and `admit` against `run.admissions`; step 7's L6 | R1 says the orders the arrivals submit that `admit` accepts are the placed ones; the list's order places records and says nothing of their content; `RulesAfterArrival` and `OfferBeforeRules` become `EndingAfterArrival` and `OfferBeforeEnding`; L6 is the state invariant and was never deleted | Text; two fixtures |
| **S8.1:** two versions of one fill | A18: elements of one key alike in the read fields are one fill, and two that differ are a conflict of the pull, reported wherever in it they stand, before any chain | **Yes** (the pull's reader; brief 4) |
| **The end's price** (raised here) | A coin's end closes a holding at its adverse price (A10, the lesser of last bid and price for a long), the price staying: the wealth at the bid is the same before and after it, and a last mid made by an ask pulled up is not turned into cash | **Yes** (step 7) |

### Deleted this round, and why each claim survives

| Deleted | Why the claim survives |
|---|---|
| A18's two-clock placement, reach, listings copies (in force, entries, flags), end window and its lateness rule, the end's last-month input, `E_HEADER` at `w_start` | Nothing of a copy reaches a run; the end is a past day's nothing paid; unsettled hours are the venue's, a day late (V23 to V25) |
| The engine's change of a coin's rules: `Payload.listing`, its chunk and checks, the state's `rules`, the `.rules` trigger, the `rules` cause, step 4's test 6, step 5's test 9 and its rule clauses | No reader makes it: the archive's market has none, the forward market's is the header's |
| `RulesAfterArrival`, `OfferBeforeRules` | Their cases are an end's: `EndingAfterArrival`, `OfferBeforeEnding` |
| R1's claim that no restatement can let a rule change's cancel follow its arrival | It proved only the list's order; the cases are the fixtures' |
| `settlement` as the price of a listing's end (own price) | A holding closes at its adverse price; the bid wealth is continuous |

### Disputed, or open

| Point | State | Would change what is built |
|---|---|---|
| Rules fixed at the registration, against copies at midnights a day late (the advisor's hypothesis) | Derived: the copies need a monotone rule against a clock ahead and V24-like assumptions; a fixed copy needs none, and the replay already ran on one | **Yes**, if reopened |
| Ends in the engine against a coin that merely goes stale and is dropped by the reader | Kept: a stale coin's cash would stay spent, and spans (CS2.1's bar) would change what the committed definition computes | **Yes**, if reopened |
| V24 | A clock off by a day in both places is assumed away; an operator's check of the collector host's clock and of `Date` is owed (brief 4's acceptance) | No, unless a reviewer finds a clock that leads the engine by a day |
| The venue's answer for a coin that dies inside the run (S3.3) | The record answers it: `fundingHistory` serves delisted coins (`venue/sources.toml`, certified; FTM's rows through 2026-09-30, above), so a dead coin's hours are settled at zero and hold nothing. V25 is what the record cannot show of every coin | The advisor's check of TON's stored rows before 2026-11-01 (V25) |
| O26 | Unchanged | Only if study 2's fitted trigger misses B5 |

**Would any open point change what is built?** Yes: this round's review, and the routed items of brief 4 and the criteria drafts.

### Committed criteria: reported, not edited

None touched. The drafts of CS2.1's and the shared revision's sentences that quote copies, ends and two clocks are routed (report, "Routed to study 2's round 21").

### Owed and routed

- **The merge with `rearchitecture-s2`** conflicts only in `ledger.md`: keep both sides whole, edit no line.
- **Study 2's round 21:** the registration's copy of `meta` at the freeze (the universe's coins it flags, TON now, are no coin of the forward market, which the report names; the vault's list of seventeen names is unchanged); brief 4, steps 6 and 7 (walls 2 to 5 and the tests), the criteria drafts, architecture 6.6 and 6.8 (and 6.1's two clauses at an end, still true as written), `VAULT.md`'s date handling and the delisted-name probe, `RECORDER.md`'s "Listings change" and "the venue's time" (no change needed but for who reads a `Date`), and the recorder build plan's items unchanged by this round.
- **Not done:** `checks.mm2-tests`' two timing tests (round 17's note) and the two branches' merge.

### What the next reviewers should check

1. The end rule and the hour rule as one: a live coin ended; a dead coin never ended while its name trades again; an hour shown unsettled that the venue settled; a replay that reads an end another lacks; a day of nothing that a venue-wide stop makes (one coin's and no other's).
2. Rules fixed at the registration: a verdict CS2.2 or CS2.3 that moves; any path by which a rule enters the run from what came after.
3. Deleting rule changes from the engine: a claim that rested on them.
4. U1's clause: a restatement that passes it and omits or doubles a payment; whether `PaymentSkip` is the only class it must exclude; whether T1, K1 and the bar's funding need more.
5. The end at the adverse price against T1, K1, CS2.2 and the bar.
6. V24 and the day: a clock or cache pattern that shows a settled hour unsettled; V25 against any record of a listed coin at a rate of zero for a day, or of a delisted one whose rows are not zero.
7. The kept form and the witness (brief 4, wall 3), which the criteria's T_730 uses.

Neon first, then GPT; findings in parts.

### Open questions

None that only the human can decide. For the advisor: the delisted-name probe, the deletion of the engine's rule changes, the fixed rules and the adverse price (each a design decision of this round, reversible by restoring the text), and the bound on the trace's `off_rules` rows if the venue makes a coin's lots finer (one row for nearly each of its quotes, some 57 million a year).

### Convergence

**Not converged.** The region was re-derived and its findings' constructions can no longer be stated, but nobody who did not write it has read it.
## The last pass, round 12, study 2

Appended 2026-11-21 21:22 UTC (16:22 EST) by the Opus 5.5 architect (maximum effort) for round 12's study 2 half, on branch `rearchitecture-s2`, beside the kernel half on `rearchitecture` (`CLAUDE.md`, Orchestration; the human, 2026-11-21). Reviews answered: GPT's read of round 9 (`audit/reviews/2026-11-21-gpt-round9.md`), GPT-6.2's read of study 2 as a whole (`audit/reviews/2026-11-21-gpt62-study2-whole.md`) and GPT-6.2's audit of the live recorders (`audit/reviews/2026-11-21-gpt62-recorder-audit.md`). Report: `/home/kevin/repos/moneymachine/data/builder/architect-r12-s2-report.md`, with the drafted criteria texts and the recorders' build plan. The ids D250 to D261 leave room for the kernel half's; the advisor renumbers at the merge if they meet. No market data, no `data/holdout/`, no token or key file; `PROGRESS.md` and `audit/criteria.md` untouched.

### In plain words

- **One cause under most findings:** the design read what the record covers from proxies (a listing's host-clock time, a majority of quoting coins, a file's clean end, a healthy connection, a marker written before its data was safe), and let steps that only optimize block the capture. Now each source states its own coverage in the bytes a capture pins, each verdict waits for the coverage it needs, steps that only optimize fall back, and the end is a date.
- **The horizon** needs every listed coin's settled funding past the midnight, or the coin let go once its listing ended and its rows stood still over a month of asking, and one coin's book line past it. No host clock, no majority, no refusal for a horizon that went back.
- **The capture never refuses:** the month's pull and the packing fall back to what is on disk.
- **CS2.3 waits for the vault's fills to be covered** over its 61 days, read from completed pull files; the deployed collector must first stage its pulls atomically.
- **A coin is recorded only while both its channels are:** a dead `trades` subscription under healthy books is a gap, not an absence of prints.
- **The registration is authenticated once** into the first state and carried; the stake is chosen among those no settlement can end; the bootstrap's shares are no operating power; the held-back months are a development set; and the three verdicts claim a positive control on a frozen replica, not the vault's edge.
- **Nobody declares a record ended:** the last firing, 62 days after the 730th judged day, is final. The human's word of 2026-11-21 (enough disk) fixes the horizon at 730 judged days.

### Who has seen what

- GPT read round 9; GPT-6.2 read study 2 as a whole at `e6c971e` and the recorders at `9bf37ad`.
- Nobody has read this round's commits (`eb420e7` to the one that appends this).

### Agreed

- **From GPT's read of round 9, unchanged:** the removal of `D_capture`; the stream-ended packing closure (D222); raw ≡ packed by routing, purity and `_order` (D223); the pinned windows and environment (D225); the post-capture sealed majority (D205); D228's algorithm and its independent reference; the absence of a further holdout leak through the pack refusal.
- **From GPT-6.2:** the event-level ledger, the bid's crossings, the joint 5% under the two nulls and V16, the guard as a refusal of rung 2, the entry count, and once-only judging of CS2.2 and CS2.3.

### Settled by derivation in round 12, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D250 | The horizon (GPT's round 9 disputes 1 to 3; replaces D221) | `T_k` the later of `T_prev` and `T_raw`, capped at `w_start + 730 d`; `T_raw` the largest midnight with every header coin's funding row in `[T + 1 h, T + 25 h)` or the coin let go (its listing ended in the latest copy, its settled hours unchanged since `State_{k-1}`, a completed pull since), and one universe coin's book line of any book in the same window. A short page before a delisting keeps the coin in until the venue serves the rest; listings give a membership, never a time; one line suffices because funding bounds `T` by the venue's clock. `R_HORIZON_REGRESSION` and the monotonicity theorem deleted | **Yes** (brief 4, step 7, wall 3 and test 10; architecture 6.6) |
| D251 | Nothing before a capture refuses (dispute 5; revises D224's pre-capture half) | The capture follows the month's pull whatever it ends in; a file without a pack two hosts agree on is pinned raw; what is left is a changed closed file and the release wait | **Yes** (brief 4, step 7) |
| D252 | Exclusive funding pages (dispute 4) | The next `fundingHistory` page starts at `last_time + 1`; each row is asked for once in a pull; `stuck` deleted for funding; the wording "as first served" made true within a pull; a re-stamped row named as the record's error | **Yes** (`VAULT.md`; brief 4, step 7) |
| D253 | The last firing (GPT-6.2's finding 3) | The first monthly firing at least 62 days after the 730th judged day ends is final; nobody declares a record ended; the human's dated stop ends the test at the last published day and leaves only "not judged"; disk assumed for 730 days (the human) | **Yes** (brief 4, step 7; architecture 6.6, 6.8; CS2.1's drafted revision) |
| D254 | CS2.3's vault coverage, and the collector's pulls (finding 6; audit 1 to 4, 9) | CS2.3 judged at the first replay with 61 days run whose capture's completed fills pulls cover `[w_start, w_start + 62 d]`; `VAULT.md`: one completed pull one file named by its start, pages checked against their range, durability before the watermark and `stop`, fees and orders checked, funding resumed from the last pull, alarms by identity; the staging collector deployed before the freeze | **Yes** (`VAULT.md`; brief 4, steps 6, 7; CS2.3's drafted revision) |
| D255 | A coin is recorded while both its channels are (finding 7; audit 5) | The recorder makes a subscription live from its acknowledgement, decides `unacked` at its deadline and re-sends it on its connection; the capture pins `events`; the reader feeds a coin's quotes only while its `trades` subscription is live (routed to the kernel's architect) | **Yes** (`RECORDER.md`; brief 4, step 7; `KERNEL.md` A18, brief 3 step 6, routed) |
| D256 | The registration authenticated once (finding 5) | `State_0` holds the commit id, the file's hash and `w_start` from the remote's push record, logged and reviewed; every state carries them; a replaced file is a changed closed file; the replay's identity, the fit's export and report kept with the registration | **Yes** (brief 4, step 6) |
| D257 | The months held back are a development set (finding 4) | No verdict depends on their blindness; the check is never called out of sample; the registration lists what touched them; the rule against material from 2026-11-01 on persists past the release until the freeze | Text, and the registration's list (brief 4, steps 3, 6; architecture 6.4) |
| D258 | Operating power, and the stake (finding 2) | The bootstrap's shares are conditional and never called power; the registration gives the reference model at the chosen pair's replay volatility and Sharpe as an upper reference; the choice is among `φ` with `(1 − φ)^17 ≥ 1/26` (1/16, 1/8), which no capped settlement ends with every coin in a cycle; GPT-6.2's figures reproduced (`round12_study2`) | **Yes** (brief 4, step 5; architecture 6.3; `arithmetic.py.txt`) |
| D259 | The three verdicts' claim (finding 1) | Narrowed to a positive control of the confirmer on a frozen replica of a rule with a live record; no verdict says the confirmer detected the vault's edge | Text (architecture 6.1; `paper-changes.md` A5 item 8, rewritten from revision 4's stale list) |
| D260 | CS2.1's note and CS2.2's revision redrafted, CS2.3's drafted (round 9's provenance; D215, D227) | Every retained verdict stated as its judging replay's, on its capture's record; the last firing and the human's stop folded in; "adds no way to pass" holds against judging each day once at first publication, not against re-judging on the latest record, and the drafts say so; CS2.3's adds a way to be judged, not a false "met" | Advisor's criteria commit only |
| D261 | The recorders' specs and build plan (GPT-6.2's audit) | A listings read that is not whole changes nothing; a response is whole or the request failed; `check` reports whole gaps, subscription gaps and missing hours; `stop` after durable data; cut and malformed files; one writer a file; a failed write ends the run; refused coins reconsidered; the style gate and named handlers. Nine steps, the listings and HTTP fixes first | **Yes** (`RECORDER.md`, `VAULT.md`) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D250 to D261 | This round | Settled by derivation; not yet read by GPT | **Yes**, if GPT breaks them |
| Routed | The reader's liveness rule and the listings copy rule (`KERNEL.md` A18), brief 3's recorders' table, A13's identity, V13 | For the kernel's architect, through the advisor | **Yes** (the frozen reader) |
| O22, O24, O26 | As round 9 left them | Open until their measurements | As before |

**Would any open point change what is built?** Yes: GPT's read of this round, and the routed reader rules, which the frozen build carries.

### Committed criteria: reported, not edited

- CS2.1's revision (replacing D215's draft), CS2.2's (replacing D227's) and CS2.3's (new) are drafted in full in the report, item 3, for two fresh reviewers and the advisor's commit.

### Assumptions only the human can choose

- **A second copy of the recordings** is a spend: the design assumes enough disk (the human, 2026-11-21) and still recommends a second copy on another node.

### Owed

- **By the advisor:** route the kernel changes; route the recorders' build plan (steps 1 and 2 at once); the disk measurement; deploy the staging `mmvault` before the freeze; the three drafted revisions to two fresh reviewers, then commit them alone.
- **By GPT:** the read below.

### What GPT, the next reviewer, should attack first

1. **D250's let-go rule:** a coin let go while the venue still has rows for it (listings copies misordered by a host clock, a relisting, pulls that complete for the other coins and return `[]` for it through a whole interval), or held across its delisting.
2. **D250's one-line recorder clause:** a day run while lines the recorder will still write are not yet on disk.
3. **D255's reader rule:** `recv` compared across the files of one run (flush order, a stepped clock, a killed run's `events`), one frame on two connections, raw against packed.
4. **D254's coverage:** a covered record that still misses a round trip (page checks, retention, late indexing, a collector's clock), and the 62nd day.
5. **D258's eligible stakes:** a ledger at `φ` of 1/8 that ends within 212 days on a plausible market, or a better rule fixed before the replay.
6. **D253 and the drafted revisions:** any lever in the last firing or the human's stop, and a run that passes while each claim is false, or fails while it holds.
7. **D256:** a deployment that substitutes `State_0` itself.
8. **D261:** anything in the audit's ten findings the revised specs still permit.

### Convergence

**Not converged.** Every finding of the three reviews is answered at its cause, and none landed on a patch; GPT has read none of it, and two reader rules are routed to the kernel's architect.

## The last pass, round 13, study 2

Appended 2026-11-22 02:07 UTC (21:07 EST) by the Opus 5.5 architect (maximum effort) for round 13's study 2 half, on branch `rearchitecture-s2`, beside the kernel half's round 13 on `rearchitecture`. Reviews answered together: GPT-6.2's read of round 12's study 2 half (`audit/reviews/2026-11-21-gpt62-round12-study2.md`) and Neon's (`audit/reviews/2026-11-21-neon-round12-study2.md`). Report, with the four drafted criteria texts, the kernel changes to route and the revised recorder plan: `/home/kevin/repos/moneymachine/data/builder/architect-r13-s2-report.md`. Ids D270 to D284 leave room for the kernel half's; the advisor renumbers at the merge if they meet. No market data, no `data/holdout/`, no token or key file; `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **The one cause under both reviews:** round 12 still read some things through stand-ins (funding past a midnight for the funding before it, one book's timestamp for the recorder's progress, one pull for a month of asking, a pull's completion for the fills the venue had shown, clocks compared across files, cycles opening one at a time), and let one transition mean two (a missing row ended the test like a bad one; "no new day" named nothing). Each now reads the thing itself, and each transition says one thing.
- **The horizon** needs every coin's funding present for every hour before the midnight (a hole waits for its row), a book received when it was stamped, and a delisted coin let go only after thirty pulls found nothing more. A missing settlement holds the month; a bad item ends the test.
- **A coin's books count only while its trades are recorded,** decided by the recorder from its one socket's order, so no clock is read.
- **Every month's run names whatever its capture allows,** even with no new day; the last reading is fixed; the human's budget stop is reported as an operator stop.
- **CS2.3 waits for the vault's fills to be asked for again a month after each moment,** by pulls that cannot have been cut by the venue's retention: about a month later than before.
- **The test ledger never buys into the cash its funding needs** (a twenty-fifth at cost), instead of round 12's filter on the stake, which seven of its twelve pairs failed in one dip.
- **Every report prints the registration's four identifiers;** the runner cannot authenticate its first state, so the check is against the remote.
- **The urgent recorder fixes changed once, early** (`0a38f6b`): only the venue's flag delists a coin, and the HTTP tests carry valid JSON.

### Who has seen what

- GPT-6.2 and Neon read round 12 at `f67812b`. Nobody has read this round's commits (`0a38f6b` to the one that appends this).

### Agreed

- **From GPT-6.2:** the narrowed claim and development-set designation (D257, D259); the fixed calendar; capture-specific verdicts; the raw fallback (D251) and exclusive pagination for unchanged stamps (D252, now refined); the two urgent recorder fixes; the Brownian figures.
- **From Neon:** D251; D252 (with the span-end guard, now in); D257; D259; the power arithmetic; the deletion of `R_HORIZON_REGRESSION` and of host-clock listing times; round 12's core recorder fixes.

### Settled by derivation in round 13, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D270 | The horizon's funding clause (GPT's D250; Neon's 3B; replaces D250's clause 1) | Each coin's reach, the first hour without a row; every coin not let go has its reach after `T`, and some coin has; a coin let go once flagged and 30 queries from its reach came back empty; `T_k` the later of `T_prev` and `T_raw` | **Yes** (brief 4, wall 3, test 10) |
| D271 | The horizon's recorder clause (Neon's 3A) | A book line witnesses its stamp only when received within an hour of it; the host's clock can only take a witness away | **Yes** (brief 4) |
| D272 | Absence and rejection (GPT) | `R_SETTLEMENT_MISSING` holds the month at the last midnight before it; every other engine error ends the test | **Yes** (brief 4) |
| D273 | Books paired with prints at routing (Neon's 2; GPT's plan 4; replaces D255's reader rule) | `l2Book-fast` only while the coin's `trades` is live on that socket, the rest in `l2Book-fast-unpaired`; the reader reads no `events` | **Yes** (`RECORDER.md`; brief 4; kernel's rule withdrawn) |
| D274 | The capture (GPT's D251) | Packing a job as hours close, attempts killed at 30 minutes; Step 1 pins only, and `fsync`s all it pins first | **Yes** (brief 4; `RECORDER.md`) |
| D275 | What a run names (GPT; Neon's 5) | Every settled run names what its capture allows on the days through its last matching midnight; `continue`, `end_study` with its cause, halts; the last firing's capture the last admitted, settled after any outage | **Yes** (brief 4) |
| D276 | The operator stop (GPT; Neon's 5) | Kept, reported as made with the reports visible, with each unjudged condition's figures; a non-final "earned" not forfeited (Ville at any stopping) | Text and report (brief 4; CS2.1's draft) |
| D277 | CS2.3's coverage (GPT; Neon's 4; replaces D254's union) | An instant covered by a completed pull made 31 days after it, run to its making, under 5,000 fills; the daily re-read 32 days; judged about day 93 | **Yes** (brief 4; `VAULT.md`; CS2.3's draft) |
| D278 | The ledger's reserve (GPT's D258; Neon's 1; replaces D258's filter) | A buy leaves cash at least 1/24 of what the ledger paid for its units; all 30 pairs eligible; `round13_study2` | **Yes** (`kernel-v2.md` A12, routed; brief 4, step 5; architecture 6.1; CS2.1's draft) |
| D279 | The registration (GPT's D256; Neon's 6e) | `State_0` pushed; every report prints commit id, file hash, `w_start`, `State_0`'s hash; checked against the remote outside the runner; fit export and candidate programs kept | **Yes** (brief 4, step 6) |
| D280 | Pages and storage (GPT's D252; Neon's 6d) | Funding pages cut at whole hours, a span done at its `endTime`, each coin stored when its own queries completed; the vault's watermark never back; fee rates decimal strings | **Yes** (`VAULT.md`) |
| D281 | The urgent listings and HTTP lines (GPT's plan 1, 2; Neon's 6a) | Only its flag delists a coin; each listings line holds its request; framing fixtures with valid JSON, trailers, a close-delimited body complete when its array or object parses (`close_notify` refuted) | **Yes** (`RECORDER.md`, `VAULT.md`, `0a38f6b`) |
| D282 | Progress evidence and late items (GPT) | The horizon is evidence, the capture the input; a late item behind a published midnight ends the test at `T*`, every verdict standing as its capture's | Tests (brief 4) |
| D283 | The recorder plan (GPT's plan 3 to 9; Neon's 6b, 6c) | Shutdown before style and subscriptions; `route.ml`'s handlers; the added tests of each step | **Yes** (report; `RECORDER.md`, `VAULT.md`) |
| D284 | The criteria drafts (replacing D260's) | CS2.1's ends and what stands; CS2.1's reserve; CS2.2's sentence corrected; CS2.3's coverage and its later `T*` | Advisor's criteria commit only |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D270 to D284 | This round | Settled by derivation; read by neither model | **Yes**, if broken |
| Routed | The ledger's reserve (A12, K1, `confirm`), the listings copy rule (A18), the withdrawn liveness rule, V13, brief 3's recorders' table | For the kernel's architect, through the advisor | **Yes** (the frozen build) |
| Noted | The kernel's ordering of listings copies by `recv` | Not acted on: needs a host clock stepped back past two differing copies | No |

**Would any open point change what is built?** Yes: the reviews of this round, and the routed kernel changes, which the frozen build carries.

### Committed criteria: reported, not edited

- Four drafted revisions, in full in the report: CS2.1 (ends and what stands, replacing round 12's draft), CS2.1 (the ledger's reserve, new), CS2.2 (replacing round 12's draft), CS2.3 (replacing round 12's draft). For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- **The operator stop:** kept as the human's budget authority and labelled; the human may give it up for the two years.
- **A second copy of the recordings** (round 12's, still open).

### Owed

- **By the advisor:** route the urgent lines' change (`0a38f6b`) to the builders if not already; route the kernel changes; the recorder plan in its new order; the four drafts to two fresh reviewers, then commit them alone.
- **By GPT and Neon:** the read below.

### What GPT and Neon should attack first

1. D270 and D271: a day published whose record still changes with every reach past it and an on-time witness; a coin let go after thirty empty answers that the venue still owed; a skew that freezes `T` for good.
2. D272: an absence that is not `R_SETTLEMENT_MISSING`, or a rejection a later capture removes.
3. D273: a book routed as paired while its prints were not recorded, from the server's ordering of acknowledgements and data.
4. D275 and D276: a verdict named on a capture that a later one contradicts beyond what the drafts say; an operator-stop lever beyond leaving conditions unjudged.
5. D277: a covered instant whose fill is missed under V18 without an alarm.
6. D278: a ledger that keeps the reserve and still ends within 212 days on a plausible market; a way the cut is not a scale fixed before its buy.
7. D279: a substitution the four printed values do not show.
8. D280, D281, D283: anything in both reviews' recorder findings the revised specs still permit.

### Convergence

**Not converged.** Every finding of both reviews is answered at its cause; three round 12 rules are deleted rather than patched (the stake filter, the reader's interval rebuild, the capture's packing step); neither model has read this round, and the kernel changes are routed.

## The last pass, round 14, study 2

Appended 2026-11-22 08:20 UTC (03:20 EST) by the Opus 5.5 architect (maximum effort) for round 14's study 2 half, on branch `rearchitecture-s2`, beside the kernel half's round 14 on `rearchitecture`. Answered: GPT-6.2's read of round 13's study 2 half (`audit/reviews/2026-11-22-gpt62-round13-study2.md`); the urgent recorder fix's second pass (`recorder-urgent` `65232d3`, carried into the specs and then replaced); GPT-6.2's hold of that fix (`audit/reviews/2026-11-22-gpt62-recorder-urgent-fix-2.md`) and the advisor's question whether the recorders should use a vetted HTTP client and one strict JSON decoder; and the shared request budget (`audit/decisions.md`, 2026-11-22). Report, with the four drafted criteria texts, the kernel changes to route and the recorder build plan: `/home/kevin/repos/moneymachine/data/builder/architect-r14-s2-report.md`. Ids D290 to D305 leave room for the kernel half's, which uses none. No market data, no `data/holdout/`, no token or key file; `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **A delisted coin's market ends where the venue stopped paying funding on it,** not at our hourly copy of the listings, which comes later on our own clock: a coin held across its delisting is closed there and the run goes on, and anything a relisting brings afterwards is set aside. We wait thirty days after the delisting before trusting that its last payments are all in.
- **A stop is a pause when more of the record could undo it, an end when nothing could:** a missing payment, or a trade that crossed a rules change between copies, pauses; two different values for one thing end the test.
- **The vault's fills count as complete for a moment only when asked for again a month later, up to the present, in a reply small enough that the venue's 10,000-fill memory cut nothing,** and the daily re-read starts wherever that is not yet true.
- **The recorders stop writing their own web client and JSON reader:** libcurl does the web requests and one strict JSON library reads every reply, the forward reader included. Two reviews of our own client kept finding edge cases; these are solved problems.
- **The venue's request budget is shared out in fixed, enforced allocations,** each request reserving its largest possible cost before it is sent.
- **The study is complete when its three questions are answered; every month's verdicts count only after their registration identifiers are checked against GitHub;** the monthly capture no longer pulls anything itself.

### Who has seen what

- GPT-6.2 read round 13 at `d79a8ca`, and the urgent fix's second pass at `91bb08c`. Nobody has read this round's commits (`43116ed` to the one that appends this).

### Agreed

- **From GPT-6.2's read of round 13:** the narrowed claim and capture provenance; verdict-only settlement and the disclosed operator stop; judging on an unchanged prefix; the cost-basis buy clamp and the conditional size bound; whole-hour funding paging; socket-local routing; background packing with the raw fallback; the reach for every coin through the cutoff.
- **From its review of the urgent fix:** the close-delimited path deleted, one reader for both callers, whole wrong-shaped listings kept with their request, omission changing no subscription, the old ten-second retry gone, a failed vault page leaving the watermark.

### Settled by derivation in round 14, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D290 | A listing's end (GPT-6.2's coarse delisting and relisting rows; replaces round 13's end at the copy) | A flagged coin ends at the whole hour after its last settlement before its first flagging copy, settled at its price there; its events from then on counted and not fed; its end's hour not due | **Yes** (brief 4, wall 3; `KERNEL.md` A18, routed) |
| D291 | Finality of an end, and holes (D270; replaces round 13's thirty asks) | Final once a completed query covering end to flag came back empty from a pull begun 30 days after the flag (premise: the venue serves a delisted coin's settlements within 30 days of its flag); asks before the flag never count; holes are never let go | **Yes** (brief 4) |
| D292 | Coverage over the modeled intervals, and the receipt clock (D270's day-212 case; D271's premise) | Clause 1 each coin's reach after `T` or at its final end; the witness only while a coin is listed, the "some coin has" bound deleted; the receipt clock's premise stated, its failure counted in each report | **Yes** (brief 4) |
| D293 | What stops a run (D272; replaces round 13's absence and rejection) | A stop an added line could undo holds the month (`R_SETTLEMENT_MISSING`, `R_OFF_RULES`, routed); one none could ends the test; a stop below `T_prev` is `T*`; test 10's contradictory bullet deleted; wall 2 holds instead of ending; test 2's crossed quote replaced | **Yes** (brief 4) |
| D294 | Acquisition order (D272's backward `recv` step) | `<run>` the later of the start and one past the largest under the root; copies in acquisition order, each timed no earlier than the one before | **Yes** (`RECORDER.md`; `KERNEL.md` A18, routed) |
| D295 | The capture (D274) | Length read, then the file and every directory up to the root `fsync`ed, then hashed; what a compressor still holds belongs to a later capture; the capture's own pull deleted, with `--from-ms`, the 15-minute kill and the lock's wait | **Yes** (brief 4; `VAULT.md`) |
| D296 | CS2.3's coverage (D277; replaces round 13's) | Pulls with no `endTime`, fewer than 10,000 fills, begun 31 days after each instant; the re-read from the earliest uncovered instant, a freeze dependency; the claim of the observed fills | **Yes** (`VAULT.md`; brief 4; CS2.3's draft) |
| D297 | Admission and the exit (D275) | A month's capture the first committed at or after its firing, fixed through replay outages; `end_study` with five causes, `complete` among them | **Yes** (brief 4) |
| D298 | The registration gates each verdict (D279) | Every settled report's verdicts the study's only after its four identifiers are checked against a fresh clone of the remote; a mismatch voids them and halts for the human | **Yes** (brief 4, step 6) |
| D299 | The reserve (D278) | As a rule at the buy, `max(0, (24C − B)/25)`, basis by the ledger's own fraction sold; text: a capped hour only to 25/24 of cost; power moved both ways; one ledger in replay and forward | Text, and A12's wording (routed) |
| D300 | The REST client (the advisor's question; GPT-6.2's two holds) | libcurl through `ocurl` in the pin, one call owning each request; curl's framing relied on and tested; status, an announced length or chunking, 16 MiB and the error events ours; the urgent fix's reader and syntax rules deleted; `cohttp-async` refused (its readers end a cut body without error) | **Yes** (`RECORDER.md`, `VAULT.md`) |
| D301 | One JSON decoder (finding 3) | `jsont` for every JSON the recorders and the forward reader read, one decode into the fields used; Yojson out of `mmrec`; jsonm refused (its numbers are `float_of_string`'s) | **Yes** (`RECORDER.md`; `KERNEL.md` A18, routed) |
| D302 | The request budget (the advisor; finding 6) | Allocations `hl` 480, `ws` 40, `vault` 120, `settled` 45, one-off 300, each request reserving its largest weight and settling to the counted; cursors strictly advancing | **Yes** (`CLUSTER.md`; `RECORDER.md`; `VAULT.md`) |
| D303 | The criteria drafts (replacing D284) | CS2.1's ends with the hold and the exit; CS2.1's reserve with both-way power; CS2.2 while not judged; CS2.3's coverage and observed-fills claim | Advisor's criteria commit only |
| D304 | What the reader rechecks (the advisor's question) | One decoder; a line holding no item counted and fed nothing; `R_MALFORMED_FRAME` deleted; the collector's stored hour the reader's present one | **Yes** (brief 4; `VAULT.md`; `KERNEL.md`, routed) |
| D305 | The listings read and memory (findings 4, 5) | The main dex's `meta` first; no `:` on the main dex, a dex not named twice; at most 100,000 perps kept; grown buffers released; websocket messages bounded at 16 MiB | **Yes** (`RECORDER.md`) |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D290 to D305 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18's end and due hour, acquisition order, `R_OFF_RULES`, the reader's decoder and rechecks, A12's wording, brief 3's table | For the kernel's architect, through the advisor | **Yes** (the frozen reader) |
| Advisor's | `hl`'s 480 against the half-rate practice | The allocations fit the venue's limit; lowering or retiring `hl` is the advisor's | No study outcome |

**Would any open point change what is built?** Yes: this round's review, the routed reader changes, and the recorders' rebuild on libcurl and jsont, which the builders follow from the report.

### Committed criteria: reported, not edited

- Four drafted revisions, in full in the report: CS2.1 (ends and what stands), CS2.1 (the ledger's reserve), CS2.2, CS2.3, replacing round 13's four. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- **The operator stop** (round 13's, still open).
- **A second copy of the recordings** (round 12's, still open).

### Owed

- **By the advisor:** route the recorder build plan (steps 1 and 2 first: the client and decoder, replacing `recorder-urgent`'s `rest.ml` and `strict_json.ml`); route the kernel changes; the four drafts to two fresh reviewers, then commit them alone; decide on `hl`'s allocation.
- **By GPT-6.2 and Neon:** the read below.

### What GPT-6.2 and Neon should attack first

1. D290 and D291: an hour after a coin's last settlement before its flag that is not the venue's end; the 30-day premise; the due-hour clause.
2. D293: a stop on the wrong side of the classification; the holds' crossings against Ville.
3. D294: copies or runs the new numbering still misorders.
4. D300 to D302 and D305: a reply curl passes whole that is not the server's framed body; a jsont decision that changes a stored line or a verdict; a leaked socket or exception; any sequence of retries, pages or dexes over an allocation.
5. D296: a covered instant whose fill was lost, under V18.
6. D297 and D298: a substitution the gate passes; a capture whose content depends on more than its commit.
7. D303: a run that passes while a drafted claim is false, or fails while it holds.

### Convergence

**Not converged.** Every finding of GPT-6.2's read of round 13 and of its second hold of the urgent fix is answered at its cause; the recorders' patch loop is ended by deleting the code that drew it; neither model has read this round, and the reader changes are routed.

### Neon's read of round 13, answered in the same round (appended 08:21 UTC, 03:21 EST)

Neon's review (`audit/reviews/2026-11-22-neon-round13-study2.md`) arrived after the table above. It accepts D271 to D276, D278, D279 and D281 to D284 as round 13 specified them; its three findings meet GPT-6.2's at their causes, and round 14's re-derivations close them:

| Neon's finding | Closed by | Changes what is built |
|---|---|---|
| 1. The 32-day re-read against 31-day coverage has no slack: a midnight run 10 s late, or one failed and run an hour later, leaves a seam no later re-read covers, and CS2.3 is withheld for good | D296: the re-read starts at the earliest instant no stored pull covers, read from the files, with no `endTime`; a seam cannot outlive the next run. Neon's two constructions added to `VAULT.md` test 3 and brief 4's CS2.3 tests | Already, by D296 |
| 2. Thirty empty answers can be thirty hourly retries within thirty hours | D291: finality is an empty answer from a pull begun 30 days after the flag, not a count; D295 deletes the capture's own pull and its hourly retries. Added to brief 4's horizon tests | Already, by D291 and D295 |
| 3. `VAULT.md`'s funding test 1 kept round 12's `last_time + 1` | `43116ed`: the test pages at the whole hour after each page's last row | Text, done |

**Who has seen what, corrected:** Neon read round 13 at `d79a8ca` (its bundle); neither model has read round 14.

## The last pass, round 15, study 2

Appended 2026-11-22 17:09 UTC (12:09 EST) by the Opus 5.5 architect (maximum effort) for round 15's study 2 half, on branch `rearchitecture-s2`, beside the kernel half's round 15 on `rearchitecture`. Answered: GPT-6.2's read of round 14's study 2 half (`audit/reviews/2026-11-22-gpt62-round14-study2.md`), Neon's (`audit/reviews/2026-11-22-neon-round14-study2.md`, findings 1 to 10), and the human's decision of 2026-11-22 retiring the `hl` recorder (`audit/decisions.md`). Report, with the criteria drafts in full, the kernel changes to route and the recorder build plan's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r15-s2-report.md`. No market data from 2026-11-01 on (the one count taken, the vault's most fills in one millisecond, read times only of its fills before that date), nothing under `data/holdout/`, no token or key file; `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **A delisted coin ends where its funding payments stop,** read from the payments alone; the flag, on our clock, only says which gap is the end.
- **Any stop of the engine ends the test,** as the committed criterion says: the waiting state round 14 added could never be left, since no later data can undo a stop.
- **No month publishes a day that had not happened when the month began; each month's report counts only if it was computed from the last accepted one, recorded on GitHub.**
- **The recorders judge a reply whole by its complete JSON, which catches every cut reply, and read ids and times from their exact text;** all our framing rules are gone.
- **Vault coverage uses the exact retention condition, and the reader re-checks every pull; an unreadable trade makes its coin stale and an unreadable fill withholds the entry match.**
- **Without `hl`, the recorders use 505 of the venue's 1,200 a minute, and at worst 725;** nothing of study 2 or the recorders read `hl`'s data.

### Who has seen what

- GPT-6.2 read round 14 at `be858e5`; Neon read round 14 (its bundle). Nobody has read this round's commits (`1a1b796` to the one that appends this). By the human's decision of 08:52 UTC (03:52 EST), this round goes to Neon and a fresh Opus.

### Agreed

- **From GPT-6.2's read of round 14:** elapsed delisting grace, holes preserved, acquisition order for files, durable file pins, fixed monthly admission, the successful exit, gap rereads to the venue's now, the reserve's arithmetic, capture-specific claims, whole-hour funding paging, flag-only removal; single-owner cleanup, informational responses, keep-alive, main-dex-first polling, ownership checks, released buffers, the vault run stopping at its first failure; deleting the second JSON parser and counting unreadable stream items; the cold-start fixture.
- **From Neon's read of round 14:** its round 13 findings closed; D292, D295, D297, D299, D305; libcurl and jsont in place of our own client and parser; the drafts' structure.

### Settled by derivation in round 15, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D306 | A listing's end (GPT-6.2's finality hour; Neon 1; replaces D290) | The coin's reach `R`, when a flag timed `e` has `B(e)` (the first whole hour after `e + 1 h`) and every hour from `R` to it without settlement; any flagging copy may qualify; a reach at `w_start` ends the coin there; a modeled settlement at the last price | **Yes** (brief 4, wall 3; `KERNEL.md` A18, routed) |
| D307 | Finality (replaces D291's query) | A completed query from a pull begun 30 days after `e` asked every hour from `R` to `B(e)` and returned none; finality is the horizon's, the reader cuts at every end; the ending `known` as the kernel half derived it, with the qualifying copy | **Yes** (brief 4) |
| D308 | The calendar bound (GPT-6.2) | Clause 0: `T` at or before the first midnight of the day of the firing the capture answers, written into `Capture_k` | **Yes** (brief 4) |
| D309 | What stops a run (GPT-6.2's permanence; Neon 4; replaces D293) | Every stop ends the test, the hold deleted: events fed before `T_raw` are fed in every later run, `R_SETTLEMENT_MISSING` cannot occur there, no copy timed before an event comes after the fact; the lot-size change's cost stated in wall 2; the union admission considered and not taken | **Yes** (brief 4; `KERNEL.md` A18's sentence, routed) |
| D310 | Copy timing (Neon 3; replaces D294's clamp) | Each copy timed by its own `recv`, ties in acquisition order; a clock fault stays in its copy | **Yes** (brief 4; `KERNEL.md` A18, routed) |
| D311 | The state chain (GPT-6.2; Neon 5; extends D298) | Reports print the hashes of the state read, the capture read and the state written; acceptance requires the state read to be the last accepted one written, then pushes the link to `audit/study2/accepted.tsv` | **Yes** (brief 4, step 6) |
| D312 | Halts (Neon 10) | Each ends the study at its last accepted report; a changed file's halt resumes once restored; no halt voids an accepted verdict | **Yes** (brief 4) |
| D313 | The capture (GPT-6.2) | The manifest committed durably; a capture is a cut of each file at its read, not an instant | **Yes** (brief 4) |
| D314 | Whole replies (GPT-6.2's framing; Neon 9; replaces D300's framing check) | Whole when the body decodes as one JSON array or object, which no cut or mixed-in framing does; the framing check and `head` stage deleted; `MAXFILESIZE` at 16 MiB; `SIGPIPE` ignored; curl's head limit documented | **Yes** (`RECORDER.md`, `VAULT.md`) |
| D315 | JSON (GPT-6.2's exact fields; Neon 7; amends D301) | jsont in three steps: depth 64, `Jsont.ignore`, the typed decode with every integer read from its own bytes; duplicates decoded each and the last kept; CR and LF as spaces in the vault's lines | **Yes** (`RECORDER.md`, `VAULT.md`; `KERNEL.md` A18, routed) |
| D316 | Coverage (Neon 2.1; GPT-6.2's page exhaustion; amends D296) | Covered when fewer than 10,000 of a pull's fills are at or after `t`; the re-read past what retention took; the paging premise stated (the vault's most in one millisecond, 6) | **Yes** (`VAULT.md`; brief 4; CS2.3's draft) |
| D317 | What the reader rechecks (Neon 2.2 and 6; GPT-6.2's usable rows; amends D304) | Covering pulls and finality queries by their own pages; an unreadable fill in the chain's span withholds CS2.3, and a failed judging is the one; an unreadable print withholds its coin's books until a readable one | **Yes** (brief 4; `KERNEL.md` A18, routed) |
| D318 | The budget without `hl` (the human; GPT-6.2; Neon 8; replaces D302's numbers) | `ws` 40, `vault` 120, `settled` 45, one one-off script 300 (a lock): 505; holds from sending to 60 s after the end; failures keep the largest; CronJobs at `backoffLimit: 0`; the worst minute 725 | **Yes** (`CLUSTER.md`; `RECORDER.md`; `VAULT.md`; `ingest/hl.py` and `ops/live.py`, builder) |
| D319 | The catalog's memory (GPT-6.2; amends D305) | Names kept to 64 bytes, a longer one refused as past the subscription maximum | **Yes** (`RECORDER.md`) |
| D320 | Day 1 (Neon 6.3) | Per coin, as `KERNEL.md` A18 already reads; brief 4 said "the copy" | Text and a test |
| D321 | The criteria drafts (replacing D303) | CS2.1's ends without the hold, with halts and the one-path argument for the 5%; the reserve's unchanged; CS2.2 with halts; CS2.3 by the exact retention condition, rechecked pages, unreadable fills and one judging | Advisor's criteria commit only |
| D322 | `hl`'s data (the human) | Nothing of study 2 or the recorders reads it; the 30-day comparison sentence deleted; the infrastructure's references are the builder's | No |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D306 to D322 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18's end, copy timing, stop codes, the decoder's steps, unreadable prints, the reader's fills and pages, brief 3's table | For the kernel's architect, through the advisor | **Yes** (the frozen reader) |
| Advisor's | The union admission between two differing copies | Not taken: it removes wall 2's cost (a lot-size change ends the test) at the price of a pending-rules record and a restated admission law | Only the forward test's survival |

**Would any open point change what is built?** Yes: this round's review, the routed reader changes, and the recorder build plan's steps 1, 2 and 8.

### Committed criteria: reported, not edited

- Three drafts in full in the report (CS2.1's ends, CS2.2, CS2.3), replacing round 14's; CS2.1's reserve draft stands as round 14 wrote it. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- **The operator stop** (round 13's, still open).
- **A second copy of the recordings** (round 12's, still open).

### Owed

- **By the advisor:** route the kernel changes; the recorder build (steps 1 and 2 first) with the changes listed in the report; the builder task removing `hl` from `ops/live.py`, `ops/diskguard.py`, the mirror and `CLUSTER.md`'s table, with `ingest/hl.py`'s 300 and lock; the drafts to two fresh reviewers; whether to send the union admission to the kernel's architect.
- **By Neon and a fresh Opus:** the read below.

### What Neon and a fresh Opus should attack first

1. D306 and D307: a flag that qualifies a gap that is not the venue's end, within the premise; a delisting that never qualifies; `B(e)`'s hour; the ending `known`.
2. D309: a stop in a run to `T_raw` that a later capture could undo.
3. D308, D311, D312: a capture's month that publishes a day early; a substitution the chain passes; a halt that adds or keeps a verdict wrongly.
4. D314 and D315: a cut body that decodes as an array or object; a disagreement between the depth count and jsont, or a location that does not give an integer's bytes.
5. D316 and D317: a covered instant whose fill was lost; a page sequence the recheck passes that no writer completed; a coin withheld long on readable prints.
6. D318: any minute over 1,200.
7. D321: a run that passes while a drafted claim is false, or fails while it holds.

### Convergence

**Not converged.** Every finding of both reads of round 14 is answered at its cause: three by deleting a rule round 14 added (the hold, the clamp on copy times, the framing check), the rest by stating the exact condition an earlier rule approximated (the end at the reach, the retention condition, integers by their bytes, holds to a request's end); neither reviewer has read this round, and the reader changes are routed.

## The last pass, round 16, study 2

Appended 2026-11-22 23:20 UTC (18:20 EST) by a fresh Opus 5.5 architect (maximum effort) for round 16's study 2 half, on branch `rearchitecture-s2`, beside the kernel half's round 16 on `rearchitecture`. Answered: the fresh Opus's read of round 15's study 2 half (`audit/reviews/2026-11-22-opus-round15-study2.md`, F1 to F5 and its text points), Neon's (`audit/reviews/2026-11-22-neon-round15-study2.md`, findings 1 to 6), and the human's decisions of 2026-11-22: the operator's budget stop kept, no second copy of the recordings, `hl` and the Oracle VM's recorders retired. The kernel half's ending `known` (`a503574`) is carried into brief 4. Report, with the criteria drafts in full, the kernel changes to route and the build plan's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r16-s2-report.md`. Ids D323 to D336. No market data, nothing under `data/holdout/`, no token or key file: one request's head was read at 23:02 UTC (18:02 EST), its body discarded, to see that the venue sends `Date`; curl 8.22.0's source was read from the pinned tarball. `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **The venue's own clock dates every listings copy and every pull,** from the time each reply states; our host's clock, which nothing checked, no longer decides when rules change, when a delisting is final, or when a fill was re-read a month later.
- **A delisting flag ends only a gap it can belong to,** and a market listed again under a second entry is read as listed.
- **A trade or quote that breaks its coin's rules as last copied is set aside and counted, not the end of the test:** a lot-size change costs about an hour of one coin's record.
- **Whether prints are being recorded readably is the recorder's decision, made in its socket's order;** the reader's own rule for it is deleted.
- **The reader checks every page of a pull and reads fills one by one.**
- **The fee check is reported, not a stop; a refused report is run again; each month's capture is on GitHub before anything runs on it;** two halts are deleted.
- **A program sending requests waits a minute when it starts,** so our worst minute is 505 of the venue's 1,200.
- **The 5% argument names the one place the record is read with hindsight,** a delisting's last hours, and the report counts what that cut.

### Who has seen what

- The fresh Opus and Neon read round 15 at `2bf7ad4`. Nobody has read this round's commits (`1735b99` to the one that appends this).

### Agreed

- **From the fresh Opus's read of round 15:** D306 to D311, D313 to D316, D318 to D320 and D322; D317 but prints; D321 but end (6); the hold, the clamp and the framing check deleted; the reserve's draft. D306 and D310 are since amended on Neon's findings (D324, D323).
- **From Neon's read of round 15:** D308, D309, D311, D313, D315, D316, D319, D320, D322; D314's completeness rule; D318 but sequential scripts; the reserve's and CS2.2's drafts.

### Settled by derivation in round 16, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D323 | Clocks (the fresh Opus F5; Neon 1.2, 1.3; replaces D310's `recv` and coverage's host-clock day) | Each REST line keeps the reply's `Date` (IMF-fixdate, else `null`); copies and pulls timed by it; coverage 30 days after an instant, over the 61 judged days; finality's query dated 30 days after the flag | **Yes** (`RECORDER.md`, `VAULT.md`, brief 4; `KERNEL.md` A18, routed) |
| D324 | The flag's bounds (Neon 1.1; amends D306) | A flag dated at or after `w_start`, and `R` at or before `B(e)`; a coin read by the entries of its name; the ending `known` `max(R, t_F)` plus the lag | **Yes** (brief 4; `RECORDER.md`; A18, routed) |
| D325 | Single-event faults (the fresh Opus F2; replaces wall 2's end) | Dropped and counted, read against copies dated before them; stops only at contradictions, order faults and refused dates; a lot-size change costs about an hour of the coin | **Yes** (brief 4; `kernel-v2.md` A3, C2, routed) |
| D326 | Readable prints (the fresh Opus F1; Neon 2; replaces D317's print rule) | The router pairs books with live and readable prints in socket order; frames go to their channel's file whatever they hold; an unplaceable frame unpairs its connection; the reader withholds nothing | **Yes** (`RECORDER.md`; brief 4; A18, routed) |
| D327 | Rechecks (Neon 3; the fresh Opus's depth) | Every page's request; fills and prints read one by one; finality queries bounded and dated; a line's depth 65 | **Yes** (`VAULT.md`; brief 4; A18, routed) |
| D328 | The fee witness and ends (Neon 4; the fresh Opus's two ends) | `halt_fee_witness` deleted, the witness reported; a run's verdicts named through its earliest end; `complete` only on what then stands | **Yes** (brief 4; brief 3's table, routed) |
| D329 | Refused reports (the fresh Opus F3) | `halt_substitution` deleted; a refused report names nothing and its month is run again from the last accepted state, read by its remote hash | **Yes** (brief 4, steps 6 and 7) |
| D330 | The capture's identity (the fresh Opus F4) | Step 1 pushes each capture's row to `audit/study2/captures.tsv`; the month's capture is the first on the remote after its firing; nothing runs before it; acceptance checks it | **Yes** (brief 4) |
| D331 | The budget across processes (Neon 6.1; the fresh Opus's 725) | No request in a process's first 60 s; `hl.py` on the recorders' hold rule; the worst minute the allocations' 505 | **Yes** (`CLUSTER.md`; `RECORDER.md`; `VAULT.md`; `ingest/hl.py`, builder) |
| D332 | Whole replies (the fresh Opus; Neon 6.2) | The false framing sentence deleted; the overflowing length fails under the maximum size (curl's `lib/http.c`), test 21 restated | Text and a test |
| D333 | The 5% at a listing's end (Neon 5) | Conceded as a named assumption with a count in the report; an exact rule (no event between `R` and `B(e)`) not taken for its survival cost on unseen venue behaviour | The CS2.1 draft and the report |
| D334 | Texts (the fresh Opus) | Holes before the end; Day 1's omission deleted; distinct fills and retention by time | Text, and a kernel line (routed) |
| D335 | The criteria drafts (replacing D321's CS2.1 ends and CS2.3) | CS2.1's ends with drops, three halts, the earliest end, acceptance of state and capture, the two assumptions; CS2.3 by the venue's date over the 61 days; CS2.2 and the reserve stand | Advisor's criteria commit only |
| D336 | The human's decisions of 2026-11-22 | Phase 2 and the second copy deleted from `RECORDER.md`; architecture 6.8 and 12; the open questions closed | No study outcome |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D323 to D336 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18's dates, entries, flag bounds, prints and rechecks; A3 and C2's drops; brief 3's table | For the kernel's architect, through the advisor | **Yes** (the frozen reader and admission) |
| D333 | The listing end's look ahead | A stated assumption with a count, not a rule | Only if a reviewer shows the exact rule costs no survival |

**Would any open point change what is built?** Yes: this round's review, the routed kernel changes, and the recorder build plan's steps 1 to 7.

### Committed criteria: reported, not edited

- Two drafts in full in the report (CS2.1's ends and CS2.3), replacing round 15's; CS2.2's round 15 draft and CS2.1's reserve (round 14's) stand. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- None open. The operator stop (round 13's) and a second copy (round 12's) were decided on 2026-11-22.

### Owed

- **By the advisor:** route the kernel changes; the recorder build with this round's changes; the builder task for `ingest/hl.py`; the capture host's push credential; the drafts to two fresh reviewers; this round to its reviewers.

### What the reviewers should attack first

1. D323: a copy or pull whose venue date misleads within the premise and moves a verdict; a margin the 30 days or the 61-day span still needs.
2. D324: a true delisting no flag qualifies; a false end left open; a relisting the per-name rule misreads.
3. D325: a drop that changes across captures or reads a later line; a contradiction now dropped; a crossing a drop makes likelier under the venue's null.
4. D326: books fed while prints go unread; books withheld on readable prints beyond the stated cost.
5. D327 to D330: a page sequence or finality query that passes wrongly; a run whose verdicts depend on which end applies; a substitution acceptance passes.
6. D331: any minute over 505.
7. D335: a run that passes while a drafted claim is false, or fails while it holds; whether the 5% paragraph's two assumptions are all the reading needs.

### Convergence

**Not converged.** Every finding of both reads of round 15 is answered at its cause. Four answers delete a rule: `halt_fee_witness`, `halt_substitution`, the reader's print rule, and the restart arithmetic. The others state the exact condition the old one approximated: the venue's clock for the host's, the flag's bounds, drops for single-event faults, every page for the first. One finding (Neon 5) is conceded as a stated assumption. Neither reviewer has read this round.

**Corrected at 23:21 UTC (18:21 EST), before anyone read this section:** D324's second bound, `R` at or before `B(e)`, follows from the first. Every hour from `w_start` to `R` holds a settlement, so an unsettled `B(e)` at or after `w_start` lies at or after `R`. So D324 is one bound, a flag dated at or after `w_start`, beside the per-name rule. Brief 4's end rule (`rearchitecture-s2`, the commit after this) states that bound alone.

## The last pass, round 17, study 2

Appended 2026-11-23 01:53 UTC (20:53 EST) by a fresh Opus 5.5 architect (maximum effort) for round 17's study 2 half, on branch `rearchitecture-s2`, beside the kernel half's round 17 on `rearchitecture`. Answered: Neon's read of round 16's study 2 half (`audit/reviews/2026-11-22-neon-round16-study2.md`, findings 1 to 6), the fresh Opus kernel review's finding 6 (`audit/reviews/2026-11-22-opus-round16-kernel.md`: the ending's `known` preceded the last fact its rule reads), and the human's decisions of 2026-11-22 as carried. Neon's review of round 16's criteria drafts was lost, so both drafts are given again whole and unreviewed. Report, with the criteria drafts in full near its top, the kernel changes to route and the build plan's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r17-s2-report.md`. Ids D337 to D344. No market data, nothing under `data/holdout/`, no token or key file, no request to the venue; `arithmetic.py.txt` neither called nor extended. `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **No trade or quote is checked against the coin's rules as last copied;** those rules govern the replica's own orders. Setting events aside by their content, round 16's way of surviving a lot-size change, could tilt the 5% at midnight (Neon). A lot-size change now costs nothing of the record.
- **The 5% argument names, once, the three ways the record can differ from what the venue did,** assumes none depends on where prices go next, and the report shows at each crossing whether it leaned on that.
- **No clock is trusted alone:** a time a verdict reads is the venue's, and a reply's date counts only when our receipt agrees within an hour, the check the recorder's quotes already had. The vault collector keeps no clock between runs.
- **A file already pinned keeps its first fingerprint;** a flipped bit is caught, not certified.
- **Counts are of what the venue sent, read or not,** for the vault's retention and for a delisting's finality.
- **A delisting is known only after the last hour its rule checks has passed.**
- **The one-off script's budget left with the retired `hl` recorder:** 205 of the venue's 1,200 a minute, 410 at most under kills.

### Who has seen what

- Neon read round 16 at `7982cbe`, without the criteria drafts' tail. Nobody has read this round's commits (`453c0c8` to the one that appends this).

### Agreed

- **From Neon's read of round 16:** D324 (the flag's bound, the per-name rule, the ending's `known` but for the kernel review's point, now D341), D328, D329, D332, D333, D334, D336; D326 in structure; D330 in mechanism (its condition, finding 3, is D339); D325's aim, the test's survival of a rules change (its means are replaced: D337).
- **From the fresh Opus's kernel read of round 16:** that `R_OFF_RULES` is gone from every live text and the reach rule matches A12 and K2.

### Settled by derivation in round 17, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D337 | Events off the copied rules (Neon 1; replaces D325's drop) | No quote or print read against its coin's rules: market sizes at a rules-free scale, no grid or lot check on market events, a resting order offered whole lots of the copied rules; what the model cannot read is no item, counted, and the router's print rule is the reader's; the drop outcome deleted; the 5% stated on the venue's events as the model prices them, with one assumption on the record's three differences and a count at each crossing | **Yes** (brief 4; `RECORDER.md`; `kernel-v2.md` A2, A3, A7, C2 and `KERNEL.md` A18, routed; the CS2.1 draft) |
| D338 | Clocks (Neon 2 and 5; amends D323) | The venue's stamps and servers' dates, the remote's push, and this host's clock as their witness: a venue time a line holds counts only where its `recv` is within an hour; this host's clock decides nothing alone and no program keeps it (`mmvault`'s `state.json`, hourly pull, watermark, overlap and daily trigger deleted; one pull a run from what is uncovered); no reader chooses a file by its name (the skip before `w_start − 24 h` deleted) | **Yes** (`VAULT.md`; `RECORDER.md`; brief 4; A18, routed) |
| D339 | Re-hashed closed files (Neon 3) | A pin, once made, is carried and never made again; Step 1 reads nothing of a file pinned closed; the hosts' `E_HASH` against the first pin settles `halt_storage_corrupt`; Step 1's length check deleted | **Yes** (brief 4, the capture) |
| D340 | Unreadable elements (Neon 4) | Retention and page counts by what the venue returned, read or not; an element of a coin's query is a row for an absence; a finality query delimited by coin, `endTime` and chain, its rows read and in order | **Yes** (brief 4; `VAULT.md`; A18, routed) |
| D341 | The ending's `known` (the fresh Opus's kernel F6) | `B(t_F) + late + listings.lag`, after the last fact the rule reads | **Yes** (brief 4; A18, routed) |
| D342 | The budget (Neon 6) | `ingest/hl.py` deleted on `main` with `hl`, its 300 and lock leave; sum 205; a kill can double a writer's minute, 410 | Text (`CLUSTER.md`) |
| D343 | Texts (Neon 6) | The re-pairing quantifier; a relisting within two hours of its delisting holds `T` to the last firing, stated; Month 1's wait for a coin delisted before `w_start`, noted | Text and a router test |
| D344 | The criteria drafts (replacing D335) | CS2.1's ends with end (1)'s list re-derived and the 5% paragraph re-derived; CS2.3 with retention by what the venue returned and the date witnessed by receipt; CS2.2 and the reserve stand | Advisor's criteria commit only |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D337 to D344 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A2, A3, A7, C2 and A18 for D337; A18 for D338, D340, D341; brief 3's table | For the kernel's architect, through the advisor; the size scale (6 proposed) is the kernel architect's | **Yes** (the frozen reader and admission) |
| D337's limit | An event the model cannot read that foretells a move (bids all pulled before a fall) makes the null false whatever the rule | Stated in the claim's paragraph, as rung 2's limit is | No, unless a reviewer shows a reading that removes it at no cost |
| D343 | A relisting within two hours of its delisting holds `T` to the last firing | A stated cost; settlements are by name, so no record tells it from a withdrawn flag | Only if a reviewer finds a record that does |

**Would any open point change what is built?** Yes: this round's review, the routed kernel changes (D337's above all), and the recorder build plan's two steps.

### Committed criteria: reported, not edited

- Two drafts in full near the top of the report (CS2.1's ends and CS2.3), replacing round 16's, which no model read whole; CS2.2's round 15 draft and CS2.1's reserve (round 14's) stand. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- None open.

### Owed

- **By the advisor:** route the kernel changes; the recorder build's two steps (routing; `mmvault`); the drafts to two fresh reviewers; this round to its reviewers.

### What the reviewers should attack first

1. D337: a record on which reading off-rule events changes a verdict the null does not cover; a kernel law a market size off the copied lots breaks; whether "an event the model cannot read moves no price" belongs in the null or in the assumption.
2. The 5% paragraph: a run that passes while the drafted claim is false, or fails while it holds; whether a crossing at a day's end valued at the venue's own prices needs no assumption, as claimed.
3. D338: two clocks within an hour of each other that still move a verdict; any decision left that reads this host's clock.
4. D339 and D340: a corruption the carried pins miss; a pull or a query that passes wrongly under element counts and delimitation.
5. D341: a fact the rule reads that `B(t_F) + late + lag` still precedes.

### Convergence

**Not converged.** Every finding of Neon's read of round 16 and the kernel review's sixth is answered at its cause, and three causes cover them: a choice of the record by content (D337), a clock taken alone (D338), and a reading that trusted what it computed over what it holds (D339 to D341). Each answer deletes what round 16 had added or kept: the drop outcome and the rules check on market events, `state.json` with the hourly pull, its watermark and the daily trigger, the stream files' skip by name, Step 1's length check, `ingest/hl.py`'s allocation. Nobody has read this round.

## The last pass, round 18, study 2

Appended 2026-11-23 07:07 UTC (02:07 EST) by a fresh Opus 5.5 architect (maximum effort) for round 18's study 2 half, on branch `rearchitecture-s2`, beside the kernel half on `rearchitecture`. Answered: Neon's read of round 17's study 2 half (`audit/reviews/2026-11-23-neon-round17-study2.md`, findings 1 to 6), the kernel half's two routed corrections (offered whole lots; test 10's time), and the advisor's brief to cut the spec rather than grow it. Report, with the criteria drafts in full, the kernel changes to route and the build plan's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r18-s2-report.md`. Ids D345 to D352. No market data, nothing under `data/holdout/`, no token or key file, no request to the venue. `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **A day, once replayed, is never read differently:** a line written about it afterwards is counted and ignored. So a verdict named one month is named again every later month, as the committed criteria always said, and the machinery six rounds built to catch a changed day (re-checking published days, ending the test there, a chain of states, withdrawals, halts) is deleted.
- **Each month's snapshot fingerprints a file once, after it has sat unchanged a month;** each machine reads each file once. Packing goes. Results come a month later.
- **A delisted coin ends only where the record is silent around its flag, and nothing recorded is thrown away;** the thirty-day finality wait goes.
- **The 5% claim says only what it shows.** The vault collector runs daily, reads none of its own files, and asks for everything from November 1st; the entry check waits for one complete download a month after its 61 days.
- **Nothing halts;** a month two machines cannot agree on is skipped and logged.
- **Brief 4 halved** (169,783 bytes to about 79,000), `VAULT.md` and `RECORDER.md` shorter.

### Who has seen what

- Neon read round 17 at `1457cb3`, without `RECORDER.md`'s tail and `CLUSTER.md`. Nobody has read this round's commits (`bacabdb` to the one that appends this).

### Agreed

- **From Neon's read of round 17:** D337's core (no market event read against its coin's rules), D338's two-clock witness in principle (kept for the horizon's book line; the copies' and pulls' dates are now read by nothing), `state.json`'s deletion, D340's element counts (kept for the whole pull), D339's direction for closed files, D342, D343.
- **From the kernel half's round 17:** the recorded size offered as recorded, with T1, E1, L4 and F0 as they stood.

### Settled by derivation in round 18, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D345 | The cause under every finding: a later replay read a record grown behind published days | **A line added behind is not read:** a line of a file first listed by capture `s`, stamped before the horizon of capture `s`'s replay where that replay ran a day, is counted and not fed. The record of every time a replay ran is the same in every later replay, so "what a day's end showed stands" holds as committed. Deleted: the prefix check, `T*`, the state chain and `accepted.tsv`'s links, withdrawals, carried verdicts, the three halts | **Yes** (brief 4, steps 6 and 7; A18 and A13, routed; the CS2.1 draft) |
| D346 | Files re-hashed into captures (Neon 1); pre-start files re-read (Neon 6a) | One table a month, a file hashed once after a month at rest and its hash carried; a replay reads hashed files only; a host reads each once and keeps its lines. Deleted: closed-file tests, open-file pins, the `fsync` chain, Step 1's lock, the two-host packs, `mmrec cat`'s length | **Yes** (brief 4, wall 2; `RECORDER.md`; brief 3, routed) |
| D347 | How far a replay runs | To the midnight that began the capture before's day, every coin settled through it or ended, a book received on time past `T + 1 h`; each horizon at least the one before, by D345 | **Yes** (brief 4, wall 3) |
| D348 | A listing's end (Neon 5b, 4b; replaces D306, D307, D324's finality and D341's `known`) | A flag at `e` with the coin silent from `e − 1 h` to `e + 1 h` ends it at `E`, the first whole hour after its last event before `e − 1 h`, used only past `e + 1 h`; no event cut; known at `e + 1 h` plus the greatest lag. Deleted: the cut between `R` and the flag's bound and its count, `B(e)`'s check, the 30-day query and its rules, Month 1's wait. Cost: a held coin whose book came after its last settled hour stops the run | **Yes** (brief 4, wall 4; A18, routed) |
| D349 | CS2.3's coverage (Neon 4a, 4c; replaces coverage by instants) | One whole pull from at or before `w_start`, not listed by the capture of a firing 30 days after the 61st day, with fewer than 10,000 elements from `w_start` on, counted as returned; the clock the captures'. Cost: about six months; a vault three times busier leaves it "not judged" | **Yes** (brief 4, wall 5; `VAULT.md`; the CS2.3 draft) |
| D350 | `mmvault` (Neon 3) | Daily and stateless: fills and funding from 2026-11-01 with no `endTime`, funding paged at its last row's time inclusive, fees and orders; no stored file read. Deleted: pulls from what is uncovered, the identity rebuild, `new`, the 5,000 alarm, the vault pulls' directory `fsync`s | **Yes** (`VAULT.md`) |
| D351 | The 5% paragraph (Neon 2); clocks (Neon 6b) | The null on the record as the model prices it; the assumption over the whole path; a crash shown only as one-sided books is a move the record does not make; what the record lacks reported, certifying nothing. The crossing diagnostics and the venue's-wealth sentence deleted. Copies by receipt; the reply's `Date` deleted from the recorders and readers | **Yes** (the CS2.1 draft; `RECORDER.md`; A18, routed) |
| D352 | The criteria drafts (replacing D344); texts | CS2.1's ends (final, complete, the last firing at 31 days, the operator stop), the record read once and the 5%; CS2.2's operator stop; CS2.3's whole late pull; the reserve's stands. Brief 4's offered sizes as recorded (the kernel half's correction); the fee witness and layers 1 and 2 in `study2 measure`, outside the build; brief 4's header cut to a pointer here | Advisor's criteria commit; text |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D345 to D352 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18 (copies by receipt, the end, lines added behind, a failed checksum, kept lines), A13's identity, brief 3's step 6, step 9 and table | For the kernel's architect, through the advisor | **Yes** (the frozen reader and identity) |
| GPT's round-4 objections | A lever in when the first reading is made; a wait that avoids a stop; the first of a key | Met in the report ("The cause"): the capture's time is the calendar's and the remote's; the wait adds crossings only inside the one bound; a second settlement of an hour is never fetched (H16) | **Yes**, if GPT finds a lever the capture leaves |

**Would any open point change what is built?** Yes: this round's review, and the routed kernel changes, which the frozen reader carries.

### Committed criteria: reported, not edited

- Three drafts in full near the top of the report (CS2.1's ends, CS2.2's operator stop, CS2.3), replacing round 17's; CS2.1's reserve draft (round 14's) stands. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- None open.

### Owed

- **By the advisor:** route the kernel changes; the recorder build's changes (`mmvault` daily and stateless first); the drafts to two fresh reviewers; this round to Neon, then GPT.

### What the reviewers should attack first

1. D345: two replays that read one time differently; a lever in a capture's timing; a line not read whose absence moves a verdict outside the null.
2. D347: an honest record whose horizon never passes; one that passes a missing settlement.
3. D348: a live coin ended; a delisted coin never ended; the end's `known`.
4. D349: a pull that passes while retention cut a fill of the 61 days.
5. D346: kept lines that read otherwise than the file.
6. D352: a run that passes while a drafted claim is false, or fails while it holds.

### Convergence

**Not converged, and re-derived rather than patched.** Every finding of Neon's read of round 17 is answered at one cause, a later replay reading a record grown behind published days, which rounds 2 to 17 handled by machinery around it. D345 removes the cause, and the machinery goes with it: the prefix check, `T*`, the state chain, withdrawals, halts, finality, coverage by instants, the reply's date, packs and the capture's durability rules. Nobody has read this round.

## The last pass, round 19, study 2

Appended 2026-11-24 06:36 UTC (01:36 EST) by a fresh Opus 5.5 architect (maximum effort) for round 19's study 2 half, on branch `rearchitecture-s2`, beside the kernel half on `rearchitecture`. Answered: Neon's read of round 18's study 2 half (`audit/reviews/2026-11-24-neon-round18-study2.md`, findings 1 to 6, "still larger than its cause" and "what the deletions lost"), and the advisor's two questions: whether what a replay reads for a day can be fixed by that day alone, and whether the monthly verdicts are worth what "a published day stands" costs. Report, with the criteria drafts in full, the kernel changes to route and the build plan's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r19-s2-report.md`. Ids D353 to D360. No market data, nothing under `data/holdout/`, no token or key file, no request to the venue. `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **Each day's record is fixed by the calendar, not by history:** a line counts for its day only if its file was on disk by the start of the second month after the day's month, and a day is first judged in the third month after its own. Every month's report then agrees with every other about every day they share, and no replay needs to know what an earlier one did, which round 18's rule needed and nothing recorded (Neon's first finding).
- **The cost is a month of delay; the gain is a month of margin:** a collector down for up to a month loses nothing (Neon's third finding).
- **A delisted coin is cashed out an hour after the delisting notice,** once the silence that proves it is past, so the test never spends money it could only know it had by looking ahead (Neon's second finding, a fair market on which round 18 passed the 5%).
- **The entry check is judged on one download of the vault's fills,** the first complete one made a month after its 61 days, and on those 61 days' fills alone; the vault collector no longer stops for one odd fill (Neon's fourth finding).
- **Listing copies are timed by the venue's clock again, checked against ours** (Neon's fifth finding); **two machines agreeing on rows that contradict an accepted month end the test there** (Neon's sixth).
- **The monthly verdicts are kept:** they are what make the visible reports and the human's budget stop harmless.

### Who has seen what

- Neon read round 18 whole at `652900a` and accepted its direction. Nobody has read this round's commits (`e4dd658` to the one that appends this).

### Agreed

- **From Neon's read of round 18:** the capture that hashes a file once at rest (D346's core); the daily, stateless `mmvault` with inclusive funding pages (D350's core); the 5% paragraph's null on the record and its path-wide assumption (D351's core); CS2.2's operator stop; the recorded size offered as recorded; `study2 measure` outside the build; `CLUSTER.md`'s weights and `RECORDER.md`'s routing and `mmrec cat`.

### Settled by derivation in round 19, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D353 | What a replay reads depends on the history of captures and replays (Neon 1; replaces D345's rule and D347's bound) | **The record of a time is fixed by the calendar:** an item is read only where its file's `since` is at most the second month after its time's; the replay of month `k` runs the days of months up to `k − 3`, whose records its table holds whole. No date, earlier horizon or first-settled replay is read. One missing capture loses no file written on time; two running stop the test. Cost: a day first judged two to three months after it | **Yes** (brief 4, step 7, walls 1 to 3; A18 3a, routed) |
| D354 | The listing's end settled before the silence that decides it (Neon 2; replaces D348's timing) | The listing ends at `e + 1 h`, after every fact it reads, settling at the coin's price there and beginning the span there; the funding ends at `E`, which moves no wealth and only makes the hours from `E` undue | **Yes** (brief 4, wall 4; A18, routed) |
| D355 | A delisted coin's funding; walls 3 and 4 deciding each other (Neon 3) | Every hour before a coin's funding end needs its settlement, held or not; a backfill within the month of margin is read; an end is decided from fixed records and used by the horizon only where they are fixed. Deleted: the exemption "for every hour before its last settlement". The settled collector reads its files as the reader does, no longer stopping for good at one corrupt file | **Yes** (brief 4, walls 3 and 4; `VAULT.md`) |
| D356 | CS2.3's judging replay and its union of pulls (Neon 4.1) | One pull judges: the earliest whole late pull by `since` then path, the same in every table; its fills of the 61 days alone, each coin chained from its first there at the venue's `startPosition`; an unreadable element withholds only where its place in the pull's order may fall in the 61 days. Deleted: the first settled replay, the union, the copy before 2026-11-01 as input, the chain from the vault's first fill | **Yes** (brief 4, steps 1 and 7; the replay of given fills, routed; the CS2.3 draft) |
| D357 | `mmvault`'s fail-stop (Neon 4.2) | A page is checked only for what asking the next needs, the rest stored as served; a reply that fails its check fails its own pull, and only a failed request stops the run | **Yes** (`VAULT.md`) |
| D358 | Copies by receipt alone (Neon 5.1); GPT's round-4 objections (Neon 5.2) | Copies timed by the reply's date within an hour of their `recv` again (D338 restored; round 18's routed item 1 withdrawn); the capture's lever stated as an assumption and shown by a test; "What it adds" says plainly that a backfill within the months adds passing paths | **Yes** (`RECORDER.md`; the CS2.1 draft) |
| D359 | Kept lines, the cost before `w_start`, the halts (Neon 6) | Kept lines hold what some replay reads, with the counts of the rest and the stream's end, under their own checksum; every host reads each file in the month it is first hashed; a settled report whose rows of a day differ from an accepted one's ends the test at the accepted one | **Yes** (brief 4, walls 2 and 6; A18 3c, routed) |
| D360 | The criteria drafts (replacing D352) | CS2.1's record fixed by the calendar, the last firing in the third month after the 730th day's, a fifth end (a build fault), the listing's end after its facts, the lever stated, "What it adds" both ways; CS2.2's operator stop; CS2.3 on one pull with a chain of the 61 days; the reserve's stands | Advisor's criteria commit; text |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D353 to D360 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18 (the listing's end and the funding's end, the record of a time, kept lines; copies' date kept, whose whole seconds meet every tick, so the order of a millisecond the fresh Opus's finding 1 on the kernel's round 17 asks R1 to state decides every rule change), A13's identity, the replay of given fills from a given position, brief 3's step 6, step 9 and table | For the kernel's architect, through the advisor | **Yes** (the frozen reader and identity) |
| The capture's lever | A capture made late can bring a file written in its delay into the record of the month two before | An assumption, stated in the CS2.1 draft like the registration's push time; the acceptance logs every delay | No, unless a reviewer finds a way to close it at no cost |

**Would any open point change what is built?** Yes: this round's review, and the routed kernel changes, which the frozen reader carries.

### Committed criteria: reported, not edited

- Three drafts in full near the top of the report (CS2.1's reading and ends, CS2.2's operator stop, CS2.3), replacing round 18's; CS2.1's reserve draft (round 14's) stands. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- None open.

### Owed

- **By the advisor:** route the kernel changes; the recorder build's changes (the listings `date` built again, `mmvault`'s page checks and run stop, the settled collector's scan); the drafts to two fresh reviewers; this round to Neon, then GPT.

### What the reviewers should attack first

1. D353: two replays that read one time differently; what a late, a missing or two missing captures change; a day run before its record is whole.
2. D355 with D353: an honest record whose horizon never passes where it should, or one that passes a hole; whether each horizon is at least the one before where an end becomes decidable later.
3. D354: any wealth, bar or guard state set before `e + 1 h` by what follows it; a live coin ended.
4. D356: a pull that passes while retention cut a fill of the 61 days; the placement of an unreadable element; what the chain of the 61 days lets through.
5. D359: a kept form that reads otherwise than its file; the end at a build fault where the accepted report was the wrong one.
6. D360: a run that passes while a drafted claim is false, or fails while it holds.

### Convergence

**Not converged, and re-derived where round 18's mechanism patched.** Neon's three findings on round 18's mechanism (1, 2, 3) had one cause: what a replay read for a day hung on the history of captures and replays, which no table holds. D353 fixes the record of a day by the calendar, which needs no history, and the patches Neon proposed for it (each table carrying every capture's date, a sequential horizon algorithm, a post-`E` funding query) are not needed. Findings 4 to 6 are answered at their causes (CS2.3 judged on what no later pull changes; a collector checking only what it needs; a clock check deleted too soon; a cache with no check). Nobody has read this round.

### Open questions

- **For the human:** none. **For the advisor:** routing the kernel changes (the report's list: the listing's end as two records, the record of a time, kept lines, the replay of given fills from a given position; round 18's routing of copies by `recv` withdrawn), and whether the month of delay this round adds (a day first judged two to three months after it, the last firing in the third month after the 730th day's) goes into the plain summary as a cost of the design.

## The last pass, round 20, study 2

Appended 2026-11-24 15:32 UTC (10:32 EST) by a fresh Opus 5.5 architect (maximum effort) for round 20's study 2 half, on branch `rearchitecture-s2`, beside the kernel half on `rearchitecture`. Answered: GPT-6.2's read of round 19's study 2 half (`audit/reviews/2026-11-24-gpt62-round19-study2.md`, sections 1 to 6) and, routed by the advisor mid-run, the part of GPT-6.2's read of kernel round 18 that is this half's (`audit/reviews/2026-11-24-gpt62-round18-kernel.md`, "Listing ends and reader order"). Report, with the criteria drafts in full, the kernel changes to route and the recorder build's changes: `/home/kevin/repos/moneymachine/data/builder/architect-r20-s2-report.md`. Ids D361 to D370. No market data, nothing under `data/holdout/`, no token or key file, no request to the venue. `PROGRESS.md`, `audit/criteria.md`, `kernel2/`, `kernel-v2.md` and brief 3 untouched.

### In plain words

- **A delisted coin is ended only on the venue's own word:** its flag, and its funding history showing it settled nothing for the two hours around the flag. Our recorder stops recording a coin at its flag, so the silence of our own record proved nothing (GPT).
- **An hour the venue says it did not settle pays nothing and no longer stops the test;** an hour we failed to ask about still does. A coin delisted before the start whose flag the venue later dropped no longer stops the test on its first hour (GPT).
- **No rule change is read before the venue could have written it:** a reply counts from the later of its two clocks, the venue's and ours, so either clock alone keeps it safe (GPT rebuilt Neon's 8.52% false passes from a reply dated early).
- **The vault download that judges the entry check is dated by its own first request;** fills repeated across its pages count once; fills of one millisecond may chain in any order (GPT).
- **A contradiction between two accepted months ends the test without keeping any verdict it touches,** and only the engine's rows are compared.
- **The criteria drafts share one statement of the reading and the ends,** and each condition has one judgment rule.

### Who has seen what

- GPT-6.2 read round 19 at `93b1c4e` and kernel round 18 at `5dedbc6`; Neon read round 18. Nobody has read this round's commits (`bad3522` to the one that appends this).

### Agreed

- **From GPT's read of round 19:** the calendar cutoff; monthly reports on one path; the operator's budget stop on one adapted path; cash release and the span change at the listing's end, with `E` only of funding (now deleted, D362); full hourly coverage before an end, held or flat; the restored `Date`'s cure of a host step-back with a truthful venue date; one vault pull, a bounded matching window, payload isolation, rescanning corrupt funding files; the reduced cache, its checksum and early population; ending on a genuine prefix contradiction; fixed valuation and variance thresholds; strict entry majorities.
- **From GPT's read of kernel round 18:** A3's canonical sort and deleting the honest-reader stop for disorder; whole-file capture hashes, the kept-lines checksum, the forward identity, the packs' deletion; A18 as the readers' one home; per-coin starting positions for given fills.

### Settled by derivation in round 20, study 2 (not yet reviewed)

| ID | Point | Settled by | Changes what is built |
|---|---|---|---|
| D361 | A copy dated before its state (GPT on round 19, 2: Neon's 8.52% rebuilt); replaces D358's "by the `Date`, within an hour of `recv`" | **A reply is placed by its two clocks:** if either is right it was made after `min(date, recv) − 30 s` and before `max(date + 1 s, recv)`. A copy is in force from the later, `w_start`'s rules included; a reply's reach runs to the earlier. The hour check is deleted: an off clock only delays. Every REST line keeps `date` | **Yes** (brief 4, wall 4; `RECORDER.md`; `VAULT.md`; A18, routed) |
| D362 | Absence in our record read as the venue's (GPT on round 19, 3: a pre-start delisting whose flag is gone held every horizon) | **An hour is settled, shown unsettled, or a hole:** shown unsettled where whole replies cover its span of lateness and no settlement names it; it pays nothing and holds nothing. A failed pull leaves no reply, so no failure of ours shows an hour unsettled. Round 19's funding end at `E` (`Payload.fundingEnd`) deleted. V23 (the venue's funding replies omit nothing) routed, as V18 is of fills | **Yes** (brief 4, walls 3 and 4; `VAULT.md`; A18 and V23, routed) |
| D363 | A live coin ended by a flag and our own unsubscribe's silence; an event at the window's end; an unflagged copy before the end (GPT on round 19, 3; GPT on kernel round 18); replaces D354's end | **A listing ends on the venue's evidence, after all of it:** a flag in force at `e`; from `e − 1 h` to `e + 1 h`, both included, no book, print or settlement of the coin, and whole replies covering the span; no copy within the hour after giving it rules. The end is at the millisecond after the span. Our unsubscribe can only remove a blocker. Missing replies end nothing, and their hours hold the horizon | **Yes** (brief 4, wall 4 and test 12; A18, routed) |
| D364 | CS2.3's pull dated by other files' `since` (GPT on round 19, 4); replaces D356's lateness | **Late is the pull's own:** its first reply made 30 days or more after the 61st judged day ended, by its two clocks. The earliest is still by `since` and then path. The other-file proxy deleted | **Yes** (brief 4, wall 5; `VAULT.md`'s lines with `date`) |
| D365 | Retention's conclusion and the count (GPT on round 19, 4) | Stated conditional on V18's "returns every fill it keeps"; the count is of distinct fills, each unreadable element one | **Yes** (brief 4, wall 5 and test 5) |
| D366 | The chain's greedy order within a millisecond rejects a valid chain (GPT on round 19, 4) | **`chained` tries every order** and returns one for the replay of given fills; M4 states existence; the search is millisecond by millisecond | **Yes** (brief 4, step 1; brief 3's replay of given fills fed that order, routed) |
| D367 | An endpoint-local failure withholds the day's fees and orders (GPT on round 19, 4); refines D357 | A failed request fails its own pull, the run going on; a sixth 429 ends the run, its limit being the IP's | **Yes** (`VAULT.md`) |
| D368 | The third host's cache, persistent no-output runs, the build fault's comparison and its kept verdict (GPT on round 19, 5); refines D359 | Every host keeps each month's files whether or not it runs; retries end at the next firing; the acceptance compares the engine's rows only; a build fault ends the test with both reports kept and a verdict standing only on rows both give | **Yes** (brief 4, walls 2 and 6, test 13) |
| D369 | The run id's order and a decoder's error read as a cut (GPT on kernel round 18) | `RECORDER.md`'s run numbering stands (test 22); the build (`writer.ml`) owes it. A stream is complete, cut, malformed or corrupt; `mmrec cat` exits 2 on corrupt; nothing of a corrupt stream is read or kept; the build (`recording.ml`) owes it | **Yes** (`RECORDER.md`; the recorder build; A18, routed) |
| D370 | The criteria drafts (GPT on round 19, 6; replacing D360) | One shared revision beneath the definitions (the reading, the reports, the ends); CS2.1 with "outgrew"'s conservatism; CS2.2 by an accepted report, with the backfill's added "held"; CS2.3 with one judgment rule and its added "met" paths; the missing-capture guarantees stated as they hold (GPT 1) | Advisor's criteria commit; text |

### Disputed, or open

| | Point | State | Would change what is built |
|---|---|---|---|
| D361 to D370 | This round | Settled by derivation; read by no model | **Yes**, if broken |
| Routed | A18 (a reply's two clocks and reach, what a reply covers, the unsettled hour, the listing's end, a stream's four states, a duplicate's place), V23 and V18's cell, brief 3's step 2, tests 13 and 15 and its table | For the kernel's round 19, through the advisor | **Yes** (the frozen reader) |
| The recorder build | Run numbering and the decoder's states, specified and not built | Owed before the freeze | **Yes** (the deploy) |
| The captures' lever | A late capture can bring a file written in its delay into the record of the month two before | An assumption, stated in the CS2.1 draft; GPT accepts the cutoff under it | No |
| V23 | The venue's funding replies leave out no settlement it made | An assumption of the kind V18 is, witnessed on the vault's held days | No, unless a reviewer finds the silence can depend on prices |

**Would any open point change what is built?** Yes: this round's review, and the routed kernel and recorder changes.

### Committed criteria: reported, not edited

- Four drafts in full near the top of the report: a shared revision beneath "The days run", CS2.1, CS2.2 and CS2.3, replacing round 19's three; CS2.1's reserve draft (round 14's) stands. For two fresh reviewers, then the advisor's commit.

### Assumptions only the human can choose

- None open.

### Owed

- **By the advisor:** route the kernel changes and V23; the recorder build's two defects (run numbering, the decoder's states) and its changes (every REST line's `date`, per-pull failures); the drafts to two fresh reviewers; this round to Neon, then GPT.

### What the reviewers should attack first

1. D361: a reply both clocks misplace the same way while each passes; whether the two bounds hold of a reply's content (a cached body, a `Date` set before the body, a timeout anywhere longer than 30 s).
2. D362: a record on which our own failure shows an hour unsettled; a reply credited with more than it covers; whether a reply's silence can depend on where prices go next (V23 as a lever).
3. D363: a live coin ended; a dead coin never ended where a relisting under its name is then fed; anything set at the end by what follows it.
4. D364 to D366: a pull late by its clocks and not by its asking; a chain an order passes where the record is wrong; the distinct count against V18.
5. D368: a build fault the engine-row comparison misses; a contested verdict the rule keeps.
6. D370: a run that passes while a drafted claim is false, or fails while it holds.

### Convergence

**Not converged, and re-derived where round 19 patched.** GPT's two points that the advisor flagged as our own doing and the venue's dates had one cause each. The silence: rounds 18 and 19 read the absence of a settlement, book or print in our record as the venue's; only the venue's reply can say what it did not do, so D362 and D363 rest every silence on a reply, which deletes the funding end and answers both directions of GPT 3 (a live coin ended, a dead one never) and the kernel review's boundary and unflagged-copy cases with one concept. The dates: rounds 18 and 19 each trusted one clock and fell to the other's fault; D361 places a reply between its two clocks, using the bound that is safe for each use, which answers the backdated copy and the pull's dating (D364) with one rule and deletes the hour check. The rest are fixes at their causes: a greedy rule where existence was meant (D366), a stop wider than its failure (D367), a comparison of rows no prefix fixes and a verdict kept past its contradiction (D368), and two build defects against a spec that is right or now says so (D369). Nobody has read this round.

### Open questions

- **For the human:** none. **For the advisor:** routing the kernel changes and V23 (the report's list), the recorder build's owed fixes, and whether the plain summary says that an hour the venue's own reply shows unsettled now pays and holds nothing, a trust in the venue's funding history like the one already placed in its fill history.


## Project Reset and Spec Freeze (2026-11-25 06:48 UTC / 2026-11-25 01:48 EST)

**Convergence: FROZEN.** Under the **honest-but-buggy** threat model and the <=2-round materiality-capped review rule, this entry closes the 20-round specification loop and freezes the consolidated specifications across `audit/program/kernel-v2.md`, `kernel2/KERNEL.md`, `audit/program/briefs/3-kernel-v2.md`, `audit/program/briefs/4-study-2.md`, `audit/program/architecture.md`, `audit/program/arithmetic.py.txt`, and `audit/program/python-extinction.md`.

### What is consolidated and frozen

1. **Kernel v2 (`kernel-v2.md`, `kernel2/KERNEL.md`, `briefs/3-kernel-v2.md`):**
   - **Compiler-sandbox dropped:** replaced the 8-round two-stage clean-compile boundary (`engineExport`/`engineClean`/`engine.kexp`/`CleanPrelude.lean`/`stage2-clean.lean`/`primitives.txt`/`frozen.txt`) with the honest-but-buggy proof gate (`kernel2/lean/check-proofs.sh`): offline Lake build + Lean `collectAxioms` admitting only `{propext, Classical.choice, Quot.sound}` + static allowlist scan banning unapproved `@[implemented_by]`, `@[extern]`, `unsafe`, `partial`, and bare `axiom`, verified by `checks.engine-proofs-fixtures` (`BadImplementedBy.lean` etc.).
   - **Pinned MPFR (`pkgs.mpfr`) adopted for `exp`/`log`:** `Engine.Exact.exp` and `Engine.Exact.log` bind via `@[extern]` to `kernel2/lean/c/mpfr_ops.c` (`mm2_mpfr_exp`/`mm2_mpfr_log`), rounded once to 53-bit binary64 with IEEE subnormalization (`mpfr_subnormalize`) and canonical quiet NaN. Deleted exact-rational series `X4` formulas, `@[csimp]` incremental `expFast`/`logFast`/`nearestBitsFast` twins (`X6`), the `x4-counts` 15-CPU-day sweep, and `O26`. Step 5 Test 12 verifies pinned MPFR bit-for-bit across boundaries, all four IEEE rounding modes, and CORE-MATH hardest inputs (plus `nearestBits` `X5` against `mpfr_set_q`) and asserts production `mm2` links pinned `libmpfr` while forbidding glibc `libm` `exp`/`log`.
   - **Decoupled `kernel2/` sub-flake:** documented `kernel2/flake.nix` + `kernel2/flake.lock` (sha256 `415c302c51d5ef65241ba0c845256bceca418b90da4df45cc0d71e4eb139153b`), pinning Lean 4.34.0, OCaml 5.4.1, and `pkgs.mpfr`/`pkgs.gmp` independently of root and live recorders.
   - **Step 5x trimmed:** reduced to the decoupled sub-flake, pinned MPFR, `check-proofs.sh`, and Round 19/20 machine/observation alignment on Step 5, ready to merge into `kernel2-build` and execute Steps 5a → 6 → 7 → 8 → 9 → 10 immediately.

2. **Study 2 (`briefs/4-study-2.md`, `architecture.md`, `kernel2/KERNEL.md`):**
   - **Kernel Round 20 simplifications folded in:** universe coin rules (`sz_decimals`, `figures = 5`, `decimals = 6 − sz_decimals`, `tiers`) and active (unflagged) flags fixed at registration from one hashed copy of `meta` (`TON` flagged out in `meta-2026-11-16.json`, verified emitting 0.0 funding rows for 1,117 hours after delisting, V25); midnight coin-end rule on a quiet zero-funding UTC day (`KERNEL.md` A18); day-late `unsettled` hour rule (V24); Hierholzer linear-time `chained` and pre-chain conflict rejection; zero `Payload.listing` / hourly listings-copy baggage in judged code.
   - **Single-host deterministic replay:** forward capture/replay simplified to deterministic single-host monthly replay over a hash-verified capture manifest (`audit/study2/captures/<YYYY-MM>.tsv`, verified by SHA-256 and checked for determinism under A13/D1 plus prefix consistency against the previous accepted report), dropping multi-host 2-of-3 consensus.
   - **Branch reconciliation:** `mm-program-s2`'s stalled Round 21 merge (`MERGE_HEAD = e9f2e8c` over `844bd06`) left zero committed Round 21 changes and is superseded by this freeze. Committed `CS2.1`–`CS2.3` in `audit/criteria.md` remain completely untouched (minor wording alignment owed only if criteria text is ever formally revised is noted in `briefs/4-study-2.md`).
   - **Honest power expectation:** Study 2 is expected to end `"not confirmed"` at long-only ladder volatility ~0.25–0.50; its primary empirical value is prospective measurement of fill-model fidelity (layer 2), volatility transport (CS2.2), and entry reproduction (CS2.3) beside the reopened Earlier-Cutoff (`briefs/5-earlier-cutoff.md`) and Unhinted-Search (`briefs/6-unhinted-search-dsl.md`) tracks.

3. **Python Extinction (`python-extinction.md`):**
   - Brought in Revision 3 (`2941cad`) and re-sequenced remaining Python → OCaml ports (`mmdata`, `mmops`) to **Phase 2** (after Study 2 freezes and Phase 1's urgent live fixes — including the immediate in-place GDELT retry fix in `ingest/datalayer.py` — deploy), with direct spec+test builds and zero multi-round architect churn.
