# B3 draft: the C7.6 resolver suite, revised (not frozen)

Against B2's frozen definitions (`laws-frozen.md`, `7997257`), per `rust-port-plan.md` §3 B3, with the rulings of the
decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) ("B3's draft suite is not frozen") and 05:55 UTC (00:55 EST)
("B3's fixes are not frozen; second round ruled on", `audit/decisions.md`) applied, and the third to seventh rounds'
reviews (`b3-round{3,4,5,6,7}-review-{gpt,claude}.md`) answered under the advisor's rulings (decisions of 2026-11-04
10:20 UTC (05:20 EST), 10:57 UTC (05:57 EST), 11:23 UTC (06:23 EST), 12:03 UTC (07:03 EST) and 12:38 UTC (07:38 EST)). Nothing frozen, and nothing in
`audit/criteria.md` changed. Beside this directory, rounds four to eight changed three things now: SOURCES.md §1 reserves the store's metadata column names, which
`mm`'s `source::declaration` refuses (`kernel/mm/tests/sources.rs`) and `refmm resolve` returns as `E_DECL`; C7.6's
test 3 is non-interference (one outcome across stores differing only outside the holdout rows' event times), and its
three strict xfails on `ingest/store.py` name `audit/stage7/holdout-staging.md`; and
`refmm resolve` reads its cases by the exact-integer reader.

- `rules-revision.md`: RULES.md's dated revision of §6, the case format for §7 and SOURCES.md §2's Parquet mapping, the
  whole contract for an implementer.
- `c76-revision.md`: C7.6's dated revision, committed alone before the suite's freeze.
- `resolver_suite.py`: the hand cases, the generator and its coverage tags; `resolver_hand.jsonl` (160 cases) and
  `resolver_generated.jsonl` (481 stores, seed 20261102) are what it gives (`HAND`, and `generate` over Lean's results).
- `lean_check.py`: the suite against Lean's `timeline` and `resolveAll` through `refmm resolve`
  (`reference/lean/Main.lean`), whose decoding layer is new code reading the case texts by §7's mapping.

## The freeze, after review

1. C7.6's revision into `audit/criteria.md`, alone (`criteria:` commit). RULES.md's and SOURCES.md's revisions and
   `laws-frozen.md`'s new RULES.md hash follow, with no Lean change.
2. `kernel/tests/rules/resolver_suite.py` and its two files replaced, alone, with `lean_check.py` beside them. In
   `test_suite.py`, the generated file is checked as a prefix of `stream()`, and C7.6's size (`delivered`) is counted
   over each participant's results, with `generate`'s `classes` floor and `lean_check.py`'s: every hand case equal to Lean's result, every `REACHED` tag on at
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
`nix develop -c python audit/stage7/b3-draft/lean_check.py`. It reports: both files equal `HAND` and `generate`'s
stores, compared as §7 compares results; all 160 hand expectations equal Lean's results; of the 481 generated stores,
365 resolve and 116 are invalid, and 401 have a Parquet image, with 1,001 distinct delivered pairs as C7.6 counts them
(at least 1,000; 999 without the last store); every `REACHED` tag holds on at least 10 stores (the fewest: raised to
replaced, 68; derived bound past fetchedAt, 86); `resolveAll`'s observations equal the delivery of the hand case's expected timelines, or a generated
store's Lean timelines, in every case that resolves. Every comparison checks its cardinality, so a missing case
fails. This is Lean against itself and the hand expectations, not the actual loaders, which join it in slice 5.

Type census of the store as written, by schema only (integrity inspection, no values; the advisor's, on this PC's
`data/`, which the cloud session lacks): `data/store` holds only Double, Int64 and LargeUtf8 columns and no
`tombstone` column, and `Store.write` writes `upstream` as LargeUtf8 (checked here on a synthetic write). Every type it
holds is inside SOURCES.md §2's mapping.

Self-check by the previous round's author, not reproducible and not evidence: a throwaway transcription of the text,
kept outside the repository, mutated into 34 wrong resolvers, each failing at least one hand case of that round.
