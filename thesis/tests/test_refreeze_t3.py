"""The draft must not mistake a zero-latency packing exercise for a completion bound."""

from pathlib import Path

from thesis import runner
from thesis.tests.test_snapshot_schedule import inventory, packed

MINUTE = 60_000


def completion(packing: int) -> tuple[int, int]:
    """(minutes after midnight UTC, mark pauses crossed) of the chosen budget: the packing, 1 minute of prewarm debt, 2 of
    resolutions and 6 of latency, and an 8-minute mark allowance for each hour whose preparation (55 s before it) the work
    is still running at."""
    work, pauses = packing + 1 + 2 + 6, 0
    while 5 + work + 8 * pauses >= 60 * (pauses + 1) - 55 / 60:
        pauses += 1
    return 5 + work + 8 * pauses, pauses


def test_t3_budgets_cross_the_pauses_the_timeline_reaches(tmp_path, monkeypatch):
    stress = packed(monkeypatch, tmp_path / "s", inventory(515))
    recorded = packed(monkeypatch, tmp_path / "r", inventory(339))
    assert (stress, recorded) == (188, 153)
    assert completion(stress) == (3 * 60 + 46, 3)
    assert completion(recorded) == (3 * 60 + 11, 3)
    assert completion(stress)[0] * MINUTE < runner.SESSION_OFFSET - 55_000


def test_t3_text_states_the_budgets_and_the_miss_table():
    root = Path(__file__).resolve().parents[2]
    for path in (root / "docs/whitepaper.tex", root / "audit/stage10/criteria-revision-draft.md"):
        text = path.read_text()
        assert "03:46 UTC (22:46 EST)" in text and "03:11 UTC (22:11 EST)" in text
        assert "188" in text and "153" in text and "796" in text and "620" in text
        assert "257 min" not in text and "252-minute" not in text and "05:03 UTC" not in text


def test_the_miss_table_floors_28_minus_20_over_r():
    assert [int(28 - 20 / r) for r in (1, 1.4, 2)] == [8, 13, 18]
    root = Path(__file__).resolve().parents[2]
    assert "13 at $r=1.4$" in (root / "docs/whitepaper.tex").read_text()


def test_the_draft_labels_both_human_approved_revisions_as_approved():
    root = Path(__file__).resolve().parents[2]
    text = (root / "audit/stage10/criteria-revision-draft.md").read_text()
    assert "21:44 UTC (16:44 EST)" in text
    assert "**APPROVED" in text
    assert "registered_at" in text
