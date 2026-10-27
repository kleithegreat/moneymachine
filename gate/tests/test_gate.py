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
    assert abs(gate.dsr(r, 1) - expect) < 1e-12


def test_dsr_deflates_with_more_trials():
    r = np.random.default_rng(1).normal(0.001, 0.02, 3000)
    values = [gate.dsr(r, n) for n in (1, 10, 100, 1000)]
    assert all(a >= b for a, b in zip(values, values[1:])) and values[0] > 0.9 > 0.5 > values[-1]


def test_dsr_edge_cases():
    assert gate.dsr(np.zeros(100), 5) == 0.0
    assert gate.dsr(np.array([0.1, 0.2]), 5) == 0.0
    with pytest.raises(ValueError):
        gate.dsr(np.array([0.1, np.nan, 0.2]), 5)


def test_holm_matches_statsmodels():
    p = np.random.default_rng(2).uniform(0, 0.2, 17)
    assert np.allclose(gate.holm(p), multipletests(p, method="holm")[1])


def test_holm_refuses_a_p_value_outside_the_unit_interval():
    for bad in (np.nan, -0.1, 1.5):
        with pytest.raises(ValueError):
            gate.holm([0.01, bad])


def test_holdout_pvalue_bets_the_truncated_plug_in_on_the_past():
    # Bets 0, then clip(0.1/0.01) = 0.5, then clip(0.2/0.02) = 0.5: wealth 1, 1.05, 1.05 * 0.975.
    assert gate.holdout_pvalue([0.1, 0.1, -0.05]) == 1 / 1.05
    assert gate.holdout_pvalue([]) == 1.0
    assert gate.holdout_pvalue(np.zeros(540)) == 1.0
    assert gate.holdout_pvalue(np.full(546, -0.01)) == 1.0
    assert gate.holdout_pvalue(np.full(546, 0.05)) == pytest.approx(1 / 1.025 ** 545, rel=1e-12)
    assert gate.holdout_pvalue(np.r_[0.01, -1.0, np.zeros(10)]) == 1.0


def test_holdout_pvalue_rejects_returns_outside_its_scope():
    for bad in ([0.1, np.nan], [0.1, np.inf], [0.1, -1.0000001]):
        with pytest.raises(ValueError):
            gate.holdout_pvalue(bad)


def test_holdout_pvalues_are_valid_on_a_fair_martingale_and_vectorized():
    rng = np.random.default_rng(5)
    x = np.where(rng.random((20_000, 546)) < 0.5, 0.01, -0.01)
    p = gate.holdout_pvalues(x)
    assert (p <= 0.05).mean() < 0.05 and (p <= 0.01).mean() < 0.01
    assert all(gate.holdout_pvalue(x[i]) == p[i] for i in range(20))


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
    progs = gate.programs(ledger, "c", list(cands))
    assert sorted(p["params"]["size"]["value"] for p in progs.values()) == [0.01, 0.02]


def test_stepm_keeps_every_model_when_all_are_superior():
    import pandas as pd
    rng = np.random.default_rng(6)
    r = pd.DataFrame({k: rng.normal(0.01 * (i + 1), 0.01, 600) for i, k in enumerate("abc")})
    assert gate.stepm(r, list(r.columns), 1) == ["a", "b", "c"]


def test_clusters_and_effective_n():
    import pandas as pd
    rng = np.random.default_rng(4)
    base = rng.normal(0, 0.01, 500)
    r = pd.DataFrame({"a": base, "b": base + rng.normal(0, 1e-4, 500), "c": rng.normal(0, 0.01, 500), "z": np.zeros(500)})
    assert gate.clusters(r, 0.9) == 3
    report = gate.effective_n(r, 0.5, 1)
    assert [v["n"] for v in report["by_n"].values()] == [4, 3, 3] and report["fragile"] == []


def test_bankrupt_lists_experiments_reaching_minus_b(tmp_path):
    import sqlite3

    db = sqlite3.connect(tmp_path / "l.sqlite")
    db.execute("CREATE TABLE results(experiment_id INTEGER PRIMARY KEY, returns BLOB)")
    for i, r in enumerate(([0.01, -0.2], [0.02, -gate.LOSS_BOUND, 0.0]), 1):
        db.execute("INSERT INTO results VALUES (?, ?)", (i, np.array(r, "<f8").tobytes()))
    db.commit()
    assert gate.bankrupt(tmp_path / "l.sqlite") == [2]
