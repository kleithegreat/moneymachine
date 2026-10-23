"""Terms certification (paper §5). A source doc has one `## Terms: <host>` or `## Terms: <host>/<path prefix>`
section per place we fetch from automatically. A section is certified when it carries its evidence: the URL of
the terms, the retrieval date, the basis (a clause permitting our automated use, or an official API whose terms
allow it), and the quoted text."""

import re
from pathlib import Path


def sections(doc):
    """`host[/prefix]` -> its section's text."""
    return dict(re.findall(r"^## Terms: (\S+)\n(.*?)(?=^## |\Z)", doc, re.M | re.S))


def certified(section):
    return (re.search(r"^- URL: https://\S+$", section, re.M) is not None
            and re.search(r"^- Retrieved: \d{4}-\d{2}-\d{2}$", section, re.M) is not None
            and re.search(r"^- Basis: (permitting clause|official API)$", section, re.M) is not None
            and re.search(r"^> \S", section, re.M) is not None)


def allowlist(path):
    """The certified `host[/prefix]` entries of a source doc."""
    return {k for k, s in sections(Path(path).read_text()).items() if certified(s)}


def admits(entries, host, path):
    """Whether some entry covers this host and path: a bare host covers all of it, `host/prefix` only that prefix."""
    return any(e == host or (e.startswith(host + "/") and (host + path).startswith(e)) for e in entries)
