# Review: revision 7 still has blocking safety-contract gaps

**R4–R7 are corrected at the supported `run` entry point. N4’s admission restrictions are removed. However, R1–R3 are not fully closed by the Lean:** `Trusted` does not express several properties attributed to it, and the new value/control split still does not establish authorization for every actual loader read.

I found **no remaining counterexample to the two corrected theorem statements, and no additional false Lean theorem statement** in this static review. `L5_certified` appears correct as a formula, but its conclusion is substantially narrower than its description.

This review covers the supplied files only. I did not execute Lean or the migration suite. Expected `sorry` proofs are not findings. No files were edited.

## 1. Disposition of every previous finding

| Finding | Disposition in revision 7 |
|---|---|
| **R1: authoritative certificates, bytes and observations** | **Partially closed; blocking gaps remain.** `Trusted` supplies useful equalities and issuance membership, but not resolver correctness, effective-availability correctness, read confinement, current admission position or build-pinned policy/verifier. See B1–B2. |
| **R2: incomplete read footprint** | **Partially closed; blocking gap remains.** Declared entity/revision/tombstone controls are now explicitly authorized before resolution. Removing finiteness checks also eliminates admission’s numeric inspection. But resolver payload decoding, discarded values and upstream value reads are not covered by a complete read contract. See B3. |
| **R3: execution before `knownAt`** | **The Boolean admission check is closed; the semantic attestation is not.** Providers must have `venueState = true`. Nothing in `Trusted` establishes that their resolved role payloads actually satisfy that attestation. The explicitly accepted execution-clock exception also still permits later-known values to affect decision quantities. |
| **R4: unvalidated entry point** | **Closed for `run`.** `v2-Sim.lean:489–493` checks registry, policy and program text before admission. `runProgram` and `admit` remain unchecked internal interfaces; they must not be presented as independently safe entry points. |
| **R5: false `L5_shape`** | **Closed.** `sameShape` now distinguishes `none`, bar and rate constructors (`v2-Spec.lean:229–232`). The previous sentinel counterexample no longer works. |
| **R6: false `L5_text`** | **Closed for the reported defect.** The theorem now requires `reg.Valid` (`v2-Laws.lean:194–196`). I found no replacement counterexample in the supplied checker. |
| **R7: false admission-error biconditional** | **Closed.** `L5_order` states the correct implication and the no-admission-failure/evaluation equality. The draft adopts it rather than repeating the false converse. |
| **N4: narrower observation admission** | **Closed in Lean.** Finiteness, absolute-grid and event-slot-uniqueness restrictions are gone. The bar projection enforces the old bar-duration relation by construction. Some contradictory prose remains; see §5. |
| **N5: over-wide accesses and single-grant coverage** | **Still present, non-blocking.** Both conservative restrictions remain unchanged. They can prevent C7.4 acceptance, but do not authorize extra use. |
| **N6: cross-source delivery order** | **Not changed in Lean; conditionally addressed by the proposed comparison format.** Numerical interleaving remains unobservable here. Byte identity depends on what was actually frozen as the delivery artifact. |
| **N7: listing intervals** | **The proposed migration requirement is correct, but not established by Lean or supplied evidence.** Missing reconciliation evidence is non-blocking under the requested classification. An actual mismatch affecting eligibility or accounting is blocking. |

## 2. Blocking findings

### B1. `Trusted` equates the loader to a resolver without specifying the resolver’s safety properties

**Where:** `v2-Source.lean:224–237`; `v2-Laws.lean:199–211`.

The crucial field is:

```lean
resolve : ∀ req, ld.resolve req = resolver st req
```

But `resolver` is an unrestricted parameter. Neither `Trusted` nor `L5_certified` requires that it:

- obtains output values from the corresponding bound stored cells;
- computes certified effective availability;
- preserves field/role projections of the same stored column consistently;
- bounds derived availability by the necessary upstream availability and delay;
- reads only required datasets and declared dependencies;
- produces role values that satisfy `venueState`.

