"""Unit tests for `fabric.views` entity blinding and `fabric.ledger` append-only SQLite store."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from fabric.ledger import ForecastLedger
from fabric.views import EntityBlinder, PodView


def test_entity_blinder_determinism_and_redaction() -> None:
    blinder = EntityBlinder("salt-alpha")
    other = EntityBlinder("salt-beta")

    a1 = blinder.entity_alias("uuid-nvda")
    a2 = blinder.entity_alias("uuid-nvda")
    b1 = other.entity_alias("uuid-nvda")
    assert a1 == a2
    assert a1 != b1
    assert a1.startswith("ENT_")
    assert blinder.doc_alias("doc-123").startswith("DOC_")

    redacted = blinder.redact_text(
        "On 2026-04-12T08:00:00Z, NVIDIA (NVDA) expanded capacity at TSMC.",
        {"NVIDIA": a1, "NVDA": a1},
        extra_terms=["TSMC"],
    )
    assert "[DATE]" in redacted
    assert "NVIDIA" not in redacted
    assert "NVDA" not in redacted
    assert "TSMC" not in redacted
    assert a1 in redacted


def test_pod_view_validation() -> None:
    view = PodView(pod_id="macro_pod", allowed_sources=("fred",), min_confidence=0.8)
    assert view.blinding_mode == "NONE"
    with pytest.raises(ValueError):
        PodView(pod_id="bad", min_quality=1.5)


def test_forecast_ledger_append_only_hash_chain_and_scoring(tmp_path: Path) -> None:
    db_path = tmp_path / "ledger.sqlite"
    ledger = ForecastLedger(db_path)

    f1 = ledger.submit_forecast(
        pod_id="pod_a",
        entity_id="ent_1",
        target_event="APPROVED_2026",
        horizon_end="2026-12-31T00:00:00Z",
        prob_estimate=0.8,
        crowd_baseline=0.5,
        rationale_citations=[{"doc_id": "d1", "raw_hash": "abc"}],
        submitted_at="2026-01-10T00:00:00Z",
    )
    f2 = ledger.submit_forecast(
        pod_id="pod_a",
        entity_id="ent_2",
        target_event="HIKE_Q2",
        horizon_end="2026-06-30T00:00:00Z",
        prob_estimate=0.2,
        crowd_baseline=0.4,
        rationale_citations=[{"doc_id": "d2"}],
        submitted_at="2026-01-11T00:00:00Z",
    )
    assert f1.prev_hash == ForecastLedger.GENESIS_HASH
    assert f2.prev_hash == f1.entry_hash
    assert ledger.verify_chain() is True

    # UPDATE and DELETE triggers abort mutations.
    with sqlite3.connect(db_path) as con:
        with pytest.raises(sqlite3.DatabaseError, match="UPDATE on forecasts forbidden"):
            con.execute("UPDATE forecasts SET prob_estimate = 0.9 WHERE forecast_id = ?", (f1.forecast_id,))
        with pytest.raises(sqlite3.DatabaseError, match="DELETE on forecasts forbidden"):
            con.execute("DELETE FROM forecasts WHERE forecast_id = ?", (f1.forecast_id,))

    ledger.resolve_forecast(f1.forecast_id, 1, "h1", resolved_at="2026-12-31T01:00:00Z")
    ledger.resolve_forecast(f2.forecast_id, 0, "h2", resolved_at="2026-06-30T01:00:00Z")
    summary = ledger.score_summary("pod_a")
    assert summary["resolved_count"] == 2
    assert summary["mean_brier"] == pytest.approx(0.04)
    assert summary["crowd_mean_brier"] == pytest.approx(0.205)
    assert summary["brier_skill_vs_crowd"] == pytest.approx(1.0 - (0.04 / 0.205))

    # Even if triggers are bypassed offline, verify_chain detects any tampering.
    with sqlite3.connect(db_path) as con:
        con.execute("DROP TRIGGER forecasts_no_update")
        con.execute("UPDATE forecasts SET prob_estimate = 0.55 WHERE forecast_id = ?", (f1.forecast_id,))
        con.commit()
    assert ledger.verify_chain() is False
