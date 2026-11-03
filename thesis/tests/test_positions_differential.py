"""thesis/positions.py against GPT's independent implementation from the stage 10 criteria alone (gpt_positions.py).

GPT's file stays as GPT wrote it. Two comparisons are kept apart: the raw one, against that file, whose disagreements are
what the readings below settle; and the approved one, with `READINGS` (audit/stage10/readings.md) applied to its
source here, where everything must agree exactly: identifiers, times, reasons, outcomes, sizing, reservations, every
fill and the hourly equity, as exact rationals. Each implementation sizes its own theses, so a difference propagates.
Scenario classes turn on what could make the two disagree, fixed cases sit on each boundary, and `production` reads the
prices through Market and Track.data rather than the synthetic as-of view.
"""

import random
import tempfile
import types
from concurrent.futures import ProcessPoolExecutor
from fractions import Fraction
from pathlib import Path

import pytest

from ingest.live import append
from thesis import market as market_module
from thesis import positions, runner, scoring
from thesis.tests import gpt_positions

HOUR, DAY, DELTA, WINDOW = 3600, 86400, 120, 300
HOURS = 600
CORE, BUILDER = ("A", "B"), ("xyz:C",)
MARKETS = CORE + BUILDER
LAG = {"A": DELTA, "B": DELTA, "xyz:C": WINDOW}
SETS = 150
PRODUCTION_SETS = 20
READINGS = {
    # Reading 1: the quantity and R_gross's P_e are the reference open, and the cost is only in the fill.
    "the quantity comes from the open": [("""unit_q = Fraction(leg["w"]) / price""", """unit_q = Fraction(leg["w"]) / reference["reference"]""")],
    "R_gross's entry price is the open": [("""/ entry["price"] - ONE""", """/ entry["reference"] - ONE""")],
    # Reading 2: with the hour's core bar missing, the latest earlier bar's close, else its open.
    "a funding mark after a missing bar is the last close": [("""        reference = self.bars[market][selected][0]
""", """        opening, closing = self.bars[market][selected]
        reference = closing if closing is not None and selected + HOUR <= timestamp else opening
""")],
    # Reading 3: a leg with no bar by its exit is suppressed at that boundary and holds nothing up.
    "a leg that can no longer enter holds no reservation": [("""    if thesis["size"] > 0 and all(path["exit"] is not None for path in paths):
        released = max(path["exit"]["available_at"] for path in paths)
""", """    if thesis["size"] > 0 and all(path["exit"] is not None or (path["entry"] is None and action["threshold"] <= now) for path in paths):
        released = max(path["exit"]["available_at"] if path["exit"] else -(-action["threshold"] // HOUR) * HOUR for path in paths)
""")],
    # SCORING.md's cost cells are per side, which GPT's data shape did not carry.
    "an exit fills at its own side's cell": [("""                "cells": _cells(raw["cells"]),
""", """                "cells": _cells(raw["cells"]),
                "exit_cells": _cells(raw["exit_cells"]),
"""), ("""        cost = leg["cells"][tier]
        price = reference["reference"] * (ONE - leg["w"] * cost)
""", """        cost = leg["exit_cells"][tier]
        price = reference["reference"] * (ONE - leg["w"] * cost)
""")],
}


