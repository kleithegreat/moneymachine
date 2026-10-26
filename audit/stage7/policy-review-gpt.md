# GPT 6.1 Sol's review of the draft certification policy (sources/policy.json on branch stage7, commit 7c174ce)

Run from `~/.cache/mm-gpt/policy.nZAu` with tools denied; GPT saw policy.json, CERTIFICATES.md, SOURCES.md, RULES.md and the stage 7 criteria. Verbatim below.

# Review: `policy.json`

**Verdict: do not freeze this draft.** It has the six category entries for each kind, but several entries do not establish the property they would certify. The largest risks are unsupported historical availability, exemptions without checkable conditions, incomplete migration rules, and coverage tests that cannot establish event completeness.

Findings below are ranked by severity. **Each is blocking for the affected certification path.** A path can be unblocked by fixing it or explicitly rejecting it—not by accepting unspecified evidence or granting broader scope.

This review uses the supplied documents. The underlying stage 0/5 criteria and audit artifacts were not supplied, so their thresholds and applicability cannot be independently verified.

## Critical

### 1. Justifications are names, not verifiable exemptions

**Location:** `justifications`, `kinds.*`

The policy lists four justification names but supplies none of their required predicates or evidence schemas. A certificate could therefore claim `identity-keyed`, `prospective-only`, `derived-inherits`, or `not-extracted` without establishing the corresponding property.

The mapping alternatives are also structurally ambiguous: `"or": "identity-keyed"` and `"or": "derived-inherits"` do not distinguish a test from a justification.

**Concrete fix:** Define a closed, executable alternative structure and a verifier-checkable definition for every justification:

- **`identity-keyed`:** exact symbol equality against a pinned venue-rules artifact, restricted to that artifact’s entity and time scope.
- **`prospective-only`:** authenticated fetchedAt for every revision and a checked rule bounded below by that field.
- **`derived-inherits`:** separate preservation checks for each category; exact upstream certificates and lineage; no new acquisition; inherited terms restrictions; unchanged entity assignment where mapping is inherited; revision and deletion propagation.
- **`not-extracted`:** pinned implementation with no model call, including its execution dependencies.

**Basis:** `CERTIFICATES.md` §2.

### 2. Passing `live-first-seen` does not establish the availability granted

**Location:** `tests.live-first-seen`

Several gaps permit premature or unsupported historical use:

- `"the source's tolerance"` has no defined value, units, provenance, or scope.
- First-seen time may exceed rule time by that tolerance, but nothing requires the pinned rule itself to express the resulting availability bound. A passing test could authorize use before the recorder observed the value.
- “Claimed times count only where protocol-enforced or server-set” names a requirement without defining how it is proved.
- A successful 24-hour window has no specified relationship to the entities, columns, or historical intervals granted.
- Only observations first seen in the window are sampled. Missing observations and changed versions are not clearly accounted for.
- Independent witnesses have no deterministic selection or enforcement procedure.

**Concrete fix:** Pin the admissible timing basis and its supporting evidence per entity, column, and event-time interval. Define numeric timing parameters and clock-error treatment. Recompute first-seen times from authenticated raw responses, and verify that every granted row is supported by the **unchanged pinned rule** and every selected witness. Unsupported rows must be outside scope; prospective use requires an appropriate declaration/rule, not a certificate-side override.

**Basis:** `CERTIFICATES.md` §3; `RULES.md` §6.

### 3. A later re-fetch cannot establish historical vintages

**Location:** `tests.refetch-compare`, history availability path

Two matching snapshots taken 24 hours apart do not show what was available before either fetch. A backfilled history may already contain revisions. The draft could certify that history retroactively without recoverable past versions or contemporaneous recording.

The supplied criteria explicitly say that a source without recoverable past versions is usable only from its certified recording start.

**Concrete fix:** Require evidence of the vintage available at each historical availability claim: recoverable upstream versions or authenticated contemporaneous records, with their scope pinned. Where that evidence is absent, reject historical grants and allow only prospective scope under a suitable pinned rule. Do not treat “unchanged across two fetches” as historical-vintage evidence.

**Basis:** supplied `stage7-criteria.md`, C8.2 Inputs; `CERTIFICATES.md` §3.

### 4. Migrated feeds have citations, not preserved certification rules

**Location:** `migrated`

Criterion IDs and mutable-looking directories do not preserve the frozen thresholds, applicability decisions, dated amendments, and limitations required by `CERTIFICATES.md` §2. Nor does the policy specify how migration entries interact with the generic tests: replacement, supplementation, or exemption.

There is no category-by-category bridge:

