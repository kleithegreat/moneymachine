## Verdict

1. **The main bitemporal repair works, but resolution is not fully faithful and future-information paths remain.** Ordinary corrections, reverts, tombstones, rejected revisions and re-listings no longer erase earlier deliveries. Derived resolution, event-slot extraction and event tie ordering still allow later records to change earlier inputs.
2. **I found no concrete counterexample to the revised law formulas**, including `L8_monotone` and `L8_known`. Those laws do **not** establish temporal-prefix invariance.
3. **Single-revision resolver behavior matches v1 on canonical, checked inputs**, provided the upstream keys are also single-revision. That does not independently establish end-to-end C7.4 equivalence without the v1 implementation.
4. **Execution intentionally remains retrospective.** Reading final venue revisions can change historical accounting and subsequent decisions before those revisions’ `fetchedAt`. Admission and authorization introduce additional outcome channels.

## Blocking findings

### 1. Derived resolution reintroduces future-dependent missingness

**Where:** `v2-Resolve.lean:93–106`; revised `RULES.md:154–157`.

`upKnown` takes the maximum knownAt over the upstream key’s **entire eligible timeline**, excluding retractions. It does not restrict that timeline to information available when the derived revision was recorded or previously delivered.

Use lag zero:

| Revision | fetchedAt | Effective knownAt |
|---|---:|---:|
| Upstream original | 0 | 0 |
| Derived original, referencing that upstream key | 0 | 0 |
| Later, differing upstream correction | F | F |

Without the correction, the derived original is delivered at `0`. Adding the correction makes its dependency time `F`, so the **same derived original** is now delivered at `F`. At `0 < t < F`, its formerly visible value disappears.

This is precisely the earlier missingness channel, moved into dependency resolution. A re-listing can cause it too. A later upstream retraction alone does not increase the maximum, but later non-retraction deliveries do.

**This follows the revised prose; it is not merely an implementation bug.** `L8_known` remains satisfied because it explicitly bounds the derived value against every such upstream delivery.

A dated semantic revision must choose causal lineage—such as identified upstream revisions with immutable availability—or explicitly permit retrospective derived availability. The current rule cannot support a general “later corrections do not change earlier inputs” claim.

### 2. Event slots are extracted from the whole timeline and applied retroactively

**Where:** `v2-Resolve.lean:133–150`.

```lean
let slot := es.findSome? (slotOf ·.rev)
```

Every observation receives the first successfully decoded slot from **any delivered revision** of its key.

Two consequences:

- **Future repair changes past admission and reads.** The original revision has no integer slot; a correction fetched at `F` supplies slot `H`. The original observation, known before `F`, acquires `H`. Without the correction, event-source admission fails; with it, admission can succeed and that earlier observation can supply the input at `H`.
- **Ordinary slot corrections are ignored.** If the original has slot `H₀` and a later correction has `H₁`, both deliveries retain `H₀`.

The latter is a direct revision-payload fidelity problem, not just an unusual invalid-input case. §6 does not authorize replacing every revision’s slot with a timeline-wide value.

Either decode each entry’s slot independently or explicitly establish an immutable-slot invariant. Future revisions must not supply missing metadata to earlier entries.

### 3. Later corrections can still reorder earlier event deliveries

**Where:** `v2-Resolve.lean:49–51,129–137`; `v2-Sim.lean:215–227`.

Filtering `Stored.keys` by `V` fixes the previous **beyond-V** example. It does not fix revisions fetched after query time but within `V`.

Take event-source originals `A₀` and `B₀`, sharing source, coin, knownAt and slot, but holding different values:

```text
store 1: [A₀, B₀]
store 2: [B_F, A₀, B₀]     where t < F ≤ V
```

`B_F` is an ordinary differing correction of B, delivered at `F`. Both stores have exactly the same revisions fetched by `t`, in the same relative order.

Nevertheless:

- Store 1 enumerates keys `[A, B]`; the earlier delivery order is `A₀, B₀`.
- Store 2 enumerates keys `[B, A]`; the earlier delivery order is `B₀, A₀`.

Because event ties use resolver position, the machine holds different values before `F`.

`Trusted.canonical` does not require chronological or append-only stored ordering. This counterexample satisfies its column constraints.

A stable ordering contract must be enforced or assumed explicitly, with compatibility addressed for C7.4. Neither L8 law covers this cross-key channel.

### 4. Final-revision execution can alter decisions before the correction was recorded

**Where:** `v2-Sim.lean:188–224,302–368,399–409`; `RULES.md:161–163`.

The implementation faithfully follows the explicit execution exception: bars and rates come from final revisions, without checking their knownAt against execution time.

Consequently, a correction fetched at `F` can change, before `F`:

