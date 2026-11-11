# Adversarial review of the rearchitecture, revision 3, by Gemini 4 Argon (web UI), 2026-11-11

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial (CLAUDE.md, Orchestration). Revision 3 re-derived the program from its root after the two-round rule tripped, so this is the first review of the re-derivation.
- **Bundle:** `~/Downloads/argon-rearchitecture-r3.md`: branch `rearchitecture` at `337619f`, the arithmetic script, the decisions of 2026-11-11, and Argon's round 2.
- **Format:** two parts, saved by the human as a PDF at 2026-11-11 20:52 UTC (15:52 EST), filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged.

**Verdict:** do not approve. 3 critical findings:
- study 1's shared twin seeds couple the markets, and the kernel's convexity does not cancel between twins;
- section 4 understates forward power: stopping rather than terminal power, intra-week lock-up, and the gate's loss cap;
- study 1's power is claimed for the band's best case only.

2 high:
- outcome-dependent recording delays;
- a deterministic G100, an intersection null, and crashes counted.

2 medium: script inconsistencies, and the dispositions of paper findings 7, 10 and 11.

---

11/11/26, 3:52 PM                                           See instructions in attached doc.



     See instructions in attached doc.
     https://gemini.google.com/app/0858ee74070bc1bb

     User prompt: See instructions in attached doc.
     Response: Verdict: Do not approve revision 3; its recommendation to abandon all forward
     studies and stop the program rests on flawed power derivations in Section 2 and Section 4,
     while its redesigned Study 1 introduces a fatal inter-market dependence bug that invalidates
     Wald's sequential sign test. Specifically, Section 4's forward power table understates power by
     forcing all weekly purchases in account() to lock up cash without settling until week's end
     (shrinking the 60th bet of a week to 0.24% of cash), by solving for terminal wealth P(WN ≥         ​




     20) = 0.80 (N = 11.8/e2 ) instead of the stopping boundary P(supn≤N Wn ≥ 20) = 0.80 (      ​   ​




     N = 8.67/e2 ), and by retaining the gate's 100σ worst-loss cap (L = 2 against σ = 0.02)
     when a 10σ step stop (L = 0.20) cuts the two-year 80%-power Sharpe requirement on
     certified Hyperliquid data from 4.0 to 2.09. Meanwhile, Study 1's new twin-market plant
     measure evaluates all 100 study markets' picks on the same K fixed fresh market seeds and the
     same noisy reference denominator, coupling all 100 classifications to a single finite sample draw
     and breaking independence across markets in Wald's SPRT, while non-linear bankruptcy
     resurrection in the frozen kernel creates positive convexity payoffs under planted drift that do
     not cancel between twins.

     Ranked Findings (Part 1 of 2)
     1. Critical — Study 1's shared-K twin-market measure breaks independence across the
     100 study markets, fails to cancel non-linear kernel defects, and understates
     classification error

             Where: architecture.md §5.1: "A pick earns from the plant when the plant's effect on its
             score is at least half the plant's effect on the locked reference program's score. The effect is
             the program's mean score over K fresh planted markets minus its mean score over their
             twins, which share every seed and have plant strength zero. The fresh markets' seeds are
             fixed in the manifest and shared by all picks... Whatever the frozen kernel pays that is not the
             plant, a defect or a leak, it pays on both twins, and the difference removes it." Also §5.2
             ("Dependence between markets"), §5.5 Wall 1 ("misclassified with probability 3·10⁻⁵"), and
             arithmetic.py.txt line 131 (norm.sf(4)).

             Construction:
                    1. Sharing K fresh markets across all picks breaks inter-market independence in
                       Wald's SPRT: Let Efresh = {(Mk (α), Mk (0))}K
                                                 ​      ​             ​




                                                                          k=1 be the K fixed fresh twin-market
                                                                                    ​




                       pairs shared by all picks. On each study market m ∈ {1, … , 100}, arm a ∈ {A, B}
                       selects a pick πa,m , which is classified as earning from the plant if
                                            ​




