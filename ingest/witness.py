"""C0.8: replay of the fixed witness strategy W0 over the search part of W.

Conventions (stage 0 criteria, C0.8 as revised), per 4h bar [b, b + 4h): funding settlements
at b + 1h ..= b + 4h, marks at its close, margin check, delisting closeouts, equity at b + 4h,
then fills at b + 4h of the orders decided at b + delta (only if a later bar will mark them),
then the decision at b + 4h + delta.
- decision at t_d = B + DELTA from as_of(t_d): funding settled at B, bar ending at B;
- fill at B + 4h at the open of the bar starting there (unfilled if it recorded no trade), moved by the taker cost model, plus fee;
- funding settles hourly on the position held, before any fill at the same instant, priced at
  the open of the 4h bar containing the hour (oracle prices are not in the public history);
- maintenance margin is checked at each bar's adverse extreme; a coin leaving U is closed at
  its last bar's close.
"""

import json
import math
import sys
from pathlib import Path

import polars as pl

from ingest import checks
from ingest.policy import BAR, DELTA, HOLDOUT_START, HOUR, W_END, W_START
from ingest.store import stores

INITIAL = 10_000.0
THRESHOLD = 1e-4
SIZE = 0.008333333333333333  # W0's per-coin weight, 0.1 / |U|, as the literal in kernel/strategies/w0.json


def truncate(x, decimals):
    f = 10**decimals
    return math.trunc(x * f) / f


class Book:
    """Cash-based account, plus an independent average-entry PnL ledger for reconciliation."""

    def __init__(self):
        self.cash, self.pos = INITIAL, {}
        self.entry, self.realized, self.fees, self.funding = {}, 0.0, 0.0, 0.0

    def fill(self, coin, qty, price, fee):
        old = self.pos.get(coin, 0.0)
        new = old + qty
        if old and (old > 0) != (qty > 0):
            closed = min(abs(qty), abs(old)) * math.copysign(1, old)
            self.realized += closed * (price - self.entry[coin])
        if new == 0:
            self.entry.pop(coin, None)
        elif not old or (old > 0) != (new > 0):
            self.entry[coin] = price
        elif (old > 0) == (qty > 0):
            self.entry[coin] = (old * self.entry[coin] + qty * price) / new
        self.pos[coin] = new
        if new == 0:
            del self.pos[coin]
        self.cash -= qty * price + fee
        self.fees += fee

    def settle(self, coin, price, rate):
        pay = self.pos.get(coin, 0.0) * price * rate
        self.cash -= pay
        self.funding -= pay

    def equity(self, marks):
        return self.cash + sum(q * marks[c] for c, q in self.pos.items())

    def reconciled(self, marks):
        unrealized = sum(q * (marks[c] - self.entry[c]) for c, q in self.pos.items())
        return INITIAL + self.realized + unrealized - self.fees + self.funding


