"""Study 1, step 2: the measure (audit/program/briefs/1-positive-control.md, "Definitions the tests rest on" and
step 2; audit/program/architecture.md 5.1). Written from the plan before the code, by another model than the
builder's.

A pair is (planted score, twin score); a program's effect on it is planted minus twin. A pick wins a pair when both
effects are defined, the reference's is positive and the pick's is at least SHARE times it; it earns from the plant
when it wins at least MAJORITY of the PAIRS pairs.
"""

import hashlib
import math
import random
from fractions import Fraction
from pathlib import Path
from typing import Any

import pytest

from gate import markets, search
from gate.control.constants import MAJORITY, PAIRS, SHARE
from gate.control.measure import classify, score, scores

Score = float | None
Pair = tuple[Score, Score]
Finite = tuple[float, float]
Program = dict[str, Any]

REFERENCE: Pair = (2.0, 1.0)
HALF: Pair = (1.5, 1.0)
NOTHING: Pair = (1.0, 1.0)
BAD = (None, math.nan, math.inf, -math.inf)


def lists(won: int) -> tuple[list[Pair], list[Pair]]:
    """A pick and a reference of PAIRS pairs, where the pick wins exactly the first `won`."""
    pick = [HALF] * won + [NOTHING] * (PAIRS - won)
    return pick, [REFERENCE] * PAIRS


def one(pick: Pair, reference: Pair) -> int:
    """The count classify gives when the pair under test is the only one that could be won."""
    picks = [pick] + [NOTHING] * (PAIRS - 1)
    references = [reference] + [REFERENCE] * (PAIRS - 1)
    won, _ = classify(picks, references)
    count: int = won
    return count


def test_constants_are_the_plans() -> None:
    assert (PAIRS, MAJORITY, SHARE) == (32, 24, 0.5)


def test_returns_the_count_and_whether_it_reaches_the_majority() -> None:
    assert classify(*lists(0)) == (0, False)
    assert classify(*lists(PAIRS)) == (PAIRS, True)


def test_23_pairs_won_is_false_and_24_is_true() -> None:
    assert classify(*lists(23)) == (23, False)
    assert classify(*lists(24)) == (24, True)


def test_every_count_is_judged_by_the_majority_alone() -> None:
    for won in range(PAIRS + 1):
        assert classify(*lists(won)) == (won, won >= 24)


@pytest.mark.parametrize(
    ("pick", "reference", "won"),
    [
        pytest.param(HALF, REFERENCE, 1, id="exactly half the reference's effect"),
        pytest.param((math.nextafter(1.5, 0.0), 1.0), REFERENCE, 0, id="just below half"),
        pytest.param((3.0, 1.0), REFERENCE, 1, id="above the reference's effect"),
        pytest.param((-1.0, -1.5), (-2.0, -3.0), 1, id="negative scores, effects 0.5 and 1"),
        pytest.param((-1.25, -1.5), (-2.0, -3.0), 0, id="negative scores, effects 0.25 and 1"),
        pytest.param((10.0, 0.0), (1.0, 1.0), 0, id="reference effect zero, pick large"),
        pytest.param(NOTHING, (1.0, 1.0), 0, id="reference effect zero, pick zero"),
        pytest.param((100.0, 0.0), (0.0, 1.0), 0, id="reference negative, pick large positive"),
        pytest.param((0.0, 0.0), (0.0, 1.0), 0, id="reference negative, pick zero above half of it"),
        pytest.param((-1.0, 0.0), (0.0, 1.0), 0, id="reference negative, pick equal to it"),
        pytest.param((-1e3, 1.0), REFERENCE, 0, id="pick ruined on the planted market"),
    ],
)
def test_a_pair_is_won_exactly_as_defined(pick: Pair, reference: Pair, won: int) -> None:
    assert one(pick, reference) == won


@pytest.mark.parametrize("bad", BAD, ids=repr)
@pytest.mark.parametrize("slot", range(4), ids=("pick planted", "pick twin", "reference planted", "reference twin"))
def test_a_missing_or_nonfinite_score_loses_the_pair(slot: int, bad: Score) -> None:
    scores_ = [*HALF, *REFERENCE]
    scores_[slot] = bad
    pick: Pair = (scores_[0], scores_[1])
    reference: Pair = (scores_[2], scores_[3])
    assert one(pick, reference) == 0


