"""Locked null suite v3.

All randomness comes from the numpy.random.Generator supplied by the caller.
Sequential generators are vectorized across series. Their outputs may be
non-C-contiguous; every output has dtype float64 and shape (m, n).
"""

import numpy as np


SUITE_ID = "holdout-calibration-locked-v3"
LENGTHS = (540, 546, 1080)

_SQRT3 = np.sqrt(3.0)

# For T ~ t_4 conditioned on |T| <= 8:
#     E[T^2 | |T| <= 8] = 64 / 35.
_T4_TRUNC_SD = np.sqrt(64.0 / 35.0)

# E[min(0.01 * P, 1)] for Pareto(minimum=1, tail index=1.5).
_LEFT_TAIL_CENTER = 0.028


def _standardized_truncated_t4(rng, size):
    """Draw t_4 conditioned on |T| <= 8, then standardize its variance."""
    z = rng.standard_t(4.0, size=size)
    bad = np.abs(z) > 8.0
    while np.any(bad):
        z[bad] = rng.standard_t(4.0, size=int(np.count_nonzero(bad)))
        bad = np.abs(z) > 8.0
    z /= _T4_TRUNC_SD
    return z


def _truncated_standard_normal(rng, size):
    """Draw a standard normal conditioned on absolute value at most 6."""
    z = rng.standard_normal(size=size)
    bad = np.abs(z) > 6.0
    while np.any(bad):
        z[bad] = rng.standard_normal(size=int(np.count_nonzero(bad)))
        bad = np.abs(z) > 6.0
    return z


def peso(rng, m, n):
    """Independent rare losses with exactly compensating positive carry."""
    q = 0.002
    a = 0.9 * q / (1.0 - q)
    out = np.full((m, n), a, dtype=np.float64)
    out[rng.random((m, n)) < q] = -0.9
    return out


def peso_noisy(rng, m, n):
    """Independent rare losses; non-loss returns have uniform noise."""
    q = 0.005
    a = 0.5 * q / (1.0 - q)
    out = rng.uniform(-_SQRT3, _SQRT3, size=(m, n))
    out *= 0.01
    out += a
    out[rng.random((m, n)) < q] = -0.5
    return out


def ruin(rng, m, n):
    """Fair positive carry until an absorbing total loss."""
    q = 0.002
    a = q / (1.0 - q)
    alive = np.ones(m, dtype=bool)
    out = np.empty((n, m), dtype=np.float64)

    for t in range(n):
        crash = alive & (rng.random(m) < q)
        out[t] = np.where(alive, a, 0.0)
        out[t, crash] = -1.0
        alive[crash] = False

    return out.T


def left_tail(rng, m, n):
    """Centered capped Pareto losses, with an analytic centering constant."""
    # V lies in (0, 1], including when rng.random returns zero.
    out = rng.random((m, n))
    np.subtract(1.0, out, out=out)
    np.power(out, -2.0 / 3.0, out=out)
    out *= 0.01
    np.minimum(out, 1.0, out=out)
    np.subtract(_LEFT_TAIL_CENTER, out, out=out)
    return out


def right_tail(rng, m, n):
    """Centered mean-one lognormal returns."""
    log_sd = 1.5
    out = rng.lognormal(
        mean=-0.5 * log_sd * log_sd,
        sigma=log_sd,
        size=(m, n),
    )
    out -= 1.0
    out *= 0.02
    return out


def garch_t(rng, m, n):
    """Capped GARCH volatility with standardized truncated-t innovations."""
    alpha = 0.08
    beta = 0.9
    omega = 0.0004 * (1.0 - alpha - beta)

    variance = np.full(m, 0.0004, dtype=np.float64)
    out = np.empty((n, m), dtype=np.float64)

    for t in range(500 + n):
        z = _standardized_truncated_t4(rng, m)
        r = np.sqrt(variance) * z

        if t >= 500:
            out[t - 500] = r

        variance = omega + alpha * np.square(r) + beta * variance
        np.minimum(variance, 0.1**2, out=variance)

    return out.T


