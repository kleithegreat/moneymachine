"""C10.1: registration refuses every invalid field and any supplied time, commits canonical content to
an append-only ledger, is idempotent per request id, admits under the cap in commit order, and serializes
concurrent registrations, reading t_r inside the commit."""

import json
import math
import sqlite3
import threading
from pathlib import Path

import pytest

from ingest.policy import DAY, HOUR
from thesis import positions, registry

REPO = Path(__file__).resolve().parents[2]
T_R = 400 * DAY + 10 * HOUR
LISTINGS = {"X": False, "Y": True, "Z": False, "W": False}
DAYS = {"X": range(200, 400), "W": range(200, 400), "Z": range(350, 400)}
ZERO = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}
CONFIG = {"initial": 10_000.0, "fee": 0.0, "costs": {m: ZERO for m in LISTINGS}, "fallback": []}
DATA = {"bars": {m: positions.Bars({h * HOUR: (100.0, 100.0) for h in range(9000, 9700)}) for m in LISTINGS},
        "funding": {m: {h * HOUR: 0.0 for h in range(4800, 9700)} for m in LISTINGS}, "listed": lambda markets: LISTINGS,
        "daily": {m: positions.Bars({t * DAY: (100.0, 100.0) for t in DAYS.get(m, ())}) for m in LISTINGS}, "cutoff": T_R}


def request(**over):
    r = {"request_id": "r1", "legs": [["X", 1]], "T": 405 * DAY, "p": 0.6, "L": 0.1, "catalyst": "a scheduled release",
         "catalyst_id": "release", "sources": ["f1"], "outcome_market": None}
    r.update(over)
    return r


def register(ledger, req, t_r=T_R, account="main"):
    return registry.register(ledger, account, "s1", req, lambda: t_r, {"f1", "f2"}, CONFIG, DATA)


@pytest.fixture
def ledger(tmp_path, built_kernel):
    return registry.Ledger(tmp_path / "ledger.sqlite", "thesis-test")


@pytest.mark.parametrize("over", [
    {"legs": [["Y", 1]]}, {"legs": [["Q", 1]]}, {"legs": [["Z", 1]]}, {"legs": [["X", 2]]}, {"legs": [["X", True]]},
    {"legs": [["X", 1], ["X", -1]]}, {"legs": [["X", 1], ["W", 1]]}, {"legs": []},
    {"T": 405 * DAY + 1}, {"T": T_R + 71 * HOUR}, {"T": 461 * DAY}, {"T": 405.0 * DAY},
    {"p": 1.0}, {"p": 0.0}, {"p": math.nan}, {"p": math.inf}, {"p": "0.6"}, {"L": 0.6}, {"L": 0.005},
    {"catalyst": ""}, {"catalyst_id": "x" * 65}, {"sources": ["f9"]}, {"request_id": ""},
    {"outcome_market": "will-it-rain"}, {"outcome_market": 512345}, {"outcome_market": "1" * 21},
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
    assert errors is None and th["t_r"] == T_R and th["id"] == "main-1" and th["N"] == "1000" and th["size"] == "1000"
    assert th["b"] == "100" and th["costs"] == {"X": ZERO} and th["fee"] == 0.0 and th["fallback_costs"] == []
    assert th["base_windows"] >= 10 and th["p_ref"] == (th["base_positive"] + 1) / (th["base_windows"] + 2)
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
    assert sizes == ["1000"] * 5 + ["0"]
    assert register(ledger, request(request_id="other"), account="noread")[0]["size"] == "1000"


def test_concurrent_registrations_commit_in_clock_order_and_reserve_exactly(ledger):
    """Eight threads at once: the lock orders them, each reads t_r inside its commit, and five fit the cap."""
    ticks = iter(range(T_R, T_R + 100))
    clock = lambda: next(ticks)
    threads = [threading.Thread(target=registry.register, args=(ledger, "main", "s1", request(request_id=f"c{i}"), clock,
                                                                {"f1"}, CONFIG, DATA)) for i in range(8)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    theses = ledger.theses("main")
    assert [th["id"] for th in theses] == [f"main-{i}" for i in range(1, 9)]
    assert [th["t_r"] for th in theses] == sorted(th["t_r"] for th in theses)
    assert [th["size"] for th in theses] == ["1000"] * 5 + ["0"] * 3


def test_legs_are_checked_before_the_listing_read(ledger):
    def unread(markets):
        raise AssertionError("the venue was read for a malformed request")
    for legs in ([["X", 2]], [["X", 1], ["X", -1]], "X"):
        th, errors = registry.register(ledger, "main", "s1", request(legs=legs), lambda: T_R, {"f1"}, CONFIG,
                                       DATA | {"listed": unread})
        assert th is None and errors


def test_a_thesis_records_what_sized_it(ledger):
    first, _ = register(ledger, request())
    second, _ = register(ledger, request(request_id="r2"), t_r=T_R + 3 * HOUR)
    assert (first["cutoff"], first["E_r"], first["reserved"]) == (T_R, "10000", "0")
    assert (second["cutoff"], second["E_r"], second["reserved"], second["reconciled_hour"]) == (T_R, "10000", "100", T_R)


@pytest.mark.slow
def test_exact_money_survives_the_ledger_round_trip_over_a_long_track(ledger):
    """B3: sequential BTC theses at the frozen costs, each closing before the next registers, at an unchanged price. Each
    trade multiplies equity by a rational of 26 digits, so N's text passes Python's 4300-digit default near trade 168."""
    cells = json.loads((REPO / "venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]["BTC"]
    span, start, n = 4 * DAY, 400 * DAY, 175
    hours = range(start // HOUR, (start + n * span) // HOUR + 48)
    data = {"bars": {"BTC": positions.Bars({h * HOUR: (100.0, 100.0) for h in hours})},
            "funding": {"BTC": {h * HOUR: 0.0 for h in hours}}, "lag": {"BTC": 0}, "listed": lambda markets: {"BTC": False},
            "daily": {"BTC": positions.Bars({t * DAY: (100.0, 100.0) for t in range(200, start // DAY + n * 4)})}}
    config = {"initial": 10_000.0, "fee": 0.00045, "costs": {"BTC": cells}, "fallback": []}
    for k in range(n):
        t_r = start + k * span + HOUR
        th, errors = registry.register(ledger, "main", "s1", request(request_id=f"r{k}", legs=[["BTC", 1]], T=t_r - HOUR + span,
                                                                      sources=[]), lambda: t_r, set(), config, data | {"cutoff": t_r})
        assert errors is None and th["size"] == th["N"]
    theses = ledger.theses("main")
    F = positions.exact(theses[1]["E_r"]) / 10_000
    assert len(theses[-1]["N"]) > 2 * 4300 and all(positions.exact(th["E_r"]) == 10_000 * F ** k for k, th in enumerate(theses))
    assert positions.admit(10_000.0, theses, [], data, start + n * span + HOUR, 0.1)["E_r"] == 10_000 * F ** n
