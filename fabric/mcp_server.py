"""Plane 4: Point-in-time MCP service & server exposing the 6 causal fabric tools."""

from __future__ import annotations

import json
import re
from collections.abc import Mapping, Sequence
from datetime import datetime, timedelta
from typing import Any

from mcp.server.fastmcp import FastMCP

from fabric.catalog import FabricCatalog, ensure_utc
from fabric.ledger import ForecastLedger
from fabric.search import PitSearchIndex
from fabric.views import EntityBlinder, PodView

_LOOKBACK_RE = re.compile(r"^\s*(\d+)\s*([smhdw])\s*$")
_UNIT_SECONDS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}


def _parse_lookback(lookback: str, as_of: datetime) -> datetime:
    match = _LOOKBACK_RE.match(lookback.lower())
    if match is None:
        return ensure_utc(lookback)
    amount = int(match.group(1))
    unit = match.group(2)
    return as_of - timedelta(seconds=amount * _UNIT_SECONDS[unit])


def _parse_region(region: Sequence[float] | Mapping[str, float]) -> tuple[float, float, float, float]:
    if isinstance(region, Mapping):
        bounds = (
            float(region["min_lon"]),
            float(region["min_lat"]),
            float(region["max_lon"]),
            float(region["max_lat"]),
        )
    else:
        if len(region) != 4:
            raise ValueError("region bbox sequence must have [min_lon, min_lat, max_lon, max_lat]")
        bounds = (float(region[0]), float(region[1]), float(region[2]), float(region[3]))
    if bounds[0] > bounds[2] or bounds[1] > bounds[3]:
        raise ValueError(f"invalid bounding box coordinates: {bounds}")
    return bounds


def _iso_or_none(val: Any) -> Any:
    return val.isoformat() if isinstance(val, datetime) else val


