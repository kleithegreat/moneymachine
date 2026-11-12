"""Study 1, step 2: the measure, and its laws L2.1 to L2.12 (audit/program/briefs/1-positive-control.md at 54c11fb,
"Definitions the tests rest on" and step 2; audit/program/architecture.md 5.1). Written from the plan before the
code, by another model than the builder's.

A pair is (planted score, twin score); a program's effect on it is planted minus twin, undefined when either score
is missing or not finite. A pick wins a pair when both effects are defined, the reference's is positive and the
pick's is at least SHARE times it; it earns from the plant when it wins at least MAJORITY of the PAIRS pairs.

Laws marked for Lean in the plan: L2.8 (`test_l2_8_*`) and L2.10 (`test_l2_10_*`). The plan's other four Lean laws,
L6.1, L6.4, L6.5 and L6.6, are step 6's and are not in this file.
"""

import hashlib
import math
import random
import subprocess
import tempfile
from collections.abc import Callable
from fractions import Fraction
from pathlib import Path
from typing import Any

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from gate import markets, search
from gate.control.constants import MAJORITY, PAIRS, SHARE
from gate.control.measure import classify, even, score, scores

Score = float | None
Pair = tuple[Score, Score]
Contest = tuple[list[Pair], list[Pair]]
Program = dict[str, Any]

REFERENCE: Pair = (2.0, 1.0)
HALF: Pair = (1.5, 1.0)
NOTHING: Pair = (1.0, 1.0)
LOST: Pair = (None, None)
BAD: tuple[Score, ...] = (None, math.nan, math.inf, -math.inf)


def lists(won: int) -> Contest:
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


def won_pairs(pick: list[Pair], reference: list[Pair]) -> set[int]:
    """The pairs the pick wins, each found by classifying it with every other pair of the pick missing."""
    found: set[int] = set()
    for i in range(PAIRS):
        alone = [LOST] * PAIRS
        alone[i] = pick[i]
        count, _ = classify(alone, reference)
        if count == 1:
            found.add(i)
    return found


def effect(pair: Pair) -> float | None:
    planted, twin = pair
    if planted is None or twin is None or not math.isfinite(planted) or not math.isfinite(twin):
        return None
    return planted - twin


def expected_count(pick: list[Pair], reference: list[Pair]) -> int:
    """The definition, computed independently."""
    won = 0
    for pick_pair, reference_pair in zip(pick, reference):
        pick_effect, reference_effect = effect(pick_pair), effect(reference_pair)
        if pick_effect is None or reference_effect is None:
            continue
        if reference_effect > 0 and 2 * pick_effect >= reference_effect:
            won += 1
    return won


def tail(pairs: int, majority: int, q: Fraction) -> Fraction:
    """P(at least `majority` wins in `pairs` independent trials at chance q), exactly."""
    terms = (math.comb(pairs, k) * q**k * (1 - q) ** (pairs - k) for k in range(majority, pairs + 1))
    return sum(terms, start=Fraction(0))


def pass_chance(q: Fraction) -> Fraction:
    """P(a pick earns) when it wins each pair independently with chance q, summed over classify's own verdicts."""
    chance = Fraction(0)
    for won in range(PAIRS + 1):
        _, earns = classify(*lists(won))
        if earns:
            chance += math.comb(PAIRS, won) * q**won * (1 - q) ** (PAIRS - won)
    return chance


def test_constants_are_the_plans() -> None:
    assert (PAIRS, MAJORITY, SHARE) == (57, 39, 0.5)


def test_the_rule_is_the_smallest_with_both_bounds() -> None:
    """The first (pairs, majority), by pairs then majority, that classes a pick at q = 1/2 as earning with
    probability at most 1/200 and one at q = 3/4 with probability at least 9/10, in whole numbers."""
    found = None
    for pairs in range(1, PAIRS + 1):
        for majority in range(pairs + 1):
            wins = range(majority, pairs + 1)
            at_half = 200 * sum(math.comb(pairs, k) for k in wins) <= 2**pairs
            at_three_quarters = 10 * sum(math.comb(pairs, k) * 3**k for k in wins) >= 9 * 4**pairs
            if found is None and at_half and at_three_quarters:
                found = (pairs, majority)
    assert found == (57, 39) == (PAIRS, MAJORITY)