Calling the parameter “RULES.md §6” in a comment does not express these obligations.

#### Counterexample satisfying the written `Trusted` fields

Take valid declarations, roles, policy and program text, with genuine issued certificates and matching bindings for all required sources.

Let:

- every stored row of every **required** source precede `holdoutStart`;
- an additional, unrequired stored source contain holdout data;
- `resolver st req` read that additional source and emit its value as an observation of a required source, with an early supplied `known`;
- `ld.resolve := resolver st`;
- `ld.rows` be exactly the required sources’ stored event-time inventory.

Give the emitted observation sufficient grants and ordinary shape. Supply normal provider observations so a decision can use it.

All written `Trusted` fields can hold:

- `rows` is complete for `req`;
- `resolve` equals the supplied resolver;
- identities, certificate hashes, issuance and supersessions are unchanged;
- the frozen holdout configuration is correct.

Nevertheless:

- stage 1 checks only required dataset identities;
- stage 2 checks only required stored rows;
- resolution obtains holdout data outside that set;
- the relabelled, early-known observation can reach a decision.

The same construction substitutes a value genuinely available at hour 100 while assigning its output observation `known = hour 4`.

**This does not falsify the Lean formula of `L5_certified`.** Its formula establishes identity and row-time properties for the required datasets, and equality with the supplied resolver’s output. It does not establish that every dataset actually read was required, or that output availability is correct.

**Required closure:** state the resolver’s provenance, availability, dependency-confinement and role-coherence obligations precisely, and make them assumptions of the trusted boundary. They may still be discharged externally; a formal proof of the entire production resolver is not necessary. The obligations themselves must exist.

---

### B2. Authentic ledger contents do not prevent admission-state rollback or policy substitution

**Where:** `v2-Source.lean:142–151,173–188,229–237`.

`Trusted` authenticates the supersession list, but not `adm.position`. It also does not connect `adm.policy` or `adm.verifier` to authoritative build-pinned values.

#### Counterexample: new evaluation using a superseded certificate

Let the genuine ledger contain:

```text
certificate k was issued
k was superseded at position 10
```

For a new evaluation, supply:

```text
adm.supersessions = led.supersessions
adm.position      = 9
```

Then the supersession test:

```lean
pos ≤ m.position
```

is false for position 10, so `Meta.valid` can accept `k`.

Every written `Trusted` field can still hold, even with a genuinely correct resolver and certificate hash function. There is no field requiring the admission position to be the authorized current ledger position, nor a distinction between reproducing an old experiment and admitting a new one.

This matters if supersession withdrew an invalid availability, mapping or certification claim: the old certificate can again authorize a leakage-producing evaluation.

Similarly, a genuinely issued certificate under an obsolete policy/verifier passes `matches` when the supplied metadata simply repeats those obsolete hashes. The comment that these fields are compiled into the build is not an invariant of `Trusted`.

**Required closure:** authenticate the admission snapshot, including its position and build-pinned policy/verifier. If historical replay is supported, distinguish it from new evaluation and constrain it explicitly.

---

### B3. The value/control split authorizes declared controls, not every actual payload read

**Where:** `v2-Source.lean:33–39,118–121,153–157,224–237`; `v2-Sim.lean:450–472`.

The control-column change is substantive and useful. In particular, a missing declared tombstone or entity column now causes stage-1 refusal.

However, value grants still cover only:

```text
observations for which readFrom returns some time
```

There is no complete account of payload values opened while resolving those observations.

#### Counterexample: decoded but undeliverable value

Use an otherwise harmless successful run and one ordinary non-role observation:

```text
known > lastTick
role  = none
```

Its certificate authorizes all declared controls but has no value grants.

A resolver may decode its numeric payload when constructing the resolved array. Nevertheless:

```text
readFrom observation = none
```

so it generates no access and `inScope` passes.

