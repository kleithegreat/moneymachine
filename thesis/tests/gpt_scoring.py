"""C10.4 (stage 10 revision of 2026-10-23): GPT's independent scorer, written by GPT 6.1 Sol from thesis/SCORING.md
and the stage 10 criteria alone, tools denied (~/.cache/mm-gpt/s10scorer.3g4b), and updated by it on 2026-10-24 from
the revised SCORING.md and its own previous file (~/.cache/mm-gpt/c104.3Rq2), and on 2026-11-02 from the readings in audit/criteria.md and its own previous file (~/.cache/mm-gpt/scorer-PGkc). Committed verbatim below this note."""

"""Independent C10.4 thesis scorer, updated for the 2026-11-02 readings.

Choices left undetermined by the specifications:
- Malformed-input handling: assume valid registered theses, positive hypothetical
  N, unique thesis IDs, and the required account cost cells; no new validation
  protocol is imposed.
- Duplicate timestamps: retain the earlier scorer's stable hourly ordering and
  last-row-wins daily and funding dictionaries.
- Output numeric representation: retain Python floats for numeric results.
  Arithmetic and discrete decisions precede conversion; ordinary float rounding,
  underflow, and overflow behavior apply only at the output boundary.
"""

from bisect import bisect_left, bisect_right
from decimal import Decimal
from fractions import Fraction
from math import floor

HOUR = 3_600_000
DAY = 86_400_000
DELTA = 120_000


def _rational(value):
    """Read a recorded decimal or rational exactly, without float arithmetic."""
    if isinstance(value, (int, Fraction)):
        return Fraction(value)

    # str(float) supplies its shortest decimal representation. Decimal parsing
    # is exact and avoids Python's integer-string digit limit for long records.
    text = str(value)
    if "/" in text:
        numerator, denominator = text.split("/")
        return (
            Fraction(Decimal(numerator))
            / Fraction(Decimal(denominator))
        )
    return Fraction(Decimal(text))


def _integer(value):
    """Read an integral bar or funding timestamp without rounding."""
    result = _rational(value)
    if result.denominator != 1:
        raise ValueError("Bar and funding timestamps must be integral")
    return result.numerator


