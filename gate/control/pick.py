"""A session's pick (step 3): the same function for the agent and for G100."""

import json
import math
import sqlite3
from contextlib import closing
from pathlib import Path
from typing import Any

QUERY = (
    "SELECT e.program, d.content FROM disclosures d JOIN experiments e ON e.id = d.experiment_id "
    "WHERE d.campaign = ? AND d.agent = ? AND d.kind = 'eval' ORDER BY d.id"
)


def evaluated(ledger: Path, campaign: str, agent: str) -> list[tuple[dict[str, Any], float | None]]:
    """One agent's evaluations in one campaign, in order: each program with its disclosed search-period
    `sharpe_annualized`, None where the evaluation disclosed no finite one."""
    with closing(sqlite3.connect(ledger)) as db:
        rows = db.execute(QUERY, (campaign, agent)).fetchall()
    found: list[tuple[dict[str, Any], float | None]] = []
    for text, content in rows:
        value = json.loads(content).get("result", {}).get("sharpe_annualized")
        usable = value is not None and math.isfinite(value)
        found.append((json.loads(text), float(value) if usable else None))
    return found


def pick(ledger: Path, campaign: str, agent: str) -> dict[str, Any] | None:
    """Among the programs one agent evaluated in one campaign, the one with the highest disclosed search-period
    `sharpe_annualized`; ties go to the earliest evaluation. None when no evaluation disclosed the statistic."""
    best: dict[str, Any] | None = None
    best_score = -math.inf
    for program, value in evaluated(ledger, campaign, agent):
        if value is not None and (best is None or value > best_score):
            best = program
            best_score = value
    return best
