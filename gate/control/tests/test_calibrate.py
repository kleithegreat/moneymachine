"""Step 5 of the build plan: calibration and the model-free walls (gate/control/calibrate.py).

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `find_strength(earns, ids, log) -> dict` with keys "strength" (float, None when stopped) and "stopped" (bool).
  `earns(strength, market_id) -> bool` is whether G100's pick earns from the plant there, so the stub stands in for
  the kernel. `log` is the JSON-lines file, one line a market, that a restarted run resumes from. The bracket is
  [0, 0.01], eight bisection steps, target 0.15.
- `wall_2(effects)`, `wall_3(earns)`, `wall_4(earns)` each return {"count", "denominator", "status"}, status being
  "pass" or "stop". `effects` are the reference's effects on the cal-b pairs, None where undefined.
- `cal_a_ids()`, `cal_b_ids()`, `blind_ids()` are the id sets the plan names.
- `projected_seconds(seconds_per_evaluation)` is the whole job's time."""

import hashlib
import json
import math
from collections.abc import Callable, Sequence
from pathlib import Path

import pytest

from gate.control import calibrate

LO, HI, STEPS, TARGET = 0.0, 0.01, 8, 0.15
IDS = [f"control-1-cal-a-{i:03d}" for i in range(400)]


def uniform(market_id: str) -> float:
    return int.from_bytes(hashlib.sha256(market_id.encode()).digest()[:8], "big") / 2**64


class Stub:
    """A rate that rises with strength, one fixed function of strength on a fixed set of markets."""

    def __init__(self, rate: Callable[[float], float], die_after: int | None = None) -> None:
        self.rate = rate
        self.die_after = die_after
        self.calls: list[tuple[float, str]] = []

    def __call__(self, strength: float, market_id: str) -> bool:
        if self.die_after is not None and len(self.calls) >= self.die_after:
            raise RuntimeError("killed")
        self.calls.append((strength, market_id))
        return uniform(market_id) < self.rate(strength)


def linear(strength: float) -> float:
    return 0.3 * strength / HI


def convex(strength: float) -> float:
    return 0.45 * (strength / HI) ** 2


def expected_path(stub_rate: Callable[[float], float], ids: Sequence[str]) -> list[float]:
    """The plan's rule, implemented here: the upper end first, then eight midpoints."""
    path = [HI]
    lo, hi = LO, HI
    for _ in range(STEPS):
        mid = (lo + hi) / 2
        path.append(mid)
        earned = sum(uniform(i) < stub_rate(mid) for i in ids)
        if earned / len(ids) > TARGET:
            hi = mid
        else:
            lo = mid
    return path


def verdict(result: dict[str, object]) -> tuple[object, object]:
    return result["strength"], result["stopped"]


def strengths_in_order(calls: list[tuple[float, str]]) -> list[float]:
    seen: list[float] = []
    for strength, _ in calls:
        if strength not in seen:
            seen.append(strength)
    return seen


@pytest.mark.parametrize("rate", [linear, convex], ids=["linear", "convex"])
def test_bisection_ends_within_a_256th_of_the_crossing(tmp_path: Path, rate: Callable[[float], float]) -> None:
    stub = Stub(rate)
    result = calibrate.find_strength(stub, IDS, tmp_path / "log.jsonl")
    sixty_first = sorted(uniform(i) for i in IDS)[60]
    crossing = min(s for s in (k * HI / 100000 for k in range(100001)) if rate(s) > sixty_first)
    assert result["stopped"] is False
    assert abs(result["strength"] - crossing) <= HI / 256 + 1e-6


@pytest.mark.parametrize("rate", [linear, convex], ids=["linear", "convex"])
def test_the_rule_is_the_plans_and_every_step_uses_the_same_markets(
    tmp_path: Path, rate: Callable[[float], float]
) -> None:
    stub = Stub(rate)
    result = calibrate.find_strength(stub, IDS, tmp_path / "log.jsonl")
    path = expected_path(rate, IDS)
    assert strengths_in_order(stub.calls) == pytest.approx(path, rel=1e-12)
    assert len(path) == 9
    assert result["strength"] == pytest.approx(path[-1], rel=1e-12)
    for strength in path:
        used = [m for s, m in stub.calls if s == pytest.approx(strength, rel=1e-12)]
        assert sorted(used) == sorted(IDS)


def test_the_upper_end_is_evaluated_first_on_every_market(tmp_path: Path) -> None:
    stub = Stub(linear)
    calibrate.find_strength(stub, IDS, tmp_path / "log.jsonl")
    assert [s for s, _ in stub.calls[: len(IDS)]] == [HI] * len(IDS)


def test_a_rate_at_or_below_the_target_at_the_upper_end_stops_the_run(tmp_path: Path) -> None:
    stub = Stub(lambda s: 0.1)
    result = calibrate.find_strength(stub, IDS, tmp_path / "log.jsonl")
    assert result["stopped"] is True
    assert result["strength"] is None
    assert {s for s, _ in stub.calls} == {HI}
    assert len(stub.calls) == len(IDS)


def test_exactly_the_target_at_the_upper_end_also_stops(tmp_path: Path) -> None:
    firsts = set(IDS[:60])
    calls: list[tuple[float, str]] = []

    def earns(strength: float, market_id: str) -> bool:
        calls.append((strength, market_id))
        return market_id in firsts

    result = calibrate.find_strength(earns, IDS, tmp_path / "log.jsonl")
    assert result["stopped"] is True
    assert {s for s, _ in calls} == {HI}


