"""C0.3/C0.7 judged window: the first 24 h without an L2 gap over 60 s, complete or None."""

import json

from ingest import availability
from ingest.availability import MAX_GAP, SPAN
from ingest.policy import BAR, HOUR

S = 30_000


def write(tmp_path, times):
    with open(tmp_path / "polls-x.jsonl", "w") as f:
        for coin, ts in times.items():
            for t in ts:
                f.write(json.dumps({"kind": "l2", "coin": coin, "sent": t, "recv": t}) + "\n")
    return tmp_path


def test_window_restarts_after_a_gap_and_needs_a_full_span(tmp_path):
    t0 = 10 * SPAN
    steady = list(range(t0, t0 + 2 * SPAN, S))
    gap_at = t0 + HOUR
    holed = [t for t in steady if not gap_at < t < gap_at + MAX_GAP + S]
    root = write(tmp_path, {"A": steady, "B": holed})
    start, end = availability.window(root, root, after=t0)
    assert start == min(t for t in holed if t > gap_at) and end == start + SPAN
    assert availability.window(root, root, after=t0 + SPAN + MAX_GAP) is None
    edge = write(tmp_path, {"A": list(range(t0, t0 + SPAN - MAX_GAP + 1, S))})
    assert availability.window(edge, edge, after=t0) == (t0, t0 + SPAN)


def test_a_late_boundary_poll_restarts_the_window(tmp_path):
    t0 = 10 * SPAN
    write(tmp_path, {"A": list(range(t0, t0 + 2 * SPAN, S))})
    b = t0 + HOUR
    with open(tmp_path / "polls-x.jsonl", "a") as f:
        for recv in (b + 5_000, b + 45_001):
            f.write(json.dumps({"kind": "funding", "coin": "A", "boundary": b, "purpose": "first", "sent": recv, "recv": recv}) + "\n")
        f.write(json.dumps({"kind": "funding", "coin": "A", "boundary": b + HOUR, "purpose": "first",
                            "sent": b + HOUR + 35_000, "recv": b + HOUR + 35_000}) + "\n")
    assert availability.window(tmp_path, tmp_path, after=t0) == (b + 45_001, b + 45_001 + SPAN)


def test_a_clock_log_gap_restarts_the_window(tmp_path):
    t0 = 10 * SPAN
    write(tmp_path, {"A": list(range(t0, t0 + 2 * SPAN, S))})
    restart = t0 + 200_000 + availability.CLOCK_SLACK + 1
    readings = [t0 - 300_000, t0 + 200_000] + list(range(restart, t0 + 2 * SPAN, 300_000))
    with open(tmp_path / "sources-x.jsonl", "w") as f:
        for t in readings:
            f.write(json.dumps({"source": "clock", "key": "timesyncd", "sent": t, "recv": t, "data": {"offset_ms": 1.5}}) + "\n")
    assert availability.window(tmp_path, tmp_path, after=t0) == (restart, restart + SPAN)


def test_a_bar_is_observed_once_its_close_has_passed_without_waiting_for_the_next_bar():
    b = 10 * SPAN
    bar = {"t": b - BAR, "o": "1", "h": "2", "l": "0.5", "c": "1.5", "v": "9", "n": 3}
    polls = [{"kind": "bar", "coin": "A", "boundary": b, "purpose": p, "sent": t, "recv": t, "data": [bar]}
             for p, t in (("first", b + 5_000), ("verify", b + 600_000))]
    out = availability.analyze(polls)
    assert out["failures"] == [] and out["first_observed_lag_ms"]["max"] == 5_000


def test_the_clock_record_reports_offsets_gaps_and_how_long_one_exchange_is_reported():
    m = 60_000
    start, end = 100 * m, 200 * m
    readings = [(t * m, 5.0 if t < 140 else -7.0) for t in range(95, 206, 5)] + [(10 * m, 900.0)]
    c = availability.clock(readings, (start, end))
    assert c["max_abs_ms"] == 7.0 and c["brackets"] and c["max_gap_min"] == 5
    assert c["exchanges"] == 2 and c["max_unchanged_min"] == 65
    assert not availability.clock(readings[2:], (start, end))["brackets"]


