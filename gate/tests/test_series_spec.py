"""Spec-only examples: C3.2 v3, C4.5 v3, NULLS and campaigns' public docstrings.

No production bodies, prior tests, live logs or market data were read. Campaigns
are synthetic and models, canaries and kernel execution are replaced at boundaries.
The old-version pacing exclusion and the newer sibling-family docstring conflict;
cross-version pooling is deliberately not adjudicated here.
"""

import json
import os
import signal
import subprocess
import sys
import threading
from collections.abc import Iterable
from pathlib import Path
from typing import Any, Never

import pytest

from gate.agent import campaigns as series


def run(stopped: str = "finished", exit: int = 0) -> dict[str, Any]:
    """Session wire shape only; expected crash accounting comes from C3.2."""
    return {"stopped": stopped, "exit": exit}


@pytest.mark.parametrize(
    "record,expected",
    [
        ({}, True),
        (run(), False),
        (run(exit=1), True),
        (run(exit=-9), True),
        (run("turn limit"), False),
        (run("wall time"), False),
    ],
)
def test_c32_crashes_versus_designed_ends(record: dict[str, Any], expected: Any) -> None:
    assert series.crashed(record) is expected


@pytest.mark.parametrize(
    "promoted,runs,evaluations,expected",
    [
        (False, [run()], [1], False),
        (False, [run()], [0], True),
        (False, [{}], [1], True),
        (False, [run(exit=1)], [1], True),
        (True, [run()], [1], True),
        (False, [run("turn limit")], [1], False),
        (False, [run("wall time")], [1], False),
    ],
)
def test_c32_no_evaluation_or_crash_counts_even_without_a_promotion(
    promoted: bool, runs: list[dict[str, Any]], evaluations: list[int], expected: Any
) -> None:
    assert series.counts(promoted, runs, evaluations) is expected


def agent(
    evaluations: int = 1, received: bool = True, holds: bool = True, record: dict[str, Any] | None = None
) -> series.AgentOutcome:
    """Four agent_evidence records are the swarm_class interface, not simulated ledgers."""
    return series.AgentOutcome(
        evaluations=evaluations, received=received, holds=holds, run=run() if record is None else record
    )


def test_swarm_established_needs_only_two_evaluations_not_the_obsolete_floor() -> None:
    """1+1+0+0=2, far below 200, establishes v3 if a filled trial and history exist."""
    agents = [agent(), agent(), agent(0, False), agent(0, False, record=run(exit=1))]
    assert series.swarm_class([], None, agents, 1, True) == "established"


@pytest.mark.parametrize(
    "trials,history,agents,expected",
    [
        (0, True, [agent(), agent(), agent(0, False), agent(0, False)], "not established"),
        (1, False, [agent(), agent(), agent(0, False), agent(0, False)], "not established"),
        (1, True, [agent(), agent(0, False), agent(0, False), agent(0, False)], "not established"),
        (0, False, [agent(0, False)] * 4, "not established"),
        (1, True, [agent(holds=False)] + [agent()] * 3, "unresolved"),
        (1, True, [agent(record=run(exit=1))] + [agent()] * 3, "unresolved"),
        (1, True, [agent(record={})] + [agent()] * 3, "unresolved"),
    ],
)
def test_swarm_evidence_boundaries(trials: Any, history: Any, agents: list[series.AgentOutcome], expected: str) -> None:
    assert series.swarm_class([], None, agents, trials, history) == expected


def test_swarm_gate_failure_is_unresolved_but_promotion_dominates() -> None:
    agents = [agent()] * 4
    assert series.swarm_class([], "holdout did not complete", agents, 1, True) == "unresolved"
    assert series.swarm_class(["h"], "holdout did not complete", [], 0, False) == "promoted"


def test_missing_agent_evidence_is_unresolved() -> None:
    """Three valid records cannot establish the declared four-agent campaign."""
    assert series.swarm_class([], None, [agent()] * 3, 1, True) == "unresolved"


