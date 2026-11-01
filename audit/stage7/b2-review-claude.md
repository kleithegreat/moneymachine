# B2 review: a dependency spanning several sources

**Recommendation: option (a), revising the frozen Lean.** Do it in a slightly wider form than the port plan states. A dependency gets a list of sources. Upstream references name a key by source, stored entity and event time (`(source, entity, event)`), not by a coin index. An upstream key that cannot be resolved makes the derived row unusable. Option (b) cannot be built without breaking C7.4 as written or weakening the leakage bound, so it is not a real alternative. The "Evidence keys" reading is half right: keep what it says about control columns, replace what it says about keys.

This touches a leakage guarantee, so per CLAUDE.md §3 rule 1 it belongs under "Decisions awaiting the human's review" in `PROGRESS.md`, and the GPT review the port plan names is still owed (`rust-port-plan.md:76`).

## 1. What the frozen Lean does today

- **A dependency reads one source.** `Dep` has a single `source : Nat` (`Source.lean:27-31`).
- **Upstream keys carry no source.** `Revision.upstream : List (String × List (Nat × Int))` (`Source.lean:301`).
- **An empty dependency makes the row unusable.** In `timeline`, a dependency whose resolved upstream list is empty gives `[] => .error .unusable` (`Resolve.lean:100-104`). For a covered hour with no sightings, a single-source sightings dependency is empty, so the zero count is never delivered.
- **Unresolvable upstream keys are silently dropped.** The same code uses `ups.filterMap (… upKnown …)` (`Resolve.lean:102`), so an upstream key with no usable knownAt is skipped as long as any other key resolves.
- **Upstream records are found by coin.** `upKnown` calls `timeline … dep.source c e`, and `Stored.eligible` filters `r.coin == some coin` (`Resolve.lean:45-47`). `Revision.coin` is documented as "the coin of U it maps to (none outside U)" (`Source.lean:291`). An evidence record has no coin, so under the frozen text it cannot be reached as an upstream at all. That is why the port invented the "entity index" reading.
- **The Lean narrowed a spec that had already been reviewed, and nothing records it as a decision.**
  - `d1d7ad8` at 2026-10-26 02:15 UTC (2026-10-25 22:15 EDT) revised SOURCES.md §5 so a dependency spans sources. This answered GPT's annex review §3 (`annex-review-gpt.md:48-58`).
  - The single-source `Dep` first appears in `2790140` at 2026-10-26 22:12 UTC (18:12 EDT). It was frozen at 23:30 UTC (19:30 EDT).
  - None of the reviews (`laws-review-*.md`, `laws-v2-draft.md` §4) mentions the narrowing.
  - The Rust already has the reviewed design: `Dependency { sources, lag }` and a `depends` that flattens the source lists (`kernel/mm/src/source.rs:180, 218-221`).
  - The paper says the same thing: "available no earlier than the latest of its inputs plus its processing time" (`whitepaper.tex:257`).

So option (a) puts the reviewed spec back into the Lean; it is not a new design.

## 2. Options

### (a) `Dep.sources` with source-qualified upstream keys: recommended, with three refinements

