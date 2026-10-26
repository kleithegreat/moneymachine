# The availability rule language, version 1

An availability rule computes when one stored observation became usable: its `knownAt`, in integer
milliseconds since the Unix epoch (UTC). Each source declaration names one rule, and a dataset version
pins it. A rule is data: a JSON AST, checked once when it is loaded and then evaluated on each row.
Evaluation is deterministic and total: it returns a time or one of the rejection codes below, never
anything else. It reads only the row's own fields and the declared dependencies supplied with it, and
uses no host code, I/O, clock or randomness. This document is the whole specification: an
implementation that follows it exactly agrees with every other on every rule and row.

## Values and types

There are two types, and no conversion between them:

- **Time**: an instant, an integer number of ms since 1970-01-01T00:00:00Z. It may be negative.
- **Duration**: a length of time, an integer number of ms, **≥ 0**.

Every value that evaluation produces, intermediate ones included, lies in the **range**
[−2^62, 2^62 − 1]. A value outside the range is an overflow (`R_OVERFLOW`); arithmetic is exact
integer arithmetic, so the check is on the exact result.

## Rule documents

A rule document is a JSON object with exactly two keys:

```json
{"rule": 1, "expr": <Time expression>}
```

`rule` is the language version and must be the integer `1`. `expr` must have type Time.

JSON is read strictly. A document with a duplicate key at any level, a number written with a
fraction or an exponent where an integer is required (`1.0`, `1e3`), a value of a JSON type other than
the one required, or nesting deeper than 64 levels is malformed.

## Expressions

Every expression is a JSON object with exactly one key, the operator:

| Expression | Type | Meaning |
|---|---|---|
| `{"field": NAME}` | Time | The row's field NAME. NAME is a non-empty string. |
| `{"dep": NAME}` | Time | The knownAt of the declared dependency NAME, supplied with the row. NAME is a non-empty string. |
| `{"ms": N}` | Duration | The constant N, an integer with 0 ≤ N ≤ 2^62 − 1. |
| `{"add": [T, D]}` | Time | T + D. T has type Time and D type Duration, in that order. |
| `{"floor": [T, P]}` | Time | The latest multiple of P that is ≤ T: T − (T mod P), with mod the Euclidean remainder (0 ≤ T mod P < P, so −1 floors to −P). P is a constant `{"ms": N}` with N > 0. |
| `{"max": [T1, T2, …]}` | Time | The largest of two to sixteen Time arguments. |

Arrays have exactly the arity shown (`add` and `floor` two, `max` two to sixteen). Nothing else is an
expression: an unknown operator, an object with zero or several keys, a bare number or string, or
`null` is malformed.

The floor's grid has its origin at the epoch: `floor(T, 3600000)` is the start of T's UTC hour, and a
time exactly on the grid is its own floor.

## Checking a rule

Checking happens once, before any row is evaluated, against a **context**: the set of field names the
declaration gives type Time, and the set of declared dependency names. A rule is rejected with
`E_RULE` if:

- it is malformed (above);
- an expression has the wrong type for its position, including an `expr` that is not Time;
- a `field` names something outside the context's Time fields, or a `dep` something outside its
  dependencies;
- a constant is outside 0 ≤ N ≤ 2^62 − 1, or a `floor` period is not a constant with N > 0.

The only Duration expression is a constant, so durations never overflow and a period is never zero
at evaluation.

A checked rule has no other way to fail at check time. A rule that is not checked is never evaluated.

## Evaluating a checked rule on a row

A **row** maps field names to JSON values; **deps** maps dependency names to JSON values. Evaluation
proceeds bottom-up, and the **first** rejection in this order is the result: operands of an
operator are evaluated left to right, each completely, before the operator itself.

- `{"field": NAME}`: if NAME is absent from the row, or its value is `null`, the result is
  `R_FIELD_ABSENT`. If the value is not a JSON integer (a boolean, a string, a number with a fraction
  or exponent, an array or an object), the result is `R_FIELD_TYPE`. If the integer is outside the
  range, `R_OVERFLOW`. Otherwise it is the value.
- `{"dep": NAME}`: the same three checks and codes, against deps.
- `{"ms": N}`: N.
- `{"add": [T, D]}`: T + D, or `R_OVERFLOW` if outside the range.
- `{"floor": [T, P]}`: T − (T mod P), Euclidean. (The result is always within the range when T is.)
- `{"max": [T1, …]}`: the largest value.

The result of a rule on a row is either a Time or exactly one of `R_FIELD_ABSENT`, `R_FIELD_TYPE` and
`R_OVERFLOW`. A row whose rule is rejected has no knownAt, and is never delivered.

Integers in rows and deps are compared by their exact mathematical value, whatever their JSON
spelling (`-0` is 0). A JSON integer is a number with no fraction and no exponent part.

`{"floor": [{"field": "t"}, {"ms": 0}]}` and `{"add": [{"ms": 1}, {"field": "t"}]}` are rejected
with `E_RULE`: a zero period, and operands in the wrong order.

## Examples

With HOUR = 3,600,000, δ = 120,000 and a settlement latency of 60,000:

| Rule (`expr`) | Row | Result |
|---|---|---|
| `{"add": [{"field": "eventTime"}, {"ms": 120000}]}` | `{"eventTime": 14400000}` | 14520000 |
| `{"max": [{"add": [{"floor": [{"field": "reportedTime"}, {"ms": 3600000}]}, {"ms": 120000}]}, {"add": [{"field": "reportedTime"}, {"ms": 60000}]}]}` | `{"reportedTime": 7200048}` | 7320000 |
| the same | `{"reportedTime": 22487645}` | 22547645 |
| `{"floor": [{"field": "t"}, {"ms": 3600000}]}` | `{"t": -1}` | −3600000 |
| `{"add": [{"field": "t"}, {"ms": 1}]}` | `{"t": 4611686018427387903}` | `R_OVERFLOW` |
| `{"field": "t"}` | `{"t": 1.0}` | `R_FIELD_TYPE` |
| `{"max": [{"field": "a"}, {"field": "b"}]}` | `{"b": "x"}` | `R_FIELD_ABSENT` (a is first) |

The second row is the pilot's funding rule: a rate reported 48 ms after the hour is known at the
hour plus δ, and one reported 887,645 ms late at its report plus the latency.
