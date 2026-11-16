"""Ending a killed runner must not discard the session it has already spent."""

from pathlib import Path

from gate.control import runner
from gate.control.tests.fakes import Fakes, IDS, calls, drive, is_market_line, jsonl, world


def test_end_judges_the_kept_ninth_session_before_declaring_an_early_end(tmp_path: Path) -> None:
    root = tmp_path / "study"
    world(root, [False] * len(IDS), ["earn"] * 9, kills={("session", 8)})
    interrupted = drive(root, runner.run, restarts=1)
    assert interrupted.exits == [-9]
    assert len(interrupted.lines) == 8
    effects = Fakes(root)

    runner.end(effects.out, verify=effects.verify)
    runner.run(
        effects.out,
        effects.work,
        verify=effects.verify,
        room=effects.room,
        market=effects.market,
        session=effects.session,
        spent=effects.spent,
        judge=effects.judge,
    )

    lines = jsonl(effects.out / "results.jsonl")
    markets = [line for line in lines if is_market_line(line)]
    assert [line["id"] for line in markets] == IDS[:9]
    assert markets[-1]["decision"] == "claim"
    assert len([call for call in calls(effects.ctl) if call["kind"] == "session"]) == 9