class CausalFabricService:
    """POD-scoped, strictly bitemporal service powering the 6 MCP agent tools."""

    def __init__(
        self,
        catalog: FabricCatalog,
        *,
        pod_view: PodView | None = None,
        search_index: PitSearchIndex | None = None,
        ledger: ForecastLedger | None = None,
        pinned_as_of: datetime | str | None = None,
    ) -> None:
        self.catalog = catalog
        self.pod_view = pod_view or PodView(pod_id="default")
        if search_index is None:
            self.search_index = PitSearchIndex()
            self.search_index.index_from_catalog(catalog)
        else:
            self.search_index = search_index
        self.ledger = ledger
        self.pinned_as_of = ensure_utc(pinned_as_of) if pinned_as_of is not None else None
        self._blinder: EntityBlinder | None = (
            EntityBlinder(self.pod_view.blind_salt) if self.pod_view.blinding_mode == "BLINDED_ENTITIES" else None
        )
        self._entity_alias_to_real: dict[str, str] = {}
        self._doc_alias_to_real: dict[str, str] = {}

    def _check_as_of(self, as_of_utc: datetime | str) -> datetime:
        ts = ensure_utc(as_of_utc)
        if self.pinned_as_of is not None and ts > self.pinned_as_of:
            raise ValueError(
                f"requested as_of_utc {ts.isoformat()} exceeds pinned pod clock {self.pinned_as_of.isoformat()}"
            )
        return ts

    def _mask_entity(self, entity_id: str | None) -> str | None:
        if entity_id is None or self._blinder is None:
            return entity_id
        alias = self._blinder.entity_alias(entity_id)
        self._entity_alias_to_real[alias] = entity_id
        return alias

    def _unmask_entity(self, entity_or_alias: str | None) -> str | None:
        if entity_or_alias is None:
            return None
        if self._blinder is None:
            return entity_or_alias
        if entity_or_alias in self._entity_alias_to_real:
            return self._entity_alias_to_real[entity_or_alias]
        for row in self.catalog.conn.execute("SELECT CAST(entity_id AS VARCHAR) FROM core.dim_entity").fetchall():
            real_id = str(row[0])
            if self._blinder.entity_alias(real_id) == entity_or_alias:
                self._entity_alias_to_real[entity_or_alias] = real_id
                return real_id
        return entity_or_alias

    def _mask_doc(self, doc_id: str) -> str:
        if self._blinder is None:
            return doc_id
        alias = self._blinder.doc_alias(doc_id)
        self._doc_alias_to_real[alias] = doc_id
        return alias

    def _unmask_doc(self, doc_or_alias: str) -> str:
        if self._blinder is None:
            return doc_or_alias
        if doc_or_alias in self._doc_alias_to_real:
            return self._doc_alias_to_real[doc_or_alias]
        for row in self.catalog.conn.execute("SELECT CAST(doc_id AS VARCHAR) FROM core.fact_documents").fetchall():
            real_id = str(row[0])
            if self._blinder.doc_alias(real_id) == doc_or_alias:
                self._doc_alias_to_real[doc_or_alias] = real_id
                return real_id
        return doc_or_alias

    def _blind_term_map(self, entity_ids: Sequence[str] | None = None) -> dict[str, str]:
        if self._blinder is None:
            return {}
        aliases = self.catalog.resolve_entity_aliases(entity_ids)
        term_map: dict[str, str] = {}
        for real_id, terms in aliases.items():
            alias = self._blinder.entity_alias(real_id)
            self._entity_alias_to_real[alias] = real_id
            for term in terms:
                term_map[term] = alias
        return term_map

    def _redact(self, text: str, term_map: Mapping[str, str]) -> str:
        if self._blinder is None:
            return text
        return self._blinder.redact_text(text, term_map, mask_dates=True)

    def resolve_entity(self, query: str, *, as_of_utc: datetime | str) -> dict[str, Any]:
        """Tool 1: Resolve entities and active PIT graph edges (`G(t)`) as of `as_of_utc`."""
        as_of = self._check_as_of(as_of_utc)
        cleaned = query.strip()
        if not cleaned:
            raise ValueError("entity resolution query cannot be empty")
        unmasked_target = self._unmask_entity(cleaned)
        needle = cleaned.lower()

        rows = self.catalog.conn.execute(
            """
            SELECT CAST(entity_id AS VARCHAR), entity_type, canonical_name, aliases_json, external_ids_json
            FROM core.dim_entity
            ORDER BY canonical_name ASC
            """
        ).fetchall()

        matched: list[dict[str, Any]] = []
        matched_ids: list[str] = []
        for eid, etype, cname, aliases_json, ext_json in rows:
            aliases = list(json.loads(aliases_json))
            ext_ids = dict(json.loads(ext_json))
            haystack = [eid.lower(), cname.lower(), *[str(a).lower() for a in aliases]]
            haystack.extend(str(v).lower() for v in ext_ids.values())
            is_match = (unmasked_target == eid) or any(needle in item for item in haystack)
            if not is_match:
                continue
            matched_ids.append(eid)
            if self._blinder is not None:
                alias = self._mask_entity(eid)
                matched.append(
                    {
                        "entity_id": alias,
                        "entity_type": etype,
                        "canonical_name": alias,
                        "aliases": [],
                        "external_ids": {},
                    }
                )
            else:
                matched.append(
                    {
                        "entity_id": eid,
                        "entity_type": etype,
                        "canonical_name": cname,
                        "aliases": aliases,
                        "external_ids": ext_ids,
                    }
                )

        edges: list[dict[str, Any]] = []
        if matched_ids:
            all_edges = self.catalog.pit_edges(as_of, valid_at=as_of, pod_view=self.pod_view)
            id_set = set(matched_ids)
            for edge in all_edges:
                if edge["src_entity_id"] not in id_set and edge["dst_entity_id"] not in id_set:
                    continue
                edges.append(
                    {
                        "edge_id": edge["edge_id"],
                        "src_entity_id": self._mask_entity(edge["src_entity_id"]),
                        "dst_entity_id": self._mask_entity(edge["dst_entity_id"]),
                        "rel_type": edge["rel_type"],
                        "valid_from": _iso_or_none(edge["valid_from"]),
                        "valid_to": _iso_or_none(edge["valid_to"]),
                        "known_at": _iso_or_none(edge["known_at"]),
                        "confidence": edge["confidence"],
                        "source_id": edge["source_id"],
                        "raw_hash": edge["raw_hash"],
                    }
                )

        return {"as_of_utc": as_of.isoformat(), "entities": matched, "edges": edges}

    def query_pit_series(
        self,
        entity_id: str,
        metrics: Sequence[str],
        *,
        as_of_utc: datetime | str,
        lookback: str | None = None,
        include_fcst: bool = False,
    ) -> dict[str, Any]:
        """Tool 2: Query point-in-time observation series for an entity and metric list."""
        as_of = self._check_as_of(as_of_utc)
        real_eid = self._unmask_entity(entity_id)
        assert real_eid is not None
        min_event_time = _parse_lookback(lookback, as_of) if lookback else None
        metric_set = set(metrics)

        raw_rows = self.catalog.pit_latest(
            as_of,
            pod_view=self.pod_view,
            entity_id=real_eid,
            polarity=None if include_fcst else "OBS",
            include_fcst=include_fcst,
        )
        term_map = self._blind_term_map() if self._blinder is not None else {}
        series: list[dict[str, Any]] = []
        for row in raw_rows:
            if metric_set and row["metric"] not in metric_set:
                continue
            if min_event_time is not None and row["event_time"] < min_event_time:
                continue
            val_text = row["value_text"]
            if val_text is not None and self._blinder is not None:
                val_text = self._redact(val_text, term_map)
            series.append(
                {
                    "entity_id": self._mask_entity(row["entity_id"]),
                    "source_id": row["source_id"],
                    "metric": row["metric"],
                    "value_num": row["value_num"],
                    "value_text": val_text,
                    "unit": row["unit"],
                    "event_time": _iso_or_none(row["event_time"]),
                    "known_at": _iso_or_none(row["known_at"]),
                    "revision_id": row["revision_id"],
                    "revision_state": row["revision_state"],
                    "polarity": row["polarity"],
                    "quality_score": row["quality_score"],
                    "license_class": row["license_class"],
                    "raw_hash": row["raw_hash"],
                }
            )
        return {
            "as_of_utc": as_of.isoformat(),
            "entity_id": self._mask_entity(real_eid),
            "count": len(series),
            "observations": series,
        }

    def search_documents(
        self,
        query: str,
        *,
        as_of_utc: datetime | str,
        doc_types: Sequence[str] | None = None,
        entity_id: str | None = None,
        limit: int = 10,
    ) -> dict[str, Any]:
        """Tool 3: Hybrid Tantivy BM25 search locked to `known_at <= as_of_utc`."""
        as_of = self._check_as_of(as_of_utc)
        real_eid = self._unmask_entity(entity_id) if entity_id is not None else None
        hits = self.search_index.search(
            query,
            as_of=as_of,
            top_k=limit,
            pod_view=self.pod_view,
            doc_types=doc_types,
            entity_ids=[real_eid] if real_eid is not None else None,
        )
        term_map = self._blind_term_map() if self._blinder is not None else {}
        formatted: list[dict[str, Any]] = []
        for hit in hits:
            formatted.append(
                {
                    "doc_id": self._mask_doc(hit.doc_id),
                    "entity_id": self._mask_entity(hit.entity_id),
                    "source_id": hit.source_id,
                    "doc_type": hit.doc_type,
                    "title": self._redact(hit.title, term_map),
                    "known_at": hit.known_at,
                    "score": hit.score,
                    "snippet": self._redact(hit.snippet, term_map),
                    "raw_hash": hit.raw_hash,
                    "license_class": hit.license_class,
                }
            )
        return {"as_of_utc": as_of.isoformat(), "hits": formatted}

    def diff_document_versions(
        self,
        *,
        doc_id_a: str | None = None,
        doc_id_b: str | None = None,
        source_id: str | None = None,
        entity_id: str | None = None,
        doc_type: str | None = None,
        t_prev_utc: datetime | str | None = None,
        t_curr_utc: datetime | str | None = None,
        as_of_utc: datetime | str,
    ) -> dict[str, Any]:
        """Tool 4: Compute line-level and section diffs across two historical versions."""
        as_of = self._check_as_of(as_of_utc)
        real_doc_ids = (self._unmask_doc(doc_id_a), self._unmask_doc(doc_id_b)) if doc_id_a and doc_id_b else None
        real_eid = self._unmask_entity(entity_id) if entity_id is not None else None

        diff = self.catalog.diff_document_versions(
            doc_ids=real_doc_ids,
            source_id=source_id,
            entity_id=real_eid,
            doc_type=doc_type,
            t_prev=t_prev_utc,
            t_curr=t_curr_utc,
            as_of=as_of,
            pod_view=self.pod_view,
        )
        term_map = self._blind_term_map() if self._blinder is not None else {}
        sec_diffs = diff["section_diffs"]
        if self._blinder is not None:
            sec_diffs = {
                key: {
                    "old": self._redact(str(val["old"]), term_map) if val["old"] is not None else None,
                    "new": self._redact(str(val["new"]), term_map) if val["new"] is not None else None,
                }
                for key, val in sec_diffs.items()
            }
        return {
            "as_of_utc": as_of.isoformat(),
            "from_doc_id": self._mask_doc(diff["from_doc_id"]),
            "to_doc_id": self._mask_doc(diff["to_doc_id"]),
            "entity_id": self._mask_entity(diff["entity_id"]),
            "source_id": diff["source_id"],
            "doc_type": diff["doc_type"],
            "unified_diff": self._redact(diff["unified_diff"], term_map),
            "added_lines": [self._redact(line, term_map) for line in diff["added_lines"]],
            "removed_lines": [self._redact(line, term_map) for line in diff["removed_lines"]],
            "section_diffs": sec_diffs,
        }

    def sample_spatial_tensor(
        self,
        region: Sequence[float] | Mapping[str, float],
        variable: str,
        t_start_utc: datetime | str,
        t_end_utc: datetime | str,
        *,
        as_of_utc: datetime | str,
    ) -> dict[str, Any]:
        """Tool 5: Extract PIT-valid spatial summary statistics over a bounding box and window."""
        as_of = self._check_as_of(as_of_utc)
        min_lon, min_lat, max_lon, max_lat = _parse_region(region)
        t_start = ensure_utc(t_start_utc)
        t_end = min(ensure_utc(t_end_utc), as_of)
        if t_end < t_start:
            raise ValueError(f"effective end time {t_end.isoformat()} precedes t_start {t_start.isoformat()}")

        pit_rows = self.catalog.pit_latest(as_of, pod_view=self.pod_view, metric=variable, polarity="OBS")
        ext_map_rows = self.catalog.conn.execute(
            "SELECT CAST(entity_id AS VARCHAR), external_ids_json FROM core.dim_entity"
        ).fetchall()
        coords_by_entity: dict[str, tuple[float | None, float | None]] = {}
        for eid, ext_json in ext_map_rows:
            ext = json.loads(ext_json)
            lon = float(ext["lon"]) if "lon" in ext else None
            lat = float(ext["lat"]) if "lat" in ext else None
            coords_by_entity[eid] = (lon, lat)

        points: list[dict[str, Any]] = []
        values: list[float] = []
        raw_hashes: set[str] = set()
        for row in pit_rows:
            et = row["event_time"]
            if et < t_start or et > t_end:
                continue
            lon, lat = coords_by_entity.get(row["entity_id"], (None, None))
            if lon is not None and (lon < min_lon or lon > max_lon):
                continue
            if lat is not None and (lat < min_lat or lat > max_lat):
                continue
            val = row["value_num"]
            if val is not None:
                values.append(float(val))
            raw_hashes.add(row["raw_hash"])
            points.append(
                {
                    "entity_id": self._mask_entity(row["entity_id"]),
                    "lon": lon,
                    "lat": lat,
                    "event_time": _iso_or_none(et),
                    "known_at": _iso_or_none(row["known_at"]),
                    "value": val,
                    "unit": row["unit"],
                    "raw_hash": row["raw_hash"],
                }
            )

        summary = {
            "count": len(values),
            "mean": (sum(values) / len(values)) if values else None,
            "min": min(values) if values else None,
            "max": max(values) if values else None,
        }
        return {
            "as_of_utc": as_of.isoformat(),
            "variable": variable,
            "bbox": {"min_lon": min_lon, "min_lat": min_lat, "max_lon": max_lon, "max_lat": max_lat},
            "t_start_utc": t_start.isoformat(),
            "t_end_utc": t_end.isoformat(),
            "summary": summary,
            "raw_hashes": sorted(raw_hashes),
            "samples": points,
        }

    def register_prospective_forecast(
        self,
        entity_id: str,
        target_event: str,
        horizon_end_utc: datetime | str,
        prob_estimate: float,
        rationale_citations: Sequence[dict[str, Any]],
        *,
        crowd_baseline: float | None = None,
        submitted_at_utc: datetime | str | None = None,
    ) -> dict[str, Any]:
        """Tool 6: Append a timestamped forecast + evidence citations to the SQLite ledger."""
        if self.ledger is None:
            raise RuntimeError("ForecastLedger is not configured on this CausalFabricService")
        real_eid = self._unmask_entity(entity_id) or entity_id
        resolved_citations: list[dict[str, Any]] = []
        for citation in rationale_citations:
            item = dict(citation)
            if "doc_id" in item and isinstance(item["doc_id"], str):
                item["doc_id"] = self._unmask_doc(item["doc_id"])
            if "entity_id" in item and isinstance(item["entity_id"], str):
                item["entity_id"] = self._unmask_entity(item["entity_id"])
            resolved_citations.append(item)

        submitted_at = submitted_at_utc if submitted_at_utc is not None else self.pinned_as_of
        entry = self.ledger.submit_forecast(
            pod_id=self.pod_view.pod_id,
            entity_id=real_eid,
            target_event=target_event,
            horizon_end=horizon_end_utc,
            prob_estimate=prob_estimate,
            rationale_citations=resolved_citations,
            crowd_baseline=crowd_baseline,
            submitted_at=submitted_at,
        )
        return {
            "forecast_id": entry.forecast_id,
            "pod_id": entry.pod_id,
            "entity_id": self._mask_entity(entry.entity_id),
            "target_event": entry.target_event,
            "submitted_at": entry.submitted_at,
            "horizon_end": entry.horizon_end,
            "prob_estimate": entry.prob_estimate,
            "prev_hash": entry.prev_hash,
            "entry_hash": entry.entry_hash,
        }


