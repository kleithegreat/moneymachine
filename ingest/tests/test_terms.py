"""Tests for source metadata, license classification, and host allowlists in `ingest.terms`."""

from pathlib import Path

from ingest import datalayer, terms


def test_every_declared_feed_loads_cleanly() -> None:
    assert datalayer.feeds()["feeds"]


def test_license_class_classification_and_defaults(tmp_path: Path) -> None:
    assert terms.license_class("treasury") == "PUBLIC_DOMAIN"
    assert terms.license_class("sec") == "PUBLIC_DOMAIN"
    assert terms.license_class("gdelt-events") == "PUBLIC_DOMAIN"
    assert terms.license_class("bls-cpi") == "PUBLIC_DOMAIN"
    assert terms.license_class("worldbank") == "CC_BY"
    assert terms.license_class("wikimedia") == "CC_BY"
    assert terms.license_class("databento") == "PERSONAL_RESEARCH"
    assert terms.license_class("unregistered_new_source") == "PERSONAL_RESEARCH"

    custom = tmp_path / "sources.toml"
    custom.write_text(
        '[explicit_nc]\nlicense_class = "NON_COMMERCIAL"\n[[explicit_nc.terms]]\nhost = "nc.example.org"\n'
    )
    assert terms.license_class("explicit_nc", custom) == "NON_COMMERCIAL"
    assert terms.license_class("missing_source", custom) == "PERSONAL_RESEARCH"


def test_allowlist_filters_by_source_retrieval_and_license(tmp_path: Path) -> None:
    assert "api.gdeltproject.org" in terms.allowlist(retrieval=True)
    assert "api.hyperliquid.xyz" in terms.allowlist("hyperliquid")

    custom = tmp_path / "sources.toml"
    custom.write_text(
        """
[pub]
license_class = "PUBLIC_DOMAIN"
[[pub.terms]]
host = "pub.example.org"
retrieval = true

[nc]
license_class = "NON_COMMERCIAL"
[[nc.terms]]
host = "nc.example.org"
retrieval = false
"""
    )
    assert terms.allowlist(path=custom) == {"pub.example.org", "nc.example.org"}
    assert terms.allowlist(retrieval=True, path=custom) == {"pub.example.org"}
    assert terms.allowlist(allowed_licenses={"PUBLIC_DOMAIN", "CC_BY"}, path=custom) == {"pub.example.org"}
    assert terms.allowlist(allowed_licenses={"NON_COMMERCIAL"}, path=custom) == {"nc.example.org"}


def test_a_prefix_entry_admits_only_its_prefix() -> None:
    entries = {"api.x.org", "www.y.gov/feeds/"}
    assert terms.admits(entries, "api.x.org", "/anything") and terms.admits(entries, "www.y.gov", "/feeds/a.xml")
    assert not terms.admits(entries, "www.y.gov", "/newsevents/a.htm") and not terms.admits(entries, "x.org", "/")
    assert not terms.admits(entries, "evil.api.x.org", "/") and not terms.admits(entries, "www.y.gov.evil", "/feeds/")
