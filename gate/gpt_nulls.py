# Independent N2/N3 null generators for C2.2, written by GPT 6.1 Sol from gate/NULLS.md and gate/nulls.json alone, tools denied.
import numpy as np


__all__ = ["generate"]


# Exact conditional variance of T ~ Student-t(5), given |T| <= 8.
# With T = sqrt(5) * tan(theta), its density is proportional to cos(theta)^4.
_T5_THETA = np.arctan(8.0 / np.sqrt(5.0))
_T5_TRUNC_VAR = (
    5.0
    * (_T5_THETA / 8.0 - np.sin(4.0 * _T5_THETA) / 32.0)
    / (
        3.0 * _T5_THETA / 8.0
        + np.sin(2.0 * _T5_THETA) / 4.0
        + np.sin(4.0 * _T5_THETA) / 32.0
    )
)
_T5_TRUNC_SD = np.sqrt(_T5_TRUNC_VAR)


def _student_t(rng):
    """Rejection-truncate a Student-t(5) at +/-8, then standardize."""
    while True:
        value = rng.standard_t(5)
        if abs(value) <= 8.0:
            return value / _T5_TRUNC_SD


def _truncated_laplace(rng, scale):
    """Sample Laplace(0, scale) conditional on absolute value <= 0.2."""
    if scale == 0.0:
        return 0.0
    while True:
        value = rng.laplace(0.0, scale)
        if abs(value) <= 0.2:
            return value


def _vector(value, name, length):
    result = np.asarray(value, dtype=np.float64)
    if result.shape != (length,) or not np.all(np.isfinite(result)):
        raise ValueError(
            "{} must be a finite vector of length {}".format(name, length)
        )
    return result


def _scalar(value, name):
    result = float(value)
    if not np.isfinite(result):
        raise ValueError("{} must be finite".format(name))
    return result


def _integer(value, name):
    if isinstance(value, (bool, np.bool_)) or not isinstance(
        value, (int, np.integer)
    ):
        raise ValueError("{} must be an integer".format(name))
    return int(value)


