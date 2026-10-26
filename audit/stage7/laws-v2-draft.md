# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (draft for review)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings, every stage 6 law to keep
its guarantee for every admitted declaration (held and event cadences included), each law whose definitions change
to be revised, independently reviewed and frozen before its proof, and a binding law. This draft states the changed
definitions and the revised law statements, before any proof. `Ref/Spec.lean` and `Ref/Laws.lean` are the frozen
version 1; nothing here edits them until the review is resolved.

## 1. What changes and why

Version 1's market, machine and delivery name their sources: `Market` holds `funding`, `bars` and `events` arrays;
the machine holds `funding`, `bar` and `events` per coin; delivery runs three loops; inputs are a closed enum
(`Input.funding`, …, `Input.event slot`) whose unit is fixed in code; L5 speaks of "event sources". SOURCES.md
(version 1) replaces all of this with declarations: a registry of sources, each with typed fields, a cadence (held or
event) and an availability rule; DSL inputs are declared field names; the simulator reads execution data only through
two roles (`bars`, `settlement`).

Unchanged: the DSL's operators, windows, ticks and their typing; the simulator's step, fills, funding settlement,
margin and accounting (they read the role tables, which carry exactly the columns they read today); `NumOps` and its
obligations; R version 1 and L3.

## 2. Changed definitions

```lean
/-- A declared input, resolved by the checker against the registry (SOURCES.md §1). -/
structure Input where
  source : Nat        -- the declaration's index in the registry
  field : Nat         -- the field's index within that declaration, in field-name order
  unit : Dim          -- the declared unit
  event : Bool        -- the declaration's cadence is `event`
  deriving DecidableEq, Repr

/-- What the checker and the machine need of a registry: per declaration, its fields' input names and units, and
its cadence. -/
structure Registry where
  sources : Array (Array (String × Dim) × Bool)    -- (fields in name order, event cadence)

/-- One resolved observation (RULES.md §6): its declaration, coin, slot time (eventTime, or the event hour), effective
knownAt, and one value per declared field, `none` where the stored column is null. -/
structure Obs (α : Type) where
  source : Nat
  coin : Nat
  event : Int
  known : Int
  vals : Array (Option α)

/-- The role tables the simulator reads (SOURCES.md §6), as today's `BarRow` and a settlement row. -/
structure RateRow (α : Type) where
  coin : Nat
  event : Int
  known : Int
  rate : α

structure Market (α : Type) where
  obs : Array (Obs α)          -- every resolved observation of every bound source
  bars : Array (BarRow α)      -- role `bars`, from its provider
  rates : Array (RateRow α)    -- role `settlement`, from its provider
  intervals : Array (Int × Int)
  bound : List Nat             -- the registry indices of the bound sources

/-- Admissible markets add: observation keys (source, coin, event) unique; every observation's source bound and
in range, its coin in range, and its value count its source's field count; settlement keys (coin, event) unique. The
bar conditions are unchanged. -/
structure Market.Admissible (reg : Registry) (m : Market α) : Prop where
  obsKeys : (m.obs.toList.map fun o => (o.source, o.coin, o.event)).Nodup
  obsSource : ∀ o ∈ m.obs.toList, o.source ∈ m.bound ∧ o.source < reg.sources.size ∧
    o.vals.size = (reg.sources[o.source]!).1.size
  obsCoin : ∀ o ∈ m.obs.toList, o.coin < m.intervals.size
  rateKeys : (m.rates.toList.map fun r => (r.coin, r.event)).Nodup
  rateCoin : ∀ r ∈ m.rates.toList, r.coin < m.intervals.size
  barKeys : (m.bars.toList.map fun b => (b.coin, b.openTime)).Nodup
  barEvent : ∀ b ∈ m.bars.toList, b.event = b.openTime + BAR
  barCoin : ∀ b ∈ m.bars.toList, b.coin < m.intervals.size
```

**Machine.** `MState`'s `funding`, `bar` and `events` become one field, `held : Array (Array (Option (Obs α)))`,
indexed by source then coin: delivering an observation replaces that source's held observation for its coin whole
(SOURCES.md §4). An input reads `held[inp.source][coin]`, then its `vals[inp.field]`; for an event input, only if the
held observation's `event` equals the tick's hour (defined at its own tick only, never after). A held observation
whose field is `none` makes the input undefined.

**Delivery.** One loop over `oOrder`, the observations sorted by (known, source, coin, event), delivers every
observation with known ≤ tick, each checked `known ≤ tick` (I1) and raising `maxKnown`. Version 1's three loops are
this loop's restriction to three sources; since every delivery due at a tick completes before the tick's evaluation,
the interleaving is unobservable (SOURCES.md §4).

**Prefixes and views.**

