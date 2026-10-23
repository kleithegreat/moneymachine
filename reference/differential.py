"""C6.4: `mm` against the Lean reference kernel `refmm` on a frozen corpus (PROGRESS.md, stage 6).

`freeze` writes the corpus (`audit/stage6/differential-corpus.jsonl`) and its manifest before the judged run.
`run` rebuilds every market from the manifest and checks each against its frozen hash (store and venue). It
then compares every program's verdict, and every run through `mmdump` (mm's own loader, simulator and
machine) and `refmm`. A run's output is the trace, returns, gross returns, each node's static type and the count of
defined node values, every float as its bits, and a stream file holding every node's value (definedness and
bits) for every coin at every tick of the machine's schedule, a replay of that schedule beside the simulator
run. Both are compared byte for byte. `pass` also requires the corpus to hold every expected component.
"""

import filecmp
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
from reference import edge_markets

REPO = Path(__file__).resolve().parents[1]
AUDIT = REPO / "audit" / "stage6"
REF = REPO / "reference/lean/.lake/build/bin/refmm"
DUMP = REPO / "reference/mmdump/target/release/mmdump"
GENERATOR = "kernel/mm/tests/rules.rs"
NULLS = ("N1", "N2", "N3")
DAYS = 550
EVENT_COINS = [0, 4, 7]
FLOATS = {"decision": (3, 4), "fill": (3, 5, 10, 11, 12), "unfilled": (3,), "funding": (3, 4, 5), "equity": (2, 3)}
MANIFEST, CORPUS = "differential-manifest.json", "differential-corpus.jsonl"


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def build():
    kernel.build()
    subprocess.run(["lake", "build"], cwd=REPO / "reference/lean", check=True, capture_output=True)
    subprocess.run(["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True)


def generated(seed, n):
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "corpus.jsonl"
        env = os.environ | {"CORPUS_SEED": str(seed), "CORPUS_N": str(n), "CORPUS_OUT": str(out)}
        subprocess.run(["cargo", "test", "-q", "--release", "--test", "rules", "emit_differential_corpus", "--", "--ignored"],
                       cwd=REPO / "kernel", env=env, check=True, capture_output=True)
        programs = out.read_text().splitlines()
    if len(programs) != n:
        raise ValueError(f"the generator emitted {len(programs)} programs, not {n}")
    return programs


def null_market(root, model, seed):
    params = json.loads((REPO / "gate/nulls.json").read_text())
    ev = {"arrays": np.random.default_rng(seed).poisson(2.0, (24 * 60, len(EVENT_COINS))).astype(float),
          "coins": EVENT_COINS, "block_hours": 24}
    arrays = markets.generate(model, params.get(model), f"differential-{model}-{seed}", DAYS, events=ev)
    return markets.write(root, arrays, 0, edge_markets.COST)


def market_hash(root):
    """Of every file of the market: the store, its policy and the venue's rules and execution model."""
    h = hashlib.sha256()
    for f in sorted(Path(root).rglob("*")):
        if f.is_file():
            h.update(str(f.relative_to(root)).encode())
            h.update(hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()


def corpus(seed, n):
    """[(name, program text, [market names])]: generated programs, W0 and the probes on the null markets; every
    deterministic case on its own market and the null markets; rejections and adversarial cases checked only."""
    w0 = (REPO / "kernel/strategies/w0.json").read_text()
    out = [(f"gen-{i}", p, list(NULLS)) for i, p in enumerate(generated(seed, n))]
    out += [("W0", w0, list(NULLS))] + [(f"probe-{p['name']}", json.dumps(p), list(NULLS)) for p in probes.probes(True)]
    out += [(f"case-{k}", json.dumps(p), ms) for k, p, ms in edge_markets.cases(NULLS)]
    out += [(f"reject-{k}", json.dumps(p), []) for k, p in edge_markets.rejections().items()]
    out += [(f"adversarial-{f.stem}", f.read_text().split("\n", 1)[1], [])
            for f in sorted((REPO / "kernel/tests/adversarial").glob("*.case"))]
    return out


def expected():
    """name -> markets of every corpus item but the generated programs."""
    out = {"W0": list(NULLS)} | {f"probe-{p['name']}": list(NULLS) for p in probes.probes(True)}
    out |= {f"case-{k}": ms for k, _, ms in edge_markets.cases(NULLS)}
    out |= {f"reject-{k}": [] for k in edge_markets.rejections()}
    return out | {f"adversarial-{f.stem}": [] for f in sorted((REPO / "kernel/tests/adversarial").glob("*.case"))}


def complete(items, generated_n, minimum=1000):
    """What the corpus lacks against C6.4's list, or []: every expected item on exactly its markets, all
    `generated_n` generated programs on every null market, and at least `minimum` (0 for a development run) of
    them distinct (both sides of a rewrite instance can coincide)."""
    by = {it["name"]: it for it in items}
    missing = [f"{k} on {ms}" for k, ms in expected().items() if k not in by or sorted(by[k]["markets"]) != sorted(ms)]
    gen = [it for it in items if it["name"].startswith("gen-")]
    distinct = len({it.get("program") for it in gen})
    if len(gen) < generated_n or distinct < minimum:
        missing.append(f"{len(gen)} generated programs of {generated_n}, {distinct} distinct of at least {minimum}")
    missing += [f"{it['name']} not on every null market" for it in gen if sorted(it["markets"]) != sorted(NULLS)]
    return missing


def markets_of(seed, work):
    roots = {m: null_market(work / m, m, seed) for m in NULLS}
    roots |= {m: f(work / m) for m, f in edge_markets.MARKETS.items()}
    return roots


def freeze(seed, n="1024", audit=AUDIT, minimum=1000):
    """Write the corpus and manifest of the judged run, once."""
    audit = Path(audit)
    manifest = audit / MANIFEST
    if manifest.exists():
        raise FileExistsError(manifest)
    build()
    items = corpus(int(seed), int(n))
    missing = complete([{"name": k, "program": p, "markets": ms} for k, p, ms in items], int(n), minimum)
    if missing:
        raise ValueError(f"incomplete corpus: {missing}")
    with tempfile.TemporaryDirectory() as d:
        hashes = {m: market_hash(r) for m, r in markets_of(int(seed), Path(d)).items()}
    blob = subprocess.run(["git", "hash-object", GENERATOR], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip()
    audit.mkdir(parents=True, exist_ok=True)
    (audit / CORPUS).write_text("".join(json.dumps({"name": k, "program": p, "markets": ms}) + "\n" for k, p, ms in items))
    manifest.write_text(json.dumps({
        "seed": int(seed), "generated": int(n), "minimum": minimum, "generator": {"file": GENERATOR, "git_blob": blob},
        "corpus_sha256": sha((audit / CORPUS).read_text()),
        "markets": {m: {"market_sha256": h, "version": edge_markets.VERSIONS.get(m, 1),
                        "spec": f"null model {m}, {DAYS} days, id differential-{m}-{seed}" if m in NULLS else f"reference/edge_markets.py {m}"}
                    for m, h in hashes.items()},
        "initial_state": "kernel defaults: equity 10,000 USD, flat, from the market's w_start; no warm-up beyond each window's own",
        "numeric_policy": "bit-for-bit on every float, log/exp/sqrt included: no math library is declared different",
    }, indent=1) + "\n")
    return str(manifest)


def verdict_mm(path):
    r = subprocess.run([str(kernel.MM), "check", str(path)], capture_output=True, text=True)
    d = json.loads((r.stdout + r.stderr).strip().splitlines()[-1])
    return "ok" if d.get("ok") else d["code"]


def divergence(a, b):
    """The first discrete and the first numeric divergence between two runs, as (field, index, mm, ref)."""
    first = {}
    for key in sorted(set(a) | set(b)):
        if key in ("trace", "returns", "gross_returns", "nodes"):
            continue
        if a.get(key) != b.get(key):
            first.setdefault("discrete", (key, 0, a.get(key), b.get(key)))
    ta, tb = a.get("trace", []), b.get("trace", [])
    for i, (x, y) in enumerate(zip(ta, tb)):
        fl = FLOATS.get(x[0], ()) if x[0] == y[0] else ()
        if "discrete" not in first and (len(x) != len(y) or [v for j, v in enumerate(x) if j not in fl] != [v for j, v in enumerate(y) if j not in fl]):
            first["discrete"] = ("trace", i, x, y)
        if "numeric" not in first and fl and [x[j] for j in fl] != [y[j] for j in fl]:
            first["numeric"] = ("trace", i, x, y)
    if len(ta) != len(tb):
        first.setdefault("discrete", ("trace length", min(len(ta), len(tb)), len(ta), len(tb)))
    for key in ("returns", "gross_returns"):
        xs, ys = a.get(key, []), b.get(key, [])
        i = next((i for i, (x, y) in enumerate(zip(xs, ys)) if x != y), None)
        if i is not None:
            first.setdefault("numeric", (key, i, xs[i], ys[i]))
        if len(xs) != len(ys):
            first.setdefault("discrete", (f"{key} length", min(len(xs), len(ys)), len(xs), len(ys)))
    if a.get("nodes") != b.get("nodes"):
        first.setdefault("discrete", ("nodes", 0, a.get("nodes"), b.get("nodes")))
    return first


def stream_divergence(sa, sb, nodes, coins):
    """The first discrete (definedness) and first numeric (bits) difference between two stream files, as
    (field, (tick, node, coin), mm, ref)."""
    first, xs, ys = {}, Path(sa).read_bytes(), Path(sb).read_bytes()
    i = j = k = 0
    while i < len(xs) and j < len(ys) and len(first) < 2:
        x = None if xs[i] == 0 else xs[i + 1:i + 9].hex()
        y = None if ys[j] == 0 else ys[j + 1:j + 9].hex()
        at = (k // (nodes * coins), k // coins % nodes, k % coins)
        if (x is None) != (y is None):
            first.setdefault("discrete", ("node definedness", at, x, y))
        elif x != y:
            first.setdefault("numeric", ("node value bits", at, x, y))
        i, j, k = i + (1 if x is None else 9), j + (1 if y is None else 9), k + 1
    if (i < len(xs)) != (j < len(ys)):
        first.setdefault("discrete", ("stream length", k, len(xs), len(ys)))
    return first


def coverage(run):
    """Event counts of one run, defined node values, and an abort under its code."""
    c = {f"abort {run['abort']}": 1} if "abort" in run else {}
    for e in run.get("trace", []):
        k = e[1] if e[0] == "fill" else e[0]
        c[k] = c.get(k, 0) + 1
    if isinstance(run.get("nodes"), dict):
        c["defined node values"] = run["nodes"]["defined"]
    return c


CHUNK = 64


def chunk(names, texts, market, root, version, tmp):
    """Run programs on one market through both kernels, each loading the market once; per program, (name, market,
    agreed, first divergences, coverage)."""
    d = Path(tempfile.mkdtemp(dir=tmp))
    paths = []
    for i, text in enumerate(texts):
        paths.append(d / f"p{i}.json")
        paths[-1].write_text(text)
    (d / "list").write_text("".join(f"{p}\n" for p in paths))
    (d / "a").mkdir()
    (d / "b").mkdir()
    subprocess.run([str(DUMP), d / "list", root / "store", root / "venue", str(version), d / "mk.json", d / "a"], check=True, capture_output=True)
    subprocess.run([str(REF), "run", d / "list", d / "mk.json", d / "b"], check=True, capture_output=True)
    coins = len(json.loads((d / "mk.json").read_text())["venue"]["sz_decimals"])
    out = []
    for i, name in enumerate(names):
        a, b = (json.loads((d / k / f"{i}.json").read_text()) for k in ("a", "b"))
        sa, sb = d / "a" / f"{i}.bin", d / "b" / f"{i}.bin"
        same = sa.exists() == sb.exists() and (not sa.exists() or filecmp.cmp(sa, sb, shallow=False))
        first = divergence(a, b) if a != b else {}
        if not same:
            first |= stream_divergence(sa, sb, len(a["types"]), coins) if sa.exists() and sb.exists() else {"discrete": ("stream file", 0, sa.exists(), sb.exists())}
        out.append((name, market, a == b and same, first, coverage(a)))
    shutil.rmtree(d)
    return out


def run(out, workers="4", audit=AUDIT):
    """The judged run on the frozen manifest; writes the report to `out`."""
    audit = Path(audit)
    manifest = json.loads((audit / MANIFEST).read_text())
    text = (audit / CORPUS).read_text()
    if sha(text) != manifest["corpus_sha256"]:
        raise ValueError("the corpus differs from the frozen manifest")
    items = [json.loads(l) for l in text.splitlines()]
    build()
    work = Path(tempfile.mkdtemp(dir=REPO / "data"))
    roots = markets_of(manifest["seed"], work)
    for m, r in roots.items():
        if market_hash(r) != manifest["markets"][m]["market_sha256"]:
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
    by_market = {}
    for it in items:
        for m in it["markets"]:
            by_market.setdefault(m, []).append(it)
    chunks = [(m, its[i:i + CHUNK]) for m, its in by_market.items() for i in range(0, len(its), CHUNK)]
    with ThreadPoolExecutor(int(workers)) as pool:
        results = [r for rs in pool.map(lambda c: chunk([it["name"] for it in c[1]], [it["program"] for it in c[1]], c[0],
                                                       roots[c[0]], manifest["markets"][c[0]]["version"], work), chunks) for r in rs]
    shutil.rmtree(work)
    total = {}
    for *_, cov in results:
        for k, v in cov.items():
            total[k] = total.get(k, 0) + v
    failures = [{"name": n, "market": m, "first": d} for n, m, ok, d, _ in results if not ok]
    missing = complete(items, manifest["generated"], manifest["minimum"])
    report = {"manifest_sha256": sha((audit / MANIFEST).read_text()), "programs": len(items),
              "verdict_disagreements": verdicts, "verdict_codes": codes, "runs": len(results),
              "run_disagreements": failures, "coverage": total, "corpus_missing": missing,
              "pass": not verdicts and not failures and not missing}
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    return {k: report[k] for k in ("programs", "runs", "pass")} | {"verdict_disagreements": len(verdicts), "run_disagreements": len(failures)}
