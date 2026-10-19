"""C0.3/C0.7 judged window: the first 24 h without an L2 gap over 60 s, complete or None."""

import json

from ingest import availability
from ingest.availability import MAX_GAP, SPAN

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
    gap_at = t0 + 3_600_000
    holed = [t for t in steady if not gap_at < t < gap_at + MAX_GAP + S]
    root = write(tmp_path, {"A": steady, "B": holed})
    start, end = availability.window(root, after=t0)
    assert start == min(t for t in holed if t > gap_at) and end == start + SPAN
    assert availability.window(root, after=t0 + SPAN + MAX_GAP) is None
    edge = write(tmp_path, {"A": list(range(t0, t0 + SPAN - MAX_GAP + 1, S))})
    assert availability.window(edge, after=t0) == (t0, t0 + SPAN)
