"""C6.5's effort proxy, recovered after the fact (it was not instrumented at the time). Per milestone, between
consecutive milestone commits: elapsed wall time; active time, the sum over each session transcript of its gaps of
at most 5 minutes between consecutive events; the sessions with events; and, from git, the commits made in the
interval and how many of them were dated revisions or in-progress steps.
usage: python effort.py "name|commit" ...   (the first interval starts at the stage 6 criteria commit)"""

import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

D = Path.home() / ".claude/projects/-home-kevin-repos-moneymachine"
TS = re.compile(r'"timestamp":"([^"]+)"')
sessions = {}
for f in D.glob("*.jsonl"):
    for line in open(f, errors="ignore"):
        m = TS.search(line)
        if m:
            sessions.setdefault(f.stem, []).append(datetime.datetime.fromisoformat(m.group(1).replace("Z", "+00:00")).timestamp())
for ts in sessions.values():
    ts.sort()


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


milestones = [("start (criteria: stage 6)", "1ebc588")] + [tuple(x.split("|")) for x in sys.argv[1:]]
times = [(n, h, int(git("show", "-s", "--format=%ct", h))) for n, h in milestones]
rows = []
for (_, ph, pt), (n, h, t) in zip(times, times[1:]):
    active, active_sessions = 0, 0
    for ts in sessions.values():
        ev = [x for x in ts if pt < x <= t]
        active += sum(b - a for a, b in zip(ev, ev[1:]) if b - a <= 300)
        active_sessions += bool(ev)
    subjects = git("log", "--format=%s", f"{ph}..{h}").splitlines()
    rows.append({"milestone": n, "commit": h, "elapsed_h": round((t - pt) / 3600, 2), "active_h": round(active / 3600, 2),
                 "sessions": active_sessions, "commits": len(subjects),
                 "revisions_or_in_progress": sum("revision" in s or "in progress" in s for s in subjects)})
print(json.dumps(rows, indent=1))
