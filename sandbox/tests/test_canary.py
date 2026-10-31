"""The sandbox canary: its verdict on scripted sessions, and against the real CLI only when asked (MM_CANARY=1, with
CLAUDE_CODE_OAUTH_TOKEN), since that spends a few model turns."""

import json
import os
import re
import socket
from pathlib import Path

import pytest

from sandbox import canary, session


def scripted(outside_denied):
    """A session that writes the note, sends it through the client, is refused the second outside Write by an error
    and the first by a denial (if `outside_denied`), and is denied `touch`."""
    def run(workdir, client, model, max_turns, wall_seconds):
        work = Path(workdir) / "work"
        nonce = re.search(r"exactly `(\w+)`", (work / "brief.md").read_text()).group(1)
        (work / "note.txt").write_text(nonce)
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(str(session.socket_path(workdir, client)))
        s.sendall(json.dumps({"cmd": "send", "args": [nonce]}).encode() + b"\n")
        s.recv(100)
        uses = [("w1", "Write", {"file_path": "/work/note.txt"}), ("w2", "Write", {"file_path": canary.OUTSIDE[0]}),
                ("w3", "Write", {"file_path": canary.OUTSIDE[1]}), ("b1", "Bash", {"command": "touch /work/x"})]
        lines = [{"type": "assistant", "message": {"content": [{"type": "tool_use", "id": i, "name": n, "input": x}]}}
                 for i, n, x in uses]
        lines += [{"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "w3", "is_error": True}]}},
                  {"type": "result", "permission_denials": [{"tool_use_id": "b1"}] + [{"tool_use_id": "w2"}] * outside_denied}]
        (Path(workdir) / "transcript.jsonl").write_text("".join(json.dumps(l) + "\n" for l in lines))
        return {"turns": 4, "stopped": "finished", "exit": 0, "transcript_sha256": "x"}
    return run


def test_the_verdict(monkeypatch):
    monkeypatch.setattr(session, "run", scripted(True))
    r = canary.check()
    assert r["write"] and r["client"] and r["bash_denied"] and all(r["outside_refused"].values())
    monkeypatch.setattr(session, "run", scripted(False))
    with pytest.raises(RuntimeError, match="'/home/agent/outside.txt': False"):
        canary.check()


@pytest.mark.skipif(not (os.environ.get("MM_CANARY") == "1" and os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")),
                    reason="spends model turns: set MM_CANARY=1 and CLAUDE_CODE_OAUTH_TOKEN")
def test_the_real_cli():
    canary.check()
