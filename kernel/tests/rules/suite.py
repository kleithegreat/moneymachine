"""C7.6's frozen suite for the availability rule language (kernel/RULES.md, version 1), frozen before any
implementation of it.

- HAND: cases with hand-computed results, covering every code, its precedence, boundaries at ±1 ms, negative
  timestamps, the ends of the range, floor underflow, JSON spelling, depth 64 against 65, the size limit, and a field
  sharing a dependency's name (added with RULES.md's clarification of 2026-10-26, before any judged run).
- generate(): at least 1,000 distinct well-typed (rule, row) pairs from a fixed seed, at least 100 each containing a
  floor, a maximum, an offset and a composition (an operator inside another's operand). They have no expected
  results: the implementations must agree on them.

Comparison: every implementation reads the cases as JSON lines on stdin (RULES.md §7) and writes one JSON line per
case, its result. A hand case passes when every implementation gives its expected result; a generated case when all
give the same result. Every case counts: a missing line, a crash, a timeout or a malformed output fails.
"""

import json
import random

H = 3_600_000
D = 120_000
LO, HI = -(2**62), 2**62 - 1


def rule(expr):
    return json.dumps({"rule": 1, "expr": expr})


def f(n):
    return {"field": n}


def dep(n):
    return {"dep": n}


def ms(n):
    return {"ms": n}


def add(t, d):
    return {"add": [t, d]}


def floor(t, p):
    return {"floor": [t, p]}


def mx(*a):
    return {"max": list(a)}


BAR = rule(add(f("eventTime"), ms(D)))
FUND = rule(mx(add(floor(f("reportedTime"), ms(H)), ms(D)), add(f("reportedTime"), ms(60_000))))
CEIL = rule(mx(add(floor(f("t"), ms(H)), ms(H)), f("t")))
T = rule(f("t"))
AB = rule(mx(f("a"), f("b")))
TD = rule(mx(f("t"), dep("d")))


def case(r, row, expect, fields=("t",), deps_declared=(), deps="{}"):
    return {"rule": r, "fields": list(fields), "deps_declared": list(deps_declared), "row": row, "deps": deps, "expect": expect}


def nest(depth):
    """A row whose unused member nests arrays so that the row's depth is exactly `depth`."""
    return '{"t": 1, "x": ' + "[" * (depth - 1) + "]" * (depth - 1) + "}"


