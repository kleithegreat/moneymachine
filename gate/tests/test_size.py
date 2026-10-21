import numpy as np

from gate import locked_v3, size


def test_each_generator_gives_bounded_finite_series_of_the_declared_shape():
    for name in locked_v3.GENERATORS:
        x = size.series(name, 540, m=50)
        assert x.shape == (50, 540) and np.isfinite(x).all() and x.min() >= -1, name


def test_series_are_seeded_by_the_suite_and_cell():
    assert np.array_equal(size.series("peso_noisy", 546, m=5), size.series("peso_noisy", 546, m=5))
    assert not np.array_equal(size.series("peso_noisy", 546, m=5), size.series("peso_noisy", 540, m=5)[:, :540])


def test_report_bounds_each_judged_level_over_all_judged_pairs():
    r = size.report({f"a/{n}": np.linspace(0, 1, 20000) for n in locked_v3.LENGTHS})
    assert r["judged_pairs"] == 9 and r["confidence"] == 1 - 0.05 / 9
    level = r["cells"]["a/540"]["levels"]["0.05"]
    assert level["rejections"] == 1000 and 0.05 < level["upper"] < 0.06
    assert "upper" not in r["cells"]["a/540"]["levels"]["0.001"]


def test_main_writes_work_and_report(tmp_path, monkeypatch):
    monkeypatch.setattr(size, "SERIES", 4)
    monkeypatch.setattr(locked_v3, "GENERATORS", {"peso": locked_v3.GENERATORS["peso"]})
    monkeypatch.setattr(locked_v3, "LENGTHS", (540,))
    size.main(tmp_path / "work.json", tmp_path / "audit.json")
    assert (tmp_path / "audit.json").exists() and "peso/540" in (tmp_path / "work.json").read_text()