- fill prices or whether a bar traded;
- funding charges;
- marks, liquidation and equity;
- subsequent order quantities, which use that equity.

The decision machine can receive exactly the same economic input values through time `t < F`, yet order sizing differs because historical execution used the later final revision.

**This is authorized by revised §6, not a conformance defect.** It nevertheless defeats an unrestricted recorded-time non-leakage claim. `L1_decisions` does not prevent it: its separate `execView` equality premise fails.

The necessary distinction is between:

- later-recorded evidence of **the venue state actually applied at event time**, explicitly permitted here; and
- arbitrary later revisions influencing historical outcomes.

`venueState : Bool` and `Trusted` authenticate an attestation, not its truth. That external verifier obligation is essential. Do not describe the system as generally invariant to later-recorded information without this exception.

### 5. Future observations can determine whether an earlier run produces output

**Where:** `v2-Sim.lean:435–484`.

Run admission scans the entire resolved observation array, not just observations available during the evaluated period.

For example, append a provider correction fetched at `F` after the run’s last tick. Its availability rule succeeds, but a required role cell is missing or unparsable:

- it is a non-retraction delivery with `role = none`;
- `roleOk` rejects it;
- the entire historical run returns `R_BINDING`.

Without that future correction, the earlier run can succeed. Unlike a **rule rejection**, a role-payload failure is not converted into a timed retraction.

Scope checking also has a retrospective component: `readFrom` assigns execution-time reads to role observations without testing `o.final`, even though execution uses only final records.

Global validation may be intentional, but then causal delivery does not imply causal **output/admission**. This distinction matters wherever rejected runs affect discovery selection.

### 6. Correction detection still reads values outside the certificate’s declared inventory

**Where:** `v2-Resolve.lean:68–73,109`; `v2-Source.lean:94–100,249–255`.

`differs` examines every non-excluded observed column. Certificate matching authorizes only `Decl.controls`; value grants cover only `Decl.values`. An otherwise-unused column `x` need belong to neither.

This no longer changes the ordinary key’s visibility **before** the correction’s fetchedAt. It can still change decisions afterward:

1. Key A delivers weight `1`.
2. Key B later delivers weight `2`.
3. A subsequent A revision has unchanged declared inputs but changes only ungranted `x`.

If `x` is unchanged, the revision adds nothing and the machine retains B. If `x` changes, A delivers again and replaces B in the source/coin held state.

Thus an ungranted value controls a decision-relevant delivery. This behavior follows §6’s all-observed-column comparison, but exceeds the stated certificate inventory.

Authorize that comparison inventory explicitly as controls, or revise the comparison semantics. It is not harmless merely because it only creates a later delivery.

### 7. Duplicate-key validation and timeline grouping use different identities

**Where:** `v2-Resolve.lean:45–58`; `v2-Resolve.lean:172–174`.

`validAt` detects duplicates by:

```text
(entity, event, fetchedAt)
```

but `eligible` groups revisions by:

```text
(coin, event)
```

Two revisions with different `entity` strings, both mapping to `some 0`, and equal event/fetchedAt therefore pass `validAt` and enter the same timeline. Their relative order can determine the delivered result, despite §6 rejecting fetchedAt ties for one key.

Neither `Registry.Valid` nor `Trusted.canonical` establishes the entity-to-coin correspondence needed to exclude this case.

Validation must use the resolver’s key identity, or the trusted boundary must enforce a sufficient mapping invariant.

## Everything else — short list

- **Correctly repaired:** ordinary correction/revert bounds, timed tombstones and rule-rejection retractions, re-listings, predecessor-knownAt bounds, dependency-name uniqueness and checked-rule admission.
- **Law assessment:** no concrete false statement found. The revised L8 formulas appear consistent with the implementation; the counterexamples above expose missing guarantees, not contradictions of those formulas. `deliveryPrefix` also contains mutable `final` flags, making its equality stronger than equality of historical economic inputs.
- **C7.4:** single-revision successful observations have the old rule/derivation time, payload and final execution record. Full v1 run/error/order equivalence remains unverified from these attachments.
- **Remaining conformance boundaries:** retraction timestamps bypass range checking (`v2-Resolve.lean:116–119`); `Cell.sameValue` does not equate `.int 1` with numeric binary64 `1`; full JSON validation and §7 rejection diagnostics remain outside this resolver.
- **Intentional exceptions/limits:** first observations may backdate before fetchedAt; unusable lineage members are discarded when another succeeds; a retraction of an older key becomes the latest source/coin observation and can clear the held input.
- **Freeze discipline:** record any resulting definition, statement or safety-contract changes as dated revisions before judging dependent proofs. **Static review only; Lean was not executed and no files were edited.**
