"""thesis/positions.py against GPT's independent implementation from the stage 10 criteria alone (gpt_positions.py).

Each scenario class turns on what could make the two disagree. `READINGS` names every place the criteria left GPT a
choice that thesis/SCORING.md or the track's data shape settles otherwise; each is applied to GPT's module here, never
in its file, and audit/reviews/2026-11-02-thesis-bundle.md says why. Everything else must agree exactly: identifiers,
times, reasons and outcomes, money within 1e-9.
"""

import random
import types
from fractions import Fraction
from pathlib import Path

import pytest

from thesis import positions
from thesis.tests import gpt_positions

HOUR, DAY, DELTA, WINDOW = 3600, 86400, 120, 300
HOURS = 600
CORE, BUILDER = ("A", "B"), ("xyz:C",)
MARKETS = CORE + BUILDER
LAG = {"A": DELTA, "B": DELTA, "xyz:C": WINDOW}
SETS = 150
READINGS = {
    # SCORING.md's "q = w N / open(e)": the quantity and R_gross's P_e are the open, and the cost is only in the fill.
    "the quantity comes from the open": ("""unit_q = Fraction(leg["w"]) / price""", """unit_q = Fraction(leg["w"]) / reference["reference"]"""),
    "R_gross's entry price is the open": ("""/ entry["price"] - ONE""", """/ entry["reference"] - ONE"""),
    # SCORING.md's mark: with the hour's bar missing, the last bar's close, not its open.
    "a funding mark after a missing bar is the last close": ("""        reference = self.bars[market][selected][0]
""", """        opening, closing = self.bars[market][selected]
        reference = closing if closing is not None and selected + HOUR <= timestamp else opening
"""),
    # "Until its position is fully closed": a leg with no bar by its exit will never enter, so it holds nothing up.
    "a leg that can no longer enter holds no reservation": ("""    if thesis["size"] > 0 and all(path["exit"] is not None for path in paths):
        released = max(path["exit"]["available_at"] for path in paths)
""", """    if thesis["size"] > 0 and all(path["exit"] is not None or (path["entry"] is None and action["threshold"] <= now) for path in paths):
        released = max(path["exit"]["available_at"] if path["exit"] else -(-action["threshold"] // HOUR) * HOUR for path in paths)
"""),
}


def read_as_scored():
    """GPT's module with READINGS applied to its source."""
    source = (Path(gpt_positions.__file__)).read_text()
    for old, new in READINGS.values():
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    module = types.ModuleType("gpt_positions_as_scored")
    exec(compile(source, "gpt_positions_as_scored", "exec"), module.__dict__)
    return module


