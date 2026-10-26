"""Synthetic markets N1, N2, N3 and planted signals (gate/NULLS.md), in the kernel's store format:
<root>/{store (with its policy.json), holdout, venue}."""

import functools
import hashlib
import json
from pathlib import Path

import numpy as np
import polars as pl

from ingest.policy import BAR, DAY, HOLDOUT_START, HOUR, POLICY, W_START
from ingest.store import Store, write_split

CAP = 0.04
EPS_MAX = 0.5
SIGMA_MAX = 0.0625


NULLS = Path(__file__).resolve().parent / "nulls.json"
FLAT_COST = {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}


def null_params():
    return json.loads(NULLS.read_text())


def seed(text):
    return int.from_bytes(hashlib.sha256(text.encode()).digest()[:8], "little")


@functools.lru_cache(maxsize=8)
def truncated_t_sd(nu, bound):
    """Standard deviation of Student-t(nu) conditional on |x| <= bound."""
    from scipy import stats

    return float(np.sqrt(stats.t(nu).expect(lambda x: x * x, lb=-bound, ub=bound, conditional=True)))


def truncated_t(rng, nu, shape, bound=8.0):
    """Student-t(nu) truncated symmetrically at +-bound by resampling, then scaled to unit variance."""
    x = rng.standard_t(nu, shape)
    bad = np.abs(x) > bound
    while bad.any():
        x[bad] = rng.standard_t(nu, bad.sum())
        bad = np.abs(x) > bound
    return x / truncated_t_sd(nu, bound)


def truncated_normal(rng, shape, bound=8.0):
    x = rng.standard_normal(shape)
    bad = np.abs(x) > bound
    while bad.any():
        x[bad] = rng.standard_normal(bad.sum())
        bad = np.abs(x) > bound
    return x


@functools.lru_cache(maxsize=4)
def store_funding(store, version, coins):
    """Hourly funding and premium of `coins` over the search part of a store: (T x K, T x K)."""
    df = Store(store).as_of("funding", HOLDOUT_START, version).to_pandas()
    grid = np.arange(W_START, HOLDOUT_START, HOUR)
    piv = {k: df.pivot(index="eventTime", columns="coin", values=k).reindex(grid)[list(coins)].to_numpy()
           for k in ("fundingRate", "premium")}
    return piv["fundingRate"], piv["premium"]


def store_events(store, version, coins, block_hours=24):
    """event_paths spec from the real forum counts of `coins` (U's order) over the search part, on the
    hours every mapped coin is covered."""
    piv = Store(store).as_of("events_forum", HOLDOUT_START, version).to_pandas().pivot(
        index="eventTime", columns="coin", values="count")
    have = [c for c in coins if c in piv.columns]
    return {"arrays": piv[have].dropna().to_numpy(), "coins": [coins.index(c) for c in have], "block_hours": block_hours}


def funding_source(spec):
    """(F, P) source arrays and, per synthetic coin, its source column (None: independent blocks)."""
    if "arrays" in spec:
        F, P = spec["arrays"]
    else:
        long = tuple(c for c in spec["coins"] if c not in spec["short"])
        F, P = store_funding(spec["store"], spec["version"], long)
    cols, k = [], 0
    for c in spec["coins"]:
        cols.append(None if c in spec.get("short", ()) else k)
        k += c not in spec.get("short", ())
    return np.nan_to_num(F, nan=1.25e-5), np.nan_to_num(P), cols


def block_indices(rng, n, length, mean_block):
    idx = np.empty(n, int)
    i = 0
    while i < n:
        start, size = rng.integers(length), rng.geometric(1 / mean_block)
        take = min(size, n - i)
        idx[i:i + take] = (start + np.arange(take)) % length
        i += take
    return idx