@pytest.mark.parametrize(
    "classes,expected",
    [
        ([], "not established"),
        (["established"] * 9, "not established"),
        (["established"] * 10, "pass"),
        (["established"] * 9 + ["promoted"], "pass"),
        (["established"] * 9 + ["unresolved"], "pass"),
        (["established"] * 9 + ["not established"], "pass"),
        (["established"] * 8 + ["not established"] * 2, "not established"),
        (["established"] * 8 + ["promoted", "not established"], "pass"),
        (["established"] * 8 + ["promoted", "unresolved"], "failed"),
        (["unresolved"] * 2, "failed"),
        (["promoted"] * 2, "failed"),
    ],
)
def test_swarm_verdict_thresholds_and_failed_precedence(classes: list[str], expected: Any) -> None:
    """Ten required, at most one adverse and one 'not established' class; two adverse fail."""
    assert series.swarm_verdict(classes) == expected


def test_declared_ids_are_exact_fresh_v3_cohorts(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """C3.2 has 20 IDs, C4.5 has 10; NULLS forbids recycling an older version's seed IDs."""
    monkeypatch.setattr(series, "OUT", tmp_path)
    for name, prefix, size in [("agent", "agent-null-3", 20), ("swarm", "swarm-null-3", 10)]:
        ids, log = series.cohort(name)
        assert ids == [f"{prefix}-N2-{n}" for n in range(size)]
        assert Path(log).name == f"{prefix}.jsonl"


def usage_row(before: dict[str, Any], after: dict[str, Any], account: str = "TAMU", tokens: int = 1) -> dict[str, Any]:
    """One token-bearing campaign and the two probes of its account's usage windows."""
    return {"account": account, "usage": {"input_tokens": tokens}, "windows": {"before": before, "after": after}}


def log_rows(path: Path, rows: Iterable[dict[str, Any]]) -> Path:
    path.write_text("".join(json.dumps(row) + "\n" for row in rows))
    return path


def test_need_empty_or_no_token_campaign_measures_nothing(tmp_path: Path) -> None:
    log = tmp_path / "swarm-null-3.jsonl"
    assert series.need(log) == {}
    log_rows(log, [usage_row({"w": [0.0, "r"]}, {"w": [0.75, "r"]}, tokens=0)])
    assert series.need(log) == {}


def test_need_uses_max_not_sum_across_accounts_and_ignores_reset_crossings(tmp_path: Path) -> None:
    """Deltas 1/8 and 3/8 yield 3/8, not 1/2; a changed reset measures neither."""
    log = log_rows(
        tmp_path / "swarm-null-3.jsonl",
        [
            usage_row({"w": [0.125, "r"], "week": [0.25, "s"]}, {"w": [0.25, "r"], "week": [0.5, "s"]}),
            usage_row({"w": [0.25, "r"]}, {"w": [0.625, "r"]}, "Cornell"),
            usage_row({"w": [0.0, "old"]}, {"w": [0.75, "new"]}),
            usage_row({"w": [0.0, "r"]}, {"w": [0.75, "r"]}, tokens=0),
        ],
    )
    assert series.need(log) == {"w": 0.375, "week": 0.25}


def test_need_ties_and_missing_probes_do_not_create_measurements(tmp_path: Path) -> None:
    """Two equal deltas of 1/8 still reserve 1/8; a one-sided probe measures nothing."""
    log = log_rows(
        tmp_path / "swarm-null-3.jsonl",
        [
            usage_row({"w": [0.0, "r"]}, {"w": [0.125, "r"]}),
            usage_row({"w": [0.25, "r"]}, {"w": [0.375, "r"]}),
            usage_row({}, {"week": [0.75, "s"]}),
            usage_row({"week": [0.0, "s"]}, {}),
        ],
    )
    assert series.need(log) == {"w": 0.125}


@pytest.fixture
def pacing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, threading.Event]:
    """Fresh stop signal and fake account tokens; never probe a real subscription."""
    stop = threading.Event()
    monkeypatch.setattr(series, "STOP", stop)
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_TAMU", "synthetic-tamu")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "synthetic-cornell")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "synthetic-original")
    return tmp_path / "swarm-null-3.jsonl", stop


