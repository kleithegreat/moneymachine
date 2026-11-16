"""An incomplete daemon log must not hide a final ledger's pick."""

import json
import sqlite3
from pathlib import Path
from typing import Any

import pytest

from gate.control import runner
from gate.control.pick import pick
from gate.control.tests.fakes import ASKED, IDS, NOTICE, SERVED, STRENGTH, judgement, transcript


def test_kept_pick_is_judged_despite_a_partial_final_daemon_line(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    own = tmp_path / "agent" / IDS[8]
    workdir = own / "run"
    workdir.mkdir(parents=True)
    ledger = own / "ledger.sqlite"
    program = {"dsl": 1, "weight": {"const": 0.1, "unit": "1"}}
    with sqlite3.connect(ledger) as database:
        database.execute("CREATE TABLE experiments (id INTEGER PRIMARY KEY, program TEXT)")
        database.execute(
            "CREATE TABLE disclosures (id INTEGER PRIMARY KEY, experiment_id INTEGER, campaign TEXT, "
            "agent TEXT, kind TEXT, content TEXT)"
        )
        database.execute("INSERT INTO experiments VALUES (1, ?)", (json.dumps(program),))
        database.execute(
            "INSERT INTO disclosures VALUES (1, 1, ?, 'A', 'eval', ?)",
            (IDS[8], json.dumps({"result": {"sharpe_annualized": 2.0}})),
        )
    assert pick(ledger, IDS[8], "A") == program
    (workdir / "transcript.jsonl").write_text(transcript([ASKED]))
    (workdir / "daemon.log").write_bytes(b'{"cmd": "eval", "response": {"ok": tr')
    monkeypatch.setattr(runner, "wait_until_unnamed", lambda path: None)

    def judge(market_id: str, strength: float, kept: Path) -> dict[str, Any]:
        assert pick(kept, market_id, "A") == program
        return judgement(8, "earn", 1)

    line = runner.market_line(
        IDS[8],
        8,
        {"running_wins": 8, "running_losses": 0},
        own,
        {"strength": STRENGTH, "constants": {"NOTICE": NOTICE, "SERVED": list(SERVED)}},
        {IDS[8]: {"earns": False}},
        runner.count_evaluations,
        judge,
    )
    assert (line["evaluations"], line["agent_earns"], line["decision"]) == (1, True, "claim")
