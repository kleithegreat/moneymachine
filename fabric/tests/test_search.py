"""Point-in-time Tantivy search tests enforcing strict `known_at <= as_of` visibility."""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from fabric.cas import CASStore
from fabric.catalog import FabricCatalog
from fabric.search import PitSearchIndex
from fabric.views import PodView


def test_pit_search_enforces_as_of_ceiling_and_pod_filters(tmp_path: Path) -> None:
    idx_dir = tmp_path / "tantivy"
    idx = PitSearchIndex(idx_dir)

    idx.index_document(
        doc_id="doc-early",
        title="Biotech Phase 3 Enrollment Complete",
        body="AlphaBio announced completed enrollment for trial NCT001.",
        source_id="clinicaltrials_v2",
        doc_type="trial_update",
        known_at="2026-02-01T12:00:00Z",
        raw_hash=hashlib.sha256(b"early").hexdigest(),
        entity_id="ent-1",
        license_class="PUBLIC_DOMAIN",
    )
    idx.index_document(
        doc_id="doc-future",
        title="Biotech Phase 3 Primary Endpoint Met",
        body="AlphaBio achieved statistical significance in trial NCT001 topline readout.",
        source_id="sec_edgar",
        doc_type="8k",
        known_at="2026-06-15T12:00:00Z",
        raw_hash=hashlib.sha256(b"future").hexdigest(),
        entity_id="ent-1",
        license_class="PUBLIC_DOMAIN",
    )

    early_hits = idx.search("AlphaBio enrollment readout", as_of="2026-03-01T00:00:00Z")
    assert [h.doc_id for h in early_hits] == ["doc-early"]

    all_hits = idx.search("AlphaBio", as_of="2026-07-01T00:00:00Z")
    assert {h.doc_id for h in all_hits} == {"doc-early", "doc-future"}

    view = PodView(pod_id="ct_only", allowed_sources=("clinicaltrials_v2",))
    filtered_hits = idx.search("AlphaBio", as_of="2026-07-01T00:00:00Z", pod_view=view)
    assert [h.doc_id for h in filtered_hits] == ["doc-early"]

    # Persistence check across reopen from disk
    reopened = PitSearchIndex(idx_dir)
    assert [h.doc_id for h in reopened.search("significance", as_of="2026-07-01T00:00:00Z")] == ["doc-future"]


def test_pit_search_rebuilds_from_catalog_and_rejects_empty_query(tmp_path: Path) -> None:
    cas = CASStore(tmp_path)
    with FabricCatalog() as cat:
        rec = cas.put(b"filing")
        cat.record_artifact(rec, source_id="sec_edgar", ingested_at="2026-01-01T00:00:00Z")
        eid = cat.upsert_entity(entity_type="COMPANY", canonical_name="NVDA")
        cat.add_document(
            entity_id=eid,
            source_id="sec_edgar",
            doc_type="10K",
            title="Supply Constraints",
            body_text="TSMC CoWoS packaging capacity expanded materially.",
            event_time="2026-01-10T00:00:00Z",
            known_at="2026-01-11T00:00:00Z",
            raw_hash=rec.sha256,
        )
        idx = PitSearchIndex()
        count = idx.index_from_catalog(cat)
        assert count == 1
        hits = idx.search("CoWoS packaging", as_of="2026-01-12T00:00:00Z")
        assert len(hits) == 1
        with pytest.raises(ValueError, match="cannot be empty"):
            idx.search("   ", as_of="2026-01-12T00:00:00Z")
