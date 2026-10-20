import numpy as np

from gate import size


def test_generators_have_zero_mean_and_the_declared_shape():
    rng = np.random.default_rng(0)
    for suite in size.SUITES.values():
        for name, gen in suite["generators"].items():
            x = gen(rng, 200, 1080)
            assert x.shape == (200, 1080), name
            assert abs(x.mean()) < 10 * x.std() / np.sqrt(x.size), name


def test_chains_have_the_declared_flat_share():
    rng = np.random.default_rng(1)
    assert abs(1 - size._active(rng, 2000, 1080, 1 / 12, 1 / 4).mean() - 0.75) < 0.01
    assert abs(1 - size._active(rng, 2000, 1080, 1 / 36, 1 / 4).mean() - 0.9) < 0.01


def test_report_judges_each_level_against_its_limit():
    exact = {f"a/{n}": np.linspace(0, 1, 20000) for n in size.LENGTHS}
    assert size.report(exact)["passed"]
    oversized = {**exact, "a/540": np.r_[np.zeros(300), np.ones(19700)]}
    assert not size.report(oversized)["passed"]


def test_a_cell_runs_end_to_end():
    p = size.cell("locked", "jumps", 540, m=4, workers=2, chunk=2)
    assert p.shape == (4,) and ((p > 0) & (p <= 1)).all()
