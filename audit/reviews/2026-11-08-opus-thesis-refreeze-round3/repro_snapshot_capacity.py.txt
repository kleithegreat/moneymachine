"""Reproduction (Opus round-three review): the daily snapshot over warm caches cannot finish near 00:10 at the
thesis allowance, because every candle increment reserves the 5,000-candle page ceiling (103 of 120 per minute).

Run: cd <worktree> && nix develop -c pytest -q /tmp/rf3/repro/test_snapshot_capacity.py -p no:cacheprovider
Inventory sizes are estimates (docs/research/2026-11-07-argon-hip3-growth.md on main: 166 live builder assets;
about 186 live core perps), unverified; the failure holds far below them (see the small case)."""

import json
import types

import httpx
import pytest

from ingest import hl
from thesis import market, runner

H, DAY = 3_600_000, 86_400_000


def fake_clock(monkeypatch, clock):
    monkeypatch.setattr(hl, "time", type("Clock", (), {"monotonic": staticmethod(lambda: clock[0] / 1000),
                                                     "sleep": staticmethod(lambda s: clock.__setitem__(0, clock[0] + s * 1000))}))
    monkeypatch.setattr(market, "time", hl.time)
    monkeypatch.setattr(market, "now_ms", lambda: int(clock[0]))


def warm(root, m, now):
    """Caches complete up to the previous increment, as a running track holds them each midnight."""
    d = root / m.replace(":", "_")
    d.mkdir(parents=True)
    day0 = (now - market.HISTORY["1d"]) // DAY * DAY + DAY
    (d / "1d.json").write_text(json.dumps([[t, 100.0, 100.0] for t in range(day0, now // DAY * DAY - DAY, DAY)]))
    h0 = (now - market.HISTORY["1h"]) // H * H + H
    (d / "1h.json").write_text(json.dumps([[t, 100.0, 100.0] for t in range(h0, now // H * H - 2 * H, H)]))


def snapshot_minutes(tmp_path, monkeypatch, n_core, n_builder):
    now = 20_000 * DAY + 10 * 60_000  # a midnight + 00:10
    clock = [now]
    fake_clock(monkeypatch, clock)
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    core = [f"C{i}" for i in range(n_core)]
    builder = [f"xyz:B{i}" for i in range(n_builder)]
    for name in core + builder:
        warm(tmp_path / "m", name, now)

    def post(url, json):
        t = json["type"]
        if t == "meta":
            names = builder if json.get("dex") else core
            out = {"universe": [{"name": n} for n in names]}
        elif t == "perpDexs":
            out = [None, {"name": "xyz"}]
        else:
            r = json["req"]
            step = hl.INTERVAL_MS[r["interval"]]
            first = -(-r["startTime"] // step) * step
            out = [{"t": s, "o": "100", "c": "100"} for s in range(first, min(r["endTime"] + 1, clock[0]), step)]
        return httpx.Response(200, json=out, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    track = types.SimpleNamespace(root=tmp_path, market=m)
    snap = runner.Track.snapshot(track, now)
    assert len(snap["daily"]) == n_core  # builder markets need marks to enter; their daily read happens regardless
    return (clock[0] - now) / 60_000


@pytest.mark.parametrize("n_core, n_builder", [(186, 166), (30, 10)])
def test_the_daily_snapshot_fits_before_the_session_wall(tmp_path, monkeypatch, n_core, n_builder):
    minutes = snapshot_minutes(tmp_path, monkeypatch, n_core, n_builder)
    print(f"snapshot of {n_core} core + {n_builder} builder warm markets: {minutes:.0f} min")
    assert minutes <= 60


@pytest.mark.parametrize("n_core, n_builder", [(186, 166), (30, 10)])
def test_reference_without_page_reservations(tmp_path, monkeypatch, n_core, n_builder):
    """The same run charging base weight only (the deployed main client's charge for these short increments)."""
    monkeypatch.setattr(market, "MAX_ITEMS", {"fundingHistory": 0, "candleSnapshot": 0})
    minutes = snapshot_minutes(tmp_path, monkeypatch, n_core, n_builder)
    print(f"base-weight reference, {n_core} core + {n_builder} builder: {minutes:.0f} min")


def warm_funding(root, m, now):
    d = root / m.replace(":", "_")
    h0 = (now - market.HISTORY["funding"]) // H * H + H
    (d / "funding.json").write_text(json.dumps([[t, 0.0001] for t in range(h0, now // H * H, H)]))


@pytest.mark.parametrize("held", [10, 40])
def test_a_registration_read_of_the_accounts_markets_fits_the_session(tmp_path, monkeypatch, held):
    """`Track.inputs` reads every market the account has ever held (runner.py:93): an hour after the caches were last
    touched, each costs one candle and one funding increment, so registration time grows with the account's history."""
    now = 20_000 * DAY + 10 * 60_000
    clock = [now]
    fake_clock(monkeypatch, clock)
    x = market.Exchange(tmp_path / "x")
    m = market.Market(tmp_path / "m", x)
    names = [f"C{i}" for i in range(held)]
    for name in names:
        warm(tmp_path / "m", name, now)
        warm_funding(tmp_path / "m", name, now)

    def post(url, json):
        if json["type"] == "fundingHistory":
            first = -(-json["startTime"] // H) * H
            out = [{"time": t, "fundingRate": "0.0001"} for t in range(first, min(json.get("endTime", clock[0]) + 1, clock[0]), H)]
        else:
            r = json["req"]
            step = hl.INTERVAL_MS[r["interval"]]
            first = -(-r["startTime"] // step) * step
            out = [{"t": s, "o": "100", "c": "100"} for s in range(first, min(r["endTime"] + 1, clock[0]), step)]
        return httpx.Response(200, json=out, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    track = types.SimpleNamespace(market=m, read=lambda mk, t: runner.Track.read(track, mk, t))
    runner.Track.data(track, names, now)
    minutes = (clock[0] - now) / 60_000
    print(f"registration read of {held} held markets: {minutes:.0f} min")
    assert minutes <= 10
