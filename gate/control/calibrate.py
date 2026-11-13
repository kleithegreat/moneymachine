"""Calibration and the model-free walls (step 5).

`python -m gate.control.calibrate` finds the strength at which G100 earns from the plant at TARGET, checks it on fresh
markets, and judges walls 2 to 5 (audit/program/briefs/1-positive-control.md, step 5). Every market's result is
one JSON line in a log, so a stopped run resumes without recomputing."""

import hashlib
import json
import math
import os
import shutil
import sys
import tempfile
import time
from collections.abc import Callable, Mapping, Sequence
from concurrent.futures import ProcessPoolExecutor, as_completed
from fractions import Fraction
from functools import partial
from pathlib import Path
from typing import Any

from gate import search
from gate.control import constants, pairs
from gate.control.judge import fresh_scores, load_program
from gate.control.measure import classify, effect, even, finite
from gate.control.pick import pick

HI = 0.01
SECONDS_LIMIT = 24 * 3600
MIRROR_PAIRS = {
    "constant": ("long", "short"),
    "trend": ("momentum", "reversal"),
    "random_low": ("random_low", "random_low_neg"),
    "random_mid": ("random_mid", "random_mid_neg"),
    "random_high": ("random_high", "random_high_neg"),
}
MIRROR_NAMES = [name for pair in MIRROR_PAIRS.values() for name in pair]
CONSTANTS = ("long", "short")
OUT = Path(__file__).resolve().parents[2] / "audit" / "control-1"
MANIFEST_SEED = "control-1"
CAMPAIGN = "calibration"
SEARCHER = "G100"
G100_EVALUATIONS = 100
EVALUATIONS_A_MARKET = G100_EVALUATIONS + 2 * 2 * constants.PAIRS
BLIND_EVALUATIONS = constants.BLIND_MARKETS * (1 + len(MIRROR_NAMES)) * 2 * constants.PAIRS
BLIND_MARKETS_EQUIVALENT = math.ceil(BLIND_EVALUATIONS / EVALUATIONS_A_MARKET)
STRENGTHS = constants.MAX_STEPS + 1

Result = Any
Log = dict[tuple[float, str], Result]


def cal_a_ids() -> list[str]:
    return [f"control-1-cal-a-{i:04d}" for i in range(constants.SEARCH_MARKETS)]


def cal_b_ids() -> list[str]:
    return [f"control-1-cal-b-{i:04d}" for i in range(constants.CHECK_MARKETS)]


def blind_ids() -> list[str]:
    return [f"control-1-blind-{i:03d}" for i in range(constants.BLIND_MARKETS)]


def g100_seed(manifest_seed: str, market_id: str) -> int:
    digest = hashlib.sha256(f"{manifest_seed}:{market_id}:G100".encode()).digest()
    return int.from_bytes(digest[:8], "big")


def g100_trial(
    strength: float, market_id: str, work: Path, manifest_seed: str = MANIFEST_SEED, twins: Path | None = None
) -> Result:
    """G100 on the market at `strength`: whether its pick earns from the plant, the pairs it wins, and the
    reference's effect on each fresh pair. `work` is scratch, removed on return; the twins go to `twins`, which
    defaults to a directory of `work`."""
    work.mkdir(parents=True, exist_ok=True)
    try:
        market = pairs.write_market(work, market_id, strength)
        ledger = work / "ledger.sqlite"
        search.run(SEARCHER, market, ledger, CAMPAIGN, g100_seed(manifest_seed, market_id))
        chosen = pick(ledger, CAMPAIGN, SEARCHER)
        shutil.rmtree(market)
        programs = [load_program("reference")] + ([chosen] if chosen is not None else [])
        reference_scores, *picked = fresh_scores(strength, market_id, programs, work, twins or work / "twins")
        wins, earns = classify(picked[0], reference_scores) if picked else (0, False)
        return {"earns": earns, "wins": wins, "effects": [effect(p) for p in reference_scores]}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def g100_earns(strength: float, market_id: str, work: Path, manifest_seed: str = MANIFEST_SEED) -> bool:
    return bool(g100_trial(strength, market_id, work, manifest_seed)["earns"])


def blind_trial(strength: float, market_id: str, work: Path) -> Result:
    """The reference and the mirror set on the market's fresh pairs: whether each mirror pair's even part earns,
    and each mirror program. `work` is scratch, removed on return."""
    work.mkdir(parents=True, exist_ok=True)
    try:
        programs = [load_program(name) for name in ["reference", *MIRROR_NAMES]]
        reference, *rest = fresh_scores(strength, market_id, programs, work, work / "twins")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    mine = dict(zip(MIRROR_NAMES, rest))
    return {
        "even": {name: classify(even(mine[a], mine[b]), reference)[1] for name, (a, b) in MIRROR_PAIRS.items()},
        "programs": {name: classify(mine[name], reference)[1] for name in MIRROR_NAMES},
    }


