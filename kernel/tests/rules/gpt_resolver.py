"""C7.6: GPT 6.1 Sol's independent implementation of the resolver of kernel/RULES.md §6 (and the rule language it applies),
written from RULES.md and the resolver case format alone, with tools denied (~/.cache/mm-gpt/resolver.BUJv). Committed verbatim below this note."""

"""Availability-rule resolver for RULES.md and RESOLVER_CASES.md.

resolve(case) accepts the documented case-dict schema.
Run this module to process one case per JSON line.
"""

import json
import re
import sys


MIN_TIME = -(1 << 62)
MAX_TIME = (1 << 62) - 1

_SURROGATE = re.compile(r"[\ud800-\udfff]")
_METADATA = frozenset(("fetchedAt", "source", "hash", "tombstone"))


class _BadJSON(Exception):
    pass


class _BadRule(Exception):
    pass


class _Reject(Exception):
    def __init__(self, code):
        self.code = code


class _Number:
    """A JSON number retained without floating-point conversion."""

    __slots__ = ("text", "integer")

    def __init__(self, text):
        self.text = text
        self.integer = not any(c in text for c in ".eE")


def _decimal_integer(text):
    """Parse an arbitrary-size decimal integer without digit-limit failures."""
    negative = text.startswith("-")
    if text[:1] in ("-", "+"):
        text = text[1:]

    result = 0
    for start in range(0, len(text), 9):
        part = text[start:start + 9]
        result = result * (10 ** len(part)) + int(part)
    return -result if negative else result


def _bad_constant(_):
    raise _BadJSON()


def _object_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _BadJSON()
        result[key] = value
    return result


def _check_depth(text):
    depth = 0
    quoted = False
    escaped = False

    for char in text:
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char in "[{":
            depth += 1
            if depth > 64:
                raise _BadJSON()
        elif char in "]}":
            depth -= 1


def _check_strings(value):
    pending = [value]
    while pending:
        item = pending.pop()
        if isinstance(item, str):
            if _SURROGATE.search(item):
                raise _BadJSON()
        elif isinstance(item, dict):
            pending.extend(item.keys())
            pending.extend(item.values())
        elif isinstance(item, list):
            pending.extend(item)


def _load_json(text, *, rule=False, native_integers=False):
    try:
        if isinstance(text, (bytes, bytearray)):
            raw = bytes(text)
            if rule and len(raw) > 65_536:
                raise _BadJSON()
            text = raw.decode("utf-8")
        elif isinstance(text, str):
            raw = text.encode("utf-8")
            if rule and len(raw) > 65_536:
                raise _BadJSON()
        else:
            raise _BadJSON()

        if text.startswith("\ufeff"):
            raise _BadJSON()

        _check_depth(text)
        value = json.loads(
            text,
            parse_int=_decimal_integer if native_integers else _Number,
            parse_float=_Number,
            parse_constant=_bad_constant,
            object_pairs_hook=_object_pairs,
        )
        _check_strings(value)
        return value
    except (ValueError, UnicodeError) as exc:
        raise _BadJSON() from exc


def _small_integer(value):
    """Return an in-range integer, or None for any other value."""
    if type(value) is int:
        number = value
    elif isinstance(value, _Number) and value.integer:
        if len(value.text.lstrip("-")) > 19:
            return None
        number = int(value.text)
    else:
        return None

    return number if MIN_TIME <= number <= MAX_TIME else None


def _checked(value):
    if not MIN_TIME <= value <= MAX_TIME:
        raise _Reject("R_OVERFLOW")
    return value


def _read_time(mapping, name):
    value = mapping.get(name)
    if value is None:
        raise _Reject("R_FIELD_ABSENT")

    if not (
        type(value) is int
        or isinstance(value, _Number) and value.integer
    ):
        raise _Reject("R_FIELD_TYPE")

    number = _small_integer(value)
    if number is None:
        raise _Reject("R_OVERFLOW")
    return number


