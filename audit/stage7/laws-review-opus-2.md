Fresh-context Opus review of stage 7 slice 1 laws, revision 2 (GPT unavailable)

Files read: audit/stage7/laws-v2-draft.md; Ref/Spec.lean, Laws.lean, Sim.lean, Machine.lean, Syntax.lean; reference/SEMANTICS.md; kernel/SOURCES.md, CERTIFICATES.md, RULES.md §6, INVARIANTS.md; audit/stage7/migration-annex.md §4; kernel/mm/src/sim.rs `run`; criteria.md Stage 7. No file was edited.

Verdict: freezing is blocked by five defects (B1 to B5). Revision 2 does fix D2, D6, D7 and D10 cleanly, and its overall shape is right: role data on the observations, one delivered store read two ways, and preflight followed by evaluate.

## Blocking defects

**B1. `authorized` drops I8's row-level guard, and L5.3 would then forbid it.**
- `authorized` checks only dataset identity and lineage. L5.3 states `R_HOLDOUT ↔ ¬authorized`.
- I8 aborts on any row with eventTime ≥ holdout start, "whatever file it came from". Threat T16 covers "a copy of them".
- A copy, an alias with a new id, or a non-holdout dataset spanning the holdout period passes `authorized`. An implementation that keeps I8's row check would then break L5.3's ↔, so the frozen law would make the guard non-conforming. This is also attack 15, and C7.7 requires all I1–I10 mutants to still be caught.
- Change: give the admission or policy a `holdoutStart`. Define `authorized c a mode := mode = .holdout ∨ (the identity/lineage clause, lineage transitive ∧ ∀ o ∈ c.obs, o.key < holdoutStart)`. Use content identity (manifest hash) for `DatasetId`. Revise the INVARIANTS I8 row in the same change and add it to §5.

**B2. The precedence (unbound, then uncertified, then holdout) is unimplementable and leaks.**
- `certified` quantifies over per-observation `accesses` (coin, key, known), so computing it means resolving payloads.
- §5 and SOURCES §7 require the holdout check "before any payload is opened". Both cannot hold.
- In search mode, R_UNCERTIFIED versus R_HOLDOUT on a holdout-lineage binding would reveal whether holdout rows fall inside grants.
- Resolver errors (R_OVERFLOW, an invalid dataset, cycles; RULES §6) have no place in the order.
- Change: unbound → holdout by identity/lineage (payload-free) → resolve (resolver errors) → holdout by row (B1) → uncertified → evaluate. Restate L5.1–L5.4 for that order. C7.2 only requires certificates to be checked "before any delivery or evaluation", so this order satisfies it.

**B3. The admission does not tie observations to their bindings or manifests.**
- `bindings` is a list. `certified` uses ∃ b, `authorized` uses ∀ b.
- `Obs` carries no dataset, and `a.manifest` is an opaque function unrelated to `a.obs`.
- So a second binding for s with a valid certificate "certifies" observations that came from another dataset. `Matches` on the manifest then constrains nothing, and attacks 4 and 6 are not expressed.
- Change: make `bindings : Nat → Option Binding` (one per source). Add `Obs.dataset`, with Admissible requiring `o.dataset = (bindings o.source).dataset`, or index the observations by dataset. Add a named admission test that recomputes the manifest from the bytes actually read (attack 6).

**B4. `accesses` under-approximates execution reads, so uncertified execution data can pass (attacks 5 and 9).**
- Execution reads role columns by event time, whatever their knownAt:
  - a fill reads a bar's open and trades at openTime;
  - marks and extremes are read at the bar's event time, before its knownAt;
  - in the last step, settlement reads rates at h ≤ b_last + BAR, whose known can exceed lastTick under a slower settlement rule.
- `accesses` keeps only `o.known ≤ lastTick`, with use interval `[o.known, stop)`. Those reads are either missing or start too late.
- Columns: CERTIFICATES §5 grants are "over an entity, **a stored column**", but `Cert` says "column set" and an access carries all of a source's columns at once.
- Scope: §5 also covers availability inputs, and mapping and coverage facts; `accesses` covers neither.
- Change, in three parts:
  1. **Role reads.** Make accesses per column. For role columns, include every role observation the projections can read through `stop`, with use starting at the read time: `min(o.known, openTime)` for open and trades, `min(o.known, key)` for close, high, low and rate.
  2. **Undefined terms.** Define `lastTick`.
  3. **Scope coverage.** State in the document which check covers time columns, mapping, coverage and upstream lineage: the verifier at issuance (`derived-inherits`), plus `Matches` requiring a derived certificate's `upstream` ids to equal the certificates bound to its dependencies.

