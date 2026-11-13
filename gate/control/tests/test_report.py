"""Study 1, step 9: the report (gate/control/report.py), its behaviours and laws L9.1 to L9.3, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2 and 5.4, at ce7ff38. Written from the
plan before the code, by another model than the builder's. The input files are the ones the runner could have
written, in the format `test_runner.py` fixes, built here by `fakes.simulate` from random scripts of sessions.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `summary(out, *, verify) -> dict` and `write(out, *, verify) -> None`, the second writing `out/report.md`. Both
  call `verify()` first (the manifest) and read `out`'s `calibration.json`, `searcher.jsonl` and `results.jsonl`, and
  no ledger.
- The summary's keys:
  - "state": "claim", "futility" or "undecided" (the decision of the first market line that ends the study),
    "ended early" (the state line), or "running";
  - "ended": true for the first four; "name": for those, architecture 5.4's name, word for word, else None;
  - "markets": the market lines counted, which are those up to the end (all of them when nothing ended);
  - "wins", "losses", "concordant": the outcomes of the counted lines;
  - "agent" and "searcher": {"earned", "rate", "interval"}, over the counted lines (`agent_earns`,
    `searcher_earns`), the interval Clopper-Pearson's at 95%; rate and interval None when no line counts;
  - "by_models": for each set of ids that answered a counted session, keyed by its ids sorted and joined with
    ", ", the agent's {"sessions", "share", "earned", "rate", "interval"} over those sessions, "share" being their
    count over "markets";
  - "g100_at_k": for each counted market, {"id", "k", "pick", "earns"}: `k` the agent's evaluations there, and G100's
    last earlier best at or before evaluation `k` (`searcher.jsonl`), pick None and earns False when there is none;
  - "cut_off": the ids of counted lines whose session reached no designed end ("crashed" or "killed");
  - "unnamed": the ids of counted lines whose session is not the agent's;
  - "beyond": the ids of market lines after the end, which enter no count above.
- `report.md` holds the name; under a claim every model id that answered a counted session; each arm's earned count
  as "<earned>/<markets>", each rate and interval bound to three decimals; each set's share to three decimals and the
  sentence `SETS` when a market counts; every counted market's id, every model id and every ending in the lines; and,
  for a study that has not ended, the words "not ended"."""

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

from gate.control.sequential import outcome
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
SCRIPTED += ["crash", "signal", "empty", "foreign", "foreign-crash"]
CLAIM = "The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do"
NAMES = {
    "claim": CLAIM,
    "futility": "Not shown",
    "undecided": "Inconclusive",
    "ended early": "Inconclusive at the markets judged",
}
SETS = "The sets are not arms: which ids answer a session depends on how long it runs"
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
    "unnamed",
    "beyond",
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
) -> list[Record]:
    """The runner's lines for a script with the sessions `killed` killed while running, optionally cut after `cut`
    lines and given a last "ended early" line, or followed by `beyond` market lines past the end."""
    lines, _ = simulate(g100, script, killed)
    if cut is not None and cut < len(lines):
        lines = lines[:cut]
        if tail == "ended early":
            lines.append({"state": "ended early", "markets": len(lines)})
    if beyond and lines and is_market_line(lines[-1]) and ends_study(lines[-1]):
        last = len(lines)
        for k in range(min(beyond, len(IDS) - last)):
            extra = dict(lines[-1])
            extra["id"] = IDS[last + k]
            extra["agent_earns"] = k % 2 == 0
            extra["searcher_earns"] = not g100[last + k]
            extra["outcome"] = outcome(extra["agent_earns"], extra["searcher_earns"])
            lines.append(extra)
    return lines


def lay_out(root: Path, g100: list[bool], lines: list[Record]) -> Path:
    out = root / "out"
    out.mkdir(parents=True)
    (out / "calibration.json").write_text(json.dumps({"strength": 0.004, "walls": {}}))
    (out / "searcher.jsonl").write_text("".join(json.dumps(searcher_line(i, e)) + "\n" for i, e in zip(IDS, g100)))
    (out / "results.jsonl").write_text("".join(json.dumps(line) + "\n" for line in lines))
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


def model_set(line: Record) -> str:
    return ", ".join(sorted(model for model, _ in line["models"]))


