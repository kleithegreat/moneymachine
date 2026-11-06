"""B3 draft: C7.6's resolver suite, for the resolver and the case format of the RULES.md revision in rules-revision.md
(§6 and §7), which is the whole contract: an implementer reads that, never this file. Not frozen; it replaces
kernel/tests/rules/resolver_suite.py once reviewed.

- HAND: hand-computed cases. Keys and entries of an expected result are written here without their cells and role
  payloads, which `case` adds from the entry's own revision (none on a retraction).
- generate(resolve): the shortest prefix of `stream()`'s stores, from a fixed seed and without expected results (the
  implementations must agree), whose results under `resolve` reach C7.6's size, SIZE pairs as `delivered` counts them
  (its home is C7.6's revision, `c76-revision.md`). `classes` names what a store's inputs exercise and `reached` what a
  result shows; a frozen suite has at least FLOOR stores in each of CLASSES and, over Lean's results (`lean_check.py`),
  REACHED.
"""

import json
import random
from collections import Counter

from ingest.knownat import Malformed, evaluate, parse
from kernel.tests.rules.suite import D, H, HI, LO, add, dep, f, mx, rule

BAR = rule(add(f("eventTime"), {"ms": D}))
LATE = rule(add(f("eventTime"), {"ms": 100 * H}))
REP = rule(mx(add(f("eventTime"), {"ms": D}), f("reportedTime")))
SEEN = rule(mx(f("observed"), f("fetchedAt")))
RECV = rule(mx(f("recv"), f("fetchedAt")))
COUNT = rule(mx(f("eventTime"), dep("recording")))
LAG = 1000


def src(name, r=BAR, times=("eventTime",), values=("close",), entity=("coin",), event="eventTime", slot=None,
        evidence=False, deps=(), roles=None):
    return {"name": name, "rule": r, "times": list(times), "values": list(values), "entity": list(entity),
            "event": event, "slot": slot, "roles": roles, "evidence": evidence, "deps": list(deps)}


BARS = src("bars")
REPORTED = src("bars", REP, times=("eventTime", "reportedTime"))
SIGHT = src("sight", SEEN, times=("observed", "created"), values=(), entity=("host", "id"), event="observed",
            evidence=True)
POLL = src("poll", RECV, times=("recv",), values=(), entity=("host",), event="recv", evidence=True)
EVENTS = src("events", COUNT, values=("count",), slot="slot",
             deps=({"name": "recording", "sources": ["sight", "poll"], "lag": LAG},))
UP = src("up", rule(add(f("observed"), {"ms": 100 * H})), times=("observed",), values=(), entity=("host",),
         event="observed", evidence=True)
OHLC = src("bars", values=(), roles={"bars": ["open", "high", "low", "close", "trades"]})
RATES = src("rates", values=(), roles={"settlement": ["rate"]})
METADATA = {"fetchedAt", "tombstone", "upstream", "source", "hash", "knownAt"}


def rev(source, fetched, cells, tombstone=False, upstream=None):
    text = cells if isinstance(cells, str) else json.dumps(cells)
    return {"source": source, "fetchedAt": fetched, "tombstone": tombstone, "cells": text,
            "upstream": upstream if isinstance(upstream, str) else json.dumps(upstream or {})}


def role_columns(s):
    return next(iter(s["roles"].values())) if s["roles"] else []


def declared(s):
    return sorted(set(s["values"] + s["times"] + s["entity"] + [s["event"]] + ([s["slot"]] if s["slot"] else [])
                      + role_columns(s)))


def order(cell):
    """A cell's place in §7's order; equal exactly for equal cells (an integer is never a non-integer, the two zeros
    one value)."""
    return [order(c) for c in cell] if isinstance(cell, list) else (
        (0,) if cell is None else (1, cell) if isinstance(cell, bool) else (2, cell) if isinstance(cell, int)
        else (3, cell + 0.0) if isinstance(cell, float) else (4, cell))


def ident(cells):
    return json.dumps(order(cells))


def stored(rows, s, k, fetched):
    """Key k's revision fetched at `fetched`, in a store that resolves: its row and decoded cells."""
    return next((r, cells) for r in rows
                if r["source"] == s["name"] and r["fetchedAt"] == fetched for cells in [json.loads(r["cells"])]
                if ident([cells.get(x) for x in s["entity"]]) == ident(k["entity"])
                and cells.get(s["event"]) == k["event"])


def case(sources, rows, version, queries, expect, universe=("BTC", "ETH")):
    if isinstance(expect, dict):
        by = {s["name"]: s for s in sources}
        for k in expect["keys"]:
            s = by[k["source"]]
            for e in k["timeline"]:
                cells = stored(rows, s, k, e[0])[1]
                e[4:] = [None, None] if e[2] else [{x: cells.get(x) for x in declared(s)},
                                                   [cells.get(x) for x in role_columns(s)] if s["roles"] else None]
        expect["keys"].sort(key=lambda k: (k["source"], order(k["entity"]), k["event"]))
    return {"universe": list(universe), "sources": list(sources), "rows": rows, "version": version,
            "queries": list(queries), "expect": expect}


def key(source, entity, event, coin, timeline, visible):
    return {"source": source, "entity": list(entity), "event": event, "coin": coin,
            "timeline": [list(e) + [None] * (4 - len(e)) for e in timeline], "visible": list(visible)}


E = 10 * H
K = E + D
F = 50 * H
b = lambda v, **extra: {"coin": "BTC", "eventTime": E, "close": v, **extra}
bars = lambda rows, version, queries, timeline, visible, sources=(BARS,): case(
    sources, rows, version, queries, {"keys": [key("bars", ["BTC"], E, 0, timeline, visible)]})

# Evidence and derived fixtures: hour E's count for BTC, recorded from host "h".
P = E + 5000  # a poll's receive time
s1 = lambda created=1, observed=E + 500, host="h", i=1: {"host": host, "id": i, "observed": observed,
                                                         "created": created}
poll = lambda fetched, recv=P, host="h": rev("poll", fetched, {"host": host, "recv": recv})
ev = lambda fetched, count, lineage, slot=E, tombstone=False: rev(
    "events", fetched, {"coin": "BTC", "eventTime": E, "count": count, "slot": slot}, tombstone, {"recording": lineage})
