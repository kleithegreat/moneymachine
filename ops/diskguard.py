"""Recording capacity alarm; policy and limitations: paper appendix O2, deployment: CLUSTER.md §5."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

VOLUMES = {
    "hl": "data/live",
    "sources": "data/sources_live",
    "datalayer": "data/datalayer",
    "thesis": "data/thesis",
    "agent": "data/agent",
}
MAX_AGE = 30 * 60


def capacity(path):
    s = os.statvfs(path)
    return {
        "bytes": {"free": s.f_bavail * s.f_frsize, "total": s.f_blocks * s.f_frsize},
        "inodes": {"free": s.f_favail, "total": s.f_files},
    }


def problems(sample):
    alarms = []
    for resource in ("bytes", "inodes"):
        try:
            free, total = sample[resource]["free"], sample[resource]["total"]
        except (KeyError, TypeError) as e:
            raise ValueError(f"invalid {resource} capacity") from e
        if type(free) is not int or type(total) is not int or not 0 <= free <= total or total <= 0:
            raise ValueError(f"invalid {resource} capacity: {free}/{total}")
        if free * 5 <= total:
            alarms.append(f"{resource}: {free}/{total} available ({100 * free / total:.1f}%), at/below 20% reserve")
    return alarms


def check(data, mirror, now=None):
    alarms = []
    for name, path in (("PC data", data), ("PC mirror", mirror)):
        try:
            alarms.extend(f"{name} ({path}): {p}" for p in problems(capacity(path)))
        except (OSError, ValueError) as e:
            alarms.append(f"{name} ({path}): cannot measure capacity: {e}")
    for volume in VOLUMES:
        try:
            record = json.loads((Path(mirror) / volume / "MANIFEST.json").read_text())
            taken = record["taken"]
            current = time.time() if now is None else now
            if type(taken) is not int or not (current - MAX_AGE) * 1000 <= taken <= current * 1000:
                raise ValueError("missing fresh capacity report (future or older than 30 minutes)")
            alarms.extend(f"prodesk7 {volume}: {p}" for p in problems(record["capacity"]))
        except (OSError, ValueError, KeyError, TypeError) as e:
            alarms.append(f"prodesk7 {volume}: cannot establish capacity: {e}")
    return alarms


def main(data=Path("data"), mirror=Path("/srv/moneymachine/mirror")) -> int:
    alarms = check(data, mirror)
    if not alarms:
        return 0
    body = "\n".join(alarms) + "\nAdd capacity or remove only regenerable data; never delete recordings."
    print(body, file=sys.stderr)
    subprocess.run(
        ["notify-send", "--urgency=critical", "--expire-time=0", "moneymachine: recording capacity alarm", body],
        check=True,
        timeout=10,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
