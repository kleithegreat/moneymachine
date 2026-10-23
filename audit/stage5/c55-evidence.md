# C5.5 evidence map (2026-10-23)

Each requirement of C5.5, with the test or record that shows it. Every test named passes at the commit that adds
this file, and every mutant is caught by `python -m cli mutants` (log in PROGRESS.md).

| Requirement | Evidence |
|---|---|
| Hourly counts of items with knownAt in (τ − 1h, τ], unit `ev` | `venue/sources/derived.md` (Count); `ingest/tests/test_events.py::test_counts_are_prospective_with_the_margin`; `kernel/mm/tests/events.rs::counts_have_their_own_unit` |
| Unlock schedules | Not applicable: unlocks are a blocked category (PROGRESS.md, Blockers), so no schedule input exists and the "schedules read from the latest revision" mutant has nothing to mutate |
| `hours_since` on the tick clock | `kernel/DSL.md` (op table); `kernel/mm/tests/events.rs::hours_since_counts_ticks_since_the_condition_held` |
| DSL.md documents unit, missingness, freshness | `kernel/DSL.md` input table: `forum_posts` and `gov_proposals` are `ev`, "defined only at that hour's tick, never held, and undefined outside the source's coverage or for unmapped coins" |
| I1 (no future information) | Kernel: `counts_are_fresh_only_and_respect_known_at` (delivery before knownAt is an error) and mutant "I1 events delivered early". Derivation: `ingest/tests/test_derived.py::test_rows_never_depend_on_later_records` and mutant "C5 coverage reads a later poll" |
| I8 (holdout) | Derived rows are split at the holdout boundary by `write_split`; mutant "I8 holdout rows admitted" |
| Mutant: as_of returning latest content | "C5 as_of returns the latest content" |
| Mutant: knownAt equal to the claimed time with no lag | "C5 knownAt from the claimed time" (knownAt from the claimed creation time instead of the witness) and "C5 derivation without the availability margin" (no lag after the witness) |
| Mutant: dropped tombstones | "C5 tombstones dropped" |
| Mutant: aggregation window admitting (τ, τ + 1h] | "C5 derivation counts future items" |
| Independent implementation | `ingest/tests/derived/independent.py`, written by GPT from `derived.md` and `FORMAT.md` alone; `test_derived.py::test_independent_implementation_agrees` (2,000 cases, boundary-dense) |
| `R_INPUT_UNAVAILABLE` for an absent input | `events.rs::missing_dataset_is_input_unavailable` (both inputs); `kernel/tests/cli/test_cli.py::test_event_inputs_only_in_the_holdout_are_unbound_in_search` (search store without the dataset, through `mm eval`) |