def run(data_root, version, venue=Path(__file__).resolve().parents[1] / "venue" / "hyperliquid"):
    root = Path(data_root)
    search, _ = stores(root)
    venue = Path(venue)
    rules = json.loads((venue / "rules.json").read_text())
    cost = json.loads((venue / "execution.json").read_text())["cost_bps_ex_fee"]
    fee_rate = rules["rules"]["taker_fee"]["value"]
    min_notional = rules["rules"]["min_order_notional_usd"]["value"]

    bars = search.as_of("bars_4h", HOLDOUT_START, version)
    funding = search.as_of("funding", HOLDOUT_START, version)
    delisted = {c for c, r in rules["coins"].items() if r["delisted"]}
    listed = checks.listed_intervals(bars, W_START, W_END, delisted)
    intervals = {c: (listed[c][0], min(listed[c][1], HOLDOUT_START)) for c in rules["coins"] if c in listed}
    bar = {(c, t): r for c, t, *r in bars.select("coin", "openTime", "open", "high", "low", "close", "trades").iter_rows()}
    rate_at = {(c, t): r for c, t, r in funding.select("coin", "eventTime", "fundingRate").iter_rows()}

    book, trace, worst, orders, marks = Book(), [], 0.0, {}, {}

    def execute(t, coin, qty, ref, why):
        side = "buy" if qty > 0 else "sell"
        bps = cost[coin][side]["1000" if abs(qty) * ref <= 1000 else "10000"]
        price = ref * (1 + (bps if side == "buy" else -bps) / 1e4)
        fee = abs(qty) * price * fee_rate
        book.fill(coin, qty, price, fee)
        trace.append({"t": t, "type": why, "coin": coin, "qty": qty, "ref": ref, "price": price, "fee": fee})

    b = W_START
    while b + 2 * BAR <= HOLDOUT_START:
        for h in range(b + HOUR, b + BAR + HOUR, HOUR):
            for coin in list(book.pos):
                if (coin, h) in rate_at and (coin, h - h % BAR) in bar:
                    px = bar[(coin, h - h % BAR)][0]
                    book.settle(coin, px, rate_at[(coin, h)])
                    trace.append({"t": h, "type": "funding", "coin": coin, "rate": rate_at[(coin, h)], "price": px})
        for coin in list(book.pos):
            if (coin, b) in bar:
                marks[coin] = bar[(coin, b)][3]
        adverse = {c: bar[(c, b)][2] if q > 0 else bar[(c, b)][1] for c, q in book.pos.items() if (c, b) in bar}
        eq_adverse = book.cash + sum(q * adverse.get(c, marks[c]) for c, q in book.pos.items())
        mm = sum(abs(q) * adverse.get(c, marks[c]) / (2 * min(t["maxLeverage"] for t in rules["coins"][c]["marginTiers"])) for c, q in book.pos.items())
        if book.pos and eq_adverse < mm:
            for coin in list(book.pos):
                execute(b + BAR, coin, -book.pos[coin], adverse.get(coin, marks[coin]), "liquidation")
        for coin in list(book.pos):
            if b + BAR >= intervals[coin][1]:
                execute(b + BAR, coin, -book.pos[coin], marks[coin], "delisting")

        e1, e2 = book.equity(marks), book.reconciled(marks)
        worst = max(worst, abs(e1 - e2) / abs(e1))
        trace.append({"t": b + BAR, "type": "equity", "equity": e1, "reconciled": e2})

        for coin, qty in (orders.pop(b + BAR, {}) if b + 3 * BAR <= HOLDOUT_START else {}).items():
            if (coin, b + BAR) in bar and bar[(coin, b + BAR)][4] > 0:
                execute(b + BAR, coin, qty, bar[(coin, b + BAR)][0], "fill")
            else:
                trace.append({"t": b + BAR, "type": "unfilled", "coin": coin, "qty": qty})

        t_d = b + BAR + DELTA
        view_f = search.as_of("funding", t_d, version)
        view_b = search.as_of("bars_4h", t_d, version)
        for coin, (start, end) in intervals.items():
            if not (start <= b + BAR and b + 3 * BAR <= end):
                continue
            f = view_f.filter((pl.col("coin") == coin) & (pl.col("eventTime") == b + BAR))
            p = view_b.filter((pl.col("coin") == coin) & (pl.col("eventTime") == b + BAR))
            if f.height == 0 or p.height == 0:
                trace.append({"t": t_d, "type": "hold", "coin": coin})
                continue
            known = [f["knownAt"].item(), p["knownAt"].item()]
            assert max(known) <= t_d
            rate, price = f["fundingRate"].item(), p["close"].item()
            w = -math.copysign(1.0, rate) * SIZE if abs(rate) > THRESHOLD else 0.0
            target = w * e1 / price if w else 0.0
            held = book.pos.get(coin, 0.0)
            qty = -held if target == 0.0 else truncate(target - held, rules["coins"][coin]["szDecimals"])
            if qty and (abs(qty) * price >= min_notional or target == 0.0):
                orders.setdefault(b + 2 * BAR, {})[coin] = qty
                trace.append({"t": t_d, "type": "decision", "coin": coin, "rate": rate, "price": price,
                              "qty": qty, "inputs_knownAt": known})
        b += BAR
    return trace, worst


if __name__ == "__main__":
    data_root, version, out, *venue = sys.argv[1:]
    trace, worst = run(data_root, int(version), *venue)
    Path(out).write_text("\n".join(json.dumps(r) for r in trace) + "\n")
    eq = [r for r in trace if r["type"] == "equity"]
    print(json.dumps({"steps": len(eq), "final_equity": eq[-1]["equity"], "worst_reconciliation_rel": worst,
                      "fills": sum(r["type"] == "fill" for r in trace),
                      "holds": sum(r["type"] == "hold" for r in trace)}))
