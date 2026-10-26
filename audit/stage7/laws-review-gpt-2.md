# Review: revision 6 is not ready to freeze

The Lean fixes several revision-5 problems, but **does not yet establish the claimed certification, holdout, or availability boundary**. I also find **two false Lean theorem statements**: `L5_shape` and `L5_text`.

This is a static review of the supplied files. I have not executed Lean or the migration suite. `sorry` is expected at this stage; the findings concern definitions and statements, not missing proofs. No files were edited.

I use **blocking** for leakage/false-discovery risks or false statements. A non-blocking semantic issue can still prevent C7.4 or C7.7 acceptance.

## 1. Disposition of B1–B7 and N1–N3

| Previous finding | Disposition in the Lean |
|---|---|
| **B1: preflight construction order** | **Partially closed.** `run` now calls metadata checks before `rows`, then resolution. However, `Loader.rows` is an unrestricted function, not a timestamp-only read capability. Its type does not establish what it reads internally. |
| **B2: certified bytes disconnected from observations** | **Open.** `Loader.Faithful` appears only in prose/comments. It is neither defined nor required. Certificate authority and metadata authenticity are also unmodeled. |
| **B3: late execution-role observations** | **Open as a Lean guarantee.** Execution still ignores `knownAt`. The proposed venue-state exception is not represented by a predicate, certificate field, or admission obligation. |
| **B4: omitted control columns** | **Partially closed.** Declared event, slot, availability and role columns now enter observation accesses. Reads involved in resolution, rejected revisions, tombstones and entity selection are not comprehensively represented. |
| **B5: upstream reads outside grants** | **Partially closed.** Supplied lineage entries generate accesses. Nothing establishes that lineage is complete, authentic, or includes every actual transitive resolver read. |
| **B6: empty-window initialization** | **Closed for valid policies and the original scenario.** `useEnd` covers initialization. But `run` does not require `Policy.Valid`; invalid policies reopen inverted access intervals. |
| **B7: event tie order** | **Definition-level fix is correct.** Event ties use resolver position and the machine keeps one latest observation. Migration must still establish that resolver position preserves version-1 array order. |
| **N1: positional failure provenance** | **Original ambiguity closed.** `firstFailure` identifies positions. The draft’s stronger public-result biconditional remains false; the Lean correctly does not state it. |
| **N2: access over-approximation** | **Partially closed.** The erroneous `min known key` start is gone. Overlong footprints and single-grant coverage remain migration risks. |
| **N3: incomplete definitions/signatures** | **Substantially improved, not closed.** Execution definitions and signatures exist, and L3 still uses `p.WF`. But the trusted boundary is absent, domains have narrowed, and two new signatures are false. |

## 2. Blocking findings

### R1. There is no Lean admission boundary connecting authoritative certificates, certified bytes and evaluated observations

**Where:** `v2-Source.lean:111–145,158–194`; `v2-Sim.lean:479–486`; `v2-Laws.lean:3–9`.

The draft says `Loader.Faithful` states the bytes-to-observations invariant. **No such definition exists in the supplied Lean.** Nor does `run` require an equivalent validated loader.

Similarly:

- `Meta.valid` treats presence in `Meta.certs` as issuance;
- certificate IDs need not hash their payloads;
- certificate IDs need not be unique;
- supersessions, ledger position, policy/verifier hashes and the holdout inventory are arbitrary supplied metadata;
- nothing connects `rows` to `resolve`.

The header’s claim that quantifying over arbitrary admissible observations is “the stronger statement” is valid for some structural machine properties. It is **not** a replacement for a certificate-to-data invariant.

**Concrete counterexample**

Use a valid registry, checked program, matching genuine bindings and certificates.

Provide:

```text
ld.rows req    = []
ld.resolve req = well-shaped observations taken from another dataset
```

The substituted observations can contain:

- holdout values;
- invented early `knownAt`;
- values unrelated to the bound dataset.

Choose their keys within the certificates’ broad event grants and provide grants covering the modeled use intervals. Stage 1 passes; stage 2 sees no rows; observation admissibility and scope pass.

