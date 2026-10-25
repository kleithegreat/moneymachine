"""The HL client charges every attempt against its per-minute budget, retried ones included."""

import httpx

from ingest import hl


def test_each_retry_is_charged(monkeypatch):
    replies = iter([429, 500, 200])
    info = hl.Info(1200)
    info.http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(next(replies), json=[])))
    monkeypatch.setattr(hl.time, "sleep", lambda s: None)
    assert info.post({"type": "meta"}, weight=20) == []
    assert [w for _, w in info.spent] == [20, 20, 20]
