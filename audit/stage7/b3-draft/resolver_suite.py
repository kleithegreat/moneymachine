"""B3 draft: C7.6's resolver suite revised to the bitemporal resolver as frozen after B2 (kernel/RULES.md §6 and its
dated revisions to 2026-11-01; reference/lean/Ref/Resolve.lean, `timeline`). Not frozen; it replaces
kernel/tests/rules/resolver_suite.py once reviewed. Open points for the review: README.md.

A case is one store at one dataset version:

    {"universe": [COIN, ...],
     "sources": [{"name": S, "rule": TEXT, "times": [...], "values": [...], "entity": [COL, ...], "event": COL,
                  "slot": COL or null, "evidence": BOOL, "deps": [{"name": N, "sources": [S, ...], "lag": D}, ...]}, ...],
     "rows": [{"source": S, "fetchedAt": INT, "tombstone": BOOL, "cells": TEXT, "upstream": TEXT}, ...],
     "version": V, "queries": [t, ...]}

- A source is a declaration reduced to what resolution reads. `times` are its rule's Time fields (`fetchedAt`, the
  revision's own, is always in the rule's context and never listed); `values` its value columns; `entity` its entity
  columns (`["coin"]` unless `evidence`); `event` its event column, among `times`; `slot` an event source's slot column.
  Its cadence is Lean's evidence if `evidence`, event if it has a `slot`, held otherwise; an adapter to Lean's `Decl`
  names each value column's input uniquely (`fields`), since no rule reads one.
  The compared columns (RULES.md §6, second revision: declared value and control columns other than `fetchedAt`) are
  `values`, `times`, `event`, `slot` and `entity`. Every case's registry is valid (paper §5, `Registry.valid`): sources
  named uniquely, dependencies naming declared sources, at least one each, acyclic. Admission's refusals are tested
  elsewhere (`reference/admission_differential.py`).
- `cells` is a JSON object text (RULES.md §1) of the revision's stored columns, never `fetchedAt`, `source`, `hash` or
  the tombstone flag; integer tokens are integers, other numbers IEEE doubles (equal as values, so 0.0 and -0.0 are
  one value), and an absent column is null. Its event column holds an integer and its entity columns integers, strings,
  booleans or null in every case.
- A revision's key is (source, entity, event): its entity is the list of its entity columns' values, in declared order,
  compared as decoded values (so `"\\u0042TC"` and `"BTC"` are one string); its event the event column's value. A
  non-evidence source's key maps to the universe's coin equal to its `coin` value, else to none (outside U); an
  evidence source's to none.
- `upstream` is a JSON object text mapping a dependency name to the keys the revision was computed from, each
  `[S, [entity values], event]`. Members naming no declared dependency are not read.
- **Invalid dataset** (the result is `"INVALID"`): among the eligible revisions (fetchedAt ≤ V) of any source, two of
  one key share a fetchedAt, a fetchedAt is out of range, or the stored bytes do not decode: `cells` or `upstream`
  malformed or not an object, a column or a lineage's dependency named twice (F-1), a reserved column in `cells`, an
  upstream member not a list of keys of that shape. (Proposed: README.md, point 1.)
- `E_RULE`: a source's rule fails checking (RULES.md §4) against its `times` and its dependencies' names; the case is
  rejected before any row.

The result lists every key with an eligible revision, sources in declaration order, each source's keys in the order of
their first eligible row:

    {"keys": [{"source": S, "entity": [...], "event": INT, "coin": INT or null,
               "timeline": [[FETCHEDAT, KNOWNAT, RETRACTION, SLOT], ...], "visible": [FETCHEDAT or null per query]}]}

`timeline` is Lean's `timeline` (its entries' fetchedAt, knownAt, retraction flag and slot: an event source's slot
column's value, a retraction keeping the slot of what it retracts; null for other sources); `coin` an index into
`universe`. `visible` names, per query t, the latest entry with knownAt ≤ t, null if there is none or it is a
retraction.

- HAND: hand-computed cases, `b2-revision.md` §8 and `b2-fixes-review-claude.md`'s F-1 and F-2 among them.
- generate(): at least 1,000 (key, query) pairs over generated multi-source stores, from a fixed seed, without expected
  results: the implementations must agree.
"""

