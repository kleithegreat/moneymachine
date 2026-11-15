"""Step 5 of the revised build plan: calibration and the model-free walls (gate/control/calibrate.py), laws L5.1-L5.6.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `find_strength(earns, ids, log, workers=1) -> dict`, keys "strength" (float, None when no strength), "stopped"
  (bool, true exactly when strength is None) and "rate" (the strength's rate on `ids`, None when stopped).
  `earns(strength, market_id) -> bool` is whether G100's pick earns from the plant there; the stub stands in for the
  kernel. With workers above 1, `earns` is a picklable module-level callable and may run in threads or processes.
  `log` is the JSON-lines file, one line per (strength, market) evaluated, that a restarted run resumes from.
- The bracket is [0, HI], HI = 0.01; the rule is the plan's. A rate is within the tolerance when
  `abs(rate - TARGET) <= TOLERANCE` in exact arithmetic, the ends included: 29 to 31 of 200 are inside.
- Nothing is kept between trials (revision of 2026-11-13): a trial is a function of its market and its strength
  alone. `g100_earns` makes every pair it scores, both members through `pairs.arrays`, and leaves no market in `work`
  when it returns. Lines that hosts write for a strength's markets are merged into `log` in any order, so each line
  names its market as a JSON string.
- `rate_at(earns, strength, ids, log, workers=1) -> float`: G100's rate at a strength (the check).
- `wall_2(effects)`, `wall_3(earns)`, `wall_4(strength, earns)`, `wall_5(earns)` return {"count", "denominator",
  "status"}, status "pass" or "stop". `effects` are the reference's effects, None where undefined. `wall_4`'s `earns`
  are booleans per check market and `strength` is the search's result, None when it found none. `wall_3`'s `earns`
  maps each of the five mirror pairs ("constant", "trend", "random_low", "random_mid", "random_high") to its 200
  classifications of the even part; `wall_5`'s maps "long" and "short" to their 200 classifications as picks. For
  these two, "count" is the largest of the counts, "denominator" the length of one list, and "counts" maps each key
  to its own count. Thresholds come from `constants` (EVEN_ALLOWED = 4, CONSTANT_ALLOWED = 14, BAND) and 0.95 for
  wall 2. Wall 3 is judged per pair, not pooled.
- `make_report(*, search, effects, even_earns, constant_earns, check_earns, mirror_rates, pick_wins) -> dict` with
  keys "strength", "walls" ({"2","3","4","5"} reports), "mirror_rates" (as given) and "pick_histogram" (58 counts,
  index k the number of picks that won k pairs). The last two are never judged.
- `cal_a_ids()`, `cal_b_ids()`, `blind_ids()`; `g100_seed(manifest_seed, market_id) -> int`;
  `g100_earns(strength, market_id, work, manifest_seed="control-1") -> bool`, one market through the kernel;
  `timed_market() -> float`, the seconds one whole cal-a market takes at the bracket's upper end, everything included;
  `projected_seconds(seconds_per_market, cores=1)`, the whole job's time, in markets: 13 strengths on 1,600, one on
  10,000, and wall 3's blind markets counted as at most 1,000 market-equivalents (the plan's 250,800 evaluations are
   765); the projection is printed and stops nothing: `main` runs whatever its probes' times.
- `shares(ids, weights) -> list[list[str]]`: one contiguous share per positive integer core count, in host order.
   Rounding is unspecified; when the proportions are integral, the lengths are exact.
- `main(argv, *, out, work, trial, blind, probes)` is the batch entry point with injected effects for these tests;
   normal CLI use supplies the real effects. `argv` accepts `--share k --weights w0,w1,...`, with no share for a
   deciding run. `out/calibration.jsonl` is the merged input; a share only appends to `out/share-k.jsonl`, never
   rewrites the merged input or writes `out/calibration.json`. A deciding run appends missing trials to the merged
   input and writes that report. Conflicting trials or probes raise RuntimeError or a nonzero SystemExit.
- `trial(strength, market_id, work) -> dict` holds "earns", "pairs_won", "reference_effects" and "pick_effects"
   (PAIRS effects each). `blind(strength, market_id, work) -> dict` holds "even_earns", "constant_earns" and
   "mirror_earns", each mapping names to booleans. These are full trial results, not just their judged bits.
- `probes() -> list[tuple[float, dict]]` supplies each host's whole timed trial result and seconds, in weights order,
   collected from the hosts before this run. All results must agree before any search trial; times may differ.
   Probe transport, like log transport, belongs to the batch runner, not these tests."""

