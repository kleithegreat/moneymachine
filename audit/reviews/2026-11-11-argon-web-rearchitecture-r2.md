# Adversarial review of the rearchitecture, revision 2, by Gemini 4 Argon (web UI), 2026-11-11

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial (CLAUDE.md, Orchestration). This is the second and last fix round.
- **Bundle:** `~/Downloads/argon-rearchitecture-r2.md`, branch `rearchitecture` at `35cf871`, with the human's answers to section 12 added. It gave the reference stake as $2,500 per purchase. The human later set $2,500 as the bankroll, so $125 per purchase (`audit/decisions.md`, 2026-11-11 17:25 UTC (12:25 EST)), which weakens finding 3.
- **Format:** two parts, saved by the human as a PDF at 2026-11-11 17:35 UTC (12:35 EST). The PDF is filed beside this file.
- **Text:** below, extracted with `pdftotext` and otherwise unchanged. Mathematics the extraction garbled is legible in the PDF.

**Verdict:** do not approve; return to the root. There are 4 critical findings (the mirror account, the stake and pause rules, the stake's depth on Kalshi, and study 1's operating table under independence), 3 high and 3 medium. By the two-round rule the architect re-derives (CLAUDE.md, Reviews).

---

11/11/26, 12:35 PM                                                                      See attached instructions.



     See attached instructions.
     https://gemini.google.com/app/3f7a358f71f43808

     User prompt: See attached instructions.
     Response: Verdict: Do not approve revision 2; the design must return to its root. Moving
     Study 2 to a self-financing account under Ville's inequality fixes the Student-t failure of revision
     1, and pairing Study 1 on the same markets removes the uncalibrated point null. However,
     revision 2 introduces critical theoretical breaks in both studies: Study 2's mirror account tests a
                                                                                                 1
     point-wise null (∀i, μi ≥ ci ) whose negation is not portfolio loss, and its leverage map 1−c
                                        ​       ​                                                                                             ​




     allows a genuinely profitable procedure to hit 20 on the mirror first and be falsely judged a net
     loser; the recommended half-Kelly stake rule is not a proper scoring rule for log wealth, hitting
     Brief 2's own wall by incentivizing 2x edge exaggeration while deploying roughly half the capital
     assumed in the power table; the pause rule (cash + open cost >= 20) is invariant under
     purchases and permanently deadlocks if one settlement record is lost; the human's $2,500
     reference stake on Kalshi's 7-day universe collapses admissible breadth below the 30-
     event/week abort wall; and Study 1's paired SPRT operating table (arithmetic.py.txt) was
     computed under the false assumption that the two arms are statistically independent on the
     same market.

     Ranked Findings (Part 1 of 2)
     1. Critical — Study 2's mirror account tests the wrong null, subsidizes fees, and falsely
     convicts profitable procedures

             Where: architecture.md §5.2: "The mirror. A second account, computed from the same
             record, buys for each purchase the complementary claim, which pays 1 − x, at 1 − c,
             staking the fraction of its own cash that the account staked of its cash. Under the
             hypothesis that every purchase had non-negative expected net return it is a non-negative
             supermartingale. If it reaches 20, that hypothesis is rejected at 5% and the procedure is said
             to lose net of costs." Also §4, §8, and paper-changes.md A7.
             Construction:
                     1. Logical mismatch between null and claim: The main account's null is H0+ :                                         ​




                        ∀i, E[xi ∣ Fti ] ≤ ci , whose negation is ∃i, E[xi ∣ Fti ] > ci . The mirror account's
                                ​

                                            ​
                                                        ​                                                     ​

                                                                                                                          ​
                                                                                                                              ​       ​




                        null is H0− : ∀i, E[xi ∣ Fti ] ≥ ci . The negation of H0− is not that "the procedure's
                                    ​                       ​


                                                                        ​
                                                                            ​       ​                             ​




                        purchases lose net of costs"; it is merely ∃i, E[xi ∣ Fti ] < ci (at least one purchase
                                                                                                          ​
                                                                                                                      ​
                                                                                                                          ​       ​




                        had negative expected net return). Any real procedure with heterogeneous bets
                        violates both H0+ and H0− simultaneously.
                                                    ​               ​




                                                1
                     2. Leverage distortion 1−c     vs. 1c : When the main account stakes fraction f of cash at
                                                                ​               ​




                        cost c, its payout multiplier per unit is 1c . The mirror stakes the same fraction f of
                                                                                          ​




