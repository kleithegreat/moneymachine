# C7.7 review of the B2 fixes

**The fixes satisfy the rulings. I found no blocking counterexample in this diff.** The strengthened timing bound, canonical-lineage requirements and declaration rejection are suitable for refreezing.

This is a static review using `b2-fixes.diff` and the current files. I did not execute Lean, rerun the differentials, independently verify hashes or inspect the underlying datasets. Reported validation remains development evidence, not independently reproduced evidence.

## 1. Compliance with the rulings

| Fix | Assessment and outcome affected |
|---|---|
| **Retractions bound derived revisions** | Correct. `upKnown` now includes every upstream delivery recorded by the derived revision, including retractions (`reference/lean/Ref/Resolve.lean:100–106`). `L8_known` removes both corresponding non-retraction restrictions (`reference/lean/Ref/Laws.lean:453–458`), and the proof establishes the enlarged bound (`reference/lean/Ref/Proof/Resolve.lean:332–357,388–389`). This closes the identified early-derived-value path. |
| **Unique dependency names in lineage** | Correct at the specified trusted boundary. `(r.upstream.map (·.1)).Nodup` prevents a second same-named entry from hiding keys behind `find?` (`reference/lean/Ref/Resolve.lean:198–201`). This is a canonical-decoding obligation, **not a new executable rejection inside `timeline`**. Bypassing that obligation still permits the old attack, but no longer satisfies the trusted contract. |
| **Injective stored-entity encoding and mapping** | Correctly distinguished. Canonical decoding forbids equal encoded entities from representing different entity-column tuples (`reference/lean/Ref/Resolve.lean:201`). The certificate pins the encoding (`kernel/CERTIFICATES.md:83–86`). Separately, the general binding and certification contracts forbid two stored entities mapping to one coin (`kernel/SOURCES.md:86–89`; `kernel/CERTIFICATES.md:59–60`). Coin-mapping injectivity remains a certification obligation, not a property proved by `Stored.validAt`. |
| **Empty dependency source lists** | Correct. `Registry.valid` now explicitly rejects them (`reference/lean/Ref/Source.lean:121–126`). The generator produces negative cases and multi-column evidence keys (`reference/admission_differential.py:31–40`). Lean checks registry validity before the metadata differential; Rust reports a refused declaration instead of crashing (`reference/lean/Main.lean:103–109,136–139`; `reference/mmdump/src/main.rs:120–123`). This changes declaration/run acceptance, as intended. |
| **Dated specification corrections** | Correct. The revised keys, undeclared-column behavior, delivery ordering, retractions, required set and authorization stages now match the relevant Lean definitions (`kernel/SOURCES.md:76–89,98–116,161–178`). RULES explicitly supersedes the historical exclusion of retractions (`kernel/RULES.md:200–206`). |

The additional annex deduplication requirement and encoding pin implement the accompanying rulings rather than unrelated redesign (`audit/stage7/migration-annex.md:26–27,99–103,109–112`).

One qualification: “can only make rows later” is best understood as a conservative timing statement. A raised dependency bound can also cause overflow rejection and therefore missingness or a retraction, rather than merely delaying a usable value (`reference/lean/Ref/Resolve.lean:117,123–130`). This is not a blocking defect.

## 2. Concrete adversarial scenarios

These conclusions assume canonical decoding and truthful certification.