| Feeds | Unresolved certification obligations |
|---|---|
| `hl-funding`, `hl-bars-4h` | Show exactly which cited criteria establish each category and each applicable field/role. The IDs alone establish nothing. |
| `discourse-sightings`, `snapshot-sightings` | Show how the cited criteria cover terms, availability, revisions, mapping applicability, and coverage for evidence-keyed records. |
| `discourse-polls`, `snapshot-polls` | Same obligations; omission of C5.2 needs an explicit applicability decision, not an implicit mapping exemption. |
| `forum-events`, `governance-events` | Show that C5.4/C5.5 establish the derived categories, including upstream closure, coverage, and valid inheritance—not merely transformation behavior. |

**Concrete fix:** Add an immutable, hashed migration annex containing the exact criteria and amendments, per-category decisions, thresholds, evidence identities, limitations, and permitted grants. Pin the declarations, transformations, dependencies, mappings, coverage conventions, and bindings required by `SOURCES.md` §9. Uncovered categories must require additional evidence or reject issuance.

**Basis:** `CERTIFICATES.md` §2; `SOURCES.md` §9; C7.4.

## High

### 5. Evidence inputs are not evidence schemas

**Location:** every test’s `evidence`

Lists such as `"poll logs"`, `"labels"`, and `"store manifest"` do not define required fields, types, identities, completeness checks, authentication, or rejection conditions. Even the explicitly “authenticated” tests leave authentication undefined.

A digest proves that supplied bytes did not change; it does not prove that recorder times are genuine or that omitted responses never existed.

**Concrete fix:** Reference versioned, machine-readable schemas and verifier procedures for every input. Define recorder authentication, response-to-revision linkage, timestamp provenance, label records, lineage identities, completeness reconciliation, and failure behavior. Require the hashed bundle and complete data manifest specified in §4.

**Basis:** `CERTIFICATES.md` §§2–4.

### 6. Samples and windows can be selected after observing favorable results

**Location:** `live-first-seen.window`, `refetch-compare.window`, `blind-labels.sample`, all `"certified scope"` windows

A “frozen seed” can be frozen after trying many seeds. An unspecified continuous day can be selected after inspecting many days. The certified scope can likewise exclude difficult entities or intervals after testing.

The draft also omits the required commitments before return-conditioned evaluation or selection.

**Concrete fix:** Define and pin, before the relevant outcomes are inspected:

- Population manifest, scope, window start/end, and cutoff.
- Sampling algorithm, ordering, seed derivation, replacement rules, and exclusions.
- Treatment of failed attempts, interrupted recordings, and retests.
- Declaration, feed specification, thresholds, and applicability commitments before any return-conditioned selection.

Record commitment identities and chronology in the certificate; reject missing or contradictory provenance.

**Basis:** `CERTIFICATES.md` §2.

### 7. `gaps` does not establish event coverage or trustworthy zero counts

**Location:** `tests.gaps`

“Coverage intervals stored as data” is not a passing predicate. An arbitrary coverage artifact could claim completeness without evidence. Event cadence provides no fixed number of expected events, so the missing-share denominator is undefined.

The test also does not establish that:

- Every zero-count window had positive coverage and mapping evidence.
- Those facts were available by the derived row’s knownAt.
- A later poll legitimately establishes an earlier window.
- Derived coverage was independently recomputed.

For held cadence, the policy leaves slot boundaries, nulls, tombstones, polling failures, and gap measurement unspecified. A blanket 1%/24-hour threshold is not demonstrated to preserve each migrated feed’s frozen requirements.

**Concrete fix:** Split coverage by cadence and acquisition type. Define exact expected-slot construction and gap arithmetic for held feeds. For event feeds, define a completeness predicate from authenticated polls and the pinned acquisition/transformation semantics. Recompute derived coverage and require timely, nonempty coverage-and-mapping lineage for zeros.

**Basis:** `CERTIFICATES.md` §§2–3; `SOURCES.md` §§4–5.

### 8. Evidence declarations have no applicable mapping or coverage test

**Location:** generic kind matrix; migrated sightings and polls

`SOURCES.md` explicitly permits evidence declarations keyed by forum host or Snapshot space, with empty fields and `cadence.evidence`.

Neither mapping alternative works as written:

- `identity-keyed` requires coin symbols.
- `blind-labels` assumes entity mapping on mapped records, without defining a task for evidence keys.

Likewise, `gaps` assumes per-entity expected observations against a cadence that evidence declarations do not have.

This is an **effective category hole**, despite the matrix containing entries.

**Concrete fix:** Add explicit evidence-declaration applicability branches. Define key-integrity and acquisition-completeness tests for their actual key domain, or narrowly defined, checkable applicability justifications. Do not silently treat host/space keys as coin identities or bypass these categories.

**Basis:** `SOURCES.md` §1, Evidence declarations; `CERTIFICATES.md` §2.

### 9. The revision comparison can omit the changes that matter

**Location:** `tests.refetch-compare`

The required comparison is later history against what was **recorded live**. The draft instead accepts two fetches, without specifying that the first is a live record.

“Per key” and “same observed values” also leave additions, deletions, tombstones, complete-fetch boundaries, and non-DSL stored columns ambiguous. The statement that the resolver hides changes until fetch is asserted, not verified.

