"""C1.4: `mm eval --trace` of W0 matches the stage 0 Python witness at every step: the same events in the same order,
and every decision, fill, funding settlement, equity and reconciliation value within $1e-6 (exactly where both read the
same datum)."""

import json
import os
import subprocess
from pathlib import Path

import pytest

from gate.kernel import MM, build
from ingest import witness

REPO = Path(__file__).resolve().parents[3]
TOL = 1e-6


def stage0_version():
    """The latest stage 0 dataset version: the judged second fetch once it exists."""
    reports = sorted((REPO / "audit" / "stage0").glob("ingest-*.json"))
    return int(reports[-1].stem.rsplit("-", 1)[1]) if reports else None


VENUE = Path(os.environ.get("MM_VENUE", REPO / "venue" / "hyperliquid"))
pytestmark = pytest.mark.skipif(
    stage0_version() is None or not (VENUE / "execution.json").exists(),
    reason="needs the stage 0 backfill in data/ and the C0.7 execution model")


KINDS = ("equity", "decision", "hold", "fill", "liquidation", "delisting", "unfilled", "funding")


def by_type(events, kinds):
    return [e for e in events if e["type"] in kinds]


def steps(events):
    return [(e["t"], e["type"], e.get("coin", "")) for e in by_type(events, KINDS)]


def test_kernel_matches_witness(tmp_path):
    version = stage0_version()
    build()
    out = tmp_path / "trace.jsonl"
    r = subprocess.run([str(MM), "eval", str(REPO / "kernel/strategies/w0.json"), "--campaign", "stage1-differential",
                        "--agent", "test", "--version", str(version), "--trace", str(out), "--venue", str(VENUE),
                        "--ledger", str(tmp_path / "l.sqlite")], cwd=REPO, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    kernel = [json.loads(l) for l in out.read_text().splitlines()]
    py, worst = witness.run(REPO / "data", version, VENUE)
    assert worst <= 1e-9
    assert steps(kernel) == steps(py)
    print(f"W0 on dataset version {version}: " + ", ".join(f"{k} {len(by_type(py, {k}))}" for k in KINDS))

    ke, pe = by_type(kernel, {"equity"}), by_type(py, {"equity"})
    assert [e["t"] for e in ke] == [e["t"] for e in pe]
    assert max(abs(a["equity"] - b["equity"]) for a, b in zip(ke, pe)) <= TOL
    assert max(abs(a["reconciled"] - b["reconciled"]) for a, b in zip(ke, pe)) <= TOL

    kf, pf = by_type(kernel, {"fill", "liquidation", "delisting"}), by_type(py, {"fill", "liquidation", "delisting"})
    assert [(e["type"], e["t"], e["coin"]) for e in kf] == [(e["type"], e["t"], e["coin"]) for e in pf]
    for a, b in zip(kf, pf):
        assert abs(a["qty"] - b["qty"]) <= 1e-12 and abs(a["price"] - b["price"]) <= TOL
        assert abs(a["fee"] - b["fee"]) <= TOL

    kd, pd = by_type(kernel, {"decision"}), by_type(py, {"decision"})
    assert [(e["t"], e["coin"], e["qty"]) for e in kd] == [(e["t"], e["coin"], e["qty"]) for e in pd]
    assert all(abs(a["weight"] - b["weight"]) <= 1e-12 for a, b in zip(kd, pd))

    key = lambda e: (e["t"], e["coin"])
    kfund, pfund = sorted(by_type(kernel, {"funding"}), key=key), sorted(by_type(py, {"funding"}), key=key)
    for a, b in zip(kfund, pfund):
        assert (a["rate"], a["price"]) == (b["rate"], b["price"]) and abs(a["paid"] - b["paid"]) <= TOL, (a, b)
