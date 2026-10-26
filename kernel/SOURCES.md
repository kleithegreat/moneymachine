# Source declarations, version 1

A strategy reads data only through declared sources (paper §5). A **declaration** says what a source is: its entity
key, its typed fields, its cadence, how missing values behave, when each observation becomes known (an availability
rule, `RULES.md`) and how revisions resolve. It names no feed: a feed reaches a declaration only through a **binding**
backed by a valid **certificate** (`CERTIFICATES.md`). Nothing in the kernel, the reference kernels or ingestion
selects behavior by a source, dataset or field name; every such choice comes from a declaration, a role contract or
the run manifest. For declared inputs, this document supersedes DSL.md's catalogue of inputs and its statement that
inputs hold; DSL.md's operators, clock and simulator semantics are unchanged.

## 1. Declarations and the registry

A declaration is one JSON file, read as RULES.md §1 reads JSON:

```json
{
  "declaration": 1,
  "name": "hl-funding",
  "version": 1,
  "entity": "coin",
  "times": ["eventTime", "reportedTime"],
  "fields": {
    "funding": {"column": "fundingRate", "unit": "1/h"},
    "premium": {"column": "premium", "unit": "1"}
  },
  "cadence": {"held": {"period_ms": 3600000, "phase_ms": 0, "slot": "eventTime"}},
  "missing": "undefined",
  "revisions": "latest",
  "rule": {"rule": 1, "expr": {"max": [
    {"add": [{"floor": [{"field": "reportedTime"}, {"ms": 3600000}]}, {"ms": 120000}]},
    {"add": [{"field": "reportedTime"}, {"ms": 60000}]}]}},
  "depends": {},
  "role": {"settlement": {"rate": "fundingRate"}}
}
```

| Key | Meaning |
|---|---|
| `declaration` | must be `1` |
| `name` | `[a-z0-9-]{1,64}` |
| `version` | a positive integer; any change to a declaration is a new version |
| `entity` | must be `"coin"`: the run's coins are the only entity domain in version 1 |
| `times` | the stored integer-ms columns an availability rule may read; `fetchedAt` is always available and never listed |
| `fields` | DSL input name → `{"column", "unit"}`: the stored numeric column delivered as that input, and its unit in DSL.md's grammar. Input names match `[a-z][a-z0-9_]{0,31}` |
| `cadence` | `{"held": {"period_ms": P, "phase_ms": O, "slot": C}}` or `{"event": {"slot": C}}` (§4) |
| `missing` | must be `"undefined"` |
| `revisions` | must be `"latest"`: RULES.md §6 |
| `rule` | the availability rule document (RULES.md §3) |
| `depends` | for a derived source, dependency name → `{"sources": [NAME, …], "lag_ms": D}` (§5); `{}` otherwise |
| `role` | the roles this declaration can provide (§6), each role column → stored column; `{}` if none |

Rejected in version 1: other entity domains, enum or non-numeric fields, many-to-many relations, other missing or
revision semantics. A declaration file that breaks any rule above is rejected whole.

**Evidence declarations** (revision of 2026-10-26 02:03 UTC (22:03 EDT), before any implementation consumed this document: the event feeds'
upstream observations and polls are keyed by forum host or Snapshot space, not by coin, so their lineage could not be
declared). A declaration with `"entity": {"evidence": [K1, …]}`, a non-empty list of its stored key columns, declares
records keyed by those columns rather than by (coin, `eventTime`). It must have `"fields": {}`, `"role": {}` and
`"cadence": {"evidence": {}}`. It exposes no DSL input and fills no role: it exists only to be a dependency of a
derived source, and is certified, bound and resolved like any other (RULES.md §6, with its own key columns as the key).
No strategy reads it, so it does not widen version 1's entity domain for strategies.

**The registry** is the immutable set of declarations a run uses: `sources/registry.json` lists, per declaration name,
its active version and the SHA-256 of that version's file, which is retained under `sources/<name>/<version>.json`.
Files under `sources/` that the registry does not list are not declarations. Within one registry: one active version
per name, and input names unique across the active declarations. The **rule bytes** pinned by a dataset version are
the exact UTF-8 bytes of the `rule` member's value in the declaration file, with their SHA-256; reformatting them
changes the identity.

## 2. Stored observations and binding

A bound feed stores immutable revisions keyed by (coin, `eventTime`), holding only observed columns, `fetchedAt` and,
for a key a complete fetch no longer lists, a tombstone flag (`ingest/store.py`). Every field column holds a finite
number or null; null means undefined. Every Time column and key time holds an integer of ms in RULES.md's range.

A **binding** names a declaration version, a stored dataset and a certificate. Binding validates, and never converts:
- the dataset's schema metadata against the declaration: every field column numeric (an all-null column needs explicit
  numeric schema metadata, never inferred from values), every Time column integer-ms, every role column per its role
  contract (§6); extra stored columns are allowed, and are kept, since corrections compare them (RULES.md §6);
- the entity keys against the certified mapping artifact: no symbol normalization, no broadcast. A contextual scalar
  applies to several coins only through an explicit certified assignment to those keys, recorded with its scope;
- the units against the certificate's schema metadata, never inferred from names or values.

## 3. Resolution

RULES.md §6, on the run's admitted snapshot (§7).

## 4. Delivery

Ticks are DSL.md's: τ = H + δ for every hour H. At a tick, every resolved observation with effective knownAt ≤ τ not yet
delivered is delivered, each source's in the order (effective knownAt, coin, eventTime), times as integers and coins
by decoded scalar sequences. Every delivery due at a tick completes before any expression or cross-sectional
operation is evaluated, so the interleaving of sources is unobservable.

