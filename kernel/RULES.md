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

### Revision 2026-10-26 23:28 UTC (19:28 EDT), human decision: bitemporal resolution

GPT's sixth review of stage 7's Lean (`audit/stage7/laws-review-gpt-6.md`) showed that the selection above lets
information recorded after a query time change what the query sees: a correction fetched at F leaves its key with no
observation before F; a later tombstone removes the key from the past; a differing unused column delays it. The
resolver is therefore bitemporal. Selection and Visibility above are replaced by the following; rule evaluation,
the derivation bound, the range and dataset validity stand.

- **Timeline.** A key's eligible revisions (fetchedAt ≤ V), in fetchedAt order, each delivered at its own effective
  knownAt. A revision identical to the one before it (no observed column differs, as values, an absent column
  being null, and the same tombstone flag) adds nothing.
- **Effective knownAt** of each delivered revision: the rule's value on its row, raised to its fetchedAt if it is not
  the key's first delivered revision (it is then a correction of the one before it), to the knownAt of the revision
  it replaces, and by the derivation bound, where a dependency's upstream time is the latest knownAt among the
  upstream key's delivered revisions that are not retractions.
- **Retractions.** A tombstone, or a revision whose rule evaluation is rejected, is delivered as a retraction (the key
  has no value from then on) at its fetchedAt, raised to the knownAt of the revision it replaces; there is never a
  fallback to an older revision. One before any delivered revision adds nothing.
- **Visibility.** A query at time t sees the key's latest delivered revision with knownAt ≤ t, or nothing if that
  is a retraction or none is delivered by t. Execution's reads of venue state (bars and settlement rates by event
  time) use each key's final delivered revision.

A key with one revision resolves exactly as before. The reference is `reference/lean/Ref/Resolve.lean` (`timeline`,
`resolveAll`); the C7.6 suites are revised to match before any judged run (`audit/criteria.md`, C7.6).

### Revision 2026-10-26 23:39 UTC (19:39 EDT), second: causal lineage, decoding, declared columns

From GPT's seventh review (`audit/stage7/laws-review-gpt-7.md`), so that no record fetched after a query time changes
what the query sees:
- **Derivation bound.** A dependency's upstream time is the latest knownAt among the upstream key's delivered
  revisions, not retractions, recorded no later than the derived revision itself.
- **Decoding.** A revision whose event slot or role payload does not decode is a retraction, like a rejected rule
  evaluation; each delivered revision carries its own slot, and a retraction keeps the slot of what it retracts.
- **Declared columns.** Whether a revision differs from the one before it is judged on the declaration's value and
  control columns only (not `fetchedAt`, the revision or tombstone columns, or undeclared columns).
