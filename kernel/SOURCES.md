# Source declarations, version 1

A strategy reads data only through declared sources (paper §5). A **declaration** says what a source
is: its entity key, its typed fields, its cadence, how missing values behave, when each observation
becomes known (an availability rule, `RULES.md`) and how revisions resolve. It names no feed: a feed
reaches a declaration only through a **binding** backed by a valid **certificate** (C7.3). This document
specifies declarations and what the kernel does with them. Nothing in the kernel, the reference
kernels or ingestion selects behavior by a source, dataset or field name; every such choice comes from
a declaration.

## Files

Each declaration is one JSON file `sources/<name>.json`, read strictly (duplicate keys, unknown keys,
non-integer numbers where integers are required and wrong JSON types are rejected):

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
  "cadence": {"held": {}},
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
| `name` | the source's name, `[a-z0-9-]{1,64}`, equal to the file name; unique |
| `version` | a positive integer; a changed declaration is a new version, and a certificate pins one |
| `entity` | must be `"coin"`: the entity domain is the run's coins (other domains are outside version 1) |
| `times` | the stored columns of type Time an availability rule may read. `fetchedAt` is always available to the rule and is not listed |
| `fields` | DSL input name → `{"column", "unit"}`: the stored numeric column delivered as that input, and its unit in DSL.md's grammar. Input names are `[a-z][a-z0-9_]{0,31}`, unique across all declarations |
| `cadence` | `{"held": {}}` or `{"event": {}}` (Delivery, below) |
| `missing` | must be `"undefined"`: an input with no delivered observation is undefined, never zero |
| `revisions` | must be `"latest"` (below) |
| `rule` | the availability rule (`RULES.md`), checked against `times` and `depends` |
| `depends` | for a derived source, dependency name → `{"source": NAME, "lag_ms": D}` (below); `{}` otherwise |
| `role` | `null`, or the simulator role this source fills, with its column mapping (below) |

Unsupported in version 1 and rejected: other entity domains, enum fields, non-numeric fields,
many-to-many relations, other missing or revision semantics.

## Stored observations

A bound feed stores immutable revisions keyed by (coin, `eventTime`), each holding only observed
columns plus `fetchedAt`, and tombstones for keys a complete fetch no longer lists (`ingest/store.py`).
For each declared field, its column holds a finite number or null.

## Resolution

At a dataset version V (a fetchedAt cutoff), each key resolves to its latest revision fetched by V.
A key whose latest revision is a tombstone is absent. There is no fallback to an older revision.

The revision's knownAt is the rule's value on it. If the revision's observed columns (every stored
column except `fetchedAt`, `source`, `hash` and the tombstone flag) differ from the key's first
revision, it is a correction, and its knownAt is the later of the rule's value and its `fetchedAt`: no
rule backdates a value nobody had then. A revision whose rule evaluation is rejected (`RULES.md`) has no
knownAt and is never delivered.

## Delivery

Ticks are DSL.md's: τ = H + δ for every hour H. At a tick, every resolved observation with knownAt ≤ τ
not yet delivered is delivered, in order of (knownAt, coin, eventTime), sources in declaration-name
order.

- **Held:** the observation's fields replace the coin's held values for that source's inputs. A null
  column leaves that input undefined until a later observation defines it.
- **Event:** eventTime is on the hour grid. An observation keyed at eventTime E is its inputs' value at
  the tick E + δ only, and only if it was delivered by then; an observation known later is never
  defined. A tick with no such observation leaves the input undefined, and nothing is held past its
  tick. A covered hour with nothing to count is an observation with value 0; an hour outside coverage
  has no observation.

## Derived sources

A derived source's rows are computed from other sources' observations by a versioned transformation.
Each dependency names an upstream source and a processing lag D ≥ 0, and the transformation stores with
each row, per dependency, the latest knownAt among the upstream observations it used. A derived row's
knownAt is the later of its rule's value and, for every dependency, that time plus D, whatever the rule
says. A rule may also read those times as `{"dep": name}`.

## Roles

The simulator needs execution data with fixed meanings. A role is part of the kernel's contract, not a
source name. Version 1 has two, and a run requires exactly one bound source per role:

| Role | Columns mapped | Used for |
|---|---|---|
| `bars` | `open`, `high`, `low`, `close`, `trades`, `openTime` | fills at the open, marks, margin, liquidation and delisting (INVARIANTS.md) |
| `settlement` | `rate` | hourly funding settlement on held positions |

`role` maps each of the role's names to a stored column of the source. Role data is required, and
certified, whether or not a strategy reads any of the source's fields.

## Checking and preflight

- `mm check` types a program from the declarations alone. An input name not declared is
  `E_UNKNOWN_INPUT`. A program's **required sources** are every source one of its input names belongs
  to, wherever the name occurs: the weight, every let (used or not), every branch, and the prediction
  condition; plus every role's source.
- Before any delivery or evaluation, preflight checks each required source: unbound is
  `R_INPUT_UNAVAILABLE`; bound without a valid, matching, in-scope certificate is `R_UNCERTIFIED`. A
  refusal emits no result-bearing output and is recorded through the ledger.
- Binding validates the feed's columns against the declaration (every declared column present and
  numeric, every role column present) and never converts entities or units.
