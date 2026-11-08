"""Source-blind acquisition/crash regressions for Argon's 2026-11-08 T3 review."""

import contextlib
import json
import multiprocessing
import signal
import threading
from pathlib import Path

import httpx
import pytest

from ingest import hl
from ingest.policy import DAY, HOUR
from thesis import market, runner
from thesis.tests.test_market import fake_clock
from thesis.tests.test_runner import MONDAY, FakeMarket, track  # noqa: F401


class OfflineMarket(FakeMarket):
    def hold(self, cancel=None):
        return contextlib.nullcontext()


@pytest.fixture
def subject(track):
    track.market = OfflineMarket(MONDAY + 40 * DAY)
    return track


def write_before_attest(root, connection):
    runner.kernel.build = lambda: Path(root) / "bin" / "mm"
    runner.harness.manifest_hash = lambda binary: "0" * 64
    runner.now_ms = lambda: MONDAY + runner.SNAPSHOT_OFFSET
    t = runner.Track(root)
    t.market = OfflineMarket(MONDAY + 40 * DAY)
    snapshot = t.snapshot

    def written(cutoff):
        result = snapshot(cutoff)
        connection.send("written")
        threading.Event().wait(60)
        return result

    t.snapshot = written
    t.acquire(MONDAY)


@pytest.mark.parametrize("state", ["file_only", "stopped_before_attest", "killed_before_attest"])
def test_unattested_snapshot_file_is_never_reused(subject, monkeypatch, state):
    cutoff = MONDAY + runner.SNAPSHOT_OFFSET
    monkeypatch.setattr(runner, "now_ms", lambda: cutoff)
    snapshot = subject.snapshot
    if state == "file_only":
        snapshot(cutoff)
    elif state == "stopped_before_attest":
        monkeypatch.setattr(subject, "snapshot", lambda t: (snapshot(t), subject.stop.set())[0])
        subject.acquire(MONDAY)
        monkeypatch.setattr(subject, "snapshot", snapshot)
        subject.stop.clear()
    else:
        ctx = multiprocessing.get_context("spawn")
        parent, child = ctx.Pipe(duplex=False)
        process = ctx.Process(target=write_before_attest, args=(subject.root, child))
        process.start()
        try:
            assert parent.poll(20) and parent.recv() == "written"
        finally:
            process.kill()
            process.join(10)
            parent.close()
            child.close()
        assert process.exitcode == -signal.SIGKILL
    assert (subject.root / "snapshots" / f"{cutoff}.json").exists()
    assert subject.ledger.records("snapshot_ready") == []
    subject.market.delisted.add("BTC")
    rebuilt = subject.snapshot(cutoff)
    assert "BTC" not in rebuilt["markets"], "unattested bytes bypassed fresh acquisition"


def test_attested_snapshot_remains_the_shared_immutable_snapshot(subject, monkeypatch):
    cutoff = MONDAY + runner.SNAPSHOT_OFFSET
    monkeypatch.setattr(runner, "now_ms", lambda: cutoff)
    subject.acquire(MONDAY)
    before = subject.snapshot(cutoff)
    subject.market.delisted.add("BTC")
    assert subject.snapshot(cutoff) == before


def test_attested_returns_the_exact_bytes_verified_before_file_mutation(subject, monkeypatch):
    cutoff = MONDAY + runner.SNAPSHOT_OFFSET
    monkeypatch.setattr(runner, "now_ms", lambda: cutoff)
    subject.acquire(MONDAY)
    original = subject.attested(MONDAY, MONDAY + DAY)
    assert original is not None
    path = subject.root / "snapshots" / f"{cutoff}.json"
    read_bytes = Path.read_bytes
    changed = json.loads(read_bytes(path))
    assert changed["markets"]
    changed["markets"] = {}
    replacement = json.dumps(changed).encode()
    mutated = []

    def read_then_mutate(self):
        contents = read_bytes(self)
        if self == path and not mutated:
            self.write_bytes(replacement)
            mutated.append(True)
        return contents

    monkeypatch.setattr(Path, "read_bytes", read_then_mutate)
    result = subject.attested(MONDAY, MONDAY + DAY)
    assert mutated, "the snapshot read must exercise the mutation race"
    assert result is None or result == original, "attested() returned bytes it did not verify"


def test_monday_can_finish_after_0500_and_run_the_benchmark(subject, monkeypatch):
    date = MONDAY
    clock, bars, holds = [date + 5 * HOUR - 1], [], []
    monkeypatch.setattr(runner, "now_ms", lambda: clock[0])

    class Crossing(OfflineMarket):
        @contextlib.contextmanager
        def hold(self, cancel=None):
            holds.append("enter")
            try:
                yield
            finally:
                holds.append("exit")

        def bars(self, name, interval, now=None):
            bars.append((name, interval))
            clock[0] = date + 5 * HOUR
            return super().bars(name, interval, now)

    subject.market = Crossing(MONDAY + 40 * DAY)
    subject.acquire(date)
    assert holds == ["enter", "exit"]
    assert subject.attested(date, date + DAY) is not None
    clock[0] += HOUR
    subject.benchmark(date)
    assert len(subject.ledger.theses("benchmark")) == 4


@pytest.mark.parametrize("crossing, allowed", [("reply", 1), ("limiter_wait", 0)])
def test_deadline_cancels_between_http_pages_and_releases_the_real_limiter(subject, tmp_path, monkeypatch, crossing, allowed):
    date = MONDAY + DAY
    clock, candles = [date + 5 * HOUR - 1], []
    fake_clock(monkeypatch, clock)
    monkeypatch.setattr(runner, "now_ms", lambda: int(clock[0]))
    x = market.Exchange(tmp_path / "x", limiter=hl.WeightLimit(120))
    subject.market = market.Market(tmp_path / "m", x)
    if crossing == "limiter_wait":
        x.limiter.spent = [(clock[0] / 1000, 80)]

    def post(url, json):
        if json["type"] == "meta":
            payload = {"universe": [{"name": "BTC"}, {"name": "X"}]}
        elif json["type"] == "perpDexs":
            payload = [None]
        else:
            candles.append(json)
            req = json["req"]
            payload = [{"t": date - k * DAY, "o": "100", "c": "100"} for k in range(90, 0, -1)
                       if req["startTime"] <= date - k * DAY <= req["endTime"]]
            clock[0] = max(clock[0], date + 5 * HOUR)
        return httpx.Response(200, json=payload, request=httpx.Request("POST", url))

    monkeypatch.setattr(x.http, "post", post)
    subject.acquire(date)
    clock[0] = date + 6 * HOUR
    x.limiter.spent = []
    errors = []

    def background():
        try:
            x._charge(20, background=True)
        except BaseException as exc:
            errors.append(exc)

    released = threading.Thread(target=background, daemon=True)
    released.start()
    released.join(2)
    assert not released.is_alive(), "expired acquisition retained the background hold"
    assert not errors
    assert len(candles) == allowed, "acquisition charged another page after 05:00 UTC"
    assert subject.ledger.records("snapshot_ready") == []
    assert not (subject.root / "snapshots" / f"{date + runner.SNAPSHOT_OFFSET}.json").exists()