- **Held:** a delivered observation replaces the coin's held observation of that source whole, even when its eventTime
  precedes the one it replaces, so each of its inputs takes the new observation's value, and a null column makes that
  input undefined. A key with no observation (absent, tombstoned or rejected) delivers nothing and clears nothing. The
  slot grid (period P, phase O, the Time column C labelling a slot) documents the cadence and is checked against the
  feed by certification; it is not an availability promise, a time-to-live or a source of synthesized values.
- **Event:** column C, on the hour grid, keys the observation to hour E. Its inputs are defined at the tick E + δ only,
  and only if the observation was delivered by then; an observation known later is never defined, and never moves to
  another tick. Nothing survives its tick.

## 5. Derived sources

A derived source's rows are computed from upstream sources by a pinned transformation (code identified by hash; a
declaration never loads or runs code). Each declared dependency names one or more upstream sources and a processing lag
D ≥ 0; deps[d] is the latest effective knownAt among every upstream record the row read from any of them. (Revision of
2026-10-26 02:15 UTC (22:15 EDT): a dependency spans sources, so that a key's recording, its sightings and its polls, is one dependency, whose
read set is never empty for a covered window; with one source per dependency, a covered window without sightings had
an empty observations dependency, and so no time.)
- Each derived row records, per dependency, the immutable identities (key and fetchedAt) of every upstream revision it
  used, including the poll and coverage evidence that establishes the completeness of its aggregation window. A stored
  dependency time is a cache, never authority.
- The resolver computes deps[d] from those identities under the upstream's own pinned rule at the same dataset
  version (RULES.md §6). If an identified upstream revision is not the one selected at that version, or has no usable
  knownAt, the derived row is unusable until recomputed and recertified.
- A count of zero needs positive evidence that its window was covered and its coin mapped; an empty set of counted
  items is not that evidence. An empty lineage has no time, and makes the row unusable.
- Mapping and coverage facts are inputs like any other: available by the row's knownAt. A later poll never establishes
  coverage of an earlier window, unless the frozen transformation states and certification verifies that inference.

## 6. Roles

The simulator needs execution data with fixed meanings. A role is part of the kernel's contract, not a source name.
A run's manifest selects exactly one provider declaration for each role.

| Role | Column | Type and unit | Meaning |
|---|---|---|---|
| `bars` | `openTime` | integer ms | the bar's open; bars are 4h, on the 4h grid |
| | `open` `high` `low` `close` | number, usd/coin | prices over [openTime, openTime + 4h) |
| | `trades` | integer | trades in the bar |
| `settlement` | `rate` | number, 1/h | the hourly funding rate settled at the row's eventTime, positive meaning longs pay |

The provider's declaration maps each role column to a stored column under its `role` key. The simulator reads role data only in the phases INVARIANTS.md and DSL.md prescribe: fills at the
open, marks at the close, margin at the adverse extreme, settlement on held positions; reading a bar's execution
outcome does not deliver that bar's other columns to expressions. Role columns need certification even when absent
from `fields`.

## 7. Checking, preflight and admission

- `mm check` types a program from the active registry alone, reading no feed, binding, certificate or store. An input
  name not declared is `E_UNKNOWN_INPUT`.
- A program's **required set** is every source owning an input name that occurs anywhere in it (the weight, every let,
  used or not, every branch, the prediction condition), every role provider of the run, and the transitive closure of
  their dependencies.
- **Preflight** pins the whole required set before any observation is loaded, initialized, delivered or evaluated: a
  missing binding anywhere in it is `R_INPUT_UNAVAILABLE`; a binding whose certificate is invalid, superseded,
  mismatched or does not cover the run's access is `R_UNCERTIFIED`. Checking errors come first, then missing bindings,
  then certificates. A refusal is recorded through the ledger and emits no result-bearing output.
- **Access authorization** is a separate check: before any payload is opened, every access the run makes (strategy
  inputs, roles, warm-up and window history, fills and accounting after the last decision, mapping and coverage
  inputs, transitive dependencies) is authorized for the run's mode by immutable dataset identity and lineage, never by
  names, paths, aliases or bindings. A search evaluation never materializes a holdout observation or a value derived
  from one (I8, generalized); a crossing is refused before loading, with no result-bearing output.
- **Admission** pins one immutable snapshot: the registry, role selections, bindings, the data manifest and the
  certificate closure, with the ledger position of its lifecycle check. Evaluation reads those admitted bytes, never a
  reopened path. A run's identity includes all of them; substituting a feed keeps the program's source references and
  changes the run's identity.

## 8. Commands

Operator steps go through the CLI, and each writes its records to the ledger before anything is printed:
`mm source register FILE` (a declaration version into the registry), `mm certify BUNDLE` (the verifier;
`CERTIFICATES.md`), `mm bind DECLARATION DATASET CERTIFICATE`, then `mm check` and `mm eval` as before. A demonstration
procedure (C7.5) lists every invocation, every file the operator supplies (only under `sources/`, the evidence bundle
and the data) and every artifact the commands produce.

## 9. Migration

Before C7.4 is judged, a migration annex pins, for Hyperliquid funding and premium, the 4h bars and both event-count
feeds: their declarations, rules, grids, role mappings, feed specifications, transformations with their raw and poll
dependencies, mappings, coverage semantics, bindings and certificate evidence, including the event derivation's every
convention (`venue/sources/derived.md`). A missing piece or a mismatch blocks migration; it is never repaired by
changing the baseline, widening a scope, dropping a case or projecting away another field.