def recount(out: Path) -> Record:
    """The summary, computed here from the files."""
    lines = read(out / "results.jsonl")
    g100 = {line["id"]: line for line in read(out / "searcher.jsonl")}
    end = next((i for i, line in enumerate(lines) if ends_study(line)), None)
    before = lines if end is None else lines[: end + 1]
    counted = [line for line in before if is_market_line(line)]
    after = [] if end is None else [line["id"] for line in lines[end + 1 :] if is_market_line(line)]
    if end is None:
        state = "running"
    elif is_market_line(lines[end]):
        state = lines[end]["decision"]
    else:
        state = lines[end]["state"]
    n = len(counted)
    groups: dict[str, list[Record]] = {}
    for line in counted:
        groups.setdefault(model_set(line), []).append(line)
    at_k = []
    for line in counted:
        k = line["evaluations"]
        bests = [b for b in g100[line["id"]]["earlier"] if b["evaluation"] <= k] if k else []
        best = bests[-1] if bests else {"pick": None, "earns": False}
        at_k.append({"id": line["id"], "k": k, "pick": best["pick"], "earns": best["earns"]})
    by_models = {}
    for key, group in groups.items():
        earned = sum(bool(line["agent_earns"]) for line in group)
        by_models[key] = {"sessions": len(group), "share": len(group) / n, **rate(earned, len(group))}
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
        "by_models": by_models,
        "g100_at_k": at_k,
        "cut_off": [line["id"] for line in counted if line["ended"] in ("crashed", "killed")],
        "unnamed": [line["id"] for line in counted if not line["is_agent"]],
        "beyond": after,
    }


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
        assert got["by_models"][key]["share"] == pytest.approx(group["share"], abs=1e-12), key
        same_rate(got["by_models"][key], group)
    return got


def in_dir(build: Callable[[Path], Path], check: Callable[[Path], object]) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        check(build(Path(scratch)))


def laid(tmp_path: Path, g100: list[bool], script: list[str], **kw: Any) -> Path:
    return lay_out(tmp_path, g100, history(g100, script, **kw))


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
    assert "not ended" not in text.lower()


def test_a_claim_names_the_models_that_answered_and_each_sets_share(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "fallback", "mixed", "fallback"] + ["earn"] * 5)
    got = check_summary(out)
    text = written(out)
    assert got["state"] == "claim"
    assert ASKED in text and FALLBACK in text
    shares = {key: group["share"] for key, group in got["by_models"].items()}
    assert shares == pytest.approx({ASKED: 6 / 9, FALLBACK: 2 / 9, ", ".join(sorted((ASKED, FALLBACK))): 1 / 9})
    for share in shares.values():
        assert f"{share:.3f}" in text
    assert SETS in text


def test_an_early_end_is_inconclusive_at_the_markets_judged(tmp_path: Path) -> None:
    g100 = [i % 2 == 0 for i in range(len(IDS))]
    out = laid(tmp_path, g100, ["earn", "miss", "miss", "earn"] * 5, cut=4, tail="ended early")
    got = check_summary(out)
    assert (got["state"], got["ended"], got["markets"]) == ("ended early", True, 4)
    text = written(out)
    assert NAMES["ended early"] in text
    assert "not ended" not in text.lower()


def test_a_study_that_has_reached_no_end_is_reported_as_not_ended(tmp_path: Path) -> None:
    out = laid(tmp_path, [False] * len(IDS), ["earn", "miss", "crash", "foreign", "miss"], cut=4)
    got = check_summary(out)
    assert (got["state"], got["ended"], got["name"], got["markets"]) == ("running", False, None, 4)
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


# Behaviours 3 and 4: reported, never judged


def test_the_agents_rate_and_share_for_each_set_of_ids_with_the_sentence(tmp_path: Path) -> None:
    script = ["earn", "fallback", "mixed", "miss", "fallback", "miss", "mixed", "earn", "foreign", "earn"] * 2
    out = laid(tmp_path, [False] * len(IDS), script)
    got = check_summary(out)
    both = ", ".join(sorted((ASKED, FALLBACK)))
    unnamed = ", ".join(sorted((ASKED, FOREIGN)))
    assert set(got["by_models"]) == {ASKED, FALLBACK, both, unnamed}
    assert got["by_models"][unnamed]["earned"] == 0
    assert sum(group["share"] for group in got["by_models"].values()) == pytest.approx(1.0)
    assert SETS in written(out)


