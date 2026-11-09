"""The HL client retries 429s, 5xxs and transport errors, and charges every attempt against its per-minute budget."""

import httpx
import pytest

from ingest import hl


def test_each_retry_is_charged(monkeypatch: pytest.MonkeyPatch) -> None:
    replies = iter([429, 500, "timeout", 200])

    def reply(req: httpx.Request) -> httpx.Response:
        r = next(replies)
        if r == "timeout":
            raise httpx.ReadTimeout("timed out", request=req)
        return httpx.Response(r, json=[])

    info = hl.Info(1200)
    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    monkeypatch.setattr(hl.time, "sleep", lambda s: None)
    assert info.post({"type": "meta"}, weight=20) == []
    assert [w for _, w in info.limiter.spent] == [20, 20, 20, 20]


def test_an_impossible_charge_is_rejected_without_waiting(monkeypatch: pytest.MonkeyPatch) -> None:
    info = hl.Info(60)
    monkeypatch.setattr(hl.time, "sleep", lambda s: pytest.fail("impossible charge waited"))
    with pytest.raises(ValueError, match="weight"):
        info._charge(80)


@pytest.mark.parametrize("body, per_items", [({"type": "fundingHistory"}, 20), ({"type": "candleSnapshot"}, 60)])
def test_recorder_requests_keep_base_then_actual_item_charging(
    monkeypatch: pytest.MonkeyPatch, body: dict[str, str], per_items: int
) -> None:
    info = hl.Info(360)
    charged: list[int] = []
    monkeypatch.setattr(info, "_charge", lambda weight, background=False: charged.append(weight))

    def reply(req: httpx.Request) -> httpx.Response:
        assert charged == [20]
        return httpx.Response(200, json=[{}])

    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    assert info.post(body, per_items=per_items) == [{}]
    assert charged == [20, 0]


def test_shared_client_charges_only_returned_items_after_a_full_page(monkeypatch: pytest.MonkeyPatch) -> None:
    info = hl.Info(120)
    page = [{"t": i * hl.HOUR} for i in range(4800)]
    charged: list[int] = []
    monkeypatch.setattr(info, "_charge", lambda weight, background=False: charged.append(weight))

    def reply(req: httpx.Request) -> httpx.Response:
        assert charged == [20]
        return httpx.Response(200, json=page)

    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    assert len(info.candles("X", "1h", 0, 4800 * hl.HOUR)) == 4800
    assert charged == [20, 80]


def test_shared_client_does_not_retry_a_malformed_successful_response(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[httpx.Request] = []

    def reply(req: httpx.Request) -> httpx.Response:
        calls.append(req)
        return httpx.Response(200, text="{torn") if len(calls) == 1 else httpx.Response(200, json=[])

    info = hl.Info()
    info.http = httpx.Client(transport=httpx.MockTransport(reply))
    monkeypatch.setattr(hl.time, "sleep", lambda seconds: None)
    with pytest.raises(ValueError):
        info.meta()
    assert len(calls) == 1
