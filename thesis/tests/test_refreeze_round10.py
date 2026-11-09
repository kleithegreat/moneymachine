"""Round ten: N1-N5 of the round-nine review (audit/reviews/2026-11-09-opus-thesis-refreeze-round9.md)."""
import json

import httpx

from ingest.policy import DAY, HOUR
from thesis import harness, runner
from thesis.daemon import SPEC
from thesis.tests.test_refreeze_round9 import record, transcript
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401

USAGE = SPEC["usage"]
REFUSAL = '{"ok": false, "error": "[Errno 2] No such file or directory: \'missing.json\'"}'
NINE = MONDAY + runner.SNAPSHOT_OFFSET + 60_000


def audited(tmp_path, calls, records):
    return harness.audit(transcript(tmp_path, calls), records)


def test_n2_an_unreadable_file_as_claude_code_records_it_is_refused_locally(tmp_path):
    a = audited(tmp_path, [("./thesis-agent register missing.json", "Exit code 1\n" + REFUSAL),
                           ("./thesis-agent markets", "{}")], [record("markets")])
    assert a["match"] is True and a["refused_locally"] == 1


def test_n2_a_wrong_arity_with_a_plus_command_is_decided_by_the_result(tmp_path):
    a = audited(tmp_path, [("./thesis-agent prices", "Exit code 2\n" + USAGE)], [])
    assert a["match"] is True and a["refused_locally"] == 1


def test_n3_a_refusal_beside_another_call_in_one_command_attributes_nothing(tmp_path):
    command = "./thesis-agent register missing.json; ./thesis-agent register a.json"
    a = audited(tmp_path, [(command, "Exit code 1\n" + REFUSAL)], [record("register", "a.json")])
    assert a["refused_locally"] == 0 and a["client_calls"] == 2 and a["match"] is False


def test_n3_the_unattributable_extra_call_is_not_absorbed_by_a_neighbours_record(tmp_path):
    command = "./thesis-agent register missing.json; ./thesis-agent register a.json; ./thesis-agent register b.json"
    a = audited(tmp_path, [(command, "Exit code 1\n" + REFUSAL)], [record("register", "a.json")])
    assert a["match"] is False


def test_n3_a_shell_expansion_that_changes_the_arity_is_not_refused_by_its_tokens(tmp_path):
    a = audited(tmp_path, [("./thesis-agent exit $(cat args.txt)", '{"ok":true}')], [record("exit", "a", "b")])
    assert a["refused_locally"] == 0 and a["match"] is True


def test_n3_only_the_clients_own_refusal_counts_as_one(tmp_path):
    for output in ("Exit code 1\n" + REFUSAL + "\nextra", "Exit code 1\n" + json.dumps({"ok": False, "error": "x", "more": 1}),
                   REFUSAL, "Exit code 0\n" + REFUSAL, "Exit code 1\nusage: other", "Exit code 1\n" + json.dumps({"ok": True, "error": "x"})):
        assert audited(tmp_path, [("./thesis-agent register f.json", output)], [])["refused_locally"] == 0, output


def blip(market_name, interval, times):
    class Blip(FakeMarket):
        failures = times

        def bars(self, market, i, now=None):
            if market == market_name and i == interval and Blip.failures:
                Blip.failures -= 1
                raise httpx.HTTPStatusError("502 once", request=httpx.Request("POST", "https://x"), response=httpx.Response(502))
            return FakeMarket.bars(self, market, i, now)

    return Blip


def at(monkeypatch, t):
    monkeypatch.setattr(runner, "now_ms", lambda: t)


