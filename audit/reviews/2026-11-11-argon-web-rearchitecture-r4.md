# Adversarial review of the rearchitecture, revision 4, by Gemini 4 Argon (web UI), 2026-11-11

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial (CLAUDE.md, Orchestration), asked for an agreed-and-disputed ledger under the convergence rule.
- **Bundle:** `~/Downloads/argon-rearchitecture-r4.md`, branch `rearchitecture` at `9e5240b`.
- **Format:** two parts, saved by the human as a PDF at 2026-11-11 21:46 UTC (16:46 EST), filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged.

**Verdict:** converging. 8 points agreed, including the stopping constant 8.59/e², study 1's per-market fresh pairs and its population null, and the world-filtration proof. Open disputes:
- **Critical:**
  - study 2's isolated-margin bound and per-leg margins;
  - study 2's fixed pre-freeze hedge;
  - study 1's persistent plant, which pays funding-blind momentum (wall 3), and the 24-of-32 rule's false negatives.
- **High:**
  - study 2's frozen Kelly fraction under a volatility shift, and its 4.4 years, which should be 6.13;
  - study 2's in-sample fidelity on 5-second snapshots.
- **Medium:** study 1's bisection noise, and crashes after the first evaluation.
- **Low:** the perp bracket account.

---

11/11/26, 4:46 PM                                               See instructions in attached doc.



     See instructions in attached doc.
     https://gemini.google.com/app/9791da1f24f82439

     User prompt: See instructions in attached doc.
     Response: Verdict: Revision 4 is a major methodological step forward—we now agree with Fable on the 8.59/e2
     continuous Brownian reflection constant, on generating fresh twin pairs independently per study market in Study
     1, on restating the paper-account supermartingale on the world's filtration Gt (for fixed-cost binary contracts), and
                                                                                            ​




     on requiring a measured thesis count from the existing ledger before reopening the reading-agent line. However,
     revision 4 still cannot be approved as written because Study 2's confirmer design and Study 1's twin-market
     measure contain three critical breaks: (1) in Study 2, requiring the posted isolated margin L on a hedged series
     to be at most 23.4σstep is algebraically identical to requiring ≥ 200% annualized hedged volatility on total posted
                                ​




     margin, forcing > 11 × –22× leverage that liquidates a dip-buying ladder on routine crypto dips (breaking vault
     fidelity), while placing the long and short legs on separate isolated margins creates a convex straddle payoff that
     breaks the Ville supermartingale under the null; (2) Study 2's fixed pre-freeze short −βˉpre rm,t fails to hedge a dip-
                                                                                                                        ​   ​                   ​




     buyer's regime-dependent inventory βt , allowing pure post-freeze market drift (βˉpost − βˉpre )μm in either a bull or
                                                      ​                                             ​   ​                       ​           ​           ​




     bear market to cross wealth 20 with > 75% probability under zero timing skill; and (3) in Study 1, adding a
     persistent AR(1) funding process (ϕ = 1 − 1/42) into the planted coins' price returns induces strong positive price
     autocorrelation, allowing a funding-blind price-momentum program to capture > 50% of the reference effect on
     most twin pairs and trip Wall 3 before Session 1.

     Ranked Findings (Part 1 of 2)
     1. Critical — Study 2's 23.4σstep isolated-margin bound and per-leg isolated margin conflict with vault
                                              ​




     fidelity, liquidate the dip-buyer on routine moves, and break the supermartingale null via straddle
     truncation

           agreed: Replacing the gate's fixed L = 2 (100σ ) cap with a rule's own isolated-margin loss bound L is valid
                                                                                            2190
           in principle if L is a single net position's worst-case loss and satisfies L ≤ Splanned σstep .  ​




                                                                                                                ​
                                                                                                                    ​                       ​




           disputed:
                    Where: architecture.md §2.2 ("Kelly's fraction fits under 1/L while a step's worst loss is at most
                    √2190 / S standard deviations of a step: 23.4 at Sharpe 2, 33.4 at 1.4... A rule on isolated margin has
                    one, the margin it posts for the step"), §6 ("The tested series. The replica's net return a step, minus a
                    fixed short of its universe sized to its average exposure before the freeze, every leg on isolated margin
                    posted at the step's start. The step's loss cannot exceed the margin posted, and that bound must be at
                    most 23.4 standard deviations of a step"), and arithmetic.py.txt confirmer() lines 118–119.
                    Construction:
                       1. The 23.4σstep bound requires ≥ 200% annualized hedged volatility per dollar of total
                                          ​




                          posted margin, destroying fidelity to a low-leverage dip-buyer: Let Mtotal = Mlong + Mshort                               ​           ​       ​




                          be the isolated margin posted at the start of a 4-hour step across the replica's long ladder and the
                          fixed short hedge. Because a 4-hour crypto candle can whipsaw (or long large-cap dips can
                          diverge from the universe basket), the worst-case step loss is L = Mtotal (or                             ​




                          max(Mlong , Mshort ) ≥ Mtotal /2 without whipsaws). Requiring L ≤ 2190
                                      ​           ​       ​




                                                                                                   S
                                                                                                       σstep = 23.40σstep at            ​




                                                                                                                                        ​                   ​       ​




                          S = 2 is algebraically identical to requiring:




https://gemini.google.com/app/9791da1f24f82439                                                                                                                              1/11
11/11/26, 4:46 PM                                                                                        See instructions in attached doc.


                          σann, hedged   σstep 2190
                                       =            ≥ S = 2.0                                                            (200% annualized volatility on posted margin).
                                                             ​           ​




                                                                         ​




                            Mtotal           ​L
                                                                    = (βt − βˉpre )rm,t + ϵt strips out average market exposure
                                                            hedged
                         Because the tested series Rt                                        ​               ​                   ​   ​           ​       ​




                         βˉpre , its step volatility σstep is only the residual timing volatility, whereas Mlong and Mshort must
                           ​         ​                               ​                                                                                                                           ​                       ​




                         each margin the full unhedged directional shock of βt rm,t and −βˉpre rm,t . Specifically, for                              ​       ​           ​   ​       ​




                         large-cap perps with 4-hour volatility σm,step = 1.5% (70.2% annualized), average exposure      ​




                         βˉpre = 0.50, and exposure SD SD(βt ) = 0.25, the hedged step SD is σstep = 0.25 × 1.5% =
                           ​         ​                                                                   ​                                                                           ​




                         0.375%. The bound L ≤ 23.4σstep forces total posted margin to Mtotal ≤ 23.4 × 0.375% =
                                                                                                 ​                                                                               ​




                         8.77% (Mlong = Mshort = 4.39%, i.e., 11.4× to 22.8× leverage). At 4.39% margin per leg, any
                                                 ​               ​




                         4.4% 4-hour dip liquidates the dip-buyer's filled long ladder instead of holding the dip, and any
                         8.8% 4-hour rally liquidates the βˉpre = 0.50 short hedge—failing the Fidelity wall against the
                                                                                         ​           ​




                         actual cross-margined vault. Even worse, a dip-buying ladder places resting limit orders that
                         require margin posted at step start; on non-dip steps where few orders fill (βt ≈ 0), Mtotal /σstep                                                             ​                           ​       ​




                         blows up far beyond 23.4. Conversely, posting realistic non-liquidating margin (Mtotal = 50%)                                                                                   ​




                         yields L/σstep = 133.3 > 23.4, capping the bet at 1/L and collapsing 2-year power at Sharpe 2
                                                         ​




                         back to the gate's capped regime.
                       2. Posting "every leg on isolated margin" creates a convex straddle that breaks the Ville
                          supermartingale under the null: Section 2.2 notes that "clipping a loss raises the mean and
                          breaks the null," yet §6 places "every leg on isolated margin posted at the step's start." When the
                          long leg βrm,t and short hedge leg −βrm,t are placed on separate isolated margins ML =
                                                     ​                                                               ​                                                                                       ​




                          MS = M , any step move ∣rm,t ∣ > M /β liquidates and truncates the losing leg at −M while the
                                 ​                                               ​




                          winning leg earns uncapped upside:

                                             = max(−M , βrm,t ) + max(−M , −βrm,t ) = {
                               hedged                                                                                                                        0                                       if ∣βrm,t ∣ ≤ M ,
                                                                                                                                                                                                                 ​




                         Rt
                                                                                                                                                             ∣βrm,t ∣ − M > 0                        if ∣βrm,t ∣ > M .
                                         ​                                   ​                                                               ​                                               ​                                   ​




                                                                                                                                                                     ​                                           ​




                         Under a zero-mean symmetric jump-diffusion null where ∣βrm,t ∣ > M on 1% of steps by an                                                 ​




                         average excess of 2%, separate per-leg isolated margins generate a positive drift of +0.02% per
                         step (+43.8%/year), violating E0 [Rthedged ∣ Ft−1 ] ≤ 0 and invalidating the 5% Ville bound.
                                                                                     ​                           ​                       ​




                    Outcome: Study 2 either fails its pre-freeze walls (the replica cannot simultaneously match the cross-
                    margined vault's returns and satisfy L ≤ 23.4σstep on recorded books) or invalidates its Type-I error    ​




                    bound via per-leg isolated-margin truncation.
                    Severity: Critical.

     2. Critical — Study 2's fixed pre-freeze short lets passive market drift be confirmed as edge in both bull
     and bear markets, and pre-freeze decomposition cannot detect it

           agreed: Stripping out passive market exposure is necessary so a long-only dip-buyer is not confirmed
           merely for holding positive crypto beta.
           disputed:
                    Where: architecture.md §6 ("Decomposition, with no waiting, descriptive only: how much of the
                    reported Sharpe is the return of holding the vault's average exposure, and how much is timing... Claim,
                    on rejection: from the freeze on, not every four-hour step of the frozen replica, hedged, had a non-
                    positive expected net return given its past. The tested series. The replica's net return a step, minus a
                    fixed short of its universe sized to its average exposure before the freeze") and §11.4 ("A wrong size

https://gemini.google.com/app/9791da1f24f82439                                                                                                                                                                                       2/11
11/11/26, 4:46 PM                                                                                                                                 See instructions in attached doc.


                    leaves market return in the tested series, and a rising market would then be confirmed as edge. The
                    decomposition result is the check, and it is descriptive").
                    Construction:
                       1. Step-level and window-level market return leakage under zero timing skill: A dip-buying
                          ladder has path-dependent exposure βt ∈ [0, 1]: it accumulates inventory during drawdowns and                                           ​




                          unloads inventory in rallies. With a static short sized to pre-freeze average exposure βˉpre , the                                                                                                                                                              ​   ​




                                                               = (βt − βˉpre )rm,t − ct . Since βt is determined by start-of-
                                                        hedged
                          post-freeze step return is Rt                                                                           ​                                   ​               ​               ​                   ​                   ​                       ​




                          step inventory (and resting order fills), conditional on the past Ft−1 :                                                                                                                                                            ​




                                                                                                                                  ∣ Ft−1 ] = (βt − βˉpre )E[rm,t ∣ Ft−1 ] − ct .
                                                                                                         hedged
                                                                                     E[Rt                                     ​                               ​                               ​                       ​                   ​           ​                       ​       ​




                           Even when the strategy has zero timing skill (Cov(βt , rm,t ) = 0), any post-freeze shift in                                                                                                               ​           ​




                           average ladder utilization βˉpost =
                                                              βˉpre converts raw market drift μm directly into tested edge
                                                                                                          ​       ​                       ​           ​                                                                                                                   ​




                           (βˉpost − βˉpre )μm :
                             ​   ​           ​       ​                   ​




                                 Bull-market false confirmation (βˉpost > βˉpre , μm > 0): Suppose pre-freeze was a low-dip                       ​                       ​               ​                   ​               ​




                                 grind with βˉpre = 0.25, while post-freeze experiences deeper pullbacks that keep the
                                                                     ​       ​




                                 ladder filled at βˉpost = 0.65 during an +80%/year bull market (μm = 0.80, residual
                                                                                     ​               ​                                                                                                                                                                            ​




                                 σhedged = 0.16). With zero timing skill, the residual beta Δβˉ = +0.40 earns +32%/year
                                                 ​                                                                                                                                                                                                        ​




                                 (annualized Sharpe S = 0.32/0.16 = 2.00), crossing wealth 20 within two years with 77%
                                 probability.
                                 Bear-market false confirmation (βˉpost < βˉpre , μm < 0): Conversely, suppose pre-freeze had                             ​                   ​                   ​               ​               ​




                                 frequent dips (βˉpre = 0.60) and post-freeze enters a −60%/year bear market where the
                                                                                 ​       ​




                                 ladder stops out or sits lightly filled at βˉpost = 0.20. Then Δβˉ = −0.40 (the tested series is                                                 ​                       ​                                                       ​




                                 net short the market by 40%), earning (−0.40)(−0.60) = +24%/year from the market
                                 crash and confirming a passive short-market overhang as strategy skill.
                       2. Pre-freeze decomposition is tautologically blind to post-freeze beta mismatch: By
                          construction, βˉpre = T1pre ∑t≤0 βt makes the average residual exposure identically zero in the
                                                             ​       ​                           ​                        ​           ​




                          pre-freeze decomposition (βˉpre − βˉpre = 0). A pre-freeze descriptive check provides zero control
                                                                                             ​




                                                                                                              ​       ​                       ​




                          over βˉpost − βˉpre after the freeze.
                                     ​   ​               ​       ​




                    Outcome: Allows Study 2's confirmer to reject the null at W ≥ 20 purely from post-freeze market drift
                        0 whenever ladder utilization shifts between pre-freeze and post-freeze regimes.
                    μm =
                       ​




                    Severity: Critical.

     3. Critical — Study 1's planted AR(1) funding process (ϕ = 1 − 1/42) induces price momentum on the
     planted twin, allowing funding-blind momentum programs to beat half the reference and trip Wall 3

           agreed: Giving each study market m its own 32 fresh twin pairs (m/fresh/0 to m/fresh/31) seeded from
           m's id completely resolves the Round 3 inter-market dependence bug across the 100 study markets.

           disputed:
                    Where: architecture.md §5.1 ("They differ in the planted coins' returns and, under N2, in those coins'
                    variance paths, which feed on the planted return... A pick earns from the plant when, on at least 24 of
                    its market's 32 pairs, its effect is at least half the locked reference program's effect on the same pair,
                    and that effect is positive"), §5.5 Wall 3 ("A locked set of programs that cannot read funding (constant

https://gemini.google.com/app/9791da1f24f82439                                                                                                                                                                                                                                                    3/11
11/11/26, 4:46 PM                                                                                        See instructions in attached doc.


                    long and short... momentum; reversal; a fixed random position at three leverages) is classified on 200
                    calibration markets each. At most 1% of those classifications earn from the plant. More means the score
                    pays convexity on most pairs, and the measure is wrong"), §9 Finding 1, and arithmetic.py.txt line
                    188 (phi = 1 - 1 / 42).
                    Construction:
                       1. Planting persistent AR(1) funding into price returns creates positive return autocorrelation
                          that pays funding-blind price momentum: Fable assumes a funding-blind program can only
                          beat 0.5Δref via convexity ("More means the score pays convexity on most pairs"). In
                                          ​




                          gate/markets.py (arithmetic.py.txt line 188), the funding signal st is a highly persistent                                                              ​




                          AR(1) process with ϕ = 1 − 1/42 = 0.9762 (long-run variance factor 1+ϕ     1−ϕ
                                                                                                         = 83), whereas                                                               ​




                          unplanted price returns rt (0) are serially uncorrelated noise (σr ). Because the generator plants
                                                                          ​                                                                                       ​




                          the edge by adding +αst to the planted coins' price returns rt (α) = rt (0) + αst , the planted
                                                                      ​                                                                                       ​           ​               ​




                          coins' price returns themselves become positively autocorrelated:

                                                      Cov(rt (α), rt−k (α)) = α2 Cov(st , st−k ) = ϕk α2 σs2 > 0.
                                                                              ​                  ​                                ​               ​                           ​




                         Consider the funding-blind momentum program in Wall 3 that forms an exponential moving
                                                                        ∞
                         average of past price returns Mt = (1 − λ) ∑k=1 λk−1 rt−k (α) with λ = 0.95 (∼ 20-step
                                                                                             ​                            ​                           ​




                         lookback) and never reads funding. Averaging over 20 steps shrinks unplanted price-noise
                                                                               1+λϕ
                         variance by 1−λ
                                      1+λ
                                          = 391
                                              ​ = 0.0256, while preserving 1−λ
                                                                  ​




                                                                           1+λ 1−λϕ
                                                                                     = 0.692 of the persistent plant              ​           ​




                         variance. At a modest per-step plant SNR of δ = ασs /σr = 0.12, the correlation between the          ​           ​




                         funding-blind price EMA Mt and the current planted drift αst is:
                                                                                  ​                                                                       ​




                                                                                        (1−λ)ϕ
                                                                                         1−λϕ
                                                                                               δ     ​


                                                                                                                          0.812 × 0.12
                                    ρ(Mt , αst ) =                                                                   =                   = 0.516 > 0.50.
                                                                                                                         0.0256 + 0.0100
                                                  ​       ​                                                      ​                                                    ​




                                                                                      1−λ
                                                                                      1+λ
                                                                                         ​+ 0.692δ 2             ​
                                                                                                                                                                      ​




                         On the twin (α = 0), ρ = 0. Thus, a funding-blind price-momentum program earns > 50% of the
                         funding reference program's twin difference on a majority of pairs—either tripping Wall 3 (> 1%
                         pass rate) and halting Study 1 before Session 1, or misclassifying ordinary price-momentum
                         rules discovered by G100/the agent as "earning from the planted funding edge."
                       2. The 24-of-32 majority rule suffers a 78%–94% false-negative rate on genuine picks
                          capturing 60%–70% of the reference edge: As noted in §11.2, when the reference program sits
                          near Wall 2's threshold (95% positive pairs, pair SNR zref = 1.645), a genuine funding pick                 ​




                          capturing 70% of the reference effect with unit residual noise has single-pair success probability
                          q = Φ( (0.7−0.5)×1.645
                                      1.25−0.70
                                                 ) = 0.671. Under binom.sf(23, 32, q), a pick with q = 0.671 is
                                                      ​
                                                              ​




                          rejected as failing 78.0% of the time (P(≥ 24/32) = 0.220), and at q = 0.60
                          (arithmetic.py.txt line 154) it is rejected 94.0% of the time (0.0596).
                    Outcome: Halts Study 1 at Wall 3 (or contaminates Study 1 with funding-blind price-momentum picks)
                    and discards up to 78%–94% of partial funding discoveries.
                    Severity: Critical.
     CONTINUE FOR PART 2



     User prompt: continue


https://gemini.google.com/app/9791da1f24f82439                                                                                                                                                4/11
11/11/26, 4:46 PM                                                      See instructions in attached doc.


     Response: Ranked Findings (Part 2 of 2)
     4. High — Study 2's pre-freeze Kelly fraction and power table ignore post-freeze volatility shifts (σ
                                                                                                         ^pre =
                                                                                                                                   ​




     σpost ), miscompute time-to-80%-power at Sharpe 1.4 as 4.4 years instead of 6.13 years, and overstate
           ​




     discrete heavy-tailed power via continuous Brownian formulas

               agreed: In continuous time for homoskedastic Gaussian returns with known volatility, the reflection formula
               gives u0.80 = 2.9305 (N = 8.59/e2 ) and requires annualized Sharpe S = 2.9305/ 2 = 2.072 over two
                           ​                                                                                    ​




               years when the rule's worst loss satisfies L ≤ 1/λ∗ .

               disputed:
                    Where: architecture.md §2.2 ("A bet sized for Sharpe 2 has power 0.77 within two years at a true
                    Sharpe of 2, 0.47 at 1.4 and 0.90 at 2.4"), §2.3 Table ("Two years: 1.76 | 2.07 | 4.0"), §6 ("Test. Wealth
                    starts at 1 and bets Kelly's fraction for a Sharpe of 2, computed from the replay before the freeze and
                    registered... Power within one year and two: 0.12 and 0.28 at Sharpe 1; 0.22 and 0.47 at 1.4; 0.42 and
                    0.77 at 2; 0.57 and 0.90 at 2.4. Under no edge, 0.04. Eighty percent takes 1.5 years at 2.4 and 4.4 at
                    1.4"), and arithmetic.py.txt series_power() (lines 97–110) and confirmer() (lines 113–128).
                    Construction:
                       1. Freezing the unstandardized Kelly fraction from pre-freeze replay
                          (\hat{\sigma}_{\text{pre}}) causes negative log-wealth drift when post-freeze
                          volatility rises (\sigma_{\text{post}} > \hat{\sigma}_{\text{pre}}): Section 6
                                                                              2190
                          registers the fixed betting fraction λreg = 2.0/σ^pre from the pre-freeze replay. However,
                                                                                        ​




                                                                        ​               ​




                                                                                    ​




                          series_power() in arithmetic.py.txt (line 106) simulates 1 + bets *
                          rng.normal(sharpe * dt, math.sqrt(dt), paths), tacitly assuming that post-freeze
                          step volatility σpost is identically equal to pre-freeze volatility σ
                                                   ​                                          ^pre . Let r = σpost /σ
                                                                                                                    ^pre be the
                                                                                                                        ​   ​




                          post-freeze to pre-freeze volatility ratio. When true post-freeze Sharpe is Spost , the effective
                                                                                                                    ​




                          standardized bet size is beff = 2r, giving annual log-wealth drift and diffusion spread:
                                                           ​




                                                               g(r) = 2rSpost − 2r2 ,
                                                                               ​                s(r) = 2r.

                               If post-freeze crypto volatility is 1.5× higher than pre-freeze (r = 1.5) while true Sharpe is
                               Spost = 1.4 (the vault's recent figure), the strategy is over-bet beyond 2× Kelly: annual log drift
                                    ​




                               becomes strictly negative (g(1.5) = 2(1.5)(1.4) − 2(1.5)2 = −0.30/year), cutting 2-year
                               power from 0.47 to 0.34. At r = 2.0, g(2.0) = −2.40/year and 2-year power at Spost = 1.4         ​




                               collapses to 0.21 (and at Spost = 2.0, g(2.0) = 0 and 2-year power drops from 0.77 to 0.45).
                                                                 ​




                               Conversely, if post-freeze volatility is half of pre-freeze (r = 0.5), the strategy under-bets (beff =   ​




                               1.0) and 2-year power drops from 0.77 to 0.58 at S = 2.0 and from 0.47 to 0.27 at S = 1.4.

                       2. Wrong formula for "4.4 years at 1.4" in §6: Section 6 states that Study 2's test (which bets the
                          fixed fraction b = 2.0 for Sharpe 2) takes "4.4 [years] at 1.4" to reach 80% power. Line 127 of
                          arithmetic.py.txt computed U80**2 / 1.4**2 = 4.38 years, which assumes the test
                          bets Kelly's fraction for S = 1.4 (b = 1.4) rather than the registered bet b = 2.0. Under the
                          registered bet b = 2.0 at true Sharpe S = 1.4, annual drift is 2(1.4) − 2 = 0.80 and annual
                          spread is 2.0: at T = 4.38 years, crossing(0.80 * 4.38, 2 * sqrt(4.38)) is only 0.692
                          (69.2%). Reaching 80% power under the registered bet b = 2.0 actually takes 6.13 years
                          (crossing(0.80 * 6.13, 2 * sqrt(6.13)) = 0.800), 40% longer than stated. (At S = 2.4
                          with b = 2.0, 80% power takes 1.52 years vs. 1.49 years.)


https://gemini.google.com/app/9791da1f24f82439                                                                                              5/11
11/11/26, 4:46 PM                                               See instructions in attached doc.


                       3. Discrete-step and heavy-tail drag on the 2.07 threshold: In series_power(), discrete 4-hour
                          steps at S = 2.072 reach 20 in 0.786 of paths (requiring S = 2.12 for 80.0% discrete power),
                          and under leptokurtic 4-hour perp returns (γ4 = 10), fourth-moment log drag − γ44−1 λ4 σ 4 and
                                                                         ​
                                                                                                              ​




                                                                                                                  ​




                          discrete boundary overshoot reduce 2-year power at S = 2.0 by a further 3–5 points.

                    Outcome: Overstates Study 2's robustness to volatility regime shifts between pre-freeze and post-
                    freeze windows and understates the time required to reach 80% power at the vault's recent Sharpe of
                    1.4 (6.13 years vs. 4.4 years).
                    Severity: High.

     5. High — Study 2's pre-freeze fidelity check on a reverse-engineered vault conflates in-sample
     specification fitting with kernel validation and cannot verify sub-5-second passive ladder fills or isolated-
     margin step mechanics

           agreed: Replaying the kernel against a live Hyperliquid account's public history over archived L2 books is a
           valuable engineering test of fee, funding, and accounting plumbing that requires no forward waiting.
           disputed:
                    Where: architecture.md §6 ("Fidelity, with no waiting: the replica run by the kernel over the archive,
                    against the vault's own public record over the same dates. This is the first check of the kernel's fills,
                    fees and funding against an account that really traded, and it is a result about the machinery whatever
                    the edge... Walls before any forward step: the archive's dates cover the vault's record; the replica
                    reproduces the vault's daily returns within a tolerance registered before the comparison; the kernel can
                    post isolated margin a step on recorded books").
                    Construction:
                       1. In-sample observational equivalence between reverse-engineered parameters and kernel
                          fill errors: Because the Astraeus vault's source code is not public ("a reverse-engineered vault: a
                          long-only ladder that buys dips in large caps"), its ladder spacing, order sizes, and dip thresholds
                          are inferred from the vault's historical trades and equity curve. Testing whether the reverse-
                          engineered replica matches the vault's daily returns over those same archive dates tests the joint
                          hypothesis of (reverse-engineered rule + kernel execution model). For example, if the kernel's fill
                          model on 5-second S3 L2 snapshots overstates passive limit-order fill rates by 25% (by ignoring
                          queue priority or missing sub-5-second wick reversals), a reverse-engineered ladder tuned to
                          match the vault's historical daily returns simply widens its dip thresholds by 15–30 bps to match
                          daily exposure, passing the daily-return tolerance wall while leaving the kernel's fill defect
                          undetected. To test kernel fills independently of rule reverse-engineering, the kernel must replay
                          the vault's exact historical order/trade events (from Hyperliquid's public vault trade history) or
                          validate the reverse-engineered rule on a held-out pre-freeze sub-window not used to infer the
                          ladder.
                       2. 5-second S3 L2 snapshots miss sub-5-second liquidation wicks that drive dip-buying
                          ladders: Hyperliquid's S3 archive records L2 orderbook snapshots at 5-second intervals
                          ([hyperliquid-archive], §3). A limit-order dip ladder fills primarily during sub-second
                          liquidation cascades that sweep book depth between 5-second snapshots and bounce back
                          within 1–3 seconds. Replaying a limit-order ladder solely against 5-second L2 snapshots misses
                          every intra-interval wick fill unless supplemented by tick/trade-stream extrema.
                       3. Mismatch between the cross-margined vault and Study 2's 4-hour isolated-margin step
                          series: The live vault runs continuously on a cross-margined account, whereas Study 2's
                          confirmer tests a 4-hour stepped series with "every leg on isolated margin posted at the step's

https://gemini.google.com/app/9791da1f24f82439                                                                                   6/11
11/11/26, 4:46 PM                                               See instructions in attached doc.


                         start." If the fidelity wall compares the unhedged cross-margined replica against the vault, it never
                         validates the isolated-margin step series actually fed to the confirmer; if it compares the 4-hour
                         isolated-margin replica, step-boundary resets and isolated-margin liquidations break fidelity with
                         the vault.
                    Outcome: Prevents the daily-return fidelity check from separating kernel execution accuracy from in-
                    sample reverse-engineering unless order-level fill replay and an out-of-sample pre-freeze holdout are
                    required.
                    Severity: High.

     6. Medium — Study 1's 400-market bisection steps are too noisy for the [0.13, 0.17] band, sessions killed
     by outages after evaluation 1 are still counted as misses, and N2 variance-path shifts alter twin scores

           agreed: Defining the null over the population of markets and the pinned model_id, halting on a model_id
           change, and voiding/rerunning sessions that exit non-zero with 0 evaluations (spent == 0) fix the
           deterministic-Bm , model-mixture, and 0-evaluation crash bugs from Round 3.
                                    ​




           disputed:
                    Where: architecture.md §5.1 ("They differ in the planted coins' returns and, under N2, in those coins'
                    variance paths, which feed on the planted return"), §5.2 ("A session that carries another id is not
                    counted; the study stops there... A session is void when the harness exits non-zero with no evaluation in
                    the ledger... Every other session counts: one that ends by its own choice with no evaluation is a miss,
                    and one cut off after an evaluation is judged on its pick"), §5.3 ("The plant's strength is found without a
                    model, by bisection: the strength at which G100's rate on 2,000 calibration markets is between 0.13 and
                    0.17... At 0.3 the study is not powered... In all 20 of stage 3's null campaigns the agent stopped on its
                    own after 6 to 22 evaluations, median 10.5"), §5.4 ("an agent at 0.3 against 0.15 stops here up to 8% of
                    the time and ends undecided up to 36%"), §5.5 Wall 4 ("The bisection ends inside the band within eight
                    steps"), and arithmetic.py.txt line 155 (8 strengths of 400 markets and one of 2,000).
                    Construction:
                       1. 8-step bisection on 400-market samples has SE = 0.0179, nearly as wide as the
                          [0.13, 0.17] target band: While arithmetic.py.txt line 155 checks the final strength on
                          2,000 markets (SE = 0.0080 at 0.15, SE = 0.0088 at 0.19, so 0.19 is 2.28 SE above 0.17, not
                          2.5 SE), the 8 bisection steps that locate that strength use only 400 markets per step (
                          SE400 = 0.15 × 0.85/400 = 0.0179). Because a 95% noise fluctuation on 400 markets is
                                ​                        ​




                          ±0.035—almost the full width (0.04) of the [0.13, 0.17] target band—noisy bisection steps
                          frequently bracket the wrong sub-interval, causing the 8th step to miss [0.13, 0.17] on the
                          2,000-market check over 25% of the time even when a smooth solution exists, falsely tripping
                          Wall 4.
                       2. Under-powering and high futility risk when the agent stops early (median 10.5 vs. G100's
                          100 evaluations): Section 5.1 drops the equal-budget claim and pits the agent's self-stopped
                          session (median 10.5 evaluations in Stage 3) against G100's full 100 evaluations. If the agent's
                          10–20 evaluation search achieves a 2× higher discovery rate than G100's 100 evaluations (pA =   ​




                          0.30 vs. pB = 0.15–0.19), §5.3's table shows power is only 0.323 to 0.667 under
                                        ​




                          least/independent overlap. Moreover, §5.4 states that an agent at 0.30 stops for futility "up to 8%
                          of the time and ends undecided up to 36%" (quoting only pB = 0.15), omitting
                                                                                            ​




                          arithmetic.py.txt's output at the band edge (0.30, 0.19) where futility stops hit 26.9% and
                          undecided hits 40.7% (failing 67.7% of the time).


https://gemini.google.com/app/9791da1f24f82439                                                                                    7/11
11/11/26, 4:46 PM                                                                                           See instructions in attached doc.


                          3. Mid-session operational crashes (spent >= 1) are still counted as agent misses instead of
                             resumed/voided: Under §5.2, a session is voided only when it exits non-zero "with no evaluation
                             in the ledger." Because the agent typically runs an initial baseline evaluation on turn 1 (spent =
                             1), any API timeout, provider 5xx drop, or sandbox crash occurring on turns 2–15 exits non-zero
                             with spent >= 1. Section 5.2 forces that crashed session to be "judged on its pick" (its turn-1
                             baseline evaluation, which fails), so a 5-session API instability streak after turn 1 still injects up to
                             5 × (−0.5108) = −2.55 into the SPRT log-likelihood ratio and triggers a false futility stop.
                             Interrupted sessions exiting non-zero before the agent calls finish should be resumed from
                             their last recorded turn on the same market rather than scored on a truncated turn-1 pick.
                          4. N2 variance-path divergence between twins: Under N2 (§5.1), adding planted returns +αst                                                                                                    ​




                                                                            2         2
                             alters the GARCH conditional variance path σi,t       σi,t (0) on the planted coins, which
                                                                              (α) =                                                             ​                                       ​




                             changes return volatility and margin liquidation timing on the planted twin even for strategies that
                             do not trade funding.
                    Outcome: Risks false Wall 4 failures during 400-market bisection, exposes early-stopping agent runs (
                    pA = 0.30) to a 26.9% false futility rate at the band edge, and penalizes mid-session API outages
                      ​




                    (spent >= 1) as capability misses.
                    Severity: Medium.

     7. Low — Section 6's restated validity proof on the world's filtration holds for fixed-cost binary contracts,
     but applying it to §4's Hyperliquid perp theses requires fill-time indexing, isolated-margin gap bounds, and
     funding deduction

           agreed: Restating the paper-account supermartingale Vt = Ct + ∑i∈U (t) scii E[xi ∣ Gt ] on the world's                           ​                   ​                           ​
                                                                                                                                                                                                        ​




                                                                                                                                                                                                        ​
                                                                                                                                                                                                            ​   ​   ​




           filtration Gt (rather than the record's filtration Ftrec ) completely resolves the Round 3 Doob-martingale and
                            ​                                                                                   ​




           decision-predictability objections for fixed-cost binary payoffs xi ∈ [0, 1].                                                                                ​




           disputed:
                    Where: architecture.md §4 ("A reading agent's bracketed theses on perps"), §6 last paragraph ("A
                    purchase pays a stake the agent registers, at most 5% of cash, at the recorded all-in cost c < 1, and
                    holds stake/c units. A recorded settlement x in [0, 1] pays (stake/c)·x into cash. The null is rejected
                    when cash reaches 20. Null: for every purchase, E[x | everything that has happened by its
                    registration, recorded or not] ≤ c"), and arithmetic.py.txt account() line 81.

                    Construction:
                          1. Measurability of recorded all-in cost cj at registration time τj : In §6's proof, a registration at​                                                                   ​




                                                               s
                             τj lowers cash by sj and adds cjj E[xj ∣ Gτj ] ≤ sj to Vτj . This inequality requires the recorded all-
                                                                                    ​




                                ​                           ​                           ​                   ​                           ​                   ​                       ​


                                                                                                                                    ​                                           ​



                                                                                    ​




                             in execution cost cj to be known (Gτj -measurable) at the time τj in the conditioning set. If the
                                                        ​


                                                                                                    ​
                                                                                                        ​                                                                                       ​




                             agent registers a thesis at τj and its entry fill price cj is determined at the next recorded
                                                                    ​                                                                                               ​




                             Hyperliquid book snapshot τjfill > τj , the null and supermartingale step must be indexed at τjfill
                                                                                ​               ​                                                                                                                           ​




                             (when cj is realized), or else random execution cost cj creates a Jensen's inequality wedge
                                            ​                                                                                                                               ​




                             E[xj /cj ∣ Gτj ] =
                                    ​   ​


                                               E[xj ∣ Gτj ]/E[cj ∣ Gτj ].
                                                ​
                                                    ​           ​


                                                                        ​
                                                                            ​               ​


                                                                                                                        ​
                                                                                                                            ​




                          2. Mapping §4's bracketed perp theses to x ∈ [0, 1]: Because event-contract exchanges were
                             dropped (§3), §4's reading agent trades bracketed theses on Hyperliquid perps. For a multi-day
                             perp bracket to satisfy x ∈ [0, 1] and E0 [x ∣ Gτj ] ≤ c on recorded books, the account​


                                                                                                                                                    ​
                                                                                                                                                        ​




                             specification must enforce (a) per-position isolated margin equal to stake so a price gap past the
                             stop-loss bracket cannot produce x < 0 (losses exceeding stake), and (b) deduction of


https://gemini.google.com/app/9791da1f24f82439                                                                                                                                                                                  8/11
11/11/26, 4:46 PM                                                       See instructions in attached doc.


                                  cumulative hourly funding payments inside the bracket's payoff x (otherwise a perp with positive
                                  funding carry has E[xprice ∣ Gτ ] =
                                                            ​   ​



                                                                     c).
                                3. Terminal pending-payout bug in account() (line 81): Section 6 states that "the null is rejected
                                   when cash reaches 20", but arithmetic.py.txt line 81 evaluates reached |= cash +
                                   pending.sum(axis=1) >= 20 at the end of week 104, counting unrecorded pending positions
                                   as realized cash at the horizon (at bets = 33, hold = 5, edge = 0, line 81 inflates the null
                                   crossing rate from 0.0235 to 0.0242).
                      Outcome: Leaves minor specification gaps between §6's binary-contract formula (c < 1, x in [0,
                      1]) and §4's Hyperliquid perp bracket design, plus a one-line horizon mismatch in account().

                      Severity: Low.

     Convergence Ledger: Agreed Points vs. Open Disputes
     Points Now Agreed

         1. Continuous stopping constant (8.59/e2 and Sharpe 2.07): We agree with Fable's continuous Brownian
            reflection derivation (u0.80 = 2.9305, u20.80 = 8.59, and 2.9305/ 2 = 2.07 over two years when Kelly is
                                                 ​                  ​                            ​




            uncapped).
         2. Reading-agent threshold and parking the thesis track: We agree that at a net edge ceiling of e = 0.05,
            reaching 80% power within two years requires ≥ 33 independent bets/week settled daily, and that the
            reading-agent track should stay parked until the advisor counts registered theses/week in the existing
            thesis ledger.
         3. Q2 paired-arm discordance scaling: We agree with Fable's §4 analysis that pairing an agent with and
            without text filings cancels market variance where the two arms agree, so power scales with the count of
            discordant forecasts.
         4. Study 1 per-market fresh twin pairs (m/fresh/0..31): Generating 32 fresh twin pairs per study market
            from m's own seed completely fixes the Round 3 inter-market dependence bug across the 100 study markets.
         5. Study 1 population null and model_id pinning: Stating the null over the population of markets and the
            pinned model_id (and stopping if model_id changes) resolves the deterministic-Bm and model-mixture
                                                                                                            ​




            bugs.
         6. Study 1 voiding of 0-evaluation crashes: Voiding and rerunning sessions that exit non-zero with 0
            evaluations (spent == 0) fixes pre-evaluation startup crashes.
         7. Section 6's validity proof on the world's filtration Gt : Restating the supermartingale Vt on Gt resolves our
                                                                               ​                                ​     ​




            Round 3 filtration and outcome-dependent delay critique for fixed-cost binary contracts.
         8. Paper Findings 7, 10, and 11 (argon-paper-findings.md): We agree with Fable's dispositions of Paper
            Findings 11 (entering the stationary bootstrap variance understatement into the defect table at funding
            shares 0.05–0.25), 10 (quoting the suite's tolerance as the certified size), and 7 (noting the algebraic bound
            γ^4 ≥ γ^32 + 1 on sample moments and the 91-day wall).
              ​   ​     ​   ​




     Disputes Still Open




https://gemini.google.com/app/9791da1f24f82439                                                                                       9/11
11/11/26, 4:46 PM                                                                         See instructions in attached doc.


      # Severity Section                         Open Dispute                                                       Required Fix to Converge

                                                 Study 2's 23.4σstep bound and
                                                 per-leg isolated margin: L ≤
                                                                                                                    Margin the replica and hedge inside a
                                                 23.4σstep requires ≥ 200%
                                                                      ​




                                                                                                                    single cross-margined sub-account (or
                                                 annualized hedged vol on total                                     net portfolio stop-loss at −Lnet ) rather
                                                 posted margin, forcing > 11 ×
                                                                                                                                                                                 ​




                                                                                                                    than per-leg isolated margins, and verify
      1    Critical    §2.2, §6                  –22× leverage that liquidates a                                    pre-freeze whether a non-liquidating
                                                 dip-buyer on 4.4%–8.8% moves                                       Lnet achieves ≤ 23.4σstep ; if not, size
                                                 (breaking vault fidelity), while
                                                                                                                        ​                                    ​




                                                                                                                    the bet at min(λreg , 1/Lnet ) and report
                                                 separate per-leg isolated margins
                                                                                                                                         ​                           ​




                                                                                                                    the resulting capped power.
                                                 create a convex straddle that
                                                 violates E0 [Rthedged ] ≤ 0.
                                                                          ​                 ​




                                                 Study 2's fixed pre-freeze
                                                 short hedge: Because a dip-
                                                 buyer's exposure βt is regime-                                     Either (a) dynamically hedge start-of-
                                                 dependent, a static pre-freeze                                     step inventory −βt−1 rm,t (testing high-
                                                                                                                                                 ​   ​




                                                 short −βˉpre rm,t leaves (βt −                                     frequency intra-step fill timing) or (b)
      2 Critical       §6, §11.4                                                                                    state explicitly in Study 2's claim that
                                                                  ​           ​       ​                     ​




                                                 βˉpre )rm,t unhedged, allowing bull
                                                                                                                    rejection confirms joint dip-accumulation
                                                  ​   ​       ​




                                                 or bear market drift (βˉpost −
                                                                                                                    + market drift relative to fixed βˉpre , not
                                                                                                    ​   ​




                                                 βˉpre )μm to cross W = 20 with
                                                                                                                                                                             ​       ​




                                                  ​   ​   ​




                                                                                                                    market-neutral timing skill.
                                                 > 75% probability under zero
                                                 timing skill.
                                                 Study 1's AR(1) plant pays
                                                 funding-blind price momentum
                                                 & 24/32 rule drops partial                                         Demean or randomize the planted
                                                 picks: Planting persistent AR(1)                                   funding sign at a faster frequency (or
                                                 funding (ϕ = 1 − 1/42) into                                        orthogonalize planted returns against
                                                                                                                    lagged price EMA) so funding-blind price
                                                 returns induces price
      3 Critical       §5.1, §5.5                                                                                   momentum has zero expected edge, and
                                                 autocorrelation (ρ = 0.516 >
                                                                                                                    increase pair count from 32 to 64 (or
                                                 0.50), letting Wall 3's funding-                                   lower threshold from 0.5Δref to
                                                 blind momentum program pass on
                                                                                                                                                                         ​




                                                                                                                    0.35Δref ) so 0.7Δref picks pass > 85%
                                                 a majority of pairs; meanwhile
                                                                                                                                ​            ​




                                                                                                                    of the time.
                                                 24/32 rejects q = 0.67 picks
                                                 78% of the time.
                                                 Study 2's pre-freeze Kelly
                                                 sensitivity and 4.4-year error:
                                                 Freezing λreg on σ^pre yields    ​             ​




                                                                                                                    Scale each step's bet by trailing pre-
                                                 negative log drift (g = −0.30) at                                  step realized variance σ 2
                                                                                                                                            ^t−1 (capped at      ​




                       §2.2, §6,                 S = 1.4 if σpost = 1.5σ  ^pre ; and                                1/Lt , which remains Ft−1 -predictable),
      4 High
                                                                                      ​                         ​
                                                                                                                            ​                            ​




                       arithmetic.py             80% power at S = 1.4 under                                         and fix line 127 of arithmetic.py.txt
                                                 Study 2's registered bet b = 2                                     and §6 to report 6.13 years at S = 1.4
                                                 takes 6.13 years, not 4.4 years                                    when betting for Sharpe 2.
                                                 (U80^2/1.4^2 assumes betting
                                                 b = 1.4).



https://gemini.google.com/app/9791da1f24f82439                                                                                                                                           10/11
11/11/26, 4:46 PM                                                     See instructions in attached doc.


      # Severity Section                         Open Dispute                                Required Fix to Converge

                                                 Study 2's in-sample fidelity
                                                 wall on 5s L2 snapshots:
                                                                                             Split the pre-freeze archive into an
                                                 Matching daily returns of a
                                                                                             inference window and an out-of-sample
                                                 reverse-engineered ladder on the
                                                                                             fidelity holdout, replay the vault's exact
      5 High           §6                        same archive dates used to infer
                                                                                             public fills to test kernel accounting
                                                 the ladder cannot separate
                                                                                             directly, and incorporate trade-stream
                                                 kernel fill bugs from parameter
                                                                                             high/lows between 5s L2 snapshots.
                                                 tuning, and 5s L2 snapshots miss
                                                 sub-5s liquidation wicks.
                                                 Study 1's 400-market bisection
                                                 noise, spent >= 1 crash rule,
                                                 and (0.3, 0.19) futility rate:              Use ≥ 1, 000 markets in the final 3
                                                 400-market bisection steps (                bisection steps (or stochastic
                                                 SE = 0.0179) fail the                       approximation), resume sessions
                                                                                             interrupted by non-zero harness exits
      6 Medium         §5.2–5.5                  [0.13, 0.17] check > 25% of the
                                                                                             from their last checkpointed turn, and
                                                 time; outages killing a session             quote the 26.9% futility / 40.7%
                                                 after turn 1 (spent >= 1) are still         undecided figures for (0.3, 0.19) in
                                                 scored as misses; and
                                                                                             §5.4.
                                                 (0.3, 0.19) has a 26.9% futility
                                                 rate.
                                                 Perp bracket mapping in §6's
                                                 account & line 81 of
                                                 account(): Applying §6's binary
                                                                                             Index the null at fill time τ fill , define
                                                 formula (c < 1, x in [0, 1])
                       §4, §6,                   to §4's perp brackets requires              x ∈ [0, 1] net of funding on isolated
      7 Low                                      indexing at fill time τ fill , isolated     margin for perp brackets, and remove +
                       arithmetic.py
                                                 margin for gap risk, and                    pending.sum(axis=1) from line 81 of
                                                 deducting funding inside x; line            arithmetic.py.txt.
                                                 81 of account() counts
                                                 pending as cash.




https://gemini.google.com/app/9791da1f24f82439                                                                                             11/11
