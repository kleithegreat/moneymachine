# B3 draft: the C7.6 resolver suite, revised (not frozen)

Drafted 2026-11-02 on `stage7` against B2's frozen definitions (`laws-frozen.md`, `7997257`; `b2-revision.md`), per
`rust-port-plan.md` §3 B3. `resolver_suite.py` states the case format and holds the hand cases and the generator;
`resolver_hand.jsonl` (60 cases) and `resolver_generated.jsonl` (76 stores, 1,172 (key, query) pairs, seed 20261102)
are what it gives (`HAND`, `generate()`). Nothing frozen and nothing under `kernel/` changed. Once reviewed, it is
committed alone, replacing `kernel/tests/rules/resolver_suite.py` and its two files (below).

## What changes from version 1's suite

- **A case is a store**, not one key: several sources with their declarations reduced to what resolution reads,
  revisions with stored cells and lineage, a version and queries. The result is every key's timeline (fetchedAt,
  knownAt, retraction, slot) and, per query, the delivery visible then, which is Lean's `timeline` and its visibility
  (RULES.md §6, bitemporal revisions). Version 1 selected one revision before the availability filter.
- **Evidence keys and keys outside U are in the result.** Lean's `resolveAll` delivers neither, but their timelines
  decide every derived row, so `refmm`'s resolver mode prints `timeline` for each key, not only `resolveAll`.
- **Rejection codes are gone from the result.** A rejected evaluation is nothing (first revision) or a retraction
  (later), as Lean's `Entry` carries no code. The rule language's codes stay covered by the frozen rule suite
  (`kernel/tests/rules/suite.py`).
- **Hand cases of `b2-revision.md` §8**: a covered zero count with polls-only lineage, usable at the poll's knownAt plus
  the lag; a lineage key of a source outside its dependency; a key with no delivery recorded by the derived revision,
  alone and beside a good key (no masking); a later upstream correction leaving the earlier derived row unmoved while
  bounding its recomputation; and a retraction recorded by the derived revision bounding it (B2's fix).
- **Also by hand:** `b2-revision.md` §7's N-1 (an identical recomputation with a usable lineage after an unusable first
  revision adds nothing, so the key is never delivered), two dependencies each bounded by its own lag, a derived source
  over a derived one, and repeats of a tombstone or a rejected revision adding nothing.
- **F-1** (`b2-fixes-review-claude.md`): a lineage naming a dependency twice makes the dataset invalid, with its hand
  case; so does a malformed lineage key.
- **F-2**, both directions: a key's entity is decoded from its entity columns' values, never given separately, so one
  tuple is one key (an escaped string and permuted members change nothing) and two tuples two keys (`("ab","c")`
  against `("a","bc")`, the id `1` against `"1"`), directly and as lineage keys.

## Open points for the review

1. **The named response to stored bytes that do not decode is not yet in the spec.** The suite says "dataset invalid"
   for malformed `cells` or `upstream`, a column or a lineage's dependency named twice, a reserved column, and a
   lineage key of the wrong shape, among eligible revisions. Lean only assumes these away (`Trusted.canonical`). This
   wants one dated sentence in RULES.md §6 (or SOURCES.md §5), reviewed with the suite; F-1 asked for exactly this.
   Version 1 instead gave `R_ROW` per revision: the suite drops that.
2. **C7.6's frozen criterion still describes version 1.** Its resolver bullet reads "the latest revision chosen before
   the availability filter, with no fallback to an older revision"; under the human's bitemporal decision of
   2026-10-26 an earlier value stays visible until a correction's knownAt, and "no fallback" survives only for
   retractions. RULES.md's revision says the suites are revised "to match", but `audit/criteria.md` carries no dated
   revision of that bullet, and it also names `store.as_of` and `mm`'s loader where the plan has Python, Rust, GPT's
   resolver and Lean through `refmm`. The advisor should decide whether C7.6 needs a dated revision before this suite
   judges anything (criterion lines are never edited).
3. **Not covered**, each for a reason to confirm:
   - role payloads (a bars or settlement row that does not decode is a retraction): the suite's sources carry no roles;
     a hand case needs the role columns in the format;
   - an integer cell against a double of the same value (Lean's `.int 1` and `.num 1.0` differ; RULES.md says only
     "compared as values"): no case mixes them, and the prose should say which;
   - `validAt`'s one-coin-per-entity clause: here the coin is a lookup of the entity in `universe`, so it cannot fail;
     a mapping artifact is C7.3's;
   - an event column that is not an integer: the format excludes it; point 1's response would cover it if stated;
   - registry invalidity (empty `sources`, cycles): admission's, `reference/admission_differential.py`.
4. **The swap**, when frozen: `kernel/tests/rules/resolver_suite.py` and its two files are replaced; in `test_suite.py`,
   the size check counts (key, query) pairs; `ingest/knownat.resolve`, `gpt_resolver.py` and `mm resolve`
   (`rule.rs::resolve`, `effective`) are version 1's and die (`rust-port-plan.md` §1). GPT writes its new independent
   resolver from the spec alone (C7.6), not from this file; a fresh `test_three_implementations` case adds Lean.

## Self-check (by the suite's author, not independent)

Every hand expectation was computed by hand from RULES.md §6, then compared with a throwaway transcription of Lean's
`timeline` kept outside the repository: 60 of 60 agree, and no expectation was changed by the comparison. The same
transcription ran every generated store: 74 resolve, 2 are invalid (a shared fetchedAt within a key), and the derived
source's keys reach empty timelines, single deliveries and retractions.