| Attempt | Concrete scenario and result |
|---|---|
| **Derived value before its upstream information** | An upstream value is known at 10; its retraction is recorded and known at 50. A first derived revision recorded at 60 has rule result 20 and lag 5. Its lineage includes that key. The new bound is at least **55**, not 20. A retraction the transformation could see can no longer disappear from the calculation (`reference/lean/Ref/Resolve.lean:100–117`). **Outcome protected:** input availability, decisions and returns. |
| **Hide a late or unusable key** | A lineage contains `("recording",[goodPoll])` followed by `("recording",[lateSighting])`. Such a row violates the new `Nodup` obligation. With one entry containing both keys, `mapM` rejects the row if the sighting has no qualifying delivery (`reference/lean/Ref/Resolve.lean:109–113,198–201`). **Outcome protected:** early delivery. |
| **Leak evidence across holdout** | An item claims creation before boundary H but is observed at H+1. Its evidence event is the recorder’s observation time, not its creation claim. Dependency closure includes the evidence source, and stage 2 rejects the search before resolution (`kernel/SOURCES.md:57–64`; `reference/lean/Ref/Source.lean:54,267–284`). Changing its name or binding alias does not evade the separate identity check. **Outcome protected:** holdout isolation. |
| **Make a covered zero unusable** | A covered hour contains no sightings but has its required covering polls. The single `recording` dependency permits both source kinds; its listed lineage contains polls only. Nonemptiness is checked over the dependency’s keys, **not separately for every permitted source**. With those poll bounds at or before T, count zero is delivered at T (`reference/lean/Ref/Resolve.lean:109–117`; `audit/stage7/migration-annex.md:52–58`). **Outcome protected:** covered-zero definedness and C7.4 preservation. |
| **Resolve against a source outside the dependency** | Dependency `recording` permits A and B; a listed key names C. `upKnown` returns `.unusable` before consulting C’s timeline—even if C is otherwise certified (`reference/lean/Ref/Resolve.lean:100–106`). **Outcome protected:** source confinement and availability. |
| **Later correction rewrites an earlier derived observation** | Upstream original is recorded at 10, derived revision at 20, upstream correction or retraction at 30, dataset version 40. The later upstream entry fails the `fetchedAt ≤ 20` filter and cannot change that derived revision’s bound (`reference/lean/Ref/Resolve.lean:102–104`). **Outcome protected:** the earlier derived delivery’s timing. |

The last result is not unconditional historical-result stability. Whole-run admission can still refuse a changed dataset, and final venue-state revisions can change historical accounting under the expressly retained exceptions (`kernel/RULES.md:185–190`).

## 3. Law strength and non-vacuity

### `L8_known`

The revised statement is strong enough for the selected B2 contract:

- every delivered non-retraction value has nonempty lineage for every dependency;
- every listed key belongs to that dependency;
- every key has a delivery recorded by the derived revision;
- **every qualifying delivery, including retractions**, bounds the derived value by its knownAt plus lag.

These are explicit conjuncts, not merely a bound over a potentially empty set (`reference/lean/Ref/Laws.lean:453–458`).

Removing “non-retraction” from the existence clause does not create a substantive escape: a timeline’s first entry cannot be a retraction, and its entries are recording-time ordered. A retraction recorded by F therefore has an earlier non-retraction entry also recorded by F (`reference/lean/Ref/Laws.lean:432–452`).

It is non-vacuous. For example, two evidence declarations and one derived declaration can deliver the polls-only covered zero described above. The actual resolver uses registry-size fuel; an acyclic valid registry provides sufficient depth (`reference/lean/Ref/Source.lean:124–126`; `reference/lean/Ref/Resolve.lean:165–166`).

It still does **not** prove lineage completeness, recorder authenticity, or stability across two different stores. Nor does it independently eliminate duplicate lineage names: its formula still uses `find?`; the whole-lineage interpretation depends on canonical decoding.

### Other laws

No other law header changes in the supplied fixes diff. Their interpreted domains do change:

- `Registry.Valid` excludes empty-source dependencies.
- `Trusted.canonical` imposes stronger decoding premises.
- `resolveAll` incorporates the stronger retraction bound.

Thus it would be imprecise to claim that every theorem is formally stronger over arbitrary malformed inputs. Some hypotheses now describe a narrower domain. **No guarantee is weakened for declarations and decoded datasets satisfying the intended contract.**