def test_returns_the_count_and_whether_it_reaches_the_majority() -> None:
    assert classify(*lists(0)) == (0, False)
    assert classify(*lists(PAIRS)) == (PAIRS, True)


def test_38_pairs_won_is_false_and_39_is_true() -> None:
    assert classify(*lists(38)) == (38, False)
    assert classify(*lists(39)) == (39, True)


def test_every_count_is_judged_by_the_majority_alone() -> None:
    for won in range(PAIRS + 1):
        assert classify(*lists(won)) == (won, won >= 39)


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
    assert classify([LOST] * PAIRS, [REFERENCE] * PAIRS) == (0, False)


def test_a_ruined_pick_with_huge_effects_of_either_sign_does_not_earn() -> None:
    """Architecture 5.1: near bankruptcy the twin difference is large and of either sign. Its mean effect here is
    far above the reference's, yet it wins only the 28 pairs where its effect is positive."""
    pick: list[Pair] = [(2e6, 0.0) if i % 2 else (-1e6, 0.0) for i in range(PAIRS)]
    assert classify(pick, [REFERENCE] * PAIRS) == (28, False)


def test_pairs_are_matched_by_position() -> None:
    pick: list[Pair] = [HALF] * 39 + [NOTHING] * 18
    reference: list[Pair] = [REFERENCE] * 39 + [(0.0, 1.0)] * 18
    assert classify(pick, reference) == (39, True)
    assert classify(pick, reference[::-1]) == (21, False)


@pytest.mark.parametrize(
    ("pick_length", "reference_length"), [(56, 57), (57, 56), (58, 57), (57, 58), (56, 56), (58, 58), (0, 0)]
)
def test_a_list_that_is_not_57_long_is_an_error(pick_length: int, reference_length: int) -> None:
    with pytest.raises(ValueError):
        classify([HALF] * pick_length, [REFERENCE] * reference_length)


def test_even_is_the_mean_of_the_members_scores_on_each_market() -> None:
    member: list[Pair] = [(3.0, 1.0), (None, 2.0), (1.0, None), (-4.0, 0.5)] + [NOTHING] * (PAIRS - 4)
    mirror: list[Pair] = [(-1.0, 2.0), (5.0, 4.0), (None, None), (2.0, 0.25)] + [NOTHING] * (PAIRS - 4)
    expected: list[Pair] = [(1.0, 1.5), (None, 3.0), (None, None), (-1.0, 0.375)] + [NOTHING] * (PAIRS - 4)
    assert [tuple(pair) for pair in even(member, mirror)] == expected


UNIT = 2.0**-16


def grid(low: int, high: int) -> st.SearchStrategy[float]:
    """Multiples k of 2^-16 with low <= k <= high: step 2 draws finite scores with |k| <= 2^20, so that sums,
    differences and halves are exact in binary64."""
    return st.integers(low, high).map(lambda k: k * UNIT)


finite = grid(-(2**20), 2**20)
half_range = grid(-(2**19), 2**19)
raises = grid(0, 2**20)
bad = st.sampled_from(BAD)
any_score = st.one_of(finite, finite, finite, bad)
present_score = st.one_of(finite, finite, finite, st.none())
indices = st.integers(0, PAIRS - 1)


def pair_lists(scores_: st.SearchStrategy[Score]) -> st.SearchStrategy[list[Pair]]:
    return st.lists(st.tuples(scores_, scores_), min_size=PAIRS, max_size=PAIRS)


@st.composite
def close_contests(draw: st.DrawFn) -> Contest:
    """A reference with positive effects, multiples of 2^-14, and a pick at a multiple of 1/4 of each, so that counts
    fall near the majority and every score stays on step 2's grid."""
    pick: list[Pair] = []
    reference: list[Pair] = []
    for _ in range(PAIRS):
        reference_effect = draw(st.integers(1, 2**16)) * 4 * UNIT
        reference_twin = draw(half_range)
        pick_effect = reference_effect * draw(st.integers(-2, 8)) / 4
        pick_twin = draw(half_range)
        reference.append((reference_twin + reference_effect, reference_twin))
        pick.append((pick_twin + pick_effect, pick_twin))
    return pick, reference