import json
import random

from kernel.tests.rules.suite import D, H, HI, LO, add, dep, f, mx, rule

BAR = rule(add(f("eventTime"), {"ms": D}))
LATE = rule(add(f("eventTime"), {"ms": 100 * H}))
REP = rule(mx(add(f("eventTime"), {"ms": D}), f("reportedTime")))
SEEN = rule(mx(f("observed"), f("fetchedAt")))
RECV = rule(mx(f("recv"), f("fetchedAt")))
COUNT = rule(mx(f("eventTime"), dep("recording")))
LAG = 1000


def src(name, r=BAR, times=("eventTime",), values=("close",), entity=("coin",), event="eventTime", slot=None,
        evidence=False, deps=()):
    return {"name": name, "rule": r, "times": list(times), "values": list(values), "entity": list(entity),
            "event": event, "slot": slot, "evidence": evidence, "deps": list(deps)}


BARS = src("bars")
REPORTED = src("bars", REP, times=("eventTime", "reportedTime"))
SIGHT = src("sight", SEEN, times=("observed", "created"), values=(), entity=("host", "id"), event="observed",
            evidence=True)
POLL = src("poll", RECV, times=("recv",), values=(), entity=("host",), event="recv", evidence=True)
EVENTS = src("events", COUNT, values=("count",), slot="slot",
             deps=({"name": "recording", "sources": ["sight", "poll"], "lag": LAG},))


def rev(source, fetched, cells, tombstone=False, upstream=None):
    text = cells if isinstance(cells, str) else json.dumps(cells)
    return {"source": source, "fetchedAt": fetched, "tombstone": tombstone, "cells": text,
            "upstream": upstream if isinstance(upstream, str) else json.dumps(upstream or {})}


def case(sources, rows, version, queries, expect, universe=("BTC", "ETH")):
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
s1 = lambda created=1, observed=E + 500, host="h", i=1: {"host": host, "id": i, "observed": observed, "created": created}
poll = lambda fetched, recv=P, host="h": rev("poll", fetched, {"host": host, "recv": recv})
ev = lambda fetched, count, lineage, slot=E: rev("events", fetched, {"coin": "BTC", "eventTime": E, "count": count,
                                                                     "slot": slot}, upstream={"recording": lineage})
