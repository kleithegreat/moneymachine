"""Source-blind mark cohort/retry regressions for Argon's 2026-11-08 T3 review."""

import httpx
import pytest

from ingest.policy import HOUR
from thesis import market
from thesis.tests.test_market import fake_clock


def ten_dexes(tmp_path, monkeypatch, metered):
    clock, calls = [HOUR + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path / "m", market.Exchange(tmp_path / "x"))
    if not metered:
        monkeypatch.setattr(m.sampler, "_charge", lambda *a, **kw: None)

    def post(url, json):
        dex = json.get("dex")
        if dex is None:
            payload = [{"name": f"d{i}"} for i in range(10)]
        else:
            calls.append((dex, clock[0]))
            payload = [{"universe": [{"name": f"{dex}:COIN"}]}, [{"markPx": "100"}]]
        return httpx.Response(503 if dex == "d9" else 200, json=payload,
                              request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(HOUR + 5_000)
    return m, calls


def test_initial_cohort_pagination_has_no_error_backoff(tmp_path, monkeypatch):
    _, calls = ten_dexes(tmp_path, monkeypatch, metered=False)
    first = {d: next(t for dex, t in calls if dex == d) for d in {d for d, _ in calls}}
    assert len(first) == 10 and set(first.values()) == {HOUR + 5_000}, first


@pytest.mark.parametrize("metered", [False, True])
def test_second_cohort_failure_keeps_all_six_attempts(tmp_path, monkeypatch, metered):
    m, calls = ten_dexes(tmp_path, monkeypatch, metered)
    failed = [t for d, t in calls if d == "d9"]
    assert len(failed) == 6, failed
    assert max(failed) < HOUR + 290_000
    assert all(market.seal(m.marks(f"d{i}:COIN")) == {HOUR: 100.} for i in range(9))


@pytest.mark.parametrize("retry_at, allowed", [(250_000, True), (289_999, True), (290_000, False)])
def test_retry_cutoff_reserves_only_one_ten_second_timeout(tmp_path, monkeypatch, retry_at, allowed):
    clock, sent = [HOUR + 5_000], []
    fake_clock(monkeypatch, clock)
    m = market.Market(tmp_path / "m", market.Exchange(tmp_path / "x"))

    def post(url, json):
        if json["type"] == "perpDexs":
            payload, status = [{"name": "d"}], 200
        else:
            sent.append(clock[0])
            payload = [{"universe": [{"name": "d:X"}]}, [{"markPx": "100"}]]
            status = 503 if len(sent) == 1 else 200
            if len(sent) == 1:
                clock[0] = HOUR + retry_at - 1_000
        return httpx.Response(status, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(m.sampler.http, "post", post)
    m.record_marks(HOUR + 5_000)
    assert sent == [HOUR + 5_000] + ([HOUR + retry_at] if allowed else [])
    assert market.seal(m.marks("d:X")) == ({HOUR: 100.} if allowed else {})


@pytest.mark.parametrize("sent, received", [(5_000, 299_999), (5_000, 300_000), (299_999, 299_999), (300_000, 300_000)])
def test_mark_send_and_receipt_must_both_precede_the_seal(sent, received):
    expected = {HOUR: 100.} if sent < 300_000 and received < 300_000 else {}
    assert market.seal([(HOUR + sent, HOUR + received, 100.)]) == expected
