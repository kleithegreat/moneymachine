"""The sandbox canary: its verdict on scripted sessions, counterexamples included, and against the real CLI only when
asked (MM_CANARY=1, with CLAUDE_CODE_OAUTH_TOKEN), since that spends a few model turns."""

import json
import os
import re
import socket
from pathlib import Path

import pytest

from sandbox import canary, session

GOOD = [("w1", "Write", {"file_path": canary.NOTE, "content": "draft"}, "ok"),
        ("w2", "Write", {"file_path": canary.NOTE, "content": "NONCE"}, "ok"),
        ("b1", "Bash", {"command": canary.SEND}, "ok"),
        ("w3", "Write", {"file_path": canary.OUTSIDE[0], "content": "x"}, "denied"),
        ("w4", "Write", {"file_path": canary.OUTSIDE[1], "content": "x"}, "denied"),
        ("r1", "Read", {"file_path": canary.OUTSIDE_READ}, "denied"),
        ("b2", "Bash", {"command": canary.TOUCH}, "denied")]


def scripted(calls, exit=0):
    """A session whose effects are always the good ones (the note holds the nonce, the daemon gets it) and whose
    transcript holds `calls`, each (id, tool, input, "ok" | "error" | "denied")."""
    def run(workdir, client, model, max_turns, wall_seconds):
        work = Path(workdir) / "work"
        nonce = re.search(r"exactly `(\w+)`", (work / "brief.md").read_text()).group(1)
        (work / "note.txt").write_text(nonce)
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(str(session.socket_path(workdir, client)))
        s.sendall(json.dumps({"cmd": "send", "args": [nonce]}).encode() + b"\n")
        s.recv(100)
        lines = []
        for i, name, inp, outcome in calls:
            inp = {k: nonce if v == "NONCE" else v for k, v in inp.items()}
            lines += [{"type": "assistant", "message": {"content": [{"type": "tool_use", "id": i, "name": name, "input": inp}]}},
                      {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": i, "is_error": outcome != "ok"}]}}]
        lines.append({"type": "result", "permission_denials": [{"tool_use_id": i} for i, _, _, o in calls if o == "denied"]})
        (Path(workdir) / "transcript.jsonl").write_text("".join(json.dumps(l) + "\n" for l in lines))
        return {"turns": len(calls), "stopped": "finished", "exit": exit, "transcript_sha256": "x"}
    return run


def outcome(i, new):
    return [(j, n, x, new if j == i else o) for j, n, x, o in GOOD]


@pytest.mark.parametrize("calls", [
    outcome("w2", "denied"),
    [c for c in GOOD if c[0] != "b1"],
    outcome("w3", "error"),
    outcome("r1", "ok"),
    GOOD + [("g1", "Glob", {"pattern": "*"}, "ok")],
], ids=["workspace Write denied though the file exists", "daemon reached without a Bash call",
        "outside Write failed but not denied", "outside Read allowed", "tool outside PERMITTED"])
def test_counterexamples_fail(monkeypatch, calls):
    monkeypatch.setattr(session, "run", scripted(calls))
    with pytest.raises(canary.Broken):
        canary.check()


def test_the_good_session_passes_and_a_session_that_did_not_run_is_unavailable(monkeypatch, capsys):
    monkeypatch.setattr(session, "run", scripted(GOOD))
    assert canary.check()["write"] and canary.passes()
    monkeypatch.setattr(session, "run", scripted([], exit=1))
    with pytest.raises(canary.Unavailable):
        canary.check()
    assert not canary.passes() and "unavailable" in capsys.readouterr().out


@pytest.mark.skipif(not (os.environ.get("MM_CANARY") == "1" and os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")),
                    reason="spends model turns: set MM_CANARY=1 and CLAUDE_CODE_OAUTH_TOKEN")
def test_the_real_cli():
    canary.check()
