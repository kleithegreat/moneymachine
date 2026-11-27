"""End-to-end tests for `CausalFabricService` MCP tools and entity blinding."""

from __future__ import annotations

import asyncio
from pathlib import Path

import pytest

from fabric.cas import CASStore
from fabric.catalog import FabricCatalog
from fabric.ledger import ForecastLedger
from fabric.mcp_server import CausalFabricService, create_mcp_server
from fabric.search import PitSearchIndex
from fabric.views import PodView


def test_mcp_six_tools_causal_isolation_and_blinding(tmp_path: Path) -> None:
    cas = CASStore(tmp_path)
    ledger = ForecastLedger(tmp_path / "ledger.sqlite")
    with FabricCatalog() as cat:
        h_v1 = cas.put(b"v1-sec").sha256
        h_v2 = cas.put(b"v2-sec").sha256
        h_obs = cas.put(b"temp-obs").sha256
        cat.record_artifact(cas.put(b"v1-sec"), source_id="sec_edgar", ingested_at="2026-01-01T00:00:00Z")
        cat.record_artifact(cas.put(b"v2-sec"), source_id="sec_edgar", ingested_at="2026-02-01T00:00:00Z")
        cat.record_artifact(cas.put(b"temp-obs"), source_id="macro_datalayer", ingested_at="2026-01-01T00:00:00Z")

        nvda = cat.upsert_entity(
            entity_type="COMPANY",
            canonical_name="NVIDIA",
            aliases=["NVDA"],
            external_ids={"ticker": "NVDA", "lon": "-121.96", "lat": "37.37"},
        )
        tsmc = cat.upsert_entity(entity_type="COMPANY", canonical_name="TSMC", aliases=["TSM"])
        cat.add_edge(
            src_entity_id=nvda,
            dst_entity_id=tsmc,
            rel_type="FABRICATED_BY",
            valid_from="2025-01-01T00:00:00Z",
            known_at="2026-01-02T00:00:00Z",
            source_id="sec_edgar",
            raw_hash=h_v1,
        )
        cat.add_observation(
            entity_id=nvda,
            source_id="macro_datalayer",
            metric="t2m_c",
            value_num=18.5,
            unit="C",
            event_time="2026-01-15T12:00:00Z",
            known_at="2026-01-15T12:05:00Z",
            raw_hash=h_obs,
        )
        cat.add_document(
            entity_id=nvda,
            source_id="sec_edgar",
            doc_type="10K",
            title="NVIDIA 2026 Filing",
            body_text="NVIDIA relies on TSMC foundry supply.\nMargin stable.",
            sections={"risk": "TSMC concentration risk."},
            event_time="2026-01-20T00:00:00Z",
            known_at="2026-01-21T00:00:00Z",
            raw_hash=h_v1,
        )
        cat.add_document(
            entity_id=nvda,
            source_id="sec_edgar",
            doc_type="10K",
            title="NVIDIA Q1 Amendment",
            body_text="NVIDIA relies on TSMC foundry supply.\nPackaging capacity constrained.",
            sections={"risk": "TSMC CoWoS bottleneck added."},
            event_time="2026-02-20T00:00:00Z",
            known_at="2026-02-21T00:00:00Z",
            revision_id=2,
            raw_hash=h_v2,
        )

        blind_view = PodView(pod_id="pod_alpha", blinding_mode="BLINDED_ENTITIES", blind_salt="secret-42")
        idx = PitSearchIndex()
        idx.index_from_catalog(cat)
        service = CausalFabricService(
            cat,
            pod_view=blind_view,
            search_index=idx,
            ledger=ledger,
            pinned_as_of="2026-03-01T00:00:00Z",
        )

        # 1. Resolve entity + blinding check
        res = service.resolve_entity("NVIDIA", as_of_utc="2026-02-28T00:00:00Z")
        assert len(res["entities"]) == 1
        masked_nvda = res["entities"][0]["entity_id"]
        assert masked_nvda.startswith("ENT_")
        assert res["entities"][0]["canonical_name"] == masked_nvda
        assert len(res["edges"]) == 1

        # 2. Query PIT series using masked entity pseudonym
        series = service.query_pit_series(masked_nvda, ["t2m_c"], as_of_utc="2026-02-28T00:00:00Z")
        assert series["count"] == 1
        assert series["observations"][0]["value_num"] == pytest.approx(18.5)

        # 3. Search documents with blind redaction and pinned clock guard
        docs = service.search_documents("Packaging capacity", as_of_utc="2026-02-28T00:00:00Z")
        assert len(docs["hits"]) == 1
        hit = docs["hits"][0]
        assert hit["doc_id"].startswith("DOC_")
        assert "NVIDIA" not in hit["title"]
        assert "TSMC" not in hit["snippet"]

        with pytest.raises(ValueError, match="exceeds pinned pod clock"):
            service.search_documents("Packaging", as_of_utc="2026-04-01T00:00:00Z")

        # 4. Diff document versions (t_prev -> t_curr) with blind redaction
        diff = service.diff_document_versions(
            source_id="sec_edgar",
            entity_id=masked_nvda,
            doc_type="10K",
            t_prev_utc="2026-02-01T00:00:00Z",
            t_curr_utc="2026-02-28T00:00:00Z",
            as_of_utc="2026-02-28T00:00:00Z",
        )
        assert any("Packaging capacity constrained." in line for line in diff["added_lines"])
        assert "NVIDIA" not in diff["unified_diff"]
        assert "TSMC" not in str(diff["section_diffs"])

        # 5. Sample spatial tensor
        tensor = service.sample_spatial_tensor(
            [-123.0, 36.0, -121.0, 38.0],
            "t2m_c",
            "2026-01-01T00:00:00Z",
            "2026-02-01T00:00:00Z",
            as_of_utc="2026-02-28T00:00:00Z",
        )
        assert tensor["summary"]["count"] == 1
        assert tensor["summary"]["mean"] == pytest.approx(18.5)

        # 6. Register prospective forecast -> ledger records canonical entity ID & citations
        reg = service.register_prospective_forecast(
            entity_id=masked_nvda,
            target_event="COWOS_SHORTAGE_Q2",
            horizon_end_utc="2026-06-30T00:00:00Z",
            prob_estimate=0.81,
            rationale_citations=[{"doc_id": hit["doc_id"], "entity_id": masked_nvda}],
            crowd_baseline=0.55,
            submitted_at_utc="2026-02-28T00:00:00Z",
        )
        assert reg["entity_id"] == masked_nvda
        assert ledger.verify_chain() is True
        assert ledger.count_forecasts("pod_alpha") == 1

        # Verify FastMCP server registers all 6 tools
        server = create_mcp_server(service)
        tools = asyncio.run(server.list_tools())
        assert {t.name for t in tools} == {
            "resolve_entity",
            "query_pit_series",
            "search_documents",
            "diff_document_versions",
            "sample_spatial_tensor",
            "register_prospective_forecast",
        }