https://gemini.google.com/app/0858ee74070bc1bb                                                                   1/13
11/11/26, 3:52 PM                                                                                See instructions in attached doc.


                                                                     ^ (πa,m ; Efresh ) ≥ 1 Δ
                                                                     Δ                      ^ (πref ; Efresh ).
                                                                                          2
                                                                                         ​             ​               ​               ​               ​




                      Because every study market m = 1, … , 100 is judged against the same realization
                      of Efresh and the same sample threshold 12 Δ
                                       ​
                                                                      ^ (πref ; Efresh ), the discordant indicators                ​           ​




                      D1 , … , D100 are not independent across m: they share the common random
                           ​                 ​




                      environment Efresh . If the finite draw Efresh happens to yield a slightly low sample
                                                     ​                                                             ​




                      estimate Δ ^ (πref ; Efresh ) < Δref or favors the smooth funding family named in the
                                                 ​               ​                   ​




                      agent's brief over G100's trees, it shifts the win probability on all 100 study markets
                      simultaneously, violating the i.i.d./independent-increment requirement of
                      sign_test().

                    2. Kernel defects (bankruptcy resurrection) and lookahead leaks do not cancel
                       between twins: Cancellation requires score additivity S(π, Mk (α)) =                                                                        ​




                       Splant (π, α) + Sdefect (π, Mk (0)). In gate/markets.py, adding planted
                               ​                             ​               ​




                       drift/funding α > 0 changes the return series rt (α) = rt (0) + αst , causing the                       ​                   ​                       ​




                       cumulative price and equity paths on Mk (α) and Mk (0) to diverge. Because the      ​                               ​




                       frozen kernel's bankruptcy resurrection bug (Paper Finding 2c) and margin
                       liquidations are non-linear threshold functions of equity (Wt ≤ 0), they do not affect                                              ​




                       both twins equally. Specifically, because bankruptcy truncates left-tail losses at
                       −100% while resurrection preserves post-bankruptcy upside, adding variance/drift
                       from the plant α > 0 to a high-leverage noisy pick creates a strictly positive
                       Jensen's inequality (call-option convexity) gain:
                                           E[ max(−L, Rtwin + Rplant )] − E[ max(−L, Rtwin )] > 0
                                                                                 ​                             ​                                                       ​




                      even for a degenerate strategy with zero forecasting edge. Similarly, any pick that
                      multiplies an evaluator leak by the funding input (pos = funding * leak)
                      evaluates to near-zero on the zero-plant twin and non-zero on the planted market,
                      multiplying rather than canceling the leak.
                    3. The 4 SE / 3 ⋅ 10−5 classification error bound is mathematically false: Section
                                             ^ ref ≥ 4 SE(Δ
                       5.5 sets K so that 12 Δ           ​
                                                             ^ (π)) on calibration picks and claims
                                                                     ​




                       misclassification probability Φ(−4) = 3.17 × 10−5 . First, this treats the threshold
                       1 ^                                                            ^                ^
                       2 Δref as deterministic; for an uncorrelated pick with SE(Δ(π )) = SE(Δref ), the
                       ​           ​                                                                                                                                                   ​




                       standard error of Δ^ (π) − 1 Δ ^
                                                   2 ref is
                                                                1 + 0.25 SE = 1.118 SE, reducing the margin
                                                                         ​                   ​                             ​




                                              −4
                       to 3.58 SE (1.7 × 10 , Over 5× larger). Second, K is calibrated only on G100's
                       calibration picks, which does not bound the variance of agent picks during the study.
                       Third, 3 ⋅ 10−5 applies only if every pick's true effect is exactly 0 or Δref ; picks that                                                              ​




                       partially capture the plant with true effect Δ(π) ∈ (0.35Δref , 0.65Δref ) sit within                                                   ​                   ​




                       0–1.2 SE of the threshold and are misclassified up to 50% of the time, with errors
                       correlated across all 100 study markets via the shared K seeds.