Revision 7 correctly stops `admissible` from inspecting the numeric value. It does **not** prevent the resolver from having read it.

The same missing contract covers:

- payloads decoded from rejected revisions;
- discarded records;
- upstream value cells read during a runtime derivation;
- extra payload reads by `rows` that leave its returned timestamp inventory unchanged.

`Trusted.rows` and `Trusted.resolve` are extensional output equalities. They cannot distinguish an implementation that opens only authorized columns from one that opens additional columns and returns identical outputs. The staging obligations remain comments, not fields.

Deleting lineage is safe **only if** the resolver is constrained to dependency-control reads and separately authorized value reads. That restriction is not currently expressed.

**Required closure:** either enforce selective authorized decoding or model a complete read trace/footprint, including resolver reads, and require its authorization. For staging claims, include an explicit operational implementation obligation.

If grants intentionally authorize only downstream *use*, while arbitrary payload decoding is permitted, say so. That is not the requested guarantee that an admitted run reads only authorized data.

## 3. Availability and execution: what is and is not guaranteed

### Ordinary DSL inputs

For a correctly attributed observation, the supplied `known` is respected:

- `Ctx.deliver` stops at observations later than the delivery tick;
- `MState.deliver` independently rejects later-known observations;
- checked programs use the registry’s held/event flag.

I found no ordinary-input path around these checks through supported `run`.

The unresolved issue is whether that supplied `known` is the certified effective availability—B1—not the delivery comparison itself.

### Execution can still affect decisions before a record’s `knownAt`

For example:

1. A position fills at hour 8.
2. A settlement record has event time hour 9 and `known = hour 100`.
3. Execution applies its rate during the step ending at hour 12.
4. Normal, timely provider observations satisfy freshness at hour 12.
5. The changed equity changes the hour-12 order quantity.

`venueState = true` allows this; it does not delay settlement.

**Under revision 7’s expressly accepted venue-state exception, this is not an additional blocking finding.** It preserves version-1 execution behavior, and `L1_decisions` is the appropriate restricted non-interference statement.

But the blanket statement “no value reaches a decision before its `knownAt`” remains false. The accurate claim distinguishes:

- input, decision-price and freshness reads through timely delivery;
- execution-effective venue state affecting the account and therefore sizing.

The separate blocking issue is that the current trusted contract does not establish the truth or applicability of the venue-state attestation to the resolved payloads.

## 4. Law truth and version-1 strength

| Law | Assessment |
|---|---|
| **L1_values / L1_simulator** | No counterexample identified. The per-source latest store and schedule retain the old machine guarantees under the natural migration mapping. |
| **L1_decisions** | No counterexample identified. It retains version 1’s execution-view qualification; it is not a blanket `knownAt` theorem. |
| **L2_units / L2_checker** | No counterexample identified. Registry correspondence is now explicit, and the instrumented input uses the input’s unit rather than the checker’s node-type array. |
| **L3_rewrite** | The substantive version-1 conclusions remain: WF preservation, node correspondence and trace equality. It retains `p.WF reg`, rather than narrowing to checker-produced programs. Source preservation and admission-inclusive equality are additions. |
| **L4_fills / L4_orders** | No counterexample identified. Their execution conclusions remain on `evaluate`, not merely on certificate-approved runs. Removing the absolute-grid restriction does not invalidate the bar-duration relation, which `barRow` constructs directly. |
| **L5_shape / L5_text / L5_order** | The reported false statements are corrected. |
| **L5_certified** | Appears true as written mathematically, but does not establish all the safety properties attributed to it. B1–B3 concern that gap, not a counterexample to its formula. |
| **L6_bounded** | **Formally narrower than version 1.** Version 1 quantified over arbitrary `Program`, `Market` and policy. Revision 7 states only that the validated text-entry `run` cannot return `.bound`; invalid inputs can be rejected before evaluation. The numerical hypothesis remains only `N.Bounded`, correctly. |
| **L7_reads** | No counterexample identified. It states the latest-delivered held/event read, including the finite filter and undefined result. |

