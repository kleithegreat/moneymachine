# Stage 7: porting `mm` to the frozen Lean definitions (PROGRESS item 5.2)

Written 2026-11-01 04:07 UTC (00:07 EDT) on branch `stage7` at `933b3f4`. The target is the Lean frozen in
`laws-frozen.md` (`reference/lean/Ref/{Source,Resolve,Json,Syntax,Machine,Sim,Units,Spec,Laws}.lean`, RULES.md §6
with its bitemporal revisions); where `mm`, SOURCES.md or the C7.4 annex disagree with it, the disagreement is listed
in §3 and settled there, never bridged in code. Each slice deletes what it replaces (CLAUDE.md §2): at the end no
Rust names a concrete source, dataset or field (C7.1), and `EVENT_INPUTS`, the per-input enum variants and the
per-dataset branches in `market.rs` are gone (C7.4).

## 1. Each Lean definition and its Rust home

| Lean (file: definitions) | Rust today | What changes |
|---|---|---|
| `Json`: `Value`, `value`, `parse` | `dsl.rs` (`Strict`, serde), `rule.rs` (`Json`, own parser) | One JSON reader. `rule.rs`'s parser already keeps spans and exact integers; `dsl.rs`'s duplicate-key refusal becomes `uniqueKeys` after parsing, before `program` (Syntax revision of 2026-10-31). serde_json leaves the checker. |
| `Syntax`: `Dim`, `Input`, `Op`, `Node`, `Ty`, `Program`, `Code`, `typeOp`, `expr`, `program`, `check` | `units.rs` (`Unit`), `dsl.rs` | `Unit` already is `Dim` (six bases). `dsl::Input` (the enum, `HELD`, `EVENT_INPUTS`, `event_dataset`) becomes Lean's `Input {source, field, event, unit}`; `check(inputs, text)` takes the registry's input table, so `mm check` reads `sources/registry.json` and nothing else (C7.2). `Program::event_datasets` dies (stage 1's `required` replaces it). |
| `Source`: `Decl`, `Dep`, `Cadence`, `Role`, `RuleExpr.ty/lb`, `Decl.ruleOk/values/controls` | `source.rs` (`Declaration`, `declaration`), `rule.rs` (`Expr`, `check`, `lower_bound`) | `Declaration` gains Lean's columns: `eventColumn` (`eventTime`), `entityColumns` (`coin`, or an evidence declaration's key columns other than its event column), `slotColumn` (event cadence only), `revisionColumns`; `times` stays without `fetchedAt` (Lean's `times` is it plus `fetchedAt`). Held `period_ms`/`phase_ms` stay as certification's grid, outside the semantics. Evidence declarations (SOURCES.md §1, revision of 2026-10-26 02:03) are parsed. |
| `Source`: `Registry.closure/inputs/valid`, `Roles.valid`, `Program.sources` | `source.rs::registry` (unique inputs, registered acyclic deps) | Adds `inputs` (declaration order, then input-name order: `BTreeMap` already gives it), evidence and role-column conditions of `valid`, and `Roles` (a run's manifest selects one provider per role, SOURCES.md §6). |
| `Source`: `Grant`, `Access`, `Cert`, `Binding`, `Mode`, `Meta`, `Meta.valid/matches/delivered/required`, `stage1`, `stage2`, `Loader`, `Abort` | none (`main.rs::load_ctx`, `market::LoadError::Holdout`, `sim::Abort`) | New `admission.rs`: `Meta` read from the ledger (certificates, supersessions, position) and the run manifest (bindings, roles); `stage1` and `stage2` exactly as Lean, with positions (`Abort.position`). `sim::Abort` gains `Uncertified`, `Holdout`, `Roles`, `Binding`, `Invalid`. Certificate payloads and ids per CERTIFICATES.md; issuance is C7.3's verifier, outside this port. |
| `Source`: `Cell`, `Revision`, `Stored`; `Resolve`: `RuleExpr.eval`, `Stored.eligible/keys/validAt`, `differs`, `timeline`, `rolePayload`, `slotOf`, `decodes`, `resolveAll`, `Obs` | `market.rs` (`read_rows`, `resolve`, `known`, `same_values`, `NOT_VALUES`), `rule.rs` (`evaluate`, `resolve`, `effective`) | New `resolve.rs`: Parquet rows decoded to `Revision`s with declared columns only, then `timeline` and `resolveAll` as Lean (bitemporal, every eligible revision delivered, retractions, upstream keys (source, stored entity, event) with bounds recorded no later than the derived revision). `market.rs::known`'s dataset branch, `resolve`, `same_values` and `NOT_VALUES` die (undeclared columns are never compared). `rule.rs::evaluate` stays (C7.6); `rule.rs::resolve`/`effective`, version 1's snapshot resolver, die once the resolver suite is revised (§3, B3). |
| `Machine`: `BarRow`, `RateRow`, `Win`, `MState` (`latest` per source and coin), `deliver`, `input`, `eval`, `tickNode`, `tick`, `rank` | `machine.rs` (`Machine`: `funding`, `bar`, `events` typed slots; `deliver_funding/bar/event`) | The three typed slots and three deliver functions become `latest: Vec<Vec<Option<Obs>>>` and one `deliver`; `input` is Lean's (a held input reads the latest observation, an event input only when its slot is the current hour). `Win`, `eval`, `tick`, `rank` are already the same functions. |
| `Sim`: `Fill`, `Event`, `Venue`, `Policy`, `Run`, `Book`, `Index`, `checkFill`, `Order`, `SState`, `barRow`, `rateRow`, `Ctx`, `Ctx.make/deliver/execute/closeout/bankrupt/start/step/bounds/evaluate`, `accountingOk` | `sim.rs` (`run`), `market.rs` (`Market`, `Venue`, `Policy`, `Funding`, `Bar`, `Event`, `bar_at`, `rate_at`, `bar_times`) | `sim::run` takes a `Ctx` built as `Ctx.make`: delivered observations ordered by (knownAt, source, coin, tie), execution's bars and rates projected from the role providers' final observations, `Index` over them. `Market`'s typed vectors and `sim::run`'s three delivery loops die. `Market.intervals` becomes `Meta.intervals`, still computed by the front end from the venue's delisting (until C8.1). |
| `Sim`: `Ctx.admissible`, `readFrom`, `accesses`, `inScope`, `admit`, `admission`, `runProgram`, `run` | none | `admission.rs`: run admission (`R_BINDING`), scope (`R_UNCERTIFIED`, position 7), `run` from text (`R_INVALID` at position 0). `main.rs`'s `eval`/`holdout` call `admission` and then evaluate; nothing reads a payload before stage 2 passes (named tests 17, 18). |
| `Resolve`: `Ledger`, `Trusted` | `ledger.rs` | `Trusted` is what `mm` must discharge, not port: content hashes for bindings, ledger tables for certificates and supersessions (append-only triggers), the staging tests. New tables only; existing ones untouched. |
| `Num`, `Float`, `Units` (`evalU`), `Spec`, `Laws`, `Exec`, `Proof/*` | `f64`; `canon.rs` (egg rules) | Proof-side, no port. `canon.rs`'s rewrites must stay the rule set `Spec.Rule` lists (L3_rewrite): checked once in slice 2, since `op_symbol` prints input names. `Exec`'s compiled replacements are Lean-only. |

## 2. Order

Each slice is bit-identical on everything version 1 can express (keys with one revision, C7.4's identity), passes
`cargo test` in `kernel/mm`, and is checked by the differentials named; development runs are never judged.

1. **Declarations to Lean's `Decl`** (`source.rs`): evidence declarations, the one clause of `Registry.valid` that
   `registry` lacked (evidence cadence exactly for evidence entities, without fields or roles). Done 2026-11-01;
   check: `kernel/mm/tests/sources.rs`. The role-column clause holds since B1's decision; Lean's `controls`
   arrived with admission (slice 6), `values` comes with `inScope`.
2. **The checker over the registry** (`dsl.rs`, `canon.rs`, `main.rs check`, `reference/mmdump`). Done 2026-11-02 (`e2b4925`): the six event-feed and evidence declarations are registered; `dsl::parse` takes `source::inputs(registry)` (`mm check --sources`, default the repository's `sources/`, fixed at build; the pod needs it passed); `Node::Input` indexes the table and the `Input` enum and `HELD` are gone. Interim until slice 3: `machine.rs`'s `Read::of` maps input names to the typed slots, and `EVENT_INPUTS` stays for the loader and simulator. Checked: all 1,196 C6.4 verdicts agree with `refmm` (0 disagreements); `cargo test --release`, `kernel/tests/cli` and the daemon tests pass; `canon.rs`'s 16 rewrites are Lean's 17 schemas less `ifNotRev`, which the e-graph's equalities (symmetric) already give. The run half of the harness (`differential.run`) stops before comparing: market N1 does not rebuild as frozen in this tree (nothing in this slice touches markets; cause not yet found). The slice needed the event feeds'
   declarations in `sources/registry.json`, as the annex states them after B2. Checks: C6.4's harness
   (`reference/differential.py`, development run) on all 1,196 verdicts against `refmm`, whose fixed registry has the
   same four inputs; `kernel/tests/adversarial` and `admitted` verdicts unchanged.
3. **The machine over observations** (`machine.rs`). Checks: C6.4's harness, every run's node streams against
   `refmm`; named tests 16 (`machine.rs::held_and_event_reads`) and 19 (`late_correction_undefines_event`).
4. **The simulator from `Ctx`** (`sim.rs`, `market.rs`). Checks: C6.4's harness on its runs (trace, returns, gross
   returns, equity); `mm eval --trace` of `933b3f4` against the new binary on W0, the stage 2 probes and the first 200
   C6.4 programs over C6.4's markets, byte-identical (the C7.4 comparison, as a development run before its baseline).
5. **The resolver** (`resolve.rs`, `market.rs` loader): after B3. Checks: the revised C7.6 resolver suite across
   Python (`ingest/knownat.py`), Rust and GPT's independent resolver, and Lean's `resolveAll` through a `refmm`
   resolver mode; on one-revision keys, the old loader's observations byte-identical.
6. **Admission** (`admission.rs`, `ledger.rs`, `main.rs`): Checks: named tests 4–6, 8, 9, 13, 15, 17, 18, 20–23
   (`laws-v2-draft.md` §2) each with its positive control; refusal codes and positions against Lean's `admission`
   through `refmm` on the fresh C7.7 corpus (it needs the market exporter with revisions, registry and certificates,
   PROGRESS 5.2). Metadata and event times (positions 1 to 5) done 2026-11-01: `admission::admit`, `stage1`,
   `stage2` and `Declaration::controls` as Lean's; named tests 4, 9, 13, 15, 20 and 22, the staging half of 18 (no
   row read before stage 1 passes) and supersession in `kernel/mm/tests/admission.rs`; `reference/admission_differential.py`
   (`mmdump admit` against `refmm admit`, Lean's `admit` itself) agrees on 60,000 random cases (seeds 1 to 3, every
   position reached) and catches each of four injected mutants (supersession bound, provider attestation, holdout
   bound, certificate-chain fuel). Left: positions 6 and 7 (`Ctx.admissible`, `inScope` with `values`, after slices
   4 and 5), the ledger's certificate and supersession tables, `main.rs`'s wiring (`LoadError::Holdout` dies), and
   tests 5, 6, 8, 17, 18, 21, 23 and 24, which need the loader or slice 2's checker.
   **Two-run checks (self-composition; Clarkson and Schneider, *Hyperproperties*, 2010), the human's decision of
   2026-11-02.** A sampled differential is per-run evidence, and non-interference compares two runs, so slice 5 adds both,
   first checking whether they already exist under another name: the same run on two stores differing only in records
   known after t gives byte-identical decisions through t (`mm`); the same requests to the daemon with only the holdout's
   bytes changed give identical replies (`gate/tests/test_agent_daemon.py`). Each gets a positive control: a mutant that
   reads ahead must fail it.
7. **Then, outside this port:** the verifier and `mm certify`/`mm bind`/preflight (C7.2, C7.3; tests 1–3, 7, 10, 12),
   the event feeds as derived sources (C7.4), the mutants (I1–I10, C5) rerun on the ported kernel.

## 3. Disagreements with the frozen Lean, and blockers

- **B1. The bars role's `openTime`.** SOURCES.md §6, `ROLES` in `source.rs`, the committed `hl-bars-4h` 1 and the
  annex's draft table have six bars columns with `openTime`; the frozen `Registry.valid` requires exactly `open high
  low close trades`, and `barRow` takes the open as `key − BAR`. The Lean is the simpler contract (bars are 4h on the
  4h grid, so the open is the event time less 4h) and its laws are proved on it. Decided 2026-11-01 (`audit/decisions.md`):
  SOURCES.md §6's dated revision, `hl-bars-4h` 2, `ROLES` and the annex row.
- **B2. A dependency spanning several sources.** Settled 2026-11-01 16:59 UTC (`audit/decisions.md`, both reviews
  `b2-review-{claude,gpt}.md`) by a dated revision of the frozen Lean, drafted in `b2-revision.md` and frozen only after
  its review: `Dep.sources`; upstream keys (source, stored entity, event), each of its dependency's sources and with a
  delivery recorded by the derived revision, else the row is unusable (no key masks another); timelines keyed by stored
  entity; evidence records outside U, reached only as upstream keys. `source.rs`'s `Dependency` and `depends` already
  are this. Slice 5 implements the entity-keyed timeline and the strict lineage rule; the event feeds' declarations and
  `ingest/events.py`'s lineage follow the revised annex.
- **B3. The C7.6 resolver suite is version 1's.** RULES.md §6's bitemporal revision says the C7.6 suites are revised
  to match before any judged run; `kernel/tests/rules/resolver_suite.py`, `mm resolve` (`rule.rs::resolve`) and
  `ingest/knownat.py` still select one revision. The revision is frozen evidence: drafted, reviewed and committed alone
  before slice 5, then Python, Rust and GPT's resolver agree on it.
- **Evidence keys** (settled with B2). An evidence declaration names its event column among its key columns
  (`{"evidence": [K…], "event": C}`, C in `times`): the recorder's observation time, which stage 2's holdout check
  reads. Its records have no coin (Lean's `coin = none`), never an entity index; Lean's `entityColumns` are the other
  key columns, so its controls are its times, `fetchedAt`, its key columns and `tombstone`, as `Declaration::controls`
  computes (`source.rs` reads the event column since this revision).
- **Delivery order** differs only in form: `mm` delivers funding, then bars, then events at each tick, each by
  (knownAt, coin, event or store position); Lean orders all by (knownAt, source, coin, tie). Machine state is per
  source and coin and `maxKnown` a maximum, so the interleaving is unobservable; slice 4 adopts Lean's order and its
  ties (event time then recording time for held sources, recording time then event time for event sources), which
  drops the store-position tie.

## 4. Next

B1 and B2 are decided (B2's revision is frozen only after its review, `b2-revision.md`), and slice 6's metadata half
is done. What rests on neither the annex's draft declarations (slices 2
to 4) nor B3 (slice 5): slice 6's ledger tables (certificates, supersessions, the admission position) and `Meta`
read from them and the run manifest.
