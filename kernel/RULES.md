# The availability rule language and resolver, version 1

An availability rule computes a candidate time at which one stored revision of an observation became
usable. The **resolver** turns that candidate into the revision's effective `knownAt`, enforcing bounds
no rule can remove, and decides which revision a query sees. Both are deterministic and total: every
input gets a value or exactly one of the codes below, never anything else. A rule reads only its row's
fields and the dependency times the resolver supplies, and uses no host code, I/O, clock or
randomness. This document is the whole specification (C7.6): implementations that follow it agree on
every input. A frozen version's meaning never changes; any change is a new version number.

## 1. JSON texts

Rule documents, rows and dependency maps are JSON texts, read as follows. A text that breaks any rule of
this section is **malformed**.

- UTF-8 without a byte-order mark, holding exactly one RFC 8259 value followed only by JSON whitespace.
  No comments, trailing commas, `NaN` or `Infinity`.
- Strings decode to sequences of Unicode scalar values; an escape denoting an unpaired surrogate is
  malformed. Strings are compared by those sequences, without normalization or case folding, so `"t"`
  and `"t"` are the same string.
- No object has two members with the same decoded key, at any depth.
- **Depth:** the outermost value has depth 1, and each array or object inside another adds 1. A text
  of depth greater than 64 is malformed. A rule document longer than 65,536 bytes is malformed.
- **Numbers** are classified by their spelling. An **integer** is a number token matching
  `-?(0|[1-9][0-9]*)`; its value is the exact mathematical integer, and `-0` is 0. Any other number
  token (with a fraction or an exponent: `1.0`, `1e3`) is a **non-integer**, whatever its value.
  `true`, `false` and `null` are never numbers. No value is ever rounded or converted to floating
  point. Every in-range integer has at most 19 digits, so an implementation may treat a longer integer
  token as out of range without computing it.

## 2. Values and types

Two types, with no conversion between them:

- **Time**: an instant, an integer number of ms since 1970-01-01T00:00:00Z. It may be negative.
- **Duration**: an integer number of ms, ≥ 0.

The **range** is [−2^62, 2^62 − 1]. It applies to every expression node's value, leaves included, and
to the resolver's results; implementations compute each node's exact mathematical result and then check
it. Machine overflow, wrapping and saturation are never language semantics.

## 3. Rule documents and expressions

A rule document is an object with exactly the two members `{"rule": 1, "expr": E}`, where `rule` is the
integer 1 and E is an expression of type Time. Every expression is an object with exactly one member,
its operator:

| Expression | Type | Meaning |
|---|---|---|
| `{"field": NAME}` | Time | the row's field NAME |
| `{"dep": NAME}` | Time | the time the resolver supplies for dependency NAME |
| `{"ms": N}` | Duration | the integer constant N, 0 ≤ N ≤ 2^62 − 1 |
| `{"add": [T, D]}` | Time | T + D, with T of type Time and D of type Duration, in that order |
| `{"floor": [T, P]}` | Time | the largest multiple of P that is ≤ T: P × ⌊T / P⌋; P is a constant `{"ms": N}` with N > 0 |
| `{"max": [T1, …, Tk]}` | Time | the largest of 2 ≤ k ≤ 16 Time arguments |

NAME is any non-empty string. `add` and `floor` take arrays of exactly two expressions. Anything else in
an expression position (an unknown operator, an object with zero or several members, a number, a
string, an array, `null`) is malformed. The floor's grid has its origin at the epoch, and a time on the
grid is its own floor: `floor(t, 3600000)` is the start of t's UTC hour, and `floor(−1, 3600000)` is
−3,600,000.

## 4. Checking

A rule is checked once, against a **context**: the set of field names its declaration gives type Time,
and the set of its declared dependency names. Checking rejects the rule with `E_RULE` if:

1. its text is malformed, or it is not a rule document of version 1;
2. an expression has the wrong type for its position, or `expr` is not of type Time;
3. a `field` name is not one of the context's Time fields, or a `dep` name not one of its dependencies;
4. a constant is out of range, or a `floor` period is not a constant greater than 0;
5. its **lower-bound set** is empty or lacks a declared dependency. The lower-bound set LB holds terms tagged by
   kind: LB(field f) = {field f}; LB(dep d) = {dep d}; LB(add [e, D]) = LB(e); LB(max [e1, …]) = LB(e1) ∪ … ∪
   LB(ek); LB(floor …) = ∅. Every declared dependency d must appear as dep d: a field with the same name does
   not count. (Clarified 2026-10-26, before any judged run, after GPT's independent implementation read the
   untagged notation literally.)

Rule 5 makes every accepted rule's value at least one recorded time it names and at least every
declared dependency's time, so a rule cannot backdate below what it reads: a floored time counts only
inside a `max` with an unfloored one. `E_RULE` rejects the rule, and any binding requiring it, before
any row is evaluated; it is never a per-row result, and there is no default rule.

## 5. Evaluating a checked rule on a row

A **row** is a JSON object text mapping field names to values, and **deps** a JSON object text mapping
dependency names to values. Both are read in full first: a malformed row or deps text, or one whose
outermost value is not an object, gives `R_ROW`. Members the rule never reads need only be well formed.

Then the expression is evaluated depth-first, left to right; each operand is evaluated completely before
the next, and the first rejection reached is the result (`max` evaluates every argument up to the first
rejection, with no short-circuit by value):

- `{"field": NAME}`: if NAME is absent from the row or its value is `null`, `R_FIELD_ABSENT`; if the
  value is not an integer (a non-integer number, a boolean, a string, an array, an object),
  `R_FIELD_TYPE`; if it is out of range, `R_OVERFLOW`; otherwise its value.
