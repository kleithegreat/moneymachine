## Verdict

1. **Not both gaps are closed.** Concrete revision selection closes the arbitrary value-driven choice between stored revisions. **Temporal leakage remains**, including through suppression. Correction detection also preserves an ungranted-value channel that can change decisions.
2. **`Resolve.lean` is not faithful over all inputs admitted by the Lean.** Its ordinary selection and arithmetic are substantially correct, but required validation invariants are missing, and derived bounds have a concrete defect.
3. **`L8_known` is false as written**, even with `Registry.valid = true`.
4. **Do not freeze revision 10 yet.** Blocking findings follow.

## Blocking: duplicate dependency names break derived bounds and falsify `L8_known`

**Where:** `v2-Source.lean:78–87`; `v2-Resolve.lean:84–98`; `v2-Laws.lean:243–247`.

`Registry.valid` does not require dependency names to be unique. `effectiveKnown` constructs one time per dependency, but later retrieves times using the **first matching name**, not the corresponding dependency.

### Counterexample

Use three held declarations, with no cycles:

| Source | Rule | Dependencies | Single revision’s rule input |
|---|---|---|---|
| 0 | `field "t"` | none | `t = 0` |
| 1 | `field "t"` | none | `t = 100` |
| 2 | `dep "d"` | `(source 0, name "d", lag 0)`, `(source 1, name "d", lag 0)` | upstream entry `"d" ↦ [(0, 0)]` |

Every source has one non-tombstone revision at coin `0`, event `0`, fetchedAt `0`; take `V = 0`. There are no corrections. Other declaration fields can satisfy every registry check.

At source 2:

```text
ds = [("d", 0), ("d", 100)]
rule evaluation = 0
first dependency bound = 0
second dependency bound = 0   -- find? retrieves the first "d" again
effectiveKnown ... 3 2 0 0 = some (.ok 0)
```

But:

```text
effectiveKnown ... 2 1 0 0 = some (.ok 100)
```

Instantiate `L8_known` with `fuel = 2`, the second dependency, its upstream key `(0, 0)`, and `t = 100`. Its conclusion includes **`100 ≤ 0`**.

This is both:

- a **false law**, not merely an inadequately strong statement; and
- an availability leak: a derived decision input can arrive before a contributing upstream input.

**Required closure:** reject duplicate dependency names and bind each computed time/bound to its dependency without ambiguous name lookup. Merely adding the existing `Registry.Valid` hypothesis to the law would not fix it.

## Blocking: future controls can still change earlier decisions

**Where:** `v2-Resolve.lean:45–66,79–111`; `v2-Laws.lean:241–247`.

### Later tombstones and rejected revisions suppress earlier inputs

Take an ordinary source key with:

- an original revision, available at `0`, containing weight `1`;
- another eligible revision fetched at `F`, with `t < F ≤ V`.

Change only the later revision’s tombstone flag:

- **false**, with identical observed columns: it is not a correction; its rule can yield `0`, so weight `1` is delivered before `t`;
- **true**: `select` returns `none`; the key has no observation, including before `t`.

Thus a control recorded after decision time determines whether an earlier decision receives an input. A later selected revision whose rule rejects similarly suppresses the older usable revision.

**This follows RULES.md’s snapshot selection and no-fallback semantics. It is not an implementation divergence.** It does, however, leave the second review gap open. Bounds on emitted observations cannot establish causality for omissions.

`L8_known` says nothing about tombstones, rejected evaluations, or the availability of controls responsible for suppression. Its “never before what it was resolved from” description therefore overstates its guarantee.

**Required closure:** either supply a temporal-prefix guarantee covering suppression, with corresponding semantics, or explicitly narrow the safety claim to retrospective snapshots. Adding `knownAt ≥ selected.fetchedAt` alone does not repair suppression.

### Even revisions beyond `V` can change event delivery order

`Stored.keys` uses **all stored revisions**, not eligible revisions, to establish first-appearance order (`v2-Resolve.lean:48–50`). `resolveAll` preserves that key order. Event sources then use resolver position as their delivery tie-breaker (`v2-Sim.lean:220–226`).

