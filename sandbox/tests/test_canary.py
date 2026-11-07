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


def scripted(calls, exit=0, send=True, touch=False, message=None, final=True):
    """A session whose effects are always the good ones (the note holds the nonce, the daemon gets it) and whose
    transcript holds `calls`, each (id, tool, input, "ok" | "error" | "denied" | "no result")."""
    def run(workdir, client, model, max_turns, wall_seconds):
        work = Path(workdir) / "work"
        nonce = re.search(r"exactly `(\w+)`", (work / "brief.md").read_text()).group(1)
        (work / "note.txt").write_text(nonce)
        if touch:
            (work / "x").touch()
        if send:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(str(session.socket_path(workdir, client)))
                s.sendall(json.dumps(message or {"cmd": "send", "args": [nonce]}).encode() + b"\n")
                s.recv(100)
        lines = []
        for i, name, inp, outcome in calls:
            inp = {k: nonce if v == "NONCE" else v for k, v in inp.items()}
            lines.append({"type": "assistant", "message": {"content": [{"type": "tool_use", "id": i, "name": name, "input": inp}]}})
            if outcome != "no result":
                lines.append({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": i,
                                                                         "is_error": outcome != "ok"}]}})
        if final:
            lines.append({"type": "result", "permission_denials": [{"tool_use_id": i} for i, _, _, o in calls if o == "denied"]})
        (Path(workdir) / "transcript.jsonl").write_text("".join(json.dumps(l) + "\n" for l in lines))
        return {"turns": len(calls), "stopped": "finished", "exit": exit, "transcript_sha256": "x"}
    return run


def outcome(i, new):
    return [(j, n, x, new if j == i else o) for j, n, x, o in GOOD]


@pytest.mark.parametrize("missing", [c[0] for c in GOOD])
def test_an_unattempted_step_is_inconclusive_and_the_next_canary_can_pass(monkeypatch, capsys, missing):
    """A required tool action proves nothing about the sandbox unless the model attempts it."""
    monkeypatch.setattr(session, "run", scripted([c for c in GOOD if c[0] != missing], send=missing != "b1"))
    with pytest.raises(canary.Unavailable, match="not attempted"):
        canary.check()
    assert not canary.passes()
    output = capsys.readouterr().out
    assert "inconclusive" in output and "SANDBOX CONTRACT BROKEN" not in output
    monkeypatch.setattr(session, "run", scripted(GOOD))
    assert canary.passes()


@pytest.mark.parametrize("allowed", ["w3", "w4", "r1", "b2"])
def test_an_allowed_forbidden_attempt_is_broken_even_if_another_step_was_skipped(monkeypatch, allowed):
    """Missing evidence must never hide an observed contract violation."""
    monkeypatch.setattr(session, "run", scripted([c for c in outcome(allowed, "ok") if c[0] != "w1"]))
    with pytest.raises(canary.Broken):
        canary.check()


@pytest.mark.parametrize("calls", [
    outcome("w2", "denied"),
    outcome("w1", "no result"),
    outcome("w3", "error"),
    outcome("r1", "ok"),
    GOOD + [("g1", "Glob", {"pattern": "*"}, "ok")],
    [c for c in GOOD if c[0] != "b1"],
], ids=["workspace Write denied though the file exists", "a Write with no result",
        "outside Write failed but not denied", "outside Read allowed", "tool outside PERMITTED", "daemon reached without Bash"])
def test_counterexamples_fail(monkeypatch, calls):
    monkeypatch.setattr(session, "run", scripted(calls))
    with pytest.raises(canary.Broken):
        canary.check()


@pytest.mark.parametrize("command", ["touch x", "touch /work/x ", "/bin/touch /work/x"])
def test_varied_forbidden_commands_and_effects_are_broken_before_incomplete_or_failed_run(monkeypatch, command):
    calls = [c for c in GOOD if c[0] != "b2"] + [("extra", "Bash", {"command": command}, "ok")]
    monkeypatch.setattr(session, "run", scripted(calls, exit=1, touch=True))
    with pytest.raises(canary.Broken):
        canary.check()


def test_daemon_reached_by_a_different_command_is_broken(monkeypatch):
    calls = [c for c in GOOD if c[0] != "b1"] + [("extra", "Bash", {"command": "python client.py"}, "ok")]
    monkeypatch.setattr(session, "run", scripted(calls))
    with pytest.raises(canary.Broken):
        canary.check()


