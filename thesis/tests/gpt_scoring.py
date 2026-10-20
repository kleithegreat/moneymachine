# Interpretations of ambiguities:
# - SCORING.md's explicit anchor rule takes precedence over the stage criteria's
#   "completed daily" wording: a daily bar opening exactly at t_r is eligible as
#   an anchor. Historical calculations use daily opens, never daily closes.
# - Funding coverage metadata is absent from the input. Supplied funding rows
#   are therefore treated as exhaustive; an absent market or empty list means
#   no funding rows. Missing funding observations cannot otherwise be detected.
# - The stage's valid horizons imply D >= 1. D <= 0 would make the specified
#   window sequence nonterminating, so it is rejected.
# - N is the positive hypothetical notional specified by SCORING.md, including
#   for size-zero theses; an actual N <= 0 is rejected.

"""Independent thesis scoring using only the Python standard library."""

from bisect import bisect_left, bisect_right
from math import floor

HOUR = 3_600_000
DAY = 86_400_000
DELTA = 120_000
LOOKBACK = 1_095 * DAY


class _Bars:
    def __init__(self, rows):
        ordered = sorted(rows, key=lambda row: row[0])
        self.times = [row[0] for row in ordered]
        self.values = {row[0]: (row[1], row[2]) for row in ordered}

    def first_at_or_after(self, timestamp):
        index = bisect_left(self.times, timestamp)
        return self.times[index] if index < len(self.times) else None

    def mark(self, timestamp, daily):
        index = bisect_right(self.times, timestamp) - 1
        if index < 0:
            return None

        start = self.times[index]
        opening, closing = self.values[start]
        if daily:
            # A previous daily bar cannot substitute for a missing day's bar.
            return opening if timestamp < start + DAY else None

        # For hourly marks, the last available bar may be older than one hour.
        return closing if start + HOUR <= timestamp else opening


class _Funding:
    def __init__(self, rows):
        ordered = sorted(rows, key=lambda row: row[0])
        self.times = [row[0] for row in ordered]
        self.rates = [row[1] for row in ordered]

    def between(self, entry, exit_time):
        """Yield every row with entry < timestamp <= exit_time."""
        start = bisect_right(self.times, entry)
        end = bisect_right(self.times, exit_time)
        for index in range(start, end):
            yield self.times[index], self.rates[index]


def _fill(quantity, reference, market_costs, fee_rate):
    side = "buy" if quantity > 0 else "sell"
    cell = "1000" if abs(quantity) * reference <= 1000 else "10000"
    bps = market_costs[side][cell]
    adjustment = bps / 10_000
    price = reference * (
        1 + adjustment if quantity > 0 else 1 - adjustment
    )
    fee = abs(quantity) * price * fee_rate
    return price, fee


def _comparison(pairs):
    """Pairs contain (main probability, comparison probability, outcome)."""
    count = len(pairs)
    if count == 0:
        return {
            "n_pairs": 0,
            "B": None,
            "B_ref": None,
            "diff": None,
            "skill": None,
        }

    main_loss = sum((p - outcome) ** 2 for p, _, outcome in pairs) / count
    reference_loss = sum(
        (reference - outcome) ** 2 for _, reference, outcome in pairs
    ) / count
    return {
        "n_pairs": count,
        "B": main_loss,
        "B_ref": reference_loss,
        "diff": main_loss - reference_loss,
        "skill": (
            None if reference_loss == 0
            else 1 - main_loss / reference_loss
        ),
    }


def _clusters(theses, results):
    count = len(theses)
    parents = list(range(count))

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    def union(left, right):
        left_root = find(left)
        right_root = find(right)
        if left_root != right_root:
            parents[right_root] = left_root

    markets = [
        {market for market, _ in thesis["legs"]}
        for thesis in theses
    ]

    for right in range(count):
        current = theses[right]
        for left in range(right):
            previous = theses[left]
            linked = (
                previous["session"] == current["session"]
                or previous["catalyst_id"] == current["catalyst_id"]
                or (
                    bool(markets[left] & markets[right])
                    and previous["t_r"] <= current["T"]
                    and current["t_r"] <= previous["T"]
                )
            )
            if linked:
                union(left, right)

    # Insertion order makes both cluster order and member order follow input.
    components = {}
    for index, thesis in enumerate(theses):
        root = find(index)
        components.setdefault(root, []).append(thesis["id"])

    return [
        {
            "name": members[0],
            "members": members,
            "resolved": all(
                results[identifier]["outcome"] is not None
                for identifier in members
            ),
        }
        for members in components.values()
    ]