def _compile(expression, expected, fields, dependencies):
    """Return (AST, tagged lower-bound set)."""
    if not isinstance(expression, dict) or len(expression) != 1:
        raise _BadRule()

    operator, argument = next(iter(expression.items()))

    if operator in ("field", "dep"):
        if expected != "Time":
            raise _BadRule()
        if not isinstance(argument, str) or not argument:
            raise _BadRule()

        declared = fields if operator == "field" else dependencies
        if argument not in declared:
            raise _BadRule()

        return (operator, argument), {(operator, argument)}

    if operator == "ms":
        number = _small_integer(argument)
        if expected != "Duration" or number is None or number < 0:
            raise _BadRule()
        return ("ms", number), set()

    if expected != "Time":
        raise _BadRule()

    if operator in ("add", "floor"):
        if not isinstance(argument, list) or len(argument) != 2:
            raise _BadRule()

        left, lower_bounds = _compile(
            argument[0], "Time", fields, dependencies
        )
        right, _ = _compile(
            argument[1], "Duration", fields, dependencies
        )

        # The only Duration expression is a constant ms expression.
        if operator == "floor":
            if right[0] != "ms" or right[1] <= 0:
                raise _BadRule()
            lower_bounds = set()

        return (operator, (left, right)), lower_bounds

    if operator == "max":
        if not isinstance(argument, list) or not 2 <= len(argument) <= 16:
            raise _BadRule()

        children = []
        lower_bounds = set()
        for child_expression in argument:
            child, child_bounds = _compile(
                child_expression, "Time", fields, dependencies
            )
            children.append(child)
            lower_bounds.update(child_bounds)
        return ("max", tuple(children)), lower_bounds

    raise _BadRule()


def _check_rule(text, fields, dependencies):
    document = _load_json(text, rule=True)
    if not isinstance(document, dict):
        raise _BadRule()
    if set(document) != {"rule", "expr"}:
        raise _BadRule()
    if _small_integer(document["rule"]) != 1:
        raise _BadRule()

    tree, lower_bounds = _compile(
        document["expr"], "Time", fields, dependencies
    )
    required = {("dep", name) for name in dependencies}
    if not lower_bounds or not required.issubset(lower_bounds):
        raise _BadRule()
    return tree


