"""Terms certification (paper §5): a source binds only if its doc quotes the clause permitting our automated
use, with its URL and retrieval date, or shows it is an official API whose terms allow it. Every host the
code fetches must have such a section."""

import re
from pathlib import Path
from urllib.parse import urlparse

from ingest import hl, sources_record

REPO = Path(__file__).resolve().parents[2]
FETCHED = {
    "venue/sources/discourse.md": sources_record.FORUMS,
    "venue/sources/snapshot.md": [urlparse(sources_record.HUB).hostname],
    "venue/hyperliquid/sources.md": [urlparse(hl.URL).hostname],
}


def terms(doc):
    """host -> its `## Terms: host` section's text."""
    return dict(re.findall(r"^## Terms: (\S+)\n(.*?)(?=^## |\Z)", doc, re.M | re.S))


def certified(section):
    return (re.search(r"^- URL: https://\S+$", section, re.M) is not None
            and re.search(r"^- Retrieved: \d{4}-\d{2}-\d{2}$", section, re.M) is not None
            and re.search(r"^- Basis: (permitting clause|official API)$", section, re.M) is not None
            and re.search(r"^> \S", section, re.M) is not None)


def test_every_fetched_host_has_certified_terms():
    missing = [(doc, host) for doc, hosts in FETCHED.items() for host in hosts
               if not certified(terms((REPO / doc).read_text()).get(host, ""))]
    assert not missing


def test_a_section_without_its_evidence_fails():
    good = "- URL: https://x.org/tos\n- Retrieved: 2026-10-22\n- Basis: permitting clause\n\n> You may automate access.\n"
    assert certified(good)
    for drop in ("- URL", "- Retrieved", "- Basis", "> "):
        assert not certified("\n".join(l for l in good.splitlines() if not l.startswith(drop)))
    assert not certified(good.replace("permitting clause", "silence"))
