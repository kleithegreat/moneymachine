"""C2.3: the gate's DSR and GPT's independent one agree to 1e-9 on random and edge-case inputs."""

import numpy as np

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
        yield r, int(rng.integers(1, 5000)), float(rng.uniform(0, 0.2))
    rng = np.random.default_rng(5)
    yield rng.normal(0.01, 0.02, 500), 1, 0.05
    yield rng.normal(0.01, 0.02, 10), 50, 0.05
    yield np.r_[np.full(99, -0.001), 1.0], 3, 0.01
    yield np.r_[np.full(99, 0.5), -10.0], 3, 0.01
    yield np.r_[np.full(999, 0.01), -5.0], 10, 0.0
    yield np.zeros(100), 5, 0.1
    # Two-point series are the only data whose variance term reaches zero (kurtosis = skew^2 + 1):
    # it is then a square, and rounding near its root at Sharpe = 2 / skew makes it <= 0.
    for f in np.linspace(0.7503750, 0.7503756, 301):
        z = np.r_[np.full(100, 3.0), np.full(900, -1 / 3)]
        yield 0.01 * (f + z), 7, 0.03


def test_edge_cases_are_exercised():
    hits = 0
    for r, n, sd in cases():
        if r.std() == 0:
            continue
        s = r.mean() / r.std(ddof=1)
        z = (r - r.mean()) / r.std()
        hits += 1 - (z**3).mean() * s + ((z**4).mean() - 1) / 4 * s * s <= 0
    assert hits >= 10


def test_dsr_implementations_agree():
    disagreements = []
    for i, (r, n, sd) in enumerate(cases()):
        a, b = gate.dsr(r, n, sd), gpt_dsr.dsr(r, n, sd)
        if not abs(a - b) <= 1e-9:
            disagreements.append((i, len(r), n, sd, a, b))
    assert disagreements == [], disagreements[:5]