SK = ["sight", ["h", 1], E + 500]
PK = ["poll", ["h"], P]
derived = (SIGHT, POLL, EVENTS)

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
    # A correction fetched before the first's rule time is known at the replaced one's knownAt; the later wins a tie.
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
    # Doubles compare as values: the two zeros are one value; 1.5 and 2.5 differ.
    bars([rev("bars", 100, b(0.0)), rev("bars", F, b(-0.0))], F, [F], [[100, K, False]], [100]),
    bars([rev("bars", 100, b(1.5)), rev("bars", F, b(2.5))], F, [F], [[100, K, False], [F, F, False]], [F]),
    # A tombstone retracts from its fetchedAt, with no fallback; a later value is a new delivery.
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True)], F, [K, F - 1, F, 10**15],
         [[100, K, False], [F, F, True]], [100, 100, None, None]),
    bars([rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True), rev("bars", 60 * H, b(1))], 60 * H,
         [K, 55 * H, 60 * H], [[100, K, False], [F, F, True], [60 * H, 60 * H, False]], [100, None, 60 * H]),
    # A tombstone before any delivery adds nothing, and the revision after it is still known no earlier than its
    # fetchedAt (third revision of 2026-10-26).
    bars([rev("bars", 100, b(1), tombstone=True), rev("bars", F, b(1))], F, [K, F], [[F, F, False]], [None, F]),
    # A retraction and a correction are raised to the knownAt of what they replace.
    case([src("bars", LATE)], [rev("bars", 100, b(1)), rev("bars", F, b(1), tombstone=True)], F, [110 * H - 1, 110 * H],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, 110 * H, False], [F, 110 * H, True]], [None, None])]}),
    case([src("bars", LATE)], [rev("bars", 100, b(1)), rev("bars", F, b(2))], F, [110 * H],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, 110 * H, False], [F, 110 * H, False]], [F])]}),
    # A corrected rule over the same revisions; a rule reading fetchedAt.
    case([src("bars", rule(add(f("eventTime"), {"ms": D + 1000})))], [rev("bars", 100, b(1)), rev("bars", 200, b(1))],
         200, [K, K + 1000], {"keys": [key("bars", ["BTC"], E, 0, [[100, K + 1000, False]], [None, 100])]}),
    case([src("bars", rule(mx(add(f("eventTime"), {"ms": D}), f("fetchedAt"))))], [rev("bars", F, b(1))], F,
         [K, F], {"keys": [key("bars", ["BTC"], E, 0, [[F, F, False]], [None, F])]}),
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
    # Dataset validity: a shared fetchedAt within a key (not across keys, not past the cutoff), an out-of-range fetchedAt.
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, b(2))], 100, [K], "INVALID"),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, b(2))], 99, [K], {"keys": []}),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 100, {"coin": "ETH", "eventTime": E, "close": 1})], 100, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100]),
                   key("bars", ["ETH"], E, 1, [[100, K, False]], [100])]}),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", LO - 1, b(2))], 100, [K], "INVALID"),
    # Stored bytes that do not decode: malformed, a duplicate column, a reserved column (proposed, README 1).
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, "{")], 200, [K], "INVALID"),
    case([BARS], [rev("bars", 100, '{"coin": "BTC", "eventTime": 36000000, "close": 1, "close": 2}')], 100, [K],
         "INVALID"),
    case([BARS], [rev("bars", 100, b(1, fetchedAt=100))], 100, [K], "INVALID"),
    case([BARS], [rev("bars", 100, b(1)), rev("bars", 200, "{")], 199, [K],
         {"keys": [key("bars", ["BTC"], E, 0, [[100, K, False]], [100])]}),
    # E_RULE before any row.
    case([src("bars", rule(f("u")))], [rev("bars", 100, b(1))], 100, [K], "E_RULE"),
    # Keys: coins outside U are keys with no coin; keys in order of their first eligible row.
    case([BARS], [rev("bars", 100, {"coin": "DOGE", "eventTime": E, "close": 1}), rev("bars", 200, b(1)),
                  rev("bars", 50, {"coin": "ETH", "eventTime": E, "close": 1})], 200, [K],
         {"keys": [key("bars", ["DOGE"], E, None, [[100, K, False]], [100]),
                   key("bars", ["BTC"], E, 0, [[200, K, False]], [200]),
                   key("bars", ["ETH"], E, 1, [[50, K, False]], [50])]}),
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
    # An empty lineage, or none for the dependency, is unusable; a lineage member naming no dependency is not read.
    case(derived, [poll(P + 1000), ev(P + 3000, 0, [])], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                      upstream={"other": [PK]})], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [], [None])]}),
    case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                      upstream={"recording": [PK], "other": [["bars", ["BTC"], E]]})], P + 3000, [10**15],
         {"keys": [key("poll", ["h"], P, None, [[P + 1000, P + 1000, False]], [P + 1000]),
                   key("events", ["BTC"], E, 0, [[P + 3000, P + 1000 + LAG, False, E]], [P + 3000])]}),
    # §8: a later upstream correction does not move an earlier derived row; the recomputed row after it is bounded by it.
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
    # F-1: a lineage naming a dependency twice does not decode: the dataset is invalid (proposed, README 1).
    case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                      upstream=f'{{"recording": [], "recording": {json.dumps([PK])}}}')], P + 3000,
         [10**15], "INVALID"),
    case(derived, [poll(P + 1000), rev("events", P + 3000, {"coin": "BTC", "eventTime": E, "count": 0, "slot": E},
                                      upstream='{"recording": [["poll", "h", 36005000]]}')], P + 3000, [10**15],
         "INVALID"),
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
          rev("daily", E + 9000, {"coin": "BTC", "eventTime": E, "total": 0}, upstream={"counts": [["events", ["BTC"], E]]})],
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
]