def _evaluate(tree, row, dependencies):
    operator, argument = tree

    if operator == "field":
        return _read_time(row, argument)
    if operator == "dep":
        return _read_time(dependencies, argument)
    if operator == "ms":
        return argument

    if operator == "add":
        left = _evaluate(argument[0], row, dependencies)
        right = _evaluate(argument[1], row, dependencies)
        return _checked(left + right)

    if operator == "floor":
        time = _evaluate(argument[0], row, dependencies)
        period = _evaluate(argument[1], row, dependencies)
        return _checked(period * (time // period))

    # A checked tree's remaining operator is max. Evaluate every
    # argument, in order, stopping only on the first rejection.
    result = _evaluate(argument[0], row, dependencies)
    for child in argument[1:]:
        value = _evaluate(child, row, dependencies)
        if value > result:
            result = value
    return result


def _read_object(text):
    try:
        value = _load_json(text)
    except _BadJSON:
        raise _Reject("R_ROW") from None

    if not isinstance(value, dict):
        raise _Reject("R_ROW")
    return value


def _is_number(value):
    return type(value) is int or isinstance(value, _Number)


def _number_key(value):
    """Exact numeric-value key; no floating point or large powers of ten."""
    text = value.text if isinstance(value, _Number) else str(value)
    negative = text.startswith("-")
    if negative:
        text = text[1:]

    mantissa, separator, exponent_text = text.lower().partition("e")
    exponent = _decimal_integer(exponent_text) if separator else 0
    whole, _, fraction = mantissa.partition(".")

    digits = (whole + fraction).lstrip("0")
    if not digits:
        return (0, "", 0)

    significant = digits.rstrip("0")
    exponent += len(digits) - len(significant) - len(fraction)
    return (-1 if negative else 1, significant, exponent)


def _same_value(left, right):
    if _is_number(left) or _is_number(right):
        return (
            _is_number(left)
            and _is_number(right)
            and _number_key(left) == _number_key(right)
        )

    # In particular, booleans are not equal to integers.
    if type(left) is not type(right):
        return False

    if isinstance(left, dict):
        return (
            left.keys() == right.keys()
            and all(_same_value(left[key], right[key]) for key in left)
        )

    if isinstance(left, list):
        return (
            len(left) == len(right)
            and all(_same_value(a, b) for a, b in zip(left, right))
        )

    return left == right


def _same_observed(left, right):
    columns = (left.keys() | right.keys()) - _METADATA
    return all(
        _same_value(left.get(column), right.get(column))
        for column in columns
    )


def _effective_known_at(tree, selected, earliest, declared, lags):
    # Both selected texts are completely read before expression evaluation.
    row = _read_object(selected["row"])
    dependencies = _read_object(selected["deps"])

    # Recorder metadata is authoritative, not any similarly named row member.
    row["fetchedAt"] = selected["fetchedAt"]
    candidate = _evaluate(tree, row, dependencies)

    if selected is not earliest:
        original_row = _read_object(earliest["row"])
        if not _same_observed(row, original_row):
            correction_bound = _checked(selected["fetchedAt"])
            candidate = max(candidate, correction_bound)

    # Successful evaluation has already validated every declared dependency:
    # the checked lower-bound set includes every dep, and max never skips it.
    for name in sorted(declared):
        dependency_time = _read_time(dependencies, name)
        dependency_bound = _checked(dependency_time + lags[name])
        candidate = max(candidate, dependency_bound)

    return _checked(candidate)


def resolve(case):
    """Resolve one case having the RESOLVER_CASES.md envelope schema.

    The envelope supplies integer fetchedAt/version/query values, boolean
    tombstones, and a nonnegative integer lag for every declared dependency.
    Dependency times are supplied by each revision's deps JSON text.
    """
    fields = set(case["fields"])
    declared = set(case["deps_declared"])

    # E_RULE precedes selection, duplicate detection, tombstones, and rows.
    try:
        tree = _check_rule(case["rule"], fields, declared)
    except (_BadJSON, _BadRule):
        return "E_RULE"

    eligible = []
    fetched_times = set()

    for revision in case["revisions"]:
        fetched_at = revision["fetchedAt"]
        if fetched_at <= case["version"]:
            if fetched_at in fetched_times:
                return "INVALID"
            fetched_times.add(fetched_at)
            eligible.append(revision)

    queries = case["queries"]

    if not eligible:
        return {
            "selected": None,
            "knownAt": None,
            "visible": [False for _ in queries],
        }

    selected = max(eligible, key=lambda revision: revision["fetchedAt"])
    earliest = min(eligible, key=lambda revision: revision["fetchedAt"])

    if selected["tombstone"]:
        return {
            "selected": selected["fetchedAt"],
            "knownAt": None,
            "visible": [False for _ in queries],
        }

    try:
        known_at = _effective_known_at(
            tree, selected, earliest, declared, case["lags"]
        )
    except _Reject as rejection:
        known_at = rejection.code

    return {
        "selected": selected["fetchedAt"],
        "knownAt": known_at,
        "visible": [
            type(known_at) is int and known_at <= query
            for query in queries
        ],
    }


def main():
    # Permit exact JSON envelope integers of arbitrary spelling length,
    # including when serializing selected fetchedAt values.
    sys.set_int_max_str_digits(0)

    for line in sys.stdin.buffer:
        if not line.strip():
            continue
        case = _load_json(line, native_integers=True)
        result = resolve(case)
        sys.stdout.write(
            json.dumps(result, ensure_ascii=True, separators=(",", ":"))
            + "\n"
        )


if __name__ == "__main__":
    main()
