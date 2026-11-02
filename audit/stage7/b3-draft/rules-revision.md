# B3 draft: RULES.md's revision of §6 and §7 (not frozen)

Draft text of one dated revision, from the decision of 2026-11-02 01:32 UTC ("B3's draft suite is not frozen",
`audit/decisions.md`) and its reviews (`audit/stage7/b3-review-{gpt,claude}.md`). At the freeze it is appended to
`kernel/RULES.md` §6 (the first part) and replaces §7's resolver sentence (the second), and `laws-frozen.md` records
RULES.md's new hash. No Lean changes. Everything below the line is the text to append.

---

### Revision of 2026-11-02, B3: stored bytes, and the resolver restated whole

From both B3 reviews (`audit/stage7/b3-review-{gpt,claude}.md`; decision of 2026-11-02 01:32 UTC). It changes no result
of the revisions above; it states what they left open, and restates resolution whole so that it reads without them.

**Stored bytes.** A revision's stored columns and its lineage are JSON texts read as §1 reads them. A dataset is
invalid, as when two eligible revisions of one key share a fetchedAt, if any eligible revision (fetchedAt ≤ V) does not
decode; revisions fetched after V are not examined. One does not decode if:
- its stored columns are malformed, or not an object; or a member is not a **cell** (an integer, a non-integer number, a
  string, a boolean or null: an array or object is not); or a member is named `fetchedAt`, `source`, `hash`, the
  tombstone column or a revision column;
- its event column is absent or not an integer in range;
- its lineage is malformed, or not an object; or any member, whether or not it names a declared dependency, is not an
  array of **lineage keys** `[S, [c1, …, ck], e]`, with S a string, each ci a cell and e an integer in range; or a key's
  S is not a declared source, or its k differs from the number of S's entity columns.

§5's `R_ROW` is never a resolver result. A revision that decodes and whose rule evaluation is rejected, whose lineage is
unusable, or whose slot or role payload does not decode, follows the timeline below. A well-shaped lineage key of a
declared source outside its dependency, or one naming a key with no delivery, makes the revision unusable; it is never
malformed. A lineage member naming no declared dependency is checked as above and not resolved.

**Cells.** An integer and a non-integer number are different values even when numerically equal (`1` and `1.0`
differ). A non-integer number's value is the IEEE 754 binary64 number nearest its decimal value, ties to even; one whose
magnitude rounds to infinity does not decode. Two cells are equal if both are integers of one value, both non-integers
of one value (the two zeros being one value), or both the same string (§1), boolean or null. An absent column is null.

**Keys.** A source's key is its entity, the list of its entity columns' cells in declared order, and its event time,
the event column's integer. Keys are compared as decoded cells, never as bytes, so `"BTC"` and `"BTC"` are one
entity and `["ab", "c"]` and `["a", "bc"]` two. A lineage key `[S, [c1, …, ck], e]` names the key of S with entity
`[c1, …, ck]` and event time e.

**Slots and roles.** An event source's slot decodes if and only if its slot column holds an integer; it need not equal
the event time. A role provider's payload decodes if and only if each of its role's columns decodes: for bars, `open`,
`high`, `low` and `close` are numbers (`num`: an integer or a non-integer, as its value) and `trades` an integer; for
settlement, `rate` is a number.

**Timeline.** A key's timeline at V is built from its eligible revisions in fetchedAt order. Let *last* be the eligible
revision before the current one, and *prev* the knownAt of the timeline's latest entry. For each revision r:
1. If r is identical to *last* (no declared value or control column differs as cells, other than `fetchedAt` and the
   revision and tombstone columns, and the tombstone flag is the same), r adds nothing.
2. Otherwise, r's candidate knownAt, if r is usable, is the rule's value on r's row with each dependency's upstream
   time; raised to r's fetchedAt if *last* exists; raised to *prev* if it exists; and raised to each dependency's
   upstream time plus its lag. Each raise is range-checked like any bound. r is **unusable** if its rule evaluation is
   rejected (§5), a raise is out of range, its slot or role payload does not decode, or its lineage is unusable.
