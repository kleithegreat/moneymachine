# B2 review

## Recommendation

**Adopt option (a): let one dependency span several declared sources, with source-qualified upstream keys. Keep the event-count definition unchanged.** Make this a reviewed, dated revision of the frozen semantics—not a Rust adaptation hidden behind the port.

The abstraction should be:

> A dependency is a named, delayed read set. Its records may come from several sources. A usable dependency needs nonempty evidence, not a nonempty set of counted events.

That matches the existing `recording` dependency and removes the mismatch directly. Restating genuine recorded responses, including empty responses, is a valid alternative, but restructuring the feeds merely to preserve `Dep.source` would move complexity into ingestion and certification.

**Outcome affected:** derived-input knowledge times and definedness; consequently decisions, returns, finalist selection and potentially false promotions. This is not an outcome-neutral documentation decision under `CLAUDE.md:37`.

This is a static review; no files were edited or tests run.

## 1. Findings that determine the choice

### F1. The frozen Lean cannot express the declared dependency

**Outcome affected: covered-zero delivery, subsequent strategy state and trading results.**

`SOURCES.md` deliberately changed a dependency to span sources because a covered window can have polls but no sightings (`kernel/SOURCES.md:104–119`). The annex accordingly declares one `recording` dependency over sightings and polls (`audit/stage7/migration-annex.md:16–25`).

Lean instead has:

- one `Dep.source` (`reference/lean/Ref/Source.lean:26–31`);
- upstream references containing only `(coin,event)` (`reference/lean/Ref/Source.lean:291–302`);
- an unusable dependency when no referenced upstream key supplies a time (`reference/lean/Ref/Resolve.lean:95–104`).

Thus neither splitting `recording` into two dependencies nor selecting one of its sources implements the annex:

- splitting loses covered zeros when sightings are empty;
- selecting polls alone omits the sightings’ availability bound;
- selecting sightings alone omits coverage evidence.

C7.4 requires raw observations **and** polls, covered-zero deliveries, and byte-identical knowledge times and definedness—not merely unchanged positive counts (`audit/criteria.md:870–887`). The original annex review explicitly prohibits fabricated items, unrelated observations and invented empty-set times (`audit/stage7/annex-review-gpt.md:48–58`).

### F2. “Only delays or removes data” is not a false-discovery safety argument

**Outcome affected: orders, returns, selection and promotion in either direction.**

For a covered hour, `0` and undefined are different inputs. They can produce different branches, window histories and `hours_since` state. Event data arriving after its designated tick is never recovered at another tick (`reference/lean/Ref/Machine.lean:132–137`; `kernel/SOURCES.md:100–102`).

The intended event availability is, schematically,

\[
K(r)=\max\left(T,\ \max_d(\operatorname{deps}[d]+D_d),\
\text{applicable correction and predecessor bounds}\right).
\]

The annex uses lag zero and `max(eventTime + δ, dep recording)` (`audit/stage7/migration-annex.md:18–25`). With authenticated live recording times equal to receive times, the required sightings and covering polls are available by \(T\), so both positive and covered-zero rows remain usable at \(T\). If an authenticated bound exceeds \(T\), the row must miss its tick; migration then fails rather than backdating it (`audit/stage7/migration-annex.md:50–58`).

Neither losing that row nor restoring it has a general monotone effect on false discoveries. Earlier reviews already demonstrate that delayed availability and changed missingness can change decisions (`audit/stage7/laws-review-gpt-6.md:92–112`).

### F3. The latest bitemporal contract must survive B2

**Outcome affected: later evidence retroactively changing earlier derived inputs.**

The controlling rule is **not** SOURCES §5’s old requirement that the identified revision remain selected at dataset version \(V\) (`kernel/SOURCES.md:112–117`).

The later revisions require upstream deliveries to have been **recorded no later than the derived revision** (`kernel/RULES.md:168–183`). Lean implements that cutoff at `reference/lean/Ref/Resolve.lean:95–97`. It was introduced because taking an upstream key’s entire eligible timeline lets a later correction delay an already-existing derived observation (`audit/stage7/laws-review-gpt-7.md:10–30`).

B2 must therefore distinguish:

1. **provenance:** which immutable revisions the transformation actually used;
2. **availability:** the causal upstream timeline bound specified by the revised resolver.

Do not restore “latest at \(V\)” invalidation, or silently replace the current bound with a different exact-revision algorithm.

Also distinguish three meanings of monotonicity:

- `L8_monotone`: successive deliveries **within one key’s timeline** have nondecreasing recording and knowledge times;
- temporal-prefix stability: later-recorded upstream corrections do not rewrite earlier derived availability;
- statistical monotonicity: a change cannot add false promotions.