A short run can then tick an input using the substituted value. Extending the example with ordinary provider observations makes subsequent decisions depend on it.

There is a separate forgery scenario even with an honest loader: insert a fabricated certificate into `Meta.certs`, make its identity fields match, and omit supersession records. The implemented predicate accepts it as valid.

These are counterexamples to the **supplied model’s safety claim**, not evidence that an external production loader necessarily behaves this way.

**Minimal fix**

Define an explicit trusted admission interface covering:

1. authoritative certificate issuance, IDs, lifecycle and build-pinned policy/verifier;
2. authoritative holdout metadata;
3. complete stored-row inventory;
4. content-identity verification;
5. faithful resolution, effective availability and complete lineage.

Require that interface in safety theorems and in the supported safe-run entry point. External tests can discharge implementation obligations, but those obligations must first exist precisely.

For B1, also distinguish **output shape** from **read capability**. A function returning timestamps can internally open every payload column. Model staged reads operationally, or explicitly place timestamp-only behavior inside the trusted loader contract.

---

### R2. `accesses` is not a footprint of every read performed by an admitted run

**Where:** `v2-Sim.lean:432–475`; `v2-Source.lean:31–36`.

`Ctx.accesses` covers observations selected by `readFrom`, plus their supplied lineage. Resolution and admission perform additional reads.

This problem remains even after supplying honest certificate metadata and faithful dataset resolution.

#### Scenario A: an undeliverable observation is read with no grants

Provide one non-role held observation with:

```text
o.known > c.lastTick
o.role  = none
```

Its certificate has no grants.

Then:

- `readFrom o = none`;
- it contributes no accesses;
- `inScope` passes for it;
- resolution has nevertheless read its payload;
- `admissible` reads its field values to check finiteness.

With otherwise harmless inputs, `run` succeeds. This is an admitted payload read outside the modeled authorization footprint, although that value is not delivered to the DSL.

#### Scenario B: a tombstone controls definedness without an observation access

The resolver reads a tombstone/revision-control column and removes the corresponding record. No resulting `Obs` exists, so no access for that read can be generated by `Ctx.accesses`.

A certificate can grant the live numeric field and the modeled time/control columns while omitting the tombstone column. The run can still consume the tombstone to decide whether an input is defined.

The same structural issue affects discarded revisions and resolver reads that do not survive into a delivered observation.

#### Scenario C: entity selection is not enumerated

`Decl` has event and slot column names, but no entity-key column or explicit certified metadata projection. The loader must determine `Obs.coin`. If this requires reading an ordinary stored entity-key column, that column is not automatically included in `Decl.columns`.

Reading it changes which coin receives a value, including cross-sectional results.

**Minimal fix**

Have loading/resolution produce an explicit, complete read footprint, including reads of:

- undeliverable observations inspected by admission;
- tombstones and rejected revisions;
- entity and revision selectors;
- actual transitive upstream records.

Scope-check that footprint as well as evaluation accesses. Alternatively, prevent those reads through a selective authorized loader.

If some controls are intentionally exempt certified metadata, define that metadata authorization contract explicitly. Binding a whole manifest’s identity does not itself establish column-grant coverage.

---

### R3. Execution can still use a value arbitrarily before its `knownAt`

**Where:** `v2-Sim.lean:126–129,298–307,341–364`; `v2-Source.lean:111–119,168–171`.

The venue-state explanation does not appear in the Lean admission contract.

`Roles.valid` checks declaration capabilities. `Meta.matches` checks identity fields. Neither establishes that a role record is the value actually applied by the venue at its event time.

**Concrete counterexample**

Use an ordinary position filled at hour 8. Supply:

```text
settlement event = hour 9
knownAt          = hour 100
rate             = a finite value
```

Provide matching certificates with broad grants. Use separate normal settlement observations to maintain decision freshness.

The step from hour 8 to hour 12 reads the hour-9 rate directly from `ix.rateAt`, changes cash/equity, and can change later order sizing—long before hour 100.

All implemented observation-shape and scope checks can pass.

Even an authentic venue-state record remains a literal read before its single `knownAt`. Thus the requested blanket prohibition cannot simultaneously describe ordinary version-1 execution and this design.