@pytest.mark.parametrize("name, inp", [("Bash", {"command": "ls"}), ("Read", {"file_path": "/tool/egress.py"}),
                                      ("Read", {"file_path": "/etc/./passwd"}),
                                      ("Write", {"file_path": "/home/agent/.rc"}),
                                      ("Write", {"file_path": "/work/../home/agent/.rc"})])
def test_extra_calls_cannot_hide_behind_the_seven_literal_probes(monkeypatch, name, inp):
    monkeypatch.setattr(session, "run", scripted(GOOD + [("extra", name, inp, "ok")]))
    with pytest.raises(canary.Broken):
        canary.check()


def test_unexplained_filesystem_effect_is_broken(monkeypatch):
    monkeypatch.setattr(session, "run", scripted([c for c in GOOD if c[0] != "b2"], touch=True))
    with pytest.raises(canary.Broken):
        canary.check()


def test_a_wrong_daemon_effect_is_broken_even_without_the_literal_send_probe(monkeypatch):
    calls = [c for c in GOOD if c[0] != "b1"] + [("variant", "Bash", {"command": "./canary send /work/note.txt"}, "ok")]
    monkeypatch.setattr(session, "run", scripted(calls, message={"cmd": "send", "args": ["wrong"]}))
    with pytest.raises(canary.Broken):
        canary.check()


def test_a_denied_extra_forbidden_tool_is_not_a_contract_violation(monkeypatch):
    monkeypatch.setattr(session, "run", scripted(GOOD + [("extra", "Glob", {"pattern": "*"}, "denied")]))
    assert canary.check()["write"]


def test_effect_violations_are_classified_before_cli_metadata(monkeypatch):
    good = scripted(GOOD)

    def run(workdir, *args):
        result = good(workdir, *args)
        (Path(workdir) / "work/note.txt").write_text("wrong")
        return result

    monkeypatch.setattr(session, "run", run)
    monkeypatch.setattr(session, "claude_binary", lambda: (_ for _ in ()).throw(RuntimeError("metadata unavailable")))
    with pytest.raises(canary.Broken):
        canary.check()


def test_killed_session_without_final_denial_evidence_is_inconclusive(monkeypatch, capsys):
    monkeypatch.setattr(session, "run", scripted(GOOD, exit=-9, final=False))
    with pytest.raises(canary.Unavailable):
        canary.check()
    assert not canary.passes()
    assert "SANDBOX CONTRACT BROKEN" not in capsys.readouterr().out


@pytest.mark.parametrize("allowed", ["w3", "w4", "r1", "b2"])
def test_a_kill_never_hides_an_observed_allowed_forbidden_call(monkeypatch, allowed):
    monkeypatch.setattr(session, "run", scripted(outcome(allowed, "ok"), exit=-9, final=False))
    with pytest.raises(canary.Broken):
        canary.check()


def test_a_kill_never_hides_an_unpermitted_filesystem_effect(monkeypatch):
    monkeypatch.setattr(session, "run", scripted(GOOD, exit=-9, touch=True, final=False))
    with pytest.raises(canary.Broken):
        canary.check()


@pytest.mark.parametrize("tool", ["Read", "Write"])
def test_tilde_paths_use_the_sandbox_home_not_the_working_directory(monkeypatch, tool):
    monkeypatch.setattr(session, "run", scripted(GOOD + [("extra", tool, {"file_path": "~/.rc"}, "ok")]))
    with pytest.raises(canary.Broken):
        canary.check()


def test_the_good_session_passes_and_a_session_that_did_not_run_is_unavailable(monkeypatch, capsys):
    monkeypatch.setattr(session, "run", scripted(GOOD))
    assert canary.check()["write"] and canary.passes()
    monkeypatch.setattr(session, "run", scripted([], exit=1, send=False))
    with pytest.raises(canary.Unavailable):
        canary.check()
    assert not canary.passes() and "unavailable" in capsys.readouterr().out


@pytest.mark.skipif(not (os.environ.get("MM_CANARY") == "1" and os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")),
                    reason="spends model turns: set MM_CANARY=1 and CLAUDE_CODE_OAUTH_TOKEN")
def test_the_real_cli():
    canary.check()