The first does not prove the other two (`reference/lean/Ref/Laws.lean:428–456`; `audit/stage7/laws-review-gpt-7.md:1–6`). First-revision backfills, retrospective venue-state execution and global admission remain the expressly documented exceptions (`kernel/RULES.md:185–190`).

### F4. Source qualification alone does not establish complete lineage

**Outcome affected: admitting a derived value before every required contributor is usable.**

Current `timeline` uses `filterMap`: an unusable referenced key is discarded if another key supplies a time (`reference/lean/Ref/Resolve.lean:100–104`). `L8_known` bounds existing non-retraction upstream deliveries; it does not prove that every declared lineage member exists or resolves (`reference/lean/Ref/Laws.lean:452–455`).

This is a recorded limitation, not a newly discovered false theorem (`audit/stage7/laws-review-gpt-6.md:209–212`; `audit/stage7/laws-v2-draft.md:188`).

With a multi-source dependency, a good poll could therefore mask an unusable sighting unless certification rejects incomplete or unusable required provenance. **Do not carry the audit table’s “no outcome” classification into a claim of all-contributor causality.**

For B2’s migrated immutable evidence, require the verifier to check every required revision identity and its usability. If arbitrary unresolved contributors are to be supported beyond that certified subset, explicitly strengthen the resolver and its law; do not describe the existing existential behavior as that stronger guarantee.

## 2. Options

### A. Generalize the frozen dependency — recommended

**Outcome affected:** restores covered zeros while retaining availability bounds from both sightings and polls. Incorrect source qualification, closure or cutoff handling could introduce leakage.

Change `Dep.source` to a nonempty collection of sources. Qualify every upstream key by its source, and require that source to belong to the dependency. Compute one maximum over the dependency’s referenced causal upstream timelines.

This preserves the existing event semantics:

- no new event, sentinel or coverage convention;
- no empty-set timestamp;
- no source-specific resolver branch;
- no change to margins, membership windows or coverage boundaries.

**Cost and identities.** Revise and refreeze `Source.lean`, `Resolve.lean`, affected law statements and normative prose. Re-prove the changed L8 result and revalidate monotonicity. Because source closure, registry validity and certificate matching also depend on `Decl.depends`, review their affected laws too—not just the two L8 names in the port plan (`reference/lean/Ref/Source.lean:52,105–127,249–275`).

The Lean definition/proof artifacts, production build, resolver evidence and resulting run identities fork. Changed declaration bytes require new declaration versions; changed pinned artifacts require new certificates and bindings. Unchanged upstream data, mappings and rule-expression bytes need not change merely because the dependency representation changes (`kernel/SOURCES.md:41,63–68`; `kernel/CERTIFICATES.md:83–98`).

**Simplicity.** This is the smallest conceptual correction to the contracts already adopted. Rust already represents `Dependency.sources` and flattens it for closure (`kernel/mm/src/source.rs:36–40,217–220`). The reason to prefer it is not that Rust already has it, but that evidence-set cardinality should not dictate how many feeds constitute one logical dependency.

It follows CLAUDE’s instruction to remove the wrong abstraction rather than patch its consequences (`CLAUDE.md:3–7,13–17`).

**Evidence keys:** requires the explicit source-local interpretation described below; source qualification becomes essential.

### B. Restate each dependency’s input as a genuinely nonempty observation set

**Outcome affected:** can preserve covered zeros, but can also delay rows or change counts if the restatement changes recording times, earliest-sighting selection or coverage.

A legitimate version is:

> An observation record represents an authenticated received result set, including an empty result set—not only an item sighting.

Then every covered window has actual observed responses, and its observations dependency need not be empty. Polls can remain a separate coverage dependency, provided the representation and lineage are genuine.

This is valid only if:

- empty records correspond to actual successful responses;
- original authenticated receive/recording times are retained;
- backfills are distinguished from live coverage;
- all item sightings and claim ties remain recoverable;
- required records are not discarded to keep a bound below \(T\).

The current acquisition code already obtains sightings and polling evidence from the same successful responses, while also incorporating backfill sightings (`ingest/events.py:29–47`). That gives this alternative a real basis; it does **not** justify inventing historical empty-sighting records.

**Cost and identities.** Replace the evidence schema/declarations, transformation specification and lineage construction; independently review the new representation and rerun C7.4 fixtures and certification. Evidence data manifests, producer/transformation hashes, affected declarations, certificates, bindings and runs fork.

The one-source-per-dependency Lean need not change **for cardinality**, but that does not automatically eliminate the evidence-key formalization work below. Keeping Lean frozen is therefore only a conditional saving.

**Simplicity.** Natural if “received result set” is already the authoritative evidence unit. Otherwise it duplicates the polls representation and restructures ingestion to accommodate an unnecessary Lean restriction. In that form it is the workaround CLAUDE §1 rejects.