def test_a_rate_just_above_the_target_at_the_upper_end_goes_on(tmp_path: Path) -> None:
    firsts = set(IDS[:61])
    result = calibrate.find_strength(lambda s, m: m in firsts, IDS, tmp_path / "log.jsonl")
    assert result["stopped"] is False
    assert result["strength"] is not None
    assert 0 < result["strength"] <= HI


@pytest.mark.parametrize("die_after", [7, 400, 1234, 3599])
def test_a_killed_run_resumes_without_repeating_a_market(tmp_path: Path, die_after: int) -> None:
    log = tmp_path / "log.jsonl"
    first = Stub(linear, die_after=die_after)
    with pytest.raises(RuntimeError):
        calibrate.find_strength(first, IDS, log)
    second = Stub(linear)
    resumed = calibrate.find_strength(second, IDS, log)
    clean = calibrate.find_strength(Stub(linear), IDS, tmp_path / "clean.jsonl")
    assert not set(first.calls) & set(second.calls)
    assert len(set(first.calls) | set(second.calls)) == len(first.calls) + len(second.calls)
    assert verdict(resumed) == verdict(clean)
    lines = [json.loads(line) for line in log.read_text().splitlines()]
    assert len(lines) == len(first.calls) + len(second.calls)


def test_a_finished_run_restarted_evaluates_nothing_and_agrees(tmp_path: Path) -> None:
    log = tmp_path / "log.jsonl"
    first = calibrate.find_strength(Stub(linear), IDS, log)
    again = Stub(linear)
    second = calibrate.find_strength(again, IDS, log)
    assert again.calls == []
    assert verdict(second) == verdict(first)


def test_a_stopped_run_restarted_stays_stopped_without_new_evaluations(tmp_path: Path) -> None:
    log = tmp_path / "log.jsonl"
    calibrate.find_strength(Stub(lambda s: 0.1), IDS, log)
    again = Stub(lambda s: 0.1)
    result = calibrate.find_strength(again, IDS, log)
    assert result["stopped"] is True
    assert again.calls == []


def test_the_id_sets_are_the_plans_and_share_nothing() -> None:
    a, b, blind = calibrate.cal_a_ids(), calibrate.cal_b_ids(), calibrate.blind_ids()
    assert (len(a), len(b), len(blind)) == (400, 2000, 200)
    assert a[0] == "control-1-cal-a-000" and a[-1] == "control-1-cal-a-399"
    assert b[0] == "control-1-cal-b-0000" and b[-1] == "control-1-cal-b-1999"
    assert blind[0] == "control-1-blind-000" and blind[-1] == "control-1-blind-199"
    assert len(set(a) | set(b) | set(blind)) == 2600


def test_the_projection_is_the_plans_count_of_evaluations() -> None:
    assert calibrate.projected_seconds(1.0) == pytest.approx(1_276_800 + 102_400)
    assert calibrate.projected_seconds(0.25) == pytest.approx((1_276_800 + 102_400) / 4)


def positive_share(count: int, total: int) -> list[float | None]:
    effects: list[float | None] = [1.0] * count
    effects += [-1.0] * (total - count)
    return effects


def test_wall_2_needs_95_percent_positive_effects() -> None:
    ok = calibrate.wall_2(positive_share(950, 1000))
    assert (ok["count"], ok["denominator"], ok["status"]) == (950, 1000, "pass")
    bad = calibrate.wall_2(positive_share(949, 1000))
    assert (bad["count"], bad["denominator"], bad["status"]) == (949, 1000, "stop")


def test_wall_2_counts_zero_negative_missing_and_nonfinite_effects_as_not_positive() -> None:
    bad_kinds: list[float | None] = [0.0, None, math.nan, -2.0, math.inf]
    bad = [bad_kinds[i % 5] for i in range(51)]
    stop = calibrate.wall_2([1.0] * 949 + bad)
    assert (stop["count"], stop["denominator"], stop["status"]) == (949, 1000, "stop")
    passing = calibrate.wall_2([1.0] * 950 + bad[:50])
    assert (passing["count"], passing["denominator"], passing["status"]) == (950, 1000, "pass")
    assert calibrate.wall_2([0.0] * 100)["status"] == "stop"
    assert calibrate.wall_2([None] * 100)["status"] == "stop"


def test_wall_3_allows_at_most_14_of_1400() -> None:
    ok = calibrate.wall_3([True] * 14 + [False] * 1386)
    assert (ok["count"], ok["denominator"], ok["status"]) == (14, 1400, "pass")
    bad = calibrate.wall_3([True] * 15 + [False] * 1385)
    assert (bad["count"], bad["denominator"], bad["status"]) == (15, 1400, "stop")
    assert calibrate.wall_3([False] * 1400)["status"] == "pass"


@pytest.mark.parametrize(
    ("earned", "status"),
    [(259, "stop"), (260, "pass"), (300, "pass"), (340, "pass"), (341, "stop"), (0, "stop"), (2000, "stop")],
)
def test_wall_4_is_the_band_013_to_017_of_2000(earned: int, status: str) -> None:
    report = calibrate.wall_4([True] * earned + [False] * (2000 - earned))
    assert (report["count"], report["denominator"], report["status"]) == (earned, 2000, status)