**B5. Definitions are elided under statements that would be frozen.**
- Elided: `Registry.Valid := ...`, `Grant`/`covers`, `closure`, `lastTick`, `Valid`, `Matches`, `Mode`, `barRow`, the `oOrder` comparator, and where `c.intervals` comes from (Admission has no intervals).
- `Valid` is recursive over upstream ids, so it needs an inductive definition (a cyclic set is then invalid). Upstream ids must resolve within `a.certs`, and ids must be unique.
- `Decl` has no hash or rule-bytes fields, yet `Matches` compares against "the registry's".
- Change: write all of these in Lean before freezing; a statement over "..." can be weakened later. For intervals, name their origin (the venue-rules artifact in the run identity) and say whether C7.2's certification covers them. Delisting closeouts depend on them; if not covered, record a known limitation.

## Should fix before freezing

**N1. §4's "computes version 1's on every corpus run" is false, which puts C7.4 at risk.**
- (a) `mm` (sim.rs `run`) delivers every event dataset in the store, whether or not the program reads it. D5 delivers only required sources. For programs that don't read events (W0 likely does not), the delivery stream changes, and so can `maxKnown`, which is each fill's `inputsKnown`. The C6.4 synthetic markets especially need checking.
- (b) Within a tick, version 1 delivers all funding, then all bars, then events in (known, coin, slot) order. Revision 2 orders by (known, source, coin, key). These differ routinely, for example two event sources at the same hour for different coins, not only in the one tie the draft names.
- The annex compares "deliveries with their knownAt" byte for byte, with "no sorting … or other normalization".
- Change: check what the baseline capture records. If it is ordered, or includes unread event rows, change the design, not the comparison. Two options: deliver every bound source and require certification for every delivered one; or order by (tick batch, role rank, known, coin, source, key). Otherwise record a Blocker.

**N2. `required` conflates three sets.** Dependency-only coin-keyed sources get delivered: this raises `maxKnown` and demands use-grants for data the run never reads. Change: delivered = `p.sources ∪ roles` (or the bound set, per N1); must be bound and certified = the closure; dependency scope is handled per B4.

**N3. L7 is false as stated, and its wording contradicts itself.**
- A node value is `read.bind N.keep`, and Admissible does not require finite `vals`, so a non-finite value breaks the stated equality.
- "Defined iff an observation … is in [the prefix] … undefined if null" contradicts itself.
- Change: for H = wStart + n·HOUR, with `machineAfter N n = .ok ms` and `p.nodes[i]! = .input ⟨s,k⟩`, c listed at H, `ms.vals[i]![c]! =` (last (s,c) observation in the prefix, or `find? (slot = H)` for an event source) `.bind (·.vals[k]!) |>.bind N.keep`. Drop "never zero by default"; the equation implies it.

**N4. L5.5 is vacuous.** Any `.error` result already carries no trace. Replace it with refusal non-interference: preflight's result depends only on bindings, certs, position, manifests, lineage, holdout and the access set, never on `vals` or role payload values. Under B2, R_HOLDOUT depends on no observation at all.

**N5. L5.6 is true by definition** of `p.sources` as written. State it on the text: `check reg text = .ok p` and an input name occurring anywhere in `text` (a let, used or not; a branch; the prediction) imply that its source ∈ `p.sources`. It is provable: lets are interned whether or not they are used (Syntax.lean, around line 316).

**N6. Add C7.7's own wording as the headline of L5:** `c.run N a mode = .ok r → (∀ s ∈ c.required, bound a s) ∧ certified c a ∧ authorized c a mode`.

**N7. `Matches` is missing three checks, and supersession sits in the wrong place.**
- Missing from `Matches`:
  - the policy hash (attack 3);
  - the verifier version;
  - the upstream certificate ids against the certificates bound for the dependencies (attack 4 for derived feeds).
- `supersededAt` stored on `Cert` mixes the hashed payload with ledger state. Model it as `a.supersessions : List (Hash × Nat)` instead.

