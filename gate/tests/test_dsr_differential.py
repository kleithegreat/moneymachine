"""C2.3: the gate's DSR and GPT's independent one agree to 1e-9 on random and edge-case inputs."""

import numpy as np
import pytest

from gate import gate
from gate.tests import gpt_dsr


def cases():
    rng = np.random.default_rng(23)
    for _ in range(1000):
        t = int(rng.integers(3, 4000))
        kind = rng.integers(4)
        r = (rng.normal(rng.normal(0, 0.002), rng.uniform(0.001, 0.05), t) if kind == 0 else
             rng.standard_t(rng.uniform(2.5, 10), t) * 0.01 + rng.normal(0, 0.001) if kind == 1 else
             np.exp(rng.normal(0, rng.uniform(0.1, 2), t)) * 0.001 - 0.0005 if kind == 2 else
             np.where(rng.random(t) < 0.02, rng.normal(0.2, 0.05, t), rng.normal(-0.001, 0.002, t)))
        yield r, int(rng.integers(1, 5000))
    rng = np.random.default_rng(5)
    yield rng.normal(0.01, 0.02, 500), 1
    yield rng.normal(0.01, 0.02, 10), 50
    yield np.r_[np.full(99, -0.001), 1.0], 3
    yield np.r_[np.full(99, 0.5), -10.0], 3
    yield np.r_[np.full(999, 0.01), -5.0], 10
    yield np.zeros(100), 5
    yield rng.normal(0.01, 0.02, 3), 2
    # Two-point series are the only data whose variance term reaches zero (kurtosis = skew^2 + 1):
    # it is then a square, and rounding near its root at Sharpe = 2 / skew makes it <= 0.
    for f in np.linspace(0.7503750, 0.7503756, 301):
        z = np.r_[np.full(100, 3.0), np.full(900, -1 / 3)]
        yield 0.01 * (f + z), 7


def test_edge_cases_are_exercised():
    hits = 0
    for r, n in cases():
        if r.std() == 0:
            continue
        s = r.mean() / r.std(ddof=1)
        z = (r - r.mean()) / r.std()
        hits += 1 - (z**3).mean() * s + ((z**4).mean() - 1) / 4 * s * s <= 0
    assert hits >= 10


def test_dsr_implementations_agree():
    disagreements = []
    for i, (r, n) in enumerate(cases()):
        a, b = gate.dsr(r, n), gpt_dsr.dsr(r, n)
        if not abs(a - b) <= 1e-9:
            disagreements.append((i, len(r), n, a, b))
    assert disagreements == [], disagreements[:5]


def test_extreme_finite_returns_agree_without_overflow():
    for r in (np.array([0.0, 0.0, 1e300, -1e300]), np.array([1e-300, 2e-300, 0.0, 5e-301]), np.r_[np.ones(50), 1 + 2e-16]):
        a, b = gate.dsr(r, 10), gpt_dsr.dsr(r, 10)
        assert np.isfinite(a) and abs(a - b) <= 1e-9, (r[:4], a, b)


@pytest.mark.parametrize("bad", [np.nan, np.inf, -np.inf])
def test_both_refuse_a_nonfinite_return(bad):
    r = np.r_[np.random.default_rng(7).normal(0, 0.01, 50), bad]
    for dsr in (gate.dsr, gpt_dsr.dsr):
        with pytest.raises(ValueError):
            dsr(r, 10)