### Non-blocking law-strength issue: L6

The L6 restriction does not itself demonstrate an incorrect outcome, so I classify it **non-blocking**. Nevertheless, C7.7’s “older or weaker statement does not count” requirement should not be satisfied solely by the wrapped theorem.

Retaining the unrestricted evaluator bounded-loss statement, with the public-`run` theorem as a corollary, would preserve the old scope. The step’s bounded-loss logic does not appear to need the new admission checks.

L5’s old unavailable-only biconditional also cannot be transplanted without qualifications: new earlier checks can now produce other refusals. The positional formulation is the correct replacement, not a newly false law.

## 5. Non-blocking findings and C7.4

### N5 remains: conservative scope can reject baseline runs

`accesses` still requires every selected observation’s value columns through `useEnd`, even after replacement, and one grant must cover the entire interval.

Thus both previous examples remain:

- an old held value’s grant expires after its last actual use but before `useEnd`;
- adjacent grants jointly cover all uses, but neither individually covers the aggregated access.

These are **non-blocking safety-wise** because they refuse rather than authorize extra data. They remain C7.4 risks. The annex’s instruction to refine accesses rather than widen evidence is correct.

### N6 remains conditional: global delivery bytes differ

The Lean still globally orders observations primarily by `known` (`v2-Sim.lean:224–226`), whereas version 1 drains funding, bars and events separately.

For two observations ready at one tick:

```text
funding known = tick − 1
bar known     = tick − 2
```

version 1 delivers funding then bar; version 2 delivers bar then funding.

The numerical machine is insensitive to that cross-source shuffle. Therefore this is **non-blocking under the requested outcome classification**.

For C7.4:

- If the frozen baseline artifact genuinely consists of independent per-source streams, the proposed comparison can preserve its bytes.
- If it records the global delivery sequence, these bytes differ. Regrouping afterward is not an identity-only projection.

The supplied files contain neither the frozen artifact nor the comparison procedure. The draft’s proposed annex alone does not demonstrate which case applies.

Within each source, the revised tie ordering matches the intended version-1 behavior, provided resolver position preserves the original event-array order.

### N7: exact listing-interval equality is required, not established

The annex now gives the right rule: exact equality with the fixed baseline loader, or migration blocked.

Neither `Trusted` nor admission checks that correspondence. For example:

```text
baseline interval end = hour 12
new interval end      = hour 20
decision boundary     = hour 8
```

The eligibility condition `8 + 2·BAR ≤ end` changes from false to true. With fresh providers and a defined nonzero weight, decisions can differ.

That is a counterexample to **unconditional migration equivalence**, not evidence that the fixed corpus actually contains this mismatch.

- Missing reconciliation evidence: **non-blocking**.
- An actual mismatch changing decisions or returns: **blocking**.

### Remaining documentary inconsistencies

These are **non-blocking**, but should not guide an implementation differently from the Lean:

- `laws-v2-draft.md:90–91` still prescribes finite role columns and absolute-grid bars at admission, although those checks were removed.
- `laws-v2-draft.md:96–97` still says grants cover availability/control columns and upstream records, contradicting the new dataset-level control authorization.
- Several ledger entries still cite deleted `Loader.Faithful`, `Decl.columns`, or stale section numbers.
- `L5_certified`’s description says no holdout dataset was opened; its formula establishes this only for the required dataset identities, not every actual resolver read.

## Exit recommendation

**Do not freeze the complete safety claim yet.** The remaining blockers are:

1. missing resolver provenance, availability and read-confinement obligations;
2. unauthenticated admission position and build policy/verifier;
3. missing authorization coverage for actual loader payload reads.

The two previously false theorem patterns are fixed. The conservative footprint, comparison-format evidence, interval reconciliation evidence and L6 statement scope are **non-blocking under the requested classification**, although they still matter for C7.4/C7.7 acceptance.
