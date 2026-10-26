"""The HL client retries 429s, 5xxs and transport errors, and charges every attempt against its per-minute budget."""

import httpx

from ingest import hl


def test_each_retry_is_charged(monkeypatch):
    replies = iter([429, 500, "timeout", 200])

    def reply(req):
        r = next(replies)
        if r == "timeout":
            raise httpx.ReadTimeout("timed out", request=req)
        return httpx.Response(r, json=[])

    info = hl.Info(1200)
    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    monkeypatch.setattr(hl.time, "sleep", lambda s: None)
    assert info.post({"type": "meta"}, weight=20) == []
    assert [w for _, w in info.spent] == [20, 20, 20, 20]
