"""Unit tests for `fabric.manifest` YAML contracts and shipped manifests."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from fabric.manifest import load_all_manifests, load_manifest


def test_shipped_manifests_load_and_validate() -> None:
    manifest_dir = Path(__file__).resolve().parents[1] / "manifests"
    manifests = load_all_manifests(manifest_dir)
    assert {
        "hyperliquid_ws",
        "macro_datalayer",
        "clinicaltrials_gov_v2",
        "sec_edgar",
        "polymarket_clob",
    }.issubset(manifests)
    assert manifests["polymarket_clob"].temporal_polarity == "FCST"
    assert manifests["macro_datalayer"].temporal_semantics == "restatable_vintage"


def test_manifest_rejects_extra_fields_and_duplicates(tmp_path: Path) -> None:
    bad = tmp_path / "bad.yaml"
    bad.write_text(
        """
source_id: bad_src
domain: macro
modality: tabular
storage_tier: local_hot_ducklake
temporal_semantics: append_only
cadence: hourly
unexpected_flag: true
"""
    )
    with pytest.raises(ValidationError):
        load_manifest(bad)

    bad.unlink()
    for idx in (1, 2):
        (tmp_path / f"dup{idx}.yaml").write_text(
            """
source_id: dup_src
domain: macro
modality: tabular
storage_tier: local_hot_ducklake
temporal_semantics: append_only
cadence: hourly
"""
        )
    with pytest.raises(ValueError, match="duplicate source_id"):
        load_all_manifests(tmp_path)