def generate(n_pairs=1200, seed=20261102):
    """Generated stores: a bars source, the two evidence sources and the derived count, each key with up to four
    revisions (tombstones, corrections, identical repeats, rejected evaluations, undecodable slots), lineages drawn
    over the stored evidence keys and occasional absent ones or keys of other sources, until (key, query) pairs number
    at least n_pairs. The cutoff is drawn independently, so some cases see part of a store."""
    rng = random.Random(seed)
    out, total = [], 0
    hosts, coins = ("h", "g"), ("BTC", "ETH", "DOGE")
    while total < n_pairs:
        rows, ekeys, pkeys = [], [], []
        fetch = lambda: rng.randint(0, 30) * H + rng.choice((0, 1, 500, D))
        for _ in range(rng.randint(0, 3)):
            coin, e = rng.choice(coins), rng.choice((0, 1, 2)) * H + E
            for _ in range(rng.randint(1, 3)):
                cells = {"coin": coin, "eventTime": e, "close": rng.choice((1, 1, 2, None, 0.5))}
                if rng.random() < 0.15:
                    cells["reportedTime"] = rng.choice((e, e + 3 * H, "x"))
                rows.append(rev("bars", fetch(), cells, rng.random() < 0.15))
        for _ in range(rng.randint(0, 3)):
            host, i, obs = rng.choice(hosts), rng.randint(1, 2), E + rng.randint(0, 3) * 1000
            ekeys.append(["sight", [host, i], obs])
            for _ in range(rng.randint(1, 3)):
                rows.append(rev("sight", fetch(), s1(created=rng.randint(1, 2), observed=obs, host=host, i=i),
                                rng.random() < 0.1))
        for _ in range(rng.randint(0, 2)):
            host, recv = rng.choice(hosts), E + rng.randint(0, 3) * 1000
            pkeys.append(["poll", [host], recv])
            rows.append(rev("poll", fetch(), {"host": host, "recv": recv}))
        good, bad = ekeys + pkeys, [["sight", ["h", 9], E], ["bars", ["BTC"], E]]
        for _ in range(rng.randint(0, 3)):
            coin = rng.choice(coins)
            for _ in range(rng.randint(1, 3)):
                pool = good if good and rng.random() < 0.8 else good + bad
                lineage = rng.sample(pool, min(len(pool), 0 if rng.random() < 0.05 else rng.randint(1, 3)))
                rows.append(rev("events", rng.randint(15, 45) * H + rng.choice((0, 1, 500, D)),
                                {"coin": coin, "eventTime": E, "count": rng.randint(0, 2),
                                 "slot": rng.choice((E, E, E, "x"))}, rng.random() < 0.1, {"recording": lineage}))
        rng.shuffle(rows)
        version = rng.choice((40 * H, rng.randint(0, 40) * H))
        queries = sorted(rng.randint(0, 45) * H + rng.choice((-1, 0, 1, D, LAG)) for _ in range(4))
        lag = rng.choice((0, LAG))
        sources = (BARS if rng.random() < 0.7 else REPORTED, SIGHT, POLL,
                   src("events", COUNT, values=("count",), slot="slot",
                       deps=({"name": "recording", "sources": ["sight", "poll"], "lag": lag},)))
        c = case(sources, rows, version, queries, None)
        del c["expect"]
        out.append(c)
        entity = {x["name"]: x["entity"] + [x["event"]] for x in sources}
        total += len(queries) * len({(r["source"], json.dumps([json.loads(r["cells"]).get(k) for k in entity[r["source"]]]))
                                     for r in rows if r["fetchedAt"] <= version})
    return out
