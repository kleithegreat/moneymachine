"""C0.3: from recorder polls, when each settled funding row and closed bar was first observed.

C0.3 and C0.7 are judged on the first 24 h after RECORDING_FROM (the last recorder restart) in which
no coin's L2 poll gap exceeds MAX_GAP and no boundary poll comes more than BOUNDARY_GAP after the
boundary or the previous poll of the same row (PROGRESS.md, C0.7 revisions of 2026-10-19).
"""

import json
import sys
from collections import defaultdict

from ingest.backfill import funding_known
from ingest.hl import HOUR
from ingest.live import read
from ingest.store import DELTA

BAR = 4 * HOUR
RECORDING_FROM = 1792455550295
SPAN = 24 * HOUR
MAX_GAP = 60_000
BOUNDARY_GAP = 35_000
VERIFY_AFTER = 600_000


def load(live_dir):
    return read(live_dir, "polls")


def window(live_dir, after=RECORDING_FROM):
    """(start, end) of the judged span, or None while no complete one exists yet."""
    sent, rows = defaultdict(list), defaultdict(list)
    for p in load(live_dir):
        if p["kind"] == "l2" and p["sent"] >= after:
            sent[p["coin"]].append(p["sent"])
        elif p["kind"] != "l2" and p["purpose"] == "first" and p["boundary"] >= after:
            rows[(p["kind"], p["coin"], p["boundary"])].append(p["recv"])
    if not sent:
        return None
    gaps = [(a, b) for ts in sent.values() for a, b in zip(sorted(ts), sorted(ts)[1:]) if b - a > MAX_GAP]
    gaps += [(a, b) for (_, _, boundary), ts in rows.items() for a, b in zip([boundary] + sorted(ts), sorted(ts))
             if b - a > BOUNDARY_GAP]
    gaps.sort()
    start = max(min(ts) for ts in sent.values())
    for a, b in gaps:
        if a < start + SPAN and b > start:
            start = max(start, b)
    end = start + SPAN
    return (start, end) if all(max(ts) >= end - MAX_GAP for ts in sent.values()) else None


def judged(live_dir):
    """The polls C0.3 and C0.7 judge: L2 snapshots inside the window, and the boundaries whose
    first and verify polls both fall inside it."""
    span = window(live_dir)
    if span is None:
        sys.exit("no complete 24 h window yet")
    start, end = span
    for p in load(live_dir):
        if start <= (p["sent"] if p["kind"] == "l2" else p["boundary"]) and \
                (p["sent"] < end if p["kind"] == "l2" else p["boundary"] + VERIFY_AFTER < end):
            yield p


def _value(kind, data, boundary):
    if kind == "funding":
        rows = [r for r in data if r["time"] // HOUR * HOUR == boundary]
        return json.dumps([rows[0]["fundingRate"], rows[0]["premium"]]) if rows else None
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
        known = boundary + DELTA
        if kind == "funding":
            reported = [r["time"] for p in ps for r in p["data"] if r["time"] // HOUR * HOUR == boundary]
            known = funding_known(min(reported)) if reported else known
        if first is None or first > known:
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
    print(json.dumps({"window": window(sys.argv[1]), **analyze(judged(sys.argv[1]))}, indent=1))
