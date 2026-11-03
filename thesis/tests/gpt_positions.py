"""Position management: GPT's independent implementation, written by GPT 6.1 Sol from the stage 10 criteria and positions.py's data shape alone, tools denied (~/.cache/mm-gpt/positions-fWkk), 2026-11-02 06:43 UTC (01:43 EST), and updated by GPT from the criteria's readings of 2026-11-02 and SCORING.md alone (~/.cache/mm-gpt/positions2-CzWZ), 2026-11-03 03:29 UTC (2026-11-02 22:29 EST). Committed verbatim below this note; its list of what the spec leaves open is in its own docstring."""

"""
Independent, standard-library-only thesis-position replay.

UNDETERMINED DETAILS / INTERFACE CONVENTIONS
------------------------------------------
1. Spread legs fill independently. Invalidation starts after every leg has
   entered and uses a common closing boundary strictly after every entry.
2. At an identical price timestamp, an opening reference wins over a close
   for account marking. Stale account marks are reported.
3. Missing cost cells use the per-tier, per-side maximum over the supplied U.
   A legacy flat cell table applies to both sides; directional tables may
   instead contain separate "buy" and "sell" mappings.
4. A wholly suppressed managed position reports zero trading return. Its
   as-registered outcome still requires a valid entry strictly before exit.
5. Legacy explicitly supplied N=0 is evaluated as a per-unit limiting
   hypothetical position, using the smallest cost tier. Normal admission
   with positive initial equity never creates hypothetical N=0.
6. The original interface has no cutoff argument. Optional data["cutoff"]
   supplies C; otherwise C defaults to now, or t_r in admit. That default
   represents an instantaneous/same-timestamp read. A delayed live read must
   supply its actual cutoff.
7. Funding receipt times and historical cache contents are not represented.
   Supplied funding rows are usable from settlement; available_at reports
   the nominal price-availability gate, not an independently observed
   receipt or reconciliation-write time.

PUBLIC API
----------
replay(initial, theses, exits, data, now)
admit(initial, theses, exits, data, t_r, L)

All timestamps are integer UTC Unix seconds, preserving the original API.
Hour boundaries are multiples of 3600; midnights are multiples of 86400.

Numbers may be int, finite float, Decimal, Fraction, decimal text, or exact
rational text. Floats mean their shortest decimal representation. Monetary
amounts, quantities, prices, rates, and returns remain Fraction objects in
the existing API. admit additionally returns a JSON-ready "record" whose
exact numeric fields are rational text, without a digit-length limit.

initial:
    {"time": hour_aligned_timestamp, "cash": number}

theses, in registration commit order:
    {
        "id": unique_nonempty_string,
        "t_r": timestamp,
        "T": UTC_midnight,
        "L": number,
        "p": number,
        "N": frozen_hypothetical_per_leg_notional,
        "size": N_or_zero,
        "b": actual_reservation,
        "legs": [{
            "market": nonempty_string,
            "w": -1_or_1,
            "fee": fractional_rate_or_None,
            "cells": {
                "1000": fractional_cost,
                "10000": fractional_cost
            } or {
                "buy": tier_mapping_or_None,
                "sell": tier_mapping_or_None
            } or None,
            "cost_fallback": bool
        }, ...]
    }

exits, in decision commit order:
    {"id": thesis_id, "time": timestamp, "reason": string}

data:
    {
        "bars": {market: {hour: (positive_open, positive_close_or_None)}},
        "funding": {market: {hour: finite_fractional_rate}},
        "lag": {market: integer_seconds_in_[0,3600)},
        "cutoff": optional_timestamp,
        "terms": {
            market: {
                "fee": fractional_rate_or_None,
                "cells": flat_or_directional_cells_or_None
            }
        },
        "U": [market, ...]
    }

Core lag is 120 seconds; builder lag is 300 seconds. Opens are usable at
H+lag independently of closes. Closes are usable at H+3600+lag. The adapter
must supply the bars actually returned by its read, and final sealed builder
references; this module does not reconstruct samples or invent missing bars.

This is a snapshot replay, not a daemon, ledger, eligibility checker, sample
sealer, historical-data retrier, baseline scorer, or resolution-record writer.
Those operations require inputs/persistence absent from this interface.
The host must preserve actual read snapshots and committed state, serialize
admission with registration, persist admit's exact record, and never recompute
registered sizes. A later replay cannot reconstruct a past cache, funding
receipt time, or an earlier persisted suppression from a newer snapshot.
"""

from decimal import Decimal, InvalidOperation
from fractions import Fraction

HOUR = 3600
DAY = 86400
DELTA = 120
ZERO = Fraction(0)
ONE = Fraction(1)
TIERS = ("1000", "10000")
SIDES = ("buy", "sell")


