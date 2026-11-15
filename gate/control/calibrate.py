"""Calibration and the model-free walls (step 5), laws L5.1 to L5.6.

`python -m gate.control.calibrate --weights w0,w1,...` finds the strength at which G100 earns from the plant at
TARGET, checks it on fresh markets, and judges walls 2 to 5 (audit/program/briefs/1-positive-control.md, step 5).
Every trial's result is one JSON line in `calibration.jsonl`, so a stopped run resumes without recomputing. With
`--share k` the run evaluates only host k's share of the first set of trials the log lacks, appends it to
`share-k.jsonl` and decides nothing; the hosts' lines are merged into the log in any order."""

import argparse
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


def g100_trial(strength: float, market_id: str, work: Path, manifest_seed: str = MANIFEST_SEED) -> Result:
    """G100 on the market at `strength`: whether its pick earns from the plant, the pairs it wins, and the
    effect of the reference and of the pick on each fresh pair. `work` is scratch, removed on return."""
    work.mkdir(parents=True, exist_ok=True)
    try:
        market = pairs.write_market(work, market_id, strength)
        ledger = work / "ledger.sqlite"
        search.run(SEARCHER, market, ledger, CAMPAIGN, g100_seed(manifest_seed, market_id))
        chosen = pick(ledger, CAMPAIGN, SEARCHER)
        shutil.rmtree(market)
        programs = [load_program("reference")] + ([chosen] if chosen is not None else [])
        reference_scores, *picked = fresh_scores(strength, market_id, programs, work)
        wins, earns = classify(picked[0], reference_scores) if picked else (0, False)
        pick_effects = [effect(p) for p in picked[0]] if picked else [None] * constants.PAIRS
        return {
            "earns": earns,
            "pairs_won": wins,
            "reference_effects": [effect(p) for p in reference_scores],
            "pick_effects": pick_effects,
        }
    finally:
        shutil.rmtree(work, ignore_errors=True)


def g100_earns(strength: float, market_id: str, work: Path, manifest_seed: str = MANIFEST_SEED) -> bool:
    return bool(g100_trial(strength, market_id, work, manifest_seed)["earns"])


