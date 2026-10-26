"""C7.6's resolver suite (kernel/RULES.md §6-7), frozen before the resolver's implementations.

A case is one key's revisions under one rule:

    {"rule": TEXT, "fields": [...], "deps_declared": [...], "lags": {DEP: D},
     "revisions": [{"fetchedAt": INT, "tombstone": BOOL, "row": TEXT, "deps": TEXT}, ...],
     "version": V, "queries": [t, ...]}

`row` holds the revision's stored columns other than fetchedAt and the tombstone flag (as a JSON object text whose values
are integers, strings, booleans or null, compared as values in correction detection), `deps` the times the resolver
supplies for its dependencies, and `lags` each declared dependency's processing delay. The rule reads the row's fields
and `fetchedAt`, which is the revision's fetchedAt. The result is

    {"selected": FETCHEDAT or null, "knownAt": INT or CODE or null, "visible": [BOOL per query]}

or the string "INVALID" when two eligible revisions share a fetchedAt (RULES.md §6: the dataset is invalid). `selected`
is null when no revision is eligible, and then `knownAt` is null; a selected tombstone gives `knownAt` null. A rejected
rule evaluation, or an out-of-range bound, gives its code (RULES.md §5); `E_RULE` rejects the case before any revision.

- HAND: cases with hand-computed results: selection at and around the cutoff, no fallback to an older revision,
  tombstones (selected, superseded, restored), corrections (changed values, an absent column, a restored original, a
  tombstone in between), dependency bounds and their lags, a rejected evaluation, overflow of a bound, a duplicate
  fetchedAt, visibility at knownAt − 1, knownAt and knownAt + 1, and a corrected rule over the same revisions.
- generate(): at least 1,000 queries over generated multi-revision keys, from a fixed seed, with no expected results:
  the implementations must agree.
"""

import json
import random

from kernel.tests.rules.suite import D, H, add, dep, f, mx, rule

BAR = rule(add(f("eventTime"), {"ms": D}))
TD = rule(mx(add(f("eventTime"), {"ms": D}), dep("rec")))


def rev(fetched, row, tombstone=False, deps="{}"):
    return {"fetchedAt": fetched, "tombstone": tombstone, "row": json.dumps(row), "deps": deps}


def case(r, revisions, version, queries, expect, fields=("eventTime",), deps_declared=(), lags=None):
    return {"rule": r, "fields": list(fields), "deps_declared": list(deps_declared), "lags": lags or {},
            "revisions": revisions, "version": version, "queries": list(queries), "expect": expect}


E = 10 * H  # an eventTime
K = E + D  # its rule time
row = lambda v: {"eventTime": E, "close": v if v is None else int(v)}

