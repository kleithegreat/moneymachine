# B3 draft: the C7.6 resolver suite, revised (not frozen)

Against B2's frozen definitions (`laws-frozen.md`, `7997257`), per `rust-port-plan.md` §3 B3, with the rulings of the
decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) ("B3's draft suite is not frozen") and 05:55 UTC (00:55 EST)
("B3's fixes are not frozen; second round ruled on", `audit/decisions.md`) applied. Nothing frozen, and nothing under
`kernel/` or in `audit/criteria.md` changed.

- `rules-revision.md`: RULES.md's dated revision of §6, the case format for §7 and SOURCES.md §2's Parquet mapping, the
  whole contract for an implementer.
- `c76-revision.md`: C7.6's dated revision, committed alone before the suite's freeze.
- `resolver_suite.py`: the hand cases, the generator and its coverage tags; `resolver_hand.jsonl` (134 cases) and
  `resolver_generated.jsonl` (119 stores, seed 20261102) are what it gives (`HAND`, `generate()`).
- `lean_check.py`: the suite against Lean's `timeline` and `resolveAll` through `refmm resolve`
  (`reference/lean/Main.lean`), whose decoding layer is new code reading the case texts by §7's mapping.

## The freeze, after review

1. C7.6's revision into `audit/criteria.md`, alone (`criteria:` commit). RULES.md's and SOURCES.md's revisions and
   `laws-frozen.md`'s new RULES.md hash follow, with no Lean change.
2. `kernel/tests/rules/resolver_suite.py` and its two files replaced, alone, with `lean_check.py` beside them. In
   `test_suite.py`, the size check becomes `pairs` over the generated stores (at least 1,000 and 200), with
   `generate`'s `classes` floor and `lean_check.py`'s: every hand case equal to Lean's result, every `REACHED` tag on at
   least `FLOOR` stores of Lean's results, `resolveAll`'s observations equal to its timeline's delivery. The old
   suite's resolver path leaves `test_three_implementations.py` in the same commit, or it fails; its shallow `same`
   (nested `true` equal to `1`) is replaced by `lean_check.same`, which tells an integer from a non-integer.
3. In slice 5: `store.as_of` is replaced by its bitemporal version in `ingest/store.py`, its callers
   (`ingest/backfill.py`, `ingest/witness.py`) moved with it; that is the Python participant. `ingest/knownat.resolve`,
   `gpt_resolver.py` and `rule.rs::resolve`/`effective` die with their callers. GPT writes its new resolver from
   RULES.md, SOURCES.md and §7 alone, never from this directory. C7.6's revision names the loader-level tests these
   cases cannot show: the loaders' observations against `resolveAll`, the Parquet mapping, holdout staging, evidence
   and outside-U keys never delivered, one entity on two coins. Admission's refusals of an invalid registry stay in
   `reference/admission_differential.py`.

## Checks

Reproducible, on this commit: `nix develop -c bash -c 'cd reference/lean && lake build refmm'`, then
`nix develop -c python audit/stage7/b3-draft/lean_check.py`. It reports: all 134 hand expectations equal Lean's
results; of the 119 generated stores (3,020 (key, query) pairs, 1,332 on keys of at least two eligible revisions), 90
resolve and 29 are invalid; every `REACHED` tag holds on at least 10 stores (the fewest: raised to replaced, 12;
retraction keeps slot, 19; derived bound past fetchedAt, 22); `resolveAll`'s observations equal the delivery of its own
timelines in every case that resolves. This is Lean against itself and the hand expectations, not the actual loaders,
which join it in slice 5.

Self-check by the previous round's author, not reproducible and not evidence: a throwaway transcription of the text,
kept outside the repository, mutated into 34 wrong resolvers, each failing at least one hand case of that round.
