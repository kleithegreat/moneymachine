"""A recorder holds its directory alone and stops between polls on SIGTERM."""

import os
import signal
import threading

import pytest

from ingest import availability, live, record


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
    for _ in range(len(expected) + 1):
        before = len(attempts)
        rec.step()
        assert len(attempts) == before + 1
    assert attempts == expected[:failed] + [expected[failed]] + expected[failed:]
    rec.step()
    assert len(attempts) == len(expected) + 1


def test_four_hour_boundary_verifies_each_request_once(recorder_clock):
    rec, clock = recorder_clock
    calls = []
    rec.poll = lambda *request: calls.append(request) or True
    clock[0] = record.BAR + record.VERIFY_AFTER
    for _ in range(22):
        rec.step()
    calls.clear()
    clock[0] = 2 * record.BAR + record.FIRST_AFTER
    rec.step()
    assert len(calls) == 22 and all(call[-1] == "first" for call in calls)
    calls.clear()
    clock[0] = 2 * record.BAR + record.VERIFY_AFTER
    for _ in range(22):
        before = len(calls)
        rec.step()
        assert len(calls) == before + 1
    expected = [(kind, coin, 2 * record.BAR, "verify") for kind in ("funding", "bar") for coin in rec.coins]
    assert calls == expected
    rec.step()
    assert calls == expected


def test_verification_drops_a_persistent_failure_after_three_attempts(recorder_clock):
    rec, clock = recorder_clock
    clock[0] = record.BAR + record.VERIFY_AFTER
    calls, errors = [], []
    rec.log = errors.append

    def poll(*request):
        calls.append(request)
        if request[1] == "coin0":
            raise TypeError("invalid response")
        return True

    rec.poll = poll
    for _ in range(3):
        rec.step()
    assert len(calls) == 3 and len(errors) == 1
    error = errors[0]
    assert error["kind"] == "funding" and error["coin"] == "coin0" and error["boundary"] == record.BAR
    assert error["purpose"] == "dropped" and error["dropped"] and error["attempts"] == 3
    assert error["data"] == [] and not error["found"]
    assert "invalid response" in error["error"] and error["sent"] <= error["recv"]
    rec.step()
    assert calls[-1][1] == "coin1"
    for _ in range(30):
        rec.step()
    assert not rec.verify and len(errors) == 2


def test_merge_uses_the_other_hosts_reference_after_a_dropped_verification(recorder_clock):
    rec, clock = recorder_clock
    boundary = record.BAR
    rec.verify = rec.verify[:1]
    first = {"kind": "funding", "coin": "coin0", "boundary": boundary, "purpose": "first",
             "sent": boundary + 5_000, "recv": boundary + 5_000,
             "data": [{"time": boundary, "fundingRate": "0.001", "premium": "0"}], "found": True}
    rec.log(first)

    def fail(*request):
        raise RuntimeError("verification unavailable")

    rec.poll = fail
    clock[0] = boundary + record.VERIFY_AFTER
    for _ in range(3):
        rec.step()
    other = rec.out / "oci"
    other.mkdir()
    reference = [{"time": boundary, "fundingRate": "0.002", "premium": "0"}]
    for purpose, t in (("first", boundary + 9_000), ("verify", clock[0])):
        live.append(other, "polls", t, first | {"purpose": purpose, "sent": t, "recv": t, "data": reference})
    for directory in (rec.out, other):
        for t in (boundary, clock[0]):
            live.append(directory, "sources", t, {"source": "clock", "recv": t, "data": {"offset_ms": 1.5}})

    polls = availability.merge([("local", rec.out, rec.out), ("oci", other, other)])
    assert {p["host"] for p in polls} == {"oci"}
    assert all(p["data"] == reference for p in polls)
    result = availability.analyze(polls)
    assert result["events"] == {"funding:coin0": 1} and result["failures"] == []


def test_first_polls_precede_one_backlogged_verification(recorder_clock):
    rec, clock = recorder_clock
    calls = []
    rec.poll = lambda *request: calls.append(request) or True
    clock[0] = 2 * record.BAR + record.FIRST_AFTER
    rec.step()
    assert len(calls) == 23
    assert all(call[-1] == "first" for call in calls[:22])
    assert calls[-1][-1] == "verify" and calls[-1][2] == record.BAR
    rec.step()
    assert len(calls) == 24 and calls[-1][-1] == "verify"
