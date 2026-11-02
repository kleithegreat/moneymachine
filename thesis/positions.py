"""Paper positions for registered theses (audit/criteria.md, stage 10): admission under the concurrent risk cap at
registration, entry, invalidation, discretionary and horizon exits, funding, costs, the hourly account, and each
thesis's as-registered outcome.

A thesis carries what was fixed when it was committed: its notional N, its size (N, or 0 when the cap refused it),
its reservation b, and its markets' fee and cost cells. Replays consume these and never recompute them; `admit` is
the only place they are decided.

Data: `bars[market]` is the Bars {openTime: (open, close)} of 1h bars, where a close may be None (a builder market's next
mark is missing); `funding[market]` is {hour: rate}, one row per settled hour, where a missing row is missing data,
never a zero rate, and ends the account's reconciled equity until it arrives; `lag[market]` is how long after a
price's time it becomes available to a decision (δ for candles, the mark seal for builder markets). Fills use a bar's
open at its openTime; sizing uses only prices available by then; invalidation uses only the closes of the bar just
ended. At an hour, funding settles first, then exits, then entries, and a leg not entered by its exit never enters.
Fills move the reference open adversely by the coin's cost cell ("1000" if |q| * ref <= 1000, else "10000") and pay
the taker fee.
"""

from bisect import bisect_left, bisect_right

from ingest.policy import DELTA, HOUR

RISK, CAP = 0.01, 0.05
ROUNDING = 1e-12  # what float arithmetic can leave of an exact tie, which each `<=` below counts as met


class Bars(dict):
    """{openTime: (open, close)} with its openTimes sorted, for the lookups below."""

    def __init__(self, rows=()):
        super().__init__(rows)
        self.times = sorted(self)


def mark(bars, t, lag=0):
    """The latest price available at t: the last bar whose open is available by t, at its close if that is
    available and not None, else at its open."""
    i = bisect_right(bars.times, t - lag)
    if i == 0:
        return None
    s = bars.times[i - 1]
    o, c = bars[s]
    return c if c is not None and s + HOUR + lag <= t else o


def first_open(bars, t, now):
    """The first openTime at or after t, among bars already opened by `now`."""
    i = bisect_left(bars.times, t)
    return bars.times[i] if i < len(bars.times) and bars.times[i] <= now else None


def fill(ref, q, cells, fee):
    """(price, fee, cost) of trading q at reference ref."""
    side = "buy" if q > 0 else "sell"
    bps = cells[side]["1000" if abs(q) * ref <= 1000 * (1 + ROUNDING) else "10000"]
    price = ref * (1 + (bps if q > 0 else -bps) / 1e4)
    return price, abs(q) * price * fee, abs(q) * abs(price - ref)


def outcome(th, data, now):
    """The as-registered net return per N of the fixed-quantity position from the scheduled entry to
    the horizon exit, and o = 1 iff it is > 0; None while any needed price or funding row is not known."""
    total = 0.0
    for market, w in th["legs"]:
        bars, rates, cells = data["bars"].get(market, Bars()), data["funding"].get(market, {}), th["costs"][market]
        e, x = first_open(bars, th["t_r"] + DELTA, now), first_open(bars, th["T"], now)
        if e is None or x is None or e >= x:
            return None
        q = w * th["N"] / bars[e][0]
        pin, fin, _ = fill(bars[e][0], q, cells, th["fee"])
        pout, fout, _ = fill(bars[x][0], -q, cells, th["fee"])
        total += q * (pout - pin) - fin - fout
        for h in range(e + HOUR, x + 1, HOUR):
            if h not in rates:
                return None
            total -= q * rates[h] * mark(bars, h)
    r = total / th["N"]
    return {"R_net": r, "o": int(r > 0)}


class Account:
    """One paper account: cash, open legs, risk reservations, and an independent PnL ledger."""

    def __init__(self, initial, data):
        self.initial, self.bars, self.lag = initial, data["bars"], data.get("lag", {})
        self.cash = initial
        self.realized = self.funding = self.fees = self.costs = 0.0
        self.positions = {}
        self.last_reconciled = None

    def legs(self):
        return [l for p in self.positions.values() for l in p["legs"] if l["open"]]

    def equity(self, t, available=False):
        """Marked at t; with `available`, only from prices a decision at t could see."""
        return self.cash + sum(l["q"] * mark(self.bars[l["market"]], t, self.lag.get(l["market"], 0) if available else 0)
                               for l in self.legs())

    def sizing_equity(self, t):
        """The latest reconciled equity available at t: at t, unless a missing funding row stopped it earlier."""
        return self.equity(t, available=True) if self.last_reconciled is None else self.last_reconciled

    def reconciled(self, t):
        unrealized = sum(l["q"] * (mark(self.bars[l["market"]], t) - l["ref"]) for l in self.legs())
        return self.initial + self.realized + unrealized + self.funding - self.fees - self.costs

    def reserved(self):
        return sum(p["b"] for p in self.positions.values() if not p["closed"])

    def trade(self, leg, ref, q):
        price, fee, cost = fill(ref, q, leg["costs"], leg["fee"])
        self.cash -= q * price + fee
        self.fees += fee
        self.costs += cost
        return price, fee


