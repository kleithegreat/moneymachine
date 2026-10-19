"""C3.1: the mm-agent daemon fixes paths, enforces the budget, filters disclosures, logs every call."""

import json
import socket
import sqlite3
import subprocess
from pathlib import Path

import pytest

from gate.agent.daemon import FIELDS, Daemon
from gate.markets import write_market

REPO = Path(__file__).resolve().parents[2]
MM = REPO / "kernel/target/release/mm"
W0 = json.loads((REPO / "kernel/strategies/w0.json").read_text())


def call(sock, req):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(str(sock))
    s.sendall(json.dumps(req).encode() + b"\n")
    return json.loads(s.makefile().readline())


@pytest.fixture
def daemon(tmp_path):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    market = write_market(tmp_path / "m", market_id="daemon", days=40, holdout_days=10)
    d = Daemon(tmp_path / "a.sock", MM, market, tmp_path / "l.sqlite", "camp", "A", 3, tmp_path / "log.jsonl").serve()
    yield d, tmp_path
    d.close()


def test_budget_disclosure_and_log(daemon):
    d, tmp = daemon
    text = json.dumps(W0)
    outs = [call(d.socket_path, {"cmd": "eval", "programs": [text], "store": "/elsewhere", "ledger": "/x"}) for _ in range(4)]
    assert all(o["ok"] for o in outs[:3]) and outs[3]["code"] == "BUDGET"
    assert set(outs[0]) == set(FIELDS) | {"ok", "remaining"}
    log = [json.loads(l) for l in open(tmp / "log.jsonl")]
    assert [e["cmd"] for e in log] == ["eval"] * 4
    db = sqlite3.connect(tmp / "l.sqlite")
    assert db.execute("SELECT COUNT(*) FROM experiments WHERE campaign='camp' AND agent='A'").fetchone()[0] == 3
    assert db.execute("SELECT COUNT(DISTINCT campaign) FROM experiments").fetchone()[0] == 1


def test_rejections_count_and_check_is_free(daemon):
    d, _ = daemon
    bad = json.dumps(W0).replace('"input": "funding"', '"input": "next_open"')
    assert call(d.socket_path, {"cmd": "check", "programs": [bad]})["code"] == "E_UNKNOWN_INPUT"
    assert call(d.socket_path, {"cmd": "budget"})["remaining"] == 3
    assert call(d.socket_path, {"cmd": "eval", "programs": [bad]})["code"] == "E_UNKNOWN_INPUT"
    assert call(d.socket_path, {"cmd": "budget"})["remaining"] == 2


def test_select_requires_evaluated_programs(daemon):
    d, tmp = daemon
    text = json.dumps(W0)
    assert not call(d.socket_path, {"cmd": "select", "programs": [text]})["ok"]
    call(d.socket_path, {"cmd": "eval", "programs": [text]})
    assert call(d.socket_path, {"cmd": "select", "programs": [text]})["ok"]
    rows = sqlite3.connect(tmp / "l.sqlite").execute("SELECT agent, note FROM selections").fetchall()
    assert rows == [("A", "agent selection")]


def test_bad_requests(daemon):
    d, _ = daemon
    assert not call(d.socket_path, {"cmd": "holdout", "programs": ["{}"]})["ok"]
    assert not call(d.socket_path, {"cmd": "eval", "programs": ["{}", "{}"]})["ok"]
