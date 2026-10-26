"""fastmm against mm on the frozen C6.4 corpus (a diagnostic, not a judged run): every run on every market through
`differential.chunk`, with fastmm in refmm's place. Verdicts are not compared: fastmm uses the reference checker.
Markets are rebuilt from the manifest and checked against their frozen hashes, less the `version` file that
market directories gained after the freeze (b2c0007)."""

import hashlib
import json
import shutil
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from reference import differential as diff

FAST = diff.REPO / "reference/lean/.lake/build/bin/fastmm"


def frozen_hash(root):
    h = hashlib.sha256()
    for f in sorted(Path(root).rglob("*")):
        if f.is_file() and f.relative_to(root) != Path("version"):
            h.update(str(f.relative_to(root)).encode())
            h.update(hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()


def run(out, workers="4"):
    manifest = json.loads((diff.AUDIT / diff.MANIFEST).read_text())
    text = (diff.AUDIT / diff.CORPUS).read_text()
    if diff.sha(text) != manifest["corpus_sha256"]:
        raise ValueError("the corpus differs from the frozen manifest")
    items = [json.loads(l) for l in text.splitlines()]
    work = Path(tempfile.mkdtemp(dir=diff.REPO / "data"))
    roots = diff.markets_of(manifest["seed"], work)
    for m, r in roots.items():
        if frozen_hash(r) != manifest["markets"][m]["market_sha256"]:
            raise ValueError(f"market {m} does not rebuild as frozen")
    diff.REF = FAST
    by_market = {}
    for it in items:
        for m in it["markets"]:
            by_market.setdefault(m, []).append(it)
    chunks = [(m, its[i:i + diff.CHUNK]) for m, its in by_market.items() for i in range(0, len(its), diff.CHUNK)]
    with ThreadPoolExecutor(int(workers)) as pool:
        results = [r for rs in pool.map(lambda c: diff.chunk([it["name"] for it in c[1]], [it["program"] for it in c[1]], c[0],
                                                            roots[c[0]], manifest["markets"][c[0]]["version"], work), chunks) for r in rs]
    shutil.rmtree(work)
    total = {}
    for *_, cov in results:
        for k, v in cov.items():
            total[k] = total.get(k, 0) + v
    failures = [{"name": n, "market": m, "first": d} for n, m, ok, d, _ in results if not ok]
    report = {"corpus_sha256": manifest["corpus_sha256"], "runs": len(results), "run_disagreements": failures,
              "coverage": total, "agree": not failures}
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
    return {"runs": len(results), "disagreements": len(failures)}


if __name__ == "__main__":
    print(run(*sys.argv[1:]))
