# Independent I2/I3/I9 fill checker for C1.5, written by GPT 6.1 Sol from whitepaper.tex,
# INVARIANTS.md and FORMAT.md alone, with tools denied.
def check(case: dict) -> str:
    fill = case["fill"]
    why = fill["why"]
    decided = fill["decided"]
    submitted = fill["submitted"]
    filled = fill["filled"]

    if not (fill["inputs_known"] <= decided <= submitted <= filled):
        return "R_TIMING"

    if why in ("liquidation", "delisting"):
        if not (decided == submitted == filled):
            return "R_TIMING"

    qty = float(fill["qty"])
    if qty == 0.0:
        return "R_FILL"

    bar = None
    if why == "fill":
        for candidate in case["bars"]:
            if candidate["open_time"] >= submitted:
                bar = candidate
                break
        if bar is None:
            return "R_FILL"
        if bar["open_time"] > filled or bar["trades"] < 1:
            return "R_FILL"
        reference = float(bar["open"])
    elif why in ("liquidation", "delisting"):
        for candidate in case["bars"]:
            if candidate["event"] <= filled:
                if bar is None or (
                    candidate["event"], candidate["open_time"]
                ) > (bar["event"], bar["open_time"]):
                    bar = candidate
        if bar is None:
            return "R_FILL"
        if why == "liquidation":
            reference = float(bar["high"] if qty > 0.0 else bar["low"])
        else:
            reference = float(bar["close"])
    else:
        return "R_FILL"

    if fill["source_open"] != bar["open_time"]:
        return "R_FILL"
    if float(fill["reference"]) != reference:
        return "R_FILL"

    magnitude = abs(qty)
    side = "buy" if qty > 0.0 else "sell"
    sign = 1.0 if qty > 0.0 else -1.0
    bucket = 0 if magnitude * reference <= 1000.0 else 1
    bps = float(case["cost_bps"][side][bucket])
    price = reference * (1.0 + sign * bps / 1e4)

    if float(fill["price"]) != price:
        return "R_FILL"

    fee = magnitude * price * float(case["taker_fee"])
    if float(fill["fee"]) != fee:
        return "R_FILL"

    if why == "fill" and magnitude * float(fill["decision_price"]) > 10000.0:
        return "R_PORTFOLIO"

    return "ok"
