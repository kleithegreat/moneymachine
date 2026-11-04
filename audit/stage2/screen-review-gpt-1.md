
1. **BLOCKING — The universal variance derivation is too strong.**

   The proposed scale is defensible as a **first-order, zero-Sharpe reference**, not as the sampling variance for every stated null.

   Under i.i.d. returns with suitable moments,
   \[
   \operatorname{Var}(\hat S)\approx
   \frac{1-\gamma_3S+(\gamma_4-1)S^2/4}{T}.
   \]
   At \(S=0\), its leading term is \(1/T\). Using \(T-1\) is a convention consistent with the existing DSR formula, not an exact derivation. Even for i.i.d. Gaussian returns, with the usual sample standard deviation,
   \[
   \operatorname{Var}(\hat S)=\frac{T-1}{T(T-3)},\qquad T>3,
   \]
   not \(1/(T-1)\).

   The zero-Sharpe first-order result **can extend to heteroskedastic martingale differences**: the denominator’s estimation error drops out at first order, and return autocovariances vanish. But this requires a martingale CLT and consistent variance normalization—finite second moments, appropriate stabilization and no dominating observations, for example. “For any heteroskedastic, heavy-tailed martingale-difference returns” is false. Heavy tails can violate those conditions; finite variance alone does not guarantee a useful finite-sample normal approximation.

   Away from zero, dependence generally requires the long-run variance of the Sharpe estimator’s influence function, not merely the displayed skewness/kurtosis expression.

   **Fix:** call \(1/\sqrt{T-1}\) a *regular zero-mean martingale-null asymptotic reference scale*, with explicit qualifications. The paper’s i.i.d. qualification is narrower than—and currently inconsistent with—the gate’s universal claim.

2. **BLOCKING — “Least favourable” and the listed optimism/conservatism limits need correction.**

   Zero mean is the natural boundary reference for a non-positive-mean null, but it is not a demonstrated uniformly least-favourable Sharpe distribution over the stated composite class. Subtracting costs also generally makes returns supermartingale differences, not martingale differences.

   Specific corrections:

   - **Correlation is not invariably conservative.** For two standard Gaussian estimates with correlation \(\rho\),
     \[
     E[\max(Z_1,Z_2)]=\sqrt{(1-\rho)/\pi}.
     \]
     Perfect anticorrelation gives \(0.798\), versus \(0.564\) under independence. Independence provides the relevant conservative expected-maximum comparison under **nonnegative correlations and the Gaussian reference model**, not arbitrary correlation. Opposite-sign strategy variants make this distinction practically relevant.
   - **Adaptive search can be optimistic:** correct. Raw canonical count does not account for all information used to construct trials, including disclosures and data-dependent inclusion.
   - **Negative-\(S\), high-skew trials:** a legitimate warning, but incomplete. Their variance can exceed the boundary reference even without extreme skew. Conversely, a larger variance alone does not establish a larger upper-tail probability because their mean is negative.
   - **Rare losses and unstable empirical moments are missing.** Even an i.i.d., bounded-below, zero-mean distribution can produce mostly small positive returns and very rare losses. Samples missing the losses can look exceptionally attractive despite true \(S=0\). This is finite-sample/nonuniform approximation failure, not just a negative-\(S\) issue.

   These limitations need not disqualify a heuristic screen. They do disqualify the current derivation as a general null guarantee.

3. **NON-BLOCKING — Retiring observed cross-trial dispersion addresses a real defect, but the diagnosis overstates when the old estimator worked.**

   A genuine edge contaminating its own benchmark is a concrete design problem, and `c26-failure.md` supplies strong evidence of its operational effect.

   However, “\(\sigma_S\) estimates sampling spread only when every trial is null” should not imply that *every-trial-null is sufficient*. Null strategies can have different negative means from costs, different sampling distributions, substantial correlation and adaptive construction. With identical return streams, cross-trial dispersion is zero despite nonzero marginal sampling uncertainty.

   The replacement removes this particular self-penalization. It does **not** establish that candidates will reach the holdout or that C2.6 will pass; the holdout’s power bottleneck remains.

4. **NON-BLOCKING — No other active rule in the supplied specification repeats the same dispersion mistake.**

   In the active specification:

   - raw \(N\) counts trials;
   - correlation clusters are diagnostic;
   - SPA and StepM use joint returns and bootstrap distributions;
   - Holm uses the frozen finalist-family size;
   - the betting holdout test uses each finalist’s returns.

   SPA/StepM do use other trials’ statistics and construct null bootstrap distributions. That is not the same mistake as interpreting mixed observed Sharpe dispersion as null sampling noise. Their inferential assumptions still do not survive arbitrary adaptive search, as the specification correctly acknowledges.

   This is a **specification-level finding**, not verification of implementation. Also, the claim “nothing in the screen depends on other trials except \(N\)” should explicitly exclude the correlation-based fragility diagnostics.

