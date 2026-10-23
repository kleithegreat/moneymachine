"""C6.4's deterministic cases: hand-built stores, each read by `mm`'s own loader, and the programs run on them
and on the null markets.

`edge` has four coins over 40 days:
- E0 is a random walk with flat stretches and signed-zero funding.
- E1 has E0's prices (rank ties), its own funding, size decimals 0 and leverage 3.
- E2 is listed late (no rows before day 10). Its first bar has no trade, it has a 3-bar and a 30-hour
  gap, and it has size decimals 1.
- E3 is delisted after day 30.

Version 2 restates some of E0's funding (new values, a late stamp, and knownAt exactly at a tick
and 1 ms after it). Forum counts are bound for E0 and E1, and governance counts nowhere.

`liquidation` and `ruin` have two coins of leverage 2 over 20 days, both dropping 40% (liquidation) or 60%
(bankruptcy at full gross) inside one bar.
"""

import json
from pathlib import Path

import numpy as np
import polars as pl

from gate.markets import FLAT_COST
from ingest.policy import BAR, HOUR, POLICY
from ingest.store import Store


def _walk(rng, n, flat=()):
    r = rng.normal(0, 0.02, n)
    r[list(flat)] = 0.0
    return 100 * np.exp(np.cumsum(r))


def _write(root, bars, funding, coins, delisted=(), events=None, revisions=None):
    root = Path(root)
    end = max(b["eventTime"] for b in bars) + HOUR
    store = Store(root / "store")
    store.write("bars_4h", pl.DataFrame(bars), 1, "edge-markets")
    store.write("funding", pl.DataFrame(funding), 1, "edge-markets")
    if events:
        store.write("events_forum", pl.DataFrame(events), 1, "edge-markets")
    if revisions:
        store.write("funding", pl.DataFrame(revisions), 2, "edge-markets")
    (root / "store" / "policy.json").write_text(json.dumps(POLICY | {"w_start": 0, "holdout_start": end, "w_end": end}))
    venue = root / "venue"
    venue.mkdir(parents=True, exist_ok=True)
    rules = {"rules": {"taker_fee": {"value": 0.00045}, "min_order_notional_usd": {"value": 10.0}},
             "coins": {c: {"szDecimals": sz, "maxLeverage": lev, "marginTiers": [{"lowerBound": "0.0", "maxLeverage": lev}],
                           "delisted": c in delisted} for c, (sz, lev) in coins.items()}}
    (venue / "rules.json").write_text(json.dumps(rules))
    (venue / "execution.json").write_text(json.dumps({"cost_bps_ex_fee": {c: FLAT_COST for c in coins}}))
    return root


def _bar(coin, k, o, c, rng, trades=7):
    return {"coin": coin, "eventTime": (k + 1) * BAR, "openTime": k * BAR, "open": float(o), "high": float(max(o, c) * (1 + abs(rng.normal(0, 0.005)))),
            "low": float(min(o, c) * (1 - abs(rng.normal(0, 0.005)))), "close": float(c), "volume": float(rng.uniform(1, 9)), "trades": trades}


def _funding(coin, h, rate, premium, late=0):
    return {"coin": coin, "eventTime": h * HOUR, "fundingRate": float(rate), "premium": float(premium), "reportedTime": h * HOUR + 50 + late}


def edge(root):
    rng = np.random.default_rng(64)
    n, hours = 40 * 6, 40 * 24 + 1
    px = _walk(rng, n + 1, flat=range(30, 42))
    bars, funding = [], []
    for k in range(n):
        for coin in ("E0", "E1", "E2", "E3"):
            if coin == "E2" and (k < 60 or 120 <= k < 123):
                continue
            o, c = (px[k], px[k + 1]) if coin in ("E0", "E1") else (px[k] * 1.5, px[k + 1] * 1.5 + (0.3 if k % 3 else -0.2))
            trades = 0 if (coin == "E2" and k in (60, 140, 141)) or (coin == "E3" and k >= 180) else 7
            bars.append(_bar(coin, k, o, c, rng, trades))
    for h in range(hours):
        for coin in ("E0", "E1", "E2", "E3"):
            if coin == "E2" and (h < 240 or 600 <= h < 630):
                continue
            rate = [0.0, -0.0, 1.25e-5, -2e-5, 3e-4][h % 5] if coin == "E0" else rng.normal(1e-5, 5e-5)
            funding.append(_funding(coin, h, rate, [0.0, -0.0, 4e-4, -6e-4][h % 4] if coin == "E0" else rng.normal(0, 5e-4)))
    events = [{"coin": c, "eventTime": h * HOUR, "count": float(rng.poisson(1.5))} for c in ("E0", "E1") for h in range(hours)]
    revisions = [_funding("E0", h, 2e-4, 1e-3) for h in range(100, 110)]
    revisions += [_funding("E0", 200, 1e-4, 0.0, late=887_595), _funding("E0", 300, -1e-4, 0.0, late=59_950),
                  _funding("E0", 301, -1e-4, 0.0, late=59_951)]
    return _write(root, bars, funding, {"E0": (3, 10), "E1": (0, 3), "E2": (1, 20), "E3": (2, 5)}, {"E3"}, events, revisions)