def test_infinite_effects_on_both_sides_lose_the_pair() -> None:
    assert one((math.inf, 0.0), (math.inf, 0.0)) == 0
    assert one((0.0, -math.inf), (0.0, -math.inf)) == 0


def test_a_pick_with_no_scores_wins_nothing() -> None:
    assert classify([(None, None)] * PAIRS, [REFERENCE] * PAIRS) == (0, False)


def test_a_ruined_pick_with_huge_effects_of_either_sign_does_not_earn() -> None:
    """Architecture 5.1: near bankruptcy the twin difference is large and of either sign. Its mean effect here is
    far above the reference's, yet it wins only the pairs where its effect is positive."""
    pick: list[Pair] = [(2e6, 0.0) if i % 2 else (-1e6, 0.0) for i in range(PAIRS)]
    assert classify(pick, [REFERENCE] * PAIRS) == (16, False)


def test_pairs_are_matched_by_position() -> None:
    pick: list[Pair] = [HALF] * 24 + [NOTHING] * 8
    reference: list[Pair] = [REFERENCE] * 24 + [(0.0, 1.0)] * 8
    assert classify(pick, reference) == (24, True)
    assert classify(pick, reference[::-1]) == (16, False)


def dyadic(rng: random.Random, bound: int) -> float:
    """A multiple of 1/4, so sums and halves are exact in floating point."""
    return rng.randint(-4 * bound, 4 * bound) / 4


def random_lists(rng: random.Random) -> tuple[list[Finite], list[Finite]]:
    pick = [(dyadic(rng, 10), dyadic(rng, 10)) for _ in range(PAIRS)]
    reference = [(dyadic(rng, 10), dyadic(rng, 10)) for _ in range(PAIRS)]
    return pick, reference


def expected_count(pick: list[Finite], reference: list[Finite]) -> int:
    """The definition, computed independently on finite scores."""
    won = 0
    for (pick_planted, pick_twin), (reference_planted, reference_twin) in zip(pick, reference):
        pick_effect = pick_planted - pick_twin
        reference_effect = reference_planted - reference_twin
        if reference_effect > 0 and 2 * pick_effect >= reference_effect:
            won += 1
    return won


@pytest.mark.parametrize("seed", range(20))
def test_random_scores_follow_the_definition(seed: int) -> None:
    pick, reference = random_lists(random.Random(seed))
    won = expected_count(pick, reference)
    assert classify(pick, reference) == (won, won >= 24)


@pytest.mark.parametrize("seed", range(20))
def test_adding_one_number_to_a_programs_two_scores_on_a_pair_changes_nothing(seed: int) -> None:
    rng = random.Random(seed)
    pick, reference = random_lists(rng)
    before = classify(pick, reference)
    shifted_pick: list[Finite] = []
    shifted_reference: list[Finite] = []
    for (a, b), (c, d) in zip(pick, reference):
        u, v = dyadic(rng, 1000), dyadic(rng, 1000)
        shifted_pick.append((a + u, b + u))
        shifted_reference.append((c + v, d + v))
    assert classify(shifted_pick, shifted_reference) == before


@pytest.mark.parametrize("seed", range(5))
def test_the_order_of_the_pairs_does_not_matter(seed: int) -> None:
    rng = random.Random(seed)
    pick, reference = random_lists(rng)
    order = list(range(PAIRS))
    rng.shuffle(order)
    assert classify([pick[i] for i in order], [reference[i] for i in order]) == classify(pick, reference)


@pytest.mark.parametrize(
    ("pick_length", "reference_length"), [(31, 32), (32, 31), (33, 32), (32, 33), (31, 31), (33, 33), (0, 0)]
)
def test_a_list_that_is_not_32_long_is_an_error(pick_length: int, reference_length: int) -> None:
    with pytest.raises(ValueError):
        classify([HALF] * pick_length, [REFERENCE] * reference_length)


def pass_chance(q: Fraction) -> Fraction:
    """P(a pick earns) when it wins each pair independently with chance q, summed over classify's own verdicts."""
    chance = Fraction(0)
    for won in range(PAIRS + 1):
        _, earns = classify(*lists(won))
        if earns:
            chance += math.comb(PAIRS, won) * q**won * (1 - q) ** (PAIRS - won)
    return chance


