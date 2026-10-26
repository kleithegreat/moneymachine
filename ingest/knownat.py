"""The availability rule language, version 1 (kernel/RULES.md §1-5: strict JSON reading, checking, and evaluation of
a checked rule on a row) and its resolver (§6). `mm` implements both in Rust (`kernel/mm/src/rule.rs`); the C7.6
suites hold the two, and an independent third, to the same results."""

import json
import sys

LO, HI = -(2**62), 2**62 - 1
MAX_DEPTH, MAX_RULE_BYTES, MAX_ARGS = 64, 65_536, 16
WHITESPACE = " \t\n\r"


class Malformed(Exception):
    pass


class Real:
    """A JSON number that is not an integer token."""


def parse(text):
    """The value of a JSON text under RULES.md §1, or Malformed. Integers are exact ints; other numbers are Real."""
    p = Parser(text)
    p.space()
    v = p.value(1)
    p.space()
    if p.i != len(text):
        raise Malformed("trailing content")
    return v


class Parser:
    def __init__(self, text):
        self.s, self.i = text, 0

    def space(self):
        while self.i < len(self.s) and self.s[self.i] in WHITESPACE:
            self.i += 1

    def peek(self):
        if self.i >= len(self.s):
            raise Malformed("end of text")
        return self.s[self.i]

    def value(self, depth):
        c = self.peek()
        if c in "{[" and depth > MAX_DEPTH:
            raise Malformed("too deep")
        if c == "{":
            return self.obj(depth)
        if c == "[":
            return self.arr(depth)
        if c == '"':
            return self.string()
        for word, v in (("true", True), ("false", False), ("null", None)):
            if self.s.startswith(word, self.i):
                self.i += len(word)
                return v
        return self.number()

    def obj(self, depth):
        self.i += 1
        out = {}
        self.space()
        if self.peek() == "}":
            self.i += 1
            return out
        while True:
            self.space()
            if self.peek() != '"':
                raise Malformed("key")
            k = self.string()
            self.space()
            if self.peek() != ":":
                raise Malformed("colon")
            self.i += 1
            self.space()
            if k in out:
                raise Malformed("duplicate key")
            out[k] = self.value(depth + 1)
            self.space()
            c = self.peek()
            self.i += 1
            if c == "}":
                return out
            if c != ",":
                raise Malformed("object")

    def arr(self, depth):
        self.i += 1
        out = []
        self.space()
        if self.peek() == "]":
            self.i += 1
            return out
        while True:
            self.space()
            out.append(self.value(depth + 1))
            self.space()
            c = self.peek()
            self.i += 1
            if c == "]":
                return out
            if c != ",":
                raise Malformed("array")

    def string(self):
        self.i += 1
        out = []
        while True:
            c = self.peek()
            self.i += 1
            if c == '"':
                return "".join(out)
            if c == "\\":
                e = self.peek()
                self.i += 1
                if e in '"\\/':
                    out.append(e)
                elif e in "bfnrt":
                    out.append({"b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t"}[e])
                elif e == "u":
                    u = self.hex4()
                    if 0xD800 <= u < 0xDC00:
                        if self.s[self.i:self.i + 2] != "\\u":
                            raise Malformed("lone surrogate")
                        self.i += 2
                        low = self.hex4()
                        if not 0xDC00 <= low < 0xE000:
                            raise Malformed("lone surrogate")
                        out.append(chr(0x10000 + ((u - 0xD800) << 10) + (low - 0xDC00)))
                    elif 0xDC00 <= u < 0xE000:
                        raise Malformed("lone surrogate")
                    else:
                        out.append(chr(u))
                else:
                    raise Malformed("escape")
            elif ord(c) < 0x20:
                raise Malformed("control character")
            elif 0xD800 <= ord(c) < 0xE000:
                raise Malformed("surrogate")
            else:
                out.append(c)

    def hex4(self):
        h = self.s[self.i:self.i + 4]
        if len(h) != 4 or any(c not in "0123456789abcdefABCDEF" for c in h):
            raise Malformed("hex escape")
        self.i += 4
        return int(h, 16)

    def number(self):
        start = self.i
        if self.peek() == "-":
            self.i += 1
        if self.i < len(self.s) and self.s[self.i] == "0":
            self.i += 1
        elif self.i < len(self.s) and self.s[self.i] in "123456789":
            while self.i < len(self.s) and self.s[self.i].isascii() and self.s[self.i].isdigit():
                self.i += 1
        else:
            raise Malformed("number")
        integer = True
        if self.i < len(self.s) and self.s[self.i] == ".":
            integer = False
            self.i += 1
            self.digits()
        if self.i < len(self.s) and self.s[self.i] in "eE":
            integer = False
            self.i += 1
            if self.i < len(self.s) and self.s[self.i] in "+-":
                self.i += 1
            self.digits()
        token = self.s[start:self.i]
        if not integer:
            return Real()
        if len(token.lstrip("-")) > 19:
            return HI + 1
        return int(token)

    def digits(self):
        start = self.i
        while self.i < len(self.s) and self.s[self.i].isascii() and self.s[self.i].isdigit():
            self.i += 1
        if self.i == start:
            raise Malformed("digits")


def is_int(v):
    return type(v) is int


class RuleError(Exception):
    pass


def check(text, fields, deps):
    """The checked expression of a rule document text, or RuleError (E_RULE)."""
    if len(text.encode("utf-8", "surrogatepass")) > MAX_RULE_BYTES:
        raise RuleError("too long")
    try:
        doc = parse(text)
    except Malformed as e:
        raise RuleError(str(e))
    if not (type(doc) is dict and set(doc) == {"rule", "expr"} and is_int(doc["rule"]) and doc["rule"] == 1):
        raise RuleError("not a version 1 rule document")
    if typ(doc["expr"], set(fields), set(deps)) != "time":
        raise RuleError("expr is not Time")
    lb = lower_bound(doc["expr"])
    if not lb or not {("dep", d) for d in deps} <= lb:
        raise RuleError("lower-bound set")
    return doc["expr"]


