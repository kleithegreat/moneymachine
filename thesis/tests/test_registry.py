"""C10.1: registration refuses every invalid field and any supplied time, commits canonical content to
an append-only ledger, is idempotent per request id, and admits under the cap in commit order."""

import json
import math
import sqlite3

import pytest

from gate import kernel
from ingest.policy import DAY, HOUR
from thesis import registry

T_R = 400 * DAY + 10 * HOUR
LISTINGS = {"X": False, "Y": True, "Z": False, "W": False}
DAILY = {"X": [t * DAY for t in range(200, 400)], "W": [t * DAY for t in range(200, 400)], "Z": [t * DAY for t in range(350, 400)]}
ZERO = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}
CONFIG = {"initial": 10_000.0, "fee": 0.0, "costs": {m: ZERO for m in LISTINGS}}
DATA = {"bars": {m: {h * HOUR: (100.0, 100.0) for h in range(9000, 9700)} for m in LISTINGS}, "funding": {}}


def request(**over):
    r = {"request_id": "r1", "legs": [["X", 1]], "T": 405 * DAY, "p": 0.6, "L": 0.1, "catalyst": "a scheduled release",
         "catalyst_id": "release", "sources": ["f1"]}
    r.update(over)
    return r


def register(ledger, req, t_r=T_R, account="main"):
    return registry.register(ledger, account, "s1", req, t_r, LISTINGS, lambda m: DAILY.get(m, []), {"f1", "f2"}, CONFIG, DATA)


@pytest.fixture
def ledger(tmp_path):
    kernel.build()
    return registry.Ledger(tmp_path / "ledger.sqlite", "thesis-test")


@pytest.mark.parametrize("over", [
    {"legs": [["Y", 1]]}, {"legs": [["Q", 1]]}, {"legs": [["Z", 1]]}, {"legs": [["X", 2]]}, {"legs": [["X", True]]},
    {"legs": [["X", 1], ["X", -1]]}, {"legs": [["X", 1], ["W", 1]]}, {"legs": []},
    {"T": 405 * DAY + 1}, {"T": T_R + 71 * HOUR}, {"T": 461 * DAY}, {"T": 405.0 * DAY},
    {"p": 1.0}, {"p": 0.0}, {"p": math.nan}, {"p": math.inf}, {"p": "0.6"}, {"L": 0.6}, {"L": 0.005},
    {"catalyst": ""}, {"catalyst_id": "x" * 65}, {"sources": ["f9"]}, {"request_id": ""},
])
def test_invalid_fields_are_refused(ledger, over):
    th, errors = register(ledger, request(**over))
    assert th is None and errors and ledger.theses("main") == []


@pytest.mark.parametrize("extra", ["t_r", "id", "registered", "size"])
def test_no_time_or_derived_field_can_be_supplied(ledger, extra):
    th, errors = register(ledger, {**request(), extra: 0})
    assert th is None and errors


def test_a_registered_thesis_is_canonical_append_only_and_idempotent(ledger):
    th, errors = register(ledger, request())
    assert errors is None and th["t_r"] == T_R and th["id"] == "main-1" and th["N"] == 1000 and th["size"] == 1000
    (lid, created, content), = ledger.records("thesis", "main")
    db = sqlite3.connect(ledger.path)
    text = db.execute("SELECT content FROM disclosures WHERE id = ?", (lid,)).fetchone()[0]
    assert text == registry.canonical(content) and json.loads(text) == th
    with pytest.raises(sqlite3.DatabaseError):
        db.execute("UPDATE disclosures SET content = '{}' WHERE id = ?", (lid,))
    with pytest.raises(sqlite3.DatabaseError):
        db.execute("DELETE FROM disclosures WHERE id = ?", (lid,))
    again, errors = register(ledger, request(), t_r=T_R + HOUR)
    assert errors is None and again == th
    changed, errors = register(ledger, request(p=0.7), t_r=T_R + HOUR)
    assert changed is None and "already used" in errors[0]
    assert len(ledger.theses("main")) == 1


def test_admission_follows_commit_order_at_the_cap(ledger):
    sizes = [register(ledger, request(request_id=f"r{i}"))[0]["size"] for i in range(6)]
    assert sizes == [1000] * 5 + [0]
    assert register(ledger, request(request_id="other"), account="noread")[0]["size"] == 1000
