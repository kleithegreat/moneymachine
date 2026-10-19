"""Live recordings: the clock the recorders stamp with, and the reader for their JSONL files."""

import json
import time
from datetime import datetime
from pathlib import Path


def now_ms():
    return int(time.time() * 1000)


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def read(live_dir, prefix):
    """Every record of `<live_dir>/<prefix>-*.jsonl`, in file order."""
    for p in sorted(Path(live_dir).glob(f"{prefix}-*.jsonl")):
        with open(p) as f:
            for line in f:
                yield json.loads(line)