def work_in(scratch: Path, label: str, strength: float, market_id: str) -> Path:
    return scratch / f"{label}-{strength!r}-{pairs.stem(market_id)}"


def g100_in(scratch: Path, strength: float, market_id: str) -> Result:
    return g100_trial(strength, market_id, work_in(scratch, "g100", strength, market_id), twins=scratch / "twins")


def g100_earns_in(scratch: Path, strength: float, market_id: str) -> bool:
    return bool(g100_in(scratch, strength, market_id)["earns"])


def blind_in(scratch: Path, strength: float, market_id: str) -> Result:
    return blind_trial(strength, market_id, work_in(scratch, "blind", strength, market_id))


def load_log(log: Path) -> Log:
    """Every complete line of the log; a final line cut short by a kill is dropped from the file."""
    cached: Log = {}
    if not log.exists():
        return cached
    good = 0
    for line in log.read_bytes().splitlines(keepends=True):
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            break
        cached[(float(row["strength"]), row["market"])] = row["result"]
        good += len(line)
    with log.open("r+b") as handle:
        handle.truncate(good)
    return cached


def run_markets(
    trial: Callable[[float, str], Result], strength: float, ids: Sequence[str], log: Path, workers: int
) -> list[Result]:
    """The trial's result on each id at `strength`, in order. A result already in the log is not recomputed, and
    each new one is appended to the log as it finishes."""
    cached = load_log(log)
    missing = [i for i in ids if (strength, i) not in cached]
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("a") as handle:

        def record(market_id: str, result: Result) -> None:
            cached[(strength, market_id)] = result
            handle.write(json.dumps({"strength": strength, "market": market_id, "result": result}) + "\n")
            handle.flush()

        if workers <= 1:
            for market_id in missing:
                record(market_id, trial(strength, market_id))
        else:
            with ProcessPoolExecutor(max_workers=workers) as pool:
                futures = {pool.submit(trial, strength, i): i for i in missing}
                try:
                    for future in as_completed(futures):
                        record(futures[future], future.result())
                except BaseException:
                    pool.shutdown(wait=False, cancel_futures=True)
                    raise
    return [cached[(strength, i)] for i in ids]


def rate_of(results: Sequence[Result]) -> Fraction:
    return Fraction(sum(bool(r) for r in results), len(results))


def rate_at(
    earns: Callable[[float, str], bool], strength: float, ids: Sequence[str], log: Path, workers: int = 1
) -> float:
    """G100's rate at `strength`: the share of `ids` on which its pick earns."""
    return float(rate_of(run_markets(earns, strength, ids, log, workers)))


def verdict(rate: Fraction) -> str:
    target = Fraction(str(constants.TARGET))
    if abs(rate - target) <= Fraction(str(constants.TOLERANCE)):
        return "inside"
    return "above" if rate > target else "below"


def find_strength(
    earns: Callable[[float, str], bool], ids: Sequence[str], log: Path, workers: int = 1
) -> dict[str, Any]:
    """The bracket search of step 5. Returns the strength (None when the search found none), `stopped`, and the
    strength's rate on `ids`."""

    def rate(strength: float) -> Fraction:
        return rate_of(run_markets(earns, strength, ids, log, workers))

    def found(strength: float, at: Fraction) -> dict[str, Any]:
        return {"strength": strength, "stopped": False, "rate": float(at)}

    top = rate(HI)
    first = verdict(top)
    if first == "inside":
        return found(HI, top)
    if first == "below":
        return {"strength": None, "stopped": True, "rate": None}
    low, high = 0.0, HI
    for _ in range(constants.MAX_STEPS):
        middle = (low + high) / 2
        at = rate(middle)
        side = verdict(at)
        if side == "inside":
            return found(middle, at)
        if side == "above":
            high = middle
        else:
            low = middle
    return {"strength": None, "stopped": True, "rate": None}


def report(count: int, denominator: int, passed: bool) -> dict[str, Any]:
    return {"count": count, "denominator": denominator, "status": "pass" if passed else "stop"}


def wall_2(effects: Sequence[float | None]) -> dict[str, Any]:
    """The reference's effect is positive on at least 95% of the pairs."""
    positive = sum(e is not None and finite(e) and e > 0 for e in effects)
    return report(positive, len(effects), len(effects) > 0 and 20 * positive >= 19 * len(effects))


