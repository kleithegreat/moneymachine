# Review: revision 5 is not ready to freeze

I find **seven blocking issues** affecting leakage, certification, or potentially decisions and returns. Several concern limitations §11 calls harmless. There are also non-blocking specification issues that must be resolved before C7.7’s statements can be frozen.

This is a static review of the supplied files. I have not assumed that the frozen migration corpus excludes a counterexample unless the supplied specifications establish that exclusion.

## Blocking findings

### B1. The executable construction does not enforce the claimed preflight order

**Where:** `laws-v2-draft.md` §§4–5, `Ctx.make`, `Ctx.preflight`.

Preflight receives an already constructed context. Constructing it requires:

- filtering resolved observations;
- sorting them;
- projecting role payloads;
- constructing the execution index;
- computing dependency closure, including indexing declarations selected as providers.

Consequently, the comment “the resolver runs here” is not an executable stage: `Admission.obs` already contains its output, and `Ctx.make` has already processed it. In compiled, strict Lean, putting `.roles` first inside `preflight` does not move it before context construction.

**Failure scenario:** A dataset has a superseded certificate. Its observations are nevertheless resolved and its rate payloads incorporated into the execution index before `.uncertified` is returned. Likewise, an out-of-range provider can reach `reg.decls[s]!` during closure construction before `.roles` is returned.

This violates the payload-free ordering independently of whether a result is eventually emitted. L5.4’s equality of refusal results does not prove that no payload was opened.

**Minimal fix:** Make the stages explicit:

1. validate registry, program and provider metadata;
2. compute `required` without observations;
3. check bindings, identities and certificate lifecycle;
4. perform I8’s narrowly permitted time-column scan;
5. resolve;
6. check observation shape and scope;
7. construct the evaluation context and execution index.

The loader must implement this order; a pure function over already loaded observations cannot establish the loading guarantee.

---

### B2. The model does not connect the evaluated observations to the certified bytes

**Where:** §§3, 5–7, `Admission`, `Admission.WF`, `Admission.matches`, L5.

The definitions check supplied identities, but contain no invariant establishing that:

- `rows` is the complete row inventory of the opened datasets;
- `obs` is the resolver’s output from those datasets;
- its values, keys, slots and effective knownAt correspond to those bytes;
- `certs` is an authoritative snapshot of verifier-issued certificates.

`Admission.WF` establishes only unique certificate IDs, and is not required by `run` anyway. It does not establish the payload-hash or issuance claims in the comments.

**Failure scenario:** Keep genuine bindings and matching certificates, but supply observations from another dataset and `rows := []`. Give those observations valid shape and keys covered by the genuine grants. Every implemented check can pass. Holdout rows omitted from `rows`, or values assigned an invented early knownAt, are then evaluated.

This is a **model counterexample**, not a claim that the production loader necessarily permits this substitution. But L5, as stated without premises, cannot establish the intended certificate-to-data guarantee.

**Minimal fix:** Define the trusted admission boundary explicitly. Use a validated admission type, or require an invariant connecting authoritative certificate records, immutable manifests, complete row inventories and resolver output. Prove or separately validate its constructor. Merely adding `Admission.WF` is insufficient.

---

### B3. Arbitrarily late role observations can affect earlier decisions

**Where:** §§4, 6, role accesses, `Index.of`, execution projections and unchanged simulation phases.

Execution indexes contain role observations independently of their knownAt. Settlement and bar lookups use event/open time, not delivery. Neither admissibility nor scope imposes an availability restriction on those reads.

**Failure scenario:** A settlement provider has a legitimate prospective-only rate for hour 9, first observed at hour 100, with `known = 100h`. Other settlement rows provide normal decision freshness. A position filled at hour 8 is charged that rate during the step ending at hour 12. Its equity and subsequent order sizing therefore depend on the rate long before hour 100.

A matching certificate with grants spanning the run does not prevent this: grants are permission, not an implementation of the row’s availability rule.