- `{"dep": NAME}`: the same, against deps.
- `{"ms": N}`: N.
- `{"add": [T, D]}`: T + D, or `R_OVERFLOW` if out of range.
- `{"floor": [T, P]}`: P × ⌊T / P⌋ (Euclidean), or `R_OVERFLOW` if out of range (only possible for T
  near −2^62).
- `{"max": [T1, …]}`: the largest value.

The result is a Time or exactly one of `R_ROW`, `R_FIELD_ABSENT`, `R_FIELD_TYPE` and `R_OVERFLOW`.

## 6. The resolver

The resolver applies a source's pinned rule to its stored revisions. A source's stored revisions each
have a key (`coin`, `eventTime`), observed columns, `fetchedAt` (the trusted time at which our recorder
or backfill stored it, an integer of ms) and, for a key a complete fetch no longer lists, a **tombstone**
flag. Time-typed columns are stored as integers of ms; a column of another type cannot be a Time field
(binding rejects it).

- **Dataset version.** A dataset version V is a fetchedAt cutoff, and pins each source's rule as the
  exact bytes of its rule document and their SHA-256. A corrected rule is a new dataset version; no
  stored output of another rule, cached knownAt included, is ever authoritative.
- **Selection.** For each key, the eligible revisions are those with fetchedAt ≤ V. The selected
  revision is the eligible one with the largest fetchedAt; two eligible revisions of one key with the
  same fetchedAt make the dataset invalid. No eligible revision, or a selected tombstone, means the key
  has no observation. Selection happens before availability and does not depend on the query time.
- **Effective knownAt** of the selected revision R is the rule's value on R's row, raised by two bounds
  no rule can remove:
  - **Corrections.** If R's observed columns (all stored columns except `fetchedAt`, `source`, `hash`
    and the tombstone flag, compared as values, with a column absent from one revision treated as null)
    differ from those of the key's earliest revision, R is a correction, and its knownAt is at least its
    fetchedAt.
  - **Derived sources.** For a derived source, each dependency d has a declared processing delay D_d ≥
    0, and the resolver supplies deps[d] as the latest effective knownAt among the upstream revisions
    the derived row was computed from, resolved at the same dataset version under the upstream's own
    pinned rule. The derived row's knownAt is at least deps[d] + D_d for every d. A dependency with no
    usable upstream knownAt makes the row unusable. Dependency graphs are acyclic; a cycle makes the
    dataset invalid.
  - Each bound is computed exactly; a value out of range is `R_OVERFLOW`.
- **Visibility.** A query at time t sees the selected revision exactly when its effective knownAt ≤ t.
  A rejected rule evaluation, or knownAt > t, leaves the key with no observation at t: there is never a
  fallback to an older revision.

Which rule a source uses, and which time scope it covers (for example, a feed's own timestamps only
where they are protocol-enforced or server-set and a live test passed, and `fetchedAt` alone where a
row is usable only prospectively), is the certificate's business (`CERTIFICATES.md`), not this
language's. A rule names its times; it never chooses among them by whether they are present: an absent
field rejects the row.

## 7. Conformance

Implementations are compared on cases of the form

```json
{"rule": "<rule document text>", "fields": ["…"], "deps_declared": ["…"], "row": "<row text>", "deps": "<deps text>"}
```

where the three texts are passed as text, never pre-decoded. The result is the JSON integer of the Time,
or the code string (`"E_RULE"`, `"R_ROW"`, `"R_FIELD_ABSENT"`, `"R_FIELD_TYPE"`, `"R_OVERFLOW"`). `E_RULE`
takes precedence over everything about the row. Host exceptions, parser diagnostics and resource limits
are never language results; a case that produces one fails the comparison. Resolver cases give a store
fixture, a dataset version and query times, and compare, per key and query, the selected revision's
fetchedAt, its effective knownAt or code, and whether it is visible.

## 8. Examples

With HOUR = 3,600,000, δ = 120,000 and a settlement latency of 60,000:

| `expr` | row | result |
|---|---|---|
| `{"add": [{"field": "eventTime"}, {"ms": 120000}]}` | `{"eventTime": 14400000}` | 14520000 |
| `{"max": [{"add": [{"floor": [{"field": "reportedTime"}, {"ms": 3600000}]}, {"ms": 120000}]}, {"add": [{"field": "reportedTime"}, {"ms": 60000}]}]}` | `{"reportedTime": 7200048}` | 7320000 |
| the same | `{"reportedTime": 22487645}` | 22547645 |
| `{"max": [{"floor": [{"field": "t"}, {"ms": 3600000}]}, {"field": "t"}]}` | `{"t": -1}` | −1 |
| `{"max": [{"floor": [{"field": "t"}, {"ms": 3}]}, {"field": "t"}]}` | `{"t": -4611686018427387904}` | `R_OVERFLOW` |
| `{"add": [{"field": "t"}, {"ms": 1}]}` | `{"t": 4611686018427387903}` | `R_OVERFLOW` |
| `{"field": "t"}` | `{"t": 1.0}` | `R_FIELD_TYPE` |
| `{"field": "t"}` | `{"t": true}` | `R_FIELD_TYPE` |
| `{"field": "t"}` | `{"t": -0}` | 0 |
| `{"max": [{"field": "a"}, {"field": "b"}]}` | `{"b": "x"}` | `R_FIELD_ABSENT` (a is reached first) |
| `{"field": "t"}` | `{"t": 1, "t": 2}` | `R_ROW` |
| `{"floor": [{"field": "t"}, {"ms": 3600000}]}` | any | `E_RULE` (empty lower-bound set) |
| `{"add": [{"ms": 1}, {"field": "t"}]}` | any | `E_RULE` (operands out of order) |

The second and third rows are the pilot's funding rule: a rate reported 48 ms after the hour is known at
the hour plus δ, and one reported 887,645 ms late at its report plus the latency.
