"""The generators satisfy NULLS.md: funding passes through prices exactly as the kernel settles
it, so with zero innovations a held position's gross PnL is zero; and innovations are null."""

import json
import os
import subprocess
from pathlib import Path

import numpy as np
import pytest

from gate import markets

REPO = Path(__file__).resolve().parents[2]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"
FUNDING = {"mu": [1.25e-5] * 12, "phi": [0.9] * 12, "s": [2e-4] * 12, "nu": [4.0] * 12}
N2 = {"funding": FUNDING, "lambda": 0.5, "garch": {"omega": [4e-5] * 12, "alpha": [0.08] * 12, "beta": [0.9] * 12}}
N3 = {"funding": FUNDING, "regime": {"P": [[0.98, 0.02], [0.05, 0.95]], "m": [0.7, 1.8], "rho": [0.3, 0.7],
                                     "sigma": [0.02] * 12, "p_jump": 0.002, "k_jump": 0.05}}


def run_mm(root, strategy, tmp_path):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    trace = tmp_path / "t.jsonl"
    r = subprocess.run([str(MM), "eval", str(strategy), "--campaign", "c", "--agent", "a", "--store", str(root / "store"),
                        "--venue", str(root / "venue"), "--policy", str(root / "policy.json"),
                        "--ledger", str(tmp_path / "l.sqlite"), "--trace", str(trace)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    return [json.loads(l) for l in trace.read_text().splitlines()]


def test_funding_passes_through_exactly(tmp_path):
    params = dict(N2, garch={"omega": [0.0] * 12, "alpha": [0.0] * 12, "beta": [0.5] * 12})
    arrays = markets.generate("N2", params, "passthrough", days=30)
    assert np.all(arrays["eps"] == 0) and np.abs(arrays["funding"]).max() > 1e-4
    root = markets.write(tmp_path / "m", arrays, 0, {s: {"1000": 3.0, "10000": 5.0} for s in ("buy", "sell")})
    strategy = tmp_path / "s.json"
    weight = {"op": "mul", "args": [{"op": "sign", "args": [{"input": "premium"}]}, {"const": 0.15, "unit": "1"}]}
    strategy.write_text(json.dumps({"dsl": 1, "name": "flip", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
                                    "weight": weight}))
    trace = run_mm(root, strategy, tmp_path)
    fills = [e for e in trace if e["type"] == "fill"]
    funding = [e for e in trace if e["type"] == "funding"]
    assert len(fills) > 50 and any(abs(e["paid"]) > 0 for e in funding)
    last = [e for e in trace if e["type"] == "equity"][-1]
    costs = sum(e["fee"] + e["qty"] * (e["price"] - e["ref"]) for e in fills if e["t"] < last["t"])
    assert abs(last["equity"] - (10_000 - costs)) < 1e-6, (last["equity"], 10_000 - costs)


@pytest.mark.parametrize("model,params", [("N1", None), ("N2", N2), ("N3", N3)])
def test_innovations_are_null(model, params):
    eps, prev_f = [], []
    for i in range(20):
        a = markets.generate(model, params, f"null-{model}-{i}", days=120)
        eps.append(a["eps"][1:])
        prev_f.append(a["funding"][4 * np.arange(1, a["eps"].shape[0]) - 4])
    e, f = np.concatenate(eps), np.concatenate(prev_f)
    assert abs(e.mean()) < 4 * e.std() / np.sqrt(e.size)
    lagged = np.concatenate([np.zeros((1, 12)), e[:-1]])
    for x in (lagged, f, np.abs(lagged)):
        r = np.corrcoef(x.reshape(-1), e.reshape(-1))[0, 1] if x.std() > 0 else 0.0
        assert abs(r) < 4 / np.sqrt(e.size)


def test_planted_signal_shifts_the_mean():
    a = markets.generate("N2", N2, "planted", days=365, planted=(0, 1), beta=0.02)
    signal = -np.clip(a["funding"][4 * np.arange(1, a["eps"].shape[0]) - 4] / 1e-4, -1, 1)
    e = a["eps"][1:]
    slope = [np.polyfit(signal[:, i], e[:, i], 1)[0] for i in range(12)]
    assert abs(slope[0] - 0.02) < 0.004 and abs(slope[1] - 0.02) < 0.004 and max(abs(s) for s in slope[2:]) < 0.004