def blind_trial(strength: float, market_id: str, work: Path) -> Result:
    """The reference and the mirror set on the market's fresh pairs: whether each mirror pair's even part earns,
    each constant position as a pick, and each mirror program. `work` is scratch, removed on return."""
    work.mkdir(parents=True, exist_ok=True)
    try:
        programs = [load_program(name) for name in ["reference", *MIRROR_NAMES]]
        reference, *rest = fresh_scores(strength, market_id, programs, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    mine = dict(zip(MIRROR_NAMES, rest))
    mirror_earns = {name: classify(mine[name], reference)[1] for name in MIRROR_NAMES}
    return {
        "even_earns": {name: classify(even(mine[a], mine[b]), reference)[1] for name, (a, b) in MIRROR_PAIRS.items()},
        "constant_earns": {name: mirror_earns[name] for name in CONSTANTS},
        "mirror_earns": mirror_earns,
    }


def work_in(work: Path, strength: float, market_id: str) -> Path:
    return work / f"{strength!r}-{pairs.stem(market_id)}"


def in_own_dir(trial: Callable[[float, str, Path], Result], work: Path, strength: float, market_id: str) -> Result:
    return trial(strength, market_id, work_in(work, strength, market_id))


def scan(log: Path) -> tuple[list[dict[str, Any]], int]:
    """The complete lines of the log, parsed, and their bytes; a final line cut short by a kill is not one."""
    rows: list[dict[str, Any]] = []
    good = 0
    for line in log.read_bytes().splitlines(keepends=True):
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            break
        good += len(line)
    return rows, good


def parse(logs: Sequence[Path]) -> Log:
    """Every trial in the logs. Two lines of one trial count once if their results are equal; if they differ, a
    trial was not a function of its market and strength, and there is no report."""
    cached: Log = {}
    for log in logs:
        rows = scan(log)[0] if log.exists() else []
        for row in rows:
            key = (float(row["strength"]), row["market"])
            if key in cached and cached[key] != row["result"]:
                raise RuntimeError(f"two different results for the trial {key}")
            cached[key] = row["result"]
    return cached


def load_log(log: Path) -> Log:
    """Every trial in the log, after a final line cut short by a kill is dropped from the file."""
    if log.exists():
        with log.open("r+b") as handle:
            handle.truncate(scan(log)[1])
    return parse([log])


def evaluate(
    trial: Callable[[float, str], Result],
    strength: float,
    ids: Sequence[str],
    known: Log,
    log: Path,
    workers: int,
) -> None:
    """The trial on each of `ids` at `strength` that `known` lacks. Each result is appended to `log` as it finishes
    and added to `known`."""
    missing = [i for i in ids if (strength, i) not in known]
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("a") as handle:

        def record(market_id: str, result: Result) -> None:
            known[(strength, market_id)] = result
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


def run_markets(
    trial: Callable[[float, str], Result], strength: float, ids: Sequence[str], log: Path, workers: int
) -> list[Result]:
    """The trial's result on each id at `strength`, in order. A result already in the log is not recomputed."""
    known = load_log(log)
    evaluate(trial, strength, ids, known, log, workers)
    return [known[(strength, i)] for i in ids]


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


def bracket(rate: Callable[[float], Fraction]) -> dict[str, Any]:
    """The bracket search of step 5 over a rate function. Returns the strength (None when the search found none),
    `stopped`, and the strength's rate."""

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


def find_strength(
    earns: Callable[[float, str], bool], ids: Sequence[str], log: Path, workers: int = 1
) -> dict[str, Any]:
    return bracket(lambda strength: rate_of(run_markets(earns, strength, ids, log, workers)))


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
    markets: int = STRENGTHS * constants.SEARCH_MARKETS + constants.CHECK_MARKETS + BLIND_MARKETS_EQUIVALENT
    return markets * seconds_per_market / cores


def timed_trial(work: Path) -> tuple[float, Result]:
    """The seconds one whole cal-a market takes at the bracket's upper end, with everything a market costs
    (generating and writing it and its pairs, each evaluator's start, G100's evaluations and the classification),
    and the trial's whole result."""
    started = time.perf_counter()
    result = g100_trial(HI, cal_a_ids()[0], work)
    return time.perf_counter() - started, result


def timed_market() -> float:
    with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as scratch:
        return timed_trial(Path(scratch) / "market")[0]


class Incomplete(Exception):
    """The log lacks some trial of a set of markets at `strength`."""

    def __init__(self, strength: float) -> None:
        super().__init__(strength)
        self.strength = strength


def rate_in(known: Log, strength: float) -> Fraction:
    """G100's rate at `strength` on the search's markets, from the log alone."""
    results = [known.get((strength, market_id)) for market_id in cal_a_ids()]
    if any(result is None for result in results):
        raise Incomplete(strength)
    return rate_of([result["earns"] for result in results if result is not None])


def next_set(known: Log) -> tuple[float, list[str], str] | None:
    """The first set of markets, in the order of the job, that the log does not wholly hold: the strength, the ids
    and which trial (`trial` or `blind`) evaluates them. None when the log holds the whole job."""
    try:
        found = bracket(partial(rate_in, known))
    except Incomplete as stop:
        return stop.strength, cal_a_ids(), "trial"
    strength = found["strength"]
    if strength is None:
        return None
    for ids, which in ((cal_b_ids(), "trial"), (blind_ids(), "blind")):
        if any((strength, market_id) not in known for market_id in ids):
            return strength, ids, which
    return None


def shares(ids: Sequence[str], weights: Sequence[int]) -> list[list[str]]:
    """One contiguous run of the ordered ids a host, in proportion to the weights (the hosts' cores)."""
    total = sum(weights)
    edges = [len(ids) * sum(weights[:k]) // total for k in range(len(weights) + 1)]
    return [list(ids[edges[k] : edges[k + 1]]) for k in range(len(weights))]


def check_probes(probes: Sequence[tuple[float, Result]]) -> None:
    """The hosts' timed trials must be equal in every field: `generate` is numpy, whose transcendental functions
    are chosen by CPU and may differ in the last bit between hosts."""
    first = probes[0][1]
    if any(result != first for _, result in probes):
        raise RuntimeError("wall: the hosts' timed trials differ")


def file_probes(out: Path, hosts: int) -> list[tuple[float, Result]]:
    rows = [json.loads((out / f"probe-{k}.json").read_text()) for k in range(hosts)]
    return [(row["seconds"], row["result"]) for row in rows]


def effective_seconds(weights: Sequence[int], seconds: Sequence[float]) -> float:
    """Seconds a market takes on one core, as if the hosts were one machine of the sum of their rates."""
    return 1 / sum(cores / elapsed for cores, elapsed in zip(weights, seconds))


def mirror_rates(blinds: Sequence[Result]) -> dict[str, float]:
    names = list(blinds[0]["mirror_earns"]) if blinds else []
    return {name: sum(b["mirror_earns"][name] for b in blinds) / len(blinds) for name in names}


def decide(known: Log, strength: float | None, found: dict[str, Any]) -> dict[str, Any]:
    checks = [known[(strength, i)] for i in cal_b_ids()] if strength is not None else []
    blinds = [known[(strength, i)] for i in blind_ids()] if strength is not None else []
    return make_report(
        search=found,
        effects=[e for c in checks for e in c["reference_effects"]],
        even_earns={name: [b["even_earns"][name] for b in blinds] for name in MIRROR_PAIRS},
        constant_earns={name: [b["constant_earns"][name] for b in blinds] for name in CONSTANTS},
        check_earns=[bool(c["earns"]) for c in checks],
        mirror_rates=mirror_rates(blinds),
        pick_wins=[c["pairs_won"] for c in checks],
    )


def parser() -> argparse.ArgumentParser:
    arguments = argparse.ArgumentParser(prog="python -m gate.control.calibrate")
    arguments.add_argument("--weights", required=True, help="the hosts' cores, comma separated, in host order")
    arguments.add_argument("--share", type=int, help="run only this host's share and decide nothing")
    arguments.add_argument("--probe", action="store_true", help="time this host's market and write probe-k.json")
    return arguments


def main(
    argv: Sequence[str],
    *,
    out: Path,
    work: Path,
    trial: Callable[[float, str, Path], Result],
    blind: Callable[[float, str, Path], Result],
    probes: Callable[[], Sequence[tuple[float, Result]]],
    workers: int = 1,
) -> int:
    args = parser().parse_args(argv)
    weights = [int(w) for w in args.weights.split(",")]
    timed = probes()
    check_probes(timed)
    each = effective_seconds(weights, [seconds for seconds, _ in timed])
    print(f"{each:.1f} s a market on one core of the hosts together: projected {projected_seconds(each) / 3600:.1f} h")
    merged = out / "calibration.jsonl"
    own = merged if args.share is None else out / f"share-{args.share}.jsonl"
    if own.exists():
        with own.open("r+b") as handle:
            handle.truncate(scan(own)[1])
    known = parse([merged, own])
    evaluators = {"trial": trial, "blind": blind}

    def run_stage(stage: tuple[float, list[str], str]) -> None:
        strength, ids, which = stage
        todo = ids if args.share is None else shares(ids, weights)[args.share]
        evaluate(partial(in_own_dir, evaluators[which], work), strength, todo, known, own, workers)

    if args.share is not None:
        stage = next_set(known)
        if stage is not None:
            run_stage(stage)
        return 0
    while (stage := next_set(known)) is not None:
        run_stage(stage)
    found = bracket(partial(rate_in, known))
    result = decide(known, found["strength"], found)
    (out / "calibration.json").write_text(json.dumps(result, indent=2) + "\n")
    stopped = [k for k, wall in result["walls"].items() if wall["status"] == "stop"]
    print(f"walls stopped: {stopped}" if stopped else "all walls pass")
    return 1 if stopped else 0


def cli(argv: Sequence[str]) -> int:
    args = parser().parse_args(argv)
    cores = os.cpu_count() or 1
    scratch = Path(tempfile.mkdtemp(prefix="calibration-", dir=os.environ.get("TMPDIR")))
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        if args.probe:
            seconds, result = timed_trial(scratch / "market")
            (OUT / f"probe-{args.share}.json").write_text(json.dumps({"seconds": seconds, "result": result}))
            return 0
        probes = partial(file_probes, OUT, len(args.weights.split(",")))
        return main(argv, out=OUT, work=scratch, trial=g100_trial, blind=blind_trial, probes=probes, workers=cores)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(cli(sys.argv[1:]))