https://gemini.google.com/app/3f7a358f71f43808                                                                                                    1/14
11/11/26, 12:35 PM                                          See attached instructions.

                                                                             1
                       mirror cash at price 1 − c, giving payout multiplier 1−c . On a favorite at c = 0.95
                                                                                     ​




                       with f = 0.05, a loss (x = 0) costs the main account 5% of cash, but pays the
                       mirror account 0.05 × 0.95
                                               0.05
                                                  ​ = +95% of its entire cash (nearly doubling the mirror in
                       one bet). Conversely, on a cheap contract at c = 0.20, a win pays the main account
                       4f but costs the mirror only f , while a loss pays the mirror only 0.20
                                                                                          0.80
                                                                                             ​ f = 0.25f .

                     3. Profitable run that fails via the mirror: Suppose each week the procedure makes
                        30 purchases at all-in cost c = 0.20 where true win probability is q = 0.22 (a
                        +10% net edge per dollar staked), staking half-Kelly f1 = 0.22−0.20
                                                                                    2(0.80)
                                                                                         ​   = 0.0125 or a
                                                                                                 ​




                        moderate f1 = 0.03125 of cash each, and 5 purchases on favorites at c = 0.95
                                    ​




                        where the agent reports p = 0.96 (f2 = 0.05) but true probability is q = 0.88 (a
                        −7.37% net loss per dollar on those 5 bets).

                            Main account: Weekly expected net return is 30(0.03125)(+0.10) +
                            5(0.05)(−0.0737) = +0.09375 − 0.01842 = +7.53% of cash per week.
                            Weekly expected log growth is 30[0.22 ln(1.125) + 0.78 ln(0.96875)] +
                            5[0.88 ln(1.00263) + 0.12 ln(0.95)] = +0.0393 − 0.0192 = +0.0201 per
                            week (reaches 20 in ∼ 149 weeks).

                            Mirror account: On the 30 bets at 1 − c = 0.80 (1 − q = 0.78), weekly log
                            growth is 30[0.78 ln(1.00781) + 0.22 ln(0.96875)] = −0.0273. On the 5
                            bets at 1 − c = 0.05 (1 − q = 0.12), weekly log growth is 5[0.12 ln(1.95) +
                            0.88 ln(0.95)] = +0.1750. Net mirror log growth is +0.1750 − 0.0273 =
                            +0.1477 per week—reaching 20 in 20.3 weeks (with probability > 99% by
                            week 52). Under §8 ("ends with the claim when cash reaches 20, and as a loss
                            when the mirror does"), the study terminates around week 20 and falsely
                            declares a +7.53%/week profitable procedure a net loser.

                     4. Fee and spread subsidy: Because c = a + fee is the all-in ask cost, pricing the
                        mirror at 1 − c = (1 − a) − fee instead of the executable complement ask (1 −
                        b) + fee subsidizes the mirror by (a − b) + 2 fee per share.

             Outcome: False negative ("loses net of costs") judgments against genuinely profitable
             procedures, or simultaneous crossing of 20 by both accounts (for which §8 defines no tie-
             break).
             Severity: Critical.

     2. Critical — Study 2's half-Kelly stake rule is improper (hitting Brief 2's wall), under-
     deploys capital relative to the power table, and deadlocks under the pause rule




https://gemini.google.com/app/3f7a358f71f43808                                                                 2/14
11/11/26, 12:35 PM                                            See attached instructions.


             Where: architecture.md §5.3: "Recommended start: half of Kelly's fraction from the
             agent's own registered probability p, (p − c) / (2(1 − c)) of cash, capped at 5% of
             cash, and no purchase unless p > c. Log wealth under Kelly's rule is a proper score, so the
             agent's honest probability is its best report." briefs/2-thesis-track.md Q4: "If the rule
             gives the agent a reason to misreport its probability, that is a wall." architecture.md
             §5.3: "The pause. When cash plus the cost of open positions reaches 20, the account stops
             buying until they settle." architecture.md §5.7 property 2.
             Construction:
                     1. Half-Kelly is not a proper scoring rule for log wealth: For true probability q > c,
                        expected single-bet log growth G(f ) = q ln(1 + f 1−c    c
                                                                                    ) + (1 − q) ln(1 − f ) is
                                                                                           ​




                        uniquely maximized at the full-Kelly fraction f ∗ (q) = 1−c . Under the half-Kelly rule
                                                                                   q−c
                                                                                               ​




                                  p−c
                        f (p) = 2(1−c) , an agent with true belief q achieves f (p) = f ∗ (q) if and only if it
                                       ​




                        misreports
                                                 p∗ = c + 2(q − c) = 2q − c =
                                                                             q.
                       For c = 0.50 and true probability q = 0.52, reporting honestly (p = 0.52 ⟹
                       f = 0.02) yields expected log growth 0.00060, whereas exaggerating the edge two-
                       fold (p = 0.54 ⟹ f = 0.04) yields 0.00080 (33% faster log growth). By Brief 2
                       Q4, this is an immediate design wall.
                     2. Disconnect between §5.3's stake rule and §5.4's power table: Section 5.4
                        (arithmetic.py.txt, account()) assumes deployed = 1.0 (100% of cash
                        staked in equal 1/m parts every week). Under §5.3's actual rule f =
                       min(0.05, 2(1−c)
                                     p−c
                                          ) applied to remaining cash at each registration, an honest agent
                                           ​




                       with the table's stated edges never reaches the 5% cap (which requires p − c ≥
                       0.10(1 − c)):

                             In the table's row 60 at 0.20 | 0.10 (2 points) (p = 0.22, c = 0.20),
                                                   0.02
                             the rule stakes f = 2(0.80)​= 1.25% of remaining cash per purchase. Across
                             60 sequential purchases, total deployed cash is 1 − 0.987560 = 53.0% (not
                             100%), cutting weekly log growth from 0.064 to 0.043, raising expected weeks
                             from 47 to 70, and cutting 52-week power from 0.66 to 0.24. With 30
                             purchases, it deploys only 31.5% of cash, failing §5.4's 50% shakedown wall.

                             In row 30 at 0.50 | 0.08 (p = 0.54, c = 0.50), f = 0.04, deploying 1 −
                             0.9630 = 70.6% of cash; with 2 points of edge (p = 0.52), f = 0.02,
                             deploying only 45.5% of cash (again failing the 50% shakedown wall).