def funding_paths(rng, spec, coins, hours):
    """Stationary block bootstrap of real funding and premium (NULLS.md); zeros when spec is None."""
    if spec is None:
        return np.zeros((hours, coins)), np.zeros((hours, coins))
    F, P, cols = funding_source(spec)
    T, K = F.shape
    joint = block_indices(rng, hours, T, spec["block_hours"])
    f, p = np.empty((hours, coins)), np.empty((hours, coins))
    for i, col in enumerate(cols):
        if col is None:
            idx = block_indices(rng, hours, T * K, spec["block_hours"])
            f[:, i], p[:, i] = F.T.reshape(-1)[idx], P.T.reshape(-1)[idx]
        else:
            f[:, i], p[:, i] = F[joint, col], P[joint, col]
    return np.clip(f, -CAP, CAP), p


def event_paths(rng, spec, coins, hours):
    """Hourly event counts per coin, block-bootstrapped from real counts independently of epsilon
    (stage 5): {"arrays": (T x K counts), "coins": [synthetic coin index per column], "block_hours"}.
    Synthetic coins without a column get no rows (the input is undefined there)."""
    counts, cols = np.asarray(spec["arrays"], float), spec["coins"]
    idx = block_indices(rng, hours, counts.shape[0], spec["block_hours"])
    out = np.full((hours, coins), np.nan)
    for k, c in enumerate(cols):
        out[:, c] = counts[idx, k]
    return out


def generate(model, params, market_id, days, planted=(), beta=0.0, events=None):
    """Arrays for one market: per-bar o, c, high, low, volume and hourly funding, premium."""
    rng = np.random.default_rng(seed(market_id))
    coins = 12
    n = days * 6
    hours = n * 4 + 1
    f, premium = funding_paths(rng, None if model == "N1" else params["funding"], coins, hours)
    eps = np.zeros((n, coins))
    sig = np.zeros((n, coins))
    if model == "N1":
        sig[:] = 0.02
        x = truncated_normal(rng, (n, coins))
    elif model == "N2":
        g = params["garch"]
        omega, alpha, beta_g = (np.asarray(g[k], float) for k in ("omega", "alpha", "beta"))
        lam = params["lambda"]
        x = lam * truncated_t(rng, 5, (n, 1)) + np.sqrt(1 - lam**2) * truncated_t(rng, 5, (n, coins))
    elif model == "N3":
        r = params["regime"]
        P = np.asarray(r["P"], float)
        m = np.asarray(r["m"], float)
        rho = np.asarray(r["rho"], float)
        state = np.zeros(n, int)
        u = rng.random(n)
        for k in range(1, n):
            state[k] = state[k - 1] if u[k] < P[state[k - 1], state[k - 1]] else 1 - state[k - 1]
        sig[:] = np.minimum(np.asarray(r["sigma"], float)[None, :] * m[state][:, None], SIGMA_MAX)
        zm, zi = truncated_t(rng, 5, (n, 1)), truncated_t(rng, 5, (n, coins))
        rs = rho[state][:, None]
        jumps = (rng.random((n, coins)) < r["p_jump"]) * np.clip(rng.laplace(0, r["k_jump"], (n, coins)), -0.2, 0.2)
        x = np.sqrt(rs) * zm + np.sqrt(1 - rs) * zi + jumps / sig
    else:
        raise ValueError(model)
    planted_mask = np.zeros(coins, bool)
    planted_mask[list(planted)] = True
    var = np.minimum(omega / (1 - alpha - beta_g), SIGMA_MAX**2) if model == "N2" else None
    for k in range(n):
        if model == "N2":
            sig[k] = np.sqrt(var)
        signal = -np.clip((f[4 * k - 4] - 1.25e-5) / 1e-4, -1, 1) if k else np.zeros(coins)
        eps[k] = np.clip(sig[k] * x[k] + planted_mask * beta * signal, -EPS_MAX, EPS_MAX)
        if model == "N2":
            var = np.minimum(omega + alpha * eps[k] ** 2 + beta_g * var, SIGMA_MAX**2)
    f1, f2, f3, f4 = (f[4 * np.arange(n) + i] for i in (1, 2, 3, 4))
    o = np.empty((n, coins))
    c = np.empty((n, coins))
    px = np.full(coins, 100.0)
    for k in range(n):
        o[k] = px
        c[k] = px * (1 + f1[k] + f2[k] + f3[k] + eps[k]) / (1 - f4[k])
        px = c[k]
    w = np.abs(rng.standard_normal((2, n, coins))) * sig / 2
    high = np.maximum(o, c) * (1 + w[0])
    low = np.minimum(o, c) * (1 - w[1])
    volume = rng.lognormal(10, 0.5, (n, coins))
    forum = event_paths(np.random.default_rng(seed(market_id + "/events")), events, coins, hours) if events else None
    return {"forum_posts": forum, "open": o, "close": c, "high": high, "low": low, "volume": volume, "funding": f, "premium": premium,
            "eps": eps, "sigma": sig}


