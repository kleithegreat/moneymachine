"""Step 5 of the revised build plan: calibration and the model-free walls (gate/control/calibrate.py), laws L5.1-L5.5.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `find_strength(earns, ids, log, workers=1) -> dict`, keys "strength" (float, None when no strength), "stopped"
  (bool, true exactly when strength is None) and "rate" (the strength's rate on `ids`, None when stopped).
  `earns(strength, market_id) -> bool` is whether G100's pick earns from the plant there; the stub stands in for the
  kernel. With workers above 1, `earns` is a picklable module-level callable and may run in threads or processes.
  `log` is the JSON-lines file, one line per (strength, market) evaluated, that a restarted run resumes from. Caching
  the strength-zero twins across candidates is allowed, so the tests never count twin work, only `earns` calls.
- The bracket is [0, HI], HI = 0.01; the rule is the plan's. A rate is within the tolerance when
  `abs(rate - TARGET) <= TOLERANCE`, inclusive. The tests skip rates exactly on that edge, which floats cannot decide.
- `rate_at(earns, strength, ids, log, workers=1) -> float`: G100's rate at a strength (the check).
- `wall_2(effects)`, `wall_3(earns)`, `wall_4(strength, earns)` return {"count", "denominator", "status"}, status
  "pass" or "stop". `effects` are the reference's effects, None where undefined; `earns` are booleans, one per
  classification (wall 3) or per check market (wall 4); `strength` is the search's result, None when it found none.
  Thresholds come from `constants` (EVEN_ALLOWED, BAND) and 0.95 for wall 2.
- `make_report(*, search, effects, even_earns, check_earns, mirror_rates, pick_wins) -> dict` with keys "strength",
  "walls" ({"2","3","4"} reports), "mirror_rates" (as given) and "pick_histogram" (58 counts, index k the number of
  picks that won k pairs). The last two are never judged.
- `cal_a_ids()`, `cal_b_ids()`, `blind_ids()`; `g100_seed(manifest_seed, market_id) -> int`;
  `g100_earns(strength, market_id, work, manifest_seed="control-1") -> bool`, one market through the kernel;
  `projected_seconds(seconds_per_evaluation, cores=1)`; `projection_ok(seconds_per_evaluation, cores) -> bool`, true
  when the projection is at most 24 hours."""

import contextlib
import hashlib
import json
import math
import tempfile
from fractions import Fraction
from pathlib import Path

import pytest
from hypothesis import assume, given, settings
from hypothesis import strategies as st

from gate.control import calibrate, constants
from gate.control.constants import BAND, EVEN_ALLOWED, MAX_STEPS, PAIRS, TARGET, TOLERANCE

HI = 0.01
SEARCH_SIZE = constants.SEARCH_MARKETS
LAW = settings(max_examples=25, deadline=None)
IDS = [f"control-1-cal-a-{i:04d}" for i in range(SEARCH_SIZE)]
SMALL = IDS[:200]


def uniform(market_id: str) -> float:
    return int.from_bytes(hashlib.sha256(market_id.encode()).digest()[:8], "big") / 2**64


class Rate:
    """A picklable stub: G100 earns on a market when the market's fixed uniform is below `rate(strength)`.
    `rate` is `clamp(slope * s/HI + wiggle * sin(freq * s/HI), 0, 1)`: rising when wiggle is 0, otherwise not."""

    def __init__(self, slope: float, wiggle: float = 0.0, freq: float = 0.0, die_after: int | None = None) -> None:
        self.slope, self.wiggle, self.freq, self.die_after = slope, wiggle, freq, die_after
        self.calls: list[tuple[float, str]] = []

    def rate(self, strength: float) -> float:
        x = strength / HI
        return min(1.0, max(0.0, self.slope * x + self.wiggle * math.sin(self.freq * x)))

    def __call__(self, strength: float, market_id: str) -> bool:
        if self.die_after is not None and len(self.calls) >= self.die_after:
            raise RuntimeError("killed")
        self.calls.append((strength, market_id))
        return uniform(market_id) < self.rate(strength)


class Jump(Rate):
    """A rate that is 0 up to a strength and 0.3 above it: no strength can sit inside the tolerance."""

    def rate(self, strength: float) -> float:
        return 0.3 if strength > 0.0001 else 0.0


def realized(stub: Rate, strength: float, ids: list[str]) -> Fraction:
    return Fraction(sum(uniform(i) < stub.rate(strength) for i in ids), len(ids))


def classify(rate: Fraction) -> str:
    gap = abs(rate - Fraction(str(TARGET)))
    edge = Fraction(str(TOLERANCE))
    assume(gap != edge)
    return "inside" if gap < edge else ("above" if rate > Fraction(str(TARGET)) else "below")


