"""The committed evidence a criterion is judged on. Evidence of a stage not yet exited, and not produced yet, skips its
criterion, never passes it; a missing file of an exited stage fails."""

import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
AUDIT = REPO / "audit"
NOT_EXITED = ("stage3/", "stage4/")


def load(relative):
    path = AUDIT / relative
    if not path.exists():
        assert relative.startswith(NOT_EXITED), f"audit/{relative} is missing, and its stage has exited"
        pytest.skip(f"audit/{relative} not produced yet")
    return json.loads(path.read_text())


def ingest_reports():
    """Stage 0 ingestion reports, oldest first."""
    return [json.loads(p.read_text()) for p in sorted((AUDIT / "stage0").glob("ingest-*.json"))]
