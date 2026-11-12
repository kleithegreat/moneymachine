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


def pick(ledger: Path, campaign: str, agent: str) -> dict[str, Any] | None:
    """Among the programs one agent evaluated in one campaign, the one with the highest disclosed search-period
    `sharpe_annualized`; ties go to the earliest evaluation. None when no evaluation disclosed the statistic."""
    best: dict[str, Any] | None = None
    best_score = -math.inf
    with closing(sqlite3.connect(ledger)) as db:
        rows = db.execute(QUERY, (campaign, agent)).fetchall()
    for text, content in rows:
        value = json.loads(content).get("result", {}).get("sharpe_annualized")
        if value is None or not math.isfinite(value):
            continue
        if best is None or value > best_score:
            best = json.loads(text)
            best_score = float(value)
    return best