HAND = [
    case(BAR, [rev(100, row(1.0))], 100, [K - 1, K, K + 1], {"selected": 100, "knownAt": K, "visible": [False, True, True]}),
    case(BAR, [rev(100, row(1.0))], 99, [K], {"selected": None, "knownAt": None, "visible": [False]}),
    case(BAR, [rev(100, row(1.0)), rev(200, row(1.0))], 150, [K], {"selected": 100, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(200, row(1.0))], 200, [K], {"selected": 200, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, row(2.0))], 50 * H, [K, 50 * H - 1, 50 * H],
         {"selected": 50 * H, "knownAt": 50 * H, "visible": [False, False, True]}),
    case(BAR, [rev(100, row(1.0)), rev(5, row(2.0))], 100, [K], {"selected": 100, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(200, row(2.0))], 200, [K], {"selected": 200, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, {"eventTime": E})], 50 * H, [50 * H],
         {"selected": 50 * H, "knownAt": 50 * H, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, row(None))], 50 * H, [50 * H],
         {"selected": 50 * H, "knownAt": 50 * H, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, {"eventTime": E}, tombstone=True)], 50 * H, [10**15],
         {"selected": 50 * H, "knownAt": None, "visible": [False]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, {"eventTime": E}, tombstone=True)], 40 * H, [K],
         {"selected": 100, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, {"eventTime": E}, tombstone=True), rev(60 * H, row(1.0))], 60 * H, [K],
         {"selected": 60 * H, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, row(1.0)), rev(50 * H, {"eventTime": E}, tombstone=True), rev(60 * H, row(3.0))], 60 * H, [K, 60 * H],
         {"selected": 60 * H, "knownAt": 60 * H, "visible": [False, True]}),
    case(BAR, [rev(100, row(1.0)), rev(100, row(2.0))], 100, [K], "INVALID"),
    case(BAR, [rev(100, row(1.0)), rev(100, row(2.0))], 99, [K], {"selected": None, "knownAt": None, "visible": [False]}),
    case(BAR, [rev(100, row(1.0)), rev(200, row(1.0)), rev(200, row(2.0))], 150, [K],
         {"selected": 100, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(100, {"close": 1})], 100, [K], {"selected": 100, "knownAt": "R_FIELD_ABSENT", "visible": [False]}),
    case(BAR, [rev(100, {"eventTime": 4611686018427387903 - D + 1})], 100, [0],
         {"selected": 100, "knownAt": "R_OVERFLOW", "visible": [False]}),
    case(BAR, [rev(100, {"eventTime": E})], 100, [K], {"selected": 100, "knownAt": K, "visible": [True]}),
    case(rule(f("u")), [rev(100, row(1.0))], 100, [K], "E_RULE"),
    case(TD, [rev(100, row(1.0), deps=json.dumps({"rec": K - 5}))], 100, [K], {"selected": 100, "knownAt": K, "visible": [True]},
         deps_declared=("rec",), lags={"rec": 0}),
    case(TD, [rev(100, row(1.0), deps=json.dumps({"rec": K + 7}))], 100, [K, K + 7],
         {"selected": 100, "knownAt": K + 7, "visible": [False, True]}, deps_declared=("rec",), lags={"rec": 0}),
    case(TD, [rev(100, row(1.0), deps=json.dumps({"rec": K - 5}))], 100, [K, K + 999, K + 1000],
         {"selected": 100, "knownAt": K + 995, "visible": [False, True, True]}, deps_declared=("rec",), lags={"rec": 1000}),
    case(TD, [rev(100, row(1.0), deps="{}")], 100, [K], {"selected": 100, "knownAt": "R_FIELD_ABSENT", "visible": [False]},
         deps_declared=("rec",), lags={"rec": 0}),
    case(TD, [rev(100, row(1.0), deps=json.dumps({"rec": 4611686018427387903}))], 100, [K],
         {"selected": 100, "knownAt": "R_OVERFLOW", "visible": [False]}, deps_declared=("rec",), lags={"rec": 1}),
    case(TD, [rev(100, row(1.0), deps=json.dumps({"rec": K})), rev(50 * H, row(2.0), deps=json.dumps({"rec": K}))], 50 * H, [K, 50 * H],
         {"selected": 50 * H, "knownAt": 50 * H, "visible": [False, True]}, deps_declared=("rec",), lags={"rec": 0}),
    case(BAR, [rev(100, row(1.0)), rev(200, {"eventTime": E, "close": 1, "extra": 5})], 200, [K, 200],
         {"selected": 200, "knownAt": K, "visible": [True, False]}),
    case(BAR, [rev(200, row(1.0)), rev(100, row(2.0))], 200, [K], {"selected": 200, "knownAt": K, "visible": [True]}),
    case(BAR, [rev(200, row(2.0)), rev(100, row(1.0)), rev(300, row(1.0))], 300, [K], {"selected": 300, "knownAt": K, "visible": [True]}),
    case(rule(add(f("eventTime"), {"ms": D + 1000})), [rev(100, row(1.0)), rev(200, row(1.0))], 200, [K, K + 1000],
         {"selected": 200, "knownAt": K + 1000, "visible": [False, True]}),
]


def generate(n_queries=1200, seed=20261026):
    """Generated keys, each with up to five revisions (some tombstones, some corrections, occasional deps), until the
    queries number at least n_queries."""
    rng = random.Random(seed)
    out, total = [], 0
    while total < n_queries:
        derived = rng.random() < 0.3
        r = TD if derived else BAR
        base = rng.choice((0, 5, 10)) * H
        revs, times = [], rng.sample(range(1, 80), rng.randint(1, 5))
        for k in times:
            tomb = rng.random() < 0.15
            values = {"eventTime": E + base} if tomb else {"eventTime": E + base, "close": rng.choice((1, 1, 2, None))}
            deps = json.dumps({"rec": E + base + rng.choice((-H, 0, D, H, 30 * H))}) if derived else "{}"
            revs.append(rev(k * H, values, tomb, deps))
        version = rng.choice((0, rng.randint(1, 80))) * H
        queries = sorted(rng.sample(range(0, 120), 4))
        c = case(r, revs, version, [q * H + rng.choice((-1, 0, 1, D)) for q in queries], None,
                 deps_declared=("rec",) if derived else (), lags={"rec": rng.choice((0, 1000))} if derived else {})
        del c["expect"]
        out.append(c)
        total += len(c["queries"])
    return out