**N8. Every Admissible clause needs an enforcing rejection, or the laws are vacuous for runs the implementation accepts.** The clauses: role selection in range, listing the role, and distinct providers (`roles.bars = roles.settlement` makes every row of that source inadmissible); `vals.size`; bars `key = openTime + BAR` on the 4h grid; event slots on the hour grid and unique; finiteness. Each needs a code in SOURCES §6/§7 and a test.

**N9. The access use interval is over-strict.** Starting at `o.known` demands grants back to the oldest warm-up row, and post-delisting rows need grants though they are never read. Use `[max(o.known, wStart + δ), stop)`; this is a precision fix, not a safety one.

**N10. Erasure.**
- `Cert.source` is redundant with `declHash`.
- `RolePayload.bar.openTime` is redundant with `key` (key = openTime + BAR).
- `BarRow.v` is unused by execution.
- `Obs.slot` is meaningless for held sources.

## Q1: weakened or vacuous laws

- No version 1 guarantee is weakened, apart from I8 via L5.3 (B1).
- L1–L4 and L6 look true and provable on `evaluate`:
  - with the total order on (known, source, coin, key), equal prefixes give equal stores;
  - L3's set equality holds because rules only overwrite op nodes;
  - L4 and L6 on `evaluate` are stronger than on `run`.
- L7 is false as stated (N3); L5.5 and L5.6 are vacuous (N4, N5).
- The edge cases you listed raised no further problems:
  - the required set is never empty, because roles are included;
  - coins with no rows mean no access and stale holds, which is acceptable;
  - out-of-order event times are handled by the store;
  - with equal knownAt, the larger key wins, consistent with SOURCES §4;
  - delisting behaves as in version 1;
  - a role provider that also supplies inputs works (its `vals` and role payload need not be checked for consistency).

## Q3: L5's completeness

Not complete. L5 needs:
- B1's row bound;
- B2's precedence, with resolver errors placed;
- B4's role and column access;
- N4 in place of L5.5;
- N5's text-level L5.6;
- N6's headline.

Out-of-scope use becomes R_UNCERTIFIED only once B4 is fixed; today, execution reads escape it. The positive case (L5.4) is fine.

## Q4: C7.7's 16 attacks

| Status | Attacks | Where |
|---|---|---|
| Covered by a law here | 8 | L5.6, once stated on the text (N5) |
| | 16 | L7, once fixed (N3) |
| Covered only after a fix | 5, 9 | L5.2, after B4 |
| | 15 | L5.3, after B1 |
| Partly covered | 4 | `Matches` checks the declaration, rule bytes and manifest; mapping, extractor and upstream are not checked (N7) |
| | 6 | needs B3 plus an admission test |
| No law and no named test | 1, 2, 3, 7 | verifier and ledger tests |
| | 10, 12, 13 | verifier and resolver tests |
| | 11, 14 | C7.6 resolver and rule-language suites |

I found no test plan under audit/stage7. The draft should carry a 16-row table naming each attack's law or test, the check it targets, the expected code and its positive control.

## Q5: are the §5 spec changes weakenings?

- **§7 precedence plus `authorized`:** a weakening of I8 and T16 (B1), and internally inconsistent (B2).
- **"Unrequired sources are never admitted":** not a security weakening, but it conflicts with C7.4's byte-identity (N1).
- **§4 (key and slot, slot uniqueness) and §6 (non-null role columns):** strengthenings. They are acceptable once enforced (N8).
- **§1 (evidence):** a clarification.
- **Missing from §5:**
  - the INVARIANTS I8 row;
  - a CERTIFICATES §5 decision on per-column versus column-set grants;
  - the R_UNCERTIFIED code in INVARIANTS;
  - deleting SEMANTICS §8's "core datasets always present".

## The draft's §6 answers to D1–D11

| Status | Defects | What remains |
|---|---|---|
| Resolved | D2, D6, D7, D10 | none (D7 and D10 still need enforcement, N8) |
| Mostly resolved | D1 | execution-read certification (B4) |
| | D4 | the overloaded required set (N2) |
| | D8 | L5.5 is vacuous (N4) |
| | D9 | L7 is false as worded (N3) |
| Partly resolved | D3 | B3, B5, N7 |
| | D5 | N1, N2 |
| | D11 | B1, B2 |

No criterion needs redefining for any of these fixes.
