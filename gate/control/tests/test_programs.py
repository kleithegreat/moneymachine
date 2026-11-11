"""Step 4 of the build plan: the reference and the funding-blind set (gate/control/programs/*.json).

The reference is programs/reference.json; the other seven files in that directory are the funding-blind set."""

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
BLIND = sorted(p for p in FOLDER.glob("*.json") if p != REFERENCE)
FUNDING_INPUTS = {"funding", "premium"}
CAL_MARKET = "control-1-cal-a-000"
SMOKE_STRENGTH = 0.005


def inputs_read(node: Any) -> set[str]:
    """Every held input named anywhere in a program's JSON."""
    found: set[str] = set()
    if isinstance(node, dict):
        if "input" in node:
            found.add(str(node["input"]))
        for child in node.values():
            found |= inputs_read(child)
    elif isinstance(node, list):
        for child in node:
            found |= inputs_read(child)
    return found


def test_the_set_is_a_reference_and_seven_programs() -> None:
    assert REFERENCE.is_file()
    assert len(BLIND) == 7
    texts = {json.dumps(json.loads(p.read_text()), sort_keys=True) for p in [REFERENCE, *BLIND]}
    assert len(texts) == 8


@pytest.mark.parametrize("path", [REFERENCE, *BLIND], ids=lambda p: p.stem)
def test_every_program_type_checks_in_the_kernel(path: Path, tmp_path: Path) -> None:
    out = subprocess.run(
        [str(MM), "check", str(path), "--campaign", "t", "--agent", "t", "--ledger", str(tmp_path / "l.sqlite")],
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    assert out.returncode == 0, out.stdout + out.stderr
    assert json.loads(out.stdout.strip().splitlines()[-1])["ok"] is True


def test_every_program_scores_on_a_calibration_market(tmp_path: Path) -> None:
    market = support.study_market(tmp_path / "m", CAL_MARKET, SMOKE_STRENGTH)
    for path in [REFERENCE, *BLIND]:
        value = support.score(path, market, tmp_path / "l.sqlite")
        assert value is not None and math.isfinite(value), path.name


def test_the_reference_reads_funding() -> None:
    assert inputs_read(json.loads(REFERENCE.read_text())) & FUNDING_INPUTS


@pytest.mark.parametrize("path", BLIND, ids=lambda p: p.stem)
def test_no_blind_program_reads_funding_or_premium(path: Path) -> None:
    assert not inputs_read(json.loads(path.read_text())) & FUNDING_INPUTS


@pytest.mark.slow  # 50 pairs, two 730-day markets each, scored by the kernel
def test_the_reference_earns_on_at_least_45_of_50_pairs(tmp_path: Path) -> None:
    positive = 0
    for i in range(50):
        market_id = f"control-1-cal-a-{i:03d}"
        planted = support.study_market(tmp_path / f"p{i}", market_id, SMOKE_STRENGTH)
        twin = support.study_market(tmp_path / f"t{i}", market_id, 0.0)
        with_plant = support.score(REFERENCE, planted, tmp_path / "l.sqlite")
        without = support.score(REFERENCE, twin, tmp_path / "l.sqlite")
        if with_plant is not None and without is not None and with_plant - without > 0:
            positive += 1
    assert positive >= 45
