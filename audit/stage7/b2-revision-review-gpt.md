# C7.7 review: do not freeze yet

**The central B2 resolver change implements the advisor’s decision correctly. I found no counterexample to the revised Lean law formulas. However, two contract mismatches should be fixed before this revision is frozen: the empty dependency-source case and outcome-relevant stale specification text.**

This is a static review. Git execution was unavailable, so I used the requested changed-file fallback. I did not execute Lean, rerun differentials, or independently verify the reported hashes.

## 1. Blocking findings

### B1. An empty source list is admitted by Lean but forbidden by the intended contract and Rust

**Outcome affected:** declaration acceptance, whether a run returns results, and reference/production agreement. This is not a demonstrated early-delivery leak.

`Registry.valid` checks source indices through `d.depends.all`, but an empty `Dep.sources` satisfies that check vacuously (`reference/lean/Ref/Source.lean:119–128`). The specification requires “one or more” sources (`kernel/SOURCES.md:109–114`), and Rust explicitly rejects an empty list (`kernel/mm/src/source.rs:180–190`).

**Concrete scenario:**

1. Declare a held field `x`, rule `dep "recording"`, and dependency `recording` with `sources := []`.
2. The rule has the required dependency lower bound, and the Lean registry can be valid.
3. Bind and certify this declaration alongside ordinary venue providers.
4. Check a program that mentions `x` in an unused let but has a constant weight.
5. Every row of `x` is unusable, but missing observations are permitted; the rest of the run can succeed.
6. Rust rejects the declaration before that run can exist.

Thus “its rows are unusable” does **not** make the acceptance difference outcome-neutral.

**Required resolution:** reject empty `Dep.sources` in `Registry.valid`. Add an explicit negative declaration case; the current generator always produces nonempty source lists (`reference/admission_differential.py:31–33`), so the reported differential cannot settle this question.

This restores the chosen contract without changing any intended valid declaration.

### B2. Current normative specifications still prescribe observably different behavior

**Outcome affected:** input definedness, decisions, returns, admission and discovery selection.

B2’s revised dependency prose agrees with Lean, but other current sections of `SOURCES.md` remain incompatible with it.

#### Event ordering can select a different input

`SOURCES.md` orders each source by `(knownAt, coin, eventTime)` (`kernel/SOURCES.md:93–96`). Lean orders event ties by **recording time, then event time** (`reference/lean/Ref/Sim.lean:217–231`), matching the later RULES revision (`kernel/RULES.md:176–179`).

**Scenario:** two event keys have the same coin and knownAt. The current-hour row was recorded first; an older-hour correction was recorded second.

- Lean delivers the current row, then the older correction: the current-hour input is undefined.
- Event-time ordering delivers the older key first, then the current row: the input is defined.

That can change a weight and an order.

#### Tombstones and rejected revisions are not “deliver nothing”

The held-delivery text says a tombstoned or rejected key delivers nothing and clears nothing (`kernel/SOURCES.md:98–102`). Lean emits a timed retraction after an earlier delivery (`reference/lean/Ref/Resolve.lean:117–129`).

**Scenario:** a held value `1` is delivered, then its key receives a tombstone at F. Lean delivers a retraction at F and makes the input undefined; following the “clears nothing” text can leave `1` held.

#### The required set omits sources that Lean actually includes

The specification describes the closure of program references and providers (`kernel/SOURCES.md:150–152`). Lean also includes **every bound non-evidence source**, even if the program never mentions it (`reference/lean/Ref/Source.lean:260–265`).

**Scenario:** an unused bound source depends on holdout evidence. Lean includes that evidence and refuses the search run; an implementation following only the specified required set can omit it and run.

**Required resolution:** add a dated, current specification revision covering these differences. Also correct:

- extra columns supposedly participating in corrections (`kernel/SOURCES.md:80–82`), although `differs` compares declared columns only (`reference/lean/Ref/Resolve.lean:71–76`);
- the claim that every access is authorized before payload opening (`kernel/SOURCES.md:157–161`): Lean separates metadata checks, event-time scanning, resolution and post-resolution value scope (`reference/lean/Ref/Sim.lean:490–507`).

These are existing inconsistencies, not newly introduced resolver regressions. Nevertheless, they can change outcomes and should not remain active instructions for the independent port being frozen.

## 2. Concrete adversarial paths

Subject to truthful certification and canonical decoding, the requested direct attacks are handled as follows.

