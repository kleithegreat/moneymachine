"""C10.4 (stage 10 revision of 2026-10-23): GPT's independent scorer, written by GPT 6.1 Sol from thesis/SCORING.md
and the stage 10 criteria alone, tools denied (~/.cache/mm-gpt/s10scorer.3g4b). Committed verbatim below this note."""

"""Independent thesis scoring using only the Python standard library."""

from bisect import bisect_left, bisect_right
from math import floor, fsum

HOUR = 3_600_000
DAY = 86_400_000
DELTA = 120_000


def score(test):
    """Return the outcomes, base rates, scores, and clusters for one test set."""
    fee_rate = test["account"]["fee"]
    costs = test["account"]["costs"]
    now = test["now"]
    theses = test["theses"]

    hourly = {
        market: sorted(rows, key=lambda row: row[0])
        for market, rows in test["hourly"].items()
    }
    hourly_times = {
        market: [row[0] for row in rows]
        for market, rows in hourly.items()
    }
    daily_opens = {
        market: {row[0]: row[1] for row in rows}
        for market, rows in test["daily"].items()
    }
    funding = {
        market: sorted(rows, key=lambda row: row[0])
        for market, rows in test["funding"].items()
    }
    funding_times = {
        market: [row[0] for row in rows]
        for market, rows in funding.items()
    }

    def fill(market, quantity, reference):
        side = "buy" if quantity > 0 else "sell"
        cell = "1000" if abs(quantity) * reference <= 1000 else "10000"
        bps = costs[market][side][cell]
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

        rows = funding.get(market, ())
        times = funding_times.get(market, ())
        first = bisect_right(times, entry)
        stop = bisect_right(times, exit_time)

        for index in range(first, stop):
            hour, rate = rows[index]
            if use_daily:
                day = (hour // DAY) * DAY
                mark = daily_opens.get(market, {}).get(day)
            else:
                mark = hourly_mark(market, hour)
            if mark is None:
                return None
            contributions.append(-quantity * rate * mark)

        return fsum(contributions)

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

        net_return = fsum(contributions) / notional
        return {"R_net": net_return, "o": int(net_return > 0)}

    def base_rate(thesis):
        legs = thesis["legs"]
        registered = thesis["t_r"]
        duration = floor((thesis["T"] - registered) / DAY + 0.5)
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
                net_return = fsum(contributions) / thesis["N"]
                positive_count += int(net_return > 0)

            exit_time -= step

        probability = (
            (positive_count + 1) / (complete_count + 2)
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
            "p_ref": probability,
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

        main_brier = fsum(main_losses) / count
        reference_brier = fsum(reference_losses) / count
        return {
            "n_pairs": count,
            "B": main_brier,
            "B_ref": reference_brier,
            "diff": main_brier - reference_brier,
            "skill": (
                None
                if reference_brier == 0
                else 1 - main_brier / reference_brier
            ),
        }

    scores = {
        "n_resolved": len(resolved),
        "B": (
            fsum((thesis["p"] - observed) ** 2
                 for thesis, observed, _ in resolved) / len(resolved)
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
