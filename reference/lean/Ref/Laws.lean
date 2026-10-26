import Ref.Spec
import Ref.Resolve

/-!
The laws, generalized over declarations by stage 7 (audit/stage7/laws-v2-draft.md §7; stage 6's statements with
their revisions, C7.7). Each holds for every number structure `N`, every valid registry and roles, every admission
metadata and every admissible array of resolved observations; L3's obligations and L6's are explicit hypotheses, as
in version 1. The machine and simulator laws quantify over every admissible observation array; the binding laws
state what admission checks, and `L5_certified` what an admitted run guarantees under the trusted boundary
(`Trusted`, Source.lean), whose obligations the implementation discharges outside the model. These statements are
reviewed and frozen before any proof; `sorry` marks proofs not yet written.
-/

namespace Ref

variable {α : Type} [Inhabited α]

/-! ## L1 non-interference -/

/-- Equal delivery prefixes give equal machine states (values, windows, held observations, `hours_since` state)
at every tick through t. -/
theorem L1_values (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs₁ obs₂ : Array (Obs α)) (v : Venue α) (pol : Policy)
    (_ : pol.Valid) (stop : Int) (req : List Nat) (n : Nat)
    (_ : (Ctx.make reg roles p adm obs₁ v pol stop req).admissible = true)
    (_ : (Ctx.make reg roles p adm obs₂ v pol stop req).admissible = true)
    (hP : (Ctx.make reg roles p adm obs₁ v pol stop req).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)
        = (Ctx.make reg roles p adm obs₂ v pol stop req).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)) :
    ∀ k ≤ n, (Ctx.make reg roles p adm obs₁ v pol stop req).machineAfter N k
      = (Ctx.make reg roles p adm obs₂ v pol stop req).machineAfter N k := by
  sorry

/-- The simulator's machine is that schedule: after j steps, it is the machine after the tick at wStart + 4j·HOUR. -/
theorem L1_simulator (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy) (_ : pol.Valid)
    (stop : Int) (req : List Nat) (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true)
    (j : Nat) (s : SState α) (hj : j ≤ (Ctx.make reg roles p adm obs v pol stop req).bounds.length)
    (h : (Ctx.make reg roles p adm obs v pol stop req).steps N j = .ok s) :
    (Ctx.make reg roles p adm obs v pol stop req).machineAfter N (4 * j) = .ok s.machine := by
  sorry

/-- Equal delivery prefixes and execution views through step k's decision give the same observations at every
step through it: the same trace, or the same rejection. -/
theorem L1_decisions (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs₁ obs₂ : Array (Obs α)) (v : Venue α)
    (_ : v.Valid adm.intervals.size) (pol : Policy) (_ : pol.Valid) (stop : Int) (req : List Nat) (k : Nat)
    (_ : (Ctx.make reg roles p adm obs₁ v pol stop req).admissible = true)
    (_ : (Ctx.make reg roles p adm obs₂ v pol stop req).admissible = true)
    (hP : (Ctx.make reg roles p adm obs₁ v pol stop req).deliveryPrefix ((Ctx.make reg roles p adm obs₁ v pol stop req).decisionTime k)
        = (Ctx.make reg roles p adm obs₂ v pol stop req).deliveryPrefix ((Ctx.make reg roles p adm obs₂ v pol stop req).decisionTime k))
    (hE : (Ctx.make reg roles p adm obs₁ v pol stop req).execView ((Ctx.make reg roles p adm obs₁ v pol stop req).decisionTime k)
        = (Ctx.make reg roles p adm obs₂ v pol stop req).execView ((Ctx.make reg roles p adm obs₂ v pol stop req).decisionTime k)) :
    ∀ j ≤ k + 1, ((Ctx.make reg roles p adm obs₁ v pol stop req).steps N j).map (·.trace)
      = ((Ctx.make reg roles p adm obs₂ v pol stop req).steps N j).map (·.trace) := by
  sorry

/-! ## L2 unit soundness -/

