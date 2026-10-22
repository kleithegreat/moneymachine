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

A key has coverage only if it has at least one poll and maps to a coin of U
(`discourse_map.json`, `snapshot_map.json`). With s its first poll and L its last, the hours
counted are every τ on the hour grid (multiples of 3 600 000) with

    ceil_hour(s) + 3 600 000 ≤ τ ≤ floor_hour(L)

`ceil_hour` and `floor_hour` round to the grid, leaving exact multiples unchanged. The first hour
lies wholly after s, so items that existed before it are not read as new. The last hour ends at
or before the last poll, so a recording gap at the end is not read as zero events.

## Count

At each covered τ, the count is the number of the key's items with knownAt in (τ − 3 600 000, τ].
It is a row (coin, eventTime = τ, knownAt = τ, count) and is written even when it is 0. Hours
outside coverage, and coins with no mapped key, have no row, so the input is undefined there
(DSL.md). Rows carry the sha256 of `ingest/events.py` and of the mapping file.