SK = ["sight", ["h", 1], E + 500]
PK = ["poll", ["h"], P]
derived = (SIGHT, POLL, EVENTS)
UK = ["up", ["a"], E]
up = lambda fetched: rev("up", fetched, {"host": "a", "observed": E})
over_up = (SIGHT, UP, src("events", COUNT, values=("count",), slot="slot",
                          deps=({"name": "recording", "sources": ["sight", "up"], "lag": LAG},)))
bar = lambda c=1.5, t=5, h=2: {"coin": "BTC", "eventTime": E, "open": 1, "high": h, "low": 0.5, "close": c, "trades": t}
rate = lambda r: {"coin": "BTC", "eventTime": E, "rate": r}
ohlc = lambda rows, version, queries, timeline, visible: bars(rows, version, queries, timeline, visible, (OHLC,))
rates = lambda rows, version, queries, timeline, visible: case(
    (RATES,), rows, version, queries, {"keys": [key("rates", ["BTC"], E, 0, timeline, visible)]})
EVENT = '{"coin": "BTC", "eventTime": %s, "close": 1}'
CLOSE = '{"coin": "BTC", "eventTime": 36000000, "close": %s}'

HAND = [
    # One revision, the cutoff, visibility at knownAt - 1, knownAt and + 1.
    bars([rev("bars", 100, b(1))], 100, [K - 1, K, K + 1], [[100, K, False]], [None, 100, 100]),
    case([BARS], [rev("bars", 100, b(1))], 99, [K], {"keys": []}),
    # An identical later revision adds nothing.
    bars([rev("bars", 100, b(1)), rev("bars", 200, b(1))], 200, [K], [[100, K, False]], [100]),
    # A correction is known at its fetchedAt; before it the earlier value stays visible (bitemporal), and a cutoff
    # before it never sees it.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(2))], F, [K, F - 1, F], [[100, K, False], [F, F, False]],
         [100, 100, F]),
    bars([rev("bars", 100, b(1)), rev("bars", F, b(2))], F - 1, [K, F], [[100, K, False]], [100, 100]),
    # Two revisions known at one time: the later wins the tie.
    bars([rev("bars", 100, b(1)), rev("bars", 200, b(2))], 200, [K - 1, K], [[100, K, False], [200, K, False]],
         [None, 200]),
    # Timeline order is fetchedAt order, never stored row order.
    bars([rev("bars", 200, b(2)), rev("bars", 100, b(1))], 200, [K], [[100, K, False], [200, K, False]], [200]),
    # An absent column is null: absent after a value is a correction, absent after null is not.
    bars([rev("bars", 100, b(1)), rev("bars", F, {"coin": "BTC", "eventTime": E})], F, [F],
         [[100, K, False], [F, F, False]], [F]),
    bars([rev("bars", 100, b(None)), rev("bars", F, {"coin": "BTC", "eventTime": E})], F, [F], [[100, K, False]],
         [100]),
    # Undeclared columns are never compared.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1, extra=5))], F, [F], [[100, K, False]], [100]),
    # Doubles compare as values: the two zeros are one value, each delivered with its own sign; 1.5 and 2.5 differ.
    bars([rev("bars", 100, b(0.0)), rev("bars", F, b(-0.0))], F, [F], [[100, K, False]], [100]),
    bars([rev("bars", 100, b(-0.0))], 100, [K], [[100, K, False]], [100]),
    bars([rev("bars", 100, b(1.5)), rev("bars", F, b(2.5))], F, [F], [[100, K, False], [F, F, False]], [F]),
    # A tombstone retracts from its fetchedAt, with no fallback; a later value is a new delivery.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True)], F, [K, F - 1, F, 10**15],
         [[100, K, False], [F, F, True]], [100, 100, None, None]),
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True), rev("bars", 60 * H, b(1))], 60 * H,
         [K, 55 * H, 60 * H], [[100, K, False], [F, F, True], [60 * H, 60 * H, False]], [100, None, 60 * H]),
    # A tombstone before any delivery adds nothing, and the revision after it is still known no earlier than its
    # fetchedAt (third revision of 2026-10-26).
    bars([rev("bars", 100, b(1), tombstone=True), rev("bars", F, b(1))], F, [K, F], [[F, F, False]], [None, F]),
    # A retraction is raised to the knownAt of what it replaces; the correction's own rule value is that time.
    case([src("bars", LATE)], [rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True)], F, [110 * H - 1, 110 * H],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, 110 * H, False], [F, 110 * H, True]], [None, None])]}),
    case([src("bars", LATE)], [rev("bars", 100, b(1)), rev("bars", F, b(2))], F, [110 * H],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, 110 * H, False], [F, 110 * H, False]], [F])]}),
    # A corrected rule over the same revisions; a rule reading fetchedAt.
    case([src("bars", rule(add(f("eventTime"), {"ms": D + 1000})))], [rev("bars", 100, b(1)), rev("bars", 200, b(1))],
         200, [K, K + 1000], {"keys": [key("bars", ["BTC"], E, 0, [[100, K + 1000, False]], [None, 100])]}),
    case([src("bars", rule(mx(add(f("eventTime"), {"ms": D}), f("fetchedAt"))))], [rev("bars", F, b(1))], F,
         [K, F], {"keys": [key("bars", ["BTC"], E, 0, [[F, F, False]], [None, F])]}),
    # A correction whose own rule value and fetchedAt are earlier is raised to the knownAt of what it replaces; so is a
    # rejected later evaluation, a retraction.
    bars([rev("bars", 100, b(1, reportedTime=E + 3 * H)), rev("bars", 200, b(2, reportedTime=E))], 200,
         [K, E + 3 * H - 1, E + 3 * H], [[100, E + 3 * H, False], [200, E + 3 * H, False]], [None, None, 200],
         sources=(REPORTED,)),
    bars([rev("bars", 100, b(1, reportedTime=E + 3 * H)), rev("bars", 200, b(1, reportedTime="x"))], 200,
         [K, E + 3 * H], [[100, E + 3 * H, False], [200, E + 3 * H, True]], [None, None], sources=(REPORTED,)),
    # A rejected first evaluation adds nothing (the key has no delivery); a rejected later one retracts.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1, reportedTime=E))], F, [K, F], [[F, F, False]], [None, F],
         sources=(REPORTED,)),
    bars([rev("bars", 100, b(1, reportedTime=E)), rev("bars", F, b(1))], F, [K, F],
         [[100, K, False], [F, F, True]], [100, None], sources=(REPORTED,)),
    bars([rev("bars", 100, b(1, reportedTime=E)), rev("bars", F, b(1, reportedTime="x"))], F, [F],
         [[100, K, False], [F, F, True]], [None], sources=(REPORTED,)),
    bars([rev("bars", 100, b(1, reportedTime=E)), rev("bars", F, b(1, reportedTime=HI + 1))], F, [F],
         [[100, K, False], [F, F, True]], [None], sources=(REPORTED,)),
    case([BARS], [rev("bars", 100, {"coin": "BTC", "eventTime": HI - D + 1, "close": 1})], 100, [0],
         {"keys": [key("bars", ["BTC"], HI - D + 1, 0, [], [None])]}),
    # Negative times.
    case([BARS], [rev("bars", 100, {"coin": "BTC", "eventTime": -H, "close": 1})], 100, [-H + D - 1, -H + D],
         {"keys": [key("bars", ["BTC"], -H, 0, [[100, -H + D, False]], [None, 100])]}),
    # Dataset validity: a shared fetchedAt within a key (not across keys, not past the cutoff), an out-of-range
    # fetchedAt.
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, b(2))], 100, [K], "INVALID"),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, b(2))], 99, [K], {"keys": []}),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, {"coin": "ETH", "eventTime": E, "close": 1})], 100, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100]),
                   key("bars", ["ETH"], E, 1, [[100, K, False]], [100])]}),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", LO - 1, b(2))], 100, [K], "INVALID"),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", -2**63 - 1, b(2))], 100, [K], "INVALID"),
    # Stored bytes that do not decode, among eligible revisions only.
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, "{")], 200, [K], "INVALID"),
    case([BARS], [rev("bars", 100, '{"coin": "BTC", "eventTime": 36000000, "close": 1, "close": 2}')], 100, [K],
         "INVALID"),
    *[case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, text)], 200, [K], "INVALID")
      for text in ('[1]', CLOSE % "[1]", CLOSE % "1e999",
                   '{"coin": "BTC", "eventTime": 36000000, "close": 1, "\\u0063lose": 2}',
                   '{"coin": "\\ud800", "eventTime": 36000000, "close": 1}',
                   '{"coin": "BTC", "close": 1}', EVENT % "36000000.0", EVENT % '"x"', EVENT % "null", EVENT % "true",
                   EVENT % (HI + 1), CLOSE % 2**63, CLOSE % (-2**63 - 1), CLOSE % '1, "extra": "\\ud800"',
                   CLOSE % '1, "extra": 1, "extra": 2')],
    # Integers are cells in the signed 64-bit range only: a slot past it does not decode, its ends do.
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK], slot=2**63)], P + 3000, [10**15], "INVALID"),
    *[bars([rev("bars", 100, b(1)), rev("bars", F, b(v))], F, [F], [[100, K, False], [F, F, False]], [F])
      for v in (2**63 - 1, -2**63)],
    # Undeclared members are never read, whatever they hold or are named.
    *[bars([rev("bars", 100, b(1)), rev("bars", 200, text)], 200, [K], [[100, K, False]], [100])
      for text in (CLOSE % '1, "extra": {}', CLOSE % '1, "extra": 1e999', json.dumps(b(1, fetchedAt=200)),
                   json.dumps(b(1, source="x")), json.dumps(b(1, hash="x")),
                   json.dumps(b(1, tombstone=True)), json.dumps(b(1, upstream=[1])),
                   CLOSE % f'1, "extra": {10**30}')],
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, EVENT % "36000000.0")], 199, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100])]}),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, "{")], 199, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100])]}),
    # E_RULE before any row; E_DECL, a declared column named as the store's metadata (SOURCES.md §1), before it.
    case([src("bars", rule(f("u")))], [rev("bars", 100, b(1))], 100, [K], "E_RULE"),
    case([src("bars", rule(f("u")))], [rev("bars", 100, "{")], 100, [K], "E_RULE"),
    *[case([s], [rev(s["name"], 100, b(1))], 100, [K], "E_DECL")
      for s in (src("bars", values=("fetchedAt",)), src("bars", values=("tombstone",)), src("bars", values=("source",)),
                src("bars", values=("hash",)), src("bars", values=("knownAt",)),
                src("bars", times=("eventTime", "upstream")), src("bars", rule(f("u")), values=("upstream",)),
                src("sight", SEEN, times=("observed",), values=(), entity=("source", "observed"), event="observed",
                    evidence=True),
                src("bars", values=(), roles={"settlement": ["fetchedAt"]}))],
    # Keys: coins outside U are keys with no coin, as is a coin cell that is not a string.
    case([BARS], [rev("bars", 100, {"coin": "DOGE", "eventTime": E, "close": 1}), rev("bars", 200, b(1)),
                  rev("bars", 50, {"coin": "ETH", "eventTime": E, "close": 1})], 200, [K],
         {"keys": [key("bars", ["DOGE"], E, None, [[100, K, False]], [100]),
                   key("bars", ["BTC"], E, 0, [[200, K, False]], [200]),
                   key("bars", ["ETH"], E, 1, [[50, K, False]], [50])]}),
    case([BARS], [rev("bars", 100, {"coin": 1, "eventTime": E, "close": 1})], 100, [K],
         {"keys": [key("bars", [1], E, None, [[100, K, False]], [100])]}),
    # F-2, one tuple is one key: an escape and member order do not change it.
    bars([rev("bars", 100, b(1)), rev("bars", F, '{"close": 1, "eventTime": 36000000, "coin": "\\u0042TC"}')], F, [F],
         [[100, K, False]], [100]),
    # F-2, two tuples are two keys: no concatenation, no conversion between a string and an integer.
    case([SIGHT], [rev("sight", 100, {"host": "ab", "id": "c", "observed": E, "created": 1}),
                   rev("sight", F, {"host": "a", "id": "bc", "observed": E, "created": 2}),
                   rev("sight", 200, {"host": "a", "id": 1, "observed": E, "created": 1}),
                   rev("sight", 300, {"host": "a", "id": "1", "observed": E, "created": 2})], F, [F],
         {"keys": [key("sight", ["ab", "c"], E, None, [[100, E, False]], [100]),
                   key("sight", ["a", "bc"], E, None, [[F, F, False]], [F]),
                   key("sight", ["a", 1], E, None, [[200, E, False]], [200]),
                   key("sight", ["a", "1"], E, None, [[300, E, False]], [300])]}),
    # b2-revision.md §8: a covered zero count whose lineage is polls only, usable at the poll's knownAt plus the lag.
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK])], P + 3000, [P + 1000 + LAG - 1, P + 1000 + LAG],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000, P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [None, P + 3000])]}),
    # §8: a key of a source outside its dependency (bars is not recording's) makes the row unusable.
    case((BARS,) + derived, [rev("bars", 100, b(1)), poll(P + 1000), ev(P + 3000, 0, [PK, ["bars", ["BTC"], E]])],
         P + 3000, [10**15],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100]),
                   key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    # §8: a key with no delivery recorded by the derived revision; and one such key is not masked by a good one.
    case(derived, [poll(P + 4000), ev(P + 3000, 0, [PK])], P + 4000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 4000, P + 4000, False]], [P + 4000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case(derived, [poll(P + 1000), rev("sight", P + 4000, s1()), ev(P + 3000, 1, [PK, SK])], P + 4000,
         [10**15],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[P + 4000, P + 4000, False]], [P + 4000]),
                   key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    # An empty lineage, or none for the dependency, is unusable; a lineage member naming no dependency is checked and
    # not resolved.
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [])], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                      upstream={"other": [PK]})], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case((BARS,) + derived, [poll(P + 1000),
                             rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                 upstream={"recording": [PK], "other": [["bars", ["BTC"], E]]})], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [P + 3000])]}),
    # §8: a later upstream correction does not move an earlier derived row; the recomputed row after it is bounded by
    # it.
    case(derived, [rev("sight", E + 1000, s1()), rev("sight", 20 * H, s1(created=2)),
                   ev(E + 8000, 1, [SK]), ev(21 * H, 2, [SK])], 21 * H, [E + 1000 + LAG, 21 * H - 1, 21 * H],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False], [20 * H, 20 * H, False]],
                       [E + 1000, 20 * H, 20 * H]),
                   key("events", ["BTC"], E, 0, [[E + 8000, E + 1000 + LAG, False, E], [21 * H, 21 * H, False, E]],
                       [E + 8000, E + 8000, 21 * H])]}),
    # A retraction recorded by the derived revision bounds it (B2's fix).
    case(derived, [rev("sight", E + 1000, s1()), rev("sight", 15 * H, s1(), tombstone=True),
                   ev(16 * H, 0, [SK])], 16 * H, [15 * H + LAG - 1, 16 * H],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False], [15 * H, 15 * H, True]],
                       [None, None]),
                   key("events", ["BTC"], E, 0, [[16 * H, 15 * H + LAG, False, E]], [None, 16 * H])]}),
    # The lineage's key is compared as decoded values (F-2 in lineage): an escape names the same key, a string id not.
    case(derived, [rev("sight", E + 1000, s1()),
                   rev("events", E + 8000, {"coin": "BTC", "eventTime": E, "count": 1, "slot": E},
                       upstream='{"recording": [["sight", ["\\u0068", 1], 36000500]]}')], E + 8000, [E + 8000],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000]),
                   key("events", ["BTC"], E, 0, [[E + 8000, E + 1000 + LAG, False, E]], [E + 8000])]}),
    case(derived, [rev("sight", E + 1000, s1()), ev(E + 8000, 1, [["sight", ["h", "1"], E + 500]])], E + 8000,
         [E + 8000],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    # A lineage that does not decode, read whole: F-1's dependency named twice, a member naming no dependency, a key's
    # shape, an undeclared source (derived declares no bars), a key's entity of the wrong length.
    *[case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                         upstream=text)], P + 3000, [10**15], "INVALID")
      for text in (f'{{"recording": [], "recording": {json.dumps([PK])}}}', '{', '[]', '{"recording": 1}',
                   '{"recording": [1]}', '{"recording": [["poll", ["h"]]]}', '{"recording": [[1, ["h"], 36005000]]}',
                   '{"recording": [["poll", "h", 36005000]]}', '{"recording": [["poll", [["h"]], 36005000]]}',
                   '{"recording": [["poll", ["h"], 36005000.0]]}', f'{{"recording": [["poll", ["h"], {HI + 1}]]}}',
                   '{"recording": [["poll", ["h", 1], 36005000]]}', '{"recording": [["bars", ["BTC"], 36000000]]}',
                   f'{{"recording": [["poll", [{2**63}], 36005000]]}}',
                   f'{{"recording": {json.dumps([PK])}, "other": 1}}',
                   f'{{"recording": {json.dumps([PK])}, "other": [["bars", ["BTC"], 36000000]]}}')],
    # A later derived revision whose lineage is unusable retracts, keeping its slot; a slot that does not decode is
    # unusable (first: nothing; later: a retraction keeping the slot it retracts).
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK]), ev(F, 1, [PK, SK])], F, [F - 1, F],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000, P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E], [F, F, True, E]],
                       [P + 3000, None])]}),
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK], slot="x"), ev(F, 1, [PK])], F, [F],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[F, F, False, E]], [F])]}),
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK]), ev(F, 1, [PK], slot=None)], F, [F],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E], [F, F, True, E]],
                       [None])]}),
    # A tombstone's lineage is never read, whatever it holds; any other derived revision's null lineage does not decode.
    *[case(derived, [poll(P + 1000), ev(P + 3000, 0, [PK]), {**ev(F, 0, [PK], tombstone=True), "upstream": lineage}], F,
           [F - 1, F],
           {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000, P + 1000]),
                     key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E], [F, F, True, E]],
                         [P + 3000, None])]})
      for lineage in ("{", None, "[]")],
    case(derived, [poll(P + 1000), {**ev(P + 3000, 0, [PK]), "upstream": None}], P + 3000, [10**15], "INVALID"),
    # A repeated tombstone, or a repeat of a rejected revision, adds nothing: a revision is compared with the stored one
    # before it, delivered or not.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True), rev("bars", 60 * H, b(1), tombstone=True)],
         60 * H, [60 * H], [[100, K, False], [F, F, True]], [None]),
    bars([rev("bars", 100, b(1, reportedTime=E)), rev("bars", F, b(1)), rev("bars", 60 * H, b(1))], 60 * H, [60 * H],
         [[100, K, False], [F, F, True]], [None], sources=(REPORTED,)),
    # b2-revision.md §7, N-1: a recomputation with identical cells and a usable lineage adds nothing after an unusable
    # first revision, so the key is never delivered (missingness, recorded as a limitation).
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [SK]), ev(F, 0, [PK])], F, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    # Each dependency's own lag bounds its own time; lacking one of two dependencies is unusable.
    *[case((SIGHT, POLL, src("both", rule(mx(f("eventTime"), dep("a"), dep("b"))), values=("count",),
                             deps=({"name": "a", "sources": ["poll"], "lag": LAG},
                                   {"name": "b", "sources": ["sight"], "lag": 10 * LAG}))),
           [rev("sight", E + 1000, s1()), poll(P + 1000),
            rev("both", E + 8000, {"coin": "BTC", "eventTime": E, "count": 1}, upstream=lineage)], E + 8000,
           [E + 10999, E + 11000],
           {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000, E + 1000]),
                     key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000, P + 1000]),
                     key("both", ["BTC"], E, 0, timeline, visible)]})
      for lineage, timeline, visible in (({"a": [PK], "b": [SK]}, [[E + 8000, E + 11000, False]], [None, E + 8000]),
                                         ({"a": [PK]}, [], [None, None]))],
    # A derived source over a derived source: the upstream time is the upstream derived row's knownAt.
    case(derived + (src("daily", rule(mx(f("eventTime"), dep("counts"))), values=("total",),
                        deps=({"name": "counts", "sources": ["events"], "lag": 0},)),),
         [poll(P + 1000), ev(P + 3000, 0, [PK]),
          rev("daily", E + 9000, {"coin": "BTC", "eventTime": E, "total": 0},
              upstream={"counts": [["events", ["BTC"], E]]})],
         E + 9000, [P + 1000 + LAG - 1, P + 1000 + LAG],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000, P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [None, P + 3000]),
                   key("daily", ["BTC"], E, 0, [[E + 9000, P + 1000 + LAG, False]], [None, E + 9000])]}),
    # A lag pushing the bound out of range makes the row unusable.
    case((SIGHT, POLL, src("events", COUNT, values=("count",), slot="slot",
                           deps=({"name": "recording", "sources": ["sight", "poll"], "lag": HI},))),
         [poll(P + 1000), ev(P + 3000, 0, [PK])], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    # The derivation bound decides a later derived revision: its lineage's upstream is recorded before it and known
    # after it, past its fetchedAt and what it replaces, plus the lag. And on a first revision.
    case(over_up, [rev("sight", E + 1000, s1()), up(15 * H), ev(E + 8000, 1, [SK]), ev(20 * H, 2, [UK])], 20 * H,
         [E + 1000 + LAG, 110 * H, 110 * H + LAG - 1, 110 * H + LAG],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000] * 4),
                   key("up", ["a"], E, None, [[15 * H, 110 * H, False]], [None, 15 * H, 15 * H, 15 * H]),
                   key("events", ["BTC"], E, 0,
                       [[E + 8000, E + 1000 + LAG, False, E], [20 * H, 110 * H + LAG, False, E]],
                       [E + 8000, E + 8000, E + 8000, 20 * H])]}),
    case(over_up, [up(15 * H), ev(20 * H, 1, [UK])], 20 * H, [20 * H, 110 * H + LAG - 1, 110 * H + LAG],
         {"keys": [key("up", ["a"], E, None, [[15 * H, 110 * H, False]], [None, 15 * H, 15 * H]),
                   key("events", ["BTC"], E, 0, [[20 * H, 110 * H + LAG, False, E]], [None, None, 20 * H])]}),
    # Two usable keys of one dependency, in either order: the latest bounds it.
    *[case(over_up, [rev("sight", E + 1000, s1()), up(15 * H), ev(20 * H, 1, lineage)], 20 * H, [110 * H + LAG],
           {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000]),
                     key("up", ["a"], E, None, [[15 * H, 110 * H, False]], [15 * H]),
                     key("events", ["BTC"], E, 0, [[20 * H, 110 * H + LAG, False, E]], [20 * H])]})
      for lineage in ([SK, UK], [UK, SK])],
    # A slot unlike the event time, moved by a correction, then retracted by a tombstone holding another slot: the
    # retraction keeps the slot it retracts; a later value carries its own.
    case(derived, [poll(P + 1000), ev(P + 3000, 1, [PK], slot=E + H), ev(20 * H, 1, [PK], slot=E + 2 * H),
                   ev(30 * H, 1, [PK], slot=E + 5 * H, tombstone=True), ev(40 * H, 1, [PK], slot=E + 3 * H)], 40 * H,
         [P + 1000 + LAG, 20 * H, 30 * H, 40 * H],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000] * 4),
                   key("events", ["BTC"], E, 0,
                       [[P + 3000, P + 1000 + LAG, False, E + H], [20 * H, 20 * H, False, E + 2 * H],
                        [30 * H, 30 * H, True, E + 2 * H], [40 * H, 40 * H, False, E + 3 * H]],
                       [P + 3000, 20 * H, None, 40 * H])]}),
    case(derived, [poll(P + 1000), ev(P + 3000, 1, [PK], slot=E + H), ev(F, 1, [PK], slot="x")], F, [F],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E + H], [F, F, True, E + H]],
                       [None])]}),
    # Declaration order is not dependency order.
    case((EVENTS, POLL, SIGHT), [poll(P + 1000), ev(P + 3000, 0, [PK])], P + 3000, [P + 1000 + LAG],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [P + 3000])]}),
    case((src("daily", rule(mx(f("eventTime"), dep("counts"))), values=("total",),
              deps=({"name": "counts", "sources": ["events"], "lag": 0},)), EVENTS, POLL, SIGHT),
         [poll(P + 1000), ev(P + 3000, 0, [PK]),
          rev("daily", E + 9000, {"coin": "BTC", "eventTime": E, "total": 0},
              upstream={"counts": [["events", ["BTC"], E]]})],
         E + 9000, [P + 1000 + LAG],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [P + 3000]),
                   key("daily", ["BTC"], E, 0, [[E + 9000, P + 1000 + LAG, False]], [E + 9000])]}),
    # F-2 on the evidence path: one tuple stored under two spellings is one key, so a changed column is a correction, an
    # unchanged one adds nothing, and the correction bounds a recomputation.
    case(derived, [rev("sight", E + 1000, s1()),
                   rev("sight", 20 * H, '{"created": 2, "observed": 36000500, "id": 1, "host": "\\u0068"}'),
                   ev(E + 8000, 1, [SK]), ev(20 * H + 1, 2, [SK])], 20 * H + 1, [20 * H + LAG - 1, 20 * H + LAG],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False], [20 * H, 20 * H, False]],
                       [20 * H, 20 * H]),
                   key("events", ["BTC"], E, 0,
                       [[E + 8000, E + 1000 + LAG, False, E], [20 * H + 1, 20 * H + LAG, False, E]],
                       [E + 8000, 20 * H + 1])]}),
    case([SIGHT], [rev("sight", E + 1000, s1()),
                   rev("sight", 20 * H, '{"created": 1, "observed": 36000500, "id": 1, "host": "\\u0068"}')],
         20 * H, [F],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000])]}),
    # An integer and a non-integer differ even when numerically equal, as a value, an entity, a lineage key, a slot and
    # a rule's field; numbers of one kind compare by value, whatever their spelling.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1.0))], F, [F], [[100, K, False], [F, F, False]], [F]),
    bars([rev("bars", 100, b(1.0)), rev("bars", F, CLOSE % "1e0")], F, [F], [[100, K, False]], [100]),
    bars([rev("bars", 100, b(0)), rev("bars", F, CLOSE % "-0")], F, [F], [[100, K, False]], [100]),
    # A non-integer is its binary64 value, not its exact decimal: two spellings of one binary64 number are one value,
    # and the next binary64 number is another.
    bars([rev("bars", 100, b(1.0)), rev("bars", F, CLOSE % "1.00000000000000001")], F, [F], [[100, K, False]], [100]),
    bars([rev("bars", 100, b(1.0)), rev("bars", F, CLOSE % "1.0000000000000002")], F, [F],
         [[100, K, False], [F, F, False]], [F]),
    case([SIGHT], [rev("sight", 100, {"host": "a", "id": 1, "observed": E, "created": 1}),
                   rev("sight", 200, {"host": "a", "id": 1.0, "observed": E, "created": 1})], 200, [F],
         {"keys": [key("sight", ["a", 1], E, None, [[100, E, False]], [100]),
                   key("sight", ["a", 1.0], E, None, [[200, E, False]], [200])]}),
    case([SIGHT], [rev("sight", 100, {"host": "a", "id": 0.0, "observed": E, "created": 1}),
                   rev("sight", 200, {"host": "a", "id": -0.0, "observed": E, "created": 2})], 200, [F],
         {"keys": [key("sight", ["a", 0.0], E, None, [[100, E, False], [200, E, False]], [200])]}),
    case(derived, [rev("sight", E + 1000, s1()), ev(E + 8000, 1, [["sight", ["h", 1.0], E + 500]])], E + 8000,
         [E + 8000],
         {"keys": [key("sight", ["h", 1], E + 500, None, [[E + 1000, E + 1000, False]], [E + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case(derived, [poll(P + 1000), ev(P + 3000, 1, [PK], slot=float(E))], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    bars([rev("bars", 100, b(1, reportedTime=E)), rev("bars", F, b(1, reportedTime=float(E)))], F, [K, F],
         [[100, K, False], [F, F, True]], [100, None], sources=(REPORTED,)),
    # Roles. A payload that decodes is delivered as its cells; one that does not is unusable (first: nothing; later: a
    # retraction); a role column alone makes a correction, each entry carrying its own payload.
    ohlc([rev("bars", 100, bar())], 100, [K], [[100, K, False]], [100]),
    *[ohlc([rev("bars", 100, bad), rev("bars", F, bar())], F, [K, F], [[F, F, False]], [None, F])
      for bad in (bar(c=None), bar(c=True), bar(c="x"), bar(t=5.0), bar(t=None))],
    *[ohlc([rev("bars", 100, bar()), rev("bars", F, bad)], F, [K, F], [[100, K, False], [F, F, True]], [100, None])
      for bad in (bar(c=None), bar(c=True), bar(c="x"), bar(t=5.0), bar(t=None))],
    ohlc([rev("bars", 100, bar()), rev("bars", F, bar(h=3))], F, [K, F], [[100, K, False], [F, F, False]], [100, F]),
    ohlc([rev("bars", 100, bar()), rev("bars", F, bar())], F, [F], [[100, K, False]], [100]),
    rates([rev("rates", 100, rate(1))], 100, [K], [[100, K, False]], [100]),
    rates([rev("rates", 100, rate(1)), rev("rates", F, rate(1.0))], F, [F], [[100, K, False], [F, F, False]], [F]),
    # An integer's number is the nearest binary64, ties to even: 2^53 + 1 is delivered as 2^53, a correction of it.
    rates([rev("rates", 100, rate(2**53)), rev("rates", F, rate(2**53 + 1))], F, [F], [[100, K, False], [F, F, False]],
          [F]),
    *[rates([rev("rates", 100, bad), rev("rates", F, rate(0.5))], F, [K, F], [[F, F, False]], [None, F])
      for bad in (rate("x"), rate(None), rate(False), {"coin": "BTC", "eventTime": E})],
    rates([rev("rates", 100, rate(0.5)), rev("rates", F, rate("x"))], F, [K, F], [[100, K, False], [F, F, True]],
          [100, None]),
    # Round 11: absent post-V event time, whole-text depth, and slots separate from rule times and metadata.
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, {"coin": "BTC", "close": 2})], 199, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100])]}),
    *[case([BARS], [rev("bars", 100, CLOSE % ('1, "extra": ' + '[' * n + '0' + ']' * n))], 100, [K], expected)
      for n, expected in ((64, "INVALID"), (63, {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100])]}))],
    *[case([src("events", slot=name)], [rev("events", 100, b(1))], 100, [K], "E_DECL")
      for name in sorted(METADATA)],
    case([src("events", rule(f("slot")), slot="slot")], [], 100, [K], "E_RULE"),
    case([src("events", rule(f("slot")), times=("eventTime", "slot"), slot="slot")], [], 100, [K], {"keys": []}),
]


