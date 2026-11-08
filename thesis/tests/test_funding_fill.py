"""Refreeze finding 2 (audit/reviews/2026-11-07-gpt-funding-fill-design.md): funding history is filled page by page
outside sessions, from durable coverage, and a session asks the venue only about its own range."""

import json
import subprocess
import sys
import textwrap
import threading
import time

import httpx
import pytest

from ingest import hl
from thesis import market
from thesis.tests.test_market import Venue, fake_clock

H, DAY = market.HOUR, market.DAY
NOW = 2000 * DAY + 10 * 60_000
ROWS = [(NOW - k * H, 0.001) for k in range(1, 1201)]


class Failing(Venue):
    """A venue whose `n`th page request fails."""

    def __init__(self, rows, n, error):
        super().__init__(rows)
        self.n, self.error = n, error

    def funding_page(self, coin, start, end, background=False):
        if len(self.requests) + 1 == self.n:
            raise self.error
        return super().funding_page(coin, start, end, background)


def saved(root):
    return json.loads((root / "X" / "funding-ranges.json").read_text())


def test_every_validated_page_is_committed_before_the_next_is_asked_for(tmp_path):
    x = Failing(ROWS, 3, httpx.ReadTimeout("slow"))
    m = market.Market(tmp_path, x)
    with pytest.raises(httpx.ReadTimeout):
        m.funding("X", NOW, background=True)
    assert len(saved(tmp_path)["rows"]) == 1000 and not m.ready("X", NOW)
    done = saved(tmp_path)["fetched"][0][1]
    x.n = 0
    x.requests.clear()
    assert len(m.funding("X", NOW, background=True)) == 1200
    assert done - H < x.requests[0][0] <= done and len(x.requests) == 2
    assert m.ready("X", NOW)


@pytest.mark.parametrize("error", [httpx.HTTPStatusError("429", request=httpx.Request("POST", "x"), response=httpx.Response(429)),
                                   ValueError("malformed")])
def test_a_failed_page_leaves_the_job_pending_with_its_progress(tmp_path, error):
    x = Failing(ROWS, 2, error)
    m = market.Market(tmp_path, x)
    with pytest.raises(type(error)):
        m.funding("X", NOW, background=True)
    assert len(saved(tmp_path)["rows"]) == 500 and not m.ready("X", NOW)


@pytest.mark.parametrize("bad", [[{"time": NOW + H, "fundingRate": "0.1"}], [{"time": NOW - H, "fundingRate": "nan"}],
                                 [{"time": NOW - 2 * H, "fundingRate": "0.1"}, {"time": NOW - 3 * H, "fundingRate": "0.1"}],
                                 [{"time": NOW - H}], {"rows": 1}, [{"time": NOW - H, "fundingRate": "0.1"}] * 501])
def test_a_malformed_page_commits_nothing(tmp_path, bad):
    class Bad(Venue):
        def funding_page(self, coin, start, end, background=False):
            return bad

    m = market.Market(tmp_path, Bad([]))
    with pytest.raises(ValueError):
        m.funding("X", NOW, background=True)
    assert not (tmp_path / "X").exists()


def test_a_killed_fill_resumes_from_durable_coverage(tmp_path):
    script = textwrap.dedent(f"""
        import os, signal, sys
        from thesis import market
        from thesis.tests.test_market import Venue
        NOW = {NOW}
        rows = [(NOW - k * market.HOUR, 0.001) for k in range(1, 1201)]
        class V(Venue):
            def funding_page(self, coin, start, end, background=False):
                if len(self.requests) == 2:
                    os.kill(os.getpid(), signal.SIGKILL)
                return super().funding_page(coin, start, end, background)
        market.Market(sys.argv[1], V(rows)).funding("X", NOW, background=True)
    """)
    run = subprocess.run([sys.executable, "-c", script, str(tmp_path)], capture_output=True)
    assert run.returncode == -9
    done = saved(tmp_path)["fetched"][0][1]
    assert len(saved(tmp_path)["rows"]) == 1000
    x = Venue(ROWS)
    m = market.Market(tmp_path, x)
    assert len(m.funding("X", NOW, background=True)) == 1200
    assert done - H < x.requests[0][0] <= done


def test_a_session_read_asks_only_about_its_own_range(tmp_path):
    x = Venue(ROWS)
    m = market.Market(tmp_path, x)
    m.funding("X", NOW, background=True)
    x.requests.clear()
    m.funding_repaired.clear()
    rows = m.funding("X", NOW + 2 * H, NOW - 5 * H)
    assert len(rows) == 1200 and all(a >= NOW - 6 * H for a, _ in x.requests), x.requests


def test_a_narrow_read_never_repairs_a_hole_outside_its_range(tmp_path):
    x = Venue([r for r in ROWS if r[0] != NOW - 600 * H])
    m = market.Market(tmp_path, x, repair_every=0)
    m.funding("X", NOW, background=True)
    x.requests.clear()
    m.funding("X", NOW, NOW - 100 * H)
    assert all(a > NOW - 101 * H for a, _ in x.requests)