def replay(initial, theses, exits, data, now):
    """Replay one account's `theses` (in commit order, with their registered sizes) and discretionary `exits` up to
    `now`: the account, each thesis's state, the hourly equity up to the first funding row an open leg lacked, and every
    [hour, market] row lacked (a position that lacked one has no managed return)."""
    acct, bars, funding = Account(initial, data), data["bars"], data["funding"]
    out = {t["id"]: {"N": t["N"], "size": t["size"], "entry": None, "exit": None, "managed_return": None, "outcome": None}
           for t in theses}
    exit_at = {e["id"]: e["t_x"] + DELTA for e in reversed(exits)}
    queue = sorted(theses, key=lambda t: t["t_r"])
    equity, missing = [], []
    h = min((t["t_r"] for t in theses), default=now + 1) // HOUR * HOUR
    while h <= now:
        if acct.last_reconciled is None and any(h not in funding.get(l["market"], {}) for l in acct.legs()):
            acct.last_reconciled = acct.equity(h, available=True)
        for l in acct.legs():
            rate = funding.get(l["market"], {}).get(h)
            if rate is None:
                missing.append([h, l["market"]])
                acct.positions[l["id"]]["complete"] = False
                continue
            paid = l["q"] * rate * mark(bars[l["market"]], h)
            acct.cash -= paid
            acct.funding -= paid
            acct.positions[l["id"]]["pnl"] -= paid
        for tid, p in acct.positions.items():
            when, reason = min(p["triggers"].items(), key=lambda kv: (kv[1], kv[0]))[::-1]
            if p["closed"] or h < when:
                continue
            for l in p["legs"]:
                if l["open"] and h in bars[l["market"]]:
                    ref = bars[l["market"]][h][0]
                    price, fee = acct.trade(l, ref, -l["q"])
                    acct.realized += l["q"] * (ref - l["ref"])
                    p["pnl"] += l["q"] * (price - l["fill"]) - fee
                    l["open"], l["exit"] = False, {"t": h, "ref": ref, "fill": price}
            if not any(l["open"] for l in p["legs"]):
                p["closed"] = True
                exited = [l for l in p["legs"] if l["exit"]]
                out[tid]["exit"] = {"t": max((l["exit"]["t"] for l in exited), default=h), "reason": reason,
                                    "legs": [{"market": l["market"], "ref": l["exit"]["ref"], "fill": l["exit"]["fill"]}
                                             for l in exited]}
                out[tid]["managed_return"] = p["pnl"] / p["N"] if p["complete"] and p["entry"] else None
        for tid, p in acct.positions.items():
            for l in p["legs"]:
                if l["ref"] is None and p["t_r"] + DELTA <= h < min(p["triggers"].values()) and h in bars[l["market"]]:
                    l["ref"] = bars[l["market"]][h][0]
                    l["q"] = l["w"] * p["N"] / l["ref"]
                    l["fill"], fee = acct.trade(l, l["ref"], l["q"])
                    p["pnl"] -= fee
                    l["open"], l["t"] = True, h
            if p["entry"] is None and all(l["ref"] is not None for l in p["legs"]):
                p["entry"] = out[tid]["entry"] = {"t": max(l["t"] for l in p["legs"]), "legs": [
                    {"market": l["market"], "ref": l["ref"], "fill": l["fill"], "q": l["q"]} for l in p["legs"]]}
        while queue and queue[0]["t_r"] < h + HOUR and queue[0]["t_r"] <= now:
            th = queue.pop(0)
            if th["size"] > 0:
                triggers = {"horizon": th["T"]}
                if th["id"] in exit_at:
                    triggers["discretionary"] = exit_at[th["id"]]
                acct.positions[th["id"]] = {
                    "t_r": th["t_r"], "N": th["size"], "b": th["b"], "L": th["L"], "pnl": 0.0, "entry": None,
                    "closed": False, "complete": True, "triggers": triggers,
                    "legs": [{"id": th["id"], "market": m, "w": w, "ref": None, "q": 0.0, "open": False, "exit": None,
                              "costs": th["costs"][m], "fee": th["fee"]} for m, w in th["legs"]]}
        close = h + HOUR
        if close <= now:
            for p in acct.positions.values():
                if not p["closed"] and p["entry"] is not None and "invalidation" not in p["triggers"]:
                    seen = close + max(acct.lag.get(l["market"], 0) for l in p["legs"])
                    closes = [bars[l["market"]].get(h, (None, None))[1] for l in p["legs"]]
                    if seen <= now and None not in closes and sum(
                            l["w"] * (c / l["ref"] - 1) for l, c in zip(p["legs"], closes)) <= -p["L"] * (1 - ROUNDING):
                        p["triggers"]["invalidation"] = max(close + DELTA, seen)
            if acct.last_reconciled is None:
                equity.append((close, acct.equity(close), acct.reconciled(close)))
        h += HOUR
    for th in theses:
        out[th["id"]]["outcome"] = outcome(th, data, now)
    return acct, out, equity, missing


def run(initial, theses, exits, data, now):
    _, out, equity, missing = replay(initial, theses, exits, data, now)
    return {"theses": out, "equity": equity, "missing_funding": missing}


def admit(initial, theses, exits, data, t_r, L):
    """The sizing of a thesis committed at t_r after `theses`: b = RISK times the latest reconciled equity and N = b / L; size N and reservation b if the open positions' reservations plus b stay within CAP of that equity,
    else size 0 with N kept as its hypothetical notional (from the initial equity when equity is not positive)."""
    acct = replay(initial, theses, exits, data, t_r)[0]
    e_r = acct.sizing_equity(t_r)
    b = RISK * e_r
    if e_r > 0 and acct.reserved() + b <= CAP * e_r * (1 + ROUNDING):
        return {"N": b / L, "size": b / L, "b": b}
    return {"N": b / L if e_r > 0 else RISK * initial / L, "size": 0, "b": 0.0}