class MissingData(Exception):
    """A required value cannot be determined from the supplied inputs."""


def _number(value):
    if isinstance(value, bool):
        raise ValueError("Boolean is not a numeric input")
    if isinstance(value, Fraction):
        return value
    if isinstance(value, int):
        return Fraction(value)
    if isinstance(value, str) and "/" in value:
        parts = value.split("/")
        if len(parts) != 2:
            raise ValueError("Invalid rational text")
        numerator = _number(parts[0])
        denominator = _number(parts[1])
        if denominator == ZERO:
            raise ValueError("Zero rational denominator")
        return numerator / denominator
    try:
        decimal = value if isinstance(value, Decimal) else Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("Invalid numeric input") from exc
    if not decimal.is_finite():
        raise ValueError("Non-finite number")
    return Fraction(decimal)


def _integer_text(value):
    """Avoid Python's configurable large-int string digit limit."""
    if value == 0:
        return "0"
    sign = "-" if value < 0 else ""
    value = abs(value)
    chunks = []
    while value:
        value, remainder = divmod(value, 10 ** 9)
        chunks.append(remainder)
    return (
        sign + str(chunks[-1])
        + "".join("{:09d}".format(part) for part in reversed(chunks[:-1]))
    )


def _rational_text(value):
    value = _number(value)
    numerator = _integer_text(value.numerator)
    if value.denominator == 1:
        return numerator
    return numerator + "/" + _integer_text(value.denominator)


def _integer(value, name):
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(name + " must be an integer")
    return value


def _hour(value, name):
    value = _integer(value, name)
    if value % HOUR:
        raise ValueError(name + " must be hour-aligned")
    return value


