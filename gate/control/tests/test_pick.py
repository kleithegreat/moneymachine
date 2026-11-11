"""Step 3 of the build plan: the pick (gate/control/pick.py), the same function for both arms.

`pick(ledger, campaign, agent)` returns the program as a dict, or None. Ledgers are built with the real kernel on a
small market, and the scores the pick must agree with are read straight from the ledger's tables."""

import json
from pathlib import Path
from typing import Any

import pytest

from gate import markets, search
from gate.control import measure, pick
from gate.control.tests import support

pytestmark = pytest.mark.usefixtures("built_kernel")


@pytest.fixture(scope="module")
def market(tmp_path_factory: pytest.TempPathFactory) -> Path:
    return Path(markets.write_market(tmp_path_factory.mktemp("pick-market"), "pick-m", days=60, model="N1"))


def candidates() -> list[dict[str, Any]]:
    return [
        support.momentum(0.02, "m02"),
        support.momentum(0.1, "m10"),
        support.momentum(-0.05, "r05"),
        support.program({"const": 0.05, "unit": "1"}, "long"),
        support.program({"const": -0.05, "unit": "1"}, "short"),
    ]


def fill(ledger: Path, market: Path, programs: list[dict[str, Any]], campaign: str = "c", agent: str = "A") -> None:
    for program in programs:
        support.evaluate(program, market, ledger, campaign, agent)


def best_of(ledger: Path, campaign: str, agent: str) -> tuple[str, float]:
    return max(support.ledger_scores(ledger, campaign, agent), key=lambda row: row[1])


def test_pick_is_the_highest_scoring_program(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    fill(ledger, market, candidates())
    scores = support.ledger_scores(ledger, "c", "A")
    assert len(scores) == 5
    assert len({s for _, s in scores}) > 1
    chosen = pick.pick(ledger, "c", "A")
    best_text, _ = best_of(ledger, "c", "A")
    assert chosen == json.loads(best_text)


def test_pick_is_json_the_kernel_accepts(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    fill(ledger, market, candidates())
    chosen = pick.pick(ledger, "c", "A")
    assert chosen is not None
    result = support.evaluate(chosen, market, tmp_path / "other.sqlite")
    assert result["disclosure"]["result"]["sharpe_annualized"] is not None


def test_rescored_pick_equals_the_ledgers_score(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    fill(ledger, market, candidates())
    chosen = pick.pick(ledger, "c", "A")
    _, best = best_of(ledger, "c", "A")
    assert measure.score(chosen, market) == best


@pytest.mark.parametrize("names", [("first", "second"), ("zz-first", "aa-second")])
def test_ties_go_to_the_earlier_evaluation(tmp_path: Path, market: Path, names: tuple[str, str]) -> None:
    """The same program under two names scores alike; the name is outside its identity, so only the order tells."""
    scratch = tmp_path / "scratch.sqlite"
    scored = [(support.score(p, market, scratch), p) for p in candidates()]
    best = max((s, p) for s, p in scored if s is not None)[1]
    others = [p for p in candidates() if p is not best]
    early, late = (dict(best, name=n) for n in names)
    ledger = tmp_path / "l.sqlite"
    fill(ledger, market, [others[0], early, others[1], late, others[2]])
    chosen = pick.pick(ledger, "c", "A")
    assert chosen is not None
    assert chosen["name"] == names[0]


def test_programs_without_a_statistic_are_ignored(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    unscored = [support.momentum(0.02, "hidden"), support.program({"input": "nonesuch"}, "rejected")]
    for program in unscored:
        support.evaluate(program, market, ledger, "c", "A", disclose="fills")
    assert pick.pick(ledger, "c", "A") is None
    fill(ledger, market, [support.momentum(0.05, "scored")])
    chosen = pick.pick(ledger, "c", "A")
    assert chosen is not None
    assert chosen["name"] == "scored"


def test_an_agent_with_no_evaluation_has_no_pick(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    fill(ledger, market, candidates(), "c", "B")
    assert pick.pick(ledger, "c", "A") is None


def test_pick_reads_only_its_campaign_and_agent(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    ranked = sorted(candidates(), key=lambda p: support.score(p, market, tmp_path / "s.sqlite") or -1e9)
    worst, best = ranked[0], ranked[-1]
    fill(ledger, market, [worst, ranked[1]], "c1", "A")
    fill(ledger, market, [best], "c1", "B")
    fill(ledger, market, [best], "c2", "A")
    fill(ledger, market, [ranked[2], worst], "c2", "B")
    first = pick.pick(ledger, "c1", "A")
    assert first == json.loads(best_of(ledger, "c1", "A")[0])
    assert first["name"] != best["name"]
    assert pick.pick(ledger, "c2", "B") == json.loads(best_of(ledger, "c2", "B")[0])
    assert pick.pick(ledger, "c1", "B")["name"] == best["name"]
    assert pick.pick(ledger, "c3", "A") is None


@pytest.mark.slow  # a real G100 search: one hundred kernel evaluations
def test_pick_is_the_same_function_for_the_searcher(tmp_path: Path, market: Path) -> None:
    ledger = tmp_path / "l.sqlite"
    spent = search.run("G100", market, ledger, "g", 12345)
    assert spent > 0
    chosen = pick.pick(ledger, "g", "G100")
    assert chosen is not None
    rows = support.ledger_scores(ledger, "g", "G100")
    assert len(rows) <= 100
    assert any(json.loads(text) == chosen for text, _ in rows)
    top = max(score for _, score in rows)
    chosen_scores = [score for text, score in rows if json.loads(text) == chosen]
    assert max(chosen_scores) == top
