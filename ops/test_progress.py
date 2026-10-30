"""PROGRESS.md stays a current-state document small enough to read whole at the start of every session (CLAUDE.md)."""

from pathlib import Path

CAP = 12 * 1024


def test_progress_fits_its_cap():
    assert len((Path(__file__).resolve().parents[1] / "PROGRESS.md").read_bytes()) <= CAP
