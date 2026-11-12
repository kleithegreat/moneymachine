"""Study 1, step 9: the report (gate/control/report.py), its behaviours and laws L9.1 to L9.3, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2 and 5.4, at 54c11fb. Written from the
plan before the code, by another model than the builder's. The input files are the ones the runner could have
written, in the format `test_runner.py` fixes, built here by `fakes.simulate` from random scripts of sessions.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `summary(out, *, verify) -> dict` and `write(out, *, verify) -> None`, the second writing `out/report.md`. Both
  call `verify()` first (the manifest) and read `out`'s `calibration.json`, `searcher.jsonl`, `results.jsonl` and
  `voids.jsonl` (absent when no session was void), and no ledger.
- The summary's keys:
  - "state": "claim", "futility" or "undecided" (the decision of the first market line that ends the study),
    "ended early" or "model changed" (a state line), "paused" (the last line, with no end before it), or "running";
  - "ended": true for the first five; "name": for those, architecture 5.4's name, word for word, else None;
  - "markets": the market lines counted, which are those up to the end (all of them when nothing ended);
  - "wins", "losses", "concordant": the outcomes of the counted lines;
  - "agent" and "searcher": {"earned", "rate", "interval"}, over the counted lines (`agent_earns`,
    `searcher_earns`), the interval Clopper-Pearson's at 95%; rate and interval None when no line counts;
  - "by_models": for each set of ids that answered a counted session, keyed by its ids sorted and joined with
    ", ", the agent's {"sessions", "earned", "rate", "interval"} over those sessions;
  - "g100_at_k": for each counted market, {"id", "k", "pick", "earns"}: `k` the agent's evaluations there, and G100's
    last earlier best at or before evaluation `k` (`searcher.jsonl`), pick None and earns False when there is none;
  - "cut_off": the ids of counted lines whose session ended "crashed" or "killed";
  - "beyond": the ids of market lines after the end, which enter no count above;
  - "voids": the number of void lines;
  - "voids_as_misses": {"decision", "markets", "beyond"}: the decision when every counted market with a void line
    counts as the agent's miss, taken at the shortest prefix that does not continue, else at the last counted
    market; "markets", that prefix's length; "beyond" when that decision is "continue".
- `report.md` holds the name; under a claim every model id that answered a counted session, and 5.4's sentence when
  "voids_as_misses" is not a claim; each arm's earned count as "<earned>/<markets>", each rate and interval bound to
  three decimals; every counted and void market's id and every model id in the lines; for a model change, the ids
  that caused it; and, for a study that has not ended (paused or running), the words "not ended"."""

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
    ASKED,
    FALLBACK,
    FOREIGN,
    IDS,
    ends_study,
    is_market_line,
    manifest,
    searcher_line,
    simulate,
)

Record = dict[str, Any]
LAW = settings(max_examples=40, deadline=None)
SCRIPTED = ["earn"] * 4 + ["miss"] * 4 + ["fallback"] * 3 + ["mixed", "notice", "nopick", "turns", "wall"]
SCRIPTED += ["crash", "signal", "empty", "empty", "foreign"]
CLAIM = "The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do"
NAMES = {
    "claim": CLAIM,
    "futility": "Not shown",
    "undecided": "Inconclusive",
    "ended early": "Inconclusive at the markets judged",
    "model changed": "Inconclusive at the markets judged",
}
NOT_REACHED = "With its void sessions counted as misses, the claim is not reached"
KEYS = (
    "state",
    "ended",
    "name",
    "markets",
    "wins",
    "losses",
    "concordant",
    "g100_at_k",
    "cut_off",
    "beyond",
    "voids",
    "voids_as_misses",
)


def report() -> ModuleType:
    return importlib.import_module("gate.control.report")


def verify() -> Record:
    return manifest()


def history(
    g100: list[bool],
    script: list[str],
    cut: int | None = None,
    tail: str | None = None,
    beyond: int = 0,
    killed: frozenset[int] = frozenset(),
) -> tuple[list[Record], list[Record]]:
    """The runner's lines for a script with the sessions `killed` killed while running, optionally cut after `cut`
    lines and given a last state line, or followed by `beyond` market lines past the end."""
    lines, voids, _ = simulate(g100, script, killed)
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