def crash(root, drop):
    rng = np.random.default_rng(int(drop * 100))
    n = 20 * 6
    px = _walk(rng, n + 1)
    bars = []
    for k in range(n):
        for coin, scale in (("C0", 1.0), ("C1", 0.7)):
            o, c = px[k] * scale, px[k + 1] * scale
            b = _bar(coin, k, o, c, rng)
            if k == 60:
                b["low"] = float(min(o, c) * (1 - drop))
            bars.append(b)
    funding = [_funding(c, h, 1e-5, 0.0) for c in ("C0", "C1") for h in range(n * 4 + 1)]
    return _write(root, bars, funding, {"C0": (3, 2), "C1": (2, 2)})


MARKETS = {"edge": edge, "liquidation": lambda r: crash(r, 0.4), "ruin": lambda r: crash(r, 0.6)}
VERSIONS = {"edge": 2, "liquidation": 1, "ruin": 1}


def c(x, unit="1"):
    return {"const": x, "unit": unit}


def op(name, *args, **extra):
    return {"op": name, "args": list(args), **extra}


def inp(name):
    return {"input": name}


def ret(x, h=4):
    return op("sub", op("div", inp(x), op("lag", inp(x), hours=h)), c(1.0))


def w(x, scale=0.3):
    return op("mul", op("clip", x, c(-1.0), c(1.0)), c(scale))


R = op("mul", ret("close"), c(20.0))
F = op("div", inp("funding"), c(1e-4, "1/h"))
P = op("mul", inp("premium"), c(1e3))
NAN = op("sub", op("exp", c(1000.0)), op("exp", c(1000.0)))


def program(name, weight, lets=None, params=None):
    p = {"dsl": 1, "name": name, "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"}, "weight": weight}
    if lets:
        p["let"] = lets
    if params:
        p["params"] = params
    return p


