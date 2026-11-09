"""Executable C3 mechanism/ledger counterexamples from the 2026-11-03 GPT reviews."""

import json
import sqlite3
import struct
import subprocess
from pathlib import Path

import numpy as np
import pytest

from gate import kernel, markets
from gate.search import const, op
from ingest.policy import HOUR

DECISION = "audit/decisions.md: the mechanism check's two defects are qualified, not forked"
HUNT = "audit/reviews/2026-11-03-gpt-hunt-gate.md"


def arrays(bars):
    return {
        **{k: np.full((bars, 2), 100.0) for k in ("open", "high", "low", "close", "volume")},
        "funding": np.zeros((4 * bars + 1, 2)),
        "premium": np.zeros((4 * bars + 1, 2)),
    }


def evaluate(mm, market, tmp_path: Path, weight, condition, name="s"):
    strategy = tmp_path / f"{name}.json"
    strategy.write_text(
        json.dumps(
            {
                "dsl": 1,
                "name": name,
                "mechanism": {"counterparty": "synthetic", "predictions": ["true earns more"], "capacity": "small"},
                "weight": weight,
                "prediction": {"condition": condition},
            }
        )
    )
    ledger, trace = tmp_path / f"{name}.sqlite", tmp_path / f"{name}.jsonl"
    run = subprocess.run(
        kernel.command(
            "eval",
            strategy,
            "mechanism-defects",
            "gate",
            ledger,
            market,
            "--mechanism",
            "on",
            "--trace",
            str(trace),
            binary=mm,
        ),
        capture_output=True,
        text=True,
    )
    assert run.returncode == 0, run.stdout + run.stderr
    return json.loads(run.stdout)["disclosure"], [json.loads(line) for line in trace.read_text().splitlines()], ledger


@pytest.fixture
def closing(built_kernel, tmp_path: Path):
    a = arrays(6)
    a["volume"][0] = 1000
    a["premium"][:] = [1, -1]
    market = markets.write(
        tmp_path / "market", a, 0, {side: {"1000": 10.0, "10000": 10.0} for side in ("buy", "sell")}, taker_fee=0.001
    )
    weight = op("if", op("gt", {"input": "volume"}, const(500, "coin")), const(0.1), const(0))
    return evaluate(built_kernel, market, tmp_path, weight, op("gt", {"input": "premium"}, const(0)))


@pytest.mark.xfail(strict=True, reason=f"{DECISION}; {HUNT} finding 1: closing costs omitted")
def test_mechanism_mean_net_return_includes_closing_fills(closing) -> None:
    """Two flat-price, one-exposure round trips; both fees and slippage must be netted."""
    disclosure, trace, _ = closing
    result = disclosure["result"]
    fills = [e for e in trace if e["type"] == "fill"]
    expected_fills = [(8 * HOUR, 10, 100.1, 1.001), (12 * HOUR, -10, 99.9, 0.999)]
    for coin in ("S0", "S1"):
        actual = [(e["t"], e["qty"], e["price"], e["fee"]) for e in fills if e["coin"] == coin]
        assert len(actual) == 2
        for got, expected in zip(actual, expected_fills):
            assert got == pytest.approx(expected)
    assert len(fills) == 4
    entry_cost = 10 * (100.1 - 100) + 10 * 100.1 * 0.001
    closing_cost = 10 * (100 - 99.9) + 10 * 99.9 * 0.001
    expected_net = -(entry_cost + closing_cost) / 10_000
    assert entry_cost == pytest.approx(2.001)
    assert closing_cost == pytest.approx(1.999)
    assert result["final_equity"] == pytest.approx(10_000 - 2 * (entry_cost + closing_cost))
    assert result["total_return"] == pytest.approx(2 * expected_net)
    mechanism = result["mechanism"]
    assert (mechanism["exposures_true"], mechanism["exposures_false"]) == (1, 1)
    assert mechanism["share_true"] == 0.5
    assert (mechanism["mean_true"], mechanism["mean_false"]) == pytest.approx((expected_net, expected_net)), mechanism


