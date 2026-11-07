"""C10.2/C10.5: the exchange adapter permits only the frozen public read types, at one fixed host."""

import random

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
        self.rows, self.starts, self.requests = rows, [], []

    def funding(self, market, start, end):
        self.starts.append(start)
        self.requests.append((start, end))
        return [{"time": t, "fundingRate": str(r)} for t, r in self.rows if start <= t < end]

    def candles(self, market, interval, start, end):
        self.starts.append(start)
        self.requests.append((start, end))
        return [{"t": t, "o": str(r), "c": str(r)} for t, r in self.rows if start <= t < end]


def test_a_funding_row_the_venue_supplies_late_fills_its_hole(tmp_path):
    x = Venue([(H, 0.1), (3 * H, 0.3)])
    m = market.Market(tmp_path, x, repair_every=0)
    assert m.funding("X", 4 * H) == [[H, 0.1], [3 * H, 0.3]]
    x.rows = [(H, 0.1), (2 * H, 0.2), (3 * H, 0.3)]
    assert m.funding("X", 4 * H) == [[H, 0.1], [2 * H, 0.2], [3 * H, 0.3]]


def test_a_candle_the_venue_supplies_late_fills_its_hole(tmp_path):
    x = Venue([(H, 1.0), (3 * H, 3.0)])
    m = market.Market(tmp_path, x, repair_every=0)
    assert m.bars("X", "1h", 5 * H) == [[H, 1.0, 1.0], [3 * H, 3.0, 3.0]]
    x.rows = [(H, 1.0), (2 * H, 2.0), (3 * H, 3.0)]
    assert m.bars("X", "1h", 5 * H) == [[H, 1.0, 1.0], [2 * H, 2.0, 2.0], [3 * H, 3.0, 3.0]]


def test_a_cached_row_is_never_rewritten(tmp_path):
    x = Venue([(H, 0.1), (3 * H, 0.3)])
    m = market.Market(tmp_path, x, repair_every=0)
    m.funding("X", 4 * H)
    x.rows = [(H, 0.9), (2 * H, 0.2), (3 * H, 0.9), (4 * H, 0.4)]
    assert m.funding("X", 5 * H) == [[H, 0.1], [2 * H, 0.2], [3 * H, 0.3], [4 * H, 0.4]]


def test_without_a_hole_only_new_rows_are_requested(tmp_path):
    x = Venue([(H, 0.1), (2 * H, 0.2)])
    m = market.Market(tmp_path, x)
    m.funding("X", 3 * H)
    m.funding("X", 3 * H)
    assert x.starts[-1] == 2 * H + 1


def test_a_hole_of_any_age_is_retried_until_the_venue_fills_it(tmp_path):
    now = 2000 * market.DAY
    old = now - 1000 * market.DAY
    x = Venue([(old, 0.1), (old + 2 * H, 0.3), (now - H, 0.5)])
    m = market.Market(tmp_path, x, repair_every=0)
    m.funding("X", now)
    x.rows.append((old + H, 0.2))
    assert [old + H, 0.2] in m.funding("X", now)


def test_rows_missing_before_the_first_cached_row_are_retried(tmp_path):
    now = 200 * market.DAY
    x = Venue([(now - 5 * H, 0.1), (now - H, 0.5)])
    m = market.Market(tmp_path, x, repair_every=0)
    m.funding("X", now)
    x.rows.append((now - 9 * H, 0.9))
    assert m.funding("X", now)[0] == [now - 9 * H, 0.9]


def test_a_hole_is_requested_alone_not_with_everything_after_it(tmp_path):
    now = 2000 * market.DAY
    hole = now - 2000 * H
    x = Venue([(hole + k * H, 0.5) for k in range(-1000, 1000) if k != 0])
    m = market.Market(tmp_path, x, repair_every=0)
    m.funding("X", now)
    x.requests.clear()
    m.funding("X", now)
    assert (hole, hole + H) in [(a, b - 1) for a, b in x.requests]


def test_repair_is_bounded_to_one_pass_per_interval(tmp_path):
    now = 200 * market.DAY
    x = Venue([(now - 5 * H, 0.1), (now - 3 * H, 0.3)])
    m = market.Market(tmp_path, x, repair_every=H)
    m.funding("X", now)
    x.requests.clear()
    m.funding("X", now)
    assert all(start > now - 3 * H for start, _ in x.requests)


