"""Position management: GPT's independent implementation, written by GPT 6.1 Sol from the stage 10 criteria and positions.py's data shape alone, tools denied (~/.cache/mm-gpt/positions-fWkk), 2026-11-02 06:43 UTC (01:43 EST). Committed verbatim below this note; its list of what the spec leaves open is in its own docstring."""

"""
Self-contained, standard-library-only paper-position replay.

Public API
----------
replay(initial, theses, exits, data, now)
admit(initial, theses, exits, data, t_r, L)

INPUT CONTRACT
--------------
All timestamps are integer Unix seconds in UTC. Hour boundaries are multiples
of 3600; UTC midnights are multiples of 86400. No datetime objects are accepted.

Numbers may be int, finite float, Decimal, Fraction, or decimal string.
Floats are interpreted through str(value). Returned monetary amounts, prices,
quantities, rates, and returns are exact fractions.Fraction objects. No
rounding is performed.

initial:
    {
        "time": hour-aligned timestamp,
        "cash": number                 # normally 10000
    }
    There are no positions or liabilities before initial["time"].

theses:
    A list of already accepted registrations, in atomic commit order.
    Equal t_r values retain list order. Each item is:
    {
        "id": nonempty unique string,
        "t_r": timestamp,              # daemon-assigned commit time
        "T": UTC-midnight timestamp,
        "L": number,                  # [0.01, 0.50]
        "p": number,                  # [0.01, 0.99]
        "N": number,                  # frozen hypothetical per-leg notional
        "size": number,               # N if funded, otherwise 0
        "b": number,                  # actual reservation: N*L or 0
        "legs": [
            {
                "market": nonempty string,
                "w": +1 or -1,
                "fee": number or None,
                "cells": {
                    "1000": number,
                    "10000": number
                } or None,
                "cost_fallback": bool
            },
            ...
        ]
    }
    There is one leg, or two distinct markets with weights +1 and -1.
    fee and cells are fractional rates, not basis points, and lie in [0,1).
    None means a required frozen input is missing, not zero.
    A size-zero thesis retains its hypothetical N. For nonpositive sizing
    equity, admit returns N=size=b=0.

exits:
    A list of append-only committed decisions, in commit order:
    {
        "id": thesis id,
        "time": daemon-assigned commit timestamp,
        "reason": string
    }
    Multiple decisions are permitted; none alters a registration.

data:
    {
        "bars": {
            market: {
                hour: (positive_open, positive_close_or_None),
                ...
            },
            ...
        },
        "funding": {
            market: {
                settled_hour: finite_fractional_rate,
                ...
            },
            ...
        },
        "lag": {
            market: integer_seconds_in_[0,3600),
            ...
        },

        # The following fields are used only by admit to return a terms
        # snapshot for the adapter to copy into the new registration:
        "terms": {
            market: {
                "fee": fractional_rate_or_None,
                "cells": {"1000": rate, "10000": rate} or None
            },
            ...
        },
        "U": [market, ...]
    }
    Missing bars, funding rows, fees, and cells are missing data.
    Core lag is normally 120; builder lag is normally 300.
    Bars are already adapted: a builder open is its sealed M_m(H), and its
    close is M_m(H+3600) or None. This module does not reconstruct samples.
    For decisions an open at H is available at H+lag[market], and a bar's
    close at H+3600 is available at H+3600+lag[market].
    Funding rows are treated as available at their settlement timestamps.

admit returns:
    E_r, budget, N, size, b, admitted, reason, reserved_before,
    cap, equity_time, equity_available_at, and a frozen "terms" mapping.
    The caller supplies the exposure separately and copies the corresponding
    terms into its registration. The signature has no exposure argument.

replay returns:
    {
        "theses": [
            {
                "id", "N", "size", "b", "funded",
                "reservation_released_at",
                "cost_fallback_markets",
                "managed": {
                    "legs": [... entry/exit fills ...],
                    "return": Fraction or None,
                    "reasons": [...],
                    ...
                },
                "as_registered": {
                    "legs": [... hypothetical entry/horizon fills ...],
                    "return": Fraction or None,
                    "outcome": 0, 1, or None,
                    "brier": Fraction or None,
                    "reasons": [...],
                    ...
                }
            }, ...
        ],
        "account": {
            "now",
            "equity": Fraction or None,
            "equity_reason",
            "reserved_risk",
            "latest_reconciled": {...},
            "hourly": [...]
        }
    }

UNDETERMINED BEHAVIORS: CHOICES AND REASONS
-----------------------------------------
1. This is a pure replay of accepted registrations, not a daemon, eligibility
   checker, ledger, sample sealer, or baseline scorer. The adapter supplies
   validated registrations and sealed bars; those services need inputs and
   persistence absent from this API.
2. Numeric arithmetic is exact rational arithmetic without rounding. Prices
   and costs can otherwise change cap decisions or the sign of a zero return.
3. Spread legs fill independently at their own first available openings.
   Invalidation starts only after every leg has entered and uses closes
   strictly later than every entry boundary, following "each leg" literally.
4. Entry P_e is the adverse execution price. Execution costs are represented
   by adverse fills, not also debited a second time; fees use executed
   notional. This follows the supplied data-shape's fill convention.
5. Entry quantity and its cost tier form an implicit equation. All
   self-consistent tiers are tested; if both work, "1000" wins; if neither
   works, the fill's price and dependent results remain unresolved. This
   avoids silently violating either the quantity or tier rule.
6. Hypothetical cost tiers use frozen N even for size-zero theses. N=0 uses
   the "1000" tier and the per-unit limiting position. Size-zero theses have
   no actual managed return, but retain their hypothetical outcome.
7. The earliest actionable exit threshold wins. Equal thresholds prioritize
   invalidation, discretionary exit, then horizon; discretionary ties retain
   commit order. This supplies the unspecified reason-label tie break.
8. An exit opportunity before or simultaneous with a leg's entry suppresses
   that pending leg rather than opening exposure after its exit. Its return
   remains unresolved under e>=x. This is not cancellation of the thesis.
9. A reservation is released when every leg's closing or pending-suppression
   reference is available, not retroactively at its boundary. Missing
   funding can leave equity unresolved but does not keep a closed position's
   reservation alive.
10. Funding requires every row in (e,x], including zero-rate rows. Valuation
    uses that hour's opening reference, otherwise the latest earlier opening
    reference, never a close. Funding rates are available at settlement;
    valuation waits for the reference's availability.
11. Account marks use the latest available open or non-null close, preferring
    an open at an identical price timestamp; stale marks are reported.
    Fills and invalidation never use this fallback. This makes the otherwise
    unspecified marking policy explicit.
12. Hourly reconciliation waits for the largest required leg lag for that
    hour. There is no intra-hour reconciliation. Sizing uses the latest
    successfully reconciled hour; current-hour equity is None while its
    reconciliation is unavailable or incomplete. The initial cash snapshot
    is reconciled immediately.
13. admit is a pure proposal: the caller must serialize admit plus append.
    Existing rows are the preceding commits, including equal-time commits.
    It snapshots all supplied markets because its signature has no exposure.
    Missing coin cells use per-tier maxima over explicit U; unavailable
    fallback inputs remain missing instead of being invented.
"""