**Minimal fix**

Resolve the contract explicitly:

- distinguish decision availability from an authorized execution-effective clock;
- require a trusted, precisely specified venue-state attestation for execution-role records;
- state and prove the corresponding restricted non-interference guarantee.

If the requirement instead means **no read whatsoever before the one `knownAt`**, execution must be delayed/gated, and the resulting conflict with version-1 migration must be resolved explicitly. Adding a prose certificate obligation alone does not close the Lean finding.

---

### R4. `run` does not require the validated objects assumed by its safety argument

**Where:** `v2-Sim.lean:479–486`; `v2-Spec.lean:48–65`; `v2-Machine.lean:134–137`.

`run` accepts an arbitrary registry, program and policy. It checks neither `Registry.Valid`, `Program.WF` nor `Policy.Valid`.

This is consequential, not merely an API cleanliness issue.

#### Scenario A: a checked declaration’s event cadence is bypassed

Take a valid event declaration and a delivered observation from an earlier slot. Construct a program input with:

```text
inp.event = false
```

The registry says event, but `MState.input` uses the cached flag in `Input`, not the declaration.

The old observation is then read as held at later ticks. `run` admits this program if its other checks pass. The `p.WF` hypotheses protect L7, but `run` does not establish that hypothesis.

#### Scenario B: an invalid policy permits an expired grant to cover a later read

Let:

```text
wStart = 0
delta  = 2 * BAR
stop   = 2 * BAR
```

There is one simulation step. Therefore:

```text
firstTick = 2 * BAR
lastTick  = 3 * BAR
useEnd    = 2 * BAR + 1
```

Supply a non-role held observation known at `3 * BAR`. Its access interval is:

```text
(3 * BAR, 2 * BAR + 1)
```

This is inverted.

A grant whose permitted use interval is only:

```text
(2 * BAR, 2 * BAR + 1)
```

passes `Grant.covers`: its start is before the access start and its end equals the access end.

Yet evaluation delivers and reads the value at `3 * BAR`, outside that grant. Empty provider streams can keep the simulation otherwise harmless and successful.

**Minimal fix**

Make the supported entry point consume validated registry/program/policy objects, or check their executable equivalents before loading.

Also establish that every generated access has a nonempty, correctly ordered interval; do not rely on a policy invariant that the entry point does not require.

---

### R5. `L5_shape` is false: `sameShape` confuses bars with rates

**Where:** `v2-Spec.lean:225–232`; `v2-Laws.lean:181–186`.

The role summary is:

```lean
bar ... trades  ↦ some (allFinite, trades)
rate x          ↦ some (finite x, -1)
```

It does not encode the constructor.

**Concrete counterexample**

Use two loaders returning observations identical except for:

```text
loader 1: role = bar finiteOpen finiteHigh finiteLow finiteClose (-1)
loader 2: role = rate finiteRate
```

Set the source to the selected **bars provider**.

Both role summaries are:

```text
some (true, -1)
```

Thus `sameShape = true`. Make both loaders constant over `req`, with identical `rows`, satisfying the theorem’s entire shape hypothesis.

But:

- the bar passes `roleOk`: negative trade counts are not rejected;
- the rate fails `roleOk`, because its source is the bars provider.

Give loader 1 sufficient grants. Its `firstFailure` is `none`; loader 2’s is `some (6, .binding)`.

The theorem’s conclusion is false.

**Minimal fix**

Include an explicit role-constructor tag in `sameShape`, or compare matching constructors directly. Do not use a trade-count sentinel as the discriminator.

---

### R6. `L5_text` is false without registry name uniqueness

**Where:** `v2-Laws.lean:189–192`; `v2-Syntax.lean:246–250`.

The theorem does not require `reg.Valid`.

**Concrete counterexample**

Create four declarations:

- source 0: bars provider;
- source 1: settlement provider;
- source 2: held field named `"x"`;
- source 3: another held field named `"x"`.

Bind sources 0, 1 and 2; leave source 3 unbound. Give all declarations no dependencies.

Check a valid program whose weight is input `"x"`.