import contextlib
import copy
import hashlib
import json
import math
import re
import tempfile
from collections.abc import Callable, Sequence
from fractions import Fraction
from pathlib import Path
from typing import Any

import pytest
from hypothesis import assume, given, settings
from hypothesis import strategies as st

from gate.control import calibrate, constants, pairs
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
    return "inside" if gap <= edge else ("above" if rate > Fraction(str(TARGET)) else "below")


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


def run(stub: Callable[[float, str], bool], ids: list[str], log: Path, workers: int = 1) -> dict[str, object]:
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
    assert (EVEN_ALLOWED, constants.CONSTANT_ALLOWED, constants.BLIND_MARKETS) == (4, 14, 200)


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


class First:
    """G100 earns exactly on the first `count` markets, at every strength."""

    def __init__(self, count: int) -> None:
        self.earning = set(SMALL[:count])

    def __call__(self, strength: float, market_id: str) -> bool:
        return market_id in self.earning


@pytest.mark.parametrize(("count", "strength"), [(29, HI), (30, HI), (31, HI), (28, None), (32, None)])
def test_the_tolerances_ends_are_inside(tmp_path: Path, count: int, strength: float | None) -> None:
    """145/1000 and 155/1000 are 0.005 from the target: inside. A rate one market beyond is outside, and a constant
    rate beyond it has no strength at the upper end or on any midpoint."""
    result = run(First(count), SMALL, tmp_path / "log.jsonl")
    assert result["strength"] == strength
    assert result["stopped"] is (strength is None)


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
    run(Rate(0.05), SMALL, log)
    again = Rate(0.05)
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


MARKETS = 13 * 1600 + 10000


@given(st.floats(0.001, 100.0), st.integers(1, 200))
def test_the_projection_counts_whole_markets_and_the_blind_ones(seconds: float, cores: int) -> None:
    per_core = calibrate.projected_seconds(seconds, cores) * cores / seconds
    assert MARKETS <= per_core <= MARKETS + 1000


@given(st.floats(0.001, 100.0), st.integers(1, 200), st.floats(1.0, 10.0))
def test_the_projection_is_linear_in_the_market_time_and_inverse_in_the_cores(
    seconds: float, cores: int, factor: float
) -> None:
    base = calibrate.projected_seconds(seconds, cores)
    assert calibrate.projected_seconds(seconds * factor, cores) == pytest.approx(base * factor)
    assert calibrate.projected_seconds(seconds, cores * 2) == pytest.approx(base / 2)


@pytest.mark.slow  # one whole market through the kernel
def test_the_timed_market_is_a_whole_markets_time() -> None:
    seconds = calibrate.timed_market()
    assert math.isfinite(seconds) and seconds > 1.0


