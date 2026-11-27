"""Plane 0: Declarative YAML source manifests for the multi-modal data fabric."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field

Modality = Literal[
    "tabular",
    "event_log",
    "document",
    "document_and_structured_diff",
    "spatial_stream",
    "tensor_virtual",
    "l3_book",
]
StorageTier = Literal[
    "local_hot_ducklake",
    "local_cold_parquet",
    "remote_virtual_icechunk",
    "on_demand_ephemeral",
]
TemporalSemantics = Literal[
    "append_only",
    "restatable_vintage",
    "prospective_forecast",
    "snapshot_diff",
]
TemporalPolarity = Literal["OBS", "FCST", "SCHED"]
LicenseClass = Literal[
    "PUBLIC_DOMAIN",
    "CC_BY",
    "PERSONAL_RESEARCH",
    "NON_COMMERCIAL",
    "COMMERCIAL_API",
    "RESTRICTED_INTERNAL",
]


class EntityResolverSpec(BaseModel):
    """Mapping rule from a source-local identifier into the canonical entity graph."""

    model_config = ConfigDict(extra="forbid")

    local_key: str
    target_node_type: str
    resolver_pipeline: str


class QualitySLA(BaseModel):
    """Data-quality and causal-integrity expectations declared per source."""

    model_config = ConfigDict(extra="forbid")

    max_freshness_lag_hours: float | None = Field(default=None, gt=0)
    require_raw_cas_hash: bool = True
    reject_future_known_at: bool = True


class SourceManifest(BaseModel):
    """Declarative metadata contract for any dataset or connector entering the fabric."""

    model_config = ConfigDict(extra="forbid")

    source_id: str = Field(min_length=1)
    domain: str = Field(min_length=1)
    modality: Modality
    storage_tier: StorageTier
    temporal_semantics: TemporalSemantics
    temporal_polarity: TemporalPolarity = "OBS"
    license_class: LicenseClass = "PERSONAL_RESEARCH"
    retroactive_history_start: datetime | None = None
    live_collection_start: datetime | None = None
    cadence: str = Field(min_length=1)
    entity_resolvers: list[EntityResolverSpec] = Field(default_factory=list)
    quality_sla: QualitySLA = Field(default_factory=QualitySLA)


def load_manifest(path: Path | str) -> SourceManifest:
    """Parse and validate one `*.yaml` source manifest."""
    raw = yaml.safe_load(Path(path).read_text())
    return SourceManifest.model_validate(raw)


def load_all_manifests(directory: Path | str) -> dict[str, SourceManifest]:
    """Load and validate all YAML manifests inside `directory`, keyed by `source_id`."""
    root = Path(directory)
    manifests: dict[str, SourceManifest] = {}
    for file_path in sorted([*root.glob("*.yaml"), *root.glob("*.yml")]):
        manifest = load_manifest(file_path)
        if manifest.source_id in manifests:
            raise ValueError(f"duplicate source_id {manifest.source_id!r} in {file_path}")
        manifests[manifest.source_id] = manifest
    return manifests
