"""C7.6: GPT 6.1 Sol's independent implementation of kernel/RULES.md v1, written from RULES.md alone with tools denied, then
updated by it for the clarification of section 4 rule 5 from RULES.md, the diff and its own previous file
(~/.cache/mm-gpt/rulesimpl.GVB0). Committed verbatim below this note."""

#!/usr/bin/env python3
"""Availability rule language v1, excluding the resolver."""

import json
import sys

MIN_TIME = -(1 << 62)
MAX_TIME = (1 << 62) - 1

_BIG_INTEGER = object()
_NON_INTEGER = object()
_HEX_DIGITS = frozenset("0123456789abcdefABCDEF")
_ESCAPES = {
    '"': '"',
    "\\": "\\",
    "/": "/",
    "b": "\b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t",
}


class _MalformedJSON(Exception):
    pass


class _InvalidRule(Exception):
    pass


class _JSONParser:
    """Strict JSON parser; numbers are never converted to floating point."""

    def __init__(self, text):
        self.text = text
        self.length = len(text)
        self.pos = 0

    def parse(self):
        result = self._value(0)
        self._space()
        if self.pos != self.length:
            raise _MalformedJSON
        return result

    def _space(self):
        text = self.text
        pos = self.pos
        while pos < self.length and text[pos] in " \t\r\n":
            pos += 1
        self.pos = pos

    def _value(self, containers):
        self._space()
        if self.pos == self.length:
            raise _MalformedJSON

        ch = self.text[self.pos]
        if ch == "{":
            if containers >= 64:
                raise _MalformedJSON
            return self._object(containers + 1)
        if ch == "[":
            if containers >= 64:
                raise _MalformedJSON
            return self._array(containers + 1)
        if ch == '"':
            return self._string()
        if ch == "-" or "0" <= ch <= "9":
            return self._number()

        for spelling, value in (
            ("true", True),
            ("false", False),
            ("null", None),
        ):
            if self.text.startswith(spelling, self.pos):
                self.pos += len(spelling)
                return value
        raise _MalformedJSON

    def _object(self, containers):
        self.pos += 1
        self._space()
        result = {}

        if self.pos < self.length and self.text[self.pos] == "}":
            self.pos += 1
            return result

        while True:
            self._space()
            if self.pos >= self.length or self.text[self.pos] != '"':
                raise _MalformedJSON
            key = self._string()
            if key in result:
                raise _MalformedJSON

            self._space()
            if self.pos >= self.length or self.text[self.pos] != ":":
                raise _MalformedJSON
            self.pos += 1
            result[key] = self._value(containers)

            self._space()
            if self.pos >= self.length:
                raise _MalformedJSON
            ch = self.text[self.pos]
            self.pos += 1
            if ch == "}":
                return result
            if ch != ",":
                raise _MalformedJSON

    def _array(self, containers):
        self.pos += 1
        self._space()
        result = []

        if self.pos < self.length and self.text[self.pos] == "]":
            self.pos += 1
            return result

        while True:
            result.append(self._value(containers))
            self._space()
            if self.pos >= self.length:
                raise _MalformedJSON
            ch = self.text[self.pos]
            self.pos += 1
            if ch == "]":
                return result
            if ch != ",":
                raise _MalformedJSON

    def _hex4(self, pos):
        if pos + 4 > self.length:
            raise _MalformedJSON
        token = self.text[pos:pos + 4]
        if any(ch not in _HEX_DIGITS for ch in token):
            raise _MalformedJSON
        return int(token, 16)

    def _string(self):
        text = self.text
        pos = self.pos + 1
        start = pos
        pieces = []

        while pos < self.length:
            ch = text[pos]
            if ch == '"':
                pieces.append(text[start:pos])
                self.pos = pos + 1
                return "".join(pieces)

            if ch == "\\":
                pieces.append(text[start:pos])
                pos += 1
                if pos >= self.length:
                    raise _MalformedJSON

                escape = text[pos]
                pos += 1
                if escape == "u":
                    code = self._hex4(pos)
                    pos += 4

                    if 0xD800 <= code <= 0xDBFF:
                        if text[pos:pos + 2] != "\\u":
                            raise _MalformedJSON
                        low = self._hex4(pos + 2)
                        if not 0xDC00 <= low <= 0xDFFF:
                            raise _MalformedJSON
                        pos += 6
                        code = (
                            0x10000
                            + ((code - 0xD800) << 10)
                            + (low - 0xDC00)
                        )
                    elif 0xDC00 <= code <= 0xDFFF:
                        raise _MalformedJSON

                    pieces.append(chr(code))
                else:
                    if escape not in _ESCAPES:
                        raise _MalformedJSON
                    pieces.append(_ESCAPES[escape])

                start = pos
                continue

            code = ord(ch)
            if code < 0x20 or 0xD800 <= code <= 0xDFFF:
                raise _MalformedJSON
            pos += 1

        raise _MalformedJSON

    def _number(self):
        text = self.text
        pos = self.pos
        start = pos

        if text[pos] == "-":
            pos += 1
            if pos >= self.length:
                raise _MalformedJSON

        digit_start = pos
        if text[pos] == "0":
            pos += 1
        elif "1" <= text[pos] <= "9":
            pos += 1
            while pos < self.length and "0" <= text[pos] <= "9":
                pos += 1
        else:
            raise _MalformedJSON
        integer_end = pos

        non_integer = False
        if pos < self.length and text[pos] == ".":
            non_integer = True
            pos += 1
            fraction_start = pos
            while pos < self.length and "0" <= text[pos] <= "9":
                pos += 1
            if pos == fraction_start:
                raise _MalformedJSON

        if pos < self.length and text[pos] in "eE":
            non_integer = True
            pos += 1
            if pos < self.length and text[pos] in "+-":
                pos += 1
            exponent_start = pos
            while pos < self.length and "0" <= text[pos] <= "9":
                pos += 1
            if pos == exponent_start:
                raise _MalformedJSON

        self.pos = pos
        if non_integer:
            return _NON_INTEGER
        if integer_end - digit_start > 19:
            return _BIG_INTEGER
        return int(text[start:integer_end])


