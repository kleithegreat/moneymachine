"""Study 1, step 8: the runner (gate/control/runner.py), its behaviours and laws L8.1 to L8.8, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2, at ce7ff38. Written from the plan
before the code, by another model than the builder's. No agent session, kernel run or account check happens here:
every effect is a fake from `fakes.py`, and every kill is a SIGKILL of the process running the runner.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `run(out, work, *, verify, room, market, session, spent, judge) -> None`, keyword effects defaulting to the real
  ones (`fakes.py`'s docstring lists their signatures). `out` is `audit/control-1`'s stand-in: it holds
  `searcher.jsonl` (step 7) and receives `results.jsonl`. The manifest comes from `verify()`, which is called first
  and whose exception propagates; the runner takes `SERVED` and `NOTICE` from its "constants". `work` is the data
  root: everything of the agent's arm on market `m` (its market, run directory and ledger) lives under
  `work/agent/<m>`, and G100's arm under `work/searcher`. A session's campaign is its market's id. `room()` is called
  before every session; None ends the runner without a line. The runner learns a session's evaluations from `spent`
  and its pick from `judge`, and reads no ledger itself. A session that left no `run.json` in its workdir was killed.
- **An exit for a person** (behaviour 6) is a `RuntimeError` or a `SystemExit` out of `run`, whose message names the
  market and the cause: "crash" for a session that crashed, or the ids outside `SERVED`. It comes after that market's
  line, and nothing is written after it.
- `end(out, *, verify) -> None` is `--end`: it appends {"state": "ended early", "markets": <market lines>}.
- `model_ids(transcript, notice) -> list[tuple[str, int]]`: the plan's "model ids", each with its count of assistant
  lines, in order of first appearance; `notice` is the manifest's `NOTICE`, or None.
- A market line of `results.jsonl` holds "id", "run" (the run record, None for a killed session), "models" (the model
  ids as [id, count] pairs), "is_agent", "evaluations", "ended" (the run's `stopped` at a designed end, "crashed", or
  "killed"), "pick" (None for a session that is not the agent's), "reads", "pairs_won", "reference_median",
  "pick_median", "agent_earns", "searcher_earns" (from `searcher.jsonl`), "outcome", "running_wins",
  "running_losses" and "decision"; it has an "outcome" key and no "state" key. The only state line is
  {"state": "ended early", "markets": ...}.
- A kept ledger is read once no process's command line names it (behaviour 6): `fakes.kernel_standin` is such a
  process, with an evaluation still to commit when the runner dies."""

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

from gate.control.sequential import decide, outcome
from gate.control.tests.fakes import (
    ASKED,
    FALLBACK,
    FOREIGN,
    IDS,
    KINDS,
    NOTICE,
    STOPPED,
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
    run_record,
    sha256,
    simulate,
    stops_for_a_person,
    transcript,
    world,
)

LAW = settings(max_examples=15, deadline=None)
EFFECTS = ("room", "market", "session", "spent", "judge")


def runner() -> ModuleType:
    return importlib.import_module("gate.control.runner")


def go(root: Path, restarts: int = 120, kill_after: Callable[[], float] | None = None) -> Drive:
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
    lines, _ = simulate(g100, script, killed_sessions(kills or set()))
    return [project(line) for line in lines]


def as_lists(ids: list[tuple[str, int]]) -> list[list[Any]]:
    return [[model, count] for model, count in ids]


def check_stop_messages(d: Drive) -> None:
    """Each exit for a person names its market and its cause, and comes right after that market's line."""
    stopped = [snapshot for code, snapshot in zip(d.exits, d.snapshots) if code == STOPPED]
    assert len(stopped) == len(d.stops)
    for snapshot, message in zip(stopped, d.stops):
        last = json.loads(snapshot.splitlines()[-1])
        assert stops_for_a_person(last), last
        assert last["id"] in message, message
        if not last["is_agent"]:
            assert any(model in message for model, _ in last["models"] if model not in (ASKED, FALLBACK)), message
        else:
            assert "crash" in message.lower(), message


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
        for extra in (first, second):
            lines = [assistant(a) for a in answers]
            for line in extra:
                lines.insert(rnd.randint(0, len(lines)), line)
            path = write(Path(scratch), "".join(line + "\n" for line in lines))
            assert as_lists(runner().model_ids(path, notice)) == ids_of(answers, notice)


# Behaviours 1 and 2: decisions in the manifest's order, one session a market, nothing after a stop


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
        assert first.exits == [0]
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


def test_no_market_gets_a_second_session_whatever_its_session_did() -> None:
    g100 = [False] * len(IDS)
    script = ["empty", "crash", "nopick", "foreign", "foreign-crash", "signal", "late", "earn", "miss"] * 3
    with study(g100, script, {("session", 4), ("judge", 6), ("spent", 9)}) as root:
        d = go(root)
        ids = [c["id"] for c in sessions(d)]
        assert ids == IDS[: len(ids)]
        assert [line["id"] for line in market_lines(d)] == ids


