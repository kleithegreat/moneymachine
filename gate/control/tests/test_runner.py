"""Study 1, step 8: the runner (gate/control/runner.py), its behaviours and laws L8.1 to L8.6, from
audit/program/briefs/1-positive-control.md and audit/program/architecture.md 5.2. Written from the plan before the code,
by another model than the builder's. No agent session, kernel run or account check happens here: every effect is a fake
from `fakes.py`, and every kill is a SIGKILL of the process running the runner.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `run(out, work, *, verify, room, market, session, spent, judge) -> None`, keyword effects defaulting to the real
  ones (`fakes.py`'s docstring lists their signatures). `out` is `audit/control-1`'s stand-in: it holds
  `searcher.jsonl` (step 7) and receives `results.jsonl` and `voids.jsonl`; the manifest comes from `verify()`, which
  is called first and whose exception propagates. `work` is the data root: everything of the agent's arm on market `m`
  (its market, run directories and ledgers, kept voids among them) lives under `work/agent/<m>`, and G100's arm under
  `work/searcher`. A session's campaign is its market's id. `room()` is called before every session; None ends the
  runner without a line. The runner reads a session's ledger only through `spent` and `judge`, and a session that left
  no `run.json` in its workdir did not end.
- `end(out, *, verify) -> None` is `--end`: it appends {"state": "ended early", "markets": <market lines>}.
- `model_ids(transcript) -> list[str]`: every model id that answered in the transcript (at least each assistant line's
  `message.model`), each once, in order of first appearance; lines that do not parse are skipped.
- A market line of `results.jsonl` holds "id", "run" (the run record), "models", "evaluations", "stopped", "pick",
  "pairs_won", "reference_median", "pick_median", "agent_earns", "searcher_earns" (from `searcher.jsonl`), "outcome",
  "running_wins", "running_losses" and "decision"; it has an "outcome" key and no "state" key. A state line has
  "state": "paused" or "model changed" with the market's "id" ("model changed" also with its "models"), or
  "ended early" with "markets". A line of `voids.jsonl` holds "id", "run", "evaluations" and "ledger", the path of
  the void session's kept ledger.
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

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from gate.control.constants import MAX_VOIDS
from gate.control.sequential import decide, outcome
from gate.control.tests.fakes import (
    BEHAVIOURS,
    FOREIGN,
    IDS,
    PINNED,
    Drive,
    Fakes,
    Record,
    behaviour_of,
    calls,
    drive,
    ends_study,
    evaluations,
    is_market_line,
    jsonl,
    project,
    run_record,
    sha256,
    simulate,
    transcript,
    world,
)

LAW = settings(max_examples=15, deadline=None)
KINDS = ("room", "market", "session", "spent", "judge")


def runner() -> ModuleType:
    return importlib.import_module("gate.control.runner")


def go(root: Path, restarts: int = 60, kill_after: Callable[[], float] | None = None) -> Drive:
    return drive(root, runner().run, restarts, kill_after)


@contextmanager
def study(
    g100: list[bool],
    script: list[str],
    kills: set[tuple[str, int]] | None = None,
    model: str = PINNED,
    room_limit: int | None = None,
    pause_seconds: float = 0.0,
) -> Iterator[Path]:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch) / "study"
        world(root, g100, script, kills or set(), model, room_limit, pause_seconds)
        yield root


def sessions(d: Drive) -> list[Record]:
    return [c for c in d.calls if c["kind"] == "session"]


def violations(d: Drive) -> list[object]:
    return [c["text"] for c in d.calls if c["kind"] == "violation"]


def market_lines(d: Drive) -> list[Record]:
    return [line for line in d.lines if is_market_line(line)]


def killed_sessions(kills: set[tuple[str, int]]) -> set[int]:
    return {n for kind, n in kills if kind == "session"}


def expected(g100: list[bool], script: list[str], kills: set[tuple[str, int]] | None = None) -> list[Record]:
    lines, _, _ = simulate(g100, script, killed_sessions(kills or set()))
    return [project(line) for line in lines]


# The model ids


def test_model_ids_of_a_session_answered_by_the_pinned_model(tmp_path: Path) -> None:
    path = tmp_path / "transcript.jsonl"
    path.write_text(transcript(PINNED, foreign=False))
    assert runner().model_ids(path) == [PINNED]


def test_model_ids_record_a_fallback_to_another_model(tmp_path: Path) -> None:
    """Stage 3's sessions show this case: Opus 5.5's safeguards refused, and every response came from Opus 4.8."""
    path = tmp_path / "transcript.jsonl"
    path.write_text(transcript(PINNED, foreign=True))
    ids = runner().model_ids(path)
    assert FOREIGN in ids
    assert len(ids) == len(set(ids))


def test_model_ids_skip_lines_that_do_not_parse_and_keep_the_order_of_first_appearance(tmp_path: Path) -> None:
    path = tmp_path / "transcript.jsonl"
    answers = ["model-b", "model-a", "model-b", "model-c"]
    text = "not json\n" + "".join(
        json.dumps({"type": "assistant", "message": {"model": m, "content": []}}) + "\n" for m in answers
    )
    path.write_text(text + '{"type": "assistant", "message": {"mod')
    assert runner().model_ids(path) == ["model-b", "model-a", "model-c"]


# Behaviour 1: decisions in the manifest's order, nothing after a stop


@pytest.mark.parametrize(
    ("agent", "searcher", "decision", "markets"),
    [("earn", False, "claim", 9), ("miss", True, "futility", 6), ("miss", False, "undecided", 100)],
)
def test_stub_outcomes_give_step_6s_decisions_and_no_session_runs_after_the_stop(
    agent: str, searcher: bool, decision: str, markets: int
) -> None:
    g100 = [searcher] * len(IDS)
    script = [agent] * len(IDS)
    with study(g100, script) as root:
        first = go(root)
        assert violations(first) == []
        assert [line for line in first.lines] and first.lines[-1]["decision"] == decision
        assert [project(line) for line in first.lines] == expected(g100, script)
        assert len(first.lines) == markets
        assert len(sessions(first)) == markets
        for n, line in enumerate(first.lines):
            text = transcript(PINNED, foreign=False)
            assert line["run"] == run_record(n, agent, IDS[n], sha256(text.encode()))
        again = go(root)
        assert len(sessions(again)) == markets
        assert again.lines == first.lines


def test_decisions_follow_a_mixed_sequence_in_the_manifests_order() -> None:
    script = ["earn", "miss", "earn", "nopick", "earn", "earn", "miss", "earn", "earn", "earn", "earn", "earn"] * 4
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


def test_a_void_is_rerun_on_the_same_market_and_its_outcome_is_not_in_results() -> None:
    g100 = [False] * len(IDS)
    script = ["crash", "miss", "earn"]
    with study(g100, script) as root:
        d = go(root)
        assert violations(d) == []
        assert [c["id"] for c in sessions(d)[:3]] == [IDS[0], IDS[0], IDS[1]]
        assert d.lines[0]["id"] == IDS[0]
        assert d.lines[0]["pick"] == "pick-1"
        assert d.lines[0]["agent_earns"] is False
        assert [v["id"] for v in d.voids] == [IDS[0]]
        assert d.voids[0]["evaluations"] == evaluations(0)
        judged = {c["session"] for c in d.calls if c["kind"] == "judge"}
        assert 0 not in judged


def test_a_void_session_is_kept_with_its_ledger() -> None:
    with study([False] * len(IDS), ["signal", "earn"]) as root:
        d = go(root)
        kept = Path(str(d.voids[0]["ledger"]))
        assert json.loads(kept.read_text())["session"] == 0
        assert kept.is_relative_to(root / "work" / "agent" / IDS[0])
        tokens = {p.read_text() for p in (root / "work" / "agent" / IDS[0]).rglob("token")}
        assert {"session-0", "session-1"} <= tokens
        assert violations(d) == []


def test_the_third_void_on_a_market_pauses_the_runner_and_a_restart_resumes_at_that_market() -> None:
    g100 = [False] * len(IDS)
    script = ["earn", "crash", "signal", "crash", "earn"]
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
    script = ["crash"] * 5 + ["earn"] * 9
    with study(g100, script) as root:
        go(root, restarts=1)
        second = go(root, restarts=1)
        assert [c["id"] for c in sessions(second)[:6]] == [IDS[0]] * 6
        assert len(sessions(second)) == 14
        assert [line.get("state") for line in second.lines[:1]] == ["paused"]
        assert second.lines[1]["id"] == IDS[0]
        assert second.lines[1]["pick"] == "pick-5"


# Behaviour 3: a crash with evaluations is void; the turn limit and the wall time are judged


def test_a_crashed_session_with_evaluations_is_void_and_a_turn_limit_or_wall_time_session_is_judged() -> None:
    g100 = [False] * len(IDS)
    script = ["crash", "turns", "wall", "signal", "turns"]
    with study(g100, script) as root:
        d = go(root)
        assert [v["id"] for v in d.voids] == [IDS[0], IDS[2]]
        lines = market_lines(d)
        assert (lines[0]["id"], lines[0]["stopped"], lines[0]["agent_earns"]) == (IDS[0], "turn limit", True)
        assert (lines[1]["id"], lines[1]["stopped"], lines[1]["agent_earns"]) == (IDS[1], "wall time", False)
        assert (lines[2]["id"], lines[2]["pick"]) == (IDS[2], "pick-4")


def test_a_session_ending_by_its_own_choice_with_no_pick_is_a_miss() -> None:
    g100 = [True] + [False] * (len(IDS) - 1)
    with study(g100, ["nopick", "earn"]) as root:
        d = go(root)
        assert (d.lines[0]["pick"], d.lines[0]["agent_earns"], d.lines[0]["outcome"]) == (None, False, "loss")
        assert d.voids == []


# Behaviour 4: the model


def test_a_foreign_model_stops_the_study_and_its_market_has_no_result_line() -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn", "earn", "foreign", "earn"]) as root:
        d = go(root)
        assert [line["id"] for line in market_lines(d)] == IDS[:2]
        last = d.lines[-1]
        assert (last["state"], last["id"]) == ("model changed", IDS[2])
        assert FOREIGN in last["models"]
        assert len(sessions(d)) == 3
        again = go(root)
        assert len(sessions(again)) == 3
        assert again.lines == d.lines


def test_the_pinned_model_is_the_manifests() -> None:
    g100 = [False] * len(IDS)
    with study(g100, ["earn"] * 9, model="claude-test-pinned") as root:
        d = go(root)
        assert d.lines[-1]["decision"] == "claim"
        assert all(line["models"] == ["claude-test-pinned"] for line in d.lines)


# Behaviours 5 and 6: kills


@pytest.mark.parametrize("point", [("judge", 0), ("spent", 0), ("judge", 1)])
def test_killed_between_a_sessions_end_and_its_result_line(point: tuple[str, int]) -> None:
    """On restart the session is not run again, its pick is classified from the kept ledger, and one line is written."""
    g100 = [False] * len(IDS)
    script = ["earn"] * 9
    with study(g100, script, {point}) as root:
        d = go(root)
        assert d.exits[0] == -9
        assert len(sessions(d)) == 9
        assert [c["id"] for c in sessions(d)] == IDS[:9]
        assert [line["id"] for line in d.lines] == IDS[:9]
        assert [project(line) for line in d.lines] == expected(g100, script)
        judged = [c["session"] for c in d.calls if c["kind"] == "judge"]
        assert sorted(set(judged)) == list(range(9))
        assert d.voids == []


def test_killed_during_a_session_is_a_void_whatever_its_ledger_holds() -> None:
    g100 = [False] * len(IDS)
    script = ["earn"] * 12
    with study(g100, script, {("session", 2)}) as root:
        d = go(root)
        assert d.exits[0] == -9
        assert [v["id"] for v in d.voids] == [IDS[2]]
        assert json.loads(Path(str(d.voids[0]["ledger"])).read_text())["session"] == 2
        assert [c["id"] for c in sessions(d)][:4] == [IDS[0], IDS[1], IDS[2], IDS[2]]
        assert d.lines[2]["pick"] == "pick-3"
        assert 2 not in {c["session"] for c in d.calls if c["kind"] == "judge"}
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
    with study(g100, ["crash", "earn", "signal", "earn", "earn"] * 3) as root:
        g100_ledger = root / "work" / "searcher" / IDS[0] / "ledger.sqlite"
        d = go(root)
        assert violations(d) == []
        assert g100_ledger.read_text() == "G100's ledger"


# Behaviours 9 and 10: verify first, and the early end


def test_verify_failing_stops_the_runner_before_any_session(tmp_path: Path) -> None:
    world(tmp_path / "s", [False] * len(IDS), ["earn"])
    fakes = Fakes(tmp_path / "s")

    def broken() -> dict[str, object]:
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

SCRIPTED = ["earn"] * 4 + ["miss"] * 4 + ["nopick", "turns", "wall", "crash", "crash", "signal", "foreign"]
scripts = st.lists(st.sampled_from(SCRIPTED), max_size=40)
searchers = st.lists(st.booleans(), min_size=len(IDS), max_size=len(IDS))
kill_sets = st.sets(st.tuples(st.sampled_from(KINDS), st.integers(0, 30)), max_size=6)


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
def test_l8_5_kills_outside_a_session_change_no_line_and_a_kill_during_one_adds_one_void(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    d = observe(g100, script, kills)
    lines, voids, launched = simulate(g100, script, killed_sessions(kills))
    assert [project(line) for line in d.lines] == [project(line) for line in lines]
    assert [(v["id"], v["evaluations"]) for v in d.voids] == [(v["id"], v["evaluations"]) for v in voids]
    assert len(sessions(d)) == launched


@LAW
@given(searchers, scripts, kill_sets)
def test_l8_6_a_void_adds_no_result_line_and_every_session_is_a_line_or_a_void(
    g100: list[bool], script: list[str], kills: set[tuple[str, int]]
) -> None:
    d = observe(g100, script, kills)
    check_accounting(d)
    void_sessions = {n for n in range(len(sessions(d))) if n in killed_sessions(kills)} | {
        n
        for n in range(len(sessions(d)))
        if n not in killed_sessions(kills) and BEHAVIOURS[behaviour_of(script, n)].exit not in (0, -9)
    }
    judged = {line.get("pick") for line in market_lines(d)}
    assert not {f"pick-{n}" for n in void_sessions} & judged


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