def _read_json(text, *, rule=False):
    if not isinstance(text, str):
        raise _MalformedJSON

    if rule:
        # UTF-8 has at least one byte per scalar value.
        if len(text) > 65_536:
            raise _MalformedJSON
        try:
            byte_length = len(text.encode("utf-8", errors="strict"))
        except UnicodeError:
            raise _MalformedJSON from None
        if byte_length > 65_536:
            raise _MalformedJSON

    # A BOM outside a string is rejected by the grammar. Raw surrogate
    # code points are rejected by string parsing, or by the grammar.
    return _JSONParser(text).parse()


def _names(value):
    if type(value) is not list:
        raise _InvalidRule
    if any(type(name) is not str for name in value):
        raise _InvalidRule
    return set(value)


def _check_expr(expr, expected, fields, declared):
    if type(expr) is not dict or len(expr) != 1:
        raise _InvalidRule
    op, arg = next(iter(expr.items()))

    if op == "ms":
        if (
            expected != "duration"
            or type(arg) is not int
            or not 0 <= arg <= MAX_TIME
        ):
            raise _InvalidRule
        return set()

    if expected != "time":
        raise _InvalidRule

    if op == "field" or op == "dep":
        allowed = fields if op == "field" else declared
        if type(arg) is not str or not arg or arg not in allowed:
            raise _InvalidRule
        # Lower-bound terms distinguish fields from dependencies.
        return {(op, arg)}

    if op == "add" or op == "floor":
        if type(arg) is not list or len(arg) != 2:
            raise _InvalidRule

        lower_bounds = _check_expr(arg[0], "time", fields, declared)
        _check_expr(arg[1], "duration", fields, declared)

        if op == "floor":
            # The only Duration expression is an ms constant.
            if arg[1]["ms"] <= 0:
                raise _InvalidRule
            return set()
        return lower_bounds

    if op == "max":
        if type(arg) is not list or not 2 <= len(arg) <= 16:
            raise _InvalidRule
        lower_bounds = set()
        for child in arg:
            lower_bounds.update(
                _check_expr(child, "time", fields, declared)
            )
        return lower_bounds

    raise _InvalidRule