def reference_search(stub: Rate, ids: list[str]) -> tuple[float | None, list[float]]:
    """The plan's rule, implemented here. Returns the strength (None for no strength) and the strengths visited."""
    visited = [HI]
    verdict = classify(realized(stub, HI, ids))
    if verdict == "inside":
        return HI, visited
    if verdict == "below":
        return None, visited
    lo, hi = 0.0, HI
    for _ in range(MAX_STEPS):
        mid = (lo + hi) / 2
        visited.append(mid)
        verdict = classify(realized(stub, mid, ids))
        if verdict == "inside":
            return mid, visited
        if verdict == "above":
            hi = mid
        else:
            lo = mid
    return None, visited


def run(stub: Rate, ids: list[str], log: Path, workers: int = 1) -> dict[str, object]:
    result: dict[str, object] = calibrate.find_strength(stub, ids, log, workers)
    return result


def verdict(result: dict[str, object]) -> tuple[object, object, object]:
    return result["strength"], result["stopped"], result["rate"]


def visited_in_order(calls: list[tuple[float, str]]) -> list[float]:
    seen: list[float] = []
    for strength, _ in calls:
        if strength not in seen:
            seen.append(strength)
    return seen


any_rate = st.builds(Rate, st.floats(0.0, 0.6), st.floats(0.0, 0.15), st.floats(0.0, 40.0))


def fresh_log() -> Path:
    return Path(tempfile.mkdtemp(dir=tempfile.gettempdir())) / "log.jsonl"


def test_the_constants_the_search_rests_on() -> None:
    assert (TARGET, TOLERANCE, MAX_STEPS, SEARCH_SIZE, constants.CHECK_MARKETS) == (0.15, 0.005, 12, 1600, 10000)
    assert tuple(BAND) == (0.12, 0.18)


def test_rising_rate_crossing_the_target_returns_a_strength(tmp_path: Path) -> None:
    for stub in (Rate(0.3), Rate(0.45), Rate(0.6)):
        result = run(stub, IDS, tmp_path / f"{stub.slope}.jsonl")
        assert result["stopped"] is False
        assert isinstance(result["strength"], float)
        assert 0 < result["strength"] <= HI
        assert abs(realized(stub, result["strength"], IDS) - Fraction(str(TARGET))) <= Fraction(str(TOLERANCE))


def test_the_upper_end_is_evaluated_first_on_every_market(tmp_path: Path) -> None:
    stub = Rate(0.3)
    run(stub, IDS, tmp_path / "log.jsonl")
    assert [s for s, _ in stub.calls[:SEARCH_SIZE]] == [HI] * SEARCH_SIZE


def test_a_rate_below_the_band_at_the_upper_end_stops_the_run(tmp_path: Path) -> None:
    stub = Rate(0.1)
    result = run(stub, IDS, tmp_path / "log.jsonl")
    assert (result["stopped"], result["strength"]) == (True, None)
    assert {s for s, _ in stub.calls} == {HI}
    assert len(stub.calls) == SEARCH_SIZE


def test_no_candidate_inside_the_tolerance_stops_the_run(tmp_path: Path) -> None:
    jump = Jump(0.0)
    result = run(jump, SMALL, tmp_path / "log.jsonl")
    assert (result["stopped"], result["strength"]) == (True, None)
    assert len(visited_in_order(jump.calls)) <= MAX_STEPS + 1


def test_a_stopped_run_restarted_stays_stopped_without_new_evaluations(tmp_path: Path) -> None:
    log = tmp_path / "log.jsonl"
    run(Rate(0.1), SMALL, log)
    again = Rate(0.1)
    assert run(again, SMALL, log)["stopped"] is True
    assert again.calls == []


def test_a_finished_run_restarted_evaluates_nothing_and_agrees(tmp_path: Path) -> None:
    log = tmp_path / "log.jsonl"
    first = run(Rate(0.3), SMALL, log)
    again = Rate(0.3)
    assert verdict(run(again, SMALL, log)) == verdict(first)
    assert again.calls == []


def test_the_id_sets_are_the_plans_and_share_nothing() -> None:
    a, b, blind = calibrate.cal_a_ids(), calibrate.cal_b_ids(), calibrate.blind_ids()
    assert (len(a), len(b), len(blind)) == (1600, 10000, 200)
    assert (a[0], a[-1]) == ("control-1-cal-a-0000", "control-1-cal-a-1599")
    assert (b[0], b[-1]) == ("control-1-cal-b-0000", "control-1-cal-b-9999")
    assert (blind[0], blind[-1]) == ("control-1-blind-000", "control-1-blind-199")
    assert len(set(a) | set(b) | set(blind)) == 11800


