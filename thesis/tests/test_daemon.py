"""C10.1/C10.2: the daemon records every call before releasing its bytes, sets every time itself, limits
registrations, admits only sources disclosed in the session, and exposes only the session's commands."""

import json

import pytest

from gate import kernel
from ingest.policy import DAY, HOUR
from thesis import daemon as thesis_daemon
from thesis import positions, registry

NOW = 400 * DAY + 10 * HOUR
ZERO = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}
SNAPSHOT = {"taken": NOW - HOUR, "listings": {"X": False},
            "markets": {"X": {"last_close": 100.0, "t": NOW - HOUR}},
            "daily": {"X": [[t * DAY, 100.0, 100.0] for t in range(200, 400)]}}
DATA = {"bars": {"X": {h * HOUR: (100.0, 100.0) for h in range(9000, 9700)}}, "funding": {}}
CONFIG = {"initial": 10_000.0, "fee": 0.0, "costs": {"X": ZERO}}


class Fetcher:
    def fetch(self, url):
        if "bad" in url:
            return {"refused": "non-global", "url": url, "final_url": url, "redirects": [], "started": 1, "ended": 2}
        return {"status": 200, "url": url, "final_url": url, "redirects": [], "content_type": "text/plain", "body": b"news",
                "truncated": False, "started": 1, "ended": 2}


@pytest.fixture
def make(tmp_path):
    kernel.build()
    ledger = registry.Ledger(tmp_path / "l.sqlite", "thesis-test")
    clock = iter(range(NOW, NOW + 10_000, 7))

    def build(commands=("markets", "prices", "fetch", "register", "positions", "exit"), ablation_of=None):
        replay = lambda account, now: positions.run(CONFIG, ledger.theses(account), ledger.exits(account), DATA, now)
        return thesis_daemon.Daemon(tmp_path / "s.sock", "s1", "main", ledger, SNAPSHOT, Fetcher(), tmp_path / "responses",
                                    replay, lambda account, markets, t_r: (CONFIG, DATA), commands,
                                    clock=lambda: next(clock), ablation_of=ablation_of), ledger
    return build


def call(d, cmd, *args):
    return json.loads(d.handle({"cmd": cmd, "args": list(args)}))


def thesis(**over):
    r = {"request_id": "r1", "legs": [["X", 1]], "T": 405 * DAY, "p": 0.6, "L": 0.1, "catalyst": "c", "catalyst_id": "c",
         "sources": []}
    r.update(over)
    return json.dumps(r)


def test_every_call_is_recorded_with_the_hash_of_its_exact_bytes(make, tmp_path):
    d, ledger = make()
    outs = [d.handle({"cmd": "markets", "args": []}), d.handle({"cmd": "nope"}), d.handle({"cmd": "fetch", "args": ["https://bad"]}),
            d.handle({"cmd": "fetch", "args": ["https://ok"]})]
    calls = [c for _, _, c in ledger.records("call", "main")]
    assert [c["seq"] for c in calls] == [1, 2, 3, 4]
    for body, c in zip(outs, calls):
        assert c["response_sha256"] == registry.sha256(body)
        assert (tmp_path / "responses" / f"{c['response_sha256']}.json").read_bytes() == body
    assert calls[3]["fetch"]["body_sha256"] == registry.sha256(b"news") and calls[2]["ok"] is False


def test_no_bytes_are_released_if_the_record_cannot_be_written(make, monkeypatch):
    d, ledger = make()
    monkeypatch.setattr(ledger, "disclose", lambda *a: (_ for _ in ()).throw(RuntimeError("ledger down")))
    with pytest.raises(RuntimeError):
        d.handle({"cmd": "markets", "args": []})


def test_registration_uses_the_daemon_clock_only_disclosed_sources_and_at_most_two(make):
    d, _ = make()
    assert not call(d, "register", thesis(sources=["s1-f1"]))["ok"]
    fid = call(d, "fetch", "https://ok")["retrieval_id"]
    first = call(d, "register", thesis(sources=[fid]))
    assert first["ok"] and NOW <= first["thesis"]["t_r"] < NOW + 10_000
    assert not call(d, "register", thesis(request_id="r2", t_r=1))["ok"]
    assert call(d, "register", thesis(request_id="r2"))["ok"]
    assert "at most 2" in call(d, "register", thesis(request_id="r3"))["message"]


def test_exits_only_own_open_positions_and_session_commands(make):
    d, ledger = make()
    th = call(d, "register", thesis())["thesis"]
    assert not call(d, "exit", "main-9", "why")["ok"]
    assert call(d, "exit", th["id"], "catalyst passed")["ok"] and ledger.exits("main")[0]["id"] == th["id"]
    noread, _ = make(commands=("markets", "prices", "register", "positions", "exit"))
    assert not call(noread, "fetch", "https://ok")["ok"]
    ablation, ledger = make(commands=("prices", "forecast"), ablation_of=th["id"])
    assert not call(ablation, "register", thesis(request_id="z"))["ok"]
    assert call(ablation, "forecast", "0.4")["ok"] and not call(ablation, "forecast", "0.5")["ok"]
    assert [c for _, _, c in ledger.records("ablation")] == [{"thesis": th["id"], "p": 0.4, "session": "s1"}]