# Behaviour 3: how a session ended


def test_a_crash_is_judged_on_its_ledger_a_crash_without_an_evaluation_is_a_miss_and_both_stop_for_a_person() -> None:
    g100 = [False] * len(IDS)
    script = ["crash", "empty", "signal", "nopick", "turns", "wall"]
    with study(g100, script) as root:
        d = go(root)
        assert [c["id"] for c in sessions(d)[:6]] == IDS[:6]
        lines = market_lines(d)
        got = [(line["id"], line["ended"], line["pick"], line["agent_earns"]) for line in lines[:6]]
        assert got == [
            (IDS[0], "crashed", "pick-0", True),
            (IDS[1], "crashed", None, False),
            (IDS[2], "crashed", "pick-2", False),
            (IDS[3], "finished", None, False),
            (IDS[4], "turn limit", "pick-4", True),
            (IDS[5], "wall time", "pick-5", False),
        ]
        assert (lines[0]["evaluations"], lines[1]["evaluations"], lines[3]["evaluations"]) == (4, 0, 0)
        assert lines[0]["run"]["exit"] == 1
        assert d.exits[:3] == [STOPPED] * 3
        assert len(d.stops) == 3
        check_stop_messages(d)
        assert [project(line) for line in d.lines] == expected(g100, script)


# Behaviour 4: the model


def test_sessions_answered_by_either_served_id_or_both_are_judged_with_their_ids_and_counts() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "fallback", "mixed", "notice"] + ["earn"] * 5
    with study(g100, script) as root:
        d = go(root)
        assert d.exits == [0] and d.lines[-1]["decision"] == "claim"
        assert [line["models"] for line in d.lines[:4]] == [
            [[ASKED, 3]],
            [[FALLBACK, 3]],
            [[ASKED, 1], [FALLBACK, 3]],
            [[ASKED, 3]],
        ]
        assert all(line["is_agent"] for line in d.lines)


@pytest.mark.parametrize("event_at", [None, 0, 1, 99])
def test_the_fallback_event_changes_no_line_wherever_it_stands(event_at: int | None) -> None:
    """After the first responses, as the pilot's client wrote it; before them; last; absent."""
    g100 = [i % 4 == 0 for i in range(len(IDS))]
    script = ["fallback", "mixed", "earn", "miss"] * 6
    with study(g100, script, event_at=event_at) as root:
        d = go(root)
        projected = [project(line) for line in d.lines]
        want = expected(g100, script)
        for line in projected + want:
            line["run"] = None
        assert projected == want


@pytest.mark.parametrize("kind", ["foreign", "foreign-crash"])
def test_a_session_with_an_unnamed_id_is_a_miss_its_line_holds_the_ids_and_the_runner_stops_for_a_person(
    kind: str,
) -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn", "fallback", kind, "earn"]) as root:
        d = go(root)
        line = market_lines(d)[2]
        assert (line["id"], line["is_agent"], line["pick"], line["agent_earns"]) == (IDS[2], False, None, False)
        assert FOREIGN in [model for model, _ in line["models"]]
        assert line["outcome"] == "concordant" and line["decision"] == "continue"
        assert 2 not in judged_sessions(d)
        assert d.exits[0] == STOPPED
        check_stop_messages(d)
        assert [c["id"] for c in sessions(d)[:4]] == IDS[:4]
        assert market_lines(d)[3]["id"] == IDS[3]


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


def test_killed_during_a_session_with_an_evaluation_is_judged_from_its_kept_ledger_and_not_rerun() -> None:
    g100 = [False] * len(IDS)
    script = ["earn"] * 12
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert d.exits == [-9, 0]
        assert [c["id"] for c in sessions(d)] == IDS[:9]
        line = d.lines[2]
        assert (line["id"], line["pick"], line["run"], line["ended"]) == (IDS[2], "pick-2", None, "killed")
        assert [project(line) for line in d.lines] == expected(g100, script, {("session", 2)})


def test_a_killed_sessions_ledger_is_read_only_after_its_kernel_process_has_committed_and_exited() -> None:
    """G1: the stand-in for `mm eval -` still has the session's one evaluation to commit, 1.5 s after the runner dies.
    The restart starts at once; its line is the line of the ledger after the commit."""
    g100 = [False] * len(IDS)
    script = ["earn", "earn", "slow"] + ["earn"] * 9
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert d.exits == [-9, 0]
        line = d.lines[2]
        assert (line["id"], line["ended"], line["evaluations"], line["pick"], line["agent_earns"]) == (
            IDS[2],
            "killed",
            1,
            "pick-2",
            True,
        )
        reads = [c for c in d.calls if c["kind"] in ("spent", "judge") and IDS[2] in str(c.get("ledger", ""))]
        assert all(c["kind"] != "judge" or c["evaluations"] == 1 for c in reads)
        assert [project(line) for line in d.lines] == expected(g100, script, {("session", 2)})