def contests(scores_: st.SearchStrategy[Score] = any_score) -> st.SearchStrategy[Contest]:
    return st.one_of(st.tuples(pair_lists(scores_), pair_lists(scores_)), close_contests())


@given(contests())
def test_classify_follows_the_definition(contest: Contest) -> None:
    pick, reference = contest
    won = expected_count(pick, reference)
    assert classify(pick, reference) == (won, won >= MAJORITY)


@given(contests())
def test_l2_1_the_count_is_in_range_and_the_verdict_is_the_majority(contest: Contest) -> None:
    count, earns = classify(*contest)
    assert 0 <= count <= PAIRS
    assert earns == (count >= MAJORITY)


def shifted(pair: Pair, by: float) -> Pair:
    planted, twin = pair
    return (None if planted is None else planted + by, None if twin is None else twin + by)


@given(contests(), st.lists(finite, min_size=PAIRS, max_size=PAIRS), st.lists(finite, min_size=PAIRS, max_size=PAIRS))
def test_l2_2_adding_one_number_to_both_scores_of_a_pair_changes_nothing(
    contest: Contest, pick_shifts: list[float], reference_shifts: list[float]
) -> None:
    pick, reference = contest
    moved_pick = [shifted(pair, by) for pair, by in zip(pick, pick_shifts)]
    moved_reference = [shifted(pair, by) for pair, by in zip(reference, reference_shifts)]
    assert classify(moved_pick, moved_reference) == classify(pick, reference)


@given(contests(), st.permutations(range(PAIRS)))
def test_l2_3_one_permutation_of_both_lists_changes_nothing(contest: Contest, order: list[int]) -> None:
    pick, reference = contest
    permuted_pick = [pick[i] for i in order]
    permuted_reference = [reference[i] for i in order]
    assert classify(permuted_pick, permuted_reference) == classify(pick, reference)


def raised(pair: Pair, up: float, down: float) -> Pair:
    planted, twin = pair
    return (None if planted is None else planted + up, None if twin is None else twin - down)


@given(contests(), st.lists(st.tuples(indices, raises, raises), max_size=PAIRS))
def test_l2_4_raising_the_picks_planted_score_or_lowering_its_twin_never_lowers_the_count(
    contest: Contest, moves: list[tuple[int, float, float]]
) -> None:
    pick, reference = contest
    before, _ = classify(pick, reference)
    moved = list(pick)
    for i, up, down in moves:
        moved[i] = raised(moved[i], up, down)
    after, _ = classify(moved, reference)
    assert after >= before


def spoiled(pair: Pair, slot: int, value: Score) -> Pair:
    planted, twin = pair
    return (value, twin) if slot == 0 else (planted, value)


@given(contests(), st.lists(st.tuples(st.booleans(), indices, st.integers(0, 1), bad), max_size=2 * PAIRS))
def test_l2_5_a_missing_or_nonfinite_score_never_raises_the_count(
    contest: Contest, spoilers: list[tuple[bool, int, int, Score]]
) -> None:
    pick, reference = contest
    before, _ = classify(pick, reference)
    spoiled_pick, spoiled_reference = list(pick), list(reference)
    for on_pick, i, slot, value in spoilers:
        target = spoiled_pick if on_pick else spoiled_reference
        target[i] = spoiled(target[i], slot, value)
    after, _ = classify(spoiled_pick, spoiled_reference)
    assert after <= before


def positive_pairs(reference: list[Pair]) -> set[int]:
    found: set[int] = set()
    for i, pair in enumerate(reference):
        e = effect(pair)
        if e is not None and e > 0:
            found.add(i)
    return found


@given(pair_lists(any_score))
def test_l2_6_the_reference_against_itself_wins_exactly_its_positive_pairs(reference: list[Pair]) -> None:
    positive = positive_pairs(reference)
    assert won_pairs(reference, reference) == positive
    assert classify(reference, reference) == (len(positive), len(positive) >= MAJORITY)


