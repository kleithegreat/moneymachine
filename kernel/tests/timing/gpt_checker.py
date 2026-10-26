# Written by GPT 6.1 Sol from whitepaper.tex and INVARIANTS.md alone.

def check(case: dict) -> str:
    """Check one case in the documented mm check-fills format."""
    fill = case["fill"]
    why = fill["why"]
    closeout = why in ("liquidation", "delisting")

    known = fill["inputs_known"]
    decided = fill["decided"]
    submitted = fill["submitted"]
    filled = fill["filled"]

    # I2 takes precedence over every fill and portfolio failure.
    if not (known <= decided <= submitted <= filled):
        return "R_TIMING"
    if closeout and not (known == decided == submitted == filled):
        return "R_TIMING"

    # I3: a recorded fill must have a nonzero signed quantity.
    qty = float(fill["qty"])
    if qty == 0.0:
        return "R_FILL"
    if why not in ("fill", "liquidation", "delisting"):
        return "R_FILL"

    bars = case["bars"]

    if why == "fill":
        # Select before testing tradability: an unfilled order cannot roll
        # past a zero-trade or otherwise ineligible first source bar.
        source = next(
            (bar for bar in bars if bar["open_time"] >= submitted),
            None,
        )
        if source is None:
            return "R_FILL"
        if not (
            source["open_time"] == fill["source_open"]
            and source["open_time"] <= filled
            and source["trades"] >= 1
        ):
            return "R_FILL"
        reference = float(source["open"])
    else:
        # Closeouts use the latest closed bar, not the next opening bar.
        source = max(
            (bar for bar in bars if bar["event"] <= filled),
            key=lambda bar: (bar["event"], bar["open_time"]),
            default=None,
        )
        if source is None:
            return "R_FILL"
        if source["open_time"] != fill["source_open"]:
            return "R_FILL"

        if why == "delisting":
            reference = float(source["close"])
        elif qty > 0.0:
            reference = float(source["high"])
        else:
            reference = float(source["low"])

    if float(fill["reference"]) != reference:
        return "R_FILL"

    magnitude = abs(qty)
    side = "buy" if qty > 0.0 else "sell"
    sign = 1.0 if qty > 0.0 else -1.0
    bucket = 0 if magnitude * reference <= 1000.0 else 1
    bps = float(case["cost_bps"][side][bucket])

    # Preserve the specified binary64 operation order; use no tolerance,
    # decimal arithmetic, reassociation, or fused multiply-add.
    price = reference * (1.0 + sign * bps / 1e4)
    if float(fill["price"]) != price:
        return "R_FILL"

    fee = magnitude * price * float(case["taker_fee"])
    if float(fill["fee"]) != fee:
        return "R_FILL"

    # The case format supplies no equity, weights, size precision, or prior
    # position. Its specified portfolio verdict tests only decision notional;
    # it cannot establish bankruptcy, truncation, or the exact-close exception.
    if why == "fill":
        if magnitude * float(fill["decision_price"]) > 10000.0:
            return "R_PORTFOLIO"

    return "ok"
