# Review of the stage 7 hunt fixes, second pass (89fd44f)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review (C7.7) from a clean worktree (no `data/`), at `89fd44f`; started 2026-11-04 11:06 UTC (06:06 EST), reply received 11:11 UTC (06:11 EST). The reply as given, tool transcript omitted.

## Findings

**No findings affecting a C7.x outcome.** Findings 1–3 of the previous fixes review are resolved.

## Revision legitimacy

`audit/stage7/laws-frozen.md:212–236` legitimately strengthens admission; no frozen threshold is loosened:

- Every declaration, including unused ones, may provide at most one role.
- Bars providers must have held cadence.
- Every field sharing a unit-bearing role column’s stored column must have that role column’s dimension. Integer `trades` has no imposed dimension.
- Rust additionally requires bars’ period **14,400,000**, phase **0**, and slot **`eventTime`**.

Law statements are textually unchanged, but their `Registry.Valid`/`CheckerAccepted` hypotheses are stronger. Remaining admitted declarations retain their guarantees; previously invalidly accepted contracts are refused rather than silently reinterpreted. The recorded hashes match. Independent review/freeze and subsequent proof revalidation remain necessary before counting the affected proofs toward **C7.7**, as the revision acknowledges.

## Cause-level fixes

- **Dual-role payload loss:** `kernel/mm/src/source.rs:211–212` and `reference/lean/Ref/Source.lean:134` consistently enforce SOURCES.md §1’s single-role contract. This removes the ambiguous declarations at admission; `rolePayload` need not choose according to the run.
- **Wrong grid/timestamp:** `kernel/mm/src/source.rs:214–215` requires `eventTime`, not merely any declared time column. Certification’s §4 slot-grid check therefore applies to the timestamp execution uses under §6.
- **Lean/Rust contract disagreement:** `reference/lean/Ref/Source.lean:135–136` now enforces the modeled cadence and dimension requirements consistently with Rust’s parser. The numeric grid remains explicitly outside Lean’s declaration abstraction.

## Differential and regression evidence

I reproduced `lake build`, all five Rust source tests, both hunt regressions, and **zero disagreements on 5,000 cases each for seeds 1, 2 and 3**. Position-zero refusals were **942/930/969**; cases reaching resolution were **524/484/469**, matching the revision.

The differential is sound **for its stated generated subset**: Rust parses declaration text independently; Lean now receives the fields and validates them (`reference/lean/Main.lean:106–114`). Both-role, event-bars and wrong-unit refusal cases remain in the comparison, including isolated examples—not filtered away. Substituting the previous `Registry.valid` produced the claimed **485 disagreements on seed 1**.

This establishes development agreement through declaration validation and admission positions 1–5, not successful resolution, execution, certification, numeric-grid agreement, or a judged C7.7 corpus pass.

The regressions discriminate against the relevant old code:

- Original dual-role cases produce `"true 1 0"` and `"true 0 1"`.
- The original Rust parser accepts the rejected period, phase, slot, role-count and unit mutations; the first-pass parser still accepts the wrong-slot mutation.
- **Three negative Lean examples fail the previous predicate; two positive controls pass both.** Consequently, `audit/stage7/laws-frozen.md:222` overstates matters when saying all five examples fail previously. This is a non-blocking evidence-description error, not a changed C7.x outcome.

**merge**
