"""Labeled fill-check cases for C1.5. Each case is one fill with its coin's bars. Non-ok cases
plant exactly one violation into an otherwise valid fill, so the label is known by
construction. Format: kernel/tests/timing/FORMAT.md."""

import json
import random
import sys

HOUR = 3_600_000
BAR = 4 * HOUR
DELTA = 120_000


def price(reference, qty, cost):
    side = "buy" if qty > 0 else "sell"
    bucket = 0 if abs(qty) * reference <= 1000 else 1
    s = 1.0 if qty > 0 else -1.0
    return reference * (1.0 + s * cost[side][bucket] / 1e4)


def base(rng):
    n = 12
    bars, px = [], rng.uniform(1, 500)
    for k in range(n):
        o = px
        c = o * (1 + rng.gauss(0, 0.02))
        bars.append({"open_time": k * BAR, "event": (k + 1) * BAR, "open": o, "high": max(o, c) * 1.01,
                     "low": min(o, c) * 0.99, "close": c, "trades": rng.randint(1, 50)})
        px = c
    for k in sorted(rng.sample(range(1, n - 1), rng.randint(0, 3))):
        bars[k] = None
    bars = [b for b in bars if b]
    cost = {"buy": [rng.uniform(0, 5), rng.uniform(5, 20)], "sell": [rng.uniform(0, 5), rng.uniform(5, 20)]}
    return {"taker_fee": rng.choice([0.00045, 0.00035, 0.001]), "cost_bps": cost, "bars": bars}


def valid_fill(rng, case):
    bars = case["bars"]
    src = rng.choice(bars[1:])
    earlier = [b for b in bars if b["open_time"] < src["open_time"]]
    lo = earlier[-1]["open_time"] + 1 if earlier else 0
    submitted = rng.randint(lo, src["open_time"])
    decided = submitted - rng.choice([0, 0, rng.randint(0, HOUR)])
    known = decided - rng.choice([0, rng.randint(0, 8 * HOUR)])
    filled = src["open_time"] + rng.choice([0, 0, rng.randint(0, BAR)])
    reference = src["open"]
    dp = reference * rng.uniform(0.9, 1.1)
    qty = round(rng.choice([1, -1]) * rng.uniform(0.001, 9999) / dp, 3) or 0.001
    p = price(reference, qty, case["cost_bps"])
    return {"why": "fill", "qty": qty, "inputs_known": known, "decision_price": dp, "decided": decided,
            "submitted": submitted, "filled": filled, "source_open": src["open_time"], "reference": reference,
            "price": p, "fee": abs(qty) * p * case["taker_fee"]}


def valid_closeout(rng, case):
    src = rng.choice(case["bars"])
    qty = round(rng.choice([1, -1]) * rng.uniform(0.01, 100), 3) or 0.001
    why = rng.choice(["liquidation", "delisting"])
    reference = src["close"] if why == "delisting" or rng.random() < 0.3 else (src["high"] if qty > 0 else src["low"])
    t = src["event"] + rng.choice([0, 0, rng.randint(0, BAR)])
    p = price(reference, qty, case["cost_bps"])
    return {"why": why, "qty": qty, "inputs_known": t, "decision_price": reference, "decided": t, "submitted": t,
            "filled": t, "source_open": src["open_time"], "reference": reference, "price": p,
            "fee": abs(qty) * p * case["taker_fee"]}


def refresh(f, case):
    f["price"] = price(f["reference"], f["qty"], case["cost_bps"])
    f["fee"] = abs(f["qty"]) * f["price"] * case["taker_fee"]


def bar_at(case, t):
    return next((b for b in case["bars"] if b["open_time"] == t), None)