def each_at_most(earns: Mapping[str, Sequence[bool]], allowed: int) -> dict[str, Any]:
    counts = {name: sum(flags) for name, flags in earns.items()}
    denominator = len(next(iter(earns.values())))
    largest = max(counts.values())
    return {**report(largest, denominator, largest <= allowed), "counts": counts}


def wall_3(earns: Mapping[str, Sequence[bool]]) -> dict[str, Any]:
    """Each mirror pair's even part earns on at most EVEN_ALLOWED markets."""
    return each_at_most(earns, constants.EVEN_ALLOWED)


def wall_5(earns: Mapping[str, Sequence[bool]]) -> dict[str, Any]:
    """Each constant position, classified as a pick, earns on at most CONSTANT_ALLOWED markets."""
    return each_at_most(earns, constants.CONSTANT_ALLOWED)


def wall_4(strength: float | None, earns: Sequence[bool]) -> dict[str, Any]:
    """The search found a strength and G100's rate on the check is inside BAND."""
    count = sum(earns)
    low, high = (Fraction(str(edge)) for edge in constants.BAND)
    inside = len(earns) > 0 and low <= Fraction(count, len(earns)) <= high
    return report(count, len(earns), strength is not None and inside)


def make_report(
    *,
    search: dict[str, Any],
    effects: Sequence[float | None],
    even_earns: Mapping[str, Sequence[bool]],
    constant_earns: Mapping[str, Sequence[bool]],
    check_earns: Sequence[bool],
    mirror_rates: dict[str, float],
    pick_wins: Sequence[int],
) -> dict[str, Any]:
    histogram = [0] * (constants.PAIRS + 1)
    for wins in pick_wins:
        histogram[wins] += 1
    return {
        "strength": search["strength"],
        "walls": {
            "2": wall_2(effects),
            "3": wall_3(even_earns),
            "4": wall_4(search["strength"], check_earns),
            "5": wall_5(constant_earns),
        },
        "mirror_rates": mirror_rates,
        "pick_histogram": histogram,
    }


def projected_seconds(seconds_per_market: float, cores: int = 1) -> float:
    """The job's time in whole markets: every strength on the search's markets, one on the check's, and wall 3's
    and wall 5's blind markets."""
    markets = STRENGTHS * constants.SEARCH_MARKETS + constants.CHECK_MARKETS + BLIND_MARKETS_EQUIVALENT
    return markets * seconds_per_market / cores


def projection_ok(seconds_per_market: float, cores: int) -> bool:
    return projected_seconds(seconds_per_market, cores) <= SECONDS_LIMIT


def timed_market() -> float:
    """Seconds one whole cal-a market takes at the bracket's upper end, with a cold twin cache: generating and
    writing it and its pairs, each evaluator's start, G100's evaluations and the classification."""
    with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as scratch:
        started = time.perf_counter()
        g100_trial(HI, cal_a_ids()[0], Path(scratch) / "market")
        return time.perf_counter() - started


def main() -> int:
    cores = os.cpu_count() or 1
    each = timed_market()
    print(f"{each:.1f} s a market on {cores} cores: projected {projected_seconds(each, cores) / 3600:.1f} h")
    if not projection_ok(each, cores):
        print("wall: the projection is above 24 hours")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix="calibration-", dir=os.environ.get("TMPDIR")))
    trial, earns, blind = (partial(f, scratch) for f in (g100_in, g100_earns_in, blind_in))
    checks: list[Result] = []
    blinds: list[Result] = []
    try:
        found = find_strength(earns, cal_a_ids(), OUT / "search.jsonl", cores)
        strength = found["strength"]
        if strength is not None:
            checks = run_markets(trial, strength, cal_b_ids(), OUT / "check.jsonl", cores)
            blinds = run_markets(blind, strength, blind_ids(), OUT / "blind.jsonl", cores)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    result = make_report(
        search=found,
        effects=[e for c in checks for e in c["effects"]],
        even_earns={name: [b["even"][name] for b in blinds] for name in MIRROR_PAIRS},
        constant_earns={name: [b["programs"][name] for b in blinds] for name in CONSTANTS},
        check_earns=[bool(c["earns"]) for c in checks],
        mirror_rates={n: sum(b["programs"][n] for b in blinds) / max(len(blinds), 1) for n in MIRROR_NAMES},
        pick_wins=[c["wins"] for c in checks],
    )
    (OUT / "calibration.json").write_text(json.dumps(result, indent=2) + "\n")
    stopped = [k for k, wall in result["walls"].items() if wall["status"] == "stop"]
    print(f"walls stopped: {stopped}" if stopped else "all walls pass")
    return 1 if stopped else 0


if __name__ == "__main__":
    sys.exit(main())
