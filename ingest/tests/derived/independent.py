"""Reference implementation of the hourly event counts in derived.md."""

from collections import Counter

HOUR_MS = 3_600_000
ADMITTED_DELAY_MS = 600_000


def _ceil_hour(time_ms):
    """Round up to the hour grid, leaving exact multiples unchanged."""
    return ((time_ms + HOUR_MS - 1) // HOUR_MS) * HOUR_MS


def counts(case):
    """Return [coin, tau, count] rows for every covered hour."""
    admitted = case["admitted"]

    # key -> (coin, first poll, first covered hour, last covered hour)
    coverage = {}
    for key, coin in case["coin_of"].items():
        polls = case["polls"].get(key, [])
        if not polls:
            continue

        first_poll = min(polls)
        last_poll = max(polls)
        start = case["start"] if admitted else first_poll

        first_hour = _ceil_hour(start) + HOUR_MS
        last_hour = (last_poll // HOUR_MS) * HOUR_MS

        if first_hour <= last_hour:
            coverage[key] = (coin, first_poll, first_hour, last_hour)

    # Select each item's earliest observation, breaking equal observation
    # times by the smallest claimed creation time.
    # (key, id) -> (observation time, claimed creation time)
    earliest = {}
    for key, item_id, created, observed_at in case["observations"]:
        if key not in coverage:
            continue

        item = (key, item_id)
        candidate = (observed_at, created)
        previous = earliest.get(item)
        if previous is None or candidate < previous:
            earliest[item] = candidate

    totals = Counter()
    for (key, item_id), (witness, created) in earliest.items():
        coin, first_poll, first_hour, last_hour = coverage[key]

        if admitted:
            known_at = created + ADMITTED_DELAY_MS
        else:
            if created < first_poll:
                continue
            known_at = witness

        # The unique hour ending at tau such that:
        #     tau - HOUR_MS < known_at <= tau
        tau = _ceil_hour(known_at)
        if first_hour <= tau <= last_hour:
            totals[key, tau] += 1

    rows = []
    for key in sorted(coverage):
        coin, first_poll, first_hour, last_hour = coverage[key]
        for tau in range(first_hour, last_hour + HOUR_MS, HOUR_MS):
            rows.append([coin, tau, totals[key, tau]])

    return rows
