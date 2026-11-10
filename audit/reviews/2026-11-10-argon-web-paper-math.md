# Adversarial mathematics review of the whitepaper by Gemini 4 Argon (web UI), 2026-11-10

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial (CLAUDE.md, Orchestration).
- **Bundle:** `~/Downloads/argon-paper-math-check.md`, the whole `docs/whitepaper.tex` at `main` `b1f280b`, with the thesis-track sections excluded.
- **Format:** the human ran it in three parts ("continue" between them) and saved the chat as a PDF at 2026-11-10 21:51 UTC (16:51 EST). The PDF is filed beside this file (`2026-11-10-argon-web-paper-math.pdf`).
- **Text:** below is its text, extracted with `pdftotext` and otherwise unchanged. Mathematics that the extraction garbled is legible in the PDF.

The advisor checked Finding 1's arithmetic before filing: λ* = μ/σ² ≈ 5.2 at the stated Sharpe and σ, so the cap binds. Under λ = 1/2 it reproduced 25.9.

---

11/10/26, 4:51 PM

Review according to the instructions in the document.

Review according to the instructions in the document.
https://gemini.google.com/app/4673503b2ce23adf

User prompt: Review according to the instructions in the document.
Response: Verdict: While the whitepaper is unusually candid about its engineering defects and operational compromises, its load-bearing
mathematical scaffolding breaks at three critical points that invalidate its core statistical and power claims. First, the holdout power derivation in
2
Appendix S4a uses an unconstrained Kelly approximation (log K ≃ nSstep
/2) that violates the mandatory Ville supermartingale cap λt ≤ 1/2
by more than an order of magnitude at the paper's own baseline volatility (σ = 2% per bar); under the cap, reaching p = 0.05 in n = 546 steps
requires an annualized Sharpe ratio of 25.9, not the claimed 4.9, which directly explains why Stage 2 failed with zero power. Second, capping
reported step returns at −1 (Theorem 6) gives zero-mean pre-absorption null strategies with leverage Λ = 4 a strictly positive expected
reported return (\E[rt ∣ Ft−1 ] > 0), corrupting every search-period test (DSR, SPA, Romano–Wolf) and allowing strategies that go completely
bankrupt during the holdout to pass the running-maximum betting test (p = 1/ maxt Kt ≤ 0.05)—while the frozen pilot's unpatched
"bankruptcy resurrection" defect breaks Appendix S3's proof that reported and pre-absorption running maxima agree. Third, Appendix E2's proof
of the pre-absorption lower bound rt′ ≥ −2 relies on a non-causal settlement order (Appendix D1) that credits end-of-bar closing funding qcf4
to positions already liquidated intrabar at the wick (contradicting Appendix E1); under chronological intrabar liquidation, rt′ drops to −2.072 <
−2 (and to −2.16 < −2 after end-of-bar funding erodes equity below the Λ = 4 mark-gross bound), breaking the nonnegativity required by
Ville's inequality.
​

​

​

​

​

​

​

​

​

Finding 1 — Unconstrained Kelly Power Formula Violates the Mandatory Ville Cap λt ≤ 1/2 by 10.5×
​

