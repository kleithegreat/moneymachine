"""Publish each staged Oracle file that extends its destination; report all divergences."""

import fcntl
import sys
from pathlib import Path


def extends(source, destination):
    with source.open("rb") as incoming, destination.open("rb") as previous:
        while block := previous.read(1 << 20):
            if incoming.read(len(block)) != block:
                return False
    return True


def publish(source, destination):
    source, destination = Path(source), Path(destination)
    files = sorted(p for p in source.rglob("*") if p.is_file())
    with (destination / ".pull.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        divergent = []
        for path in files:
            target = destination / path.relative_to(source)
            if target.exists():
                if path.samefile(target):
                    continue
                if not extends(path, target):
                    divergent.append(f"{target}: source no longer extends destination")
                    continue
            target.parent.mkdir(parents=True, exist_ok=True)
            path.replace(target)
        if divergent:
            raise SystemExit("\n".join(divergent))


if __name__ == "__main__":
    publish(*sys.argv[1:])
