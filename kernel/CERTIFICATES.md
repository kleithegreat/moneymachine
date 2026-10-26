# Certificates, version 1

A feed binds to a declaration (`SOURCES.md`) only with a certificate, and only the certification
**verifier** issues one. Whoever builds a feed, an agent included, may submit evidence; the verifier
decides. This document specifies the evidence, the frozen policy the verifier applies, what a
certificate pins, and its lifecycle.

## The applicability policy

`sources/policy.json` is frozen: it changes only by a dated criteria revision, and a certificate pins
its hash. For each source **kind** it lists the tests that apply among paper §5's six categories, and
the justification kinds that may replace a test that does not:

| Kind | Terms | Availability | Revisions | Entity mapping | Coverage | Extractor |
|---|---|---|---|---|---|---|
| `history` (a backfilled API history) | required | required | required | required or `identity-keyed` | required | `not-extracted` |
| `recorded` (our own live recording, prospective) | required | required | `prospective-only` | required or `identity-keyed` | required | `not-extracted` |
| `derived` (a transformation of certified sources) | `derived-inherits` | required | `derived-inherits` | `derived-inherits` | required | `not-extracted` |

LLM-extracted sources are outside version 1 and rejected.

A justification is valid only if the verifier can check its kind:
- `identity-keyed`: every stored entity key is a coin symbol of the venue's own rules file, the same
  string, so there is no mapping to measure;
- `prospective-only`: the certified time scope starts no earlier than the feed's first recorded poll;
- `derived-inherits`: every dependency is bound with a valid certificate whose scope covers the
  derived scope;
- `not-extracted`: the transformation is code pinned by hash, with no model call.

## Tests

Each test in the policy has a frozen metric, predicate or threshold, sample procedure, minimum sample
and evidence window. A migrated feed's tests keep the thresholds, applicability decisions, amendments
and limitations its stage 0 or stage 5 criteria froze; the policy cites them. A test with a missing,
failed, unverifiable or empty sample is a rejection.

- **Terms:** every host the feed fetches has a certified record in `venue/sources.toml`
  (`ingest/terms.py`), which the verifier rereads.
- **Availability:** from a live recording window, the observations' first-seen times against the rule's
  knownAt, recomputed by the verifier from the raw poll logs. Feed timestamps count only where the
  claimed time is protocol-enforced or server-set and this test passed; otherwise rows are
  prospective-only.
- **Revisions:** a later re-fetch of the certified history compared with what was recorded live; the
  verifier recomputes the comparison.
- **Entity mapping:** precision (and recall where frozen) on blind-labelled samples; the bundle records
  each labeler's independence, and the verifier recomputes the figures from the labels.
- **Coverage:** gap intervals per coin, recomputed from the stored rows and poll logs.

## The evidence bundle

A directory whose `manifest.json` lists every file with its sha256, the declaration and version, the
feed specification, the dataset cutoff, the producer and transformation versions, the mapping and
coverage artifacts, the upstream certificates, and per test its inputs. The verifier rejects a bundle
whose files do not match the manifest.

## What a certificate pins

A certificate is a ledger record (`certificates` table, append-only) with:
- the declaration (name, version, file sha256) and the rule language version;
- the feed specification and data-manifest hashes, and the dataset cutoff;
- producer and transformation versions;
- mapping and coverage artifacts;
- the revision policy and the upstream certificates;
- the evidence hashes, the policy hash and the verifier's version;
- the certified scope: entities, fields and a time interval.

## Lifecycle

A change to anything pinned, or use beyond the certified scope, needs a new certificate. A newer
certificate supersedes an older one through an append-only supersession record. Earlier experiments
keep their certificate ids and stay reproducible; a new evaluation cannot use a superseded
certificate. Every run's identity records the ids of the certificates it used.
