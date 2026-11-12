"""Study 1, step 8: the runner (gate/control/runner.py), its behaviours and laws L8.1 to L8.7, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2, at 54c11fb. Written from the plan
before the code, by another model than the builder's. No agent session, kernel run or account check happens here:
every effect is a fake from `fakes.py`, and every kill is a SIGKILL of the process running the runner.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `run(out, work, *, verify, room, market, session, spent, judge) -> None`, keyword effects defaulting to the real
  ones (`fakes.py`'s docstring lists their signatures). `out` is `audit/control-1`'s stand-in: it holds
  `searcher.jsonl` (step 7) and receives `results.jsonl` and `voids.jsonl`. The manifest comes from `verify()`, which
  is called first and whose exception propagates; the runner takes `SERVED` and `NOTICE` from its "constants". `work`
  is the data root: everything of the agent's arm on market `m` (its market, run directories and ledgers, kept voids
  among them) lives under `work/agent/<m>`, and G100's arm under `work/searcher`. A session's campaign is its market's
  id. `room()` is called before every session; None ends the runner without a line. The runner learns a session's
  evaluations from `spent` and its pick from `judge`, and reads no ledger itself. A session that left no `run.json`
  in its workdir was killed.
- `end(out, *, verify) -> None` is `--end`: it appends {"state": "ended early", "markets": <market lines>}.
- `model_ids(transcript, notice) -> list[tuple[str, int]]`: the plan's "model ids", each with its count of assistant
  lines, in order of first appearance; `notice` is the manifest's `NOTICE`, or None.
- A market line of `results.jsonl` holds "id", "run" (the run record, None for a killed session), "models" (the model
  ids as [id, count] pairs), "evaluations", "ended" (the run's `stopped` at a designed end, "crashed", or "killed"),
  "pick", "reads", "pairs_won", "reference_median", "pick_median", "agent_earns", "searcher_earns" (from
  `searcher.jsonl`), "outcome", "running_wins", "running_losses" and "decision"; it has an "outcome" key and no
  "state" key. A state line has "state": "paused" with the market's "id", "model changed" with "id" and "models", or
  "ended early" with "markets". A line of `voids.jsonl` holds "id", "run" (None for a killed session), "models" and
  "ended".
- A pause comes after the third void on a market since that market's last pause, so a restart gives the market three
  more sessions."""

import hashlib
import importlib
import json
import random
import tempfile
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from gate.control.constants import MAX_VOIDS
from gate.control.sequential import decide, outcome
from gate.control.tests.fakes import (
    ASKED,
    FALLBACK,
    FOREIGN,
    IDS,
    KINDS,
    NOTICE,
    Drive,
    Fakes,
    Record,
    calls,
    drive,
    ends_study,
    event_line,
    ids_of,
    is_market_line,
    jsonl,
    project,
    project_void,
    run_record,
    sha256,
    simulate,
    transcript,
    world,
)

LAW = settings(max_examples=15, deadline=None)
EFFECTS = ("room", "market", "session", "spent", "judge")


def runner() -> ModuleType:
    return importlib.import_module("gate.control.runner")


def go(root: Path, restarts: int = 60, kill_after: Callable[[], float] | None = None) -> Drive:
    return drive(root, runner().run, restarts, kill_after)


@contextmanager
def study(
    g100: list[bool],
    script: list[str],
    kills: set[tuple[str, int]] | None = None,
    room_limit: int | None = None,
    pause_seconds: float = 0.0,
    event_at: int | None = -1,
) -> Iterator[Path]:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch) / "study"
        world(root, g100, script, kills or set(), room_limit, pause_seconds, event_at)
        yield root


def sessions(d: Drive) -> list[Record]:
    return [c for c in d.calls if c["kind"] == "session"]


def judged_sessions(d: Drive) -> set[int]:
    return {c["session"] for c in d.calls if c["kind"] == "judge"}


def violations(d: Drive) -> list[object]:
    return [c["text"] for c in d.calls if c["kind"] == "violation"]


def market_lines(d: Drive) -> list[Record]:
    return [line for line in d.lines if is_market_line(line)]


def killed_sessions(kills: set[tuple[str, int]]) -> set[int]:
    return {n for kind, n in kills if kind == "session"}


