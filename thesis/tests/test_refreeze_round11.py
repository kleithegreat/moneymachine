"""Argon's round-ten concrete counterexamples; synthetic inputs only."""
import json
import socket
import subprocess
import sys

import pytest

from sandbox import session
from sandbox.tests.test_client import client
from thesis import harness
from thesis.daemon import SPEC
from thesis.tests.test_daemon import make  # noqa: F401
from thesis.tests.test_refreeze_round9 import record, transcript

USAGE = SPEC["usage"]
REFUSAL = '{"ok": false, "error": "[Errno 2] No such file or directory: \'missing.json\'"}'


@pytest.mark.parametrize("command,output,records", [
    ("./thesis-agent prices; ./thesis-agent markets", "Exit code 2\n" + USAGE,
     [record("prices", "BTC"), record("markets")]),
    ("./thesis-agent exit $(cat id.txt) wrong_reason", "{}", [record("exit", "id1", "different_reason")]),
    ("./thesis-agent register $(cat two_files.txt); ./thesis-agent markets", "Exit code 2\n" + USAGE,
     [record("register", "x.json"), record("markets")]),
    ('for f in a.json missing.json; do ./thesis-agent register "$f" >/dev/null || ./thesis-agent register "$f"; done',
     "Exit code 1\n" + REFUSAL, []),
    ('for f in a.json missing.json; do ./thesis-agent register "$f" >/dev/null; done', "Exit code 1\n" + REFUSAL, []),
    ("./thesis-agent markets", "Exit code 1\n" + REFUSAL, []),
])
def test_f1_f2_argon_counterexamples_fail_closed(tmp_path, command, output, records):
    assert harness.audit(transcript(tmp_path, [(command, output)]), records)["match"] is False


def test_f1_bare_client_is_recorded_not_an_audit_crash(tmp_path):
    refusal = {"request": {"cmd": None, "args": [], "argv": [], "refusal": USAGE}}
    a = harness.audit(transcript(tmp_path, [("./thesis-agent", "refused")]), [refusal])
    assert a["match"] is True and a["refused"] == 1


@pytest.mark.parametrize("argv", [[], ["prices"], ["exit", "id", "wrong", "arity"], ["register", "missing.json"]])
def test_f1_f2_every_refused_invocation_reaches_the_daemon(argv):
    sent = []
    assert client(SPEC, sent)(argv) != 0
    assert len(sent) == 1 and sent[0]["argv"] == argv and sent[0]["refusal"]


def test_f1_f2_daemon_records_refusal_without_executing_it(make):
    daemon, ledger = make()
    req = {"cmd": None, "args": [], "argv": ["register", "missing.json"], "refusal": "unreadable FILE: missing.json"}
    out = json.loads(daemon.handle(req))
    assert out == {"ok": False, "message": req["refusal"]}
    assert [c for _, _, c in ledger.records("call")][0]["request"] == req
    assert ledger.theses("main") == []


def test_f1_f2_real_clients_record_each_loop_iteration_and_bare_invocation(make, tmp_path):
    daemon, ledger = make()
    daemon.serve()
    script = tmp_path / "thesis-agent"
    script.write_text(f"#!{sys.executable} -I\nSPEC = {SPEC | {'socket': str(daemon.socket_path)}!r}\n"
                      + (session.HERE / "client.py").read_text())
    script.chmod(0o755)
    (tmp_path / "a.json").write_text("{}")
    try:
        result = subprocess.run(
            ["/bin/sh", "-c", 'for f in a.json missing.json; do ./thesis-agent register "$f" >/dev/null; done; ./thesis-agent'],
            cwd=tmp_path, capture_output=True, text=True, timeout=10)
    finally:
        daemon.close()
    calls = [c for _, _, c in ledger.records("call")]
    assert result.returncode == 2 and len(calls) == 3
    assert [bool(c["request"]["refusal"]) for c in calls] == [False, True, True]


@pytest.mark.parametrize("command", ["./thesis-agent", "./thesis-agent prices BTC",
    "./thesis-agent exit id 'too late'", './thesis-agent exit id "too late"',
    "./thesis-agent fetch 'https://example.invalid/?x=1&y=2'", "./thesis-agent exit id '$(not executed)'" ])
def test_single_literal_execution_maps_by_count_not_output(tmp_path, command):
    calls = [record("markets")]
    a = harness.audit(transcript(tmp_path, [(command, "Exit code 1\n" + REFUSAL)]), calls)
    assert a["match"] is True and a["client_executions"] == a["daemon_calls"] == 1


@pytest.mark.parametrize("command", ["python -c 'import socket'", "./thesis-agent markets >/dev/null",
    "./thesis-agent markets; ./thesis-agent positions", "./thesis-agent prices $m", "./thesis-agent prices `cat x`",
    "./thesis-agent prices *", "./thesis-agent prices M?", "./thesis-agent prices ${m}", "./thesis-agent markets\n", "./thesis-agent markets &",
    "./thesis-agent prices <(cat x)", "./thesis-agent exit id \"$reason\"", "./thesis-agent prices B\\TC"])
def test_nonliteral_or_nonclient_bash_fails_even_with_equal_record_count(tmp_path, command):
    assert harness.audit(transcript(tmp_path, [(command, "{}")]), [record("markets")])["match"] is False


def test_refusals_are_counted_from_records_only_and_missing_records_fail(tmp_path):
    calls = [record("markets"), {"request": {"argv": ["prices"], "refusal": USAGE}}]
    t = transcript(tmp_path, [("./thesis-agent markets", "{}"), ("./thesis-agent prices", "any output")])
    a = harness.audit(t, calls)
    assert a["match"] is True and a["refused"] == 1
    assert harness.audit(t, calls[:1])["match"] is False
    assert harness.audit(t, calls + calls[:1])["match"] is False


@pytest.mark.parametrize("damage", ["truncated", "invalid", "duplicate", "missing_result"])
def test_unattributable_transcripts_fail_closed(tmp_path, damage):
    t = transcript(tmp_path, [("./thesis-agent markets", "{}")])
    lines = t.read_text().splitlines()
    if damage == "truncated":
        lines.pop()
    elif damage == "invalid":
        lines.insert(0, "not json")
    elif damage == "duplicate":
        lines.insert(0, lines[0])
    else:
        lines.pop(1)
    t.write_text("\n".join(lines) + "\n")
    assert harness.audit(t, [record("markets")])["match"] is False


def test_killing_a_client_before_recording_never_gets_a_refusal_exemption(tmp_path):
    sock = tmp_path / "unrecorded.sock"
    script = tmp_path / "thesis-agent"
    script.write_text(f"SPEC = {SPEC | {'socket': str(sock)}!r}\n" + (session.HERE / "client.py").read_text())
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(sock))
        server.listen()
        server.settimeout(5)
        proc = subprocess.Popen([sys.executable, "-I", str(script), "markets"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            conn, _ = server.accept()
            with conn:
                conn.settimeout(5)
                assert json.loads(conn.makefile("rb").readline())["argv"] == ["markets"]
                proc.kill()
                proc.communicate(timeout=5)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate(timeout=5)
    t = transcript(tmp_path, [("./thesis-agent markets", "Exit code 137\nkilled")])
    assert proc.returncode < 0 and harness.audit(t, [])["match"] is False