def test_widening_a_read_discovers_the_uncovered_prefix_and_keeps_every_row(tmp_path):
    x = Venue(ROWS)
    m = market.Market(tmp_path, x)
    recent = m.funding("X", NOW, NOW - 50 * H)
    assert m.ready("X", NOW) is False
    x.requests.clear()
    x.rows = [(t, 9.0) for t, _ in ROWS]
    full = m.funding("X", NOW)
    assert x.requests and x.requests[0][0] == (NOW - market.HISTORY["funding"]) // H * H
    assert all(r in full for r in recent)
    assert len(full) == 1200 and m.ready("X", NOW)


def test_a_session_read_does_not_wait_for_a_background_fill_of_the_same_market(tmp_path):
    inside, release = threading.Event(), threading.Event()

    class Slow(Venue):
        def funding_page(self, coin, start, end, background=False):
            if background:
                inside.set()
                release.wait(10)
            return super().funding_page(coin, start, end, background)

    m = market.Market(tmp_path, Slow(ROWS))
    filler = threading.Thread(target=lambda: m.funding("X", NOW, background=True))
    filler.start()
    assert inside.wait(5)
    start = time.monotonic()
    assert len(m.funding("X", NOW, NOW - 5 * H)) == 5
    assert time.monotonic() - start < 2
    release.set()
    filler.join()
    assert m.ready("X", NOW)


def test_stopping_ends_a_fill_between_pages_with_its_progress(tmp_path):
    stop = threading.Event()

    class Stopping(Venue):
        def funding_page(self, coin, start, end, background=False):
            stop.set()
            return super().funding_page(coin, start, end, background)

    m = market.Market(tmp_path, Stopping(ROWS))
    m.prewarm("X", NOW, stop)
    assert len(saved(tmp_path)["rows"]) == 500 and not m.ready("X", NOW)


def test_readiness_is_the_ranges_fetched_not_the_end_of_pagination(tmp_path):
    x = Venue(ROWS[:100])
    m = market.Market(tmp_path, x)
    assert not m.ready("X", NOW)
    m.prewarm("X", NOW, threading.Event())
    assert m.ready("X", NOW) and len(saved(tmp_path)["rows"]) == 100
    x.requests.clear()
    m.prewarm("X", NOW + H, threading.Event())
    assert x.requests == []
    m.prewarm("X", NOW + DAY, threading.Event())
    assert len(x.requests) == 1


def test_background_fill_refreshes_a_warm_market_once_a_day_and_retries_omissions_daily(tmp_path, monkeypatch):
    clock = [NOW]
    fake_clock(monkeypatch, clock)
    x = Venue([r for r in ROWS if r[0] != NOW - 600 * H])
    m = market.Market(tmp_path, x, repair_every=0)
    m.prewarm("X", NOW, threading.Event())
    assert len(saved(tmp_path)["rows"]) == 1199
    x.rows, clock[0] = ROWS, NOW + DAY
    m.prewarm("X", NOW + DAY, threading.Event())
    assert len(saved(tmp_path)["rows"]) == 1200 + 24 * 0


def fast_limiter(monkeypatch):
    monkeypatch.setattr(hl.time, "sleep", lambda s: time.sleep(min(s, 0.01)))


def test_a_background_charge_yields_to_a_waiting_foreground_charge_and_to_a_hold(monkeypatch):
    limiter = hl.WeightLimit(100)
    limiter.charge(100)
    order = []
    fg = threading.Thread(target=lambda: (limiter.charge(60), order.append("fg")))
    bg = threading.Thread(target=lambda: (limiter.charge(10, background=True), order.append("bg")))
    now = time.monotonic()
    limiter.spent = [(now - 59.5, 100)]
    fg.start()
    while not limiter.foreground:
        time.sleep(0.001)
    bg.start()
    fg.join(5)
    bg.join(5)
    assert order == ["fg", "bg"]
    with limiter.hold():
        limiter.spent = []
        t = threading.Thread(target=lambda: limiter.charge(10, background=True))
        t.start()
        t.join(0.6)
        assert t.is_alive()
    t.join(5)
    assert not t.is_alive()


def test_four_warm_markets_register_inside_a_session_at_the_certified_remainder(tmp_path, monkeypatch):
    from thesis.daemon import MAX_REGISTRATIONS
    from thesis.harness import WALL_SECONDS

    clock = [NOW]
    fake_clock(monkeypatch, clock)
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path, x)
    markets = [f"M{i}" for i in range(MAX_REGISTRATIONS * 2)]

    def post(url, json):
        rows = [{"time": t, "fundingRate": "0.001"} for t, _ in sorted(ROWS) if json["startTime"] <= t <= json["endTime"]][:500]
        return httpx.Response(200, json=rows, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    for name in markets:
        m.prewarm(name, NOW - 2 * DAY, threading.Event())
    start, requests = clock[0], len(list((tmp_path / "x").glob("info-*.jsonl")))
    clock[0] = NOW
    for name in markets:
        m.funding(name, NOW, NOW - 3 * H)
    assert clock[0] - start < WALL_SECONDS * 1000
    assert sum(w for _, w in x.limiter.spent) <= len(markets) * 45
    assert len(markets) * 45 <= market.BUDGET_PER_MIN * 3
