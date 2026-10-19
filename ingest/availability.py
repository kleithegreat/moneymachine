"""C0.3: from recorder polls, when each settled funding row and closed bar was first observed."""

import json
import sys
from collections import defaultdict
from pathlib import Path

from ingest.hl import HOUR
from ingest.store import DELTA

BAR = 4 * HOUR


def load(live_dir):
    for p in sorted(Path(live_dir).glob("polls-*.jsonl")):
        with open(p) as f:
            for line in f:
                yield json.loads(line)


def _value(kind, data, boundary):
    if kind == "funding":
        rows = [r for r in data if r["time"] // HOUR * HOUR == boundary]
        return json.dumps([rows[0]["fundingRate"], rows[0]["premium"]]) if rows else None
    if not any(c["t"] == boundary for c in data):
        return None
    rows = [c for c in data if c["t"] == boundary - BAR]
    return json.dumps([rows[0][k] for k in "ohlcvn"]) if rows else None


def analyze(polls):
    seen = defaultdict(list)
    offsets = []
    for p in polls:
        if p["kind"] == "l2":
            offsets.append((p["data"]["time"] - (p["sent"] + p["recv"]) / 2, p["recv"] - p["sent"]))
        else:
            seen[(p["kind"], p["coin"], p["boundary"])].append(p)
    events, failures = defaultdict(int), []
    for (kind, coin, boundary), ps in sorted(seen.items()):
        ref = [_value(kind, p["data"], boundary) for p in ps if p["purpose"] == "verify"]
        if not ref or ref[0] is None:
            failures.append({"kind": kind, "coin": coin, "boundary": boundary, "why": "no verify value"})
            continue
        first = min((p["recv"] for p in ps if _value(kind, p["data"], boundary) == ref[0]), default=None)
        events[(kind, coin)] += 1
        if first is None or first > boundary + DELTA:
            failures.append({"kind": kind, "coin": coin, "boundary": boundary, "first_observed": first,
                             "lag_ms": None if first is None else first - boundary})
    lags = sorted(min(p["recv"] for p in ps if _value(k, p["data"], b) is not None) - b
                  for (k, c, b), ps in seen.items() if any(_value(k, p["data"], b) is not None for p in ps))
    return {
        "events": {f"{k}:{c}": n for (k, c), n in sorted(events.items())},
        "failures": failures,
        "first_observed_lag_ms": {"min": lags[0], "median": lags[len(lags) // 2], "max": lags[-1]} if lags else None,
        "clock_offset_ms": {"max_abs": max(abs(o) for o, _ in offsets), "max_rtt": max(r for _, r in offsets),
                            "n": len(offsets)} if offsets else None,
        "span_h": (max(p["recv"] for v in seen.values() for p in v) - min(p["sent"] for v in seen.values() for p in v)) / HOUR
        if seen else 0,
    }


if __name__ == "__main__":
    print(json.dumps(analyze(load(sys.argv[1])), indent=1))
