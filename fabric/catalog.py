"""Planes 1-3: DuckDB/DuckLake bitemporal catalog, ASOF joins, and QA audit."""

from __future__ import annotations

import difflib
import json
import math
import uuid
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from fabric.cas import CASRecord
from fabric.views import PodView

_VALID_REVISION_STATES = frozenset({"ORIGINAL", "RESTATED", "RETRACTED"})
_VALID_POLARITIES = frozenset({"OBS", "FCST", "SCHED"})

_SCHEMA_SQL = """
CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.raw_artifacts (
    raw_hash VARCHAR PRIMARY KEY,
    source_id VARCHAR NOT NULL,
    uri VARCHAR NOT NULL,
    byte_size BIGINT NOT NULL,
    compressed_size BIGINT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL,
    license_class VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_entity (
    entity_id UUID PRIMARY KEY,
    entity_type VARCHAR NOT NULL,
    canonical_name VARCHAR NOT NULL,
    aliases_json JSON NOT NULL DEFAULT '[]',
    external_ids_json JSON NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS core.rel_entity_edge (
    edge_id UUID PRIMARY KEY,
    src_entity_id UUID NOT NULL,
    dst_entity_id UUID NOT NULL,
    rel_type VARCHAR NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    known_at TIMESTAMPTZ NOT NULL,
    confidence DOUBLE NOT NULL,
    source_id VARCHAR NOT NULL,
    license_class VARCHAR NOT NULL,
    revision_id INTEGER NOT NULL DEFAULT 1,
    revision_state VARCHAR NOT NULL DEFAULT 'ORIGINAL',
    raw_hash VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS core.fact_observations (
    obs_id UUID PRIMARY KEY,
    entity_id UUID NOT NULL,
    source_id VARCHAR NOT NULL,
    metric VARCHAR NOT NULL,
    value_num DOUBLE,
    value_text VARCHAR,
    unit VARCHAR,
    event_time TIMESTAMPTZ NOT NULL,
    known_at TIMESTAMPTZ NOT NULL,
    revision_id INTEGER NOT NULL DEFAULT 1,
    revision_state VARCHAR NOT NULL DEFAULT 'ORIGINAL',
    polarity VARCHAR NOT NULL DEFAULT 'OBS',
    quality_score DOUBLE NOT NULL DEFAULT 1.0,
    license_class VARCHAR NOT NULL,
    raw_hash VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS core.fact_documents (
    doc_id UUID PRIMARY KEY,
    entity_id UUID,
    source_id VARCHAR NOT NULL,
    doc_type VARCHAR NOT NULL,
    title VARCHAR NOT NULL,
    body_text VARCHAR NOT NULL,
    sections_json JSON NOT NULL DEFAULT '{}',
    event_time TIMESTAMPTZ NOT NULL,
    known_at TIMESTAMPTZ NOT NULL,
    revision_id INTEGER NOT NULL DEFAULT 1,
    revision_state VARCHAR NOT NULL DEFAULT 'ORIGINAL',
    polarity VARCHAR NOT NULL DEFAULT 'OBS',
    quality_score DOUBLE NOT NULL DEFAULT 1.0,
    license_class VARCHAR NOT NULL,
    raw_hash VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS core.fact_expectations (
    expectation_id UUID PRIMARY KEY,
    entity_id UUID NOT NULL,
    source_id VARCHAR NOT NULL,
    target_event VARCHAR NOT NULL,
    horizon_end TIMESTAMPTZ NOT NULL,
    prob_or_value DOUBLE NOT NULL,
    unit VARCHAR NOT NULL DEFAULT 'PROBABILITY',
    polarity VARCHAR NOT NULL DEFAULT 'FCST',
    known_at TIMESTAMPTZ NOT NULL,
    revision_id INTEGER NOT NULL DEFAULT 1,
    revision_state VARCHAR NOT NULL DEFAULT 'ORIGINAL',
    quality_score DOUBLE NOT NULL DEFAULT 1.0,
    license_class VARCHAR NOT NULL,
    raw_hash VARCHAR NOT NULL
);
"""

