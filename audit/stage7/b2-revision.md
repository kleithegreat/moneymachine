# B2: the frozen Lean revised so a dependency spans several sources (draft for review, not frozen)

Drafted 2026-11-01 on branch `stage7` from the frozen Lean at `1e2c604` (its files match `laws-frozen.md`'s latest
table), as the advisor's decision of 2026-11-01 16:59 UTC (11:59 EST) states it (`audit/decisions.md`), using both
reviews (`b2-review-claude.md`, `b2-review-gpt.md`). The draft's C7.7 reviews (`b2-revision-review-{claude,gpt}.md`) did
not freeze it; the blockers the advisor ruled on (`audit/decisions.md`, 2026-11-01 20:30 UTC (15:30 EST)) are fixed here.
One more review round, on the fixes' diff only, comes before the freeze, which then appends a dated revision with these
hashes to `laws-frozen.md`. Diff of the revision: `git diff 1e2c604 -- reference/lean kernel/RULES.md kernel/SOURCES.md
kernel/CERTIFICATES.md audit/stage7/migration-annex.md`. Diff of the fixes: the same, from `11da863`.

## 1. Changed definitions

`Source.lean`:
- `Dep`: `source : Nat` becomes `sources : List Nat`.
- `Decl`: `entityColumn : String` becomes `entityColumns : List String`: `["coin"]` for a coin-keyed source, an evidence
  source's key columns other than its event column. `eventColumn` is unchanged; for evidence it is the declared event
  column (`observed`, `recv`).
- `Decl.depends`: `d.deps.flatMap (·.sources)` (was `map (·.source)`).
- `Decl.controls`: `… ++ d.entityColumns ++ …` (was `[d.entityColumn]`).
- `Registry.valid`: every dependency names at least one source (`!dep.sources.isEmpty`).
- `Revision`: `upstream : List (String × List (Nat × String × Int))`, each key (source, stored entity, event time) (was
  (coin, event time)); the docstring states `coin = none` for evidence.

`Resolve.lean`:
- `Stored.eligible`: a key's revisions selected by `r.entity == entity` (was `r.coin == some coin`).
- `Stored.keys`: `(coin, entity, event)` for each eligible revision with a coin (was `(coin, event)`).
- `Stored.validAt`: the clause "two eligible revisions of one coin and event share a fetchedAt" is replaced by "an
  entity's eligible revisions map to one coin (or all to none)"; the entity-key clause and the range clause stand.
- `timeline`: keyed by `(s, entity, event)`. `upKnown` returns `Except`: `.unusable` if the key's source is not among
  `dep.sources`, or if no delivery of it, a retraction included, is recorded by the revision; otherwise the latest such
  knownAt. `known` takes each dependency's keys with `mapM` (was `filterMap`), so one unusable key makes
  the row unusable instead of being skipped beside another; an empty list stays `.unusable`.
- `resolveAll`: iterates `(coin, entity, event)` and calls `timeline … s entity event`; each `Obs.coin` is the key's
  coin. Evidence revisions, with no coin, never become observations.
- `Trusted.canonical`: a lineage's dependency names unique, so the one `find?` reads is the whole lineage; a stored
  entity an injective encoding of its entity columns.

Unchanged text whose meaning changes through `depends` or `controls`: `Registry.closure`,
`Meta.matches`, `Meta.required`, `stage1`, `differs`.

## 2. Changed statements