Severity: Critical
Location: Appendix S4a (\label{app:power}), Section 7 (\label{sec:gate}), and Section 12 (\label{sec:findings}, "Calibration
and sensitivity (stage 2)"):
"At a saturated half-cap, log Kn ≃ n(μ/2 − \Er2 /8), so ignoring the quadratic cost, one finalist needs μ ≃ 2 log 20/n to
reach p = 0.05: about 1.66%, 1.10%, 0.55% and 0.11% per step at n = 360, 546, 1, 080, 5, 400. Holm raises that hurdle. An
2
/2, hence annualized S ≃ 2 log 20 (6 ⋅ 365)/546 ≃
unconstrained second-order Kelly approximation gives log K ≃ nSstep
4.9 at 546 steps."
​

​

​

The Claim: Under a second-order Kelly approximation for the holdout betting test, a single finalist needs an annualized Sharpe ratio of
approximately S ≃ 4.9 (Sstep ≃ 0.1048 per 4-hour bar) to reach p = 0.05 (log Kn ≥ log 20 ≈ 2.9957) over n = 546 steps (91 days).
​

​

Why It Is Wrong (with Recomputation):
1. In Appendix S3 (\label{app:bet}), the second-order Taylor expansion of expected log-wealth for a constant bet λ is \E[log(1 +
2
λr)] ≃ λμ − 12 λ2 \E[r2 ]. Obtaining \E[log Kn ] ≃ 12 nSstep
requires setting λ equal to the unconstrained oracle Kelly fraction:
​

​

​

λ∗ =

​

μ
μ
S
≃ 2 = step .
\E[r2 ]
σ
σ
​

​

​

​

2. However, Appendix S3 proves that Ville's supermartingale inequality under the lower bound rt′ ≥ −L = −2 strictly requires capping
the betting fraction at λt ≤ 1/L = 1/2 ("Ville's nonnegativity requires λt ≤ 1/L under r′ ≥ −L, so any later bet must keep λt ≤
1/L").
​

​

​

​

3. The unconstrained fraction λ∗ = Sstep /σ stays within the cap λt ≤ 1/2 if and only if per-step volatility satisfies σ ≥ 2Sstep . At n =
546, Sstep = 2 log 20/546 = 0.10475, so the unconstrained approximation is valid only if per-step volatility is at least σ ≥
2(0.10475) = 20.95% per 4-hour bar—which corresponds to 20.95% × 6 ⋅ 365 = 980% annualized volatility!
​

​

​

​

​

​

4. At the paper's own baseline crypto bar volatility of σ = 2% per 4-hour bar (used in N1 and C1.7, Appendices D1 and K1), a strategy
with annualized Sharpe S = 4.9 (Sstep = 0.10475, mean per-step return μ = Sstep σ = 0.002095 = 0.2095%) has an
unconstrained Kelly fraction of:
​

​

λ∗ =

0.10475
= 5.2375,
0.02
​

which exceeds the mandatory cap λt ≤ 1/2 by a factor of 10.5×.
​

5. Because the actual bet is capped at λt ≤ 1/2 (and starts at λ1 = 0 with noisy plug-in estimates min(1/2, max(0, St−1 /Qt−1 ))),
the actual expected log-wealth at n = 546, σ = 0.02, and Sann = 4.9 is bounded above by the saturated half-cap drift:
​

​

​

​

​

\E[log K546 ] ≤ 546 (
​

μ σ 2 + μ2
0.002095 0.0004044
−
) = 546 (
−
) = 546(0.0010475 − 0.0000505) = 0.5443 ≪ log(
2
8
2
8
​

https://gemini.google.com/app/4673503b2ce23adf

​

​

​

1/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

This yields K546 ≈ e0.5443 = 1.723, or p ≈ 0.580—nowhere near the p = 0.05 threshold!
​

6. Recomputing the true required annualized Sharpe at σ = 0.02 and n = 546 under the λt ≤ 1/2 cap: solving 546(μ/2 − (σ 2 +
μ2 )/8) = log 20 gives μ = 0.01109 = 1.11% per 4-hour bar (matching S4a's first sentence!), which at σ = 2% per bar is a perstep Sharpe of Sstep = 0.01109/0.02 = 0.5545, or an annualized Sharpe ratio of:
​

​

Sann = 0.5545 6 ⋅ 365 = 25.95
​

(not 4.9).

​

Which Result or Decision It Changes: It invalidates the S ≃ 4.9 power benchmark in Appendix S4a, directly explains why Stage 2's
power check C2.6 failed with 0/100 promotions on planted Sharpes of 1, 2, 2.5, and 3 in N2-s3 (and why even N2-long at n = 5, 400
steps with μ = 0.2% per step had only 5/100 promotions, requiring a human waiver to exit Stage 2), and proves that the pilot's 91-day
forward holdout (n = 546) has essentially zero power for any strategy with realistic volatility (σ ≈ 2% per bar) and annualized Sharpe <
20.

Finding 2 — Capping Reported Losses at −1 Breaks the Null for Search-Period Tests, Promotes Bankrupt Paths on
the Holdout, and Fails Under the Pilot's Bankruptcy Resurrection Defect
Severity: Critical
Location: Section 6 (\label{sec:verified}, Theorem 6), Section 7 (\label{sec:gate}, Steps 2–4 & Step 7), Section 11
(\label{sec:roadmap}, Stage 2), Section 12 (\label{sec:findings}, "Adversarial findings remain findings"), Appendix S3
(\label{app:bet}), and Appendix D1 (\label{app:nulls}):
"6. Bounded returns. Losses are capped at account equity, so every reported per-step return is at least −1." "Bankruptcy's
reported −1 and the pre-absorption terminal loss cannot create a new maximum, and later reported returns are zero. Thus their
running maxima agree, and Ville [39] gives p = min(1, 1/ max K)... The pilot's reported floor Brep = 1 follows from
absorption and zero subsequent equity (I10/L6). It does not imply this conditional null, because \E[max(r′ , −Brep ) ∣ F] =
\E[r′ ∣ F] + \E[(−Brep − r′ )+ ∣ F]." "The defects are future-dependent delisting, reopening after stop-out, unbudgeted
holds, pre-fill sizing equity, bankruptcy resurrection..."
​

​

​

​

The Claim: (a) In the frozen pilot and corrected design, the holdout test's running maximum maxt Kt computed on reported returns rt =
max(rt′ , −1) equals the pre-absorption running maximum maxt Kt′ , preserving conditional Type I error control P (pi ≤ u ∣
Fsearch , H0,i ) ≤ u; (b) requiring positive holdout return alongside pi ≤ αHolm prevents promoting losers; and (c) the null models have
"zero expected net-of-cost return for every strategy expressible in the DSL" for the search-period gate (DSR, Hansen's SPA, Romano–Wolf)
and C2.1's probes.
​

​

​

​

​

​

​

​

​

​

​

Why It Is Wrong (with Concrete Counterexamples):
1. Search-period tests (DSR, SPA, Romano–Wolf) and C2.1 probes operate on arithmetic means of reported returns rt =
max(rt′ , −1), where the null expectation is strictly positive: Unlike Ville's multiplicative wealth process, DSR, Hansen's SPA,
T
Romano–Wolf, and C2.1's per-step z-test/regression probes compute the sample mean rˉ = T1 ∑t=1 rt of reported step returns.
′
′
Under a leveraged strategy (Λ = 4) where pre-absorption return rt ∈ [−2, ∞) satisfies \E[rt ∣ Ft−1 ] = 0, capping the bankruptcy
return at −1 makes \E[rt ∣ Ft−1 ] = \E[rt′ ∣ Ft−1 ] + \E[(−1 − rt′ )+ ∣ Ft−1 ] > 0. Even without any venue shortfall (rt′ ≥ −1), a
strategy that goes 100% bankrupt has a strictly positive arithmetic mean of reported step returns: if a strategy earns r1 = +1.5 on
step 1 (equity $10, 000 → $25, 000), loses 100% of its equity on step 2 (r2 = −1.0, equity $25, 000 → $0), and has rt = 0 for t =
3, … , T , its actual dollar return is −100% (total ruin), yet its mean per-step return is rˉ = (+1.5 − 1.0)/T = +0.5/T > 0 with a
positive Sharpe ratio S^ > 0!
​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

2. The holdout test's running maximum p = min(1, 1/ max1≤t≤T Kt ) rejects H0 on strategies that go bankrupt during the
holdout: Suppose a finalist earns rt = +0.30 on steps t = 1, … , 23 of the holdout, and then goes completely bankrupt on step
′
24 (r24
= −1.5 ⟹ r24 = −1.0, terminal equity eT = $0). With λ1 = 0 and λt = 1/2 for t = 2, … , 23, the wealth at step 23
reaches K23 = (1.15)22 = 21.645 > 20. On step 24 (bankruptcy), K24 = 21.645(1 − 0.5) = 10.822, and Kt = 10.822
thereafter. Because p = 1/ max1≤t≤T Kt = 1/21.645 = 0.0462 < 0.05, the holdout test certifies a strategy that went 100%
bankrupt on the holdout! If Step 7 evaluates holdout return as ∑Tt=1 rt = 23(0.30) − 1.0 = +5.90 > 0, the bankrupt strategy is
promoted to paper trading; even if Step 7 checks terminal dollar equity eT > e0 , a strategy that peaks at K23 = 21.645 and then
loses 99.9% of its gains so that eT = 1.0001e0 is promoted with p = 0.0462.
​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

3. The frozen pilot's "bankruptcy resurrection" defect invalidates Appendix S3's running-maximum equivalence proof: Appendix
S3 proves maxt Ktrep = maxt Kt′ only under the premise that "later reported returns are zero" after bankruptcy. Yet Section 12
explicitly admits that in the frozen pilot (used for all judged runs in Stages 1–4), accounts suffer from bankruptcy resurrection
("Bankrupt accounts and their pending orders cannot revive within a reporting window" is an unjudged post-pilot fix in K1). When a
bankrupt account has rτ′ = −2 capped at rτ = −1, its pre-absorption wealth is Kτ′ = Kτ −1 (1 − 2λτ ) = 0 (at λτ = 1/2), whereas
​

​

​

​

​

https://gemini.google.com/app/4673503b2ce23adf

​

​

​

​

​

2/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

its reported wealth is Kτrep = Kτ −1 (1 − λτ ) = 12 Kτ −1 > 0. If the account resurrects at t > τ and achieves positive returns, Ktrep
continues compounding from 12 Kτ −1 > 0 and can exceed maxs<τ Ks′ , creating false rejections under H0 .
​

​

​

​

​

​

​

​

​

​

​

Which Result or Decision It Changes: It invalidates the theorem that reported-return holdout p-values equal pre-absorption p-values in
the frozen pilot, breaks the zero-mean null property for arithmetic-mean tests (DSR, SPA, Romano–Wolf, C2.1) whenever trajectories hit −1,
and shows the holdout promotion rule fails to guard against catastrophic post-peak drawdowns or bankruptcy.

Finding 3 — Appendix E2's Pre-Absorption Bound rt′ ≥ −2 Fails (rt′ = −2.072 and −2.16) Under Chronological
Settlement and Contradicts Appendix E1
​

​

Severity: Critical
Location: Appendix E2 (\label{app:loss}), Appendix D1 (\label{app:nulls}), and Appendix E1 (\label{app:execution}):
"Settlement precedes fills at equal instants, so that the position that actually held the hour pays for it." "With hourly ∣f ∣ ≤ 0.04,
c/o ≤ (1 + 3 ⋅ 0.04 + 0.3)/(1 − 0.04) < 1.48. An adverse closeout loses at most 0.3 + 0.1 ⋅ 1.48 < 0.448 before closeout
cost when the bar moves against the position, or 0.1 + 3 ⋅ 0.04 + 0.04 ⋅ 1.48 < 0.28 when it moves for it. Closeout cost adds
at most 1.1 ⋅ 1.48κ, so m < 0.46 ≤ 1/2 − 2κ... Λ = 4, m ≤ 12 − 2κ ⟹ r′ ≥ −2." "Under the simulator's settlement
order, a predictable position q held through a bar earns q(c − o) − qo(f1 + f2 + f3 ) − qcf4 ... Long liquidation adds q(low −
c) ≤ 0, short liquidation adds q(high − c) ≤ 0."
​

​

​

​

​

The Claim: In the corrected gapless synthetic market (∣ε∣ ≤ 0.3, ∣u∣ ≤ 0.1, ∣f ∣ ≤ 0.04, κ ≤ 0.003, Λ = 4), pre-fill and post-fill mark
gross satisfy G0 , G1 ≤ Λeprev , single-bar carrying loss per unit notional satisfies m < 0.46 ≤ 12 − 2κ = 0.494, and every step's preabsorption return satisfies rt′ ≥ −2.
​

​

​

​

​

Why It Is Wrong (with Recomputation and Counterexample): In a 4-hour bar [B, B + 4h), funding f1 , f2 , f3 settles at B + 1h, B +
2h, B + 3h (at o), while f4 settles at the closing boundary B + 4h (at c). Intrabar liquidation (stop-out) occurs at the intrabar wick (low or
high).
​

​

​

​

1. Under chronological / E1-compliant settlement (intrabar liquidation occurs before the B + 4h close c, so a liquidated
position does not settle f4 c): Consider a unit-notional short position (q = −1/o) on a bar with f1 = f2 = f3 = f4 = +0.04, ε =
+0.3, and wick multiplier u = 0.1. Then c/o = (1 + 3(0.04) + 0.3)/(1 − 0.04) = 1.42/0.96 = 1.479167, and the adverse wick
is high/o = 1.1(c/o) = 1.627083. The short is liquidated intrabar at high, losing (high − o)/o = 0.627083 on price while
receiving f1 + f2 + f3 = 0.12 in funding for the first 3 hours. Its loss before closeout cost is:
​

​

​

​

​

​

​

​

high − o
− (f1 + f2 + f3 ) = 1.627083 − 1 − 0.12 = 0.507083 > 0.448.
o
​

​

​

​

Adding the closeout cost 1.1(c/o)κ = 1.627083 × 0.003 = 0.004881 gives:

m = 0.507083 + 0.004881 = 0.51196 > 0.494 =

1
− 2κ,
2
​

which after a reversal from G0 = 4eprev to G1 = 4eprev yields:
​

​

​

​

rt′ = −Λ(2κ + m) = −4(0.006 + 0.51196) = −2.0718 < −2.
​

Furthermore, under chronological settlement, a long position that barely survives the intrabar stop-out check with Gadv = Λeadv
(with u = 0, so low = c) subsequently pays the 4th-hour funding f4 c = 0.04G0 at B + 4h. This reduces equity to eprev = (1 −
0.04Λ)eadv = 0.84eadv , leaving mark gross at:
​

​

​

​

​

​

​

G0 =
​

Λ
4
eprev =
eprev = 4.7619 eprev > 4 eprev ,
1 − 0.04Λ
0.84
​

​

​

​

​

​

violating E2's claim that G0 ≤ Λeprev ! If the strategy then emits an undefined weight (which K1 states holds the existing position) or a
tiny sign-preserving reduction (which E2 states bypasses margin admission), G1 = 4.7619eprev is carried into the next bar, where an
′
adverse closeout produces rt+1
≈ −4.7619 × 0.4528 = −2.156 < −2.
​

​

​

​

​

2. Under D1's non-causal settlement order (B + 4h funding qcf4 is settled at the future closing price c before intrabar
liquidation): In E2's derivation, the only reason the liquidated short loses 0.3 + 0.1(1.4792) = 0.4479 instead of 0.5071 is that D1
credits the short with +f4 (c/o) = +0.0592 of end-of-bar funding at the closing price c even though the position was liquidated
intrabar at high. This directly violates E1's invariant ("so that the position that actually held the hour pays for it") and introduces
intrabar lookahead into the stop-out check (making intrabar liquidation equity depend on the end-of-bar close c).
​

​

https://gemini.google.com/app/4673503b2ce23adf

3/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

Which Result or Decision It Changes: Under any causal intrabar liquidation model, rt′ can fall below −2, which makes 1 + λt rt′ < 0 at
λt = 1/2, breaking the nonnegativity required by Ville's theorem in Appendix S3 and invalidating the holdout test's Type I error guarantee.
​

​

​

Finding 4 — Stage 4 Clopper–Pearson Bounds (0.133 and 0.198) Pool Across 7 Zero-Evaluation Runs, 1 Unaudited
Run, and Redesigned Versions
Severity: High
Location: Section 12 (\label{sec:findings}, "Swarm smoke failures (stage 4)") and Appendix S4 (\label{app:calibration}):
"V2 failed with two counted campaigns out of ten. In each, an agent ran /work/mm-agent instead of the permitted relative
command, received no evaluation and stopped. One campaign also exposed a crash in reporting a missing log. No false
discovery was observed, but neither version passed. V3 passed as written: ten campaigns, none promoted, one unresolved (N28, whose agent attempted the unpermitted Edit tool, refused by the CLI with no breach, so its audit does not hold and the
frozen rule leaves the campaign unresolved rather than established; it would not change the verdict). Pooled over the three
versions, 22 campaigns started and 21 are known non-promotions, an upper bound of 0.133 at 95%; one campaign of v2 crashed
without a gate outcome, and counted as a promotion the bound is 0.198."
The Claim: Pooling across Stage 4 versions v1, v2, and v3 yields n = 21 valid non-promoting trials (and x = 1 of n = 22 if the v2 crash is
counted as a promotion), establishing a 95% one-sided Clopper–Pearson upper bound of 0.133 (or 0.198) on the swarm gate's falsepromotion rate.
Why It Is Wrong (with Recomputation): The reported numbers 0.133 = 1 − 0.051/21 (x = 0, n = 21) and 0.198 (solving (1 −
q)21 (1 + 21q) = 0.05 for x = 1, n = 22) require all 21 non-crashing campaigns across v1 (2), v2 (9), and v3 (10) to be i.i.d. Bernoulli(q)
trials of the swarm gate procedure. This is false for three reasons:
1. Seven campaigns in v2 made zero evaluations (P (promotion) ≡ 0): In 7 of v2's 9 non-crashing campaigns, the agent invoked
the wrong binary path (/work/mm-agent), "received no evaluation and stopped." Because the gate only promotes strategies that
were evaluated and filled at least once (Appendix S5), a campaign with zero evaluations has promotion probability identically zero (
pi = 0 =
 q ). Counting 7 structurally impossible promotions as Bernoulli(q) trials inflates n and fabricates statistical confidence out
of broken CLI invocations. Moreover, this directly contradicts the paper's own rule in the immediately preceding paragraph ("Single
agent (stage 3)"): "V2 made no evaluations because workspace writes were denied, so it established no procedure despite its numerical
count."
​

2. One campaign in v3 (N2-8) failed its audit and was left "unresolved rather than established," yet is counted among the 21
"known non-promotions."
3. Optional stopping and redesign across versions: v1 was halted after n = 2 runs failed the 200-evaluation floor, and v2 was halted
after 10 runs failed, violating the fixed-n binomial assumption of Clopper–Pearson. Recomputation: Across all three versions, the
number of campaigns that actually evaluated strategies and established an audited gate outcome is at most 2 (v1) +
2 (v2 counted) + 9 (v3 established) = 13 (or 9 in the passing v3 version alone):
For x = 0, n = 13: q0.95 = 1 − 0.051/13 = 0.206 (not 0.133).
​

Counting the v2 crash as a promotion (x = 1, n = 14): solving (1 − q)13 (1 + 13q) = 0.05 gives q0.95 = 0.300 (not 0.198).
​

For the passing v3 run's 9 established campaigns alone (x = 0, n = 9): q0.95 = 1 − 0.051/9 = 0.283, which exceeds Appendix
S4's stated zero-promotion smoke bound for 10 runs (1 − 0.051/10 = 0.259 ≈ 26%).
​

Which Result or Decision It Changes: It invalidates the pooled 0.133 and 0.198 confidence bounds in Section 12 and shows that v3's 9
established campaigns do not meet the 10-run zero-promotion bound (25.9%) cited in Appendix S4.
CONTINUE FOR PART 2

User prompt: continue

Response: Finding 5 — The Mechanism Check Has Up to 99.9% Pass Rate Under the Complete Null Because
Cov(rˉA − rˉB , rˉ) = (σA2 − σB2 )/n > 0
​

​

​

​

Severity: High
Location: Section 7 (\label{sec:gate}, Step 5), Section 8 (\label{sec:mechanism}), and Appendix S5 (\label{app:selection}):
"5. Mechanism check. A candidate whose pre-registered mechanism prediction fails is removed from the finalists. There is no
override by a higher statistical threshold." "Ideally they are tested on data not used to find the strategy, since predictions
https://gemini.google.com/app/4673503b2ce23adf

4/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

checked on the same sample are not independent of the PnL result... A liquidation-cascade strategy should earn more when
positions are crowded near liquidation and less when funding has normalized." "The mechanism's positive sample-mean
difference matches its stated sample claim. The 10--90% exposure shares are an underived choice to keep the claim from being
vacuous."
The Claim: Requiring a strategy's conditional mechanism prediction to hold (specifically, partitioning active exposure into regime A and
regime B with exposure shares wA , wB ∈ [0.10, 0.90] and requiring the sample-mean difference rˉA − rˉB > 0) acts as an empirical filter
that removes spurious search-period survivors.
​

​

​

​

Why It Is Wrong (with Derivation and Counterexample):
1. In the implementation (Appendix S5), the mechanism check is evaluated on the same search-period sample used to select the
strategy, and tests only the sign of the unstandardized difference D = rˉA − rˉB > 0. Even for an unselected strategy under a
homoskedastic null (σA = σB ), a zero-mean symmetric difference satisfies P (D > 0 ∣ H0 ) = 0.50, passing half of all noise
strategies.
​

​

​

​

​

2. Worse, in Step 5 of the gate, the mechanism check is applied only after a strategy has been selected for having a large positive
overall active sample mean S = wA rˉA + wB rˉB ≫ 0 (having passed DSR ≥ 0.95, SPA, and Romano–Wolf). Suppose a strategy has
zero true edge in every period (\E[rt ∣ Ft−1 ] = 0), with active bars partitioned into nA = wA n bars in regime A (variance σA2 ) and
nB = wB n bars in regime B (variance σB2 ). Under the null, the covariance between the mechanism test statistic D = rˉA − rˉB and
the overall active sample mean S = wA rˉA + wB rˉB is:
​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

Cov(D, S) = Cov(rˉA − rˉB , wA rˉA + wB rˉB ) = wA
​

​

​

​

σA2
σ2
σ 2 − σB2
− wB B = A
.
nA
nB
n
​

​

​

​

​

​

​

​

​

​

​

​

Notice that the exposure shares wA = nA /n and wB = nB /n cancel out completely: the [0.10, 0.90] exposure-share rule in
Appendix S5 has zero effect on the covariance Cov(D, S).
​

​

​

​

3. Whenever the mechanism predicts higher returns in the more volatile regime (σA > σB —as in Section 8's flagship example where
regime A is "crowded near liquidation" and regime B is "when funding has normalized"), D and S are strictly positively correlated
under the complete null.
​

​

4. Concrete numerical example: Take wA = 0.20, wB = 0.80, and σA = 3σB (σA2 = 9σB2 ) under an independent Gaussian null.
Then:
​

Var(D) = (

​

​

9
1
σ2
σ2
+
) B = 46.25 B ,
0.20 0.80 n
n
​

​

​

ρ(D, S) =

​

​

Var(S) = (0.20(9) + 0.80(1))

​

​

​

​

σB2
σ2
= 2.60 B ,
n
n
​

​

​

​

9−1
8
=
= +0.7295.
10.9659
46.25 × 2.60
​

​

​

Conditional on a pure-noise strategy passing the search screen with a t-statistic of zS = S/ Var(S) = 3.0, the conditional
distribution of ZD = D/ Var(D) under H0 is N (ρzS , 1 − ρ2 ) = N (2.1886, 0.4678), so the probability that the null strategy
passes the mechanism check is:
​

​

​

​

​

P (rˉA − rˉB > 0 ∣ zS = 3.0, H0 ) = Φ (
​

​

​

​

​

2.1886
) = Φ(3.200) = 99.93%.
0.4678
​

​

Which Result or Decision It Changes: It shows that Step 5 of the statistical gate provides virtually zero filtering power (99.9% pass rate
under H0 ) for any mechanism that designates higher-volatility states as the active regime on the search sample, and proves that the 10–
90% exposure-share rule fails to prevent this degeneracy.
​

ˉ ≤ 0.0776) Is Vacuous When Power Is Low (≤ 7%),
Finding 6 — C2.5's Hoeffding Bound on Unconditional FDP (X
Passing Gates Whose Promotions Are 100% False
Severity: High
Location: Section 11 (\label{sec:roadmap}, Stage 2), Section 12 (\label{sec:findings}, "Calibration and sensitivity (stage 2)"), and
Appendix S4 (\label{app:calibration}):

ˉ + log(1/δ)/(2n) with confidence 1 − δ . C2.5 chooses n =
"For campaign FDP X ∈ [0, 1], Hoeffding gives \EX ≤ X
ˉ
100, δ = 0.05, target 0.20, giving X ≤ 0.20 − log 20/200 ≃ 0.0776. C9.5's union bound over M mixed cells gives penalty
log(M /0.05)/(2n)..." "After a revised reference scale and an independent implementation, the r2 exit record reports C2.1-C2.5 met. Every complete-null cell had zero promotions in 300 campaigns, and every judged Sharpe mixed cell had zero FDR...
C2.6 failed in both rounds, as written and amended: r2 N2-s3 power was zero and N2-long was 5/100; stage 2 exited only by
the human's sensitivity waiver, not a pass."
​

​

​

https://gemini.google.com/app/4673503b2ce23adf

5/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

ˉ = 1 ∑100 Xi ≤ 0.0776 across n = 100 mixed-signal-and-noise campaigns certifies at 95%
The Claim: Observing sample mean X
i=1
100
confidence that the gate controls the false discovery rate among promotions below 0.20, and Stage 2 met C2.5 across all judged mixed
cells.
​

​

​

Why It Is Wrong (with Recomputation and Counterexample):
1. Unconditional FDR = \E[V / max(R, 1)] vs. Positive pFDR = \E[V /R ∣ R > 0]: In campaign i, let Ri be the total number of
Vi
promoted finalists and Vi ≤ Ri be the number of false promotions. Because Xi = FDPi = max(R
is defined as 0 whenever a
i ,1)
campaign promotes nothing (Ri = 0), Xi is deterministically bounded above by the promotion indicator:
​

​

​

​

​

​

​

​

​

​

n

Xi =
​

Vi
ˉ ≤ 1 ∑ 1{Ri > 0}.
≤ 1{Ri > 0} ⟹ X
max(Ri , 1)
n i=1
​

​

​

​

​

​

​

2. Consequently, whenever a gate promotes in at most 7 out of 100 mixed campaigns—as occurred throughout Stage 2 (N2-s3
ˉ is at most 0.07 ≤ 0.0776 even if
promoted in 0/100 campaigns; N2-long promoted in 5/100 campaigns)—the sample average X
100% of all promoted strategies are false discoveries (Vi = Ri whenever Ri > 0, i.e., pFDR = 100%)!
​

​

​

3. Concrete counterexample: Suppose in n = 100 mixed campaigns, the gate completely ignores the planted real signals and instead
promotes a pure-noise strategy in 5 campaigns (Vi = Ri = 1 in 5 runs, and Ri = 0 in 95 runs). Every single promotion made by the
ˉ = 5/100 = 0.050 ≤ 0.0776, so the gate passes C2.5 with room
system is false (pFDR = \E[V /R ∣ R > 0] = 1.00), yet X
ˉ = 0 trivially, providing zero information about whether
to spare. In cells with zero power (N2-s3, where Ri = 0 in all 100 runs), X
promotions are real or noise.
​

​

​

​

4. Missing union bound across mixed cells (internal contradiction with C9.5): Appendix S4 correctly notes that testing M mixed
cells in C9.5 requires a union-bound penalty log(M /0.05)/(2n), yet applies the unadjusted single-cell penalty
log(20)/200 = 0.1224 in C2.5 across multiple generators and planted-Sharpe cells (e.g., for M = 9 cells, the 95% family-wise
ˉ ≤ 0.20 − log(180)/200 = 0.0389, less than half of 0.0776).
Hoeffding bound requires X
​

​

​

Which Result or Decision It Changes: It invalidates the claim that passing C2.5 in Stage 2 certifies false-discovery control among
promoted strategies when C2.6 failed with 0%–5% promotion rates, because any gate with promotion rate ≤ 7.7% passes C2.5 even if
100% of its promotions are false discoveries.

Finding 7 — The Deflated Sharpe Ratio Formula Is Non-Monotone in S^, Has a Finite Ceiling Φ(2 T − 1/ γ^4 − 1) as
S^ → ∞, and Treats Step 2's Multi-N Max as Non-Trivial When Nraw Dominates Deterministically
​

​

​

​

​

Severity: High
Location: Section 7 (\label{sec:gate}, Step 2), Appendix S2 (\label{app:dsr}), and Appendix S5 (\label{app:selection}):
"2. Screen. Candidates must pass a deflated Sharpe threshold computed at each of several effective-N estimates, using the
largest." "Then DSR = Φ (

(\Shat−S0 ) T −1
),
1−γ^3 \Shat+(γ^4 −1)\Shat2 /4
​

−1

​

​

​

−1

E Φ (1−1/(N e))
S0 = (1−γE )Φ (1−1/NT)+γ
." "The raw count of filled
−1

​

​

​

​

​

​

​

​

​

trials is the primary N , so that no favorable estimate is chosen. The complete-linkage ∣ρ∣ cuts 0.9 and 0.5 are chosen contrasts
for testing fragility, not bounds on the effective number of trials."
The Claim: (a) Evaluating DSR with the plug-in variance denominator 1 − γ^3 S^ + γ^44−1 S^2 properly penalizes non-normal returns while
screening for high Sharpe ratios at DSR ≥ 0.95; and (b) computing the DSR threshold at several effective-N estimates (
Nraw , N∣ρ∣=0.9 , N∣ρ∣=0.5 ) and "using the largest" combines multiple estimators.
​

​

​

​

​

​

​

​

Why It Is Wrong (with Derivation and Counterexample):
1. Non-monotonicity in S^ (higher Sharpe ratios receive lower DSR scores): Because Appendix S2 plugs the observed sample
Sharpe S^ (rather than the null benchmark S0 ) into the variance denominator V (S^) = 1 − γ^3 S^ + cS^2 (where c = (γ^4 − 1)/4),
^
differentiating the DSR z-score Z(S^) = (S −S0 ) ^T −1 with respect to S^ gives:
​

​

​

​

​

​

V (S )

∂Z
=
∂S^
​

​

T −1

(1 − 12 γ^3 S0 ) + (cS0 − 12 γ^3 ) S^
​

​

​

​

​

(1 − γ^3 S^ + cS^2 )
​

​

3/2

​

​

.

​

Whenever γ^3 > 2cS0 = γ^42−1 S0 (which holds for every positively skewed strategy at N = 1 where S0 = 0, and whenever S0 <
2γ^3
2−γ^3 S0
∂Z
^
^
^
γ^4 −1 ), ^ < 0 for all S > Speak = γ^3 −2cS0 : increasing a strategy's Sharpe ratio S strictly lowers its DSR!
​

​

​

​

​

​

​

​

​

​

​

​

​

​

∂S

​

​

​

​

​

​

^
https://gemini.google.com/app/4673503b2ce23adf

​

​

^

^
6/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

2. Finite upper bound as S^ → ∞ rejects sparse/episodic strategies regardless of Sharpe: As S^ → ∞, Z(S^) does not grow
without bound; the S^ terms in the numerator and denominator cancel:

2 T −1
lim Z(S^) =
.
γ^4 − 1
S^→∞
​

​

​

​

​

​

−1)
Whenever a strategy has sample kurtosis γ^4 > 1 + 4(T
≈ 1 + 1.4785(T − 1) (for instance, an episodic event or extreme2
z0.95
funding strategy that triggers on a single spike or has heavy outlier bars), sup ^
DSR(S^) < 0.95, so no positive Sharpe ratio
​

​

​

​

S >S0

can pass the screen.

​

​

3. Deterministic vacuity of max(Nraw , N0.9 , N0.5 ): Complete-linkage clustering partitions the Nraw filled strategies into Nclust
clusters, so 1 ≤ N0.5 ≤ N0.9 ≤ Nraw holds deterministically on every dataset. Since S0 (N ) is strictly increasing in N , "computed at
each of several effective-N estimates, using the largest" in Section 7 Step 2 is algebraically identical to evaluating only Nraw and
ignoring the cluster estimators entirely.
​

​

​

​

​

​

​

​

​

​

Which Result or Decision It Changes: It shows that the DSR screen in Step 2 penalizes positively skewed strategies for having too high a
Sharpe ratio, places an absolute kurtosis ceiling beyond which no Sharpe can pass, and renders the multi-N maximum in Step 2 vacuous.

Finding 8 — N2's Common-Factor t5 Construction Reduces Innovation Kurtosis by Up to 33.3% (Violating C2.2's 20%
Tolerance) and Leaves GARCH(1, 1) Fourth Moments Infinite Before Clipping
​

Severity: High
Location: Section 12 (\label{sec:findings}, "Calibration and sensitivity (stage 2)") and Appendix D1 (\label{app:nulls}):
"N2's GARCH and t5 with common factor... Variance targeting uses ω = s2 (1 − α − β), derived from stationary GARCH
variance; it keeps near-integrated fits from overstating that target. For unit-variance independent factors xi = λzm +
1 − λ2 zi , correlation is λ2 , motivating the square root of fitted mean correlation... C2.2's 100-year moment tolerances (5%
mean absolute innovation, 20% kurtosis, 0.05 autocorrelations/correlations) are chosen stochastic diagnostics."
​