| Attempt and concrete scenario | Result under the draft | Relevant definition |
|---|---|---|
| **Use a derived value too early.** A row’s rule yields T, but a listed sighting has knownAt T+1 and lag 0. | Its knownAt is raised to at least T+1. An event row misses its T tick rather than moving ticks. | `Resolve.lean:99–116`; `Laws.lean:453–458` |
| **Hide a missing contributor behind a good poll.** Lineage lists a usable poll and a sighting with no delivery recorded by the derived revision. | `mapM` rejects the row; the poll cannot mask the missing sighting. | `Resolve.lean:108–112` |
| **Lose a covered zero.** `recording.sources` contains sightings and polls, but that hour has only covering polls and count 0. | It succeeds: nonemptiness is required over the dependency’s listed keys, not separately for every named source. With authenticated poll times ≤ T and lag 0, knownAt is T. | `Resolve.lean:108–116`; `migration-annex.md:20–26,51–58` |
| **Resolve outside the dependency.** A key names source C, while its dependency permits only A and B—even if C is otherwise certified. | The row is unusable before C’s timeline is consulted. | `Resolve.lean:99–105` |
| **Cross a holdout boundary through evidence.** An item claims creation before H but was observed at or after H. | With the specified evidence projection, `row.event ≥ H` and stage 2 refuses the search run. Source closure includes every dependency source. | `Source.lean:53,264–265,279–281`; `SOURCES.md:57–63`; `Resolve.lean:197` |
| **Let a later upstream correction rewrite an earlier derived observation.** Upstream original is recorded at 0; derived row at 10; upstream correction at 20; V=30. | The correction is excluded from that derived row’s bound by `fetchedAt ≤ 10`. It does not move the earlier derived delivery. | `Resolve.lean:101–103` |

### Remaining certification-dependent paths

These are consequential limitations, not newly false theorems:

- **Omitted lineage still permits early delivery.** A transformation uses a sighting known at T+1 but lists only a poll known by T. Strict `mapM` succeeds because the missing sighting was never listed. This can change decisions and returns. The draft acknowledges this correctly (`audit/stage7/b2-revision.md:99–100`). The verifier must recompute and reconcile complete lineage, not merely validate the supplied keys.
- **A false evidence event projection can cross holdout.** If decoding uses the item’s creation claim instead of recorder observation time, the preceding holdout example passes stage 2. The declaration schema alone cannot prove that a column is recorder-set (`kernel/mm/src/source.rs:119–144`). Certification must authenticate this fact.
- **Non-injective tuple encoding can resolve the wrong record.** Joining tuple components with an unescaped separator can alias `("a|b","c")` and `("a","b|c")`. The resulting bound can concern the wrong evidence. Implement exact tuple equality through a stable, injective encoding into `Revision.entity`, and pin that encoding with the transformation/loader artifacts (`SOURCES.md:57–61`; `Source.lean:292–303`).

The scheduled B3 suite should exercise these boundaries using actual stored evidence decoding, not only pre-supplied event timestamps.

## 3. L8 strength and non-vacuity

### `L8_known`

**It states the principal B2 claim, and strengthens rather than weakens the frozen contributor guarantee.**

For every delivered non-retraction value and every dependency, it requires:

1. nonempty lineage;
2. membership of every listed key’s source in that dependency;
3. existence of a non-retraction upstream delivery recorded by the derived revision;
4. a knownAt-plus-lag bound for **every** qualifying delivery of each listed key.

These are explicit at `reference/lean/Ref/Laws.lean:448–458`. The existential clause prevents the old universal-bound-only claim from succeeding vacuously for a nonexistent key. The proof establishes these facts through successful `mapM` and maximum bounds (`reference/lean/Ref/Proof/Resolve.lean:332–389`).

It is non-vacuous at production fuel: two evidence sources with one usable poll and a derived source with polls-only lineage produce a real delivery. A declaration need not list a key from every source in its dependency.

However, it does **not** prove:

- completeness of lineage;
- that the latest upstream state is currently unretracted—the definition deliberately takes prior non-retraction deliveries;
- temporal-prefix stability across two stores or versions;
- the rule-result lower bound;
- the recording-time bound for a first successful delivery following earlier failed eligible revisions.

The last two properties are enforced by the definition but not fully expressed by this law (`Resolve.lean:113–125`). This is inherited statement scope, not a B2 weakening. Do not present the theorem as proving those stronger claims.

### `L8_monotone`

The entity-keyed statement preserves the corresponding within-key guarantee: successive delivered entries have nondecreasing fetchedAt and knownAt (`Laws.lean:430–441`).

It is non-vacuous: an original derived value followed by a differing correction yields two entries, and the predecessor and recording bounds order them.

It is **not** a theorem that later records leave earlier derived observations unchanged. That protection comes from the recording cutoff in `upKnown`, not from within-timeline monotonicity.

### Accepted exceptions remain

First-revision certified backfills, final venue-state execution and whole-run admission remain explicit exceptions (`kernel/RULES.md:185–190`). B2 does not remove them. In particular, “later records cannot change any historical result” would still be false.

## 4. Review of all 18 affected laws

On the intended nonempty-source, canonically decoded and certified domain, I find no weakened guarantee.

