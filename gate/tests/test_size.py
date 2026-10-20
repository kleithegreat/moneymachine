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


def test_report_bounds_each_judged_level_over_all_judged_pairs():
    exact = {f"a/{n}": np.linspace(0, 1, 20000) for n in size.LENGTHS}
    r = size.report(exact)
    assert r["judged_pairs"] == 9 and r["confidence"] == 1 - 0.05 / 9
    level = r["cells"]["a/540"]["levels"]["0.05"]
    assert level["rejections"] == 1000 and 0.05 < level["upper"] < 0.06
    assert "upper" not in r["cells"]["a/540"]["levels"]["0.001"]


def test_a_cell_runs_end_to_end():
    p = size.cell("locked", "jumps", 540, m=4, workers=2, chunk=2)
    assert p.shape == (4,) and ((p > 0) & (p <= 1)).all()
