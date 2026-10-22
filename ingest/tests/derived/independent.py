"""Derive hourly event counts from a case described by FORMAT.md."""

HOUR_MS = 3_600_000


def counts(case: dict) -> list:
    """Return [coin, tau, count] rows, including covered hours with zero events.

    Observations and polls are assumed to have already been cut at the
    dataset version. The input is not modified.
    """
    margin = case["margin"]
    coin_of = case["coin_of"]

    # key -> (coin, first poll, first covered hour, last covered hour)
    coverage = {}
    for key, polls in case["polls"].items():
        if key not in coin_of or not polls:
            continue

        first_poll = min(polls)
        last_poll = max(polls)
        ceil_first_poll = -(-first_poll // HOUR_MS) * HOUR_MS
        first_hour = ceil_first_poll + HOUR_MS
        last_hour = (last_poll // HOUR_MS) * HOUR_MS

        if first_hour <= last_hour:
            coverage[key] = (
                coin_of[key],
                first_poll,
                first_hour,
                last_hour,
            )

    # Choose the earliest observation per (key, id), breaking ties by the
    # smallest claimed creation time. Apply the prospective filter afterward.
    earliest = {}
    for key, item_id, created, at in case["observations"]:
        if key not in coverage:
            continue

        item = (key, item_id)
        candidate = (at, created)
        previous = earliest.get(item)
        if previous is None or candidate < previous:
            earliest[item] = candidate

    totals = {}
    for (key, _item_id), (witness, created) in earliest.items():
        _coin, first_poll, first_hour, last_hour = coverage[key]
        if created < first_poll:
            continue

        known_at = witness + margin

        # Ceiling assigns known_at to exactly (tau - HOUR_MS, tau],
        # including known_at == tau and excluding the lower boundary.
        tau = -(-known_at // HOUR_MS) * HOUR_MS
        if first_hour <= tau <= last_hour:
            bucket = (key, tau)
            totals[bucket] = totals.get(bucket, 0) + 1

    rows = []
    for key, (coin, _first_poll, first_hour, last_hour) in coverage.items():
        for tau in range(first_hour, last_hour + 1, HOUR_MS):
            rows.append([coin, tau, totals.get((key, tau), 0)])

    return rows
