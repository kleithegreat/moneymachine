# C7.4 migration annex (draft for review, 2026-10-26)

Required by `kernel/SOURCES.md` §9 before C7.4 is judged. It pins how the four existing feeds move onto declarations,
bindings and certificates, and how preservation is compared. Nothing here changes any feed's data or semantics: a
mismatch with the baseline blocks migration, and is never repaired by changing the baseline, widening a scope,
dropping a case or projecting away another field.

## 1. Declarations (branch `stage7`, `sources/`)

| Declaration | Kind | Key | Fields (unit) | Cadence | Rule | Role |
|---|---|---|---|---|---|---|
| `hl-funding` 1 | history | coin, eventTime | `funding` ← fundingRate (1/h), `premium` ← premium (1) | held, 1 h, phase 0, slot eventTime | max(floor(reportedTime, 1 h) + δ, reportedTime + 60,000) | settlement: rate ← fundingRate |
| `hl-bars-4h` 1 | history | coin, eventTime | `open` `high` `low` `close` (usd/coin), `volume` (coin) | held, 4 h, phase 0, slot eventTime | eventTime + δ | bars: openTime, open, high, low, close, trades |
| `discourse-observations` 1 | recorded, evidence | key, id, observed | none | evidence | observed | none |
| `discourse-polls` 1 | recorded, evidence | key, recv | none | evidence | recv | none |
| `snapshot-observations` 1 | recorded, evidence | key, id, observed | none | evidence | observed | none |
| `snapshot-polls` 1 | recorded, evidence | key, recv | none | evidence | recv | none |
| `forum-events` 1 | derived | coin, eventTime | `forum_posts` ← count (ev) | event, slot eventTime | eventTime + δ | none |
| `governance-events` 1 | derived | coin, eventTime | `gov_proposals` ← count (ev) | event, slot eventTime | eventTime + δ | none |

δ = 120,000 ms. The two venue rules are C0.3's, as amended for C0.4 (`audit/criteria.md`). The derived sources depend
on their source's observations and polls with lag 0, and on the mapping artifact (`venue/sources/discourse_map.json`,
`venue/sources/snapshot_map.json`, pinned by hash).

## 2. The event transformation

`ingest/events.py`, pinned by its SHA-256, computes the counts exactly as `venue/sources/derived.md` specifies, cut at
the dataset version V:
- an item is a (key, id) pair; its claimed creation time is that of its earliest observation (ties: the smallest
  claim), and its witness w the time of that observation;
- items with a claim before the key's first poll are excluded (pre-first-poll exclusion);
- an item's knownAt is w plus the source's margin (60,000 ms for Discourse, 0 for Snapshot);
- the hour τ has tick T = τ + δ and witness window (T − 3,600,000 − m, T − m];
- τ is covered when T ≤ V and, for every instant t of the window, a poll p of the key has t − 600,000 < p ≤ t (polls
  exactly 600,000 ms apart cover; a longer gap uncovers every hour it touches);
- coverage never depends on a poll after the window, so a later poll never establishes coverage;
- at a covered τ of a mapped coin, the count is the number of items with knownAt in (T − 3,600,000, T], written even
  when 0; an uncovered hour or an unmapped coin has no row, and the input is undefined there;
- records fetched after V are excluded.

**Lineage.** Each count row records, per dependency, the identities of the upstream records it used: for observations,
(key, id, observed) of every counted item; for polls, (key, recv) of every poll that establishes the window's coverage.
It also records the mapping artifact's hash, and the SHA-256 of the sorted identity list (the lineage hash). The
dependency time is the latest upstream knownAt among them, which is at most T − m ≤ T, so the rule eventTime + δ = T
already satisfies RULES.md §6's dependency bound with lag 0. A zero count's lineage is its covering polls, never empty.

## 3. Bindings and certificates

| Declaration | Dataset | Certificate evidence (stage 0 or 5) | Scope |
|---|---|---|---|
| `hl-funding`, `hl-bars-4h` | `data/store` at version 1792613363942 | C0.2 to C0.5 and C0.9 (`audit/stage0/ingest-1792613363942.json`, C0.3's availability evidence), with every dated amendment | U's coins, W's event-time interval; permitted use in search and holdout modes as the stage 0 split allows |
| the evidence sources | `data/sources` and the live poll logs | C5.1 to C5.3 (`audit/stage5/`), with the amendment of 2026-10-22 | prospective only: from each key's first poll |
| `forum-events`, `governance-events` | the derived store at the same version | C5.4 and C5.5 (`audit/stage5/`), the derived fixtures (`venue/sources/derived.md`) | the evidence sources' scope, mapped coins only |

Stage 7 claims no new pre-registration for these feeds: their thresholds, applicability decisions, amendments and
limitations stay as stages 0 and 5 froze them, cited by reference in `sources/policy.json`.

## 4. The comparison

- **Baseline:** the `main` commit the pilot's judged runs use, after the `post-stage0` merge (criteria revision of
  2026-10-26), recorded with its build hashes before `stage7` is rebased onto it.
- **Cases:** W0, every stage 2 probe, and the first 200 programs of the frozen C6.4 corpus (`reference/differential.py`),
  on the stage 0 dataset version 1792613363942 and on C6.4's frozen markets (`reference/edge_markets.py`). No spent
  holdout is used.
- **Compared, byte for byte:** deliveries with their knownAt, definedness, node streams, decisions, fills, accounting
  traces and returns.
- **Projection:** removes only the kernel's build hash and the declaration, binding and certificate ids.
- **Coverage:** the cases must between them deliver every migrated field, both event feeds, covered zero counts,
  uncovered hours, revisions, tombstones and availability boundaries, or the comparison fails.
- **Derived fixtures** (`derived.md`): pre-first-poll exclusion, the earliest-observation and claim tie-breaks, both
  margins, records after the cutoff, the window ending at the tick, polls exactly 10 minutes apart and gaps, no
  coverage from a later poll, zero only for covered mapped hours, undefined elsewhere, and lineage hashes.