def host(root, l2=(), boundary=(), clock=()):
    """A host's directories: L2 (coin, sent) polls, boundary (kind, coin, boundary, purpose, recv) polls, clock times."""
    root.mkdir(parents=True, exist_ok=True)
    with open(root / "polls-x.jsonl", "w") as f:
        for coin, t in l2:
            f.write(json.dumps({"kind": "l2", "coin": coin, "sent": t, "recv": t}) + "\n")
        for kind, coin, b, purpose, t in boundary:
            f.write(json.dumps({"kind": kind, "coin": coin, "boundary": b, "purpose": purpose, "sent": t, "recv": t}) + "\n")
    with open(root / "sources-x.jsonl", "w") as f:
        for i, t in enumerate(clock):
            f.write(json.dumps({"source": "clock", "key": "timesyncd", "sent": t, "recv": t, "data": {"offset_ms": 1.5 + i % 2}}) + "\n")
    return root, root


def test_merge_keeps_one_snapshot_per_slot_preferring_the_first_host_and_drops_unclocked_polls(tmp_path):
    clock = list(range(0, 2 * SPAN, 300_000))
    local = host(tmp_path / "local", [("A", 1_000), ("A", 31_000)], clock=clock)
    oci = host(tmp_path / "oci", [("A", 2_000), ("A", 61_000), ("A", 2 * SPAN + 10 * availability.CLOCK_SLACK)], clock=clock)
    polls = availability.merge([("local", *local), ("oci", *oci)])
    assert sorted((p["host"], p["sent"]) for p in polls) == [("local", 1_000), ("local", 31_000), ("oci", 61_000)]


def test_each_boundary_comes_from_the_first_host_whose_polls_are_complete(tmp_path):
    b, clock = 10 * SPAN, list(range(10 * SPAN - 600_000, 10 * SPAN + 3_600_000, 300_000))
    local = host(tmp_path / "local", boundary=[("funding", "A", b, "first", b + 5_000), ("funding", "A", b, "first", b + 45_000),
                                              ("funding", "A", b, "verify", b + 600_000)], clock=clock)
    oci = host(tmp_path / "oci", boundary=[("funding", "A", b, "first", b + 9_000), ("funding", "A", b, "verify", b + 600_000)],
               clock=clock)
    polls = availability.merge([("local", *local), ("oci", *oci)])
    assert {p["host"] for p in polls} == {"oci"}
    complete_local = host(tmp_path / "local2", boundary=[("funding", "A", b, "first", b + 30_000), ("funding", "A", b, "verify", b + 600_000)],
                          clock=clock)
    assert {p["host"] for p in availability.merge([("local", *complete_local), ("oci", *oci)])} == {"local"}


def test_the_merged_window_starts_at_the_threshold_and_bridges_a_local_outage(tmp_path, monkeypatch):
    t0 = 10 * SPAN
    monkeypatch.setattr(availability, "THRESHOLD", t0)
    steady = range(t0 - SPAN, t0 + 2 * SPAN, S)
    clock = list(range(t0 - SPAN, t0 + 2 * SPAN, 300_000))
    outage = (t0 + HOUR, t0 + 3 * HOUR)
    local = host(tmp_path / "local", [("A", t) for t in steady if not outage[0] < t < outage[1]],
                 clock=[t for t in clock if not outage[0] < t < outage[1]])
    host(tmp_path / "oci" / "live", [("A", t) for t in steady], clock=())
    host(tmp_path / "oci" / "clock", clock=clock)
    assert availability.window(*local, after=t0) != (t0, t0 + SPAN)
    window, hosts, polls = availability.judgment(*local, tmp_path / "oci")
    assert window == (t0, t0 + SPAN)
    assert [h[0] for h in hosts] == ["oci"]
    assert {p["host"] for p in polls} == {"oci"}


def test_a_complete_local_window_from_before_the_threshold_is_judged_alone(tmp_path, monkeypatch):
    t0 = availability.RECORDING_FROM + SPAN
    monkeypatch.setattr(availability, "THRESHOLD", t0 + HOUR)
    clock = list(range(t0 - HOUR, t0 + 2 * SPAN, 300_000))
    local = host(tmp_path / "local", [("A", t) for t in range(t0, t0 + 2 * SPAN, S)], clock=clock)
    window, hosts, polls = availability.judgment(*local, tmp_path / "oci")
    assert window == (t0, t0 + SPAN) and [h[0] for h in hosts] == ["local"]