**Evidence keys:** identify responses, not invented items. They still need explicit source-local decoding and a meaningful evidence-time projection.

### C. Unify sightings and polls into one authoritative recording source

**Outcome affected:** same availability and covered-zero outcomes as B, with additional risks around lossless backfill handling and response granularity.

This is the cleaner form of B: one recording source contains authenticated acquisition records. Successful live responses establish coverage and contain zero or more sightings; backfill records provide sightings but never live coverage.

It removes the duplicated evidence-source split instead of retaining an observations wrapper beside polls. A single-source `recording` dependency is then honest.

**Cost and identities.** Larger acquisition/schema/lineage migration than A; the old evidence declarations and active split paths must actually be replaced, not retained as parallel compatibility channels. Re-review coverage, earliest-observation behavior, ties, backfills and all hash encodings. New evidence and transformation identities propagate through certification and runs.

**Simplicity.** Potentially the best acquisition model from first principles, but the repository has not established that this consolidation is lossless and time-preserving. It should not be adopted solely to avoid reopening proved Lean. A still leaves the more general dependency abstraction useful for genuinely independent sources.

**Evidence keys:** acquisition-record identities, with explicit live/backfill provenance. No coin mapping or synthetic event-time convention.

### Reject: empty-time defaults, optional dependencies, unrelated witnesses

**Outcome affected:** unsupported zeros, early derived availability or silently missing contributor bounds.

Defining `max([])` as zero/negative infinity, dropping the empty dependency, borrowing a poll from another dependency without changing the contract, or attaching an unrelated sighting merely hides the mismatch. These violate the existing empty-lineage rule and the annex review (`kernel/SOURCES.md:118–121`; `audit/stage7/annex-review-gpt.md:48–58`).

## 3. Settle “Evidence keys” explicitly

**Outcome affected:** wrong evidence lookup, accidental revision collapse, unauthorized controls or holdout access.

**Do not approve the port plan’s reading as an undocumented reinterpretation of frozen Lean. Approve its source-local indexing idea only through an explicit reviewed decoding contract.**

The tension is real:

- evidence declarations use their actual key columns and expose no strategy fields (`kernel/SOURCES.md:55–61`);
- Lean describes `Revision.coin` as a coin of \(U\), and provides singular entity/event-column fields (`reference/lean/Ref/Source.lean:34–49,291–302`);
- `Decl.controls` always includes those singular columns (`reference/lean/Ref/Source.lean:97–100`);
- Rust’s evidence controls instead enumerate the actual evidence key columns, without assuming `eventTime` (`kernel/mm/src/source.rs:200–214`).

Specify:

1. **Source-local identity.** Evidence indices encode complete key tuples injectively, without string normalization, coin assignment or broadcast. Never interpret the same index across sources without its source qualifier.
2. **Lossless keys.** Retain `(key,id,observed,created)` for sightings and `(key,recv)` for polls. Different claims at the same observation time must not become competing revisions (`audit/stage7/migration-annex.md:16–24`).
3. **Real controls.** Represent composite key columns explicitly in Lean’s declaration decoding/control inventory. No fake stored `coin` or `eventTime` columns.
4. **Real evidence time.** Define the event-time projection used by admission—for example `observed` for sightings and `recv` for polls—not a constant or a producer’s creation claim. `Loader.rows` and stage 2 examine every required stored row’s event time (`reference/lean/Ref/Source.lean:222–226,278–280`; `reference/lean/Ref/Resolve.lean:189`).
5. **No strategy-domain expansion.** Evidence indices never enter the coin machine. Existing construction already filters evidence out through `Meta.delivered` and `Ctx.make` (`reference/lean/Ref/Source.lean:259–264`; `reference/lean/Ref/Sim.lean:220–223`).
6. **Pinned decoding.** Retain the encoding and reverse identity mapping with admitted artifacts; adding records must not alias existing identities or introduce order-dependent lookup behavior.

This preserves C7’s coin-only strategy subset while making its evidence-only exception precise.

## 4. Concrete changes for A

### Contracts and audit record

**Outcome protected: preventing an unreviewed semantic change from being treated as an equivalent port.**