from decimal import Decimal, InvalidOperation
from fractions import Fraction

HOUR = 3600
DAY = 86400
DELTA = 120
ZERO = Fraction(0)
ONE = Fraction(1)
TIERS = ("1000", "10000")


class MissingData(Exception):
    """A required value cannot be determined from the supplied inputs."""


def _number(value):
    if isinstance(value, bool):
        raise ValueError("Boolean is not a numeric input")
    if isinstance(value, Fraction):
        return value
    if isinstance(value, int):
        return Fraction(value)
    try:
        d = value if isinstance(value, Decimal) else Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("Invalid number: {!r}".format(value)) from exc
    if not d.is_finite():
        raise ValueError("Non-finite number")
    return Fraction(d)


def _integer(value, name):
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(name + " must be an integer")
    return value


def _hour(value, name):
    value = _integer(value, name)
    if value % HOUR:
        raise ValueError(name + " must be hour-aligned")
    return value


def _bounded(value, low, high, name, upper_inclusive=True):
    value = _number(value)
    if value < low or (value > high if upper_inclusive else value >= high):
        raise ValueError(name + " outside permitted range")
    return value


def _rate(value, name):
    if value is None:
        return None
    return _bounded(value, ZERO, ONE, name, upper_inclusive=False)


def _cells(value):
    if value is None:
        return None
    result = {}
    for tier in TIERS:
        if tier not in value or value[tier] is None:
            return None
        result[tier] = _rate(value[tier], "cost cell")
    return result


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
        if notional < 0 or size not in (ZERO, notional):
            raise ValueError("size must be zero or frozen nonnegative N")
        if reserve != (notional * loss if size > 0 else ZERO):
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
            "id": ident, "t_r": tr, "T": horizon, "L": loss,
            "p": probability, "N": notional, "size": size,
            "b": reserve, "legs": legs,
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
                "time": timestamp, "reason": decision["reason"],
                "order": order,
            })
    return result


