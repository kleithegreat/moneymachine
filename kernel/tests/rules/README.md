# Frozen C7.6 suites

B3 froze at 2026-11-06 20:50:51 UTC (15:50:51 EST). The contract is `kernel/RULES.md` §6–7 and
`kernel/SOURCES.md` §2; the comparison and size are C7.6's B3 revision in `audit/criteria.md`.
`audit/stage7/laws-frozen.md` records the new RULES.md hash; this freeze changes no Lean.

Review history and rulings live in `audit/decisions.md`: GPT on round 9 (`audit/stage7/b3-round9-review-gpt.md`),
fresh Claude (Opus 5.5 through the Antigravity CLI) on round 10 (`b3-round10-review-claude.md`), Gemini 4 Argon's
round 8 calibration (`b3-round8-calibration-argon.md`, which halted the first freeze), and Argon at the freeze on
round 11 (`b3-round11-review-argon.md`). The last left wording only, answered without another round under the human's
fix-and-freeze rule. The former draft's copies now live only in their frozen homes; historical paths remain in git.

`resolver_suite.py` supplies `HAND`, `stream`, `generate`, `delivered`, `classes` and `reached`;
`resolver_hand.jsonl` and `resolver_generated.jsonl` are the frozen cases. `lean_check.py` checks them against
Lean's `timeline` and `resolveAll` through `refmm resolve`. `test_suite.py` checks the generated input prefix,
coverage, size over each available participant's results, hand expectations and observation delivery.
`test_three_implementations.py` compares rule evaluation only, using the same recursive cell-kind comparison.

## Reproduce

```sh
nix develop -c bash -c 'cd reference/lean && lake build refmm'
nix develop -c python kernel/tests/rules/lean_check.py
```

All 171 hand expectations equal Lean. Of 481 generated stores, 365 resolve, 116 are invalid and 401 have a Parquet
image. They give 1,001 distinct delivered pairs (999 without the last store); every `REACHED` tag holds on at least
10 stores (fewest: raised to replaced, 68; derived bound past fetchedAt, 86). `resolveAll`'s observations equal
the timelines' delivery in every resolving case. Comparisons check cardinality: a missing case fails.
This is Lean against itself and the hand expectations; `test_suite.py` adds the production loaders, and a pass of C7.6's comparison also needs GPT's resolver.

## Slice 5

`store.as_of` is `ingest/resolve.py`'s bitemporal resolver, and `market::load` and `mm resolve` are
`kernel/mm/src/resolve.rs`. `loaders.py` writes each case's Parquet image and runs both; `test_suite.py` holds them to
Lean's result and observations on every case with an image (546 of the 652 cases). `ingest/knownat.resolve` and
`rule.rs::resolve`/`effective` are gone. `gpt_resolver.py` is GPT's independent resolver, written
in one sealed reply from RULES.md and SOURCES.md alone, never this suite; `test_suite.py` holds it to Lean on every
case. C7.6 also names GPT's resolver in the structural holdout review and the Parquet-as-cells test (named test 2). Invalid-registry admission
refusals stay in `reference/admission_differential.py`.

Type census of the store as written, by schema only (integrity inspection, no values; the advisor's prior inspection,
not repeated for this freeze): `data/store` holds only Double, Int64 and LargeUtf8 columns and no `tombstone` column,
and `Store.write` writes `upstream` as LargeUtf8 (checked on a synthetic write). Every type it holds is inside
SOURCES.md §2's mapping.
