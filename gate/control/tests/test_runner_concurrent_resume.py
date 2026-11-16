"""Two starts recovering one kept session must not count that market twice."""

import contextlib
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

from gate.control import runner
from gate.control.tests.fakes import IDS, Fakes, jsonl, world


def test_concurrent_restarts_record_one_market_once(tmp_path: Path) -> None:
    root = tmp_path / "study"
    world(root, [False] * len(IDS), ["earn"], room_limit=0)
    effects = Fakes(root)
    own = root / "work" / "agent" / IDS[0]
    market = effects.market(own / "market", IDS[0], effects.manifest["strength"])
    (own / "launched").touch()
    effects.session(market, own / "ledger.sqlite", IDS[0], own / "run")
    first_judge = threading.Event()
    both_judges = threading.Event()
    release = threading.Event()
    lock = threading.Lock()
    calls = 0

    def judge(market_id: str, strength: float, ledger: Path) -> dict[str, Any]:
        nonlocal calls
        with lock:
            calls += 1
            first_judge.set()
            if calls == 2:
                both_judges.set()
        assert release.wait(10)
        judged: dict[str, Any] = effects.judge(market_id, strength, ledger)
        return judged

    def start() -> None:
        runner.run(
            effects.out,
            effects.work,
            verify=effects.verify,
            room=lambda: None,
            market=effects.market,
            session=effects.session,
            spent=effects.spent,
            judge=judge,
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(start)
        try:
            assert first_judge.wait(5)
            second = pool.submit(start)
            both_judges.wait(1)
        finally:
            release.set()
        first.result(timeout=10)
        with contextlib.suppress(RuntimeError):
            second.result(timeout=10)

    assert [line["id"] for line in jsonl(effects.out / "results.jsonl")] == [IDS[0]]
