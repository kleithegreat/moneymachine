"""Source catalog metadata and pragmatic license classification from `venue/sources.toml`.

Tracks source endpoints and classifies sources into explicit `LICENSE_CLASSES` so research pods
can filter data feeds declaratively (`PUBLIC_DOMAIN`, `CC_BY`, `PERSONAL_RESEARCH`,
`NON_COMMERCIAL`, `COMMERCIAL_API`, `RESTRICTED_INTERNAL`) without blocking research on
missing legal-quote certificates.
"""

import tomllib
from collections.abc import Collection, Iterable, Mapping
from pathlib import Path
from typing import Any

REGISTRY = Path(__file__).resolve().parents[1] / "venue" / "sources.toml"

LICENSE_CLASSES: tuple[str, ...] = (
    "PUBLIC_DOMAIN",
    "CC_BY",
    "PERSONAL_RESEARCH",
    "NON_COMMERCIAL",
    "COMMERCIAL_API",
    "RESTRICTED_INTERNAL",
)

_PUBLIC_DOMAIN_SOURCES: frozenset[str] = frozenset(
    {
        "treasury",
        "treasury-yields",
        "sec",
        "bls",
        "bea",
        "eia",
        "cftc",
        "fed",
        "fed-ddp",
        "nyfed",
        "philadelphia-fed-rtdsm",
        "nws",
        "openfda",
        "gdelt",
        "ecb",
        "bis",
    }
)


def registry(path: str | Path = REGISTRY) -> dict[str, Any]:
    """Load the source metadata registry TOML."""
    with open(path, "rb") as f:
        data: dict[str, Any] = tomllib.load(f)
    return data


def _resolve_source_key(source: str, reg: Mapping[str, Any]) -> str:
    if isinstance(reg.get(source), Mapping):
        return source
    matches = [
        name
        for name, sec in reg.items()
        if isinstance(sec, Mapping) and (source.startswith(f"{name}-") or source.startswith(f"{name}_"))
    ]
    return max(matches, key=len) if matches else source


def license_class(source: str, path: str | Path = REGISTRY) -> str:
    """Return the license class for `source`, defaulting gracefully to `PERSONAL_RESEARCH`."""
    reg = registry(path)
    resolved = _resolve_source_key(source, reg)
    section = reg.get(resolved)
    if isinstance(section, Mapping):
        declared = section.get("license_class")
        if isinstance(declared, str) and declared in LICENSE_CLASSES:
            return declared
    if source in _PUBLIC_DOMAIN_SOURCES or resolved in _PUBLIC_DOMAIN_SOURCES:
        return "PUBLIC_DOMAIN"
    if not isinstance(section, Mapping):
        return "PERSONAL_RESEARCH"
    terms_text = " ".join(
        str(t.get("quote", "")) + " " + str(t.get("notes", ""))
        for t in section.get("terms", [])
        if isinstance(t, Mapping)
    ).lower()
    if "cc by" in terms_text or "cc-by" in terms_text or "cc0" in terms_text:
        return "CC_BY"
    return "PERSONAL_RESEARCH"


def allowlist(
    source: str | None = None,
    retrieval: bool = False,
    allowed_licenses: Collection[str] | None = None,
    path: str | Path = REGISTRY,
) -> set[str]:
    """Return host[/prefix] entries matching `source`, optional `retrieval` flag, and `allowed_licenses`."""
    reg = registry(path)
    entries: set[str] = set()
    for name, section in reg.items():
        if source not in (None, name) or not isinstance(section, Mapping):
            continue
        if allowed_licenses is not None and license_class(name, path) not in allowed_licenses:
            continue
        for term in section.get("terms", []):
            if not isinstance(term, Mapping):
                continue
            host = term.get("host")
            if isinstance(host, str) and host and (not retrieval or bool(term.get("retrieval"))):
                entries.add(host)
    return entries


def admits(entries: Iterable[str], host: str, path: str) -> bool:
    """Whether some entry covers this host and path: a bare host covers all of it, `host/prefix` only that prefix."""
    return any(e == host or (e.startswith(host + "/") and (host + path).startswith(e)) for e in entries)
