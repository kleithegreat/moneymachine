"""Built-kernel counterexamples to findings 1–6 of the static kernel hunt.

Oracles: kernel/INVARIANTS.md I1, I5, I9, I10; kernel/DSL.md target
weights/hold/zero-close semantics; docs/whitepaper.tex §6 non-interference.
Finding 3 tests the advertised portfolio budget, not just I9's emitted vector.
N1–N3 never delist; liquidation/bankruptcy remain possible (unbounded wicks),
and DSL expressions can be undefined even with complete, finite market inputs.
"""

import json
import sqlite3
import struct
import subprocess

import numpy as np
import polars as pl
import pytest

from gate import kernel, markets
from gate.search import const, op
from ingest.policy import DELTA, HOUR
from ingest.store import Store

HUNT = "audit/reviews/2026-11-03-gpt-hunt-kernel.md"


def arrays(bars=8, coins=1):
    return {**{k: np.full((bars, coins), 100.0) for k in ("open", "high", "low", "close", "volume")},
            "funding": np.zeros((4 * bars + 1, coins)), "premium": np.zeros((4 * bars + 1, coins))}


def write_market(path, a, bps=0, fee=0, holdout_days=0):
    return markets.write(path, a, holdout_days,
                         {side: {"1000": bps, "10000": bps} for side in ("buy", "sell")}, taker_fee=fee)


