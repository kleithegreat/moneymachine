"""Live recordings: the clock the recorders stamp with, the writer and reader of their day JSONL files, and each
recorder's writer lock and stop signal."""

import fcntl
import json
import signal
import sys
import threading
import time
from datetime import datetime
from pathlib import Path


def now_ms():
    return int(time.time() * 1000)


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def append(live_dir, prefix, t, rec):
    """Append `rec` to `<live_dir>/<prefix>-<UTC day of t ms>.jsonl`, on a line of its own after a torn record."""
    with open(Path(live_dir) / f"{prefix}-{time.strftime('%Y%m%d', time.gmtime(t / 1000))}.jsonl", "ab+") as f:
        if f.tell() and f.seek(-1, 2) and f.read(1) != b"\n":
            f.write(b"\n")
        f.write(json.dumps(rec, separators=(",", ":")).encode() + b"\n")


def read(live_dir, prefix):
    """Every record of `<live_dir>/<prefix>-*.jsonl`, in file order; a line that does not parse (a write cut short) is
    named on stderr and skipped."""
    for p in sorted(Path(live_dir).glob(f"{prefix}-*.jsonl")):
        with open(p) as f:
            for n, line in enumerate(f, 1):
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    print(f"torn record skipped: {p}:{n}", file=sys.stderr)


def recording(out_dir):
    """Hold `out_dir`'s writer lock, exiting if another recorder holds it; SIGTERM sets the returned event."""
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    stop.lock = open(Path(out_dir) / ".writer.lock", "w")
    try:
        fcntl.flock(stop.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(f"{out_dir} has a running writer")
    return stop
