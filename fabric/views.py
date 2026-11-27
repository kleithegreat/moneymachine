"""Plane 4: Composable Pod Views and salted entity blinding for agentic experiments."""

from __future__ import annotations

import hashlib
import hmac
import re
from collections.abc import Iterable, Mapping
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

BlindingMode = Literal["NONE", "BLINDED_ENTITIES", "PROSPECTIVE_ONLY"]

_ISO_DATE_OR_YEAR = re.compile(r"\b(?:19|20)\d{2}(?:-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?Z?)?)?\b")


class PodView(BaseModel):
    """Scoped read-only visibility specification bound to an experiment pod."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    pod_id: str = Field(min_length=1)
    allowed_sources: tuple[str, ...] | None = None
    allowed_licenses: tuple[str, ...] | None = None
    min_confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    min_quality: float = Field(default=0.0, ge=0.0, le=1.0)
    blinding_mode: BlindingMode = "NONE"
    blind_salt: str = ""


class EntityBlinder:
    """Deterministic HMAC-SHA256 entity/document pseudonymizer and text redactor."""

    def __init__(self, salt: str) -> None:
        self._key = salt.encode("utf-8")

    def pseudonym(self, prefix: str, real_id: str) -> str:
        digest = hmac.new(self._key, f"{prefix}:{real_id}".encode(), hashlib.sha256).hexdigest()[:12]
        return f"{prefix}_{digest}"

    def entity_alias(self, entity_id: str) -> str:
        return self.pseudonym("ENT", entity_id)

    def doc_alias(self, doc_id: str) -> str:
        return self.pseudonym("DOC", doc_id)

    def redact_text(
        self,
        text: str,
        entity_aliases: Mapping[str, str],
        *,
        mask_dates: bool = True,
        extra_terms: Iterable[str] = (),
    ) -> str:
        """Mask known entity names/tickers/identifiers and historical calendar dates."""
        out = text
        terms: list[tuple[str, str]] = [
            (term, alias) for term, alias in entity_aliases.items() if len(term.strip()) >= 2
        ]
        for term in extra_terms:
            if len(term.strip()) >= 2 and term not in entity_aliases:
                terms.append((term, self.pseudonym("TERM", term)))
        for term, alias in sorted(terms, key=lambda pair: len(pair[0]), reverse=True):
            escaped = re.escape(term)
            pattern = rf"\b{escaped}\b" if term[0].isalnum() and term[-1].isalnum() else escaped
            out = re.sub(pattern, alias, out, flags=re.IGNORECASE)
        if mask_dates:
            out = _ISO_DATE_OR_YEAR.sub("[DATE]", out)
        return out