def lay_out(root: Path, g100: list[bool], lines: list[Record], voids: list[Record]) -> Path:
    out = root / "out"
    out.mkdir(parents=True)
    void_lines = [{k: v[k] for k in ("id", "run", "models", "ended")} for v in voids]
    (out / "calibration.json").write_text(json.dumps({"strength": 0.004, "walls": {}}))
    (out / "searcher.jsonl").write_text("".join(json.dumps(searcher_line(i, e)) + "\n" for i, e in zip(IDS, g100)))
    (out / "results.jsonl").write_text("".join(json.dumps(line) + "\n" for line in lines))
    if void_lines:
        (out / "voids.jsonl").write_text("".join(json.dumps(v) + "\n" for v in void_lines))
    return out


def summarize(out: Path) -> Record:
    result: Record = report().summary(out, verify=verify)
    return result


def written(out: Path) -> str:
    report().write(out, verify=verify)
    return (out / "report.md").read_text()


def clopper_pearson(k: int, n: int) -> tuple[float, float]:
    low = 0.0 if k == 0 else float(stats.beta.ppf(0.025, k, n - k + 1))
    high = 1.0 if k == n else float(stats.beta.ppf(0.975, k + 1, n - k))
    return low, high


def rate(earned: int, n: int) -> Record:
    if n == 0:
        return {"earned": 0, "rate": None, "interval": None}
    return {"earned": earned, "rate": earned / n, "interval": clopper_pearson(earned, n)}


def read(path: Path) -> list[Record]:
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def recount(out: Path) -> Record:
    """The summary, computed here from the files."""
    lines = read(out / "results.jsonl")
    voids = read(out / "voids.jsonl")
    g100 = {line["id"]: line for line in read(out / "searcher.jsonl")}
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
    groups: dict[str, list[Record]] = {}
    for line in counted:
        groups.setdefault(", ".join(sorted(model for model, _ in line["models"])), []).append(line)
    at_k = []
    for line in counted:
        k = line["evaluations"]
        bests = [b for b in g100[line["id"]]["earlier"] if b["evaluation"] <= k] if k else []
        best = bests[-1] if bests else {"pick": None, "earns": False}
        at_k.append({"id": line["id"], "k": k, "pick": best["pick"], "earns": best["earns"]})
    return {
        "state": state,
        "ended": state in NAMES,
        "name": NAMES.get(state),
        "markets": n,
        "wins": sum(line["outcome"] == "win" for line in counted),
        "losses": sum(line["outcome"] == "loss" for line in counted),
        "concordant": sum(line["outcome"] == "concordant" for line in counted),
        "agent": rate(sum(bool(line["agent_earns"]) for line in counted), n),
        "searcher": rate(sum(bool(line["searcher_earns"]) for line in counted), n),
        "by_models": {
            key: {"sessions": len(group), **rate(sum(bool(line["agent_earns"]) for line in group), len(group))}
            for key, group in groups.items()
        },
        "g100_at_k": at_k,
        "cut_off": [line["id"] for line in counted if line["ended"] in ("crashed", "killed")],
        "beyond": after,
        "voids": len(voids),
        "voids_as_misses": voids_as_misses(counted, {v["id"] for v in voids}),
    }


def voids_as_misses(counted: list[Record], voided: set[str]) -> Record:
    wins = losses = 0
    decision = "continue"
    for index, line in enumerate(counted):
        agent = bool(line["agent_earns"]) and line["id"] not in voided
        result = outcome(agent, bool(line["searcher_earns"]))
        wins += result == "win"
        losses += result == "loss"
        decision = decide(wins, losses, index + 1)
        if decision != "continue":
            return {"decision": decision, "markets": index + 1, "beyond": False}
    return {"decision": decision, "markets": len(counted), "beyond": decision == "continue"}


def same_rate(got: Record, want: Record) -> None:
    assert got["earned"] == want["earned"]
    if want["rate"] is None:
        assert got["rate"] is None and got["interval"] is None
    else:
        assert got["rate"] == pytest.approx(want["rate"], abs=1e-12)
        assert list(got["interval"]) == pytest.approx(list(want["interval"]), abs=1e-6)


def check_summary(out: Path) -> Record:
    got = summarize(out)
    want = recount(out)
    for key in KEYS:
        assert got[key] == want[key], key
    for arm in ("agent", "searcher"):
        same_rate(got[arm], want[arm])
    assert set(got["by_models"]) == set(want["by_models"])
    for key, group in want["by_models"].items():
        assert got["by_models"][key]["sessions"] == group["sessions"], key
        same_rate(got["by_models"][key], group)
    return got


