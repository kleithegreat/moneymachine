[0m
> build · gpt-6.1-sol
**Do not freeze this draft yet.** The derived rules are rejected by `RULES.md`, and the lineage description cannot establish the claimed dependency bound. The following are ordered by importance.

## 1. Both derived availability rules fail static checking

**Annex §1; `RULES.md` §4.5.** `eventTime + δ` contains neither declared dependency in its lower-bound set. A runtime argument that dependencies happen to precede T cannot replace this syntactic requirement.

Replace both derived rules with the following, using these exact dependency names:

```json
{"rule":1,"expr":{"max":[
  {"add":[{"field":"eventTime"},{"ms":120000}]},
  {"dep":"observations"},
  {"dep":"polls"}
]}}
```

Add:

> `forum-events` declares `observations` → `discourse-observations` and `polls` → `discourse-polls`; `governance-events` declares the corresponding Snapshot sources. Each dependency has `lag_ms: 0`. Every additional declared dependency must also occur as a `dep` term in the rule’s lower-bound set. All rules must pass RULES.md §4 before binding; no cached dependency time or proof about the dataset substitutes for checking.

Also replace the assertion that dependency time is necessarily at most `T − m`. That is not established by the proposed lineage, and need not hold for effective upstream times.

> For each dependency, the resolver computes the maximum effective knownAt of the identified, selected upstream revisions, under that upstream declaration’s pinned rule at the same V. Stored dependency times are caches only. Effective derived availability includes the dependency and correction bounds of RULES.md §6. Availability equals T only when all those bounds are ≤ T. Otherwise the event is undefined at its original tick; it is never backdated, moved to another tick, or recovered through an older revision. Any resulting mismatch with the baseline blocks migration.

## 2. The recorded-evidence rules do not establish prospective-only availability

**Annex §§1 and 3; `CERTIFICATES.md` §§2–3.** Rules consisting solely of `observed` or `recv` are not syntactically bounded below by authenticated `fetchedAt`. Saying the certificate is “prospective only” cannot repair this: certificates do not override rules.

Replace the observation rules with:

```json
{"rule":1,"expr":{"max":[
  {"field":"observed"},
  {"field":"fetchedAt"}
]}}
```

Use the analogous rule with `recv` for polls. Add:

> Observation and poll timestamps require authenticated recorder evidence. A producer-supplied timestamp is insufficient. The evidence bundle pins the relationship between `observed`, `recv` and `fetchedAt`; equality is not assumed. Backfill observations use their fetchedAt as their observation time. Live sightings use the successful poll’s receive time. Poll evidence contains successful live polls only—not failed requests, request-start times or backfill fetches. Both revision eligibility (`fetchedAt ≤ V`) and the observation/poll cutoff specified by derived.md are enforced.

> The verifier checks whether these rules preserve the legacy event availability on the certified data. A later authenticated recording time or correction that raises an upstream effective knownAt beyond T is a blocker, not permission to use the earlier timestamp alone.

This matters especially for Snapshot’s zero margin: there is no margin to absorb a recording delay.

## 3. Covered zero counts expose an unresolved empty-dependency problem

**Annex §2; `SOURCES.md` §5; `RULES.md` §6.** “A zero count’s lineage is its covering polls, never empty” addresses the union of dependencies, not the mandatory **observations dependency**.

A mapped key may have complete polling coverage and no sightings at all. `derived.md` requires a zero row. The annex supplies no observations identities, so that dependency has no usable time. Neither specification defines empty-dependency time as zero, minus infinity or the poll time.

Add this explicit blocker:

> A covered mapped window with no observations for its key is a mandatory zero-count fixture. A non-empty poll lineage does not supply a time for an empty observations dependency. Before this annex is frozen, it must pin a contract-supported representation of authenticated empty observation input, with its declaration, immutable revision identity, availability rule and certificate evidence, and demonstrate that this fixture resolves to zero at T. If the current declaration and resolver contracts cannot represent it, migration remains blocked pending an explicit normative revision. The implementation must not invent an empty-set time, omit the declared dependency, fabricate an item, or attach an unrelated observation merely to make lineage non-empty.

This cannot safely be resolved by annex prose silently changing the resolver.

## 4. Lineage omits inputs needed to establish the count—and uses incomplete revision identities

**Annex §2; `SOURCES.md` §5.** The required identity is **upstream key plus fetchedAt**, not just the observation/poll key. The current lineage also names only counted items, omitting potentially necessary evidence for earliest-observation selection, claim ties, exclusions and the first-poll boundary.

Replace the lineage paragraph with:

> Each row records, separately for every declared dependency, the complete immutable identities `(upstream key, fetchedAt)` of every upstream revision used to derive it. This includes the records used to select earliest observations and resolve equal-time claim ties, apply pre-first-poll exclusions, establish the key’s first successful poll, and establish coverage, including the poll at or before the window’s left endpoint. A counted-item list alone is not derivation lineage.

> The transformation specification pins the exact per-row read set and its construction, including empty inputs. It may not retrospectively remove a used record from lineage because that record would delay availability. If preserving the legacy transformation requires an input whose effective knownAt exceeds T, that is a migration blocker.

> Every identified revision must be the revision selected at V under its upstream resolver. A selected tombstone, rejected revision, unavailable dependency or superseded certificate makes the derived row unusable as specified by the source and certificate contracts; there is no fallback to an older revision.

Also pin how evidence storage preserves observation ties:

> Distinct sightings, including equal-observation-time sightings carrying different claims, must remain representable until the frozen earliest-observation/minimum-claim rule is applied. They must not accidentally become competing revisions of one evidence key and be reduced by `latest`. The evidence schema and fixtures pin the lossless representation.

The current evidence key table does not establish that property.

## 5. The coverage window incorrectly has an open left endpoint

**Annex §2 versus `derived.md`, Coverage.** Item membership uses `(a,b]`; coverage is tested over **`[a,b]`**. The annex conflates them.

Replace the window and coverage bullets with:

> For hour τ, let `T = τ + 120000`, `a = T − 3600000 − m`, and `b = T − m`. Item membership uses witness interval `(a,b]`. Coverage is tested over the closed interval `[a,b]`.

> An hour is covered only when `T ≤ V`, its key maps to a coin of U, and for every instant `t ∈ [a,b]` there is a successful live poll p with `t − 600000 < p ≤ t`. Equivalently, there is a poll at or before a; consecutive polls from the last such poll through b have gaps no greater than 600000 ms; and the last poll at or before b is strictly later than `b − 600000`. No poll after b establishes coverage.

Add fixtures for:

> A first poll at a, a first poll at `a + 1 ms`, a poll at b, a last poll exactly at `b − 600000`, interior gaps of 600000 and 600001 ms, and a poll after b that would close an otherwise uncovered gap.

Keep the margin distinction explicit:

> Coverage uses `[T − 3600000 − m, T − m]`; count membership uses knownAt interval `(T − 3600000, T]`. Count membership never uses the claimed creation time. Each `(key,id)` counts at most once.

## 6. A mapping hash is not evidence that the mapping was available in time

**Annex §§1–3; `SOURCES.md` §5; `CERTIFICATES.md` §§2–5.** The mapping is pinned by hash, but its assignment semantics, temporal availability and authorized scope are not pinned. Those facts affect both counts and zero-row production.

Add:

> For each mapping artifact, the frozen manifest pins its bytes and SHA-256, exact key-to-coin assignments, applicable entity and event-time scope, availability evidence and permitted-use grants. The verifier establishes that every mapping fact used by a row was available by that row’s effective knownAt. An artifact hash alone does not establish availability.

> The mapping contract explicitly specifies permitted assignment cardinalities and the handling of duplicate keys, multiple keys assigned to one coin, and unmapped keys. Migration preserves the frozen mapping contract; it introduces no aggregation, broadcast, normalization or reassignment by inference. Unsupported assignments block migration.

> A derived mapping test cannot use `derived-inherits` to justify a changed entity assignment. Any representation of mapping facts as an additional source dependency is declared, certified, included in lineage and included in the rule’s dependency lower-bound set.

## 7. The required identities, schemas, specifications and grants are described, not actually pinned

**Annex §§1 and 3; `SOURCES.md` §9.** “Pinned by SHA-256,” directory references, “every dated amendment,” “U’s coins” and “the evidence sources’ scope” leave substantive choices unresolved.

The declaration table also omits exact `times`, missing/revision settings and several stored-column mappings. The bars role is a list rather than an explicit role-column mapping.

Add a freeze requirement:

> The annex is frozen only together with a committed, populated migration manifest. No placeholder, branch head, mutable directory reference or “latest” reference is a pin.

> The manifest identifies all declaration files and their SHA-256 values; registry bytes; exact rule bytes and hashes; Time columns; complete evidence keys; numeric and role schemas; missing and revision settings; held periods and phases; event-slot validation; every field-column and role-column mapping; feed specifications; producer and transformation hashes; mapping and coverage artifacts; immutable data manifests and cutoffs; and the exact dated criteria and evidence artifacts being retained.

For bindings and certificates:

> Each binding names an exact declaration version, immutable dataset manifest and verifier-issued certificate id. Each certificate pins the frozen policy hash and upstream certificate closure. Historical stage-0/5 reports are evidence inputs, not certificates or submitted passes.

> Scope is enumerated as explicit grants over entity, stored column, event-time interval and permitted-use interval, with half-open integer-ms endpoints. Grants cover role columns, availability inputs, raw observations, polls, mapping and coverage facts, warm-up and all other accessed history. Separate grants do not combine into a product. Dataset cutoff is specified separately. Authorization for search versus holdout is checked independently by immutable dataset identity and lineage.

> Evidence logs used for comparison or admission are immutable snapshots identified by manifest, never reopened “live poll logs.” Missing evidence or insufficient scope blocks migration; it does not become undefined data or a silently dropped case.

## 8. The proposed lineage hash does not replace `derived.md`’s records-read hash

**Annex §2 versus `derived.md`, Count.** `derived.md` requires each row to carry the transformation hash, mapping hash, cut V and SHA-256 of the **records read**. The annex supplies a sorted identity-list hash instead.

Add:

> Every derived row retains the SHA-256 of `ingest/events.py`, the mapping-file SHA-256, cut V and the legacy SHA-256 of the records read, computed by the frozen legacy encoding and read-set definition. A new lineage-identity hash is additional metadata and never substitutes for that records-read hash.

> The manifest pins the exact encoding, ordering, dependency/type separation, treatment of duplicates and hash input bytes for both hashes, with independently specified expected fixture values. Any ambiguity in the legacy hash definition is resolved from the frozen baseline implementation and outputs, not by choosing a new encoding during migration.

Otherwise a changed claim or read set could escape the stated identity-list comparison.

## 9. The comparison is not yet a frozen, independently checkable experiment

**Annex §4; C7 evidence rule and C7.4.** The baseline is described but not identified; baseline **outputs** are not explicitly captured before rebase; case identities, expected fixture results, execution configuration and projection implementation remain unspecified.

Replace §4’s baseline/case setup with:

> Before `stage7` is rebased onto the pilot-fixed baseline, and before any C7 criterion is judged, commit an immutable comparison manifest containing the exact baseline commit, build hashes and captured baseline outputs. The baseline is the pilot-selected main commit after the required correctness merge; migration results cannot influence its selection.

> Before the first judged C7.4 run, commit the complete case inventory, generation procedures and seeds where applicable, exact program bytes, data and market fixture identities, run configurations, expected fixture outcomes, mandatory coverage witnesses, projection implementation and comparison procedure. The C6.4 corpus ordering and identity are frozen so “first 200” is unambiguous. Every stage-2 probe is individually enumerated.

> Baseline and migrated executions use the same pinned semantic inputs, including U, decision interval, warm-up/history, simulator settings and post-decision accounting horizon. Only the changes explicitly required to select the migrated declarations, bindings and certificates differ. Semantic baseline expectations are captured independently of the migrated implementation.

Also replace the coverage assertion with something auditable:

> The manifest maps each mandatory coverage class to named cases and expected observations or absences. It includes every migrated DSL field, every simulator role column, both event feeds, positive and covered-zero counts, unmapped and uncovered absences, margins and endpoint cases, revisions, tombstones, dependency bounds and availability boundaries. A source merely being registered or opened is not coverage. Missing mandatory coverage fails C7.4; it is not repaired by changing the selected baseline suite or its data.

> Derived fixtures have frozen raw inputs and hand-specified expected rows, counts, absences, times and hashes. Agreement between two implementations without those expected outcomes is insufficient.

## 10. Projection and failure handling could conceal differences

**Annex §4.** “Removes … ids” needs exact locations. A recursive removal by field name could erase item ids or lineage. Byte comparison also needs to detect absent, duplicate, truncated and unparsed output.

Add:

> The projection is a frozen allowlist of exact artifact paths and structured field locations for kernel, declaration, binding and certificate identity fields. It does not remove fields by name globally. It preserves item ids, timestamps, counts, lineage, hashes other than the enumerated identities, ordering and every semantic payload. No sorting, rounding, tolerance, timestamp shifting or additional normalization is applied.

> Compare the complete expected artifact inventory, record counts and projected byte streams. Missing or extra artifacts or records, duplicates where prohibited, skipped cases, crashes, timeouts, malformed or truncated output, and any byte mismatch fail the judged run. Host errors are not accepted outcomes. There is no automatic baseline regeneration or golden-file update.

> Preserve unprojected artifacts. Record the identity substitutions separately so projection cannot conceal a changed input snapshot or lineage graph. Every failed judged run remains recorded; every rerun has a new identity.

## 11. The annex omits C7.4’s required deletion of per-feed implementation paths

Add a migration-completion paragraph:

> Migration completion requires deletion of `EVENT_INPUTS`, the per-input enum variants, and the per-dataset branches in `market.rs` and `ingest/store.py` identified by C7.4. The frozen migration inventory enumerates their exact locations and replacement declaration/role mechanisms. The completion evidence records their removal and verifies that equivalent identifier-selected behavior has not merely moved into another production, ingestion, reference-kernel or generated-code path.

A byte-identical comparison alone would not demonstrate that requirement.
exit=0
