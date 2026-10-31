import Ref.Spec
import Ref.Resolve
import Ref.Proof.Checker
import Ref.Proof.Admission
import Ref.Proof.Shape
import Ref.Proof.Resolve
import Ref.Proof.Bound
import Ref.Proof.Sim
import Ref.Proof.Units
import Ref.Proof.Reads
import Ref.Proof.Fills
import Ref.Proof.Orders
import Ref.Proof.Prefix
import Ref.Proof.RewriteLaw
import Ref.Proof.View
import Ref.Proof.Text

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
   intro k hk
   apply machineAfter_agree N (make_agree reg roles p adm obs₁ obs₂ v pol stop req _ hP) k
   change pol.wStart + (k : Int) * HOUR + pol.delta ≤ pol.wStart + (n : Int) * HOUR + pol.delta
   simp only [HOUR]
   omega

/-- The simulator's machine is that schedule: after j steps, it is the machine after the tick at wStart + 4j·HOUR. -/
theorem L1_simulator (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (_ : CheckerAccepted reg p)
    (_ : roles.valid reg = true) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy) (_ : pol.Valid)
    (stop : Int) (req : List Nat) (_ : (Ctx.make reg roles p adm obs v pol stop req).admissible = true)
    (j : Nat) (s : SState α) (hj : j ≤ (Ctx.make reg roles p adm obs v pol stop req).bounds.length)
    (h : (Ctx.make reg roles p adm obs v pol stop req).steps N j = .ok s) :
    (Ctx.make reg roles p adm obs v pol stop req).machineAfter N (4 * j) = .ok s.machine := by
  obtain ⟨t, ht, hp⟩ := steps_proj N _ j hj s h
  rw [Ctx.machineAfter_eq, ht]
  exact congrArg (fun x => Except.ok x.1) hp

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
   let c₁ := Ctx.make reg roles p adm obs₁ v pol stop req
   let c₂ := Ctx.make reg roles p adm obs₂ v pol stop req
   let T := pol.wStart + ((k : Int) + 1) * BAR + pol.delta
   have hE' : c₁.execView T = c₂.execView T := hE
   simp only [Ctx.execView, Prod.mk.injEq] at hE'
   have S : SameView c₁ c₂ T := ⟨make_l4Valid reg roles p adm obs₁ v pol stop req ‹_›,
     make_l4Valid reg roles p adm obs₂ v pol stop req ‹_›, hE'.2.2.2, rfl, hE'.1, hE'.2.1, hE'.2.2.1⟩
   have A : Agree c₁ c₂ T := make_agree reg roles p adm obs₁ obs₂ v pol stop req T hP
   have hp : pol.Valid := ‹_›
   simp only [Policy.Valid, Policy.valid, Bool.and_eq_true, decide_eq_true_eq] at hp
   intro j hj
   have htime : pol.wStart + (j : Int) * BAR + pol.delta ≤ T := by
     dsimp only [T]
     simp only [BAR, HOUR]
     omega
   exact congrArg (fun e : Except Abort (SState α) => e.map (·.trace))
     (steps_view p v pol stop N S A (by omega) j htime)

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
  have hW : p.WF reg := check_wf (show CheckerAccepted reg p from ‹_›).2.choose_spec
  have hc := umachine_corr N (Ctx.make reg roles p adm obs v pol stop req) hW n
  cases hu : (Ctx.make reg roles p adm obs v pol stop req).umachineAfter N n with
  | error e =>
    cases hm : (Ctx.make reg roles p adm obs v pol stop req).machineAfter N n <;>
      rw [hu, hm] at hc
    · cases e with
      | inl a =>
        cases hc
        simp [hu, hm]
      | inr e => exact hc.elim
    · cases e <;> exact hc.elim
  | ok u =>
    cases hm : (Ctx.make reg roles p adm obs v pol stop req).machineAfter N n with
    | error a => rw [hu, hm] at hc; exact hc.elim
    | ok ms =>
      rw [hu, hm] at hc
      refine ⟨by simp [hu], by simp [hu, hm], ?_⟩
      intro u' hu'
      have : u = u' := by simpa [hu] using hu'
      subst u'
      exact ⟨ms, hm, hc.vals, hc.wins, hc.since, hc.latest, fun i _ coin x t ht => hc.tagged i coin x t ht⟩

