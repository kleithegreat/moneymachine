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
_rng = np.random.default_rng(0)
_F = np.where(_rng.random((2000, 11)) < 0.5, 1.25e-5, _rng.standard_t(3, (2000, 11)) * 3e-5)
FUNDING = {"arrays": (_F, _F * 8 + _rng.normal(0, 1e-5, _F.shape)), "coins": [f"C{i}" for i in range(12)],
           "short": ["C8"], "block_hours": 168}
N2 = {"funding": FUNDING, "lambda": 0.5, "garch": {"omega": [4e-5] * 12, "alpha": [0.08] * 12, "beta": [0.9] * 12}}
N3 = {"funding": FUNDING, "regime": {"P": [[0.98, 0.02], [0.05, 0.95]], "m": [0.7, 1.8], "rho": [0.3, 0.7],
                                     "sigma": [0.02] * 12, "p_jump": 0.002, "k_jump": 0.05}}


def run_mm(root, strategy, tmp_path):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    trace = tmp_path / "t.jsonl"
    r = subprocess.run([str(MM), "eval", str(strategy), "--campaign", "c", "--agent", "a", "--store", str(root / "store"),
                        "--venue", str(root / "venue"), "--ledger", str(tmp_path / "l.sqlite"), "--trace", str(trace)], capture_output=True, text=True)
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
    costs = sum(e["fee"] + e["qty"] * (e["price"] - e["ref"]) for e in fills)
    assert all(e["t"] < last["t"] for e in fills)
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
    beta = 0.02
    a = markets.generate("N2", N2, "planted", days=730, planted=(0, 1), beta=beta)
    signal = -np.clip((a["funding"][4 * np.arange(1, a["eps"].shape[0]) - 4] - 1.25e-5) / 1e-4, -1, 1)
    e = a["eps"][1:]
    for i in range(12):
        x, y = signal[:, i], e[:, i]
        slope = np.polyfit(x, y, 1)[0]
        se = (y - slope * x).std() / (x.std() * np.sqrt(len(x)))
        assert abs(slope - (beta if i < 2 else 0.0)) < 4 * se, (i, slope, se)
    assert all(np.polyfit(signal[:, i], e[:, i], 1)[0] > 0 for i in (0, 1))


def test_event_series_reach_the_kernel(tmp_path):
    counts = np.random.default_rng(1).poisson(0.3, (500, 2))
    events = {"arrays": counts, "coins": [0, 3], "block_hours": 24}
    arrays = markets.generate("N1", None, "events", days=30, events=events)
    root = markets.write(tmp_path / "m", arrays, 0, {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")})
    w = {"op": "mul", "args": [{"op": "sign", "args": [{"op": "sub", "args": [
        {"op": "mean", "args": [{"input": "forum_posts"}], "hours": 24}, {"const": 0.3, "unit": "ev"}]}]}, {"const": 0.1, "unit": "1"}]}
    s = tmp_path / "s.json"
    s.write_text(json.dumps({"dsl": 1, "name": "ev", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"}, "weight": w}))
    trace = run_mm(root, s, tmp_path)
    coins = {e["coin"] for e in trace if e["type"] == "fill"}
    assert coins and coins <= {"S0", "S3"}


def test_store_events_reads_the_search_part_on_common_coverage(tmp_path):
    import polars as pl

    from ingest.store import HOLDOUT_START, stores, write_split

    H = 3_600_000
    hours = list(range(HOLDOUT_START - 10 * H, HOLDOUT_START + 5 * H, H))
    rows = [(c, t, t, float(i + 10 * (c == "AAVE"))) for c in ("BTC", "AAVE") for i, t in enumerate(hours)
            if not (c == "AAVE" and t < HOLDOUT_START - 6 * H)]
    df = pl.DataFrame(rows, schema={"coin": pl.Utf8, "eventTime": pl.Int64, "knownAt": pl.Int64, "count": pl.Float64}, orient="row")
    search, holdout = stores(tmp_path)
    write_split(search, holdout, "events_forum", df, 5, "t")
    spec = markets.store_events(str(tmp_path / "store"), 5, ("BTC", "ETH", "AAVE"))
    assert spec["coins"] == [0, 2]
    assert spec["arrays"].tolist() == [[float(i), float(i + 10)] for i in range(4, 10)]