def respell(cells):
    """The same revision under another text: members reversed, each string's first character escaped."""
    spell = lambda v: f'"\\u{ord(v[0]):04x}{v[1:]}"' if isinstance(v, str) and v else json.dumps(v)
    return "{" + ", ".join(f"{json.dumps(k)}: {spell(v)}" for k, v in reversed(cells.items())) + "}"


def store(rng):
    """One store: a bars source (with or without reportedTime or roles), three evidence sources (one known after it is
    fetched), a derived count over one or two dependencies of up to three sources each, with drawn lags, and sometimes a
    derived source over it, declared in any order; lineages drawn over stored keys and occasional absent or foreign
    ones; a derived revision often fetched just after an upstream one; a key whose second revision reads the later-known
    upstream key, so the bound decides it, then a value or a tombstone, holding another slot, raised to it; for
    reportedTime bars, a key whose correction, fetched and reported before what it replaces is known, is raised to it;
    sometimes a row that does not decode."""
    rows, keys = [], {"bars": [], "sight": [], "poll": [], "up": [], "events": []}
    fetch = lambda: rng.randint(0, 30) * H + rng.choice((0, 1, 500, D))
    spelled = lambda cells: respell(cells) if rng.random() < 0.1 else cells
    bars_source = rng.choice((BARS, REPORTED, OHLC))
    for _ in range(rng.randint(1, 3)):
        coin, e = rng.choice(("BTC", "ETH", "DOGE")), rng.choice((0, 1, 2)) * H + E
        keys["bars"].append(["bars", [coin], e])
        for _ in range(rng.randint(1, 3)):
            close = rng.choice((1, 1, 2, None, 0.5, 1.0, True))
            cells = ({"coin": coin, "eventTime": e, "open": 1, "high": 2, "low": 0.5, "close": close,
                      "trades": rng.choice((5, 5, 5.0))} if bars_source is OHLC
                     else {"coin": coin, "eventTime": e, "close": close})
            if bars_source is not OHLC and rng.random() < 0.4:
                cells["reportedTime"] = rng.choice((e, e + 3 * H, "x"))
            rows.append(rev("bars", fetch(), spelled(cells), rng.random() < 0.15))
    if bars_source is REPORTED:
        coin, e, first = rng.choice(("BTC", "ETH", "DOGE")), E + 3 * H, rng.randint(0, 12) * H
        keys["bars"].append(["bars", [coin], e])
        rows.append(rev("bars", first, {"coin": coin, "eventTime": e, "close": 1, "reportedTime": e + 3 * H}))
        rows.append(rev("bars", first + rng.choice((1, H)), {"coin": coin, "eventTime": e, "close": rng.choice((1, 2)),
                                                            "reportedTime": rng.choice((e, e + H, "x"))}))
    for _ in range(rng.randint(1, 3)):
        host, i, obs = rng.choice(("h", "g")), rng.randint(1, 2), E + rng.randint(0, 3) * 1000
        keys["sight"].append(["sight", [host, i], obs])
        for _ in range(rng.randint(1, 3)):
            rows.append(rev("sight", fetch(), spelled(s1(rng.randint(1, 2), obs, host, i)), rng.random() < 0.1))
    for _ in range(rng.randint(1, 2)):
        host, recv = rng.choice(("h", "g")), E + rng.randint(0, 3) * 1000
        keys["poll"].append(["poll", [host], recv])
        rows.append(rev("poll", fetch(), spelled({"host": host, "recv": recv})))
    ups = []
    for host, obs in zip(("a", "b"), sorted(rng.sample(range(4), 2))):
        ups.append((["up", [host], E + obs * 1000], rng.randint(0, 14) * H + rng.choice((0, 1, 500, D))))
        keys["up"].append(ups[-1][0])
        rows.append(rev("up", ups[-1][1], spelled({"host": host, "observed": E + obs * 1000})))
    deps = [{"name": name, "sources": rng.sample(("sight", "poll", "up", "bars"), rng.randint(1, 3)),
             "lag": rng.choice((0, 1, LAG, 100 * H))} for name in ("recording", "other")[:rng.choice((1, 1, 2))]]
    upstream_times = [r["fetchedAt"] for r in rows]
    absent = [["sight", ["h", 9], E], ["bars", ["BTC"], E], ["poll", ["z"], E]]
    def lineage():
        out = {}
        for d in deps:
            good = [k for name in d["sources"] for k in keys[name]]
            foreign = [k for name in ("sight", "poll", "up", "bars") if name not in d["sources"] for k in keys[name]]
            pool = good if good and rng.random() < 0.9 else good + absent + foreign
            out[d["name"]] = rng.sample(pool, 0 if rng.random() < 0.03 else min(len(pool), rng.randint(1, 2)))
        return out

    event = lambda coin, e, count, slot: {"coin": coin, "eventTime": e, "count": count, "slot": slot}
    for _ in range(rng.randint(1, 3)):
        coin, e = rng.choice(("BTC", "ETH", "DOGE")), rng.choice((E, E, E + H))
        keys["events"].append(["events", [coin], e])
        for _ in range(rng.randint(1, 4)):
            fetched = (rng.choice(upstream_times) + rng.choice((0, 1, LAG - 1, LAG))
                       if rng.random() < 0.7 else rng.randint(15, 45) * H + rng.choice((0, 1, 500, D)))
            rows.append(rev("events", fetched, event(coin, e, rng.randint(0, 2),
                                                     rng.choice((e, e, e, e + H, e + 2 * H, "x", None))),
                            rng.random() < 0.1, lineage()))
    if "up" in deps[0]["sources"]:
        coin = rng.choice(("BTC", "ETH", "DOGE"))
        first = ups[0][1] + rng.choice((0, 1, LAG - 1))
        second = max(first, ups[1][1]) + rng.choice((1, LAG - 1, LAG))
        for fetched, count, (k, _) in ((first, 0, ups[0]), (second, 1, ups[1])):
            rows.append(rev("events", fetched, event(coin, E + 2 * H, count, E), False,
                            {**lineage(), deps[0]["name"]: [k]}))
        tombstone = rng.random() < 0.5
        rows.append(rev("events", second + 1, event(coin, E + 2 * H, 2, E + H), tombstone,
                        {**lineage(), deps[0]["name"]: [ups[0][0]]}))
    sources = [bars_source, SIGHT, POLL,
               src("up", rule(add(f("observed"), {"ms": 5 * H})), times=("observed",), values=(), entity=("host",),
                   event="observed", evidence=True),
               src("events", rule(mx(f("eventTime"), *[dep(d["name"]) for d in deps])), values=("count",), slot="slot",
                   deps=deps)]
    if rng.random() < 0.3:
        lag = rng.choice((0, LAG))
        sources.append(src("daily", rule(mx(f("eventTime"), dep("counts"))), values=("total",),
                           deps=({"name": "counts", "sources": ["events"], "lag": lag},)))
        for _ in range(rng.randint(1, 2)):
            pool = keys["events"] + [["events", ["BTC"], E]]
            rows.append(rev("daily", rng.randint(20, 50) * H, {"coin": rng.choice(("BTC", "ETH")), "eventTime": E,
                                                               "total": rng.randint(0, 2)}, False,
                            {"counts": [rng.choice(pool)]}))
    if rng.random() < 0.15:
        rows.append(rev("bars", fetch(), "{"))
    rng.shuffle(rows)
    rng.shuffle(sources)
    queries = sorted(rng.randint(0, 50) * H + rng.choice((-1, 0, 1, D, LAG)) for _ in range(4))
    c = case(sources, rows, rng.choice((50 * H, rng.randint(0, 50) * H)), queries, None)
    del c["expect"]
    return c


