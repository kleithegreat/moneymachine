
```python
"""Independent implementation of the Screen revised 2026-10-27 18:33 UTC."""

import numpy as np
from scipy.stats import norm


def dsr(returns, n_trials) -> float:
    """Return the per-4h-period deflated Sharpe score, not a pass/fail flag."""
    if (
        isinstance(n_trials, (bool, np.bool_))
        or not isinstance(n_trials, (int, np.integer))
        or n_trials < 1
    ):
        raise ValueError("n_trials must be an integer >= 1")
    n_trials = int(n_trials)

    if np.iscomplexobj(returns):
        raise ValueError("returns must be real")
    r = np.asarray(returns, dtype=np.float64)
    if r.ndim != 1:
        raise ValueError("returns must be one-dimensional")
    if not np.all(np.isfinite(r)):
        # Invalid observations are errors, not observations to silently drop.
        raise ValueError("returns must contain only finite values")

    t = r.size
    if t < 2:
        # Unspecified boundary: insufficient data for sample variance or T-1.
        # Conservatively return 0, so an undefined score cannot pass the Screen.
        return 0.0

    if np.all(r == r[0]):
        # Unspecified boundary: constant returns have undefined Sharpe/moments.
        # Return 0 even for a positive constant; do not manufacture certainty.
        return 0.0

    # Positive rescaling cancels from Sharpe and standardized central moments.
    # Scale twice to avoid overflow/underflow in powers of raw returns.
    y = r / np.max(np.abs(r))
    mean = np.mean(y)
    centered = y - mean
    spread = np.max(np.abs(centered))
    if spread == 0.0:
        return 0.0

    u = centered / spread
    m2 = np.mean(u * u)
    m3 = np.mean(u * u * u)
    m4 = np.mean((u * u) ** 2)

    # The text does not specify ddof. Choose the usual sample-SD Sharpe
    # (ddof=1), with zero benchmark return and no annualization.
    sharpe = (mean / spread) / np.sqrt(m2 * (t / (t - 1)))

    # Use empirical central moments (divisor T), without bias corrections.
    # This matches the wording's distributional moments and Pearson inequality.
    skew = m3 / (m2 ** 1.5)
    kurtosis = m4 / (m2 * m2)  # Ordinary kurtosis, not excess.

    skew_term = skew * sharpe
    kurtosis_term = (kurtosis - 1.0) * sharpe * sharpe / 4.0
    variance_term = 1.0 - skew_term + kurtosis_term
    degeneracy_limit = 1e-12 * (
        1.0 + abs(skew_term) + kurtosis_term
    )

    # Apply the revised rule before dividing, irrespective of the numerator.
    if variance_term <= degeneracy_limit:
        return 0.0

    root_t_minus_one = np.sqrt(t - 1)
    if n_trials == 1:
        s0 = 0.0
    else:
        # isf(p) = Phi^{-1}(1-p), avoiding cancellation in 1-p.
        q = 1.0 / n_trials
        gamma = np.euler_gamma
        z_n = (
            (1.0 - gamma) * norm.isf(q)
            + gamma * norm.isf(q * np.exp(-1.0))
        )
        s0 = z_n / root_t_minus_one

    statistic = (
        (sharpe - s0) * root_t_minus_one / np.sqrt(variance_term)
    )
    return float(norm.cdf(statistic))
```

Chosen conventions:
- Sharpe uses sample standard deviation (`ddof=1`), zero benchmark return, and no annualization.
- Skewness and ordinary kurtosis use uncorrected empirical central moments with divisor `T`.
- `T < 2` and exactly constant series return `0`; nonconstant two-observation series use the formula.
- Invalid arguments and non-finite observations raise `ValueError`; observations, including zeros, are never dropped.