# Rank revisions within each natural key BEFORE excluding 'RETRACTED' so a later
# retraction suppresses earlier revisions instead of resurrecting them.
_MACROS_SQL = """
CREATE OR REPLACE MACRO core.pit_latest(
    as_of_ts,
    allowed_sources,
    allowed_licenses,
    min_quality,
    polarity_filter
) AS TABLE (
    WITH ranked AS (
        SELECT
            obs_id,
            entity_id,
            source_id,
            metric,
            value_num,
            value_text,
            unit,
            event_time,
            known_at,
            revision_id,
            revision_state,
            polarity,
            quality_score,
            license_class,
            raw_hash,
            row_number() OVER (
                PARTITION BY entity_id, source_id, metric, event_time
                ORDER BY known_at DESC, revision_id DESC, obs_id DESC
            ) AS rn
        FROM core.fact_observations
        WHERE known_at <= as_of_ts
          AND (allowed_sources IS NULL OR list_contains(allowed_sources, source_id))
          AND (allowed_licenses IS NULL OR list_contains(allowed_licenses, license_class))
          AND (polarity_filter IS NULL OR polarity = polarity_filter)
    )
    SELECT
        obs_id,
        entity_id,
        source_id,
        metric,
        value_num,
        value_text,
        unit,
        event_time,
        known_at,
        revision_id,
        revision_state,
        polarity,
        quality_score,
        license_class,
        raw_hash
    FROM ranked
    WHERE rn = 1
      AND revision_state <> 'RETRACTED'
      AND quality_score >= min_quality
);

CREATE OR REPLACE MACRO core.pit_edges(
    as_of_ts,
    valid_at_ts,
    allowed_sources,
    allowed_licenses,
    min_confidence
) AS TABLE (
    WITH ranked AS (
        SELECT
            edge_id,
            src_entity_id,
            dst_entity_id,
            rel_type,
            valid_from,
            valid_to,
            known_at,
            confidence,
            source_id,
            license_class,
            revision_id,
            revision_state,
            raw_hash,
            row_number() OVER (
                PARTITION BY src_entity_id, dst_entity_id, rel_type
                ORDER BY known_at DESC, revision_id DESC, edge_id DESC
            ) AS rn
        FROM core.rel_entity_edge
        WHERE known_at <= as_of_ts
          AND (allowed_sources IS NULL OR list_contains(allowed_sources, source_id))
          AND (allowed_licenses IS NULL OR list_contains(allowed_licenses, license_class))
    )
    SELECT
        edge_id,
        src_entity_id,
        dst_entity_id,
        rel_type,
        valid_from,
        valid_to,
        known_at,
        confidence,
        source_id,
        license_class,
        revision_id,
        revision_state,
        raw_hash
    FROM ranked
    WHERE rn = 1
      AND revision_state <> 'RETRACTED'
      AND valid_from <= valid_at_ts
      AND (valid_to IS NULL OR valid_to > valid_at_ts)
      AND confidence >= min_confidence
);

CREATE OR REPLACE MACRO core.pit_expectations(
    as_of_ts,
    allowed_sources,
    allowed_licenses,
    min_quality
) AS TABLE (
    WITH ranked AS (
        SELECT
            expectation_id,
            entity_id,
            source_id,
            target_event,
            horizon_end,
            prob_or_value,
            unit,
            polarity,
            known_at,
            revision_id,
            revision_state,
            quality_score,
            license_class,
            raw_hash,
            row_number() OVER (
                PARTITION BY entity_id, source_id, target_event, horizon_end
                ORDER BY known_at DESC, revision_id DESC, expectation_id DESC
            ) AS rn
        FROM core.fact_expectations
        WHERE known_at <= as_of_ts
          AND (allowed_sources IS NULL OR list_contains(allowed_sources, source_id))
          AND (allowed_licenses IS NULL OR list_contains(allowed_licenses, license_class))
    )
    SELECT
        expectation_id,
        entity_id,
        source_id,
        target_event,
        horizon_end,
        prob_or_value,
        unit,
        polarity,
        known_at,
        revision_id,
        revision_state,
        quality_score,
        license_class,
        raw_hash
    FROM ranked
    WHERE rn = 1
      AND revision_state <> 'RETRACTED'
      AND quality_score >= min_quality
);
"""


def ensure_utc(ts: datetime | str) -> datetime:
    """Normalize an ISO-8601 string or datetime into a timezone-aware UTC datetime."""
    parsed = datetime.fromisoformat(ts.replace("Z", "+00:00")) if isinstance(ts, str) else ts
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def canonical_uuid(*parts: str) -> str:
    """Derive a deterministic UUIDv5 string from ordered namespace parts."""
    if not parts:
        raise ValueError("canonical_uuid requires at least one part")
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "::".join(parts)))


def _validate_unit_interval(name: str, value: float) -> float:
    if not math.isfinite(value) or value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be finite in [0.0, 1.0], got {value!r}")
    return float(value)


def _validate_state_and_polarity(revision_state: str, polarity: str | None = None) -> None:
    if revision_state not in _VALID_REVISION_STATES:
        raise ValueError(f"invalid revision_state: {revision_state!r}")
    if polarity is not None and polarity not in _VALID_POLARITIES:
        raise ValueError(f"invalid polarity: {polarity!r}")


def _validate_causal_times(
    event_ts: datetime,
    known_ts: datetime,
    *,
    polarity: str,
    max_known_at: datetime | None,
) -> None:
    if polarity == "OBS" and known_ts < event_ts:
        raise ValueError(
            f"causal violation for OBS: known_at {known_ts.isoformat()} < event_time {event_ts.isoformat()}"
        )
    if max_known_at is not None and known_ts > max_known_at:
        raise ValueError(f"future known_at rejected: {known_ts.isoformat()} > max_known_at {max_known_at.isoformat()}")


def _pod_filters(pod_view: PodView | None) -> tuple[list[str] | None, list[str] | None, float]:
    if pod_view is None:
        return None, None, 0.0
    sources = list(pod_view.allowed_sources) if pod_view.allowed_sources is not None else None
    licenses = list(pod_view.allowed_licenses) if pod_view.allowed_licenses is not None else None
    return sources, licenses, pod_view.min_quality


def _cursor_dicts(cur: duckdb.DuckDBPyConnection) -> list[dict[str, Any]]:
    cols = [desc[0] for desc in (cur.description or [])]
    rows: list[dict[str, Any]] = []
    for raw_row in cur.fetchall():
        record: dict[str, Any] = {}
        for key, val in zip(cols, raw_row, strict=True):
            record[key] = str(val) if isinstance(val, uuid.UUID) else val
        rows.append(record)
    return rows