def sparse_bursts(rng, m, n):
    """Stationary sparse activity with standardized truncated-t bursts."""
    p_flat_to_active = 1.0 / 36.0
    p_active_to_flat = 1.0 / 4.0
    p_active = p_flat_to_active / (
        p_flat_to_active + p_active_to_flat
    )

    active = rng.random(m) < p_active
    out = np.empty((n, m), dtype=np.float64)

    for t in range(n):
        z = _standardized_truncated_t4(rng, m)
        out[t] = np.where(active, 0.03 * z, 0.0)

        if t + 1 < n:
            p_switch = np.where(
                active, p_active_to_flat, p_flat_to_active
            )
            active ^= rng.random(m) < p_switch

    return out.T


def doubling(rng, m, n):
    """Fair signs with exposure doubling after losses, capped at eight."""
    exposure = np.ones(m, dtype=np.float64)
    out = np.empty((n, m), dtype=np.float64)

    for t in range(n):
        positive = rng.random(m) < 0.5
        r = np.where(positive, 0.01 * exposure, -0.01 * exposure)
        out[t] = r
        exposure = np.where(
            positive,
            1.0,
            np.minimum(8.0, 2.0 * exposure),
        )

    return out.T


def vol_regime(rng, m, n):
    """Stationary volatility regimes with unrescaled truncated normals."""
    p_calm_to_stressed = 1.0 / 50.0
    p_stressed_to_calm = 1.0 / 10.0
    p_stressed = p_calm_to_stressed / (
        p_calm_to_stressed + p_stressed_to_calm
    )

    stressed = rng.random(m) < p_stressed
    out = np.empty((n, m), dtype=np.float64)

    for t in range(n):
        z = _truncated_standard_normal(rng, m)
        sigma = np.where(stressed, 0.04, 0.005)
        out[t] = sigma * z

        if t + 1 < n:
            p_switch = np.where(
                stressed, p_stressed_to_calm, p_calm_to_stressed
            )
            stressed ^= rng.random(m) < p_switch

    return out.T


def gpt_a(rng, m, n):
    """Deadline-dependent carry with a single absorbing crash.

    Index steps by k = 0, ..., n-1. While alive, the crash probability is

        q_k = p / (n - p*k),  p = 0.9.

    A crash returns -1 and ends trading. Otherwise the return is uniform
    on [a_k/2, 3*a_k/2], where

        a_k = p / (n - p*(k+1)) = q_k / (1-q_k).

    Survival through k steps has probability 1-p*k/n. Consequently,
    each possible crash step has unconditional probability p/n, and
    exactly 10% of paths survive the entire horizon in the specified
    distribution.

    Surviving paths show exclusively positive, gradually increasing,
    lightly noisy returns. Compensation is concentrated in absorbing
    losses spread uniformly over the horizon. This challenges methods
    that interpret smooth observed carry as evidence of a positive mean.
    Every alive step is nevertheless conditionally fair, even given
    the survival state and all previous observations.
    """
    p = 0.9
    alive = np.ones(m, dtype=bool)
    out = np.empty((n, m), dtype=np.float64)

    for k in range(n):
        denominator = n - p * k
        q = p / denominator
        a = p / (n - p * (k + 1))

        crash = alive & (rng.random(m) < q)
        carry = a * (0.5 + rng.random(m))

        out[k] = np.where(alive, carry, 0.0)
        out[k, crash] = -1.0
        alive[crash] = False

    return out.T


