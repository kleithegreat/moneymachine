"""Plan step 0: `archive.bars` is gone, and `parse` keeps the name and signature kernel version 2's test 5 imports."""

import inspect
from pathlib import Path

import polars as pl

from ingest import archive


def test_bars_is_deleted_with_what_only_it_used() -> None:
    assert not hasattr(archive, "bars")
    assert not hasattr(archive, "_utc")


def test_parse_keeps_its_signature() -> None:
    signature = inspect.signature(archive.parse)
    assert list(signature.parameters) == ["path"]
    assert signature.parameters["path"].annotation in (Path, "Path")
    assert signature.return_annotation in (pl.DataFrame, "pl.DataFrame")
