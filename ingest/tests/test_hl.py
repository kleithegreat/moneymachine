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


@pytest.mark.parametrize("body, per_items", [({"type": "fundingHistory"}, 20), ({"type": "candleSnapshot"}, 60)])
def test_recorder_requests_keep_base_then_actual_item_charging(monkeypatch, body, per_items):
    info = hl.Info(360)
    charged = []
    monkeypatch.setattr(info, "_charge", charged.append)

    def reply(req):
        assert charged == [20]
        return httpx.Response(200, json=[{}])

    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    assert info.post(body, per_items=per_items) == [{}]
    assert charged == [20, 0]


def test_shared_client_charges_only_returned_items_after_a_full_page(monkeypatch):
    info = hl.Info(120)
    page = [{"t": i * hl.HOUR} for i in range(4800)]
    charged = []
    monkeypatch.setattr(info, "_charge", charged.append)

    def reply(req):
        assert charged == [20]
        return httpx.Response(200, json=page)

    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    assert len(info.candles("X", "1h", 0, 4800 * hl.HOUR)) == 4800
    assert charged == [20, 80]
