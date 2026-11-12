"""Study 1, step 9: the report (gate/control/report.py), its behaviours and laws L9.1 to L9.3, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2 and 5.4. Written from the plan before
the code, by another model than the builder's. The input files are the ones the runner could have written, in the
format `test_runner.py` fixes, built here by `fakes.simulate` from random scripts of sessions.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `summary(out, *, verify, judge) -> dict` and `write(out, *, verify, judge) -> None`, the second writing
  `out/report.md`. Both call `verify()` first (the manifest: "markets", "strength", "seed", "model") and read
  `out`'s `calibration.json`, `searcher.jsonl`, `results.jsonl` and `voids.jsonl` (absent when no session was void).
  `judge(market_id, strength, ledger) -> judgement`, as the runner's, classifies a void session's pick from the
  ledger its void line names.
- The summary's keys:
  - "state": "claim", "futility" or "undecided" (the decision of the first market line that ends the study),
    "ended early" or "model changed" (a state line), "paused" (the last line, with no end before it), or "running";
  - "ended": true for the first four; "name": for those, architecture 5.4's name of the result, else None;
  - "markets": the market lines counted, which are those up to the end (all of them when nothing ended);
  - "wins", "losses", "concordant": the outcomes of the counted lines;
  - "agent" and "searcher": {"earned", "rate", "interval"}, over the counted lines (`agent_earns`,
    `searcher_earns`), the interval Clopper-Pearson's at 95%; rate and interval None when no line counts;
  - "beyond": the ids of market lines after the end, which enter no count above;
  - "voids": the number of void lines;
  - "void_rule": {"decision", "markets", "beyond"}: the decision when each counted market's first void session with a
    pick is judged on that pick in place of its rerun (revision 4's rule), taken at the shortest prefix that does not
    continue, else at the last counted market; "markets", that prefix's length; "beyond" when that last decision is
    "continue".
- `report.md` holds the name, each arm's earned count as "<earned>/<markets>", each rate and interval bound to three
  decimals, every counted and void market's id, and every model id in the lines; an unfinished study (paused, model
  changed, running) is said to have "not ended"."""

import importlib
import json
import shutil
import tempfile
from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest
from hypothesis import assume, given, settings
from hypothesis import strategies as st
from scipy import stats

from gate.control.sequential import decide, outcome
from gate.control.tests.fakes import (
    FOREIGN,
    IDS,
    PINNED,
    ends_study,
    is_market_line,
    judgement,
    manifest,
    searcher_line,
    simulate,
)

Record = dict[str, Any]
LAW = settings(max_examples=40, deadline=None)
SCRIPTED = ["earn"] * 4 + ["miss"] * 4 + ["nopick", "turns", "wall", "crash", "crash", "signal", "foreign"]
SUMMARY_KEYS = (
    "state",
    "ended",
    "name",
    "markets",
    "wins",
    "losses",
    "concordant",
    "agent",
    "searcher",
    "voids",
    "void_rule",
)
CLAIM = "The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do"
NAMES = {
    "claim": CLAIM,
    "futility": "Not shown",
    "undecided": "Inconclusive",
    "ended early": "Inconclusive at the markets judged",
}


def report() -> ModuleType:
    return importlib.import_module("gate.control.report")


def judge(market_id: str, strength: float, ledger: Path) -> Record:
    ledger = Path(ledger)
    if not ledger.exists():
        return judgement(-1, "nopick")
    content = json.loads(ledger.read_text())
    return judgement(content["session"], content["behaviour"])


def verify() -> Record:
    return manifest()


def history(
    g100: list[bool], script: list[str], cut: int | None = None, tail: str | None = None, beyond: int = 0
) -> tuple[list[Record], list[Record]]:
    """The runner's lines for a script, optionally cut after `cut` lines and given a last state line, or followed by
    `beyond` market lines past the end."""
    lines, voids, _ = simulate(g100, script)
    if cut is not None and cut < len(lines):
        lines = lines[:cut]
        if tail == "ended early":
            lines.append({"state": "ended early", "markets": sum(map(is_market_line, lines))})
        elif tail == "paused":
            nxt = sum(map(is_market_line, lines))
            lines.append({"state": "paused", "id": IDS[nxt]})
    if beyond and lines and is_market_line(lines[-1]) and ends_study(lines[-1]):
        last = sum(map(is_market_line, lines))
        for k in range(min(beyond, len(IDS) - last)):
            extra = dict(lines[-1])
            extra["id"] = IDS[last + k]
            extra["agent_earns"] = k % 2 == 0
            extra["searcher_earns"] = not g100[last + k]
            extra["outcome"] = outcome(extra["agent_earns"], extra["searcher_earns"])
            lines.append(extra)
    ids = {line.get("id") for line in lines}
    return lines, [v for v in voids if v["id"] in ids]