​

​

​

​

The Claim: Constructing correlated innovations via xi = λzm + 1 − λ2 zi from independent unit-variance t5 variables zm , zi yields a
valid t5 GARCH process whose moments match the target within C2.2's 20% kurtosis tolerance.
​

​

​

​

​

​

​

​

Why It Is Wrong (with Recomputation):
1. Sum of independent t5 variables is not t5 and loses up to 33.3% of its kurtosis: A standardized unit-variance tν variable with
6
ν = 5 has theoretical fourth moment (ordinary kurtosis) κt5 = 3 + ν−4
= 9. However, the student-t family is not closed under linear
combinations. For independent unit-variance zm , zi ∼ t5 , the fourth moment of xi = λzm + 1 − λ2 zi is:
​

​

​

​

​

​

​

​

​

​

​

​

4
2
\E[x4i ] = λ4 \E[zm
] + 6λ2 (1 − λ2 )\E[zm
]\E[zi2 ] + (1 − λ2 )2 \E[zi4 ] = 9(λ4 + (1 − λ2 )2 ) + 6λ2 (1 − λ2 ) = 9 − 12λ2 (1 − λ2
​

​

​

​

​

For a cross-coin correlation of ρ = λ2 = 0.50 (typical for crypto perpetuals), \E[x4i ] = 9 − 12(0.25) = 6.0, which is 33.3% below
the t5 kurtosis of 9.0—violating C2.2's 20% kurtosis tolerance even before GARCH filtering!
​

​

2
2. Infinite unconditional fourth moment in GARCH(1, 1): For σt2 = ω + αε2t−1 + βσt−1
with εt = σt xt , finite unconditional
2
4
2
4
kurtosis requires (α + β) + (\E[xi ] − 1)α < 1 (Bollerslev, 1986). For \E[xi ] ∈ [6, 9] and near-integrated crypto GARCH fits (
α + β ≈ 0.95, α ≥ 0.10), (α + β)2 + (\E[x4i ] − 1)α2 ≥ 0.9025 + 5(0.01) = 0.9525 and exceeds 1 whenever α ≥ 0.14, so the
simulated kurtosis in C2.2 is an artifact of the ad-hoc volatility cap 0.06252 and return clip ∣ε∣ ≤ 0.3, not the GARCH(1, 1)-t5 model.
​

​

​

​

​

​

​

​

​

​

Which Result or Decision It Changes: It explains why C2.2's generator comparison initially failed on "variance and standardization
defects" and shows that N2 does not generate t5 -distributed innovations when λ > 0.
​

CONTINUE FOR PART 3

User prompt: continue

Response: Finding 9 — The Unregularized Plug-In Betting Rule λt = min(1/2, max(0, St−1 /Qt−1 )) Has an Infinite
Discontinuity at r1 = 0 and Degenerates into a Bang-Bang {0, 1/2} Switch
​

​

​

​

Severity: High
Location: Section 7 (\label{sec:gate}, "The holdout test") and Appendix S3 (\label{app:bet}):

https://gemini.google.com/app/4673503b2ce23adf

7/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

"The bet is λ1 = 0, then min(1/2, max(0, St−1 /Qt−1 )), zero if Q = 0, with S = ∑ r, Q = ∑ r2 . Maximizing the secondorder approximation \E log(1 + λr) ≃ λμ − λ2 \Er2 /2 gives μ/\Er2 , which motivates the plug-in. The cap 1/2 = 1/L is
derived, not chosen... Only the plug-in form inside [0, 1/2] is a choice."
​

​

​

The Claim: Using the unregularized sample ratio St−1 /Qt−1 = (∑s=1 rs ) / (∑s=1 rs2 ) inside [0, 1/2] provides a well-behaved plug-in
t−1

​

​

t−1

​

​

​

​

2

Kelly fraction approximating μ/\E[r ] on the holdout.

Why It Is Wrong (with Derivation and Counterexample):
1. Infinite discontinuity at t = 2 (S1 /Q1 = 1/r1 → +∞ as r1 → 0+ ): After step 1 (λ1 = 0), the estimator at step 2 is:
​

​

​

​

​

S1
r1
1
= 2 = .
Q1
r1
r1
​

​

​

​

​

​

Unlike regularized betting martingales (such as Waudby-Smith and Ramdas 2024, which add a prior pseudo-variance c > 0 to the
denominator or shrink λt at rate O(1/ t)), S1 /Q1 = 1/r1 explodes as r1 → 0+ . For every positive first-bar return r1 ∈ (0, 2]—
even a microscopic floating-point dust gain of r1 = +10−12 —the ratio 1/r1 ≥ 1/2 immediately slams λ2 to the maximum possible
cap λ2 = 1/2, whereas at r1 = 0 (or r1 = −10−12 ), λ2 = 0. Counterexample: If a strategy has r1 = +10−6 on bar 1 and
experiences a single large loss r2 = −1.80 on bar 2, λ2 = 1/2 causes the wealth process to drop to K2 = 1 + 12 (−1.80) = 0.10
(a 90% wealth collapse on bar 2 triggered by a 10−6 noise tick on bar 1), requiring a 200× gain thereafter to reach Kt = 20.
​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

​

2. Bang-bang saturation across the entire holdout: At step t, λt hits the upper cap 1/2 whenever rˉt−1 ≥ 12 r2 t−1 ≈ 12 σ 2 , and hits
the lower cap 0 whenever rˉt−1 ≤ 0. In terms of the running t-statistic Zt−1 = σ/rˉt−1t−1 , the interior region λt ∈ (0, 1/2) is only:
​

​

​

​

​

​

​

​

​

​

​

0 < Zt−1 <
​

1
σ t − 1.
2
​

​

At the paper's baseline volatility σ = 0.02 per 4-hour bar and holdout length n = 546 ( 545 = 23.35), the upper boundary of the
interior region is Zt−1 = 0.01 t − 1 ≤ 0.2335. Under H0 , P (0 < Zt−1 < 0.01 t − 1) = Φ(0.01 t − 1) − 0.5 is at most
9.2% at t = 546 (and < 1.3% for t ≤ 10). Over more than 90% of the distribution, St−1 /Qt−1 never acts as a Kelly fraction inside
(0, 1/2); it acts as a discontinuous bang-bang switch λt ∈ {0, 1/2}.
​

​

​

​

​

​

​

​

​

​

Which Result or Decision It Changes: It invalidates the second-order interior Kelly motivation in Appendix S3, explains why early-step
rare losses caused the holdout calibration suites (v1 and v2.1) to fail or lose power, and makes the holdout p-value hypersensitive to the sign
of the very first active bar.

Finding 10 — Locked Holdout Suite v3's Slack Tolerances (0.0625, 0.015, 0.01) Pass Broken Implementations with
Up to 60%–80% Inflated Type I Error
Severity: High
Location: Section 12 (\label{sec:findings}, "Holdout-test studies") and Appendix S4 (\label{app:calibration}):
"The human adopted the bounded-return betting test, and its fresh v3 suite passed its 99 judged pairs. That checks the
implementation on bounded conditional-null series..." "The locked holdout suites choose 20,000 series per cell, lengths 540,
546 and 1,080, and levels 0.05, 0.01 and 0.005. Bonferroni confidence 1 − 0.05/K is derived to cover all K pairs (54 in v1 and
v2, 99 in v3). The tolerances 0.0625, 0.015 and 0.01 are chosen slack for an implementation check."
The Claim: Requiring the 1 − 0.05/99 one-sided upper confidence bound across n = 20, 000 simulated null series per cell to fall below
0.0625 (at α = 0.05), 0.015 (at α = 0.01), and 0.010 (at α = 0.005) verifies the holdout test implementation.
Why It Is Wrong (with Recomputation):
1. For v3's exact Ville supermartingale test (p = min(1, 1/ maxt Kt )), the theoretical rejection rate under any valid bounded
conditional-null series is strictly bounded by α (not merely asymptotically ≈ α, and typically ≪ α due to supermartingale overshoot
at the stopping boundary).
​

​

2. With n = 20, 000 series and K = 99 pairs (δBonf = 0.05/99 = 5.05 × 10−4 , z1−δ = 3.2877), if an implementation actually
satisfies ptrue ≤ α, the expected upper Clopper–Pearson bound at α = 0.05, 0.01, 0.005 is at most:
​

​

​

At α = 0.05: qupper (1000; 20000) = 0.0553 (whereas the tolerance is 0.0625).
​

At α = 0.01: qupper (200; 20000) = 0.0125 (whereas the tolerance is 0.0150).
​

At α = 0.005: qupper (100; 20000) = 0.0068 (whereas the tolerance is 0.0100).
​

https://gemini.google.com/app/4673503b2ce23adf

8/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

3. Because v3 kept the wide heuristic tolerances (0.0625, 0.015, 0.010) from the failed asymptotic tests (v1/v2), a bugged
implementation whose true false-rejection rate at α = 0.005 is actually ptrue = 0.0080 (a +60% relative inflation in Type I error,
which is +6.0σ above α = 0.005 at n = 20, 000) produces x = 160 rejections with a 1 − 0.05/99 Clopper–Pearson upper bound
of:
​

qupper (160; 20000) = 0.00999 < 0.0100,
​

and therefore passes v3! Similarly, at α = 0.01 (the exact Holm threshold for k = 5 finalists in Stage 9!), an implementation with
ptrue = 0.0124 (+3.4σ above 0.01) has qupper (248; 20000) = 0.01498 < 0.0150 and passes v3.
​

​

Which Result or Decision It Changes: It shows that v3's tolerances are mis-specified for an exact non-asymptotic supermartingale test
and fail to reject implementation bugs that inflate tail false-discovery rates by 24%–60% at the Holm-adjusted levels (α = 0.01 and
0.005).

Finding 11 — Stationary Bootstrap Block Length (b = 6 Four-Hour Bars = 24 Hours) Is 7× Shorter Than the Null
Generator's Own 168-Hour Funding Blocks
Severity: Medium
Location: Section 7 (\label{sec:gate}, Table 3 & Steps 3–4), Appendix S5 (\label{app:selection}), and Appendix D1
(\label{app:nulls}):
"White's Reality Check, Hansen's SPA... Key assumption to check: A correctly specified family and a suitable bootstrap for
dependent data." "DSR 0.95, SPA/StepM 0.05, stationary-bootstrap mean block 6 four-hour steps and 1,000 resamples are
choices: a stringent screen and a reproducible, affordable heuristic for dependence." "Funding and premiums are resampled
jointly in stationary blocks of mean length 168 hours, which retains their observed floor, tails and cross-coin dependence."
The Claim: A stationary bootstrap with geometric mean block length b = 6 four-hour steps (24 hours) adequately captures serial
dependence for Hansen's SPA and Romano–Wolf StepM in the pilot's funding-dislocation domain.
Why It Is Wrong (with Recomputation):
1. In the pilot's target strategy family (funding dislocations, Stage 0 and Appendix D2), positions are driven by persistent funding rates
and premiums whose autocorrelation structure spans a full week—which is why Appendix D1 explicitly requires a stationary block
length of 168 hours = 42 four-hour bars to preserve their serial dependence!
2. When a strategy's trading signal or conditional variance has geometric persistence at the 42-bar (168h) scale (with lag-k
autocorrelation ρk = ϕk , where ϕ = 1 − 1/42 = 0.9762), the true long-run variance factor relative to i.i.d. variance is 1+ϕ
= 83.0.
1−ϕ
Resampling with mean block length b = 6 (continuation probability pboot = 1 − 1/6 = 0.8333) attenuates lag-k autocovariances by
(pboot )k = (5/6)k , capturing only:
​

