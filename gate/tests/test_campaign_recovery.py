import json
import signal
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

from gate import campaign, sweep
from gate.agent import campaigns
from ops import live

pytestmark = pytest.mark.local


@pytest.mark.parametrize("tail", [b'{"id":"interrupted",', b'{"id":"\xe2\x82'])
def test_killed_series_append_recovers_as_a_crash(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, tail: bytes) -> None:
    tmp_path = tmp_path / "app"
    tmp_path.mkdir()
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setitem(campaigns.COHORTS, "agent", ("recovery", 3))
    monkeypatch.setattr(campaigns, "series_inputs", lambda: {"mm": "test"})
    monkeypatch.setattr(campaigns, "ready", lambda _: ("test", {}))
    monkeypatch.setattr(campaigns, "check_frozen", lambda mm: None)
    monkeypatch.setattr(campaigns, "windows", lambda: {})
    ids, log = campaigns.cohort("agent")
    prefix = (json.dumps({"id": ids[0], "counts_as_promotion": False}) + "\n").encode()
    log.write_bytes(prefix)
    (tmp_path / ids[1]).mkdir()
    killed = subprocess.run(
        [
            sys.executable,
            "-c",
            "import os, signal, sys; f = os.open(sys.argv[1], os.O_WRONLY | os.O_APPEND); "
            "os.write(f, bytes.fromhex(sys.argv[2])); os.kill(os.getpid(), signal.SIGKILL)",
            str(log),
            tail.hex(),
        ]
    )
    assert killed.returncode == -signal.SIGKILL
    mirror = tmp_path.parent / "mirror"
    monkeypatch.setattr(live, "VOLUMES", {"agent": "."})
    live.mirror(tmp_path, mirror)
    started: list[str] = []

    def complete(cid: str, inputs: dict[str, Any]) -> dict[str, Any]:
        started.append(cid)
        return {"counts_as_promotion": False}

    monkeypatch.setitem(campaigns.SERIES, "agent", complete)

    campaigns.run_series("agent")

    raw = log.read_bytes()
    assert raw.startswith(prefix + tail + b"\n")
    rows = campaign.records(log)
    assert [r["id"] for r in rows] == ids
    assert rows[1]["counts_as_promotion"] and "interrupted" in rows[1]["crash"]
    assert started == ids[2:]
    live.mirror(tmp_path, mirror)
    live.verify(tmp_path, mirror)
    assert campaigns.need(log) == {}
    monkeypatch.setattr(sweep, "results", lambda _: [])
    summary = tmp_path / "summary.json"
    campaigns.summary("agent", summary)
    assert json.loads(summary.read_text())["ids"] == ids
    campaigns.run_series("agent")
    assert log.read_bytes() == raw and started == ids[2:]


def test_complete_final_result_without_newline_is_preserved(tmp_path: Path) -> None:
    log = tmp_path / "series.jsonl"
    row = {"id": "complete", "counts_as_promotion": False}
    log.write_text(json.dumps(row))
    (tmp_path / "interrupted").mkdir()
    with campaign.resume(["complete", "interrupted", "next"], log, tmp_path) as (todo, _):
        assert todo == ["next"]
    rows = [json.loads(line) for line in log.read_bytes().splitlines()]
    assert rows[0] == row and rows[1]["id"] == "interrupted" and rows[1]["counts_as_promotion"]


@pytest.mark.parametrize("corrupt", [b'{"broken":\n', b"\xff\n"])
def test_torn_records_are_ignored_without_changing_history(tmp_path: Path, corrupt: bytes) -> None:
    log = tmp_path / "series.jsonl"
    original = b'{"id":"complete"}\n' + corrupt + b'{"id":"later"}\n'
    log.write_bytes(original)
    with campaign.resume(["next"], log, tmp_path) as (todo, _):
        assert todo == ["next"]
    assert campaign.recorded(log) == {"complete", "later"}
    assert log.read_bytes() == original


def test_exclusive_is_only_a_lock(tmp_path: Path) -> None:
    log = tmp_path / "series.jsonl"
    original = b'{"id":"torn'
    log.write_bytes(original)
    with campaign.exclusive(log):
        assert log.read_bytes() == original
        with pytest.raises(RuntimeError, match="another run"), campaign.exclusive(log):
            pytest.fail("lock was not exclusive")
    assert log.read_bytes() == original