@given(st.text(min_size=1, max_size=12), st.text(min_size=1, max_size=20))
def test_g100_seed_is_the_first_eight_bytes_of_the_sha256(manifest_seed: str, market_id: str) -> None:
    digest = hashlib.sha256(f"{manifest_seed}:{market_id}:G100".encode()).digest()
    assert calibrate.g100_seed(manifest_seed, market_id) == int.from_bytes(digest[:8], "big")


def test_the_projection_is_the_plans_count_of_evaluations() -> None:
    evaluations = 328 * 1600 * 13 + 328 * 10000 + 250_800
    assert evaluations == 10_353_200
    assert calibrate.projected_seconds(1.0) == pytest.approx(evaluations)
    assert calibrate.projected_seconds(0.25, 8) == pytest.approx(evaluations / 32)


@given(st.floats(0.001, 1.0), st.integers(1, 200))
def test_a_projection_above_24_hours_stops_the_job(seconds: float, cores: int) -> None:
    projected = calibrate.projected_seconds(seconds, cores)
    assume(abs(projected - 86400) > 1)
    assert calibrate.projection_ok(seconds, cores) is (projected <= 86400)


@pytest.mark.slow  # 100 G100 evaluations, 342 scorings, kernel
def test_g100_never_earns_at_strength_zero(tmp_path: Path) -> None:
    """At strength zero a market and its twin are one market, so the reference's effect is zero, not positive."""
    for market_id in ("control-1-cal-a-0000", "control-1-cal-a-0001"):
        assert calibrate.g100_earns(0.0, market_id, tmp_path / market_id) is False


def effects_with(positive: int, total: int, other: float | None = -1.0) -> list[float | None]:
    return [1.0] * positive + [other] * (total - positive)


def test_wall_2_needs_95_percent_positive_effects() -> None:
    ok = calibrate.wall_2(effects_with(950, 1000))
    assert (ok["count"], ok["denominator"], ok["status"]) == (950, 1000, "pass")
    bad = calibrate.wall_2(effects_with(949, 1000))
    assert (bad["count"], bad["denominator"], bad["status"]) == (949, 1000, "stop")


@pytest.mark.parametrize("other", [0.0, None, math.nan, -2.0, -math.inf, math.inf])
def test_wall_2_counts_zero_negative_missing_and_nonfinite_effects_as_not_positive(other: float | None) -> None:
    assert calibrate.wall_2(effects_with(949, 1000, other))["status"] == "stop"
    assert calibrate.wall_2(effects_with(950, 1000, other))["status"] == "pass"
    assert calibrate.wall_2([other] * 100)["status"] == "stop"


def test_wall_3_allows_at_most_the_constant_of_the_classifications() -> None:
    total = 5 * constants.BLIND_MARKETS
    ok = calibrate.wall_3([True] * EVEN_ALLOWED + [False] * (total - EVEN_ALLOWED))
    assert (ok["count"], ok["denominator"], ok["status"]) == (EVEN_ALLOWED, total, "pass")
    bad = calibrate.wall_3([True] * (EVEN_ALLOWED + 1) + [False] * (total - EVEN_ALLOWED - 1))
    assert (bad["count"], bad["denominator"], bad["status"]) == (EVEN_ALLOWED + 1, total, "stop")
    assert calibrate.wall_3([False] * total)["status"] == "pass"


