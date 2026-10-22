"""Derive hourly event counts from observations and successful live polls."""

from bisect import bisect_right

HOUR = 3_600_000
POLL_LIFETIME = 600_000


def _poll_runs(polls):
    """Yield maximal polling-coverage intervals [start, stop)."""
    start = previous = polls[0]
    for current in polls[1:]:
        if current - previous > POLL_LIFETIME:
            yield start, previous + POLL_LIFETIME
            start = current
        previous = current
    yield start, previous + POLL_LIFETIME


def counts(case) -> list:
    """Return [coin, tau, count] rows for every covered grid hour."""
    version = case["version"]
    margin = case["margin"]

    earliest = {}
    for key, item_id, created, at in case["observations"]:
        items = earliest.setdefault(key, {})
        candidate = (at, created)
        if item_id not in items or candidate < items[item_id]:
            items[item_id] = candidate

    rows = []
    for key, coin in case["coin_of"].items():
        polls = sorted(set(case["polls"].get(key, [])))
        if not polls:
            continue

        first_poll = polls[0]
        known_times = sorted(
            witnessed + margin
            for witnessed, created in earliest.get(key, {}).values()
            if created >= first_poll
        )

        for start, stop in _poll_runs(polls):
            minimum_tau = start + HOUR + margin
            first_tau = -(-minimum_tau // HOUR) * HOUR
            last_tau = min(version, stop + margin - 1)

            for tau in range(first_tau, last_tau + 1, HOUR):
                count = (
                    bisect_right(known_times, tau)
                    - bisect_right(known_times, tau - HOUR)
                )
                rows.append([coin, tau, count])

    return rows
