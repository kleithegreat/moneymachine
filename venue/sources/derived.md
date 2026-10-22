# Derived event inputs

`events_forum` (Discourse, input `forum_posts`) and `events_governance` (Snapshot, input
`gov_proposals`) are hourly counts per coin, derived by `ingest/events.py` from two kinds of
record, both cut at the dataset version V:

- **observations**: every sighting of an item, as (key, id, claimed creation time, observed at).
  A backfill revision is observed at its fetchedAt, and a live poll's items at the poll's receive
  time. Keys are a forum host or a Snapshot space; times are integer milliseconds since the epoch.
- **polls**: the receive time of every successful live poll of each key.

Only observations and polls at or before V count.

## Per item

An item is a (key, id) pair. Its claimed creation time `created` is the one carried by its earliest
observation (ties: the smallest claim), and its witness `w` is the time of that observation.

Both sources are prospective (stage 5 amendment of 2026-10-22). Only items with `created` ≥ the key's first
poll count, since older items are not new events. An item's knownAt is `w` plus the source's margin:
60 000 for Discourse and 0 for Snapshot.

## Coverage

A key has coverage only if it maps to a coin of U (`discourse_map.json`, `snapshot_map.json`).
With m the source's margin, the witness window of an hour τ on the grid (multiples of 3 600 000)
is [a, b] with a = τ − 3 600 000 − m and b = τ − m: an item counts at τ exactly when its witness
falls in (a, b]. τ is covered when τ ≤ V and the key was being polled throughout that window: for
every instant t in [a, b], the key has a poll p with t − 600 000 < p ≤ t. Equivalently: the key has
a poll at or before a, no two consecutive polls from the last such one to b are more than 600 000
apart, and its last poll at or before b is later than b − 600 000.

Coverage at τ therefore depends only on polls at or before b ≤ τ, never on a later one. A first
poll at s leaves every hour whose window starts before s uncovered, so items that existed before
recording began are never read as new. A recording gap of more than 10 minutes leaves every
hour whose window it touches uncovered, rather than read as zero events.

## Count

At each covered τ, the count is the number of the key's items with knownAt in (τ − 3 600 000, τ].
It is a row (coin, eventTime = τ, count), known at τ, and is written even when it is 0. Hours
outside coverage, and coins with no mapped key, have no row, so the input is undefined there
(DSL.md). Rows carry the sha256 of `ingest/events.py` and of the mapping file.