def weights():
    """name -> weight (or whole program): every operator and input, then the boundary cases."""
    out = {f"op-{o}": w(op(o, R, F)) for o in ("add", "sub", "mul", "min", "max")}
    out |= {
        "op-div": w(op("div", R, F)),
        "op-div-by-zero": w(op("div", R, op("sign", inp("premium")))),
        "op-neg": w(op("neg", R)), "op-abs": w(op("abs", R)), "op-sign": w(op("sign", R)),
        "op-log": w(op("log", op("div", inp("close"), op("lag", inp("close"), hours=4)))),
        "op-log-nonpositive": w(op("log", ret("close"))),
        "op-exp": w(op("exp", R)),
        "op-sqrt": w(op("sqrt", op("abs", R))),
        "op-sqrt-negative": w(op("sqrt", R)),
        "op-clip": op("clip", R, c(-0.2), c(0.4)),
        "op-if": w(op("if", op("gt", R, c(0.0)), F, P)),
        "op-not-and-or": w(op("if", op("or", op("and", op("ge", R, c(0.1)), op("not", op("lt", F, c(0.0)))), op("le", P, c(-0.3))), c(1.0), c(-1.0))),
        "op-convert": w(op("mul", op("convert", inp("funding"), to="1/d"), c(100.0, "d"))),
        "op-convert-year": w(op("mul", op("convert", inp("funding"), to="1/y"), c(1.0, "y"))),
        "op-lag": w(op("lag", R, hours=6)), "op-mean": w(op("mean", R, hours=6)), "op-sum": w(op("sum", R, hours=13)),
        "op-std": w(op("std", R, hours=6), 2.0), "op-min-over": w(op("min_over", R, hours=24)), "op-max-over": w(op("max_over", R, hours=24)),
        "op-ema": w(op("ema", R, hours=4)),
        "op-xs-mean": w(op("xs_mean", R)), "op-xs-demean": w(op("xs_demean", R)), "op-xs-rank": op("sub", op("xs_rank", R), c(0.5)),
        "op-xs-rank-ties": op("sub", op("xs_rank", inp("premium")), c(0.5)),
        "op-hours-since": w(op("div", op("hours_since", op("gt", F, c(0.5))), c(24.0, "h"))),
        "input-volume": w(op("sub", op("div", inp("volume"), op("mean", inp("volume"), hours=24)), c(1.0))),
        "input-high-low": w(op("mul", op("sub", op("div", inp("high"), inp("low")), c(1.0)), c(10.0))),
        "input-open": w(ret("open", 8)),
        "input-forum": w(op("sub", op("div", inp("forum_posts"), c(1.5, "ev")), c(1.0))),
        "input-governance-unbound": w(op("div", inp("gov_proposals"), c(1.0, "ev"))),
        "if-stateful-unselected": w(op("if", op("gt", P, c(0.0)), op("ema", R, hours=4), op("mean", op("lag", F, hours=6), hours=6))),
        "ema-seeding": w(op("ema", op("sub", op("div", op("lag", inp("close"), hours=24), inp("close")), c(1.0)), hours=13)),
        "window-longer-than-history": w(op("mean", R, hours=4380)),
        "nan-intermediate": w(op("add", NAN, R)),
        "nan-min-first": w(op("min", NAN, R)), "nan-max-second": w(op("max", R, NAN)),
        "infinite-weight": op("exp", c(1000.0)),
        "literal-negative-zero-normalizes": c(-0.0),
        "signed-zero-neg": op("neg", c(0.0)),
        "signed-zero-mul": op("mul", c(-1.0), c(0.0)),
        "signed-zero-min-tie": op("min", op("neg", c(0.0)), c(0.0)),
        "signed-zero-max-tie": op("max", c(0.0), op("neg", c(0.0))),
        "signed-zero-sign": op("sign", op("neg", c(0.0))),
        "signed-zero-add": op("add", op("neg", c(0.0)), op("neg", c(0.0))),
        "zero-target-close": op("if", op("gt", R, c(0.0)), c(0.5), c(0.0)),
        "zero-target-close-negative-zero": op("if", op("gt", R, c(0.0)), c(-0.5), op("neg", c(0.0))),
        "reversal": w(op("sign", R), 0.5),
        "buy-and-hold": c(0.5),
        "gross-cap": c(5.0),
        "order-notional-cap": op("mul", op("max", op("sub", op("xs_rank", R), c(0.9)), c(0.0)), c(20.0)),
        "below-min-notional": c(0.0004),
        "truncation": c(0.0137),
        "huge-finite": op("mul", c(1e300), op("sign", R)),
    }
    out["params-and-lets"] = program("params-and-lets", w(op("mul", {"ref": "r"}, {"param": "k"})),
                                     lets={"f": F, "r": op("add", R, {"ref": "f"})}, params={"k": {"value": 0.5, "unit": "1"}})
    return {k: v if "dsl" in v else program(k, v) for k, v in out.items()}


def cases(nulls):
    """[(name, program, [markets])]: every weight on `edge` and on each null market, and the lifecycle programs on
    the crash markets."""
    ws = weights()
    out = [(k, p, ["edge", *nulls]) for k, p in ws.items()]
    for m in ("liquidation", "ruin"):
        out += [(f"{k}@{m}", ws[k], [m]) for k in ("buy-and-hold", "gross-cap", "reversal", "input-forum")]
    return out


def rejections():
    """Programs `mm` must reject, one per rejection path not already in kernel/tests/adversarial."""
    bad = {
        "unit-mismatch": op("add", F, inp("funding")),
        "boolean-weight": op("gt", R, c(0.0)),
        "weight-unit": inp("funding"),
        "unknown-op": op("tanh", R),
        "lag-zero": op("lag", R, hours=0),
        "lag-too-long": op("lag", R, hours=4381),
        "unknown-input": inp("open_interest"),
        "convert-non-time": op("convert", inp("close"), to="usd"),
        "sqrt-odd-exponent": op("sqrt", inp("funding")),
        "log-unit": op("log", inp("close")),
        "rank-unit": op("xs_rank", inp("close")),
    }
    out = {k: program(k, v) for k, v in bad.items()}
    out["unknown-ref"] = program("unknown-ref", {"ref": "nope"})
    out["forward-let"] = program("forward-let", {"ref": "a"}, lets={"a": {"ref": "b"}, "b": c(0.1)})
    out["unknown-field"] = program("unknown-field", c(0.1)) | {"extra": 1}
    out["wrong-dsl"] = program("wrong-dsl", c(0.1)) | {"dsl": 2}
    return out
