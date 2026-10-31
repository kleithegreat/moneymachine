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
