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
