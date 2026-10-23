"""The Lean reference kernel agrees with mm: verdicts and codes on every adversarial case and generated
program, and bit-exact runs (trace, returns, gross returns) on a short null market. A smoke version
of C6.4, which is judged on its own frozen corpus."""

import json
import random
import subprocess
from pathlib import Path

import numpy as np
import pytest

from gate import kernel, markets, search
from gate.kernel import MM
from gate.probes import probes

REPO = Path(__file__).resolve().parents[2]
REF = REPO / "reference/lean/.lake/build/bin/refmm"
DUMP = REPO / "reference/mmdump/target/release/mmdump"


@pytest.fixture(scope="module", autouse=True)
def built():
    kernel.build()
    subprocess.run(["lake", "build"], cwd=REPO / "reference/lean", check=True, capture_output=True)
    subprocess.run(["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True)


def verdict_mm(path):
    r = subprocess.run([str(MM), "check", str(path)], capture_output=True, text=True)
    d = json.loads((r.stdout + r.stderr).strip().splitlines()[-1])
    return "ok" if d.get("ok") else d["code"]


def test_verdicts_agree(tmp_path):
    texts = [c.read_text().split("\n", 1)[1] for c in sorted((REPO / "kernel/tests/adversarial").glob("*.case"))]
    rng = random.Random(5)
    texts += [json.dumps(search.compile_genome(search.random_genome(rng, 7))) for _ in range(40)]
    bad = []
    for k, text in enumerate(texts):
        f = tmp_path / f"{k}.json"
        f.write_text(text)
        ref = subprocess.run([str(REF), "check", str(f)], capture_output=True, text=True).stdout.strip()
        if ref != verdict_mm(f):
            bad.append((k, ref, verdict_mm(f)))
    assert bad == []


def test_runs_agree_bit_for_bit(tmp_path):
    params = json.loads((REPO / "gate/nulls.json").read_text())
    ev = {"arrays": np.random.default_rng(3).poisson(2.0, (300, 3)).astype(float), "coins": [0, 4, 7], "block_hours": 24}
    root = markets.write(tmp_path / "m", markets.generate("N2", params["N2"], "lean-smoke", 45, (0, 1), 0.01, ev), 5,
                         {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")})
    rng = random.Random(9)
    w0 = json.loads((REPO / "kernel/strategies/w0.json").read_text())
    since = {**w0, "name": "hours since funding was positive", "weight": {"op": "mul", "args": [
        {"op": "hours_since", "args": [{"op": "gt", "args": [{"input": "funding"}, {"const": 0, "unit": "1/h"}]}]},
        {"const": 0.0005, "unit": "1/h"}]}}
    programs = [w0, since] + probes(True)[:6]
    programs += [search.compile_genome(search.random_genome(rng, 7)) for _ in range(6)]
    bad = []
    for k, prog in enumerate(programs):
        pf = tmp_path / "p.json"
        pf.write_text(json.dumps(prog))
        subprocess.run([str(DUMP), pf, root / "store", root / "venue", "1", tmp_path / "mk.json", tmp_path / "a.json",
                        tmp_path / "sa.bin"], check=True)
        subprocess.run([str(REF), "run", pf, tmp_path / "mk.json", tmp_path / "b.json", tmp_path / "sb.bin"], check=True)
        a, b = json.loads((tmp_path / "a.json").read_text()), json.loads((tmp_path / "b.json").read_text())
        if a != b or (tmp_path / "sa.bin").read_bytes() != (tmp_path / "sb.bin").read_bytes():
            bad.append(k)
    assert bad == []