def score(test):
    """Return the outcomes, base rates, scores, and clusters for one test set."""
    fee_rate = _rational(test["account"]["fee"])
    costs = test["account"]["costs"]
    now = _rational(test["now"])
    theses = [
        {
            **thesis,
            "t_r": _rational(thesis["t_r"]),
            "T": _rational(thesis["T"]),
            "N": _rational(thesis["N"]),
            "p": _rational(thesis["p"]),
            "p_ablation": (
                None
                if thesis["p_ablation"] is None
                else _rational(thesis["p_ablation"])
            ),
            "legs": [
                (market, _rational(sign))
                for market, sign in thesis["legs"]
            ],
        }
        for thesis in test["theses"]
    ]

    hourly = {
        market: sorted(
            [
                (
                    _integer(opened),
                    _rational(open_price),
                    None if close_price is None else _rational(close_price),
                )
                for opened, open_price, close_price in rows
            ],
            key=lambda row: row[0],
        )
        for market, rows in test["hourly"].items()
    }
    hourly_times = {
        market: [row[0] for row in rows]
        for market, rows in hourly.items()
    }
    daily_opens = {
        market: {
            _integer(row[0]): _rational(row[1])
            for row in rows
        }
        for market, rows in test["daily"].items()
    }
    funding = {
        market: {
            _integer(hour): _rational(rate)
            for hour, rate in rows
        }
        for market, rows in test["funding"].items()
    }

    def fill(market, quantity, reference):
        side = "buy" if quantity > 0 else "sell"
        cell = "1000" if abs(quantity) * reference <= 1000 else "10000"
        bps = _rational(costs[market][side][cell])
        if quantity > 0:
            price = reference * (1 + bps / 10_000)
        else:
            price = reference * (1 - bps / 10_000)
        fee = abs(quantity) * price * fee_rate
        return price, fee

    def hourly_mark(market, timestamp):
        times = hourly_times.get(market, ())
        index = bisect_right(times, timestamp) - 1
        if index < 0:
            return None
        opened, open_price, close_price = hourly[market][index]
        if opened + HOUR <= timestamp and close_price is not None:
            return close_price
        return open_price

    def leg_return(market, sign, notional, entry, exit_time,
                   entry_reference, exit_reference, use_daily):
        quantity = sign * notional / entry_reference
        entry_price, entry_fee = fill(market, quantity, entry_reference)
        exit_price, exit_fee = fill(market, -quantity, exit_reference)
        contributions = [
            quantity * (exit_price - entry_price),
            -entry_fee,
            -exit_fee,
        ]

        rates = funding.get(market, {})

        # Funding excludes entry and includes exit. Every intervening
        # settlement must have a row, including hours with a zero rate.
        for hour in range(entry + HOUR, exit_time + 1, HOUR):
            if hour not in rates:
                return None
            rate = rates[hour]

            if use_daily:
                day = (hour // DAY) * DAY
                mark = daily_opens.get(market, {}).get(day)
            else:
                mark = hourly_mark(market, hour)

            # A zero rate does not excuse missing required price data.
            if mark is None:
                return None
            contributions.append(-quantity * rate * mark)

        return sum(contributions, Fraction(0))

    def outcome(thesis):
        contributions = []
        notional = thesis["N"]

        for market, sign in thesis["legs"]:
            times = hourly_times.get(market, ())
            entry_index = bisect_left(times, thesis["t_r"] + DELTA)
            exit_index = bisect_left(times, thesis["T"])

            if entry_index == len(times) or exit_index == len(times):
                return None

            entry = times[entry_index]
            exit_time = times[exit_index]
            if entry > now or exit_time > now or entry >= exit_time:
                return None

            contribution = leg_return(
                market,
                sign,
                notional,
                entry,
                exit_time,
                hourly[market][entry_index][1],
                hourly[market][exit_index][1],
                False,
            )
            if contribution is None:
                return None
            contributions.append(contribution)

        net_return = sum(contributions, Fraction(0)) / notional
        return {"R_net": float(net_return), "o": int(net_return > 0)}

    def base_rate(thesis):
        legs = thesis["legs"]
        registered = thesis["t_r"]
        duration = floor(
            (thesis["T"] - registered) / DAY + Fraction(1, 2)
        )
        step = duration * DAY

        common_days = set(daily_opens.get(legs[0][0], {}))
        for market, _ in legs[1:]:
            common_days.intersection_update(daily_opens.get(market, {}))

        anchor = max(
            (day for day in common_days if day <= registered),
            default=None,
        )
        if anchor is None:
            return None, 0, 0

        lower_bound = registered - 1_095 * DAY
        complete_count = 0
        positive_count = 0
        exit_time = anchor

        while exit_time - step >= lower_bound:
            entry = exit_time - step
            contributions = []
            complete = True

            for market, sign in legs:
                opens = daily_opens.get(market, {})
                if entry not in opens or exit_time not in opens:
                    complete = False
                    break

                contribution = leg_return(
                    market,
                    sign,
                    thesis["N"],
                    entry,
                    exit_time,
                    opens[entry],
                    opens[exit_time],
                    True,
                )
                if contribution is None:
                    complete = False
                    break
                contributions.append(contribution)

            if complete:
                complete_count += 1
                net_return = (
                    sum(contributions, Fraction(0)) / thesis["N"]
                )
                positive_count += int(net_return > 0)

            exit_time -= step

        probability = (
            Fraction(positive_count + 1, complete_count + 2)
            if complete_count >= 10
            else None
        )
        return probability, complete_count, positive_count

    thesis_results = {}
    resolved = []

    for thesis in theses:
        result = outcome(thesis)
        probability, complete_count, positive_count = base_rate(thesis)
        thesis_results[thesis["id"]] = {
            "outcome": result,
            "p_ref": (
                None if probability is None else float(probability)
            ),
            "m": complete_count,
            "x": positive_count,
        }
        if result is not None:
            resolved.append((thesis, result["o"], probability))

    def comparison(use_ablation):
        main_losses = []
        reference_losses = []

        for thesis, observed, base_probability in resolved:
            reference = (
                thesis["p_ablation"] if use_ablation else base_probability
            )
            if reference is None:
                continue
            main_losses.append((thesis["p"] - observed) ** 2)
            reference_losses.append((reference - observed) ** 2)

        count = len(main_losses)
        if count == 0:
            return {
                "n_pairs": 0,
                "B": None,
                "B_ref": None,
                "diff": None,
                "skill": None,
            }

        main_brier = sum(main_losses, Fraction(0)) / count
        reference_brier = sum(reference_losses, Fraction(0)) / count
        return {
            "n_pairs": count,
            "B": float(main_brier),
            "B_ref": float(reference_brier),
            "diff": float(main_brier - reference_brier),
            "skill": (
                None
                if reference_brier == 0
                else float(1 - main_brier / reference_brier)
            ),
        }

    scores = {
        "n_resolved": len(resolved),
        "B": (
            float(
                sum(
                    (
                        (thesis["p"] - observed) ** 2
                        for thesis, observed, _ in resolved
                    ),
                    Fraction(0),
                ) / len(resolved)
            )
            if resolved
            else None
        ),
        "base_rate": comparison(False),
        "ablation": comparison(True),
    }

    parents = list(range(len(theses)))

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    def union(left, right):
        left_root = find(left)
        right_root = find(right)
        if left_root != right_root:
            earlier = min(left_root, right_root)
            later = max(left_root, right_root)
            parents[later] = earlier

    sessions = {}
    catalysts = {}
    market_intervals = {}

    for index, thesis in enumerate(theses):
        session = thesis["session"]
        catalyst = thesis["catalyst_id"]

        if session in sessions:
            union(index, sessions[session])
        else:
            sessions[session] = index

        if catalyst in catalysts:
            union(index, catalysts[catalyst])
        else:
            catalysts[catalyst] = index

        for market in {market for market, _ in thesis["legs"]}:
            market_intervals.setdefault(market, []).append(
                (thesis["t_r"], thesis["T"], index)
            )

    for intervals in market_intervals.values():
        intervals.sort()
        representative = None
        latest_end = None

        for start, end, index in intervals:
            if representative is not None and start <= latest_end:
                union(representative, index)
                latest_end = max(latest_end, end)
            else:
                representative = index
                latest_end = end

    components = {}
    for index in range(len(theses)):
        components.setdefault(find(index), []).append(index)

    clusters = []
    for members in components.values():
        member_ids = [theses[index]["id"] for index in members]
        clusters.append({
            "name": member_ids[0],
            "members": member_ids,
            "resolved": all(
                thesis_results[thesis_id]["outcome"] is not None
                for thesis_id in member_ids
            ),
        })

    return {
        "theses": thesis_results,
        "scores": scores,
        "clusters": clusters,
    }
