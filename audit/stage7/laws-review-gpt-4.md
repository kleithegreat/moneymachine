## Verdict

1. **B1 is not closed. B2 is closed**, conditional on the external ledger and build-pin parameters being authoritative.
2. **I found no counterexample to a Lean law formula as written.** The blockers below concern missing guarantees; they do not falsify `L5_shape` or `L5_certified`.
3. **The B3 argument does not hold:** a decoded value carried by no read observation can influence resolution’s shape, changing decisions or admission.
4. Two blocking items remain.

### Blocking: B1’s provenance obligation does not bind role payloads or slots

**Where:** `v2-Source.lean:246–250`; `v2-Sim.lean:437–446`.

The field-value equality is substantive, but the role condition only requires:

```lean
o.role.isSome → ((cellOf row col.2).bind value).isSome
```

It checks that mapped stored cells parse—not that their values equal the emitted role payload. Nor does `provenance` constrain `o.slot`.

**Role counterexample satisfying `Trusted`:**

- A genuinely certified settlement row contains rate `0`.
- Its emitted observation has the correct source, key, coin, field values and `knownAt`, but `role = some (.rate 1)`.
- The mapped rate cell parses, so `provenance` holds. `admissible` accepts the role constructor and source.
- Matching grants authorize the mapped `"rate"` column.
- With a held position and nonzero settlement price, execution charges funding at `1`, not the stored `0`, changing equity, returns and potentially subsequent quantities.

The certificate’s genuine venue-state attestation does not help: it authenticates a claim about the stored record, while the emitted role value need not equal that record.

**Independent slot counterexample:**

An event row’s stored slot is an earlier hour, but the resolver emits `slot = some currentHour`, keeping its key, coin, values and correct availability unchanged. `Trusted` permits this; admission checks only slot presence. At the current tick, `MState.input` returns the value instead of `none` (`v2-Machine.lean:134–137`), potentially changing a decision.

**Required closure:** bind each role component—including the integer trade count—to its mapped stored cell, and bind the emitted slot to the declaration’s specified slot semantics. These are missing obligations, not requests to prove the entire production resolver.

### Blocking: B3 permits decoded, ungranted values to control resolution

**Where:** `v2-Source.lean:243–250`; `v2-Spec.lean:186–190,229–232`; `laws-v2-draft.md:53–56,158–163`.

`confined` prevents output dependence on **unrequested datasets**. It does not prevent dependence on ungranted payloads **inside requested datasets**. `provenance` constrains observations that are emitted, but not which eligible rows are selected, omitted, duplicated or ordered.

**Output counterexample:**

Use a required ordinary held source containing:

- **H:** a numeric value `x`, with `known > lastTick` and no role. Thus `readFrom H = none`; H needs no value grant.
- **S:** a different row with fixed value `1`, timely availability and sufficient grants.

Let the resolver always emit H, but emit S only when decoded `x` exceeds a threshold. Supply normal, timely role providers and a checked program whose weight reads this source.

Both branches can satisfy all written `Trusted` obligations:

- Only requested datasets influence resolution.
- Every emitted observation exactly matches its own stored row.
- All emitted keys are unique and all structural checks pass.
- Every read observation is covered by grants.

Nevertheless, without S the weight is undefined; with S it is defined and can produce an order. **No read observation carries `x`, yet `x` changes an output.** Matching issued certificates for each content version suffice; no forgery or rollback is involved.

**Admission-result variant:** conditionally duplicate an otherwise valid, undeliverable H. Its values remain unread in both branches, but duplicate keys cause `.binding` in one branch and permit admission in the other.

`L5_shape` does not exclude either construction. It **assumes** equal resolved shape; it does not establish that changing an unread stored payload preserves shape.

**Required closure:** specify resolution’s selection, multiplicity, ordering and metadata computation, with a non-interference obligation excluding ungranted payloads from those decisions. Blanket permission to decode does not establish permission—or safety—for using decoded values as selection controls.

## Everything else

- **B2 closed:** `position` and `pinned` address the reported rollback and policy/verifier substitution; `L5_certified` uses current ledger position and pinned hashes.
- **L6 scope restored:** the evaluator statement is unrestricted apart from `N.Bounded`, with the public-run guarantee alongside it.
- No additional law-formula counterexample identified. The accepted execution-clock exception, conservative grants, migration evidence and operational staging remain qualifications, not additional demonstrated blockers here.

*Static review of the supplied files; Lean was not executed. No files were edited.*