def deep_rule(depth):
    """A valid rule document of exactly `depth` levels: the document, then pairs of an add object and its array."""
    e = f("t")
    for _ in range((depth - 2) // 2):
        e = add(e, ms(1))
    return rule(e), (depth - 2) // 2


HAND = [
    case(BAR, '{"eventTime": 14400000}', 14520000, ("eventTime",)),
    case(FUND, '{"reportedTime": 7200048}', 7320000, ("reportedTime",)),
    case(FUND, '{"reportedTime": 22487645}', 22547645, ("reportedTime",)),
    case(FUND, '{"reportedTime": 7200000}', 7320000, ("reportedTime",)),
    case(FUND, '{"reportedTime": 7259999}', 7320000, ("reportedTime",)),
    case(FUND, '{"reportedTime": 7260000}', 7320000, ("reportedTime",)),
    case(FUND, '{"reportedTime": 7260001}', 7320001, ("reportedTime",)),
    case(CEIL, '{"t": -1}', 0),
    case(CEIL, '{"t": -3600000}', 0),
    case(CEIL, '{"t": -3600001}', -3600000),
    case(CEIL, '{"t": 0}', 3600000),
    case(CEIL, '{"t": 3599999}', 3600000),
    case(rule(mx(floor(f("t"), ms(H)), f("t"))), '{"t": -1}', -1),
    case(rule(add(f("t"), ms(1))), '{"t": 4611686018427387902}', HI),
    case(rule(add(f("t"), ms(1))), '{"t": 4611686018427387903}', "R_OVERFLOW"),
    case(rule(mx(floor(f("t"), ms(3)), f("t"))), '{"t": -4611686018427387904}', "R_OVERFLOW"),
    case(rule(mx(floor(f("t"), ms(3)), f("t"))), '{"t": -4611686018427387902}', -4611686018427387902),
    case(rule(mx(f("t"), floor(f("t"), ms(3)))), '{"t": -4611686018427387904}', "R_OVERFLOW"),
    case(T, '{"t": -4611686018427387904}', LO),
    case(T, '{"t": 4611686018427387903}', HI),
    case(T, '{"t": 4611686018427387904}', "R_OVERFLOW"),
    case(T, '{"t": -4611686018427387905}', "R_OVERFLOW"),
    case(T, '{"t": 10000000000000000000}', "R_OVERFLOW"),
    case(T, '{"t": ' + "9" * 400 + "}", "R_OVERFLOW"),
    case(T, '{"t": -0}', 0),
    case(T, '{"t": 0}', 0),
    case(T, '{"t": 1.0}', "R_FIELD_TYPE"),
    case(T, '{"t": 1e3}', "R_FIELD_TYPE"),
    case(T, '{"t": 1E400}', "R_FIELD_TYPE"),
    case(T, '{"t": -0.0}', "R_FIELD_TYPE"),
    case(T, '{"t": true}', "R_FIELD_TYPE"),
    case(T, '{"t": false}', "R_FIELD_TYPE"),
    case(T, '{"t": "5"}', "R_FIELD_TYPE"),
    case(T, '{"t": [1]}', "R_FIELD_TYPE"),
    case(T, '{"t": {"a": 1}}', "R_FIELD_TYPE"),
    case(T, '{"t": null}', "R_FIELD_ABSENT"),
    case(T, '{}', "R_FIELD_ABSENT"),
    case(T, '{"T": 1}', "R_FIELD_ABSENT"),
    case(AB, '{"b": "x"}', "R_FIELD_ABSENT", ("a", "b")),
    case(AB, '{"a": "x"}', "R_FIELD_TYPE", ("a", "b")),
    case(AB, '{"a": 1, "b": null}', "R_FIELD_ABSENT", ("a", "b")),
    case(AB, '{"a": 4611686018427387904, "b": "x"}', "R_OVERFLOW", ("a", "b")),
    case(AB, '{"a": 5, "b": 7}', 7, ("a", "b")),
    case(AB, '{"a": 7, "b": 5, "c": "unused"}', 7, ("a", "b")),
    case(T, '{"t": 1, "t": 2}', "R_ROW"),
    case(T, '{"t": 1, "\\u0074": 2}', "R_ROW"),
    case(T, '{"t": 1, "x": {"a": 1, "a": 2}}', "R_ROW"),
    case(T, '{"t": 1, "x": NaN}', "R_ROW"),
    case(T, '{"t": 1, "x": Infinity}', "R_ROW"),
    case(T, '{"t": 1, "x": "\\ud800"}', "R_ROW"),
    case(T, '﻿{"t": 1}', "R_ROW"),
    case(T, '{"t": 1} x', "R_ROW"),
    case(T, '{"t": 1,}', "R_ROW"),
    case(T, '{"t": 01}', "R_ROW"),
    case(T, '{"t": +1}', "R_ROW"),
    case(T, '{"t": 1 /* c */}', "R_ROW"),
    case(T, '[{"t": 1}]', "R_ROW"),
    case(T, '"t"', "R_ROW"),
    case(T, '{', "R_ROW"),
    case(T, '', "R_ROW"),
    case(T, ' \n {"t": 3} \t', 3),
    case(T, '{"t": 1, "x": "\\ud83d\\ude00"}', 1),
    case(T, nest(64), 1),
    case(T, nest(65), "R_ROW"),
    case(TD, '{"t": 5}', 9, deps_declared=("d",), deps='{"d": 9}'),
    case(TD, '{"t": 11}', 11, deps_declared=("d",), deps='{"d": 9}'),
    case(TD, '{"t": 5}', "R_FIELD_ABSENT", deps_declared=("d",), deps='{}'),
    case(TD, '{"t": 5}', "R_ROW", deps_declared=("d",), deps='[]'),
    case(TD, '{"t": 5}', "R_ROW", deps_declared=("d",), deps='{"d": 1, "d": 2}'),
    case(TD, '{"t": "x"}', "R_ROW", deps_declared=("d",), deps='{"d": 1,}'),
    case(TD, '{"t": 5}', "R_FIELD_TYPE", deps_declared=("d",), deps='{"d": 9.0}'),
    case(rule(add(f("t"), ms(0))), '{"t": 5}', 5),
    case(json.dumps({"rule": 1, "expr": {"add": [{"field": "t"}, {"ms": 0}]}}).replace('"ms": 0', '"ms": -0'), '{"t": 5}', 5),
    case(rule(f("é")), '{"\\u00e9": 4}', 4, ("é",)),
    case(rule(f("t")).replace('"t"', '"\\u0074"'), '{"t": 4}', 4),
    case(rule({"ceil": [f("t"), ms(H)]}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"rule": 1, "expr": {"field": "t", "ms": 1}}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"rule": 2, "expr": f("t")}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"rule": 1.0, "expr": f("t")}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"rule": True, "expr": f("t")}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"expr": f("t")}), '{"t": 1}', "E_RULE"),
    case(json.dumps({"rule": 1, "expr": f("t"), "note": "x"}), '{"t": 1}', "E_RULE"),
    case(json.dumps([1, f("t")]), '{"t": 1}', "E_RULE"),
    case(rule(f("u")), '{"u": 1}', "E_RULE"),
    case(rule(f("")), '{"t": 1}', "E_RULE"),
    case(rule(mx(f("t"), dep("e"))), '{"t": 1}', "E_RULE", deps_declared=("d",)),
    case(rule(f("t")), '{"t": 1}', "E_RULE", deps_declared=("d",)),
    case(rule(f("d")), '{"d": 1}', "E_RULE", ("d",), deps_declared=("d",)),
    case(rule(mx(f("d"), dep("d"))), '{"d": 1}', 4, ("d",), deps_declared=("d",), deps='{"d": 4}'),
    case(rule({"add": [ms(1), f("t")]}), '{"t": 1}', "E_RULE"),
    case(rule(add(f("t"), f("t"))), '{"t": 1}', "E_RULE"),
    case(rule(ms(5)), '{"t": 1}', "E_RULE"),
    case(rule(add(f("t"), ms(-1))), '{"t": 1}', "E_RULE"),
    case(rule(add(f("t"), ms(2**62))), '{"t": 1}', "E_RULE"),
    case(rule(add(f("t"), ms(HI))), '{"t": 0}', HI),
    case(rule(add(f("t"), {"ms": 1.0})), '{"t": 1}', "E_RULE"),
    case(rule(add(f("t"), {"ms": True})), '{"t": 1}', "E_RULE"),
    case(rule(mx(floor(f("t"), ms(0)), f("t"))), '{"t": 1}', "E_RULE"),
    case(rule(mx(floor(f("t"), f("t")), f("t"))), '{"t": 1}', "E_RULE"),
    case(rule(floor(f("t"), ms(H))), '{"t": 1}', "E_RULE"),
    case(rule(mx(floor(f("t"), ms(H)), floor(f("t"), ms(60_000)))), '{"t": 1}', "E_RULE"),
    case(rule(mx(f("t"))), '{"t": 1}', "E_RULE"),
    case(rule(mx(*[f("t")] * 16)), '{"t": 1}', 1),
    case(rule(mx(*[f("t")] * 17)), '{"t": 1}', "E_RULE"),
    case(rule({"add": [f("t")]}), '{"t": 1}', "E_RULE"),
    case(rule({"add": [f("t"), ms(1), ms(1)]}), '{"t": 1}', "E_RULE"),
    case(rule({"field": 5}), '{"t": 1}', "E_RULE"),
    case(rule(5), '{"t": 1}', "E_RULE"),
    case(rule(None), '{"t": 1}', "E_RULE"),
    case('﻿' + T, '{"t": 1}', "E_RULE"),
    case(T + " x", '{"t": 1}', "E_RULE"),
    case('{"rule": 1, "rule": 1, "expr": {"field": "t"}}', '{"t": 1}', "E_RULE"),
    case('{"rule": 1, "expr": {"field": "t", "field": "t"}}', '{"t": 1}', "E_RULE"),
    case(T, '{"t": 1, "t": 1}', "R_ROW"),
    case(rule(f("u")), '{', "E_RULE"),
    case(deep_rule(64)[0], '{"t": 0}', deep_rule(64)[1]),
    case(deep_rule(66)[0], '{"t": 0}', "E_RULE"),
    case(rule(mx(f("t"), f("x" * 70_000))), '{"t": 1}', "E_RULE", ("t", "x" * 70_000)),
]


