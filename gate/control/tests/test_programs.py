"""Step 4 of the revised build plan: the reference and the mirror set (gate/control/programs/*.json), with law L4.1.

Interface the plan leaves open: eleven flat JSON files in `programs/`. `reference.json` is the reference. The mirror
set is five pairs, ten files, named as in PAIRS below (the first of a pair is the plain one, the second its negation):
constant long/short, momentum/reversal on the last day's close-to-close return, and a blind position,
`sign(xs_demean(mean(volume, 168)))` times 0.01, 0.05 or 2/12 (`random_low`, `random_mid`, `random_high`), each with its
negation. The DSL has no per-file negation flag, so a
program's negation is its weight wrapped in `neg`, or equivalently a constant with its sign flipped, a double `neg`
removed; every other field except `name` and `mechanism` is equal (L4.1)."""

import json
import math
import subprocess
from pathlib import Path
from typing import Any

import pytest

from gate.control.tests import support
from gate.kernel import MM

pytestmark = pytest.mark.usefixtures("built_kernel")

FOLDER = Path(__file__).resolve().parents[1] / "programs"
REFERENCE = FOLDER / "reference.json"
PAIRS = {
    "constant": ("long", "short"),
    "trend": ("momentum", "reversal"),
    "random_low": ("random_low", "random_low_neg"),
    "random_mid": ("random_mid", "random_mid_neg"),
    "random_high": ("random_high", "random_high_neg"),
}
MIRROR = sorted(name for pair in PAIRS.values() for name in pair)
EVENT_INPUTS = {"funding", "premium", "forum_posts", "gov_proposals"}
PRICE_INPUTS = {"open", "high", "low", "close", "volume"}
COINS, GROSS_CAP = 12, 2
CAL_MARKET = "control-1-cal-a-0000"
SMOKE_STRENGTH = 0.005


def load(name: str) -> dict[str, Any]:
    loaded: dict[str, Any] = json.loads((FOLDER / f"{name}.json").read_text())
    return loaded


def nodes(node: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(node, dict):
        found.append(node)
        for child in node.values():
            found += nodes(child)
    elif isinstance(node, list):
        for child in node:
            found += nodes(child)
    return found


def inputs_read(node: Any) -> set[str]:
    return {str(n["input"]) for n in nodes(node) if "input" in n}


def negate(weight: dict[str, Any]) -> dict[str, Any]:
    if weight.get("op") == "neg":
        inner: dict[str, Any] = weight["args"][0]
        return inner
    if "const" in weight:
        return {**weight, "const": -weight["const"]}
    return {"op": "neg", "args": [weight]}


def constant_value(weight: dict[str, Any]) -> float:
    if "const" in weight:
        return float(weight["const"])
    assert weight.get("op") == "neg", "a constant program is a const or a neg of one"
    return -constant_value(weight["args"][0])


def test_the_set_is_a_reference_and_ten_programs() -> None:
    files = sorted(p.stem for p in FOLDER.glob("*.json"))
    assert files == sorted(["reference", *MIRROR])
    texts = {json.dumps(load(name), sort_keys=True) for name in files}
    assert len(texts) == 11


@pytest.mark.parametrize("name", ["reference", *MIRROR])
def test_every_program_type_checks_in_the_kernel(name: str, tmp_path: Path) -> None:
    out = subprocess.run(
        [
            str(MM),
            "check",
            str(FOLDER / f"{name}.json"),
            "--campaign",
            "t",
            "--agent",
            "t",
            "--ledger",
            str(tmp_path / "l.sqlite"),
        ],
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    assert out.returncode == 0, out.stdout + out.stderr
    assert json.loads(out.stdout.strip().splitlines()[-1])["ok"] is True


def test_every_program_scores_on_a_calibration_market(tmp_path: Path) -> None:
    market = support.study_market(tmp_path / "m", CAL_MARKET, SMOKE_STRENGTH)
    for name in ["reference", *MIRROR]:
        value = support.score(FOLDER / f"{name}.json", market, tmp_path / "l.sqlite")
        assert value is not None and math.isfinite(value), name


def test_the_reference_reads_funding_and_no_other_event_input() -> None:
    read = inputs_read(load("reference"))
    assert "funding" in read
    assert not read & (EVENT_INPUTS - {"funding"})


@pytest.mark.parametrize("name", MIRROR)
def test_no_mirror_program_reads_funding_or_premium(name: str) -> None:
    read = inputs_read(load(name))
    assert not read & EVENT_INPUTS
    assert read <= PRICE_INPUTS


def test_the_constant_pair_holds_opposite_constants_at_the_highest_leverage() -> None:
    long_value = constant_value(load("long")["weight"])
    short_value = constant_value(load("short")["weight"])
    assert long_value > 0 and short_value < 0
    assert long_value == -short_value
    assert abs(long_value) >= GROSS_CAP / COINS


def test_the_trend_pair_reads_the_last_days_close_only() -> None:
    for name in PAIRS["trend"]:
        program = load(name)
        assert inputs_read(program) == {"close"}
        hours = {n["hours"] for n in nodes(program["weight"]) if n.get("op") in {"lag", "mean", "sum"}}
        assert 24 in hours, name


def test_the_three_random_pairs_differ() -> None:
    texts = {json.dumps(load(PAIRS[pair][0])["weight"], sort_keys=True) for pair in PAIRS if pair.startswith("random")}
    assert len(texts) == 3


@pytest.mark.parametrize("pair", list(PAIRS))
def test_l4_1_the_members_of_a_mirror_pair_differ_only_by_the_sign_of_the_target(pair: str) -> None:
    first, second = (load(name) for name in PAIRS[pair])
    for field in set(first) | set(second):
        if field not in {"weight", "name", "mechanism"}:
            assert first.get(field) == second.get(field), field
    assert second["weight"] == negate(first["weight"])
    assert first["weight"] == negate(second["weight"])
    assert first["weight"] != second["weight"]


@pytest.mark.slow  # 50 pairs, two 730-day markets each, scored by the kernel
def test_the_reference_earns_on_at_least_45_of_50_pairs(tmp_path: Path) -> None:
    positive = 0
    for i in range(50):
        market_id = f"control-1-cal-a-{i:04d}"
        planted = support.study_market(tmp_path / f"p{i}", market_id, SMOKE_STRENGTH)
        twin = support.study_market(tmp_path / f"t{i}", market_id, 0.0)
        with_plant = support.score(REFERENCE, planted, tmp_path / "l.sqlite")
        without = support.score(REFERENCE, twin, tmp_path / "l.sqlite")
        if with_plant is not None and without is not None and with_plant - without > 0:
            positive += 1
    assert positive >= 45