gpt = read_as_scored()


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
                self.bars[m] = {h * HOUR: (opens[h], opens[h + 1]) for h in range(HOURS) if opens[h] is not None}
            else:
                self.bars[m] = {h * HOUR: (opens[h], round(opens[h] * (1 + (rng.choice([-0.03, 0.03]) if gaps else 0.0)), 2)
                                           if opens[h + 1] is None or gaps else opens[h + 1])
                                for h in range(HOURS) if opens[h] is not None}
            self.funding[m] = {h * HOUR: rng.choice([0.0, 1e-4, -1e-4, 5e-4]) for h in range(HOURS + 1)
                               if not (funding_holes and rng.random() < 0.01)}
        self.cells = {m: {"1000": rng.choice([1, 2, 5]), "10000": rng.choice([3, 8, 12])} if costs else {"1000": 0, "10000": 0}
                      for m in self.markets}
        self.fee = 0.00035 if costs else 0.0
        self.requests = []
        t = 2 * HOUR
        for i in range(rng.randint(1, 9)):
            t += rng.randint(1, 30 * HOUR // len(self.markets))
            t += WINDOW - t % HOUR if t % HOUR < WINDOW else 0
            k = rng.choice([1, 1, 2])
            names = rng.sample(self.markets, k)
            legs = [[names[0], rng.choice([1, -1])]] if k == 1 else [[names[0], 1], [names[1], -1]]
            T = (t // DAY + rng.randint(4, 12)) * DAY
            self.requests.append({"id": f"t{i}", "t_r": t, "legs": legs, "T": T, "L": rng.choice([0.01, 0.02, 0.05, 0.1, 0.5]), "p": 0.5})
        self.exits = sorted(({"id": r["id"], "time": r["t_r"] + rng.randint(1, 72 * HOUR)} for r in self.requests
                             if exits and rng.random() < 0.4), key=lambda e: e["time"])
        self.t_end = HOURS * HOUR

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
                "fee": self.fee, "costs": {m: {"buy": self.cells[m], "sell": self.cells[m]} for m, _ in r["legs"]},
                "N": float(sized["N"]), "size": float(sized["size"]), "b": float(sized["b"])}

    def gpt_thesis(self, r, sized):
        return {"id": r["id"], "t_r": r["t_r"], "T": r["T"], "L": r["L"], "p": r["p"], "N": sized["N"], "size": sized["size"],
                "b": sized["b"], "legs": [{"market": m, "w": w, "fee": self.fee, "cost_fallback": False,
                                           "cells": {k: Fraction(v, 10_000) for k, v in self.cells[m].items()}}
                                          for m, w in r["legs"]]}

    def ours_exits(self, now):
        return [{"id": e["id"], "t_x": e["time"] * 1000} for e in self.exits if e["time"] <= now]

    def gpt_exits(self):
        return [{**e, "reason": "x"} for e in self.exits]


def close(a, b, tol=1e-9):
    if a is None or b is None:
        return a is None and b is None
    return abs(float(a) - float(b)) <= tol * max(1.0, abs(float(a)))


def compare(s, seen=None):
    """Every disagreement of the two implementations on scenario `s`: sizing at each registration, then each thesis's
    legs, reason and returns and the account's equity once every price is known. `seen` collects the cases reached."""
    seen = set() if seen is None else seen
    diffs, ours, theirs = [], [], []
    initial = {"time": 0, "cash": 10_000}
    for r in s.requests:
        now = r["t_r"]
        data = s.ours_data(now)
        mine = positions.admit(10_000.0, ours, s.ours_exits(now), data, now * 1000, r["L"])
        his = gpt.admit(initial, theirs, [e for e in s.gpt_exits() if e["time"] <= now], s.gpt_data(), now, r["L"])
        for k in ("N", "size", "b"):
            if not close(mine[k], his[k], 1e-9):
                diffs.append(("admit", r["id"], k, mine[k], float(his[k])))
        sized = his
        ours.append(s.ours_thesis(r, sized))
        theirs.append(s.gpt_thesis(r, sized))
    now = s.t_end + HOUR + WINDOW
    acct, out, equity, _ = positions.replay(10_000.0, ours, s.ours_exits(now), s.ours_data(now), now * 1000)
    report = gpt.replay(initial, theirs, s.gpt_exits(), s.gpt_data(), now)
    for th in report["theses"]:
        i, mine = th["id"], out[th["id"]]
        reg = th["as_registered"]
        seen |= {"size zero"} if th["size"] == 0 else set()
        seen |= {"unresolved"} if reg["outcome"] is None else {f"outcome {reg['outcome']}"}
        o = mine["outcome"]
        if (o and o["o"]) != reg["outcome"] and not (o is None and reg["outcome"] is None):
            diffs.append(("outcome", i, o and o["o"], reg["outcome"]))
        if not close(o and o["R_net"], reg["return"]):
            diffs.append(("R_net", i, o and o["R_net"], reg["return"] and float(reg["return"])))
        if th["size"] == 0:
            continue
        p, man = acct.positions[i], th["managed"]
        seen |= {g["exit"]["reason"] for g in man["legs"] if g["exit"]}
        seen |= {"suppressed leg" for g in man["legs"] if g.get("pending_entry_suppressed")}
        seen |= {"spread" for g in man["legs"][1:]}
        seen |= {"missing funding" for r in man["reasons"] if "missing_funding" in r}
        if not close(mine["managed_return"], man["return"]):
            diffs.append(("managed", i, mine["managed_return"], man["return"] and float(man["return"]), man["reasons"]))
        for l, g in zip(p["legs"], man["legs"]):
            e, x = g["entry"], g["exit"]
            if (l["t"] / 1000 if l["ref"] is not None else None) != (e and e["time"]):
                diffs.append(("entry", i, l["market"], l["ref"] is not None and l["t"] / 1000, e and e["time"]))
            lx = l["exit"]
            if (lx and lx["t"] / 1000) != (x and x["time"]):
                diffs.append(("exit", i, l["market"], lx and lx["t"] / 1000, x and x["time"]))
            if x and lx and float(x["reference"]) != lx["ref"]:
                diffs.append(("exit ref", i, l["market"], lx["ref"], float(x["reference"])))
        if mine["exit"] and man["legs"] and any(g["exit"] for g in man["legs"]):
            reason = next(g["exit"]["reason"] for g in man["legs"] if g["exit"])
            if mine["exit"]["reason"] != reason:
                diffs.append(("reason", i, mine["exit"]["reason"], reason))
    theirs_eq = report["account"]["latest_reconciled"]
    if not close(acct.sizing_equity(now * 1000), theirs_eq["equity"]):
        diffs.append(("equity", acct.sizing_equity(now * 1000), theirs_eq["time"], float(theirs_eq["equity"])))
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


@pytest.mark.parametrize("name", CLASSES)
def test_the_two_implementations_agree(name):
    seen = set()
    diffs = [(seed, d) for seed in range(SETS) for d in compare(Scenario(seed, **CLASSES[name]), seen)]
    assert not diffs, diffs[:5]
    assert {"horizon", "invalidation", "size zero", "spread", "outcome 0", "outcome 1"} <= seen
    assert name == "plain" or "discretionary" in seen
    assert name not in ("outages", "everything") or {"suppressed leg", "unresolved"} <= seen
    assert name not in ("funding_holes", "everything") or "missing funding" in seen