def leaf(rng, fields, deps):
    """A Time leaf: a field or a declared dependency."""
    if deps and rng.random() < 0.25:
        return dep(rng.choice(deps))
    return f(rng.choice(fields))


def time_expr(rng, fields, deps, depth):
    """A well-typed Time expression whose lower-bound set is non-empty."""
    if depth == 0 or rng.random() < 0.25:
        return leaf(rng, fields, deps)
    op = rng.choice(("add", "max", "floor_in_max"))
    if op == "add":
        return add(time_expr(rng, fields, deps, depth - 1), ms(rng.choice((0, 1, 59_999, 60_000, D, H, H - 1, 86_400_000, rng.randrange(0, 10**7)))))
    if op == "max":
        return mx(*[time_expr(rng, fields, deps, depth - 1) for _ in range(rng.randint(2, 4))])
    period = rng.choice((1, 3, 1000, 60_000, H, 4 * H, 86_400_000, rng.randrange(1, 10**8)))
    return mx(floor(time_expr(rng, fields, deps, depth - 1), ms(period)), time_expr(rng, fields, deps, depth - 1))


def lower_bound(e):
    k, v = next(iter(e.items()))
    if k in ("field", "dep"):
        return {(k, v)}
    if k == "add":
        return lower_bound(v[0])
    if k == "max":
        return set().union(*map(lower_bound, v))
    return set()


