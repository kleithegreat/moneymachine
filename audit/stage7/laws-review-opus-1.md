Fresh-context Opus review of stage 7 slice 1 laws (GPT unavailable)

Scope: I read the whole of `audit/stage7/laws-v2-draft.md` and checked it against v1's `Ref/Spec.lean`, `Ref/Laws.lean` (statements only), `Ref/Sim.lean`, `Ref/Machine.lean`, `Ref/Syntax.lean`, `reference/SEMANTICS.md`, `kernel/SOURCES.md`, `kernel/CERTIFICATES.md`, `kernel/RULES.md` §6, and criteria C7.1–C7.7. I edited nothing. The defects are listed most important first. Defects 1 to 3 should block freezing.

## Defects

### D1. Role data is not tied to any source, and the simulator does not "read only the role tables" (blocking; touches L1, L4, L5 and attack 9)
- **The step reads delivered rows, not the tables.** Step 9 of `Ctx.step` reads machine state, not tables:
  - freshness is `s.machine.funding[c].event == B` and `s.machine.bar[c].event == B`;
  - the order price is `s.machine.bar[c]!.get!.c`;
  - `maxKnown`, which becomes the fills' `inputsKnown`, includes the knownAt of funding and bars.

  The draft deletes `MState.funding` and `MState.bar` but never says what freshness and the decision price read. The bars provider may have no DSL fields (SOURCES §6: "Role columns need certification even when absent from `fields`"). In that case nothing holds its close or event in the machine. The claim that the simulator's step is unchanged is false.
- **The same row has two homes.** Market keeps `obs`, `bars` and `rates` side by side. Nothing ties `m.bars` or `m.rates` to the selected provider, to `m.bound`, or to that provider's observations (key set, knownAt, values). `Ctx.make` has no role selection either. The consequences:
  - (a) "every role provider is in `m.bound`" says nothing about where `m.bars` came from, so **attack 9 (uncertified execution data) is not expressible**;
  - (b) if freshness keeps reading delivered bar and settlement rows, those deliveries are not in `deliveryPrefix` (it covers `obs` only). **L1_values would then be false**: two markets can agree on `obs` and differ in bar knownAt.
- **Proposed fix: one stored row, one observation.**
  - Add a typed role payload to `Obs`, e.g. `role : Option (RolePayload α)` with `| bar (openTime trades : Int) (o h l c : α) | rate (r : α)`.
  - Add `roles : Roles` (bars and settlement provider indices) to the run's context.
  - Define `Market.bars reg roles m` and `Market.rates reg roles m` as projections of the providers' observations, and delete the stored `bars` and `rates` arrays.
  - Freshness reads the event of the held observation for `roles.bars` and for `roles.settlement`. The decision price reads the held bar payload's close.
  - Move `barKeys`, `barEvent`, `barCoin`, `rateKeys` and `rateCoin` onto the providers' observations. Add "an observation carries a role payload iff its source is that role's provider". `deliveryPrefix` then covers the role data automatically.
  - Restate `execView`, `barAt` and `latestClosed` on the projections.

### D2. The event cadence's single held slot contradicts SOURCES §4 when observations arrive out of event order (blocking; attack 16)
- **What breaks.** `held[s][c]` is replaced whole on every delivery, and an event input reads it only if `held.event = hour`.
- **Example.** Take event-source observations (s, c, E) with knownAt E+δ−10 and (s, c, E′), E′ < E, with knownAt E+δ−5. This is easy to produce: a correction of an earlier hour (knownAt ≥ fetchedAt, RULES §6) or a late derived row. At tick E+δ both are delivered in knownAt order. E′ overwrites E, so the input is undefined at E.
- **What the spec says.** SOURCES §4: "defined at the tick E + δ only, and only if the observation was delivered by then". It was delivered. The same loss happens when an observation for a later hour is known early.
- **Scope.** Version 1 has the same flaw. It never fired because the v1 rule gives knownAt = eventTime + δ, which is monotone.
- **Proposed fix.**
  - Hold per (source, coin) the delivered observations: `held : Array (Array (List (Obs α)))`, which may be pruned of event < hour.
  - A held input reads the last delivered entry. An event input reads `find? (·.event == hour)`; obsKeys makes it unique.
  - Same structure, two reads, both selected by the registry's cadence (see D6).
  - Add a law that pins the read semantics (D9).