@pytest.mark.parametrize(
    "tamu,cornell,expected",
    [
        (0.25, 0.25, "TAMU"),
        (0.3, 0.1, "TAMU"),
        (0.300001, 0.3, "Cornell"),
    ],
)
def test_first_need_half_and_ceiling_point_eight_include_exact_ties(
    pacing: tuple[Path, threading.Event], monkeypatch: pytest.MonkeyPatch, tamu: float, cornell: float, expected: str
) -> None:
    """FIRST_NEED=0.5: 0.3+0.5=0.8 fits, but 0.300001+0.5 does not; TAMU wins ties."""
    log, _ = pacing
    probes = {"synthetic-tamu": {"w": [tamu, "r"]}, "synthetic-cornell": {"w": [cornell, "r"]}}
    monkeypatch.setattr(series, "windows", lambda token=None: probes[token])
    room = series.wait_for_room(log)
    assert room is not None
    account, windows = room
    assert account == expected
    assert windows == probes["synthetic-" + expected.lower()]
    assert os.environ["CLAUDE_CODE_OAUTH_TOKEN"] == "synthetic-" + expected.lower()


def test_all_windows_must_fit_and_measured_need_replaces_first_need(
    pacing: tuple[Path, threading.Event], monkeypatch: pytest.MonkeyPatch
) -> None:
    """Measured w=1/8 permits 0.625; unmeasured week needs 1/2 and blocks TAMU's 0.31."""
    log, _ = pacing
    log_rows(log, [usage_row({"w": [0.125, "r"]}, {"w": [0.25, "r"]})])
    probes = {
        "synthetic-tamu": {"w": [0.625, "r"], "week": [0.31, "s"]},
        "synthetic-cornell": {"w": [0.625, "r"], "week": [0.25, "s"]},
    }
    monkeypatch.setattr(series, "windows", lambda token=None: probes[token])
    assert series.wait_for_room(log) == ("Cornell", probes["synthetic-cornell"])


def test_failed_probe_cannot_select_an_account_and_stop_interrupts_wait(
    pacing: tuple[Path, threading.Event], monkeypatch: pytest.MonkeyPatch
) -> None:
    log, stop = pacing

    def unavailable(token: str | None = None) -> None:
        stop.set()
        return None

    monkeypatch.setattr(series, "windows", unavailable)
    assert series.wait_for_room(log) is None
    assert os.environ["CLAUDE_CODE_OAUTH_TOKEN"] == "synthetic-original"


def test_already_stopped_never_probes_an_account(
    pacing: tuple[Path, threading.Event], monkeypatch: pytest.MonkeyPatch
) -> None:
    log, stop = pacing
    stop.set()

    def forbidden(*args: Any) -> None:
        pytest.fail("a stopped series must not make a model call")

    monkeypatch.setattr(series, "windows", forbidden)
    assert series.wait_for_room(log) is None


