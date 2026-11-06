# B3 draft: RULES.md's revision of §6 and §7, and SOURCES.md's of §2 (not frozen)

Draft text of two dated revisions, from the decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) ("B3's draft suite
is not frozen") and 05:55 UTC (00:55 EST) ("B3's fixes are not frozen; second round ruled on", `audit/decisions.md`) and
their reviews (`audit/stage7/b3-review-{gpt,claude}.md`, `b3-fixes-review-{gpt,claude}.md`). At the freeze the first
part is appended to `kernel/RULES.md` §6, the second replaces §7's resolver sentence, the third is appended to
`kernel/SOURCES.md` §2, and `laws-frozen.md` records RULES.md's new hash. No change to frozen Lean (`Ref/`). Everything
below each line is the text to append.

---

### Revision at the freeze, B3: what the resolver reads, and the resolver restated whole

From the B3 reviews (`audit/stage7/b3-review-{gpt,claude}.md`, `b3-fixes-review-{gpt,claude}.md`,
`b3-round{3,4,5,6,7,8}-review-{gpt,claude}.md`, `b3-round9-review-gpt.md`, `b3-round10-review-claude.md`,
`b3-round8-calibration-argon.md`, answered against round 10 in round 11;
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
by §7, Parquet by SOURCES.md §2. A dataset is invalid if two eligible revisions of one key share a fetchedAt, an
eligible revision's fetchedAt is outside §2's range [−2^62, 2^62 − 1], eligible revisions of one entity map to different
coins, or any eligible revision does not decode. Eligible means fetchedAt ≤ V; revisions fetched after V are not
examined. One does not decode if:
- a declared column's stored value is not a cell under its representation's mapping;
- its event column is null, absent or not an integer in §2's range [−2^62, 2^62 − 1];
- it is a derived source's revision that is not a tombstone, and its lineage is null or absent, does not decode under
  its mapping, or is not an object; or any member, whether or not it names a declared dependency, is not an array of
  **lineage keys** `[S, [c1, …, ck], e]`, with S a string, each ci a cell and e an integer in §2's range
  [−2^62, 2^62 − 1]; or a key's S is not
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
   upstream time plus its lag. Each raise is checked against §2's range [−2^62, 2^62 − 1], like any bound. r is
   **unusable** if its rule evaluation is rejected (§5), a raise is outside that range, its slot or role payload does
   not decode, or its lineage is unusable.
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

---

### §7, the resolver's case format (replaces the sentence beginning "Resolver cases give a store fixture")

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
  columns; `event` its event column, among `times`; `slot` an event source's slot column (SOURCES.md §1); `roles` its role columns. Its
  declared columns are `values`, `times`, `event`, `slot`, `entity` and the role columns; a non-evidence source's one
  entity column is `coin`. No source has revision columns; the tombstone flag is the row's. Sources may be declared in
  any order; every case's registry is otherwise valid (SOURCES.md §1).
- `cells` and `upstream` are the revision's stored texts, passed as text and never pre-decoded. **The JSON mapping:** a
  text is read whole as §1 reads it, and one that is malformed or not an object does not decode. Of `cells`, a member
  that is not a declared column is never read; a declared member's value maps an integer to an integer (not a cell
  outside −2^63 to 2^63 − 1), a non-integer number to a non-integer, and a string, boolean or null to itself, and an array or
  object is not a cell. `upstream` is the lineage, whose keys' cells map the same way; null is a lineage that does not
  decode. A non-evidence source's key maps to the universe's coin equal to its `coin` cell, else to none.
- The result is `"E_DECL"` if a source's declared columns include one of the store's metadata columns (SOURCES.md
  §1, revision of 2026-11-04); else `"E_RULE"` if a source's rule fails checking (§4) against its `times` (with `fetchedAt`) and its
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

---

### Revision at the freeze, B3: Parquet as cells (SOURCES.md §2)

From the B3 reviews cited above. **For resolution (RULES.md §6)**, not binding's schema validation above: the store holds a dataset's
revisions as every `.parquet` file under its directory (file names carry no timestamp or version meaning), each row one
revision. A column's **type** is its Arrow type as its file
states it: the embedded Arrow schema (`ARROW:schema`) where present, else the Arrow type its Parquet physical and
logical types map to. A **string column** is one of type Utf8 or LargeUtf8, wherever this section names a string. A
row's metadata is `fetchedAt`, a non-null Int64, and `tombstone`, a Boolean (a null, or a file without the column, is
false). The **footer schema checks** require `fetchedAt` to have type Int64 and `tombstone`, if present, Boolean.
Names are the ordered list of direct children of the Parquet schema's root group and, if embedded, the ordered list
of top-level fields of `ARROW:schema`: neither list repeats a name and the two lists must be identical, including order.
Nested leaves are not top-level fields (a List column is one field); undeclared columns' subtrees are ignored.
A file failing these checks makes the dataset invalid, whatever V, since its rows cannot be placed or decoded
unambiguously; so does a null `fetchedAt`, checked after a search's holdout check (C7.6 test 3). For an eligible
non-tombstone derived row, `upstream` decodes only from a non-null string column holding its lineage as a JSON text read
by RULES.md §7's mapping; any other type, a null, or a file without the column is a lineage that does not decode. On
tombstones and post-V rows `upstream` is never read, whatever its type. A declared column's value maps to a cell by the column's type in the file that stores the
row: Int64 to an integer; a finite Double to a non-integer; a string column to a string; Boolean to a boolean; a null of
any of these types to null. Nothing else is a cell: no other type (UInt64, Int32, Decimal, Timestamp, Null, List,
Struct, …), and no NaN or infinite Double. Each row decodes by its own file's types, never by a type unified across
files (which would turn an integer into a non-integer). Undeclared columns are never read, whatever their type (RULES.md
§6, B3 revision).
