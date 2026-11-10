"""C10.2 (audit/stage10/criteria-revision-round11-draft.md), wording (b), through the runner's own paths: transcripts in the
CLI's stream-json shape, a torn file left by a killed writer, a report written beside a live runner. D1 and D3 of Argon's review
of rounds 13-14 (audit/reviews/2026-11-09-argon-web-refreeze-rounds13-14.md)."""

import json
import multiprocessing as mp
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

from thesis import harness, report, runner
from thesis.tests.test_record_before_reply import wait_for
from thesis.tests.test_runner import MONDAY, track  # noqa: F401

REPO = Path(__file__).resolve().parents[2]
TOOLS = ("Bash", "Read", "Write")


def init(tools=TOOLS):
    return {"type": "system", "subtype": "init", "tools": list(tools), "session_id": "s"}


def turn(*blocks):
    return {"type": "assistant", "message": {"role": "assistant", "content": list(blocks)}}


def use(id, name, kind="tool_use"):
    return {"type": kind, "id": id, "name": name, "input": {}}


def answer(*ids, error=False):
    return {
        "type": "user",
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": i, "content": "x", **({"is_error": True} if error else {})}
                for i in ids
            ],
        },
    }


def result(denials=()):
    return {
        "type": "result",
        "subtype": "success",
        "is_error": False,
        "permission_denials": [{"tool_name": "?", "tool_use_id": i, "tool_input": {}} for i in denials],
    }


def session_of(*blocks, tools=TOOLS, denials=(), denied=False):
    ids = [b["id"] for b in blocks if "id" in b]
    return [init(tools), turn(*blocks), answer(*ids, error=denied), result(denials)]


def text(lines):
    return "".join((line if isinstance(line, str) else json.dumps(line)) + "\n" for line in lines)


def verdict(track, monkeypatch, tmp_path, transcript, run=None):
    """C10.2's section of the report written after a main session whose CLI left `transcript` (text, or None for none)."""
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)

    def run_session(work, kind, start_daemon, task=None):
        work.mkdir(parents=True, exist_ok=True)
        if transcript is not None:
            (work / "transcript.jsonl").write_text(transcript)
        return {"kind": kind, **({"exit": 0} if run is None else run)}

    monkeypatch.setattr(runner.harness, "run_session", run_session)
    track.session("main", MONDAY, {"taken": MONDAY}, ())
    report.write(track, MONDAY + 2 * 86_400_000, tmp_path / "r.json")
    return json.loads((tmp_path / "r.json").read_text())["c10_2"]


PASSING = {
    "permitted tools": session_of(use("a", "Read"), use("b", "Bash")),
    "fallback and redacted thinking blocks": session_of(
        {"type": "fallback"},
        {"type": "redacted_thinking", "data": "x"},
        {"type": "thinking", "thinking": "x"},
        {"type": "text", "text": "x"},
    ),
    "a denied call to a tool outside the set": session_of(
        use("a", "Edit"), tools=(*TOOLS, "Edit"), denials=("a",), denied=True
    ),
    "a tool the session never had": session_of(use("a", "Edit"), denied=True),
}
FAILING = {
    "WebFetch executed": session_of(use("a", "WebFetch"), tools=(*TOOLS, "WebFetch")),
    "WebFetch not denied, though listed": session_of(use("a", "WebFetch"), tools=(*TOOLS, "WebFetch"), denials=("b",)),
    "server_tool_use": session_of(use("a", "web_search", "server_tool_use")),
    "mcp_tool_use": session_of(use("a", "mcp__x__y", "mcp_tool_use")),
    "an unknown block type": session_of({"type": "web_search_tool_result"}),
    "no init": session_of(use("a", "Read"))[1:],
    "no result": session_of(use("a", "Read"))[:-1],
    "a line that is not JSON": [*session_of(use("a", "Read"))[:-1], "corrupt bytes", result()],
}


@pytest.mark.parametrize("name", PASSING)
def test_c10_2_passes_an_honest_session(track, monkeypatch, tmp_path, name):
    assert verdict(track, monkeypatch, tmp_path, text(PASSING[name]))["pass"] is True


@pytest.mark.parametrize("name", FAILING)
def test_c10_2_fails_what_it_cannot_prove_honest(track, monkeypatch, tmp_path, name):
    body = text(FAILING[name])
    assert verdict(track, monkeypatch, tmp_path, body)["pass"] is False


