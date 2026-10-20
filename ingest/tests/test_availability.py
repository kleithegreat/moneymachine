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
    start, end = availability.window(root, after=t0)
    assert start == min(t for t in holed if t > gap_at) and end == start + SPAN
    assert availability.window(root, after=t0 + SPAN + MAX_GAP) is None
    edge = write(tmp_path, {"A": list(range(t0, t0 + SPAN - MAX_GAP + 1, S))})
    assert availability.window(edge, after=t0) == (t0, t0 + SPAN)


def test_a_late_boundary_poll_restarts_the_window(tmp_path):
    t0 = 10 * SPAN
    write(tmp_path, {"A": list(range(t0, t0 + 2 * SPAN, S))})
    b = t0 + HOUR
    with open(tmp_path / "polls-x.jsonl", "a") as f:
        for recv in (b + 5_000, b + 45_001):
            f.write(json.dumps({"kind": "funding", "coin": "A", "boundary": b, "purpose": "first", "sent": recv, "recv": recv}) + "\n")
        f.write(json.dumps({"kind": "funding", "coin": "A", "boundary": b + HOUR, "purpose": "first",
                            "sent": b + HOUR + 35_000, "recv": b + HOUR + 35_000}) + "\n")
    assert availability.window(tmp_path, after=t0) == (b + 45_001, b + 45_001 + SPAN)


def test_a_bar_is_observed_once_its_close_has_passed_without_waiting_for_the_next_bar():
    b = 10 * SPAN
    bar = {"t": b - BAR, "o": "1", "h": "2", "l": "0.5", "c": "1.5", "v": "9", "n": 3}
    polls = [{"kind": "bar", "coin": "A", "boundary": b, "purpose": p, "sent": t, "recv": t, "data": [bar]}
             for p, t in (("first", b + 5_000), ("verify", b + 600_000))]
    out = availability.analyze(polls)
    assert out["failures"] == [] and out["first_observed_lag_ms"]["max"] == 5_000
