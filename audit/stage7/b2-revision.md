# B2: the frozen Lean revised so a dependency spans several sources (draft for review, not frozen)

Drafted 2026-11-01 on branch `stage7` from the frozen Lean at `1e2c604` (its files match `laws-frozen.md`'s latest
table), as the advisor's decision of 2026-11-01 16:59 UTC (11:59 EST) states it (`audit/decisions.md`), using both
reviews (`b2-review-claude.md`, `b2-review-gpt.md`). It is frozen only after a fresh Opus review and a GPT review
(C7.7); the freeze then appends a dated revision with these hashes to `laws-frozen.md`. Diff for review:
`git diff 1e2c604 -- reference/lean kernel/RULES.md kernel/SOURCES.md audit/stage7/migration-annex.md`.

## 1. Changed definitions

`Source.lean`:
- `Dep`: `source : Nat` becomes `sources : List Nat`.
- `Decl`: `entityColumn : String` becomes `entityColumns : List String`: `["coin"]` for a coin-keyed source, an evidence
  source's key columns other than its event column. `eventColumn` is unchanged; for evidence it is the declared event
  column (`observed`, `recv`).
- `Decl.depends`: `d.deps.flatMap (·.sources)` (was `map (·.source)`).
- `Decl.controls`: `… ++ d.entityColumns ++ …` (was `[d.entityColumn]`).
- `Revision`: `upstream : List (String × List (Nat × String × Int))`, each key (source, stored entity, event time) (was
  (coin, event time)); the docstring states `coin = none` for evidence.

`Resolve.lean`:
- `Stored.eligible`: a key's revisions selected by `r.entity == entity` (was `r.coin == some coin`).
- `Stored.keys`: `(coin, entity, event)` for each eligible revision with a coin (was `(coin, event)`).
- `Stored.validAt`: the clause "two eligible revisions of one coin and event share a fetchedAt" is replaced by "an
  entity's eligible revisions map to one coin (or all to none)"; the entity-key clause and the range clause stand.
- `timeline`: keyed by `(s, entity, event)`. `upKnown` returns `Except`: `.unusable` if the key's source is not among
  `dep.sources`, or if no delivery of it that is not a retraction is recorded by the revision; otherwise the latest
  such knownAt, as before. `known` takes each dependency's keys with `mapM` (was `filterMap`), so one unusable key makes
  the row unusable instead of being skipped beside another; an empty list stays `.unusable`.
- `resolveAll`: iterates `(coin, entity, event)` and calls `timeline … s entity event`; each `Obs.coin` is the key's
  coin. Evidence revisions, with no coin, never become observations.

Unchanged text whose meaning changes through `depends` or `controls`: `Registry.closure`, `Registry.valid`,
`Decl.ruleOk` (no), `Meta.matches`, `Meta.required`, `stage1`, `differs`.

## 2. Changed statements

