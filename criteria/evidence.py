"""The committed evidence a criterion is judged on. A criterion whose evidence does not exist yet is
skipped, never passed."""

import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
AUDIT = REPO / "audit"


def load(relative):
    path = AUDIT / relative
    if not path.exists():
        pytest.skip(f"audit/{relative} not produced yet")
    return json.loads(path.read_text())


def ingest_reports():
    """Stage 0 ingestion reports, oldest first."""
    return [json.loads(p.read_text()) for p in sorted((AUDIT / "stage0").glob("ingest-*.json"))]
