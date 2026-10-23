"""Terms certification (paper §5): every place the code fetches from automatically has a certified Terms section
(ingest/terms.py), and a section without its evidence is not certified."""

from pathlib import Path
from urllib.parse import urlparse

from ingest import hl, sources_record, terms
from thesis import retrieval

REPO = Path(__file__).resolve().parents[2]
FETCHED = {
    "venue/sources/discourse.md": sources_record.FORUMS,
    "venue/sources/snapshot.md": [urlparse(sources_record.HUB).hostname],
    "venue/hyperliquid/sources.md": [urlparse(hl.URL).hostname],
}


def test_every_fetched_host_has_certified_terms():
    missing = [(doc, host) for doc, hosts in FETCHED.items() for host in hosts
               if not terms.certified(terms.sections((REPO / doc).read_text()).get(host, ""))]
    assert not missing


def test_every_retrieval_entry_is_certified():
    entries = terms.sections(retrieval.SOURCES.read_text())
    assert entries and all(terms.certified(s) for s in entries.values())


def test_a_section_without_its_evidence_fails():
    good = "- URL: https://x.org/tos\n- Retrieved: 2026-10-22\n- Basis: permitting clause\n\n> You may automate access.\n"
    assert terms.certified(good)
    for drop in ("- URL", "- Retrieved", "- Basis", "> "):
        assert not terms.certified("\n".join(l for l in good.splitlines() if not l.startswith(drop)))
    assert not terms.certified(good.replace("permitting clause", "silence"))


def test_a_prefix_entry_admits_only_its_prefix():
    entries = {"api.x.org", "www.y.gov/feeds/"}
    assert terms.admits(entries, "api.x.org", "/anything") and terms.admits(entries, "www.y.gov", "/feeds/a.xml")
    assert not terms.admits(entries, "www.y.gov", "/newsevents/a.htm") and not terms.admits(entries, "x.org", "/")
    assert not terms.admits(entries, "evil.api.x.org", "/") and not terms.admits(entries, "www.y.gov.evil", "/feeds/")
