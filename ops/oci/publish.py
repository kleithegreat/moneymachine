"""Publish a staged Oracle pull only when every existing destination is its prefix."""

import fcntl
import sys
from pathlib import Path


def publish(source, destination):
    source, destination = Path(source), Path(destination)
    files = sorted(p for p in source.rglob("*") if p.is_file())
    with (destination / ".pull.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for path in files:
            target = destination / path.relative_to(source)
            if target.exists():
                with path.open("rb") as incoming, target.open("rb") as previous:
                    while block := previous.read(1 << 20):
                        if incoming.read(len(block)) != block:
                            raise SystemExit(f"{target}: source no longer extends destination")
        for path in files:
            target = destination / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            path.replace(target)


if __name__ == "__main__":
    publish(*sys.argv[1:])
