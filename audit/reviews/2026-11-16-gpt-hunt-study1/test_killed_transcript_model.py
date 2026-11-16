"""A killed session must not turn an unserved model's evaluated pick into the agent's win."""

import json
import multiprocessing
import os
import signal
from pathlib import Path
from typing import Any

import pytest

from gate.control import runner
from gate.control.tests.fakes import FOREIGN, IDS, NOTICE, SERVED, STRENGTH, judgement
from sandbox import session


def test_kill_keeps_the_model_of_a_response_that_already_evaluated(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    context = multiprocessing.get_context("fork")
    checkpoint = context.Event()
    hold = context.Event()
    own = tmp_path / "agent" / IDS[0]
    workdir = own / "run"
    workdir.mkdir(parents=True)
    ledger = own / "ledger.sqlite"

    class FakeProxy:
        def __init__(self, *args: Any) -> None:
            pass

        def close(self) -> None:
            pass

    class FakeCLI:
        returncode = 0

        def __init__(self, *args: Any, **kwargs: Any) -> None:
            self.stdout = self.lines()

        def lines(self) -> Any:
            yield json.dumps({"type": "assistant", "message": {"model": FOREIGN, "content": []}}) + "\n"
            ledger.write_text("committed evaluation from the response above")
            checkpoint.set()
            hold.wait(30)

        def wait(self) -> int:
            return 0

        def kill(self) -> None:
            pass

    monkeypatch.setattr(session, "Proxy", FakeProxy)
    monkeypatch.setattr(session, "claude_binary", lambda: "/synthetic/claude")
    monkeypatch.setattr(session, "sandbox_command", lambda *args: ["synthetic-cli"])
    monkeypatch.setattr(session.subprocess, "Popen", FakeCLI)
    process = context.Process(target=session.run, args=(workdir, "mm-agent", SERVED[0], 200, 60))
    process.start()
    try:
        assert checkpoint.wait(10), "the stub never reached its committed evaluation"
        assert process.pid is not None
        os.kill(process.pid, signal.SIGKILL)
        process.join(10)
        assert process.exitcode == -signal.SIGKILL
    finally:
        if process.is_alive():
            process.kill()
            process.join(10)

    assert ledger.exists()
    monkeypatch.setattr(runner, "wait_until_unnamed", lambda path: None)
    content = {"strength": STRENGTH, "constants": {"NOTICE": NOTICE, "SERVED": list(SERVED)}}
    line = runner.market_line(
        IDS[0],
        0,
        None,
        own,
        content,
        {IDS[0]: {"earns": False}},
        lambda *args: 1,
        lambda *args: judgement(0, "earn", 1),
    )
    assert (line["is_agent"], line["agent_earns"], line["outcome"]) == (False, False, "concordant")
