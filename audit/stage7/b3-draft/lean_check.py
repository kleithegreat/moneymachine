"""The suite against Lean's `timeline` and `resolveAll` (`refmm resolve`): the two files equal `HAND` and the stores
`generate` gives over Lean's results, with their size; every hand case's expected result; the REACHED floors over the
generated stores; and `resolveAll`'s observations against the delivery a timeline gives (RULES.md §6's "Visibility and
delivery", revision of 2026-11-04), the hand case's expected one or a generated store's Lean result: the shape of
C7.6's loader-level comparison, which the actual loaders join in slice 5.

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
import resolver_suite as suite

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
    lines = [json.loads(line) for line in out.splitlines()]
    assert len(lines) == len(cases), (len(lines), len(cases))
    return lines


def lines(name):
    return [json.loads(line) for line in (Path(__file__).parent / name).read_text().splitlines()]


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
    hand = lean(suite.HAND, refmm)
    failures = [(i, c["expect"], got["result"]) for i, (c, got) in enumerate(zip(suite.HAND, hand, strict=True))
                if not same(got["result"], c["expect"])]
    print(f"hand: {len(suite.HAND) - len(failures)} of {len(suite.HAND)} agree with Lean")
    for f in failures:
        print("  disagrees:", *f, sep="\n    ")
    stores = suite.generate(lambda c: lean([c], refmm)[0]["result"])
    results = lean(stores, refmm)
    files = same(lines("resolver_hand.jsonl"), suite.HAND) and same(lines("resolver_generated.jsonl"), stores)
    outcome = Counter("resolves" if isinstance(r["result"], dict) else r["result"] for r in results)
    size = sum(suite.delivered(c, r["result"]) for c, r in zip(stores, results, strict=True))
    reached = Counter(t for c, r in zip(stores, results, strict=True) for t in suite.reached(c, r["result"]))
    print(f"files equal HAND and generate(): {files}")
    print(f"generated: {len(stores)} stores, {dict(outcome)}, {sum(map(suite.image, stores))} with a Parquet image; "
          f"delivered pairs {size}, at least {suite.SIZE}")
    print("reached:", {t: reached[t] for t in suite.REACHED})
    short = [t for t in suite.REACHED if reached[t] < suite.FLOOR]
    expected = [c["expect"] for c in suite.HAND] + [r["result"] for r in results]
    projection = [i for i, (c, e, r) in enumerate(zip(suite.HAND + stores, expected, hand + results, strict=True))
                  if isinstance(e, dict) and not same(deliveries(c, e), r["observations"])]
    print(f"observations: resolveAll differs from the timeline's delivery in {len(projection)} cases {projection[:10]}")
    return 1 if failures or short or projection or not files or size < suite.SIZE else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
