"""Plane 1: Immutable Content-Addressable Storage (CAS) with Zstd compression and SHA-256 provenance."""

from __future__ import annotations

import hashlib
import io
import os
import re
from dataclasses import dataclass
from pathlib import Path

import zstandard as zstd

_HEX64 = re.compile(r"^[0-9a-f]{64}$")


def _validate_digest(digest: str) -> str:
    norm = digest.lower()
    if not _HEX64.match(norm):
        raise ValueError(f"invalid SHA-256 digest: {digest!r}")
    return norm


def _decompress_zst(blob: bytes) -> bytes:
    dctx = zstd.ZstdDecompressor()
    with dctx.stream_reader(io.BytesIO(blob)) as reader:
        return reader.read()


@dataclass(frozen=True)
class CASRecord:
    """Metadata returned when storing an immutable payload into CAS."""

    sha256: str
    uri: str
    byte_size: int
    compressed_size: int
    existed: bool


class CASStore:
    """Content-addressable Zstd blob store keyed by uncompressed SHA-256 digest."""

    def __init__(self, root: Path | str, *, uri_prefix: str | None = None, level: int = 9) -> None:
        self.root = Path(root)
        self.base_dir = self.root / "cas" / "sha256"
        self.uri_prefix = uri_prefix.rstrip("/") if uri_prefix else None
        self.level = level

    def path_for(self, digest: str) -> Path:
        norm = _validate_digest(digest)
        return self.base_dir / norm[:2] / norm[2:4] / f"{norm}.zst"

    def uri_for(self, digest: str) -> str:
        norm = _validate_digest(digest)
        if self.uri_prefix is not None:
            return f"{self.uri_prefix}/{norm[:2]}/{norm[2:4]}/{norm}.zst"
        return self.path_for(norm).resolve().as_uri()

    def exists(self, digest: str) -> bool:
        return self.path_for(digest).is_file()

    def _quarantine_corrupt(self, path: Path) -> None:
        bad = path.read_bytes()
        bad_hash = hashlib.sha256(bad).hexdigest()[:16]
        damaged = path.with_name(f"{path.name}.damaged-{bad_hash}")
        os.replace(path, damaged)

    def put(self, raw: bytes) -> CASRecord:
        """Persist `raw` once under its SHA-256 digest, verifying any pre-existing object."""
        digest = hashlib.sha256(raw).hexdigest()
        dest = self.path_for(digest)
        uri = self.uri_for(digest)
        if dest.exists():
            blob = dest.read_bytes()
            try:
                if hashlib.sha256(_decompress_zst(blob)).hexdigest() == digest:
                    return CASRecord(
                        sha256=digest,
                        uri=uri,
                        byte_size=len(raw),
                        compressed_size=len(blob),
                        existed=True,
                    )
            except zstd.ZstdError:
                pass
            self._quarantine_corrupt(dest)

        dest.parent.mkdir(parents=True, exist_ok=True)
        compressed = zstd.ZstdCompressor(level=self.level).compress(raw)
        tmp = dest.with_name(f".{dest.name}.{os.getpid()}.tmp")
        with open(tmp, "wb") as f:
            f.write(compressed)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, dest)
        return CASRecord(
            sha256=digest,
            uri=uri,
            byte_size=len(raw),
            compressed_size=len(compressed),
            existed=False,
        )

    def get(self, digest: str) -> bytes:
        """Read and verify the decompressed bytes for `digest`."""
        norm = _validate_digest(digest)
        dest = self.path_for(norm)
        if not dest.is_file():
            raise FileNotFoundError(f"CAS object not found: {norm}")
        raw = _decompress_zst(dest.read_bytes())
        actual = hashlib.sha256(raw).hexdigest()
        if actual != norm:
            raise ValueError(f"CAS integrity mismatch for {norm}: got {actual}")
        return raw
