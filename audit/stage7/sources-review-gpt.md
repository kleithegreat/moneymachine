[0m
> build · gpt-6.1-sol
[0m→ [0mRead . [90m[limit=100][0m
> build · gpt-6.1-sol
**Do not freeze these drafts yet.** The following are ordered by importance. Proposed wording belongs in `SOURCES.md` or `CERTIFICATES.md`; none requires changing frozen `RULES.md`.

## 1. Certification does not enforce the full availability bound

**`CERTIFICATES.md`, Availability; C7.3.** The independent-witness bound is missing. Moreover, `prospective-only` merely constrains the certificate’s start date: it does not stop a row fetched later from receiving an earlier, feed-claimed knownAt. The declaration’s single rule also cannot silently acquire certificate-dependent semantics.

**Add:**

> For every certified row, the verifier establishes the permitted availability basis. A claimed-time rule is permitted only within the entity, field and historical interval for which protocol-enforced or server-set timestamps and the required live test qualify it. Its effective availability must additionally respect every applicable independent-witness bound selected by the frozen policy. The policy defines witness selection deterministically; the producer cannot select or omit witnesses.
>
> A prospective-only revision must have effective knownAt no earlier than its trusted fetchedAt. Merely starting the certificate’s scope at the first poll does not satisfy this requirement.
>
> These bounds must be expressible by the declaration’s pinned rule and the frozen resolver. A certificate cannot override that rule, authorize a different rule for particular rows, or make a rejected row usable. Rows requiring incompatible availability bases must be excluded from scope or represented by an explicitly specified, uniformly applicable rule arrangement.
>
> `fetchedAt` and witness times require authenticated recorder evidence; producer-supplied timestamp values alone are not evidence of observation time.

This closes the most direct route to early use.

## 2. There is no holdout boundary

**Both drafts; C7.4 and the requested holdout review.** A valid certificate is not authorization to access a holdout. A renamed dataset, substituted binding, shifted timestamp, role provider or derived dependency can currently carry protected data into evaluation.

**Add to `SOURCES.md`:**

> Certification and evaluation authorization are separate checks. Before opening observation payloads, the evaluator computes the complete access closure: strategy inputs, simulator roles, initialization and warm-up data, outstanding-order and accounting horizons, mappings, coverage inputs and transitive derived dependencies.
>
> Every access must be authorized for the campaign and evaluation purpose. Authorization follows immutable dataset identity and transitive lineage, not source names, paths, aliases, bindings or transformed timestamps. A declaration, binding, certificate or derived transformation cannot grant access to a protected partition.
>
> Search evaluations and C7.4 comparisons must not materialize holdout observations or values derived from them. A required access crossing that boundary is refused before payload loading and produces no result-bearing output.

Explicitly cover fills or final accounting that extend beyond the last decision tick.

## 3. “Entities, fields and a time interval” is not an implementable scope definition

**`CERTIFICATES.md`, What a certificate pins; C7.2–C7.3.** Is time eventTime, knownAt, fetchedAt or evaluation time? Does a scoped held observation remain usable after the interval ends? Are role-only columns covered? Can independently certified combinations be combined into an uncertified Cartesian product?

**Replace the scope bullet with:**

> The certified scope is an explicit set of grants over entity, stored column, event-time interval and permitted-use-time interval. Intervals are half-open `[start, end)` in integer milliseconds. The dataset cutoff is a separate pinned dimension. No Cartesian-product expansion of separate grants is implied.
>
> Scope includes DSL-visible fields, role-only columns, availability inputs, and the mapping and coverage facts used to produce or select observations. Each actual access, including initialization, warm-up, lag/window history and held-value reuse, must fall within its applicable grant.
>
> A value does not remain authorized outside its permitted-use interval merely because it was delivered earlier. Out-of-scope required access is `R_UNCERTIFIED`, not undefined data and not an instruction to discard rows silently.

A different scope representation is possible, but these dimensions and boundary rules cannot remain implicit.

## 4. A ledger “pass” and a manifest hash do not establish certificate authority or immutable use

**`CERTIFICATES.md`, issuance, evidence and identity; C7.3.** The drafts do not specify how forged certificate rows are distinguished from verifier-issued records, whether a manifest is complete, or how validation survives subsequent file changes.

**Add:**

> A certificate is accepted only through an issuer-authenticated, committed verifier record. A builder-written ledger row, certificate file or asserted pass is not authority. Issuance authenticates external evidence and recomputes every machine-checkable result; it never accepts producer-reported metrics as results.
>
> The data manifest completely identifies the immutable snapshot, including relevant revisions, tombstones, poll logs, lineage and schema metadata. The verifier checks completeness as well as listed-file hashes.
>
> Declarations, exact rule bytes, feed specifications, producer and transformation implementations, mappings, coverage artifacts, policy and evidence are retained by content hash. A version label without an immutable implementation identity is insufficient.
>
> Preflight admits one immutable snapshot. Evaluation uses those admitted bytes, not subsequently reopened mutable paths or aliases. Cached outputs are keyed by the complete admitted identity and never substitute for recomputation under another rule.
>
> Issuance, binding and run admission become effective only after their ledger transactions commit. Failure to verify or commit emits no success or result-bearing output.

## 5. Required-source preflight is not transitively closed

**`SOURCES.md`, Checking and preflight; C7.2.** Direct inputs and roles are included, but derived dependencies are not. “Before delivery or evaluation” also leaves loading, initialization and coverage computation outside the boundary.

**Replace the required-set/preflight language with:**

> The statically required sources include every source named anywhere in the program, including unused lets, inactive branches and the prediction condition. The run additionally requires its selected role providers and the transitive dependency closure of all required sources.
>
> `mm check` reads declarations only. It neither reads nor validates feeds, bindings, certificates or stores. It records role obligations without consulting bindings.
>
> Preflight resolves and pins the complete required closure before observation loading, initialization, delivery, coverage computation or expression evaluation. A missing binding anywhere in that closure is `R_INPUT_UNAVAILABLE`; an invalid, mismatching, superseded or insufficiently scoped certificate is `R_UNCERTIFIED`.
>
> Compilation errors take precedence. For an otherwise valid program, any missing required binding takes precedence over certificate failures. Refusal is ledger-recorded before output and emits no result-bearing output.

## 6. Derived lineage is currently a producer assertion, not a resolvable dependency

**`SOURCES.md`, Derived sources; C7.3–C7.4.** Storing “the latest knownAt” does not identify the inputs used. A producer can omit a late input, reuse an obsolete revision or supply a fabricated timestamp. Raw observations and polls required by C7.4 also have no explicit representation.

**Replace the derived provenance paragraph with:**

> Each derived row records, for every declared dependency, immutable identities of all required upstream revisions and evidence inputs. A stored dependency timestamp is a cache, never authority.
>
> The verifier recomputes the pinned transformation and its lineage. The resolver derives dependency times from the identified upstream inputs under their own pinned rules at the same dataset cutoff. If an upstream revision selected at that cutoff differs from the revision used to compute the row, the derived row is unusable until recomputed and recertified. An unavailable required input makes the row unusable.
>
> Version 1 must explicitly represent the migrated event feeds’ raw-observation and poll dependencies, with revision identities, availability rules and certificate bindings. Evidence-only upstream inputs expose no DSL fields and do not broaden the supported strategy entity or field types. If those dependencies cannot be represented under the frozen resolver, migration is blocked; they cannot be omitted or replaced by asserted times.

The drafts need the corresponding lineage/binding schema, not just this obligation.

## 7. Zero counts, mapping and coverage have dependencies too

**`SOURCES.md`, Derived sources and Delivery; C7.4.** An empty set of counted events has no maximum input knownAt. Without explicit poll and mapping dependencies, zero can appear before completeness is known, or coverage can be inferred from a later poll.

**Add:**

> A derived count’s required inputs include the observations counted, the mapping facts assigning them, and the poll/frontier evidence establishing completeness of its aggregation window. A zero count requires positive evidence of covered, mapped completeness; an empty event set alone does not establish zero.
>
> Empty dependency lineage has no default timestamp. It is invalid unless the frozen transformation explicitly defines and verifies a sufficient nonempty completeness witness.
>
> Operational mapping and coverage facts must be available by the row’s effective knownAt. A later poll cannot retroactively establish coverage unless the frozen, certified transformation expressly supports that inference. Later audit labels are evidence, not automatically earlier operational inputs.

## 8. `derived-inherits` can waive tests that the transformation invalidates

**`CERTIFICATES.md`, applicability policy; C7.3.** Having certified upstreams does not show that a new transformation preserves their mapping, terms restrictions or revision semantics.

**Replace its justification with:**

> `derived-inherits` is valid only for the particular test whose property the verifier establishes is preserved by the pinned transformation. The verifier checks the exact upstream certificates and lineage, absence of additional acquisition, preservation of applicable terms restrictions, the declared entity assignment, and propagation of revisions, deletions and availability.
>
> Upstream certification alone does not justify inheritance. A transformation that changes entity assignment requires applicable mapping evidence. New hosts require terms evidence. Coverage is recomputed, not inherited. Excluded extraction cannot enter through an upstream dependency.

## 9. Role mappings omit the contract that makes execution causal

**`SOURCES.md`, Roles; C7.2–C7.4.** Columns alone do not specify units, bar interval, funding sign, freshness or which timestamp identifies the required observation. Nor do they distinguish strategy-visible data from simulator outcome data.

**Add:**

> Each role has a frozen contract specifying column types and units, timestamp meanings, cadence, observation identity and freshness requirements, and permitted simulator access phases. A binding supplies columns, not alternative role semantics.
>
> The version-1 bars role represents the frozen 4h execution bars; the settlement role represents hourly funding with the frozen sign and rate convention. Decision readiness requires the settlement for H and the bar ending at H, not merely any held values from those providers.
>
> Simulator accesses follow exactly the phases prescribed by DSL.md and INVARIANTS.md. Access to a bar’s execution outcome does not deliver that bar’s other columns to strategy expressions, windows, prediction conditions or coverage logic.
>
> A run explicitly selects exactly one provider declaration for each required role. Merely registering another role-capable declaration neither changes that selection nor makes the registry invalid. Role-only columns require certification even when absent from `fields`.

Publish the actual type/unit/time/phase table before freezing.

## 10. Held cadence has no period, so C7.1 and C7.5 are not expressible

**`SOURCES.md`, cadence.** `{"held": {}}` cannot declare an hourly, 4h or daily grid. It also cannot demonstrate the synthetic source’s distinct cadence.

**Replace held cadence with:**

> A held cadence is `{"held":{"period_ms":P,"phase_ms":O}}`, where P is a positive in-range integer and `0 ≤ O < P`. Its nominal slots are `O + kP` milliseconds from the Unix epoch. The declaration specifies which Time column labels the nominal slot and its boundary meaning.
>
> The nominal grid is not an availability promise: delivery still requires effective knownAt ≤ tick. The period is not a time-to-live. A held value persists until a delivered observation replaces or clears it, subject to certified-use scope.
>
> Missing nominal observations do not synthesize zero, a new observation or expiration.

The migrated grid labels must be checked against the baseline rather than guessed.

## 11. Delivery order is ambiguous and source-name ordering threatens renaming invariance

**`SOURCES.md`, Delivery; C7.1 and C7.4.** “Order of `(knownAt, coin, eventTime)`, sources in declaration-name order” admits source-major and time-major readings. Late older observations, early event arrivals and cross-source evaluation also need explicit outcomes.

**Replace with:**

> Resolution is performed against the run’s fixed snapshot. Within each source, observations are ordered by `(effective knownAt, coin, eventTime)`, with times compared as integers and coins by decoded Unicode scalar sequences.
>
> All deliveries due at a tick complete before any expression or cross-sectional operation is evaluated. Cross-source interleaving is semantically unobservable. Trace serialization uses explicit run-manifest slots preserved by consistent renaming, not declaration-name spelling.
>
> For held inputs, the last observation in that order wins, even when its eventTime precedes that of a previously delivered observation. Each field is replaced independently; null or absent clears it to undefined. It does not retain the preceding non-null value.
>
> For an event observation keyed at E, its value is defined only at tick E + δ, and only if its selected revision is usable by that tick. Earlier delivery must preserve it for that tick; later availability never moves it to another tick. No event value survives its designated tick.
>
> A missing key, tombstone or rejected revision is not a delivered null and does not itself clear another held observation.

If “last delivered wins” is not baseline behavior, resolve that before freezing.

Also add:

> For declared inputs, this section supersedes DSL.md’s blanket statement that inputs hold and its hard-coded input catalogue. DSL operators, evaluation clock and simulator semantics remain unchanged.

## 12. Binding contradicts nullable storage and lacks a complete schema contract

**`SOURCES.md`, Stored observations and Binding; C7.1–C7.2.** “Every declared column present and numeric” rejects permitted nulls. All-null columns cannot prove a numeric schema. Time columns and role-only columns lack equivalent validation.

**Replace the binding bullet with:**

> Every DSL field has numeric type `number`: a finite numeric value, excluding booleans, or null/absent meaning undefined. Binding validates the declared dataset schema and every stored non-null value; an all-null column requires explicit numeric schema metadata. It is not inferred from samples.
>
> Every declared Time column and temporal key has the integer-millisecond type and range required by RULES.md. Null or absent Time inputs retain RULES.md’s rejection semantics when read; they do not receive defaults.
>
> Role columns are validated against the role contract, including types, units and temporal meaning. Extra stored columns are permitted but remain part of correction comparison as specified by RULES.md; loaders must not prune them before resolution.
>
> Required keys, allowed keys, name collisions and type conflicts are validated at every schema level.

## 13. Certified mapping and units are not actually checked by binding

**`SOURCES.md`, Binding; C7.1 and C7.5.** Existing wording checks columns but not the certified mapping. A declaration’s unit label does not establish the feed’s unit. `identity-keyed` does not pin the venue universe or symbol-validity intervals.

**Add:**

> Binding matches the feed’s certified schema metadata, units, mapping artifact and applicable scope to the exact declaration. It does not infer units from values or names, perform scaling, normalize symbols, broadcast values or substitute a current mapping.
>
> `identity-keyed` pins the venue-rules artifact and its applicable entity/time scope; membership in an unversioned current symbol list is insufficient.
>
> A contextual scalar may apply to multiple run coins only through an explicit certified assignment to those keys, with its scope and availability recorded. The assignment asserts applicability, not that the scalar’s subject is a coin. No implicit broadcast is permitted.
>
> If that assignment is not representable by the frozen mapping contract, the real-feed demonstration is blocked.

## 14. The applicability table is not the frozen test policy

**`CERTIFICATES.md`, policy and Tests; C7.3.** Required metrics, predicates, sampling procedures, minima and windows are promised but not specified. Kind selection can also become a way to avoid a revisions test.

**Add:**

> The normative policy contains, for every applicable test and permitted justification, its exact predicate or metric, threshold, deterministic sample procedure, minimum sample, evidence window and required evidence schema. Missing entries reject issuance; prose category names are not executable policy.
>
> The verifier determines source kind from acquisition and lineage evidence, rather than accepting the submitter’s label. `recorded` cannot authorize historical usability before authenticated observation.
>
> Migrated-feed policy entries identify the exact stage 0/stage 5 frozen decisions, dated amendments and limitations by immutable reference. Those limitations constrain certificate scope; they are not replaced by generic stage 7 defaults.

Add the missing design-freeze rule:

> For a new feed, the declaration, feed specification, thresholds and applicability decisions are committed before any return-conditioned evaluation or selection involving it. Mapping, keywords, lag and coverage-window selection count. Issuance records those commitments and rejects missing or contradictory provenance. Migrated feeds retain their explicitly identified earlier decisions.

## 15. Supersession does not define validity, dependency effects or replay

**`CERTIFICATES.md`, Lifecycle; C7.3.** “Newer” could mean automatic replacement. Partial scope replacement is undefined. A derived certificate could remain accepted after its upstream is superseded. Reproduction could become a route around the new-evaluation prohibition.

**Replace Lifecycle with:**

> A certificate has an immutable identifier over its complete canonical payload and authenticated issuance record. Bindings and runs reference exact identifiers, never “latest”.
>
> Supersession explicitly names the superseded certificate ids and takes effect at its committed ledger position. It supersedes each named certificate in full; partial supersession is unsupported in version 1. A later issuance does not automatically supersede another certificate.
>
> New-run admission atomically checks validity of every certificate in the transitive dependency closure. A superseded upstream certificate prevents new admission of dependent certificates until replacement certification establishes a valid closure. Admission pins bindings, artifacts and the lifecycle ledger position.
>
> Existing experiments retain their original identities and artifacts. Any replay facility is restricted to that existing experiment and its original authorization; it cannot evaluate another strategy, expand data access or release new search results under a superseded certificate.

## 16. C7.5’s documented, no-code operator path is absent

**Both drafts; C7.5.** There are no registration, submission, certification or binding commands. Terms records live outside the permitted edit locations. The policy also needs a viable synthetic route: a no-network fixture cannot supply empirical terms samples or raw live API evidence by assertion.

**Add a normative CLI section:**

> The documented CLI provides declaration registration, evidence submission and verification, certificate inspection, binding creation, checking and evaluation. Each command specifies its accepted files, immutable outputs, ledger effects, rejection outcomes and commit-before-output behavior.
>
> The frozen demonstration procedure enumerates every CLI-produced artifact and location. Operator-supplied files are confined to `sources/`, the evidence bundle and data; strategy documents may be supplied from those locations or through documented standard input.
>
> Before the generic implementation is frozen, the policy and CLI support both the synthetic demonstration and a qualifying real-feed path. A no-fetch fixture justification requires verifier-checkable evidence and cannot authorize external historical data. A new terms record, where needed, must be admissible through the permitted path rather than a manual edit outside it.
>
> A transformation hash is identity evidence, not permission to execute submitted code. Declarations and bundles cannot load plug-ins, evaluate host-language expressions, generate implementations or change policy.

Publish the exact invocation sequences and expected outcomes for both demonstrations.

## 17. Declaration identity, active versions and exact rule bytes need definition

**`SOURCES.md`, Files; `CERTIFICATES.md`, Identity; C7.1–C7.3.** One mutable `<name>.json` path cannot preserve old versions by itself. Global input uniqueness across all archived versions is impossible when a version retains its inputs. Embedded JSON also needs a precise rule-byte identity.

**Add:**

> A run pins an immutable registry containing at most one active version of each declaration name. Input names are unique across that active registry, not across archived versions. Every registered declaration version is retained by exact content hash.
>
> The registry explicitly distinguishes declaration files from policy and demonstration files; registration does not treat every JSON file under `sources/` as a declaration.
>
> For an embedded rule, the exact UTF-8 bytes of the rule object’s value in the declaration are the rule-document bytes pinned by the dataset version. Their SHA-256 is recorded explicitly. Reformatting those bytes changes that identity.
>
> Run identity includes the registry, role selections, bindings, dataset snapshot and certificate closure. Feed substitution preserves the checked program’s source references but creates a distinct run identity.

## 18. C7.4 preservation is not established by these generic semantics

**Both drafts; C7.4.** Neither draft supplies the migrated declarations, transformations, bindings or compatibility evidence. Several proposed interpretations above could change deliveries while still sounding reasonable.

**Add a normative migration annex requirement:**

> Before migration is judged, the migration annex pins declarations, rules, grids, role contracts, feed specifications, transformations, raw/poll dependency representations, mappings, coverage semantics, bindings and certificate evidence for funding/premium, 4h bars and both event-count feeds.
>
> The event transformations specify the exact pre-first-poll exclusion, earliest-observation and claim tie-breaks, both margins, cutoff exclusion, window ending at the tick, exactly-ten-minute poll boundary, gap handling, prohibition on later-poll coverage inference, covered mapped zeros, undefined cases and lineage hashing.
>
> C7.4 compares against the pilot-fixed baseline commit, dataset cutoff `1792613363942` and frozen markets, using W0, every stage 2 probe and the first 200 frozen C6.4 programs. Deliveries, knownAt, definedness, node streams, decisions, fills, accounting and returns must be byte-identical under the frozen projection removing only the enumerated identity fields.
>
> Missing evidence or a semantic mismatch blocks migration. It is not repaired by changing the baseline, widening certificate scope, dropping a case or adding another projection exclusion. The replaced per-feed production paths are deleted.

Without that annex and comparison, neither the drafts’ completeness nor byte-identical migration can be inferred.
exit=0