def test_killed_during_a_session_without_an_evaluation_is_a_miss_and_the_next_market_follows() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "earn", "nopick"] + ["earn"] * 9
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert d.exits == [-9, 0]
        assert [c["id"] for c in sessions(d)[:4]] == IDS[:4]
        line = d.lines[2]
        assert (line["id"], line["ended"], line["run"], line["pick"], line["agent_earns"]) == (
            IDS[2],
            "killed",
            None,
            None,
            False,
        )
        assert [project(line) for line in d.lines] == expected(g100, script, {("session", 2)})


def test_a_killed_session_not_the_agents_is_a_miss_and_stops_for_a_person() -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn", "foreign", "earn"], {("session", 1)}) as root:
        d = go(root)
        assert d.exits[:2] == [-9, STOPPED]
        line = d.lines[1]
        assert (line["ended"], line["is_agent"], line["agent_earns"]) == ("killed", False, False)
        check_stop_messages(d)


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


# Laws L8.1 to L8.6 and L8.8, over random scripts of sessions and random kill points

SCRIPTED = ["earn"] * 4 + ["miss"] * 4 + ["fallback"] * 3 + ["mixed", "notice", "nopick", "turns", "wall"]
SCRIPTED += ["crash", "signal", "empty", "foreign", "foreign-crash", "late"]
scripts = st.lists(st.sampled_from(SCRIPTED), max_size=40)
searchers = st.lists(st.booleans(), min_size=len(IDS), max_size=len(IDS))
kill_sets = st.sets(st.tuples(st.sampled_from(EFFECTS), st.integers(0, 30)), max_size=6)


def observe(g100: list[bool], script: list[str], kills: set[tuple[str, int]]) -> Drive:
    with study(g100, script, kills) as root:
        d = go(root)
        assert violations(d) == []
        assert d.exits[-1] == 0
        return d


def check_only_grows(d: Drive) -> None:
    final = d.snapshots[-1]
    for before, after in zip(d.snapshots, d.snapshots[1:]):
        assert after.startswith(before)
    for call in d.calls:
        size, digest = call["results"]
        assert hashlib.sha256(final[:size]).hexdigest() == digest, call


def then(d: Drive, call: Record) -> list[Record]:
    """The lines of `results.jsonl` when the fakes saw `call`."""
    return [json.loads(line) for line in d.snapshots[-1][: call["results"][0]].splitlines()]


def check_order(d: Drive) -> None:
    ids = [line["id"] for line in market_lines(d)]
    assert ids == IDS[: len(ids)]
    for call in sessions(d):
        judged = [line["id"] for line in then(d, call) if is_market_line(line)]
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
    for call in sessions(d):
        assert not any(ends_study(line) for line in then(d, call)), call
    ending = [i for i, line in enumerate(d.lines) if ends_study(line)]
    assert ending in ([], [len(d.lines) - 1])


def check_one_session_a_market(d: Drive, slack: int = 0) -> None:
    """Each session starts when every earlier one has its line, and at the end each session has one. With `slack`, up
    to that many lines may stand for a session killed before it reached the fake's first act."""
    for n, call in enumerate(sessions(d)):
        judged = len([line for line in then(d, call) if is_market_line(line)])
        assert 0 <= judged - n <= slack, call
    assert 0 <= len(market_lines(d)) - len(sessions(d)) <= slack


def check_misses(d: Drive) -> None:
    for line in market_lines(d):
        if not line["is_agent"] or line["pick"] is None:
            assert line["agent_earns"] is False, line


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
def test_l8_5_a_kill_outside_a_session_changes_no_line_and_one_during_it_gives_its_kept_ledgers_line(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    d = observe(g100, script, kills)
    lines, stops = simulate(g100, script, killed_sessions(kills))
    assert [project(line) for line in d.lines] == [project(line) for line in lines]
    assert len(d.stops) == len(stops)
    check_stop_messages(d)


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_6_every_session_launched_is_one_market_line_or_the_one_in_flight(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    check_one_session_a_market(observe(g100, script, kills))


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_8_a_line_whose_session_is_not_the_agents_or_has_no_pick_says_the_agent_does_not_earn(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    check_misses(observe(g100, script, kills))


@pytest.mark.parametrize("seed", range(8))
def test_l8_laws_hold_under_kills_at_random_moments(seed: int) -> None:
    """Kills land anywhere, inside the runner's own steps and while a kernel stand-in still commits; the laws that need
    no script hold all the same."""
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
        check_one_session_a_market(d, slack=d.exits.count(-9))
        check_misses(d)
        check_stop_messages(d)
