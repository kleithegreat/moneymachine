# Stage 7 bug hunt (fresh Claude session), 2026-11-04 06:30 UTC (01:30 EST)

Branch `stage7` at `origin/stage7` as of 2026-11-04 06:11 UTC (01:11 EST); scope `git diff origin/main...origin/stage7`:
`kernel/mm/src/{source,admission,rule,dsl,machine,main,canon,sim}.rs`, `ingest/knownat.py`, `sources/`,
`reference/{admission_differential.py,mmdump}`, `reference/lean/Ref/{Source,Resolve,Sim,Machine,Syntax,Json}.lean` and
`Main.lean`, against `rust-port-plan.md`, `migration-annex.md`, `b2-revision.md`, `laws-frozen.md`, `kernel/{RULES,
SOURCES,CERTIFICATES}.md` and the C7 criteria. Excluded: `slice2-review-gpt.md`'s findings and the nine kernel defects.

Method: reading, then reproduction. Lean 4.34.0 (the pinned toolchain) built `Ref.Sim` and `Ref.Resolve` here, so the
Lean findings are `#eval`s of the frozen definitions, not readings. `mm` was built with cargo. Only the two tests added
below were run, not the full suite.

## Findings

### 1. A provider offering both roles delivers only its first role's payload (medium)

**Outcome it can change:** a run admitted with no execution data from its selected provider: as the settlement
provider, no funding rate reaches execution, so any held position aborts `R_SETTLEMENT_MISSING`; as the bars provider,
no bar reaches execution, so no order fills and decisions are priced from no close. Admission passes in both cases.

SOURCES.md §1 lets a declaration list "the roles this declaration can provide" (`kernel/SOURCES.md:50`); `mm` accepts a
declaration with both (`kernel/mm/src/source.rs:193-199`), as does the frozen `Registry.valid`
(`reference/lean/Ref/Source.lean:129-131`), and the admission differential generates them on purpose
(`reference/admission_differential.py:50-54`). But `rolePayload` reads only the declaration's **first** role
(`reference/lean/Ref/Resolve.lean:133-145`), `decodes` requires that first role's payload (`:152-154`), and
`resolveAll` attaches it (`:171`). `barRow` and `rateRow` take a payload only of the selected role
(`reference/lean/Ref/Sim.lean:191-199`), and `Ctx.admissible` accepts a payload of any role the declaration is capable
of (`Sim.lean:445-449`). So the selection the run manifest makes (`Roles`) never reaches resolution.

Reproduction (`reference/tests/test_hunt_stage7.py::test_an_admitted_provider_delivers_the_role_it_was_selected_for`):
declaration 1 offers bars then settlement and is the settlement provider; `Registry.valid`, `Roles.valid` and
`Ctx.admissible` are true, `Ctx.bars` has 1 row and `Ctx.rates` 0. With the order reversed (declaration 0 offers
settlement then bars and is the bars provider): admitted, 0 bars, 1 rate. The test asserts that an admitted run gets
one bar and one rate in both. No committed declaration has two roles, so no recorded result is affected; the Rust
port (slices 4 and 5) would inherit it. Either fix (a declaration provides at most one role, or the payload follows
the run's selection) changes a frozen definition and so needs a dated revision in `laws-frozen.md`.

### 2. A bars provider's grid is never checked against the role's 4h contract (low)

**Outcome it can change:** fills, marks and margins of every run whose bars provider is declared on another grid.

SOURCES.md §6 fixes bars as 4h on the 4h grid, a bar's open being its eventTime less 4h (`kernel/SOURCES.md:146,150`),
and execution assumes it (`barRow`: open `o.key - BAR`, `Sim.lean:193`). Nothing enforces it: `mm` checks a role's
columns only (`kernel/mm/src/source.rs:10-12,194-198`) and takes any held period (`:157-167`); Lean's `Decl` has no
period (the port plan keeps the grid as "certification's grid, outside the semantics", `rust-port-plan.md`, §1 `Source`
row); and certification's coverage test checks the feed against the declaration's own cadence (`sources/policy.json`,
`gaps`), so a 1h bar feed declared 1h passes it and is then executed as 4h bars. The same holds for a role column's
unit: a settlement `rate` mapped to a field declared `usd/coin` is accepted (SOURCES.md §6 requires 1/h).

Reproduction (`reference/tests/test_hunt_stage7.py::test_a_bars_provider_off_the_4h_grid_is_refused`): the committed
registry with `hl-bars-4h` 2's `period_ms` set to 3,600,000 (hashes recomputed) loads, and `mm check --sources` on it
prints `{"ok":true,…}`. The test asserts a registry error (exit 3). If the fix lands in admission (`Roles.valid`)
instead, the test moves there.

## Checked, no defect found

- `admission.rs` against Lean's `Roles.valid`, `Meta.valid/matches/required`, `stage1`, `stage2` and `Abort.position`:
  the same checks in the same order; the BFS in `required` gives `Registry.closure`'s order.
- `source.rs::declaration` and `registry` against `Registry.valid` and SOURCES.md §1: every Lean clause is enforced
  (dependency names unique by the parser's duplicate-key refusal; acyclicity over every declaration); `controls` equals
  `Decl.controls` for both entity kinds.
- `rule.rs` and `ingest/knownat.py` against RULES.md §1-5: the same parser, typing, lower-bound and evaluation rules.
- The frozen-law files: every file's SHA-256 equals the latest table in `laws-frozen.md`; no `sorry`, `axiom` or
  `native_decide` in `reference/lean`; `Exec.lean`'s `csimp` replacement is proved.
- `mm check` and `mm eval` on the committed registry: `canonical`, the equivalence key and units are unchanged from
  `main` (input names and units equal the removed `HELD` and `EVENT_INPUTS`).

Noted, not findings: version 1's resolvers (`rule.rs::resolve`, `knownat.resolve`) both read any integer token over 19
digits as one out-of-range value, so two different out-of-range observed values do not count as a correction; B3
replaces these resolvers, and a rule reading such a value rejects the row anyway.
