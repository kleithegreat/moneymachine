"""Paper positions for registered theses (PROGRESS.md, Stage 10): admission under the concurrent risk
cap, entry, invalidation, discretionary and horizon exits, funding, costs, the hourly account, and
each thesis's as-registered outcome.

Data: `bars[market]` is {openTime: (open, close)} of completed 1h bars; `funding[market]` is
{hour: rate}. A price is known at a bar's open (its openTime) and at its close (openTime + 1h). At
an hour, funding settles first, then exits, then entries. Fills move the reference open adversely
by the coin's cost cell ("1000" if |q| * ref <= 1000, else "10000") and pay the taker fee.
"""

from ingest.policy import DELTA, HOUR

RISK, CAP = 0.01, 0.05


def mark(bars, t):
    """The latest price known at t: the last bar opened by t, at its close if that has passed, else at its open."""
    s = max((s for s in bars if s <= t), default=None)
    return None if s is None else bars[s][1] if s + HOUR <= t else bars[s][0]


def first_open(bars, t, now):
    """The first openTime at or after t, among bars already opened by `now`."""
    times = [s for s in bars if t <= s <= now]
    return min(times) if times else None


def fill(ref, q, cells, fee):
    """(price, fee, cost) of trading q at reference ref."""
    side = "buy" if q > 0 else "sell"
    bps = cells[side]["1000" if abs(q) * ref <= 1000 else "10000"]
    price = ref * (1 + (bps if q > 0 else -bps) / 1e4)
    return price, abs(q) * price * fee, abs(q) * abs(price - ref)


def outcome(th, n, account, data, now):
    """The as-registered net return per N of the fixed-quantity position from the scheduled entry to
    the horizon exit, and o = 1 iff it is > 0; None while any needed price is not yet known."""
    total = 0.0
    for market, w in th["legs"]:
        bars, cells = data["bars"].get(market, {}), account["costs"][market]
        e, x = first_open(bars, th["t_r"] + DELTA, now), first_open(bars, th["T"], now)
        if e is None or x is None:
            return None
        q = w * n / bars[e][0]
        pin, fin, _ = fill(bars[e][0], q, cells, account["fee"])
        pout, fout, _ = fill(bars[x][0], -q, cells, account["fee"])
        total += q * (pout - pin) - fin - fout
        for h, rate in data["funding"].get(market, {}).items():
            if e < h <= x:
                total -= q * rate * mark(bars, h)
    r = total / n
    return {"R_net": r, "o": int(r > 0)}


class Account:
    """One paper account: cash, open legs, risk reservations, and an independent PnL ledger."""

    def __init__(self, account, data):
        self.account, self.bars = account, data["bars"]
        self.cash = account["initial"]
        self.realized = self.funding = self.fees = self.costs = 0.0
        self.positions = {}

    def legs(self):
        return [l for p in self.positions.values() for l in p["legs"] if l["open"]]

    def equity(self, t):
        return self.cash + sum(l["q"] * mark(self.bars[l["market"]], t) for l in self.legs())

    def reconciled(self, t):
        unrealized = sum(l["q"] * (mark(self.bars[l["market"]], t) - l["ref"]) for l in self.legs())
        return self.account["initial"] + self.realized + unrealized + self.funding - self.fees - self.costs

    def reserved(self):
        return sum(p["b"] for p in self.positions.values() if not p["closed"])

    def trade(self, leg, ref, q):
        price, fee, cost = fill(ref, q, self.account["costs"][leg["market"]], self.account["fee"])
        self.cash -= q * price + fee
        self.fees += fee
        self.costs += cost
        return price, fee


def run(account, theses, exits, data, now):
    """Replay one account's `theses` (in commit order) and discretionary `exits` up to `now`."""
    acct, bars, funding = Account(account, data), data["bars"], data["funding"]
    out = {t["id"]: {"N": None, "size": 0, "entry": None, "exit": None, "managed_return": None, "outcome": None} for t in theses}
    exit_at = {e["id"]: e["t_x"] + DELTA for e in exits}
    queue = list(theses)
    queue.sort(key=lambda t: t["t_r"])
    equity = []
    h = min((t["t_r"] for t in theses), default=now + 1) // HOUR * HOUR
    while h <= now:
        for l in acct.legs():
            rate = funding.get(l["market"], {}).get(h)
            if rate is not None:
                paid = l["q"] * rate * mark(bars[l["market"]], h)
                acct.cash -= paid
                acct.funding -= paid
                acct.positions[l["id"]]["pnl"] -= paid
        for tid, p in acct.positions.items():
            if p["closed"] or p["entry"] is None:
                continue
            when, reason = min(p["triggers"].items(), key=lambda kv: (kv[1], kv[0]))[::-1]
            for l in p["legs"]:
                if l["open"] and h >= when and h in bars[l["market"]]:
                    ref = bars[l["market"]][h][0]
                    price, fee = acct.trade(l, ref, -l["q"])
                    acct.realized += l["q"] * (ref - l["ref"])
                    p["pnl"] += l["q"] * (price - l["fill"]) - fee
                    l["open"], l["exit"] = False, {"t": h, "ref": ref, "fill": price}
            if all(l["exit"] for l in p["legs"]):
                p["closed"] = True
                out[tid]["exit"] = {"t": max(l["exit"]["t"] for l in p["legs"]), "reason": reason,
                                    "legs": [{"ref": l["exit"]["ref"], "fill": l["exit"]["fill"]} for l in p["legs"]]}
                out[tid]["managed_return"] = p["pnl"] / p["N"]
        for tid, p in acct.positions.items():
            for l in p["legs"]:
                if l["ref"] is None and h >= p["t_r"] + DELTA and h in bars[l["market"]]:
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
            e_r = acct.equity(th["t_r"])
            b = RISK * e_r
            n = b / th["L"] if e_r > 0 else RISK * account["initial"] / th["L"]
            out[th["id"]]["N"] = n
            if e_r > 0 and acct.reserved() + b <= CAP * e_r * (1 + 1e-12):
                out[th["id"]]["size"] = n
                triggers = {"horizon": th["T"]}
                if th["id"] in exit_at:
                    triggers["discretionary"] = exit_at[th["id"]]
                acct.positions[th["id"]] = {
                    "t_r": th["t_r"], "N": n, "b": b, "L": th["L"], "pnl": 0.0, "entry": None, "closed": False,
                    "triggers": triggers,
                    "legs": [{"id": th["id"], "market": m, "w": w, "ref": None, "q": 0.0, "open": False, "exit": None}
                             for m, w in th["legs"]]}
        close = h + HOUR
        if close <= now:
            for p in acct.positions.values():
                if not p["closed"] and p["entry"] is not None and "invalidation" not in p["triggers"]:
                    r = sum(l["w"] * (mark(bars[l["market"]], close) / l["ref"] - 1) for l in p["legs"])
                    if r <= -p["L"]:
                        p["triggers"]["invalidation"] = close + DELTA
            equity.append((close, acct.equity(close), acct.reconciled(close)))
        h += HOUR
    for th in theses:
        out[th["id"]]["outcome"] = outcome(th, out[th["id"]]["N"], account, data, now) if out[th["id"]]["N"] else None
    return {"theses": out, "equity": equity}
