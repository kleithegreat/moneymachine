# C7.4 migration annex (draft, revised 2026-10-26 from GPT's review)

Required by `kernel/SOURCES.md` §9 before C7.4 is judged. It pins how the four existing feeds move onto declarations,
bindings and certificates, and how preservation is compared. It is frozen only together with a committed, populated
**migration manifest** (§5): no placeholder, branch head, mutable directory or "latest" counts as a pin. Nothing here
changes any feed's data or semantics. A mismatch with the baseline blocks migration, and is never repaired by changing
the baseline, widening a scope, dropping a case or projecting away another field. GPT's review of the first draft:
`audit/stage7/annex-review-gpt.md`.

## 1. Declarations

| Declaration | Kind | Key | Fields (unit) | Cadence | Rule | Role |
|---|---|---|---|---|---|---|
| `hl-funding` 1 | history | coin, eventTime | `funding` ← fundingRate (1/h), `premium` ← premium (1) | held, 1 h, phase 0, slot eventTime | max(floor(reportedTime, 1 h) + δ, reportedTime + 60,000) | settlement: rate ← fundingRate |
| `hl-bars-4h` 1 | history | coin, eventTime | `open` `high` `low` `close` (usd/coin), `volume` (coin) | held, 4 h, phase 0, slot eventTime | eventTime + δ | bars: openTime ← openTime, open ← open, high ← high, low ← low, close ← close, trades ← trades |
| `discourse-sightings`, `snapshot-sightings` 1 | recorded, evidence | key, id, observed, created | none | evidence | max(observed, fetchedAt) | none |
| `discourse-polls`, `snapshot-polls` 1 | recorded, evidence | key, recv | none | evidence | max(recv, fetchedAt) | none |
| `forum-events`, `governance-events` 1 | derived | coin, eventTime | `forum_posts`, `gov_proposals` ← count (ev) | event, slot eventTime | max(eventTime + δ, dep `recording`) | none |

δ = 120,000 ms. The venue rules are C0.3's as amended for C0.4 (`audit/criteria.md`). Each derived source declares
one dependency, `recording`, spanning its sightings and polls sources, with lag 0; the rule names it, so it passes
RULES.md §4. The sightings key includes the claim, so distinct sightings of an item at one observation time with
different claims stay distinct records and are never reduced as revisions. Live sightings and polls are stored by the
recorder itself, so a live record's `fetchedAt` is the poll's receive time; a backfill observation's observation time is
its `fetchedAt`. Poll evidence holds successful live polls only.

## 2. The event transformation

`ingest/events.py`, pinned by its SHA-256, computes the counts exactly as `venue/sources/derived.md` specifies, cut at
the dataset version V (records with fetchedAt ≤ V and, as `derived.md` says, observations and polls at or before V):
- an item is a (key, id) pair, counted at most once; its claimed creation time is that of its earliest observation
  (ties: the smallest claim), and its witness w the time of that observation;
- items with a claim before the key's first successful poll are excluded;
- an item's knownAt is w plus the margin m (60,000 ms for Discourse, 0 for Snapshot); count membership uses knownAt,
  never the claim;
- for the hour τ, T = τ + δ, a = T − 3,600,000 − m and b = T − m. An item counts at τ when its knownAt is in
  (T − 3,600,000, T]. Coverage is tested over the closed interval [a, b]: τ is covered when T ≤ V, its key maps to a
  coin of U, and for every instant t in [a, b] a successful live poll p has t − 600,000 < p ≤ t; equivalently a poll at
  or before a, consecutive polls from the last such one through b at most 600,000 ms apart, and the last poll at or
  before b later than b − 600,000. No poll after b establishes coverage;
- at a covered τ, the count is written even when 0; an uncovered hour, or a coin with no mapped key, has no row.

**The mapping** (`venue/sources/discourse_map.json`, `venue/sources/snapshot_map.json`) is part of the transformation's
pinned configuration, not time-varying data: one key per coin, chosen under stage 5's frozen procedure without return
information, and applied to every hour as stage 5 applies it. Its manifest entry pins its bytes, its SHA-256, its exact
key-to-coin assignments (one key to one coin; an unmapped key counts for no coin; no aggregation, broadcast or
inference). That a mapping fixed in October applies to earlier hours is stage 5's design, kept as a limitation of the
certificates' scope, not hidden.