def expected(g100: list[bool], script: list[str], kills: set[tuple[str, int]] | None = None) -> list[Record]:
    lines, _, _ = simulate(g100, script, killed_sessions(kills or set()))
    return [project(line) for line in lines]


def as_lists(ids: list[tuple[str, int]]) -> list[list[Any]]:
    return [[model, count] for model, count in ids]


# The model ids


def write(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "transcript.jsonl"
    path.write_text(text)
    return path


def test_model_ids_count_each_id_in_order_of_first_appearance(tmp_path: Path) -> None:
    """The three mixed sessions of the pilot: one `claude-opus-5-5` response, then `claude-opus-4-8`."""
    answers = (ASKED, FALLBACK, FALLBACK, FALLBACK)
    path = write(tmp_path, transcript(answers, 3))
    assert as_lists(runner().model_ids(path, NOTICE)) == [[ASKED, 1], [FALLBACK, 3]]


def test_model_ids_pass_over_lines_that_do_not_parse_and_the_clients_own_id(tmp_path: Path) -> None:
    answers = ["model-b", "model-a", NOTICE, "model-b", "model-c"]
    text = "not json\n" + "".join(
        json.dumps({"type": "assistant", "message": {"model": m, "content": []}}) + "\n" for m in answers
    )
    path = write(tmp_path, text + '{"type": "assistant", "message": {"mod')
    assert as_lists(runner().model_ids(path, NOTICE)) == [["model-b", 2], ["model-a", 1], ["model-c", 1]]
    assert as_lists(runner().model_ids(path, None)) == [["model-b", 2], ["model-a", 1], [NOTICE, 1], ["model-c", 1]]


@pytest.mark.parametrize("event_at", [None, 0, 1, 2, 3])
def test_model_ids_do_not_read_the_fallback_event_wherever_it_stands(tmp_path: Path, event_at: int | None) -> None:
    path = write(tmp_path, transcript((FALLBACK,) * 3, event_at))
    assert as_lists(runner().model_ids(path, NOTICE)) == [[FALLBACK, 3]]


OTHER_LINES = [
    json.dumps(event_line()),
    json.dumps({"type": "system", "subtype": "init", "model": ASKED}),
    json.dumps({"type": "user", "message": {"model": FOREIGN, "content": []}}),
    json.dumps({"type": "result", "subtype": "success", "modelUsage": {FOREIGN: {}, ASKED: {}}}),
    json.dumps({"type": "rate_limit_event", "rate_limit_info": {}}),
    '{"type": "assistant", "message": {"model": "cut',
    "",
]
answer_ids = st.lists(st.sampled_from([ASKED, FALLBACK, NOTICE, FOREIGN, "model-x"]), max_size=12)
others = st.lists(st.sampled_from(OTHER_LINES), max_size=12)


def assistant(model: str) -> str:
    return json.dumps({"type": "assistant", "message": {"model": model, "content": [{"type": "text", "text": "x"}]}})


@settings(max_examples=200, deadline=None)
@given(answer_ids, others, others, st.randoms(use_true_random=False), st.sampled_from([NOTICE, None]))
def test_l8_7_model_ids_are_a_function_of_the_assistant_lines_not_named_notice(
    answers: list[str], first: list[str], second: list[str], rnd: random.Random, notice: str | None
) -> None:
    """Adding, removing or moving any line that is not an assistant line changes no id and no count."""
    with tempfile.TemporaryDirectory() as scratch:
        texts = []
        for extra in (first, second):
            lines = [assistant(a) for a in answers]
            for line in extra:
                lines.insert(rnd.randint(0, len(lines)), line)
            texts.append("".join(line + "\n" for line in lines))
        for text in texts:
            path = write(Path(scratch), text)
            assert as_lists(runner().model_ids(path, notice)) == ids_of(answers, notice)


# Behaviour 1: decisions in the manifest's order, nothing after a stop


@pytest.mark.parametrize(
    ("kind", "searcher", "decision", "markets"),
    [("earn", False, "claim", 9), ("miss", True, "futility", 6), ("miss", False, "undecided", 100)],
)
def test_stub_outcomes_give_step_6s_decisions_and_no_session_runs_after_the_stop(
    kind: str, searcher: bool, decision: str, markets: int
) -> None:
    g100 = [searcher] * len(IDS)
    script = [kind] * len(IDS)
    with study(g100, script) as root:
        first = go(root)
        assert violations(first) == []
        assert first.lines and first.lines[-1]["decision"] == decision
        assert [project(line) for line in first.lines] == expected(g100, script)
        assert len(first.lines) == markets
        assert len(sessions(first)) == markets
        text = transcript(KINDS[kind].answers, KINDS[kind].event_at)
        for n, line in enumerate(first.lines):
            assert line["run"] == run_record(n, kind, IDS[n], sha256(text.encode()))
        again = go(root)
        assert len(sessions(again)) == markets
        assert again.lines == first.lines


def test_decisions_follow_a_mixed_sequence_in_the_manifests_order() -> None:
    script = ["earn", "miss", "fallback", "nopick", "mixed", "earn", "miss", "earn", "earn", "earn", "earn"] * 4
    g100 = [i % 3 == 1 for i in range(len(IDS))]
    with study(g100, script) as root:
        d = go(root)
        assert [project(line) for line in d.lines] == expected(g100, script)
        wins = losses = 0
        for index, line in enumerate(d.lines):
            assert line["id"] == IDS[index]
            assert line["outcome"] == outcome(bool(line["agent_earns"]), g100[index])
            wins += line["outcome"] == "win"
            losses += line["outcome"] == "loss"
            assert line["decision"] == decide(wins, losses, index + 1)


# Behaviour 2: voids


def test_a_void_is_rerun_on_the_same_market_and_has_no_result_line() -> None:
    g100 = [False] * len(IDS)
    script = ["empty", "miss", "earn"]
    with study(g100, script) as root:
        d = go(root)
        assert violations(d) == []
        assert [c["id"] for c in sessions(d)[:3]] == [IDS[0], IDS[0], IDS[1]]
        assert (d.lines[0]["id"], d.lines[0]["pick"], d.lines[0]["agent_earns"]) == (IDS[0], "pick-1", False)
        assert [project_void(v) for v in d.voids] == [
            {"id": IDS[0], "models": [[ASKED, 1]], "ended": "crashed", "run": True}
        ]
        assert d.voids[0]["run"]["exit"] == 1
        assert 0 not in judged_sessions(d)


def test_a_void_session_is_kept_under_its_market() -> None:
    with study([False] * len(IDS), ["empty", "earn"]) as root:
        d = go(root)
        tokens = {p.read_text() for p in (root / "work" / "agent" / IDS[0]).rglob("token")}
        assert {"session-0", "session-1"} <= tokens
        assert violations(d) == []


def test_the_third_void_on_a_market_pauses_the_runner_and_a_restart_resumes_at_that_market() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "empty", "empty", "empty", "earn"]
    with study(g100, script) as root:
        first = go(root, restarts=1)
        assert first.exits == [0]
        assert [project(line) for line in first.lines][-1] == {"state": "paused", "id": IDS[1]}
        assert len(market_lines(first)) == 1
        assert len(sessions(first)) == 1 + MAX_VOIDS
        assert [v["id"] for v in first.voids] == [IDS[1]] * MAX_VOIDS
        second = go(root, restarts=1)
        assert sessions(second)[1 + MAX_VOIDS]["id"] == IDS[1]
        assert market_lines(second)[1]["id"] == IDS[1]
        assert market_lines(second)[1]["pick"] == f"pick-{1 + MAX_VOIDS}"