@pytest.fixture
def synthetic_series(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[list[str], Path]:
    """One injected cohort; inputs, canary and kernel checks cannot touch live resources."""
    monkeypatch.setattr(series, "OUT", tmp_path)
    monkeypatch.setattr(series, "STOP", threading.Event())
    ids = ["agent-null-3-N2-0", "agent-null-3-N2-1"]
    log = tmp_path / "agent-null-3.jsonl"
    monkeypatch.setattr(series, "cohort", lambda name: (ids, log))
    monkeypatch.setattr(series, "series_inputs", lambda: {"mm": "synthetic-kernel"})
    monkeypatch.setattr(series, "check_frozen", lambda *args: None)
    monkeypatch.setattr(series, "ready", lambda log: ("TAMU", {"w": [0.0, "r"]}))
    monkeypatch.setattr(series, "windows", lambda *args: {"w": [0.125, "r"]})
    monkeypatch.setattr(series, "usage", lambda *args: {"input_tokens": 1})
    return ids, log


def test_started_unrecorded_is_counted_crash_and_never_rerun(
    synthetic_series: tuple[list[str], Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Directory 0 started and died; only campaign 1 may execute, even on the next resume."""
    ids, log = synthetic_series
    (tmp_path / ids[0]).mkdir()
    called = []

    def complete(cid: str, inputs: Any) -> dict[str, Any]:
        assert (tmp_path / cid).is_dir()
        called.append(cid)
        return {"id": cid, "promoted": False, "counts_as_promotion": False}

    monkeypatch.setitem(series.SERIES, "agent", complete)
    series.run_series("agent")
    rows = [json.loads(line) for line in log.read_text().splitlines()]
    assert len(rows) == 2
    assert rows[0]["id"] == ids[0]
    assert rows[0]["counts_as_promotion"] is True
    assert rows[1]["counts_as_promotion"] is False
    assert called == [ids[1]]
    before = log.read_bytes()
    series.run_series("agent")
    assert log.read_bytes() == before
    assert called == [ids[1]]


def test_input_failure_starts_nothing(
    synthetic_series: tuple[list[str], Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ids, log = synthetic_series

    def missing() -> Never:
        raise FileNotFoundError("synthetic missing funding blob")

    monkeypatch.setattr(series, "series_inputs", missing)
    with pytest.raises(FileNotFoundError):
        series.run_series("agent")
    assert not any((tmp_path / cid).exists() for cid in ids)
    assert not log.exists()


def test_stop_before_ready_starts_nothing(
    synthetic_series: tuple[list[str], Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ids, log = synthetic_series
    monkeypatch.setattr(series, "ready", lambda log: None)
    series.run_series("agent")
    assert not any((tmp_path / cid).exists() for cid in ids)
    assert not log.exists() or not log.read_bytes()


def test_killed_series_recovers_started_id_without_running_it_again(tmp_path: Path) -> None:
    """SIGKILL inside the first campaign leaves its directory; restart counts it, not a retry."""
    setup = (
        "import sys,time,threading\nfrom pathlib import Path\n"
        "from gate.agent import campaigns as c\n"
        "c.OUT=Path(sys.argv[1]);c.STOP=threading.Event()\n"
        "ids=['agent-null-3-N2-0'];log=c.OUT/'agent-null-3.jsonl'\n"
        "c.cohort=lambda n:(ids,log)\nc.series_inputs=lambda:{'mm':'synthetic-kernel'}\n"
        "c.check_frozen=lambda *a:None\nc.ready=lambda p:('TAMU',{})\n"
        "c.windows=lambda *a:{}\nc.usage=lambda *a:{}\n"
    )
    child = subprocess.Popen(
        [
            sys.executable,
            "-c",
            setup
            + "def killed(cid,inputs):\n assert (c.OUT/cid).is_dir()\n print('STARTED',flush=True)\n time.sleep(60)\n"
            "c.SERIES['agent']=killed\nc.run_series('agent')\n",
            str(tmp_path),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "STARTED"
        child.kill()
        assert child.wait(timeout=10) == -signal.SIGKILL
    finally:
        if child.poll() is None:
            child.kill()
        child.communicate(timeout=10)
    resumed = subprocess.run(
        [
            sys.executable,
            "-c",
            setup + "def forbidden(*a):\n raise AssertionError('started campaign rerun')\n"
            "c.SERIES['agent']=forbidden\nc.run_series('agent')\n",
            str(tmp_path),
        ],
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert resumed.returncode == 0, resumed.stderr
    rows = [json.loads(line) for line in (tmp_path / "agent-null-3.jsonl").read_text().splitlines()]
    assert len(rows) == 1 and rows[0]["counts_as_promotion"] is True
