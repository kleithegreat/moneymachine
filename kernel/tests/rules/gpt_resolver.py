"""C7.6: GPT 6.1 Sol's independent resolver (B3), written in one reply from kernel/RULES.md and kernel/SOURCES.md alone, with every
tool denied (sealed directory ~/.cache/mm-gpt/c76-resolver.XYxt, 2026-11-07 01:45 UTC (2026-11-06 20:45 EST)). Its three
marked readings: observations' COIN is the universe index; binary64 bits are unsigned 64-bit integers; a non-resolving
case has no observations. Committed verbatim below this note."""

#!/usr/bin/env python3
"""Independent RULES.md §6–7 resolver. Standard library only."""

import json
import math
import struct
import sys
from bisect import bisect_right
from collections import deque
from dataclasses import dataclass, field


LO = -(1 << 62)
HI = (1 << 62) - 1
CELL_LO = -(1 << 63)
CELL_HI = (1 << 63) - 1
METADATA = {
    "fetchedAt", "tombstone", "source", "hash", "upstream", "knownAt"
}


class _Malformed(Exception):
    pass


class _BadRule(Exception):
    pass


class _Rejected(Exception):
    pass


class _NonInteger:
    """An unconverted JSON number token containing a fraction or exponent."""

    __slots__ = ("text",)

    def __init__(self, text):
        self.text = text


_TOO_LARGE_INTEGER = object()


def _text_integer(token):
    digits = token[1:] if token.startswith("-") else token
    # Such integers cannot be cells, constants, or Time values. Undeclared
    # members still parse successfully without constructing a huge integer.
    if len(digits) > 19:
        return _TOO_LARGE_INTEGER
    return int(token)


def _unlimited_integer(token):
    """Parse outer-case integers without Python's decimal digit limit."""
    negative = token.startswith("-")
    digits = token[1:] if negative else token
    value = 0
    for start in range(0, len(digits), 9):
        chunk = digits[start:start + 9]
        value = value * (10 ** len(chunk)) + int(chunk)
    return -value if negative else value


def _bad_constant(_):
    raise _Malformed()


def _unique_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise _Malformed()
        result[name] = value
    return result


def _read_text(text, rule=False):
    if type(text) is not str:
        raise _Malformed()
    try:
        encoded = text.encode("utf-8", "strict")
    except UnicodeEncodeError:
        raise _Malformed() from None

    if text.startswith("\ufeff") or (rule and len(encoded) > 65536):
        raise _Malformed()

    # Check container depth before invoking the recursive JSON decoder.
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
                raise _Malformed()
        elif char in "]}":
            depth -= 1
            if depth < 0:
                raise _Malformed()

    try:
        value = json.loads(
            text,
            parse_int=_text_integer,
            parse_float=_NonInteger,
            parse_constant=_bad_constant,
            object_pairs_hook=_unique_object,
        )
    except json.JSONDecodeError:
        raise _Malformed() from None

    # Inspect all decoded strings, including undeclared members and keys.
    pending = [value]
    while pending:
        item = pending.pop()
        if type(item) is str:
            if any(0xD800 <= ord(char) <= 0xDFFF for char in item):
                raise _Malformed()
        elif type(item) is list:
            pending.extend(item)
        elif type(item) is dict:
            pending.extend(item.keys())
            pending.extend(item.values())
    return value


def _is_time(value):
    return type(value) is int and LO <= value <= HI


def _bounded(value):
    if not LO <= value <= HI:
        raise _Rejected("R_OVERFLOW")
    return value


def _cell(value):
    if value is None or type(value) in (str, bool):
        return value
    if type(value) is int:
        if CELL_LO <= value <= CELL_HI:
            return value
        raise _Malformed()
    if isinstance(value, _NonInteger):
        try:
            number = float(value.text)
        except (ValueError, OverflowError):
            raise _Malformed() from None
        if math.isfinite(number):
            return number
    raise _Malformed()


def _tag(value):
    """Both a cell identity and its specified sorting key."""
    if value is None:
        return (0,)
    if type(value) is bool:
        return (1, value)
    if type(value) is int:
        return (2, value)
    if type(value) is float:
        return (3, value)
    return (4, value)


