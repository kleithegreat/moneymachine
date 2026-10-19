"""C1.4: `mm eval --trace` of W0 matches the stage 0 Python witness at every step."""

import json
import os
import subprocess
from pathlib import Path

import pytest

from ingest import witness

REPO = Path(__file__).resolve().parents[3]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"
TOL = 1e-6


def stage0_version():
    reports = sorted((REPO / "data" / "reports").glob("stage0-ingest-*.json"))
    return int(reports[0].stem.rsplit("-", 1)[1]) if reports else None


pytestmark = pytest.mark.skipif(
    stage0_version() is None or not (REPO / "venue/hyperliquid/execution.json").exists(),
    reason="needs the stage 0 backfill in data/ and the C0.7 execution model")


def by_type(events, kinds):
    return [e for e in events if e["type"] in kinds]


def test_kernel_matches_witness(tmp_path):
    version = stage0_version()
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    out = tmp_path / "trace.jsonl"
    r = subprocess.run([str(MM), "eval", str(REPO / "kernel/strategies/w0.json"), "--campaign", "stage1-differential",
                        "--agent", "test", "--version", str(version), "--trace", str(out),
                        "--ledger", str(tmp_path / "l.sqlite")], cwd=REPO, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    kernel = [json.loads(l) for l in out.read_text().splitlines()]
    py, worst = witness.run(REPO / "data", version)
    assert worst <= 1e-9

    ke, pe = by_type(kernel, {"equity"}), by_type(py, {"equity"})
    assert [e["t"] for e in ke] == [e["t"] for e in pe]
    assert max(abs(a["equity"] - b["equity"]) for a, b in zip(ke, pe)) <= TOL

    kf, pf = by_type(kernel, {"fill", "liquidation", "delisting"}), by_type(py, {"fill", "liquidation", "delisting"})
    assert [(e["type"], e["t"], e["coin"]) for e in kf] == [(e["type"], e["t"], e["coin"]) for e in pf]
    for a, b in zip(kf, pf):
        assert abs(a["qty"] - b["qty"]) <= 1e-12 and abs(a["price"] - b["price"]) <= TOL * a["price"]
        assert abs(a["fee"] - b["fee"]) <= TOL

    kd, pd = by_type(kernel, {"decision"}), by_type(py, {"decision"})
    assert [(e["t"], e["coin"], e["qty"]) for e in kd] == [(e["t"], e["coin"], e["qty"]) for e in pd]

    key = lambda e: (e["t"], e["coin"])
    assert sorted(map(key, by_type(kernel, {"funding"}))) == sorted(map(key, by_type(py, {"funding"})))
    assert sorted(map(key, by_type(kernel, {"hold"}))) == sorted(map(key, by_type(py, {"hold"})))
    assert sorted(map(key, by_type(kernel, {"unfilled"}))) == sorted(map(key, by_type(py, {"unfilled"})))
