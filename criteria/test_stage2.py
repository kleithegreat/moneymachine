"""Stage 2 criteria (PROGRESS.md, Stage 2) on the committed evidence. C2.3 is
gate/tests/test_dsr_differential.py."""

import math

import pytest

from criteria.evidence import load
from gate import locked_v3, sweep

P_MIN, Z_MAX = 0.001, 3.7
TOLERANCE = {"mean_abs_eps": ("rel", 0.05), "kurtosis": ("rel", 0.20), "acf1_abs_eps": ("abs", 0.05),
             "cross_corr": ("abs", 0.05), "funding_ar": ("abs", 0.05)}


@pytest.mark.parametrize("run", ["stage2/c21-fixed-probes.v3.json", "stage2/c21-top5.json"])
def test_c21_nulls_are_null(run):
    r = load(run)
    for model in ("N1", "N2", "N3"):
        assert min(r[model]["regression_p"]) > P_MIN, model
        assert max(abs(z) for z in r[model]["z"].values()) < Z_MAX, model


def test_c22_independent_generators_agree():
    r = load("stage2/c22.v2.json")
    for model in ("N2", "N3"):
        for stat, (kind, tol) in TOLERANCE.items():
            ours, gpt = r[model]["ours"][stat], r[model]["gpt"][stat]
            assert abs(gpt - ours) <= (tol * abs(ours) if kind == "rel" else tol), (model, stat)
        assert r[model]["gpt_regression_min_p"] > P_MIN, model


def test_c24_bound_admits_at_most_8_of_300():
    assert sweep.cp_upper(8, 300) <= 0.05 < sweep.cp_upper(9, 300)


def test_holdout_test_locked_calibration():
    r = load("stage2/holdout-size-locked-v3.json")
    assert r["suite"] == "holdout-calibration-locked-v3"
    assert len(r["cells"]) == len(locked_v3.GENERATORS) * len(locked_v3.LENGTHS)
    assert abs(r["confidence"] - (1 - 0.05 / (3 * len(r["cells"])))) < 1e-15
    for name, c in r["cells"].items():
        assert c["series"] == 20000, name
        for u, limit in {"0.05": 0.0625, "0.01": 0.015, "0.005": 0.01}.items():
            assert c["levels"][u]["upper"] <= limit, (name, u)


def test_c24_complete_null():
    cells = load("stage2/sweeps.json")["null"]
    assert len(cells) == 9
    for name, c in cells.items():
        assert c["n"] == 300 and c["promoted_upper"] <= 0.05 and c["spa_upper"] <= 0.10, name


def test_c25_mixed_fdr():
    cells = load("stage2/sweeps.json")["mixed"]
    assert len(cells) == 6
    for name, c in cells.items():
        assert c["n"] == 100 and c["fdr"] + math.sqrt(math.log(20) / 200) <= 0.20, name


def test_c26_power():
    assert load("stage2/sweeps.json")["mixed"]["N2-s3"]["power"] >= 0.30
