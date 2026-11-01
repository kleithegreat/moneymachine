"""Stage 7 port, slice 6: `mm::admission::admit` (through `mmdump admit`) against Lean's `admit` (through `refmm admit`)
on random admission cases: registries of declaration files, role selections, bindings, certificates, supersessions,
holdout identities and stored event times, each mutated toward one refusal. A development run, never judged.

usage: python -m reference.admission_differential [CASES] [SEED]

Each case's declarations are files `mm` parses; the Lean side reads this script's own decoding of each file
(`lean_decl`), so the two agree only if `mm`'s `Declaration::controls` and `source::depends` do.
"""

import hashlib
import json
import random
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REF = REPO / "reference/lean/.lake/build/bin/refmm"
DUMP = REPO / "reference/mmdump/target/release/mmdump"


def declaration(rng: random.Random, s: int) -> dict:
    """Declaration s: held or event over coins, or evidence; its dependencies on earlier declarations only. The
    first two are usually a bars and a settlement provider."""
    provider = {0: "bars", 1: "settlement"}.get(s) if rng.random() < 0.9 else None
    kind = "held" if provider else rng.choice(["held", "held", "event", "evidence"])
    deps = {}
    if s > 0:
        for name in rng.sample(["a", "b", "c"], rng.randint(0, 2)):
            deps[name] = {"sources": [f"s{u}" for u in rng.sample(range(s), rng.randint(1, min(2, s)))], "lag_ms": rng.randint(0, 9)}
    if kind == "evidence":
        times = ["recv"]
        key = rng.sample(["key", "id"], rng.randint(0, 1)) + ["recv"]
        rng.shuffle(key)
        entity = {"evidence": key, "event": "recv"}
        fields, cadence, role = {}, {"evidence": {}}, {}
    else:
        times = rng.choice([["eventTime"], ["eventTime", "reportedTime"]])
        entity = "coin"
        fields = {f"x{s}_{k}": {"column": f"c{k}", "unit": "1"} for k in range(rng.randint(1, 2))}
        slot = rng.choice(times)
        cadence = {"held": {"period_ms": 3600000, "phase_ms": 0, "slot": slot}} if kind == "held" else {"event": {"slot": slot}}
        role = {}
        if provider or kind == "held" and rng.random() < 0.3:
            r = provider or rng.choice(["bars", "settlement", "both"])
            if r in ("bars", "both"):
                role["bars"] = {c: rng.choice([c, "p" + c]) for c in ["open", "high", "low", "close", "trades"]}
            if r in ("settlement", "both"):
                role["settlement"] = {"rate": rng.choice(["rate", "c0"])}
    terms = [{"field": times[0]}, {"field": "fetchedAt"}] + [{"dep": d} for d in deps]
    return {"declaration": 1, "name": f"s{s}", "version": 1, "entity": entity, "times": times, "fields": fields,
            "cadence": cadence, "missing": "undefined", "revisions": "latest",
            "rule": {"rule": 1, "expr": {"max": terms}}, "depends": deps, "role": role}


def lean_decl(text: str, names: list[str]) -> dict:
    """The declaration as Lean's `Decl` reads it for admission: an evidence declaration's event column, and its other
    key columns as the entity columns."""
    d = json.loads(text)
    cad = next(iter(d["cadence"]))
    if cad == "evidence":
        event = d["entity"]["event"]
        entity = [k for k in d["entity"]["evidence"] if k != event]
    else:
        event, entity = "eventTime", ["coin"]
    return {"hash": hashlib.sha256(text.encode()).hexdigest(), "times": d["times"] + ["fetchedAt"], "event": event,
            "slot": d["cadence"]["event"]["slot"] if cad == "event" else None, "entity": entity, "revision": ["tombstone"],
            "cadence": cad,
            "deps": [[[names.index(u) for u in dep["sources"]], name, dep["lag_ms"]] for name, dep in sorted(d["depends"].items())],
            "roles": [[r, [[c, cols[c]] for c in (["open", "high", "low", "close", "trades"] if r == "bars" else ["rate"])]]
                      for r, cols in d["role"].items()]}


def controls(ld: dict) -> list[str]:
    return sorted(set(ld["times"] + [ld["event"]] + ld["entity"] + ([ld["slot"]] if ld["slot"] else []) + ld["revision"]))


