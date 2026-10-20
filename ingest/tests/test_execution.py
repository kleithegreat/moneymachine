from ingest import execution
from ingest.policy import BAR


def test_relative_ranges_use_reference_bars_inside_each_coins_calibration_span():
    report = {"A:buy:1000": {"calibration_span": [0, 3 * BAR]}, "B:buy:1000": {"calibration_span": None}}
    bar = lambda t, h: {"t": t, "o": "100", "h": str(h), "l": "100"}
    polls = [{"kind": "bar", "purpose": "verify", "coin": "A", "boundary": t + BAR, "data": [bar(t, h), bar(t + BAR, 999)]}
             for t, h in ((0, 102), (BAR, 101), (2 * BAR, 105), (3 * BAR, 150))]
    polls.append({"kind": "bar", "purpose": "first", "coin": "A", "boundary": BAR, "data": [bar(0, 200)]})
    polls.append({"kind": "bar", "purpose": "verify", "coin": "B", "boundary": BAR, "data": [bar(0, 200)]})
    assert execution.relative_ranges(polls, report) == {"A": [0.01, 0.05]}