def scaled_pick(reference: list[Pair], twins: list[float], c: float) -> list[Pair]:
    pick: list[Pair] = []
    for (planted, twin), pick_twin in zip(reference, twins):
        assert planted is not None and twin is not None
        pick.append((pick_twin + c * (planted - twin), pick_twin))
    return pick


@st.composite
def stepped_references(draw: st.DrawFn) -> list[Pair]:
    """A finite reference whose effects are multiples of 2^-14, as L2.7 draws them."""
    reference: list[Pair] = []
    for _ in range(PAIRS):
        reference_twin = draw(half_range)
        reference_effect = draw(st.integers(-(2**15), 2**15)) * 4 * UNIT
        reference.append((reference_twin + reference_effect, reference_twin))
    return reference


@given(stepped_references(), st.lists(half_range, min_size=PAIRS, max_size=PAIRS), st.integers(-8, 16))
def test_l2_7_a_pick_at_c_times_the_references_effect_wins_its_positive_pairs_when_c_reaches_share(
    reference: list[Pair], twins: list[float], quarters: int
) -> None:
    """Every scale c = k/4 for k in -8..16 is checked on the count; the drawn one also pair by pair."""
    positive = positive_pairs(reference)
    for k in range(-8, 17):
        count, _ = classify(scaled_pick(reference, twins, k / 4), reference)
        assert count == (len(positive) if k / 4 >= SHARE else 0)
    expected = positive if quarters / 4 >= SHARE else set()
    assert won_pairs(scaled_pick(reference, twins, quarters / 4), reference) == expected


def negated(pick: list[Pair]) -> list[Pair]:
    """The exact negation: every effect negated, by exchanging the planted and twin scores."""
    return [(twin, planted) for planted, twin in pick]


@given(contests())
def test_l2_8_lean_a_pick_and_its_negation_never_win_the_same_pair_nor_both_earn(contest: Contest) -> None:
    pick, reference = contest
    assert not won_pairs(pick, reference) & won_pairs(negated(pick), reference)
    count, earns = classify(pick, reference)
    negated_count, negated_earns = classify(negated(pick), reference)
    assert count + negated_count <= PAIRS
    assert not (earns and negated_earns)
    assert 2 * MAJORITY > PAIRS


def same(a: Score, b: Score) -> bool:
    if a is None or b is None:
        return a is b
    return a == b or (math.isnan(a) and math.isnan(b))


def mean(a: Score, b: Score) -> Score:
    return None if a is None or b is None else (a + b) / 2


@given(pair_lists(present_score), pair_lists(present_score))
def test_even_is_the_mean_of_present_scores_for_every_input(member: list[Pair], mirror: list[Pair]) -> None:
    expected = [(mean(a[0], b[0]), mean(a[1], b[1])) for a, b in zip(member, mirror)]
    assert [tuple(pair) for pair in even(member, mirror)] == expected


@given(pair_lists(any_score), pair_lists(any_score))
def test_l2_9_even_is_symmetric(member: list[Pair], mirror: list[Pair]) -> None:
    one_way, other_way = list(even(member, mirror)), list(even(mirror, member))
    assert len(one_way) == len(other_way) == PAIRS
    for (a_planted, a_twin), (b_planted, b_twin) in zip(one_way, other_way):
        assert same(a_planted, b_planted) and same(a_twin, b_twin)


@given(contests())
def test_l2_9_the_even_part_of_a_program_with_itself_classifies_as_the_program(contest: Contest) -> None:
    pick, reference = contest
    assert classify(even(pick, pick), reference) == classify(pick, reference)


@given(contests())
def test_l2_9_the_even_part_of_a_pick_and_its_negation_has_no_effect_and_wins_nothing(contest: Contest) -> None:
    pick, reference = contest
    part = even(pick, negated(pick))
    for pair in part:
        e = effect(pair)
        assert e is None or e == 0.0
    assert classify(part, reference) == (0, False)