​

​

​

1 + ϕpboot
1 + 0.9762(5/6)
=
= 9.73
1 − ϕpboot
1 − 0.9762(5/6)
​

​

​

vs. 83.0,

​

under-estimating the long-run variance of persistent series by up to 8.5× (or under-estimating standard errors by 2.9×), which
inflates studentized t-statistics in SPA and Romano–Wolf.
Which Result or Decision It Changes: It invalidates the bootstrap dependence assumption in Table 3 for any strategy whose returns or
variance inherit the 168-hour persistence built into the pilot's own funding generators.

Finding 12 — Section 10's 4-Pattern Attack Suite Cannot Certify the Licensing Boundary Against 3-Query Linear
Reconstruction (ri,t∗ = 12 (∣C1 ∣μ1 + ∣C2 ∣μ2 − ∣C3 ∣μ3 ))
​

​

​

​

​

​

​

Severity: Medium
Location: Section 10 (\label{sec:multiasset}, "Licensing boundary") and Appendix D3 (\label{app:scope}):
"What may cross: the fields of a frozen per-source report list, each with its minimum aggregation stated as a count of decision
dates and instruments per reported cell: for example results by year and by regime, contribution by instrument and class,
turnover, exposure, hit rate, results split by the strategy's own condition... The boundary belongs to the disclosure path (Section
6), and certification runs a frozen attack suite against it: single-date conditions, one-date differences between two strategies,
long-only single-instrument strategies, and threshold bisection on a feature. It passes only if no per-date value is recovered
within a stated tolerance from any combination of reports within a campaign's evaluation budget."
The Claim: Enforcing a minimum aggregation count m per reported cell, forbidding calendar-date conditions, and passing the four-pattern
attack suite (single-date conditions, one-date differences between two strategies, long-only single-instrument strategies, and threshold
bisection) certifies that no per-date value can be recovered from any combination of reports within a campaign's evaluation budget.
https://gemini.google.com/app/4673503b2ce23adf

