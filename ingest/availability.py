"""C0.3: from recorder polls, when each settled funding row and closed bar was first observed, and the
host clock's NTP record over the same window.

C0.3 and C0.7 are judged on the first 24 h after RECORDING_FROM in which no coin's L2 poll gap exceeds MAX_GAP
and no boundary poll comes more than BOUNDARY_GAP after the boundary or the previous poll of the same row
(audit/criteria.md, C0.3/C0.7 revisions). A window starting from THRESHOLD on merges the local and cloud hosts'
recordings (merge amendment of 2026-10-23 and its extension of 2026-10-24), so this PC need not be up during it.
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
THRESHOLD = 1792879093607  # 2026-10-24 21:58:13.607 UTC (17:58 EDT): 24 h after the cloud host's first clock reading
SLOT = 30_000


def load(live_dir):
    return read(live_dir, "polls")


def window(live_dir, sources_dir, after=RECORDING_FROM):
    """(start, end) of the local-only span, or None while no complete one exists yet. A gap of more than CLOCK_SLACK
    in the NTP log (`sources_dir`) restarts it, like an L2 gap (C0.3 amendment of 2026-10-23)."""
    return span(load(live_dir), [t for t, _ in ntp_readings(sources_dir)], after)


def span(polls, clock_times, after):
    """The first complete 24 h span of `polls` from `after` without an L2, boundary or clock-log gap, or None."""
    sent, rows = defaultdict(list), defaultdict(list)
    for p in polls:
        if p["kind"] == "l2" and p["sent"] >= after:
            sent[p["coin"]].append(p["sent"])
        elif p["kind"] != "l2" and p["purpose"] == "first" and p["boundary"] >= after:
            rows[(p["kind"], p["coin"], p["boundary"])].append(p["recv"])
    if not sent:
        return None
    gaps = [(a, b) for ts in sent.values() for a, b in zip(sorted(ts), sorted(ts)[1:]) if b - a > MAX_GAP]
    gaps += [(a, b) for (_, _, boundary), ts in rows.items() for a, b in zip([boundary] + sorted(ts), sorted(ts))
             if b - a > BOUNDARY_GAP]
    clock = sorted(clock_times)
    gaps += [(a, b) for a, b in zip(clock, clock[1:]) if b - a > CLOCK_SLACK]
    gaps.sort()
    start = max(min(ts) for ts in sent.values())
    for a, b in gaps:
        if a < start + SPAN and b > start:
            start = max(start, b)
    end = start + SPAN
    return (start, end) if all(max(ts) >= end - MAX_GAP for ts in sent.values()) else None


def inside(polls, window):
    """The polls C0.3 and C0.7 judge: L2 snapshots inside the window, and the boundaries whose
    first and verify polls both fall inside it."""
    start, end = window
    return [p for p in polls if start <= (p["sent"] if p["kind"] == "l2" else p["boundary"]) and
            (p["sent"] < end if p["kind"] == "l2" else p["boundary"] + VERIFY_AFTER < end)]


def complete(polls, boundary):
    """Whether one host's polls of a boundary have no first-poll gap over BOUNDARY_GAP and include the verify poll."""
    first = sorted(p["recv"] for p in polls if p["purpose"] == "first")
    return bool(first) and any(p["purpose"] == "verify" for p in polls) and \
        all(b - a <= BOUNDARY_GAP for a, b in zip([boundary] + first, first))


def merge(hosts):
    """One host-tagged poll stream from `hosts`, [(name, live_dir, clock_dir)] in preference order (merge amendment
    of 2026-10-23 and its extension of 2026-10-24): a host's polls outside its clock log or inside a gap of more
    than CLOCK_SLACK in it are dropped; each (coin, 30 s slot) keeps one L2 snapshot, the first host's, earliest send
    within it; each boundary's polls come from the first host whose polls for it are complete, else the first host
    that has any. Hosts are chosen by which polls exist, never by their values or delays."""
    l2, rows = {}, defaultdict(dict)
    for name, live_dir, clock_dir in hosts:
        clock = sorted(t for t, _ in ntp_readings(clock_dir))
        holes = [(a, b) for a, b in zip(clock, clock[1:]) if b - a > CLOCK_SLACK]
        for p in load(live_dir):
            t = p["sent"]
            if not clock or not clock[0] <= t <= clock[-1] + CLOCK_SLACK or any(a < t < b for a, b in holes):
                continue
            p = p | {"host": name}
            if p["kind"] == "l2":
                key = (p["coin"], t // SLOT)
                if key not in l2 or (l2[key]["host"] == name and t < l2[key]["sent"]):
                    l2[key] = p
            else:
                rows[(p["kind"], p["coin"], p["boundary"])].setdefault(name, []).append(p)
    order = [name for name, _, _ in hosts]
    chosen = [next((by[n] for n in order if n in by and complete(by[n], key[2])), by[next(n for n in order if n in by)])
              for key, by in rows.items()]
    return list(l2.values()) + [p for ps in chosen for p in ps]


def clock_ok(record):
    """C0.3's clock requirement (revision of 2026-10-21) over one window."""
    return bool(record) and record["max_abs_ms"] < 1000 and record["brackets"] and record["max_gap_min"] <= 10 \
        and record["max_unchanged_min"] <= 40


def judgment(live_dir, sources_dir, oci_dir=None):
    """(window, hosts, judged polls) of the earliest complete window, or None: the local-only window if it started
    before THRESHOLD, else the merged window from THRESHOLD on, in which a host whose clock fails C0.3's requirement
    over the window contributes nothing (merge amendment and its extension, audit/criteria.md)."""
    local = window(live_dir, sources_dir)
    if local is not None and local[0] < THRESHOLD:
        return local, [("local", live_dir, sources_dir)], inside(load(live_dir), local)
    hosts = [("local", live_dir, sources_dir)] + ([("oci", Path(oci_dir) / "live", Path(oci_dir) / "clock")] if oci_dir else [])
    while hosts:
        polls = merge(hosts)
        merged = span(polls, [], THRESHOLD)
        if merged is None:
            return None
        failing = [h for h in hosts if not clock_ok(clock(ntp_readings(h[2]), merged))]
        if not failing:
            return merged, hosts, inside(polls, merged)
        hosts = [h for h in hosts if h not in failing]
    return None


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


def report(live_dir, sources_dir, out, oci_dir=None):
    """The judged window, the polls each host contributed, the analysis of the polls inside it, and each host's NTP
    record over it."""
    judged = judgment(live_dir, sources_dir, oci_dir)
    if judged is None:
        sys.exit("no complete 24 h window yet")
    window_, hosts, polls = judged
    Path(out).write_text(json.dumps({"window": window_, **contributions(hosts, polls), **analyze(polls),
                                     "clock": {name: clock(ntp_readings(c), window_) for name, _, c in hosts}}, indent=1) + "\n")


def contributions(hosts, polls):
    return {"hosts": {name: sum(p.get("host", "local") == name for p in polls) for name, _, _ in hosts}}