def op(e):
    if type(e) is not dict or len(e) != 1:
        raise RuleError("not an expression")
    return next(iter(e.items()))


def typ(e, fields, deps):
    k, v = op(e)
    if k == "field" or k == "dep":
        if type(v) is not str or not v or v not in (fields if k == "field" else deps):
            raise RuleError(f"{k} name")
        return "time"
    if k == "ms":
        if not (is_int(v) and 0 <= v <= HI):
            raise RuleError("constant")
        return "duration"
    if type(v) is not list:
        raise RuleError("operands")
    if k == "add":
        if len(v) != 2 or typ(v[0], fields, deps) != "time" or typ(v[1], fields, deps) != "duration":
            raise RuleError("add")
        return "time"
    if k == "floor":
        if len(v) != 2 or typ(v[0], fields, deps) != "time" or typ(v[1], fields, deps) != "duration" or op(v[1])[1] <= 0:
            raise RuleError("floor")
        return "time"
    if k == "max":
        if not 2 <= len(v) <= MAX_ARGS or any(typ(x, fields, deps) != "time" for x in v):
            raise RuleError("max")
        return "time"
    raise RuleError("operator")


def lower_bound(e):
    k, v = op(e)
    if k in ("field", "dep"):
        return {(k, v)}
    if k == "add":
        return lower_bound(v[0])
    if k == "max":
        return set().union(*map(lower_bound, v))
    return set()


class Rejected(Exception):
    def __init__(self, code):
        self.code = code


def evaluate(expr, row, deps):
    """A checked expression's value on decoded row and deps objects, or Rejected."""
    k, v = op(expr)
    if k in ("field", "dep"):
        source = row if k == "field" else deps
        x = source.get(v)
        if x is None:
            raise Rejected("R_FIELD_ABSENT")
        if not is_int(x):
            raise Rejected("R_FIELD_TYPE")
        return ranged(x)
    if k == "ms":
        return v
    if k == "add":
        return ranged(evaluate(v[0], row, deps) + evaluate(v[1], row, deps))
    if k == "floor":
        t, p = evaluate(v[0], row, deps), evaluate(v[1], row, deps)
        return ranged(t - t % p)
    return max(evaluate(x, row, deps) for x in v)


def ranged(x):
    if not LO <= x <= HI:
        raise Rejected("R_OVERFLOW")
    return x


def result(case):
    """A conformance case's result (RULES.md §7): the Time, or a code."""
    try:
        expr = check(case["rule"], case["fields"], case["deps_declared"])
    except RuleError:
        return "E_RULE"
    try:
        return evaluate(expr, obj(case["row"]), obj(case["deps"]))
    except Rejected as r:
        return r.code


def typed(v):
    """A JSON value with its type kept, for comparisons where True must not equal 1."""
    if type(v) is dict:
        return ("obj", tuple(sorted((k, typed(x)) for k, x in v.items())))
    if type(v) is list:
        return ("arr", tuple(map(typed, v)))
    return (type(v).__name__, v if type(v) is not Real else None)


def obj(text):
    """A row or deps object text, decoded, or Rejected (R_ROW)."""
    try:
        v = parse(text)
    except Malformed:
        raise Rejected("R_ROW")
    if type(v) is not dict:
        raise Rejected("R_ROW")
    return v


def resolve(case):
    """A resolver conformance case's result (RULES.md §6; kernel/tests/rules/resolver_suite.py): the selected revision's
    fetchedAt, its effective knownAt or code, and its visibility at each query."""
    try:
        expr = check(case["rule"], [*case["fields"], "fetchedAt"], case["deps_declared"])
    except RuleError:
        return "E_RULE"
    queries, version = case["queries"], case["version"]
    eligible = [r for r in case["revisions"] if r["fetchedAt"] <= version]
    if len({r["fetchedAt"] for r in eligible}) != len(eligible):
        return "INVALID"
    if not eligible:
        return {"selected": None, "knownAt": None, "visible": [False] * len(queries)}
    selected = max(eligible, key=lambda r: r["fetchedAt"])
    earliest = min(eligible, key=lambda r: r["fetchedAt"])
    if selected["tombstone"]:
        return {"selected": selected["fetchedAt"], "knownAt": None, "visible": [False] * len(queries)}
    known = effective(expr, selected, earliest, case["lags"])
    return {"selected": selected["fetchedAt"], "knownAt": known,
            "visible": [type(known) is int and known <= t for t in queries]}


def effective(expr, selected, earliest, lags):
    """The selected revision's effective knownAt: its rule's value, raised to its fetchedAt if it is a correction and to
    every dependency's time plus its lag; or the code of a rejection."""
    try:
        row, deps, first = obj(selected["row"]), obj(selected["deps"]), obj(earliest["row"])
        known = evaluate(expr, {**row, "fetchedAt": selected["fetchedAt"]}, deps)
        if any(typed(row.get(k)) != typed(first.get(k)) for k in row.keys() | first.keys()):
            known = max(known, selected["fetchedAt"])
        for d, lag in sorted(lags.items()):
            known = max(known, ranged(deps[d] + lag))
        return known
    except Rejected as r:
        return r.code


def main(fn=result):
    for line in sys.stdin:
        print(json.dumps(fn(json.loads(line))), flush=True)


if __name__ == "__main__":
    main(resolve if sys.argv[1:] == ["resolve"] else result)