- **Order.** Deliveries at one knownAt are ordered by event time then recording time for held sources (version 1's),
  and by recording time then event time for event sources; never by stored row order.
- A retraction's knownAt is range-checked like any bound.
- Every eligible revision after a key's first is known no earlier than its fetchedAt, whether or not the revisions
  before it were delivered (third revision, 2026-10-26 23:43 UTC, from GPT's eighth review); an eligible revision with an
  out-of-range fetchedAt makes the dataset invalid.

Execution's reads of each key's final revision are the stated exception: later-recorded evidence of the venue state
applied at event time may change historical fills, funding, marks and equity, and through equity later order sizes.
Two further effects are by design, not leaks: a key's first revision is known at its rule's value, which may precede
its fetchedAt (a backfill whose availability the certificate's basis governs, `CERTIFICATES.md`); and admission's
checks (dataset validity, holdout, scope) are global over the run, so a later record can refuse a whole run, which
then returns no output. No other later record changes what a decision sees (GPT's ninth review found none).

### Revision of 2026-11-01, B2: a dependency spans sources (frozen 2026-11-02 00:55 UTC (2026-11-01 19:55 EST), `audit/stage7/laws-frozen.md`)

Decision of 2026-11-01 16:59 UTC (`audit/decisions.md`), from both B2 reviews (`audit/stage7/b2-review-{claude,gpt}.md`):
- **Keys.** A source's key is its stored entity and event time. A coin-keyed source's stored entity maps to a coin of U
  or to none; an evidence source's (SOURCES.md §1) is outside U, and its records are read only as upstream keys. A
  dataset whose eligible revisions of one entity map to different coins is invalid. Two entities mapped to one coin are
  two keys, no longer one (certification forbids such a mapping; admission refuses a run in which both have a final
  delivery at one event time).
- **Derivation bound.** A dependency names one or more upstream sources (SOURCES.md §5), and a derived revision lists,
  per dependency, the upstream keys it was computed from as (source, stored entity, event time). The dependency's
  upstream time is the latest, over those keys, of each key's latest knownAt among its delivered revisions recorded no
  later than the derived revision, a retraction included (this replaces "not retractions" in the two revisions above:
  under the second's cutoff, a retraction counted is one the derived revision could see). The revision is unusable if a
  dependency lists no key, a key of a source it does not name, or a key with no such delivery: one unusable key is never masked by another. A
  lineage names each dependency once.

### Revision of 2026-11-06 19:55:41 UTC (14:55:41 EST), B3: what the resolver reads, and the resolver restated whole

From the B3 reviews (`audit/stage7/b3-review-{gpt,claude}.md`, `b3-fixes-review-{gpt,claude}.md`,
`b3-round{3,4,5,6,7,8}-review-{gpt,claude}.md`, `b3-round9-review-gpt.md`, `b3-round10-review-claude.md`;
decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) and 05:55 UTC (00:55 EST)).
It restates resolution whole, so that it reads without the text above; where that text differs, this governs. It
replaces two things: §5's `R_ROW` as a resolver outcome (a stored row that does not decode was a rejected evaluation, so
a retraction; it now makes the dataset invalid); and, for stored non-integer cells only, §1's "No value is ever rounded
or converted to floating point" (rule arithmetic stays exact and integer). §1's example of one string reads `"\u0074"`
and `"t"`.

**What the resolver reads.** Of each stored revision, the resolver reads only its metadata (its fetchedAt and tombstone
flag), its declared columns, each as a **cell**, and, for a derived source's revision that is not a tombstone, its
lineage; undeclared columns, and a tombstone's lineage, are never read. A cell is an integer from −2^63 to 2^63 − 1, a
non-integer number, a string, a boolean or null; each stored representation maps to cells by its own mapping: JSON texts
by §7, Parquet by SOURCES.md §2. A dataset is invalid, as when two eligible revisions of one key share a fetchedAt, if
any eligible revision (fetchedAt ≤ V) does not decode; revisions fetched after V are not examined. One does not decode
if:
- a declared column's stored value is not a cell under its representation's mapping;
- its event column is null, absent or not an integer in range;
- it is a derived source's revision that is not a tombstone, and its lineage is null or absent, does not decode under
  its mapping, or is not an object; or any member, whether or not it names a declared dependency, is not an array of
  **lineage keys** `[S, [c1, …, ck], e]`, with S a string, each ci a cell and e an integer in range; or a key's S is not
  a declared source, or its k differs from the number of S's entity columns.

A revision that decodes and whose rule evaluation is rejected, whose lineage is unusable, or whose slot or role payload
does not decode, follows the timeline below. A well-shaped lineage key of a declared source outside its dependency, or
one naming a key with no entry fetched no later than the revision (step 3), makes the revision unusable; it is never
malformed. A lineage member naming no declared dependency is checked as above and not resolved.

**Cells.** An integer and a non-integer number are different values even when numerically equal (`1` and `1.0` differ).
An integer outside −2^63 to 2^63 − 1, the one range both representations carry exactly, is not a cell. A non-integer
number's value is the IEEE 754 binary64 number nearest its decimal value, ties to even, so two spellings rounding to one
binary64 number are one value (`1.0` and `1.00000000000000001`); one whose magnitude rounds to infinity is not a cell. A
cell that is a number has a **`num`**, always a finite binary64 number: a non-integer's value, its sign kept (`-0.0`'s
is −0.0), and an integer's nearest binary64 number, ties to even (2^53 + 1 is 2^53). Two cells are equal if both are integers of one value, both
non-integers of one value (the two zeros being one value), or both the same string (§1), boolean or null. An absent
column is null.

**Keys.** A source's key is its entity, the list of its entity columns' cells in declared order, and its event time, the
event column's integer. Keys are compared as cells, never as stored bytes, so `"\u0042TC"` and `"BTC"` are one entity
and `["ab", "c"]` and `["a", "bc"]` two. A lineage key `[S, [c1, …, ck], e]` names the key of S with entity `[c1, …,
ck]` and event time e.

**Slots and roles.** An event source's slot decodes if and only if its slot column holds an integer; it need not equal
the event time. A role provider's payload decodes if and only if each of its role's columns decodes: for bars, `open`,
`high`, `low` and `close` are numbers (integers or non-integers, delivered as their `num`) and `trades` an integer; for
settlement, `rate` is a number.

**Timeline.** A key's timeline at V is built from its eligible revisions in fetchedAt order. Let *last* be the eligible
revision before the current one, and *prev* the knownAt of the timeline's latest entry. For each revision r:
1. If r is identical to *last* (no declared column differs as cells, and the tombstone flag is the same), r adds
   nothing.
2. Otherwise, r's candidate knownAt, if r is usable, is the rule's value on r's row with each dependency's upstream
   time; raised to r's fetchedAt if *last* exists; raised to *prev* if it exists; and raised to each dependency's
   upstream time plus its lag. Each raise is range-checked like any bound. r is **unusable** if its rule evaluation is
   rejected (§5), a raise is out of range, its slot or role payload does not decode, or its lineage is unusable.
3. A dependency's **upstream time** is the latest, over the lineage keys r lists for it, of that key's latest knownAt
   among its timeline's entries (a retraction included) whose fetchedAt is no later than r's. The lineage is unusable if
   a dependency of r's source lists no key, a key of a source the dependency does not name, or a key with no such entry;
   one unusable key is never masked by another.
4. If there is no entry yet: a tombstone or an unusable r adds nothing; a usable r is an entry at its candidate. If
   there is: a tombstone or an unusable r is a **retraction** at its fetchedAt raised to *prev*, and a usable r an entry
   at its candidate. A retraction keeps the slot of the entry it retracts and delivers no value and no role payload;
   there is never a fallback to an older value.

**Visibility and delivery.** A query at t sees the key's latest entry with knownAt ≤ t, or nothing if that is a
retraction or there is none. Each entry of a delivered key is one observation: its fetchedAt, knownAt and slot (on a
retraction, the slot of the entry it retracts); its role payload and each value column's `num` (undefined if not a
number), both undefined on a retraction; and whether it is the key's final entry, which execution reads. Evidence
sources' keys, and keys mapped to no coin of U, are read only as upstream keys and never delivered.

## 7. Conformance

Implementations are compared on cases of the form

```json
{"rule": "<rule document text>", "fields": ["…"], "deps_declared": ["…"], "row": "<row text>", "deps": "<deps text>"}
```

where the three texts are passed as text, never pre-decoded. The result is the JSON integer of the Time,
or the code string (`"E_RULE"`, `"R_ROW"`, `"R_FIELD_ABSENT"`, `"R_FIELD_TYPE"`, `"R_OVERFLOW"`). `E_RULE`
takes precedence over everything about the row. Host exceptions, parser diagnostics and resource limits
are never language results; a case that produces one fails the comparison.

A resolver case is one store at one dataset version:

```json
{"universe": [COIN, ...],
 "sources": [{"name": S, "rule": TEXT, "times": [COL, ...], "values": [COL, ...], "entity": [COL, ...],
              "event": COL, "slot": COL or null, "roles": null or {"bars": [O, H, L, C, T]} or {"settlement": [R]},
              "evidence": BOOL, "deps": [{"name": N, "sources": [S, ...], "lag": D}, ...]}, ...],
 "rows": [{"source": S, "fetchedAt": INT, "tombstone": BOOL, "cells": TEXT, "upstream": TEXT or null}, ...],
 "version": V, "queries": [t, ...]}
```

- A source is a declaration reduced to what resolution reads. `times` are its rule's Time fields (`fetchedAt`, the
  revision's own, is always in the rule's context and never listed); `values` its value columns; `entity` its entity
  columns; `event` its event column, among `times`; `slot` an event source's slot column; `roles` its role columns. Its
  declared columns are `values`, `times`, `event`, `slot`, `entity` and the role columns; a non-evidence source's one
  entity column is `coin`. No source has revision columns; the tombstone flag is the row's. Sources may be declared in
  any order; every case's registry is otherwise valid (paper §5).
