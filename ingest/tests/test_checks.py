import polars as pl

from ingest import checks
from ingest.backfill import bar_frame, funding_frame
from ingest.hl import HOUR
from ingest.store import DELTA, Store

BAR = 4 * HOUR


def frames(hours, skip_funding=(), skip_bars=()):
    f = funding_frame([{"coin": "A", "time": h * HOUR + 40, "fundingRate": "0.0000125", "premium": "0.0"}
                       for h in range(hours) if h not in skip_funding])
    b = bar_frame([{"s": "A", "t": t, "o": "1", "h": "2", "l": "0.5", "c": "1.5", "v": "3", "n": 1}
                   for t in range(0, hours * HOUR, BAR) if t not in skip_bars], fetched_at=10**15)
    return f, b


def test_gaps():
    assert checks._gaps([0, 1, 4], 0, 6, 1) == [(2, 4), (5, 6)]


def test_coverage_counts_missing():
    f, b = frames(48, skip_funding={5, 6}, skip_bars={8 * HOUR})
    cov = checks.coverage(f, b, {"A": (0, 48 * HOUR)})["A"]
    assert (cov["funding_missing"], cov["bars_missing"], cov["max_gap_h"]) == (2, 1, 4)


def test_unclosed_bar_dropped():
    b = bar_frame([{"s": "A", "t": 0, "o": "1", "h": "1", "l": "1", "c": "1", "v": "1", "n": 1}], fetched_at=BAR - 1)
    assert b.height == 0


def test_replay_view_matches_keys(tmp_path):
    f, b = frames(48, skip_funding={12}, skip_bars={20 * HOUR})
    s = Store(tmp_path)
    s.write("funding", f, 1, "t")
    s.write("bars_4h", b, 1, "t")

    def view(d, t):
        return dict(s.as_of(d, t, 1).group_by("coin").agg(pl.col("eventTime").max()).iter_rows())

    iv = {"A": (0, 48 * HOUR)}
    by_keys = checks.replay_completeness(f, b, iv)
    by_view = checks.replay_completeness(f, b, iv, view)
    assert by_keys["failure_list"] == by_view["failure_list"] == [(0, "A"), (12 * HOUR, "A"), (24 * HOUR, "A")]
    assert s.as_of("funding", 12 * HOUR + DELTA - 1, 1)["eventTime"].max() == 11 * HOUR