def test_a_required_row_supplied_late_is_visible_within_the_repair_interval(tmp_path, monkeypatch):
    now = 200 * market.DAY
    clock = [now]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    x = Venue([(now - 5 * H, 0.1), (now - 3 * H, 0.3)])
    m = market.Market(tmp_path, x, repair_every=H)
    m.funding("X", now)
    x.rows.append((now - 4 * H, 0.2))
    assert [now - 4 * H, 0.2] not in m.funding("X", now)
    clock[0] = now + H
    assert [now - 4 * H, 0.2] in m.funding("X", now + H)


def test_listed_reads_only_the_dexes_of_the_markets_asked(tmp_path, monkeypatch):
    posts = []

    class Exchange:
        def meta(self):
            posts.append("core")
            return {"universe": [{"name": "BTC"}, {"name": "OLD", "isDelisted": True}]}

        def post(self, body):
            posts.append(body.get("dex", body["type"]))
            return [None, {"name": "xyz"}] if body["type"] == "perpDexs" else {"universe": [{"name": "xyz:GOLD"}]}

    m = market.Market(tmp_path, Exchange())
    assert m.listed(["BTC", "OLD"]) == {"BTC": False, "OLD": True}
    assert posts == ["core"]
    assert m.listed(["BTC", "xyz:GOLD"])["xyz:GOLD"] is False
    assert posts[1] == "perpDexs" and sorted(posts[2:]) == ["core", "xyz"]
    assert m.listed(["xzy:GOLD"]) == {} and posts[4:] == ["perpDexs"]


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


# F4: a warm cache gives what a cold one does.
def test_a_cached_candle_read_at_an_earlier_cutoff_shows_its_open_with_a_null_close(tmp_path):
    x = Venue([(H, 1.0), (2 * H, 2.0)])
    warm = market.Market(tmp_path / "warm", x)
    warm.bars("X", "1h", 4 * H)
    cold = market.Market(tmp_path / "cold", x)
    cutoff = 2 * H + 10 * 60_000
    assert warm.bars("X", "1h", cutoff) == cold.bars("X", "1h", cutoff) == [[H, 1.0, 1.0], [2 * H, 2.0, None]]


@pytest.mark.parametrize("cutoff", [H + market.DELTA - 1, H + market.DELTA, 2 * H, 2 * H + market.DELTA - 1, 2 * H + market.DELTA, 3 * H + market.DELTA])
def test_a_reference_as_of_a_cutoff_is_the_same_whatever_was_read_before(tmp_path, cutoff):
    rows = [(H, 1.0), (2 * H, 2.0), (3 * H, 3.0)]
    warm = market.Market(tmp_path / "warm", Venue(rows))
    warm.bars("X", "1h", 5 * H)
    assert warm.bars("X", "1h", cutoff) == market.Market(tmp_path / "cold", Venue([r for r in rows if r[0] < cutoff])).bars("X", "1h", cutoff)


def test_a_daily_candle_stays_hidden_at_an_earlier_cutoff_of_a_warm_cache(tmp_path):
    day = market.DAY
    m = market.Market(tmp_path, Venue([(day, 1.0), (2 * day, 2.0)]))
    m.bars("X", "1d", 4 * day)
    assert m.bars("X", "1d", 2 * day + market.DELTA) == [[day, 1.0, 1.0]]


def test_a_repair_spanning_a_cached_row_at_an_earlier_cutoff_shows_that_row_once(tmp_path):
    # Holes at 2H and 4H share a request, which returns the cached 3H; read as of 3H + 10 min, 3H is still in progress.
    x = Venue([(H, 1.0), (3 * H, 3.0), (5 * H, 5.0)])
    m = market.Market(tmp_path, x, repair_every=0)
    m.bars("X", "1h", 7 * H)
    assert m.bars("X", "1h", 3 * H + 10 * 60_000) == [[H, 1.0, 1.0], [3 * H, 3.0, None]]