The checker uses `find?`, so it resolves `"x"` to source 2. Nevertheless:

```text
("x", inputForSource3) ∈ reg.inputs
```

also holds.

Instantiate `L5_text` with that second input. Its premises hold, but source 3 is not delivered, named by the checked program, a provider, or a dependency. It is absent from `required`.

**Minimal fix**

Require `reg.Valid`, or the precise input-name uniqueness condition. The existing successful-check hypothesis does not supply uniqueness.

---

### R7. The draft’s L5.2 biconditional is false; the Lean states a weaker, correct-direction result

**Where:** `laws-v2-draft.md:400–401`; `v2-Laws.lean:162–168`.

The draft states:

```text
run returns error e
iff
firstFailure returns some position with code e
```

But `firstFailure` checks admission only. Evaluation can subsequently abort.

**Concrete counterexample**

Let every admission check pass. Allow a position to fill at hour 8, but omit a settlement rate needed at hour 9.

Then:

```text
firstFailure = none
run          = error settlementMissing
```

This falsifies the draft’s biconditional.

**Minimal fix**

Adopt the actual Lean formulation:

- a first admission failure determines the refusal;
- no admission failure means `run = evaluate`.

Alternatively, state a biconditional about a separately defined admission result, not every error from `run`.

**I am not claiming that `L5_order` itself is false.** It avoids the false converse. The discrepancy must be resolved before freezing one purported specification.

## 3. Law strength and domain audit

| Law | Assessment |
|---|---|
| **L1** | The main machine/simulator/decision conclusions remain recognizable. However, the new admissibility hypotheses exclude version-1-admissible markets discussed below. No additional counterexample to these Lean conclusions was identified. |
| **L2** | The substantive unit/erasure conclusion is retained, with `latest` replacing the old stores. The instrumented input obtains its tag from `Input.unit`; registry correspondence consequently depends on WF/checker soundness. |
| **L3** | Correctly retains `p.WF reg`, not `CheckerAccepted`; numerical obligations remain explicit. Adds source-set and admission-inclusive run equality. The finite-observation admissibility premise nevertheless narrows the old data domain. |
| **L4** | Fill and order conclusions are substantially retained. Stating them on `evaluate` is not a weakening to certificate-approved runs. They do not establish that execution respects `knownAt`. |
| **L5** | The supplied predicates and failure positions are useful, but do not establish authentic certification or faithful loading. `L5_shape` and `L5_text` are false. |
| **L6** | Retains only `N.Bounded` as a numerical hypothesis. It is now a statement about the admission-wrapped `run`; the draft says it is on `evaluate`. For admitted runs, `L5_order` connects the two. Resolve the documentary mismatch. |
| **L7** | Correctly expresses latest-held versus current-slot event reads, under WF and admissibility. It does not cover arbitrary programs accepted by the current unrestricted `run`. |

### N4. New admissibility restrictions narrow version 1’s domain

**Classification:** Non-blocking by themselves in the leakage/false-law sense, but unresolved C7.7 and migration obligations.

**Where:** `v1-Spec.lean:59–67`; `v2-Sim.lean:432–447`.

The new predicate adds substantive restrictions:

1. **Every supplied non-null field must be finite.**  
   Version 1 allowed a non-finite input value and filtered its node output to undefined.

   **Scenario:** An unused premium or volume value is non-finite, while execution fields are ordinary. Version 1 can evaluate a constant strategy successfully. Version 2 refuses the observation at `.binding`.

2. **Bars must open on the absolute four-hour grid.**  
   Version 1 required `event = openTime + BAR`, not `openTime % BAR = 0`.

   **Scenario:** Set `wStart = HOUR`, with bars opening at hours 1, 5, 9, etc. Version 1 admits this phase-shifted market and can trade it. Version 2 rejects its bars.

3. **Event slots must be hour-aligned and unique per source/coin.**  
   The extra slot-uniqueness check is also absent from revision 6’s prose admissibility list.

   **Scenario:** Two distinct event keys map to one slot. The declaration representation permits this, but admission rejects it. For standard migrated events where slot equals version-1 event time, this need not add a restriction; that mapping must be established rather than assumed.

