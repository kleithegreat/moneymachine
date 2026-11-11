"""Shared helpers for study 1's tests. They call the frozen kernel and generator directly, never the code under test,
so a test of a step does not lean on another step's module."""

import json
import math
import sqlite3
import subprocess
from pathlib import Path
from typing import Any

from gate import markets
from gate.agent import campaigns
from gate.kernel import command

PLANTED = (0, 1, 2, 3, 4, 5)
DAYS = 730
HOLDOUT_DAYS = 180

_INPUTS: dict[str, Any] = {}


def inputs() -> dict[str, Any]:
    """The series' inputs, resolved once per process."""
    if not _INPUTS:
        _INPUTS.update(campaigns.series_inputs())
    return _INPUTS


def study_market(root: Path, market_id: str, beta: float) -> Path:
    """A market as the plan defines it, built here from the generator."""
    shared = inputs()
    arrays = markets.generate("N2", shared["params"], market_id, DAYS, PLANTED, beta)
    return Path(markets.write(root, arrays, HOLDOUT_DAYS, shared["cost_cells"]))


def program(weight: dict[str, Any], name: str = "p") -> dict[str, Any]:
    return {
        "dsl": 1,
        "name": name,
        "mechanism": {"counterparty": "test", "predictions": ["none"], "capacity": "test"},
        "weight": weight,
    }


def momentum(size: float, name: str = "p") -> dict[str, Any]:
    """Size times the sign of the last bar's close minus open."""
    move = {"op": "sub", "args": [{"input": "close"}, {"input": "open"}]}
    return program(
        {"op": "mul", "args": [{"op": "sign", "args": [move]}, {"const": size, "unit": "1"}]},
        name,
    )


def evaluate(
    prog: dict[str, Any] | Path,
    market: Path,
    ledger: Path,
    campaign: str = "c",
    agent: str = "a",
    disclose: str = "sharpe_annualized",
) -> dict[str, Any]:
    """One `mm eval` on a market, into `ledger`; the parsed output line."""
    path = prog
    if isinstance(prog, dict):
        folder = ledger.parent / "programs"
        folder.mkdir(exist_ok=True)
        path = folder / f"{len(list(folder.iterdir()))}.json"
        path.write_text(json.dumps(prog))
    cmd = command("eval", path, campaign, agent, ledger, market, "--disclose", disclose)
    out = subprocess.run(cmd, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    parsed: dict[str, Any] = json.loads((out.stdout or out.stderr).strip().splitlines()[-1])
    return parsed


def score(prog: dict[str, Any] | Path, market: Path, ledger: Path) -> float | None:
    """The disclosed `sharpe_annualized`, or None when the kernel rejects the program or discloses no such field."""
    result = evaluate(prog, market, ledger, "scratch", "scratch")
    value = result.get("disclosure", {}).get("result", {}).get("sharpe_annualized")
    if value is None or not math.isfinite(value):
        return None
    return float(value)


def ledger_scores(ledger: Path, campaign: str, agent: str) -> list[tuple[str, float]]:
    """Every (program text, disclosed sharpe) of one campaign and agent, in evaluation order, read straight from the
    ledger's tables."""
    db = sqlite3.connect(ledger)
    rows = db.execute(
        "SELECT e.program, d.content FROM disclosures d JOIN experiments e ON e.id = d.experiment_id "
        "WHERE d.campaign = ? AND d.agent = ? AND d.kind = 'eval' ORDER BY d.id",
        (campaign, agent),
    ).fetchall()
    out: list[tuple[str, float]] = []
    for text, content in rows:
        value = json.loads(content)["result"].get("sharpe_annualized")
        if value is not None:
            out.append((text, float(value)))
    return out