**Concrete fix:** Require an authenticated live baseline and later complete re-fetch over a pinned domain. Reconcile the union of keys, additions, deletions, tombstones, and all observed columns using `RULES.md` §6 comparison semantics. Verify the resulting revision manifest and effective knownAt behavior.

**Changes need not fail certification:** “reported, not judged” can be valid if differences are exhaustively accounted for and their visibility is correctly bounded.

**Basis:** `CERTIFICATES.md` §3; `RULES.md` §6.

### 10. Mapping precision is underspecified and may measure the wrong population

**Location:** `tests.blind-labels`

The policy does not define:

- Sampling unit: raw record, distinct assignment, entity, or contextual assignment.
- What constitutes a correct label, and how disagreements or unknowns count.
- What evidence establishes blinding and labeler independence.
- Whether recall is required by the frozen criteria.
- How mappings’ entity/time scope and point-in-time availability are checked.

Record-level precision can be dominated by repeated easy records while a consequential assignment remains wrong. A minimum of 50 also leaves small populations without an explicit rule.

Finally, the supplied files do not establish that stage 5 froze a universal precision threshold of 0.8.

**Concrete fix:** Pin the labeling task, population, deterministic sampling procedure, scoring, independence evidence, and scoped mapping artifact. Preserve recall requirements wherever frozen. Define small-population behavior explicitly. For contextual scalar assignments, verify applicability, scope, and availability without implicit entity conversion.

**Basis:** `CERTIFICATES.md` §§2–3; `SOURCES.md` §2; C7.5 Supported subset.

### 11. Terms evidence can cover observed requests but miss permitted acquisition paths

**Location:** `tests.terms-record`

The predicate mentions every host/path prefix in the feed specification, but the sample is only fetched URLs in poll logs. A permitted endpoint never exercised during the evidence window could therefore escape inspection.

The evidence list also omits the certified terms records themselves and their exact identities. For derived feeds, the undefined inheritance justification does not establish that upstream restrictions are carried forward.

**Concrete fix:** Verify both the complete acquisition surface of the pinned specification/implementation and every actual request, including redirects and pagination. Reread and identify the exact certified `venue/sources.toml` records. Define URL/path matching deterministically, reject uncovered acquisition, and explicitly propagate inherited restrictions.

**Basis:** `CERTIFICATES.md` §§2–3.

### 12. Derived lineage checks do not fully establish preservation

**Location:** `tests.lineage-bound`, derived justifications

Recomputing the transformation and resolving listed lineage is necessary, but the policy does not explicitly require that the listed lineage is the **complete read set**, including mapping, polling, and coverage facts.

It also lacks explicit checks for nonempty dependency evidence, upstream scope, valid certificate closure, deletion propagation, and unchanged entity assignment when mapping is inherited. A numerically reproducible zero is not proof of a covered aggregation window.

**Concrete fix:** Recompute with a recorded, exhaustive read set; reconcile it with declared lineage; validate upstream revisions and certificate grants at the pinned cutoff; enforce dependency delays and nonempty usable evidence; and test each inherited property separately. Changed entity assignments require mapping evidence.

**Basis:** `CERTIFICATES.md` §2; `SOURCES.md` §5; `RULES.md` §6.

### 13. Issuance-wide gates and the boundary between tested and granted scope are unspecified

**Location:** policy-wide

The policy does not identify a mandatory, versioned issuance procedure enforcing:

- Kind determination from acquisition and lineage—not a submitted label.
- Rejection of LLM-extracted sources.
- Exact grants over entity, stored column, event-time interval, and permitted-use interval.
- Coverage of role columns, availability inputs, mapping/coverage facts, and transitive dependencies.
- Required declaration, schema, unit, artifact, rule, manifest, and verifier pins.
- Rejection when evidence establishes less than the requested scope.

Without that boundary, passing a narrow test could authorize a broader dataset, and separate grants could accidentally be combined into an unsupported product.

**Concrete fix:** Pin a mandatory common verifier contract, referenced by the policy, that performs these checks before issuance. Derive grants only from the intersection of established evidence and requested scope. These requirements need not all be duplicated in `policy.json`, but they cannot remain implicit or discretionary.

**Basis:** `CERTIFICATES.md` §§2, 4–5; `SOURCES.md` §§2, 6–7.

## Freeze conditions

Freeze only after:

1. Every test and justification has deterministic acceptance semantics and a versioned evidence schema.
2. Windows, populations, thresholds, and applicability decisions have verifiable commitments.
3. Historical availability and event completeness are established—not inferred from successful snapshots or asserted coverage.
4. Migrated feeds have immutable, category-complete rules preserving their frozen limitations.
5. Unsupported declaration shapes and certification paths explicitly reject issuance.
6. A pinned common issuance contract prevents evidence from granting more scope than it proves.
