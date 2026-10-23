"""Terms certification (paper §5): every place the code fetches from automatically has a certified record in the
registry `venue/sources.toml`, and a record without its evidence is not certified."""

from datetime import date
from urllib.parse import urlparse

from ingest import datalayer, hl, sources_record, terms

FETCHED = {
    "discourse": sources_record.FORUMS,
    "snapshot": [urlparse(sources_record.HUB).hostname],
    "hyperliquid": [urlparse(hl.URL).hostname],
}


def test_every_fetched_host_has_certified_terms():
    missing = [(source, host) for source, hosts in FETCHED.items() for host in hosts
               if not terms.admits(terms.allowlist(source), host, "/")]
    assert not missing
    assert datalayer.feeds()["feeds"]


def test_every_record_is_certified():
    records = [t for s in terms.registry().values() for t in s.get("terms", [])]
    assert records and all(terms.certified(t) for t in records)


def test_a_record_without_its_evidence_fails():
    good = {"host": "x.org", "url": "https://x.org/tos", "retrieved": date(2026, 10, 22), "basis": "permitting clause",
            "quote": "You may automate access."}
    assert terms.certified(good)
    for drop in ("url", "retrieved", "basis", "quote"):
        assert not terms.certified({k: v for k, v in good.items() if k != drop})
    assert not terms.certified(good | {"basis": "silence"})
    assert not terms.certified(good | {"url": "http://x.org/tos"})


def test_a_prefix_entry_admits_only_its_prefix():
    entries = {"api.x.org", "www.y.gov/feeds/"}
    assert terms.admits(entries, "api.x.org", "/anything") and terms.admits(entries, "www.y.gov", "/feeds/a.xml")
    assert not terms.admits(entries, "www.y.gov", "/newsevents/a.htm") and not terms.admits(entries, "x.org", "/")
    assert not terms.admits(entries, "evil.api.x.org", "/") and not terms.admits(entries, "www.y.gov.evil", "/feeds/")
