"""Terms certification (paper §5) from the source-certificate registry `venue/sources.toml`: one record per place
fetched automatically, with the URL of the terms, the retrieval date, the basis (a clause permitting our automated
use, or an official API whose terms allow it) and the verbatim quote. A host `h/prefix` admits only that prefix."""

import tomllib
from datetime import date
from pathlib import Path

REGISTRY = Path(__file__).resolve().parents[1] / "venue" / "sources.toml"
BASES = ("permitting clause", "official API")


def registry(path=REGISTRY):
    with open(path, "rb") as f:
        return tomllib.load(f)


def certified(record):
    return (str(record.get("url", "")).startswith("https://") and isinstance(record.get("retrieved"), date)
            and record.get("basis") in BASES and bool(str(record.get("quote", "")).strip()))


def allowlist(source=None, retrieval=False, path=REGISTRY):
    """The certified `host[/prefix]` entries of one source, of every source, or of the retrieval allowlist."""
    return {t["host"] for name, s in registry(path).items() if source in (None, name)
            for t in s.get("terms", []) if certified(t) and (not retrieval or t.get("retrieval"))}


def admits(entries, host, path):
    """Whether some entry covers this host and path: a bare host covers all of it, `host/prefix` only that prefix."""
    return any(e == host or (e.startswith(host + "/") and (host + path).startswith(e)) for e in entries)
