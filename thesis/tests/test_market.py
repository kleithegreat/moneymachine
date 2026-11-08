"""C10.2/C10.5: the exchange adapter permits only the frozen public read types, at one fixed host."""

import random
import threading

import httpx
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
    m = market.Market(tmp_path / "m", x)
    clock = [5_000]
    fake_clock(monkeypatch, clock)

    def post(url, json):
        if json["type"] == "metaAndAssetCtxs":
            clock[0] += 1_000
        return httpx.Response(200, json=replies[json["type"]], request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(5_000)
    clock[0] = H + 5_000
    m.record_marks(H + 5_000)
    assert m.marks("xyz:GOLD") == [(5_000, 6_000, 2400.5), (H + 5_000, H + 6_000, 2400.5)]
    assert m.bars("xyz:GOLD", "1h", 2 * H) == [[0, 2400.5, 2400.5], [H, 2400.5, None]]
    assert m.bars("xyz:XYZ100", "1h", 2 * H) == []
    assert (m.lag("xyz:GOLD"), m.lag("BTC")) == (market.MARK_WINDOW, market.DELTA)


class Venue:
    """A venue whose funding and candle rows come from `rows`, recording each request's start."""

    def __init__(self, rows):
        self.rows, self.starts, self.requests = rows, [], []

    def funding_page(self, coin, start, end, background=False):
        self.starts.append(start)
        self.requests.append((start, end))
        return [{"time": t, "fundingRate": str(r)} for t, r in sorted(self.rows) if start <= t < end][:market.MAX_ITEMS["fundingHistory"]]

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
        def post(self, body, background=False):
            posts.append(body.get("dex", "core" if body["type"] == "meta" else body["type"]))
            if body == {"type": "meta"}:
                return {"universe": [{"name": "BTC"}, {"name": "OLD", "isDelisted": True}]}
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


def fake_clock(monkeypatch, clock):
    monkeypatch.setattr(hl, "time", type("Clock", (), {"monotonic": staticmethod(lambda: clock[0] / 1000),
                                                     "sleep": staticmethod(lambda s: clock.__setitem__(0, clock[0] + s * 1000))}))
    monkeypatch.setattr(market, "time", hl.time)
    monkeypatch.setattr(market, "now_ms", lambda: int(clock[0]))


def test_one_dex_failing_never_costs_another_dex_its_sample(tmp_path, monkeypatch):
    def post(url, json):
        response = httpx.Response(200, json=[None, {"name": "bad"}, {"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY,
                                  request=httpx.Request("POST", url))
        if json.get("dex") == "bad":
            response = httpx.Response(400, json={"error": "dex refused"}, request=response.request)
        return response

    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    monkeypatch.setattr(m.sampler.http, "post", post)
    monkeypatch.setattr(market, "now_ms", lambda: 5_000)
    m.record_marks(5_000)
    assert m.marks("xyz:GOLD") == [(5_000, 5_000, 2400.5)]
    rows = list(market.read(m.sampler.archive, "marks"))
    bad, good = (next(r for r in rows if r["request"].get("dex") == d) for d in ("bad", "xyz"))
    assert (bad["request"]["dex"], good["request"]["dex"]) == ("bad", "xyz")
    assert bad["status"] == 400 and bad["response"] == {"error": "dex refused"}
    assert (bad["sent"], bad["recv"]) == (5_000, 5_000)
    assert good["response"] == DEX_REPLY
    assert m.marks("bad:COIN") == []


@pytest.mark.parametrize("first_status", [429, 502, 503, None])
def test_each_attempt_is_archived_at_its_actual_send_and_receipt_after_waits(tmp_path, monkeypatch, first_status):
    clock, posted = [H + market.MARK_OFFSET], []
    fake_clock(monkeypatch, clock)
    replies = iter(([first_status] if first_status else []) + ["timeout", 200])

    def post(url, json):
        posted.append(int(clock[0]))
        clock[0] += 7
        reply = next(replies)
        if reply == "timeout":
            raise httpx.ReadTimeout("cut connection")
        return httpx.Response(reply, json=DEX_REPLY, request=httpx.Request("POST", url))

    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    x = m.sampler
    monkeypatch.setattr(x.http, "post", post)
    x.limiter.spent = [(clock[0] / 1000, x.limiter.budget)]
    assert x.post({"type": "metaAndAssetCtxs", "dex": "xyz"}) == DEX_REPLY
    rows = list(market.read(x.archive, "marks"))
    assert [s["sent"] for s in rows] == posted
    assert [s["recv"] for s in rows] == [None if "error" in s else t + 7 for t, s in zip(posted, rows)]
    assert posted[0] >= H + market.MARK_OFFSET + 60_000
    assert "cut connection" in rows[-2]["error"] and rows[-2]["marks"] == {}
    assert rows[-2]["failed"] == posted[-2] + 7
    assert rows[-1]["marks"] == {"xyz:GOLD": 2400.5}
    if first_status:
        assert rows[0]["status"] == first_status and rows[0]["marks"] == {}
    assert market.seal(m.marks("xyz:GOLD")) == {H: 2400.5}


def test_a_sample_that_cannot_be_archived_is_not_swallowed_as_a_venue_failure(tmp_path, monkeypatch):
    m = market.Market(tmp_path / "m", market.Exchange(tmp_path / "x"))
    monkeypatch.setattr(m.sampler.http, "post", lambda url, json: httpx.Response(
        200, json=[None, {"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY,
        request=httpx.Request("POST", url)))
    append = market.append

    def full(out, prefix, t, row):
        if row["request"]["type"] == "metaAndAssetCtxs":
            raise OSError("disk full")
        append(out, prefix, t, row)

    monkeypatch.setattr(market, "append", full)
    with pytest.raises(OSError, match="disk full"):
        m.record_marks(H + 5_000)


@pytest.mark.parametrize("payload", [[None, []], [{"universe": [None]}, [{}]],
                                     [{"universe": [{"name": "bad:X"}]}, [None]],
                                     [{"universe": [{"name": "bad:X"}]}, []], "truncated"])
def test_malformed_successes_are_archived_retried_and_do_not_abort_other_dexes(tmp_path, monkeypatch, payload):
    clock, attempts = [H + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        attempts.append(json)
        request = httpx.Request("POST", url)
        if json["type"] == "perpDexs":
            return httpx.Response(200, json=[None, {"name": "bad"}, {"name": "xyz"}], request=request)
        if json["dex"] == "bad":
            return httpx.Response(200, text="{torn", request=request) if payload == "truncated" else httpx.Response(200, json=payload, request=request)
        return httpx.Response(200, json=DEX_REPLY, request=request)

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    rows = list(market.read(m.sampler.archive, "marks"))
    assert len(rows) == len(attempts) == 8
    assert all(not r["valid"] for r in rows if r["dex"] == "bad")
    assert market.seal(m.marks("xyz:GOLD")) == {H: 2400.5}


def test_history_and_marks_share_only_the_certified_ip_remainder(tmp_path):
    from ops import live

    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    assert m.x.limiter is m.sampler.limiter
    assert hl.BUDGET_PER_MIN == 600
    assert m.x.limiter.budget <= hl.BUDGET_PER_MIN - int(live.WORKLOADS["hl"][1][-1])
    assert m.x.limiter.budget + hl.RECORDER_WEIGHT_PER_MIN <= hl.BUDGET_PER_MIN
    assert m.x.limiter.budget == hl.BUDGET_PER_MIN - hl.RECORDER_WEIGHT_PER_MIN


def test_queued_history_releases_the_lock_and_drains_before_the_mark_deadline(tmp_path, monkeypatch):
    clock, sent = [H - 56_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    m.x._charge(market.BUDGET_PER_MIN)
    clock[0] = H - 55_000

    def post(url, json):
        sent.append(clock[0])
        payload = [{"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    def sampling_wakes_while_history_is_queued(seconds):
        assert m.x.limiter.lock.acquire(blocking=False), "history slept holding the limiter lock"
        m.x.limiter.lock.release()
        clock[0] = H + 5_000
        m.record_marks(H + 5_000)

    monkeypatch.setattr(m.sampler.http, "post", post)
    monkeypatch.setattr(hl.time, "sleep", sampling_wakes_while_history_is_queued)
    m.x._charge(20)
    assert sent == [H + 5_000] * 2
    assert sum(w for _, w in m.x.limiter.spent) == 60


def test_history_can_spend_the_whole_budget_outside_the_sampling_window(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [H + 10 * 60_000])
    x = market.Exchange(tmp_path)
    x._charge(market.BUDGET_PER_MIN)
    assert sum(w for _, w in x.limiter.spent) == market.BUDGET_PER_MIN


def test_three_dexes_all_get_the_initial_hourly_window(tmp_path, monkeypatch):
    clock, sent = [H + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        if json["type"] == "perpDexs":
            payload = [{"name": d} for d in ("a", "b", "xyz")]
        else:
            sent.append(clock[0])
            payload = DEX_REPLY
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert sent == [H + 5_000] * 3


def test_a_hung_dex_cannot_hold_up_a_healthy_dex_initial_send(tmp_path, monkeypatch):
    healthy = threading.Event()
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    monkeypatch.setattr(market, "now_ms", lambda: H + 5_000)

    def post(url, json):
        if json["type"] == "perpDexs":
            payload = [{"name": "bad"}, {"name": "xyz"}]
        elif json["dex"] == "bad":
            assert healthy.wait(1), "healthy dex waited for the hung dex"
            return httpx.Response(400, request=httpx.Request("POST", url))
        else:
            healthy.set()
            payload = DEX_REPLY
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert market.seal(m.marks("xyz:GOLD")) == {H: 2400.5}


def test_discovery_runs_in_the_drain_minute_and_contexts_at_the_deadline(tmp_path, monkeypatch):
    clock, sent = [H - 55_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        sent.append((json["type"], clock[0]))
        clock[0] += 10_000 if json["type"] == "perpDexs" else 0
        return httpx.Response(200, json=[{"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY,
                              request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert sent == [("perpDexs", H - 55_000), ("metaAndAssetCtxs", H + 5_000)]


def test_failed_discovery_uses_the_last_archived_inventory_after_restart(tmp_path, monkeypatch):
    clock = [H + 5_000]
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        return httpx.Response(200, json=[{"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY,
                              request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    clock[0] += H
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def unavailable(url, json):
        if json["type"] == "perpDexs":
            raise httpx.ReadTimeout("inventory unavailable")
        return post(url, json)

    monkeypatch.setattr(m.sampler.http, "post", unavailable)
    m.record_marks(2 * H + 5_000)
    assert market.seal(m.marks("xyz:GOLD")) == {H: 2400.5, 2 * H: 2400.5}
    assert len(list(market.read(m.sampler.archive, "marks"))) == 4


def test_the_largest_admissible_initial_wave_fits(tmp_path, monkeypatch):
    clock = [H + 5_000]
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    count = market.BUDGET_PER_MIN // 20 - 1

    def post(url, json):
        return httpx.Response(200, json=[{"name": str(d)} for d in range(count)] if json["type"] == "perpDexs" else DEX_REPLY,
                              request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert clock[0] == H + 5_000
    assert len(list(market.read(m.sampler.archive, "marks"))) == count + 1


def test_an_oversized_inventory_alarms_but_still_samples_each_dex_that_fits(tmp_path, monkeypatch, capsys):
    clock, sent = [H + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    count = market.BUDGET_PER_MIN // 20

    def post(url, json):
        if json["type"] == "perpDexs":
            payload = [{"name": str(d)} for d in range(count)]
        else:
            sent.append((json["dex"], clock[0]))
            payload = DEX_REPLY
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert len(sent) == count
    assert sum(t == H + 5_000 for _, t in sent) == count - 1
    assert all(t < H + market.MARK_WINDOW for _, t in sent)
    assert "SAMPLING CAPACITY" in capsys.readouterr().err
    assert m.sampler.limiter.released == H + 5_000


def test_failed_discovery_releases_the_history_reservation(tmp_path, monkeypatch):
    fake_clock(monkeypatch, [H + 5_000])
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    monkeypatch.setattr(m.sampler.http, "post", lambda url, json: httpx.Response(400, request=httpx.Request("POST", url)))
    with pytest.raises(httpx.HTTPStatusError):
        m.record_marks(H + 5_000)
    assert m.sampler.limiter.released == H + 5_000


def test_a_full_cold_hourly_page_fits_the_shared_exchange_budget(tmp_path, monkeypatch):
    clock = [200 * market.DAY + 10 * 60_000]
    fake_clock(monkeypatch, clock)
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path, x)

    def post(url, json):
        start = json["req"]["startTime"]
        page = [{"t": start + i * H, "o": "100", "c": "100"} for i in range(4800)]
        return httpx.Response(200, json=page, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    assert len(m.bars("BTC", "1h", clock[0])) > 4700
    assert sum(w for _, w in x.limiter.spent) == 100


def test_mark_reads_parse_each_archive_record_once_across_markets_and_appends(tmp_path, monkeypatch):
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    for h in (0, H):
        market.append(tmp_path / "marks", "marks", h + 5_000,
                      {"sent": h + 5_000, "recv": h + 6_000, "dex": "xyz", "marks": {"xyz:A": 1, "xyz:B": 2},
                       "response": "large raw payload" * 1000})
    loads, decoded = market.json.loads, []

    def decode(text):
        decoded.append(len(text))
        return loads(text)

    monkeypatch.setattr(market.json, "loads", decode)
    for _ in range(5):
        assert len(m.marks("xyz:A")) == len(m.marks("xyz:B")) == 2
    assert len(decoded) == 2
    market.append(tmp_path / "marks", "marks", 2 * H + 5_000,
                  {"sent": 2 * H + 5_000, "recv": 2 * H + 6_000, "dex": "xyz", "marks": {"xyz:A": 3}})
    assert m.marks("xyz:A")[-1] == (2 * H + 5_000, 2 * H + 6_000, 3)
    assert len(decoded) == 3


def test_incremental_mark_reads_leave_incomplete_appends_for_the_next_read(tmp_path):
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))
    row = {"sent": 5_000, "recv": 6_000, "dex": "xyz", "marks": {"xyz:A": 1}, "response": "é"}
    text = market.json.dumps(row, ensure_ascii=False).encode() + b"\n"
    path = tmp_path / "marks/marks-19700101.jsonl"
    cut = text.index("é".encode()) + 1
    path.write_bytes(text[:cut])
    assert m.marks("xyz:A") == []
    with path.open("ab") as f:
        f.write(text[cut:])
    assert m.marks("xyz:A") == [(5_000, 6_000, 1)]


def test_an_early_scheduler_wakeup_does_not_sample_the_previous_hour(tmp_path, monkeypatch):
    clock, sent = [H - 55_001], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        if json["type"] == "metaAndAssetCtxs":
            sent.append(clock[0])
        return httpx.Response(200, json=[{"name": "xyz"}] if json["type"] == "perpDexs" else DEX_REPLY,
                              request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert sent == [H + 5_000]


def test_retry_admission_includes_the_backoff_before_its_seal_margin(tmp_path, monkeypatch):
    clock, sent = [H + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path, market.Exchange(tmp_path / "x"))

    def post(url, json):
        if json["type"] == "perpDexs":
            return httpx.Response(200, json=[{"name": "xyz"}], request=httpx.Request("POST", url))
        sent.append(clock[0])
        clock[0] = max(clock[0], H + 229_500)
        return httpx.Response(503, request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(H + 5_000)
    assert sent == [H + 5_000]


def test_a_request_reserves_the_most_rows_its_range_can_return(tmp_path):
    day = {"type": "fundingHistory", "coin": "X", "startTime": 0, "endTime": market.DAY - 1}
    assert market.max_items(day) == 24
    assert market.max_items({**day, "endTime": 100 * market.DAY}) == 500 and market.max_items({"type": "fundingHistory", "startTime": 0}) == 500
    candles = {"type": "candleSnapshot", "req": {"coin": "X", "interval": "1h", "startTime": 0, "endTime": 2 * H}}
    assert market.max_items(candles) == 3 and market.max_items({**candles, "req": {**candles["req"], "endTime": 400 * market.DAY}}) == 5000


def test_a_short_range_costs_its_base_weight_and_an_excess_row_is_charged_on_receipt(tmp_path, monkeypatch):
    clock = [10 * market.DAY]
    fake_clock(monkeypatch, clock)
    x = market.Exchange(tmp_path)
    rows = [{"time": i, "fundingRate": "0"} for i in range(30)]
    monkeypatch.setattr(x.http, "post", lambda url, json: httpx.Response(200, json=rows, request=httpx.Request("POST", url)))
    x.funding_page("X", 0, 3 * H)
    assert sum(w for _, w in x.limiter.spent) == 22
