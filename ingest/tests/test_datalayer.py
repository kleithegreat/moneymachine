"""The data layer fetches only feeds whose hosts have certified terms, and keeps every body with its poll times."""

import json

import httpx
import pytest

from ingest import datalayer, live


def test_every_declared_feed_has_certified_terms():
    assert datalayer.feeds()["feeds"]


def test_a_feed_without_certified_terms_is_refused(tmp_path):
    spec = {"user_agent": "x", "feeds": [{"name": "x", "source": "ecb", "every_h": 1,
                                          "url": "https://example.org/data"}]}
    (tmp_path / "f.json").write_text(json.dumps(spec))
    with pytest.raises(PermissionError):
        datalayer.feeds(tmp_path / "f.json")


def test_poll_keeps_the_body_content_addressed_with_its_times(tmp_path):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"<data/>")))
    feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
    rec = datalayer.poll(http, feed, tmp_path)
    assert datalayer.body(tmp_path, rec["sha256"]) == b"<data/>"
    assert rec["status"] == 200 and rec["sent"] <= rec["recv"]
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["ecb-exr"]
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}


def test_discover_fetches_the_index_then_the_release_it_names(tmp_path):
    bodies = {"/gdeltv2/lastupdate.txt": b"1 ab http://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip\n",
              "/gdeltv2/20261023184500.export.CSV.zip": b"zip"}
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=bodies[req.url.path])))
    feed = next(f for f in datalayer.feeds()["feeds"] if f["name"] == "gdelt-events")
    rec = datalayer.poll(http, feed, tmp_path)
    assert rec["url"] == "https://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip"
    assert datalayer.body(tmp_path, rec["sha256"]) == b"zip"
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["gdelt-events/index", "gdelt-events"]
    assert set(datalayer.last_polls(tmp_path)) == {"gdelt-events"}


def test_a_discovered_url_without_certified_terms_is_refused(tmp_path):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"x")))
    feed = {"name": "x", "source": "gdelt", "every_h": 1,
            "discover": {"url": "https://data.gdeltproject.org/i", "pattern": "(x)", "template": "https://example.org/{}"}}
    with pytest.raises(PermissionError):
        datalayer.poll(http, feed, tmp_path)
