"""Bitemporal SQL, ASOF join, retraction, polarity, and QA tests for `fabric.catalog`."""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from fabric.cas import CASStore
from fabric.catalog import FabricCatalog
from fabric.views import PodView


def _register_blob(cas: CASStore, catalog: FabricCatalog, source_id: str, data: bytes) -> str:
    rec = cas.put(data)
    catalog.record_artifact(rec, source_id=source_id, ingested_at="2026-01-01T00:00:00Z")
    return rec.sha256


def test_pit_latest_vintages_and_non_resurrecting_retraction(tmp_path: Path) -> None:
    cas = CASStore(tmp_path)
    with FabricCatalog() as cat:
        h1 = _register_blob(cas, cat, "fred_macro", b"v1")
        h2 = _register_blob(cas, cat, "fred_macro", b"v2")
        h3 = _register_blob(cas, cat, "fred_macro", b"v3-retract")
        eid = cat.upsert_entity(entity_type="COUNTRY", canonical_name="USA", external_ids={"iso": "US"})

        cat.add_observation(
            entity_id=eid,
            source_id="fred_macro",
            metric="payems",
            value_num=150.0,
            event_time="2026-01-01T00:00:00Z",
            known_at="2026-01-05T13:30:00Z",
            revision_id=1,
            revision_state="ORIGINAL",
            raw_hash=h1,
        )
        cat.add_observation(
            entity_id=eid,
            source_id="fred_macro",
            metric="payems",
            value_num=165.0,
            event_time="2026-01-01T00:00:00Z",
            known_at="2026-02-05T13:30:00Z",
            revision_id=2,
            revision_state="RESTATED",
            raw_hash=h2,
        )
        cat.add_observation(
            entity_id=eid,
            source_id="fred_macro",
            metric="payems",
            value_num=None,
            event_time="2026-01-01T00:00:00Z",
            known_at="2026-03-01T00:00:00Z",
            revision_id=3,
            revision_state="RETRACTED",
            raw_hash=h3,
        )

        assert cat.pit_latest("2026-01-04T00:00:00Z", entity_id=eid) == []
        r1 = cat.pit_latest("2026-01-10T00:00:00Z", entity_id=eid)
        assert len(r1) == 1 and r1[0]["value_num"] == 150.0

        r2 = cat.pit_latest("2026-02-10T00:00:00Z", entity_id=eid)
        assert len(r2) == 1 and r2[0]["value_num"] == 165.0

        # Retraction at March 1 must suppress the key completely rather than resurrect v2/v1.
        assert cat.pit_latest("2026-03-10T00:00:00Z", entity_id=eid) == []

        diffs = cat.revision_diff_observations(entity_id=eid, metric="payems", as_of="2026-02-10T00:00:00Z")
        assert [d["revision_id"] for d in diffs] == [1, 2]
        assert diffs[1]["delta_from_prev"] == pytest.approx(15.0)
        assert cat.audit_invariants(now="2026-03-10T00:00:00Z")["passed"] is True


def test_obs_vs_fcst_polarity_and_lookahead_guard(tmp_path: Path) -> None:
    cas = CASStore(tmp_path)
    with FabricCatalog() as cat:
        h = _register_blob(cas, cat, "pm_src", b"polarity")
        eid = cat.upsert_entity(entity_type="COMPANY", canonical_name="ACME")

        with pytest.raises(ValueError, match="causal violation for OBS"):
            cat.add_observation(
                entity_id=eid,
                source_id="pm_src",
                metric="revenue",
                value_num=10.0,
                event_time="2026-05-01T00:00:00Z",
                known_at="2026-04-01T00:00:00Z",
                polarity="OBS",
                raw_hash=h,
            )

        # FCST for future horizon is valid and must NOT leak into default OBS pit_latest queries.
        cat.add_observation(
            entity_id=eid,
            source_id="pm_src",
            metric="approval_prob",
            value_num=0.72,
            event_time="2026-08-01T00:00:00Z",
            known_at="2026-04-01T00:00:00Z",
            polarity="FCST",
            raw_hash=h,
        )
        assert cat.pit_latest("2026-04-10T00:00:00Z", entity_id=eid) == []
        fcst = cat.pit_latest("2026-04-10T00:00:00Z", entity_id=eid, include_fcst=True)
        assert len(fcst) == 1 and fcst[0]["polarity"] == "FCST"


