## Verdict

1. **Not both closed.** Role-payload and slot provenance is closed, conditional on the supplied parsers and `knownAt`. **Selection by ungranted values remains possible.**
2. **I found no counterexample to a Lean law formula, including `L5_controls`.** Its conclusion is weaker than the claimed safety guarantee.
3. **There is also a control-time leakage gap:** `Trusted` permits future-available controls to determine earlier decision inputs.

## Blocking: `controlsOnly` does not bind which stored revision supplies the values

**Where:** `v2-Source.lean:263–283`, especially existential provenance and shape-only comparison.

`Obs.sameShape` compares source, coin, key, slot, availability, value count and role kind. It does **not** identify the stored row or revision supplying the payload. Consequently, output shape can remain constant while an unread value chooses between stored rows.

### Counterexample satisfying `Trusted`

Use an ordinary held source containing:

- **H:** an ungranted numeric value `x`, never emitted.
- **S₀ and S₁:** two revisions with the same entity, event key and effective availability, but field values `0` and `1`. Their revision-control cells may differ.

Have the resolver emit exactly one observation at that fixed key:

- from S₀ when `x` is below a threshold;
- from S₁ otherwise.

Keep the role providers fixed and valid. Grant the selected source’s field at the shared event key and appropriate use interval.

All written obligations can hold:

- **`confined`:** only requested datasets are inspected.
- **`provenance`:** each emitted observation exactly matches its selected stored row.
- **`controlsOnly`:** changing value cells never changes output count or any compared shape component. Choosing another revision is invisible to this comparison.
- **Admission:** only one observation occupies the key; its read values are covered by grants.

Nevertheless, changing **H’s ungranted `x`** changes the delivered weight from `0` to `1`, potentially changing an order and subsequent returns. No read observation carries `x`.

This survives revision 9’s stronger role and slot bindings. It also does not falsify `L5_controls`: admission can be identical while evaluation differs.

**Required closure:** make the selected stored-row identities—including revision identity and order—control-only, and bind each emitted payload to its corresponding selected row. A control-only selection trace plus provenance against that trace would suffice. Shape equality and an independent existential row witness do not.

Thus the draft’s claims that a value influences a run only through a read observation, and that resolution cannot select by a value, remain unsupported as written.

## Blocking: control authorization does not establish temporal causality

**Where:** `v2-Source.lean:118–121,263–283`; `v2-Sim.lean:450–467`.

Even with the row-selection issue fixed, `controlsOnly` permits selection using **all** requested control cells, irrespective of when those controls became available. Provenance binds an emitted observation to its own row’s `knownAt`; it does not require that time to cover other controls used to decide whether to emit it.

### Counterexample satisfying `Trusted`

Use two unrelated keys in an ordinary source:

- **S:** a timely row containing weight `1`.
- **H:** a row whose control flag—for example, a revision/tombstone control—is first available **after the decision tick**. Its event time is before the holdout boundary.

Let resolution emit S only when H’s control flag has a particular value. Do not emit H. Choose S’s ordinary row availability unchanged by H, which is not its dependency.

Then:

- selection genuinely depends only on controls, satisfying `controlsOnly`;
- any emitted S has its correct stored values and own availability, satisfying provenance;
- the certificate authorizes the control column;
- grants cover S, and the event-time holdout check passes.

At the earlier decision tick, S’s presence or absence reveals the later-available flag and can change an order. This is **not** the accepted execution-clock exception: it changes an ordinary decision input.

**Required closure:** constrain resolution temporally as well as by column class. Future-available controls must not alter earlier delivery prefixes. Alternatively, an observation’s effective availability must account for every control used in selecting it, with equivalent protection for omissions and suppression. The current structure states neither obligation.

## Everything else

- The new provenance equalities bind all bar components, integer trade count, settlement rate and slot; provider-kind admission checks complete the previous fix.
- `L5_controls` establishes admission invariance under equal controls and fixed metadata—not payload-selection non-interference or temporal causality. The other laws’ equal-prefix hypotheses do not exclude these constructions.
- Certificate issuance, current ledger position, build pins, verifier truth and production conformance remain external obligations.
- Static review only; Lean was not executed. No files were edited.
