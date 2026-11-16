"""A torn result append must be recovered from the kept session, not block the verdict."""

import json
import multiprocessing
import os
import signal
from pathlib import Path
from typing import Any

import pytest

from gate.control import runner
from gate.control.tests.fakes import Fakes, IDS, calls, child, jsonl, world


def test_partial_ninth_result_recovers_the_claim_without_another_session(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "study"
    world(root, [False] * len(IDS), ["earn"] * 9, room_limit=9)
    original = runner.append

    def torn(path: Path, line: dict[str, Any]) -> None:
        if line.get("id") == IDS[8]:
            descriptor = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            os.write(descriptor, json.dumps(line).encode()[:40])
            os.kill(os.getpid(), signal.SIGKILL)
        original(path, line)

    monkeypatch.setattr(runner, "append", torn)
    process = multiprocessing.get_context("fork").Process(target=child, args=(root, runner.run))
    process.start()
    try:
        process.join(20)
        assert process.exitcode == -signal.SIGKILL
    finally:
        if process.is_alive():
            process.kill()
            process.join(10)
    monkeypatch.setattr(runner, "append", original)
    effects = Fakes(root)
    runner.run(
        effects.out,
        effects.work,
        verify=effects.verify,
        room=effects.room,
        market=effects.market,
        session=effects.session,
        spent=effects.spent,
        judge=effects.judge,
    )
    lines = jsonl(effects.out / "results.jsonl")
    assert [line["id"] for line in lines] == IDS[:9]
    assert lines[-1]["decision"] == "claim"
    assert len([call for call in calls(effects.ctl) if call["kind"] == "session"]) == 9