def test_bitemporal_asof_join_and_edge_validity_windows(tmp_path: Path) -> None:
    cas = CASStore(tmp_path)
    with FabricCatalog() as cat:
        h = _register_blob(cas, cat, "market_src", b"asof")
        btc = cat.upsert_entity(entity_type="CRYPTO_ASSET", canonical_name="BTC")
        eth = cat.upsert_entity(entity_type="CRYPTO_ASSET", canonical_name="ETH")
        macro = cat.upsert_entity(entity_type="MACRO_SERIES", canonical_name="DGS10")

        # Fast prices at t=10:00, 10:05; slow macro at t=10:02 (known later!)
        cat.add_observation(
            entity_id=btc,
            source_id="market_src",
            metric="mid_px",
            value_num=100_000.0,
            event_time="2026-05-01T10:00:00Z",
            known_at="2026-05-01T10:00:01Z",
            raw_hash=h,
        )
        cat.add_observation(
            entity_id=btc,
            source_id="market_src",
            metric="mid_px",
            value_num=100_500.0,
            event_time="2026-05-01T10:05:00Z",
            known_at="2026-05-01T10:05:01Z",
            raw_hash=h,
        )
        cat.add_observation(
            entity_id=macro,
            source_id="market_src",
            metric="yield_10y",
            value_num=4.15,
            event_time="2026-05-01T09:50:00Z",
            known_at="2026-05-01T09:55:00Z",
            raw_hash=h,
        )
        # Future revision of 10:02 known only at 11:00 must stay invisible at as_of=10:10.
        cat.add_observation(
            entity_id=macro,
            source_id="market_src",
            metric="yield_10y",
            value_num=9.99,
            event_time="2026-05-01T10:02:00Z",
            known_at="2026-05-01T11:00:00Z",
            raw_hash=h,
        )

        joined = cat.bitemporal_asof_join(
            left_entity_id=btc,
            left_source_id="market_src",
            left_metric="mid_px",
            right_entity_id=macro,
            right_source_id="market_src",
            right_metric="yield_10y",
            as_of="2026-05-01T10:10:00Z",
        )
        assert [row["right_value_num"] for row in joined] == [4.15, 4.15]

        # Graph G(t) confidence & validity window check
        cat.add_edge(
            src_entity_id=btc,
            dst_entity_id=eth,
            rel_type="CORRELATED_CLUSTER",
            valid_from="2026-01-01T00:00:00Z",
            valid_to="2026-06-01T00:00:00Z",
            known_at="2026-01-02T00:00:00Z",
            confidence=0.85,
            source_id="market_src",
            raw_hash=h,
        )
        assert len(cat.pit_edges("2026-05-01T00:00:00Z")) == 1
        assert len(cat.pit_edges("2026-07-01T00:00:00Z")) == 0
        strict_view = PodView(pod_id="hi_conf", min_confidence=0.90)
        assert len(cat.pit_edges("2026-05-01T00:00:00Z", pod_view=strict_view)) == 0


def test_audit_detects_orphan_raw_hash(tmp_path: Path) -> None:
    orphan = hashlib.sha256(b"never-registered").hexdigest()
    with FabricCatalog() as cat:
        eid = cat.upsert_entity(entity_type="COMPANY", canonical_name="ORPHAN_CORP")
        cat.add_observation(
            entity_id=eid,
            source_id="unregistered",
            metric="px",
            value_num=1.0,
            event_time="2026-01-01T00:00:00Z",
            known_at="2026-01-01T00:01:00Z",
            raw_hash=orphan,
        )
        report = cat.audit_invariants(now="2026-01-02T00:00:00Z")
        assert report["passed"] is False
        assert report["orphan_raw_hash_violations"] == 1