**Lineage.** Each row records the identities (upstream key and fetchedAt) of every upstream record it read: the
sightings that determine each counted item's earliest observation and claim, the polls that fix the key's first poll,
and every poll establishing coverage of [a, b], the one at or before a included. A count of zero still has its
coverage polls, so its `recording` dependency is never empty. The resolver computes the dependency time from those
identities under the upstream rules at V; availability is T only when every bound of RULES.md §6 is at most T.
Otherwise the row is undefined at its tick and never moved to another tick: a mismatch that blocks migration. No record
used is dropped from lineage because it would delay availability. Each row also keeps the legacy fields of
`derived.md` (the SHA-256 of `ingest/events.py`, of the mapping file, the cut V and the SHA-256 of the records read, by
the legacy encoding), and the lineage hash is added beside them, never in their place.

## 3. Bindings and certificates

Each binding names an exact declaration version, an immutable data manifest and a verifier-issued certificate id. The
stage 0 and stage 5 reports are evidence the verifier reads, never certificates themselves.

| Declarations | Evidence (stage 0 or 5) | Scope grants |
|---|---|---|
| `hl-funding`, `hl-bars-4h` | C0.2 to C0.5 and C0.9 (`audit/stage0/ingest-1792613363942.json`, C0.3's availability evidence), every dated amendment | each coin of U and declared or role column, W's event-time interval, use in search and holdout modes as the stage 0 split allows |
| the sightings and polls | C5.1 to C5.3 (`audit/stage5/`), the amendment of 2026-10-22 | each mapped key, from its first successful poll (prospective only) |
| `forum-events`, `governance-events` | C5.4 and C5.5 (`audit/stage5/`), the derived fixtures | each mapped coin, within its key's evidence grants |

Each grant is explicit (entity, column, event-time interval, use interval, half-open integer ms), the cutoff is
separate, and search or holdout authorization is checked independently (SOURCES.md §7). Evidence logs are immutable
snapshots named in the manifest, never reopened live logs. Missing evidence or scope blocks migration.

## 4. The comparison

- **Baseline:** before `stage7` is rebased onto the pilot's baseline commit (`main` after the `post-stage0` merge;
  criteria revision of 2026-10-26), a comparison manifest records that commit, its build hashes and the captured
  baseline outputs. Migration results cannot influence the commit's selection.
- **Cases**, frozen before the first judged C7.4 run, with their exact program bytes: W0, every stage 2 probe listed by
  name, and the first 200 programs of the C6.4 corpus in its frozen order, on dataset version 1792613363942 and on
  C6.4's frozen markets, with the same universe, decision interval, warm-up and accounting horizon in both runs. No
  spent holdout is used.
- **Compared, byte for byte:** deliveries with their knownAt, definedness, node streams, decisions, fills, accounting
  traces and returns, over the complete expected inventory of artifacts and records.
- **Projection:** a frozen allowlist of exact artifact paths and field locations for the kernel build hash and the
  declaration, binding and certificate ids, never removal by field name. No sorting, rounding or other normalization.
  The substituted identities are recorded beside the result.
- **Coverage:** the manifest maps every class to named cases and expected observations or absences: every migrated
  field and role column, both event feeds, positive and covered-zero counts, unmapped and uncovered absences, both
  margins, the window's endpoints, revisions, tombstones, dependency bounds and availability boundaries. A class
  without a case fails C7.4.
- **Derived fixtures** have frozen raw inputs and hand-specified expected rows, counts, absences, times and hashes:
  pre-first-poll exclusion; the earliest-observation and claim tie-breaks; both margins; records after the cutoff; the
  window ending at the tick; a first poll at a and at a + 1 ms, a poll at b, a last poll exactly at b − 600,000, gaps of
  600,000 and 600,001 ms, and a poll after b that would close a gap; zero only for covered mapped hours; undefined
  elsewhere; lineage and legacy hashes.
- **Failure:** a missing or extra artifact or record, a skipped case, a crash, a timeout, malformed output or any byte
  difference fails the judged run, which stays recorded; a rerun has a new identity, and nothing regenerates a baseline.

## 5. The migration manifest and completion

The manifest, committed with this annex's freeze, pins every declaration file and its SHA-256, the registry bytes, each
rule's exact bytes and hash, every Time column, evidence key, numeric and role schema, missing and revision setting,
cadence grid and slot, field and role mapping, feed specification, producer and transformation hash, mapping and
coverage artifact, data manifest and cutoff, and the exact criteria lines and evidence files it relies on.

Migration is complete only when `EVENT_INPUTS`, the per-input enum variants and the per-dataset branches of
`kernel/mm/src/market.rs` and `ingest/store.py` (enumerated in the manifest) are deleted, and a scan finds no declared
name or equivalent identifier-selected behavior moved into another production, ingestion, reference-kernel or
generated path.