```lean
/-- The ordered delivery prefix by time t: every observation of a bound source with knownAt ≤ t, in delivery order,
with multiplicity. -/
def Ctx.deliveryPrefix (c : Ctx α) (t : Int) : List (Obs α) :=
  (c.oOrder.toList.map (c.m.obs[·]!)).filter (·.known ≤ t)

/-- What execution reads by event time t: the settlement role's rates with eventTime ≤ t; every field of bars closed
by t; the open and trade count of bars opened by t; and the listing intervals (unchanged but for `rates`). -/
def Ctx.execView (c : Ctx α) (t : Int) := 
  ((c.m.rates.toList.filter (·.event ≤ t)).map (fun r => (r.coin, r.event, r.rate)),
   c.m.bars.toList.filter (fun b => b.openTime + BAR ≤ t),
   (c.m.bars.toList.filter (·.openTime ≤ t)).map (fun b => (b.coin, b.openTime, b.o, b.trades)),
   c.m.intervals)
```

**Checking.** `check : Registry → String → Except Reject Program`: an input name is looked up among the registry's
field names (unique across declarations, SOURCES.md §1); an undeclared name is `E_UNKNOWN_INPUT`; the node's type is
the declared unit. `CheckerAccepted reg p := ∃ text, check reg text = .ok p`, and `Program.WF` reads
`.input inp => p.types[i]! = .num inp.unit` as before.

**Required set and binding.** `Program.sources p := (p.nodes.toList.filterMap fun n => match n with | .input inp =>
some inp.source | _ => none).eraseDups` (every input anywhere in the program: weight, lets used or not, branches,
prediction). Version 1's `Ctx.bound` (every event slot bound) becomes: every source in `p.sources`, and every role
provider, is in `m.bound`. Certification is a separate predicate of the admitted snapshot:
`Admission.certified (a) : Bool`, true when every source in the run's required set (inputs, role providers and their
transitive dependencies) has a binding whose certificate is valid, matching and in scope (CERTIFICATES.md §5, §6). The
semantics refuses at start with `inputUnavailable` when a required source is unbound, else with `uncertified` when one
is uncertified, before any delivery or tick.

## 3. Revised law statements

Every law gains the registry parameter `reg`, and `m.Admissible` becomes `m.Admissible reg`. Otherwise:

- **L1 non-interference (L1_values, L1_simulator, L1_decisions):** unchanged in form. The prefix hypothesis `hP` is
  now an equality of the single ordered observation list, which by construction covers every bound source, held and
  event alike; `hE` compares the views above. The conclusion is the same: equal machine states at every tick, equal
  traces through the step.
- **L2 unit soundness (L2_units, L2_checker):** the erasure clause's `u.m.funding = ms.funding ∧ u.m.bar = ms.bar ∧
  u.m.events = ms.events` becomes `u.m.held = ms.held`; the rest is unchanged. `L2_checker` holds for every registry.
- **L3 rewrite soundness:** unchanged (the rule schemas do not touch inputs).
- **L4 fill ordering (L4_fills, L4_orders):** unchanged in form; `latestClosed` and `barAt` read the bars role table,
  and settlement reads `rates`.
- **L5 binding (replaces version 1's L5):** a run is refused exactly when its required set is not wholly bound and
  certified, before any delivery or tick: with `inputUnavailable` if some required source is unbound, otherwise with
  `uncertified` if some required source lacks a valid, matching, in-scope certificate; when every required source is
  bound and certified, admission passes and the run is the ordinary evaluation. In particular a source named only in
  an unused let, an untaken branch or the prediction is required.

  ```lean
  theorem L5_binding (N) (reg) (p) (_ : CheckerAccepted reg p) (m) (v) (pol) (stop) (a : Admission) :
      let c := Ctx.make reg p m v pol stop
      (c.run N a = .error .inputUnavailable ↔ ∃ s ∈ c.required, s ∉ m.bound) ∧
      ((∀ s ∈ c.required, s ∈ m.bound) → (c.run N a = .error .uncertified ↔ a.certified = false)) ∧
      ((∀ s ∈ c.required, s ∈ m.bound) → a.certified = true → c.run N a = c.evaluate N)
  ```
- **L6 bounded loss:** unchanged (it reads only the book and the role tables).

## 4. Why the guarantees carry over

- Every guarantee of L1, L2 and L4 is a statement about what the machine and the simulator read; generalization
  changes only where the values come from (one observation table indexed by declaration instead of three fixed
  tables) and keeps the delivery invariant (nothing with knownAt > tick is delivered; deliveries due at a tick precede
  its evaluation). Held and event cadences are the two cases of the input read above, and the event case is defined
  only at its own hour, as version 1's event rows are.
- L5 strengthens version 1's: it now covers every source, not only event sources, and adds the certificate check.
- Restricted to the two pilot declarations and the two event declarations, the generalized semantics computes exactly
  version 1's (the three loops are the single loop's restriction, and the input reads coincide), which the C7.4
  baseline then confirms on the frozen corpus.

## 5. Questions for the reviewer

1. Is any version 1 guarantee weakened, for some admitted registry (for example a source with no fields, a held
   source whose observations arrive out of event order, or two sources with equal keys)?
2. Is the single ordered prefix the right object for L1, or does the law need per-source prefixes to stay meaningful
   when sources share a knownAt?
3. Is L5's statement complete for the required set (transitive dependencies, role providers), and is ordering
   unavailable before uncertified the right precedence?
4. Is anything in C7.7's list of named attacks (15: holdout through a declaration, binding, alias or derived
   dependency; 16: zero-filling, an event held past its tick) left without a law or test that would catch it?