def test_a_restart_after_a_pause_gives_the_market_three_more_sessions() -> None:
    g100 = [False] * len(IDS)
    script = ["empty"] * 5 + ["earn"] * 9
    with study(g100, script) as root:
        go(root, restarts=1)
        second = go(root, restarts=1)
        assert [c["id"] for c in sessions(second)[:6]] == [IDS[0]] * 6
        assert len(sessions(second)) == 14
        assert [line.get("state") for line in second.lines[:1]] == ["paused"]
        assert (second.lines[1]["id"], second.lines[1]["pick"]) == (IDS[0], "pick-5")


# Behaviour 3: which sessions count


def test_a_crash_after_an_evaluation_is_judged_a_crash_before_one_is_void_and_a_zero_exit_without_one_is_a_miss() -> (
    None
):
    g100 = [False] * len(IDS)
    script = ["crash", "empty", "signal", "nopick", "turns", "wall"]
    with study(g100, script) as root:
        d = go(root)
        assert [c["id"] for c in sessions(d)[:6]] == [IDS[0], IDS[1], IDS[1], IDS[2], IDS[3], IDS[4]]
        assert [v["id"] for v in d.voids] == [IDS[1]]
        lines = market_lines(d)
        got = [(line["id"], line["ended"], line["pick"], line["agent_earns"]) for line in lines[:5]]
        assert got == [
            (IDS[0], "crashed", "pick-0", True),
            (IDS[1], "crashed", "pick-2", False),
            (IDS[2], "finished", None, False),
            (IDS[3], "turn limit", "pick-4", True),
            (IDS[4], "wall time", "pick-5", False),
        ]
        assert lines[0]["evaluations"] == 4 and lines[2]["evaluations"] == 0
        assert lines[0]["run"]["exit"] == 1