def write(root, arrays, holdout_days, cost_cells, taker_fee=0.00045, fetched_at=1):
    """Write a generated market; rows from the last `holdout_days` go to <root>/holdout."""
    root = Path(root)
    n, coins = arrays["open"].shape
    hours = arrays["funding"].shape[0]
    names = [f"S{i}" for i in range(coins)]
    k = np.arange(n)
    bars = pl.DataFrame({
        "coin": np.repeat(names, n),
        "eventTime": np.tile((k + 1) * BAR, coins),
        "openTime": np.tile(k * BAR, coins),
        **{col: arrays[col].T.reshape(-1) for col in ("open", "high", "low", "close", "volume")},
        "trades": np.full(n * coins, 100),
    })
    h = np.arange(hours)
    funding = pl.DataFrame({
        "coin": np.repeat(names, hours),
        "eventTime": np.tile(h * HOUR, coins),
        "fundingRate": arrays["funding"].T.reshape(-1),
        "premium": arrays["premium"].T.reshape(-1),
        "reportedTime": np.tile(h * HOUR, coins),
    })
    w_end = n * BAR + HOUR
    holdout_start = n * BAR - holdout_days * DAY if holdout_days else w_end
    search, holdout = Store(root / "store", event_before=holdout_start), Store(root / "holdout", policy_root=root / "store")
    write_split(search, holdout, "funding", funding, fetched_at, "synthetic", holdout_start)
    write_split(search, holdout, "bars_4h", bars, fetched_at, "synthetic", holdout_start)
    if arrays.get("forum_posts") is not None:
        ev = arrays["forum_posts"]
        rows = [(names[c], int(t * HOUR), float(ev[t, c])) for c in range(coins) for t in range(hours) if not np.isnan(ev[t, c])]
        events = pl.DataFrame(rows, schema={"coin": pl.Utf8, "eventTime": pl.Int64, "count": pl.Float64}, orient="row")
        write_split(search, holdout, "events_forum", events, fetched_at, "synthetic", holdout_start)
    write_venue(root, {c: (3, 10, False) for c in names}, cost_cells, taker_fee)
    (root / "store" / "policy.json").write_text(json.dumps(POLICY | {"w_start": 0, "holdout_start": holdout_start, "w_end": w_end}))
    (root / "version").write_text(f"{fetched_at}\n")
    return root


def write_venue(root, coins, cost_cells, taker_fee=0.00045):
    """<root>/venue: rules for {coin: (szDecimals, maxLeverage, delisted)} and every coin at `cost_cells`."""
    venue = Path(root) / "venue"
    venue.mkdir(parents=True, exist_ok=True)
    rules = {"rules": {"taker_fee": {"value": taker_fee}, "min_order_notional_usd": {"value": 10.0}},
             "coins": {c: {"szDecimals": sz, "maxLeverage": lev, "marginTiers": [{"lowerBound": "0.0", "maxLeverage": lev}],
                           "delisted": delisted} for c, (sz, lev, delisted) in coins.items()}}
    (venue / "rules.json").write_text(json.dumps(rules))
    (venue / "execution.json").write_text(json.dumps({"cost_bps_ex_fee": {c: cost_cells for c in coins}}))


def write_market(root, market_id="test", days=60, holdout_days=0, model="N1", params=None,
                 cost_cells=None, planted=(), beta=0.0):
    return write(root, generate(model, params, market_id, days, planted, beta), holdout_days, cost_cells or FLAT_COST)
