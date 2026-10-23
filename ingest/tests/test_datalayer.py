"""The data layer fetches only feeds whose hosts have certified terms, and keeps every body with its poll times."""

import json

import httpx
import pytest

from ingest import datalayer, live


def test_every_declared_feed_has_certified_terms():
    assert datalayer.feeds()["feeds"]


def test_a_feed_without_certified_terms_is_refused(tmp_path):
    spec = {"user_agent": "x", "feeds": [{"name": "x", "doc": "venue/sources/ecb.md", "every_h": 1,
                                          "url": "https://example.org/data"}]}
    (tmp_path / "f.json").write_text(json.dumps(spec))
    with pytest.raises(PermissionError):
        datalayer.feeds(tmp_path / "f.json")


def test_poll_keeps_the_body_content_addressed_with_its_times(tmp_path):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"<data/>")))
    feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
    rec = datalayer.poll(http, feed, tmp_path)
    assert (tmp_path / "raw" / rec["sha256"]).read_bytes() == b"<data/>"
    assert rec["status"] == 200 and rec["sent"] <= rec["recv"]
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["ecb-exr"]
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}
