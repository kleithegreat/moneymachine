
- **2 — RESOLVED:** The closing revision qualifies the correlation comparison by a joint Gaussian reference and withdraws the misleading sign-reversal claim.
- **3 — RESOLVED:** It explicitly explains why all trials being null is insufficient for cross-trial dispersion to estimate marginal sampling uncertainty.
- **4 — RESOLVED:** The other-trial-independence statement now explicitly excludes the correlation-based fragility diagnostics.
- **5 — RESOLVED:** The pre-shard freeze contract pins the specification/code commit, executable and dependencies, campaign identities and counts, and failure handling, while correctly classifying inspected-family reruns as calibration evidence.
- **8 — PARTLY:** Nonfinite returns now cause a campaign crash counted as a promotion, but nonfinite moments or intermediate calculations still lack an explicit policy because finite returns do not guarantee finite floating-point calculations.
- **Sign-reversed trials — RESOLVED:** The revision gives the correct expected-maxima comparison and withdraws their claimed interchangeability with independent trials.
- **Exact Gaussian variance — RESOLVED:** The identity is now explicitly restricted to true Sharpe zero and \(T>3\).

**BLOCKING — New false arithmetic assurance, leaving item 8 open:** “With finite returns every intermediate quantity is finite” is false—for example, finite returns \((0,0,10^{100})\) can overflow the fourth central moment in binary64 arithmetic; explicitly require nonfinite computed moments, intermediates or scores to raise and trigger the same campaign-crash accounting, rather than silently rejecting a candidate.

**Verdict: Not yet fit for independent implementation or a judged stage-2 rerun; specify nonfinite-computation handling first.**
