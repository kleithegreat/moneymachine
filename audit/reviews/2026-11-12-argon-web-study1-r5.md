# Adversarial review of study 1 after the fix of round 4, by Gemini 4 Argon (web UI), 2026-11-12

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial, under the convergence rule. This is the review owed before study 1's criterion is committed.
- **Bundle:** `~/Downloads/argon-study1-r5.md`, branch `rearchitecture` at `05a3e0d`, study 1 only.
- **Format:** saved by the human as a PDF at 2026-11-12 01:36 UTC (2026-11-11 20:36 EST), filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged.

**Verdict:** converging, with no critical findings.
- **Agreed:**
  - A25: the claim is "earning from the plant by any route", with the generator unchanged;
  - A26: the 39-of-57 rule's size is 0.00384 and its power 0.901;
  - A27: the calibration sizes;
  - A28: the sequential test, its laws, its power table and the window table.
- **Still open** (medium and low): D9-a, wall 3 enforced per mirror pair (at most 3 of 200), and the N2 variance path in 5.1; D9-b, a constant-position gate or a reference restricted to the planted coins; D10, endogenous void bias stated in CS1.1, with a cap on voids; and build-plan fixes for steps 2 and 5.

---

11/11/26, 8:36 PM                                                                                                                               See attached instructions.



     See attached instructions.
     https://gemini.google.com/app/a8f5376e084a5059

     User prompt: See attached instructions.


     Response: Adversarial Review: Study 1 (Positive
     Control), Round 5 — Part 1
     1. Wall 3 on even parts (D9)
           agreed: Negating target positions negates linear drift capture while preserving symmetric fee and ruin drags, and
           two programs with strictly opposite effects (L2.8) never both win 39 of 57 pairs.
           disputed:
                    Where: architecture.md 5.1 ("Negating every position negates the first, the drift captured. It leaves the
                    second: the variance path, liquidation, clipping, ruin. ... Wall 3 measures the second part directly, on mirror pairs
                    of programs.") and 5.5 / briefs/1-positive-control.md Step 5 (BLIND_MARKETS = 200,
                    EVEN_ALLOWED = 9 over 1,000 pooled classifications across 5 mirror pairs).

                    The construction, with numbers:
                       1. The variance path and bar-return clipping are odd in position, not even. For a DSL program p with
                          target weights wi,t and its mirror −p with weights −wi,t , absent margin liquidation, the bar-t return is
                                                                                    ​                                                                                  ​




                                                                                       net
                          rp,t = gt − ct and r−p,t = −gt − ct , where gt = ∑i wi,t ri,t
                                    ​           ​                   ​                      is the gross return (including generate's
                                                                                                    ​                ​          ​                  ​           ​           ​       ​




                          bar-return clip) and ct ≥ 0 is the turnover fee. Because w_t is chosen before bar t's return is realized,
                                                                                            ​




                          Cov(gt , ct ) ≈ 0 and the return standard deviation σp (m) (which carries N2's GARCH variance path) is
                                        ​           ​                                                                                                      ​




                          symmetric: σ−p (m) = σp (m). Therefore, dividing the odd gross mean gˉp (m) by the even standard
                                                                        ​                                       ​                                                                                  ​   ​




                          deviation σp (m) yields an odd term that cancels identically in even(p, -p):
                                                                ​




                          S(p, m) + S(−p, m)                                                                                   (gˉp (m) − cˉp (m)) + (−gˉp (m) − cˉp (m))          cˉp (m)
                                             =                                                                      2190                                                  = − 2190         ≤ 0.
                                                                                                                                    ​                  ​                       ​       ​       ​                                   ​




                                   2                                                                                                            2 σp (m)                           σp (m)
                                                                                                ​                          ​                                                                               ​               ​                   ​




                                                                                                                                                                   ​                                                                   ​




                         Thus, when N2's variance path raises volatility on the planted market (σp (m) > σp (m0 )), any drift-blind                                                        ​                   ​       ​




                         program with negative sample mean gˉp < 0 gets a positive Sharpe effect Δ(p) =                                 ​   ​




                         ∣gˉp ∣ ( σp (1m0 ) − σp (1m) ) > 0, while its mirror gets Δ(−p) = −Δ(p) < 0; their average Δeven (p, −p) is
                            ​   ​




                                            ​           ​
                                                            ​




                                                                            ​
                                                                                        ​                                                                                                                                      ​




                         0. Wall 3 is completely blind to N2 variance-path and return-clipping effects on the Sharpe denominator.

                       2. 800 of the 1,000 cells in Wall 3 have zero turnover after bar 0, diluting the threshold by 5×. Four
                          of the five mirror pairs in Step 4 (constant long/short and the three fixed random leverage pairs) hold
                          static weights wi,t ≡ wi . Unless they liquidate, their turnover after bar 0 is zero, so cˉp (m) = cˉp (m0 ) =
                                                                                ​                       ​                                                                                                          ​                       ​       ​




                          c0 /T ≈ 10−6 and Δeven ≈ 0 on every pair (q = 0, not q = 1/2). Pooling 800 structurally zero cells
                            ​                                                                               ​




                          with 200 momentum/reversal cells under EVEN_ALLOWED = 9 lets the single active pair earn on
                          9/200 = 4.5% of markets—11.7× the single-pair bound of 0.00384—without tripping Wall 3.
                    Outcome it changes: Replaces the pooled 9 of 1,000 check with a per-mirror-pair bound of at most 3 of
                    200 (binom.sf(3, 200, 0.003837) = 0.0076) or replaces the static random pairs with dynamic turnover
                    pairs, and corrects 5.1's claim that even measures the N2 variance path.
                    Severity: Medium.

     2. The void rule (D10)


https://gemini.google.com/app/a8f5376e084a5059                                                                                                                                                                                                         1/5
11/11/26, 8:36 PM                                                          See attached instructions.


           agreed: The frozen harness cannot resume a crashed session, and judging a cut-off session on a partial ledger
           penalizes an outage (A24).
           disputed:
                    Where: architecture.md 5.2 ("The rule reads how the session ended and never a score. The session
                    counted for a market is the first to reach a designed end, markets stay independent, and the null is about such
                    sessions. ... The lean is second order while voids are few") and briefs/1-positive-control.md Step 8
                    Behaviour 2 and 6.
                    The construction, with numbers: A session's duration is endogenous to its search success. When the agent
                    finds a high-Sharpe program early (e.g., within 10 evaluations / ~12 turns), it exits cleanly (exit == 0). When it
                    fails to find a strong program on a market, it continues searching across many more turns and tool calls,
                    increasing its exposure to API timeouts, harness crashes, or runner kills (crashed(run) == True). Suppose
                    on a market where the single-session null holds (pA = pG100 = 0.15), a winning session (short) crashes with
                                                                                ​               ​




                    probability cW = 0.02, while a losing session (long) crashes with probability cL = 0.25. Because a void
                                           ​                                                            ​




                    triggers up to 3 fresh retries on the same market while G100 never retries, the agent's win probability on the
                    counted session rises to:
                                                         p A (1 − c W )                   0.15 × 0.98
                         pcounted ≈                                              =                           = 0.1874 > 0.15.
                                                             ​     ​




                          A
                                               pA (1 − cW ) + (1 − pA )(1 − cL )   0.15 × 0.98 + 0.85 × 0.75
                                       ​                                            ​                       ​




                                                   ​     ​             ​    ​




                    For independent arms at pG100 = 0.15, this shifts θ from 0.500 to 0.567 and inflates the sequential test's
                    Type I error from 0.020 to 0.114 (2.7× the 0.043 bound). Furthermore, Step 8 Behaviour 6 ("Killed during a
                    session: on restart that session is a void... and the market is run again") runs after searcher.jsonl is already
                    on disk (Step 7.4), so any cluster preemption or manual restart during a long session grants a fresh draw.
                    Outcome it changes: CS1.1 and Step 8 must cap total study-wide void reruns (e.g., at most 5 void reruns
                    across the study before pausing for review) or require that a claim holds under both the primary rule and
                    Step 9.4's first-session recomputation when voided sessions had already spent ≥ 10 evaluations.
                    Severity: Medium.

     3. Constant positions (D9)
           agreed: Leaving the frozen generator unchanged and redefining the claim in 5.1 as earning from the plant by any
           route (funding, momentum, or constant position), with routes reported, resolves Round 4 Finding 3 without
           modifying gate/markets.py (D9 conceded on the claim change).
           disputed:
                    Where: briefs/1-positive-control.md Step 4 ("The reference holds, on every coin and every bar, a
                    position in the direction of the plant's signal..."), Step 1 (PLANTED: coins 0 to 5 of 12), and architecture.md
                    5.5 ("Reported with the walls, never judged: each mirror-set program's own rate of earning at the study's
                    strength").
                    The construction, with numbers:
                       1. The reference trades all 12 coins while only 6 are planted. On coins 6 to 11, the reference takes full-
                          size funding positions that earn zero planted drift while adding 6 coins of unplanted return variance
                             11
                          ∑i=6 σ 2 s2i,t . This doubles the reference's portfolio variance and dilutes its Sharpe effect Δ(ref) by
                               ​               ​




                          1/ 2 = 0.7071 relative to the 6 planted coins. Consequently, the pair-win threshold SHARE * Δ(ref)
                                   ​




                          = 0.5 * Δ(ref) requires capturing only 0.5/ 2 = 35.4% of the 6-coin plant's Sharpe. At SNR =
                                                                                            ​




                          0.12, a momentum average (decay = 0.95, correlation 0.43 in arithmetic.py.txt) concentrated on
                          the 6 planted coins achieves expected effect 2 × 0.43 Δ(ref) = 0.608 Δ(ref) > 0.5 Δ(ref), and a
                                                                                        ​




                          constant position on the 6 planted coins clears 0.5 Δ(ref) whenever ∣E[s]∣/ E[s2 ] ≥ 0.354.
                                                                                                                 ​




https://gemini.google.com/app/a8f5376e084a5059                                                                                           2/5
11/11/26, 8:36 PM                                                     See attached instructions.


                       2. No wall stops calibration if constant positions earn. Because the mirror-set earning rates in Step 5.5
                          are "reported, never judged," calibration proceeds automatically into Step 7 even if constant short/long
                          earns on > 50% of blind markets at the calibrated strength b∗ .

                    Outcome it changes: Either restrict the reference program to PLANTED (coins 0 to 5) or document that SHARE
                    = 0.5 against the 12-coin reference equals 0.354 of the 6-coin oracle; and make it a wall if constant long or
                    constant short earns on more than 50% of the 200 blind markets.
                    Severity: Low-Medium.

     4. The measure (Step 2)
           agreed: Scoring pick and reference on each market's own 57 fresh twin pairs removes selection bias and between-
           market dependence (A18), and the pure/kernel split in measure.py is clean.
           disputed:
                    Where: briefs/1-positive-control.md Step 2 ("Laws of the pure layer, for every pair of lists (finite
                    scores drawn as dyadic numbers, so that sums are exact): ... L2.2 Adding one number to both scores of a pair,
                    for either program, changes nothing. ... L2.7 A pick whose effect on every pair is c times the reference's wins
                    exactly the pairs where the reference's effect is positive, when c ≥ SHARE, and none when c < SHARE.") and
                    Behaviour 7 (scores(program, pairs)).
                    The construction, with numbers:
                       1. IEEE-754 float absorption breaks L2.2, L2.7, and L2.9 on unrestricted dyadic numbers. In Python
                          float (53-bit significand), drawing arbitrary dyadic numbers in hypothesis without a shared exponent
                          bound causes rounding when adding or subtracting across scales. For example, with dyadic scores
                          ref_planted = 1.0 + 3 * 2**-52, ref_twin = 1.0 (ref_effect = 3 * 2**-52), pick_twin
                          = 1.0, and c = SHARE = 0.5, setting pick_planted = pick_twin + c * ref_effect = 1.0 +
                          1.5 * 2**-52 rounds to 1.0 + 2**-52 (or for ref_twin = 0.5, rounds down), making
                          pick_planted - pick_twin < 0.5 * ref_effect so L2.7 fails at c = 0.5. Similarly, adding x =
                          2**30 in L2.2 zeroes out differences of 2−25 .

                       2. Streaming signature in Behaviour 7 (scores(program, pairs)). gate.search.Evaluator
                          streams multiple programs against one loaded market directory (mm eval), not multiple markets against
                          one program. Calling scores(program, pairs) with a single program across 57 pairs (114 distinct
                          markets) can evaluate only 1 program per Evaluator process on each fresh market.
                    Outcome it changes: In Step 2's test specification, constrain dyadic test inputs to fixed-point integers k ⋅
                    2−16 with ∣k∣ ≤ 220 so sums and multiplication by 0.5 are exact in float64; and change Behaviour 7 to
                    scores(programs, pairs) (accepting a sequence of programs per market) so [pick, reference] in
                    Step 5 and the 11 programs in Wall 3 stream through one Evaluator per fresh market.
                    Severity: Medium (build blocker in Step 2 tests and Step 5 runtime).

     5. The 39-of-57 rule and its bound
           agreed: Because each fresh pair is seeded independently by its id (L1.4) and generate draws fresh innovations
           and funding per id, pair wins are conditionally Binomial(57, q) given the pick; (57, 39) is the exact minimum rule
           satisfying P(win ≥ 39 ∣ q = 1/2) = 0.003837 ≤ 0.005 and P(win ≥ 39 ∣ q = 3/4) = 0.9012 ≥ 0.90, and
           L2.10 holds.

           disputed: None.

     6. Calibration (Step 5)


https://gemini.google.com/app/a8f5376e084a5059                                                                                        3/5
11/11/26, 8:36 PM                                                    See attached instructions.


           agreed: Sizing the search at 1,600 markets (TOLERANCE = 0.005) and the check at 10,000 markets (BAND =
           0.12 to 0.18) reduces the false-stop probability from 31% to 0.0046 (A24).

           disputed:
                    Where: briefs/1-positive-control.md Step 5 Behaviour 1 ("For a rising function that is below TARGET
                    − TOLERANCE at strength zero, above TARGET at the upper end, and rises by at most 0.01 over any 0.01/4096
                    of strength, the search returns a strength.") and Behaviour 6 ("Before the first kernel run the job times 20
                    evaluations and prints the projected time... 328 evaluations a market at one strength, at most 13 strengths on
                    1,600 markets and one on 10,000, 10,102,400, plus wall 3's 250,800. A projection above 24 hours stops the
                    job: a wall.").
                    The construction, with numbers:
                       1. Boundary equality in Behaviour 1. The tolerance band [0.145, 0.155] has width 2 × 0.005 = 0.01.
                          After MAX_STEPS = 12 midpoints on [0, 0.01], the bracket width is 0.01/212 = 0.01/4096. A rising
                          function with step 0.01 over 0.01/4096 can take the value 0.145 at the lower endpoint and 0.155 at
                          the upper endpoint; if the builder writes strict inequality abs(rate - TARGET) < TOLERANCE instead
                          of <= TOLERANCE, both endpoints fail and Behaviour 1's property test breaks.
                       2. The 20-evaluation timing in Behaviour 6 misses market generation and process startup, and
                          recomputes cal-a twins 13 times. Timing 20 evaluations on one market measures warm streaming (9
                          ms/eval), omitting generate("N2", ...) + write_pair and per-market Evaluator startup across
                          up to 13 × 1, 600 × 57 + 10, 000 × 57 = 1, 755, 600 pairs (3, 511, 200 730-day markets). Moreover,
                          on cal-a, the 1, 600 × 57 = 91, 200 twin markets have fixed strength 0 across all 13 bisection steps,
                          and the reference's twin score is identical at every step; regenerating and re-scoring them 13 times
                          wastes 12 × 1, 600 × 57 × 2 = 2, 188, 800 evaluations and 1, 094, 400 market writes.
                    Outcome it changes: Specify abs(rate - TARGET) <= TOLERANCE in Step 5; cache cal-a's strength-0
                    twins and reference twin scores across bisection steps; and time a full calibration market (including
                    write_pair and Evaluator startup) in Behaviour 6.

                    Severity: Medium (operational / 24-hour wall risk).

     7. The sequential test (θ1 = 0.7, at most 100 markets)
                                       ​




           agreed: Exact integer characterization L6.1 (7w 3l ≥ 19 ⋅ 5w+l and 19 ⋅ 7w 3l ≤ 5w+l , with no boundary ties since
           gcd(21, 95) = 1), dominance L6.4, concordant invariance L6.5, worst-case size 0.0428 ≤ 0.043 L6.6, power
           rows across [0.11, 0.19], and the 2-week account-window table in 5.3 all verify by exact enumeration.
           disputed: None.

     8. The criterion draft CS1.1
           agreed: CS1.1 accurately states the population, the paired sign test, the 0.043 size bound, the non-rejection
           naming rule (never "no better"), and the underpowered region at pA = 0.3.
                                                                                  ​




           disputed:
                    Where: briefs/1-positive-control.md Step 0 (CS1.1, "Passes while the claim is false: only by chance,
                    at most 0.043, or by a measure that pays something other than the drift captured. Wall 3 bounds the second
                    before any session.").
                    The construction, with numbers: As shown in Points 1 and 2 above, CS1.1's "Passes while the claim is false"
                    clause omits (a) endogenous crash-length selection bias under the void rule (which raises Type I error from
                    0.020 to 0.114 when cL = 0.25, cW = 0.02 at p = 0.15) and (b) the fact that Wall 3's even cancels odd
                                            ​            ​




                    variance-path effects and is diluted 5× by pooling 800 static-position cells with 200 dynamic cells.


https://gemini.google.com/app/a8f5376e084a5059                                                                                       4/5
11/11/26, 8:36 PM                                                     See attached instructions.


                    Outcome it changes: Add one clause to CS1.1's "Passes while the claim is false" bullet noting that
                    differential crash rates between winning and losing searches can bias reruns (bounded by reporting Step 9.4's
                    first-session recomputation and capping voids), and enforce Wall 3's threshold per mirror pair (≤ 3 of 200).
                    Severity: Low-Medium.

     Convergence Ledger (After Round 5 on Study 1)
           Agreed (Closed in Round 5):
                    A25 (closes D9 on the claim and generator): Redefining Study 1's claim to earning from the plant by any
                    route (reporting the inputs read) while keeping the frozen generator unchanged is valid.
                    A26: The 39-of-57 pair rule (L2.10) has exact Binomial size 0.00384 ≤ 0.005 at q = 1/2 and power
                    0.901 ≥ 0.90 at q = 3/4.

                    A27: Calibration sizes (1, 600 search markets at tolerance 0.005; 10, 000 check markets at band [0.12, 0.18])
                    bound false stops at 0.0046.

                    A28: The sequential sign test (θ1 = 0.7, Nmax = 100), its integer laws L6.1–L6.7, its power table across
                                                     ​            ​




                    [0.11, 0.19], and the two-week window table are exact.
           Still Open (Study 1 Build & Criterion Adjustments Before Commit):
                    D9-a (Wall 3 pooling and odd variance path): Enforce Wall 3 per mirror pair (≤ 3 of 200 instead of ≤ 9 of
                    1,000 pooled across four zero-turnover pairs) and note in 5.1 that even measures fee/liquidation asymmetry,
                    not the N2 variance path.
                    D9-b (Constant-position gate & 12-coin reference dilution): Make constant long/short earning > 50% on
                    blind markets a wall (or restrict the reference to PLANTED coins 0–5 so SHARE = 0.5 is not diluted to 0.354
                    of the 6-coin plant).
                    D10 (Endogenous void bias in CS1.1): Note differential crash probability in CS1.1's "Passes while the claim is
                    false" bullet and cap total study voids (or flag if Step 9.4's recomputation flips a claim).
                    Build plan fixes (Steps 2 & 5): Bound dyadic exponents in Step 2's Hypothesis laws (L2.2, L2.7, L2.9);
                    batch [pick, reference] in one Evaluator per fresh market in Step 2 Behaviour 7; use <= TOLERANCE
                    and cache cal-a twins (b = 0) in Step 5.




https://gemini.google.com/app/a8f5376e084a5059                                                                                       5/5