def in_dir(build: Callable[[Path], Path], check: Callable[[Path], object]) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        check(build(Path(scratch)))


def laid(tmp_path: Path, g100: list[bool], script: list[str], **kw: Any) -> Path:
    lines, voids = history(g100, script, **kw)
    return lay_out(tmp_path, g100, lines, voids)


# Behaviour 1: the decision and its name


@pytest.mark.parametrize(
    ("kind", "searcher", "state"),
    [("earn", False, "claim"), ("miss", True, "futility"), ("miss", False, "undecided")],
)
def test_the_report_states_the_decision_and_its_name_word_for_word(
    tmp_path: Path, kind: str, searcher: bool, state: str
) -> None:
    out = laid(tmp_path, [searcher] * len(IDS), [kind] * len(IDS))
    got = check_summary(out)
    text = written(out)
    assert (got["state"], got["ended"], got["name"]) == (state, True, NAMES[state])
    assert NAMES[state] in text
    assert "no better" not in text.lower()


def test_a_claim_names_the_models_that_answered(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "fallback", "mixed"] + ["earn"] * 6)
    got = check_summary(out)
    text = written(out)
    assert got["state"] == "claim"
    assert ASKED in text and FALLBACK in text
    assert NOT_REACHED not in text


def test_a_claim_that_voids_counted_as_misses_do_not_reach_carries_the_sentence(tmp_path: Path) -> None:
    """Market 0's void counts as a miss: the claim at nine wins becomes eight, and the path has not ended."""
    out = laid(tmp_path, [False] * len(IDS), ["empty", "earn"] + ["earn"] * 8)
    got = check_summary(out)
    assert (got["state"], got["markets"], got["voids"]) == ("claim", 9, 1)
    assert got["voids_as_misses"] == {"decision": "continue", "markets": 9, "beyond": True}
    assert NOT_REACHED in written(out)


def test_voids_counted_as_misses_can_still_claim(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["empty", "miss"] + ["earn"] * 9)
    got = check_summary(out)
    assert (got["state"], got["markets"]) == ("claim", 10)
    assert got["voids_as_misses"] == {"decision": "claim", "markets": 10, "beyond": False}
    assert NOT_REACHED not in written(out)


def test_an_early_end_is_inconclusive_at_the_markets_judged(tmp_path: Path) -> None:
    g100 = [i % 2 == 0 for i in range(len(IDS))]
    out = laid(tmp_path, g100, ["earn", "miss", "miss", "earn"] * 5, cut=4, tail="ended early")
    got = check_summary(out)
    assert (got["state"], got["ended"], got["markets"]) == ("ended early", True, 4)
    text = written(out)
    assert NAMES["ended early"] in text
    assert "not ended" not in text.lower()


def test_a_model_change_is_an_end_inconclusive_at_the_markets_judged_with_its_cause(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "fallback", "foreign"])
    got = check_summary(out)
    assert (got["state"], got["ended"], got["name"], got["markets"]) == (
        "model changed",
        True,
        NAMES["model changed"],
        2,
    )
    text = written(out)
    assert NAMES["model changed"] in text and FOREIGN in text
    assert "not ended" not in text.lower()


@pytest.mark.parametrize("tail", ["paused", None])
def test_a_paused_or_unfinished_study_is_reported_as_not_ended(tmp_path: Path, tail: str | None) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "miss", "empty", "empty", "empty", "miss"], cut=2, tail=tail)
    got = check_summary(out)
    assert (got["ended"], got["name"]) == (False, None)
    assert "not ended" in written(out).lower()


# Behaviour 2: rates, intervals, discordant counts


def test_rates_and_exact_intervals_on_a_known_history(tmp_path: Path) -> None:
    g100 = [i in (1, 4) for i in range(len(IDS))]
    script = ["earn", "earn", "miss", "earn", "earn", "earn", "earn", "earn", "earn", "earn", "earn", "earn"]
    out = laid(tmp_path, g100, script)
    got = check_summary(out)
    n = got["markets"]
    assert (got["state"], n, got["agent"]["earned"], got["searcher"]["earned"]) == ("claim", 12, 11, 2)
    assert (got["wins"], got["losses"], got["concordant"]) == (9, 0, 3)
    text = written(out)
    for arm in ("agent", "searcher"):
        assert f"{got[arm]['earned']}/{n}" in text
        assert f"{got[arm]['rate']:.3f}" in text
        low, high = got[arm]["interval"]
        assert f"{low:.3f}" in text and f"{high:.3f}" in text