**Minimal fix:** Define and enforce the temporal contract for execution-role reads, including when their effects may enter a decision.

There is an important compatibility conflict here: version 1 deliberately reads execution outcomes on event-based clocks—for example, a scheduled bar’s open before that whole bar’s DSL knownAt. Simply requiring `row.known ≤ executionTime` would break ordinary migration.

The draft therefore must distinguish:

- the narrowly specified version-1 execution convention; and
- newly admitted, delayed or corrected observations that can reveal unavailable information.

If the requested guarantee literally prohibits **every** read before the observation’s single knownAt, it conflicts with existing execution semantics. That conflict must be resolved explicitly, not hidden behind the delivery causality check.

---

### B4. Scope omits columns that control availability and input selection

**Where:** §§2–4, `Decl`, `Ctx.accesses`; §11.2.

The omissions recorded in §11.2 are not harmless merely because input delivery checks knownAt.

In particular:

- the event-slot column is absent from `Decl`, so accesses cannot name it;
- `eventColumn` is not generally included in accesses;
- `fetchedAt` is excluded from `times`, although rules can read it and correction bounds use it;
- availability-time columns are included only through the `readable` branch, even when resolution reads them for an execution observation.

**Failure scenario:** An event declaration uses separate columns for its key, availability time and event slot. The certificate grants the numeric field and availability column, but not the slot column. The run nevertheless reads the slot to decide whether the field contributes at the current tick. Changing that uncertified column changes definedness, windows and potentially orders, while `inScope` remains true.

KnownAt bounds when the observation is delivered; it does not authorize the column used to interpret it.

**Minimal fix:** Represent the slot column and enumerate every direct control-column read, including availability inputs and execution selectors. Alternatively, introduce an explicitly certified metadata projection whose scope and provenance cover these reads. An assertion that metadata is harmless is not a substitute for that contract.

---

### B5. Dependency certificates can pass scope checking without covering any upstream read

**Where:** §§4–5, evidence cadence, `Ctx.accesses`, `Ctx.inScope`; §9’s issuance-only replacement.

Evidence sources have no delivered observations, so their accesses are empty. Thus an upstream certificate can satisfy `inScope` vacuously even though the resolver opens its records to compute a derived observation’s knownAt.

`matches` pins certificate identities; it does not establish grant coverage.

**Failure scenario:** An evidence certificate permits use only through time T. A derived source has grants extending beyond T. At a later run time, the resolver rereads the evidence to establish dependency bounds. The upstream certificate remains valid and matching, but its use interval has expired. Its empty access list passes scope checking.

The statement that lineage is certified at issuance does not specify the required implication between upstream grants and **every permitted downstream use interval**.

**Minimal fix:** Either:

- include actual transitive resolver reads in runtime scope checking; or
- define and enforce an issuance obligation proving that every downstream grant is supported by all relevant upstream entity, column, event and permitted-use grants.

If resolution instead consumes an issuance-time attestation without reopening upstream payloads, specify that executable design and its authorization contract.

---

### B6. Empty access intervals permit uncertified initialization reads

**Where:** §§4–6; §11.5.

The assertion that nothing reaches returns does not establish absence of leakage.

**Failure scenario:** Set `stop = firstTick`. Supply a well-shaped, authorized held observation known by that tick, with a matching certificate containing **no grants**.

Every access is discarded because its use interval is empty. Preflight passes. But `evaluate` still calls `start`, which delivers the observation and ticks the program. An input node reads the ungranted value.

The resulting run may have no returns, but it has performed a read forbidden by the certificate. That is within the user’s stated leakage criterion and CERTIFICATES.md’s initialization requirement.

**Minimal fix:** Either skip delivery and ticking for such a horizon, or include the initialization tick in the access model. Do not remove an actual read merely because it produces no return.

---

### B7. The claimed version-1 per-source event ordering is incorrect

**Where:** §§1, 6–7, 9; `v1-Sim.lean`, `Ctx.make`.

Version 1 sorts event rows by:

```text
(knownAt, coin, feed-slot, original-array-index)
```

