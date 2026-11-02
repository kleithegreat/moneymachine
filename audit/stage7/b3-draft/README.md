# B3 draft: the C7.6 resolver suite, revised (not frozen)

Against B2's frozen definitions (`laws-frozen.md`, `7997257`), per `rust-port-plan.md` §3 B3, with the rulings of the
decision of 2026-11-02 01:32 UTC ("B3's draft suite is not frozen", `audit/decisions.md`) on
`b3-review-{gpt,claude}.md` applied. Nothing frozen, and nothing under `kernel/` or in `audit/criteria.md` changed.

- `rules-revision.md`: RULES.md's dated revision of §6 and the case format for §7, the whole contract for an
  implementer.
- `c76-revision.md`: C7.6's dated revision, committed alone before the suite's freeze.
- `resolver_suite.py`: the hand cases, the generator and its coverage floors; `resolver_hand.jsonl` (130 cases) and
  `resolver_generated.jsonl` (117 stores, 3,012 (key, query) pairs from those that resolve, 1,252 on keys of at least
  two eligible revisions; seed 20261102) are what it gives (`HAND`, `generate()`).

## The freeze, after review

1. C7.6's revision into `audit/criteria.md`, alone (`criteria:` commit). RULES.md's revision and `laws-frozen.md`'s new
   hash follow, with no Lean change.
2. `kernel/tests/rules/resolver_suite.py` and its two files replaced, alone. In `test_suite.py`, the size check becomes
   `pairs` over the generated stores (at least 1,000 and 200), with `generate`'s `classes` floor, plus `reached`'s floor
   over Lean's results once `refmm`'s resolver mode exists. The old suite's resolver path leaves
   `test_three_implementations.py` in the same commit, or it fails; its shallow `same` (nested `true` equal to `1`) is
   replaced by a deep comparison that tells an integer from a non-integer.
3. `ingest/knownat.resolve`, `gpt_resolver.py` and `rule.rs::resolve`/`effective` die in slice 5 with their callers.
   GPT writes its new resolver from RULES.md, SOURCES.md and §7 alone, never from this directory. `refmm`'s resolver
   mode decodes the case texts itself, with `Ref/Json.lean`.

**Not in this format,** the loader-level tests C7.6's revision names: holdout staging, evidence and outside-U keys never
delivered, one entity on two coins. Admission's refusals of an invalid registry stay in
`reference/admission_differential.py`.

## Self-check (by the suite's author, not independent)

Every hand expectation was computed by hand from `rules-revision.md`, then compared with a throwaway transcription of it
kept outside the repository: 130 of 130 agree. Its results on the generated stores: 92 resolve, 25 invalid, and every
`REACHED` class has at least 10 stores (the bound past a later derived revision's fetchedAt: 30).

The same transcription, mutated into 34 wrong resolvers, among them every timeline bug the two reviews say the previous
draft would pass (no raise to the replaced knownAt, the bound on first revisions only, upstream clamped to fetchedAt, the
event time as slot, a retraction's own slot, role payloads not decoded, the final revision's values on every entry,
evidence keys by spelling, declaration order as dependency order): each fails at least one hand case. The reviews' other
two, delivering evidence and a late holdout check, are the loader-level tests above. This transcription is one reading of
the text, not Lean: the Lean comparison comes with `refmm`'s resolver mode (slice 5).