@pytest.mark.xfail(strict=True, reason=f"{DECISION}; {HUNT} finding 2: undefined predictions shrink coverage")
def test_undefined_prediction_cannot_pass_with_under_ten_percent_coverage(built_kernel, tmp_path: Path) -> None:
    """The constant-prediction replay measures all held exposures without changing trading."""
    a = arrays(104)
    a["funding"][:, 0] = -1e-5
    a["premium"][4:8] = [1, -1]
    market = markets.write(
        tmp_path / "market", a, 0, {side: {"1000": 0.0, "10000": 0.0} for side in ("buy", "sell")}, taker_fee=0
    )
    premium = {"input": "premium"}
    undefined_bool = op("gt", op("div", const(1), const(0)), const(0))
    condition = op("if", op("gt", op("abs", premium), const(0)), op("gt", premium, const(0)), undefined_bool)
    sparse, trace, _ = evaluate(built_kernel, market, tmp_path, const(0.1), condition, "sparse")
    total, total_trace, _ = evaluate(built_kernel, market, tmp_path, const(0.1), op("gt", const(1), const(0)), "total")
    assert sparse["strategy"] == total["strategy"]
    assert trace == total_trace
    assert {k: v for k, v in sparse["result"].items() if k != "mechanism"} == {
        k: v for k, v in total["result"].items() if k != "mechanism"
    }
    fills = [e for e in trace if e["type"] == "fill"]
    assert len(fills) == 2 and all(e["t"] == 8 * HOUR and e["qty"] == 10 for e in fills)
    held = 2 * sum(e["type"] == "equity" and e["t"] > 8 * HOUR for e in trace)
    assert total["result"]["mechanism"]["exposures_true"] == held
    mechanism = sparse["result"]["mechanism"]
    assert (mechanism["exposures_true"], mechanism["exposures_false"]) == (1, 1)
    assert mechanism["mean_true"] > mechanism["mean_false"]
    true_share = mechanism["exposures_true"] / held
    assert true_share < 0.1
    assert held - mechanism["exposures_true"] - mechanism["exposures_false"] > held / 2
    assert not mechanism["pass"], {"mechanism": mechanism, "held": held, "actual_true_share": true_share}


@pytest.mark.xfail(strict=True, reason=f"{DECISION}; {HUNT} finding 4: REPLACE bypasses append-only triggers")
def test_separate_connection_cannot_replace_kernel_result(closing) -> None:
    _, _, ledger = closing
    with sqlite3.connect(ledger) as db:
        db.execute("PRAGMA recursive_triggers = OFF")
        assert db.execute("PRAGMA recursive_triggers").fetchone() == (0,)
        original = db.execute("SELECT experiment_id, returns, summary, result_hash FROM results").fetchone()
        summary = json.dumps(json.loads(original[2]) | {"total_return": 1.0})
        replacement = (original[0], struct.pack("<100d", *([0.1] * 100)), summary, "replacement")
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            db.execute(
                "INSERT OR REPLACE INTO results (experiment_id, returns, summary, result_hash) VALUES (?, ?, ?, ?)",
                replacement,
            )
        assert db.execute("SELECT experiment_id, returns, summary, result_hash FROM results").fetchone() == original


def test_insert_or_ignore_duplicate_strategy_is_harmless(closing) -> None:
    _, _, ledger = closing
    with sqlite3.connect(ledger) as db:
        db.execute("PRAGMA recursive_triggers = OFF")
        original = db.execute("SELECT hash, canonical, created FROM strategies").fetchall()
        assert len(original) == 1
        strategy_hash, _, created = original[0]
        cursor = db.execute(
            "INSERT OR IGNORE INTO strategies (hash, canonical, created) VALUES (?, ?, ?)",
            (strategy_hash, "must not overwrite the canonical strategy", created + 1),
        )
        assert cursor.rowcount == 0
        assert db.execute("SELECT hash, canonical, created FROM strategies").fetchall() == original
