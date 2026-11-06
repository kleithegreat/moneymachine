# B3 draft: the C7.6 resolver suite, revised (not frozen)

Against B2's frozen definitions (`laws-frozen.md`, `7997257`), per `rust-port-plan.md` §3 B3. Review history and rulings:
the B3 entries in `audit/decisions.md`. Round 11 answers Argon's calibration of round 8
(`b3-round8-calibration-argon.md`) against round 10, including Claude's wording fixes at `101d5c7`.
Next: Argon's review at the freeze. Nothing frozen and no `audit/criteria.md` change.

SOURCES.md §1 distinguishes delivery slots from rule times and reserves metadata names, slots included (`mm` refuses
them; `refmm resolve` returns `E_DECL`). Test 3's decode limit is decided structurally by review, with a behavioural
net whose seven strict xfails on `ingest/store.py` name `audit/stage7/holdout-staging.md`. No Lean or frozen law changes:
`refmm resolve` already keeps event slots separate from rule times and uses the exact-integer reader.

- `rules-revision.md`: RULES.md's dated revision of §6, the case format for §7 and SOURCES.md §2's Parquet mapping, the
  whole contract for an implementer.
- `c76-revision.md`: C7.6's dated revision, committed alone before the suite's freeze.
- `resolver_suite.py`: the hand cases, the generator and its coverage tags; `resolver_hand.jsonl` (171 cases) and
  `resolver_generated.jsonl` (481 stores, seed 20261102) are what it gives (`HAND`, and `generate` over Lean's results).
- `lean_check.py`: the suite against Lean's `timeline` and `resolveAll` through `refmm resolve`
  (`reference/lean/Main.lean`), whose decoding layer is new code reading the case texts by §7's mapping.

## The freeze, after review

1. Read `date -u` and date C7.6's and RULES.md's revisions at that freeze time, paired with Eastern (UTC-5).
   C7.6's revision into `audit/criteria.md`, alone (`criteria:` commit, timestamped at that time). RULES.md's and SOURCES.md's revisions and
   `laws-frozen.md`'s new RULES.md hash follow, with no Lean change.
2. `kernel/tests/rules/resolver_suite.py` and its two files replaced, alone, with `lean_check.py` beside them. In
   `test_suite.py`, the generated file is checked as a prefix of `stream()`, and C7.6's size (`delivered`) is counted
   over each participant's results, with `generate`'s `classes` floor and `lean_check.py`'s: every hand case equal to Lean's result, every `REACHED` tag on at
   least `FLOOR` stores of Lean's results, `resolveAll`'s observations equal to its timeline's delivery. The old
   suite's resolver path leaves `test_three_implementations.py` in the same commit, or it fails; `test_b3_draft.py` moves
   to the installed suite with it. Its shallow `same`
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
stores, compared as §7 compares results; all 171 hand expectations equal Lean's results; of the 481 generated stores,
365 resolve and 116 are invalid, and 401 have a Parquet image, with 1,001 distinct delivered pairs as C7.6 counts them
(at least 1,000; 999 without the last store); every `REACHED` tag holds on at least 10 stores (the fewest: raised to
replaced, 68; derived bound past fetchedAt, 86); `resolveAll`'s observations equal the delivery of the hand case's expected timelines, or a generated
store's Lean timelines, in every case that resolves. Every comparison checks its cardinality, so a missing case
fails. This is Lean against itself and the hand expectations, not the actual loaders, which join it in slice 5.

Type census of the store as written, by schema only (integrity inspection, no values; the advisor's, on this PC's
`data/`, which the cloud session lacks): `data/store` holds only Double, Int64 and LargeUtf8 columns and no
`tombstone` column, and `Store.write` writes `upstream` as LargeUtf8 (checked here on a synthetic write). Every type it
holds is inside SOURCES.md §2's mapping.