def _expression(value, fields, dependencies):
    if type(value) is not dict or len(value) != 1:
        raise _BadRule()
    operator, argument = next(iter(value.items()))

    if operator in ("field", "dep"):
        context = fields if operator == "field" else dependencies
        if (
            type(argument) is not str
            or not argument
            or argument not in context
        ):
            raise _BadRule()
        return (operator, argument), "Time", {(operator, argument)}

    if operator == "ms":
        if type(argument) is not int or not 0 <= argument <= HI:
            raise _BadRule()
        return ("ms", argument), "Duration", set()

    if operator in ("add", "floor"):
        if type(argument) is not list or len(argument) != 2:
            raise _BadRule()
        left, left_type, left_lb = _expression(
            argument[0], fields, dependencies
        )
        right, right_type, _ = _expression(
            argument[1], fields, dependencies
        )
        if left_type != "Time" or right_type != "Duration":
            raise _BadRule()
        if operator == "floor":
            if right[0] != "ms" or right[1] <= 0:
                raise _BadRule()
            lower_bounds = set()
        else:
            lower_bounds = left_lb
        return (operator, (left, right)), "Time", lower_bounds

    if operator == "max":
        if type(argument) is not list or not 2 <= len(argument) <= 16:
            raise _BadRule()
        children = []
        lower_bounds = set()
        for child in argument:
            node, kind, bounds = _expression(child, fields, dependencies)
            if kind != "Time":
                raise _BadRule()
            children.append(node)
            lower_bounds.update(bounds)
        return ("max", tuple(children)), "Time", lower_bounds

    raise _BadRule()


def _check_rule(source):
    document = _read_text(source["rule"], rule=True)
    if (
        type(document) is not dict
        or set(document) != {"rule", "expr"}
        or type(document["rule"]) is not int
        or document["rule"] != 1
    ):
        raise _BadRule()

    fields = set(source["times"]) | {"fetchedAt"}
    dependencies = {dependency["name"] for dependency in source["deps"]}
    node, kind, bounds = _expression(
        document["expr"], fields, dependencies
    )
    required = {("dep", name) for name in dependencies}
    if kind != "Time" or not bounds or not required.issubset(bounds):
        raise _BadRule()
    return node