def lay_out(root: Path, g100: list[bool], script: list[str], lines: list[Record], voids: list[Record]) -> Path:
    out = root / "out"
    out.mkdir(parents=True)
    ledgers = root / "ledgers"
    ledgers.mkdir()
    void_lines = []
    for v in voids:
        session = v["session"]
        ledger = ledgers / f"void-{session}.json"
        if session % 3 != 0:
            behaviour = script[session] if session < len(script) else "miss"
            ledger.write_text(json.dumps({"session": session, "behaviour": behaviour}))
        void_lines.append({"id": v["id"], "run": v["run"], "evaluations": v["evaluations"], "ledger": str(ledger)})
    (out / "calibration.json").write_text(json.dumps({"strength": 0.004, "walls": {}}))
    (out / "searcher.jsonl").write_text("".join(json.dumps(searcher_line(i, e)) + "\n" for i, e in zip(IDS, g100)))
    (out / "results.jsonl").write_text("".join(json.dumps(line) + "\n" for line in lines))
    if void_lines:
        (out / "voids.jsonl").write_text("".join(json.dumps(v) + "\n" for v in void_lines))
    return out


def summarize(out: Path) -> Record:
    result: Record = report().summary(out, verify=verify, judge=judge)
    return result


def written(out: Path) -> str:
    report().write(out, verify=verify, judge=judge)
    return (out / "report.md").read_text()


def clopper_pearson(k: int, n: int) -> tuple[float, float]:
    low = 0.0 if k == 0 else float(stats.beta.ppf(0.025, k, n - k + 1))
    high = 1.0 if k == n else float(stats.beta.ppf(0.975, k + 1, n - k))
    return low, high


def recount(lines: list[Record], voids: list[Record]) -> Record:
    """The summary, computed here from the lines."""
    end = next((i for i, line in enumerate(lines) if ends_study(line)), None)
    before = lines if end is None else lines[: end + 1]
    counted = [line for line in before if is_market_line(line)]
    after = [] if end is None else [line["id"] for line in lines[end + 1 :] if is_market_line(line)]
    if end is not None:
        state = lines[end]["decision"] if is_market_line(lines[end]) else lines[end]["state"]
    elif lines and lines[-1].get("state") == "paused":
        state = "paused"
    else:
        state = "running"
    n = len(counted)

    def arm(key: str) -> Record:
        earned = sum(bool(line[key]) for line in counted)
        if n == 0:
            return {"earned": 0, "rate": None, "interval": None}
        return {"earned": earned, "rate": earned / n, "interval": clopper_pearson(earned, n)}

    return {
        "state": state,
        "ended": state in NAMES,
        "markets": n,
        "wins": sum(line["outcome"] == "win" for line in counted),
        "losses": sum(line["outcome"] == "loss" for line in counted),
        "concordant": sum(line["outcome"] == "concordant" for line in counted),
        "agent": arm("agent_earns"),
        "searcher": arm("searcher_earns"),
        "beyond": after,
        "voids": len(voids),
        "void_rule": void_rule(counted, voids),
    }


def void_rule(counted: list[Record], voids: list[Record]) -> Record:
    first: dict[str, bool] = {}
    for v in voids:
        if v["id"] in first:
            continue
        judged = judge(v["id"], 0.004, Path(v["ledger"]))
        if judged["pick"] is not None:
            first[v["id"]] = bool(judged["earns"])
    wins = losses = 0
    decision = "continue"
    for index, line in enumerate(counted):
        result = outcome(first.get(line["id"], bool(line["agent_earns"])), bool(line["searcher_earns"]))
        wins += result == "win"
        losses += result == "loss"
        decision = decide(wins, losses, index + 1)
        if decision != "continue":
            return {"decision": decision, "markets": index + 1, "beyond": False}
    return {"decision": decision, "markets": len(counted), "beyond": decision == "continue"}


def kept_voids(out: Path) -> list[Record]:
    path = out / "voids.jsonl"
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def check_summary(out: Path) -> Record:
    lines = [json.loads(line) for line in (out / "results.jsonl").read_text().splitlines()]
    got = summarize(out)
    want = recount(lines, kept_voids(out))
    for key in ("state", "ended", "markets", "wins", "losses", "concordant", "beyond", "voids", "void_rule"):
        assert got[key] == want[key], key
    for arm in ("agent", "searcher"):
        assert got[arm]["earned"] == want[arm]["earned"], arm
        if want[arm]["rate"] is None:
            assert got[arm]["rate"] is None and got[arm]["interval"] is None
        else:
            assert got[arm]["rate"] == pytest.approx(want[arm]["rate"], abs=1e-12)
            assert list(got[arm]["interval"]) == pytest.approx(list(want[arm]["interval"]), abs=1e-6)
    if want["ended"]:
        assert got["name"].startswith(NAMES[want["state"]])
    else:
        assert got["name"] is None
    return got