/-- The instrumented machine never raises a unit error; its defined values carry their nodes' static types,
booleans are canonical, and erasing the tags gives the executable machine's values and state (or the same
rejection). -/
theorem L2_units (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy) (_ : pol.Valid)
    (stop : Int) (req : List Nat) (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) (n : Nat) :
    let c := Ctx.make reg roles p adm obs v pol stop req
    (∀ e, c.umachineAfter N n ≠ .error (.inr e)) ∧
    (∀ a, c.umachineAfter N n = .error (.inl a) ↔ c.machineAfter N n = .error a) ∧
    (∀ u, c.umachineAfter N n = .ok u →
      ∃ ms, c.machineAfter N n = .ok ms ∧ u.erase = ms.vals ∧ u.m.wins = ms.wins ∧ u.m.since = ms.since ∧
        u.m.latest = ms.latest ∧
        ∀ i < p.nodes.size, ∀ (coin : Nat) (x : α) (t : Ty), u.tv[i]![coin]! = some (x, t) →
          t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b)) := by
  sorry

/-- The checker's programs are well-formed against the registry. -/
theorem L2_checker (reg : Registry) (p : Program) (_ : CheckerAccepted reg p) : p.WF reg := by
  sorry

/-! ## L3 rewrite soundness -/

/-- Rewriting keeps a well-formed program well-formed and reading the same declarations; at every tick every
original node's values equal its corresponding node's; every step's observations are identical (the same trace,
or the same rejection); hence the whole run, admission included. -/
theorem L3_rewrite (N : NumOps α) (hN : N.Lawful) (r : Rule) (reg : Registry) (roles : Roles) (p p' : Program)
    (i : Nat) (_ : p.WF reg) (h : r.apply p i = some p') (adm : Meta) (obs : Array (Obs α)) (v : Venue α)
    (pol : Policy) (_ : pol.Valid) (stop : Int) (req : List Nat)
    (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) :
    p'.WF reg ∧ (∀ s, s ∈ p'.sources ↔ s ∈ p.sources) ∧
    (∀ n, ((Ctx.make reg roles p' adm obs v pol stop req).machineAfter N n).isOk
        = ((Ctx.make reg roles p adm obs v pol stop req).machineAfter N n).isOk ∧
      ∀ ms ms', (Ctx.make reg roles p adm obs v pol stop req).machineAfter N n = .ok ms →
        (Ctx.make reg roles p' adm obs v pol stop req).machineAfter N n = .ok ms' →
        ∀ k < p.nodes.size, ms'.vals[r.corr i k]! = ms.vals[k]!) ∧
    (∀ j, ((Ctx.make reg roles p' adm obs v pol stop req).steps N j).map (·.trace)
        = ((Ctx.make reg roles p adm obs v pol stop req).steps N j).map (·.trace)) ∧
    ∀ (ld : Loader α) (mode : Mode),
      runProgram N reg roles p' adm ld v pol stop mode = runProgram N reg roles p adm ld v pol stop mode := by
  sorry

/-! ## L4 fill ordering -/

/-- Every fill is nonzero, ordered in time, priced by the cost table and charged the fee. An ordinary fill is its
order's scheduled bar's open, after its decision, and its recorded input bound is the decision machine's latest
knownAt, no later than the decision. A closeout is at its own time, from the coin's latest closed bar: the adverse
extreme for a liquidation, the close for a delisting. -/
theorem L4_fills (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (_ : v.Valid adm.intervals.size)
    (pol : Policy) (_ : pol.Valid) (stop : Int) (req : List Nat)
    (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true)
    (r : Run α) (hr : (Ctx.make reg roles p adm obs v pol stop req).evaluate N = .ok r) :
    let c := Ctx.make reg roles p adm obs v pol stop req
    ∀ f, Event.fill f ∈ r.trace.toList →
      N.isZero f.qty = false ∧ f.inputsKnown ≤ f.decided ∧ f.decided ≤ f.submitted ∧ f.submitted ≤ f.filled ∧
      f.price = fillPrice N v f.coin f.qty f.reference ∧ f.fee = N.mul (N.mul (N.abs f.qty) f.price) v.takerFee ∧
      (f.why = .fill →
        f.submitted = f.decided ∧ f.filled = f.decided - pol.delta + BAR ∧
        (∃ bar, barAt c f.coin f.filled = some bar ∧ bar.trades ≥ 1 ∧ f.sourceOpen = bar.openTime ∧ f.reference = bar.o) ∧
        ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = f.decided ∧
          c.machineAfter N n = .ok ms ∧ ms.maxKnown = f.inputsKnown) ∧
      (f.why ≠ .fill →
        f.inputsKnown = f.filled ∧ f.decided = f.filled ∧ f.submitted = f.filled ∧
        ∃ bar, latestClosed c f.coin f.filled = some bar ∧ f.sourceOpen = bar.openTime ∧
          ∃ q, f.qty = N.neg q ∧ f.reference = (if f.why = .delisting then bar.c else if N.lt N.zero q then bar.l else bar.h)) := by
  sorry

/-- Exactly once: every order whose due step runs (B + 3·BAR ≤ stop, with B its decision's boundary) has exactly
one later resolution in the trace, the fill at its scheduled bar if that bar exists and traded and the due step's
equity is positive, and otherwise its Unfilled record; and every ordinary fill has exactly one earlier decision it
resolves. -/
theorem L4_orders (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (_ : v.Valid adm.intervals.size)
    (pol : Policy) (_ : pol.Valid) (stop : Int) (req : List Nat)
    (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true)
    (r : Run α) (hr : (Ctx.make reg roles p adm obs v pol stop req).evaluate N = .ok r) :
    let c := Ctx.make reg roles p adm obs v pol stop req
    let resolves (t : Int) (coin : Nat) (q : α) (e : Event α) : Prop :=
      (∃ f : Fill α, e = Event.fill f ∧ f.why = .fill ∧ f.coin = coin ∧ f.decided = t ∧ f.qty = q) ∨
        e = Event.unfilled (t - pol.delta + BAR) coin q
    (∀ (i : Nat) (t : Int) (coin : Nat) (w q : α), r.trace[i]? = some (Event.decision t coin w q) →
      t - pol.delta + 3 * BAR ≤ stop →
      (∃ j : Nat, i < j ∧ ∃ e : Event α, r.trace[j]? = some e ∧ resolves t coin q e ∧
        ∀ (j' : Nat) (e' : Event α), r.trace[j']? = some e' → resolves t coin q e' → j' = j) ∧
      ((∃ bar, barAt c coin (t - pol.delta + BAR) = some bar ∧ bar.trades ≥ 1) ∧
        (∃ (k : Nat) (e : α), r.equity[k]? = some e ∧ t - pol.delta + BAR = pol.wStart + ((k : Int) + 1) * BAR ∧
          N.lt N.zero e = true) ↔
        ∃ f : Fill α, Event.fill f ∈ r.trace.toList ∧ f.why = .fill ∧ f.coin = coin ∧ f.decided = t)) ∧
    (∀ (j : Nat) (f : Fill α), r.trace[j]? = some (Event.fill f) → f.why = .fill →
      ∃ (i : Nat) (w : α), i < j ∧ r.trace[i]? = some (Event.decision f.decided f.coin w f.qty) ∧
        ∀ (i' : Nat) (w' : α), r.trace[i']? = some (Event.decision f.decided f.coin w' f.qty) → i' = i) := by
  sorry

/-! ## L5 binding and admission -/

/-- A run that produces output passed every admission check: a valid registry and policy, the checker, metadata,
event times, resolution, run admission and scope. -/
theorem L5_admitted (N : NumOps α) (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α)
    (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode) (r : Run α)
    (h : run N reg roles text adm ld v pol stop mode = .ok r) :
    reg.Valid ∧ pol.Valid ∧ ∃ p req obs, check reg.inputs text = .ok p ∧ stage1 reg roles p adm mode = .ok req ∧
      stage2 adm mode (ld.rows req) = .ok () ∧ ld.resolve req = some obs ∧
      (Ctx.make reg roles p adm obs v pol stop req).admissible = true ∧
      (Ctx.make reg roles p adm obs v pol stop req).inScope = true ∧
      (Ctx.make reg roles p adm obs v pol stop req).evaluate N = .ok r := by
  sorry

/-- The run refuses with the first failing admission check's code, in the order of `firstFailure`; with none
failing it is the evaluation of the checked program on the resolved observations. -/
theorem L5_order (N : NumOps α) (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α)
    (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode) :
    (∀ k e, firstFailure reg roles text adm ld v pol stop mode = some (k, e) →
      run N reg roles text adm ld v pol stop mode = .error e) ∧
    (firstFailure reg roles text adm ld v pol stop mode = none →
      ∃ p obs, check reg.inputs text = .ok p ∧ ld.resolve (adm.required reg roles p) = some obs ∧
        run N reg roles text adm ld v pol stop mode
          = (Ctx.make reg roles p adm obs v pol stop (adm.required reg roles p)).evaluate N) := by
  sorry

/-- The checks before resolution read no observation: two loaders with the same event-time rows fail at the same
check among positions 0 to 5, or at none of them. -/
theorem L5_staged (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld₁ ld₂ : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) (hR : ld₁.rows = ld₂.rows) :
    (firstFailure reg roles text adm ld₁ v pol stop mode).filter (·.1 ≤ 5)
      = (firstFailure reg roles text adm ld₂ v pol stop mode).filter (·.1 ≤ 5) := by
  sorry

/-- The checks after resolution never read an observation's values: resolutions of the same shape (both invalid,
or the same keys, slots, knownAt, coins, value counts and role kinds) fail at the same check, or at none. -/
theorem L5_shape (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld₁ ld₂ : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) (hR : ld₁.rows = ld₂.rows)
    (hS : ∀ req, (ld₁.resolve req).isSome = (ld₂.resolve req).isSome ∧ ∀ o₁ o₂, ld₁.resolve req = some o₁ →
      ld₂.resolve req = some o₂ → o₁.size = o₂.size ∧ ∀ i < o₁.size, (o₁[i]!).sameShape o₂[i]! = true) :
    firstFailure reg roles text adm ld₁ v pol stop mode = firstFailure reg roles text adm ld₂ v pol stop mode := by
  sorry

/-- Every declaration the program text names, in an unused let or an inactive branch included, is required. -/
theorem L5_text (reg : Registry) (_ : reg.Valid) (roles : Roles) (adm : Meta) (text name : String) (p : Program)
    (inp : Input) (h : check reg.inputs text = .ok p) (hR : InputRef text name) (hN : (name, inp) ∈ reg.inputs.toList) :
    inp.source ∈ adm.required reg roles p := by
  sorry

/-- Under the trusted boundary, an admitted run evaluated RULES.md §6's resolution of the required datasets' stored
bytes at the pinned version; every required dataset is named by an issued, current certificate under the pinned
policy and verifier; and a search run's required datasets are no holdout dataset and hold no stored row at or after
the holdout start. -/
theorem L5_certified (N : NumOps α) (num : Cell → Option α) (hash : Cert → Hash) (policy verifier : Hash)
    (holdout : List Hash) (holdoutStart : Int) (st : Stored) (led : Ledger) (reg : Registry) (roles : Roles)
    (text : String) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode)
    (hT : Trusted num hash policy verifier holdout holdoutStart reg st led adm ld) (r : Run α)
    (h : run N reg roles text adm ld v pol stop mode = .ok r) :
    ∃ p obs, check reg.inputs text = .ok p ∧ resolveAll num reg st adm.version (adm.required reg roles p) = some obs ∧
      (Ctx.make reg roles p adm obs v pol stop (adm.required reg roles p)).evaluate N = .ok r ∧
      ∀ s ∈ adm.required reg roles p, ∃ b k, adm.bindings s = some b ∧ adm.cert b.cert = some k ∧ k ∈ led.issued ∧
        k.manifest = st.identity s ∧ k.policy = policy ∧ k.verifier = verifier ∧
        !(led.supersessions.any fun (x, pos) => x == k.id && decide (pos ≤ led.position)) ∧
        (mode = .search → st.identity s ∉ holdout ∧ ∀ row ∈ st.rows s, row.event < holdoutStart) := by
  sorry

/-! ## L6 bounded loss -/

/-- Losses are capped at equity: R_BOUND, the check every step return passes before it is recorded (return ≥ −1),
never fires, for every evaluation, as in version 1, and so for every run. -/
theorem L6_bounded (N : NumOps α) (hB : N.Bounded) :
    (∀ (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy)
      (stop : Int) (req : List Nat), (Ctx.make reg roles p adm obs v pol stop req).evaluate N ≠ .error .bound) ∧
    ∀ (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy)
      (stop : Int) (mode : Mode), run N reg roles text adm ld v pol stop mode ≠ .error .bound := by
  sorry

/-! ## L8 resolution (RULES.md §6) -/

/-- Selection reads no cell: a key's selected revision is chosen among its eligible revisions by fetchedAt and
tombstone alone, so two stores whose eligible revisions of the key have the same fetchedAt and tombstone flags, in
the same order, select revisions at the same positions. -/
theorem L8_selection (st₁ st₂ : Stored) (s : Nat) (V : Int) (coin : Nat) (event : Int)
    (h : (st₁.eligible s V coin event).map (fun r => (r.fetchedAt, r.tombstone))
       = (st₂.eligible s V coin event).map (fun r => (r.fetchedAt, r.tombstone))) :
    ((st₁.select s V coin event).map fun (a, b) => (a.fetchedAt, b.fetchedAt))
      = ((st₂.select s V coin event).map fun (a, b) => (a.fetchedAt, b.fetchedAt)) := by
  sorry

/-- An observation is never known before what it was resolved from: its effective knownAt is at least its rule's
value, its fetchedAt if it is a correction, and every dependency's upstream knownAt plus its delay. -/
theorem L8_known (reg : Registry) (st : Stored) (V : Int) (fuel s coin : Nat) (event k : Int) (sel first : Revision)
    (hS : st.select s V coin event = some (sel, first)) (hK : effectiveKnown reg st V (fuel + 1) s coin event = some (.ok k)) :
    (isCorrection sel first = true → sel.fetchedAt ≤ k) ∧
    ∀ dep ∈ (reg.decls[s]!).deps, ∀ up ∈ ((sel.upstream.find? (·.1 == dep.name)).map (·.2)).getD [],
      ∀ t, effectiveKnown reg st V fuel dep.source up.1 up.2 = some (.ok t) → t + dep.lag ≤ k := by
  sorry

/-! ## L7 input reads -/

/-- After the tick at hour H = wStart + n·HOUR, an input node's value for a coin listed at H is the field of the
last observation of its declaration and coin delivered by H + δ, if the declaration is held; if it is an event
source, the same only when that observation's slot is H; otherwise undefined. Never a default. -/
theorem L7_reads (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : p.WF reg) (adm : Meta)
    (obs : Array (Obs α)) (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (req : List Nat)
    (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) (n : Nat) (ms : MState α)
    (h : (Ctx.make reg roles p adm obs v pol stop req).machineAfter N n = .ok ms)
    (i : Nat) (hi : i < p.nodes.size) (inp : Input) (hn : p.nodes[i]! = .input inp) (x : Nat)
    (hx : (Ctx.make reg roles p adm obs v pol stop req).listed x (pol.wStart + (n : Int) * HOUR) = true) :
    let r := (((Ctx.make reg roles p adm obs v pol stop req).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)).filter
      fun o => o.source == inp.source && o.coin == x).getLast?
    ms.vals[i]![x]! =
      (if inp.event && !(r.any (·.slot == some (pol.wStart + (n : Int) * HOUR))) then none
       else (r.bind (·.vals[inp.field]!)).bind N.keep) := by
  sorry

end Ref