def create_mcp_server(
    service: CausalFabricService,
    *,
    name: str = "moneymachine-data-fabric",
) -> FastMCP:
    """Bind the 6 causal `CausalFabricService` operations onto a FastMCP server."""
    server = FastMCP(name)

    def resolve_entity(query: str, as_of_utc: str) -> dict[str, Any]:
        return service.resolve_entity(query, as_of_utc=as_of_utc)

    def query_pit_series(
        entity_id: str,
        metrics: list[str],
        as_of_utc: str,
        lookback: str | None = None,
        include_fcst: bool = False,
    ) -> dict[str, Any]:
        return service.query_pit_series(
            entity_id, metrics, as_of_utc=as_of_utc, lookback=lookback, include_fcst=include_fcst
        )

    def search_documents(
        query: str,
        as_of_utc: str,
        doc_types: list[str] | None = None,
        entity_id: str | None = None,
        limit: int = 10,
    ) -> dict[str, Any]:
        return service.search_documents(
            query, as_of_utc=as_of_utc, doc_types=doc_types, entity_id=entity_id, limit=limit
        )

    def diff_document_versions(
        as_of_utc: str,
        doc_id_a: str | None = None,
        doc_id_b: str | None = None,
        source_id: str | None = None,
        entity_id: str | None = None,
        doc_type: str | None = None,
        t_prev_utc: str | None = None,
        t_curr_utc: str | None = None,
    ) -> dict[str, Any]:
        return service.diff_document_versions(
            doc_id_a=doc_id_a,
            doc_id_b=doc_id_b,
            source_id=source_id,
            entity_id=entity_id,
            doc_type=doc_type,
            t_prev_utc=t_prev_utc,
            t_curr_utc=t_curr_utc,
            as_of_utc=as_of_utc,
        )

    def sample_spatial_tensor(
        region: list[float],
        variable: str,
        t_start_utc: str,
        t_end_utc: str,
        as_of_utc: str,
    ) -> dict[str, Any]:
        return service.sample_spatial_tensor(region, variable, t_start_utc, t_end_utc, as_of_utc=as_of_utc)

    def register_prospective_forecast(
        entity_id: str,
        target_event: str,
        horizon_end_utc: str,
        prob_estimate: float,
        rationale_citations: list[dict[str, Any]],
        crowd_baseline: float | None = None,
        submitted_at_utc: str | None = None,
    ) -> dict[str, Any]:
        return service.register_prospective_forecast(
            entity_id,
            target_event,
            horizon_end_utc,
            prob_estimate,
            rationale_citations,
            crowd_baseline=crowd_baseline,
            submitted_at_utc=submitted_at_utc,
        )

    server.add_tool(
        resolve_entity, name="resolve_entity", description="Resolve entities and PIT edges as of UTC timestamp."
    )
    server.add_tool(query_pit_series, name="query_pit_series", description="Query point-in-time observation series.")
    server.add_tool(
        search_documents, name="search_documents", description="Search unstructured documents with PIT ceiling."
    )
    server.add_tool(
        diff_document_versions, name="diff_document_versions", description="Diff two historical document versions."
    )
    server.add_tool(
        sample_spatial_tensor, name="sample_spatial_tensor", description="Sample PIT spatial tensor statistics."
    )
    server.add_tool(
        register_prospective_forecast,
        name="register_prospective_forecast",
        description="Register a timestamped forecast into the append-only hash-chained ledger.",
    )
    return server
