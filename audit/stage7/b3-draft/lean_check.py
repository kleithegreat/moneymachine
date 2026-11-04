"""The suite against Lean's `timeline` and `resolveAll` (`refmm resolve`): every hand case's expected result, the REACHED
floors over the generated stores, and, per delivered key, `resolveAll`'s observations against the delivery its own
timeline gives (RULES.md §6's "Visibility and delivery", revision of 2026-11-04): the shape of C7.6's loader-level
comparison, which the actual loaders join in slice 5.

    nix develop -c python audit/stage7/b3-draft/lean_check.py [REFMM]
"""

import json
import struct
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

sys.path[:0] = [str(Path(__file__).parent), str(Path(__file__).parents[3])]
import resolver_suite as suite  # noqa: E402

REFMM = Path(__file__).parents[3] / "reference/lean/.lake/build/bin/refmm"


def same(a, b):
    """Equal as §7 reads results: an integer only to an integer, a non-integer only to a non-integer, by value."""
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(map(same, a, b))
    return a == b


def lean(cases, refmm):
    with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
        json.dump([{k: v for k, v in c.items() if k != "expect"} for c in cases], f)
        f.flush()
        out = subprocess.run([str(refmm), "resolve", f.name], capture_output=True, text=True, check=True).stdout
    return [json.loads(line) for line in out.splitlines()]


def bits(cell):
    if type(cell) is int or type(cell) is float:
        return struct.unpack("<Q", struct.pack("<d", float(cell)))[0]
    return None


def deliveries(c, result):
    """The observations a §7 result gives: per key of U of a non-evidence source, each entry, sorted as refmm sorts."""
    by, out = {s["name"]: s for s in c["sources"]}, []
    for k in result["keys"]:
        s = by[k["source"]]
        if s["evidence"] or k["coin"] is None:
            continue
        for i, (fetched, known, retraction, slot, cells, role) in enumerate(k["timeline"]):
            values = [None if retraction else bits(cells[v]) for v in s["values"]]
            payload = None if role is None else [bits(x) for x in role[:-1]] + [role[-1]] if "bars" in s["roles"] else [
                bits(role[0])]
            out.append([s["name"], k["coin"], k["event"], fetched, known, retraction, slot, values, payload,
                        i + 1 == len(k["timeline"])])
    return sorted(out, key=lambda o: (o[0], o[1], o[2], o[3]))


def main(refmm=REFMM):
    failures = []
    for i, (c, got) in enumerate(zip(suite.HAND, lean(suite.HAND, refmm))):
        if not same(got["result"], c["expect"]):
            failures.append((i, c["expect"], got["result"]))
    print(f"hand: {len(suite.HAND) - len(failures)} of {len(suite.HAND)} agree with Lean")
    for f in failures:
        print("  disagrees:", *f, sep="\n    ")
    stores = suite.generate()
    results = lean(stores, refmm)
    outcome = Counter("resolves" if isinstance(r["result"], dict) else r["result"] for r in results)
    reached = Counter(t for c, r in zip(stores, results) for t in suite.reached(c, r["result"]))
    print(f"generated: {len(stores)} stores, {dict(outcome)}; pairs {suite.pairs(stores)}")
    print("reached:", {t: reached[t] for t in suite.REACHED})
    short = [t for t in suite.REACHED if reached[t] < suite.FLOOR]
    projection = [i for i, (c, r) in enumerate(zip(suite.HAND + stores, lean(suite.HAND, refmm) + results))
                  if isinstance(r["result"], dict) and not same(deliveries(c, r["result"]), r["observations"])]
    print(f"observations: resolveAll differs from its timeline's delivery in {len(projection)} cases {projection[:10]}")
    return 1 if failures or short or projection else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
