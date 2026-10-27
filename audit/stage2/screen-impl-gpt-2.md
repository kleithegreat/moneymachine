
```python
"""Independent DSR screen implementing the 2026-10-27 18:43 UTC revision."""

import numpy as np
from scipy.special import ndtr, ndtri_exp


def dsr(returns, n_trials) -> float:
    """Return the DSR score, not the Boolean DSR >= 0.95 screen decision."""
    # Convention: reject invalid inputs rather than omit observations or
    # manufacture a score. Accept Python/NumPy integers, but not booleans.
    if isinstance(n_trials, (bool, np.bool_)) or not isinstance(
        n_trials, (int, np.integer)
    ):
        raise ValueError("n_trials must be an integer")
    n = int(n_trials)
    if n < 0:
        raise ValueError("n_trials must be nonnegative")

    if np.iscomplexobj(returns):
        raise ValueError("returns must be real")
    # Convention: use binary64 arithmetic.
    r = np.asarray(returns, dtype=np.float64)
    if r.ndim != 1:
        raise ValueError("returns must be one-dimensional")
    if not np.all(np.isfinite(r)):
        raise ValueError("returns must contain only finite values")

    t = r.size
    # Convention: represent 'N = 0 screens nothing' by the failing score 0.
    if n == 0 or t < 3:
        return 0.0

    # Test exact constancy explicitly: a rounded mean can otherwise produce
    # a spurious nonzero standard deviation for a constant floating series.
    if np.all(r == r[0]):
        return 0.0

    # Convention: numerical failures raise rather than silently fail/pass.
    with np.errstate(over="raise", divide="raise", invalid="raise", under="ignore"):
        # Positive rescaling leaves Sharpe and standardized moments unchanged
        # mathematically, while avoiding overflow in raw return powers.
        x = r / np.max(np.abs(r))
        mean = np.mean(x)
        centered = x - mean
        sample_sd = np.std(x, ddof=1)
        if sample_sd == 0.0:
            return 0.0

        sharpe = mean / sample_sd

        # Standardizing by sqrt(m2) computes precisely the specified
        # divisor-T central-moment ratios, without bias corrections.
        m2 = np.mean(centered * centered)
        u = centered / np.sqrt(m2)
        u2 = u * u
        skew = np.mean(u2 * u)
        kurtosis = np.mean(u2 * u2)  # Ordinary, not excess, kurtosis.

        skew_term = skew * sharpe
        kurtosis_term = (kurtosis - 1.0) * sharpe * sharpe / 4.0
        variance = 1.0 - skew_term + kurtosis_term
        tolerance = 1e-12 * (
            1.0 + np.abs(skew_term) + kurtosis_term
        )

        if not np.all(np.isfinite(
            [sharpe, skew, kurtosis, variance, tolerance]
        )):
            raise FloatingPointError("non-finite DSR intermediate")

        if variance <= tolerance:
            return 0.0

        root_t_minus_one = np.sqrt(t - 1.0)
        if n == 1:
            s0 = 0.0
        else:
            # Evaluate the specified normal quantiles through log tails:
            # Phi^-1(1-p) = -ndtri_exp(log(p)).
            # Taking the log from leading integer bits also supports N too
            # large to convert directly to a finite binary64 number.
            shift = max(0, n.bit_length() - 53)
            log_n = np.log(float(n >> shift)) + shift * np.log(2.0)
            gamma = np.euler_gamma
            z_n = (
                (1.0 - gamma) * (-ndtri_exp(-log_n))
                + gamma * (-ndtri_exp(-log_n - 1.0))
            )
            s0 = z_n / root_t_minus_one

        statistic = (
            (sharpe - s0) * root_t_minus_one / np.sqrt(variance)
        )
        if not np.isfinite(statistic):
            raise FloatingPointError("non-finite DSR statistic")
        return float(ndtr(statistic))
```

Conventions not fixed by the specification:
- Invalid inputs raise `ValueError`; non-finite observations are never dropped.
- `N = 0` returns `0.0`, representing “screens nothing.”
- Computation uses binary64, positive rescaling, and stable log-tail quantiles.
- Numerical failures raise `FloatingPointError` rather than produce a screening score.