- `L8_monotone`: the key parameter `coin : Nat` becomes `entity : String`. Content unchanged.
- `L8_known`: the same parameter change; the upstream timeline is `timeline … fuel up.1 up.2.1 up.2.2` (was
  `dep.source up.1 up.2`). Strengthened: for every delivered value and every dependency, the lineage is nonempty, and
  every listed key's source is in `dep.sources` and the key has a delivery recorded no later than the value. The bound
  (each such delivery's knownAt plus the lag) now covers a retraction too, where the frozen statement excluded it.

No other statement changed: the other 16 law headers are byte-identical to `1e2c604`'s.

## 3. Laws whose definition closure changes

Computed by `b2-closure.lean` (`lake env lean ../../audit/stage7/b2-closure.lean` from `reference/lean`): the transitive
constants of each law's statement, through definitions' bodies, not proofs. All 18 reach the changed structures `Dep`
and `Decl`; the definitions with changed bodies that each reaches:

| Law | Changed definitions reached | Through |
|---|---|---|
| `L1_values`, `L1_simulator`, `L1_decisions`, `L2_units`, `L4_fills`, `L4_orders` | `Decl.depends`, `Registry.valid` | `CheckerAccepted`, `closure`, `ruleOk` |
| `L2_checker` | `Decl.depends`, `Registry.valid` | the same and `Program.WF` |
| `L3_rewrite` | `Decl.depends`, `Decl.controls` | `Program.WF`, `Meta.required`, `Meta.matches`, `stage1` |
| `L5_admitted`, `L5_order`, `L5_staged`, `L5_shape`, `L6_bounded` | `Decl.depends`, `Decl.controls`, `Registry.valid` | `Meta.required`, `Meta.matches`, `stage1` |
| `L5_text` | `Decl.depends`, `Registry.valid` | `Meta.required` |
| `L5_certified` | `Decl.depends`, `Decl.controls`, `Registry.valid`, `Revision`, `Stored.eligible`, `Stored.keys`, `Stored.validAt`, `timeline`, `resolveAll`, `Trusted` | the above and `Trusted.resolve`, `Trusted.canonical` |
| `L7_reads` | none (the structures only, through `Program.WF`) | |
| `L8_monotone` | `Revision`, `Decl.controls`, `Stored.eligible`, `timeline` | `differs` |
| `L8_known` | the same, `Decl.depends` and `Registry.valid` | `differs`, `closure` |

C7.7 read literally asks each of these to be reviewed. The content that matters: closure and certificate matching
over a dependency's several sources (`L5_*`, `L3_rewrite`, `L6_bounded`), control columns of evidence declarations
(`L5_*`), and what `Trusted.resolve` now computes (`L5_certified`).

## 4. Validation (development, not judged)

At the fixes' commit:
- `lake build` (library and `refmm`): passes, 109 jobs. Among the proofs only `Proof/Resolve.lean` changed since
  `1e2c604`: `timeline_ordered` (the eligible filter) and `timeline_known` (its value predicate and the `upKnown` lemma,
  simpler for the retraction fix).
- `#print axioms` for all 18 laws: only `propext`, `Classical.choice`, `Quot.sound`; no `sorryAx`. `L8_known` uses
  `Classical.choice` (it did not before B2), from the list lemmas the strict lineage proof needs; `L8_monotone` still
  needs only `propext` and `Quot.sound`.
- `refmm`'s declaration parser (`Main.lean`) reads dependencies as source lists and `entityColumns`, and its `admit`
  case decodes a real rule, so `Registry.valid` decides an invalid registry; `mmdump admit` reports a refused parse.
- The admission differential, `mmdump admit` against `refmm admit` (Lean's `admit`), on 20,000 cases each for seeds 1,
  2 and 3: no disagreement; every position 0 to 5 reached, 6,741 passing, and 1,733 refused at position 0, exactly the
  cases generated with a dependency of no sources (1% of dependencies). Evidence keys now reach three non-event columns.
  A process of 20,000 cases peaks at 3.7 GB; a run of 100,000 passes 10 GB.
- Positive controls, on the Lean side of seed 1: the `Registry.valid` clause removed, 570 disagreements, every case with
  an empty dependency (at the fixes). A dependency reduced to its first source, 1,364; an evidence declaration's entity
  columns dropped, 158 (both at the draft, `96712ee`).
- `cargo test --release` in `kernel/`: 48 passed, 1 ignored, no failure. `mm` itself is unchanged by the fixes.

## 5. What changes in behavior

1. **Strict lineage** (`mapM`). A derived row is unusable if any listed key is unusable, where the frozen Lean took
   the maximum over the usable ones. Only removes rows. GPT's F4 and Claude's F4.
2. **Source membership.** A key of a source the dependency does not name makes the row unusable (was impossible to
   state: keys had no source and were looked up in the dependency's one source).
3. **Entity keys.** Two stored entities mapped to one coin were one timeline (one could correct the other); they are
   now two. Certification forbids such a mapping (SOURCES.md §2, CERTIFICATES.md §3). If both have a final delivery at
   one event time, `Ctx.admissible` refuses the run; at different event times both deliver into that coin's slot. The
   `validAt` clause on (coin, event, fetchedAt) went with this, since no timeline is keyed by coin any more.
4. **Evidence outside U** rests on decoding: an evidence revision has `coin = none`. If an implementation gave one a
   coin, `Ctx.make`'s filter to delivered (non-evidence) sources still drops its observations.
5. **A retraction bounds what saw it.** A retraction recorded by the derived revision raises its dependency's time (Opus
   B-1). It can only make rows later.
6. **An empty `Dep.sources`** is refused by `Registry.valid`, as `mm` refuses it (GPT B1). Opus preferred the formally
   stronger theorem; the spec and `mm` say one or more, and one clause ends a disagreement a run can observe.

## 6. The migrated evidence: no retraction moves

Checked before the retraction change, as the integrity counts of data in hand, reading no prices or values: C7.4's
byte-identity is not touched.

- **Tombstones:** none. `data/sources/` holds 3,306 Discourse and 315 Snapshot revisions in four files, no row flagged
  (two files have no tombstone column); the 11 recorded `sources-*.jsonl` files (2026-10-19 to 2026-10-29, closed on
  this PC) and `ingest/sources_record.py` have no tombstone at all, since a recording appends. `ingest/events.py` also
  reads the backfill through `live`, so a tombstone would never reach a lineage.
- **Other retractions:** a retraction needs a later revision of a delivered key, and every evidence key has one
  revision: 162,031 sighting keys and 4,526 poll keys, with several revisions 0.
- **Exact duplicates (N-3):** 158,410 live sightings, all distinct; no poll key twice.
- **Venue sources** declare no dependencies, so they never consult `upKnown`.

## 7. Recorded limitations, no change

- **N-1: `differs` ignores lineage.** A row whose first revision was unusable, then recomputed with identical cells and a
  good lineage, adds nothing, so that key is never delivered. Missingness only, never leakage; comparing lineage would
  turn recomputations into corrections, which undefine events.
- **Lineage completeness stays certified, not proved:** the Lean cannot tell that a lineage omits a record the
  transformation read, and that omission would permit early delivery. C7.3's verifier recomputes lineage and gets a test
  for it (Claude's risk 3; GPT's §2).
- **A recorder-set event column is a certification fact:** an evidence declaration's event column set from a feed's claim
  would reopen F5's holdout leak. C7.3's verifier tests it, with a test of its own.

## 8. Hashes of this draft

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `c52d9c66653ee08bb383a780fba41c94ee5a292f4a61587f8af5908e4fcdb4bb` |
| `reference/lean/Ref/Resolve.lean` | `d4ac6348696f7da3ae73d5582480d9eb134f5df3479e535038ac657003c3fe3c` |
| `reference/lean/Ref/Laws.lean` | `80d1f575f7ee82005cccb1a00a62752a7353ed982a4b923c58105cedc1ea2551` |
| `kernel/RULES.md` | `5dff7ce6a03ad33eff914adc19ae0cccbf43aec563bf0f613f7d6f2b6b4d0eeb` |

`Json`, `Syntax`, `Machine`, `Sim`, `Units` and `Spec` are unchanged from `laws-frozen.md`'s latest table.

## 9. After the freeze, not part of this revision

- B3: the C7.6 resolver suite, drafted once against these definitions, with hand cases for a covered zero count with
  polls-only lineage at T, a key of a source outside its dependency, a key with no delivery by the derived revision,
  and a later upstream correction not moving an earlier derived row.
- Slice 5 (the entity-keyed timeline in `resolve.rs`), `ingest/events.py` emitting per-row lineage keys beside the
  legacy hashes, and a `refmm` resolver mode.
- `docs/whitepaper.tex` (on `main`): GPT notes that its point-in-time paragraph still describes snapshot selection, not
  the bitemporal resolver (`b2-review-gpt.md` §4).