For example:

```text
store A: [A₀, B₀, B_future]
store B: [B_future, A₀, B₀]
```

Let `B_future.fetchedAt > V`. Both stores have exactly the same eligible revisions, in the same relative order, and select the same payloads and knownAt values. Nevertheless, their resolved key orders are `[A, B]` and `[B, A]`.

If A and B share coin, knownAt and current event slot, their final held observation—and hence the event input—differs.

No stored-order invariant in `Trusted` excludes this construction. This is an additional temporal/order channel, although RULES.md itself does not specify cross-key enumeration order.

## Blocking: correction detection permits ungranted values to gate decisions

**Where:** `v2-Resolve.lean:71–74,95`; `v2-Sim.lean:450–472`; draft §1.

Use one ordinary-source key:

| Revision | fetchedAt | rule time | weight | otherwise-unused column `x` |
|---|---:|---:|---:|---:|
| earliest | 0 | 0 | 1 | 0 |
| selected | F | 0 | 1 | 0 or 1 |

Take a decision time `t < F ≤ V`.

- With selected `x = 0`, there is no correction: knownAt is `0`.
- With selected `x = 1`, correction detection raises knownAt to `F`.

The weight remains `1`, but its presence at the earlier decision changes. `x` need not be a declared field or role column, so it need never appear in `Decl.values` or any granted access.

**This comparison is required by RULES.md**, so it is not a resolver-conformance defect. It nevertheless contradicts the draft’s unrestricted claim that a value influences a run only through a read observation. “Can only delay that key” is not an outcome-safety argument: delay can change undefinedness, orders and returns.

The original **revision-choice** gap is closed; unrestricted **value-to-outcome non-interference** is not. The correction exception needs an explicit authorization/safety contract, not an assertion that it is harmless.

## Blocking: “checked rule” and canonical stored bytes are not enforced premises

**Where:** `v2-Source.lean:15–24,38–49,78–87,236–261`; `v2-Resolve.lean:22–41,69–99,141–152`.

Comments call these checked rules and stored bytes, but neither `Registry.valid` nor `Trusted` establishes the required decoding/checking invariants.

These are the remaining conformance divergences and missing premises:

### 1. Unchecked rules can read unauthorized columns

`Registry.valid` does not check rule typing, constants, operator restrictions, lower-bound sets, declared dependencies, or field membership in `Decl.times`.

For example, declare:

```text
times = ["fetchedAt"]
rule = field "hidden"
```

A certificate can authorize every `Decl.controls` column without authorizing `"hidden"`. Nevertheless, resolution reads `"hidden"` and uses it to determine availability. The registry passes its Lean checks.

Likewise, negative durations, invalid floor periods, malformed `max` arities, and rules missing required dependency lower bounds are representable without pre-row rejection. An empty `max`, for example, becomes per-row `.unusable`, rather than a rejected rule/binding.

This is an authorization gap as well as a checking-conformance gap.

### 2. §5’s full-text validation and `R_ROW` are absent

`RuleExpr.eval` consumes decoded lists, not row/dependency JSON texts. `RuleError` has no `R_ROW`; dependency values are already integers.

Consequently, it does not implement:

- reading both texts fully before evaluation;
- rejecting duplicate decoded object keys, malformed ignored members, invalid outer objects, or other JSON violations;
- the full dependency-field absent/type/error interface.

For example, a represented row containing two `"t"` entries returns the first entry; RULES.md requires `R_ROW`.

An external parser can discharge these obligations, but its correctness and the correspondence to these structures must be premises. Conformance tests alone do not establish them in the stated boundary.

### 3. Stored metadata can be shadowed or detached from authorized columns

The rule row is:

```lean
sel.cells ++ [("fetchedAt", .int sel.fetchedAt)]
```

Lookup takes the first matching entry. Thus a `"fetchedAt"` already in `cells` overrides the trusted recorder timestamp. A single revision with actual fetchedAt `F` but cell `"fetchedAt" = 0` can resolve at `0` under `field "fetchedAt"`.