def plant(rng, case, f):
    """Return (label, kind) after planting one violation in f, or None if not applicable."""
    bars = case["bars"]
    kinds = ["known_after_decision", "submitted_before_decision", "filled_before_submission"]
    if f["why"] == "fill":
        kinds += ["later_bar", "bar_before_submission", "bar_after_fill", "zero_trades", "reference_is_close",
                  "price_ulp", "wrong_bucket", "wrong_side", "fee_off", "missing_bar", "notional_cap"]
    else:
        kinds += ["closeout_wrong_extreme", "closeout_bar_not_closed", "price_ulp", "fee_off"]
    kind = rng.choice(kinds)
    src = bar_at(case, f["source_open"])
    if kind == "known_after_decision":
        f["inputs_known"] = f["decided"] + rng.randint(1, HOUR)
        return "R_TIMING", kind
    if kind == "submitted_before_decision":
        f["submitted"] = f["decided"] - rng.randint(1, HOUR)
        return "R_TIMING", kind
    if kind == "filled_before_submission":
        f["filled"] = f["submitted"] - rng.randint(1, HOUR)
        return "R_TIMING", kind
    if kind == "later_bar":
        later = [b for b in bars if b["open_time"] > f["source_open"]]
        if not later:
            return None
        b = rng.choice(later)
        f["source_open"], f["reference"] = b["open_time"], b["open"]
        f["filled"] = max(f["filled"], b["open_time"])
        refresh(f, case)
        return "R_FILL", kind
    if kind == "bar_before_submission":
        f["submitted"] = f["source_open"] + rng.randint(1, BAR)
        f["filled"] = max(f["filled"], f["submitted"])
        return "R_FILL", kind
    if kind == "bar_after_fill":
        f["filled"] = f["source_open"] - 1
        f["submitted"] = min(f["submitted"], f["filled"])
        f["decided"] = min(f["decided"], f["submitted"])
        f["inputs_known"] = min(f["inputs_known"], f["decided"])
        return "R_FILL", kind
    if kind == "zero_trades":
        src["trades"] = 0
        return "R_FILL", kind
    if kind == "reference_is_close":
        if src["close"] == src["open"]:
            return None
        f["reference"] = src["close"]
        refresh(f, case)
        return "R_FILL", kind
    if kind == "price_ulp":
        f["price"] = f["price"] * (1 + 2**-50)
        f["fee"] = abs(f["qty"]) * f["price"] * case["taker_fee"]
        return "R_FILL", kind
    if kind == "wrong_bucket":
        side = "buy" if f["qty"] > 0 else "sell"
        bucket = 0 if abs(f["qty"]) * f["reference"] <= 1000 else 1
        s = 1.0 if f["qty"] > 0 else -1.0
        f["price"] = f["reference"] * (1.0 + s * case["cost_bps"][side][1 - bucket] / 1e4)
        f["fee"] = abs(f["qty"]) * f["price"] * case["taker_fee"]
        return "R_FILL", kind
    if kind == "wrong_side":
        side = "buy" if f["qty"] > 0 else "sell"
        bucket = 0 if abs(f["qty"]) * f["reference"] <= 1000 else 1
        s = 1.0 if f["qty"] > 0 else -1.0
        f["price"] = f["reference"] * (1.0 - s * case["cost_bps"][side][bucket] / 1e4)
        f["fee"] = abs(f["qty"]) * f["price"] * case["taker_fee"]
        return ("R_FILL", kind) if case["cost_bps"][side][bucket] > 0 else None
    if kind == "fee_off":
        f["fee"] = f["fee"] * 0.5
        return "R_FILL", kind
    if kind == "missing_bar":
        case["bars"] = [b for b in bars if b["open_time"] != f["source_open"]]
        return "R_FILL", kind
    if kind == "notional_cap":
        f["qty"] = round((10_000 * rng.uniform(1.001, 2)) / f["decision_price"] * (1 if f["qty"] > 0 else -1), 3)
        if abs(f["qty"]) * f["decision_price"] <= 10_000:
            return None
        refresh(f, case)
        return "R_PORTFOLIO", kind
    if kind == "closeout_wrong_extreme":
        f["reference"] = src["low"] if f["qty"] > 0 else src["high"]
        refresh(f, case)
        return "R_FILL", kind
    if kind == "closeout_bar_not_closed":
        f["filled"] = src["event"] - rng.randint(1, BAR)
        f["submitted"] = f["decided"] = f["inputs_known"] = f["filled"]
        return "R_FILL", kind


def generate(n, seed):
    rng = random.Random(seed)
    out = []
    while len(out) < n:
        case = base(rng)
        f = valid_fill(rng, case) if rng.random() < 0.8 else valid_closeout(rng, case)
        if f["why"] == "fill" and abs(f["qty"]) * f["decision_price"] > 10_000:
            continue
        label, kind = "ok", "ok"
        if rng.random() < 0.6:
            planted = plant(rng, case, f)
            if planted is None:
                continue
            label, kind = planted
        out.append({"id": f"c{len(out)}", **case, "fill": f, "label": label, "kind": kind})
    return out


if __name__ == "__main__":
    n, seed, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    with open(path, "w") as fh:
        for c in generate(n, seed):
            fh.write(json.dumps(c) + "\n")
