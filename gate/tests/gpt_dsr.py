# Revised by GPT for the 2026-10-19 degenerate-variance revision of the stage 2 gate spec.
# Independent DSR for C2.3, written by GPT 6.1 Sol from whitepaper.tex and the stage 2 gate spec alone, tools denied.
import numpy as np
from scipy.stats import norm


def dsr(returns, n_trials, sharpe_sd) -> float:
    """Compute the deflated Sharpe probability in per-period units.

    Sharpe uses sample standard deviation (ddof=1), with zero risk-free
    return. Skewness and ordinary kurtosis use empirical central moments
    without finite-sample bias corrections. No annualization is applied.
    """
    # Require a positive integer trial count; booleans are not counts.
    if isinstance(n_trials, (bool, np.bool_)) or not isinstance(
        n_trials, (int, np.integer)
    ):
        raise ValueError("n_trials must be a positive integer")
    if n_trials < 1:
        raise ValueError("n_trials must be a positive integer")
    # Reject counts outside the finite float64 range used by this module.
    try:
        n = float(n_trials)
    except (OverflowError, ValueError) as exc:
        raise ValueError("n_trials must fit in a finite float64") from exc
    if not np.isfinite(n):
        raise ValueError("n_trials must fit in a finite float64")

    # Reject non-scalar, complex, negative, or non-finite Sharpe dispersion.
    sd_input = np.asarray(sharpe_sd)
    if sd_input.ndim != 0 or np.iscomplexobj(sd_input):
        raise ValueError("sharpe_sd must be a finite non-negative real scalar")
    try:
        sigma_s = float(sd_input)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError(
            "sharpe_sd must be a finite non-negative real scalar"
        ) from exc
    if not np.isfinite(sigma_s) or sigma_s < 0.0:
        raise ValueError("sharpe_sd must be a finite non-negative real scalar")

    # Reject malformed/non-finite returns rather than dropping observations.
    r = np.asarray(returns)
    if r.ndim != 1 or np.iscomplexobj(r):
        raise ValueError("returns must be a one-dimensional real array")
    try:
        r = np.asarray(r, dtype=np.float64)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("returns must contain finite real values") from exc
    if not np.all(np.isfinite(r)):
        raise ValueError("returns must contain finite real values")

    # Insufficient observations and constant returns fail the screen.
    t = r.size
    if t < 3 or np.all(r == r[0]):
        return 0.0

    # Positive rescaling preserves all statistics and avoids raw-moment overflow.
    x = r / np.max(np.abs(r))
    mean = np.mean(x)
    centered = x - mean
    m2 = np.mean(centered**2)
    if not np.isfinite(m2) or m2 <= 0.0:
        return 0.0

    sharpe = mean / np.sqrt(m2 * (t / (t - 1.0)))
    standardized = centered / np.sqrt(m2)
    skewness = np.mean(standardized**3)
    kurtosis = np.mean(standardized**4)  # Ordinary, not excess kurtosis.

    # One trial has no selection penalty: S0=0. Zero dispersion also gives S0=0.
    if n_trials == 1 or sigma_s == 0.0:
        s0 = 0.0
    else:
        # isf(p) equals ppf(1-p), avoiding cancellation for large trial counts.
        inverse_n = 1.0 / n
        s0 = sigma_s * (
            (1.0 - np.euler_gamma) * norm.isf(inverse_n)
            + np.euler_gamma * norm.isf(inverse_n / np.e)
        )

    variance_term = (
        1.0 - skewness * sharpe + (kurtosis - 1.0) * sharpe**2 / 4.0
    )
    variance_tolerance = 1e-12 * (
        1.0 + abs(skewness * sharpe) + (kurtosis - 1.0) * sharpe**2 / 4.0
    )
    # The gate requires zero for a variance term at or below the relative
    # tolerance; numerical failures also fail closed rather than producing a promotable result.
    if not np.isfinite(variance_term) or variance_term <= variance_tolerance:
        return 0.0
    if not np.isfinite(sharpe) or not np.isfinite(s0):
        return 0.0

    z = (sharpe - s0) * np.sqrt(t - 1.0) / np.sqrt(variance_term)
    if np.isnan(z):
        return 0.0
    # Infinite z uses the normal CDF's limiting probabilities, 0 or 1.
    return float(norm.cdf(z))