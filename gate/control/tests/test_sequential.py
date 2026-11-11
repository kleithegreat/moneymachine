"""Study 1, step 6: the sequential rule (audit/program/briefs/1-positive-control.md step 6; audit/program/architecture.md
5.1 to 5.3; audit/program/arithmetic.py.txt, `sign_test` and `study1`). Written from the plan before the code, by
another model than the builder's.

Wald's sequential sign test on discordant markets, theta <= 1/2 against THETA1, nominal errors ALPHA and BETA_ERROR,
ending undecided at MAX_MARKETS. A win adds log(THETA1 / 0.5) and a loss log((1 - THETA1) / 0.5); the boundaries are
+-log 19. The operating characteristics are computed here by exact enumeration over (wins, losses), each state
classified by `decide` itself.
"""

import math
from collections.abc import Iterable

import pytest

from gate.control.constants import ALPHA, BETA_ERROR, MAX_MARKETS, THETA1
from gate.control.sequential import decide, outcome

DECISIONS = ("claim", "futility", "undecided", "continue")


def test_constants_are_the_plans() -> None:
    assert (THETA1, ALPHA, BETA_ERROR, MAX_MARKETS) == (0.7, 0.05, 0.05, 100)
    assert math.log((1 - BETA_ERROR) / ALPHA) == pytest.approx(math.log(19), abs=1e-12)


def exact(wins: int, losses: int, markets: int) -> str:
    """The rule in integers: the sum w log(7/5) + l log(3/5) against +-log 19 is 7^w 3^l against 19^(+-1) 5^(w+l)."""
    gains = 7**wins * 3**losses
    scale = 5 ** (wins + losses)
    if gains >= 19 * scale:
        return "claim"
    if 19 * gains <= scale:
        return "futility"
    return "undecided" if markets == MAX_MARKETS else "continue"


def test_decide_matches_the_rule_on_every_reachable_count() -> None:
    for wins in range(MAX_MARKETS + 1):
        for losses in range(MAX_MARKETS + 1 - wins):
            for markets in sorted({wins + losses, MAX_MARKETS - 1, MAX_MARKETS} - set(range(wins + losses))):
                assert decide(wins, losses, markets) == exact(wins, losses, markets), (wins, losses, markets)


@pytest.mark.parametrize(
    ("wins", "losses", "decision"),
    [
        (9, 0, "claim"),
        (8, 0, "continue"),
        (0, 6, "futility"),
        (0, 5, "continue"),
        (12, 2, "claim"),
        (11, 2, "continue"),
        (15, 4, "claim"),
        (14, 4, "continue"),
        (4, 9, "futility"),
        (5, 9, "continue"),
        (1, 1, "continue"),
    ],
)
def test_hand_worked_sums(wins: int, losses: int, decision: str) -> None:
    """9 log 1.4 = 3.028 >= log 19 = 2.944 > 8 log 1.4 = 2.692; 6 log 0.6 = -3.065 <= -2.944 < 5 log 0.6 = -2.554;
    12 log 1.4 + 2 log 0.6 = 3.016 and 11 log 1.4 + 2 log 0.6 = 2.680: three more wins for every two losses;
    4 log 1.4 + 9 log 0.6 = -3.251 and 5 log 1.4 + 9 log 0.6 = -2.915."""
    assert decide(wins, losses, wins + losses) == decision


def test_nine_straight_wins_claim_and_eight_do_not() -> None:
    assert [decide(n, 0, n) for n in range(1, 10)] == ["continue"] * 8 + ["claim"]


def test_six_straight_losses_stop_and_five_do_not() -> None:
    assert [decide(0, n, n) for n in range(1, 7)] == ["continue"] * 5 + ["futility"]


def test_concordant_markets_move_nothing_but_count_toward_the_end() -> None:
    for markets in range(MAX_MARKETS):
        assert decide(0, 0, markets) == "continue"
        assert decide(8, 5, max(markets, 13)) == "continue"
    assert decide(0, 0, MAX_MARKETS) == "undecided"
    assert decide(8, 5, MAX_MARKETS) == "undecided"