# Behaviour 4: the model


def test_sessions_answered_by_either_served_id_or_both_are_judged_with_their_ids_and_counts() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "fallback", "mixed", "notice"] + ["earn"] * 5
    with study(g100, script) as root:
        d = go(root)
        assert d.voids == [] and d.lines[-1]["decision"] == "claim"
        assert [line["models"] for line in d.lines[:4]] == [
            [[ASKED, 3]],
            [[FALLBACK, 3]],
            [[ASKED, 1], [FALLBACK, 3]],
            [[ASKED, 3]],
        ]


@pytest.mark.parametrize("event_at", [None, 0, 1, 99])
def test_the_fallback_event_changes_no_line_wherever_it_stands(event_at: int | None) -> None:
    """After the first responses, as the pilot's client wrote it; before them; last; absent."""
    g100 = [i % 4 == 0 for i in range(len(IDS))]
    script = ["fallback", "mixed", "earn", "miss"] * 6
    with study(g100, script, event_at=event_at) as root:
        d = go(root)
        projected = [project(line) for line in d.lines]
        for line in projected:
            line["run"] = None
        want = expected(g100, script)
        for line in want:
            line["run"] = None
        assert projected == want


@pytest.mark.parametrize("kind", ["foreign", "foreign-crash"])
def test_an_id_outside_served_ends_the_study_and_its_market_has_no_result_line_and_no_void_line(kind: str) -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn", "fallback", kind, "earn"]) as root:
        d = go(root)
        assert [line["id"] for line in market_lines(d)] == IDS[:2]
        last = d.lines[-1]
        assert (last["state"], last["id"]) == ("model changed", IDS[2])
        assert FOREIGN in [model for model, _ in last["models"]]
        assert d.voids == []
        assert len(sessions(d)) == 3
        assert 2 not in judged_sessions(d)
        again = go(root)
        assert len(sessions(again)) == 3
        assert again.lines == d.lines


# Behaviours 5 and 6: kills


@pytest.mark.parametrize("point", [("judge", 0), ("spent", 0), ("judge", 1), ("spent", 3)])
def test_killed_between_a_sessions_end_and_its_result_line(point: tuple[str, int]) -> None:
    """On restart the session is not run again, its pick is classified from the kept ledger, and one line is written."""
    g100 = [False] * len(IDS)
    script = ["earn"] * 9
    with study(g100, script, {point}) as root:
        d = go(root)
        assert d.exits[0] == -9
        assert [c["id"] for c in sessions(d)] == IDS[:9]
        assert [project(line) for line in d.lines] == expected(g100, script)
        assert judged_sessions(d) == set(range(9))
        assert d.voids == []


def test_killed_during_a_session_with_an_evaluation_is_judged_from_its_kept_ledger_and_not_rerun() -> None:
    g100 = [False] * len(IDS)
    script = ["earn"] * 12
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert d.exits[0] == -9
        assert [c["id"] for c in sessions(d)] == IDS[:9]
        line = d.lines[2]
        assert (line["id"], line["pick"], line["run"], line["ended"]) == (IDS[2], "pick-2", None, "killed")
        assert d.voids == []
        assert [project(line) for line in d.lines] == expected(g100, script, {("session", 2)})