**Minimal fix**

Separate structural hypotheses needed by the laws from production admission restrictions. Preserve the old structural law domain where possible.

For migration, prove or test that the fixed corpus satisfies every new restriction. Do not remove mandatory markets or normalize observable delivery payloads merely to make admission pass.

## 4. Remaining non-blocking scope and migration findings

### N5. Scope remains conservatively wider than actual use

**Where:** `v2-Sim.lean:464–475`.

The revised start time is better, but every selected observation still requires coverage through `useEnd`.

**Concrete scenario**

A held row is read once, then replaced. The program has no windows or other persistent dependence on the old value. Its grant covers its actual reads, but expires before `stop`.

The old row still requires a grant through `useEnd`, so the run is refused.

Additionally, coverage requires **one grant** to cover the whole aggregated access. Adjacent grants covering every actual use do not combine:

```text
grant 1: [100, 150)
grant 2: [150, 200)
access:  [100, 200)
```

**Minimal fix**

Refine the footprint and, if grants denote a union of authorized uses, implement union coverage. Otherwise establish that existing frozen grants cover the conservative footprint. Widening evidence remains prohibited.

---

### N6. Cross-source delivery order is not version-1-identical

**Where:** `v1-Sim.lean:271–276`; `v2-Sim.lean:211–223`.

Version 1 drains funding, then bars, then events at each delivery opportunity. Version 2 globally sorts primarily by `knownAt`.

**Concrete scenario**

At one tick, both are ready:

```text
funding knownAt = tick − 1
bar knownAt     = tick − 2
```

Version 1 delivers funding then bar. Version 2 delivers bar then funding.

The per-source stores and `maxKnown` make this interleaving unobservable to the current numerical machine. Therefore this is **non-blocking under the requested outcome classification**.

However, it is an actual delivery-order difference. If the frozen delivery artifact records execution order, it breaks C7.4 byte identity. The supplied baseline artifacts and comparison procedure are unavailable, so I cannot assert whether that artifact already uses separate streams.

**Minimal fix**

Preserve version-1 delivery order generically, or establish that the already-authorized frozen comparison records independent streams. The draft’s proposed annex cannot silently broaden an identity-only projection into permission to reorder observable records.

Within a source, B7’s event tie correction is right, provided resolver order preserves the original array order.

---

### N7. Listing-interval migration is not reconciled by the supplied definitions

**Where:** `laws-v2-draft.md:374–377`; `v2-Sim.lean:227,325–327,377–378`.

The draft records a change from version-1 loader-derived delisting ends to venue-artifact intervals, but supplies no reconciliation evidence.

**Concrete scenario**

Version 1’s loaded end is hour 12; the venue artifact says hour 20.

At boundary hour 8:

```text
8 + 2 * BAR ≤ 12   is false
8 + 2 * BAR ≤ 20   is true
```

Eligibility, decisions and potentially closeout/funding accounting differ.

**Classification:** The unreconciled mapping is a non-blocking review/evidence gap; **an actual interval mismatch is blocking**, because it can change decisions and returns.

**Minimal fix**

Require exact equality with the intervals produced by the fixed baseline loader for every migrated run. If equality cannot be achieved, report migration blocked; do not repair it by changing the pilot-fixed baseline.

## 5. What can presently be claimed

With valid policies and WF programs, the machine’s ordinary input delivery does prevent consuming an observation whose **supplied** `knownAt` exceeds the delivery tick. The held/event distinction and the original B7 example are materially improved.

That does **not** presently establish:

- that the supplied `knownAt` is the certified effective availability;
- that observations came from the bound bytes;
- that certificates are authoritative;
- that all actual resolver/admission reads are scoped;
- that execution-role reads respect the one `knownAt`;
- that every `run` argument satisfies the invariants used in the laws;
- or that migrated delivery artifacts and admission outcomes remain byte-identical.

**Freeze recommendation:** fix the two false Lean statements, make the trusted boundary and execution-clock exception explicit, close the read-footprint and validated-entry-point gaps, and settle migration against the fixed baseline before C7.7 statements are frozen.
