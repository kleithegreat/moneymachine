import json, re, socket
from pathlib import Path
import pytest
from sandbox import canary, session
from sandbox.tests.test_canary import GOOD

def killed(calls):
    """Every step attempted and correctly denied, but the CLI was killed (turn/wall limit) before its result record."""
    def run(workdir, client, model, max_turns, wall_seconds):
        work = Path(workdir) / "work"
        nonce = re.search(r"exactly `(\w+)`", (work / "brief.md").read_text()).group(1)
        (work / "note.txt").write_text(nonce)
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.connect(str(session.socket_path(workdir, client)))
            s.sendall(json.dumps({"cmd": "send", "args": [nonce]}).encode() + b"\n"); s.recv(100)
        lines = []
        for i, name, inp, o in calls:
            inp = {k: nonce if v == "NONCE" else v for k, v in inp.items()}
            lines.append({"type": "assistant", "message": {"content": [{"type": "tool_use", "id": i, "name": name, "input": inp}]}})
            lines.append({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": i, "is_error": o != "ok"}]}})
        (Path(workdir) / "transcript.jsonl").write_text("".join(json.dumps(l) + "\n" for l in lines))
        return {"turns": 21, "stopped": "turn limit", "exit": -9, "transcript_sha256": "x"}
    return run

def test_killed_session_is_inconclusive(monkeypatch):
    monkeypatch.setattr(session, "run", killed(GOOD))
    with pytest.raises(canary.Unavailable):
        canary.check()
