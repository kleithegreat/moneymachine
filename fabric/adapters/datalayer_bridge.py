"""Adapter ingesting `ingest.datalayer` / `ingest.live` JSONL + gzip blobs into the data fabric."""

from __future__ import annotations

import hashlib
import json
import math
import zlib
from collections.abc import Iterable, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from fabric.cas import CASStore
from fabric.catalog import FabricCatalog, canonical_uuid, ensure_utc
from fabric.search import PitSearchIndex
from ingest import datalayer, live, terms


def _parse_timestamp(raw: Any) -> datetime:
    if isinstance(raw, (int, float)):
        secs = float(raw) / 1000.0 if abs(float(raw)) > 1e11 else float(raw)
        return datetime.fromtimestamp(secs, tz=UTC)
    if isinstance(raw, str):
        return ensure_utc(raw)
    raise ValueError(f"unsupported timestamp value: {raw!r}")


def _extract_numeric_metrics(payload: Any, *, prefix: str = "", max_metrics: int = 32) -> list[tuple[str, float]]:
    found: list[tuple[str, float]] = []

    def _walk(node: Any, path: str) -> None:
        if len(found) >= max_metrics:
            return
        if isinstance(node, bool):
            return
        if isinstance(node, (int, float)):
            val = float(node)
            if math.isfinite(val):
                found.append((path or "value", val))
            return
        if isinstance(node, dict):
            for key in sorted(node):
                sub = f"{path}.{key}" if path else str(key)
                _walk(node[key], sub)
        elif isinstance(node, list) and len(node) <= 8:
            for idx, item in enumerate(node):
                _walk(item, f"{path}[{idx}]")

    _walk(payload, prefix)
    return found


def _exists_pk(catalog: FabricCatalog, table: str, pk_col: str, pk_val: str) -> bool:
    row = catalog.conn.execute(f"SELECT 1 FROM {table} WHERE {pk_col} = CAST(? AS UUID)", [pk_val]).fetchone()
    return row is not None


def _extract_body_bytes(live_dir: Path, digest: str) -> bytes | None:
    try:
        return bytes(datalayer.body(live_dir, digest))
    except (FileNotFoundError, OSError, zlib.error, EOFError):
        return None


def _coerce_records(records: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    return [dict(item) for item in records]


def ingest_datalayer(
    live_dir: Path | str,
    *,
    cas: CASStore,
    catalog: FabricCatalog,
    prefix: str = "fetch",
    feeds: Sequence[str] | None = None,
    limit: int | None = None,
    search_index: PitSearchIndex | None = None,
) -> dict[str, int]:
    """Bridge historical `datalayer` live JSONL logs and gzipped bodies into CAS and DuckDB."""
    root = Path(live_dir)
    feed_filter = set(feeds) if feeds is not None else None
    stats = {"records": 0, "skipped": 0, "observations": 0, "documents": 0}
    entity_cache: dict[str, str] = {}

    raw_records = _coerce_records(live.read(root, prefix))
    for item in raw_records:
        if limit is not None and stats["records"] >= limit:
            break
        feed = str(item.get("feed") or "")
        if not feed or (feed_filter is not None and feed not in feed_filter):
            continue
        digest = str(item.get("sha256") or "")
        url = str(item.get("url") or "")
        status_code = item.get("status")
        if not digest:
            stats["skipped"] += 1
            continue

        body_bytes = _extract_body_bytes(root, digest)
        if body_bytes is None:
            stats["skipped"] += 1
            continue

        actual_hash = hashlib.sha256(body_bytes).hexdigest()
        if actual_hash != digest.lower():
            stats["skipped"] += 1
            continue

        recv_ts = _parse_timestamp(item["recv"])
        sent_ts = _parse_timestamp(item.get("sent", item["recv"]))
        event_ts = sent_ts if sent_ts <= recv_ts else recv_ts
        license_tag = terms.license_class(feed)
        source_id = f"datalayer.{feed}"

        cas_rec = cas.put(body_bytes)
        catalog.record_artifact(cas_rec, source_id=source_id, license_class=license_tag, ingested_at=recv_ts)

        entity_id = entity_cache.get(feed)
        if entity_id is None:
            entity_id = catalog.upsert_entity(
                entity_type="DATA_FEED",
                canonical_name=feed,
                external_ids={"url": url} if url else None,
                updated_at=recv_ts,
            )
            entity_cache[feed] = entity_id

        obs_id_status = canonical_uuid(
            "obs", entity_id, source_id, "http_status", event_ts.isoformat(), recv_ts.isoformat(), "1"
        )
        if isinstance(status_code, (int, float)) and not _exists_pk(
            catalog, "core.fact_observations", "obs_id", obs_id_status
        ):
            catalog.add_observation(
                obs_id=obs_id_status,
                entity_id=entity_id,
                source_id=source_id,
                metric="http_status",
                value_num=float(status_code),
                unit="CODE",
                event_time=event_ts,
                known_at=recv_ts,
                license_class=license_tag,
                raw_hash=cas_rec.sha256,
            )
            stats["observations"] += 1

        text_body = body_bytes.decode("utf-8", errors="replace")
        parsed_json: Any = None
        try:
            parsed_json = json.loads(text_body)
        except json.JSONDecodeError:
            parsed_json = None

        if parsed_json is not None:
            for metric_name, metric_val in _extract_numeric_metrics(parsed_json):
                obs_id = canonical_uuid(
                    "obs", entity_id, source_id, metric_name, event_ts.isoformat(), recv_ts.isoformat(), "1"
                )
                if not _exists_pk(catalog, "core.fact_observations", "obs_id", obs_id):
                    catalog.add_observation(
                        obs_id=obs_id,
                        entity_id=entity_id,
                        source_id=source_id,
                        metric=metric_name,
                        value_num=metric_val,
                        event_time=event_ts,
                        known_at=recv_ts,
                        license_class=license_tag,
                        raw_hash=cas_rec.sha256,
                    )
                    stats["observations"] += 1

        doc_id = canonical_uuid(
            "doc",
            source_id,
            entity_id,
            "datalayer_payload",
            event_ts.isoformat(),
            recv_ts.isoformat(),
            cas_rec.sha256,
            "1",
        )
        if not _exists_pk(catalog, "core.fact_documents", "doc_id", doc_id):
            body_excerpt = text_body[:20_000]
            catalog.add_document(
                doc_id=doc_id,
                entity_id=entity_id,
                source_id=source_id,
                doc_type="datalayer_payload",
                title=f"{feed} snapshot @ {event_ts.isoformat()}",
                body_text=body_excerpt,
                sections={"url": url} if url else None,
                event_time=event_ts,
                known_at=recv_ts,
                license_class=license_tag,
                raw_hash=cas_rec.sha256,
            )
            if search_index is not None:
                search_index.index_document(
                    doc_id=doc_id,
                    title=f"{feed} snapshot @ {event_ts.isoformat()}",
                    body=body_excerpt,
                    source_id=source_id,
                    doc_type="datalayer_payload",
                    known_at=recv_ts,
                    raw_hash=cas_rec.sha256,
                    entity_id=entity_id,
                    license_class=license_tag,
                )
            stats["documents"] += 1

        stats["records"] += 1

    return stats
