import numpy as np

from gate import size


def test_generators_have_zero_mean_and_the_declared_shape():
    rng = np.random.default_rng(0)
    for name, gen in size.GENERATORS.items():
        x = gen(rng, 200, 1080)
        assert x.shape == (200, 1080), name
        assert abs(x.mean()) < 10 * x.std() / np.sqrt(x.size), name


def test_zero_inflated_is_flat_three_quarters_of_the_time():
    flat = 1 - size._active(np.random.default_rng(1), 2000, 1080).mean()
    assert abs(flat - 0.75) < 0.01


def test_report_judges_each_level_against_its_limit():
    ok = {"a/540": np.linspace(0, 1, 4000)}
    assert size.report(ok)["passed"]
    oversized = {"a/540": np.r_[np.zeros(300), np.ones(3700)]}
    assert not size.report(oversized)["passed"]


def test_a_cell_runs_end_to_end():
    p = size.cell("gaussian", 540, m=4, workers=2, chunk=2)
    assert p.shape == (4,) and ((p > 0) & (p <= 1)).all()
