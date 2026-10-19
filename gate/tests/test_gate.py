import numpy as np
from scipy.stats import norm
from statsmodels.stats.multitest import multipletests

from gate import gate


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


def test_holdout_pvalue_sanity():
    rng = np.random.default_rng(3)
    assert gate.holdout_pvalue(rng.normal(0.01, 0.01, 1000), 1) < 0.001
    p = [gate.holdout_pvalue(rng.normal(0, 0.01, 300), s) for s in range(40)]
    assert 0.2 < np.mean(p) < 0.8
