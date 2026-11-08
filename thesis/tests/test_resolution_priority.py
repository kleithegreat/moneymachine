"""Source-blind regressions for Argon's 2026-11-08 T3 review, HEAD 2229563."""

import contextlib
import threading

import pytest

from ingest import hl
from ingest.policy import DAY, HOUR
from thesis import runner
from thesis.tests.test_runner import MONDAY, FakeMarket, registration, track  # noqa: F401

MIN = 60_000


class OfflineMarket(FakeMarket):
    def hold(self, cancel=None):
        return contextlib.nullcontext()


@pytest.fixture
def subject(track):
    track.market = OfflineMarket(MONDAY + 40 * DAY)
    return track


def due_thesis(subject, monkeypatch):
    monkeypatch.setattr(runner, "now_ms", lambda: MONDAY + MIN)
    assert registration(subject, subject.snapshot(MONDAY))["ok"]
    horizon = MONDAY + 10 * DAY
    bars = subject.market.bars

    def published_open(name, interval, now=None):
        rows = bars(name, interval, now)
        if interval == "1h" and now >= horizon + 5 * MIN:
            rows.append([horizon, 100., None])
        return rows

    subject.market.bars = published_open
    return horizon


def test_the_due_thesis_is_resolvable_at_0005_without_competition(subject, monkeypatch):
    horizon = due_thesis(subject, monkeypatch)
    monkeypatch.setattr(runner, "now_ms", lambda: horizon + 5 * MIN)
    subject.resolve(horizon + 5 * MIN)
    assert [c["status"] for _, _, c in subject.ledger.records("resolution")] == ["resolved"]


class ScheduledClock:
    """Run one parked limiter caller at a time; ties deliberately favor snapshot."""

    def __init__(self):
        self.now = 0.
        self.cv = threading.Condition()
        self.waiting = {}
        self.done = set()
        self.closed = False

    def sleep(self, seconds):
        who = threading.current_thread()
        gate = threading.Event()
        with self.cv:
            self.waiting[who] = (self.now + seconds, gate)
            self.cv.notify_all()
        assert gate.wait(10), "limiter scheduler stalled"
        if self.closed:
            raise RuntimeError("scheduler closed")

    def finish(self, group):
        with self.cv:
            self.done.add(group)
            self.cv.notify_all()

    def parked(self, group):
        return any((t.name == "snapshot") == (group == "snapshot") for t in self.waiting)

    def wait_for(self, predicate):
        with self.cv:
            assert self.cv.wait_for(predicate, 10), "caller neither parked nor finished"

    def step(self):
        with self.cv:
            who = min(self.waiting, key=lambda t: (self.waiting[t][0], t.name != "snapshot"))
            due, gate = self.waiting.pop(who)
            self.now = max(self.now, due)
            group = "snapshot" if who.name == "snapshot" else "resolve"
            gate.set()
            assert self.cv.wait_for(lambda: who in self.waiting or group in self.done, 10)

    def close(self):
        self.closed = True
        for _, gate in self.waiting.values():
            gate.set()


@pytest.mark.parametrize("weight, slots", [(20, 6), (21, 5)])
def test_fifo_snapshot_cannot_starve_the_0005_resolution(subject, monkeypatch, weight, slots):
    horizon = due_thesis(subject, monkeypatch)
    clock = ScheduledClock()
    monkeypatch.setattr(hl, "time", type("Clock", (), {
        "monotonic": staticmethod(lambda: clock.now), "sleep": staticmethod(clock.sleep)}))
    now = lambda: horizon + 5 * MIN + int(clock.now * 1000)
    monkeypatch.setattr(runner, "now_ms", now)
    limiter = hl.WeightLimit(120)
    limiter.spent = [((i + 1) * 60 / slots - 60, weight) for i in range(slots)]
    funding, paid, sent, errors = subject.market.funding, [], [], []

    def read(name, at=None, start=None):
        limiter.charge(22)
        paid.append(now())
        return funding(name, at, start)

    subject.market.funding = read

    def run(group, work):
        try:
            work()
        except BaseException as exc:
            errors.append(exc)
        finally:
            clock.finish(group)

    def snapshot():
        while clock.now < 2 * HOUR / 1000 and "resolve" not in clock.done:
            limiter.charge(weight)
            sent.append(now())

    resolving = threading.Thread(target=run, args=("resolve", lambda: subject.resolve(now())))
    acquiring = threading.Thread(name="snapshot", target=run, args=("snapshot", snapshot))
    resolving.start()
    try:
        clock.wait_for(lambda: clock.parked("resolve") or "resolve" in clock.done)
        acquiring.start()
        clock.wait_for(lambda: clock.parked("snapshot") or "snapshot" in clock.done)
        while "resolve" not in clock.done or "snapshot" not in clock.done:
            clock.step()
            subject.deadlines(now())
    finally:
        clock.close()
        resolving.join(10)
        if acquiring.ident is not None:
            acquiring.join(10)
    assert not errors
    records = [c for _, _, c in subject.ledger.records("resolution")]
    assert [r["status"] for r in records] == ["resolved"], records
    assert paid and paid[0] < horizon + runner.RESOLUTION_GRACE
    assert paid[0] < horizon + 5 * MIN + 2 * HOUR
    assert not sent or paid[0] <= min(sent), "a newer foreground request overtook resolution"