def _boundary(timestamp):
    return -(-timestamp // HOUR) * HOUR


def _bounded(value, low, high, name, upper_inclusive=True):
    value = _number(value)
    if value < low or (value > high if upper_inclusive else value >= high):
        raise ValueError(name + " outside permitted range")
    return value


def _rate(value, name):
    if value is None:
        return None
    return _bounded(value, ZERO, ONE, name, upper_inclusive=False)


def _flat_cells(value):
    if value is None:
        return None
    result = {}
    for tier in TIERS:
        if tier not in value or value[tier] is None:
            return None
        result[tier] = _rate(value[tier], "cost cell")
    return result


def _cells(value):
    if value is None:
        return None
    if any(side in value for side in SIDES):
        result = {
            side: _flat_cells(value.get(side))
            for side in SIDES
        }
        return result if any(table is not None for table in result.values()) else None
    return _flat_cells(value)


def _side_cells(cells, side):
    if cells is None:
        return None
    if any(name in cells for name in SIDES):
        return cells.get(side)
    return cells


def _copy_cells(cells):
    if cells is None:
        return None
    if any(side in cells for side in SIDES):
        return {
            side: None if cells.get(side) is None else dict(cells[side])
            for side in SIDES
        }
    return dict(cells)


def _initial(initial):
    return {
        "time": _hour(initial["time"], "initial.time"),
        "cash": _number(initial["cash"]),
    }


def _registrations(theses, start):
    result = []
    seen = set()
    previous = start
    for row in theses:
        ident = row["id"]
        if not isinstance(ident, str) or not ident or ident in seen:
            raise ValueError("Thesis ids must be nonempty and unique")
        seen.add(ident)
        tr = _integer(row["t_r"], "t_r")
        if tr < previous:
            raise ValueError("Theses must be in registration commit order")
        previous = tr

        horizon = _integer(row["T"], "T")
        if horizon % DAY or not 72 * HOUR <= horizon - tr <= 1440 * HOUR:
            raise ValueError("Invalid thesis horizon")
        loss = _bounded(row["L"], Fraction(1, 100), Fraction(1, 2), "L")
        probability = _bounded(
            row["p"], Fraction(1, 100), Fraction(99, 100), "p"
        )
        notional = _number(row["N"])
        size = _number(row["size"])
        reserve = _number(row["b"])
        if notional < ZERO or size not in (ZERO, notional):
            raise ValueError("size must be zero or frozen nonnegative N")
        if reserve != (notional * loss if size > ZERO else ZERO):
            raise ValueError("Frozen reservation does not match size and L")

        legs = []
        for raw in row["legs"]:
            market = raw["market"]
            weight = raw["w"]
            if not isinstance(market, str) or not market:
                raise ValueError("Invalid market")
            if isinstance(weight, bool) or weight not in (-1, 1):
                raise ValueError("Invalid leg weight")
            if not isinstance(raw["cost_fallback"], bool):
                raise ValueError("cost_fallback must be Boolean")
            legs.append({
                "market": market,
                "w": weight,
                "fee": _rate(raw["fee"], "fee"),
                "cells": _cells(raw["cells"]),
                "cost_fallback": raw["cost_fallback"],
            })
        if len(legs) not in (1, 2):
            raise ValueError("Expected one or two legs")
        if len(legs) == 2:
            if (legs[0]["market"] == legs[1]["market"]
                    or {leg["w"] for leg in legs} != {-1, 1}):
                raise ValueError("A spread needs distinct opposite legs")
        result.append({
            "id": ident,
            "t_r": tr,
            "T": horizon,
            "L": loss,
            "p": probability,
            "N": notional,
            "size": size,
            "b": reserve,
            "legs": legs,
        })
    return result


def _decisions(exits, registrations, now):
    by_id = {row["id"]: row for row in registrations}
    result = {}
    previous = None
    for order, decision in enumerate(exits):
        ident = decision["id"]
        if ident not in by_id:
            raise ValueError("Exit refers to an unknown thesis")
        timestamp = _integer(decision["time"], "exit.time")
        if previous is not None and timestamp < previous:
            raise ValueError("Exits must be in commit order")
        previous = timestamp
        if timestamp < by_id[ident]["t_r"]:
            raise ValueError("Exit precedes registration")
        if not isinstance(decision["reason"], str):
            raise ValueError("Exit reason must be a string")
        if timestamp <= now:
            result.setdefault(ident, []).append({
                "time": timestamp,
                "reason": decision["reason"],
                "order": order,
            })
    return result


class _Data:
    def __init__(self, data, markets, cutoff):
        self.cutoff = cutoff
        self.bars = {}
        self.hours = {}
        self.funding = {}
        self.lag = {}
        for market in markets:
            lag = _integer(data["lag"][market], "lag")
            if not 0 <= lag < HOUR:
                raise ValueError("lag must be in [0,3600)")
            self.lag[market] = lag

            bars = {}
            for timestamp, pair in data.get("bars", {}).get(market, {}).items():
                timestamp = _hour(timestamp, "bar time")
                opening = _number(pair[0])
                closing = None if pair[1] is None else _number(pair[1])
                if opening <= ZERO or (closing is not None and closing <= ZERO):
                    raise ValueError("Prices must be positive")
                bars[timestamp] = (opening, closing)
            self.bars[market] = bars
            self.hours[market] = sorted(bars)
            self.funding[market] = {
                _hour(timestamp, "funding time"): _number(rate)
                for timestamp, rate in
                data.get("funding", {}).get(market, {}).items()
            }

    def first_open(self, market, threshold, cutoff):
        cutoff = min(cutoff, self.cutoff)
        lag = self.lag[market]
        for timestamp in self.hours[market]:
            if timestamp >= threshold and timestamp + lag <= cutoff:
                return {
                    "time": timestamp,
                    "reference": self.bars[market][timestamp][0],
                    "available_at": timestamp + lag,
                }
        return None

    def mark(self, market, timestamp, cutoff):
        """Latest available open/close; current open wins a timestamp tie."""
        cutoff = min(cutoff, self.cutoff)
        best = None
        lag = self.lag[market]
        for opening_time in self.hours[market]:
            opening, closing = self.bars[market][opening_time]
            candidates = [(opening_time, 1, opening)]
            if closing is not None:
                candidates.append((opening_time + HOUR, 0, closing))
            for price_time, priority, price in candidates:
                if price_time <= timestamp and price_time + lag <= cutoff:
                    candidate = (price_time, priority, price)
                    if best is None or candidate[:2] > best[:2]:
                        best = candidate
        if best is None:
            raise MissingData("missing_account_mark")
        return {
            "time": best[0],
            "price": best[2],
            "stale": best[0] < timestamp,
        }

    def funding_value(self, market, timestamp, unit_q, cutoff):
        cutoff = min(cutoff, self.cutoff)
        lag = self.lag[market]

        # An unavailable current reference is not yet an established gap.
        if timestamp + lag > cutoff:
            raise MissingData(
                "funding_reference_pending:{}".format(timestamp)
            )
        if timestamp > cutoff or timestamp not in self.funding[market]:
            raise MissingData("missing_funding_row:{}".format(timestamp))

        selected = None
        for opening_time in self.hours[market]:
            if opening_time > timestamp:
                break
            selected = opening_time
        if selected is None:
            raise MissingData(
                "missing_funding_reference:{}".format(timestamp)
            )

        opening, closing = self.bars[market][selected]
        reference = opening
        reference_time = selected
        reference_kind = "open"
        if (selected < timestamp and selected + HOUR <= timestamp
                and closing is not None
                and selected + HOUR + lag <= cutoff):
            reference = closing
            reference_time = selected + HOUR
            reference_kind = "close"

        rate = self.funding[market][timestamp]
        return {
            "hour": timestamp,
            "rate": rate,
            "reference": reference,
            "reference_time": reference_time,
            "reference_kind": reference_kind,
            "reference_fallback": selected < timestamp,
            "per_N": -unit_q * reference * rate,
        }


def _require_terms(leg, side):
    if leg["fee"] is None:
        raise MissingData("missing_frozen_fee")
    cells = _side_cells(leg["cells"], side)
    if cells is None:
        raise MissingData("missing_frozen_cost_cells:" + side)
    return cells


def _entry_fill(leg, notional, reference):
    if reference is None:
        return None
    result = dict(reference)

    # Quantity is determined by the reference, not by the adverse fill.
    unit_q = Fraction(leg["w"]) / reference["reference"]
    result["unit_q"] = unit_q
    try:
        side = "buy" if unit_q > ZERO else "sell"
        cells = _require_terms(leg, side)
        reference_notional = abs(unit_q) * notional * reference["reference"]
        tier = "1000" if reference_notional <= 1000 else "10000"
        cost = cells[tier]
        price = reference["reference"] * (ONE + leg["w"] * cost)
        result.update({
            "price": price,
            "tier": tier,
            "fee_per_N": abs(unit_q) * price * leg["fee"],
            "execution_cost_per_N":
                abs(unit_q) * reference["reference"] * cost,
        })
    except MissingData as exc:
        result["error"] = str(exc)
    return result


def _exit_fill(leg, notional, entry, reference, action):
    if reference is None:
        return None
    result = dict(reference)
    result.update({
        "reason": action["reason"],
        "actionable_at": action["threshold"],
        "decision_time": action.get("decision_time"),
        "decision_reason": action.get("decision_reason"),
        "invalidating_bar_end": action.get("bar_end"),
    })
    try:
        if entry is None:
            raise MissingData("entry_quantity_unavailable")
        unit_q = entry["unit_q"]
        side = "buy" if -unit_q > ZERO else "sell"
        cells = _require_terms(leg, side)
        reference_notional = abs(unit_q) * notional * reference["reference"]
        tier = "1000" if reference_notional <= 1000 else "10000"
        cost = cells[tier]
        price = reference["reference"] * (ONE - leg["w"] * cost)
        result.update({
            "price": price,
            "tier": tier,
            "fee_per_N": abs(unit_q) * price * leg["fee"],
            "execution_cost_per_N":
                abs(unit_q) * reference["reference"] * cost,
        })
    except MissingData as exc:
        result["error"] = str(exc)
    return result


def _plan(thesis, decisions, data, now, managed):
    entries = [
        _entry_fill(
            leg,
            thesis["N"],
            data.first_open(leg["market"], thesis["t_r"] + DELTA, now),
        )
        for leg in thesis["legs"]
    ]
    actions = [{
        "threshold": thesis["T"],
        "priority": 2,
        "order": 0,
        "reason": "horizon",
    }]
    if managed:
        for decision in decisions:
            actions.append({
                "threshold": decision["time"] + DELTA,
                "priority": 1,
                "order": decision["order"],
                "reason": "discretionary",
                "decision_time": decision["time"],
                "decision_reason": decision["reason"],
            })

        # Costs, fees and funding do not affect invalidation or its inputs.
        if all(entry is not None for entry in entries):
            ends = None
            for leg in thesis["legs"]:
                market = leg["market"]
                available = {
                    timestamp + HOUR
                    for timestamp, pair in data.bars[market].items()
                    if pair[1] is not None
                    and timestamp + HOUR + data.lag[market] <= data.cutoff
                }
                ends = available if ends is None else ends & available

            last_entry = max(entry["time"] for entry in entries)
            for boundary in sorted(ends or ()):
                if boundary <= last_entry:
                    continue
                gross = sum((
                    leg["w"] * (
                        data.bars[leg["market"]][boundary - HOUR][1]
                        / entry["reference"] - ONE
                    )
                    for leg, entry in zip(thesis["legs"], entries)
                ), ZERO)
                if gross <= -thesis["L"]:
                    actionable = max(
                        [boundary + DELTA]
                        + [
                            boundary + data.lag[leg["market"]]
                            for leg in thesis["legs"]
                        ]
                    )
                    actions.append({
                        "threshold": actionable,
                        "priority": 0,
                        "order": boundary,
                        "reason": "invalidation",
                        "bar_end": boundary,
                    })
                    break

    # Priority breaks identical actionable timestamps, not merely exits
    # that happen to round to the same hourly boundary.
    action = min(
        actions,
        key=lambda item: (
            item["threshold"], item["priority"], item["order"]
        ),
    )
    effective = _boundary(action["threshold"])
    earliest_entry = _boundary(thesis["t_r"] + DELTA)
    paths = []

    for leg, entry in zip(thesis["legs"], entries):
        market = leg["market"]
        suppressed = False
        suppression_time = None

        if managed and effective <= now:
            if entry is not None:
                suppressed = entry["time"] >= effective
            else:
                # With an earlier data cutoff, do not mistake an opening
                # opportunity that has not reached its lag for a missing one.
                prior_opportunities_reached = (
                    earliest_entry >= effective
                    or effective - HOUR + data.lag[market] <= data.cutoff
                )
                suppressed = prior_opportunities_reached
            if suppressed:
                suppression_time = effective

        if managed and suppressed:
            exit_fill = None
        else:
            reference = data.first_open(market, action["threshold"], now)
            exit_fill = _exit_fill(
                leg, thesis["N"], entry, reference, action
            )
            if not managed:
                suppressed = (
                    exit_fill is not None
                    and (entry is None or entry["time"] >= exit_fill["time"])
                )

        paths.append({
            "leg": leg,
            "entry": entry,
            "exit": exit_fill,
            "suppressed": suppressed,
            "suppression_time": suppression_time,
        })

    released = None
    if managed and thesis["size"] > ZERO:
        completed = []
        for path in paths:
            if path["suppressed"]:
                completed.append(path["suppression_time"])
            elif path["entry"] is not None and path["exit"] is not None:
                # Closing-reference availability, not funding or net-PnL
                # completeness, determines this leg's reservation release.
                completed.append(path["exit"]["available_at"])
            else:
                break
        else:
            released = max(completed)

    return {
        "thesis": thesis,
        "paths": paths,
        "action": action,
        "effective_at": effective,
        "released_at": released,
    }


def _shown_fill(fill, quantity=None):
    if fill is None:
        return None
    result = dict(fill)
    if quantity is not None:
        # Preserve the original output convention: held signed quantity.
        result["quantity"] = quantity
    return result


def _view(plan, data, now, managed):
    thesis = plan["thesis"]
    fallbacks = sorted({
        leg["market"] for leg in thesis["legs"] if leg["cost_fallback"]
    })
    if managed and thesis["size"] == ZERO:
        return {
            "status": "not_funded",
            "legs": [],
            "return": None,
            "reasons": ["size_zero_no_actual_managed_position"],
            "cost_fallback_markets": fallbacks,
        }

    reasons = []
    shown = []
    price_pnl = ZERO
    funding = ZERO
    fees = ZERO
    execution_costs = ZERO

    for path in plan["paths"]:
        leg = path["leg"]
        market = leg["market"]
        entry, exit_fill = path["entry"], path["exit"]
        unit_q = None if entry is None else entry["unit_q"]
        quantity = None if unit_q is None else unit_q * thesis["N"]
        public = {
            "market": market,
            "w": leg["w"],
            "entry": _shown_fill(entry, quantity),
            "exit": _shown_fill(exit_fill, quantity),
            "funding": [],
            "cost_fallback": leg["cost_fallback"],
        }
        shown.append(public)

        if managed and path["suppressed"]:
            public["scheduled_entry"] = public["entry"]
            public["closing_opportunity"] = public["exit"]
            public["entry"] = None
            public["exit"] = None
            public["pending_entry_suppressed"] = True
            public["suppressed_at"] = path["suppression_time"]
            # No price, fee, or funding is needed for a leg never opened.
            continue

        if entry is None:
            label = (
                "entry_pending"
                if data.cutoff < (
                    _boundary(thesis["t_r"] + DELTA) + data.lag[market]
                )
                else "missing_entry_open"
            )
            reasons.append("{}:{}".format(market, label))
        elif "error" in entry:
            reasons.append("{}:{}".format(market, entry["error"]))

        if exit_fill is None:
            label = (
                "exit_pending"
                if data.cutoff < (
                    _boundary(plan["action"]["threshold"]) + data.lag[market]
                )
                else "missing_exit_open"
            )
            reasons.append("{}:{}".format(market, label))
        elif "error" in exit_fill:
            reasons.append("{}:{}".format(market, exit_fill["error"]))

        if path["suppressed"]:
            reasons.append("{}:entry_not_before_exit".format(market))
            continue
        if (entry is None or exit_fill is None
                or "error" in entry or "error" in exit_fill):
            continue

        price_pnl += unit_q * (exit_fill["price"] - entry["price"])
        fees += entry["fee_per_N"] + exit_fill["fee_per_N"]
        execution_costs += (
            entry["execution_cost_per_N"]
            + exit_fill["execution_cost_per_N"]
        )
        for hour in range(
            entry["time"] + HOUR, exit_fill["time"] + HOUR, HOUR
        ):
            try:
                item = data.funding_value(market, hour, unit_q, now)
                public["funding"].append(item)
                funding += item["per_N"]
            except MissingData as exc:
                reasons.append("{}:{}".format(market, exc))

    net = None if reasons else price_pnl + funding - fees
    return {
        "status": "resolved" if net is not None else "unresolved",
        "legs": shown,
        "return": net,
        "reasons": reasons,
        "price_pnl_per_N": price_pnl if net is not None else None,
        "funding_per_N": funding if net is not None else None,
        "fees_per_N": fees if net is not None else None,
        # Informational: already included through adverse fill prices.
        "execution_costs_per_N":
            execution_costs if net is not None else None,
        "cost_fallback_markets": fallbacks,
    }


def _reserved(plans, timestamp):
    return sum((
        plan["thesis"]["b"]
        for plan in plans
        if plan["thesis"]["t_r"] <= timestamp
        and (
            plan["released_at"] is None
            or timestamp < plan["released_at"]
        )
    ), ZERO)


def _events(plans, data, now):
    events = []

    def add(timestamp, available, phase, order, ident, market,
            realized=ZERO, funding=ZERO, fees=ZERO, costs=ZERO, error=None):
        events.append({
            "time": timestamp,
            "available_at": available,
            "phase": phase,
            "order": order,
            "id": ident,
            "market": market,
            "realized": realized,
            "funding": funding,
            "fees": fees,
            "execution_costs": costs,
            "error": error,
        })

    for commit_order, plan in enumerate(plans):
        thesis = plan["thesis"]
        if thesis["size"] == ZERO:
            continue
        size = thesis["size"]

        for leg_order, path in enumerate(plan["paths"]):
            leg = path["leg"]
            market = leg["market"]
            entry, exit_fill = path["entry"], path["exit"]
            order = (commit_order, leg_order)
            if entry is None or path["suppressed"]:
                continue

            if "error" in entry:
                add(
                    entry["time"], entry["available_at"], 2, order,
                    thesis["id"], market, error=entry["error"],
                )
            else:
                add(
                    entry["time"], entry["available_at"], 2, order,
                    thesis["id"], market,
                    fees=size * entry["fee_per_N"],
                    costs=size * entry["execution_cost_per_N"],
                )

            if exit_fill is not None:
                if "error" in entry or "error" in exit_fill:
                    add(
                        exit_fill["time"], exit_fill["available_at"], 1,
                        order, thesis["id"], market,
                        error=exit_fill.get(
                            "error", "entry_net_accounting_unavailable"
                        ),
                    )
                else:
                    add(
                        exit_fill["time"], exit_fill["available_at"], 1,
                        order, thesis["id"], market,
                        realized=size * entry["unit_q"] * (
                            exit_fill["price"] - entry["price"]
                        ),
                        fees=size * exit_fill["fee_per_N"],
                        costs=size * exit_fill["execution_cost_per_N"],
                    )

            end = min(
                now - now % HOUR,
                exit_fill["time"] if exit_fill is not None else now,
            )
            # Entry hour is excluded; exit hour is included.
            for hour in range(entry["time"] + HOUR, end + 1, HOUR):
                available = hour + data.lag[market]
                if available > data.cutoff:
                    continue
                try:
                    item = data.funding_value(
                        market, hour, entry["unit_q"], data.cutoff
                    )
                    add(
                        hour, available, 0, order, thesis["id"], market,
                        funding=size * item["per_N"],
                    )
                except MissingData as exc:
                    add(
                        hour, available, 0, order, thesis["id"], market,
                        error=str(exc),
                    )

    return sorted(
        events,
        key=lambda event: (
            event["time"], event["phase"], event["order"]
        ),
    )


def _required_lag(plans, data, hour):
    result = 0
    for plan in plans:
        thesis = plan["thesis"]
        if thesis["size"] == ZERO or thesis["t_r"] + DELTA > hour:
            continue
        for path in plan["paths"]:
            if (path["suppressed"]
                    and path["suppression_time"] is not None
                    and path["suppression_time"] <= hour):
                continue
            exit_fill = path["exit"]
            if exit_fill is None or hour <= exit_fill["time"]:
                result = max(result, data.lag[path["leg"]["market"]])
    return result


def _account(initial, plans, data, now):
    events = _events(plans, data, now)
    realized = funding = fees = execution_costs = ZERO
    cursor = 0
    first = {
        "time": initial["time"],
        "available_at": initial["time"],
        "equity": initial["cash"],
        "cash": initial["cash"],
        "realized_pnl": ZERO,
        "unrealized_pnl": ZERO,
        "funding": ZERO,
        "fees": ZERO,
        "execution_costs": ZERO,
        "reserved_risk": _reserved(plans, initial["time"]),
        "stale_marks": [],
        "errors": [],
    }
    hourly = [first]
    last_good = first

    for hour in range(
        initial["time"] + HOUR, now - now % HOUR + 1, HOUR
    ):
        available = hour + _required_lag(plans, data, hour)
        if available > data.cutoff:
            # Never skip an unreached hour and reconcile a later one.
            break

        errors = []
        while cursor < len(events) and events[cursor]["time"] <= hour:
            event = events[cursor]
            if event["available_at"] > available:
                raise AssertionError(
                    "Reconciliation preceded event availability"
                )
            cursor += 1
            realized += event["realized"]
            funding += event["funding"]
            fees += event["fees"]
            execution_costs += event["execution_costs"]
            if event["error"] is not None:
                errors.append({
                    "id": event["id"],
                    "market": event["market"],
                    "time": event["time"],
                    "reason": event["error"],
                })

        unrealized = ZERO
        stale = []
        for plan in plans:
            thesis = plan["thesis"]
            if thesis["size"] == ZERO:
                continue
            for path in plan["paths"]:
                entry, exit_fill = path["entry"], path["exit"]
                if (entry is None or path["suppressed"]
                        or entry["time"] > hour
                        or (exit_fill is not None
                            and exit_fill["time"] <= hour)):
                    continue
                if "error" in entry:
                    continue
                market = path["leg"]["market"]
                try:
                    mark = data.mark(market, hour, available)
                    unrealized += (
                        thesis["size"] * entry["unit_q"]
                        * (mark["price"] - entry["price"])
                    )
                    if mark["stale"]:
                        stale.append({
                            "id": thesis["id"],
                            "market": market,
                            "reference_time": mark["time"],
                        })
                except MissingData as exc:
                    errors.append({
                        "id": thesis["id"],
                        "market": market,
                        "time": hour,
                        "reason": str(exc),
                    })

        cash = initial["cash"] + realized + funding - fees
        equity = None if errors else cash + unrealized
        snapshot = {
            "time": hour,
            "available_at": available,
            "equity": equity,
            "cash": cash if not errors else None,
            "realized_pnl": realized if not errors else None,
            "unrealized_pnl": unrealized if not errors else None,
            "funding": funding if not errors else None,
            "fees": fees if not errors else None,
            "execution_costs": execution_costs if not errors else None,
            "reserved_risk": _reserved(plans, available),
            "stale_marks": stale,
            "errors": errors,
        }
        hourly.append(snapshot)
        if errors:
            # A missing funding row freezes all subsequent reconciliation
            # until a later supplied snapshot actually contains that row.
            break

        assert equity == (
            initial["cash"] + realized + unrealized + funding - fees
        )
        last_good = snapshot

    latest = hourly[-1]
    current_hour = now - now % HOUR
    if latest["equity"] is None:
        equity = None
        reason = "reconciliation_blocked_by_missing_required_data"
    elif latest["time"] != current_hour:
        equity = None
        reason = "current_hour_awaiting_reference_availability"
    else:
        equity = latest["equity"]
        reason = None

    return {
        "now": now,
        "cutoff": data.cutoff,
        "equity": equity,
        "equity_reason": reason,
        "equity_time": latest["time"] if equity is not None else None,
        "reserved_risk": _reserved(plans, now),
        "latest_reconciled": dict(last_good),
        "hourly": hourly,
    }


def replay(initial, theses, exits, data, now):
    """Replay frozen accepted registrations without recomputing their sizes."""
    initial = _initial(initial)
    now = _integer(now, "now")
    if now < initial["time"]:
        raise ValueError("now precedes initial account")
    cutoff = _integer(data.get("cutoff", now), "data.cutoff")
    if not initial["time"] <= cutoff <= now:
        raise ValueError("cutoff must lie between initial.time and now")

    all_theses = _registrations(theses, initial["time"])
    decisions = _decisions(exits, all_theses, now)
    active = [thesis for thesis in all_theses if thesis["t_r"] <= now]
    markets = {
        leg["market"] for thesis in active for leg in thesis["legs"]
    }
    prices = _Data(data, markets, cutoff)
    plans = []
    results = []

    for thesis in active:
        managed_plan = _plan(
            thesis, decisions.get(thesis["id"], []), prices, now, True
        )
        registered_plan = _plan(thesis, [], prices, now, False)
        plans.append(managed_plan)
        managed = _view(managed_plan, prices, now, True)
        registered = _view(registered_plan, prices, now, False)
        net = registered["return"]
        outcome = None if net is None else int(net > ZERO)
        registered["outcome"] = outcome
        registered["brier"] = (
            None if outcome is None else (thesis["p"] - outcome) ** 2
        )
        results.append({
            "id": thesis["id"],
            "N": thesis["N"],
            "size": thesis["size"],
            "b": thesis["b"],
            "funded": thesis["size"] > ZERO,
            "reservation_released_at": managed_plan["released_at"],
            "cost_fallback_markets": registered["cost_fallback_markets"],
            "managed": managed,
            "as_registered": registered,
        })

    return {
        "theses": results,
        "account": _account(initial, plans, prices, now),
    }


def _freeze_terms(data):
    supplied = data.get("terms", {})
    universe = list(data.get("U", []))
    normalized = {}
    for market, terms in supplied.items():
        normalized[market] = {
            "fee": _rate(terms.get("fee"), "fee"),
            "cells": _cells(terms.get("cells")),
        }

    fallback = {}
    for side in SIDES:
        tables = [
            _side_cells(normalized.get(market, {}).get("cells"), side)
            for market in universe
        ]
        fallback[side] = (
            {
                tier: max(table[tier] for table in tables)
                for tier in TIERS
            }
            if tables and all(table is not None for table in tables)
            else None
        )

    markets = (
        set(supplied)
        | set(data.get("bars", {}))
        | set(data.get("lag", {}))
    )
    frozen = {}
    for market in sorted(markets):
        terms = normalized.get(market, {"fee": None, "cells": None})
        directional = {}
        uses_fallback = False
        for side in SIDES:
            table = _side_cells(terms["cells"], side)
            if table is None:
                uses_fallback = True
                table = fallback[side]
            directional[side] = None if table is None else dict(table)

        if not uses_fallback:
            cells = _copy_cells(terms["cells"])
        elif all(directional[side] is None for side in SIDES):
            cells = None
        elif directional["buy"] == directional["sell"]:
            cells = dict(directional["buy"])
        else:
            cells = directional

        frozen[market] = {
            "fee": terms["fee"],
            "cells": cells,
            "cost_fallback": uses_fallback,
        }
    return frozen


def admit(initial, theses, exits, data, t_r, L):
    """
    Propose sizing against preceding committed reservations.

    The caller serializes this operation with registration, provides the
    actual data-read cutoff for a delayed read, and persists "record".
    Exposure eligibility and its commit-time venue read remain host duties.
    """
    t_r = _integer(t_r, "t_r")
    loss = _bounded(L, Fraction(1, 100), Fraction(1, 2), "L")
    if any(_integer(thesis["t_r"], "t_r") > t_r for thesis in theses):
        raise ValueError("admit received a later registration")

    report = replay(initial, theses, exits, data, t_r)
    account = report["account"]
    reconciled = account["latest_reconciled"]
    equity = reconciled["equity"]
    reserved = account["reserved_risk"]
    initial_account = _initial(initial)

    if equity <= ZERO:
        if initial_account["cash"] <= ZERO:
            raise ValueError(
                "Nonpositive initial equity has no specified "
                "positive hypothetical notional"
            )
        budget = ZERO
        notional = Fraction(1, 100) * initial_account["cash"] / loss
        size = reservation = ZERO
        admitted = False
        reason = "nonpositive_reconciled_equity"
        cap = Fraction(5, 100) * equity
    else:
        budget = Fraction(1, 100) * equity
        notional = budget / loss
        cap = Fraction(5, 100) * equity
        admitted = reserved + budget <= cap
        size = notional if admitted else ZERO
        reservation = budget if admitted else ZERO
        reason = "admitted" if admitted else "concurrent_risk_cap"

    open_reservations = [
        {"id": thesis["id"], "b": thesis["b"]}
        for thesis in report["theses"]
        if thesis["b"] > ZERO
        and (
            thesis["reservation_released_at"] is None
            or t_r < thesis["reservation_released_at"]
        )
    ]
    assert sum((item["b"] for item in open_reservations), ZERO) == reserved

    reconciled_hour = (
        None
        if reconciled["time"] == initial_account["time"]
        else reconciled["time"]
    )
    record = {
        "t_r": t_r,
        "cutoff": account["cutoff"],
        "L": _rational_text(loss),
        "E_r": _rational_text(equity),
        "budget": _rational_text(budget),
        "N": _rational_text(notional),
        "size": _rational_text(size),
        "b": _rational_text(reservation),
        "reserved_before": _rational_text(reserved),
        "cap": _rational_text(cap),
        "reconciled_hour": reconciled_hour,
        "equity_available_at": reconciled["available_at"],
        "open_reservations": [
            {"id": item["id"], "b": _rational_text(item["b"])}
            for item in open_reservations
        ],
        "admitted": admitted,
        "reason": reason,
    }
    return {
        "t_r": t_r,
        "cutoff": account["cutoff"],
        "L": loss,
        "E_r": equity,
        "budget": budget,
        "N": notional,
        "size": size,
        "b": reservation,
        "admitted": admitted,
        "reason": reason,
        "reserved_before": reserved,
        "open_reservations": open_reservations,
        "cap": cap,
        "equity_time": reconciled["time"],
        "equity_available_at": reconciled["available_at"],
        "reconciled_hour": reconciled_hour,
        "terms": _freeze_terms(data),
        "record": record,
    }