def in_dir(build: Callable[[Path], Path], check: Callable[[Path], object]) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        check(build(Path(scratch)))


# Behaviour 1: the decision and its name


@pytest.mark.parametrize(
    ("agent", "searcher", "state"),
    [("earn", False, "claim"), ("miss", True, "futility"), ("miss", False, "undecided")],
)
def test_the_report_states_the_decision_and_its_name_word_for_word(
    tmp_path: Path, agent: str, searcher: bool, state: str
) -> None:
    g100 = [searcher] * len(IDS)
    script = [agent] * len(IDS)
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    text = written(out)
    assert got["state"] == state and got["ended"] is True
    assert got["name"] in text
    if state == "claim":
        assert got["name"] == CLAIM
    assert "no better" not in text.lower()


def test_an_early_end_is_reported_inconclusive_at_the_markets_judged(tmp_path: Path) -> None:
    g100 = [i % 2 == 0 for i in range(len(IDS))]
    script = ["earn", "miss", "miss", "earn"] * 5
    lines, voids = history(g100, script, cut=4, tail="ended early")
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert (got["state"], got["markets"]) == ("ended early", 4)
    text = written(out)
    assert "inconclusive" in text.lower()
    assert got["name"] in text


@pytest.mark.parametrize("tail", ["paused", "model changed", None])
def test_an_unfinished_study_is_reported_as_not_ended(tmp_path: Path, tail: str | None) -> None:
    g100 = [False] * len(IDS)
    if tail == "model changed":
        script = ["earn", "miss", "foreign"]
        lines, voids = history(g100, script)
        lines[-1]["models"] = [PINNED, FOREIGN]
    else:
        script = ["earn", "miss", "crash", "crash", "crash", "miss"]
        lines, voids = history(g100, script, cut=2, tail=tail)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert got["ended"] is False and got["name"] is None
    text = written(out)
    assert "not ended" in text.lower()
    if tail == "model changed":
        assert FOREIGN in text


# Behaviour 2: rates, intervals, discordant counts


def test_rates_and_exact_intervals_on_a_known_history(tmp_path: Path) -> None:
    g100 = [i in (1, 4) for i in range(len(IDS))]
    script = ["earn", "earn", "miss", "earn", "earn", "earn", "earn", "earn", "earn", "earn", "earn", "earn"]
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    n = got["markets"]
    assert got["state"] == "claim"
    assert got["agent"]["earned"] == n - 1
    assert got["searcher"]["earned"] == 2
    text = written(out)
    for arm in ("agent", "searcher"):
        assert f"{got[arm]['earned']}/{n}" in text
        assert f"{got[arm]['rate']:.3f}" in text
        low, high = got[arm]["interval"]
        assert f"{low:.3f}" in text and f"{high:.3f}" in text
    assert (got["wins"], got["losses"], got["concordant"]) == (9, 0, 3)


# Behaviour 3: reported, never judged


def test_every_counted_and_void_market_and_every_model_id_appears(tmp_path: Path) -> None:
    g100 = [i % 4 == 0 for i in range(len(IDS))]
    script = ["earn", "crash", "miss", "signal", "nopick", "turns", "wall"] * 6
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    text = written(out)
    assert voids
    for line in lines:
        assert str(line["id"]) in text
        for model in line.get("models", []):
            assert model in text
    for v in voids:
        assert v["id"] in text
    for stopped in {line["stopped"] for line in lines if is_market_line(line)}:
        assert stopped in text


# Behaviour 4: voids and revision 4's rule


def test_the_decision_with_each_void_judged_on_its_pick(tmp_path: Path) -> None:
    """Market 0's first void has no pick (its ledger is gone) and its second earns; under revision 4's rule the
    second replaces the rerun's miss, so the claim comes one market sooner."""
    g100 = [False] * len(IDS)
    script = ["crash", "crash", "miss"] + ["earn"] * 9
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert got["voids"] == 2
    assert got["state"] == "claim" and got["markets"] == 10
    assert got["void_rule"] == {"decision": "claim", "markets": 9, "beyond": False}


