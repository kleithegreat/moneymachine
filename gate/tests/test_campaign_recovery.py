import json
import signal
import subprocess
import sys

import pytest

from gate import campaign
from gate.agent import campaigns


@pytest.mark.parametrize("tail", [b'{"id":"interrupted",', b'{"id":"\xe2\x82'])
def test_killed_series_append_recovers_as_a_crash(tmp_path, monkeypatch, tail):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setitem(campaigns.COHORTS, "agent", ("recovery", 3))
    monkeypatch.setattr(campaigns, "series_inputs", lambda: {"mm": "test"})
    monkeypatch.setattr(campaigns, "ready", lambda _: ("test", {}))
    monkeypatch.setattr(campaigns, "check_frozen", lambda: None)
    monkeypatch.setattr(campaigns, "windows", lambda: {})
    ids, log = campaigns.cohort("agent")
    prefix = (json.dumps({"id": ids[0], "counts_as_promotion": False}) + "\n").encode()
    log.write_bytes(prefix)
    (tmp_path / ids[1]).mkdir()
    killed = subprocess.run([sys.executable, "-c",
                             "import os, signal, sys; f = os.open(sys.argv[1], os.O_WRONLY | os.O_APPEND); "
                             "os.write(f, bytes.fromhex(sys.argv[2])); os.kill(os.getpid(), signal.SIGKILL)",
                             str(log), tail.hex()])
    assert killed.returncode == -signal.SIGKILL
    started = []
    monkeypatch.setitem(campaigns.SERIES, "agent", lambda cid, _: started.append(cid) or {"counts_as_promotion": False})

    campaigns.run_series("agent")

    raw = log.read_bytes()
    rows = [json.loads(line) for line in raw.splitlines()]
    assert raw.startswith(prefix)
    assert [r["id"] for r in rows] == ids
    assert rows[1]["counts_as_promotion"] and "interrupted" in rows[1]["crash"]
    assert started == ids[2:]
    campaigns.run_series("agent")
    assert log.read_bytes() == raw and started == ids[2:]


def test_complete_final_result_without_newline_is_preserved(tmp_path):
    log = tmp_path / "series.jsonl"
    row = {"id": "complete", "counts_as_promotion": False}
    log.write_text(json.dumps(row))
    (tmp_path / "interrupted").mkdir()
    with campaign.resume(["complete", "interrupted", "next"], log, tmp_path) as todo:
        assert todo == ["next"]
    rows = [json.loads(line) for line in log.read_bytes().splitlines()]
    assert rows[0] == row and rows[1]["id"] == "interrupted" and rows[1]["counts_as_promotion"]


@pytest.mark.parametrize("corrupt", [b'{"broken":\n', b'\xff\n'])
def test_interior_corruption_is_refused_without_changing_the_log(tmp_path, corrupt):
    log = tmp_path / "series.jsonl"
    original = b'{"id":"complete"}\n' + corrupt + b'{"id":"later"}\n'
    log.write_bytes(original)
    with pytest.raises((ValueError, UnicodeError)):
        with campaign.resume(["next"], log, tmp_path):
            pytest.fail("corrupt history was accepted")
    assert log.read_bytes() == original