# Power: each a defect positions.py could have, which the comparison must catch. Two it can't see: invalidation acting
# at close + δ rather than after the seal is the same hour; funding settling inside its reference's lag differs only in a
# mid-lag count of missing rows, which test_positions checks.
MUTANTS = {
    "the cheap cell includes nothing at $1000": [("abs(q) * ref <= 1000", "abs(q) * ref < 1000")],
    "a return of zero counts as a success": [("int(r > 0)", "int(r >= 0)")],
    "invalidation needs a loss beyond L": [("Fraction(0)) <= -p[\"L\"]", "Fraction(0)) < -p[\"L\"]")],
    "the cap excludes its own boundary": [("reserved + b <= CAP * e_r", "reserved + b < CAP * e_r")],
    "a cost cell ignores the side": [("side = \"buy\" if q > 0 else \"sell\"", "side = \"buy\"")],
    "entry needs no delay": [("if l[\"ref\"] is None and p[\"t_r\"] + DELTA <= h", "if l[\"ref\"] is None and p[\"t_r\"] <= h")],
    "an outcome enters without delay": [("first_open(bars, th[\"t_r\"] + DELTA, now)", "first_open(bars, th[\"t_r\"], now)")],
    "a discretionary exit acts at its request": [("e[\"t_x\"] + DELTA for e", "e[\"t_x\"] for e")],
    "the last discretionary exit wins": [("for e in reversed(exits)}", "for e in exits}")],
    "an exit at an entry's hour lets it enter": [("<= h < min(p[\"triggers\"].values())", "<= h <= min(p[\"triggers\"].values())")],
    "simultaneous exits take the first set": [("key=lambda kv: (kv[1], PRECEDENCE.index(kv[0]))", "key=lambda kv: kv[1]")],
    "simultaneous exits take their reasons in alphabetical order": [("PRECEDENCE.index(kv[0])", "kv[0]")],
    "a bar's close counts before it ends": [("c is not None and s + HOUR <= t", "c is not None and s + HOUR < t")],
    "funding is received, not paid": [("l[\"paid\"] += exact(rate)", "l[\"paid\"] -= exact(rate)")],
    "an outcome skips the exit hour's funding": [("range(e + HOUR, x + 1, HOUR)", "range(e + HOUR, x, HOUR)")],
    "an outcome ignores missing funding": [("            if h not in rates:\n                return None", "            if h not in rates:\n                continue")],
    "an hour reconciles before its reference": [("h + self.lag.get(l[\"market\"], 0) <= known and", "h <= known and")],
    "an hour reconciles without its funding": [("(not l[\"open\"] or h in funding.get(l[\"market\"], {}))", "True")],
    "reservations are never released": [("for p in self.live.values()), Fraction(0))", "for p in self.positions.values()), Fraction(0))")],
}


def patched(module, patches, name):
    """`module` with each (old, new) applied once to its source."""
    source = Path(module.__file__).read_text()
    for old, new in patches:
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    out = types.ModuleType(name)
    exec(compile(source, name, "exec"), out.__dict__)
    return out


def with_readings(names=tuple(READINGS)):
    """GPT's module with the named readings applied to its source."""
    return patched(gpt_positions, [p for n in names for p in READINGS[n]], "gpt_positions_as_read")


approved = with_readings()