- `L8_monotone`: the key parameter `coin : Nat` becomes `entity : String`. Content unchanged.
- `L8_known`: the same parameter change; the upstream timeline is `timeline … fuel up.1 up.2.1 up.2.2` (was
  `dep.source up.1 up.2`). Strengthened: for every delivered value and every dependency, the lineage is nonempty, and
  every listed key's source is in `dep.sources` and the key has a delivery, not a retraction, recorded no later than
  the value. The bound itself (each such delivery's knownAt plus the lag) is the old one.

No other statement changed: the other 16 law headers are byte-identical to `1e2c604`'s.

## 3. Laws whose definition closure changes

Computed by `b2-closure.lean` (`lake env lean ../../audit/stage7/b2-closure.lean` from `reference/lean`): the transitive
constants of each law's statement, through definitions' bodies, not proofs. All 18 reach the changed structures `Dep`
and `Decl`; the definitions with changed bodies that each reaches:

| Law | Changed definitions reached | Through |
|---|---|---|
| `L1_values`, `L1_simulator`, `L1_decisions`, `L2_units`, `L4_fills`, `L4_orders` | `Decl.depends` | `CheckerAccepted`, `Registry.valid`, `closure` |
| `L2_checker` | `Decl.depends` | the same and `Program.WF` |
| `L3_rewrite` | `Decl.depends`, `Decl.controls` | `Program.WF`, `Meta.required`, `Meta.matches`, `stage1` |
| `L5_admitted`, `L5_order`, `L5_staged`, `L5_shape`, `L6_bounded` | `Decl.depends`, `Decl.controls` | `Registry.valid`, `Meta.required`, `Meta.matches`, `stage1` |
| `L5_text` | `Decl.depends` | `Registry.valid`, `Meta.required` |
| `L5_certified` | `Decl.depends`, `Decl.controls`, `Revision`, `Stored.eligible`, `Stored.keys`, `Stored.validAt`, `timeline`, `resolveAll` | the above and `Trusted` (its `resolve` is `resolveAll`) |
| `L7_reads` | none (the structures only, through `Program.WF`) | |
| `L8_monotone` | `Revision`, `Decl.controls`, `Stored.eligible`, `timeline` | `differs` |
| `L8_known` | the same and `Decl.depends` | `Registry.valid`, `differs` |

C7.7 read literally asks each of these to be reviewed. The content that matters: closure and certificate matching
over a dependency's several sources (`L5_*`, `L3_rewrite`, `L6_bounded`), control columns of evidence declarations
(`L5_*`), and what `Trusted.resolve` now computes (`L5_certified`).

## 4. Validation (development, not judged)

At this draft's commit:
- `lake build` (library and `refmm`): passes, 109 jobs. Only `Proof/Resolve.lean` changed among the proofs:
  `timeline_ordered` (the eligible filter) and `timeline_known` (its value predicate and the new `upKnown` lemma).
- `#print axioms` for all 18 laws: only `propext`, `Classical.choice`, `Quot.sound`; no `sorryAx`. `L8_known` now uses
  `Classical.choice` (it did not before), from the list lemmas the strict lineage proof needs; `L8_monotone` still
  needs only `propext` and `Quot.sound`.
- `refmm`'s declaration parser (`Main.lean`) reads dependencies as source lists and `entityColumns`;
  `reference/admission_differential.py` generates evidence declarations with their event column and Lean
  declarations in the revised shape, and `mm`'s `source.rs` reads the event column (SOURCES.md §1).
- The admission differential, `mmdump admit` against `refmm admit` (Lean's `admit`), on 20,000 cases each for seeds 1,
  2 and 3: no disagreement; every position 1 to 5 reached and 6,892 passing. Positive controls, on the Lean side of
  seed 1: a dependency reduced to its first source, 1,364 disagreements; an evidence declaration's entity columns
  dropped, 158.

## 5. For the reviewers: what changes in behavior

1. **Strict lineage** (`mapM`). A derived row is unusable if any listed key is unusable, where the frozen Lean took
   the maximum over the usable ones. Only removes rows. GPT's F4 and Claude's F4.
2. **Source membership.** A key of a source the dependency does not name makes the row unusable (was impossible to
   state: keys had no source and were looked up in the dependency's one source).
3. **Entity keys.** Two stored entities mapped to one coin were one timeline (one could correct the other); they are
   now two. Certification forbids such a mapping (`migration-annex.md` §2). If both have a final delivery at one event
   time, `Ctx.admissible` refuses the run; at different event times both deliver into that coin's slot. The
   `validAt` clause on (coin, event, fetchedAt) went with this, since no timeline is keyed by coin any more.
4. **Evidence outside U** rests on decoding: an evidence revision has `coin = none`. If an implementation gave one a
   coin, `Ctx.make`'s filter to delivered (non-evidence) sources still drops its observations.
5. **An empty `Dep.sources`** is accepted by `Registry.valid`; every row of that declaration is then unusable. `mm`
   rejects it when parsing. Left open for review: a `Registry.valid` clause would make the two agree, at the cost of
   one more condition that removes no risk.
6. **Lineage completeness** is still certified, not proved: the Lean cannot tell that a positive count's lineage
   omits a sighting. C7.3's verifier carries it (Claude's risk 3).
7. **The event column is a certification fact.** An evidence source whose declared event column were a feed's claim
   would reopen F5's holdout leak; the certification policy should test that the column is recorder-set.

## 6. Hashes of this draft

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `ef9f5920bcf3e61a05a064cfdf8efd24bd22f73a4a479417f6ee02e6cc9388e3` |
| `reference/lean/Ref/Resolve.lean` | `f55b512eb6f09bcdde584273d3de4db37ce9611c65a1ce8cae0c0f4819406ebb` |
| `reference/lean/Ref/Laws.lean` | `41722b5880a5d4f20b5815e3600498965d08aea361ea2dbb7ebda06e60377b67` |
| `kernel/RULES.md` | `4f9cf8196e3cb077990f9eb5413e4c28d0e0d3887d8bdaae65cfea9169cbdfdb` |

`Json`, `Syntax`, `Machine`, `Sim`, `Units` and `Spec` are unchanged from `laws-frozen.md`'s latest table.

## 7. After the freeze, not part of this revision

- B3: the C7.6 resolver suite, drafted once against these definitions, with hand cases for a covered zero count with
  polls-only lineage at T, a key of a source outside its dependency, a key with no delivery by the derived revision,
  and a later upstream correction not moving an earlier derived row.
- Slice 5 (the entity-keyed timeline in `resolve.rs`), `ingest/events.py` emitting per-row lineage keys beside the
  legacy hashes, and a `refmm` resolver mode.
- `docs/whitepaper.tex` (on `main`): GPT notes that its point-in-time paragraph still describes snapshot selection, not
  the bitemporal resolver (`b2-review-gpt.md` §4).
