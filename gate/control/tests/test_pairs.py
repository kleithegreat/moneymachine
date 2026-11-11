"""Step 1 of the build plan: markets and twins (gate/control/pairs.py)."""

from pathlib import Path

import numpy as np
import pytest
from gate.control.constants import PAIRS, PLANTED

from gate import markets
from gate.agent.harness import harness_hash
from gate.control import pairs
from gate.control.tests import support

pytestmark = pytest.mark.usefixtures("built_kernel")

STRENGTH = 0.005
HELD = ("funding", "premium", "volume")
PRICES = ("open", "high", "low", "close")
IDS = [f"control-1-cal-a-{i:03d}" for i in range(20)]


def test_harness_is_the_frozen_one() -> None:
    assert harness_hash().startswith("6a335714")


def test_constants_the_plan_fixes() -> None:
    assert PAIRS == 32
    assert tuple(PLANTED) == (0, 1, 2, 3, 4, 5)


def test_fresh_ids_are_the_thirty_two_in_order() -> None:
    ids = pairs.fresh_ids("control-1-m007")
    assert ids == [f"control-1-m007/fresh/{i}" for i in range(32)]


def test_arrays_are_the_generators_for_the_study() -> None:
    shared = support.inputs()
    got = pairs.arrays("control-1-m003", STRENGTH)
    want = markets.generate("N2", shared["params"], "control-1-m003", 730, PLANTED, STRENGTH)
    assert set(got) == set(want)
    for key, value in want.items():
        if value is None:
            assert got[key] is None
        else:
            np.testing.assert_array_equal(got[key], value, err_msg=key)


def test_arrays_repeat_exactly() -> None:
    first = pairs.arrays("control-1-m004", STRENGTH)
    second = pairs.arrays("control-1-m004", STRENGTH)
    for key, value in first.items():
        if value is None:
            assert second[key] is None
        else:
            np.testing.assert_array_equal(value, second[key], err_msg=key)


def test_wall_1_twins_differ_only_where_the_plant_acts() -> None:
    planted = set(PLANTED)
    for market_id in IDS:
        market = pairs.arrays(market_id, STRENGTH)
        twin = pairs.arrays(market_id, 0.0)
        for key in HELD:
            np.testing.assert_array_equal(market[key], twin[key], err_msg=f"{market_id} {key}")
        coins = market["close"].shape[1]
        for coin in range(coins):
            if coin in planted:
                assert not np.array_equal(market["close"][:, coin], twin["close"][:, coin]), (market_id, coin)
            else:
                for key in PRICES:
                    np.testing.assert_array_equal(
                        market[key][:, coin], twin[key][:, coin], err_msg=f"{market_id} coin {coin} {key}"
                    )


def test_different_ids_have_different_funding() -> None:
    a = pairs.arrays("control-1-m000", STRENGTH)["funding"]
    b = pairs.arrays("control-1-m001", STRENGTH)["funding"]
    assert a.shape == b.shape
    assert not np.array_equal(a, b)
    one = pairs.arrays("control-1-m000/fresh/0", STRENGTH)["funding"]
    two = pairs.arrays("control-1-m000/fresh/1", STRENGTH)["funding"]
    assert not np.array_equal(one, two)


def test_write_pair_writes_both_markets_under_the_root(tmp_path: Path) -> None:
    planted, twin = pairs.write_pair(tmp_path, "control-1-m000/fresh/3", STRENGTH)
    planted, twin = Path(planted), Path(twin)
    assert planted != twin
    for path in (planted, twin):
        assert tmp_path in path.parents
        assert (path / "store").is_dir()
        assert (path / "venue" / "rules.json").is_file()
        assert (path / "version").is_file()


def test_written_pair_is_the_kernels_market_and_its_twin(tmp_path: Path) -> None:
    """The planted market evaluates as the generator's market at that strength, and the twin as strength zero, so the
    two are told apart by the kernel and each equals the market built here directly."""
    market_id = "control-1-m001/fresh/0"
    planted, twin = pairs.write_pair(tmp_path / "pair", market_id, STRENGTH)
    program = support.momentum(0.05)
    results = {}
    for label, path, beta in (("planted", Path(planted), STRENGTH), ("twin", Path(twin), 0.0)):
        direct = support.study_market(tmp_path / f"direct-{label}", market_id, beta)
        left = support.score(program, path, tmp_path / f"{label}-l.sqlite")
        right = support.score(program, direct, tmp_path / f"{label}-r.sqlite")
        assert left is not None
        assert left == right
        results[label] = left
    assert results["planted"] != results["twin"]