def test_g100_among_its_first_k_evaluations_is_its_last_earlier_best_at_or_before_k(tmp_path: Path) -> None:
    """The fake's earlier bests are at evaluations 1, 7 and 40; an agent's count of 0 has no pick."""
    out = laid(tmp_path, [True] * len(IDS), ["nopick", "earn", "turns", "miss"] + ["miss"] * 4)
    got = check_summary(out)
    ks = [(row["k"], row["pick"]) for row in got["g100_at_k"][:3]]
    assert ks == [(0, None), (7, f"g100-{IDS[1]}-7"), (11, f"g100-{IDS[2]}-7")]


def test_sessions_with_no_designed_end_and_sessions_an_unnamed_id_answered_are_listed(tmp_path: Path) -> None:
    g100 = [i % 4 == 0 for i in range(len(IDS))]
    script = ["earn", "crash", "empty", "signal", "nopick", "turns", "foreign", "mixed", "wall", "foreign-crash"] * 3
    out = laid(tmp_path, g100, script, killed=frozenset({4, 11}))
    got = check_summary(out)
    assert got["cut_off"] and got["unnamed"]
    assert IDS[4] in got["cut_off"]
    text = written(out)
    for line in read(out / "results.jsonl"):
        assert str(line["id"]) in text
        assert line["ended"] in text
        for model, _ in line["models"]:
            assert model in text
        for name in line["reads"]:
            assert name in text


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
    out = laid(tmp_path, [False] * len(IDS), ["earn"], cut=0)
    got = check_summary(out)
    assert (got["markets"], got["state"], got["by_models"]) == (0, "running", {})
    text = written(out)
    assert "no better" not in text.lower()
    assert "not ended" in text.lower()


# Laws

searchers = st.lists(st.booleans(), min_size=len(IDS), max_size=len(IDS))
scripts = st.lists(st.sampled_from(SCRIPTED), max_size=40)
tails = st.sampled_from([None, "ended early"])
kills = st.frozensets(st.integers(0, 40), max_size=4)


@LAW
@given(searchers, scripts, st.integers(0, 30), tails, st.integers(0, 4), kills)
def test_l9_1_the_report_is_a_function_of_its_inputs(
    g100: list[bool], script: list[str], cut: int, tail: str | None, beyond: int, killed: frozenset[int]
) -> None:
    lines = history(g100, script, cut, tail, beyond, killed)

    def check(root: Path) -> None:
        out = root / "out"
        first = written(out)
        assert written(out) == first
        copy = root / "elsewhere" / "out"
        shutil.copytree(out, copy)
        (copy / "report.md").unlink()
        assert written(copy) == first

    in_dir(lambda root: lay_out(root, g100, lines).parent, check)


@LAW
@given(searchers, scripts, st.integers(0, 30), tails, kills)
def test_l9_2_every_rate_and_count_is_a_recount_of_the_lines(
    g100: list[bool], script: list[str], cut: int, tail: str | None, killed: frozenset[int]
) -> None:
    lines = history(g100, script, cut, tail, killed=killed)
    in_dir(lambda root: lay_out(root, g100, lines), check_summary)


@LAW
@given(searchers, scripts, st.integers(1, 6))
def test_l9_3_never_no_better_and_lines_after_a_stop_enter_no_rate(
    g100: list[bool], script: list[str], beyond: int
) -> None:
    lines = history(g100, script)
    assume(ends_study(lines[-1]))
    extended = history(g100, script, beyond=beyond)
    assume(len(extended) > len(lines))

    def check(root: Path) -> None:
        plain = summarize(lay_out(root / "plain", g100, lines))
        out = lay_out(root / "extended", g100, extended)
        longer = summarize(out)
        assert longer["beyond"] == [line["id"] for line in extended[len(lines) :]]
        for key in (*KEYS, "agent", "searcher", "by_models"):
            if key != "beyond":
                assert longer[key] == plain[key], key
        assert "no better" not in written(out).lower()

    in_dir(lambda root: root, check)
