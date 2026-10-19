# Independent I2/I3/I9 fill checker for C1.5, written by a fresh-context Opus subagent from
# whitepaper.tex, INVARIANTS.md and FORMAT.md alone (GPT was unavailable; see PROGRESS.md Blockers).
"""Fill-check verdicts per FORMAT.md: R_TIMING (I2), R_FILL (I3), R_PORTFOLIO (I9 order cap)."""


def timing_ok(f):
    return f["inputs_known"] <= f["decided"] <= f["submitted"] <= f["filled"]


def source_reference(case):
    """The reference price I3 requires for this fill, or None if it has no valid source bar."""
    f, bars = case["fill"], case["bars"]
    if f["why"] == "fill":
        bar = next((b for b in bars if b["open_time"] >= f["submitted"]), None)
        if bar is None or bar["open_time"] > f["filled"] or bar["trades"] < 1:
            return None
    else:
        closed = [b for b in bars if b["event"] <= f["filled"]]
        if not closed:
            return None
        bar = closed[-1]
    if bar["open_time"] != f["source_open"]:
        return None
    if f["why"] == "fill":
        return float(bar["open"])
    if f["why"] == "delisting":
        return float(bar["close"])
    return float(bar["high"] if f["qty"] > 0 else bar["low"])


def fill_ok(case):
    f = case["fill"]
    qty = float(f["qty"])
    reference = source_reference(case)
    if qty == 0 or reference is None or float(f["reference"]) != reference:
        return False
    side, s = ("buy", 1.0) if qty > 0 else ("sell", -1.0)
    bps = float(case["cost_bps"][side][0 if abs(qty) * reference <= 1000 else 1])
    price = reference * (1.0 + s * bps / 1e4)
    fee = abs(qty) * price * float(case["taker_fee"])
    return float(f["price"]) == price and float(f["fee"]) == fee


def portfolio_ok(f):
    return f["why"] != "fill" or abs(float(f["qty"])) * float(f["decision_price"]) <= 10000


def check(case: dict) -> str:
    f = case["fill"]
    if not timing_ok(f):
        return "R_TIMING"
    if not fill_ok(case):
        return "R_FILL"
    if not portfolio_ok(f):
        return "R_PORTFOLIO"
    return "ok"