https://gemini.google.com/app/3f7a358f71f43808                                                                    3/14
11/11/26, 12:35 PM                                               See attached instructions.


                     3. The pause rule is purchase-invariant and deadlocks on a single lost settlement
                        record: Let Ct be cash and St = ∑i∈open(t) si be the cost of open positions. Any
                                        ​                ​                  ​   ​




                        purchase of stake s maps (Ct , St ) ↦ (Ct − s, St + s), leaving Ct + St strictly
                                                     ​       ​          ​            ​            ​       ​




                        invariant. Thus Ct + St never reaches 20 during purchases—even when open
                                            ​    ​




                        positions have massive positive expected value—and only changes when a position
                        settles. Conversely, suppose a settled win pushes Ct + St to 20.1 (Ct = 19.5, St =
                                                                                         ​    ​       ​




                        0.6) while one open position has a lost or indefinitely disputed settlement record.
                        Because the pause stops buying "until they settle", the account is permanently
                        frozen at Ct = 19.5 < 20 and can never reject the null, regardless of edge.
                                    ​




                     4. Undefined domain when c ≥ 1: Walking thin asks near 0.99 plus fees makes all-in
                        cost c ≥ 1, violating c in (0, 1) and causing division by zero or negative stakes in
                        (p - c)/(2(1 - c)) and 1 - c.

             Outcome: Breaks Brief 2's proper-scoring requirement, overstates 52-week power by 2 ×
             –3×, triggers false shakedown aborts, and allows a single missing settlement record to
             permanently deadlock a winning account below 20.
             Severity: Critical.

     3. Critical — The human's $2,500 reference stake on Kalshi's 7-day universe collapses
     breadth below the abort threshold and turns gross edges negative

             Where: Prompt (Human's answers to §12): "Study 2 runs, on Kalshi. The reference stake is
             $2,500 per purchase, costed against the recorded book... The agent does not fetch result
             pages: the certified search API must return page content itself." architecture.md §5.3–
             5.4: "The reference stake fills from the recorded asks. Otherwise the registration is refused.
             The contract's scheduled end is within a horizon cap. Seven days is the starting point. One
             open position per event... fewer than 30 distinct admitted events settling a week".
             Construction:
                     1. Contract depth required by $2,500: Buying $2,500 at all-in cost c requires walking
                        2,500
                          c contracts on the ask book: 5,000 contracts at
                           ​                                              c = 0.50, 12,500 contracts at
                        c = 0.20, and 25,000 contracts at c = 0.10.

                     2. Collapse of Kalshi's 7-day universe: Kalshi's short-horizon listings are dominated
                        by multi-strike ladders (daily/weekly equity indices, BTC/ETH, Fed rate tiers, city
                        temperatures, economic prints) and sports. Collapsing ladders to "one open position
                        per event, by the venue's own event grouping" reduces 20–50 strikes on one
                        underlying date to 1 event. Outside sports and HFT-priced index/crypto ladders,
                        reading-amenable catalyst events settling within 7 days that carry ≥ $2, 500 of ask
                        depth near top-of-book number fewer than 5 to 15 per week—failing §5.4's pre-
                        freeze wall ("fewer than 30 distinct admitted events settling a week").

https://gemini.google.com/app/3f7a358f71f43808                                                                 4/14
11/11/26, 12:35 PM                                                               See attached instructions.


                     3. No slippage cap in §5.3: Because §5.3 requires only that the $2,500 stake "fills
                        from the recorded asks" with no spread/slippage limit, a thin market with 200
                        contracts at 0.48 and stub asks at 0.85–0.99 "fills" $2,500 at an average cost c ≈
                        0.80, turning a true probability q = 0.54 into an un-registerable (p < c) or deeply
                        negative-return trade.
                     4. Turnover and power impact: If only m = 8 non-sports events/week pass the
                        $2,500 depth and p > c filters at average stake f = 0.03 (deploying 1 − 0.978 =
                        21.6% < 50% of cash, failing the shakedown wall), and a 4-point gross probability
                        edge (q − atop = 0.04 at 0.50) pays 1.75 cents in Kalshi taker fees plus 1.50 cents
                                       ​




                        of $2,500 book-walk slippage, net edge is 0.75 cents (e = 0.015). Weekly log
                        growth is 8[0.03(0.015) − 12 (0.03)2 ] = 0.0000 (infinite expected time to 20;
                                                             ​




                        even at e = 0.04, expected time is 500 weeks / 9.6 years, 52-week power < 0.001
                        ).
             Outcome: Study 2 either aborts before freezing under §5.4's census/shakedown walls or
             runs with near-zero power because $2,500 book walks consume the edge on thin 7-day
             events.
             Severity: Critical.

     4. Critical — Study 1's paired SPRT table (arithmetic.py.txt) falsely assumes the Agent
     and G100 are independent on the same market

             Where: architecture.md §6: "Test: Wald's sequential test of θ ≤ 1/2 against θ = 0.8
             (the agent at 0.5 against G100 at 0.2), nominal errors 5%, ending undecided at 60 markets.
             By exact enumeration: [table]"; arithmetic.py.txt lines 54–56:
             cases.append((f"agent {agent}, G100 {searcher}", agent * (1 -
             searcher), searcher * (1 - agent))).

             Construction:
                     1. For paired binary outcomes (Am , Bm ) on the same market m with marginals pA =
                                                                         ​




                        P (Am = 1) and pB = P (Bm = 1), let p11 = P (Am = 1, Bm = 1). Then
                              ​                  ​                   ​                                   ​               ​               ​




                        discordant probabilities are p10 = pA − p11 and p01 = pB − p11 , and
                                                                     ​               ​               ​               ​           ​           ​




                                                    pA − p11
                                           θ=                   ,                                        pdisc = pA + pB − 2p11 .
                                                         ​                   ​




                                                 pA + pB − 2p11
                                                                                             ​                   ​           ​       ​           ​




                                                     ​           ​                       ​




                       arithmetic.py.txt hardcodes p11 = pA pB (statistical independence on the
                                                                                 ​               ​           ​




                       same market), contradicting the entire reason for pairing.
                     2. Failure across the allowed [0.1, 0.3] calibration band: Section 6 accepts any
                        calibration strength where G100's rate is in [0.1, 0.3]. Even under

https://gemini.google.com/app/3f7a358f71f43808                                                                                                       5/14
11/11/26, 12:35 PM                                            See attached instructions.


                       arithmetic.py.txt's own independence formula, if G100's rate is pB = 0.30 and   ​




                                                                        0.35
                       the Agent hits the target pA = 0.50, then θ = 0.35+0.15
                                                     ​                         = 0.70 < 0.80: upper-
                                                                                           ​




                       decision power drops from 0.888 to 0.685, and the false lower-decision rate jumps
                       from 0.033 to 0.142 (2.8× the nominal 5% error). With negative association (p11 =       ​




                       0.05), θ = 0.643, power drops to 0.486, and the lower decision occurs 30.8% of the
                       time.
                     3. False target-advantage claim under positive correlation: Because easy market
                        seeds make the plant easier for both arms (p11 > pA pB ), suppose pA = 0.25 and
                                                                            ​         ​        ​   ​




                        pB = 0.20 with p11 = 0.1875 (p10 = 0.0625, p01 = 0.0125). Then θ = 0.0625
                          ​                      ​        ​                       ​




                                                                                                0.075 =
                                                                                                           ​




                        0.833 > 0.80: an agent that beats G100 by only 5 percentage points (0.25 vs. 0.20
                        ) exceeds the θ = 0.80 alternative designed for (0.50, 0.20).

             Outcome: Invalidates Section 6's power and Type-II error table and decouples θ = 0.80
             from the stated (0.50, 0.20) capability target.
             Severity: Critical.
     CONTINUE FOR PART 2



     User prompt: continue

     Response: Ranked Findings (Part 2 of 2)
     5. High — Study 2's validity proof and Property 2 fail under proportional staking with
     delayed payouts, and arithmetic.py.txt simulates simultaneous rather than sequential
     stakes

             Where: architecture.md §5.1: "Under the null, cash plus the conditional expected payout
             of the open positions is a non-negative supermartingale that starts at 1: each purchase
             replaces s of cash with a claim worth at most s, and between purchases a conditional
             expectation is a martingale." architecture.md §5.7 Property 1 & 2: "Both accounts are
             pure functions of the recorded bytes and the manifest... With the purchases and their stake
             fractions held fixed, cash at every time is non-decreasing in each recorded payout: a lost
             settlement record lowers it and a late one delays it... So no failure after a registration can
             raise the chance of a false rejection above 5%." arithmetic.py.txt lines 78–80
             (account).
             Construction:
                     1. Delayed settlement records inflate cash under proportional staking (violating
                        the premise of Property 2): Property 2 holds purchases and stake fractions ft fixed,
                                                                                                           ​




https://gemini.google.com/app/3f7a358f71f43808                                                                     6/14
11/11/26, 12:35 PM                                                              See attached instructions.


                       claiming that a late settlement record only delays cash and never increases it. That is
                       false when stakes are proportional to current cash (st = ft Ct ). Suppose at t = 1 the
                                                                                                        ​    ​   ​




                       account has cash C1 = 1.80 and an open position settles with payout P1 = 9.50.
                                                            ​                                                                            ​




                       From t = 2 to t = 21, the procedure makes 20 losing purchases, each staking f =
                       0.05 of current cash, followed at t = 22 by a winning purchase that doubles cash (
                       ×2):

                             On-time settlement record at t = 1: Cash becomes C1 = 1.80 + 9.50 =                     ​




                             11.30. The 20 losing bets at 5% of current cash reduce cash to 11.30 ×
                             (0.95)20 = 4.051 at t = 21. Doubling at t = 22 gives terminal cash 8.10 <
                             20 (does not reject).

                             Late settlement record delayed until t = 22: At t = 1, cash remains 1.80
                             while P1 = 9.50 sits unrecorded in the settled position, shielded from
                                                ​




                             proportional drawdowns. The 20 losing bets reduce 1.80 to 1.80 × (0.95)20 =
                             0.645. When the polling daemon records P1 = 9.50 at t = 22 (C = 10.145)
                                                                                                  ​




                             before the ×2 win, terminal cash reaches 20.29 ≥ 20 (rejects the null). Thus,
                             cash is not non-decreasing in timely payout recording: operational polling lag
                             during a losing streak shields realized payouts from proportional staking losses
                             and manufactures a crossing of 20 that on-time recording would have
                             prevented.
                     2. The null is stated only at registration, not across operational polling times:
                        Section 5.1 states the null as E[xi ∣ Fτi ] ≤ ci at registration τi . For Wt = Ct +
                                                                        ​


                                                                                   ​
                                                                                       ​    ​                            ​           ​       ​




                        ∑i∈open(t) scii E[xi ∣ Ft ] to be a supermartingale when the operational layer chooses
                                   ​




                                       ​
                                        ​




                                            ​           ​       ​




                        when to poll settlements or retry failed fetches, the filtration Ft must make polling                    ​




                        delays stopping times independent of unrecorded outcomes xi . If an operational                      ​




                        failure (e.g., HTTP 429 or schema change on disputed/split markets) correlates with
                                             ~ (i)
                        outcome state xi , Mt = E[xi ∣ Ft ] is not a martingale on the recorded byte
                                                    ​           ​   ​       ​




                        stream.
                     3. Simultaneous vs. sequential staking in arithmetic.py.txt: In account(),
                        factor = 1 - deployed + deployed * wins / (bets * cost) models
                        m = 60 bets placed simultaneously at the start of the week, each receiving
                        deployed
                           m
                               ​
                                 of initial weekly cash. Under §5.1 and §5.3, however, purchases are registered
                        sequentially from remaining cash: staking f across m sequential purchases before
                        settlement deploys 1 − (1 − f )m < 1 of cash (small_numbers() uses 1 −
                        0.9530 = 0.785), never deployed = 1.0.

             Outcome: Operational polling delays can convert a non-rejecting path (8.10) into a
             rejecting path (20.29), and the power script simulates a simultaneous batch portfolio that
             the sequential account cannot execute.

https://gemini.google.com/app/3f7a358f71f43808                                                                                                   7/14
11/11/26, 12:35 PM                                              See attached instructions.


             Severity: High.

     6. High — Study 1's "pick" and alignment measure are corrupted by the frozen kernel's
     bankruptcy resurrection, scale-invariant noise, and a masked leak check

             Where: architecture.md §6: "A session's pick is its evaluated program with the highest
             search-period score, the quantity G100 maximizes, read from the ledger the same way for
             both arms. The pick carries the plant when the alignment of its holdings with the planted
             signal is at least half the locked reference program's on the same market... Recommended
             start: the cosine between dollar holdings and the signal over all coins and steps"; "Model-
             free checks... 2. On zero-plant markets... G100's rate is at most a quarter of its rate at the
             chosen strength... 3. G100's picks from zero-plant markets, re-run on fresh zero-plant
             markets, average a net score at or below zero. An excess is a leak in the evaluator." Also
             argon-paper-findings.md Finding 2.

             Construction:
                     1. Bankruptcy resurrection (Argon Finding 2c) corrupts Study 1's pick and
                        holdings: In argon-paper-findings.md Finding 2, Fable claims against GPT that
                        "study 1 judges holdings and reads no return, so absorption matters there only for when
                        a holding ends." That is false. Study 1 runs the frozen pilot kernel (§7) and selects
                        each session's pick by "the highest search-period score"—which is a return-based
                        score computed by the defective pilot kernel. A program that goes bankrupt mid-
                        window and resurrects (Finding 2c) changes both its return score (hijacking which
                        program becomes the session's pick) and its post-bankruptcy Fill events in the
                        trace.
                     2. Cosine alignment ignores catastrophic losses and unplanted-coin churn:
                                                  ⟨H,S⟩
                        Because cos(H, S) = ∥H∥     2 ∥S∥2
                                                    ​   ​
                                                           is scale-invariant and reads no returns, a strategy
                                                            ​




                        that holds $10 aligned with the signal on the planted coin for 1 step, gets liquidated
                        or pays 50× the plant's value in taker fees, and holds $0 thereafter achieves the
                        same cosine alignment as a profitable strategy holding $10, 000. Furthermore, if the
                        reference program gets stopped out early on a volatile market seed so that
                        cos(Href , S) = 0.04, any noisy pick with cos(H, S) ≥ 0.02 passes the half-
                                  ​




                        reference threshold.
                     3. Model-free Check 3 masks evaluator leaks smaller than transaction costs: On
                        fresh zero-plant markets, any trading strategy pays strictly positive fees and
                        slippage, so a leak-free evaluator gives G100's picks a negative expected net score
                        −μcost < 0 (typically −1.5% to −3.0% annualized Sharpe-equivalent). Requiring
                              ​




                        only that average net score be "at or below zero" allows an evaluator lookahead leak
                        of +μleak ≤ μcost (e.g., Sharpe +1.5) to pass Check 3 with probability > 95%.
                                      ​    ​




https://gemini.google.com/app/3f7a358f71f43808                                                                    8/14
11/11/26, 12:35 PM                                                   See attached instructions.


                     4. Model-free Check 2 lacks sample size and fails to bound discordant bias:
                        Neither §6 nor Brief 1 specifies how many zero-plant markets Check 2 runs or with
                        what confidence bound, and a false-positive alignment rate of 14 (0.20) = 0.05 on
                                                                                                  ​




                        G100 does not bound the agent's false-positive alignment rate if the agent proposes
                        simpler, lower-dimensional programs than G100's genetic trees.
             Outcome: Resurrected bankrupt programs or fee-burning strategies can be scored as
             "carrying the plant," while lookahead leaks up to the strategy's fee drag pass Check 3
             undetected.
             Severity: High.

     7. High — The confirmation wall (4.98 vs. 26) and Table 1 Row G conflate 80%-power
     thresholds with ∼ 50%-power expected log-wealth times

             Where: architecture.md §2.1–2.3: "At T = 0.25 years a test that trusts the Gaussian
             approximation has 80% power only at Sharpe 4.98, and the gate's exact test needs about
             26." architecture.md §3 Table Row G: "net edge per dollar staked 0.04; 0.08; 0.12; 0.16 |
             exact: 22; 10; 6.5; 5 (expected weeks to 20: 95; 43; 28; 21)". arithmetic.py.txt
             (yardstick, capped_bet, account).
             Construction:
                     1. Apples-to-oranges power comparison (4.98 at 80% power vs. 26 at ∼ 50%
                        power):
                            In yardstick(), 4.98 = z0.95 +z0.80 = 2.4865
                                                                 ​




                                                                   0.2493
                                                                          is the Sharpe for 80% power.
                                                                             ​




                                                         91/365
                                                                                 ​        ​




                                                                                          ​

                                                                         ​




                            In capped_bet(), 26.03 solves n (λμ − 12 λ2 (σ 2 + μ2 )) = ln 20 = 2.9957
                                                                                      ​




                            for n = 546, λ = 0.5, σ = 0.02. That equates expected log wealth E[ln Kn ]        ​




                            to ln 20, which corresponds to roughly 50% power, not 80% power. Because
                            SD(ln K546 ) ≈ 546λσ = 0.2337, achieving 80% power (ln 20 +
                                           ​       ​




                            0.8416 × 0.2337 = 3.1924) requires Sharpe 27.7 (and over 2 years requires
                            4.0, not 3.4).
                            Even 27.7 assumes a constant oracle bet λ = 0.5 from step 1 and a quadratic
                            Taylor approximation λμ − 12 λ2 (σ 2 + μ2 ) that ignores negative skewness
                                                         ​




                            γ3 < 0 and heavy kurtosis γ4 > 3; under the gate's actual plug-in bet (Argon
                               ​                             ​




                            Finding 9), which starts at 0 and jumps, required Sharpe for 80% power exceeds
                            30.
                     2. Section 3 Table Row G reports expected hitting times (∼ 50% power) in an
                        80%-power column: Rows A–E of the Section 3 table report months to 80% power
                        (6.18 / (d^2 * n)). Row G reports 22; 10; 6.5; 5 months by dividing

https://gemini.google.com/app/3f7a358f71f43808                                                                    9/14
11/11/26, 12:35 PM                                                       See attached instructions.


                       expected weeks to 20: 95; 43; 28; 21 by 4.33. As §5.4's own simulation
                       table proves, at edge 0.04, 104 weeks (24 months) achieves only 0.65 power (not
                       0.80, which requires 28 months at 100% weekly cash turnover and 56 months at
                       50% turnover).
             Outcome: Understates the gate's true 80%-power Sharpe threshold and makes Study 2
             appear faster in Section 3's comparison table by reporting ∼ 50%-power expected hitting
             times alongside 80%-power yardstick months.
             Severity: High.

     8. Medium — Fable's dispositions of Argon's paper findings 4, 7, 10, and 11 in argon-paper-
     findings.md rely on flawed math

             Where: argon-paper-findings.md Findings 4, 7, 10, and 11; arithmetic.py.txt lines
             100–125 (argon).
             Construction:
                     1. Finding 11 (Stationary bootstrap block length — wrongly rejected by Fable):
                        Fable writes: "Does not hold as stated... Under the null the returns of a predictable
                        position are martingale differences: funding persists, the return's mean does not." This
                        is mathematically false for the gate's search screens (White's Reality Check, Hansen's
                        SPA, Romano–Wolf StepM). Those screens test the unconditional null E[rk,t ] ≤ 0                  ​




                        by bootstrap-resampling centered returns rk,t − rˉk . In both N2 and real perps, a
                                                                                         ​       ​




                        strategy holding a constant or slow-moving position post−1 = +1 receives         ​




                        persistent 4-hour funding ft (with AR(1) coefficient ϕ = 1 − 1/42 = 0.9762).
                                                         ​




                        Because price innovations in N2 are independent of ft (outside the plant), the
                                                                                                     ​




                        strategy's total return is rt = ϵt − ft − costt , whose conditional mean E[rt ∣
                                                     ​       ​       ​               ​                                       ​




                        Ft−1 ] = −ft − costt persists with ϕ = 0.9762! Therefore, rt is not a martingale
                            ​        ​           ​                                                               ​




                        difference under the null: its autocovariance at lag h is Cov(rt , rt+h ) =          ​       ​




                        Var(ft )ϕh > 0, inflating long-run variance by 1+ϕ
                                ​




                                                                          1−ϕ = 83× on the funding
                                                                                             ​




                        component (and 8.5× when funding is 10% of return variance), of which block
                        length L = 6 captures only 1+ϕ(5/6)
                                                       1−ϕ(5/6)
                                                                = 9.7 out of 83.
                                                                 ​




                     2. Finding 10 (v3 locked suite tolerances — Fable sneaks in a 99-way Bonferroni
                        correction): Fable writes: "By exact Clopper–Pearson bounds, Argon's two examples
                        (160 and 248 rejections) fail, narrowly." Look at arithmetic.py.txt line 117:
                        beta.ppf(1 - 0.05 / 99, x + 1, 20_000 - x) <= tolerance. Fable
                        divided α = 0.05 by 99 (α = 0.000505, a 99.9495% upper bound) to get max
                        passing counts of 154 and 244. Under the standard 95% Clopper–Pearson bound
                        (beta.ppf(0.95, x + 1, 20_000 - x)), x = 160 gives 0.00915 ≤ 0.01
                        (passes up to 178 rejections), and x = 248 gives 0.01379 ≤ 0.015 (passes up to

https://gemini.google.com/app/3f7a358f71f43808                                                                                   10/14
11/11/26, 12:35 PM                                                               See attached instructions.


                       269 rejections). Even at 99% confidence, 160 gives 0.00965 ≤ 0.01 and 248 gives
                       0.01440 ≤ 0.015.

                     3. Finding 7 (Deflated Sharpe Ratio ceiling — Fable checks only S^ → ∞ at zero
                        skewness): Fable claims the DSR ceiling falls below 0.95 "only above a kurtosis of
                        about 1 + 1.48(T - 1)." That solves limS^→∞ DSR(S^) < 0.95 at γ^3 = 0. At any
                                                                                                 ​                ​   ​




                        realistic finite per-step Sharpe—e.g., annualized S^ann = 3.5 (S^ = 0.0749 per 4h
                                                                                                        ​




                        step) against threshold S0,ann = 2.0 (S0 = 0.0428) over T = 546 steps—the
                                                             ​                       ​




                        numerator is (S^ − S0 ) 545 = 0.749 < 1.64485, so DSR < 0.95 at every
                                                 ​




                        kurtosis γ^4 ≥ 1, and even for S^ann = 6.0 (S^ = 0.128) with negative skewness
                                  ​   ​                              ​




                        γ^3 = −4, DSR falls below 0.95 at γ^4 = 18 ≪ 546.
                         ​   ​                                           ​   ​




                     4. Finding 4 (Stage 4 campaign recount): Fable counts v2's two zero-evaluation
                        crashes as valid gate tests. A campaign that crashes with zero evaluations has an
                        identically zero chance of promoting a strategy (0/0); counting zero-evaluation
                        crashes in a gate false-promotion bound dilutes the per-campaign promotion rate
                        with non-runs.
             Outcome: Leaves the stationary bootstrap's block-length underestimation
             unacknowledged in the defect table and puts false 99-way Bonferroni numbers (1,138,
             244 and 154) into paper-changes.md B.

             Severity: Medium.

     9. Medium — paper-changes.md introduces four new inconsistencies and mathematical
     errors into the whitepaper

             Where: paper-changes.md edits A2.3, A5.5, A6, A7.2, A7.3, and B (Finding 10).
             Construction:
                     1. Contradictory log-growth formulas between architecture.md §2.2 and
                        paper-changes.md A7.3: For m simultaneous even-price bets of net edge e,
                                                                                     2
                        portfolio return rˉ = m1 ∑i=1 ri has mean e and variance 1−e
                                                    m
                                                     ​   ​       ​




                                                                                  m
                                                                                       . At full turnover (λ =​




                                                                                                       2     2
                        1), the second-order Taylor approximation to expected log growth is e − 1−e  2m
                                                                                                         − e2 .           ​   ​




                        architecture.md §2.2 writes e − 1/(2m) (dropping −e2 /2, which gives 0.0717
                        at e = 0.08, m = 60), while paper-changes.md A7.3 writes e − 1/(2m) − e²/2
                        (0.0685), and neither matches exact binomial log growth (0.0689) or §5.3's
                        sequential half-Kelly rule.
                     2. Edit B (Finding 10, S4 line 645): Inserts "Up to 1,138, 244 and 154
                        rejections in 20,000 pass" into S4 without disclosing that those thresholds




