import Ref.Sim

/-! Which errors a computation can raise: closure lemmas for `Except`, and the simulator's steps never
raise R_INPUT_UNAVAILABLE. -/

namespace Ref

/-- x never fails with error e. -/
def Except.Avoids {ε β} (e : ε) (x : Except ε β) : Prop := x ≠ .error e

namespace Except.Avoids
variable {ε β γ : Type} {e : ε}

theorem pure (b : β) : Avoids e (Except.pure b : Except ε β) := by
  intro h; cases h

theorem ok (b : β) : Avoids e (Except.ok b : Except ε β) := by
  intro h; cases h

theorem throw {e' : ε} (h : e' ≠ e) : Avoids e (Except.error e' : Except ε β) := by
  intro h'; cases h'; exact h rfl

theorem bind {x : Except ε β} {f : β → Except ε γ} (hx : Avoids e x) (hf : ∀ b, Avoids e (f b)) :
    Avoids e (x >>= f) := by
  intro h
  cases x with
  | error e' => exact hx (by simpa [Bind.bind, Except.bind] using h)
  | ok b => exact hf b (by simpa [Bind.bind, Except.bind] using h)

theorem ite {c : Prop} [Decidable c] {x y : Except ε β} (hx : Avoids e x) (hy : Avoids e y) :
    Avoids e (if c then x else y) := by
  split <;> assumption

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Except ε (ForInStep σ))
    (hf : ∀ b s, Avoids e (f b s)) : Avoids e (forIn l init f) := by
  induction l generalizing init with
  | nil => exact ok init
  | cons b bs ih =>
    simp only [List.forIn_cons]
    apply bind (hf b init)
    intro r
    cases r with
    | done s => exact ok s
    | yield s => exact ih s

end Except.Avoids

open _root_.Ref.Except in
section
variable {α : Type} [Inhabited α]

theorem deliverFunding_avoids (c : Ctx α) (s : SState α) (tick : Int) :
    Avoids .inputUnavailable (c.deliverFunding s tick) := by
  fun_induction Ctx.deliverFunding c s tick <;> simp_all [Avoids]

theorem deliverBars_avoids (c : Ctx α) (s : SState α) (tick : Int) :
    Avoids .inputUnavailable (c.deliverBars s tick) := by
  fun_induction Ctx.deliverBars c s tick <;> simp_all [Avoids]

theorem deliverEvents_avoids (c : Ctx α) (s : SState α) (tick : Int) :
    Avoids .inputUnavailable (c.deliverEvents s tick) := by
  fun_induction Ctx.deliverEvents c s tick <;> simp_all [Avoids]

theorem deliver_avoids (c : Ctx α) (s : SState α) (tick : Int) : Avoids .inputUnavailable (c.deliver s tick) := by
  unfold Ctx.deliver
  exact Avoids.bind (deliverFunding_avoids _ _ _) fun _ =>
    Avoids.bind (deliverBars_avoids _ _ _) fun _ => deliverEvents_avoids _ _ _

theorem checkFill_avoids (N : NumOps α) (f : Fill α) (m : Market α) (ix : Index α) (v : Venue α) :
    Avoids .inputUnavailable (checkFill N f m ix v) := by
  unfold checkFill
  simp only [Avoids]
  repeat' split
  all_goals simp_all [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]

/-- Walk a do-block: binds, loops over lists, conditionals and matches, down to leaves that cannot
raise R_INPUT_UNAVAILABLE. -/
macro "avoid" : tactic => `(tactic| repeat (first
  | exact Except.Avoids.ok _
  | exact Except.Avoids.pure _
  | (apply Except.Avoids.throw; decide)
  | exact deliver_avoids _ _ _
  | exact checkFill_avoids _ _ _ _ _
  | (refine Except.Avoids.ite ?_ ?_)
  | (refine Except.Avoids.bind ?_ (fun _ => ?_))
  | (refine Except.Avoids.forIn_list _ _ _ (fun _ _ => ?_))
  | split))

theorem step_avoids (N : NumOps α) (c : Ctx α) (s : SState α) (b : Int) :
    Avoids .inputUnavailable (c.step N s b) := by
  unfold Ctx.step Ctx.execute Ctx.closeout
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  avoid

/-- Once preflight has passed, no later step raises R_INPUT_UNAVAILABLE. -/
theorem steps_avoids_of_start (N : NumOps α) (c : Ctx α) (k : Nat) (h : Avoids .inputUnavailable (c.start N)) :
    Avoids .inputUnavailable (c.steps N k) := by
  unfold Ctx.steps
  refine Avoids.bind h (fun _ => ?_)
  refine Avoids.bind (Avoids.forIn_list _ _ _ (fun _ _ => ?_)) (fun _ => Avoids.pure _)
  exact Avoids.bind (step_avoids _ _ _ _) (fun _ => Avoids.pure _)

omit [Inhabited α] in
theorem bound_false_iff (c : Ctx α) : c.bound = false ↔ ∃ s ∈ c.p.eventSlots, s ∉ c.m.bound := by
  simp [Ctx.bound]

theorem start_unbound (N : NumOps α) (c : Ctx α) (h : ∃ s ∈ c.p.eventSlots, s ∉ c.m.bound) :
    c.start N = .error .inputUnavailable := by
  simp [Ctx.start, (bound_false_iff c).2 h, throw, throwThe, MonadExceptOf.throw]; rfl

theorem start_bound (N : NumOps α) (c : Ctx α) (h : ∀ s ∈ c.p.eventSlots, s ∈ c.m.bound) :
    c.start N = (do
      let s ← c.deliver (c.state0 N) (c.pol.wStart + c.pol.delta)
      return { s with machine := s.machine.tick N c.p (c.mask c.pol.wStart) c.pol.wStart }) := by
  have : c.bound = true := by
    cases hb : c.bound
    · obtain ⟨s, hs, hn⟩ := (bound_false_iff c).1 hb; exact absurd (h s hs) hn
    · rfl
  simp [Ctx.start, this]

end
end Ref
