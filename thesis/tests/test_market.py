"""C10.2/C10.5: the exchange adapter permits only the frozen public read types, at one fixed host."""

import pytest

from ingest import hl
from thesis import market


@pytest.mark.parametrize("kind", ["order", "cancel", "clearinghouseState", "userFills", "l2Book", "exchange", None])
def test_adapter_refuses_everything_but_the_frozen_reads(tmp_path, kind):
    x = market.Exchange(tmp_path)
    with pytest.raises(PermissionError):
        x.post({"type": kind})


def test_adapter_posts_only_to_the_public_info_endpoint(tmp_path, monkeypatch):
    sent = []

    class Response:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            return {"universe": []}

    x = market.Exchange(tmp_path)
    monkeypatch.setattr(x.http, "post", lambda url, json: sent.append((url, json)) or Response())
    x.meta()
    assert sent == [(hl.URL, {"type": "meta"})] and hl.URL == "https://api.hyperliquid.xyz/info"
    assert len(list(tmp_path.glob("info-*.jsonl"))) == 1


def test_no_signing_or_exchange_endpoint_in_the_repository():
    from pathlib import Path

    repo = Path(__file__).resolve().parents[2]
    sources = [p for p in repo.rglob("*.py") if ".git" not in p.parts and "data" not in p.parts and p != Path(__file__)]
    text = "\n".join(p.read_text() for p in sources)
    for banned in ("eth_account", "eth_keys", "sign_l1_action", "private_key", "/exchange\"", "hyperliquid.exchange"):
        assert banned not in text, banned


H = 3_600_000


def test_mark_bars_use_the_earliest_sample_in_each_hours_window():
    samples = [(0 * H + 5_000, 0 * H + 6_000, 100.0), (0 * H + 60_000, 0 * H + 61_000, 999.0),
               (1 * H + 299_999, 1 * H + 300_500, 101.0), (2 * H + 5_000, 2 * H + 6_000, 102.0)]
    assert market.mark_bars(samples, 3 * H) == [[0, 100.0, 101.0], [H, 101.0, 102.0]]


def test_a_sample_sent_after_the_window_is_no_mark():
    samples = [(0 + 5_000, 6_000, 100.0), (H + 300_000, H + 301_000, 101.0), (2 * H + 5_000, 2 * H + 6_000, 102.0)]
    assert market.mark_bars(samples, 3 * H) == []


def test_a_missing_mark_gives_missing_bars_and_no_earlier_price():
    samples = [(5_000, 6_000, 100.0), (2 * H + 5_000, 2 * H + 6_000, 102.0), (3 * H + 5_000, 3 * H + 6_000, 103.0)]
    assert market.mark_bars(samples, 4 * H) == [[2 * H, 102.0, 103.0]]


def test_a_mark_received_after_now_is_not_yet_known():
    samples = [(5_000, 6_000, 100.0), (H + 5_000, H + 9_000, 101.0)]
    assert market.mark_bars(samples, H + 8_000) == []
    assert market.mark_bars(samples, H + 9_000) == [[0, 100.0, 101.0]]


def test_a_bar_whose_closing_mark_is_missing_does_not_exist():
    assert market.mark_bars([(5_000, 6_000, 100.0)], 5 * H) == []


def test_builder_markets_take_their_hourly_bars_from_recorded_marks(tmp_path, monkeypatch):
    replies = {"perpDexs": [None, {"name": "xyz"}],
               "metaAndAssetCtxs": [{"universe": [{"name": "xyz:GOLD"}, {"name": "xyz:XYZ100"}]},
                                    [{"markPx": "2400.5"}, {"markPx": None}]]}
    x = market.Exchange(tmp_path / "x")
    monkeypatch.setattr(x, "post", lambda body, *a, **k: replies[body["type"]])
    m = market.Market(tmp_path / "m", x)
    clock = iter([5_000, 6_000, H + 5_000, H + 6_000])
    monkeypatch.setattr(market, "now_ms", lambda: next(clock))
    m.record_marks()
    m.record_marks()
    assert m.marks("xyz:GOLD") == [(5_000, 6_000, 2400.5), (H + 5_000, H + 6_000, 2400.5)]
    assert m.marks("xyz:XYZ100") == []
    assert m.bars("xyz:GOLD", "1h", 2 * H) == [[0, 2400.5, 2400.5]]
