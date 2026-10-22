"""C6.4: `mm` against the Lean reference kernel `refmm` on a frozen corpus (PROGRESS.md, stage 6).

`freeze` writes the corpus (`audit/stage6/c64-corpus.jsonl`) and its manifest before the judged run.
`run` rebuilds every market from the manifest and checks that each one hashes as frozen. It then
compares every program's verdict, and every run of it through `mmdump` (mm's own loader and
simulator) and `refmm`. Both emit every float as its bits, so equal output is bit-for-bit
agreement.
"""

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

from gate import kernel, markets, probes
from reference import c64_cases

REPO = Path(__file__).resolve().parents[1]
AUDIT = REPO / "audit" / "stage6"
REF = REPO / "reference/lean/.lake/build/bin/refmm"
DUMP = REPO / "reference/mmdump/target/release/mmdump"
GENERATOR = "kernel/mm/tests/rules.rs"
NULLS = ("N1", "N2", "N3")
DAYS = 550
EVENT_COINS = [0, 4, 7]
FLOATS = {"decision": (3, 4), "fill": (3, 5, 10, 11, 12), "unfilled": (3,), "funding": (3, 4, 5), "equity": (2, 3)}


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def build():
    kernel.build()
    subprocess.run(["lake", "build"], cwd=REPO / "reference/lean", check=True, capture_output=True)
    subprocess.run(["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True)


def generated(seed, n):
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "corpus.jsonl"
        env = os.environ | {"C64_SEED": str(seed), "C64_N": str(n), "C64_CORPUS": str(out)}
        subprocess.run(["cargo", "test", "-q", "--release", "--test", "rules", "emit_c64_corpus", "--", "--ignored"],
                       cwd=REPO / "kernel", env=env, check=True, capture_output=True)
        return out.read_text().splitlines()


def null_market(root, model, seed):
    params = json.loads((REPO / "gate/nulls.json").read_text())
    ev = {"arrays": np.random.default_rng(seed).poisson(2.0, (24 * 60, len(EVENT_COINS))).astype(float),
          "coins": EVENT_COINS, "block_hours": 24}
    arrays = markets.generate(model, params.get(model), f"c64-{model}-{seed}", DAYS, events=ev)
    return markets.write(root, arrays, 0, c64_cases.COST)


def store_hash(root):
    h = hashlib.sha256()
    for f in sorted((Path(root) / "store").rglob("*")):
        if f.is_file():
            h.update(str(f.relative_to(root)).encode())
            h.update(hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()


def corpus(seed, n):
    """[(name, program text, [market names])]."""
    w0 = (REPO / "kernel/strategies/w0.json").read_text()
    out = [(f"gen-{i}", p, list(NULLS)) for i, p in enumerate(generated(seed, n))]
    out += [("W0", w0, list(NULLS))] + [(f"probe-{p['name']}", json.dumps(p), list(NULLS)) for p in probes.probes(True)]
    out += [(f"case-{k}", json.dumps(p), [m]) for k, p, m in c64_cases.cases()]
    out += [(f"reject-{k}", json.dumps(p), []) for k, p in c64_cases.rejections().items()]
    out += [(f"adversarial-{f.stem}", f.read_text().split("\n", 1)[1], [])
            for f in sorted((REPO / "kernel/tests/adversarial").glob("*.case"))]
    return out


def markets_of(seed, work):
    roots = {m: null_market(work / m, m, seed) for m in NULLS}
    roots |= {m: f(work / m) for m, f in c64_cases.MARKETS.items()}
    return roots


def freeze(seed, n="1024", audit=AUDIT):
    """Write the corpus and manifest of the judged run, once."""
    audit = Path(audit)
    manifest = audit / "c64-manifest.json"
    if manifest.exists():
        raise FileExistsError(manifest)
    build()
    items = corpus(int(seed), int(n))
    with tempfile.TemporaryDirectory() as d:
        roots = markets_of(int(seed), Path(d))
        stores = {m: store_hash(r) for m, r in roots.items()}
    blob = subprocess.run(["git", "hash-object", GENERATOR], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip()
    audit.mkdir(parents=True, exist_ok=True)
    (audit / "c64-corpus.jsonl").write_text("".join(json.dumps({"name": k, "program": p, "markets": ms}) + "\n" for k, p, ms in items))
    manifest.write_text(json.dumps({
        "seed": int(seed), "generated": int(n), "generator": {"file": GENERATOR, "git_blob": blob},
        "corpus_sha256": sha((audit / "c64-corpus.jsonl").read_text()),
        "markets": {m: {"store_sha256": h, "version": c64_cases.VERSIONS.get(m, 1),
                        "spec": f"null model {m}, {DAYS} days, id c64-{m}-{seed}" if m in NULLS else f"reference/c64_cases.py {m}"}
                    for m, h in stores.items()},
        "initial_state": "kernel defaults: equity 10,000 USD, flat, from the market's w_start; no warm-up beyond each window's own",
        "numeric_policy": "bit-for-bit on every float, log/exp/sqrt included: no math library is declared different",
    }, indent=1) + "\n")
    return str(manifest)


def verdict_mm(path):
    r = subprocess.run([str(kernel.MM), "check", str(path)], capture_output=True, text=True)
    d = json.loads((r.stdout + r.stderr).strip().splitlines()[-1])
    return "ok" if d.get("ok") else d["code"]


def divergence(a, b):
    """First discrete and first numeric divergence between two runs, as (field, index, mm, ref)."""
    first = {}
    for key in ("abort", "reject"):
        if a.get(key) != b.get(key):
            first["discrete"] = (key, 0, a.get(key), b.get(key))
    ta, tb = a.get("trace", []), b.get("trace", [])
    for i, (x, y) in enumerate(zip(ta, tb)):
        fl = FLOATS.get(x[0], ())
        if "discrete" not in first and ([v for j, v in enumerate(x) if j not in fl] != [v for j, v in enumerate(y) if j not in fl] or len(x) != len(y)):
            first["discrete"] = ("trace", i, x, y)
        if "numeric" not in first and [x[j] for j in fl] != [y[j] for j in fl if j < len(y)]:
            first["numeric"] = ("trace", i, x, y)
    if "discrete" not in first and len(ta) != len(tb):
        first["discrete"] = ("trace length", min(len(ta), len(tb)), len(ta), len(tb))
    for key in ("returns", "gross_returns"):
        xs, ys = a.get(key, []), b.get(key, [])
        i = next((i for i, (x, y) in enumerate(zip(xs, ys)) if x != y), None)
        if "numeric" not in first and i is not None:
            first["numeric"] = (key, i, xs[i], ys[i])
    return first


def coverage(run):
    """Event counts of one run: decisions are the defined weights, and an abort counts under its code."""
    c = {f"abort {run['abort']}": 1} if "abort" in run else {}
    for e in run.get("trace", []):
        k = e[1] if e[0] == "fill" else e[0]
        c[k] = c.get(k, 0) + 1
    return c


def one(name, text, market, root, version, tmp):
    d = Path(tempfile.mkdtemp(dir=tmp))
    p = d / "p.json"
    p.write_text(text)
    subprocess.run([str(DUMP), p, root / "store", root / "venue", str(version), d / "mk.json", d / "a.json"], check=True, capture_output=True)
    subprocess.run([str(REF), "run", p, d / "mk.json", d / "b.json"], check=True, capture_output=True)
    a, b = json.loads((d / "a.json").read_text()), json.loads((d / "b.json").read_text())
    shutil.rmtree(d)
    return name, market, a == b, divergence(a, b) if a != b else {}, coverage(a)


def run(out, workers="4", audit=AUDIT):
    """The judged run on the frozen manifest; writes the report to `out`."""
    audit = Path(audit)
    manifest = json.loads((audit / "c64-manifest.json").read_text())
    text = (audit / "c64-corpus.jsonl").read_text()
    if sha(text) != manifest["corpus_sha256"]:
        raise ValueError("the corpus differs from the frozen manifest")
    items = [json.loads(l) for l in text.splitlines()]
    build()
    work = Path(tempfile.mkdtemp(dir=REPO / "data"))
    roots = markets_of(manifest["seed"], work)
    for m, r in roots.items():
        if store_hash(r) != manifest["markets"][m]["store_sha256"]:
            raise ValueError(f"market {m} does not rebuild as frozen")
    verdicts, codes = [], {}
    for it in items:
        f = work / "check.json"
        f.write_text(it["program"])
        ref = subprocess.run([str(REF), "check", str(f)], capture_output=True, text=True).stdout.strip()
        mm = verdict_mm(f)
        codes[mm] = codes.get(mm, 0) + 1
        if ref != mm:
            verdicts.append({"name": it["name"], "mm": mm, "ref": ref})
    jobs = [(it["name"], it["program"], m) for it in items for m in it["markets"]]
    with ThreadPoolExecutor(int(workers)) as pool:
        results = list(pool.map(lambda j: one(*j, roots[j[2]], manifest["markets"][j[2]]["version"], work), jobs))
    shutil.rmtree(work)
    total = {}
    for *_, cov in results:
        for k, v in cov.items():
            total[k] = total.get(k, 0) + v
    failures = [{"name": n, "market": m, "first": d} for n, m, ok, d, _ in results if not ok]
    report = {"manifest_sha256": sha((audit / "c64-manifest.json").read_text()), "programs": len(items),
              "verdict_disagreements": verdicts, "verdict_codes": codes, "runs": len(results),
              "run_disagreements": failures, "coverage": total,
              "pass": not verdicts and not failures}
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    return {k: report[k] for k in ("programs", "runs", "pass")} | {"verdict_disagreements": len(verdicts), "run_disagreements": len(failures)}
