"""A recorder holds its directory alone and stops between polls on SIGTERM."""

import json
import os
import signal
import subprocess
import sys
import threading
import time

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


# GPT's bug hunt (audit/reviews/2026-11-02-gpt-hunt-recorders.md), finding 1. The child's writes fail past a size limit,
# as they do on a full disk, leaving the record torn.
FILE_LIMIT = """
import resource, signal, sys
from ingest import live
signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
resource.setrlimit(resource.RLIMIT_FSIZE, (64, 64))
try:
    live.append(sys.argv[1], "x", 0, {"pad": "y" * 1000})
except OSError:
    sys.exit(3)
"""


def torn(tmp_path):
    live.append(tmp_path, "x", 0, {"n": 1})
    assert subprocess.run([sys.executable, "-c", FILE_LIMIT, str(tmp_path)]).returncode == 3
    assert not (tmp_path / "x-19700101.jsonl").read_bytes().endswith(b"\n")


def test_an_append_after_a_torn_record_starts_on_its_own_line(tmp_path, capsys):
    torn(tmp_path)
    live.append(tmp_path, "x", 0, {"n": 2})
    assert list(live.read(tmp_path, "x")) == [{"n": 1}, {"n": 2}]
    assert "x-19700101.jsonl:2" in capsys.readouterr().err


def test_a_torn_tail_does_not_stop_a_read(tmp_path):
    torn(tmp_path)
    assert list(live.read(tmp_path, "x")) == [{"n": 1}]


def test_a_complete_record_that_lost_only_its_newline_is_kept(tmp_path):
    (tmp_path / "x-19700101.jsonl").write_text('{"n":1}')
    live.append(tmp_path, "x", 0, {"n": 2})
    assert list(live.read(tmp_path, "x")) == [{"n": 1}, {"n": 2}]


APPENDS = """
import sys
from ingest import live
while True:
    live.append(sys.argv[1], "x", 0, {"pad": "y" * 50_000_000})
"""


def test_a_writer_killed_mid_append_leaves_a_directory_the_next_writer_and_reader_can_use(tmp_path):
    child = subprocess.Popen([sys.executable, "-c", APPENDS, str(tmp_path)])
    f = tmp_path / "x-19700101.jsonl"
    while not f.exists() or f.stat().st_size == 0:
        time.sleep(0.001)
    child.send_signal(signal.SIGKILL)
    child.wait()
    live.append(tmp_path, "x", 0, {"n": "after"})
    assert list(live.read(tmp_path, "x"))[-1] == {"n": "after"}
