"""Step 1 of the revised build plan: markets and twins (gate/control/pairs.py), with laws L1.1 to L1.4.

Interface the plan leaves open, kept from the old tests where it fits:
- `fresh_ids(market_id) -> list[str]`: the `PAIRS` ids `<market id>/fresh/0` ... `/fresh/<PAIRS - 1>`, in order.
- `arrays(market_id, strength) -> dict`: `gate.markets.generate("N2", params, id, 730, PLANTED, strength)` with the
  series' parameters; values may be None.
- `write_pair(root, market_id, strength) -> (planted path, twin path)`: both under `root`, the twin at strength 0.
- `gate.control.constants` holds every name of the plan's table, `BAND` being `(0.12, 0.18)`."""

from pathlib import Path
from typing import Any

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from gate import markets
from gate.agent.harness import harness_hash
from gate.control import constants, pairs
from gate.control.tests import support

pytestmark = pytest.mark.usefixtures("built_kernel")

STRENGTH = 0.005
HELD = ("funding", "premium", "volume")
PRICES = ("open", "high", "low", "close")
IDS = [f"control-1-cal-a-{i:04d}" for i in range(20)]
PLANTED = constants.PLANTED
SLOW_LAW = settings(max_examples=8, deadline=None)

strengths = st.floats(min_value=0.0, max_value=0.01, allow_nan=False)
market_ids = st.one_of(
    st.integers(0, 99).map(lambda i: f"control-1-m{i:03d}"),
    st.integers(0, 1599).map(lambda i: f"control-1-cal-a-{i:04d}"),
    st.integers(0, 9999).map(lambda i: f"control-1-cal-b-{i:04d}"),
    st.integers(0, 199).map(lambda i: f"control-1-blind-{i:03d}"),
)


def equal(first: dict[str, Any], second: dict[str, Any], keys: list[str] | tuple[str, ...] | None = None) -> bool:
    for key in keys if keys is not None else list(first):
        a, b = first[key], second[key]
        if (a is None) != (b is None):
            return False
        if a is not None and not np.array_equal(a, b):
            return False
    return True


def unplanted_prices(market: dict[str, Any]) -> list[np.ndarray]:
    coins = market["close"].shape[1]
    return [market[key][:, c] for c in range(coins) if c not in PLANTED for key in PRICES]


def test_harness_is_the_frozen_one() -> None:
    assert harness_hash().startswith("6a335714")


def test_constants_are_the_plans_table() -> None:
    c = constants
    assert (c.PAIRS, c.MAJORITY, c.SHARE, c.THETA1) == (57, 39, 0.5, 0.7)
    assert (c.ALPHA, c.BETA_ERROR, c.MAX_MARKETS) == (0.05, 0.05, 100)
    assert (c.TARGET, c.TOLERANCE, c.MAX_STEPS) == (0.15, 0.005, 12)
    assert (c.SEARCH_MARKETS, c.CHECK_MARKETS, tuple(c.BAND)) == (1600, 10000, (0.12, 0.18))
    assert (c.BLIND_MARKETS, c.EVEN_ALLOWED, c.MAX_VOIDS) == (200, 9, 3)
    assert tuple(c.PLANTED) == (0, 1, 2, 3, 4, 5)


def test_fresh_ids_are_the_fifty_seven_in_order() -> None:
    assert pairs.fresh_ids("control-1-m007") == [f"control-1-m007/fresh/{i}" for i in range(57)]


def test_arrays_are_the_generators_for_the_study() -> None:
    shared = support.inputs()
    got = pairs.arrays("control-1-m003", STRENGTH)
    want = markets.generate("N2", shared["params"], "control-1-m003", 730, PLANTED, STRENGTH)
    assert set(got) == set(want)
    assert equal(got, want, list(want))


def test_wall_1_twins_differ_only_where_the_plant_acts() -> None:
    for market_id in IDS:
        market = pairs.arrays(market_id, STRENGTH)
        twin = pairs.arrays(market_id, 0.0)
        assert equal(market, twin, HELD), market_id
        for coin in range(market["close"].shape[1]):
            if coin in PLANTED:
                assert not np.array_equal(market["close"][:, coin], twin["close"][:, coin]), (market_id, coin)
            else:
                for key in PRICES:
                    np.testing.assert_array_equal(
                        market[key][:, coin], twin[key][:, coin], err_msg=f"{market_id} {coin}"
                    )


def test_different_ids_have_different_funding() -> None:
    a = pairs.arrays("control-1-m000", STRENGTH)["funding"]
    b = pairs.arrays("control-1-m001", STRENGTH)["funding"]
    assert a.shape == b.shape and not np.array_equal(a, b)
    one = pairs.arrays("control-1-m000/fresh/0", STRENGTH)["funding"]
    two = pairs.arrays("control-1-m000/fresh/1", STRENGTH)["funding"]
    assert not np.array_equal(one, two)


def test_write_pair_writes_both_markets_under_the_root_and_accepts_a_slash(tmp_path: Path) -> None:
    planted, twin = pairs.write_pair(tmp_path, "control-1-m000/fresh/3", STRENGTH)
    planted, twin = Path(planted), Path(twin)
    assert planted != twin
    for path in (planted, twin):
        assert tmp_path in path.parents
        assert (path / "store").is_dir()
        assert (path / "venue" / "rules.json").is_file()
        assert (path / "version").is_file()


def test_written_pair_is_the_kernels_market_and_its_twin(tmp_path: Path) -> None:
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


@SLOW_LAW
@given(market_ids, strengths)
def test_l1_1_arrays_repeat_exactly(market_id: str, strength: float) -> None:
    assert equal(pairs.arrays(market_id, strength), pairs.arrays(market_id, strength))


@SLOW_LAW
@given(market_ids, strengths, strengths)
def test_l1_2_strength_changes_no_draw(market_id: str, b1: float, b2: float) -> None:
    first, second = pairs.arrays(market_id, b1), pairs.arrays(market_id, b2)
    assert equal(first, second, HELD)
    for a, b in zip(unplanted_prices(first), unplanted_prices(second)):
        np.testing.assert_array_equal(a, b)


@SLOW_LAW
@given(market_ids)
def test_l1_3_strength_zero_is_the_generator_with_no_planted_coin(market_id: str) -> None:
    shared = support.inputs()
    bare = markets.generate("N2", shared["params"], market_id, 730, (), 0.0)
    assert equal(pairs.arrays(market_id, 0.0), bare, list(bare))


@given(market_ids, market_ids)
def test_l1_4_fresh_ids_of_two_markets_share_none_and_are_no_other_id(first: str, second: str) -> None:
    a, b = pairs.fresh_ids(first), pairs.fresh_ids(second)
    assert len(set(a)) == len(a) == constants.PAIRS
    if first != second:
        assert not set(a) & set(b)
    assert first not in a and second not in a
    assert all("/fresh/" in fresh for fresh in a)
    assert not set(a) & {first, second}