9/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

Why It Is Wrong (with Concrete Counterexample): Because the disclosure path returns exact (un-noised) conditional cell averages
1
μ(C) = ∣C∣
∑(i,t)∈C ri,t and cell counts ∣C∣ split by the strategy's own endogenous regime condition C and by instrument, preventing
pairwise 1-date diffs (∣C1 △C2 ∣ = 1) does not prevent 3-way linear reconstruction:
​

​

​

​

​

Let A and B be two disjoint sets of m dates defined by non-calendar feature ranges (e.g., volatility deciles), and let t∗ ∈
/ A ∪ B be
the target date where a secondary feature yt attains its maximum.
​

Submit three strategies whose regime conditions select C1 = A ∪ {t∗ } (size m + 1), C2 = B ∪ {t∗ } (size m + 1), and C3 = A ∪
B (size 2m), each trading a multi-instrument basket (since "contribution by instrument" is disclosed separately).
​

​

​

Every cell and its complement has size ≥ m ≫ 1, no strategy is single-instrument, no strategy uses calendar dates or threshold
bisection, and every pair of strategies differs on at least m + 1 dates (∣C1 △C2 ∣ = 2m, ∣C1 △C3 ∣ = m + 1, ∣C2 △C3 ∣ = m + 1), so
all four attack filters pass.
​