def image(c):
    """C7.6's Parquet image: no metadata collision, every cells text a §1 object, every fetchedAt an Int64."""
    if any(METADATA.intersection(declared(s)) for s in c["sources"]):
        return False
    try:
        return all(isinstance(parse(r["cells"]), dict)
                   and -2**63 <= r["fetchedAt"] < 2**63 for r in c["rows"])
    except Malformed:
        return False


def delivered(c, result):
    """C7.6's size on one store: its distinct pairs of a key in U (of a non-evidence source, with a coin) with at least
    two eligible revisions and a query time at or after the knownAt of one of the key's entries; none if the store does
    not resolve or has no Parquet image."""
    if not isinstance(result, dict) or not image(c):
        return 0
    by, counts = {s["name"]: s for s in c["sources"]}, Counter()
    for r in c["rows"]:
        if r["fetchedAt"] <= c["version"]:
            s, cells = by[r["source"]], json.loads(r["cells"])
            counts[r["source"], ident([cells.get(x) for x in s["entity"]]), cells[s["event"]]] += 1
    return sum(any(e[1] <= q for e in k["timeline"]) for k in result["keys"]
               if not by[k["source"]]["evidence"] and k["coin"] is not None
               and counts[k["source"], ident(k["entity"]), k["event"]] >= 2 for q in set(c["queries"]))


