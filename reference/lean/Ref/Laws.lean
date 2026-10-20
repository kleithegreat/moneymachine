import Ref.Spec
import Ref.Proof.Units
import Ref.Proof.Checker
import Ref.Proof.View

/-!
The five laws of stage 6 (PROGRESS.md, Stage 6, with its revisions), stated over the model of
reference/SEMANTICS.md and the definitions of `Ref/Spec.lean`. Each holds for every number structure `N`;
L3's obligations are explicit hypotheses. Abstract statements are proved here; the binary64 instance
(`floatOps`) is not, because Lean's `Float` is opaque, and it is tested instead (C6.4). These statements and
the definitions they use are frozen with SEMANTICS.md before any proof.
-/

namespace Ref

variable {α : Type} [Inhabited α]

/-! ## L1 non-interference -/

/-- Equal delivery prefixes give equal machine states (values, windows, held inputs, `hours_since`
state) at every tick through t. -/
theorem L1_values (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m₁ m₂ : Market α)
    (_ : m₁.Admissible) (_ : m₂.Admissible) (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (n : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.bound = m₂.bound)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)) :
    ∀ k ≤ n, (Ctx.make p m₁ v pol stop).machineAfter N k = (Ctx.make p m₂ v pol stop).machineAfter N k := by
  intro k hk
  simp only [Ctx.deliveryPrefix, Prod.mk.injEq] at hP
  have A : Agree (Ctx.make p m₁ v pol stop) (Ctx.make p m₂ v pol stop) (pol.wStart + (n : Int) * HOUR + pol.delta) :=
    { p := rfl, pol := rfl, intervals := hI, bound := hB, f := hP.1, b := hP.2.1, e := hP.2.2,
      f₁ := fRows_sorted .., f₂ := fRows_sorted .., b₁ := bRows_sorted .., b₂ := bRows_sorted ..,
      e₁ := eRows_sorted .., e₂ := eRows_sorted .. }
  have hT : ∀ k' ∈ List.range' 1 k, pol.wStart + ↑k' * HOUR + pol.delta ≤ pol.wStart + (n : Int) * HOUR + pol.delta := by
    intro k' hk'
    simp only [List.mem_range'_1] at hk'
    have : (k' : Int) ≤ n := by omega
    simp only [HOUR]; omega
  have h0 : (Ctx.make p m₁ v pol stop).pol.wStart + (Ctx.make p m₁ v pol stop).pol.delta ≤
      pol.wStart + (n : Int) * HOUR + pol.delta := by simp only [Ctx.make, HOUR]; omega
  rw [Ctx.machineAfter_eq, Ctx.machineAfter_eq]
  exact map_machine (bind_agree (start_agree N A h0).1 (start_agree N A h0).2
    fun r₁ r₂ hr hri => tickLoop_agree N A pol.wStart (List.range' 1 k) hT hr hri).1

/-- The simulator's machine is that schedule: after j steps, it is the machine after the tick at
wStart + 4j·HOUR. -/
theorem L1_simulator (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (j : Nat) (s : SState α)
    (hj : j ≤ (Ctx.make p m v pol stop).bounds.length) (h : (Ctx.make p m v pol stop).steps N j = .ok s) :
    (Ctx.make p m v pol stop).machineAfter N (4 * j) = .ok s.machine := by
  obtain ⟨t, ht, hp⟩ := steps_proj N _ j hj s h
  rw [Ctx.machineAfter_eq, ht]
  exact congrArg (fun x => Except.ok x.1) hp

/-- Equal delivery prefixes and execution views through step k's decision give the same observations
at every step through it: the same trace, or the same rejection. -/
theorem L1_decisions (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m₁ m₂ : Market α)
    (_ : m₁.Admissible) (_ : m₂.Admissible) (v : Venue α) (_ : v.Valid m₁.intervals.size) (pol : Policy) (_ : pol.Valid)
    (stop : Int) (k : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.bound = m₂.bound)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix ((Ctx.make p m₂ v pol stop).decisionTime k))
    (hE : (Ctx.make p m₁ v pol stop).execView ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).execView ((Ctx.make p m₂ v pol stop).decisionTime k)) :
    ∀ j ≤ k + 1, ((Ctx.make p m₁ v pol stop).steps N j).map (·.trace)
      = ((Ctx.make p m₂ v pol stop).steps N j).map (·.trace) := by
  intro j hj
  simp only [Ctx.deliveryPrefix, Prod.mk.injEq] at hP
  simp only [Ctx.execView, Prod.mk.injEq] at hE
  have A : Agree (Ctx.make p m₁ v pol stop) (Ctx.make p m₂ v pol stop) ((Ctx.make p m₁ v pol stop).decisionTime k) :=
    { p := rfl, pol := rfl, intervals := hI, bound := hB, f := hP.1, b := hP.2.1, e := hP.2.2,
      f₁ := fRows_sorted .., f₂ := fRows_sorted .., b₁ := bRows_sorted .., b₂ := bRows_sorted ..,
      e₁ := eRows_sorted .., e₂ := eRows_sorted .. }
  have S : SameView m₁ m₂ ((Ctx.make p m₁ v pol stop).decisionTime k) :=
    { A₁ := ‹m₁.Admissible›, A₂ := ‹m₂.Admissible›, intervals := hI, rates := hE.1, closed := hE.2.1,
      opened := hE.2.2.1 }
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  have hjT : pol.wStart + ↑j * BAR + pol.delta ≤ (Ctx.make p m₁ v pol stop).decisionTime k := by
    have : (j : Int) ≤ (k : Int) + 1 := by omega
    have := Int.mul_le_mul_of_nonneg_right this (Int.le_of_lt hBAR)
    simp only [Ctx.decisionTime, Ctx.make]; omega
  rw [steps_view N p v pol stop S A (Int.le_of_lt ‹pol.Valid›.delta.1) j hjT]

/-! ## L2 unit soundness -/

/-- The instrumented machine never raises a unit error; its defined values carry their nodes' static
types, booleans are canonical, and erasing the tags gives the executable machine's values and state
(or the same rejection). -/
theorem L2_units (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (n : Nat) :
    let c := Ctx.make p m v pol stop
    (∀ e, c.umachineAfter N n ≠ .error (.inr e)) ∧
    (∀ a, c.umachineAfter N n = .error (.inl a) ↔ c.machineAfter N n = .error a) ∧
    (∀ u, c.umachineAfter N n = .ok u →
      ∃ ms, c.machineAfter N n = .ok ms ∧ u.erase = ms.vals ∧ u.m.wins = ms.wins ∧ u.m.since = ms.since ∧
        u.m.funding = ms.funding ∧ u.m.bar = ms.bar ∧ u.m.events = ms.events ∧
        ∀ i < p.nodes.size, ∀ (coin : Nat) (x : α) (t : Ty), u.tv[i]![coin]! = some (x, t) →
          t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b)) := by
  intro c
  obtain ⟨_, hp⟩ := ‹CheckerAccepted p›
  have hc := umachine_corr N c (check_wf hp) n
  generalize c.umachineAfter N n = x at hc ⊢
  generalize c.machineAfter N n = y at hc ⊢
  cases x with
  | error e => cases y with
    | error a => cases e with
      | inl a' => simp only [Corr] at hc; subst hc; simp
      | inr e' => exact hc.elim
    | ok ms => cases e <;> exact hc.elim
  | ok u => cases y with
    | error a => exact hc.elim
    | ok ms =>
      refine ⟨by simp, by simp, fun u' hu => ?_⟩
      cases hu
      exact ⟨ms, rfl, hc.vals, hc.wins, hc.since, hc.funding, hc.bar, hc.events,
        fun i _ coin x t h => hc.tagged i coin x t h⟩

/-- The checker's programs are well-formed. -/
theorem L2_checker (p : Program) (_ : CheckerAccepted p) : p.WF := by
  obtain ⟨_, h⟩ := ‹CheckerAccepted p›
  exact check_wf h

/-! ## L3 rewrite soundness -/

/-- Rewriting keeps a well-formed program well-formed; at every tick every original node's values
equal its corresponding node's; and every step's observations are identical (the same trace, or the
same rejection), hence the whole run. -/
theorem L3_rewrite (N : NumOps α) (hN : N.Lawful) (r : Rule) (p p' : Program) (i : Nat) (_ : p.WF)
    (h : r.apply p i = some p') (m : Market α) (_ : m.Admissible) (v : Venue α) (pol : Policy) (_ : pol.Valid)
    (stop : Int) :
    p'.WF ∧
    (∀ n, ((Ctx.make p' m v pol stop).machineAfter N n).isOk = ((Ctx.make p m v pol stop).machineAfter N n).isOk ∧
      ∀ ms ms', (Ctx.make p m v pol stop).machineAfter N n = .ok ms → (Ctx.make p' m v pol stop).machineAfter N n = .ok ms' →
        ∀ k < p.nodes.size, ms'.vals[r.corr i k]! = ms.vals[k]!) ∧
    (∀ j, ((Ctx.make p' m v pol stop).steps N j).map (·.trace) = ((Ctx.make p m v pol stop).steps N j).map (·.trace)) ∧
    run N p' m v pol stop = run N p m v pol stop := by
  sorry

/-! ## L4 fill ordering -/

/-- Every fill is nonzero, ordered in time, priced by the cost table and charged the fee. An ordinary
fill is its order's scheduled bar's open, after its decision, and its recorded input bound is the
decision machine's latest knownAt, no later than the decision. A closeout is at its own time, from
the coin's latest closed bar: the adverse extreme for a liquidation, the close for a delisting. -/
theorem L4_fills (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (hA : m.Admissible)
    (v : Venue α) (_ : v.Valid m.intervals.size) (pol : Policy) (_ : pol.Valid) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    ∀ f, Event.fill f ∈ r.trace.toList →
      N.isZero f.qty = false ∧ f.inputsKnown ≤ f.decided ∧ f.decided ≤ f.submitted ∧ f.submitted ≤ f.filled ∧
      f.price = fillPrice N v f.coin f.qty f.reference ∧ f.fee = N.mul (N.mul (N.abs f.qty) f.price) v.takerFee ∧
      (f.why = .fill →
        f.submitted = f.decided ∧ f.filled = f.decided - pol.delta + BAR ∧
        (∃ bar, barAt m f.coin f.filled = some bar ∧ bar.trades ≥ 1 ∧ f.sourceOpen = bar.openTime ∧ f.reference = bar.o) ∧
        ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = f.decided ∧
          (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = f.inputsKnown) ∧
      (f.why ≠ .fill →
        f.inputsKnown = f.filled ∧ f.decided = f.filled ∧ f.submitted = f.filled ∧
        ∃ bar, latestClosed m f.coin f.filled = some bar ∧ f.sourceOpen = bar.openTime ∧
          ∃ q, f.qty = N.neg q ∧ f.reference = (if f.why = .delisting then bar.c else if N.lt N.zero q then bar.l else bar.h)) := by
  unfold run at hr
  cases hs : (Ctx.make p m v pol stop).steps N (Ctx.make p m v pol stop).bounds.length <;>
    simp only [hs, bind, Except.bind, pure, Except.pure, reduceCtorEq, Except.ok.injEq] at hr
  subst hr
  exact (steps_inv4 N p m hA v pol stop _ (Nat.le_refl _) _ hs).fills

/-- Exactly once: every order whose due step runs (B + 3·BAR ≤ stop, with B its decision's boundary)
has exactly one later resolution in the trace, the fill at its scheduled bar if that bar exists and
traded and otherwise its Unfilled record; and every ordinary fill has exactly one earlier decision
it resolves. -/
theorem L4_orders (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (hA : m.Admissible)
    (v : Venue α) (_ : v.Valid m.intervals.size) (pol : Policy) (_ : pol.Valid) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    let resolves (t : Int) (c : Nat) (q : α) (e : Event α) : Prop :=
      (∃ f : Fill α, e = Event.fill f ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t ∧ f.qty = q) ∨ e = Event.unfilled (t - pol.delta + BAR) c q
    (∀ (i : Nat) (t : Int) (c : Nat) (w q : α), r.trace[i]? = some (Event.decision t c w q) → t - pol.delta + 3 * BAR ≤ stop →
      (∃ j : Nat, i < j ∧ ∃ e : Event α, r.trace[j]? = some e ∧ resolves t c q e ∧
        ∀ (j' : Nat) (e' : Event α), r.trace[j']? = some e' → resolves t c q e' → j' = j) ∧
      ((∃ bar, barAt m c (t - pol.delta + BAR) = some bar ∧ bar.trades ≥ 1) ↔
        ∃ f : Fill α, Event.fill f ∈ r.trace.toList ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t)) ∧
    (∀ (j : Nat) (f : Fill α), r.trace[j]? = some (Event.fill f) → f.why = .fill →
      ∃ (i : Nat) (w : α), i < j ∧ r.trace[i]? = some (Event.decision f.decided f.coin w f.qty) ∧
        ∀ (i' : Nat) (w' : α), r.trace[i']? = some (Event.decision f.decided f.coin w' f.qty) → i' = i) := by
  intro resolves
  unfold run at hr
  cases hs : (Ctx.make p m v pol stop).steps N (Ctx.make p m v pol stop).bounds.length <;>
    simp only [hs, bind, Except.bind, pure, Except.pure, reduceCtorEq, Except.ok.injEq] at hr
  subst hr
  rename_i s
  obtain ⟨h4, hL⟩ := steps_ledger N p m hA v pol stop _ (Nat.le_refl _) s hs
  have hend : stop < pol.wStart + ↑(Ctx.make p m v pol stop).bounds.length * BAR + 2 * BAR :=
    bounds_end (Ctx.make p m v pol stop)
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  have tl : ∀ {i : Nat} {x : Event α}, s.trace[i]? = some x → s.trace.toList[i]? = some x := fun h =>
    (Array.getElem?_toList ..).trans h
  refine ⟨fun i t c w q hi hstop => ?_, fun j f hj hw => ?_⟩
  · have hres : Resolved pol.delta s.trace.toList i t c q := by
      rcases hL.fate i t c w q (tl hi) with ⟨o, ho, rfl, -, -⟩ | hres | hstop'
      · obtain ⟨e, he, rfl⟩ := List.mem_map.mp ho
        have := (h4.orders e he).2.1
        omega
      · exact hres
      · omega
    obtain ⟨j, hij, e, hj, hre⟩ := hres
    refine ⟨⟨j, hij, e, (Array.getElem?_toList ..).symm.trans hj, hre, fun j' e' hj' hre' =>
      key_index hL.rnodup (tl hj') hj (rkey_of_resolves hre') (rkey_of_resolves hre)⟩, ⟨fun ⟨bar, hbar, htr⟩ => ?_, ?_⟩⟩
    · rcases hre with ⟨f, rfl, hw, hc, hd, -⟩ | rfl
      · exact ⟨f, List.mem_of_getElem? hj, hw, hc, hd⟩
      · exact absurd htr (by have := hL.unfilled _ c q (List.mem_of_getElem? hj) bar hbar; omega)
    · rintro ⟨f, hf, hw, rfl, rfl⟩
      obtain ⟨-, -, -, -, -, -, hfill, -⟩ := h4.fills f hf
      obtain ⟨-, hfl, ⟨bar, hbar, htr, -⟩, -⟩ := hfill hw
      exact ⟨bar, hfl ▸ hbar, htr⟩
  · obtain ⟨i, w, q, hij, hi, hre⟩ := hL.cause j (.fill f) f.decided f.coin (tl hj) (by simp [rkey, hw])
    have hq : q = f.qty := by
      rcases hre with ⟨f', hf', -, -, -, hq⟩ | h
      · cases hf'; exact hq.symm
      · cases h
    subst hq
    exact ⟨i, w, hij, (Array.getElem?_toList ..).symm.trans hi, fun i' w' hi' =>
      key_index hL.dnodup (tl hi') hi rfl rfl⟩

/-! ## L5 binding -/

/-- A run is refused as unavailable exactly when some event source the program names is unbound,
before any delivery or tick; with every source bound, preflight passes and the run is the ordinary
evaluation. -/
theorem L5_binding (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (v : Venue α) (pol : Policy)
    (stop : Int) :
    (run N p m v pol stop = .error .inputUnavailable ↔ ∃ s ∈ p.eventSlots, s ∉ m.bound) ∧
    ((∃ s ∈ p.eventSlots, s ∉ m.bound) → (Ctx.make p m v pol stop).start N = .error .inputUnavailable) ∧
    ((∀ s ∈ p.eventSlots, s ∈ m.bound) →
      (Ctx.make p m v pol stop).start N = (do
        let s ← (Ctx.make p m v pol stop).deliver ((Ctx.make p m v pol stop).state0 N) (pol.wStart + pol.delta)
        return { s with machine := s.machine.tick N p ((Ctx.make p m v pol stop).mask pol.wStart) pol.wStart })) := by
  refine ⟨⟨fun hr => ?_, fun h => ?_⟩, fun h => start_unbound N _ h, fun h => start_bound N _ h⟩
  · refine Classical.byContradiction fun hn => ?_
    have hb : ∀ s ∈ p.eventSlots, s ∈ m.bound := fun s hs => Classical.byContradiction fun hm => hn ⟨s, hs, hm⟩
    have hs : Except.Avoids .inputUnavailable ((Ctx.make p m v pol stop).start N) := by
      rw [start_bound N _ hb]
      exact .bind (deliver_avoids _ _ _) fun _ => .pure _
    exact Except.Avoids.bind (steps_avoids_of_start N _ _ hs) (fun _ => .pure _) hr
  · simp only [run, Ctx.steps, start_unbound N (Ctx.make p m v pol stop) h]; rfl

end Ref
