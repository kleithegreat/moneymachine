import numpy as np
import pytest
from scipy.stats import norm
from statsmodels.stats.multitest import multipletests

from gate import gate, kernel


def test_dsr_single_trial_is_psr():
    r = np.random.default_rng(0).normal(0.01, 0.05, 1000)
    s = r.mean() / r.std(ddof=1)
    z = (r - r.mean()) / r.std()
    skew, kurt = (z**3).mean(), (z**4).mean()
    expect = norm.cdf(s * np.sqrt(999) / np.sqrt(1 - skew * s + (kurt - 1) / 4 * s**2))
    assert abs(gate.dsr(r, 1, 0.0) - expect) < 1e-12


def test_dsr_deflates_with_more_trials():
    r = np.random.default_rng(1).normal(0.001, 0.02, 3000)
    values = [gate.dsr(r, n, 0.02) for n in (1, 10, 100, 1000)]
    assert all(a >= b for a, b in zip(values, values[1:])) and values[0] > 0.9 > 0.5 > values[-1]


def test_dsr_edge_cases():
    assert gate.dsr(np.zeros(100), 5, 0.1) == 0.0
    assert gate.dsr(np.array([0.1, 0.2]), 5, 0.1) == 0.0


def test_holm_matches_statsmodels():
    p = np.random.default_rng(2).uniform(0, 0.2, 17)
    assert np.allclose(gate.holm(p), multipletests(p, method="holm")[1])


def test_bootstrap_pvalue_sanity():
    rng = np.random.default_rng(3)
    assert gate.bootstrap_pvalue(rng.normal(0.01, 0.01, 1000), 1) < 0.001
    p = [gate.bootstrap_pvalue(rng.normal(0, 0.01, 300), s) for s in range(40)]
    assert 0.2 < np.mean(p) < 0.8
    assert gate.bootstrap_pvalue(np.zeros(300), 1) == 1.0
    assert gate.bootstrap_pvalue(np.full(1080, 0.1), 1) == 1.0
    assert gate.bootstrap_pvalue(np.r_[np.zeros(299), 0.01], 1) >= 1 / (1 + gate.HOLDOUT_REPS)


def test_holdout_pvalue_is_the_worst_development_monte_carlo_pvalue(monkeypatch):
    denominator, cells = gate._calibration()
    assert denominator == 10_001 and len(cells) == 27 and all(len(c) == 4000 for c in cells)
    raw = iter([1 / 10_001, 0.05, 0.0500999, 1.0])
    monkeypatch.setattr(gate, "bootstrap_pvalue", lambda r, seed: next(raw))
    p = [gate.holdout_pvalue(np.ones(540), 0) for _ in range(4)]
    assert p[0] == max((1 + int((c <= 1).sum())) / 4001 for c in cells) and p[0] >= 1 / 4001
    assert p[0] <= p[1] <= p[2] <= p[3] == 1.0
    assert p[1] == max((1 + int((c <= 500).sum())) / 4001 for c in cells) > 0.05


def test_holdout_series_under_the_activity_floor_is_untested(monkeypatch):
    monkeypatch.setattr(gate, "bootstrap_pvalue", lambda r, seed: 1 / 10_001)
    assert [gate.floor(n) for n in (540, 546, 1080)] == [27, 28, 54]
    sparse = np.zeros(540)
    sparse[:26] = 1.0
    assert gate.holdout_pvalue(sparse, 0) == 1.0
    sparse[26] = 1.0
    assert gate.holdout_pvalue(sparse, 0) == gate.min_holdout_pvalue() < 0.05 / 33
    with pytest.raises(ValueError):
        gate.holdout_pvalue(np.r_[np.ones(539), np.nan], 0)


def test_long_run_sd_is_white_noise_sd_and_never_negative():
    rng = np.random.default_rng(4)
    assert abs(gate.long_run_sd(rng.normal(0, 1, 200_000)) - 1) < 0.02
    alternating = np.tile([1.0, -1.0], 500)
    assert gate.long_run_sd(alternating) >= 0
    x = rng.normal(0, 1, (50, 40))
    assert np.allclose(gate.long_run_sd(x), [gate.long_run_sd(row) for row in x])


def test_parameter_variants_are_separate_trials(tmp_path):
    import json, subprocess
    from pathlib import Path
    from gate.markets import write_market
    repo = Path(__file__).resolve().parents[2]
    mm = kernel.build()
    m = write_market(tmp_path / "m", market_id="params", days=40)
    base = json.loads((repo / "kernel/strategies/w0.json").read_text())
    base["weight"] = {"op": "mul", "args": [{"op": "sign", "args": [{"op": "sub", "args": [
        {"input": "close"}, {"op": "lag", "args": [{"input": "close"}], "hours": 4}]}]}, {"param": "size"}]}
    batch = tmp_path / "b.jsonl"
    lines = []
    for size in (0.01, 0.02, 0.01):
        b = json.loads(json.dumps(base))
        b["params"]["size"]["value"] = size
        lines.append(json.dumps(b))
    batch.write_text("\n".join(lines) + "\n")
    ledger = tmp_path / "l.sqlite"
    subprocess.run([str(mm), "eval", str(batch), "--campaign", "c", "--agent", "a",
                    "--store", str(m / "store"), "--venue", str(m / "venue"), "--ledger", str(ledger)], check=True, capture_output=True)
    cands = gate.candidates(ledger, "c")
    assert len(cands) == 2
    progs = gate.programs(ledger, list(cands))
    assert sorted(p["params"]["size"]["value"] for p in progs.values()) == [0.01, 0.02]


def test_clusters_and_effective_n():
    import pandas as pd
    rng = np.random.default_rng(4)
    base = rng.normal(0, 0.01, 500)
    r = pd.DataFrame({"a": base, "b": base + rng.normal(0, 1e-4, 500), "c": rng.normal(0, 0.01, 500), "z": np.zeros(500)})
    assert gate.clusters(r, 0.9) == 3
    report = gate.effective_n(r, 0.02, 0.5, 1, [])
    assert [v["n"] for v in report["by_n"].values()] == [4, 3, 3] and report["fragile"] == []