class FabricCatalog:
    """Bitemporal DuckDB/DuckLake catalog implementing Planes 1-3 invariants."""

    def __init__(
        self,
        db_path: Path | str = ":memory:",
        *,
        ducklake_data_path: Path | str | None = None,
        read_only: bool = False,
    ) -> None:
        self.db_path = str(db_path)
        if self.db_path != ":memory:" and not read_only:
            Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        self.ducklake_data_path = Path(ducklake_data_path) if ducklake_data_path is not None else None
        self.read_only = read_only
        self.conn = duckdb.connect(self.db_path, read_only=read_only)
        self.conn.execute("SET TimeZone = 'UTC';")
        if self.ducklake_data_path is not None:
            self._attach_ducklake(self.ducklake_data_path)
        if not read_only:
            self.conn.execute(_SCHEMA_SQL)
            self.conn.execute(_MACROS_SQL)
            if self.ducklake_data_path is not None:
                self._apply_ducklake_sort_orders()

    def _attach_ducklake(self, data_path: Path) -> None:
        data_path.mkdir(parents=True, exist_ok=True)
        self.conn.execute("LOAD ducklake;")
        meta_path = data_path / "catalog.ducklake"
        escaped_meta = str(meta_path).replace("'", "''")
        escaped_data = str(data_path).replace("'", "''")
        self.conn.execute(
            f"ATTACH 'ducklake:{escaped_meta}' AS core_lake (DATA_PATH '{escaped_data}', DATA_INLINING_ROW_LIMIT 100);"
        )
        self.conn.execute("USE core_lake;")

    def _apply_ducklake_sort_orders(self) -> None:
        self.conn.execute("ALTER TABLE core.fact_observations SET SORTED BY (entity_id, metric, event_time, known_at);")
        self.conn.execute("ALTER TABLE core.fact_documents SET SORTED BY (entity_id, source_id, event_time, known_at);")
        self.conn.execute("ALTER TABLE core.fact_expectations SET SORTED BY (entity_id, target_event, known_at);")

    def close(self) -> None:
        self.conn.close()

    def __enter__(self) -> FabricCatalog:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def record_artifact(
        self,
        record: CASRecord,
        *,
        source_id: str,
        license_class: str = "PERSONAL_RESEARCH",
        ingested_at: datetime | str | None = None,
    ) -> None:
        """Register an immutable CAS artifact digest and provenance URI."""
        ts = ensure_utc(ingested_at) if ingested_at is not None else datetime.now(UTC)
        self.conn.execute(
            """
            INSERT OR REPLACE INTO core.raw_artifacts (
                raw_hash, source_id, uri, byte_size, compressed_size, ingested_at, license_class
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [record.sha256, source_id, record.uri, record.byte_size, record.compressed_size, ts, license_class],
        )

    def upsert_entity(
        self,
        *,
        entity_id: str | None = None,
        entity_type: str,
        canonical_name: str,
        aliases: Sequence[str] = (),
        external_ids: Mapping[str, str] | None = None,
        updated_at: datetime | str | None = None,
    ) -> str:
        """Create or update a canonical node in `core.dim_entity`."""
        eid = entity_id or canonical_uuid("entity", entity_type, canonical_name)
        ts = ensure_utc(updated_at) if updated_at is not None else datetime.now(UTC)
        existing = self.conn.execute(
            "SELECT aliases_json, external_ids_json, created_at FROM core.dim_entity WHERE entity_id = CAST(? AS UUID)",
            [eid],
        ).fetchone()
        merged_aliases: list[str] = []
        merged_ext: dict[str, str] = {}
        created_at = ts
        if existing is not None:
            merged_aliases.extend(json.loads(existing[0]))
            merged_ext.update(json.loads(existing[1]))
            created_at = existing[2]
        for alias in aliases:
            if alias and alias not in merged_aliases:
                merged_aliases.append(alias)
        if external_ids:
            merged_ext.update(external_ids)
        self.conn.execute(
            """
            INSERT OR REPLACE INTO core.dim_entity (
                entity_id, entity_type, canonical_name, aliases_json, external_ids_json, created_at, updated_at
            ) VALUES (CAST(? AS UUID), ?, ?, CAST(? AS JSON), CAST(? AS JSON), ?, ?)
            """,
            [eid, entity_type, canonical_name, json.dumps(merged_aliases), json.dumps(merged_ext), created_at, ts],
        )
        return eid

    def resolve_entity_aliases(self, entity_ids: Sequence[str] | None = None) -> dict[str, list[str]]:
        """Return all known names, aliases, and external identifiers per canonical entity."""
        if entity_ids is None:
            rows = self.conn.execute(
                "SELECT entity_id, canonical_name, aliases_json, external_ids_json FROM core.dim_entity"
            ).fetchall()
        elif not entity_ids:
            return {}
        else:
            rows = self.conn.execute(
                """
                SELECT entity_id, canonical_name, aliases_json, external_ids_json
                FROM core.dim_entity
                WHERE list_contains(CAST(? AS VARCHAR[]), CAST(entity_id AS VARCHAR))
                """,
                [list(entity_ids)],
            ).fetchall()
        out: dict[str, list[str]] = {}
        for eid, canonical_name, aliases_json, ext_json in rows:
            terms: list[str] = [canonical_name]
            for item in json.loads(aliases_json):
                if isinstance(item, str) and item and item not in terms:
                    terms.append(item)
            for val in json.loads(ext_json).values():
                if isinstance(val, str) and val and val not in terms:
                    terms.append(val)
            out[str(eid)] = terms
        return out

    def add_edge(
        self,
        *,
        src_entity_id: str,
        dst_entity_id: str,
        rel_type: str,
        valid_from: datetime | str,
        known_at: datetime | str,
        raw_hash: str,
        source_id: str,
        valid_to: datetime | str | None = None,
        confidence: float = 1.0,
        license_class: str = "PERSONAL_RESEARCH",
        revision_id: int = 1,
        revision_state: str = "ORIGINAL",
        edge_id: str | None = None,
        max_known_at: datetime | None = None,
    ) -> str:
        """Append a time-bounded, scored relationship revision to `core.rel_entity_edge`."""
        _validate_state_and_polarity(revision_state)
        conf = _validate_unit_interval("confidence", confidence)
        vf = ensure_utc(valid_from)
        vt = ensure_utc(valid_to) if valid_to is not None else None
        kt = ensure_utc(known_at)
        if vt is not None and vt < vf:
            raise ValueError(f"valid_to {vt.isoformat()} precedes valid_from {vf.isoformat()}")
        if max_known_at is not None and kt > max_known_at:
            raise ValueError(f"future known_at rejected: {kt.isoformat()}")
        eid = edge_id or canonical_uuid(
            "edge", src_entity_id, dst_entity_id, rel_type, vf.isoformat(), kt.isoformat(), str(revision_id)
        )
        self.conn.execute(
            """
            INSERT INTO core.rel_entity_edge (
                edge_id, src_entity_id, dst_entity_id, rel_type, valid_from, valid_to, known_at,
                confidence, source_id, license_class, revision_id, revision_state, raw_hash
            ) VALUES (
                CAST(? AS UUID), CAST(? AS UUID), CAST(? AS UUID), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            [
                eid,
                src_entity_id,
                dst_entity_id,
                rel_type,
                vf,
                vt,
                kt,
                conf,
                source_id,
                license_class,
                revision_id,
                revision_state,
                raw_hash,
            ],
        )
        return eid

    def add_observation(
        self,
        *,
        entity_id: str,
        source_id: str,
        metric: str,
        event_time: datetime | str,
        known_at: datetime | str,
        raw_hash: str,
        value_num: float | None = None,
        value_text: str | None = None,
        unit: str | None = None,
        revision_id: int = 1,
        revision_state: str = "ORIGINAL",
        polarity: str = "OBS",
        quality_score: float = 1.0,
        license_class: str = "PERSONAL_RESEARCH",
        obs_id: str | None = None,
        max_known_at: datetime | None = None,
    ) -> str:
        """Append a bitemporal observation or restatement/retraction revision."""
        _validate_state_and_polarity(revision_state, polarity)
        q = _validate_unit_interval("quality_score", quality_score)
        if value_num is not None and not math.isfinite(value_num):
            raise ValueError(f"value_num must be finite, got {value_num!r}")
        et = ensure_utc(event_time)
        kt = ensure_utc(known_at)
        _validate_causal_times(et, kt, polarity=polarity, max_known_at=max_known_at)
        oid = obs_id or canonical_uuid(
            "obs", entity_id, source_id, metric, et.isoformat(), kt.isoformat(), str(revision_id)
        )
        self.conn.execute(
            """
            INSERT INTO core.fact_observations (
                obs_id, entity_id, source_id, metric, value_num, value_text, unit,
                event_time, known_at, revision_id, revision_state, polarity,
                quality_score, license_class, raw_hash
            ) VALUES (
                CAST(? AS UUID), CAST(? AS UUID), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            [
                oid,
                entity_id,
                source_id,
                metric,
                value_num,
                value_text,
                unit,
                et,
                kt,
                revision_id,
                revision_state,
                polarity,
                q,
                license_class,
                raw_hash,
            ],
        )
        return oid

    def add_document(
        self,
        *,
        source_id: str,
        doc_type: str,
        title: str,
        body_text: str,
        event_time: datetime | str,
        known_at: datetime | str,
        raw_hash: str,
        entity_id: str | None = None,
        sections: Mapping[str, str] | None = None,
        revision_id: int = 1,
        revision_state: str = "ORIGINAL",
        polarity: str = "OBS",
        quality_score: float = 1.0,
        license_class: str = "PERSONAL_RESEARCH",
        doc_id: str | None = None,
        max_known_at: datetime | None = None,
    ) -> str:
        """Append a bitemporal document record to `core.fact_documents`."""
        _validate_state_and_polarity(revision_state, polarity)
        q = _validate_unit_interval("quality_score", quality_score)
        et = ensure_utc(event_time)
        kt = ensure_utc(known_at)
        _validate_causal_times(et, kt, polarity=polarity, max_known_at=max_known_at)
        did = doc_id or canonical_uuid(
            "doc", source_id, entity_id or "*", doc_type, et.isoformat(), kt.isoformat(), raw_hash, str(revision_id)
        )
        self.conn.execute(
            """
            INSERT INTO core.fact_documents (
                doc_id, entity_id, source_id, doc_type, title, body_text, sections_json,
                event_time, known_at, revision_id, revision_state, polarity,
                quality_score, license_class, raw_hash
            ) VALUES (
                CAST(? AS UUID), CAST(? AS UUID), ?, ?, ?, ?, CAST(? AS JSON),
                ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            [
                did,
                entity_id,
                source_id,
                doc_type,
                title,
                body_text,
                json.dumps(dict(sections) if sections else {}),
                et,
                kt,
                revision_id,
                revision_state,
                polarity,
                q,
                license_class,
                raw_hash,
            ],
        )
        return did

    def add_expectation(
        self,
        *,
        entity_id: str,
        source_id: str,
        target_event: str,
        horizon_end: datetime | str,
        prob_or_value: float,
        known_at: datetime | str,
        raw_hash: str,
        unit: str = "PROBABILITY",
        polarity: str = "FCST",
        revision_id: int = 1,
        revision_state: str = "ORIGINAL",
        quality_score: float = 1.0,
        license_class: str = "PERSONAL_RESEARCH",
        expectation_id: str | None = None,
        max_known_at: datetime | None = None,
    ) -> str:
        """Append a market-implied probability or sell-side consensus expectation snapshot."""
        _validate_state_and_polarity(revision_state, polarity)
        q = _validate_unit_interval("quality_score", quality_score)
        if not math.isfinite(prob_or_value):
            raise ValueError(f"prob_or_value must be finite, got {prob_or_value!r}")
        he = ensure_utc(horizon_end)
        kt = ensure_utc(known_at)
        if max_known_at is not None and kt > max_known_at:
            raise ValueError(f"future known_at rejected: {kt.isoformat()}")
        xid = expectation_id or canonical_uuid(
            "exp", entity_id, source_id, target_event, he.isoformat(), kt.isoformat(), str(revision_id)
        )
        self.conn.execute(
            """
            INSERT INTO core.fact_expectations (
                expectation_id, entity_id, source_id, target_event, horizon_end,
                prob_or_value, unit, polarity, known_at, revision_id,
                revision_state, quality_score, license_class, raw_hash
            ) VALUES (
                CAST(? AS UUID), CAST(? AS UUID), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            [
                xid,
                entity_id,
                source_id,
                target_event,
                he,
                float(prob_or_value),
                unit,
                polarity,
                kt,
                revision_id,
                revision_state,
                q,
                license_class,
                raw_hash,
            ],
        )
        return xid

    def pit_latest(
        self,
        as_of: datetime | str,
        *,
        pod_view: PodView | None = None,
        entity_id: str | None = None,
        metric: str | None = None,
        polarity: str | None = "OBS",
        include_fcst: bool = False,
    ) -> list[dict[str, Any]]:
        """Query the latest non-retracted revision of observations known at or before `as_of`."""
        as_of_ts = ensure_utc(as_of)
        sources, licenses, min_q = _pod_filters(pod_view)
        effective_polarity = None if include_fcst else polarity
        clauses = ["1 = 1"]
        params: list[Any] = [as_of_ts, sources, licenses, min_q, effective_polarity]
        if entity_id is not None:
            clauses.append("entity_id = CAST(? AS UUID)")
            params.append(entity_id)
        if metric is not None:
            clauses.append("metric = ?")
            params.append(metric)
        sql = f"""
            SELECT *
            FROM core.pit_latest(
                CAST(? AS TIMESTAMPTZ),
                CAST(? AS VARCHAR[]),
                CAST(? AS VARCHAR[]),
                ?,
                CAST(? AS VARCHAR)
            )
            WHERE {" AND ".join(clauses)}
            ORDER BY entity_id, metric, event_time
        """
        return _cursor_dicts(self.conn.execute(sql, params))

    def pit_edges(
        self,
        as_of: datetime | str,
        *,
        valid_at: datetime | str | None = None,
        pod_view: PodView | None = None,
        src_entity_id: str | None = None,
        dst_entity_id: str | None = None,
        rel_type: str | None = None,
    ) -> list[dict[str, Any]]:
        """Resolve point-in-time valid edges from `core.pit_edges`."""
        as_of_ts = ensure_utc(as_of)
        valid_ts = ensure_utc(valid_at) if valid_at is not None else as_of_ts
        sources, licenses, _ = _pod_filters(pod_view)
        min_conf = pod_view.min_confidence if pod_view is not None else 0.0
        clauses = ["1 = 1"]
        params: list[Any] = [as_of_ts, valid_ts, sources, licenses, min_conf]
        if src_entity_id is not None:
            clauses.append("src_entity_id = CAST(? AS UUID)")
            params.append(src_entity_id)
        if dst_entity_id is not None:
            clauses.append("dst_entity_id = CAST(? AS UUID)")
            params.append(dst_entity_id)
        if rel_type is not None:
            clauses.append("rel_type = ?")
            params.append(rel_type)
        sql = f"""
            SELECT *
            FROM core.pit_edges(
                CAST(? AS TIMESTAMPTZ),
                CAST(? AS TIMESTAMPTZ),
                CAST(? AS VARCHAR[]),
                CAST(? AS VARCHAR[]),
                ?
            )
            WHERE {" AND ".join(clauses)}
            ORDER BY src_entity_id, dst_entity_id, rel_type
        """
        return _cursor_dicts(self.conn.execute(sql, params))

    def pit_expectations(
        self,
        as_of: datetime | str,
        *,
        pod_view: PodView | None = None,
        entity_id: str | None = None,
        target_event: str | None = None,
    ) -> list[dict[str, Any]]:
        """Query market-implied or consensus expectation snapshots known by `as_of`."""
        as_of_ts = ensure_utc(as_of)
        sources, licenses, min_q = _pod_filters(pod_view)
        clauses = ["1 = 1"]
        params: list[Any] = [as_of_ts, sources, licenses, min_q]
        if entity_id is not None:
            clauses.append("entity_id = CAST(? AS UUID)")
            params.append(entity_id)
        if target_event is not None:
            clauses.append("target_event = ?")
            params.append(target_event)
        sql = f"""
            SELECT *
            FROM core.pit_expectations(
                CAST(? AS TIMESTAMPTZ),
                CAST(? AS VARCHAR[]),
                CAST(? AS VARCHAR[]),
                ?
            )
            WHERE {" AND ".join(clauses)}
            ORDER BY entity_id, target_event, horizon_end
        """
        return _cursor_dicts(self.conn.execute(sql, params))

    def revision_diff_observations(
        self,
        *,
        entity_id: str,
        metric: str,
        source_id: str | None = None,
        event_time: datetime | str | None = None,
        as_of: datetime | str | None = None,
        pod_view: PodView | None = None,
    ) -> list[dict[str, Any]]:
        """Return chronological observation revisions (`Delta_t^rev`) up to `as_of`."""
        sources, licenses, min_q = _pod_filters(pod_view)
        clauses = ["entity_id = CAST(? AS UUID)", "metric = ?", "quality_score >= ?"]
        params: list[Any] = [entity_id, metric, min_q]
        if source_id is not None:
            clauses.append("source_id = ?")
            params.append(source_id)
        if event_time is not None:
            clauses.append("event_time = ?")
            params.append(ensure_utc(event_time))
        if as_of is not None:
            clauses.append("known_at <= ?")
            params.append(ensure_utc(as_of))
        if sources is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), source_id)")
            params.append(sources)
        if licenses is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), license_class)")
            params.append(licenses)
        rows = _cursor_dicts(
            self.conn.execute(
                f"""
                SELECT *
                FROM core.fact_observations
                WHERE {" AND ".join(clauses)}
                ORDER BY event_time ASC, known_at ASC, revision_id ASC
                """,
                params,
            )
        )
        last_num_by_key: dict[tuple[str, str], float] = {}
        for row in rows:
            key = (row["source_id"], row["event_time"].isoformat())
            curr = row["value_num"]
            prev = last_num_by_key.get(key)
            row["delta_from_prev"] = (curr - prev) if (curr is not None and prev is not None) else None
            if row["revision_state"] == "RETRACTED":
                last_num_by_key.pop(key, None)
            elif curr is not None:
                last_num_by_key[key] = float(curr)
        return rows

    def _fetch_document_by_id(self, doc_id: str, as_of: datetime | None, pod_view: PodView | None) -> dict[str, Any]:
        sources, licenses, min_q = _pod_filters(pod_view)
        clauses = ["doc_id = CAST(? AS UUID)", "quality_score >= ?", "revision_state <> 'RETRACTED'"]
        params: list[Any] = [doc_id, min_q]
        if as_of is not None:
            clauses.append("known_at <= ?")
            params.append(as_of)
        if sources is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), source_id)")
            params.append(sources)
        if licenses is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), license_class)")
            params.append(licenses)
        rows = _cursor_dicts(
            self.conn.execute(f"SELECT * FROM core.fact_documents WHERE {' AND '.join(clauses)}", params)
        )
        if not rows:
            raise KeyError(f"document not visible at requested as_of: {doc_id}")
        return rows[0]

    def _fetch_latest_doc_at(
        self,
        *,
        as_of: datetime,
        source_id: str | None,
        entity_id: str | None,
        doc_type: str | None,
        pod_view: PodView | None,
    ) -> dict[str, Any]:
        sources, licenses, min_q = _pod_filters(pod_view)
        clauses = ["known_at <= ?", "quality_score >= ?", "revision_state <> 'RETRACTED'"]
        params: list[Any] = [as_of, min_q]
        if source_id is not None:
            clauses.append("source_id = ?")
            params.append(source_id)
        if entity_id is not None:
            clauses.append("entity_id = CAST(? AS UUID)")
            params.append(entity_id)
        if doc_type is not None:
            clauses.append("doc_type = ?")
            params.append(doc_type)
        if sources is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), source_id)")
            params.append(sources)
        if licenses is not None:
            clauses.append("list_contains(CAST(? AS VARCHAR[]), license_class)")
            params.append(licenses)
        rows = _cursor_dicts(
            self.conn.execute(
                f"""
                SELECT *
                FROM core.fact_documents
                WHERE {" AND ".join(clauses)}
                ORDER BY known_at DESC, event_time DESC, revision_id DESC
                LIMIT 1
                """,
                params,
            )
        )
        if not rows:
            raise KeyError(f"no visible document found at {as_of.isoformat()}")
        return rows[0]

    def diff_document_versions(
        self,
        *,
        doc_ids: Sequence[str] | None = None,
        source_id: str | None = None,
        entity_id: str | None = None,
        doc_type: str | None = None,
        t_prev: datetime | str | None = None,
        t_curr: datetime | str | None = None,
        as_of: datetime | str | None = None,
        pod_view: PodView | None = None,
    ) -> dict[str, Any]:
        """Compute line-level and structured-section diffs between two document versions."""
        as_of_ts = ensure_utc(as_of) if as_of is not None else None
        if doc_ids is not None:
            if len(doc_ids) != 2:
                raise ValueError("doc_ids must contain exactly 2 document IDs")
            doc_a = self._fetch_document_by_id(doc_ids[0], as_of_ts, pod_view)
            doc_b = self._fetch_document_by_id(doc_ids[1], as_of_ts, pod_view)
        elif t_prev is not None and t_curr is not None:
            prev_ts = ensure_utc(t_prev)
            curr_ts = ensure_utc(t_curr)
            if as_of_ts is not None and (prev_ts > as_of_ts or curr_ts > as_of_ts):
                raise ValueError("t_prev and t_curr cannot exceed as_of")
            doc_a = self._fetch_latest_doc_at(
                as_of=prev_ts, source_id=source_id, entity_id=entity_id, doc_type=doc_type, pod_view=pod_view
            )
            doc_b = self._fetch_latest_doc_at(
                as_of=curr_ts, source_id=source_id, entity_id=entity_id, doc_type=doc_type, pod_view=pod_view
            )
        else:
            raise ValueError("provide either doc_ids=[old_id, new_id] or both t_prev and t_curr")

        lines_a = doc_a["body_text"].splitlines()
        lines_b = doc_b["body_text"].splitlines()
        diff_lines = list(
            difflib.unified_diff(
                lines_a,
                lines_b,
                fromfile=f"{doc_a['doc_id']}@{doc_a['known_at'].isoformat()}",
                tofile=f"{doc_b['doc_id']}@{doc_b['known_at'].isoformat()}",
                lineterm="",
            )
        )
        added_lines = [line[1:] for line in diff_lines if line.startswith("+") and not line.startswith("+++")]
        removed_lines = [line[1:] for line in diff_lines if line.startswith("-") and not line.startswith("---")]

        sec_a = json.loads(doc_a["sections_json"])
        sec_b = json.loads(doc_b["sections_json"])
        section_diffs: dict[str, dict[str, Any]] = {}
        for key in sorted(set(sec_a) | set(sec_b)):
            if sec_a.get(key) != sec_b.get(key):
                section_diffs[key] = {"old": sec_a.get(key), "new": sec_b.get(key)}

        return {
            "from_doc_id": doc_a["doc_id"],
            "to_doc_id": doc_b["doc_id"],
            "entity_id": doc_b["entity_id"],
            "source_id": doc_b["source_id"],
            "doc_type": doc_b["doc_type"],
            "unified_diff": "\n".join(diff_lines),
            "added_lines": added_lines,
            "removed_lines": removed_lines,
            "section_diffs": section_diffs,
        }

    def bitemporal_asof_join(
        self,
        *,
        left_entity_id: str,
        left_source_id: str,
        left_metric: str,
        right_entity_id: str,
        right_source_id: str,
        right_metric: str,
        as_of: datetime | str,
        tolerance_seconds: float | None = None,
        start_time: datetime | str | None = None,
        end_time: datetime | str | None = None,
        pod_view: PodView | None = None,
    ) -> list[dict[str, Any]]:
        """Bitemporal ASOF join over PIT observation snapshots (`right.event_time <= left.event_time`)."""
        as_of_ts = ensure_utc(as_of)
        sources, licenses, min_q = _pod_filters(pod_view)
        left_clauses = [
            "entity_id = CAST(? AS UUID)",
            "source_id = ?",
            "metric = ?",
        ]
        params: list[Any] = [as_of_ts, sources, licenses, min_q, left_entity_id, left_source_id, left_metric]
        if start_time is not None:
            left_clauses.append("event_time >= ?")
            params.append(ensure_utc(start_time))
        if end_time is not None:
            left_clauses.append("event_time <= ?")
            params.append(ensure_utc(end_time))

        params.extend([as_of_ts, sources, licenses, min_q, right_entity_id, right_source_id, right_metric])
        tolerance_clause = ""
        if tolerance_seconds is not None:
            tolerance_clause = "AND (r.event_time IS NULL OR EXTRACT(EPOCH FROM (l.event_time - r.event_time)) <= ?)"
            params.append(float(tolerance_seconds))

        sql = f"""
            WITH left_pit AS (
                SELECT *
                FROM core.pit_latest(
                    CAST(? AS TIMESTAMPTZ),
                    CAST(? AS VARCHAR[]),
                    CAST(? AS VARCHAR[]),
                    ?,
                    'OBS'
                )
                WHERE {" AND ".join(left_clauses)}
            ),
            right_pit AS (
                SELECT *
                FROM core.pit_latest(
                    CAST(? AS TIMESTAMPTZ),
                    CAST(? AS VARCHAR[]),
                    CAST(? AS VARCHAR[]),
                    ?,
                    'OBS'
                )
                WHERE entity_id = CAST(? AS UUID)
                  AND source_id = ?
                  AND metric = ?
            )
            SELECT
                l.event_time AS left_event_time,
                l.known_at AS left_known_at,
                l.value_num AS left_value_num,
                l.value_text AS left_value_text,
                r.event_time AS right_event_time,
                r.known_at AS right_known_at,
                r.value_num AS right_value_num,
                r.value_text AS right_value_text
            FROM left_pit l
            ASOF LEFT JOIN right_pit r
              ON l.event_time >= r.event_time
            WHERE 1 = 1
              {tolerance_clause}
            ORDER BY l.event_time ASC
        """
        return _cursor_dicts(self.conn.execute(sql, params))

    def audit_invariants(self, *, now: datetime | str | None = None) -> dict[str, Any]:
        """Run QA checks covering causal times, provenance hashes, retractions, and bounds."""
        ref_now = ensure_utc(now) if now is not None else datetime.now(UTC)

        future_obs = self._scalar_count("SELECT COUNT(*) FROM core.fact_observations WHERE known_at > ?", [ref_now])
        future_docs = self._scalar_count("SELECT COUNT(*) FROM core.fact_documents WHERE known_at > ?", [ref_now])
        future_edges = self._scalar_count("SELECT COUNT(*) FROM core.rel_entity_edge WHERE known_at > ?", [ref_now])
        future_exp = self._scalar_count("SELECT COUNT(*) FROM core.fact_expectations WHERE known_at > ?", [ref_now])
        future_known_at_violations = future_obs + future_docs + future_edges + future_exp

        lookahead_obs = self._scalar_count(
            "SELECT COUNT(*) FROM core.fact_observations WHERE polarity = 'OBS' AND known_at < event_time"
        )
        lookahead_docs = self._scalar_count(
            "SELECT COUNT(*) FROM core.fact_documents WHERE polarity = 'OBS' AND known_at < event_time"
        )
        lookahead_obs_violations = lookahead_obs + lookahead_docs

        orphan_hashes = (
            self._orphan_hash_count("core.rel_entity_edge")
            + self._orphan_hash_count("core.fact_observations")
            + self._orphan_hash_count("core.fact_documents")
            + self._orphan_hash_count("core.fact_expectations")
        )

        resurrected_retractions = self._scalar_count(
            """
            WITH retracted_keys AS (
                SELECT DISTINCT entity_id, source_id, metric, event_time
                FROM core.fact_observations
                WHERE revision_state = 'RETRACTED' AND known_at <= ?
            ),
            pit AS (
                SELECT entity_id, source_id, metric, event_time
                FROM core.pit_latest(?, NULL, NULL, 0.0, NULL)
            )
            SELECT COUNT(*)
            FROM retracted_keys r
            JOIN pit p
              ON r.entity_id = p.entity_id
             AND r.source_id = p.source_id
             AND r.metric = p.metric
             AND r.event_time = p.event_time
            """,
            [ref_now, ref_now],
        )

        out_of_bounds_scores = (
            self._scalar_count(
                "SELECT COUNT(*) FROM core.fact_observations WHERE quality_score < 0.0 OR quality_score > 1.0"
            )
            + self._scalar_count(
                "SELECT COUNT(*) FROM core.fact_documents WHERE quality_score < 0.0 OR quality_score > 1.0"
            )
            + self._scalar_count("SELECT COUNT(*) FROM core.rel_entity_edge WHERE confidence < 0.0 OR confidence > 1.0")
        )

        counts = {
            "raw_artifacts": self._scalar_count("SELECT COUNT(*) FROM core.raw_artifacts"),
            "dim_entity": self._scalar_count("SELECT COUNT(*) FROM core.dim_entity"),
            "rel_entity_edge": self._scalar_count("SELECT COUNT(*) FROM core.rel_entity_edge"),
            "fact_observations": self._scalar_count("SELECT COUNT(*) FROM core.fact_observations"),
            "fact_documents": self._scalar_count("SELECT COUNT(*) FROM core.fact_documents"),
            "fact_expectations": self._scalar_count("SELECT COUNT(*) FROM core.fact_expectations"),
        }
        passed = (
            future_known_at_violations == 0
            and lookahead_obs_violations == 0
            and orphan_hashes == 0
            and resurrected_retractions == 0
            and out_of_bounds_scores == 0
        )
        return {
            "passed": passed,
            "checked_at": ref_now.isoformat(),
            "future_known_at_violations": future_known_at_violations,
            "lookahead_obs_violations": lookahead_obs_violations,
            "orphan_raw_hash_violations": orphan_hashes,
            "resurrected_retractions": resurrected_retractions,
            "out_of_bounds_scores": out_of_bounds_scores,
            "counts": counts,
        }

    def _scalar_count(self, sql: str, params: Sequence[Any] = ()) -> int:
        row = self.conn.execute(sql, list(params)).fetchone()
        return int(row[0]) if row is not None else 0

    def _orphan_hash_count(self, table: str) -> int:
        return self._scalar_count(
            f"""
            SELECT COUNT(*)
            FROM {table} t
            LEFT JOIN core.raw_artifacts a ON t.raw_hash = a.raw_hash
            WHERE a.raw_hash IS NULL OR t.raw_hash = ''
            """
        )