| Laws | Effect of these fixes |
|---|---|
| `L1_values`, `L1_simulator`, `L1_decisions`, `L2_units`, `L2_checker`, `L4_fills`, `L4_orders` | Registry-domain restriction; evaluator conclusions unchanged. |
| `L3_rewrite` | Rewrite, source-preservation and run-equivalence guarantees unchanged. |
| `L5_admitted`, `L5_order`, `L5_staged`, `L5_shape`, `L5_text` | Invalid-registry acceptance changes intentionally; staging, scope and textual-reference guarantees remain. |
| `L5_certified` | Stronger trusted premises and the revised concrete resolver; no new guarantee of verifier correctness or mapping injectivity is proved. |
| `L6_bounded`, `L7_reads` | Numerical bound and delivered-input interpretation unchanged. |
| `L8_monotone` | Statement unchanged this round; the enlarged upstream bound preserves within-key ordering. |

## 4. Specifications, evidence and residual staleness

The revised active SOURCES sections agree with Lean’s ordering and admission stages (`reference/lean/Ref/Sim.lean:217–231,490–507`). The annex now explicitly distinguishes verifier-scoped evidence from coin-indexed runtime grants (`audit/stage7/migration-annex.md:75–79`).

Two documentary qualifications remain, neither a blocker:

1. **Historical audit descriptions are not all current implementation instructions.** For example, `laws-v2-draft.md:31–34,102–108` still describes event ordering using resolver position. The later audit entry records its replacement (`audit/stage7/laws-v2-draft.md:194`), and current SOURCES gives the actual order. **No execution outcome changes from retaining this history**; an implementer should follow the current specification, not extract an older audit description.
2. **Certificate scope prose remains broader than Lean’s runtime grant representation.** `kernel/CERTIFICATES.md:75–81` covers availability, mapping and coverage scope generally. It must be read with SOURCES’ staged controls and the annex’s verifier-enforced evidence grants, not as a claim that Lean runtime `Grant` represents evidence entities. This is documentation precision, not a demonstrated admission bypass.

### “No migrated evidence moves”

**The argument is sound given the stated counts.**

The decisive claim is not merely “no tombstones”: it is **one revision per evidence key** (`audit/stage7/b2-revision.md:115–120`). A rejected first revision produces no delivery, not a retraction; a retraction requires an earlier delivery of the same key (`reference/lean/Ref/Resolve.lean:123–130`). Consequently, none of those evidence timelines can contain an entry newly included by removing the retraction filter.

The sighting inventory also reconciles: 158,410 live sightings plus 3,306 Discourse and 315 Snapshot revisions equals 162,031 keys. Venue sources have no dependencies (`audit/stage7/b2-revision.md:115–122`).

This supports the **retraction-change-only** claim. It does not independently establish byte-identity for the complete B2 migration or replace C7.4.

## 5. Recorded limitations

| Limitation | Outcome and blocking assessment |
|---|---|
| **N-1: lineage ignored by `differs`** | An unusable first revision followed by identical cells and repaired lineage remains undelivered (`reference/lean/Ref/Resolve.lean:74–76,120–126`). This **can change definedness, decisions and returns**; “missingness only” must not mean “no outcome.” It does not itself introduce an early value. It is explicitly accepted by the ruling and does not block this freeze. Any C7.4 mismatch it causes must still fail migration. |
| **Lineage completeness** | Omitting a sighting known at T+1 while listing only polls known by T can deliver a derived value early. The new uniqueness clause does not detect omission. This remains consequential verifier work, explicitly recorded at `audit/stage7/b2-revision.md:129–131`. It does not block freezing these conditional semantics, but the promised recomputation and negative test are necessary before claiming C7.3/C7.7 completion. |
| **Recorder-set evidence event column** | Using creation claim instead of observed/receive time can conceal a holdout observation from stage 2. This is a real leakage risk if certification is wrong, not harmless missingness (`kernel/SOURCES.md:59–60`; `audit/stage7/b2-revision.md:132–133`). It is appropriately a certification obligation, not a reason to reject the present definitions. |

The recorded build, axiom checks, negative controls and differential results support the revision, with their stated development-only scope (`audit/stage7/b2-revision.md:73–91`). After refreezing, dependent proofs must be rechecked under the dated frozen definitions before being judged (`audit/stage7/laws-frozen.md:3–4`).

## Verdict: **FREEZE**