class _Data:
    def __init__(self, data, markets):
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
                if opening <= 0 or (closing is not None and closing <= 0):
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
            "time": best[0], "price": best[2],
            "stale": best[0] < timestamp,
        }

    def funding_value(self, market, timestamp, unit_q, cutoff):
        if timestamp not in self.funding[market]:
            raise MissingData("missing_funding_row:{}".format(timestamp))
        selected = None
        for opening_time in self.hours[market]:
            if opening_time > timestamp:
                break
            if opening_time + self.lag[market] <= cutoff:
                selected = opening_time
        if selected is None:
            raise MissingData("missing_funding_reference:{}".format(timestamp))
        reference = self.bars[market][selected][0]
        return {
            "hour": timestamp,
            "rate": self.funding[market][timestamp],
            "reference": reference,
            "reference_time": selected,
            "reference_fallback": selected < timestamp,
            "per_N": -unit_q * reference * self.funding[market][timestamp],
        }


def _require_terms(leg):
    if leg["fee"] is None:
        raise MissingData("missing_frozen_fee")
    if leg["cells"] is None:
        raise MissingData("missing_frozen_cost_cells")


def _entry_fill(leg, notional, reference):
    if reference is None:
        return None
    result = dict(reference)
    try:
        _require_terms(leg)
        candidates = []
        for tier in TIERS:
            cost = leg["cells"][tier]
            price = reference["reference"] * (ONE + leg["w"] * cost)
            unit_q = Fraction(leg["w"]) / price
            reference_notional = abs(unit_q) * notional * reference["reference"]
            actual_tier = "1000" if reference_notional <= 1000 else "10000"
            if actual_tier == tier:
                candidates.append((tier, cost, price, unit_q))
        if not candidates:
            raise MissingData("entry_cost_tier_has_no_fixed_point")
        tier, cost, price, unit_q = candidates[0]
        result.update({
            "price": price,
            "unit_q": unit_q,
            "tier": tier,
            "fee_per_N": abs(unit_q * price) * leg["fee"],
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
    result["reason"] = action["reason"]
    result["actionable_at"] = action["threshold"]
    result["decision_time"] = action.get("decision_time")
    result["decision_reason"] = action.get("decision_reason")
    result["invalidating_bar_end"] = action.get("bar_end")
    try:
        _require_terms(leg)
        if entry is None or "error" in entry:
            raise MissingData("entry_quantity_unavailable")
        unit_q = entry["unit_q"]
        reference_notional = abs(unit_q) * notional * reference["reference"]
        tier = "1000" if reference_notional <= 1000 else "10000"
        cost = leg["cells"][tier]
        price = reference["reference"] * (ONE - leg["w"] * cost)
        result.update({
            "price": price,
            "tier": tier,
            "fee_per_N": abs(unit_q * price) * leg["fee"],
            "execution_cost_per_N":
                abs(unit_q) * reference["reference"] * cost,
        })
    except MissingData as exc:
        result["error"] = str(exc)
    return result


def _plan(thesis, decisions, data, now, managed):
    entries = [
        _entry_fill(
            leg, thesis["N"],
            data.first_open(leg["market"], thesis["t_r"] + DELTA, now),
        )
        for leg in thesis["legs"]
    ]
    actions = [{
        "threshold": thesis["T"], "priority": 2, "order": 0,
        "reason": "horizon",
    }]
    if managed:
        for decision in decisions:
            actions.append({
                "threshold": decision["time"] + DELTA,
                "priority": 1, "order": decision["order"],
                "reason": "discretionary",
                "decision_time": decision["time"],
                "decision_reason": decision["reason"],
            })
        if all(entry is not None and "error" not in entry
               for entry in entries):
            ends = None
            for leg in thesis["legs"]:
                market = leg["market"]
                available = {
                    timestamp + HOUR
                    for timestamp, pair in data.bars[market].items()
                    if pair[1] is not None
                    and timestamp + HOUR + data.lag[market] <= now
                }
                ends = available if ends is None else ends & available
            last_entry = max(entry["time"] for entry in entries)
            for boundary in sorted(ends or ()):
                if boundary <= last_entry:
                    continue
                gross = sum((
                    leg["w"] * (
                        data.bars[leg["market"]][boundary - HOUR][1]
                        / entry["price"] - ONE
                    )
                    for leg, entry in zip(thesis["legs"], entries)
                ), ZERO)
                if gross <= -thesis["L"]:
                    actionable = max(
                        [boundary + DELTA] +
                        [boundary + data.lag[leg["market"]]
                         for leg in thesis["legs"]]
                    )
                    actions.append({
                        "threshold": actionable,
                        "priority": 0, "order": boundary,
                        "reason": "invalidation",
                        "bar_end": boundary,
                    })
                    break
    action = min(
        actions,
        key=lambda item: (
            item["threshold"], item["priority"], item["order"]
        ),
    )
    paths = []
    for leg, entry in zip(thesis["legs"], entries):
        reference = data.first_open(leg["market"], action["threshold"], now)
        exit_fill = _exit_fill(leg, thesis["N"], entry, reference, action)
        suppressed = (
            exit_fill is not None
            and (entry is None or entry["time"] >= exit_fill["time"])
        )
        paths.append({
            "leg": leg, "entry": entry, "exit": exit_fill,
            "suppressed": suppressed,
        })
    released = None
    if thesis["size"] > 0 and all(path["exit"] is not None for path in paths):
        released = max(path["exit"]["available_at"] for path in paths)
    return {
        "thesis": thesis, "paths": paths, "action": action,
        "released_at": released,
    }


def _shown_fill(fill, quantity=None):
    if fill is None:
        return None
    result = dict(fill)
    if quantity is not None:
        result["quantity"] = quantity
    return result


def _view(plan, data, now, managed):
    thesis = plan["thesis"]
    if managed and thesis["size"] == 0:
        return {
            "status": "not_funded",
            "legs": [],
            "return": None,
            "reasons": ["size_zero_no_actual_managed_position"],
            "cost_fallback_markets": sorted({
                leg["market"] for leg in thesis["legs"]
                if leg["cost_fallback"]
            }),
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
        unit_q = (
            entry["unit_q"]
            if entry is not None and "error" not in entry else None
        )
        quantity = None if unit_q is None else unit_q * thesis["N"]
        public = {
            "market": market,
            "w": leg["w"],
            "entry": _shown_fill(entry, quantity),
            "exit": _shown_fill(exit_fill, quantity),
            "funding": [],
            "cost_fallback": leg["cost_fallback"],
        }
        if managed and path["suppressed"]:
            public["scheduled_entry"] = public["entry"]
            public["closing_opportunity"] = public["exit"]
            public["entry"] = None
            public["exit"] = None
            public["pending_entry_suppressed"] = True
        shown.append(public)

        if entry is None:
            label = (
                "entry_pending"
                if now < thesis["t_r"] + DELTA + data.lag[market]
                else "missing_entry_open"
            )
            reasons.append("{}:{}".format(market, label))
        elif "error" in entry:
            reasons.append("{}:{}".format(market, entry["error"]))
        if exit_fill is None:
            label = (
                "exit_pending"
                if now < plan["action"]["threshold"] + data.lag[market]
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
        for hour in range(entry["time"] + HOUR,
                          exit_fill["time"] + HOUR, HOUR):
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
        # Informational only: already included through adverse fill prices.
        "execution_costs_per_N":
            execution_costs if net is not None else None,
        "cost_fallback_markets": sorted({
            leg["market"] for leg in thesis["legs"]
            if leg["cost_fallback"]
        }),
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
            "time": timestamp, "available_at": available,
            "phase": phase, "order": order,
            "id": ident, "market": market,
            "realized": realized, "funding": funding,
            "fees": fees, "execution_costs": costs,
            "error": error,
        })

    for commit_order, plan in enumerate(plans):
        thesis = plan["thesis"]
        if thesis["size"] == 0:
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
                continue
            add(
                entry["time"], entry["available_at"], 2, order,
                thesis["id"], market,
                fees=size * entry["fee_per_N"],
                costs=size * entry["execution_cost_per_N"],
            )
            if exit_fill is not None:
                if "error" in exit_fill:
                    add(
                        exit_fill["time"], exit_fill["available_at"], 1,
                        order, thesis["id"], market,
                        error=exit_fill["error"],
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
            for hour in range(entry["time"] + HOUR, end + 1, HOUR):
                available = hour + data.lag[market]
                if available > now:
                    continue
                try:
                    item = data.funding_value(
                        market, hour, entry["unit_q"], now
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
        if thesis["size"] == 0 or thesis["t_r"] + DELTA > hour:
            continue
        for path in plan["paths"]:
            exit_fill = path["exit"]
            if exit_fill is None or hour <= exit_fill["time"]:
                result = max(result, data.lag[path["leg"]["market"]])
    return result


def _account(initial, plans, data, now):
    events = _events(plans, data, now)
    realized = funding = fees = execution_costs = ZERO
    persistent_errors = []
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

    for hour in range(initial["time"] + HOUR,
                      now - now % HOUR + 1, HOUR):
        available = hour + _required_lag(plans, data, hour)
        if available > now:
            continue
        while cursor < len(events) and events[cursor]["time"] <= hour:
            event = events[cursor]
            if event["available_at"] > available:
                raise AssertionError("Reconciliation preceded event availability")
            cursor += 1
            realized += event["realized"]
            funding += event["funding"]
            fees += event["fees"]
            execution_costs += event["execution_costs"]
            if event["error"] is not None:
                persistent_errors.append({
                    "id": event["id"], "market": event["market"],
                    "time": event["time"], "reason": event["error"],
                })

        unrealized = ZERO
        errors = list(persistent_errors)
        stale = []
        for plan in plans:
            thesis = plan["thesis"]
            if thesis["size"] == 0:
                continue
            for path in plan["paths"]:
                entry, exit_fill = path["entry"], path["exit"]
                if (entry is None or path["suppressed"]
                        or entry["time"] > hour
                        or (exit_fill is not None
                            and exit_fill["time"] <= hour)):
                    continue
                if "error" in entry:
                    continue  # Its persistent error already prevents reconciliation.
                market = path["leg"]["market"]
                try:
                    mark = data.mark(market, hour, available)
                    unrealized += (
                        thesis["size"] * entry["unit_q"]
                        * (mark["price"] - entry["price"])
                    )
                    if mark["stale"]:
                        stale.append({
                            "id": thesis["id"], "market": market,
                            "reference_time": mark["time"],
                        })
                except MissingData as exc:
                    errors.append({
                        "id": thesis["id"], "market": market,
                        "time": hour, "reason": str(exc),
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
        if equity is not None:
            # Exact accounting identity, stronger than a dollar tolerance.
            assert equity == (
                initial["cash"] + realized + unrealized + funding - fees
            )
            last_good = snapshot

    latest = hourly[-1]
    current_hour = now - now % HOUR
    if latest["time"] != current_hour:
        equity = None
        reason = "current_hour_awaiting_reference_availability"
    elif latest["equity"] is None:
        equity = None
        reason = "current_hour_missing_required_data"
    else:
        equity = latest["equity"]
        reason = None
    return {
        "now": now,
        "equity": equity,
        "equity_reason": reason,
        "equity_time": latest["time"] if equity is not None else None,
        "reserved_risk": _reserved(plans, now),
        "latest_reconciled": dict(last_good),
        "hourly": hourly,
    }


def replay(initial, theses, exits, data, now):
    """Replay frozen accepted registrations without recomputing their sizing."""
    initial = _initial(initial)
    now = _integer(now, "now")
    if now < initial["time"]:
        raise ValueError("now precedes initial account")
    all_theses = _registrations(theses, initial["time"])
    decisions = _decisions(exits, all_theses, now)
    active = [thesis for thesis in all_theses if thesis["t_r"] <= now]
    markets = {
        leg["market"] for thesis in active for leg in thesis["legs"]
    }
    prices = _Data(data, markets)
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
            "funded": thesis["size"] > 0,
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

    fallback = None
    if universe and all(
        market in normalized and normalized[market]["cells"] is not None
        for market in universe
    ):
        fallback = {
            tier: max(normalized[market]["cells"][tier]
                      for market in universe)
            for tier in TIERS
        }

    markets = (
        set(supplied)
        | set(data.get("bars", {}))
        | set(data.get("lag", {}))
    )
    frozen = {}
    for market in sorted(markets):
        terms = normalized.get(market, {"fee": None, "cells": None})
        uses_fallback = terms["cells"] is None
        cells = fallback if uses_fallback else terms["cells"]
        frozen[market] = {
            "fee": terms["fee"],
            "cells": None if cells is None else dict(cells),
            "cost_fallback": uses_fallback,
        }
    return frozen


def admit(initial, theses, exits, data, t_r, L):
    """
    Propose sizing against all preceding committed reservations.

    The host must hold its registration transaction/lock across this call and
    appending the resulting registration. This function does not mutate input.
    It cannot validate a new exposure because none is supplied to this API.
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
    if equity <= ZERO:
        budget = notional = size = reservation = ZERO
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
    return {
        "t_r": t_r,
        "L": loss,
        "E_r": equity,
        "budget": budget,
        "N": notional,
        "size": size,
        "b": reservation,
        "admitted": admitted,
        "reason": reason,
        "reserved_before": reserved,
        "cap": cap,
        "equity_time": reconciled["time"],
        "equity_available_at": reconciled["available_at"],
        "terms": _freeze_terms(data),
    }