FLOOR = 10
CLASSES = ("two dependencies", "several sources", "lag 0", "lag 1", "lag 1000", "lag 360000000", "over derived",
           "dependant declared first", "known after fetched", "slot unlike event", "slot undecodable", "bars role",
           "respelled", "undecodable bytes")
REACHED = ("no delivery", "several entries", "retraction", "derived bound past fetchedAt", "raised to replaced",
           "retraction raised", "moved slot", "retraction keeps slot", "role", "nothing after retraction")


def classes(c):
    """What a store's inputs exercise."""
    by, names = {s["name"]: s for s in c["sources"]}, [s["name"] for s in c["sources"]]
    tags = set()
    for s in c["sources"]:
        for d in s["deps"]:
            tags.add(f"lag {d['lag']}")
            if len(d["sources"]) >= 2:
                tags.add("several sources")
            if any(names.index(u) > names.index(s["name"]) for u in d["sources"]):
                tags.add("dependant declared first")
        if len(s["deps"]) >= 2:
            tags.add("two dependencies")
        if s["name"] == "daily":
            tags.add("over derived")
        if s["roles"]:
            tags.add("bars role")
    for r in c["rows"]:
        if "\\u" in r["cells"]:
            tags.add("respelled")
        try:
            cells = json.loads(r["cells"])
        except ValueError:
            tags.add("undecodable bytes")
            continue
        lineage = json.loads(r["upstream"])
        deps = by[r["source"]]["deps"]
        if any(k[0] == "up" for d in deps if "up" in d["sources"] for k in lineage.get(d["name"], [])):
            tags.add("known after fetched")
        if r["source"] == "events":
            slot = cells.get("slot")
            if type(slot) is not int:
                tags.add("slot undecodable")
            elif slot != cells["eventTime"]:
                tags.add("slot unlike event")
    return tags