def test_a_boundary_at_the_hundredth_market_is_still_a_boundary() -> None:
    assert decide(9, 0, MAX_MARKETS) == "claim"
    assert decide(0, 6, MAX_MARKETS) == "futility"
    assert decide(8, 0, MAX_MARKETS) == "undecided"
    assert decide(0, 5, MAX_MARKETS) == "undecided"


def test_outcome_is_a_win_only_when_only_the_agent_earns_and_a_loss_only_when_only_g100_does() -> None:
    assert outcome(True, False) == "win"
    assert outcome(False, True) == "loss"
    for concordant in ((True, True), (False, False)):
        assert outcome(*concordant) not in ("win", "loss")


def first_stop(results: Iterable[tuple[bool, bool]]) -> tuple[str, int]:
    """The rule applied in the manifest's order: the first decision that is not `continue`, and its market."""
    wins = losses = markets = 0
    decision = "continue"
    for agent_earns, searcher_earns in results:
        markets += 1
        result = outcome(agent_earns, searcher_earns)
        wins += result == "win"
        losses += result == "loss"
        decision = decide(wins, losses, markets)
        if decision != "continue":
            break
    return decision, markets


WIN, LOSS, BOTH, NEITHER = (True, False), (False, True), (True, True), (False, False)


def test_the_decision_is_the_one_at_the_first_crossing_whatever_follows() -> None:
    """decide reads counts only, so the counts after a crossing can fall back inside: the order is what judges."""
    assert first_stop([WIN] * 9 + [LOSS] * 6) == ("claim", 9)
    assert decide(9, 6, 15) == "continue"
    assert first_stop([LOSS] * 6 + [WIN] * 9) == ("futility", 6)
    assert first_stop([BOTH, WIN, NEITHER] * 9 + [LOSS] * 20) == ("claim", 26)
    assert first_stop([BOTH] * 99 + [WIN] * 9) == ("undecided", 100)


Law = tuple[float, float]


def characteristics(agent_only: float, searcher_only: float) -> tuple[float, float, float, float]:
    """P(claim), P(futility), P(undecided) and the expected markets, by exact enumeration over (wins, losses), where a
    market is a win with chance `agent_only`, a loss with chance `searcher_only` and concordant otherwise."""
    alive: dict[tuple[int, int], float] = {(0, 0): 1.0}
    ended = {decision: 0.0 for decision in DECISIONS}
    expected = 0.0
    steps = ((1, 0, agent_only), (0, 1, searcher_only), (0, 0, 1 - agent_only - searcher_only))
    for markets in range(1, MAX_MARKETS + 1):
        following: dict[tuple[int, int], float] = {}
        for (wins, losses), mass in alive.items():
            for more_wins, more_losses, chance in steps:
                state = (wins + more_wins, losses + more_losses)
                reached = mass * chance
                decision = decide(*state, markets)
                if decision == "continue":
                    following[state] = following.get(state, 0.0) + reached
                else:
                    ended[decision] += reached
                    expected += markets * reached
        alive = following
    assert not alive
    return ended["claim"], ended["futility"], ended["undecided"], expected


@pytest.mark.parametrize(
    ("law", "claim", "futility", "undecided", "markets"),
    [
        pytest.param((0.5, 0.5), 0.043, 0.936, 0.021, 33, id="worst null"),
        pytest.param((0.1275, 0.1275), 0.020, 0.453, 0.527, 82, id="null at 0.15, independent"),
        pytest.param((0.5, 0.19), 0.943, 0.017, 0.041, 41, id="0.5 against 0.19, least overlap"),
        pytest.param((0.425, 0.075), 0.999, 0.000, 0.001, 29, id="0.5 against 0.15, independent"),
    ],
)
def test_the_plans_operating_characteristics(
    law: Law, claim: float, futility: float, undecided: float, markets: float
) -> None:
    """Step 6's table: probabilities to within 0.0006, expected markets to within 0.6."""
    found = characteristics(*law)
    assert found[:3] == pytest.approx((claim, futility, undecided), abs=0.0006)
    assert found[3] == pytest.approx(markets, abs=0.6)