def generate(
    model, params, funding_source, premium_source, short_slots, seed, days
):
    """Generate the N2 or N3 null market using only NumPy.

    Prices start at 100, and each later open equals the preceding close.
    Non-short slots use source columns in synthetic-slot order. At each
    independent block start, a short slot chooses a source column uniformly
    from the supplied long-history columns. Funding and premium always use
    the same sampled row and column.

    Bootstrap paths are circular, with geometric block lengths. N3 starts
    in its stationary regime distribution; if both regimes are absorbing,
    the initial distribution is uniform.

    Random draws follow bar order, then synthetic-coin order, with shared
    regime, factor, and bootstrap draws preceding that bar's coin draws.
    """
    if model not in ("N2", "N3"):
        raise ValueError("model must be 'N2' or 'N3'")

    days = _integer(days, "days")
    seed = _integer(seed, "seed")
    if days < 0:
        raise ValueError("days must be nonnegative")

    slots = [_integer(slot, "short slot") for slot in short_slots]
    if len(set(slots)) != len(slots) or any(
        slot < 0 or slot >= 12 for slot in slots
    ):
        raise ValueError("short_slots must contain unique indices in 0..11")

    is_short = np.zeros(12, dtype=bool)
    is_short[slots] = True
    long_slots = np.flatnonzero(~is_short)

    source_f = np.asarray(funding_source, dtype=np.float64)
    source_p = np.asarray(premium_source, dtype=np.float64)
    if (
        source_f.ndim != 2
        or source_p.shape != source_f.shape
        or source_f.shape[0] == 0
        or source_f.shape[1] == 0
    ):
        raise ValueError(
            "funding_source and premium_source must have matching, "
            "nonempty (T, K) shapes"
        )
    if not np.all(np.isfinite(source_f)) or not np.all(np.isfinite(source_p)):
        raise ValueError("source arrays must contain only finite values")

    source_length, source_count = source_f.shape
    if source_count < len(long_slots):
        raise ValueError("not enough source columns for the non-short slots")

    mean_block = _scalar(params["funding"]["block_hours"], "block_hours")
    if mean_block < 1.0:
        raise ValueError("block_hours must be at least 1")
    restart_probability = 1.0 / mean_block

    source_columns = np.full(12, -1, dtype=np.int64)
    source_columns[long_slots] = np.arange(len(long_slots))

    if model == "N2":
        garch = params["garch"]
        omega = _vector(garch["omega"], "omega", 12)
        alpha = _vector(garch["alpha"], "alpha", 12)
        beta = _vector(garch["beta"], "beta", 12)
        if (
            np.any(omega < 0.0)
            or np.any(alpha < 0.0)
            or np.any(beta < 0.0)
            or np.any(alpha + beta >= 1.0)
        ):
            raise ValueError(
                "GARCH requires omega, alpha, beta >= 0 and alpha + beta < 1"
            )

        loading = _scalar(params["lambda"], "lambda")
        if not 0.0 <= loading <= 1.0:
            raise ValueError("lambda must be in [0, 1]")
        idiosyncratic_loading = np.sqrt(1.0 - loading * loading)

        # The supplied omega values already implement variance targeting.
        variance_cap = 0.0625 ** 2
        variance = np.minimum(omega / (1.0 - alpha - beta), variance_cap)
    else:
        regime = params["regime"]
        transition = np.asarray(regime["P"], dtype=np.float64)
        if (
            transition.shape != (2, 2)
            or not np.all(np.isfinite(transition))
            or np.any(transition < 0.0)
            or np.any(transition > 1.0)
            or not np.allclose(
                transition.sum(axis=1), 1.0, rtol=0.0, atol=1e-12
            )
        ):
            raise ValueError("P must be a row-stochastic 2-by-2 matrix")

        multipliers = _vector(regime["m"], "m", 2)
        correlations = _vector(regime["rho"], "rho", 2)
        base_sigma = _vector(regime["sigma"], "sigma", 12)
        jump_probability = _scalar(regime["p_jump"], "p_jump")
        jump_scale = _scalar(regime["k_jump"], "k_jump")

        if np.any(multipliers <= 0.0) or np.any(base_sigma <= 0.0):
            raise ValueError("m and sigma must be positive")
        if np.any(correlations < 0.0) or np.any(correlations > 1.0):
            raise ValueError("rho must be in [0, 1]")
        if not 0.0 <= jump_probability <= 1.0 or jump_scale < 0.0:
            raise ValueError("p_jump must be in [0, 1] and k_jump >= 0")

    n_bars = days * 6
    result = {
        name: np.empty((n_bars, 12), dtype=np.float64)
        for name in ("open", "close", "high", "low", "volume", "eps")
    }
    result["funding"] = np.empty((n_bars * 4 + 1, 12), dtype=np.float64)
    result["premium"] = np.empty((n_bars * 4 + 1, 12), dtype=np.float64)

    rng = np.random.default_rng(seed)
    funding = result["funding"]
    premium = result["premium"]

    # Initialize stationary bootstrap paths at uniformly sampled source rows.
    shared_row = int(rng.integers(source_length))
    short_rows = np.zeros(12, dtype=np.int64)
    short_columns = np.zeros(12, dtype=np.int64)

    for coin in range(12):
        if is_short[coin]:
            row = int(rng.integers(source_length))
            column = int(rng.integers(source_count))
            short_rows[coin] = row
            short_columns[coin] = column
        else:
            row = shared_row
            column = source_columns[coin]

        funding[0, coin] = np.clip(source_f[row, column], -0.04, 0.04)
        premium[0, coin] = source_p[row, column]

    if model == "N3" and n_bars:
        switch_sum = transition[0, 1] + transition[1, 0]
        high_probability = (
            transition[0, 1] / switch_sum if switch_sum > 0.0 else 0.5
        )
        state = int(rng.random() < high_probability)

    previous_close = np.full(12, 100.0, dtype=np.float64)

    for bar in range(n_bars):
        if model == "N2":
            sigma = np.sqrt(variance)
            common_loading = loading
            individual_loading = idiosyncratic_loading
        else:
            if bar:
                state = int(rng.random() >= transition[state, 0])
            sigma = base_sigma * multipliers[state]
            common_loading = np.sqrt(correlations[state])
            individual_loading = np.sqrt(1.0 - correlations[state])

        market_innovation = _student_t(rng)

        # Shared long-history bootstrap path for this bar's four settlements.
        shared_rows = np.empty(4, dtype=np.int64)
        for hour in range(4):
            if rng.random() < restart_probability:
                shared_row = int(rng.integers(source_length))
            else:
                shared_row = (shared_row + 1) % source_length
            shared_rows[hour] = shared_row

        first_hour = 4 * bar + 1
        last_hour = first_hour + 4

        for coin in range(12):
            if is_short[coin]:
                for hour in range(first_hour, last_hour):
                    if rng.random() < restart_probability:
                        short_rows[coin] = rng.integers(source_length)
                        short_columns[coin] = rng.integers(source_count)
                    else:
                        short_rows[coin] = (
                            short_rows[coin] + 1
                        ) % source_length

                    row = short_rows[coin]
                    column = short_columns[coin]
                    funding[hour, coin] = np.clip(
                        source_f[row, column], -0.04, 0.04
                    )
                    premium[hour, coin] = source_p[row, column]
            else:
                column = source_columns[coin]
                funding[first_hour:last_hour, coin] = np.clip(
                    source_f[shared_rows, column], -0.04, 0.04
                )
                premium[first_hour:last_hour, coin] = source_p[
                    shared_rows, column
                ]

            innovation = (
                common_loading * market_innovation
                + individual_loading * _student_t(rng)
            )
            raw_epsilon = sigma[coin] * innovation

            if model == "N3" and rng.random() < jump_probability:
                # sigma * (B * K / sigma) equals B * K in epsilon units.
                raw_epsilon += _truncated_laplace(rng, jump_scale)

            epsilon = np.clip(raw_epsilon, -0.5, 0.5)

            upper_wick = abs(rng.normal(0.0, sigma[coin] / 2.0))
            lower_wick = abs(rng.normal(0.0, sigma[coin] / 2.0))
            volume = rng.lognormal(mean=10.0, sigma=0.5)

            rates = funding[first_hour:last_hour, coin]
            opening = previous_close[coin]
            closing = opening * (
                1.0 + rates[0] + rates[1] + rates[2] + epsilon
            ) / (1.0 - rates[3])

            result["open"][bar, coin] = opening
            result["close"][bar, coin] = closing
            result["high"][bar, coin] = (
                max(opening, closing) * (1.0 + upper_wick)
            )
            result["low"][bar, coin] = (
                min(opening, closing) * (1.0 - lower_wick)
            )
            result["volume"][bar, coin] = volume
            result["eps"][bar, coin] = epsilon
            previous_close[coin] = closing

            if model == "N2":
                variance[coin] = min(
                    omega[coin]
                    + alpha[coin] * epsilon * epsilon
                    + beta[coin] * variance[coin],
                    variance_cap,
                )

    return result