def evaluate(mm, market, tmp_path, weight, name="s", holdout_from=None):
    strategy = tmp_path / f"{name}.json"
    strategy.write_text(json.dumps({
        "dsl": 1, "name": name,
        "mechanism": {"counterparty": "synthetic", "predictions": [], "capacity": "small"},
        "weight": weight,
    }))
    ledger, trace = tmp_path / f"{name}.sqlite", tmp_path / f"{name}.jsonl"

    def run(cmd, path, *extra):
        r = subprocess.run(kernel.command(cmd, path, "kernel-defects", "gate", ledger, market,
                                           *extra, binary=mm), capture_output=True, text=True)
        assert r.returncode == 0, r.stdout + r.stderr
        return json.loads(r.stdout)

    if holdout_from is not None:
        run("eval", strategy)
        with sqlite3.connect(ledger) as db:
            trial = db.execute("SELECT trial FROM experiments").fetchone()[0]
        run("select", trial, "--note", "synthetic frozen trial")
        out = run("holdout", strategy, "--holdout-store", str(market / "holdout"),
                  "--holdout-from", str(holdout_from), "--trace", str(trace))
    else:
        out = run("eval", strategy, "--trace", str(trace))
    with sqlite3.connect(ledger) as db:
        blob = db.execute("SELECT returns FROM results ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    returns = struct.unpack(f"<{len(blob) // 8}d", blob)
    return out["disclosure"]["result"], [json.loads(line) for line in trace.read_text().splitlines()], returns


def events(trace, kind, t=None):
    return [e for e in trace if e["type"] == kind and (t is None or e["t"] == t)]


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 1: future trading activity changes current allocation")
def test_future_trades_cannot_change_current_orders(built_kernel, tmp_path):
    """I1, SEMANTICS §3/§7: identical observations through 12:02 imply identical decisions.

    Both histories state S0's halt at 24:00, known at 24:02 under §3, with no settlement price.
    The synthetic `delistings` dataset is provisional: §3 defines records, not their store adapter.
    """
    a = arrays(coins=2)
    a["close"][3:, 1] = 110
    for key in ("open", "high", "low"):
        a[key][4:, 1] = 110
    a["high"][3, 1] = 110
    traces = []
    known = []
    for name, last in (("early", 12 * HOUR), ("late", 20 * HOUR)):
        market = write_market(tmp_path / name, a)
        markets.write_venue(market, {"S0": (3, 10, True), "S1": (3, 10, False)},
                            {side: {"1000": 0, "10000": 0} for side in ("buy", "sell")}, taker_fee=0)
        for path in (market / "store" / "bars_4h").glob("*.parquet"):
            df = pl.read_parquet(path).with_columns(
                pl.when((pl.col("coin") == "S0") & (pl.col("eventTime") > last))
                .then(0).otherwise(pl.col("trades")).alias("trades"))
            path.chmod(0o644)
            df.write_parquet(path)
        store = Store(market / "store")
        store.write("delistings", pl.DataFrame({"coin": ["S0"], "eventTime": [24 * HOUR]}), 1, "synthetic")
        known.append([store.revisions("delistings"),
                      *[store.as_of(dataset, 12 * HOUR + DELTA, 1).sort(["coin", "eventTime"])
                        for dataset in ("bars_4h", "funding")]])
        _, trace, _ = evaluate(built_kernel, market, tmp_path, const(2), name)
        traces.append(trace)
    assert all(x.equals(y) for x, y in zip(*known))
    for trace in traces:
        assert [(e["coin"], e["weight"], e["qty"]) for e in events(trace, "decision", 4 * HOUR + DELTA)] == \
            [("S0", 1, 100), ("S1", 1, 100)]
        assert [(e["coin"], e["qty"]) for e in events(trace, "fill", 8 * HOUR)] == [("S0", 100), ("S1", 100)]
    for hour in (8, 12):
        decisions = [[(e["coin"], e["weight"], e["qty"])
                      for e in events(trace, "decision", hour * HOUR + DELTA)] for trace in traces]
        assert decisions[0] == decisions[1] == [], {"hour": hour, "decisions": decisions}
    equity = [events(trace, "equity", 16 * HOUR)[0]["equity"] for trace in traces]
    assert equity == pytest.approx([10_000 + 100 * (110 - 100)] * 2)


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 2: pending zero-weight close reopens after liquidation")
def test_zero_close_cannot_reopen_after_liquidation(built_kernel, tmp_path):
    """Finding 2: closing an already liquidated short must leave $500 flat (DSL zero close)."""
    a = arrays()
    a["premium"][:12] = -1
    a["premium"][12:] = 1
    a["high"][3] = 290
    a["close"][4:] = 80
    a["low"][4:] = 80
    for key in ("open", "high"):
        a[key][5:] = 80
    market = write_market(tmp_path / "market", a)
    weight = op("if", op("lt", {"input": "premium"}, const(0)), const(-0.5), const(0))
    result, trace, _ = evaluate(built_kernel, market, tmp_path, weight)
    entry, = events(trace, "fill", 8 * HOUR)
    assert (entry["qty"], entry["price"]) == (-50, 100)
    close, = events(trace, "decision", 12 * HOUR + DELTA)
    assert (close["weight"], close["qty"]) == (0, 50)
    liquidations = events(trace, "liquidation", 16 * HOUR)
    assert len(liquidations) == 1 and liquidations[0]["qty"] == 50
    assert liquidations[0]["price"] == 290
    assert 15_000 - 50 * 290 == 500
    assert events(trace, "equity", 16 * HOUR)[0]["equity"] == 500
    assert not events(trace, "fill", 16 * HOUR), {"trace": trace, "result": result}
    assert result["final_equity"] == pytest.approx(500)


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 3: mandatory holds reserve no portfolio gross budget")
def test_undefined_holds_reserve_portfolio_budget(built_kernel, tmp_path):
    """Finding 3: $20k held on $10k equity leaves zero of the advertised 2× budget."""
    a = arrays(coins=2)
    a["premium"][:12] = [1, -1]
    a["premium"][12:] = [-1, 1]
    a["close"][5:] = 95
    a["low"][5:] = 95
    for key in ("open", "high"):
        a[key][6:] = 95
    market = write_market(tmp_path / "market", a)
    weight = op("if", op("gt", {"input": "premium"}, const(0)), const(2), op("div", const(1), const(0)))
    _, trace, _ = evaluate(built_kernel, market, tmp_path, weight)
    fills = events(trace, "fill")
    held = sum(e["qty"] for e in fills if e["coin"] == "S0" and e["t"] <= 20 * HOUR)
    fresh = sum(e["qty"] for e in fills if e["coin"] == "S1" and e["t"] <= 20 * HOUR)
    assert held == 200
    assert events(trace, "hold", 12 * HOUR + DELTA) == [
        {"type": "hold", "t": 12 * HOUR + DELTA, "coin": "S0", "why": "undefined"}]
    assert events(trace, "equity", 20 * HOUR)[0]["equity"] == 10_000
    assert 200 * (100 - 95) == 1_000
    equity24 = events(trace, "equity", 24 * HOUR)[0]["equity"]
    assert (abs(held) + abs(fresh)) * 100 <= 2 * 10_000, {"held": held, "fresh": fresh, "equity24": equity24}
    assert equity24 == pytest.approx(9_000)


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 4: next target uses pre-fill equity")
def test_next_target_uses_post_fill_equity(built_kernel, tmp_path):
    """Finding 4: DSL weight 1 targets actual equity (I5), net of completed fill costs."""
    market = write_market(tmp_path / "market", arrays(), bps=10, fee=0.001)
    _, trace, _ = evaluate(built_kernel, market, tmp_path, const(1))
    first, = events(trace, "decision", 4 * HOUR + DELTA)
    assert (first["weight"], first["qty"]) == (1, 100)
    entry, = events(trace, "fill", 8 * HOUR)
    assert (entry["qty"], entry["price"], entry["fee"]) == pytest.approx((100, 100.1, 10.01))
    equity = 10_000 - 100 * (100.1 - 100) - 10.01
    assert equity == pytest.approx(9_979.99)
    assert events(trace, "equity", 12 * HOUR)[0]["equity"] == pytest.approx(equity)
    target_delta = np.trunc((equity / 100 - 100) * 1000) / 1000
    assert target_delta == pytest.approx(-0.200)
    orders = events(trace, "decision", 8 * HOUR + DELTA)
    assert [e["qty"] for e in orders] == pytest.approx([-0.200]), orders


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 5: reporting window resurrects bankrupt equity")
def test_reporting_window_cannot_resurrect_bankrupt_account(built_kernel, tmp_path):
    """Finding 5: I10 equity stays zero even when the bankruptcy is in the replay prefix."""
    a = arrays(bars=12)
    a["high"][3] = 400
    market = write_market(tmp_path / "market", a, holdout_days=1)
    prefix, prefix_trace, _ = evaluate(built_kernel, market, tmp_path, const(-0.5), "prefix")
    liquidation, = events(prefix_trace, "liquidation", 16 * HOUR)
    assert (liquidation["qty"], liquidation["price"]) == (50, 400)
    assert prefix["final_equity"] == 0
    assert prefix["total_return"] == -1
    result, trace, returns = evaluate(built_kernel, market, tmp_path, const(-0.5), holdout_from=24 * HOUR)
    marks = events(trace, "equity")
    assert marks and all(e["equity"] == 0 for e in marks)
    assert returns and all(r == 0 for r in returns)
    assert result["final_equity"] == 0, result
    assert result["total_return"] == -1


@pytest.mark.xfail(strict=True, reason=f"{HUNT} finding 6: holdout trace and cost summary omit boundary fill")
def test_reporting_trace_includes_boundary_fill_costs(built_kernel, tmp_path):
    """Finding 6: a full I5/disclosure reconciliation includes the entry at boundary H."""
    a = arrays(bars=12)
    a["premium"][20:24] = 1
    market = write_market(tmp_path / "market", a, bps=10, fee=0.001, holdout_days=1)
    weight = op("if", op("gt", {"input": "premium"}, const(0)), const(0.5), const(0))
    full_market = write_market(tmp_path / "full-market", a, bps=10, fee=0.001)
    _, full_trace, _ = evaluate(built_kernel, full_market, tmp_path, weight, "full")
    order, = events(full_trace, "decision", 20 * HOUR + DELTA)
    assert (order["weight"], order["qty"]) == (0.5, 50)
    entry, = events(full_trace, "fill", 24 * HOUR)
    assert (entry["qty"], entry["price"], entry["fee"]) == pytest.approx((50, 100.1, 5.005))
    result, trace, returns = evaluate(built_kernel, market, tmp_path, weight, holdout_from=24 * HOUR)
    entry_fee, exit_fee = 50 * 100.1 * 0.001, 50 * 99.9 * 0.001
    assert (entry_fee, exit_fee) == pytest.approx((5.005, 4.995))
    assert returns[0] == pytest.approx(-0.0010005)
    assert result["final_equity"] == pytest.approx(9_980)
    assert result["total_return"] == pytest.approx(-0.002)
    fills = events(trace, "fill")
    assert [(e["t"], e["qty"]) for e in fills] == [(24 * HOUR, 50), (28 * HOUR, -50)], {
        "fills": fills, "result": result, "returns": returns}
    assert sum(e["fee"] for e in fills) == pytest.approx(entry_fee + exit_fee)
    assert result["fees"] == pytest.approx(10)
    assert result["slippage"] == pytest.approx(10)
    assert result["turnover"] == pytest.approx(10_000)
    assert result["fills"] == 2
