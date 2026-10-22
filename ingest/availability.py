"""C0.3: from recorder polls, when each settled funding row and closed bar was first observed, and the
host clock's NTP record over the same window.

C0.3 and C0.7 are judged on the first 24 h after RECORDING_FROM (the last recorder restart) in which
no coin's L2 poll gap exceeds MAX_GAP and no boundary poll comes more than BOUNDARY_GAP after the
boundary or the previous poll of the same row (PROGRESS.md, C0.7 revisions of 2026-10-19 and 2026-10-21).
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

import polars as pl

from ingest.live import read
from ingest.policy import BAR, HOUR
from ingest.store import known_at

RECORDING_FROM = 1792617764170
SPAN = 24 * HOUR
MAX_GAP = 60_000
BOUNDARY_GAP = 35_000
VERIFY_AFTER = 600_000
CLOCK_SLACK = 600_000


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
    for p in polls:
        if p["kind"] != "l2":
            seen[(p["kind"], p["coin"], p["boundary"])].append(p)
    events, failures, margins = defaultdict(int), [], []
    for (kind, coin, boundary), ps in sorted(seen.items()):
        ref = [_value(kind, p["data"], boundary) for p in ps if p["purpose"] == "verify"]
        if not ref or ref[0] is None:
            failures.append({"kind": kind, "coin": coin, "boundary": boundary, "why": "no verify value"})
            continue
        first = min((p["recv"] for p in ps if _value(kind, p["data"], boundary) == ref[0]), default=None)
        events[(kind, coin)] += 1
        reported = [r["time"] for p in ps for r in p["data"] if r["time"] // HOUR * HOUR == boundary] if kind == "funding" else []
        known = pl.DataFrame({"eventTime": [boundary], "reportedTime": [min(reported, default=boundary)]}).select(
            known_at("funding" if kind == "funding" else "bars_4h")).item()
        if first is not None:
            margins.append(known - first)
        if first is None or first > known:
            failures.append({"kind": kind, "coin": coin, "boundary": boundary, "first_observed": first,
                             "lag_ms": None if first is None else first - boundary})
    lags = sorted(min(p["recv"] for p in ps if _value(k, p["data"], b) is not None) - b
                  for (k, c, b), ps in seen.items() if any(_value(k, p["data"], b) is not None for p in ps))
    return {
        "events": {f"{k}:{c}": n for (k, c), n in sorted(events.items())},
        "failures": failures,
        "first_observed_lag_ms": {"min": lags[0], "median": lags[len(lags) // 2], "max": lags[-1]} if lags else None,
        "min_margin_ms": min(margins, default=None),
        "span_h": (max(p["recv"] for v in seen.values() for p in v) - min(p["sent"] for v in seen.values() for p in v)) / HOUR
        if seen else 0,
    }



def clock(readings, span):
    """The NTP offsets logged around the window (C0.3 revision of 2026-10-21): readings from CLOCK_SLACK before
    its start to CLOCK_SLACK after its end, the largest gap between them, and the longest run of one unchanged
    value, which bounds the age of the NTP exchange each reading reports."""
    start, end = span
    rs = sorted((t, o) for t, o in readings if start - CLOCK_SLACK <= t <= end + CLOCK_SLACK)
    if not rs:
        return None
    changes = [rs[0][0]] + [b for (_, a), (b, o) in zip(rs, rs[1:]) if o != a] + [rs[-1][0]]
    return {"readings": len(rs), "exchanges": len(changes) - 1, "max_abs_ms": max(abs(o) for _, o in rs),
            "brackets": rs[0][0] <= start and rs[-1][0] >= end,
            "max_gap_min": max((b - a for (a, _), (b, _) in zip(rs, rs[1:])), default=0) / 60_000,
            "max_unchanged_min": max(b - a for a, b in zip(changes, changes[1:])) / 60_000}


def ntp_readings(sources_dir):
    """(time, offset ms) of each host-clock reading the stage 5 recorder logged from systemd-timesyncd."""
    return [(p["recv"], p["data"]["offset_ms"]) for p in read(sources_dir, "sources")
            if p["source"] == "clock" and isinstance(p["data"].get("offset_ms"), float)]


def report(live_dir, sources_dir, out):
    """The judged window, the analysis of the polls inside it, and the host clock's NTP record over it."""
    span = window(live_dir)
    Path(out).write_text(json.dumps({"window": span, **analyze(judged(live_dir)),
                                     "clock": clock(ntp_readings(sources_dir), span)}, indent=1) + "\n")