def test_killed_during_a_session_without_an_evaluation_is_a_void_and_the_market_is_run_again() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "earn", "nopick"] + ["earn"] * 9
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert [c["id"] for c in sessions(d)[:4]] == [IDS[0], IDS[1], IDS[2], IDS[2]]
        assert [project_void(v) for v in d.voids] == [
            {"id": IDS[2], "models": [[ASKED, 2]], "ended": "killed", "run": False}
        ]
        assert d.lines[2]["pick"] == "pick-3"
        assert 2 not in judged_sessions(d)
        assert [project(line) for line in d.lines] == expected(g100, script, {("session", 2)})


# Behaviour 7: no market twice, results only appended


def test_a_market_with_a_result_line_is_never_run_again_and_results_is_only_appended() -> None:
    g100 = [i % 2 == 0 for i in range(len(IDS))]
    script = ["earn", "miss"] * 20
    kills = {("room", 2), ("room", 3), ("market", 6), ("room", 9)}
    with study(g100, script, kills) as root:
        d = go(root)
        assert d.exits.count(-9) == 4
        for before, after in zip(d.snapshots, d.snapshots[1:]):
            assert after.startswith(before)
        ids = [c["id"] for c in sessions(d)]
        assert len(ids) == len(set(ids))
        assert [project(line) for line in d.lines] == expected(g100, script)


# Behaviour 8: the session's working directory


def test_a_sessions_working_directory_holds_nothing_of_another_market_g100_or_the_audit_directory() -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["empty", "earn", "crash", "fallback", "earn"] * 3) as root:
        g100_ledger = root / "work" / "searcher" / IDS[0] / "ledger.sqlite"
        d = go(root)
        assert violations(d) == []
        assert g100_ledger.read_text() == "G100's ledger"


# Behaviours 9 and 10: verify first, and the early end


def test_verify_failing_stops_the_runner_before_any_session(tmp_path: Path) -> None:
    world(tmp_path / "s", [False] * len(IDS), ["earn"])
    fakes = Fakes(tmp_path / "s")

    def broken() -> Record:
        raise ValueError("gate/control/measure.py differs from the manifest")

    with pytest.raises(ValueError, match="measure.py"):
        runner().run(
            tmp_path / "s" / "out",
            tmp_path / "s" / "work",
            verify=broken,
            room=fakes.room,
            market=fakes.market,
            session=fakes.session,
            spent=fakes.spent,
            judge=fakes.judge,
        )
    assert calls(tmp_path / "s" / "ctl") == []
    assert not (tmp_path / "s" / "out" / "results.jsonl").exists()


def test_after_end_a_restart_launches_nothing() -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn", "miss"] * 10, room_limit=4) as root:
        before = go(root)
        assert len(sessions(before)) == 4
        assert len(before.lines) == 4
        runner().end(root / "out", verify=Fakes(root).verify)
        lines = jsonl(root / "out" / "results.jsonl")
        assert lines[:4] == before.lines
        assert project(lines[-1]) == {"state": "ended early", "markets": 4}
        settings_path = root / "ctl" / "settings.json"
        settings_value = json.loads(settings_path.read_text())
        settings_value["room_limit"] = None
        settings_path.write_text(json.dumps(settings_value))
        after = go(root)
        assert len(sessions(after)) == 4
        assert after.lines == lines


def test_no_room_starts_no_session_and_writes_no_line() -> None:
    with study([False] * len(IDS), ["earn"] * 9, room_limit=0) as root:
        d = go(root)
        assert sessions(d) == []
        assert d.lines == []


# Laws L8.1 to L8.6, over random scripts of sessions and random kill points

SCRIPTED = ["earn"] * 4 + ["miss"] * 4 + ["fallback"] * 3 + ["mixed", "notice", "nopick", "turns", "wall"]
SCRIPTED += ["crash", "signal", "empty", "empty", "foreign", "foreign-crash"]
scripts = st.lists(st.sampled_from(SCRIPTED), max_size=40)
searchers = st.lists(st.booleans(), min_size=len(IDS), max_size=len(IDS))
kill_sets = st.sets(st.tuples(st.sampled_from(EFFECTS), st.integers(0, 30)), max_size=6)


def observe(g100: list[bool], script: list[str], kills: set[tuple[str, int]]) -> Drive:
    with study(g100, script, kills) as root:
        d = go(root)
        assert violations(d) == []
        return d