class Scenario:
    def __init__(self, seed, costs=False, gaps=False, holes=False, funding_holes=False, builder=False, exits=False, outages=False):
        rng = random.Random(seed)
        self.markets = MARKETS if builder else CORE
        self.bars, self.funding = {}, {}
        for m in self.markets:
            px, opens = rng.choice([50.0, 100.0, 200.0]), []
            out = rng.randrange(HOURS) if outages else 0
            out = range(out, out + rng.randint(50, 300)) if outages else ()
            for h in range(HOURS + 1):
                px = max(1.0, round(px * (1 + rng.choice([-0.04, -0.01, 0.0, 0.01, 0.04])), 2))
                opens.append(None if h in out or (holes and rng.random() < 0.05) else px)
            if m in BUILDER:
                self.bars[m] = {h * HOUR: (opens[h], opens[h + 1] if h < HOURS else None) for h in range(HOURS + 1) if opens[h] is not None}
            else:
                self.bars[m] = {h * HOUR: (opens[h], round(opens[h] * (1 + (rng.choice([-0.03, 0.03]) if gaps else 0.0)), 2)
                                           if opens[h + 1] is None or gaps else opens[h + 1])
                                for h in range(HOURS) if opens[h] is not None}
            self.funding[m] = {h * HOUR: rng.choice([0.0, 1e-4, -1e-4, 5e-4]) for h in range(HOURS + 1)
                               if not (funding_holes and rng.random() < 0.01)}
        side = lambda: {"1000": rng.choice([1, 2, 5]), "10000": rng.choice([3, 8, 12])} if costs else {"1000": 0, "10000": 0}
        self.cells = {m: {"buy": side(), "sell": side()} for m in self.markets}
        self.fee = 0.00035 if costs else 0.0
        self.requests = []
        t = 2 * HOUR
        for i in range(rng.randint(1, 9)):
            t += rng.randint(1, 30 * HOUR // len(self.markets))
            if rng.random() < 0.3:
                t = max(t, t // HOUR * HOUR + rng.choice([0, 1, DELTA - 1, DELTA, WINDOW - 1, WINDOW]))
            k = rng.choice([1, 1, 2])
            names = rng.sample(self.markets, k)
            legs = [[names[0], rng.choice([1, -1])]] if k == 1 else [[names[0], 1], [names[1], -1]]
            T = (t // DAY + rng.randint(4, 12)) * DAY
            self.requests.append({"id": f"t{i}", "t_r": t, "legs": legs, "T": T, "L": rng.choice([0.01, 0.02, 0.05, 0.1, 0.5]), "p": 0.5})
        self.exits = sorted(({"id": r["id"], "time": r["t_r"] + rng.randint(1, 72 * HOUR)} for r in self.requests for _ in range(2)
                             if exits and rng.random() < 0.3), key=lambda e: e["time"])
        self.t_end = HOURS * HOUR
        self.rng = rng

    def ours_data(self, now):
        """The track's data as of `now` (s): an open known at its lag (δ or the seal), and a close at its own."""
        bars = {}
        for m, rows in self.bars.items():
            bars[m] = positions.Bars({
                h * 1000: (o, c if h + HOUR + LAG[m] <= now else None) for h, (o, c) in rows.items()
                if h + LAG[m] <= now})
        return {"bars": bars, "lag": {m: LAG[m] * 1000 for m in self.markets},
                "funding": {m: {h * 1000: r for h, r in rows.items() if h <= now} for m, rows in self.funding.items()}}

    def gpt_data(self):
        return {"bars": self.bars, "funding": self.funding, "lag": {m: LAG[m] for m in self.markets}, "terms": {}, "U": []}

    def ours_thesis(self, r, sized):
        return {"id": r["id"], "t_r": r["t_r"] * 1000, "legs": r["legs"], "T": r["T"] * 1000, "L": r["L"], "p": r["p"],
                "fee": self.fee, "costs": {m: self.cells[m] for m, _ in r["legs"]}, "N": sized["N"], "size": sized["size"], "b": sized["b"]}

    def gpt_thesis(self, r, sized):
        def rates(m, side):
            return {k: Fraction(v, 10_000) for k, v in self.cells[m][side].items()}
        return {"id": r["id"], "t_r": r["t_r"], "T": r["T"], "L": r["L"], "p": r["p"], "N": sized["N"], "size": sized["size"],
                "b": sized["b"], "legs": [{"market": m, "w": w, "fee": self.fee, "cost_fallback": False,
                                           "cells": rates(m, "buy" if w > 0 else "sell"), "exit_cells": rates(m, "sell" if w > 0 else "buy")}
                                          for m, w in r["legs"]]}

    def ours_exits(self, now):
        return [{"id": e["id"], "t_x": e["time"] * 1000} for e in self.exits if e["time"] <= now]

    def gpt_exits(self):
        return [{**e, "reason": "x"} for e in self.exits]


def compare(s, gpt=approved, seen=None, data=None, code=positions):
    """Every disagreement of the two implementations on scenario `s`: sizing at each registration, reservations and sizing
    equity at the boundaries of each release, then each thesis's fills, reason, outcome and returns, and the hourly equity,
    once every price is known. `seen` collects the cases reached; `data(now)` replaces the synthetic as-of prices; `code`
    replaces positions.py."""
    seen = set() if seen is None else seen
    data = data or s.ours_data
    diffs, ours, theirs = [], [], []
    initial = {"time": 0, "cash": 10_000}

    def latest(now, known):
        return gpt.replay(initial, known, [e for e in s.gpt_exits() if e["time"] <= now], s.gpt_data(), now)["account"]

    for r in s.requests:
        now = r["t_r"]
        mine = code.admit(10_000.0, ours, s.ours_exits(now), data(now), now * 1000, r["L"])
        his = gpt.admit(initial, theirs, [e for e in s.gpt_exits() if e["time"] <= now], s.gpt_data(), now, r["L"])
        for k in ("N", "size", "b"):
            if mine[k] != his[k]:
                diffs.append(("admit", r["id"], k, float(mine[k]), float(his[k])))
        ours.append(s.ours_thesis(r, mine))
        theirs.append(s.gpt_thesis(r, his))
    now = s.t_end + HOUR + WINDOW
    acct, out, equity, _ = code.replay(10_000.0, ours, s.ours_exits(now), data(now), now * 1000, hourly=True)
    report = gpt.replay(initial, theirs, s.gpt_exits(), s.gpt_data(), now)
    released = sorted({th["reservation_released_at"] for th in report["theses"] if th["reservation_released_at"] is not None})
    for t in s.rng.sample(released, min(3, len(released))):
        for at in (t - 1, t):
            booked = [th for th in ours if th["t_r"] <= at * 1000]
            asof, _, _, _ = code.replay(10_000.0, booked, s.ours_exits(at), data(at), at * 1000)
            his = latest(at, [th for th in theirs if th["t_r"] <= at])["reserved_risk"]
            if asof.reserved() != his:
                diffs.append(("reserved", at, float(asof.reserved()), float(his)))
            seen.add("release boundary")
    for th in report["theses"]:
        i, mine = th["id"], out[th["id"]]
        reg = th["as_registered"]
        seen |= {"size zero"} if th["size"] == 0 else set()
        seen |= {"unresolved"} if reg["outcome"] is None else {f"outcome {reg['outcome']}"}
        o = mine["outcome"]
        if (o and o["o"]) != reg["outcome"] and not (o is None and reg["outcome"] is None):
            diffs.append(("outcome", i, o and o["o"], reg["outcome"]))
        if (o and o["R_net"]) != (reg["return"] if reg["return"] is None else float(reg["return"])):
            diffs.append(("R_net", i, o and o["R_net"], reg["return"] and float(reg["return"])))
        if th["size"] == 0 or i not in acct.positions:
            continue
        p, man = acct.positions[i], th["managed"]
        seen |= {g["exit"]["reason"] for g in man["legs"] if g["exit"]}
        seen |= {"suppressed leg" for g in man["legs"] if g.get("pending_entry_suppressed")}
        seen |= {"spread" for g in man["legs"][1:]}
        seen |= {"missing funding" for r in man["reasons"] if "missing_funding" in r}
        managed = p["pnl"] / p["N"] if mine["managed_return"] is not None else None
        if managed != man["return"]:
            diffs.append(("managed", i, mine["managed_return"], man["return"] and float(man["return"]), man["reasons"]))
        for l, g in zip(p["legs"], man["legs"]):
            e, x = g["entry"], g["exit"]
            if (l["t"] / 1000 if l["ref"] is not None else None) != (e and e["time"]):
                diffs.append(("entry", i, l["market"], l["ref"] is not None and l["t"] / 1000, e and e["time"]))
            elif e and (l["ref"], l["q"], l["fill"]) != (e["reference"], e["quantity"], e["price"]):
                diffs.append(("entry fill", i, l["market"], float(l["q"]), float(e["quantity"]), float(l["fill"]), float(e["price"])))
            lx = l["exit"]
            if (lx and lx["t"] / 1000) != (x and x["time"]):
                diffs.append(("exit", i, l["market"], lx and lx["t"] / 1000, x and x["time"]))
            elif x and lx and (lx["ref"], lx["fill"]) != (float(x["reference"]), float(x["price"])):
                diffs.append(("exit fill", i, l["market"], lx["ref"], float(x["reference"]), lx["fill"], float(x["price"])))
        if mine["exit"] and man["legs"] and any(g["exit"] for g in man["legs"]):
            reason = next(g["exit"]["reason"] for g in man["legs"] if g["exit"])
            if mine["exit"]["reason"] != reason:
                diffs.append(("reason", i, mine["exit"]["reason"], reason))
    hourly = {row["time"]: row["equity"] for row in report["account"]["hourly"]}
    for h, e, r in equity:
        if e != r:
            diffs.append(("our books", h, float(e), float(r)))
        if e != hourly.get(h // 1000):
            diffs.append(("hourly equity", h, float(e), hourly.get(h // 1000) and float(hourly[h // 1000])))
    if (equity[-1][1] if equity else 10_000) != report["account"]["latest_reconciled"]["equity"]:
        diffs.append(("equity", float(equity[-1][1]) if equity else 10_000, float(report["account"]["latest_reconciled"]["equity"])))
    seen |= {"hourly equity"} if equity else set()
    return diffs


CLASSES = {
    "plain": {},
    "exits": {"exits": True},
    "costs": {"costs": True, "exits": True},
    "gaps": {"gaps": True, "exits": True},
    "holes": {"holes": True, "exits": True},
    "funding_holes": {"funding_holes": True, "exits": True},
    "builder": {"builder": True, "exits": True},
    "outages": {"outages": True, "builder": True, "exits": True},
    "everything": {"costs": True, "gaps": True, "holes": True, "funding_holes": True, "builder": True, "exits": True, "outages": True},
}


@pytest.mark.slow
@pytest.mark.parametrize("name", CLASSES)
def test_the_two_implementations_agree_as_read(name):
    seen = set()
    diffs = [(seed, d) for seed in range(SETS) for d in compare(Scenario(seed, **CLASSES[name]), seen=seen)]
    assert not diffs, diffs[:5]
    assert {"horizon", "invalidation", "size zero", "spread", "outcome 0", "outcome 1", "hourly equity", "release boundary"} <= seen
    assert name == "plain" or "discretionary" in seen
    assert name not in ("outages", "everything") or {"suppressed leg", "unresolved"} <= seen
    assert name not in ("funding_holes", "everything") or "missing funding" in seen


def fixed(bars, requests, exits=(), fee=0.0, cells=None, funding=None, rates=None):
    """A Scenario of given prices: funding zero at each hour unless `funding` sets or (None) removes it."""
    s = Scenario.__new__(Scenario)
    s.markets = tuple(bars)
    s.bars = bars
    s.funding = {m: {k: v for k, v in ({h * HOUR: 0.0 for h in range(HOURS + 1)} | (funding or {}).get(m, {})).items() if v is not None} for m in bars}
    plain = {"1000": 0, "10000": 0}
    s.cells = {m: {"buy": cells or plain, "sell": cells or plain} for m in bars}
    s.fee, s.requests, s.exits, s.t_end, s.rng = fee, requests, list(exits), HOURS * HOUR, random.Random(0)
    return s


def flat(price, **at):
    rows = {h * HOUR: (price, price) for h in range(HOURS)}
    for k, v in at.items():
        rows[int(k[1:]) * HOUR] = v
    return rows


def req(i, t_r, legs, L=0.1, T=10):
    return {"id": i, "t_r": t_r, "legs": legs, "T": T * DAY, "L": L, "p": 0.5}


T_R = 10 * HOUR + 1800
LONG = [["A", 1]]
ONE_BP = {"1000": 1, "10000": 8}
LAG_POSITION = req("a", T_R, [["A", 1]])
BOUNDARIES = {
    "a return of exactly zero, with a fee and one leg": fixed(
        {"A": flat(100.0, h11=(99.9450045, 99.9450045), h240=(100.0550045, 100.0550045))}, [req("a", T_R, LONG, L=0.2)], fee=0.00045, cells=ONE_BP),
    "a notional of exactly $1000": fixed({"A": flat(50.36)}, [req("a", T_R, LONG)], cells=ONE_BP),
    "a notional just above $1000": fixed({"A": flat(100.0, h240=(100.2, 100.2))}, [req("a", T_R, LONG, L=0.09999999999995)], fee=0.00045, cells=ONE_BP),
    "a loss of exactly L": fixed({"A": flat(118.9, h12=(118.9, 130.79))}, [req("a", T_R, [["A", -1]])]),
    "a loss just short of L": fixed({"A": flat(100.0, h12=(100.0, 110.0))}, [req("a", T_R, [["A", -1]], L=0.10000000000005)]),
    "five reservations at exactly the cap": fixed({"A": flat(7.0)}, [req(f"t{i}", T_R, LONG) for i in range(6)]),
    **{f"a registration {offset} s into hour 30, core": fixed(
        {"A": flat(100.0, h30=(110.0, 110.0))}, [req("a", T_R, LONG), req("b", 30 * HOUR + offset, LONG, T=12)],
        funding={"A": {30 * HOUR: 0.001}}) for offset in (0, 1, DELTA - 1, DELTA, DELTA + 1)},
    **{f"a registration {offset} s into hour 30, builder": fixed(
        {"xyz:C": flat(100.0, h30=(110.0, 110.0))}, [req("a", T_R, [["xyz:C", 1]]), req("b", 30 * HOUR + offset, [["xyz:C", 1]], T=12)],
        funding={"xyz:C": {30 * HOUR: 0.001}}) for offset in (0, 1, WINDOW - 1, WINDOW, WINDOW + 1)},
    **{f"a registration {offset} s into hour 30, mixed spread": fixed(
        {"A": flat(100.0, h30=(110.0, 110.0)), "xyz:C": flat(100.0, h30=(90.0, 90.0))},
        [req("a", T_R, [["A", 1], ["xyz:C", -1]]), req("b", 30 * HOUR + offset, LONG, T=12)],
        funding={"A": {30 * HOUR: 0.001}, "xyz:C": {30 * HOUR: 0.002}}) for offset in (DELTA - 1, DELTA, WINDOW - 1, WINDOW)},
    "a missing funding row, then a registration": fixed(
        {"A": flat(100.0, h31=(110.0, 110.0))}, [req("a", T_R, LONG), req("b", 50 * HOUR, LONG, T=12)], funding={"A": {30 * HOUR: None}}),
    "funding at a missing core bar": fixed(
        {"A": {k: v for k, v in flat(100.0, h29=(100.0, 120.0)).items() if k != 30 * HOUR}}, [req("a", T_R, LONG)], funding={"A": {30 * HOUR: 0.001}}),
    "a horizon on a missing bar": fixed(
        {"A": {k: v for k, v in flat(100.0).items() if k != 240 * HOUR}}, [req("a", T_R, LONG)]),
    "a spread whose second leg never enters": fixed(
        {"A": flat(100.0), "xyz:C": {h * HOUR: (100.0, 100.0) for h in range(20)}}, [req("a", 25 * HOUR, [["A", 1], ["xyz:C", -1]]), req("b", 241 * HOUR, LONG, T=15)]),
    "two discretionary exits": fixed(
        {"A": flat(100.0)}, [req("a", T_R, LONG)], exits=[{"id": "a", "time": 20 * HOUR}, {"id": "a", "time": 30 * HOUR}]),
    "a discretionary exit as the horizon acts": fixed(
        {"A": flat(100.0)}, [req("a", T_R, LONG)], exits=[{"id": "a", "time": 240 * HOUR - DELTA}]),
    "a discretionary exit as an invalidation acts": fixed(
        {"A": flat(100.0, h20=(100.0, 89.0))}, [req("a", T_R, LONG)], exits=[{"id": "a", "time": 21 * HOUR}]),
    "a spread's unentered leg with a bar at the horizon": fixed(
        {"A": {k: v for k, v in flat(100.0).items() if k != 240 * HOUR}, "xyz:C": {h * HOUR: (100.0, 100.0) for h in range(240, HOURS)}},
        [req("a", T_R, [["A", 1], ["xyz:C", -1]])]),
}


@pytest.mark.parametrize("case", BOUNDARIES)
def test_the_two_implementations_agree_on_each_boundary_as_read(case):
    assert compare(BOUNDARIES[case]) == []


def production_data(s, root):
    """`s`'s prices as Market serves them from a venue holding them, read through Track.data."""
    class Venue:
        def candles(self, market, interval, start, end):
            return [{"t": h * 1000, "o": str(o), "c": str(c)} for h, (o, c) in s.bars[market].items() if start <= h * 1000 < end]

        def funding(self, market, start, end):
            return [{"time": h * 1000, "fundingRate": str(r)} for h, r in s.funding[market].items() if start <= h * 1000 < end]

    m = market_module.Market(root, Venue(), repair_every=0)
    for name in s.markets:
        if market_module.builder(name):
            for h, (o, _) in s.bars[name].items():
                t = h * 1000
                append(root / "marks", "marks", t, {"sent": t + 5_000, "recv": t + 6_000, "dex": name.split(":")[0], "marks": {name: o}})
    track = runner.Track.__new__(runner.Track)
    track.market = m
    return lambda now: runner.Track.data(track, s.markets, now * 1000)


@pytest.mark.parametrize("name", [
    pytest.param(name, marks=pytest.mark.slow) if name in {"plain", "outages"} else name for name in CLASSES
])
def test_the_production_adapter_gives_the_same_prices_and_the_same_agreement(name):
    for seed in range(PRODUCTION_SETS):
        s = Scenario(seed, **CLASSES[name])
        with tempfile.TemporaryDirectory() as root:
            data = production_data(s, Path(root))
            for now in (r["t_r"] for r in s.requests):
                view = data(now)
                synthetic = s.ours_data(now)
                assert view["bars"] == synthetic["bars"] and view["funding"] == synthetic["funding"] and view["lag"] == synthetic["lag"]
            assert compare(s, data=data) == []


def raw_disagreements(name, sets=SETS):
    """{kind of difference: count} of positions.py against GPT's file untouched, on one class. Its entry tier can have no
    fixed point (its docstring's choice 5), which leaves a fill to compare with none."""
    raw, kinds = with_readings(()), {}
    for seed in range(sets):
        try:
            diffs = compare(Scenario(seed, **CLASSES[name]), gpt=raw)
        except KeyError:
            diffs = [("no fixed point",)]
        for d in diffs:
            kinds[d[0]] = kinds.get(d[0], 0) + 1
    return name, kinds


@pytest.mark.parametrize("reading", READINGS)
def test_every_reading_is_needed_on_some_scenario(reading):
    """A reading no scenario needs would claim a disagreement that is not there."""
    without = with_readings([r for r in READINGS if r != reading])
    assert any(compare(Scenario(seed, **CLASSES["everything"]), gpt=without) for seed in range(40))


def mutant_catches(name, sets=PRODUCTION_SETS, first=False):
    """How many boundary cases and scenario sets catch mutant `name`, by a disagreement or an error (with `first`, 0 or 1)."""
    code, found = patched(positions, MUTANTS[name], "positions_mutant"), 0
    cases = [*BOUNDARIES.values(), *(Scenario(seed, **flags) for flags in CLASSES.values() for seed in range(sets))]
    for s in cases:
        try:
            found += bool(compare(s, code=code))
        except Exception:
            found += 1
        if found and first:
            break
    return name, found


@pytest.mark.parametrize("name", [
    pytest.param(name, marks=pytest.mark.slow) if name in {
        "a cost cell ignores the side", "entry needs no delay", "a discretionary exit acts at its request",
        "an outcome ignores missing funding", "an hour reconciles before its reference", "an hour reconciles without its funding",
    } else name for name in MUTANTS
])
def test_every_mutant_is_caught(name):
    assert mutant_catches(name, first=True)[1]


def test_the_raw_comparison_stays_a_real_disagreement():
    """GPT's own file disagrees with the code: raw agreement would mean the readings had become obsolete."""
    assert raw_disagreements("costs", 5)[1]


if __name__ == "__main__":
    with ProcessPoolExecutor() as pool:
        for name, kinds in pool.map(raw_disagreements, CLASSES):
            print(name, dict(sorted(kinds.items())))
        total = len(BOUNDARIES) + len(CLASSES) * PRODUCTION_SETS
        for name, found in pool.map(mutant_catches, MUTANTS):
            print(f"{name}: {found} of {total}")