3. A dependency's **upstream time** is the latest, over the lineage keys r lists for it, of that key's latest knownAt
   among its timeline's entries (a retraction included) whose fetchedAt is no later than r's. The lineage is unusable
   if a dependency of r's source lists no key, a key of a source the dependency does not name, or a key with no such
   entry; one unusable key is never masked by another.
4. If there is no entry yet: a tombstone or an unusable r adds nothing; a usable r is an entry at its candidate.
   If there is: a tombstone or an unusable r is a **retraction** at its fetchedAt raised to *prev*, and a usable r an
   entry at its candidate. A retraction keeps the slot of the entry it retracts; there is never a fallback to an older
   value.

**Visibility.** A query at t sees the key's latest entry with knownAt ≤ t, or nothing if that is a retraction or there
is none. Evidence sources' keys, and keys mapped to no coin of U, are read only as upstream keys and never delivered.

---

### §7, the resolver's case format (replaces the sentence beginning "Resolver cases give a store fixture")

A resolver case is one store at one dataset version:

```json
{"universe": [COIN, ...],
 "sources": [{"name": S, "rule": TEXT, "times": [COL, ...], "values": [COL, ...], "entity": [COL, ...],
              "event": COL, "slot": COL or null, "roles": null or {"bars": [O, H, L, C, T]} or {"settlement": [R]},
              "evidence": BOOL, "deps": [{"name": N, "sources": [S, ...], "lag": D}, ...]}, ...],
 "rows": [{"source": S, "fetchedAt": INT, "tombstone": BOOL, "cells": TEXT, "upstream": TEXT}, ...],
 "version": V, "queries": [t, ...]}
```

- A source is a declaration reduced to what resolution reads. `times` are its rule's Time fields (`fetchedAt`, the
  revision's own, is always in the rule's context and never listed); `values` its value columns; `entity` its entity
  columns; `event` its event column, among `times`; `slot` an event source's slot column; `roles` its role columns.
  Its declared columns, compared by step 1 of §6's timeline, are `values`, `times`, `event`, `slot`, `entity` and the
  role columns. No source has revision columns, and the tombstone column is named `tombstone`; the flag itself is the
  row's. Sources may be declared in any order; every case's registry is otherwise valid (paper §5).
- `cells` and `upstream` are the revision's stored texts, passed as text and never pre-decoded. A non-evidence source's
  key maps to the universe's coin equal to its `coin` cell, else to none.
- The result is `"E_RULE"` if a source's rule fails checking (§4) against its `times` and its dependencies' names,
  whatever the rows hold; `"INVALID"` for an invalid dataset; and otherwise

```json
{"keys": [{"source": S, "entity": [...], "event": INT, "coin": INT or null,
           "timeline": [[FETCHEDAT, KNOWNAT, RETRACTION, SLOT, CELLS, ROLE], ...],
           "visible": [FETCHEDAT or null per query]}, ...]}
```

  listing every key with an eligible revision, sorted by source name, then entity, then event time (cells ordered:
  null, booleans false before true, integers, non-integers, strings by their scalar values; numbers by value; lists
  element by element). Evidence keys and keys outside U are listed, with `coin` null, though never delivered: derived
  rows read their timelines. `CELLS` is the entry's revision's declared columns, an object sorted by name, an absent
  column as null; `ROLE` its role payload, the role's columns' cells as an array in the role's order, or null for a
  retraction or a source with no role; `SLOT` the entry's slot, or null for a source without one; `coin` an index into
  `universe`. `visible` names, per query t, the fetchedAt of the entry the query sees, or null.
- The size of a resolver suite is its (key, query) pairs over cases that are neither `"INVALID"` nor `"E_RULE"`.