- **`PROGRESS.md`, `audit/decisions.md`:** record B2 as outcome-relevant, with review, rationale and reversal procedure. Do not classify it like B1’s redundant `openTime` removal.
- **`audit/stage7/laws-frozen.md`:** append the dated definition/statement revision and hashes before dependent proof evidence is judged. That is the freeze’s explicit rule (`audit/stage7/laws-frozen.md:3–4`).
- **`kernel/SOURCES.md` §5:** retain multi-source dependencies; replace “not the one selected at that version” with the reviewed bitemporal provenance/availability distinction. Specify source-qualified immutable lineage.
- **`kernel/RULES.md` §6:** date the grouped-dependency clarification; retain the recording-time cutoff, correction/retraction bounds and documented exceptions. The expression language need not change merely because a dependency has several sources.
- **`audit/stage7/migration-annex.md`:** pin source-qualified lineage encoding, complete semantic read sets, evidence-key/time projections and expected zero availability. Freeze it with the populated manifest, not merely its prose (`audit/stage7/migration-annex.md:3–7,101–106`).
- **`audit/stage7/rust-port-plan.md` §3:** replace B2 and the provisional Evidence keys reading with the settled contract; retain B3’s separate suite revision.
- **`docs/whitepaper.tex`:** the derived-input principle already supports A (`docs/whitepaper.tex:257`). Correct its stale snapshot-only point-in-time paragraph to match the adopted bitemporal contract (`docs/whitepaper.tex:263`); rebuild the PDF as required by `CLAUDE.md:27`.

### Definitions and laws

**Outcome protected: correct dependency confinement, timing and admission.**

- **`Source.lean`:** change `Dep.source` to nonempty `sources`; flatten `Decl.depends`; validate membership/ranges/cycles; qualify upstream keys. Make evidence key-column and time projections explicit. Preserve unique dependency names.
- **`Resolve.lean`:** resolve each reference against its own declared source; retain `upstream.recorded ≤ derived.fetchedAt`; reject undeclared-source references rather than resolving arbitrary registry entries. Keep empty overall dependency evidence unusable.
- **`Laws.lean`, `Proof/Resolve.lean`:** revise `L8_known` for qualified references and source membership; re-prove it and revalidate `L8_monotone`. State separately whether complete usable provenance is a verifier obligation or an additional resolver guarantee.
- **Affected-law review:** audit all 18 laws’ definition dependencies. Closure, control inventory and registry changes affect L5 certification/admission/text obligations and checker premises as well as L8. Unchanged proof bodies may recompile, but their old validation artifacts do not certify the new definition closure. C7.7 explicitly requires review and refreeze of changed referenced definitions (`audit/criteria.md:930–934`).
- **`Machine.lean`:** no event-read redesign. Preserve current-slot-only reads and no default zero.

### Implementation and evidence

**Outcome protected: production/reference agreement and migration preservation.**

Update declaration decoding, the generic Rust resolver, `ingest/knownat.py`, event-lineage production and verifier checks. Extend `refmm` to exercise actual resolver inputs, not only already-resolved observations.

Revise and freeze the resolver fixtures/generator and comparison procedure before judged execution. Compare Python, Rust, independent GPT and Lean on:

- no sightings anywhere, but covered mapped zero at \(T\);
- positive counts and both margins;
- identical local keys in different evidence sources;
- undeclared-source references;
- missing/unusable required members beside a good poll;
- later upstream corrections and retractions;
- derived recording-time boundaries;
- claim ties, cutoff boundaries, gaps and unmapped keys;
- evidence-time holdout boundaries.

Keep C7.1 renaming invariance, C7.2 metadata-only checking, transitive certificate/holdout checks, C7.5’s no-code demonstrations and C7.7 mutants intact (`audit/criteria.md:830–951`).

## 5. Acceptance risks and stopping conditions

- **Migration risk — changed deliveries or returns:** any bound above \(T\) blocks preservation; do not widen scope, shift ticks or remove fixtures.
- **Provenance risk — early use:** source qualification cannot compensate for incomplete lineage or `filterMap`’s partial-success semantics.
- **Identity risk — concealed transformation changes:** retain truthful legacy records-read hashes and add lineage hashes beside them. The annex expressly forbids replacement (`audit/stage7/migration-annex.md:50–58`). C7.4 permits only enumerated identity projection, not removal of changed provenance payloads.
- **Freeze risk — overstated proof coverage:** rechecking the two L8 proofs alone is insufficient when declaration closure or control decoding changes.
- **Scope risk — altered discovery selection:** whole-run refusal remains an outcome channel, even when earlier delivery prefixes are unchanged (`audit/stage7/laws-review-gpt-9.md:25–39`).
- **Status risk — claiming completion prematurely:** the annex still calls itself draft and requires a populated freeze manifest; the active registry contains only the two venue declarations (`audit/stage7/migration-annex.md:1–7`; `sources/registry.json:1–13`).

**Bottom line:** fix the dependency abstraction in Lean, preserve the event mathematics, and formalize evidence decoding. Prefer consolidation of recording evidence only if it independently removes duplication without changing authenticated times or losing records—not as a way to avoid revisiting a frozen mistake.