https://gemini.google.com/app/3f7a358f71f43808                                                                                    11/14
11/11/26, 12:35 PM                                            See attached instructions.


                       require a 0.05
                                  99 Bonferroni correction across 99 tests rather than the single-cell
                                     ​




                       Clopper–Pearson bound (1, 182, 269, and 178).

                     3. Edit A5.5 (Table tab:rates): Places Row G's expected weeks to 20 (∼ 50% power
                        under 100% weekly turnover) into a table whose caption and other rows represent
                        6.18/(d2 n) (80% power).

                     4. Edit A7.2: Formalizes the mirror account proof in Appendix T4 while retaining the
                        false claim in A5.7 that the mirror reaching 20 proves the procedure loses net of
                        costs (Finding 1).
             Outcome: Introduces new mathematical errors into docs/whitepaper.tex if applied as
             written.
             Severity: Medium.

     10. Medium — The human's §12 search-API constraint and undecided Polymarket/perp
     records create immediate compliance and survivorship blockers

             Where: Prompt (Human's answers to §12): "The agent does not fetch result pages: the
             certified search API must return page content itself... The perp instance and the Polymarket
             recordings are undecided." architecture.md §5.6 item 1–3: "1. an official API whose terms
             permit automated queries and the use of results as input to a language model; 2. no clause
             against storing responses... 3. page content returned by the API itself, since the daemon
             never fetches a result's URL from an uncertified host."
             Construction:
                     1. Third-party copyright pass-through on full page content: Requiring the search
                        API to return full page content (rather than snippets/links) shifts the terms audit from
                        the search vendor to the underlying publishers. Search APIs that return full scraped
                        page bodies or cached text (e.g., Exa, Tavily, Brave, Perplexity/Serp wrappers)
                        uniformly disclaim copyright licenses over third-party publisher text in their ToS,
                        passing liability for permanent hash-addressed storage (item 2) and LLM ingestion
                        (item 1) to the operator. Under the project's strict compliance rule, no search API
                        can grant a sublicense to store and feed full third-party news articles that it does not
                        own.
                     2. Undecided Polymarket recordings: Because Polymarket's August 11, 2026 terms
                        forbid automated scraping and data extraction (GPT Finding 9), retaining and reading
                        previously scraped Polymarket files for any future calibration or paper diagnostic
                        violates the compliance policy unless explicitly purged or isolated under an operator
                        legal decision.
                     3. Undecided perp instance: Keeping the perp recorders or daily sessions running
                        while parked consumes part of the 600 weight/min Hyperliquid budget and personal

https://gemini.google.com/app/3f7a358f71f43808                                                                     12/14
11/11/26, 12:35 PM                                           See attached instructions.


                      account allowance for a track that §2.4 proves requires 618–2, 473 independent
                      pairs (3–10 years).
             Outcome: Blocks Study 2's freeze under §5.6 item 2–3 unless the search API is restricted
             to licensed/public-domain sources or short fair-use metadata snippets, and leaves
             uncertified Polymarket data on disk.
             Severity: Medium.

     Summary Table of Ranked Findings

      Rank Severity Target                                    Core Theoretical / Operational Break

                                                              Negating ∀i, μi ≥ ci is ∃i, μi < ci , not
                                                                                      ​       ​           ​           ​




                                                                               1
                                                              portfolio loss; 1−c leverage and fee subsidy
                                Study 2 mirror account
                                                                                          ​




      1              Critical                                 let a +7.53%/wk profitable procedure hit 20
                                (§5.2, §8, A7)
                                                              on the mirror in 20.3 weeks and be falsely
                                                              declared a loser
                                                              Half-Kelly is an improper score (optimal
                                                              report p∗ = 2q − c exaggerates edge 2×,
                                Study 2 stake & pause         hitting Brief 2's wall); deploys 31–53% of
      2              Critical   rules (§5.3, §5.4, Brief 2    cash (cutting 52-wk power from 0.66 to 0.24
                                Q4)                           ); cash + open cost >= 20 is purchase-
                                                              invariant and deadlocks if 1 settlement record
                                                              is lost

                                                              $2, 500 requires 5, 000–25, 000 contracts;
                                Kalshi $2, 500 stake & 7-     collapsing ladders on Kalshi's 7-day non-
      3              Critical   day universe (§12, §5.3–      sports universe leaves < 5–15 events/wk
                                5.4)                          (failing the 30-event/wk abort wall) and
                                                              book-walk slippage wipes out 2–4 pt edges

                                                              Enumeration hardcodes p11 = pA pB   ​           ​           ​




                                                              (independence on the same market); across
                                Study 1 paired SPRT
                                                              the allowed [0.1, 0.3] calibration band and
      4              Critical   (arithmetic.py.txt,
                                                              correlated markets, power drops to
                                §6)
                                                              0.486–0.685 and Type-II error jumps to
                                                              14–31%

      5              High       Study 2 validity & Property Under proportional staking st = ft Ct ,   ​           ​           ​




                                2 (§5.1, §5.7, account)     delayed settlement recording shields payouts
                                                            from drawdowns and inflates cash (8.10 →

https://gemini.google.com/app/3f7a358f71f43808                                                                                    13/14
11/11/26, 12:35 PM                                            See attached instructions.



      Rank Severity Target                                     Core Theoretical / Operational Break
                                                               20.29); account() simulates simultaneous
                                                               rather than sequential stakes
                                                               Frozen pilot kernel's bankruptcy resurrection
                                                               corrupts search-period return scores (the
                                Study 1 alignment, pick &
      6              High                                      pick) and fills; scale-invariant cosine ignores
                                checks (§6, Finding 2)
                                                               fee ruin; Check 3 masks lookahead leaks up
                                                               to transaction cost drag

                                                               Compares 4.98 (80% power) with 26 (∼ 50%
                                                               power, expected log wealth = ln 20 under
                                Wall derivations & Table 1
      7              High                                      constant oracle bet); Row G puts ∼ 50%-
                                Row G (§2.1–2.3, §3)
                                                               power expected hitting times in an 80%-
                                                               power table
                                                         Wrongly rejects Finding 11 (funding persists in
                                argon-paper-             unconditional SPA/StepM null returns rt =       ​




                                                                                     0.05
      8              Medium     findings.md (Findings 4, ϵt − ft − ct ); uses hidden 99 Bonferroni in
                                                                  ​             ​   ​          ​




                                7, 10, 11)               Finding 10; checks DSR ceiling only at S^ →
                                                         ∞, γ^3 = 0     ​   ​




                                                               Propagates conflicting log-growth formulas
                                                               (e - 1/(2m) vs. e - 1/(2m) - e^2/2),
                                paper-changes.md
      9              Medium                                    unstated 99-way Bonferroni cutoffs, and
                                (A2.3, A5.5, A7.2, A7.3, B)
                                                               mirror-account fallacies into
                                                               whitepaper.tex

                                                               Search APIs returning full third-party page
                                Human's §12 answers
                                                               text cannot grant storage/LLM licenses over
      10             Medium     (search API, Polymarket,
                                                               publisher copyright; retaining scraped
                                perps)
                                                               Polymarket data violates August 2026 ToS




https://gemini.google.com/app/3f7a358f71f43808                                                                   14/14