def test_a_chance_of_one_half_passes_with_probability_0_0035_exactly() -> None:
    exact = pass_chance(Fraction(1, 2))
    assert exact == Fraction(sum(math.comb(32, k) for k in range(24, 33)), 2**32)
    assert round(float(exact), 4) == 0.0035


def test_no_chance_at_or_below_one_half_passes_more_often() -> None:
    bound = pass_chance(Fraction(1, 2))
    for q in (Fraction(k, 20) for k in range(11)):
        assert pass_chance(q) <= bound


def test_a_chance_of_0_9_passes_with_probability_0_997() -> None:
    assert round(float(pass_chance(Fraction(9, 10))), 3) == 0.997


MOMENTUM: Program = search.compile_genome({"sig": ["feat", 0, "close", 24], "size": 1.0, "squash": "sign"})
FLAT: Program = {
    "dsl": 1,
    "name": "flat",
    "mechanism": {"counterparty": "unstated", "predictions": [], "capacity": "-"},
    "weight": {"const": 0.0, "unit": "1"},
}
REJECTED: Program = FLAT | {"weight": {"op": "sign", "args": [{"input": "forum_posts"}]}}
PLANTED = range(6)


def market(root: Path, market_id: str, strength: float) -> Path:
    path: Path = markets.write_market(
        root / f"{market_id.replace('/', '_')}-{strength}",
        market_id,
        days=60,
        holdout_days=10,
        planted=PLANTED,
        beta=strength,
    )
    return path


def twin(root: Path, market_id: str) -> Path:
    path: Path = markets.write_market(root / f"{market_id.replace('/', '_')}-twin", market_id, days=60, holdout_days=10)
    return path


def tree(root: Path) -> dict[str, str]:
    return {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob("*") if p.is_file()
    }


@pytest.fixture
def isolated(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, built_kernel: Path) -> Path:
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_score_is_the_disclosed_statistic_and_repeats(isolated: Path) -> None:
    planted = market(isolated, "m/fresh/0", 0.005)
    first = score(MOMENTUM, planted)
    assert isinstance(first, float) and math.isfinite(first)
    assert score(MOMENTUM, planted) == first


def test_a_program_the_kernel_rejects_has_no_score(isolated: Path) -> None:
    assert score(REJECTED, market(isolated, "m/fresh/0", 0.005)) is None


def test_scoring_writes_nothing_beside_the_market_or_in_the_working_directory(isolated: Path) -> None:
    planted = market(isolated, "m/fresh/0", 0.005)
    before = tree(isolated)
    score(MOMENTUM, planted)
    score(REJECTED, planted)
    assert tree(isolated) == before


def test_scores_returns_one_score_pair_per_fresh_pair_in_order(isolated: Path) -> None:
    planted, unplanted = market(isolated, "m/fresh/0", 0.005), twin(isolated, "m/fresh/0")
    on_planted, on_twin = score(MOMENTUM, planted), score(MOMENTUM, unplanted)
    assert on_planted != on_twin
    assert scores(MOMENTUM, [(planted, unplanted), (unplanted, planted)]) == [
        (on_planted, on_twin),
        (on_twin, on_planted),
    ]


def test_scores_of_a_rejected_program_are_missing_on_both_sides(isolated: Path) -> None:
    pair = (market(isolated, "m/fresh/0", 0.005), twin(isolated, "m/fresh/0"))
    assert scores(REJECTED, [pair]) == [(None, None)]


def test_a_program_that_never_trades_scores_the_same_on_a_market_and_its_twin(isolated: Path) -> None:
    pairs = [(market(isolated, f"m/fresh/{i}", 0.005), twin(isolated, f"m/fresh/{i}")) for i in range(2)]
    for planted_score, twin_score in scores(FLAT, pairs):
        assert planted_score == twin_score or (planted_score is None and twin_score is None)


@pytest.mark.parametrize("program", [MOMENTUM, FLAT], ids=("momentum", "flat"))
def test_at_strength_zero_every_effect_is_exactly_zero(isolated: Path, program: Program) -> None:
    pairs = [(market(isolated, f"m/fresh/{i}", 0.0), twin(isolated, f"m/fresh/{i}")) for i in range(3)]
    for planted_score, twin_score in scores(program, pairs):
        assert planted_score is not None and twin_score is not None
        assert planted_score - twin_score == 0.0