def test_the_void_rule_takes_each_markets_first_void_with_a_pick(tmp_path: Path) -> None:
    """Market 1's first void earns and its second misses; the first is the one judged."""
    g100 = [False] * len(IDS)
    script = ["earn", "crash", "crash-miss", "miss"] + ["earn"] * 8
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert (got["state"], got["markets"], got["voids"]) == ("claim", 10, 2)
    assert got["void_rule"] == {"decision": "claim", "markets": 9, "beyond": False}


def test_a_void_rule_path_that_needs_more_markets_than_were_judged_is_said_to(tmp_path: Path) -> None:
    """Market 1's void picked a program that missed; judged on it, the study has eight wins where it claimed."""
    g100 = [False] * len(IDS)
    script = ["earn", "crash-miss", "earn"] + ["earn"] * 7
    lines, voids = history(g100, script)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert got["state"] == "claim" and got["markets"] == 9
    assert got["void_rule"] == {"decision": "continue", "markets": 9, "beyond": True}


# Behaviour 5: sessions beyond the stop


def test_sessions_beyond_the_stop_are_listed_apart_and_enter_no_rate(tmp_path: Path) -> None:
    g100 = [False] * len(IDS)
    script = ["earn"] * 20
    lines, voids = history(g100, script, beyond=3)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert got["beyond"] == IDS[9:12]
    assert (got["markets"], got["agent"]["earned"], got["searcher"]["earned"]) == (9, 9, 0)
    text = written(out)
    for market_id in IDS[9:12]:
        assert market_id in text


# Verify first


def test_verify_failing_stops_the_report_before_it_writes(tmp_path: Path) -> None:
    g100 = [False] * len(IDS)
    lines, voids = history(g100, ["earn"] * 9)
    out = lay_out(tmp_path, g100, ["earn"] * 9, lines, voids)

    def broken() -> Record:
        raise ValueError("calibration.json differs")

    with pytest.raises(ValueError):
        report().write(out, verify=broken, judge=judge)
    assert not (out / "report.md").exists()


# Laws

searchers = st.lists(st.booleans(), min_size=len(IDS), max_size=len(IDS))
scripts = st.lists(st.sampled_from(SCRIPTED), max_size=40)
tails = st.sampled_from([None, "paused", "ended early"])


@LAW
@given(searchers, scripts, st.integers(0, 30), tails, st.integers(0, 4))
def test_l9_1_the_report_is_a_function_of_its_inputs(
    g100: list[bool], script: list[str], cut: int, tail: str | None, beyond: int
) -> None:
    lines, voids = history(g100, script, cut, tail, beyond)

    def check(root: Path) -> None:
        out = root / "out"
        first = written(out)
        assert written(out) == first
        copy = root / "elsewhere" / "out"
        shutil.copytree(out, copy)
        (copy / "report.md").unlink()
        assert written(copy) == first

    in_dir(lambda root: lay_out(root, g100, script, lines, voids).parent, check)


@LAW
@given(searchers, scripts, st.integers(0, 30), tails)
def test_l9_2_every_rate_and_count_is_a_recount_of_the_lines(
    g100: list[bool], script: list[str], cut: int, tail: str | None
) -> None:
    lines, voids = history(g100, script, cut, tail)
    in_dir(lambda root: lay_out(root, g100, script, lines, voids), check_summary)


@LAW
@given(searchers, scripts, st.integers(1, 6))
def test_l9_3_never_no_better_and_lines_after_a_stop_enter_no_rate(
    g100: list[bool], script: list[str], beyond: int
) -> None:
    lines, voids = history(g100, script)
    assume(ends_study(lines[-1]) and is_market_line(lines[-1]))
    extended, _ = history(g100, script, beyond=beyond)
    assume(len(extended) > len(lines))

    def check(root: Path) -> None:
        plain = summarize(lay_out(root / "plain", g100, script, lines, voids))
        out = lay_out(root / "extended", g100, script, extended, voids)
        longer = summarize(out)
        assert longer["beyond"] == [line["id"] for line in extended[len(lines) :]]
        for key in SUMMARY_KEYS:
            assert longer[key] == plain[key], key
        assert "no better" not in written(out).lower()

    in_dir(lambda root: root, check)


def test_no_rate_is_reported_when_no_market_counts(tmp_path: Path) -> None:
    g100 = [False] * len(IDS)
    script = ["crash"] * 3
    lines, voids = history(g100, script, cut=1, tail=None)
    out = lay_out(tmp_path, g100, script, lines, voids)
    got = check_summary(out)
    assert got["markets"] == 0 and got["state"] == "paused"
    assert "no better" not in written(out).lower()