def test_l2_10_lean_the_rules_bound_in_exact_rationals() -> None:
    assert 200 * sum(math.comb(57, k) for k in range(39, 58)) <= 2**57
    assert pass_chance(Fraction(1, 2)) == Fraction(sum(math.comb(57, k) for k in range(39, 58)), 2**57)


fractions = st.fractions(min_value=0, max_value=1, max_denominator=1000)


@settings(max_examples=50)
@given(fractions, fractions)
def test_l2_10_lean_the_chance_of_earning_does_not_fall_as_q_rises(a: Fraction, b: Fraction) -> None:
    low, high = min(a, b), max(a, b)
    assert pass_chance(low) <= pass_chance(high)


@settings(max_examples=50)
@given(st.fractions(min_value=0, max_value=Fraction(1, 2), max_denominator=1000))
def test_l2_10_lean_no_chance_at_or_below_one_half_earns_more_than_one_time_in_200(q: Fraction) -> None:
    assert pass_chance(q) <= Fraction(1, 200)


@settings(max_examples=50)
@given(st.fractions(min_value=Fraction(3, 4), max_value=1, max_denominator=1000))
def test_l2_10_lean_every_chance_at_or_above_three_quarters_earns_nine_times_in_ten(q: Fraction) -> None:
    assert pass_chance(q) >= Fraction(9, 10)


def test_a_chance_of_one_half_earns_with_probability_0_0038() -> None:
    assert round(float(pass_chance(Fraction(1, 2))), 4) == 0.0038


def test_a_chance_of_three_quarters_earns_with_probability_0_901() -> None:
    assert round(float(pass_chance(Fraction(3, 4))), 3) == 0.901


@pytest.mark.parametrize(
    ("q", "chance"),
    [(Fraction(6, 10), 0.12), (Fraction(671, 1000), 0.48), (Fraction(8, 10), 0.99)],
    ids=("0.6", "0.671", "0.8"),
)
def test_the_soft_step_is_the_architectures(q: Fraction, chance: float) -> None:
    assert round(float(pass_chance(q)), 2) == chance
    assert pass_chance(q) == tail(57, 39, q)


def test_revision_4s_rule_passed_three_quarters_only_0_59_of_the_time() -> None:
    assert round(float(tail(32, 24, Fraction(3, 4))), 2) == 0.59


MOMENTUM: Program = search.compile_genome({"sig": ["feat", 0, "close", 24], "size": 1.0, "squash": "sign"})
FLAT: Program = {
    "dsl": 1,
    "name": "flat",
    "mechanism": {"counterparty": "unstated", "predictions": [], "capacity": "-"},
    "weight": {"const": 0.0, "unit": "1"},
}
REJECTED: Program = FLAT | {"weight": {"op": "sign", "args": [{"input": "forum_posts"}]}}
PLANTED = range(6)


def directory(root: Path, market_id: str, name: str) -> Path:
    return root / f"{hashlib.sha256(market_id.encode()).hexdigest()[:16]}-{name}"


def market(root: Path, market_id: str, strength: float) -> Path:
    path: Path = markets.write_market(
        directory(root, market_id, str(strength)),
        market_id,
        days=60,
        holdout_days=10,
        planted=PLANTED,
        beta=strength,
    )
    return path


def twin(root: Path, market_id: str) -> Path:
    path: Path = markets.write_market(
        directory(root, market_id, "twin"), market_id, days=60, holdout_days=10, planted=PLANTED, beta=0.0
    )
    return path


def scored(programs: list[Program], pairs: list[tuple[Path, Path]]) -> list[list[Pair]]:
    return [[(planted, twin) for planted, twin in per_program] for per_program in scores(programs, pairs)]


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
    scores([MOMENTUM, REJECTED], [(planted, planted)])
    assert tree(isolated) == before