| Law(s) | Meaning under B2 |
|---|---|
| `L1_values` | Equal delivered prefixes still imply equal machine states. Dependency lists change registry validity, not the conclusion (`Laws.lean:34–49`). |
| `L1_simulator` | Machine/simulator schedule correspondence is unchanged (`52–60`). |
| `L1_decisions` | Equal delivery prefixes **and execution views** still imply equal traces. The execution qualification remains essential (`62–91`). |
| `L2_units` | Unit safety and instrumented-machine erasure remain unchanged (`95–130`). |
| `L2_checker` | Checker acceptance still implies registry-relative WF; fields, units and input cadence interpretation are unchanged (`132–135`). |
| `L3_rewrite` | WF, source preservation, node correspondence, trace equality and admission-inclusive run equality remain. Equal direct source sets induce equal flattened closures (`139–160`). |
| `L4_fills`, `L4_orders` | Fill timing/pricing and exactly-once order resolution retain their evaluator-level guarantees (`164–284`). No new certificate-only restriction is introduced. |
| `L5_admitted`, `L5_order` | Successful runs pass the same staged checks; failure ordering remains the definition’s ordering. All dependency sources now participate (`288–335`). |
| `L5_staged` | Enlarged source closure and evidence control inventories are metadata; the payload-independence statement remains (`337–348`). |
| `L5_shape` | Same resolved shape still gives the same admission outcome. It remains conditional on equal shape, not proof that resolution preserves shape across future changes (`350–362`). |
| `L5_text` | Every textual input reference remains required. Flattening dependencies only extends the transitive required set (`364–368`). |
| `L5_certified` | Its concrete resolver now handles qualified evidence keys. Closure includes every permitted dependency source; membership checks prevent successful resolution through another source. Evidence controls are checked by stage 1 (`370–409`; `Source.lean:252–276`). |
| `L6_bounded` | The unrestricted evaluator claim and public-run claim remain; numerical assumptions are unchanged (`413–426`). |
| `L7_reads` | Latest-held/current-slot-only reads remain unchanged. Evidence has no DSL fields and is excluded from delivered sources (`463–477`; `Source.lean:124,260–262`). |
| `L8_monotone`, `L8_known` | Preserved and strengthened as assessed above. |

The alias-mapping case changes the admitted domain, discussed below; it must not be advertised as unconditional equivalence over arbitrary mappings.

## 5. Remaining open questions and stale material

### Two stored entities mapped to one coin

**Outcome affected:** whole-run refusal and potentially delivery contents.

Entity-keyed timelines correctly prevent one entity from correcting another (`Resolve.lean:46–61,164–172`).

- At the **same event**, two entities with delivered timelines produce duplicate final `(source,coin,event)` keys, so admission refuses (`Sim.lean:443–453`).
- At **different events**, both can deliver into the same coin’s slot. Admission does not establish injectivity.

**Resolution:** keep entity-keyed resolution; do not restore coin grouping. Make the injective stored-entity mapping requirement explicit in the general binding/certification contract, not merely the migrated event mapping (`migration-annex.md:44–49`). Reject aliases during certification and test both event arrangements. This requires no additional resolver special case.

The old coin/event fetchedAt clause need not return: its former grouping identity no longer describes a timeline.

### Evidence outside U

**Outcome affected if decoding is wrong:** accidental strategy delivery.

`resolveAll` itself does not test evidence cadence before enumerating coin-bearing keys (`Resolve.lean:159–165`). Its “evidence never becomes observations” claim relies on `coin = none`. `Ctx.make` independently filters evidence sources out (`Sim.lean:220–223`).

Keep both facts explicit: canonical evidence decoding assigns no coin; the construction filter remains defence in depth. Do not delete the filter as redundant merely because compliant decoding makes it unnecessary.

### Admission differential coverage

**Outcome affected:** confidence in production/reference agreement, not a demonstrated new execution defect.

The revised harness checks metadata admission, source closure and control-column matching. It does not test actual evidence key decoding or resolver behavior:

- `caseDecl` supplies a placeholder rule and no fields (`Main.lean:99–110`);
- resolution deliberately fails after positions 1–5 (`Main.lean:112–137`).

The reported 60,000 agreements are useful but do not validate the holdout projection or the resolver attacks in §2. The draft appropriately schedules a resolver mode and B3 separately (`b2-revision.md:117–121`).

### Other stale descriptions

**No direct execution outcome from the prose alone, but misleading proof/implementation claims should be corrected:**

- The old audit table still classifies partial lineage as unable to change outcomes (`laws-v2-draft.md:188`), although B2 intentionally fixes an early-use path. Preserve the historical entry and append its supersession.
- The annex’s evidence “scope grants” need to distinguish verifier-enforced inheritance from runtime grants: runtime `Grant` is coin-indexed, and evidence produces no ordinary observations/accesses (`migration-annex.md:68–76`; `Source.lean:170–184`; `Sim.lean:471–479`).
- The whitepaper correction is expressly deferred and cannot be verified from this tree (`b2-revision.md:122–123`).

## Verdict

**Do not freeze yet. Fix B1 and B2 first:**

1. reject empty dependency-source lists in the validated Lean registry;
2. supersede outcome-relevant stale specification instructions with the actual bitemporal delivery, ordering, required-set and authorization contracts.

The core source-qualified, entity-keyed, strict-lineage resolver and revised L8 formulas are otherwise suitable for freezing. After the fixes, record new hashes and revalidate dependent proofs **after** the dated freeze, as required by `audit/stage7/laws-frozen.md:3–4`.