​

​

​

​

​

Yet the exact single-date, single-instrument return ri,t∗ is recovered deterministically in just 3 evaluations:
​

1
((m + 1)μi (C1 ) + (m + 1)μi (C2 ) − 2mμi (C3 )).
2

ri,t∗ =
​

​

​

​

​

​

​

​

Which Result or Decision It Changes: It proves that without differential-privacy noise on disclosed aggregates or restricting regime splits
to a fixed strategy-independent partition, the licensing boundary's certification criterion ("no per-date value is recovered... from any
combination of reports") is mathematically violated by 3-query tracker attacks.

Finding 13 — Table 1's Noise Ceiling h(N , T ) =
39.5% at N = 10

2 log N /T Overstates the Exact Gaussian Expected Maximum by
​

Severity: Medium
Location: Section 2.1 (\label{sec:budget}, Table 1) and Appendix S1 (\label{app:noise}):
"For independent Zi ∼ N (0, 1), \E maxi \Shati = \SE \E maxi Zi , \E maxi Zi ∼
."
​

​

​

​

​

​

2 log N , h(N , T ) =

​

​

2 log N /T

​

The Claim: Table 1 reports the approximate noise ceiling h(N , T ) for N ∈ {10, 1000, 100000} and T ∈ {3, 10, 20} years as an
approximation to \E[max1≤i≤N S^i ].
​

