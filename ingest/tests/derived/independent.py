from bisect import bisect_right

HOUR_MS = 3_600_000
TICK_OFFSET_MS = 120_000
POLL_GAP_MS = 600_000


def _poll_runs(times):
    """Yield maximal poll runs whose consecutive gaps are <= POLL_GAP_MS."""
    start = last = times[0]
    for at in times[1:]:
        if at - last > POLL_GAP_MS:
            yield start, last
            start = at
        last = at
    yield start, last


def counts(case):
    """Return [coin, tau, count] rows for every covered hour."""
    coin_of = case["coin_of"]
    margin = case["margin"]
    version = case["version"]

    polls = {
        key: sorted(set(times))
        for key, times in case["polls"].items()
        if key in coin_of and times
    }

    earliest = {}
    for key, item_id, created, at in case["observations"]:
        if key not in polls:
            continue
        item = (key, item_id)
        candidate = (at, created)
        if item not in earliest or candidate < earliest[item]:
            earliest[item] = candidate

    known_times = {key: [] for key in polls}
    for (key, item_id), (witness, created) in earliest.items():
        if created >= polls[key][0]:
            known_times[key].append(witness + margin)

    rows = []
    for key, times in polls.items():
        known = sorted(known_times[key])

        for start, last in _poll_runs(times):
            lower_tau = start + HOUR_MS + margin - TICK_OFFSET_MS
            upper_tau = min(
                version - TICK_OFFSET_MS,
                last + POLL_GAP_MS + margin - TICK_OFFSET_MS - 1,
            )
            first_tau = -(-lower_tau // HOUR_MS) * HOUR_MS

            for tau in range(first_tau, upper_tau + 1, HOUR_MS):
                tick = tau + TICK_OFFSET_MS
                count = (
                    bisect_right(known, tick)
                    - bisect_right(known, tick - HOUR_MS)
                )
                rows.append([coin_of[key], tau, count])

    return rows