def write_then_die(path, torn):
    """A writer as session.run is: block-buffered, killed (SIGKILL) with its last line half written."""
    out = open(path, "w")
    out.write(text(session_of(use("a", "Read"))[:2]))
    out.write(torn)
    out.flush()
    os.kill(os.getpid(), signal.SIGKILL)


def test_c10_2_fails_a_transcript_torn_in_a_line_that_names_webfetch(track, monkeypatch, tmp_path):
    path = tmp_path / "t.jsonl"
    torn = json.dumps(turn(use("b", "WebFetch")))[:40]
    child = mp.get_context("fork").Process(target=write_then_die, args=(path, torn))
    child.start()
    child.join()
    assert child.exitcode == -signal.SIGKILL
    assert verdict(track, monkeypatch, tmp_path, path.read_text())["pass"] is False


def test_c10_2_fails_a_missing_transcript_once_the_cli_started(track, monkeypatch, tmp_path):
    assert verdict(track, monkeypatch, tmp_path, None, run={"exit": 0})["pass"] is False


def test_c10_2_passes_a_session_whose_cli_never_started(track, monkeypatch, tmp_path):
    assert verdict(track, monkeypatch, tmp_path, None, run={"error": "OSError('no sandbox')"})["pass"] is True


def test_the_report_fails_c10_2_while_a_session_lacks_its_end_and_does_not_close_it(track, tmp_path):
    track.ledger.disclose(
        "session", "main", {"session": "main-1", "kind": "main", "started": 1, "taken": MONDAY, "manifest": "0"}
    )
    report.write(track, MONDAY, tmp_path / "r.json")
    c10_2 = json.loads((tmp_path / "r.json").read_text())["c10_2"]
    assert c10_2["pass"] is False and c10_2["unclosed"] == ["main-1"]
    assert list(track.ledger.records("session_end")) == []


def test_a_session_the_runner_died_in_is_audited_when_it_is_closed(track, monkeypatch, tmp_path):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + 60_000)
    track.ledger.disclose(
        "session", "main", {"session": "main-1", "kind": "main", "started": 1, "taken": MONDAY, "manifest": "0"}
    )
    work = track.root / "sessions" / track.version / "main-1"
    work.mkdir(parents=True)
    (work / "transcript.jsonl").write_text(text(session_of(use("a", "WebSearch"), tools=(*TOOLS, "WebSearch"))))
    track.close_interrupted()
    report.write(track, MONDAY + 86_400_000, tmp_path / "r.json")
    c10_2 = json.loads((tmp_path / "r.json").read_text())["c10_2"]
    assert c10_2["pass"] is False and c10_2["outside_permitted"] == {"main-1": ["WebSearch"]}


def descendants(pid):
    out = []
    for p in os.listdir("/proc"):
        if p.isdigit():
            try:
                parent = int(Path(f"/proc/{p}/stat").read_text().rsplit(")", 1)[1].split()[1])
            except OSError:
                continue
            if parent == pid:
                out += [int(p), *descendants(int(p))]
    return out


def running(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0] != "Z"
    except OSError:
        return False


def test_the_cli_dies_with_the_runner(tmp_path):
    """bwrap --die-with-parent: SIGKILL of the runner takes every process of the sandbox with it, so no CLI outlives the
    runner to keep writing a transcript nobody audits."""
    harness.workspace(tmp_path, "main")
    sleeper = "import os, time; open('/work/up', 'w').write(str(os.getpid())); time.sleep(600)"
    runner_code = (
        "import os, subprocess, sys, time\n"
        "from sandbox import session\n"
        "os.environ['CLAUDE_CODE_OAUTH_TOKEN'] = 'x'\n"
        f"subprocess.Popen(session.sandbox_command(sys.argv[1], 'thesis-agent', [sys.executable, '-c', {sleeper!r}]),"
        " stdin=subprocess.DEVNULL)\n"
        "time.sleep(600)\n"
    )
    parent = subprocess.Popen([sys.executable, "-c", runner_code, str(tmp_path)], cwd=REPO)
    try:
        wait_for(tmp_path / "work" / "up")
        sandboxed = descendants(parent.pid)
        assert len(sandboxed) >= 2
        parent.kill()
        parent.wait()
        deadline = time.time() + 10
        while time.time() < deadline and any(running(p) for p in sandboxed):
            time.sleep(0.1)
        assert [p for p in sandboxed if running(p)] == []
    finally:
        parent.kill()