### D3. `Admission.certified : Bool` is opaque and disconnected, so L5 is vacuous on certificates (blocking; C7.7's "a proof of a weaker statement does not count")
- **The certificate clauses are trivial.** As drafted, `run` checks `a.certified` and L5's certificate clauses follow by `if`. Nothing links `a` to `m`, `reg`, `c.required`, the bindings, certificate validity at a ledger position, matching (declaration hash, rule bytes, manifest hash), or scope.
- **Two homes for "bound".** `m.bound` (Market) and `a`'s bindings both say what is bound.
- **Attacks the law cannot see.** 4 (replay against another manifest or rule), 5 (out-of-scope use), 6 (data changed after validation) and 9.
- **Proposed fix.**
  - `structure Admission` with `bindings : List Binding` (source, dataset, certId), `certs`, `ledgerPos`, `manifest : Nat → Hash`, and `market : Market α`. The market is the admitted bytes: `Ctx.make reg roles p a v pol stop` takes `m := a.market`. Delete `Market.bound`; "bound" means `∃ b ∈ a.bindings, b.source = s`.
  - `certified` is a definition, not a field: `∀ s ∈ c.required, ∃ b ∈ a.bindings, b.source = s ∧ Valid a.ledgerPos b.cert ∧ Matches reg s a b.cert ∧ InScope (c.accesses s) b.cert.grants`. Here:
    - `Valid` means not superseded at `ledgerPos`, including the transitive upstream closure (CERTIFICATES §6);
    - `Matches` covers the declaration hash, rule bytes, manifest hash equal to the hash of `a.market`'s rows for s, and upstream certificate ids;
    - `InScope` means every access falls in a grant (entity, column, event-time interval, permitted-use interval).
  - `c.accesses s` must be defined statically from (reg, roles, p, coins, window, stop). It contains:
    - every (s, coin, column, eventTime) delivered by stop;
    - every (s, coin, column, τ) read at a tick τ, held values included, so that a held value used after its permitted-use interval is `R_UNCERTIFIED` (CERTIFICATES §5: "never undefined data");
    - a read for a coin outside the entity grant, even when the feed has no row for that coin;
    - role reads through stop: fills, marks, margin, settlement, after the last decision included.

    Because the access set is static, preflight is complete, `evaluate` can never raise `uncertified` mid-run, and L5's iff is meaningful.
  - The hash can stay abstract (an injective parameter).

### D4. The registry cannot express the required set
- **Missing pieces.** `Registry` has no dependencies, no role capability and no third cadence. Without them, `c.required` (named in L5 but never defined in Lean) cannot compute "role providers and the transitive closure of their dependencies".
- **Evidence declarations.** SOURCES §1's evidence declarations (`fields {}`, `cadence {"evidence": {}}`, keyed by their own columns) are required as dependencies and must be bound and certified. They cannot be represented, and `obsCoin` would reject their records.
- **Proposed fix.**
  - `inductive Cadence | held | event | evidence`, plus `depends : List Nat` per declaration.
  - `Registry.Valid`: input names Nodup across declarations, field indices in name order, acyclic depends, and evidence declarations with no fields and no role.
  - `Ctx.required := closure reg.depends (p.sources ++ [roles.bars, roles.settlement])`, defined with fuel `reg.size` or under acyclicity.
  - Admissible: no observations of evidence sources; role providers have the role capability.
  - L2_checker, and the `check` lookup for names, need `reg.Valid`; otherwise `check` silently resolves a duplicated name to its first match.