def value(rng):
    return rng.choice((
        rng.randrange(-10**13, 2 * 10**12),
        rng.randrange(0, 2000) * H + rng.choice((-1, 0, 1, 48, 887_645)),
        -rng.randrange(0, 2000) * H + rng.choice((-1, 0, 1)),
        HI - rng.randrange(0, 10**8),
        LO + rng.randrange(0, 10**8),
        0,
    ))


def generate(n=2000, seed=20261026):
    """n distinct generated cases, each well typed with a non-empty lower-bound set containing every declared dependency."""
    rng = random.Random(seed)
    out, seen = [], set()
    while len(out) < n:
        fields = rng.sample(("t", "eventTime", "reportedTime", "fetchedAt", "a", "b"), rng.randint(1, 3))
        deps = rng.sample(("d", "e"), rng.choice((0, 0, 1, 2)))
        e = time_expr(rng, fields, deps, rng.randint(1, 4))
        if deps:
            e = mx(e, *[dep(d) for d in deps])
        if not {("dep", d) for d in deps} <= lower_bound(e) or not lower_bound(e):
            continue
        row = {k: value(rng) for k in fields if rng.random() > 0.03}
        dmap = {k: value(rng) for k in deps if rng.random() > 0.03}
        c = {"rule": rule(e), "fields": sorted(fields), "deps_declared": sorted(deps), "row": json.dumps(row),
             "deps": json.dumps(dmap)}
        key = json.dumps(c, sort_keys=True)
        if key not in seen:
            seen.add(key)
            out.append(c)
    return out


def classes(c):
    """Which of C7.6's four structural classes a case's rule exercises."""
    text = json.loads(c["rule"])["expr"]

    def walk(e, inside):
        k, v = next(iter(e.items()))
        found = {"floors"} if k == "floor" else {"maxima"} if k == "max" else {"offsets"} if k == "add" else set()
        if inside and k in ("add", "max", "floor"):
            found.add("composition")
        for x in (v if isinstance(v, list) else []):
            found |= walk(x, inside or k in ("add", "max", "floor"))
        return found

    return walk(text, False)
