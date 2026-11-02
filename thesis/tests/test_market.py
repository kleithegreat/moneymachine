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
    import subprocess
    from pathlib import Path

    repo = Path(__file__).resolve().parents[2]
    tracked = subprocess.run(["git", "ls-files", "*.py"], cwd=repo, capture_output=True, text=True, check=True).stdout
    sources = [repo / p for p in tracked.split() if repo / p != Path(__file__)]
    text = "\n".join(p.read_text() for p in sources)
    for banned in ("eth_account", "eth_keys", "sign_l1_action", "private_key", "/exchange\"", "hyperliquid.exchange"):
        assert banned not in text, banned



H = 3_600_000
M = 5 * 60_000


def test_the_seal_takes_the_earliest_send_received_by_the_seal_whatever_the_receipt_order():
    a, b = (H + 5_000, H + 4 * 60_000, 101.0), (H + 10_000, H + 20_000, 999.0)
    assert market.seal([b, a]) == {H: 101.0}


def test_a_receipt_after_the_seal_is_kept_but_never_used():
    late, ok = (H + 5_000, H + M + 1, 101.0), (H + 10_000, H + 20_000, 102.0)
    assert market.seal([late, ok]) == {H: 102.0}


def test_ties_go_to_archive_order_and_sends_after_the_window_are_no_candidates():
    assert market.seal([(H + 5_000, H + 6_000, 1.0), (H + 5_000, H + 7_000, 2.0)]) == {H: 1.0}
    assert market.seal([(H + M, H + M + 100, 3.0)]) == {}


def test_a_selected_sample_without_the_markets_mark_leaves_it_missing():
    assert market.seal([(H + 5_000, H + 6_000, None), (H + 9_000, H + 10_000, 5.0)]) == {}


def test_references_are_available_only_once_sealed_and_a_missing_next_mark_leaves_the_close_null():
    samples = [(5_000, 6_000, 100.0), (2 * H + 5_000, 2 * H + 6_000, 102.0), (3 * H + 5_000, 3 * H + 6_000, 103.0)]
    assert market.mark_bars(samples, M - 1) == []
    assert market.mark_bars(samples, 3 * H + M) == [[0, 100.0, None], [2 * H, 102.0, 103.0], [3 * H, 103.0, None]]


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
    assert m.bars("xyz:GOLD", "1h", 2 * H) == [[0, 2400.5, 2400.5], [H, 2400.5, None]]
    assert m.bars("xyz:XYZ100", "1h", 2 * H) == []
    assert (m.lag("xyz:GOLD"), m.lag("BTC")) == (market.MARK_WINDOW, market.DELTA)


class Venue:
    """A venue whose funding and candle rows come from `rows`, recording each request's start."""

    def __init__(self, rows):
        self.rows, self.starts = rows, []

    def funding(self, market, start, end):
        self.starts.append(start)
        return [{"time": t, "fundingRate": str(r)} for t, r in self.rows if start <= t < end]

    def candles(self, market, interval, start, end):
        self.starts.append(start)
        return [{"t": t, "o": str(r), "c": str(r)} for t, r in self.rows if start <= t < end]


def test_a_funding_row_the_venue_supplies_late_fills_its_hole(tmp_path):
    x = Venue([(H, 0.1), (3 * H, 0.3)])
    m = market.Market(tmp_path, x)
    assert m.funding("X", 4 * H) == [[H, 0.1], [3 * H, 0.3]]
    x.rows = [(H, 0.1), (2 * H, 0.2), (3 * H, 0.3)]
    assert m.funding("X", 4 * H) == [[H, 0.1], [2 * H, 0.2], [3 * H, 0.3]]


def test_a_candle_the_venue_supplies_late_fills_its_hole(tmp_path):
    x = Venue([(H, 1.0), (3 * H, 3.0)])
    m = market.Market(tmp_path, x)
    assert m.bars("X", "1h", 5 * H) == [[H, 1.0, 1.0], [3 * H, 3.0, 3.0]]
    x.rows = [(H, 1.0), (2 * H, 2.0), (3 * H, 3.0)]
    assert m.bars("X", "1h", 5 * H) == [[H, 1.0, 1.0], [2 * H, 2.0, 2.0], [3 * H, 3.0, 3.0]]


def test_a_cached_row_is_never_rewritten(tmp_path):
    x = Venue([(H, 0.1), (3 * H, 0.3)])
    m = market.Market(tmp_path, x)
    m.funding("X", 4 * H)
    x.rows = [(H, 0.9), (2 * H, 0.2), (3 * H, 0.9), (4 * H, 0.4)]
    assert m.funding("X", 5 * H) == [[H, 0.1], [2 * H, 0.2], [3 * H, 0.3], [4 * H, 0.4]]


def test_without_a_hole_only_new_rows_are_requested(tmp_path):
    x = Venue([(H, 0.1), (2 * H, 0.2)])
    m = market.Market(tmp_path, x)
    m.funding("X", 3 * H)
    m.funding("X", 3 * H)
    assert x.starts[-1] == 2 * H + 1


def test_a_hole_older_than_any_open_horizon_is_left_alone(tmp_path):
    now = 200 * market.DAY
    old = now - market.REPAIR - 10 * H
    x = Venue([(old, 0.1), (old + 2 * H, 0.3), (now - H, 0.5)])
    m = market.Market(tmp_path, x)
    m.funding("X", now)
    m.funding("X", now)
    assert x.starts[-1] == now - H + 1


def test_a_recent_hole_is_requested_from_where_it_starts(tmp_path):
    now = 200 * market.DAY
    x = Venue([(now - 5 * H, 0.1), (now - 3 * H, 0.3)])
    m = market.Market(tmp_path, x)
    m.funding("X", now)
    m.funding("X", now)
    assert x.starts[-1] == now - 4 * H


def test_listed_reads_only_the_dexes_of_the_markets_asked(tmp_path, monkeypatch):
    posts = []

    class Exchange:
        def meta(self):
            posts.append("core")
            return {"universe": [{"name": "BTC"}, {"name": "OLD", "isDelisted": True}]}

        def post(self, body):
            posts.append(body.get("dex"))
            return {"universe": [{"name": "xyz:GOLD"}]}

    m = market.Market(tmp_path, Exchange())
    assert m.listed(["BTC", "OLD"]) == {"BTC": False, "OLD": True}
    assert posts == ["core"]
    assert m.listed(["BTC", "xyz:GOLD"])["xyz:GOLD"] is False
    assert posts[1:] == ["core", "xyz"]


def test_a_candle_in_progress_shows_its_open_from_δ_and_is_cached_only_once_complete(tmp_path):
    x = Venue([(H, 1.0), (2 * H, 2.0)])
    m = market.Market(tmp_path, x)
    assert m.bars("X", "1h", 2 * H + 60_000) == [[H, 1.0, None]]
    assert m.bars("X", "1h", 2 * H + market.DELTA) == [[H, 1.0, 1.0], [2 * H, 2.0, None]]
    assert m.bars("X", "1h", 3 * H + market.DELTA) == [[H, 1.0, 1.0], [2 * H, 2.0, 2.0]]


def test_a_daily_candle_in_progress_stays_hidden(tmp_path):
    day = market.DAY
    m = market.Market(tmp_path, Venue([(day, 1.0), (2 * day, 2.0)]))
    assert m.bars("X", "1d", 2 * day + market.DELTA) == [[day, 1.0, 1.0]]