def test_wall_4_needs_a_strength_and_a_check_rate_inside_the_band() -> None:
    n = constants.CHECK_MARKETS
    lo, hi = round(BAND[0] * n), round(BAND[1] * n)
    for earned, status in (
        (lo - 1, "stop"),
        (lo + 1, "pass"),
        (hi - 1, "pass"),
        (hi + 1, "stop"),
        (0, "stop"),
        (n, "stop"),
    ):
        report = calibrate.wall_4(0.004, [True] * earned + [False] * (n - earned))
        assert (report["count"], report["denominator"], report["status"]) == (earned, n, status)
    assert calibrate.wall_4(None, [True] * (n // 7) + [False] * (n - n // 7))["status"] == "stop"


def test_the_report_holds_each_wall_and_the_unjudged_figures() -> None:
    n = constants.CHECK_MARKETS
    wins = [0] * 10 + [PAIRS] * 5 + [39] * 3
    report = calibrate.make_report(
        search={"strength": 0.004, "stopped": False, "rate": 0.15},
        effects=effects_with(960, 1000),
        even_earns=[False] * 1000,
        check_earns=[True] * (n * 15 // 100) + [False] * (n - n * 15 // 100),
        mirror_rates={"long": 0.3},
        pick_wins=wins,
    )
    assert report["strength"] == 0.004
    assert {k: report["walls"][k]["status"] for k in "234"} == {"2": "pass", "3": "pass", "4": "pass"}
    assert report["mirror_rates"] == {"long": 0.3}
    histogram = report["pick_histogram"]
    assert len(histogram) == PAIRS + 1
    assert (histogram[0], histogram[PAIRS], histogram[39], sum(histogram)) == (10, 5, 3, len(wins))
    json.dumps(report)
    other = calibrate.make_report(
        search={"strength": 0.004, "stopped": False, "rate": 0.15},
        effects=effects_with(960, 1000),
        even_earns=[False] * 1000,
        check_earns=[True] * (n * 15 // 100) + [False] * (n - n * 15 // 100),
        mirror_rates={"long": 0.9},
        pick_wins=[20] * 50,
    )
    assert other["walls"] == report["walls"]


@LAW
@given(any_rate)
def test_l5_1_any_returned_strength_is_inside_the_tolerance_and_otherwise_none_is_reported(stub: Rate) -> None:
    result = run(stub, SMALL, fresh_log())
    expected, _ = reference_search(Rate(stub.slope, stub.wiggle, stub.freq), SMALL)
    assert result["strength"] == expected
    assert result["stopped"] is (result["strength"] is None)
    if result["strength"] is not None:
        gap = abs(realized(stub, float(result["strength"]), SMALL) - Fraction(str(TARGET)))
        assert gap <= Fraction(str(TOLERANCE))


@LAW
@given(any_rate)
def test_l5_2_at_most_thirteen_strengths_the_upper_end_first_none_twice_all_in_the_bracket(stub: Rate) -> None:
    run(stub, SMALL, fresh_log())
    _, visited = reference_search(Rate(stub.slope, stub.wiggle, stub.freq), SMALL)
    seen = visited_in_order(stub.calls)
    assert seen == visited
    assert len(seen) <= MAX_STEPS + 1
    assert seen[0] == HI
    assert all(0 < s <= HI for s in seen)
    assert len(stub.calls) == len(set(stub.calls))


@LAW
@given(any_rate, st.data())
def test_l5_3_an_interrupted_run_restarted_gives_the_same_report_and_repeats_no_market(
    stub: Rate, data: st.DataObject
) -> None:
    clean_stub = Rate(stub.slope, stub.wiggle, stub.freq)
    clean = run(clean_stub, SMALL, fresh_log())
    cut = data.draw(st.integers(0, len(clean_stub.calls)))
    log = fresh_log()
    first = Rate(stub.slope, stub.wiggle, stub.freq, die_after=cut)
    with contextlib.suppress(RuntimeError):
        run(first, SMALL, log)
    second = Rate(stub.slope, stub.wiggle, stub.freq)
    resumed = run(second, SMALL, log)
    assert verdict(resumed) == verdict(clean)
    assert not set(first.calls) & set(second.calls)
    assert sorted(first.calls + second.calls) == sorted(clean_stub.calls)
    assert len(log.read_text().splitlines()) == len(clean_stub.calls)


@settings(max_examples=10, deadline=None)
@given(any_rate, st.randoms(use_true_random=False), st.sampled_from([1, 3]))
def test_l5_4_a_rate_does_not_depend_on_the_order_markets_finish_or_the_workers(
    stub: Rate, rnd: object, workers: int
) -> None:
    base = run(Rate(stub.slope, stub.wiggle, stub.freq), SMALL, fresh_log())
    shuffled = list(SMALL)
    rnd.shuffle(shuffled)  # type: ignore[attr-defined]
    other = run(Rate(stub.slope, stub.wiggle, stub.freq), shuffled, fresh_log(), workers)
    assert verdict(other) == verdict(base)


@given(st.integers(0, 1000))
def test_l5_5_wall_2_passes_exactly_when_the_count_is_at_least_95_percent(count: int) -> None:
    report = calibrate.wall_2(effects_with(count, 1000))
    assert report["count"] == count
    assert (report["status"] == "pass") is (count >= 950)


@given(st.integers(0, 1000))
def test_l5_5_wall_3_passes_exactly_when_the_count_is_at_most_the_allowance(count: int) -> None:
    report = calibrate.wall_3([True] * count + [False] * (1000 - count))
    assert report["count"] == count
    assert (report["status"] == "pass") is (count <= EVEN_ALLOWED)


@given(st.integers(0, 1000))
def test_l5_5_wall_4_passes_exactly_when_the_check_rate_is_inside_the_band(count: int) -> None:
    n = 1000
    assume(round(BAND[0] * n) != count != round(BAND[1] * n))
    report = calibrate.wall_4(0.004, [True] * count + [False] * (n - count))
    assert report["count"] == count
    assert (report["status"] == "pass") is (BAND[0] * n < count < BAND[1] * n)
