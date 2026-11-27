"""Unit tests for `fabric.cas` content-addressable storage and quarantine."""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest
import zstandard as zstd

from fabric.cas import CASStore


def test_cas_round_trip_and_deduplication(tmp_path: Path) -> None:
    store = CASStore(tmp_path, uri_prefix="cas://local")
    payload = b'{"feed":"gdelt-events","ok":true}\n' * 8

    first = store.put(payload)
    assert not first.existed
    assert first.sha256 == hashlib.sha256(payload).hexdigest()
    assert first.byte_size == len(payload)
    assert first.uri.startswith("cas://local/")
    assert store.exists(first.sha256)
    assert store.get(first.sha256) == payload

    second = store.put(payload)
    assert second.existed
    assert second.sha256 == first.sha256


def test_cas_quarantines_corrupt_blob_and_recovers(tmp_path: Path) -> None:
    store = CASStore(tmp_path)
    payload = b"canonical raw payload bytes"
    rec = store.put(payload)
    path = store.path_for(rec.sha256)

    # Corrupt stored bytes on disk so SHA-256 verification fails on next get/put.
    corrupt_zst = zstd.ZstdCompressor().compress(b"tampered bytes")
    path.write_bytes(corrupt_zst)

    with pytest.raises(ValueError, match="integrity mismatch"):
        store.get(rec.sha256)

    healed = store.put(payload)
    assert not healed.existed
    assert store.get(rec.sha256) == payload
    damaged = list(path.parent.glob(f"{path.name}.damaged-*"))
    assert len(damaged) == 1


def test_cas_quarantines_invalid_zstd_stream(tmp_path: Path) -> None:
    store = CASStore(tmp_path)
    payload = b"valid source bytes"
    rec = store.put(payload)
    path = store.path_for(rec.sha256)
    path.write_bytes(b"not-a-valid-zstd-frame")

    healed = store.put(payload)
    assert not healed.existed
    assert store.get(rec.sha256) == payload
    assert list(path.parent.glob(f"{path.name}.damaged-*"))


def test_cas_rejects_invalid_digest(tmp_path: Path) -> None:
    store = CASStore(tmp_path)
    with pytest.raises(ValueError, match="invalid SHA-256"):
        store.path_for("deadbeef")
