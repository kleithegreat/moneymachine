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
    exact = {f"a/{n}": {"p": np.linspace(0, 1, 20000), "active": np.full(20000, n)} for n in size.LENGTHS}
    exact["a/540"]["active"][:2000] = 26
    r = size.report(exact)
    assert r["judged_pairs"] == 9 and r["confidence"] == 1 - 0.05 / 9
    cell = r["cells"]["a/540"]
    level = cell["levels"]["0.05"]
    assert level["rejections"] == 1000 and 0.05 < level["upper"] < 0.06
    assert "upper" not in cell["levels"]["0.001"]
    assert cell["floored"] == 0.1 and level["eligible_rate"] == 0


def test_a_cell_runs_end_to_end():
    c = size.cell("locked-v2", "very_sparse", 540, m=4, workers=2, chunk=2)
    p = np.array(c["p"])
    assert p.shape == (4,) and ((p > 0) & (p <= 1)).all() and len(c["active"]) == 4
