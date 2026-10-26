# Certificates, version 1

A feed binds to a declaration (`SOURCES.md`) only with a certificate, and only the certification **verifier**
(`mm certify`) issues one. Whoever builds a feed, an agent included, may submit evidence; the verifier recomputes and
decides. This document specifies the frozen policy the verifier applies, the evidence it reads, what a certificate
grants and pins, and its lifecycle. A certificate authorizes use of data; it never authorizes access to a holdout,
which is a separate check (SOURCES.md §7).

## 1. Authority

A certificate is a record of the ledger's append-only `certificates` table, written only by the verifier command in
the same transaction as its decision, and identified by the SHA-256 of its canonical payload. Agents have no path to
that command (the sandbox). A certificate file, a ledger row of another table or a submitted "pass" is never
authority. Issuance, binding and run admission take effect only once committed; a failure to verify or commit emits no
success and no result-bearing output.

## 2. The policy

`sources/policy.json` is frozen: it changes only by a dated criteria revision, and every certificate pins its hash. It
is executable data, not prose: for each source kind, each of paper §5's six categories maps to a test or to a
permitted justification kind, and each test has its exact metric or predicate, threshold, deterministic sample
procedure, minimum sample, evidence window and evidence schema. A category without an entry rejects issuance.

| Kind | Terms | Availability | Revisions | Entity mapping | Coverage | Extractor |
|---|---|---|---|---|---|---|
| `history` (a backfilled API history) | test | test | test | test, or `identity-keyed` | test | `not-extracted` |
| `recorded` (our own live recording) | test | test | `prospective-only` | test, or `identity-keyed` | test | `not-extracted` |
| `derived` (a transformation of certified sources) | `derived-inherits` | test | `derived-inherits` | test, or `derived-inherits` | test (recomputed) | `not-extracted` |

The verifier determines the kind from the acquisition and lineage evidence, never from a submitted label. LLM-extracted
sources are outside version 1 and rejected. A justification counts only if the verifier can check it:
- `identity-keyed`: every entity key is a coin symbol of the pinned venue-rules artifact, the same string, within that
  artifact's applicable entity and time scope;
- `prospective-only`: every certified revision's effective knownAt is at least its authenticated fetchedAt (the rule
  is `{"field": "fetchedAt"}` or bounded below by it), so no row is usable before we observed it;
- `derived-inherits`: for that one test, the verifier establishes from the pinned transformation and the exact upstream
  certificates and lineage that the property is preserved: no new acquisition (no new hosts, so no new terms), the
  upstream terms' restrictions carried, the same entity assignment, and revisions, deletions and availability
  propagated. A transformation that changes entity assignment needs mapping evidence of its own;
- `not-extracted`: the transformation is pinned code with no model call.

A migrated feed's policy entries keep the thresholds, applicability decisions, dated amendments and limitations its
stage 0 or stage 5 criteria froze, cited by immutable reference; those limitations bound its scope. For a new feed,
the declaration, feed specification, thresholds and applicability decisions are committed before any return-conditioned
evaluation or selection involving it (choosing a mapping, keywords, a lag or a coverage window by its correlation with
returns counts); the certificate records those commitments, and issuance rejects missing or contradictory provenance.

## 3. Tests

- **Terms:** every host the feed fetches has a certified record in `venue/sources.toml`, reread by the verifier.
- **Availability:** the permitted availability basis for every certified row. A rule reading a feed-claimed time is
  permitted only within the entities, columns and event-time interval for which that time is protocol-enforced or
  server-set and the live test passed (observations' first-seen times, recomputed by the verifier from authenticated
  raw poll logs, against the rule's knownAt). The effective knownAt also respects every independent witness the policy
  selects for the row, deterministically. Rows without such a basis are usable only prospectively. These bounds are
  expressed by the declaration's pinned rule under the frozen resolver: a certificate never overrides the rule, applies
  another rule to some rows, or makes a rejected row usable; rows needing a different basis are outside its scope.
- **Revisions:** a later re-fetch of the certified history compared with what was recorded live, recomputed.
- **Entity mapping:** precision (and recall where frozen) on blind-labelled samples, recomputed from the labels, with
  each labeler's independence recorded.
- **Coverage:** gap intervals per coin, recomputed from the stored rows and poll logs.
- `fetchedAt` and witness times count only with authenticated recorder evidence; a producer's timestamp value alone is
  never evidence of when we observed something.

## 4. The evidence bundle and the data manifest

A bundle is a directory whose `manifest.json` lists every file with its SHA-256: the declaration version, the feed
specification, the producer and transformation implementations (by hash), the mapping and coverage artifacts, the
upstream certificates, and per test its inputs. The **data manifest** identifies the immutable snapshot completely: every
revision, tombstone, poll log, lineage record and schema record of the dataset at its cutoff. The verifier rejects a
bundle whose files do not match, or a data manifest it can show incomplete.

## 5. What a certificate grants and pins

**Grants.** The certified scope is an explicit set of grants, each over an entity, a stored column, an event-time
interval and a permitted-use interval, intervals half-open [start, end) in integer ms; the dataset cutoff is pinned
separately. Separate grants never combine into a product. Scope covers DSL-visible fields, role columns, availability
inputs and the mapping and coverage facts used to produce or select observations. Every access (initialization,
warm-up, window history and held values included) must fall within a grant: a value delivered earlier is not usable
after its permitted-use interval ends. Access outside scope is `R_UNCERTIFIED`, never undefined data and never a silent
drop.

**Pins.** The declaration version and its file's SHA-256, the rule language version and the exact rule bytes; the feed
specification and the data manifest's hash, and the cutoff; producer and transformation hashes; mapping and coverage
artifacts; the revision policy and the upstream certificates' ids; the evidence hashes, the policy hash and the
verifier's version.

## 6. Lifecycle

- A certificate's id is the hash of its canonical payload. Bindings and runs reference exact ids, never "latest".
- **Supersession** is an explicit, append-only record naming the certificate ids it supersedes, effective at its
  ledger position; it supersedes each in full (no partial supersession in version 1). A later issuance supersedes
  nothing by itself.
- **Admission** of a new run checks, at one ledger position, that every certificate in its transitive closure is
  valid: a superseded upstream blocks every dependent until a replacement establishes a valid closure.
- Earlier experiments keep their ids and artifacts, and stay reproducible. Reproducing one never evaluates another
  strategy, widens data access or releases new results under a superseded certificate.
- A change to anything pinned, or use beyond the granted scope, needs a new certificate.