def test_the_size_under_the_worst_null_is_at_most_0_043() -> None:
    claim, futility, undecided, markets = characteristics(0.5, 0.5)
    assert claim <= 0.043 + 0.0005
    assert round(claim, 3) == 0.043 and round(futility, 3) == 0.936 and round(markets) == 33
    assert claim + futility + undecided == pytest.approx(1.0, abs=1e-12)


@pytest.mark.parametrize(
    "law",
    [(d, d) for d in (0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.45)]
    + [(0.3, 0.4), (0.45, 0.55), (0.1, 0.3), (0.49, 0.51), (0.0, 0.5)],
)
def test_no_null_law_claims_more_often_than_the_worst(law: Law) -> None:
    """Under the null only the agent earns no more often than only G100 does; every market discordant at one half is
    the worst case (architecture 5.2)."""
    assert characteristics(*law)[0] <= characteristics(0.5, 0.5)[0]


def overlaps(agent: float, searcher: float) -> list[Law]:
    """The discordant chances at least overlap, independent arms and most overlap (`study1`)."""
    return [(agent - both, searcher - both) for both in (0.0, agent * searcher, searcher)]


POWER = {
    (0.5, 0.11): (0.999, 1.000, 1.000),
    (0.5, 0.15): (0.988, 0.999, 1.000),
    (0.5, 0.19): (0.943, 0.993, 1.000),
    (0.4, 0.11): (0.981, 0.996, 1.000),
    (0.4, 0.15): (0.901, 0.968, 1.000),
    (0.4, 0.19): (0.734, 0.871, 1.000),
    (0.3, 0.11): (0.822, 0.888, 0.998),
    (0.3, 0.15): (0.568, 0.667, 0.973),
    (0.3, 0.19): (0.323, 0.396, 0.783),
}


@pytest.mark.parametrize(("rates", "claims"), POWER.items(), ids=[f"{a} against {g}" for a, g in POWER])
def test_the_power_table_of_section_5_3(rates: Law, claims: tuple[float, float, float]) -> None:
    found = [characteristics(*law)[0] for law in overlaps(*rates)]
    assert found == pytest.approx(claims, abs=0.0005)


@pytest.mark.parametrize(("rate", "claim"), [(0.11, 0.014), (0.15, 0.020), (0.19, 0.025)])
def test_equal_independent_rates_claim_as_section_5_3_says(rate: float, claim: float) -> None:
    discordant = rate * (1 - rate)
    assert characteristics(discordant, discordant)[0] == pytest.approx(claim, abs=0.0005)


def test_at_the_target_the_claim_is_at_least_0_943_in_41_markets_expected_at_worst() -> None:
    found = [characteristics(*law) for searcher in (0.11, 0.15, 0.19) for law in overlaps(0.5, searcher)]
    assert round(min(claim for claim, _, _, _ in found), 3) == 0.943
    assert round(max(markets for _, _, _, markets in found)) == 41


def test_at_0_3_against_0_15_the_study_ends_without_the_claim_one_time_in_three_to_two_in_five() -> None:
    """CS1.1: 0.33 to 0.43; architecture 5.4: a futility stop up to 8% of the time, undecided up to 36%."""
    found = [characteristics(*law) for law in overlaps(0.3, 0.15)]
    misses = [1 - claim for claim, _, _, _ in found[:2]]
    assert [round(miss, 2) for miss in misses] == [0.43, 0.33]
    assert max(futility for _, futility, _, _ in found) <= 0.08
    assert max(undecided for _, _, undecided, _ in found) <= 0.36


@pytest.mark.parametrize(
    ("law", "claim", "undecided"),
    [
        pytest.param((0.5, 0.3), 0.529, None, id="G100 at 0.3, least overlap"),
        pytest.param((0.0625, 0.0125), 0.083, 0.917, id="0.25 and 0.2 with 0.1875 in common"),
    ],
)
def test_argons_rows(law: Law, claim: float, undecided: float | None) -> None:
    found = characteristics(*law)
    assert found[0] == pytest.approx(claim, abs=0.0005)
    if undecided is not None:
        assert found[2] == pytest.approx(undecided, abs=0.0005)