def case(rng: random.Random) -> dict:
    n = rng.randint(2, 6)
    texts = [json.dumps(declaration(rng, s), indent=rng.choice([None, 1])) for s in range(n)]
    names = [f"s{s}" for s in range(n)]
    decls = [lean_decl(t, names) for t in texts]
    provides = lambda r: [s for s, d in enumerate(decls) if any(x[0] == r for x in d["roles"])]
    bars, settle = provides("bars"), provides("settlement")
    roles = [rng.choice(bars) if bars and rng.random() < 0.95 else rng.randrange(n + 1),
             rng.choice(settle) if settle and rng.random() < 0.95 else rng.randrange(n + 1)]
    readable = [s for s, d in enumerate(decls) if d["cadence"] != "evidence"]
    sources = rng.sample(readable, rng.randint(0, min(2, len(readable))))
    holdout = ["h-old"]
    bindings = []
    for s in range(n):
        if rng.random() < 0.9:
            dataset = rng.choice(holdout) if rng.random() < 0.04 else f"d{s}"
            bindings.append([s, dataset, f"k{s}"])
    if rng.random() < 0.05 and bindings:
        bindings.insert(0, [bindings[-1][0], "d-dup", f"k{bindings[-1][0]}"])
    bound = {}
    for s, dataset, cert in bindings:
        bound.setdefault(s, (dataset, cert))
    certs = []
    for s, (dataset, cert) in bound.items():
        d = decls[s]
        k = {"id": cert, "decl": d["hash"], "manifest": dataset, "policy": "P", "verifier": "V",
             "upstream": sorted({bound[u][1] for us, _, _ in d["deps"] for u in us if u in bound}), "controls": controls(d),
             "venueState": rng.random() < 0.95}
        for field, wrong in [("decl", "x"), ("manifest", "x"), ("policy", "P2"), ("verifier", "V2")]:
            if rng.random() < 0.02:
                k[field] = wrong
        if rng.random() < 0.03:
            k["upstream"] = k["upstream"] + [rng.choice([f"k{u}" for u in range(n)] + ["k-none"])]
        if rng.random() < 0.03 and k["upstream"]:
            k["upstream"] = k["upstream"][1:]
        if rng.random() < 0.04:
            k["controls"] = [c for c in k["controls"] if c != rng.choice(k["controls"])]
        if rng.random() < 0.02:
            k["controls"] = k["controls"] + ["extra"]
        if rng.random() < 0.97:
            certs.append(k)
        if rng.random() < 0.02:
            certs.insert(0, {**k, "venueState": not k["venueState"], "manifest": "x"})
    rng.shuffle(certs)
    position = rng.randint(0, 5)
    supersessions = [[rng.choice([k["id"] for k in certs]), rng.randint(0, 8)] for _ in range(rng.randint(0, 2)) if certs and rng.random() < 0.3]
    holdout_start = rng.choice([100, 1000])
    rows = [[s, rng.choice([0, 50, 99, 100, 500, 999, 1000])] for s in range(n) for _ in range(rng.randint(0, 2))]
    return {"decls": [{"text": t, **d} for t, d in zip(texts, decls)], "roles": roles, "sources": sources,
            "bindings": bindings, "certs": certs, "supersessions": supersessions, "position": position, "policy": "P",
            "verifier": "V", "holdout": holdout, "holdoutStart": holdout_start,
            "mode": "search" if rng.random() < 0.85 else "holdout", "rows": rows}


def main(count: int = 20000, seed: int = 0) -> int:
    subprocess.run(["lake", "build", "refmm"], cwd=REPO / "reference/lean", check=True, capture_output=True)
    subprocess.run(["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True)
    rng = random.Random(seed)
    cases = [case(rng) for _ in range(count)]
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "cases.json"
        path.write_text(json.dumps(cases))
        out = {exe.name: subprocess.run([str(exe), "admit", str(path)], check=True, capture_output=True, text=True).stdout.splitlines()
               for exe in (REF, DUMP)}
    lean, rust = out["refmm"], out["mmdump"]
    assert len(lean) == len(rust) == count, (len(lean), len(rust))
    diffs = [i for i in range(count) if lean[i] != rust[i]]
    outcomes = Counter(x.split(" ")[0] + ("" if x.startswith("ok") else " " + x.split(" ")[1]) for x in lean)
    print(json.dumps({"cases": count, "seed": seed, "disagreements": len(diffs), "outcomes": dict(sorted(outcomes.items()))}))
    for i in diffs[:5]:
        print(i, "lean:", lean[i], "mm:", rust[i])
    return 1 if diffs else 0


if __name__ == "__main__":
    sys.exit(main(*map(int, sys.argv[1:])))
