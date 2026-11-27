"""Plane 3: Point-in-time Tantivy lexical search index for fabric documents."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any

import tantivy

from fabric.catalog import ensure_utc
from fabric.views import PodView

if TYPE_CHECKING:
    from fabric.catalog import FabricCatalog

_EPOCH_UTC = datetime(1970, 1, 1, tzinfo=UTC)
_NONE_ENTITY_SENTINEL = "__NONE__"


def datetime_to_us(ts: datetime | str) -> int:
    """Convert a datetime or ISO-8601 timestamp to integer UTC microseconds since epoch."""
    dt = ensure_utc(ts)
    delta = dt - _EPOCH_UTC
    return (delta.days * 86_400 + delta.seconds) * 1_000_000 + delta.microseconds


def _build_schema() -> tantivy.Schema:
    builder = tantivy.SchemaBuilder()
    builder.add_text_field("doc_id", stored=True, tokenizer_name="raw")
    builder.add_text_field("entity_id", stored=True, tokenizer_name="raw")
    builder.add_text_field("source_id", stored=True, tokenizer_name="raw")
    builder.add_text_field("doc_type", stored=True, tokenizer_name="raw")
    builder.add_text_field("license_class", stored=True, tokenizer_name="raw")
    builder.add_text_field("raw_hash", stored=True, tokenizer_name="raw")
    builder.add_text_field("known_at_iso", stored=True, tokenizer_name="raw")
    builder.add_text_field("title", stored=True)
    builder.add_text_field("body", stored=True)
    builder.add_integer_field("known_at_us", stored=True, indexed=True, fast=True)
    return builder.build()


@dataclass(frozen=True)
class SearchHit:
    """A point-in-time search hit returned by `PitSearchIndex.search`."""

    doc_id: str
    entity_id: str | None
    source_id: str
    doc_type: str
    title: str
    known_at: str
    known_at_us: int
    score: float
    snippet: str
    raw_hash: str
    license_class: str


class PitSearchIndex:
    """Tantivy BM25 document index enforcing `known_at_us <= as_of_us` in the query plan."""

    def __init__(self, index_dir: Path | str | None = None) -> None:
        self.schema = _build_schema()
        self.index_dir = Path(index_dir) if index_dir is not None else None
        if self.index_dir is not None:
            self.index_dir.mkdir(parents=True, exist_ok=True)
            if (self.index_dir / "meta.json").is_file():
                self.index = tantivy.Index.open(str(self.index_dir))
                self.schema = self.index.schema
            else:
                self.index = tantivy.Index(self.schema, path=str(self.index_dir))
        else:
            self.index = tantivy.Index(self.schema)

    def _add_doc_to_writer(
        self,
        writer: Any,
        *,
        doc_id: str,
        title: str,
        body: str,
        source_id: str,
        doc_type: str,
        known_at: datetime | str,
        raw_hash: str,
        entity_id: str | None = None,
        license_class: str = "PERSONAL_RESEARCH",
    ) -> None:
        kt = ensure_utc(known_at)
        doc = tantivy.Document()
        doc.add_text("doc_id", doc_id)
        doc.add_text("entity_id", entity_id if entity_id is not None else _NONE_ENTITY_SENTINEL)
        doc.add_text("source_id", source_id)
        doc.add_text("doc_type", doc_type)
        doc.add_text("license_class", license_class)
        doc.add_text("raw_hash", raw_hash)
        doc.add_text("known_at_iso", kt.isoformat())
        doc.add_text("title", title)
        doc.add_text("body", body)
        doc.add_integer("known_at_us", datetime_to_us(kt))
        writer.add_document(doc)

    def index_document(
        self,
        *,
        doc_id: str,
        title: str,
        body: str,
        source_id: str,
        doc_type: str,
        known_at: datetime | str,
        raw_hash: str,
        entity_id: str | None = None,
        license_class: str = "PERSONAL_RESEARCH",
        commit: bool = True,
    ) -> None:
        """Index one bitemporal document with an exact microsecond `known_at_us` fast field."""
        writer = self.index.writer()
        writer.delete_documents("doc_id", doc_id)
        self._add_doc_to_writer(
            writer,
            doc_id=doc_id,
            title=title,
            body=body,
            source_id=source_id,
            doc_type=doc_type,
            known_at=known_at,
            raw_hash=raw_hash,
            entity_id=entity_id,
            license_class=license_class,
        )
        if commit:
            writer.commit()
            self.index.reload()

    def index_from_catalog(self, catalog: FabricCatalog) -> int:
        """Index all non-retracted documents from `core.fact_documents` into Tantivy."""
        rows = catalog.conn.execute(
            """
            SELECT doc_id, entity_id, source_id, doc_type, title, body_text, known_at, raw_hash, license_class
            FROM core.fact_documents
            WHERE revision_state <> 'RETRACTED'
            ORDER BY known_at ASC
            """
        ).fetchall()
        writer = self.index.writer()
        writer.delete_all_documents()
        for doc_id, entity_id, source_id, doc_type, title, body_text, known_at, raw_hash, license_class in rows:
            self._add_doc_to_writer(
                writer,
                doc_id=str(doc_id),
                title=str(title),
                body=str(body_text),
                source_id=str(source_id),
                doc_type=str(doc_type),
                known_at=known_at,
                raw_hash=str(raw_hash),
                entity_id=str(entity_id) if entity_id is not None else None,
                license_class=str(license_class),
            )
        writer.commit()
        self.index.reload()
        return len(rows)

    def _term_filter(self, clauses: list[tuple[Any, Any]], field: str, values: Sequence[str] | None) -> bool:
        if values is None:
            return True
        if not values:
            return False
        clauses.append((tantivy.Occur.Must, tantivy.Query.term_set_query(self.schema, field, list(values))))
        return True

    def search(
        self,
        query: str,
        *,
        as_of: datetime | str,
        top_k: int = 10,
        pod_view: PodView | None = None,
        doc_types: Sequence[str] | None = None,
        entity_ids: Sequence[str] | None = None,
    ) -> list[SearchHit]:
        """Run BM25 search restricted to `known_at_us <= as_of` and active `pod_view`."""
        cleaned = query.strip()
        if not cleaned:
            raise ValueError("search query cannot be empty")
        if top_k <= 0:
            return []

        as_of_us = datetime_to_us(as_of)
        text_query = self.index.parse_query(cleaned, ["title", "body"])
        time_query = tantivy.Query.range_query(
            self.schema,
            "known_at_us",
            tantivy.FieldType.Integer,
            lower_bound=None,
            upper_bound=as_of_us,
            include_upper=True,
        )
        clauses: list[tuple[Any, Any]] = [
            (tantivy.Occur.Must, text_query),
            (tantivy.Occur.Must, time_query),
        ]
        if pod_view is not None:
            if not self._term_filter(clauses, "source_id", pod_view.allowed_sources):
                return []
            if not self._term_filter(clauses, "license_class", pod_view.allowed_licenses):
                return []
        if not self._term_filter(clauses, "doc_type", doc_types):
            return []
        if not self._term_filter(clauses, "entity_id", entity_ids):
            return []

        combined = tantivy.Query.boolean_query(clauses)
        self.index.reload()
        searcher = self.index.searcher()
        result = searcher.search(combined, top_k)
        snip_gen = tantivy.SnippetGenerator.create(searcher, text_query, self.schema, "body")

        allowed_sources = set(pod_view.allowed_sources) if pod_view and pod_view.allowed_sources is not None else None
        allowed_licenses = (
            set(pod_view.allowed_licenses) if pod_view and pod_view.allowed_licenses is not None else None
        )

        hits: list[SearchHit] = []
        for score, addr in result.hits:
            stored = searcher.doc(addr)
            fields = stored.to_dict()
            hit_known_us = int(fields["known_at_us"][0])
            source_id = str(fields["source_id"][0])
            license_class = str(fields["license_class"][0])
            if hit_known_us > as_of_us:
                continue
            if allowed_sources is not None and source_id not in allowed_sources:
                continue
            if allowed_licenses is not None and license_class not in allowed_licenses:
                continue

            raw_eid = str(fields["entity_id"][0])
            entity_id = None if raw_eid == _NONE_ENTITY_SENTINEL else raw_eid
            body_val = str(fields["body"][0])
            snippet_obj = snip_gen.snippet_from_doc(stored)
            fragment = snippet_obj.fragment().strip() if snippet_obj is not None else ""
            if not fragment:
                fragment = body_val[:200]

            hits.append(
                SearchHit(
                    doc_id=str(fields["doc_id"][0]),
                    entity_id=entity_id,
                    source_id=source_id,
                    doc_type=str(fields["doc_type"][0]),
                    title=str(fields["title"][0]),
                    known_at=str(fields["known_at_iso"][0]),
                    known_at_us=hit_known_us,
                    score=float(score),
                    snippet=fragment,
                    raw_hash=str(fields["raw_hash"][0]),
                    license_class=license_class,
                )
            )
        return hits
