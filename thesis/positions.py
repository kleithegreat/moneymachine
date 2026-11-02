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
open at its openTime; sizing uses only the equity of the latest hour every leg's reference has reached; invalidation uses
only the closes of the bar just ended. At an hour, funding settles first, then exits, then entries, and a leg not entered
by its exit never enters; exits actionable at the same time take the first reason of PRECEDENCE. Fills move the
reference open adversely by the coin's cost cell ("1000" if |q| * ref <= 1000, else "10000") and pay the taker fee.
Money is exact, so every boundary is the frozen one, with no tolerance.
"""

from bisect import bisect_left, bisect_right
from fractions import Fraction
from functools import lru_cache
from typing import Any

from ingest.policy import DELTA, HOUR

Json = dict[str, Any]
RISK, CAP = Fraction(1, 100), Fraction(1, 20)
PRECEDENCE = ("invalidation", "discretionary", "horizon")


@lru_cache(maxsize=1 << 20)
def exact(x: Any) -> Fraction:
    """The number a recorded value states: a float's shortest decimal, or a rational's own text."""
    return Fraction(str(x))


class Bars(dict[int, tuple[float, float | None]]):
    """{openTime: (open, close)} with its openTimes sorted, for the lookups below."""

    def __init__(self, rows: Any = ()) -> None:
        super().__init__(rows)
        self.times = sorted(self)


def mark(bars: Bars, t: int) -> Fraction:
    """The latest price at t: the last bar opened by t, at its close if that bar has ended and has one, else at its open."""
    i = bisect_right(bars.times, t)
    if i == 0:
        raise LookupError(f"no bar available at {t}")
    s = bars.times[i - 1]
    o, c = bars[s]
    return exact(c if c is not None and s + HOUR <= t else o)


def first_open(bars: Bars, t: int, now: int) -> int | None:
    """The first openTime at or after t, among bars already opened by `now`."""
    i = bisect_left(bars.times, t)
    return bars.times[i] if i < len(bars.times) and bars.times[i] <= now else None


def fill(ref: Fraction, q: Fraction, cells: Json, fee: float) -> tuple[Fraction, Fraction, Fraction]:
    """(price, fee, cost) of trading q at reference ref."""
    side = "buy" if q > 0 else "sell"
    bps = exact(cells[side]["1000" if abs(q) * ref <= 1000 else "10000"])
    price = ref * (1 + (bps if q > 0 else -bps) / 10_000)
    return price, abs(q) * price * exact(fee), abs(q) * abs(price - ref)


def outcome(th: Json, data: Json, now: int) -> Json | None:
    """The as-registered net return per N of the fixed-quantity position from the scheduled entry to
    the horizon exit, and o = 1 iff it is > 0; None while any needed price or funding row is not known."""
    total, N = Fraction(0), exact(th["N"])
    for market, w in th["legs"]:
        bars, rates, cells = data["bars"].get(market, Bars()), data["funding"].get(market, {}), th["costs"][market]
        e, x = first_open(bars, th["t_r"] + DELTA, now), first_open(bars, th["T"], now)
        if e is None or x is None or e >= x:
            return None
        ref_in, ref_out = exact(bars[e][0]), exact(bars[x][0])
        q = w * N / ref_in
        pin, fin, _ = fill(ref_in, q, cells, th["fee"])
        pout, fout, _ = fill(ref_out, -q, cells, th["fee"])
        total += q * (pout - pin) - fin - fout
        paid = Fraction(0)
        for h in range(e + HOUR, x + 1, HOUR):
            if h not in rates:
                return None
            paid += exact(rates[h]) * mark(bars, h)
        total -= q * paid
    r = total / N
    return {"R_net": float(r), "o": int(r > 0)}


class Account:
    """One paper account: cash, open legs, risk reservations, and an independent PnL ledger, all exact. A leg's funding
    accrues per unit of quantity and reaches the books when the leg closes: its terms stay small while q's grow with every
    earlier thesis, so an hour costs little however long the track has run. `live` holds the positions not yet closed."""

    def __init__(self, initial: float, data: Json) -> None:
        self.initial, self.bars, self.lag = exact(initial), data["bars"], data.get("lag", {})
        self.cash = self.initial
        self.realized = self.funding = self.fees = self.costs = Fraction(0)
        self.positions: dict[str, Json] = {}
        self.live: dict[str, Json] = {}

    def legs(self) -> list[Json]:
        return [l for p in self.live.values() for l in p["legs"] if l["open"]]

    def equity(self, t: int) -> Fraction:
        return self.cash + sum((l["q"] * (mark(self.bars[l["market"]], t) - l["paid"]) for l in self.legs()), Fraction(0))

    def reconciled(self, t: int) -> Fraction:
        unrealized = sum((l["q"] * (mark(self.bars[l["market"]], t) - l["ref"] - l["paid"]) for l in self.legs()), Fraction(0))
        return self.initial + self.realized + unrealized + self.funding - self.fees - self.costs

    def reserved(self) -> Fraction:
        return sum((p["b"] for p in self.live.values()), Fraction(0))

    def settles(self, h: int, known: int, funding: Json) -> bool:
        """Whether hour h reconciles: its references are available by `known` for every leg entered or due to enter by h, and
        each entered leg has its funding row."""
        return all(h + self.lag.get(l["market"], 0) <= known and (not l["open"] or h in funding.get(l["market"], {}))
                   for p in self.live.values() if p["t_r"] + DELTA <= h for l in p["legs"] if l["exit"] is None)

    def trade(self, leg: Json, ref: Fraction, q: Fraction) -> tuple[Fraction, Fraction]:
        price, fee, cost = fill(ref, q, leg["costs"], leg["fee"])
        self.cash -= q * price + fee
        self.fees += fee
        self.costs += cost
        return price, fee


def replay(initial: float, theses: list[Json], exits: list[Json], data: Json, now: int, hourly: bool = False) -> tuple[Account, dict[str, Json], list[tuple[int, Fraction, Fraction]], list[list[Any]]]:
    """Replay one account's `theses` (in commit order, with their registered sizes) and discretionary `exits` up to
    `now`: the account, each thesis's state, the equity of the latest reconciled hour (with `hourly`, of each in turn), and
    every [hour, market] row lacked (a position that lacked one has no managed return). Reconciliation stops at the first
    hour whose reference is not yet available or whose funding row an open leg lacks. `data["cutoff"]`, if given, is when
    its prices and rows were read: an hour's reference is not established missing by data read before it was due."""
    acct, bars, funding = Account(initial, data), data["bars"], data["funding"]
    known = min(now, data.get("cutoff", now))
    out: dict[str, Json] = {t["id"]: {"N": float(exact(t["N"])), "size": float(exact(t["size"])), "entry": None, "exit": None,
                                      "managed_return": None, "outcome": None} for t in theses}
    exit_at = {e["id"]: e["t_x"] + DELTA for e in reversed(exits)}
    queue = sorted(theses, key=lambda t: t["t_r"])
    equity: list[tuple[int, Fraction, Fraction]] = []
    missing: list[list[Any]] = []
    reconciling = True

    def book(t: int) -> None:
        equity.append((t, acct.equity(t), acct.reconciled(t)))

    h = min((t["t_r"] for t in theses), default=now + 1) // HOUR * HOUR
    while h <= now:
        if reconciling and not acct.settles(h, known, funding):
            reconciling = False
            if not hourly:
                book(h - HOUR)
        for l in acct.legs():
            if h + acct.lag.get(l["market"], 0) > known:
                continue
            rate = funding.get(l["market"], {}).get(h)
            if rate is None:
                missing.append([h, l["market"]])
                acct.positions[l["id"]]["complete"] = False
                continue
            l["paid"] += exact(rate) * mark(bars[l["market"]], h)
        for tid, p in list(acct.live.items()):
            when, reason = min(p["triggers"].items(), key=lambda kv: (kv[1], PRECEDENCE.index(kv[0])))[::-1]
            if h < when:
                continue
            for l in p["legs"]:
                if l["open"] and h in bars[l["market"]]:
                    ref = exact(bars[l["market"]][h][0])
                    price, fee = acct.trade(l, ref, -l["q"])
                    paid = l["q"] * l["paid"]
                    acct.cash -= paid
                    acct.funding -= paid
                    acct.realized += l["q"] * (ref - l["ref"])
                    p["pnl"] += l["q"] * (price - l["fill"]) - fee - paid
                    l["open"], l["exit"] = False, {"t": h, "ref": float(ref), "fill": float(price)}
            if not any(l["open"] for l in p["legs"]):
                p["closed"] = True
                del acct.live[tid]
                exited = [l for l in p["legs"] if l["exit"]]
                out[tid]["exit"] = {"t": max((l["exit"]["t"] for l in exited), default=h), "reason": reason,
                                    "legs": [{"market": l["market"], "ref": l["exit"]["ref"], "fill": l["exit"]["fill"]}
                                             for l in exited]}
                out[tid]["managed_return"] = float(p["pnl"] / p["N"]) if p["complete"] and p["entry"] else None
        for tid, p in acct.live.items():
            for l in p["legs"]:
                if l["ref"] is None and p["t_r"] + DELTA <= h < min(p["triggers"].values()) and h in bars[l["market"]]:
                    ref = exact(bars[l["market"]][h][0])
                    l["ref"], l["q"] = ref, l["w"] * p["N"] / ref
                    l["fill"], fee = acct.trade(l, ref, l["q"])
                    p["pnl"] -= fee
                    l["open"], l["t"] = True, h
            if p["entry"] is None and all(l["ref"] is not None for l in p["legs"]):
                p["entry"] = out[tid]["entry"] = {"t": max(l["t"] for l in p["legs"]), "legs": [
                    {"market": l["market"], "ref": float(l["ref"]), "fill": float(l["fill"]), "q": float(l["q"])} for l in p["legs"]]}
        if reconciling and hourly:
            book(h)
        while queue and queue[0]["t_r"] < h + HOUR and queue[0]["t_r"] <= now:
            th = queue.pop(0)
            if exact(th["size"]) > 0:
                triggers = {"horizon": th["T"]}
                if th["id"] in exit_at:
                    triggers["discretionary"] = exit_at[th["id"]]
                acct.positions[th["id"]] = acct.live[th["id"]] = {
                    "t_r": th["t_r"], "N": exact(th["size"]), "b": exact(th["b"]), "L": exact(th["L"]), "pnl": Fraction(0), "entry": None,
                    "closed": False, "complete": True, "triggers": triggers,
                    "legs": [{"id": th["id"], "market": m, "w": w, "ref": None, "q": Fraction(0), "paid": Fraction(0), "open": False, "exit": None,
                              "costs": th["costs"][m], "fee": th["fee"]} for m, w in th["legs"]]}
        close = h + HOUR
        if close <= now:
            for p in acct.live.values():
                if p["entry"] is not None and "invalidation" not in p["triggers"]:
                    seen = close + max(acct.lag.get(l["market"], 0) for l in p["legs"])
                    closes = [bars[l["market"]].get(h, (None, None))[1] for l in p["legs"]]
                    if seen <= now and None not in closes and sum(
                            (l["w"] * (exact(c) / l["ref"] - 1) for l, c in zip(p["legs"], closes)), Fraction(0)) <= -p["L"]:
                        p["triggers"]["invalidation"] = max(close + DELTA, seen)
        h += HOUR
    if reconciling and not hourly and theses:
        book(h - HOUR)
    for th in theses:
        out[th["id"]]["outcome"] = outcome(th, data, now)
    return acct, out, equity, missing


def run(initial: float, theses: list[Json], exits: list[Json], data: Json, now: int, hourly: bool = False) -> Json:
    _, out, equity, missing = replay(initial, theses, exits, data, now, hourly)
    return {"theses": out, "equity": [(t, float(e), float(r)) for t, e, r in equity], "missing_funding": missing}


def admit(initial: float, theses: list[Json], exits: list[Json], data: Json, t_r: int, L: float) -> dict[str, Fraction]:
    """The exact sizing of a thesis committed at t_r after `theses`: E_r is the equity of the latest reconciled hour, b = RISK
    times it and N = b / L; size N and reservation b if the open positions' reservations plus b stay within CAP of it,
    else size 0 with N kept as its hypothetical notional (from the initial equity when equity is not positive)."""
    acct, _, equity, _ = replay(initial, theses, exits, data, t_r)
    e_r = equity[-1][1] if equity else exact(initial)
    b, loss = RISK * e_r, exact(L)
    if e_r > 0 and acct.reserved() + b <= CAP * e_r:
        return {"N": b / loss, "size": b / loss, "b": b}
    return {"N": b / loss if e_r > 0 else RISK * exact(initial) / loss, "size": Fraction(0), "b": Fraction(0)}