https://gemini.google.com/app/0858ee74070bc1bb                                                                                                                                             2/13
11/11/26, 3:52 PM                                        See instructions in attached doc.


             Outcome: Invalidates Study 1's sequential sign test across the 100 markets, allows
             bankruptcy-resurrection convexity to masquerade as plant discovery, and understates pick
             misclassification rates by orders of magnitude.
             Severity: Critical.

     2. Critical — Section 4's negative conclusion is falsified by three compounding errors:
     intra-week cash lockup in account(), terminal instead of stopping power in 11.8 / e²,
     and the gate's artificial 100σ loss cap (L = 2)

             Where: architecture.md §1: "an exact test needs about 11.8 / e² independent bets
             for 80% power at a net edge e" ; §2.2: "The gate has L = 2 against 2% a four-hour step...
             Capped, 80% power over 546 steps needs Sharpe 27.7 (26.0 at even odds), and over two
             years 4.0." ; §4 Table & text: "No forward study of a reading agent has honest power on a
             certified venue within two years... at the plausible ceiling of 0.05 the smallest count with
             80% power is above 60 independent bets a week, sustained for two years, and under the
             null the same simulation crosses 20 in 1% of paths." Also arithmetic.py.txt
             capped_bet(), betting_cost(), account(), forward_power().

             Construction:
                    1. Artificial intra-week cash depletion in account(): In arithmetic.py.txt (lines
                       145–149), account() places all bets for an entire week inside for _ in
                       range(bets): stake = fraction * cash; cash = cash - stake before
                       adding any settlement (cash = cash + payout). Thus, within each week, the k -th
                       purchase stakes f (1 − f )k−1 of initial weekly cash. At m = 60 bets/week and
                       f = 0.05, the 60th bet stakes only 0.05(0.95)59 = 0.24% of weekly cash (an
                                               60
                       average stake of 1−0.95
                                           60
                                                 ​= 1.59% instead of 5%, cutting capital deployment by
                       3.1×). When short-horizon perp theses or daily events settle sequentially across the
                       week (so at most 5–8 positions are simultaneously open), 60 bets/week reaches
                       80% power at e = 0.044 (below Fable's 0.05 ceiling, vs. 0.055 in §4), and two-year
                       power at e = 0.04 rises from 0.50 to 0.73.

                    2. Conflating terminal wealth P(WN ≥ 20) with stopping power P(supn≤N Wn ≥
                                                              ​                                          ​   ​




                       20) in 11.8 / e²: In betting_cost(), Fable solves 12 u2 − z0.80 u = ln 20 ⟹
                                                                                         ​       ​




                       u = 3.430, u2 = 11.765 (11.8 / e²), which is the probability that terminal wealth
                       at step N exceeds 20. Because the account stops as soon as wealth hits 20 (
                       supn≤N Wn ≥ 20), applying the exact Bachelier–Lévy reflection formula for the
                              ​    ​




                       running maximum of drift-diffusion ln Wt with drift e2 /2 and volatility e:
                                                                  ​




                                                        u ln 20           u ln 20
                          P( sup Wt ≥ 20) = Φ(            −     ) + 20 Φ(− −      ) = 0.80
                                                        2                 2
                                       ​   ​              ​             ​                    ​       ​




                              0≤t≤N                         u                 u


https://gemini.google.com/app/0858ee74070bc1bb                                                                   3/13
11/11/26, 3:52 PM                                           See instructions in attached doc.


                      yields u = 2.945 ⟹ N = 8.67     e2
                                                        ​(26.3% fewer bets than 11.765/e2 ; at u2 =
                      11.765, true stopping power is 89.9%, not 80%). Moreover, Fable notes that
                      account() crosses 20 in only 1% of null paths by week 104, meaning the fixed-
                      fraction test wastes 80% of its α = 0.05 Ville budget on t > 104 weeks.

                    3. Constructive forward designs on certified sources (Hyperliquid + public filings)
                       with ≥ 80% power in ≤ 2 years:
                           Systematic / hybrid perp track (Q3): Section 4 claims the gate's exact test
                           requires Sharpe 4.0 over two years. That is caused solely by setting the worst-
                           loss bound to L = 2.0 (200% loss = 100σ against 4-hour σ = 0.02), which
                           caps the betting fraction at λ = 1/L = 0.50 when optimal Kelly at Sharpe 2.0
                           is λ∗ = σμ2 = 2.0/0.022190 = 2.14. Enforcing a −20% (10σ , L = 0.20) per-step
                                        ​
                                                  ​




                                                  ​




                           stop or trading bounded cross-sectional spreads sets 1/L = 5.0 > λ∗ ,
                           removing the cap and reaching 80% exact Ville stopping power over two
                           years at annualized Sharpe S = 8.67/2 = 2.08 (or S = 2.43 terminal)—
                                                                                   ​




                           nearly halving the 4.0 wall.
                           Reading-agent perp & filing track (Q2 & Q3): Hyperliquid's certified API provides
                           150+ main-dex and HIP-3 perps with 4-hour/hourly funding alongside certified
                           public macro/SEC filing feeds. Scoring 6.5 independent catalyst or cross-
                           sectional relative-value pairs per day (45 bounded bets/week, N = 4, 680 in
                           two years) with step loss bounded at L so Kelly is uncapped reaches 80%
                           exact stopping power at net edge e = 8.67/4680 = 0.0430 (52.15% hit      ​




                           rate, well below Fable's 0.05 ceiling). Furthermore, §4 falsely dismisses Q2 by
                           claiming a no-search baseline lacks current data: pairing Arm A (agent with
                           certified text filings + current Hyperliquid prices/funding) against Arm B (same
                           agent with the same current Hyperliquid prices/funding up to timestamp t,
                                                                                  2
                           minus text filings) cancels market return variance σmkt   on identical timestamps
                                                                                                ​




                           and reaches 80% power in under 6 months.
             Outcome: Overturns the core negative conclusion in §1, §4, §6.1, and §11.1 that no forward
             study on certified venues can achieve 80% power within two years at plausible edges (≤
             0.05 or Sharpe ≈ 2).
             Severity: Critical.

     3. Critical — Study 1's claim of "92% power at the target under every dependence" is false
     across its own [0.15, 0.25] calibration band, and arithmetic.py.txt hides failing rows
     from §5.3's table

             Where: architecture.md §5.3: "Difficulty is one plant strength, chosen without a model
             on 400 calibration markets a grid value: the one at which G100's rate is nearest 0.2, inside

https://gemini.google.com/app/0858ee74070bc1bb                                                                 4/13
11/11/26, 3:52 PM                                         See instructions in attached doc.


             0.15 to 0.25 (standard error 0.02)." ; §11.4: "Study 1 at up to 100 markets in place of 60... I
             recommend yes: it holds 92% power at the target under every dependence between the
             arms." ; §8 Finding 4: "the lower boundary claims nothing, so its (0.25, 0.20) case is a true
             rejection". Also arithmetic.py.txt study1() lines 102–125.
             Construction:
                    1. Contradiction between §11.4's "92% power" claim and §5.3's calibration band:
                       Section 5.3 permits any calibration grid strength where G100's rate is in [0.15, 0.25].
                       In §5.3's own table, at (0.5, 0.25) under least overlap, power is 0.758 (75.8%)
                       with a 9.9% futility stop rate and 14.3% undecided rate—not 92%. Furthermore,
                       because G100's calibration rate is estimated on 400 markets with standard error
                          0.25 × 0.75/400 = 0.0217, a grid strength whose sample rate is p^B =
                                                 ​                                              ​   ​




                       0.24–0.25 has a true G100 rate of pB = 0.30 within 2.3σ . In arithmetic.py.txt
                                                              ​




                       lines 112–114, Fable computed ("0.5, 0.3, least overlap", 0.5, 0.3, 0.0)
                       and ("0.5, 0.3, both 0.05 (Argon)", 0.5, 0.3, 0.05) under the new
                       θ1 = 0.7, nmax = 100 test—where true θ = 0.5
                        ​              ​




                                                                      0.8 = 0.625 < 0.70, power collapses
                                                                                 ​




                       to 0.508 (50.8%), futility stops jump to 20.0%, and undecided hits 29.2%—but
                       omitted those rows from §5.3's table.
                    2. The (0.25, 0.20) positive-overlap case (both = 0.1875) fails to reject 67.9% of
                       the time: In §8 Finding 4, Fable disposes of our (0.25, 0.20) positive-correlation
                       example by saying "its (0.25, 0.20) case is a true rejection" and includes ("0.25,
                       0.2, both 0.1875 (Argon)", 0.25, 0.2, 0.1875) in arithmetic.py.txt
                       line 118, again omitting the printed output from §5.3's table. In that row, p10 = 0.0625
                                                                                                        ​




                       and p01 = 0.0125 (θ = 0.833 > 0.70), so pdisc = 0.075 yields only 7.5 expected
                              ​                                              ​




                       discordant markets across all 100 trials. Because crossing upper = ln(19) =
                       2.9444 with step size win = ln(1.4) = 0.3365 requires at least
                       ⌈2.9444/0.3365⌉ = 9 discordant wins, sign_test(100, 0.7, ...) leaves the
                       test undecided 67.5% of the time (claiming only 32.1% of the time) despite θ =
                       0.833 > 0.70.

             Outcome: Falsifies §11.4's assurance to the human that 100 markets guarantees 92%
             power across dependences and hides the (0.5, 0.3) and (0.25, 0.20) rows computed by
             arithmetic.py.txt from §5.3's decision table.

             Severity: Critical.
     CONTINUE FOR PART 2



     User prompt: continue



https://gemini.google.com/app/0858ee74070bc1bb                                                                    5/13
11/11/26, 3:52 PM                                                        See instructions in attached doc.


     Response: Ranked Findings (Part 2 of 2)
     4. High — Section 6.3 and Section 8's disposition of Finding 5 fail under outcome-
     dependent recording delays across dependent contracts, and late_records(20) (1.4%
     vs. 3.7%) is an artifact of capital lockup and horizon truncation

             Where: architecture.md §6.3: "Cash plus the conditional expected payout of every
             position not yet recorded as paid is a non-negative supermartingale on the record's own
             filtration, and cash never exceeds it. A payout recorded late, or never, is a position still open
             in that sum. No assumption is made about when records arrive: a delay may depend on
             outcomes already realized, because every stake is fixed before its own outcome, and a null
             stated on a finer filtration implies the one on the record. So the 5% bound holds under any
             dependence between contracts and any recording failure". Also §8 Finding 5 ("under a fair
             null recorded cash reaches 20 in 3.7% of paths on time and 1.4% with every payout 20
             purchases late") and arithmetic.py.txt lines 192–207 (late_records).
             Construction:
                    1. Why the tower-property argument in §6.3 fails under outcome-dependent
                       delays and dependent contracts: Let Ftrec be the record's filtration and Gt be the
                                                                                                       ​                                                                                   ​




                       world filtration at time t. Section 6.3 asserts that because a null on a finer filtration
                       implies the one on the record (E[xj ∣ Gτj ] ≤ cj ⟹ E[xj ∣ Fτrec
                                                                         ​


                                                                                   ​
                                                                                       ​




                                                                                            j
                                                                                              ] ≤ cj ), the                    ​                       ​




                                                                                                                                                                   ​
                                                                                                                                                                       ​           ​




                       process
                                                                                                       si
                                                     V t = Ct + ∑                                         E[xi ∣ Ftrec ]
                                                                                                                       ​




                                                         ​           ​                             ​                       ​               ​       ​




                                                                                                       ci
                                                                             i∈U (t)
                                                                                                                   ​




                      is a supermartingale on Ftrec under "any dependence between contracts and any
                                                             ​




                      recording failure". This fails for two distinct reasons:
                            Supermartingale failure of E[xi ∣ Ftrec ] under outcome-dependent delays:          ​




                            Suppose position 1 is registered at τ1 = 1 (c1 = 0.50) and settles in the real
                                                                                           ​                                           ​




                            world at t = 2, where losing records (x1 = 0) are recorded immediately at t =  ​




                            2 while winning records (x1 = 1) are delayed until t = 10 (e.g., manual
                                                                 ​




                            settlement review or schema change on winning payouts). Then the event {1 ∈
                            U (2)} is F2rec -measurable and implies x1 = 1, so E[x1 ∣ F2rec ] = 1. Now                             ​                           ​               ​




                            suppose position 2 is registered at τ2 = 1.5 on a negatively correlated contract
                                                                                               ​




                            (e.g., x2 = 1 − x1 , c2 = 0.50). At registration τ2 = 1.5, E[x2 ∣ G1.5 ] =
                                    ​            ​   ​                                                                                         ​                           ​           ​




                            0.50 ≤ c2 . But at t = 2, revealing {1 ∈ U (2)} in F2rec simultaneously
                                        ​                                                                                                                  ​




                            determines x2 = 0, whereas if x2 's own settlement is also delayed,
                                             ​                                 ​




                            conditioning on the joint recording indicator U (t) alters conditional
                            expectations across steps.


https://gemini.google.com/app/0858ee74070bc1bb                                                                                                                                                 6/13
11/11/26, 3:52 PM                                                    See instructions in attached doc.


                           Violation of Fτrecj
                                               -predictability for a reading agent: Because the agent reads
                                                         ​
                                                                 ​




                           live external information in Gτj (news, prices, and real-world outcomes of
                                                                      ​




                           already-settled events whose payout records are delayed in Fτrec   j
                                                                                                 ), the agent's  ​
                                                                                                                     ​




                           choice of whether to register purchase j , its target contract, and its registered
                           stake sj are Gτj -measurable, not Fτrec
                                       ​

                                                 ​
                                                     ​




                                                                  j
                                                                    -measurable. If an agent observes in the
                                                                                ​
                                                                                    ​




                           news that its unrecorded position i won (xi = 1) while i is still unrecorded in
                                                                                         ​




                           Fτrec
                              j​
                                 , or selects contract j conditioned on xi , then Fτrec
                                   ​




                                                                                     j
                                                                                        does not contain the
                                                                                             ​



                                                                                                         ​
                                                                                                             ​




                           agent's decision filtration.
                    2. Why late_records(20) in arithmetic.py.txt gets 1.4% vs. 3.7%: In
                       late_records(hold, bets=400) (lines 192–207), late_records(0) settles
                       every bet immediately before the next bet, so 100% of wealth is available to stake on
                       all 400 sequential bets. In late_records(20), holding every payout for 20
                       purchases locks up 1 − 0.9520 = 64.2% of initial cash in the pending buffer
                       (cutting active cash Ct to roughly half of total wealth on every bet) and discards the
                                                             ​




                       final 20 pending payouts at bet = 399 without ever adding them to cash. Thus,
                       late_records(20) reduces the crossing rate from 3.7% to 1.4% only because it
                       cuts effective capital deployment and truncates the last 20 settlements—not
                       because delayed recording is conservative. In fact, running late_records(0) and
                       late_records(20) on the exact same uniform draws u =
                       rng.random((200_000, 400)) produces hundreds of paths where
                       late_records(20) crosses 20 while late_records(0) never reaches 20 (the
                       exact mechanism of Finding 5.1, 20.29 vs. 8.10).

             Outcome: Invalidates §6.3's proof that the record filtration needs no assumption on polling
             independence when contracts are dependent or when a reading agent observes real-world
             outcomes before the recorder, and misinterprets capital starvation in late_records(20)
             as statistical conservatism.
             Severity: High.

     5. High — Study 1's market-by-market null, deterministic pre-computed G100 baseline,
     and operational crash rule distort the capability claim and allow a 5-session outage to
     trigger a false futility stop

             Where: architecture.md §5.1: "B, G100, with a seed fixed in the manifest... Null: on every
             study market, the agent's chance of a pick that earns from the plant is at most G100's." ;
             §5.2: "The null is stated market by market, so a change in the served model mid-study
             changes the claim's population and not the size... An agent session that crashes or evaluates
             nothing is a miss for the agent and is never replaced. This can only lower the agent's rate.
             G100's picks on all 100 study markets are computed and classified before the first session" ;
             §7: "Five consecutive sessions lost to one operational cause pause it; they still count."
             Construction:

https://gemini.google.com/app/0858ee74070bc1bb                                                                           7/13
11/11/26, 3:52 PM                                         See instructions in attached doc.


                    1. Conditioned on each fixed study market m, G100's outcome is deterministic (
                       pB,m ∈ {0, 1}): Because study market m's seed, G100's seed, and the K fresh twin
                                  ​




                       seeds are all fixed in the manifest (and §5.2 pre-computes and classifies all 100 G100
                       picks before the first agent session), G100's indicator on market m is deterministic:
                       Bm ∈ {0, 1}. Stated literally "on every study market" (pA,m ≤ pB,m for all m =
                          ​                                                                                 ​           ​




                       1, … , 100), the null asserts that on the ≈ 80 markets where Bm = 0, the agent has       ​




                       zero probability of finding the plant (pA,m = 0).
                                                                    ​




                    2. Mid-study model changes can cause Study 1 to reject when the average or
                       current model is worse than G100: Because the market-by-market null is an
                       intersection hypothesis H0 = ⋂100
                                                  ​




                                                        m=1 {pA,m ≤ pB,m }, its negation is merely ∃m :
                                                             ​          ​                   ​




                       pA,m > pB,m —the exact logical flaw Fable conceded on Study 2's mirror in Finding 1.
                              ​       ​




                       Furthermore, because Wald's sequential test runs in manifest order and stops as
                       soon as the LLR crosses ln(19) = 2.944, if Model v1 achieves pA = 0.50 vs. pB =
                                                                                                    ​               ​               ​




                       0.20 on markets 1–35 (crossing the upper boundary at m = 35) or if a silent
                       provider update at m = 25 degrades the model to pA = 0.05 < pB = 0.20 after      ​                   ​




                       banking an early lead of 8 wins to 0 losses (LLR = 8 ln(1.4) = 2.69), a single
                       lucky win on markets 26–100 pushes the LLR across 2.944 and claims capability for
                       a degraded population whose overall mean pˉA < pˉB . ​   ​       ​       ​




                    3. Counting 5 consecutive operational crashes before pausing (§7) drives the
                       SPRT into the lower futility boundary: Under θ1 = 0.70, each discordant win adds
                                                                                    ​




                       ln(0.7/0.5) = +0.3365 to the LLR, while each discordant loss adds
                       ln(0.3/0.5) = −0.5108 (1.52× larger in magnitude), with lower futility boundary
                       − ln(19) = −2.9444. Counting an operational crash as an agent miss (Am = 0)                              ​




                       does not merely "lower the agent's rate" in a fixed-sample sense: in a sequential test,
                       if an API/sandbox failure crashes 5 consecutive sessions (§7's pause threshold)
                       across a stretch where G100 succeeded on 3–4 markets and the running LLR was
                       slightly negative (e.g., −0.90), those operational crashes inject −1.53 to −2.04 of
                       LLR penalty, crossing −2.9444 and permanently terminating Study 1 for futility
                       before the operational pause in §7 can take effect.
             Outcome: Allows operational outages of ≤ 5 sessions to falsely terminate Study 1 at the
             futility boundary and equates rejecting a pointwise intersection null (∃m) with overall
             capability.
             Severity: High.

     6. Medium — Numerical and unit inconsistencies between architecture.md and
     arithmetic.py.txt




https://gemini.google.com/app/0858ee74070bc1bb                                                                                          8/13
11/11/26, 3:52 PM                                         See instructions in attached doc.


             Where: architecture.md preamble: "Run: audit/program/arithmetic.py.txt,
             which prints every number here." ; §1 ("costs of 3 to 5 cents"); §4 Table Row 2 ("0.183, 0.115,
             0.090 at 5, 10, 15: at an even mid, the event 12.4, 8.8 or 7.5 points likelier than the mid"); §4
             text ("under the null the same simulation crosses 20 in 1% of paths"); §5.3 ("At about 22
             sessions a week the study takes under five weeks at most and about two at the target");
             arithmetic.py.txt forward_power(), event_costs(), rates().

             Construction:
                    1. Incompatible cost parameter between forward_power() (c = 0.50) and
                       event_costs() (c = 0.5275) in §4 Table Row 2: In forward_power() (line 168),
                       arithmetic.py.txt solves for the 80%-power net edges 0.183, 0.115, 0.090
                       by calling account(bets, 0.5, e, min(STAKE_CAP, kelly(0.5, e))) with
                       cost = 0.50. Then in event_costs() (line 183), it plugs those exact edges
                       0.183, 0.115, 0.090 into 100 * (cost * (1 + edge) - mid) using cost =
                       0.527493 (mid = 0.50 plus 0.01 half-spread plus 0.017493 fee) to get 12.4,
                       8.8 or 7.5 points above the mid. Because a binary contract at c = 0.5275 has
                       lower return variance per unit of net edge than at c = 0.50 ( 1−c
                                                                                      c
                                                                                         = 0.896 vs. 1.000)
                                                                                              ​




                       and higher Kelly fraction 1−c = 1.116e, solving account() consistently at cost =
                                                  ce
                                                   ​




                       0.527493 yields required net edges of 0.172, 0.109, 0.085 (11.8, 8.5, and 7.2 points
                       above the mid, not 12.4, 8.8, 7.5).
                    2. Unit confusion in §1 ("costs of 3 to 5 cents"): Section 1 states that event-contract
                       exchanges have "costs of 3 to 5 cents". In event_costs(), for mid ∈
                       {0.20, 0.50, 0.80}, the all-in cost above mid (1 cent half-spread plus Kalshi taker fee
                       0.07P (1 − P )) is 2.2 cents, 2.7 cents, and 2.1 cents per contract—never 3 to 5
                       cents. Section 1 conflated 100 * fee / ask (3.4% to 5.5% of the stake in §2.4)
                       with cents per contract (at mid = 0.20, 5.5% of a 21-cent ask is 1.16 cents, not
                       5 cents).
                    3. False "same simulation" claim for the 1% null crossing rate in §4: Section 4 states
                       that every row in the table simulates staking "Kelly's fraction for the true edge,
                       capped at 5% of the cash left at that moment" and claims that "under the null the
                       same simulation crosses 20 in 1% of paths". Under that simulation rule
                       (min(STAKE_CAP, kelly(0.5, edge))), when edge = 0.0, kelly(0.5, 0.0)
                       = 0.0, so the account stakes 0 and crosses 20 in 0% of paths. Line 161 of
                       arithmetic.py.txt obtained 0.010 (1%) by overriding the Kelly rule with a
                       constant 5% stake account(60, 0.5, 0.0, STAKE_CAP) at bets = 60 only.
                    4. Numbers in architecture.md absent from arithmetic.py.txt: Despite the
                       preamble's claim that arithmetic.py.txt prints every number in
                       architecture.md, the script does not compute or print the Prophet Arena Brier
                       numbers in §2.4 (0.184 ± 0.006 vs. 0.187 ± 0.006; instead rates() line 70
                       computes an unused 0.03 Brier gain, 10× larger than Prophet Arena's 0.003

https://gemini.google.com/app/0858ee74070bc1bb                                                                   9/13
11/11/26, 3:52 PM                                         See instructions in attached doc.


                      difference), the session throughput/duration figures in §5.3 (22 sessions/week, 5
                      weeks, 2 weeks), or the Stage 3 evaluation count in §5.5 (9 of 100).
             Outcome: Violates the reproducibility invariant that arithmetic.py.txt generates every
             number in the architecture document and overstates required probability points in §4's
             table.
             Severity: Medium.

     7. Medium — Section 8's dispositions of Paper Findings 7, 10, and 11 rely on unhedged
     variance shares, a backwards Bonferroni CI direction, and an asymptotic S^ → ∞ DSR
     limit

             Where: architecture.md §8 Row 8: "11: I withdraw 'martingale differences'; the
             understatement depends on funding's share of a step's variance, 1.002 at a share of 2.5·10⁻⁵,
             4.9 at Argon's 0.10... 7: the DSR's limit in its own example is z = 11.3, so there is no ceiling; its
             examples show a Sharpe failing, which is the test working. 10: the 0.05/99 is the suite's own
             rule (paper, line 645), not mine; the sentence now names it." Also arithmetic.py.txt
             argon_paper() lines 223–237.

             Construction:
                    1. Paper Finding 11 (Stationary bootstrap variance understatement): In
                       argon_paper() line 235, Fable computes the variance understatement ratio
                         1−w+83w
                       1−w+9.723w
                                  ​, which equals 1.002 only at w = 2.5 × 10−5 (an unhedged directional
                       perp position with 2% 4-hour price volatility and 1 bp funding volatility). However, for
                       any cross-sectional funding-arbitrage or market-neutral strategy (long high-funding
                       perps, short low-funding perps—the exact family planted in Study 1) or during
                       funding spikes, price variance cancels across legs and funding's variance share w
                       rises to 0.05–0.25, where the stationary bootstrap (L = 6) understates the variance
                       of the sample mean by 2.9× to 6.9× (inflating t-statistics by 1.7× to 2.6×).

                    2. Paper Finding 10 (v3 locked suite tolerances): Line 229 of arithmetic.py.txt
                       computes beta.ppf(1 - 0.05 / 99, x + 1, 20_000 - x) <= tolerance.
                       Applying a 99-way Bonferroni correction to an upper confidence bound (1 -
                       0.05/99 = 0.999495) narrows the acceptance region (increasing the suite's false-
                       failure rate under a true null rather than controlling familywise error across 99
                       checks, which requires a lower bound beta.ppf(0.05 / 99, x, 20_000 - x +
                       1) <= alpha). Yet because tolerance was set well above nominal α (0.0625 vs.
                       0.05, 0.015 vs. 0.01, 0.01 vs. 0.005), argon_paper()'s own output (chance =
                       0.69, 0.62, 0.65) proves that a buggy test with true Type-I error inflated to 5.6%
                       , 1.2% (+20%), or 0.75% (+50%) still passes the locked suite 62% to 69% of the
                       time.


https://gemini.google.com/app/0858ee74070bc1bb                                                                    10/13
11/11/26, 3:52 PM                                                           See instructions in attached doc.


                    3. Paper Finding 7 (Deflated Sharpe Ratio screen): Fable argues that because
                       lim ^   z(S^) = 2 545 = 11.3 > 1.645 at kurtosis γ^4 = 18, there is "no ceiling".
                               S →∞   ​




                                                       17
                                                            ​   ​                                                            ​   ​




                      An asymptotic limit as annualized Sharpe S^ann → ∞ is irrelevant when          ​




                      argon_paper() line 226 confirms that over the 91-day holdout (T = 546), an
                      annualized Sharpe of 3.5 fails at every kurtosis γ^4 ≥ 1 (z ≤ 0.748 < 1.645) and           ​   ​




                      an annualized Sharpe of 6.0 with γ^3 = −4, γ^4 = 18 also fails (z = 1.613 <
                                                                                     ​   ​               ​   ​




                      1.645). Worse, in dsr_z() (line 214), whenever a positively skewed strategy satisfies
                      γ^3 S^ > 1 + γ^44−1 S^2 (e.g., γ^3 = 4, γ^4 = 10, S^ = 0.5), the Mertens radicand 1 -
                       ​   ​
                                              ​




                                                  ​                 ​   ​    ​   ​




                      skew * sharpe + (kurtosis - 1) / 4 * sharpe**2 becomes negative,
                      crashing the DSR evaluator with a domain error.
             Outcome: Understates the bootstrap defect for market-neutral/funding strategies, leaves
             the v3 test suite blind to 20%–50% Type-I error inflation 62%–69% of the time, and
             overlooks finite-sample DSR rejection of Sharpe 3.5–6.0 strategies and positive-skewness
             domain crashes.
             Severity: Medium.

     Summary Table of Ranked Findings

      Rank Severity Target                                                                   Core Theoretical / Numerical Break

                                                                                             Sharing the same K fixed fresh market
                                                                                             seeds and noisy reference estimate 12 Δ^ ref        ​   ​




                                                                                             across all 100 study markets makes the
                                          Study 1 twin-market                                discordant indicators D1 , … , D100         ​   ​




      1             Critical              measure & K rule (§5.1,                            statistically dependent (invalidating Wald's
                                          §5.2, §5.5)                                        SPRT); non-linear bankruptcy resurrection
                                                                                             creates positive convexity under planted drift
                                                                                             that does not cancel between twins; 3 ⋅ 10−5
                                                                                             error ignores denominator variance and
                                                                                             intermediate picks
      2             Critical              Negative conclusion &                              account() locks up cash across all weekly
                                          Section 4 power table (§1,                         bets before settling (shrinking the 60th bet to
                                          §2.2, §4, account,                                 0.24% of cash); 11.8/e² computes terminal
                                          betting_cost)                                      wealth P(WN ≥ 20) instead of stopping
                                                                                             power P(supn≤N Wn ≥ 20) (8.67/e2 ,
                                                                                                                         ​           ​




                                                                                             26.3% fewer bets); replacing the 100σ gate
                                                                                             cap (L = 2) with a 10σ step stop (L = 0.20)
                                                                                             cuts 2-year 80%-power Sharpe on certified


https://gemini.google.com/app/0858ee74070bc1bb                                                                                                           11/13
11/11/26, 3:52 PM                                            See instructions in attached doc.



      Rank Severity Target                                        Core Theoretical / Numerical Break
                                                                  Hyperliquid data from 4.0 to 2.08, and 45
                                                                  bounded perp/filing bets/week reaches 80%
                                                                  power at e = 0.043

                                                                  Falsely assures the human of "92% power at
                                                                  the target under every dependence" (§11.4)
                               Study 1 power across               when §5.3's own [0.15, 0.25] band drops to
                               calibration band &                 75.8% at 0.25 and 50.8% at 0.30 (1.1σ from
      3             Critical
                               dependences (§5.3, §8,             0.25); arithmetic.py.txt computes the
                               §11.4, study1)                     failing (0.5, 0.3) and (0.25, 0.20) rows (
                                                                  67.5% undecided despite θ = 0.833) but
                                                                  omits them from §5.3's table

                                                                  Conditioning on Ftrec fails when recording
                                                                                                 ​




                                                                  delays depend on realized outcomes across
                                                                  dependent contracts or when a reading agent
                               Section 6.3 validity proof         observes real-world settlements before the
      4             High       & Finding 5 disposition
                                                                  recorder; late_records(20) gets 1.4% vs.
                               (§6.3, §8, late_records)
                                                                  3.7% only because it locks up 64% of cash
                                                                  in pending and drops the last 20 payouts at
                                                                  step 400
                                                                  Pre-computing G100 on fixed seeds makes
                                                                  Bm ∈ {0, 1} deterministic per market;
                                                                        ​




                                                                  market-by-market intersection null (∀m) can
                               Study 1 null, pre-
      5             High       computed G100, and                 reject under mid-study model changes when
                               crash rule (§5.1, §5.2, §7)        average capability is worse; counting 5
                                                                  consecutive operational crashes before
                                                                  pausing (§7) injects up to −2.55 LLR,
                                                                  triggering a false futility termination

                                                                  forward_power() solves for edges at c =
                                                        0.50 while event_costs() applies them to
                                                        c = 0.5275 (overstating required edge as
                               Script reproducibility &
                               unit mismatches          12.4, 8.8, 7.5 pts vs. 11.8, 8.5, 7.2 pts); §1
      6             Medium
                               (arithmetic.py.txt, §1, conflates 3.4%–5.5% of stake with "3 to 5
                               §2.4, §4, §5.3)          cents" (2.1–2.7 cents actual); §4 claims 1%
                                                        null size under Kelly when kelly(0.5, 0)
                                                        = 0; several text numbers are absent from
                                                        the script


https://gemini.google.com/app/0858ee74070bc1bb                                                                  12/13
11/11/26, 3:52 PM                                            See instructions in attached doc.



      Rank Severity Target                                        Core Theoretical / Numerical Break

                                                                  Finding 11's 1.002 factor assumes an
                                                                  unhedged directional position (w = 2.5 ⋅
                                                                  10−5 ) rather than a market-neutral funding
                                                                  strategy (2.9 × –6.9× variance
                               Dispositions of Paper
      7             Medium     Findings 7, 10, and 11 (§8,        understatement); Finding 10's upper-bound
                               argon_paper)                       Bonferroni still lets 20%–50% inflated Type-I
                                                                  error pass 62%–69% of the time; Finding 7
                                                                  ignores finite-sample rejection of Sharpe
                                                                  3.5–6.0 at T = 546 and negative-radicand
                                                                  crashes for positive skewness




https://gemini.google.com/app/0858ee74070bc1bb                                                                    13/13