/-- The checker's programs are well-formed against the registry. -/
theorem L2_checker (reg : Registry) (p : Program) (h : CheckerAccepted reg p) : p.WF reg := by
  obtain ⟨_, _, hc⟩ := h
  exact check_wf hc

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
   obtain ⟨hw, hs, hm, ht, _⟩ := rewrite_sound N hN ‹p.WF reg› h
     (Ctx.make reg roles p adm obs v pol stop req)
   refine ⟨hw, fun s => by rw [hs], hm, ht, fun ld mode => ?_⟩
   exact runProgram_congr N reg roles p p' hs adm ld v pol stop mode fun obs req =>
     (rewrite_sound N hN ‹p.WF reg› h (Ctx.make reg roles p adm obs v pol stop req)).2.2.2.2

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
   let c := Ctx.make reg roles p adm obs v pol stop req
   change c.evaluate N = .ok r at hr
   unfold Ctx.evaluate at hr
   cases hs : c.steps N c.bounds.length with
   | error e => simp [hs, bind, Except.bind] at hr
   | ok s =>
     have hf := (steps_inv4 N c (make_l4Valid reg roles p adm obs v pol stop req ‹_›)
       c.bounds.length (Nat.le_refl _)) s hs
     simp only [hs, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hr
     subst r
     exact hf.fills

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
   let c := Ctx.make reg roles p adm obs v pol stop req
   change c.evaluate N = .ok r at hr
   unfold Ctx.evaluate at hr
   cases hs : c.steps N c.bounds.length with
   | error e => simp [hs, bind, Except.bind] at hr
   | ok s =>
     obtain ⟨h4, hl, hsol, hsize⟩ := L4Orders.steps_ledger N c
       (make_l4Valid reg roles p adm obs v pol stop req ‹_›) c.bounds.length (Nat.le_refl _) s hs
     simp only [hs, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hr
     subst r
     dsimp only
     have hpend : ∀ o ∈ s.orders.map (·.2), c.stop < o.decided - c.pol.delta + 3 * BAR := by
       intro o ho
       obtain ⟨e, he, rfl⟩ := List.mem_map.mp ho
       have ht := (h4.orders e he).2.1
       have := bounds_end c
       rw [ht]
       simp only [BAR, HOUR] at *
       omega
     have hdone := hl.drop hpend
     constructor
     · intro i t coin w q hi hstop
       have hi' : s.trace.toList[i]? = some (Event.decision t coin w q) := by simpa using hi
       obtain h | h | h := hdone.fate i t coin w q hi'
       · simp at h
       · obtain ⟨j, hij, e, he, hres⟩ := h
         refine ⟨⟨j, hij, e, by simpa using he, hres, ?_⟩, ?_⟩
         · intro j' e' he' hres'
           exact L4Orders.key_index hdone.rnodup (by simpa using he') he
             (L4Orders.rkey_of_resolves hres') (L4Orders.rkey_of_resolves hres)
         · constructor
           · rintro ⟨⟨bar, hb, htr⟩, k, eq, hk, ht, hpos⟩
             rcases hres with ⟨f, rfl, hw, hc, hd, hq⟩ | rfl
             · exact ⟨f, List.mem_of_getElem? he, hw, hc, hd⟩
             · rcases hdone.unfilled _ _ _ (List.mem_of_getElem? he) with hn | hn
               · have := hn bar hb; omega
               · obtain ⟨k', eq', hk', ht', hneg⟩ := hn
                 have hkk : k = k' := by simp only [c, Ctx.make, BAR, HOUR] at ht'; simp only [BAR, HOUR] at ht; omega
                 subst k'
                 have heq : eq = eq' := by simpa only [hk, Option.some.injEq] using hk'
                 subst eq'
                 rw [hpos] at hneg
                 cases hneg
           · rintro ⟨f, hf, hw, hc, hd⟩
             have hfill := (h4.fills f hf).2.2.2.2.2.2.1 hw
             obtain ⟨_, htime, ⟨bar, hb, htr, _, _⟩, _⟩ := hfill
             refine ⟨⟨bar, ?_, htr⟩, ?_⟩
             · simpa only [htime, hc, hd, c, Ctx.make] using hb
             · have hp := hsol f hf hw
               simpa only [L4Orders.Solvent, htime, hd, c, Ctx.make] using hp
       · exact (by change stop < t - pol.delta + 3 * BAR at h; omega)
     · intro j f hj hw
       have hj' : s.trace.toList[j]? = some (Event.fill f) := by simpa using hj
       obtain ⟨i, w, q, hij, hi, hres⟩ := hdone.cause j (.fill f) f.decided f.coin hj'
         (by simp [L4Orders.rkey, hw])
       have hq : f.qty = q := by
         rcases hres with ⟨f', he, _, _, _, hq⟩ | he
         · cases he; exact hq
         · cases he
       subst q
       refine ⟨i, w, hij, by simpa using hi, ?_⟩
       intro i' w' hi'
       exact L4Orders.key_index hdone.dnodup (by simpa using hi') hi rfl rfl

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
  unfold run at h
  rcases hA : admission reg roles text adm ld v pol stop mode with ke | c <;>
    simp only [hA, Except.mapError, bind, Except.bind] at h <;> try contradiction
  obtain ⟨hr, hp, p, hk, hc⟩ := admission_ok hA
  obtain ⟨req, obs, h1, h2, h3, rfl, had, hsc⟩ := admit_ok hc
  exact ⟨hr, hp, p, req, obs, hk, h1, h2, h3, had, hsc, h⟩

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
  constructor
  · intro k e h
    unfold firstFailure failureOf at h
    unfold run
    split at h
    · rename_i ke hA
      injection h with h
      subst h
      simp only [hA, Except.mapError, bind, Except.bind]
    · contradiction
  · intro h
    unfold firstFailure failureOf at h
    split at h
    · contradiction
    · rename_i c hA
      obtain ⟨-, -, p, hk, hc⟩ := admission_ok hA
      obtain ⟨req, obs, h1, -, h3, rfl, -, -⟩ := admit_ok hc
      obtain rfl := stage1_required h1
      refine ⟨p, obs, hk, h3, ?_⟩
      unfold run
      simp only [hA, Except.mapError, bind, Except.bind]

/-- The checks before resolution read no observation: two loaders with the same event-time rows fail at the same
check among positions 0 to 5, or at none of them. -/
theorem L5_staged (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld₁ ld₂ : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) (hR : ld₁.rows = ld₂.rows) :
    (firstFailure reg roles text adm ld₁ v pol stop mode).filter (·.1 ≤ 5)
      = (firstFailure reg roles text adm ld₂ v pol stop mode).filter (·.1 ≤ 5) := by
  unfold firstFailure admission
  simp only [bind, Except.bind, Except.mapError, throw, throwThe, MonadExceptOf.throw]
  cases reg.valid <;> cases pol.valid <;> simp only [Bool.not_false, Bool.not_true, Bool.or_false, Bool.or_true,
    ite_true, ite_false] <;> try rfl
  cases check reg.inputs text <;> simp only [Bool.false_eq_true, ite_false] <;> try rfl
  rw [admit_early, admit_early, hR]

/-- The checks after resolution never read an observation's values: resolutions of the same shape (both invalid,
or the same keys, slots, knownAt, coins, value counts and role kinds) fail at the same check, or at none. -/
theorem L5_shape (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld₁ ld₂ : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) (hR : ld₁.rows = ld₂.rows)
    (hS : ∀ req, (ld₁.resolve req).isSome = (ld₂.resolve req).isSome ∧ ∀ o₁ o₂, ld₁.resolve req = some o₁ →
      ld₂.resolve req = some o₂ → o₁.size = o₂.size ∧ ∀ i < o₁.size, (o₁[i]!).sameShape o₂[i]! = true) :
    firstFailure reg roles text adm ld₁ v pol stop mode = firstFailure reg roles text adm ld₂ v pol stop mode := by
  unfold firstFailure admission
  simp only [bind, Except.bind, Except.mapError, throw, throwThe, MonadExceptOf.throw]
  cases reg.valid <;> cases pol.valid <;> simp only [Bool.not_false, Bool.not_true, Bool.or_false, Bool.or_true,
    ite_true, ite_false] <;> try rfl
  cases check reg.inputs text <;> simp only <;> try rfl
  exact admit_shape reg roles _ adm ld₁ ld₂ v pol stop mode hR hS

/-- Every declaration the program text names, in an unused let or an inactive branch included, is required. -/
theorem L5_text (reg : Registry) (_ : reg.Valid) (roles : Roles) (adm : Meta) (text name : String) (p : Program)
    (inp : Input) (h : check reg.inputs text = .ok p) (hR : InputRef text name) (hN : (name, inp) ∈ reg.inputs.toList) :
    inp.source ∈ adm.required reg roles p :=
  text_required reg ‹_› roles adm text name p inp h hR hN

/-- Under the trusted boundary, an admitted run evaluated RULES.md §6's resolution of the required datasets' stored
bytes at the pinned version; every required dataset is named by an issued, current certificate under the pinned
policy and verifier; and a search run's required datasets are no holdout dataset and hold no stored row at or after
the holdout start. -/
theorem L5_certified (N : NumOps α) (num : Cell → Option α) (hash : Cert → Hash) (declHash : Decl → Hash)
    (policy verifier : Hash)
    (holdout : List Hash) (holdoutStart : Int) (st : Stored) (led : Ledger) (reg : Registry) (roles : Roles)
    (text : String) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode)
    (hT : Trusted num hash declHash policy verifier holdout holdoutStart reg st led adm ld) (r : Run α)
    (h : run N reg roles text adm ld v pol stop mode = .ok r) :
    ∃ p obs, check reg.inputs text = .ok p ∧ resolveAll num reg st adm.version (adm.required reg roles p) = some obs ∧
      (Ctx.make reg roles p adm obs v pol stop (adm.required reg roles p)).evaluate N = .ok r ∧
      ∀ s ∈ adm.required reg roles p, ∃ b k, adm.bindings s = some b ∧ adm.cert b.cert = some k ∧ k ∈ led.issued ∧
        k.manifest = st.identity s ∧ k.policy = policy ∧ k.verifier = verifier ∧
        !(led.supersessions.any fun (x, pos) => x == k.id && decide (pos ≤ led.position)) ∧
        (mode = .search → st.identity s ∉ holdout ∧ ∀ row ∈ st.rows s, row.event < holdoutStart) := by
  obtain ⟨-, -, p, req, obs, hk, h1, h2, h3, -, -, he⟩ := L5_admitted N reg roles text adm ld v pol stop mode r h
  obtain rfl := stage1_required h1
  refine ⟨p, obs, hk, (hT.resolve _).symm.trans h3, he, fun s hs => ?_⟩
  obtain ⟨b, k, hb, hkc, hv, hm, hhold⟩ := stage1_facts h1 s hs
  have hkm : k ∈ adm.certs := List.mem_of_find?_eq_some hkc
  have hkid : k.id = b.cert := by simpa using List.find?_some hkc
  simp only [Meta.matches, Bool.and_eq_true, beq_iff_eq] at hm
  have hsup : (adm.supersessions.any fun (x, pos) => x == b.cert && decide (pos ≤ adm.position)) = false := by
    revert hv
    cases hl : adm.certs.length with
    | zero => simp [Meta.valid]
    | succ n => simp only [Meta.valid, hkc, Bool.and_eq_true]; exact fun hv => by simpa using hv.1
  obtain ⟨⟨⟨⟨⟨⟨-, hman⟩, hpol⟩, hver⟩, -⟩, -⟩, -⟩ := hm
  refine ⟨b, k, hb, hkc, hT.issued k hkm, hman.trans (hT.identity s b hb), hpol.trans hT.pinned.1,
    hver.trans hT.pinned.2, ?_, fun hmode => ⟨?_, fun row hrow => ?_⟩⟩
  · rw [← hT.supersessions, ← hT.position, hkid]; simpa using hsup
  · rw [← hT.identity s b hb, ← hT.frozenHoldout.1]; exact hhold hmode
  · subst hmode
    unfold stage2 at h2
    split at h2 <;> try contradiction
    rename_i hrows
    simp only [beq_self_eq_true, Bool.true_and, Bool.not_eq_true', Bool.not_eq_false] at hrows
    have := List.all_eq_true.mp hrows (s, row.event) (by rw [hT.rows]; exact List.mem_flatMap.mpr ⟨s, hs, List.mem_map.mpr ⟨row, hrow, rfl⟩⟩)
    rw [← hT.frozenHoldout.2]; simpa using this

/-! ## L6 bounded loss -/

/-- Losses are capped at equity: R_BOUND, the check every step return passes before it is recorded (return ≥ −1),
never fires, for every evaluation, as in version 1, and so for every run. -/
theorem L6_bounded (N : NumOps α) (hB : N.Bounded) :
    (∀ (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy)
      (stop : Int) (req : List Nat), (Ctx.make reg roles p adm obs v pol stop req).evaluate N ≠ .error .bound) ∧
    ∀ (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy)
      (stop : Int) (mode : Mode), run N reg roles text adm ld v pol stop mode ≠ .error .bound := by
  constructor
  · intro reg roles p adm obs v pol stop req
    exact evaluate_bounded N hB _
  · intro reg roles text adm ld v pol stop mode
    unfold run
    exact Except.Avoids.bind (admission_not_bound reg roles text adm ld v pol stop mode)
      (fun c => evaluate_bounded N hB c)

/-! ## L8 resolution (RULES.md §6, bitemporal revision of 2026-10-26) -/

/-- A key's timeline never goes back: its revisions are delivered in fetchedAt order, each known no earlier than the
one it replaces, so the latest delivered revision is always the newest known. -/
theorem L8_monotone (reg : Registry) (st : Stored) (V : Int) (ok : Nat → Revision → Bool) (fuel s coin : Nat)
    (event : Int) :
    let tl := timeline reg st V ok fuel s coin event
    ∀ i, i + 1 < tl.length → (tl[i]!).rev.fetchedAt ≤ (tl[i + 1]!).rev.fetchedAt ∧ (tl[i]!).known ≤ (tl[i + 1]!).known := by
  dsimp only
  intro i hi
  have hs := timeline_ordered reg st V ok fuel s coin event
  simpa only [getElem!_pos (timeline reg st V ok fuel s coin event) i (by omega),
    getElem!_pos (timeline reg st V ok fuel s coin event) (i + 1) hi] using
    (List.pairwise_iff_getElem.mp hs i (i + 1) (by omega) hi (by omega))

/-- Nothing is known before it was recorded or before what it was derived from: every delivered revision after a
key's first, correction or retraction, is known no earlier than its fetchedAt; the first is never a retraction; and
every delivered value is known no earlier than each dependency's upstream knownAt plus its delay, for the upstream
deliveries recorded no later than the value itself (revised 2026-10-26, `audit/stage7/laws-frozen.md`). -/
theorem L8_known (reg : Registry) (_ : reg.Valid) (st : Stored) (V : Int) (ok : Nat → Revision → Bool)
    (fuel s coin : Nat) (event : Int) :
    let tl := timeline reg st V ok (fuel + 1) s coin event
    (∀ i, 0 < i → i < tl.length → (tl[i]!).rev.fetchedAt ≤ (tl[i]!).known) ∧
    (∀ e ∈ tl.head?, e.retraction = false) ∧
    ∀ e ∈ tl, e.retraction = false → ∀ dep ∈ (reg.decls[s]!).deps,
      ∀ up ∈ ((e.rev.upstream.find? (·.1 == dep.name)).map (·.2)).getD [],
      ∀ u ∈ timeline reg st V ok fuel dep.source up.1 up.2, u.retraction = false → u.rev.fetchedAt ≤ e.rev.fetchedAt →
        u.known + dep.lag ≤ e.known := by
  exact timeline_known reg st V ok fuel s coin event

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
   exact Reads.read_input N reg roles p ‹p.WF reg› adm obs v pol stop req ‹_› n ms h i hi inp hn x hx

end Ref
