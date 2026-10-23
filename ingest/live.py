"""Live recordings: the clock the recorders stamp with, the writer and reader of their day JSONL files, and
each recorder's pidfile, through which `restart` stops it between polls and starts it again."""

import json
import os
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

PIDFILE = "recorder.json"


def now_ms():
    return int(time.time() * 1000)


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def append(live_dir, prefix, t, rec):
    """Append `rec` to `<live_dir>/<prefix>-<UTC day of t ms>.jsonl`."""
    with open(Path(live_dir) / f"{prefix}-{time.strftime('%Y%m%d', time.gmtime(t / 1000))}.jsonl", "a") as f:
        f.write(json.dumps(rec, separators=(",", ":")) + "\n")


def read(live_dir, prefix):
    """Every record of `<live_dir>/<prefix>-*.jsonl`, in file order."""
    for p in sorted(Path(live_dir).glob(f"{prefix}-*.jsonl")):
        with open(p) as f:
            for line in f:
                yield json.loads(line)


def recording(out_dir, command, **args):
    """Record this recorder's pid, CLI command and arguments in `out_dir`; SIGTERM sets the returned event."""
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    (Path(out_dir) / PIDFILE).write_text(json.dumps({"pid": os.getpid(), "command": command, "args": args}) + "\n")
    return stop


def alive(pid, command):
    try:
        argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
    except FileNotFoundError:
        return False
    return b"cli" in argv and command.encode() in argv


def restart(out_dir, budget=None, wait=300):
    """Stop the recorder writing to `out_dir` (it finishes its current poll), then start it again detached with
    the same arguments, `budget` replacing its rate budget."""
    import cli

    rec = json.loads((Path(out_dir) / PIDFILE).read_text())
    args = rec["args"] | ({"budget": budget} if budget is not None else {})
    names = [a.rstrip("?").partition(":")[0] for a in cli.COMMANDS[rec["command"]][2]]
    if set(args) - set(names):
        raise ValueError(f"{rec['command']} takes no {sorted(set(args) - set(names))}")
    if alive(rec["pid"], rec["command"]):
        os.kill(rec["pid"], signal.SIGTERM)
        deadline = time.time() + wait
        while alive(rec["pid"], rec["command"]):
            if time.time() > deadline:
                raise TimeoutError(f"recorder {rec['pid']} still running {wait} s after SIGTERM")
            time.sleep(1)
    with open(Path(out_dir) / "recorder.log", "a") as log:
        p = subprocess.Popen([sys.executable, "-m", "cli", rec["command"], *(str(args[a]) for a in names if a in args)],
                             cwd=cli.REPO, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                             start_new_session=True)
    return {"stopped": rec["pid"], "started": p.pid}
