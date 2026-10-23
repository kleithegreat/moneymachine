import json, re, subprocess, sys, glob, datetime
from pathlib import Path
D = Path.home() / ".claude/projects/-home-kevin-repos-moneymachine"
ts = re.compile(r'"timestamp":"([^"]+)"')
events = []  # (t, session, compaction)
for f in D.glob("*.jsonl"):
    for line in open(f, errors="ignore"):
        m = ts.search(line)
        if m:
            t = datetime.datetime.fromisoformat(m.group(1).replace("Z", "+00:00")).timestamp()
            events.append((t, f.stem, '"isCompactSummary":true' in line))
events.sort()
milestones = [("start (criteria: stage 6)", "1ebc588")] + [tuple(x.split("|")) for x in sys.argv[1:]]
times = [(n, h, int(subprocess.run(["git", "show", "-s", "--format=%ct", h], capture_output=True, text=True).stdout)) for n, h in milestones]
rows = []
for (pn, ph, pt), (n, h, t) in zip(times, times[1:]):
    ev = [e for e in events if pt < e[0] <= t]
    active = sum(min(b[0] - a[0], 300) for a, b in zip(ev, ev[1:]) if b[0] - a[0] <= 300)
    rows.append({"milestone": n, "commit": h, "elapsed_h": round((t - pt) / 3600, 2), "active_h": round(active / 3600, 2),
                 "sessions": len({e[1] for e in ev}), "compactions": sum(e[2] for e in ev)})
print(json.dumps(rows, indent=1))