​

Why It Is Wrong (with Recomputation): Because the Gumbel convergence \E[max1≤i≤N Zi ]/ 2 log N → 1 has an O( logloglogNN )
negative correction, using the leading term 2 log N at small N severely overstates the expected maximum:
​

​

​

​

​

At N = 10, exact numerical integration gives \E[max1≤i≤10 Zi ] = 1.5388, whereas 2 log 10 = 2.1460 (a +39.5%
overestimate). The true expected maxima at T = 3, 10, 20 years are 0.89, 0.49, 0.34—not Table 1's 1.24, 0.68, 0.48.
​

​

​

At N = 1, 000, \E[max1≤i≤1000 Zi ] = 3.2414 vs. 2 log 1000 = 3.7169 (+14.7% overestimate): the true values at T =
3, 10, 20 years are 1.87, 1.02, 0.72—not Table 1's 2.15, 1.18, 0.83.
​

​

​

Which Result or Decision It Changes: It inflates every entry of Table 1 (\label{tab:ceiling}), particularly the N = 10 row (which
represents the confirmation family size in Section 9), by up to 39.5%.

Finding 14 — Stage 1's Canary Martingale Leak Threshold (Annualized Sharpe ≥ 4 Over 550 Days, or 4.91σ ) Is Blind
to Subtle Causal Leaks
Severity: Low
Location: Section 12 (\label{sec:findings}, "Kernel MVP (stage 1)") and Appendix K1 (\label{app:kernel}):
2