def test_n1_a_transient_failure_is_retried_and_the_snapshot_waits(track, monkeypatch):
    track.market = blip("BTC", "1h", 1)(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is None
    at(monkeypatch, NINE + 60_000)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert snap is not None and snap["failed"] == {} and "BTC" in snap["benchmark_markets"] and snap["ready"]["BTC"] is True
    track.benchmark(MONDAY)
    assert {th["legs"][0][0] for th in track.ledger.theses("benchmark")} >= {"BTC", "ETH"}


def test_n1_only_the_failed_market_is_read_again(track, monkeypatch):
    market = blip("BTC", "1h", 2)(MONDAY + 40 * DAY)
    track.market = market
    reads = []
    bars = market.bars
    market.bars = lambda m, i, now=None: reads.append(m) or bars(m, i, now)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    reads.clear()
    track.acquire(MONDAY)
    assert set(reads) == {"BTC"}
    assert market.calls.count(("listings",)) <= 1


def test_n1_a_failure_still_present_at_the_give_up_time_is_recorded_with_its_reason(track, monkeypatch):
    track.market = blip("BTC", "1h", 10**6)(MONDAY + 40 * DAY)
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL - 1)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is None
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert "502" in snap["failed"]["BTC"] and snap["ready"]["BTC"] is False
    ready = [c for _, _, c in track.ledger.records("snapshot_ready", "main")]
    assert len(ready) == 1 and ready[0]["failed"] == snap["failed"]


def test_n1_the_give_up_is_0445_utc_and_leaves_a_retry_in_flight_time_before_the_sessions():
    assert runner.RETRY_UNTIL == 4 * HOUR + 45 * 60_000 and runner.RETRY_UNTIL + 15 * 60_000 == runner.SESSION_OFFSET


def test_n1_a_readiness_failure_is_retried_alone(track, monkeypatch):
    ready = track.market.ready
    errors = [1]

    def flaky(m, now):
        if m == "ETH" and errors:
            errors.pop()
            raise httpx.ReadTimeout("slow")
        return ready(m, now)

    track.market.ready = flaky
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is None
    at(monkeypatch, NINE + 60_000)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY)["ready"]["ETH"] is True


def dexed(failures):
    class Dexed(FakeMarket):
        broken = failures

        def universe(self, dex=None, *, background=False):
            if dex and Dexed.broken:
                raise httpx.ReadTimeout("meta of the dex")
            return super().universe(dex, background=background)

        def dexes(self, *, background=False):
            return ["xyz"]

    return Dexed


def test_n5_a_dex_whose_listing_read_fails_is_retried_and_then_recorded(track, monkeypatch):
    track.market = dexed(True)(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY) is None
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    snap = track.attested(MONDAY, MONDAY + DAY)
    assert "meta of the dex" in snap["failed"]["xyz:*"]
    assert "market read failed at the snapshot" in runner.unbenchmarkable(snap, "xyz:GOLD", [])


def test_n5_a_dex_that_heals_costs_nothing(track, monkeypatch):
    track.market = dexed(True)(MONDAY + 40 * DAY)
    at(monkeypatch, NINE)
    track.acquire(MONDAY)
    type(track.market).broken = False
    at(monkeypatch, NINE + 60_000)
    track.acquire(MONDAY)
    assert track.attested(MONDAY, MONDAY + DAY)["failed"] == {}


def test_n5_the_core_venues_listing_failure_leaves_no_snapshot(track, monkeypatch):
    class Core(FakeMarket):
        def universe(self, dex=None, *, background=False):
            raise httpx.ReadTimeout("core meta")

    track.market = Core(MONDAY + 40 * DAY)
    for t in (NINE, MONDAY + runner.RETRY_UNTIL + 60_000):
        at(monkeypatch, t)
        try:
            track.acquire(MONDAY)
        except httpx.ReadTimeout:
            pass
    assert track.attested(MONDAY, MONDAY + DAY) is None


def test_n4_the_report_lists_the_failures(track, monkeypatch):
    from thesis import report
    track.market = blip("BTC", "1h", 10**6)(MONDAY + 40 * DAY)
    at(monkeypatch, MONDAY + runner.RETRY_UNTIL)
    track.acquire(MONDAY)
    report.write(track, MONDAY + DAY, track.root / "r.json")
    out = json.loads((track.root / "r.json").read_text())
    assert "502" in out["snapshots"][0]["failed"]["BTC"]
