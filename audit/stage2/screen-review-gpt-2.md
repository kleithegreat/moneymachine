
## Earlier findings

1. **RESOLVED — Universal variance derivation.** The latest revision correctly presents \(1/(T-1)\) as a qualified, first-order zero-mean martingale-null reference, not a universal sampling variance. `whitepaper.tex` now distinguishes that reference from the stronger assumptions underlying the full DSR formula.

2. **PARTLY — Least-favourable null and conservatism claims.** The universal least-favourable claim is withdrawn, and costs, rare losses, heavy tails and adaptive construction are acknowledged. However, the nonnegative-correlation comparison needs an explicit **joint Gaussian reference** qualification, and the new sign-reversal claim is misleading; see below.

3. **PARTLY — Diagnosis of observed dispersion.** Retiring cross-trial dispersion removes the identified self-penalization, without promising holdout power. But the retained 18:33 “Why” paragraph still needs to clarify that **all trials being null is not sufficient** for cross-sectional dispersion to estimate marginal sampling uncertainty.

4. **PARTLY — Other rules and diagnostic dependencies.** Nothing newly supplied shows another active rule making the same dispersion mistake. The retained claim that nothing depends on other trials except through \(N\) still needs to explicitly exclude the correlation-based fragility diagnostics.

5. **PARTLY — Rerun scope and evidence eligibility.** Fresh markets/searches/seeds, complete campaign accounting, no outcome-dependent stopping, retained evidence and historical failures are now explicit. A pre-run freeze of the revised specification and gate-code hashes, campaign counts, targets and failure handling remains to be established; fresh draws from inspected generator families are calibration evidence, not untouched family-level validation.

6. **RESOLVED — C2.4’s selection-frequency criterion.** The revision correctly distinguishes selection being fooled from false promotion and allows C2.4 to fail despite valid holdout protection. It no longer treats marginal SPA rejection rates as determining the joint criterion’s outcome.

7. **RESOLVED — Post-failure governance.** Both documents now explicitly permit a human-authorized **new procedure version**, distinct from a monotonic amendment. The original failure remains recorded, and a revised pass cannot certify the original design.

8. **PARTLY — Independent implementation contract.** The revision specifies the formula, moment conventions, observation grid, shared lengths, small-\(T\)/zero-variance cases, \(N=0/1\), approximation and supersession. **Still blocking:** it gives no screen-specific policy for nonfinite returns, moments or intermediate calculations—independent implementations could silently reject a candidate or instead fail the campaign.

9. **RESOLVED — Selection-conditional holdout protection.** The latest text explicitly restricts selection to search information and states the conditional-mean, loss-bound and predictable-betting assumptions. It also correctly excludes holdout-informed selection.

## New problems introduced

- **NON-BLOCKING — Sign-reversed trials are not interchangeable with independent trials.** In `gate-spec.md`, for \(Z\sim N(0,1)\) and \(x\ge0\),
  \[
  P(\max(Z,-Z)>x)=2\bar\Phi(x),
  \]
  whereas two independent normals give \(2\bar\Phi(x)-\bar\Phi(x)^2\). These are only asymptotically tail-equivalent; their expected maxima differ materially (\(0.798\) versus \(0.564\)), which matters because the benchmark targets an expected maximum.

- **NON-BLOCKING — The newly quoted exact Gaussian variance needs its domain.** State explicitly that \((T-1)/(T(T-3))\) applies at true Sharpe zero **for \(T>3\)**. The screen permits \(T=3\), where that finite-variance identity is unavailable.

**Verdict: Not yet fit for independent implementation and a judged stage-2 rerun: specify nonfinite-input/failure handling, establish the pre-run freeze, and correct the remaining explanatory claims first.**