"C1.7's Gaussian log-return mean must be −σ 2 /2, derived from \EeX = eμ+σ /2 so that prices are a martingale. The chosen 2%
volatility, 550 days, admitted and leaking Sharpes of 4 and 20, six fixed and five fresh seeds and 20 random programs have no
joint calibration of false alarms and detection."
The Claim: Running 20 random programs across 11 seeds on a 550-day (Tyr = 550/365 = 1.5068 yr) martingale canary market with an
admitted annualized Sharpe cutoff of 4.0 tests for causal leakage in the evaluator.
​

Why It Is Wrong (with Recomputation): Over Tyr = 1.5068 years, the standard error of an annualized Sharpe ratio under the martingale
−1/2
null is \SE(S^) = Tyr
= 365/550 = 0.8146. An admitted threshold of S^ = 4.0 corresponds to a single-run z -score of
4.0/0.8146 = 4.91σ (p = 4.5 × 10−7 ). Any partial or conditional lookahead bug (e.g., a 1-bar intrabar close/fill leak on a sparse signal or
​

​

​

https://gemini.google.com/app/4673503b2ce23adf

10/11

11/10/26, 4:51 PM

Review according to the instructions in the document.

a subtle window-boundary off-by-one) that generates a true annualized Sharpe of Strue = 2.0 (zmean = 2.455σ ) will fall below the 4.0
alarm threshold on 1 − Φ((4.0 − 2.0)/0.8146) = 99.3% of individual runs.
​

​

Which Result or Decision It Changes: It shows that passing C1.7 only rules out full-bar clairvoyance (S^ ≥ 4) and cannot detect moderate
lookahead bugs (S^ ∈ [1.5, 3.0]).

https://gemini.google.com/app/4673503b2ce23adf

11/11