def _evaluate(node, row, dependencies):
    operator, argument = node
    if operator in ("field", "dep"):
        values = row if operator == "field" else dependencies
        value = values.get(argument)
        if value is None:
            raise _Rejected("R_FIELD_ABSENT")
        if type(value) is not int:
            raise _Rejected("R_FIELD_TYPE")
        return _bounded(value)

    if operator == "ms":
        return argument

    if operator in ("add", "floor"):
        left = _evaluate(argument[0], row, dependencies)
        right = _evaluate(argument[1], row, dependencies)
        if operator == "add":
            return _bounded(left + right)
        return _bounded(right * (left // right))

    maximum = None
    for child in argument:
        value = _evaluate(child, row, dependencies)
        if maximum is None or value > maximum:
            maximum = value
    return maximum


def _columns(source):
    names = set(source["times"])
    names.update(source["values"])
    names.update(source["entity"])
    names.add(source["event"])
    if source["slot"] is not None:
        names.add(source["slot"])
    for columns in (source["roles"] or {}).values():
        names.update(columns)
    return sorted(names)


def _source_order(sources):
    upstream = {
        name: {
            parent
            for dependency in source["deps"]
            for parent in dependency["sources"]
        }
        for name, source in sources.items()
    }
    downstream = {name: set() for name in sources}
    for name, parents in upstream.items():
        for parent in parents:
            downstream[parent].add(name)

    ready = deque(sorted(name for name in sources if not upstream[name]))
    order = []
    while ready:
        name = ready.popleft()
        order.append(name)
        for child in sorted(downstream[name]):
            upstream[child].remove(name)
            if not upstream[child]:
                ready.append(child)
    return order if len(order) == len(sources) else None


@dataclass
class _Revision:
    fetched: int
    tombstone: bool
    cells: dict
    lineage: dict
    signature: tuple


@dataclass
class _Key:
    source: str
    entity: list
    event: int
    coin: object
    revisions: list = field(default_factory=list)
    entries: list = field(default_factory=list)
    recorded: list = field(default_factory=list)


def _decode_revision(raw, source, columns, sources):
    document = _read_text(raw["cells"])
    if type(document) is not dict:
        raise _Malformed()

    cells = {name: _cell(document.get(name)) for name in columns}
    event = cells[source["event"]]
    if not _is_time(event):
        raise _Malformed()
    entity = [cells[name] for name in source["entity"]]

    lineage = {}
    if source["deps"] and not raw["tombstone"]:
        upstream = _read_text(raw.get("upstream"))
        if type(upstream) is not dict:
            raise _Malformed()
        for name, items in upstream.items():
            if type(items) is not list:
                raise _Malformed()
            decoded = []
            for item in items:
                if type(item) is not list or len(item) != 3:
                    raise _Malformed()
                parent, parent_entity, parent_event = item
                if (
                    type(parent) is not str
                    or parent not in sources
                    or type(parent_entity) is not list
                    or len(parent_entity) != len(sources[parent]["entity"])
                    or not _is_time(parent_event)
                ):
                    raise _Malformed()
                entity_cells = [_cell(value) for value in parent_entity]
                decoded.append((
                    parent,
                    tuple(_tag(value) for value in entity_cells),
                    parent_event,
                ))
            lineage[name] = decoded

    signature = (
        raw["tombstone"],
        tuple(_tag(cells[name]) for name in columns),
    )
    revision = _Revision(
        raw["fetchedAt"], raw["tombstone"], cells, lineage, signature
    )
    return revision, entity, event


def _is_number(value):
    return type(value) in (int, float)


def _role_payload(source, cells):
    if not source["roles"]:
        return None
    role, columns = next(iter(source["roles"].items()))
    payload = [cells[name] for name in columns]
    if role == "bars":
        if (
            not all(_is_number(value) for value in payload[:4])
            or type(payload[4]) is not int
        ):
            raise _Rejected()
    elif not _is_number(payload[0]):
        raise _Rejected()
    return payload


def _candidate(source, rule, revision, keys, has_last, previous):
    dependencies = {}
    for declaration in source["deps"]:
        name = declaration["name"]
        lineage = revision.lineage.get(name, [])
        if not lineage:
            raise _Rejected()
        latest = None
        for identity in lineage:
            if identity[0] not in declaration["sources"]:
                raise _Rejected()
            upstream_key = keys.get(identity)
            if upstream_key is None:
                raise _Rejected()
            index = bisect_right(
                upstream_key.recorded, revision.fetched
            ) - 1
            if index < 0:
                raise _Rejected()
            known = upstream_key.entries[index][1]
            if latest is None or known > latest:
                latest = known
        dependencies[name] = latest

    row = dict(revision.cells)
    row["fetchedAt"] = revision.fetched
    known = _evaluate(rule, row, dependencies)

    if has_last:
        known = max(known, _bounded(revision.fetched))
    if previous is not None:
        known = max(known, _bounded(previous[1]))
    for declaration in source["deps"]:
        bound = dependencies[declaration["name"]] + declaration["lag"]
        known = max(known, _bounded(bound))

    slot = None
    if source["slot"] is not None:
        slot = revision.cells[source["slot"]]
        if type(slot) is not int:
            raise _Rejected()
    payload = _role_payload(source, revision.cells)
    return known, slot, payload


def _build_timeline(key, source, rule, keys):
    last = None
    for revision in key.revisions:
        has_last = last is not None
        identical = has_last and revision.signature == last.signature
        last = revision
        if identical:
            continue

        previous = key.entries[-1] if key.entries else None
        candidate = None
        if not revision.tombstone:
            try:
                candidate = _candidate(
                    source, rule, revision, keys, has_last, previous
                )
            except _Rejected:
                pass

        if candidate is None:
            if previous is None:
                continue
            known = _bounded(max(revision.fetched, previous[1]))
            entry = [
                revision.fetched, known, True, previous[3], None, None
            ]
        else:
            known, slot, payload = candidate
            entry = [
                revision.fetched, known, False,
                slot, revision.cells, payload,
            ]
        key.entries.append(entry)
        key.recorded.append(revision.fetched)


def _number_bits(value):
    if not _is_number(value):
        return None
    # AMBIGUITY: represent binary64 bits as an unsigned 64-bit integer.
    return struct.unpack(">Q", struct.pack(">d", float(value)))[0]


def _observation_role(source, payload):
    if payload is None:
        return None
    role = next(iter(source["roles"]))
    if role == "bars":
        return [_number_bits(value) for value in payload[:4]] + [payload[4]]
    return [_number_bits(payload[0])]


def _failure(code):
    # AMBIGUITY: undefined observations for non-resolving cases are [].
    return code, []


def _run(case):
    declarations = case["sources"]
    columns = {
        source["name"]: _columns(source) for source in declarations
    }
    if any(METADATA.intersection(names) for names in columns.values()):
        return _failure("E_DECL")

    sources = {source["name"]: source for source in declarations}
    rules = {}
    for source in declarations:
        try:
            rules[source["name"]] = _check_rule(source)
        except (_Malformed, _BadRule):
            return _failure("E_RULE")

    order = _source_order(sources)
    if order is None:
        return _failure("INVALID")

    coin_indices = {
        _tag(coin): index for index, coin in enumerate(case["universe"])
    }
    keys = {}
    entity_coins = {}
    for raw in case["rows"]:
        fetched = raw["fetchedAt"]
        if fetched > case["version"]:
            continue
        if not _is_time(fetched):
            return _failure("INVALID")

        source = sources[raw["source"]]
        try:
            revision, entity, event = _decode_revision(
                raw, source, columns[source["name"]], sources
            )
        except _Malformed:
            return _failure("INVALID")

        entity_identity = tuple(_tag(value) for value in entity)
        identity = (source["name"], entity_identity, event)
        coin = None
        if not source["evidence"]:
            coin = coin_indices.get(_tag(revision.cells["coin"]))

        mapping_identity = (source["name"], entity_identity)
        if (
            mapping_identity in entity_coins
            and entity_coins[mapping_identity] != coin
        ):
            return _failure("INVALID")
        entity_coins[mapping_identity] = coin

        if identity not in keys:
            keys[identity] = _Key(source["name"], entity, event, coin)
        keys[identity].revisions.append(revision)

    by_source = {name: [] for name in sources}
    for key in keys.values():
        key.revisions.sort(key=lambda revision: revision.fetched)
        if any(
            left.fetched == right.fetched
            for left, right in zip(key.revisions, key.revisions[1:])
        ):
            return _failure("INVALID")
        by_source[key.source].append(key)

    for name in order:
        for key in by_source[name]:
            _build_timeline(key, sources[name], rules[name], keys)

    ordered = sorted(
        keys.values(),
        key=lambda key: (
            key.source,
            tuple(_tag(value) for value in key.entity),
            key.event,
        ),
    )
    result_keys = []
    observation_list = []
    for key in ordered:
        source = sources[key.source]
        known_times = [entry[1] for entry in key.entries]
        visible = []
        for query in case["queries"]:
            index = bisect_right(known_times, query) - 1
            if index < 0 or key.entries[index][2]:
                visible.append(None)
            else:
                visible.append(key.entries[index][0])
        result_keys.append({
            "source": key.source,
            "entity": key.entity,
            "event": key.event,
            "coin": key.coin,
            "timeline": key.entries,
            "visible": visible,
        })

        if key.coin is None:
            continue
        for index, entry in enumerate(key.entries):
            fetched, known, retraction, slot, cells, payload = entry
            values = [
                None if retraction else _number_bits(cells[name])
                for name in source["values"]
            ]
            # AMBIGUITY: loader COIN means the universe index, as in keys.
            observation_list.append([
                key.source,
                key.coin,
                key.event,
                fetched,
                known,
                retraction,
                slot,
                values,
                _observation_role(source, payload),
                index == len(key.entries) - 1,
            ])

    observation_list.sort(
        key=lambda observation: (
            observation[0], observation[1],
            observation[2], observation[3],
        )
    )
    return {"keys": result_keys}, observation_list


def resolve(case):
    """Return E_DECL, E_RULE, INVALID, or the §7 keys object."""
    return _run(case)[0]


def observations(case):
    """Return sorted loader observations; [] for a non-resolving case."""
    return _run(case)[1]


def main():
    # The outer envelope is a §7 case; its stored texts remain strings.
    for line in sys.stdin:
        case = json.loads(
            line,
            parse_int=_unlimited_integer,
            parse_constant=_bad_constant,
        )
        result, observed = _run(case)
        # Python emits finite floats with a fraction or exponent, including
        # integral-valued floats and signed zero.
        output = json.dumps(
            {"result": result, "observations": observed},
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
        )
        sys.stdout.write(output + "\n")


if __name__ == "__main__":
    main()