def check_only_grows(d: Drive) -> None:
    final = d.snapshots[-1]
    for before, after in zip(d.snapshots, d.snapshots[1:]):
        assert after.startswith(before)
    for call in d.calls:
        size, digest = call["results"]
        assert hashlib.sha256(final[:size]).hexdigest() == digest, call


def check_order(d: Drive) -> None:
    ids = [line["id"] for line in market_lines(d)]
    assert ids == IDS[: len(ids)]
    final = d.snapshots[-1]
    for call in sessions(d):
        size = call["results"][0]
        then = [json.loads(line) for line in final[:size].splitlines()]
        judged = [line["id"] for line in then if is_market_line(line)]
        assert call["id"] == IDS[len(judged)], call


def check_recount(d: Drive, g100: list[bool]) -> None:
    wins = losses = 0
    for index, line in enumerate(market_lines(d)):
        assert line["searcher_earns"] == g100[index]
        assert line["outcome"] == outcome(bool(line["agent_earns"]), bool(line["searcher_earns"]))
        wins += line["outcome"] == "win"
        losses += line["outcome"] == "loss"
        assert (line["running_wins"], line["running_losses"]) == (wins, losses)
        assert line["decision"] == decide(wins, losses, index + 1)


def check_no_session_after_an_end(d: Drive) -> None:
    final = d.snapshots[-1]
    for call in sessions(d):
        size = call["results"][0]
        then = [json.loads(line) for line in final[:size].splitlines()]
        assert not any(ends_study(line) for line in then), call
    ending = [i for i, line in enumerate(d.lines) if ends_study(line)]
    assert ending in ([], [len(d.lines) - 1])


def check_accounting(d: Drive, slack: int = 0) -> None:
    """Every session launched is a market line, the model-changed line or a void. With `slack`, up to that many
    voids may stand for a session killed before it reached the session's first act (the fake's log)."""
    changed = [line for line in d.lines if line.get("state") == "model changed"]
    accounted = len(market_lines(d)) + len(changed) + len(d.voids)
    assert 0 <= accounted - len(sessions(d)) <= slack


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_1_results_only_grows(g100: list[bool], script: list[str], kills: set[tuple[str, int]]) -> None:
    check_only_grows(observe(g100, script, kills))


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_2_market_lines_follow_the_manifest_with_no_gap_and_no_market_twice(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    check_order(observe(g100, script, kills))


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_3_running_counts_and_decisions_are_a_recount_of_the_lines_above(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    check_recount(observe(g100, script, kills), g100)


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_4_no_session_starts_after_a_line_that_ends_the_study(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    check_no_session_after_an_end(observe(g100, script, kills))


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_5_a_kill_outside_a_session_changes_nothing_and_one_during_it_gives_a_void_or_its_ledgers_line(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    d = observe(g100, script, kills)
    lines, voids, launched = simulate(g100, script, killed_sessions(kills))
    assert [project(line) for line in d.lines] == [project(line) for line in lines]
    assert [project_void(v) for v in d.voids] == [project_void(v) for v in voids]
    assert len(sessions(d)) == launched


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_6_a_void_adds_no_result_line_and_every_session_is_a_line_a_void_or_the_model_change(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    d = observe(g100, script, kills)
    check_accounting(d)
    _, voids, _ = simulate(g100, script, killed_sessions(kills))
    assert not {v["session"] for v in voids} & judged_sessions(d)


@pytest.mark.parametrize("seed", range(8))
def test_l8_laws_hold_under_kills_at_random_moments(seed: int) -> None:
    """Kills land anywhere, inside the runner's own steps too; the laws that need no script hold all the same."""
    rng = random.Random(seed)
    g100 = [rng.random() < 0.3 for _ in IDS]
    script = [rng.choice(SCRIPTED) for _ in range(40)]
    with study(g100, script, pause_seconds=0.004) as root:
        d = go(root, restarts=400, kill_after=lambda: rng.uniform(0.0, 0.25))
        assert violations(d) == []
        check_only_grows(d)
        check_order(d)
        check_recount(d, g100)
        check_no_session_after_an_end(d)
        check_accounting(d, slack=d.exits.count(-9))