# GPT's round 2 review, B1: a daily row the venue omitted before the first cached one can decide a market's eligibility.
def test_daily_rows_missing_before_the_first_cached_row_are_retried(tmp_path):
    day = market.DAY
    x = Venue([(k * day, 1.0) for k in range(191, 400)])
    m = market.Market(tmp_path, x, repair_every=0)
    assert len(m.bars("X", "1d", 400 * day + market.DELTA)) == 209
    x.rows.insert(0, (190 * day, 1.0))
    assert m.bars("X", "1d", 400 * day + market.DELTA)[0][0] == 190 * day


# Claude's round 2 review, R2: a session's calls each reread every market's tail.
def test_a_read_holding_the_newest_row_it_can_show_requests_nothing(tmp_path):
    x = Venue([(H, 1.0), (2 * H, 2.0)])
    m = market.Market(tmp_path, x)
    m.bars("X", "1h", 2 * H + market.DELTA), m.funding("X", 2 * H + 1000)
    x.requests.clear()
    assert m.bars("X", "1h", 3 * H) == [[H, 1.0, 1.0], [2 * H, 2.0, None]]
    assert m.funding("X", 3 * H - 1) == [[H, 1.0], [2 * H, 2.0]] and x.requests == []
    m.bars("X", "1h", 3 * H + market.DELTA)
    assert x.requests


def test_a_row_the_venue_has_not_yet_published_is_asked_for_again(tmp_path):
    x = Venue([(H, 0.1)])
    m = market.Market(tmp_path, x)
    m.funding("X", 2 * H + 1000)
    x.rows.append((2 * H, 0.2))
    assert m.funding("X", 2 * H + 2000) == [[H, 0.1], [2 * H, 0.2]]


# GPT's round 3 check: a row read before it was shown hid the row beneath it, and a daily one was dropped once final.
class Live(Venue):
    """A venue whose candle in progress at `clock` has a close that later changes."""

    def __init__(self, rows, step, clock):
        super().__init__(rows)
        self.step, self.clock = step, clock

    def candles(self, market, interval, start, end):
        return [c | ({"c": "-1"} if c["t"] + self.step > self.clock[0] else {}) for c in super().candles(market, interval, start, end)]


@pytest.mark.parametrize("seed", range(30))
@pytest.mark.parametrize("interval, step", [("1d", market.DAY), ("1h", H)])
def test_a_warm_cache_gives_what_a_cold_one_does_at_every_read(tmp_path, monkeypatch, seed, interval, step):
    rng = random.Random(seed)
    midnight = 200 * market.DAY
    rows = [(midnight + k * step, float(k)) for k in range(-100, 4)]
    offsets = [0, 1, market.DELTA - 1, market.DELTA, market.DELTA + 1, 10 * 60_000, H - 1]
    reads = sorted(midnight + rng.randrange(-2, 3) * H + rng.choice(offsets) for _ in range(12))
    clock = [reads[0]]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    warm = market.Market(tmp_path / "warm", Live(rows, step, clock))
    funding = market.Market(tmp_path / "warm-funding", Venue(rows))
    for n, read in enumerate(reads):
        clock[0] = read
        cutoff = read - rng.choice([0, 0, H, 3 * H])
        cold = tmp_path / f"cold-{n}"
        assert warm.bars("X", interval, cutoff) == market.Market(cold, Live(rows, step, clock)).bars("X", interval, cutoff), (reads, read, cutoff)
        assert funding.funding("X", cutoff) == market.Market(cold, Venue(rows)).funding("X", cutoff), (reads, read, cutoff)


def test_ninety_days_complete_at_ten_past_midnight_after_a_read_at_midnight(tmp_path, monkeypatch):
    day, midnight = market.DAY, 200 * market.DAY
    clock = [midnight]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    m = market.Market(tmp_path, Venue([(midnight - k * day, 1.0) for k in range(91)]))
    assert len(m.bars("X", "1d", midnight)) == 89
    clock[0] = midnight + 10 * 60_000
    assert len(m.bars("X", "1d", clock[0])) == 90


