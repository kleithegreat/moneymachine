"""The draft must not mistake a zero-latency packing exercise for a completion bound."""

from pathlib import Path

from thesis import runner
from thesis.tests.test_snapshot_schedule import inventory, packed


def test_t3_reports_the_stress_budget_miss_and_the_effective_prep_cutoff(tmp_path, monkeypatch):
    minute = 60_000
    stress = packed(monkeypatch, tmp_path, inventory(863))
    projected = runner.SNAPSHOT_OFFSET + (stress + 1 + 4 * 8 + 2 + 6) * minute
    assert stress == 257 and projected == (5 * 60 + 3) * minute
    assert projected > runner.SESSION_OFFSET - 55_000
    root = Path(__file__).resolve().parents[2]
    for path in (root / "docs/whitepaper.tex", root / "audit/stage10/criteria-revision-draft.md"):
        text = path.read_text()
        assert "04:59:05" in text and "05:03" in text
        assert "257" in text and "252" in text


def test_the_draft_labels_both_human_approved_revisions_as_approved():
    root = Path(__file__).resolve().parents[2]
    text = (root / "audit/stage10/criteria-revision-draft.md").read_text()
    assert "21:44 UTC (16:44 EST)" in text
    assert "**APPROVED" in text
    assert "registered_at" in text