### D5. Observations of bound but unrequired sources are delivered
- **What happens.** `oOrder` covers every observation of every bound source. A source that is bound but not required, and so never certified, still raises `maxKnown`. That value is recorded as `inputsKnown` in fills, which is result-bearing output.
- **Holdout risk.** It is also a channel by which a holdout dataset is loaded through a binding (attack 15).
- **Proposed fix.** Deliver only observations whose source is in `c.required` (Admissible: `o.source ∈ c.required`, or filter in `Ctx.make`). L1's `hB` then becomes unnecessary; delete it.

### D6. The program carries cadence and unit; the registry should
- **What is duplicated.** `Input` duplicates `unit` and `event` from the registry, and the machine branches on `inp.event`, a flag the program carries. `Program.WF` does not tie them to `reg`.
- **The hazard.** L3 applies to WF programs, not checker-accepted ones. A WF program with `event = false` on an event source holds an event value past its tick (attack 16).
- **Proposed fix.**
  - `Input := ⟨source, field⟩`.
  - The machine reads the cadence from `reg`.
  - `Program.WF reg p` requires `source < size`, `field <` the field count, and `types[i] = .num` the declared unit.
  - `p.sources` and the rewrite laws are unaffected.

### D7. Slot versus key, and the event grid
- **Ordering mismatch.** `Obs.event` is the slot column C. SOURCES §4 orders deliveries by (knownAt, coin, eventTime), the key. When C ≠ eventTime, two observations of one source and coin with equal knownAt can be ordered differently. That changes which one ends up held.
- **Key collision.** `obsKeys` on (source, coin, slot) can reject legal data in which distinct eventTimes share a slot hour.
- **Off-grid slots.** An event slot off the hour grid is silently never defined.
- **Proposed fix.**
  - `Obs` carries both `key` (eventTime) and `slot`.
  - Order by (known, source, coin, key). Event reads use `slot`.
  - Admissible: an event source's slots are multiples of HOUR, and (source, coin, slot) is unique for event sources.
  - Alternatively, if slot must equal eventTime in v1, state that in SOURCES §1 as a divergence.

### D8. Where the preflight lives, and `evaluate`, are undefined
- **What is v1 today.** `Ctx.start` and `Ctx.umachineAfter` both contain `if !c.bound then throw .inputUnavailable`.
- **The gap.** The draft introduces `c.run N a` and `c.evaluate N` without defining either.
- **Proposed fix.**
  - `run := preflight a >>= fun _ => evaluate`.
  - Delete the binding check from `start` and `umachineAfter`.
  - Restate L1, L2 and L4 on `steps`, `machineAfter` and `evaluate` (L4: `c.evaluate N = .ok r`), and restate L6 on `evaluate` or `run`. These guarantees then hold for every admissible market, which is stronger.
  - `Abort` gains `.uncertified ↦ "R_UNCERTIFIED"`.
  - The draft writes `check : Registry → String → Except Reject Program`. Keep `Except Code`.

### D9. No law pins the input-read semantics that attack 16 names
L1 to L6 never state what an input equals, so zero-filling, holding past a tick and wrong expiry are caught only by differential tests. D2 shows that the definition itself got this wrong.

Proposed L7 (input reads), for a listed coin at tick H:
- a held input equals field k of the last observation of (s, c) in `deliveryPrefix (H+δ)`, and is `none` if there is no such observation or its value is null;
- an event input is defined iff an observation (s, c, slot = H) with knownAt ≤ H+δ exists, and then equals its value;
- otherwise the input is undefined, never 0.

This is cheap to prove and directly encodes SOURCES §4.

### D10. Nulls in role columns are unspecified
`BarRow` and `RateRow` hold α, but stored columns may be null (SOURCES §2).

Proposed fix, either:
- Admissible or the role contract requires non-null role columns, rejected at binding; or
- a null rate is a missing settlement (`R_SETTLEMENT_MISSING`, never zero) and a null bar is no bar.

State which in SOURCES §6.

### D11. Holdout access authorization is not modelled, and the spec is incomplete
SOURCES §7 makes authorization a separate check "before any payload is opened". It gives no rejection code and no precedence relative to `R_INPUT_UNAVAILABLE` and `R_UNCERTIFIED`.