@pytest.mark.slow  # two trials of one market through G100 and the kernel
def test_a_trial_makes_its_own_pairs_and_keeps_no_market(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    market_id = "control-1-cal-a-0000"
    fresh = set(pairs.fresh_ids(market_id))
    made: list[tuple[str, float]] = []
    original = pairs.arrays

    def spy(market: str, strength: float) -> Any:
        made.append((market, strength))
        return original(market, strength)

    monkeypatch.setattr(pairs, "arrays", spy)
    work = tmp_path / "work"
    for strength in (0.002, 0.004):
        made.clear()
        calibrate.g100_earns(strength, market_id, work)
        for beta in (strength, 0.0):
            generated = [m for m, s in made if m in fresh and s == beta]
            assert sorted(generated) == sorted(fresh), beta
        assert list(work.rglob("*.parquet")) == []


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


PAIR_NAMES = ("constant", "trend", "random_low", "random_mid", "random_high")
BLIND = constants.BLIND_MARKETS


def counted(count: int, total: int = BLIND) -> list[bool]:
    return [True] * count + [False] * (total - count)


def pairs_with(counts: Sequence[int]) -> dict[str, list[bool]]:
    return {name: counted(count) for name, count in zip(PAIR_NAMES, counts)}


def test_wall_3_is_judged_per_pair_not_pooled() -> None:
    ok = calibrate.wall_3(pairs_with([EVEN_ALLOWED] * 5))
    assert (ok["count"], ok["denominator"], ok["status"]) == (EVEN_ALLOWED, BLIND, "pass")
    assert ok["counts"] == dict.fromkeys(PAIR_NAMES, EVEN_ALLOWED)
    for bad_pair in range(5):
        counts = [0] * 5
        counts[bad_pair] = EVEN_ALLOWED + 1
        bad = calibrate.wall_3(pairs_with(counts))
        assert (bad["count"], bad["denominator"], bad["status"]) == (EVEN_ALLOWED + 1, BLIND, "stop")
        assert bad["counts"][PAIR_NAMES[bad_pair]] == EVEN_ALLOWED + 1
    assert calibrate.wall_3(pairs_with([0] * 5))["status"] == "pass"


def test_wall_5_allows_each_constant_at_most_its_constant() -> None:
    ok = calibrate.wall_5({"long": counted(constants.CONSTANT_ALLOWED), "short": counted(constants.CONSTANT_ALLOWED)})
    assert (ok["count"], ok["denominator"], ok["status"]) == (constants.CONSTANT_ALLOWED, BLIND, "pass")
    assert ok["counts"] == {"long": constants.CONSTANT_ALLOWED, "short": constants.CONSTANT_ALLOWED}
    for bad_side in ("long", "short"):
        sides = {"long": counted(0), "short": counted(0)}
        sides[bad_side] = counted(constants.CONSTANT_ALLOWED + 1)
        bad = calibrate.wall_5(sides)
        assert (bad["count"], bad["status"]) == (constants.CONSTANT_ALLOWED + 1, "stop")


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
        even_earns=pairs_with([0] * 5),
        constant_earns={"long": counted(0), "short": counted(0)},
        check_earns=[True] * (n * 15 // 100) + [False] * (n - n * 15 // 100),
        mirror_rates={"long": 0.3},
        pick_wins=wins,
    )
    assert report["strength"] == 0.004
    assert {k: report["walls"][k]["status"] for k in "2345"} == dict.fromkeys("2345", "pass")
    assert report["mirror_rates"] == {"long": 0.3}
    histogram = report["pick_histogram"]
    assert len(histogram) == PAIRS + 1
    assert (histogram[0], histogram[PAIRS], histogram[39], sum(histogram)) == (10, 5, 3, len(wins))
    json.dumps(report)
    other = calibrate.make_report(
        search={"strength": 0.004, "stopped": False, "rate": 0.15},
        effects=effects_with(960, 1000),
        even_earns=pairs_with([0] * 5),
        constant_earns={"long": counted(0), "short": counted(0)},
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


def trials(lines: list[str], visited: list[float]) -> list[tuple[float, str]]:
    """The (strength, market) of each log line. A line names its market; strengths are searched one after another,
    so a market's k-th line is its trial at the k-th strength visited."""
    seen: dict[str, int] = {}
    found: list[tuple[float, str]] = []
    for line in lines:
        [market] = [market_id for market_id in SMALL if f'"{market_id}"' in line]
        found.append((visited[seen.get(market, 0)], market))
        seen[market] = seen.get(market, 0) + 1
    return found


@LAW
@given(any_rate, st.data())
def test_l5_3_and_l5_4_lines_merged_from_any_hosts_in_any_order_resume_to_the_same_report(
    stub: Rate, data: st.DataObject
) -> None:
    """Hosts that share out a strength's markets each append their lines, so a merged log holds every line of the
    strengths already searched and any subset of the current one's, in any order. Resumed from it, the run gives the
    clean run's report and evaluates exactly the trials whose lines are missing."""
    clean_stub = Rate(stub.slope, stub.wiggle, stub.freq)
    clean_log = fresh_log()
    clean = run(clean_stub, SMALL, clean_log)
    visited = visited_in_order(clean_stub.calls)
    lines = clean_log.read_text().splitlines()
    of_line = dict(zip(lines, trials(lines, visited)))
    assert sorted(of_line.values()) == sorted(clean_stub.calls)
    current = visited[data.draw(st.integers(0, len(visited) - 1))]
    searched = [line for line in lines if visited.index(of_line[line][0]) < visited.index(current)]
    open_lines = [line for line in lines if of_line[line][0] == current]
    done = data.draw(st.lists(st.sampled_from(open_lines), unique=True))
    merged = searched + done
    data.draw(st.randoms(use_true_random=False)).shuffle(merged)
    log = fresh_log()
    log.write_text("".join(line + "\n" for line in merged))
    resumed_stub = Rate(stub.slope, stub.wiggle, stub.freq)
    resumed = run(resumed_stub, SMALL, log)
    assert verdict(resumed) == verdict(clean)
    kept = {of_line[line] for line in merged}
    assert sorted(resumed_stub.calls) == sorted(set(clean_stub.calls) - kept)


@given(st.integers(0, 1000))
def test_l5_5_wall_2_passes_exactly_when_the_count_is_at_least_95_percent(count: int) -> None:
    report = calibrate.wall_2(effects_with(count, 1000))
    assert report["count"] == count
    assert (report["status"] == "pass") is (count >= 950)


@given(st.lists(st.integers(0, BLIND), min_size=5, max_size=5))
def test_l5_5_wall_3_passes_exactly_when_every_pairs_count_is_at_most_the_allowance(counts: list[int]) -> None:
    report = calibrate.wall_3(pairs_with(counts))
    assert report["counts"] == dict(zip(PAIR_NAMES, counts))
    assert (report["status"] == "pass") is all(c <= EVEN_ALLOWED for c in counts)


@given(st.integers(0, BLIND), st.integers(0, BLIND))
def test_l5_5_wall_5_passes_exactly_when_both_counts_are_at_most_the_allowance(long: int, short: int) -> None:
    report = calibrate.wall_5({"long": counted(long), "short": counted(short)})
    assert report["counts"] == {"long": long, "short": short}
    assert (report["status"] == "pass") is (max(long, short) <= constants.CONSTANT_ALLOWED)


@given(st.integers(0, 1000))
def test_l5_5_wall_4_passes_exactly_when_the_check_rate_is_inside_the_band(count: int) -> None:
    n = 1000
    assume(round(BAND[0] * n) != count != round(BAND[1] * n))
    report = calibrate.wall_4(0.004, [True] * count + [False] * (n - count))
    assert report["count"] == count
    assert (report["status"] == "pass") is (BAND[0] * n < count < BAND[1] * n)


CORE_WEIGHTS = st.lists(st.integers(1, 8), min_size=1, max_size=6)
CHECK = [f"control-1-cal-b-{i:04d}" for i in range(200)]
BLIND_IDS = [f"control-1-blind-{i:03d}" for i in range(12)]
Trial = tuple[str, float, str]
Record = dict[str, Any]


@LAW
@given(st.lists(st.text(min_size=1, max_size=20), unique=True, max_size=100), CORE_WEIGHTS)
def test_l5_6_shares_are_disjoint_contiguous_and_cover_every_id(ids: list[str], weights: list[int]) -> None:
    shares = calibrate.shares(ids, weights)
    assert len(shares) == len(weights)
    assert [market for share in shares for market in share] == ids
    for host, share in enumerate(shares):
        assert all(not set(share) & set(other) for other in shares[:host])


@LAW
@given(CORE_WEIGHTS, st.integers(1, 4))
def test_l5_6_integral_share_lengths_are_proportional_to_the_hosts_cores(weights: list[int], multiple: int) -> None:
    ids = [str(i) for i in range(sum(weights) * multiple)]
    assert [len(share) for share in calibrate.shares(ids, weights)] == [weight * multiple for weight in weights]


def small_search_ids() -> list[str]:
    return list(SMALL)


def small_check_ids() -> list[str]:
    return list(CHECK)


def small_blind_ids() -> list[str]:
    return list(BLIND_IDS)


def small_batch(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(calibrate, "cal_a_ids", small_search_ids)
    monkeypatch.setattr(calibrate, "cal_b_ids", small_check_ids)
    monkeypatch.setattr(calibrate, "blind_ids", small_blind_ids)


def trial_result(earns: bool) -> Record:
    won = 39 if earns else 38
    return {
        "earns": earns,
        "pairs_won": won,
        "reference_effects": [1.0] * PAIRS,
        "pick_effects": [0.5] * won + [0.25] * (PAIRS - won),
    }


class Batch:
    def __init__(self, rate: Rate, hosts: int = 1) -> None:
        self.rate = rate
        self.calls: list[Trial] = []
        self.samples = [(0.01, trial_result(True)) for _ in range(hosts)]
        self.changed: Trial | None = None
        self.changed_field = "reference_effects"

    def probes(self) -> list[tuple[float, Record]]:
        assert self.calls == []
        return copy.deepcopy(self.samples)

    def result(self, key: Trial, result: Record) -> Record:
        if key == self.changed:
            field = self.changed_field
            value = result[field]
            if isinstance(value, list):
                value[-1] = math.nextafter(value[-1], math.inf)
            elif isinstance(value, dict):
                name = next(iter(value))
                value[name] = not value[name]
            elif field == "earns":
                result = trial_result(not value)
            else:
                won = value + 1 if result["earns"] else value - 1
                result["pairs_won"] = won
                result["pick_effects"] = [0.5] * won + [0.25] * (PAIRS - won)
        return result

    def trial(self, strength: float, market_id: str, work: Path) -> Record:
        kind = "search" if market_id in SMALL else "check"
        key = (kind, strength, market_id)
        self.calls.append(key)
        earns = uniform(market_id) < self.rate.rate(strength) if kind == "search" else market_id in CHECK[:30]
        return self.result(key, trial_result(earns))

    def blind(self, strength: float, market_id: str, work: Path) -> Record:
        key = ("blind", strength, market_id)
        self.calls.append(key)
        return self.result(
            key,
            {
                "even_earns": dict.fromkeys(PAIR_NAMES, False),
                "constant_earns": {"long": False, "short": False},
                "mirror_earns": {"long": False, "short": False, "momentum": int(market_id[-3:]) % 2 == 0},
            },
        )


def batch(stub: Batch, out: Path, weights: list[int], share: int | None = None) -> None:
    out.mkdir(parents=True, exist_ok=True)
    argv = ["--weights", ",".join(map(str, weights))]
    if share is not None:
        argv += ["--share", str(share)]
    calibrate.main(argv, out=out, work=out / "work", trial=stub.trial, blind=stub.blind, probes=stub.probes)


def batch_lines(out: Path, name: str = "calibration.jsonl") -> list[str]:
    path = out / name
    return path.read_text().splitlines() if path.exists() else []


def put_lines(out: Path, lines: list[str]) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "calibration.jsonl").write_text("".join(line + "\n" for line in lines))


def batch_report(out: Path) -> Record:
    result: Record = json.loads((out / "calibration.json").read_text())
    return result


@pytest.mark.parametrize("crosses_target", [False, True])
@LAW
@given(any_rate, CORE_WEIGHTS, st.data())
def test_l5_6_each_host_stops_at_the_first_incomplete_set_and_rounds_give_the_one_host_report(
    crosses_target: bool, rate: Rate, weights: list[int], data: st.DataObject
) -> None:
    if crosses_target:
        rate = Rate(0.3)
    with pytest.MonkeyPatch.context() as patch:
        small_batch(patch)
        root = fresh_log().parent
        clean_stub = Batch(rate)
        batch(clean_stub, root / "clean", [1])
        clean_lines = batch_lines(root / "clean")
        assert len(clean_lines) == len(clean_stub.calls)
        of_trial = dict(zip(clean_stub.calls, clean_lines))
        stages = list(dict.fromkeys((kind, strength) for kind, strength, _ in clean_stub.calls))
        merged: list[str] = []
        evaluated: list[Trial] = []
        for round_number, stage in enumerate(stages):
            current = [key for key in clean_stub.calls if key[:2] == stage]
            done = data.draw(st.lists(st.sampled_from(current), unique=True, max_size=len(current) - 1))
            merged += [of_trial[key] for key in done]
            evaluated += done
            outputs: list[str] = []
            shares = calibrate.shares([key[2] for key in current], weights)
            for host, assigned in enumerate(shares):
                out = root / f"round-{round_number}-host-{host}"
                put_lines(out, merged)
                before = (out / "calibration.jsonl").read_bytes()
                stub = Batch(rate, len(weights))
                batch(stub, out, weights, host)
                expected = [key for key in current if key[2] in assigned and key not in done]
                assert sorted(stub.calls) == sorted(expected)
                assert (out / "calibration.jsonl").read_bytes() == before
                assert not (out / "calibration.json").exists()
                lines = batch_lines(out, f"share-{host}.jsonl")
                assert len(lines) == len(expected)
                assert sorted(json.dumps(json.loads(line), sort_keys=True) for line in lines) == sorted(
                    json.dumps(json.loads(of_trial[key]), sort_keys=True) for key in expected
                )
                outputs += lines
                evaluated += stub.calls
            merged += outputs
            data.draw(st.randoms(use_true_random=True)).shuffle(merged)
        assert sorted(evaluated) == sorted(clean_stub.calls)
        out = root / "decision"
        put_lines(out, merged)
        for host in range(len(weights)):
            finished = Batch(rate, len(weights))
            batch(finished, out, weights, host)
            assert finished.calls == []
            assert not (out / "calibration.json").exists()
        deciding = Batch(rate, len(weights))
        batch(deciding, out, weights)
        assert deciding.calls == []
        assert batch_report(out) == batch_report(root / "clean")


@LAW
@given(any_rate, CORE_WEIGHTS, st.data())
def test_l5_6_repeated_equal_trial_lines_count_once_and_change_no_report(
    rate: Rate, weights: list[int], data: st.DataObject
) -> None:
    with pytest.MonkeyPatch.context() as patch:
        small_batch(patch)
        root = fresh_log().parent
        batch(Batch(rate), root / "clean", [1])
        lines = batch_lines(root / "clean")
        repeated = lines + data.draw(st.lists(st.sampled_from(lines), min_size=1, max_size=100))
        data.draw(st.randoms(use_true_random=False)).shuffle(repeated)
        put_lines(root / "repeated", repeated)
        stub = Batch(rate, len(weights))
        batch(stub, root / "repeated", weights)
        assert stub.calls == []
        assert batch_report(root / "repeated") == batch_report(root / "clean")


@LAW
@given(any_rate, CORE_WEIGHTS, st.data())
def test_l5_6_two_lines_of_one_trial_with_differing_results_give_no_report_including_effect_only_changes(
    rate: Rate, weights: list[int], data: st.DataObject
) -> None:
    with pytest.MonkeyPatch.context() as patch:
        small_batch(patch)
        root = fresh_log().parent
        clean = Batch(rate)
        batch(clean, root / "clean", [1])
        changed = data.draw(st.sampled_from(clean.calls))
        other = Batch(rate)
        other.changed = changed
        fields = (
            ["even_earns", "constant_earns", "mirror_earns"]
            if changed[0] == "blind"
            else ["earns", "pairs_won", "reference_effects", "pick_effects"]
        )
        other.changed_field = data.draw(st.sampled_from(fields))
        batch(other, root / "other", [1])
        alternate = dict(zip(other.calls, batch_lines(root / "other")))[changed]
        original = dict(zip(clean.calls, batch_lines(root / "clean")))[changed]
        assert json.loads(alternate) != json.loads(original)
        lines = batch_lines(root / "clean") + [alternate]
        data.draw(st.randoms(use_true_random=False)).shuffle(lines)
        out = root / "conflict"
        put_lines(out, lines)
        stub = Batch(rate, len(weights))
        with pytest.raises((RuntimeError, SystemExit)) as stopped:
            batch(stub, out, weights)
        if isinstance(stopped.value, SystemExit):
            assert stopped.value.code not in (None, 0)
        assert stub.calls == []
        assert not (out / "calibration.json").exists()


@pytest.mark.parametrize("field", ["earns", "pairs_won", "reference_effects", "pick_effects"])
@pytest.mark.parametrize("share", [None, 0, 1])
def test_host_probes_compare_the_whole_result_before_any_search_trial(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, field: str, share: int | None
) -> None:
    small_batch(monkeypatch)
    stub = Batch(Rate(0.3), 2)
    result = stub.samples[1][1]
    if field.endswith("effects"):
        result[field][-1] = math.nextafter(result[field][-1], math.inf)
    elif field == "earns":
        result[field] = False
    else:
        result[field] -= 1
    with pytest.raises((RuntimeError, SystemExit)) as stopped:
        batch(stub, tmp_path, [1, 3], share)
    if isinstance(stopped.value, SystemExit):
        assert stopped.value.code not in (None, 0)
    assert stub.calls == []
    assert batch_lines(tmp_path) == []
    assert not (tmp_path / "calibration.json").exists()


@pytest.mark.parametrize(("seconds", "weights"), [([1.0, 1000.0], [1, 100]), ([1000.0, 100.0], [100, 1])])
def test_equal_host_probes_allow_differing_times_and_print_the_projection_by_the_sum_of_core_rates(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    seconds: list[float],
    weights: list[int],
) -> None:
    small_batch(monkeypatch)
    stub = Batch(Rate(0.3), 2)
    stub.samples = [(seconds[host], result) for host, (_, result) in enumerate(stub.samples)]
    throughput = sum(cores / elapsed for cores, elapsed in zip(weights, seconds))
    batch(stub, tmp_path, weights)
    assert stub.calls
    assert batch_report(tmp_path)["strength"] is not None
    printed = float(re.search(r"projected ([0-9.]+) h", capsys.readouterr().out).group(1))  # type: ignore[union-attr]
    assert MARKETS / throughput / 3600 - 0.05 <= printed <= (MARKETS + 1000) / throughput / 3600 + 0.05


def test_a_projection_far_above_a_day_stops_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    small_batch(monkeypatch)
    stub = Batch(Rate(0.3), 2)
    stub.samples = [(10.0**6, result) for _, result in stub.samples]
    batch(stub, tmp_path, [1, 3])
    assert stub.calls
    assert batch_report(tmp_path)["strength"] is not None