- **Leakage and false discoveries.**
  - The knownAt bound stays: every listed upstream record still bounds the derived knownAt, and L8_known keeps that shape.
  - A covered zero count becomes usable at max(T, the coverage polls' knownAt). That equals T, because every coverage poll is at or before b = T − m (`derived.md`, Coverage). This is what C7.4 requires (`criteria.md:887`).
  - Monotonicity is unaffected. `L8_monotone` comes from the `prev` raise (`Resolve.lean:107`), which no dependency change touches.
- **Simplicity.** A dependency already means "inputs read with one processing delay" (RULES.md §6, `RULES.md:126-131`). Grouping sightings and polls under one lag-0 dependency is that meaning exactly. Nothing is added beyond letting the group hold more than one source.
- **Evidence keys.** On its own, (a) still needs a way to reach an evidence record, which refinement 2 below supplies.

### (b) Restating the derived feeds so each dependency's read set is never empty: rejected

Under the frozen Lean, every way of doing this either breaks a frozen requirement or reintroduces a patch:

1. **Two dependencies, `polls` and `sightings`.** A zero count's `sightings` dependency is empty, so the row is unusable. The defect stays exactly as it is.
2. **Polls alone carry the lineage; sightings drop out.** This breaks C7.4's "available no earlier than its latest required input" (`criteria.md:872`) and the annex's "No record used is dropped from lineage" (`migration-annex.md:56`). GPT's annex review already ruled it out: "must not … omit the declared dependency" (`annex-review-gpt.md:56`).
   - **Leakage outcome:** named test 13 (`criteria.md:947`).
   - **Scenario:** a sighting recorded at F > T (a backfill, or a producer trusting the feed's `observed`) is counted at hour τ. With sightings in lineage, the row's knownAt rises to F and the input is undefined at τ. Without them, the row is delivered at T carrying information recorded after T.
   - **Why the history is exposed:** the migration writes every historical row as a first revision at V = 1792613363942. A first revision is known at its rule's value, not at its fetchedAt (`RULES.md:186-188`). So for the migrated history the dependency bound is the only protection.
3. **Merging sightings and polls into one evidence source.**
   - The two streams are recorded separately: polls in the live logs, sightings in the raw store and in the poll bodies (`ingest/events.py:29-47`).
   - Merging them after the fact is itself a derived source with two upstreams, so the same problem comes back one level down.
   - Merging at the recorder would mean rewriting raw evidence that has already been certified under C5.1 to C5.3.
   - Giving the two record kinds one key needs a sentinel such as a null item id. That is the kind of patch §1 forbids.
4. **Dropping backfill sightings so polls carry everything.** This changes the feed's semantics, which the annex forbids (`migration-annex.md:6`), and could change C7.4's byte-identical baseline.

**Cost if adopted:** nothing in the Lean, but the annex, SOURCES.md §5, the Rust `Dependency` and stage 5's evidence would all change, and the result fails a frozen criterion.

### (c) Other options considered, all rejected

- **An empty dependency contributes no bound, with "lineage non-empty" checked per row.** A rule must still give `dep d` a value. RULES.md forbids choosing by presence ("an absent field rejects the row", `RULES.md:139-141`). GPT forbade "invent an empty-set time" (`annex-review-gpt.md:56`). A "may be empty" flag would be a §1 patch.
- **Leaving uncovered and zero hours both undefined.** This fails C7.4's covered-zero requirement as written, and any amendment to it could not be a relaxation.

## 3. Findings

Each finding names the outcome it could change.

| # | Finding | Outcome it could change | Where |
|---|---|---|---|
| F1 | Under the frozen Lean a covered zero count is never delivered. | **C7.4 fails as written.** Event-input definedness differs from the baseline, so node streams and decisions differ. | `Resolve.lean:103`, `criteria.md:885-887` |
| F2 | Every form of (b) either keeps F1 or drops sightings from the bound. | **Leakage:** test 13, on all migrated history. | §2 above |
| F3 | The port's reading of `coin` as "the source's entity index" has no pinned enumeration for open-ended tuples (key, id, created). If the index is computed from the stored data, adding a record renumbers it, so lineage written at one version names a different key at another. | **Leakage:** a lineage key resolving to an earlier-known record bounds the row too early, while `L8_known` holds for the wrong key. It also breaks bitemporal stability. | `rust-port-plan.md:84-88`, `Resolve.lean:45-47` |
| F4 | An upstream key with no usable knownAt is dropped instead of making the row unusable. SOURCES.md §5 says unusable (`SOURCES.md:115-117`); `RULES.md:130` is ambiguous at the dependency level. This holds even without B2. | **Leakage:** test 13. Scenario: a counted sighting whose rule rejects (null `observed`) or that has no delivery recorded by the derived revision; the row is still delivered at T from the polls. | `Resolve.lean:102` |
| F5 | An evidence record's Lean `event` must be the trusted observation time (`observed` for sightings, `recv` for polls). It must not be the feed's claim, and the raw store's `eventTime` *is* the claim `created` (`events.py:35, 45`). Stage 2's I8 check reads `event` for every required row, evidence included (`Source.lean:279-280`, `Trusted.rows` at `Resolve.lean:189`). | **Leakage:** test 15 (`criteria.md:950`). An item created before `holdoutStart` but observed during the holdout would pass a search run's stage 2 check. | `Source.lean:42`, `SOURCES.md:55-61` |
| F6 | A single `entityColumn : String` under-lists an evidence key's columns in `Decl.controls`. The Rust already lists them all (`source.rs:203-214`), so Lean and Rust disagree on certificate control columns. | Not leakage: the Rust is stricter. It is a refusal mismatch in the admission differential, and a bridge the port plan forbids (`rust-port-plan.md:5-6`). | `Source.lean:44, 99-100` |
| F7 | Under coin-keyed timelines, two stored entities mapped to one coin merge into one timeline, so one entity's revision "corrects" the other's. Keying by entity separates them, and `Ctx.admissible` then refuses the run (`Sim.lean:444-450`). | A refusal only for non-injective mappings, which certification forbids (`migration-annex.md:45-46`). Note it in the review. | `Resolve.lean:45-51` |
| F8 | Lineage's per-revision `fetchedAt` (`SOURCES.md:112-113`, `migration-annex.md:50`) is never read by the Lean. The key-level bound, over every delivery recorded by the derived revision, is never earlier than a per-revision bound. | None: it can only make a row later. Erase it (§2 of CLAUDE.md). For the migrated evidence, which has one revision per key, nothing changes. | `Resolve.lean:96` |

## 4. Recommended design and concrete changes

### Lean: a dated revision in `laws-frozen.md`

**`Source.lean`**
- `structure Dep where sources : List Nat; name : String; lag : Int`
- `Decl.depends := d.deps.flatMap (·.sources)`. `Registry.valid`, `closure`, `Meta.matches` and `required` keep their text, since `depends` is still `List Nat`.
- `entityColumn : String` becomes `entityColumns : List String`. It is `["coin"]` for coin-keyed sources and the key columns other than the event column for evidence. `Decl.controls` follows.
- `Revision.upstream : List (String × List (Nat × String × Int))`, each entry (source, stored entity, event).
- `Revision.coin` keeps its frozen meaning: for evidence it is `none`.

**`Resolve.lean`**
- `Stored.eligible` and `timeline` are keyed by `(s, entity : String, event)`, filtering on `r.entity`.
- `Stored.keys` returns `(entity, event)` for eligible revisions with `coin ≠ none`. `resolveAll` takes each `Obs.coin` from the revision's coin.
- `Stored.validAt` adds: an entity's eligible revisions share one coin.
- In `known`, each listed key must have its source in `dep.sources` and an `upKnown` that is `some`; otherwise `.unusable`. Use `mapM` in place of `filterMap`. An empty list stays `.unusable`, which keeps "an empty lineage has no time" (`SOURCES.md:119`) and fixes F4.
- Evidence records then never become `Obs`. They are resolved only on demand, as upstream keys.

**`Laws.lean`**
- `L8_known` quantifies over `up : Nat × String × Int` and the timeline `timeline … fuel up.1 up.2.1 up.2.2`.
- Strengthen it with a clause: every listed key's source is in `dep.sources`, and the key has a delivery recorded by `e.rev.fetchedAt`.
- `L8_monotone`'s key parameter changes from `coin : Nat` to `entity : String`.

**Proofs**
- Re-prove `timeline_ordered` and `timeline_known` (`Proof/Resolve.lean:106, 290`; about 250 lines, mostly mechanical).
- No other proof unfolds `upstream` or `controls`. A grep finds them only in `Proof/Resolve.lean`, and `Exec.lean`'s `csimp` lemmas cover `admissible`, `inScope` and `admit` only.
- Rebuild everything and redo the axiom check, as in `proof-validation-2026-10-31.md`.

### Specs

- **RULES.md §6:** the derivation bound is stated per upstream key named by source and entity, and a key without a usable knownAt makes the row unusable (`RULES.md:126-131, 172-173`).
- **SOURCES.md §1** (evidence declarations): `"entity": {"evidence": [K…], "event": C}`. C is one of the key columns, appears in `times`, and is the recorder-trusted observation time. The remaining columns are the entity.
- **SOURCES.md §5:**
  - Lineage identities become (source, entity, event); drop "and fetchedAt".
  - Replace "not the one selected at that version" (`SOURCES.md:115-116`) with the bitemporal statement: deliveries recorded no later than the derived revision.

### Annex

- **§1:** sightings are entity (key, id, created) with event `observed`; polls are entity (key) with event `recv`. The `recording` dependency is unchanged.
- **§2 lineage:** (source, entity, event) identities. Coverage polls are listed for every covered hour, zero counts included.

### Code and suites

- **`refmm`:** update the `Main.lean` declaration parser (`Main.lean:103-106`: dependencies as lists of sources, `entityColumns`). Re-run the admission differential, `mmdump admit` against `refmm admit`, as a development run.
- **Rust:** `Dependency` is already right. `source.rs` reads the evidence `event` column, and its `controls` stays as it is: it already equals the revised Lean set. Slice 5 implements the entity-keyed timeline.
- **`ingest/events.py`:** emits per-row lineage as (source, entity, event), beside the legacy hashes.
- **Order relative to B3:** settle B2 *before* drafting B3's revised C7.6 resolver suite, so the suite is frozen once. Add hand cases for:
  - a covered zero count with polls-only lineage resolving at T;
  - an upstream key from a source outside its dependency's sources being unusable;
  - an upstream key with no delivery recorded by the derived revision being unusable;
  - a later correction of an upstream key not moving an earlier derived row.

## 5. Cost: what forks and what must be redone

**Hashes that change:** `Source.lean` (`210cb1b0…`), `Resolve.lean` (`0c19d786…`), `Laws.lean` (`e3f38840…`) and `RULES.md` (`0f2fee31…`) in `laws-frozen.md`. No judged stage 7 evidence exists yet, and C7.4's baseline is mechanical output from `main`, so no judged result is invalidated.

**Review (C7.7, `criteria.md:932`):**
- `L8_known` and `L8_monotone`: statement changes, each needing a fresh Opus review and a GPT review before the freeze.
- `L2_checker`, `L5_admitted`, `L5_certified` and `L5_staged`: their statements stay the same, but the definitions they reference (`Registry.Valid`, `controls`, `depends`) change. C7.7 read literally requires each to be named and reviewed; their proofs only need to rebuild.

**Re-run as development runs:** the proof validation and the admission differential. Slice 1's `sources.rs` tests gain the evidence `event` key.

**No cost to:** slices 2 to 4. The checker reads fields, units and cadence only, so the event declarations keep their fields.

## 6. The "Evidence keys" reading

- **Confirmed (the control-column half).** An evidence declaration's controls are its `times` (with `fetchedAt`), its key columns and the revision columns. This is what `source.rs:203-214` already computes. Under the revision it follows from the Lean's own `controls`, because the event column is one of the key columns.
- **Replaced (the key half).** Lean's `coin` is never an evidence entity index (F3).
  - Evidence revisions have `coin = none`.
  - They are reached only as upstream keys, through (source, stored entity, event).
  - The evidence declaration names its event column, the trusted observation time (F5).
  - "no eventTime" in the port plan's wording is wrong: evidence has an event column, just not one named `eventTime`.

## 7. Risks

1. **Reopening the resolver invites new findings.** GPT's reviews 6 to 9 each found paths through it. Mitigation: review the diff only, listing every changed definition and statement as `laws-frozen.md` does.
2. **The stricter rule (F4) can block migration.** If the legacy transformation reads a record with no valid knownAt, the C7.4 comparison will mismatch. That is the correct, recorded outcome (`migration-annex.md:54-56`), not a defect to work around.
3. **Lineage completeness is still certified, not proved.** The Lean cannot tell when a positive count's lineage omits a sighting. This is unchanged by every option, and C7.3's verifier, recomputing from the pinned `events.py`, has to carry it. State it as a known limitation in the review.
4. **The event column is a certification fact.** If a later evidence source declares a claim as its event column, F5's leakage returns. The certification policy should test that the event column is recorder-set.
5. **Leftover filter (follow-up, not part of this revision).** Once evidence never yields `Obs`, `Ctx.make`'s filter to delivered sources (`Sim.lean:222-223`) no longer removes anything. Deleting it changes a definition that the L1, L4 and L7 laws reference, so leave it for the next revision that touches `Sim.lean` anyway.

I edited nothing.