def _check_rule(document, fields, declared):
    if (
        type(document) is not dict
        or set(document) != {"rule", "expr"}
        or type(document["rule"]) is not int
        or document["rule"] != 1
    ):
        raise _InvalidRule

    expr = document["expr"]
    lower_bounds = _check_expr(expr, "time", fields, declared)
    required_bounds = {("dep", name) for name in declared}
    if not lower_bounds or not required_bounds.issubset(lower_bounds):
        raise _InvalidRule
    return expr


def _evaluate_expr(expr, row, deps):
    op, arg = next(iter(expr.items()))

    if op == "field" or op == "dep":
        source = row if op == "field" else deps
        value = source.get(arg)
        if value is None:
            return "R_FIELD_ABSENT"
        if value is _BIG_INTEGER:
            return "R_OVERFLOW"
        if type(value) is not int:
            return "R_FIELD_TYPE"
        if not MIN_TIME <= value <= MAX_TIME:
            return "R_OVERFLOW"
        return value

    if op == "ms":
        return arg

    if op == "add" or op == "floor":
        left = _evaluate_expr(arg[0], row, deps)
        if type(left) is not int:
            return left
        right = _evaluate_expr(arg[1], row, deps)
        if type(right) is not int:
            return right

        if op == "add":
            result = left + right
        else:
            result = right * (left // right)

        if not MIN_TIME <= result <= MAX_TIME:
            return "R_OVERFLOW"
        return result

    # Only max remains in a checked expression. Evaluate every operand
    # in order, including operands that cannot increase the maximum.
    best = MIN_TIME
    for child in arg:
        value = _evaluate_expr(child, row, deps)
        if type(value) is not int:
            return value
        if value > best:
            best = value
    return best


def evaluate(case):
    """Return a Time integer or the applicable specification code."""
    if not isinstance(case, dict):
        return "E_RULE"

    try:
        fields = _names(case.get("fields"))
        declared = _names(case.get("deps_declared"))
        document = _read_json(case.get("rule"), rule=True)
        expr = _check_rule(document, fields, declared)
    except (_MalformedJSON, _InvalidRule):
        return "E_RULE"

    # Both complete texts are parsed before any expression is evaluated.
    try:
        row = _read_json(case.get("row"))
        deps = _read_json(case.get("deps"))
    except _MalformedJSON:
        return "R_ROW"

    if type(row) is not dict or type(deps) is not dict:
        return "R_ROW"

    return _evaluate_expr(expr, row, deps)


def _envelope_integer(token):
    digits = len(token) - int(token.startswith("-"))
    return _BIG_INTEGER if digits > 19 else int(token)


def _envelope_constant(_token):
    raise _MalformedJSON


def _envelope_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _MalformedJSON
        result[key] = value
    return result


def main():
    stream = getattr(sys.stdin, "buffer", sys.stdin)
    for line in stream:
        try:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="strict")

            # This decodes only the transport envelope, never rule, row,
            # or deps. Surrogate escapes are retained here so an invalid
            # inner text can reach evaluate() and receive its proper code.
            case = json.loads(
                line,
                parse_int=_envelope_integer,
                parse_float=lambda _token: _NON_INTEGER,
                parse_constant=_envelope_constant,
                object_pairs_hook=_envelope_object,
            )
        except (ValueError, _MalformedJSON, RecursionError):
            # Section 7 does not specify malformed-envelope results.
            result = "E_RULE"
        else:
            result = evaluate(case)

        sys.stdout.write(json.dumps(result, allow_nan=False) + "\n")


if __name__ == "__main__":
    main()