- `cells` and `upstream` are the revision's stored texts, passed as text and never pre-decoded. **The JSON mapping:** a
  text is read whole as §1 reads it, and one that is malformed or not an object does not decode. Of `cells`, a member
  that is not a declared column is never read; a declared member's value maps an integer to an integer (not a cell
  outside §6's range), a non-integer number to a non-integer, and a string, boolean or null to itself, and an array or
  object is not a cell. `upstream` is the lineage, whose keys' cells map the same way; null is a lineage that does not
  decode. A non-evidence source's key maps to the universe's coin equal to its `coin` cell, else to none.
- The result is `"E_DECL"` if a source's declared columns include one of the store's metadata columns (SOURCES.md
  §1, revision of 2026-11-04); else `"E_RULE"` if a source's rule fails checking (§4) against its `times` and its
  dependencies' names; both whatever the rows hold; `"INVALID"` for an invalid dataset; and otherwise

```json
{"keys": [{"source": S, "entity": [...], "event": INT, "coin": INT or null,
           "timeline": [[FETCHEDAT, KNOWNAT, RETRACTION, SLOT, CELLS, ROLE], ...],
           "visible": [FETCHEDAT or null per query]}, ...]}
```

  listing every key with an eligible revision, sorted by source name, then entity, then event time (cells ordered: null,
  booleans false before true, integers, non-integers, strings by their scalar values; numbers by value within their
  kind; lists element by element). Evidence keys and keys outside U are listed, with `coin` null, though never
  delivered: derived rows read their timelines. `CELLS` is the entry's revision's declared columns, an object sorted by
  name, an absent column as null, or null for a retraction; `ROLE` its role payload, the role's columns' cells as an
  array in the role's order, or null for a retraction or a source with no role; `SLOT` the entry's slot, or null for a
  source without one; `coin` an index into `universe`. `visible` names, per query t, the fetchedAt of the entry the
  query sees, or null.
- For C7.6's loader-level comparison, a loader also gives a resolving case's observations (§6, "Visibility and
  delivery"): `[SOURCE, COIN, EVENT, FETCHEDAT, KNOWNAT, RETRACTION, SLOT, [VALUE, ...], ROLE, FINAL]` per observation,
  sorted by source name, coin, event time and fetchedAt; values in `values` order, each value and ROLE's numbers as
  their binary64 bits (an integer), `trades` as its integer, anything undefined as null.
- Results are JSON texts read as §1 reads them and compared as cells: an integer equals only an integer and a
  non-integer only a non-integer, so a non-integer is printed with a fraction or an exponent (`1.0`, never `1`); arrays
  compare element by element, objects member by member in any order.

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