# Behaviour 3: reported, never judged


def test_the_agents_rate_for_each_set_of_ids(tmp_path: Path) -> None:
    script = ["earn", "fallback", "mixed", "miss", "fallback", "miss", "mixed", "earn", "earn"] * 2
    out = laid(tmp_path, [False] * len(IDS), script)
    got = check_summary(out)
    both = ", ".join(sorted((ASKED, FALLBACK)))
    assert set(got["by_models"]) == {ASKED, FALLBACK, both}
    assert got["by_models"][both]["sessions"] == 2


def test_g100_among_its_first_k_evaluations_is_its_last_earlier_best_at_or_before_k(tmp_path: Path) -> None:
    """The fake's earlier bests are at evaluations 1, 7 and 40; an agent's count of 0 has no pick."""
    out = laid(tmp_path, [True] * len(IDS), ["nopick", "earn", "turns", "miss"] + ["miss"] * 4)
    got = check_summary(out)
    ks = [(row["k"], row["pick"]) for row in got["g100_at_k"][:3]]
    assert ks == [(0, None), (7, f"g100-{IDS[1]}-7"), (11, f"g100-{IDS[2]}-7")]


def test_cut_off_sessions_and_every_market_model_id_and_ending_appear(tmp_path: Path) -> None:
    g100 = [i % 4 == 0 for i in range(len(IDS))]
    out = laid(tmp_path, g100, ["earn", "crash", "empty", "signal", "nopick", "turns", "mixed", "wall"] * 6)
    got = check_summary(out)
    assert got["cut_off"]
    text = written(out)
    lines = read(out / "results.jsonl")
    for line in lines:
        assert str(line["id"]) in text
        for model, _ in line.get("models", []):
            assert model in text
    for line in [ln for ln in lines if is_market_line(ln)]:
        assert line["ended"] in text
        for name in line["reads"]:
            assert name in text
    for void in read(out / "voids.jsonl"):
        assert void["id"] in text


def test_a_session_killed_after_an_evaluation_is_a_judged_cut_off_session(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "earn", "earn", "nopick", "earn"], killed=frozenset({2, 3}))
    got = check_summary(out)
    assert got["cut_off"] == [IDS[2]]
    assert got["voids"] == 1


# Behaviour 5: sessions beyond the stop


def test_sessions_beyond_the_stop_are_listed_apart_and_enter_no_rate(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn"] * 20, beyond=3)
    got = check_summary(out)
    assert got["beyond"] == IDS[9:12]
    assert (got["markets"], got["agent"]["earned"], got["searcher"]["earned"]) == (9, 9, 0)
    text = written(out)
    for market_id in IDS[9:12]:
        assert market_id in text


# Verify first, and an empty study


def test_verify_failing_stops_the_report_before_it_writes(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn"] * 9)

    def broken() -> Record:
        raise ValueError("calibration.json differs")

    with pytest.raises(ValueError):
        report().write(out, verify=broken)
    assert not (out / "report.md").exists()


def test_no_rate_is_reported_when_no_market_counts(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["empty"] * 3, cut=1)
    got = check_summary(out)
    assert (got["markets"], got["state"]) == (0, "paused")
    assert "no better" not in written(out).lower()


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

    in_dir(lambda root: lay_out(root, g100, lines, voids).parent, check)


@LAW
@given(searchers, scripts, st.integers(0, 30), tails)
def test_l9_2_every_rate_and_count_is_a_recount_of_the_lines(
    g100: list[bool], script: list[str], cut: int, tail: str | None
) -> None:
    lines, voids = history(g100, script, cut, tail)
    in_dir(lambda root: lay_out(root, g100, lines, voids), check_summary)


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
        plain = summarize(lay_out(root / "plain", g100, lines, voids))
        out = lay_out(root / "extended", g100, extended, voids)
        longer = summarize(out)
        assert longer["beyond"] == [line["id"] for line in extended[len(lines) :]]
        for key in (*KEYS, "agent", "searcher", "by_models"):
            if key != "beyond":
                assert longer[key] == plain[key], key
        assert "no better" not in written(out).lower()

    in_dir(lambda root: root, check)
