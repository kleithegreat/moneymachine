# Review of the stage 7 hunt fixes, second pass (89fd44f)

Date: 2026-11-04 11:18 UTC (06:18 EST). Model: Claude Opus 5.5 (fresh session, builder `review the stage 7 hunt
second pass`); it built none of this. Commit reviewed: `89fd44f` on `claude/stage7-hunt-fixes-2p-ksow7u`, on top of
`a095bab`. This is C7.7's review of the dated revision in `audit/stage7/laws-frozen.md` (2026-11-04 07:00 UTC (02:00 EST) heading)
and of `Registry.valid`, answering `2026-11-04-gpt-hunt-fixes-review.md` findings 1 to 3 for
`2026-11-04-claude-hunt-stage7.md` findings 1 and 2.

Method: reading, then reproduction in a detached worktree at `89fd44f`. Lean 4.34.0 (the pinned toolchain): `lake build`
completed with 109 jobs, and `reference/lean` contains no `sorry`, `native_decide` or `axiom`. `cargo test --test sources` in
`kernel/mm`. `python -m reference.admission_differential 5000 <seed>` for seeds 1, 2 and 3. To check what the
differential's result means, a classifier (scratch, not committed) labels each generated case by the invalidities it
contains and reruns it against this `refmm` and against a `refmm` built with `a095bab`'s `Source.lean` and this commit's
harness. To test the Lean examples, `a095bab`'s role clause was substituted into `Source.lean` and the file checked
(`lake env lean`). Afterwards every file was restored, and the hashes were checked against the revision's table. Not
run: the pytest file `reference/tests/test_hunt_stage7.py`, because this container has no pytest. That file changed only
its docstring and lost the dead `HUNT` constant.

## Findings

### 1. The revision overstates its Lean evidence: three of the five examples fail on the previous clause, not five (low)

`audit/stage7/laws-frozen.md:222` says "five `example`s by `decide +kernel` under it fail on the previous clause", and
the commit message repeats it. I substituted `a095bab`'s role clause and checked the file. Only
`reference/lean/Ref/Source.lean:146` (settlement `rate` in usd/coin), `:149` (bars `close` dimensionless) and `:150`
(event-cadence bars) fail. `:145` and `:147` are positive controls, and they hold under both clauses, as positive
controls should. The examples are sound; the sentence describing them is not.

**Outcome it could change:** none judged. It is an inaccurate evidence claim in the C7.7 revision record, which becomes
append-only once merged. Correct it before the merge, for example: "five `example`s, three of which fail on the previous
clause and two positive controls".

### 2. "Statements unchanged" does not list the laws whose closure changed, or why no coverage is lost (low)

The heading (`laws-frozen.md:212`) and body say the statements are unchanged. That holds for the text only.
`Registry.Valid` changed, so every law that assumes it now has a stronger hypothesis:

- through `CheckerAccepted` (`Source.lean:155`): `L1_values`, `L1_simulator`, `L1_decisions`, `L2_units`, `L2_checker`,
  `L4_fills` and `L4_orders`;
- directly: `L5_text` and `L8_known`.

`L5_admitted` concludes `reg.Valid`, so its conclusion is stronger. `L5_order`, `L5_staged` and `L5_shape` go through
`admission`'s `reg.valid` test (`Sim.lean:505`). C7.7 requires each law whose referenced definitions change to be
reviewed, revised if needed, and frozen before its proof. B2's revision listed these laws; this revision does not.

I checked the coverage argument, and it holds. Lean's `admit` refuses `!reg.valid` at position 0 (`Sim.lean:505`), and
`L5_admitted` proves that every run producing output has a valid registry. Each new conjunct is also implied by `mm`'s
parser (`kernel/mm/src/source.rs:194-216`):

- at most one role: the role-count check;
- the column names: `exactly`;
- bars held: `mm` requires held on the 4h grid, which is stricter;
- units: the same per-field test.

So every registry `mm` admits satisfies the new clause. The excluded registries are ones neither side admits, and every
law keeps its guarantee for every admitted declaration, as C7.7 requires.

**Outcome it could change:** C7.7's rule that a changed definition's laws are listed, reviewed and frozen before their
proof. No false pass is possible. Fix: name the laws above in the revision, with the one-sentence coverage argument.

## Judgement on what was asked

