"""A recorder holds its directory alone and stops between polls on SIGTERM."""

import os
import signal
import threading

import pytest

from ingest import live, record


def test_forever_stops_between_steps():
    stop, steps = threading.Event(), []
    record.forever(lambda: (steps.append(1), stop.set()), stop)
    assert steps == [1]


def test_recording_holds_the_writer_lock_and_stops_on_sigterm(tmp_path):
    before = signal.getsignal(signal.SIGTERM)
    try:
        stop = live.recording(tmp_path)
        assert not stop.is_set()
        os.kill(os.getpid(), signal.SIGTERM)
        assert stop.wait(5)
        with pytest.raises(SystemExit):
            live.recording(tmp_path)
    finally:
        signal.signal(signal.SIGTERM, before)


@pytest.fixture
def recorder_clock(tmp_path, monkeypatch):
    clock = [record.BAR + record.FIRST_AFTER]
    monkeypatch.setattr(record, "now_ms", lambda: clock[0])
    monkeypatch.setattr(record, "Info", lambda budget: None)
    coins = [f"coin{i}" for i in range(11)]
    return record.Recorder(480, coins, tmp_path), clock


@pytest.mark.parametrize("failed", [0, 3, 21])
def test_verification_retries_failed_request_without_losing_the_batch(recorder_clock, failed):
    rec, clock = recorder_clock
    expected = [(kind, coin, record.BAR, "verify") for kind in ("funding", "bar") for coin in rec.coins]
    attempts = []

    def poll(*request):
        attempts.append(request)
        if len(attempts) == failed + 1:
            raise RuntimeError("request exhausted its retries")
        return True

    rec.poll = poll
    clock[0] = record.BAR + record.VERIFY_AFTER
    with pytest.raises(RuntimeError, match="exhausted"):
        rec.step()
    rec.step()
    assert attempts == expected[:failed] + [expected[failed]] + expected[failed:]
    rec.step()
    assert len(attempts) == len(expected) + 1


def test_four_hour_boundary_verifies_each_request_once(recorder_clock):
    rec, clock = recorder_clock
    calls = []
    rec.poll = lambda *request: calls.append(request) or True
    clock[0] = 2 * record.BAR - 1
    rec.step()
    calls.clear()
    clock[0] = 2 * record.BAR + record.FIRST_AFTER
    rec.step()
    assert len(calls) == 22 and all(call[-1] == "first" for call in calls)
    calls.clear()
    clock[0] = 2 * record.BAR + record.VERIFY_AFTER
    rec.step()
    expected = [(kind, coin, 2 * record.BAR, "verify") for kind in ("funding", "bar") for coin in rec.coins]
    assert calls == expected
    rec.step()
    assert calls == expected
