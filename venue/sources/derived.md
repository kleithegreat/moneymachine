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

- **Admitted** (Discourse after passing C5.3; Snapshot never, since its creation time is
  client-claimed): knownAt = `created` + 600 000.
- **Prospective** (everything else): only items with `created` ≥ the key's first poll count (older
  items are not new events), and knownAt = `w`.

## Coverage

A key has coverage only if it has at least one poll and maps to a coin of U
(`discourse_map.json`, `snapshot_map.json`). With s its first poll and L its last, the hours
counted are every τ on the hour grid (multiples of 3 600 000) with

    ceil_hour(a) + 3 600 000 ≤ τ ≤ floor_hour(L)

where a is s, or the backfill's start (2024-08-31T00:00Z, 1725062400000) when admitted.
`ceil_hour` and `floor_hour` round to the grid, leaving exact multiples unchanged. The first hour
lies wholly after a, so items that existed before it are not read as new. The last hour ends at
or before the last poll, so a recording gap at the end is not read as zero events.

## Count

At each covered τ, the count is the number of the key's items with knownAt in (τ − 3 600 000, τ].
It is a row (coin, eventTime = τ, knownAt = τ, count) and is written even when it is 0. Hours
outside coverage, and coins with no mapped key, have no row, so the input is undefined there
(DSL.md). Rows carry the sha256 of `ingest/events.py` and of the mapping file.