Revision 5 sorts observations by:

```text
(knownAt, source, coin, key)
```

Within one event source, the former breaks ties by array position, not event key.

**Failure scenario:** At tick `H + δ`, one source has:

1. the current-hour row, known exactly at that tick;
2. an earlier-hour correction, also known exactly at that tick.

Place them in that array order.

- Version 1 delivers the current row and then the older correction. Its single held row is the older event, so the current-hour input is undefined.
- Revision 5 sorts the older key first, then the current key. Its event lookup finds the current-hour observation, so the input is defined.

An expression branching on that input can change orders and returns. Both rows satisfy the frozen Lean market’s admissibility conditions.

The concluding argument in §7 therefore depends on a tie-breaking invariant that the supplied version-1 semantics does not establish.

**Minimal fix:** Preserve the relevant version-1 tie order, or establish—with frozen inventory evidence—that the actual migration datasets and mandatory markets exclude this case. Add the counterexample as a permanent test.

If a required baseline case exhibits it, migration must remain blocked until semantics and requirements are reconciled. Reordering baseline artifacts is not an identity-only projection.

## Non-blocking findings

These do not independently demonstrate a false-discovery or leakage change, but still prevent accepting the draft as a frozen proof specification.

### N1. L5.2 needs a failing-position definition, not just positional prose

Two checks return `.holdout`, and two return `.uncertified`. Consequently, a theorem of the form

```text
run returns check k’s code ↔ preceding checks pass and check k fails
```

is false when expressed solely through the public `Except Abort` result.

**Failure scenario:** Scope fails after all earlier checks pass. The result is `.uncertified`, but certificate matching did not fail.

**Minimal fix:** Define an internal `firstFailure : Option (position × Abort)`. State the positional equivalence about that function, then separately prove that `preflight` returns its code. If L5.2 already intends control-flow provenance, make that provenance an actual definition.

### N2. Access over-approximation remains an unresolved migration risk

For fields, `min known key` can require authorization before the first actual read. Held observations are also covered through `stop` even after replacement.

**Failure scenario:** A row has key 20, knownAt 100, and sufficient grants beginning at 100. Its first read is after 100, but computed accesses begin earlier. A correctly scoped run is refused. Similarly, a replaced held value may require grants extending past its final use.

**Minimal fix:** Compute a sufficiently precise read footprint, or demonstrate that existing evidence already supports every required grant. §11.4 cannot treat widening grants as a general repair: the annex explicitly prohibits repairing migration by widening scope, and evidence limitations remain binding.

### N3. The executable predicates and complete law signatures are not yet specified

The promised later Lean completion includes substantive choices, not just transcription:

- `Ctx.admissible : Ctx α → Bool` must check finiteness, but its signature supplies no `NumOps α` or equivalent finiteness operation.
- `Index.of`, `start`, `step` and `evaluate` remain unspecified adaptations.
- The law summaries do not unambiguously preserve all original hypotheses and domains.

For example, version-1 L3 applies to any `p.WF` program under `N.Lawful`; the introductory statement that L1–L4 take `CheckerAccepted` must not silently narrow that domain.

**Failure scenario:** The eventual proof requires an extra restriction on declarations, programs or availability timing that was absent from the frozen guarantee. The proof then succeeds for a weaker statement.

**Minimal fix:** Write the complete executable definitions and exact Lean theorem signatures, retain the original domains and numerical assumptions, and independently review that completed specification **before** freezing or proving it.

## Conclusion

Revision 5 should not be accepted on the strength of the previous acceptance. Its principal unresolved problems are:

- loading order is asserted rather than implemented;
- certification is not formally connected to evaluated data;
- execution can consume arbitrarily late observations;
- direct and transitive scope checks omit consequential reads;
- initialization escapes scope at short horizons; and
- the version-1 event-ordering argument has a concrete counterexample.

The migration compatibility questions must be settled against the fixed baseline—not by widening evidence scope, changing delivery order, or weakening the laws after proof work begins.