5. **NON-BLOCKING — The proposed judging scope is substantively appropriate, with explicit dependency and freshness conditions.**

   Reimplementing C2.3 independently and rerunning gate-dependent C2.1 top-five probes and C2.4–C2.6 is appropriate. Retaining genuinely gate-independent C2.1 fixed probes and C2.2 is also appropriate; an unchanged component need not be retested merely because another component changed.

   Conditions:

   - **Fresh IDs must mean fresh stochastic experiments**, including market-generation and search randomness where applicable—not just new labels or bootstrap seeds.
   - Freeze the revised specification, code hashes, seeds/seed derivation, targets, campaign counts and failure handling before running.
   - All started campaigns remain accounted for; no stopping or selective rerunning based on outcomes.
   - Retain earlier failures as development evidence, explicitly ineligible to certify the revised gate.
   - Enumerate retained evidence, including unchanged holdout-test implementation evidence where applicable.

   Replace “stage 2 is judged only on evidence produced after this revision” with “**gate-dependent evidence is replaced as follows; the listed unchanged evidence remains eligible**.” The present blanket sentence contradicts its own exceptions.

   Fresh draws from already examined generator families provide new calibration evidence, not an untouched validation of the generator-family choice.

6. **NON-BLOCKING — C2.4’s second bullet becomes a real test; high SPA rejection rates create a failure risk, not a logically certain failure.**

   Let \(A=\{\text{SPA rejects}\}\) and \(F=\{\text{finalists exist}\}\). The judged quantity is
   \[
   P(A\cap F)=P(A)P(F\mid A),
   \]
   not SPA’s marginal rejection rate.

   The old screen made this criterion essentially vacuous. Under the revision, **expect it to become informative and potentially fail, especially for H400**. But the supplied SPA counts alone do not determine the outcome: the revised DSR screen and StepM can still suppress finalists.

   Concretely, at \(80/300\approx0.267\) SPA rejection, the population target \(P(A\cap F)\le0.10\) requires \(P(F\mid A)\le0.375\). Passing the specified confidence-upper-bound criterion requires additional margin; an observed joint rate of exactly \(30/300\) would not pass.

   If finalists accompany most H400 SPA rejections, expect a clear failure. That would **expose the existing adaptive search/selection gate’s behavior**, previously hidden by an inert screen—not refute the removal of cross-trial dispersion. Nevertheless, it remains a failure of the revised gate against its registered target and cannot be waived on that explanation.

   More screened candidates also need not monotonically increase finalists or promotions: StepM’s family changes, and Holm’s family size changes.

7. **BLOCKING — The revision conflicts with the paper’s post-failure amendment policy.**

   `whitepaper.tex`, Roadmap, permits an amendment after failure only if it “cannot increase false discoveries.” This revision explicitly relaxes screening in relevant cases and can increase false promotions. Maintaining the same valid holdout FWER bound does **not** prove that actual false-promotion probability cannot increase.

   Resolve this openly: identify the revision as a **new design version under an explicit human-approved exception or revised governance rule**, not as an amendment satisfying the existing monotonicity condition. Preserve the original C2.6 failure and avoid implying that a revised pass passes the original design.

8. **BLOCKING — Several implementation details remain underspecified or inconsistent.**

   An independent implementer needs these resolved before C2.3:

   - **\(Z_N\) is an approximation**, not the exact expected Gaussian maximum. Say so in both documents. The approximation already differs noticeably at \(N=2\).
   - **\(N=1\):** the gate specifies \(S_0=0\), but the paper’s displayed expression is undefined. Add the exception there.
   - **\(N=0\):** specify immediate empty selection without evaluating quantiles.
   - **Moments:** give exact definitions of \(\hat S,\hat\gamma_3,\hat\gamma_4\), including sample-SD convention and bias corrections. Pearson’s inequality and the degeneracy argument require compatible moment definitions; arbitrary bias-corrected skewness/kurtosis estimators need not satisfy that relationship.
   - **Observations:** specify whether screen \(T\) includes every emitted search-window step, including flat/no-trade steps, and how unequal available lengths are handled.
   - **Undefined inputs:** specify treatment of \(T<2\), zero return variance and nonfinite moments.
   - **Supersession:** clearly label the original Screen formula as historical and superseded. The long revision chain currently leaves obsolete operative-looking instructions in place.

9. **NON-BLOCKING — The holdout protection survives, but “valid under any selection” needs its existing qualifications.**

   The betting argument protects Holm after arbitrary **search-only selection**, conditional on the search information, provided each null finalist satisfies the conditional-mean hypothesis, the enforced lower bound and predictable betting rules. It does not protect holdout-informed selection or selecting a procedure after inspecting its holdout.

   Write those conditions directly into the revision’s shorthand claim. Importantly, C2.4 can fail its selection-frequency criterion while the holdout’s false-promotion guarantee remains valid: these are different properties.

**Verdict: Do not approve as written; the benchmark replacement is defensible as a calibrated heuristic, but its derivation, correlation claim, implementation contract and post-failure governance need correction before the fresh rerun.**