def score(test: dict) -> dict:
    """Return precisely the thesis, score, and cluster output in SCORING.md."""
    theses = test["theses"]
    now = test["now"]
    fee_rate = test["account"]["fee"]
    costs = test["account"]["costs"]

    markets = {
        market
        for thesis in theses
        for market, _ in thesis["legs"]
    }
    hourly = {
        market: _Bars(
            row
            for row in test["hourly"].get(market, [])
            if row[0] <= now
        )
        for market in markets
    }
    daily = {
        market: _Bars(test["daily"].get(market, []))
        for market in markets
    }
    funding = {
        market: _Funding(test["funding"].get(market, []))
        for market in markets
    }

    def net_return(thesis, leg_times, use_daily):
        bars_by_market = daily if use_daily else hourly
        notional = thesis["N"]
        total = 0.0

        for (market, sign), (entry, exit_time) in zip(
            thesis["legs"], leg_times
        ):
            bars = bars_by_market[market]
            entry_reference = bars.values[entry][0]
            exit_reference = bars.values[exit_time][0]
            quantity = sign * notional / entry_reference

            entry_price, entry_fee = _fill(
                quantity, entry_reference, costs[market], fee_rate
            )
            exit_price, exit_fee = _fill(
                -quantity, exit_reference, costs[market], fee_rate
            )

            contribution = (
                quantity * (exit_price - entry_price)
                - entry_fee
                - exit_fee
            )
            for timestamp, rate in funding[market].between(entry, exit_time):
                mark = bars.mark(timestamp, use_daily)
                if mark is None:
                    return None
                contribution -= quantity * rate * mark

            total += contribution

        return total / notional

    results = {}

    for thesis in theses:
        if thesis["N"] <= 0:
            raise ValueError("N must be a positive hypothetical notional")

        duration = floor((thesis["T"] - thesis["t_r"]) / DAY + 0.5)
        if duration <= 0:
            raise ValueError("Rounded holding duration D must be positive")

        leg_times = []
        for market, _ in thesis["legs"]:
            entry = hourly[market].first_at_or_after(
                thesis["t_r"] + DELTA
            )
            exit_time = hourly[market].first_at_or_after(thesis["T"])
            if entry is None or exit_time is None:
                break
            leg_times.append((entry, exit_time))

        outcome = None
        if len(leg_times) == len(thesis["legs"]):
            result = net_return(thesis, leg_times, False)
            if result is not None:
                outcome = {"R_net": result, "o": int(result > 0)}

        common_days = None
        for market, _ in thesis["legs"]:
            available = {
                timestamp
                for timestamp in daily[market].times
                if timestamp <= thesis["t_r"]
            }
            if common_days is None:
                common_days = available
            else:
                common_days.intersection_update(available)

        complete_count = 0
        positive_count = 0

        if common_days:
            anchor = max(common_days)
            step = duration * DAY
            earliest_entry = thesis["t_r"] - LOOKBACK
            exit_time = anchor

            while exit_time - step >= earliest_entry:
                entry = exit_time - step
                complete = all(
                    entry in daily[market].values
                    and exit_time in daily[market].values
                    for market, _ in thesis["legs"]
                )

                if complete:
                    window_times = [
                        (entry, exit_time) for _ in thesis["legs"]
                    ]
                    result = net_return(thesis, window_times, True)
                    if result is not None:
                        complete_count += 1
                        positive_count += int(result > 0)

                # Omitted windows never shift any subsequent window.
                exit_time -= step

        reference = (
            (positive_count + 1) / (complete_count + 2)
            if complete_count >= 10
            else None
        )
        results[thesis["id"]] = {
            "outcome": outcome,
            "p_ref": reference,
            "m": complete_count,
            "x": positive_count,
        }

    losses = []
    base_pairs = []
    ablation_pairs = []

    for thesis in theses:
        result = results[thesis["id"]]
        if result["outcome"] is None:
            continue

        outcome = result["outcome"]["o"]
        probability = thesis["p"]
        losses.append((probability - outcome) ** 2)

        if result["p_ref"] is not None:
            base_pairs.append((probability, result["p_ref"], outcome))
        if thesis["p_ablation"] is not None:
            ablation_pairs.append(
                (probability, thesis["p_ablation"], outcome)
            )

    return {
        "theses": results,
        "scores": {
            "n_resolved": len(losses),
            "B": sum(losses) / len(losses) if losses else None,
            "base_rate": _comparison(base_pairs),
            "ablation": _comparison(ablation_pairs),
        },
        "clusters": _clusters(theses, results),
    }