- **Is the revision legitimate?** Yes. The 2026-11-04 section is on neither `origin/main` nor `origin/stage7`, so
  rewriting it edits no frozen line. Its table matches the files: `Source.lean` `dc248cb3…`, `Resolve.lean`
  `aac49357…`, and `Laws.lean` and `kernel/RULES.md` still at B2's hashes. It loosens no threshold.
  - **What it strengthens.** `Registry.valid` keeps the old name check and the one-role bound unchanged in meaning;
    `Role.columns` gives the same lists. It adds two conjuncts: a bars provider has `.held` cadence, and a field reading
    a role column's stored column has that column's unit (`trades` excepted). Lean's valid set only shrinks, and only
    by registries `mm` also refuses (finding 2). It cannot increase false passes.
  - Main.lean's stage 6 registry, which the run differential uses, still evaluates `registry.valid = true`.
- **GPT finding 1 (differential crash).** Fixed at its cause. The generator assigns `cadence` on every branch
  (`reference/admission_differential.py:56-63`), gives role fields their role's unit with 97% probability, and puts
  every held bars provider on the eventTime grid. The harness decodes fields (`reference/lean/Main.lean:107`).
- **GPT finding 2 (bars grid on the wrong column).** Fixed at its cause: `source.rs:214` requires the slot `eventTime`,
  the column execution builds bars from. SOURCES.md §6 says so, consistent with §4 (certification checks the grid on
  the slot column) and §1 (at most one role).
- **GPT finding 3 (Lean accepts what Rust refuses).** Fixed for everything Lean models: unit consistency and bars being
  held. The numeric grid and the held slot stay `mm`'s alone, because Lean's `Decl` has neither. The revision says so.
- **Is the differential a sound check?** Yes, within its domain. On seed 1 every generated invalidity falls into one of
  four classes, and every case containing one is refused at position 0 on both sides. Cases where a class is the only
  invalidity:

  | Only invalidity | Cases (seed 1) |
  |---|---|
  | both roles | 184 |
  | event- or evidence-cadence bars provider | 369 |
  | role-unit mismatch | 105 |
  | a dependency with no sources | 139 |

  The other 4,058 cases contain none of them, and neither side refuses any at position 0.
  - Against `a095bab`'s `Source.lean` with this harness, seed 1 disagrees in 485 cases: exactly the 369 + 11 + 105 cases
    whose only new-clause violation is an event-cadence bars provider, a unit mismatch, or both. The check therefore
    detects removal of either new clause, and that is what the revision's "485" means.
  - The advisor's 0 disagreements on seeds 1 to 3 reproduce exactly. Refused at position 0: 942, 930 and 969. Ok: 524,
    484 and 469. Those numbers mean what the revision says.
  - The limits are stated or harmless. `mm`'s grid and slot refusals are never generated (Lean admits them by design),
    so only the cargo test covers them. Lean's role-name and order conjunct is never exercised false, because
    `lean_decl` writes role columns in `Role.columns` order and the generator never produces wrong names.
- **Do the new tests fail on the old code?**
  - Rust: with `a095bab`'s `source.rs`, `a_bars_provider_is_on_the_4h_grid_and_provides_one_role` fails with
    `accepted: "slot": "reportedTime"`. On `89fd44f` it passes, as do the other four tests.
  - The new `close`-unit mutation already failed on `a095bab`. It adds coverage but is not a regression test.
  - Lean: three of the five examples fail on the old clause (finding 1).

## Noted, not findings (no outcome they can change)

- `kernel/mm/tests/sources.rs:44-45`: nothing asserts that the `times` replacement found its text. If `hl-bars-4h/2.json`'s
  `times` line changed, the `slot: reportedTime` mutation would still be refused, but as "slot must be one of times", and
  the test would no longer exercise the grid-slot check. Today the text is present (`sources/hl-bars-4h/2.json:6`).
- SOURCES.md §6 gives `trades` the type "integer" and no unit. Neither `mm` (`unit.is_some_and`) nor Lean (`u.all`)
  constrains a field that reads the `trades` stored column, so such a field could be declared in usd/coin. The two sides
  agree, and no committed declaration does this. If integer means dimensionless, the spec's owner should say so.

**Verdict: fix first.** Only the two record sentences in `laws-frozen.md` (findings 1 and 2) need changing before they
become append-only; the code, tests and differential can merge as they are.