def gpt_b(rng, m, n):
    """Predictable volatility growth and self-normalized optional stopping.

    While trading, returns are independent fair signs times a
    deterministic scale growing geometrically from 0.001 to 0.05.
    Let S be cumulative return and Q cumulative squared return. Trading
    stops permanently after the first observation satisfying

        S >= 2.75 * sqrt(Q).

    Subsequent returns are zero. Growing volatility makes later
    fluctuations progressively outweigh earlier observations, while
    repeated monitoring can lock in an unusually favorable apparent
    mean. This challenges fixed-horizon Gaussian or self-normalized
    approximations that ignore the path-dependent stopping rule.

    Before every step, both the scale and whether trading continues are
    determined by the past. The next sign is independent and fair, so
    the conditional mean remains exactly zero.
    """
    active = np.ones(m, dtype=bool)
    cumulative_return = np.zeros(m, dtype=np.float64)
    cumulative_square = np.zeros(m, dtype=np.float64)
    out = np.empty((n, m), dtype=np.float64)

    log_scale_ratio = np.log(50.0)
    horizon = max(n - 1, 1)

    for t in range(n):
        scale = 0.001 * np.exp(log_scale_ratio * t / horizon)
        positive = rng.random(m) < 0.5
        r = np.where(
            active,
            np.where(positive, scale, -scale),
            0.0,
        )
        out[t] = r

        cumulative_return += r
        cumulative_square += np.square(r)

        crossed = (
            (cumulative_square > 0.0)
            & (
                cumulative_return
                >= 2.75 * np.sqrt(cumulative_square)
            )
        )
        active &= ~crossed

    return out.T


GENERATORS = {
    "peso": peso,
    "peso_noisy": peso_noisy,
    "ruin": ruin,
    "left_tail": left_tail,
    "right_tail": right_tail,
    "garch_t": garch_t,
    "sparse_bursts": sparse_bursts,
    "doubling": doubling,
    "vol_regime": vol_regime,
    "gpt_a": gpt_a,
    "gpt_b": gpt_b,
}


CHECKS = {
    "peso": (
        "Independent draws have mean -0.9*q + (1-q)*"
        "(0.9*q/(1-q)) = 0. Minimum is -0.9."
    ),
    "peso_noisy": (
        "Uniform noise has mean zero, so the mean is "
        "-0.5*q + (1-q)*(0.5*q/(1-q)) = 0. "
        "The non-crash minimum exceeds -0.5; overall minimum is -0.5."
    ),
    "ruin": (
        "While alive, conditional mean is -q + "
        "(1-q)*(q/(1-q)) = 0; after death returns are zero. "
        "Minimum is -1."
    ),
    "left_tail": (
        "For Y=min(s*P,1), E[Y]=(alpha*s-s**alpha)/(alpha-1)"
        "=0.028 at s=0.01 and alpha=1.5. Thus E[0.028-Y]=0. "
        "Minimum is 0.028-1=-0.972."
    ),
    "right_tail": (
        "X=exp(-1.5**2/2 + 1.5*Z) has mean one, so "
        "E[0.02*(X-1)]=0. The lower bound is -0.02."
    ),
    "garch_t": (
        "Symmetrically truncated t_4 innovations have mean zero and "
        "exact variance 64/35 before standardization. Volatility is "
        "predictable and at most 0.1. Standardized innovations are "
        "bounded by sqrt(35), so returns are at least -0.1*sqrt(35)>-1."
    ),
    "sparse_bursts": (
        "The stationary active probability is 1/10. Conditional on "
        "either state, the independent innovation has mean zero. "
        "Returns are at least -0.03*sqrt(35)>-1."
    ),
    "doubling": (
        "Exposure is determined by past signs and the next sign is "
        "independent and fair. Conditional mean is zero. "
        "Exposure is at most 8, so returns are at least -0.08."
    ),
    "vol_regime": (
        "The stationary stressed probability is 1/6. Conditional on "
        "either state, the independent symmetrically truncated normal "
        "has mean zero. Returns are at least -0.04*6=-0.24."
    ),
    "gpt_a": (
        "At alive step k, q=p/(n-p*k) and "
        "a=p/(n-p*(k+1))=q/(1-q). The independent uniform carry "
        "multiplier has mean one, so conditional mean is "
        "-q+(1-q)*a=0. After death returns are zero. Minimum is -1."
    ),
    "gpt_b": (
        "Trading status and scale are determined before the next "
        "independent fair sign. Conditional mean is therefore zero, "
        "including after stopping. Scale is at most 0.05, so returns "
        "are at least -0.05."
    ),
}
