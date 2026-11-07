"""The HL client retries 429s, 5xxs and transport errors, and charges every attempt against its per-minute budget."""

import httpx
import pytest

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
    assert [w for _, w in info.limiter.spent] == [20, 20, 20, 20]


def test_an_impossible_charge_is_rejected_without_waiting(monkeypatch):
    info = hl.Info(60)
    monkeypatch.setattr(hl.time, "sleep", lambda s: pytest.fail("impossible charge waited"))
    with pytest.raises(ValueError, match="weight"):
        info._charge(80)


def test_a_full_hourly_page_is_reserved_before_sending_and_never_postcharged(monkeypatch):
    info = hl.Info(120)
    page = [{"t": i * hl.HOUR} for i in range(4800)]
    charged = []
    monkeypatch.setattr(info, "_charge", charged.append)

    def reply(req):
        assert charged == [20 + 5000 // 60]
        return httpx.Response(200, json=page)

    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    assert len(info.candles("X", "1h", 0, 4800 * hl.HOUR)) == 4800
    assert charged == [103]