def test_an_hourly_bar_stays_when_the_next_was_read_before_it_showed(tmp_path, monkeypatch):
    midnight = 200 * market.DAY
    clock = [midnight + 1]
    monkeypatch.setattr(market, "now_ms", lambda: clock[0])
    m = market.Market(tmp_path, Venue([(midnight - 2 * H, 1.0), (midnight - H, 2.0), (midnight, 3.0)]))
    m.bars("X", "1h", clock[0])
    clock[0] = midnight + market.DELTA
    assert [r[0] for r in m.bars("X", "1h", clock[0])] == [midnight - 2 * H, midnight - H, midnight]


def test_a_row_that_expires_from_memory_is_read_again_before_a_newer_row_can_suppress_the_fetch(tmp_path):
    t = 100 * market.HOUR
    x = Venue([(t - 2 * market.HOUR, 1.0), (t, 3.0)])
    m = market.Market(tmp_path, x)
    m.repair_every = 10 ** 15
    assert [r[0] for r in m.bars("X", "1h", t + 2 * 60_000 + 60_000)] == [t - 2 * market.HOUR, t]
    x.rows = sorted(x.rows + [(t - market.HOUR, 2.0)])
    assert t - market.HOUR in [r[0] for r in m.bars("X", "1h", t - 60_000)]
    assert t - market.HOUR in [r[0] for r in m.bars("X", "1h", t + market.DELTA + 60_000)]


DEX_REPLY = [{"universe": [{"name": "xyz:GOLD"}]}, [{"markPx": "2400.5"}]]


def test_one_dex_failing_never_costs_another_dex_its_sample(tmp_path, monkeypatch):
    def post(body, *a, **k):
        if body["type"] == "perpDexs":
            return [None, {"name": "bad"}, {"name": "xyz"}]
        if body["dex"] == "bad":
            raise RuntimeError("retries exhausted")
        return DEX_REPLY
    x = market.Exchange(tmp_path / "x")
    monkeypatch.setattr(x, "post", post)
    m = market.Market(tmp_path / "m", x)
    monkeypatch.setattr(market, "now_ms", lambda: 5_000)
    m.record_marks()
    assert m.marks("xyz:GOLD") == [(5_000, 5_000, 2400.5)]
    bad, good = market.read(tmp_path / "m" / "marks", "marks")
    assert (bad["dex"], good["dex"]) == ("bad", "xyz")
    assert bad["marks"] == {} and "retries exhausted" in bad["error"]
    assert (bad["sent"], bad["recv"]) == (5_000, 5_000)
    assert good["response"] == DEX_REPLY
    assert m.marks("bad:COIN") == [(5_000, 5_000, None)]


@pytest.mark.xfail(strict=True, reason="audit/reviews/2026-11-04-claude-hunt-thesis.md, finding 3: the hourly mark sample waits behind the budget every other "
                   "venue read spends, and records as its send time the moment before that wait")
def test_the_mark_sample_is_sent_at_its_time_whatever_other_reads_spent(tmp_path, monkeypatch):
    """Criteria, stage 10, revision of 2026-10-23: for every builder dex and hour H a request is sent at H + 5 s."""
    clock = [H + market.MARK_OFFSET]
    monkeypatch.setattr(hl, "time", type("Clock", (), {"monotonic": staticmethod(lambda: clock[0] / 1000),
                                                         "sleep": staticmethod(lambda s: clock.__setitem__(0, clock[0] + s * 1000))}))
    monkeypatch.setattr(market, "now_ms", lambda: int(clock[0]))
    replies, posted = {"perpDexs": [None, {"name": "xyz"}], "metaAndAssetCtxs": DEX_REPLY}, []

    class Response:
        status_code = 200

        def __init__(self, body):
            self.body = body

        def raise_for_status(self):
            pass

        def json(self):
            return replies[self.body["type"]]

    x = market.Exchange(tmp_path / "x")
    monkeypatch.setattr(x.http, "post", lambda url, json: posted.append(int(clock[0])) or Response(json))
    x.spent = [(clock[0] / 1000, x.budget)]
    market.Market(tmp_path / "m", x).record_marks()
    (sample,) = market.read(tmp_path / "m" / "marks", "marks")
    assert posted[0] <= H + market.MARK_OFFSET + 1_000
    assert sample["sent"] == posted[-1]