Proposed fix, either:
- add `authorized mode a` to the preflight with an explicit precedence and code, plus an L5 clause; or
- record explicitly that I8 generalized is enforced outside the Lean model and judged by the attack 15 tests.

Either way, fix the code and precedence in SOURCES §7 first, as a recorded divergence.

## Q1: does each law keep its guarantee?
Assuming D1 to D8 are fixed:
- **Held sources out of event order:** fine; a whole replacement matches SOURCES §4.
- **Event sources out of event order:** broken (D2).
- **Sources with no fields:** fine once D4 lands; such a source can only be a role provider or a dependency.
- **Equal knownAt across sources:** unobservable; fine.
- **Nulls in fields:** fine. **Nulls in role columns:** D10.
- **Delisting:** unaffected.
- **Role providers that are also input sources:** this is exactly where D1 bites.
- **L1:** unprovable or false while freshness reads delivered role rows that lie outside the prefix (D1).
- **L5:** vacuous on certificates (D3).
- **L4:** its `inputsKnown` guarantee holds, but it can include uncertified knownAt (D5).

## Q2: single ordered prefix or per-source prefixes?
Keep the single ordered list. With unique keys, (known, source, coin, key) is a total order, so equality of the merged sorted list is equivalent to equality of every per-source prefix. Shared knownAt across sources is harmless.

## Q3: is L5 complete?
The precedence (checking, then unbound, then uncertified) matches SOURCES §7, and "a source in an unused let is required" is sound because `check` interns unused lets into `p.nodes` and the R rules never remove nodes. L5 is still incomplete:
- `c.required` is undefined (D4);
- certification is opaque (D3);
- binding has two homes (D3);
- `evaluate` is undefined (D8).

L3 needs a lemma that `Rule.apply` preserves the membership of `p.sources`.

## Q4: which of C7.7's 16 attacks does nothing here catch?

| Attacks | Caught here? | What would catch them |
|---|---|---|
| 1, 2, 3, 7, 10, 11, 12, 13, 14 | No; correctly outside the Lean model | Verifier, resolver and rule-language tests (C7.3, C7.6) |
| 4, 5, 6 | Not now | D3's definitions |
| 8 | Yes | `p.sources` over all nodes |
| 9 | Not now | D1 combined with D3 |
| 15 | No | D5 removes one channel; D11 |
| 16 | Not now; the definition is wrong | D2, D6, D9 |

## Q5: what is called "unchanged" but changes
- **"Simulator's step unchanged":** false. Step 9 reads machine-held rows. `SState`'s `fi`/`bi`/`ei` and `state0` change. `Market.index.rateAt` reads `funding`.
- **L3, L4 and L6 ("unchanged"):** each references `run`, `Ctx.make`, `Market` and `steps`, which all change. Under C7.7 each must be re-reviewed and re-frozen with its new statement. They cannot be carried over.
- **"The three loops are the single loop's restriction":** exact only under the migrated rules. v1 breaks ties among events by array index (`[known, coin, slot, i]`); the draft breaks them by event. They differ only for equal knownAt and different hours, which v1's rule (eventTime + δ) never produces. Say so, rather than claiming a literal restriction.
- **L2's erasure clause (`u.m.held = ms.held`):** fine, but D2's held representation changes it again.

## Files
- `/home/kevin/repos/moneymachine-stage7/audit/stage7/laws-v2-draft.md` (under review)
- `/home/kevin/repos/moneymachine-stage7/reference/lean/Ref/Sim.lean`: step 9's freshness and price (lines 417, 431); `Ctx.start` and `Ctx.bound` (lines 300, 312)
- `/home/kevin/repos/moneymachine-stage7/reference/lean/Ref/Machine.lean`: `MState.input`, the event read (lines 159–161)
- `/home/kevin/repos/moneymachine-stage7/kernel/SOURCES.md`: §1 evidence declarations, §4, §6, §7
- `/home/kevin/repos/moneymachine-stage7/kernel/CERTIFICATES.md`: §5 grants and held-value scope, §6 supersession