Similarly, no invariant binds `Revision.coin`, `event`, `fetchedAt`, or `tombstone` to the declaration’s authorized extraction columns. Nor does validation ensure the declared control inventory includes all actual selection controls.

If `cells` is intended to exclude reserved metadata and metadata extraction is canonical, enforce or assume that explicitly.

### 4. Correction comparison is not the specified general value comparison

`isCorrection` compares **all cell names**, without excluding `fetchedAt`, `source`, `hash`, or the tombstone column. Such entries are not forbidden by the Lean representation.

It also uses constructor/bit equality for `Cell`, not general JSON-value equality. For example, floating positive and negative zero represented by different `.num` bits compare unequal, although their numeric values are equal. Arbitrary exact JSON numbers, arrays and objects are not represented by this `Cell` type.

These differences can spuriously classify a revision as corrected and delay it. The absent-as-null treatment itself is correct.

### 5. Dataset invalidity is only checked for mapped keys

`Stored.keys` discards every revision with `coin = none`; `validAt` consequently never checks duplicate eligible fetchedAt values for those keys.

An invalid duplicate pair outside U therefore does not invalidate the dataset. RULES.md’s duplicate-revision invalidity condition is dataset-wide, not restricted to emitted entities. The representation also loses the outside entity identity needed to perform that check.

### 6. Range checking does not validate each correction bound independently

Expression-node checking is correct for checked expressions. However, correction handling first computes:

```lean
max k sel.fetchedAt
```

and only checks the resulting time.

Let `B = 2^62`. Use an earliest revision fetched at `-B-2`, a differing selected revision fetched at `-B-1`, and rule result `0`. The correction bound is out of range, but the resolver returns `0`.

RULES.md says each bound is computed exactly and an out-of-range value rejects with `R_OVERFLOW`. A stored-metadata range invariant would exclude this case, but none is present.

For valid nonnegative lags and in-range upstream times, the derived addition’s overflow cannot be hidden by the subsequent maximum; that ordinary path is sound.

### 7. Rule-byte/version authentication is not expressed

`Meta.version` is only a cutoff. There is no pinned rule-byte/hash mapping, or invariant authenticating `Decl.hash` against the declaration containing `Decl.rule`.

As written, changing a rule while retaining the declaration hash can preserve certificate matching and every `Trusted` field, provided the loader follows the changed `resolveAll`.

This does not require proving SHA-256 inside Lean. It requires an explicit authenticated-decoding/pinning premise, analogous to the intended content-identity premise.

## Everything else — short list

- **Correct on canonical, checked inputs with unique dependency names:** maximum-fetchedAt selection; duplicate rejection for mapped eligible keys; selected-tombstone suppression; earliest-revision comparison with absent-as-null; left-to-right expression rejection; Euclidean floor; ordinary correction/derived maxima; and rejection without fallback. Query visibility is enforced downstream by delivery.
- **Cycles:** `resolveAll` itself does not reject cycles as invalid datasets; fuel exhaustion makes rows unusable and can produce `some #[]`. `run` instead rejects the registry earlier with `R_INVALID`, rather than the draft’s resolver `R_BINDING`.
- **Partial lineage:** upstream failures are silently discarded when another referenced upstream succeeds. §6’s “no usable upstream knownAt” permits that existential reading, but it supplies no guarantee that **every** contributing revision was usable; clarify before claiming all-contributor causality.
- **Law strength:** `L8_selection` states equality of selected/earliest timestamps, not identities or positions; `L8_known` omits its advertised rule-result lower bound. Apart from the concrete `L8_known` counterexample above, I found no additional law-formula counterexample in the supplied definitions.
- `resolveAll` erases per-key rejection diagnostics and uses only the first declared role entry; neither the full §7 diagnostic interface nor general multi-role capability handling is provided.
- Verifier truth, venue-state attestations, complete derived lineage, authentic hashes and production conformance remain external obligations. **Static review only; Lean was not executed. No files were edited.**
