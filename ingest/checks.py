"""Stage 0 coverage, integrity and replay-completeness checks (C0.2, C0.5).

They run on fetched frames at ingestion, before the holdout split, and report only
counts, gaps and boolean outcomes, so the holdout's values are never read afterwards.
"""

import polars as pl

from ingest.hl import HOUR
from ingest.store import DELTA

BAR = 4 * HOUR
FUNDING_CAP = 0.04


def _gaps(present, start, end, step):
    """Contiguous runs [a, b) of the grid start, start+step, ... < end missing from present."""
    have = set(present)
    gaps, run = [], None
    for t in range(start, end, step):
        if t not in have:
            run = run or t
        elif run is not None:
            gaps.append((run, t))
            run = None
    if run is not None:
        gaps.append((run, end))
    return gaps


def listed_intervals(bars, w_start, w_end, delisted):
    """[start, end) per coin: W, cut for delisted coins at the close of their last traded bar.

    Funding rows do not mark delisting: the venue keeps writing zero rows afterwards.
    """
    last = dict(bars.filter(pl.col("trades") > 0).group_by("coin").agg(pl.col("eventTime").max()).iter_rows())
    return {c: (w_start, last[c] if c in delisted else w_end) for c in last}


def coverage(funding, bars, intervals):
    out = {}
    for coin, (start, end) in intervals.items():
        f = funding.filter((pl.col("coin") == coin) & pl.col("eventTime").is_between(start, end - 1))
        b = bars.filter((pl.col("coin") == coin) & pl.col("openTime").is_between(start, end - 1))
        fg = _gaps(f["eventTime"], start, end, HOUR)
        bg = _gaps(b["openTime"], start - start % BAR + (BAR if start % BAR else 0), end, BAR)
        n_f, n_b = (end - start) // HOUR, (end - start) // BAR
        out[coin] = {
            "funding_expected": n_f, "funding_missing": sum((b_ - a) // HOUR for a, b_ in fg),
            "bars_expected": n_b, "bars_missing": sum((b_ - a) // BAR for a, b_ in bg),
            "max_gap_h": max([(b_ - a) / HOUR for a, b_ in fg + bg], default=0),
            "funding_gaps": fg, "bar_gaps": bg,
        }
        out[coin]["pass"] = (out[coin]["funding_missing"] <= 0.01 * n_f and out[coin]["bars_missing"] <= 0.01 * n_b
                             and out[coin]["max_gap_h"] <= 24)
    return out


def integrity(funding, bars):
    pos = funding.filter(pl.col("premium") > 5e-4)
    return {
        "funding_duplicate_keys": funding.height - funding.unique(["coin", "eventTime"]).height,
        "bar_duplicate_keys": bars.height - bars.unique(["coin", "eventTime"]).height,
        "bars_misaligned": bars.filter(pl.col("openTime") % BAR != 0).height,
        "bars_ohlc_inconsistent": bars.filter(
            (pl.col("low") > pl.min_horizontal("open", "close")) | (pl.col("high") < pl.max_horizontal("open", "close"))
        ).height,
        "bars_negative_volume": bars.filter(pl.col("volume") < 0).height,
        "funding_over_cap": funding.filter(pl.col("fundingRate").abs() > FUNDING_CAP).height,
        "funding_reported_lag_ms": [int((funding["reportedTime"] - funding["eventTime"]).min()),
                                    int((funding["reportedTime"] - funding["eventTime"]).max())],
        "funding_modal_rate": funding["fundingRate"].mode().sort()[0],
        "funding_premium_corr": funding.select(pl.corr("fundingRate", "premium")).item(),
        "funding_positive_when_premium_gt_5bp": (pos.filter(pl.col("fundingRate") > 0).height, pos.height),
    }


def replay_completeness(funding, bars, intervals, view=None):
    """(B, coin) pairs whose view at B + DELTA lacks the funding at B or the bar ending at B.

    view(dataset, t) -> {coin: latest eventTime known at t}. With view=None it is derived
    from keys and knownAt alone, which is how the holdout is checked at ingestion.
    """
    def from_keys(df):
        return {c: set(g["eventTime"]) for (c,), g in df.group_by("coin")}

    keys = {"funding": from_keys(funding), "bars_4h": from_keys(bars)}
    lo = min(s for s, _ in intervals.values())
    hi = max(e for _, e in intervals.values())
    failures, total = [], 0
    for b in range(lo + (-lo) % BAR, hi, BAR):
        latest = {d: view(d, b + DELTA) for d in keys} if view else None
        for coin, (start, end) in intervals.items():
            if not start <= b < end:
                continue
            total += 1
            if latest is None:
                ok = all(b in keys[d].get(coin, ()) for d in keys)
            else:
                ok = all(latest[d].get(coin) == b for d in keys)
            if not ok:
                failures.append((b, coin))
    return {"pairs": total, "failures": len(failures), "fraction_ok": 1 - len(failures) / max(total, 1),
            "failure_list": failures}