def test_scores_returns_each_programs_score_pairs_in_order_and_equal_to_score(isolated: Path) -> None:
    planted, unplanted = market(isolated, "m/fresh/0", 0.005), twin(isolated, "m/fresh/0")
    on_planted, on_twin = score(MOMENTUM, planted), score(MOMENTUM, unplanted)
    flat_planted, flat_twin = score(FLAT, planted), score(FLAT, unplanted)
    assert on_planted != on_twin
    assert scored([MOMENTUM, FLAT], [(planted, unplanted), (unplanted, planted)]) == [
        [(on_planted, on_twin), (on_twin, on_planted)],
        [(flat_planted, flat_twin), (flat_twin, flat_planted)],
    ]
    assert scored([FLAT, MOMENTUM], [(planted, unplanted)]) == [[(flat_planted, flat_twin)], [(on_planted, on_twin)]]


def test_scores_starts_at_most_one_kernel_process_a_market_for_all_its_programs(
    isolated: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pairs = [(market(isolated, f"m/fresh/{i}", 0.005), twin(isolated, f"m/fresh/{i}")) for i in range(3)]
    started: list[object] = []
    original: Callable[..., None] = subprocess.Popen.__init__

    def counting(self: object, *args: Any, **kwargs: Any) -> None:
        started.append(args[0] if args else kwargs.get("args"))
        original(self, *args, **kwargs)

    monkeypatch.setattr(subprocess.Popen, "__init__", counting)
    scores([MOMENTUM, FLAT, REJECTED], pairs)
    assert 0 < len(started) <= 2 * len(pairs)


def test_a_rejected_program_has_no_scores_and_spoils_no_other(isolated: Path) -> None:
    pair = (market(isolated, "m/fresh/0", 0.005), twin(isolated, "m/fresh/0"))
    expected = (score(MOMENTUM, pair[0]), score(MOMENTUM, pair[1]))
    assert scored([REJECTED, MOMENTUM], [pair]) == [[(None, None)], [expected]]


def test_a_program_that_never_trades_scores_the_same_on_a_market_and_its_twin(isolated: Path) -> None:
    pairs = [(market(isolated, f"m/fresh/{i}", 0.005), twin(isolated, f"m/fresh/{i}")) for i in range(2)]
    [flat] = scored([FLAT], pairs)
    for planted_score, twin_score in flat:
        assert planted_score == twin_score or (planted_score is None and twin_score is None)


def test_at_strength_zero_every_effect_is_exactly_zero(isolated: Path) -> None:
    pairs = [(market(isolated, f"m/fresh/{i}", 0.0), twin(isolated, f"m/fresh/{i}")) for i in range(3)]
    for per_program in scored([MOMENTUM, FLAT], pairs):
        for planted_score, twin_score in per_program:
            assert planted_score is not None and twin_score is not None
            assert planted_score - twin_score == 0.0


def g100_program(seed: int, market_path: Path) -> Program:
    """A program from G100's own generator."""
    rng = random.Random(seed)
    genome = search.random_genome(rng, search.features(market_path))
    program: Program = search.compile_genome(genome)
    return program


market_ids = st.text(alphabet="abmz019/-", min_size=1, max_size=16)
seeds = st.integers(0, 2**32 - 1)


@settings(max_examples=6, deadline=None)
@given(seeds, market_ids, st.sampled_from([0.0, 0.005, 0.01]))
def test_l2_11_score_is_a_function(built_kernel: Path, seed: int, market_id: str, strength: float) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        planted = market(Path(scratch), market_id, strength)
        program = g100_program(seed, planted)
        first = score(program, planted)
        assert first is None or math.isfinite(first)
        assert score(program, planted) == first
        assert scored([program], [(planted, planted)]) == [[(first, first)]]


@settings(max_examples=6, deadline=None)
@given(seeds, seeds, market_ids)
def test_l2_12_at_strength_zero_every_programs_effect_is_exactly_zero(
    built_kernel: Path, seed: int, other_seed: int, market_id: str
) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        pair = (market(Path(scratch), market_id, 0.0), twin(Path(scratch), market_id))
        programs = [g100_program(seed, pair[0]), g100_program(other_seed, pair[0])]
        for [(planted_score, twin_score)] in scored(programs, [pair]):
            assert (planted_score is None) == (twin_score is None)
            if planted_score is not None and twin_score is not None:
                assert planted_score - twin_score == 0.0