def reached(c, result):
    """What a store's result shows, for the floors over Lean's results. Each tag holds only where its behaviour decides
    the result: a raise to the replaced knownAt above the revision's own rule value and fetchedAt; a derivation bound,
    with a positive lag, above the fetchedAt and the replaced knownAt; a retraction keeping a slot neither its own nor
    the event time; a query at or after a retraction seeing nothing."""
    by, tags = {s["name"]: s for s in c["sources"]}, set()
    keys = result["keys"] if isinstance(result, dict) else []
    timelines = {(k["source"], json.dumps(k["entity"]), k["event"]): k["timeline"] for k in keys}

    def upstream_time(key, by_fetched):
        known = [e[1] for e in timelines.get((key[0], json.dumps(key[1]), key[2]), []) if e[0] <= by_fetched]
        return max(known) if known else None

    for k in keys:
        tl, s = k["timeline"], by[k["source"]]
        if not tl:
            tags.add("no delivery")
        if len(tl) >= 2:
            tags.add("several entries")
        for i, (fetched, known, retraction, slot, _, role) in enumerate(tl):
            before = tl[i - 1] if i else None
            row, cells = stored(c["rows"], s, k, fetched)
            if retraction:
                tags.add("retraction")
                if known > fetched:
                    tags.add("retraction raised")
                if before and slot == before[3] != k["event"] and ident(cells.get(s["slot"])) != ident(slot):
                    tags.add("retraction keeps slot")
            elif before:
                lineage = json.loads(row["upstream"])
                if not s["deps"] and known == before[1] > max(fetched, own(s, cells, fetched)):
                    tags.add("raised to replaced")
                for d in s["deps"]:
                    times = [upstream_time(u, fetched) for u in lineage.get(d["name"], [])]
                    if d["lag"] > 0 and times and None not in times and known == max(times) + d["lag"] > max(
                            fetched, before[1]):
                        tags.add("derived bound past fetchedAt")
                if slot != before[3] and not before[2]:
                    tags.add("moved slot")
            if role is not None:
                tags.add("role")
        for q, v in zip(c["queries"], k["visible"]):
            seen = [e for e in tl if e[1] <= q]
            if seen and seen[-1][2] and v is None:
                tags.add("nothing after retraction")
    return tags


def own(s, cells, fetched):
    """A source without dependencies: its rule's value on a revision that it accepts."""
    return evaluate(json.loads(s["rule"])["expr"], {**cells, "fetchedAt": fetched}, {})


SIZE = 1000


def stream(seed=20261102):
    rng = random.Random(seed)
    while True:
        yield store(rng)


def generate(resolve):
    """The shortest prefix of `stream()` reaching SIZE pairs, as `delivered` counts them under `resolve` (a store to its
    §7 result)."""
    out, total = [], 0
    for c in stream():
        out.append(c)
        total += delivered(c, resolve(c))
        if total >= SIZE:
            break
    counts = Counter(t for c in out for t in classes(c))
    assert all(counts[t] >= FLOOR for t in CLASSES), counts
    return out
