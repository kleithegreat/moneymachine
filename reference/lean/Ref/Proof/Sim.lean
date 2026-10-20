import Ref.Spec
import Ref.Proof.Except

/-! Facts about the simulator: no step raises R_INPUT_UNAVAILABLE, and delivery and ticks touch only the
machine and the delivery cursors. -/

namespace Ref


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
section
variable {α : Type} [Inhabited α]

/-- The part of the simulator state that delivery and ticks touch: the machine and the cursors. -/
def SState.proj (s : SState α) : MState α × Nat × Nat × Nat := (s.machine, s.fi, s.bi, s.ei)

/-- o's book, trace and accounts with s's machine and cursors. -/
def SState.graft (o s : SState α) : SState α := { o with machine := s.machine, fi := s.fi, bi := s.bi, ei := s.ei }

theorem deliverFunding_graft (c : Ctx α) (o s : SState α) (t : Int) :
    c.deliverFunding (o.graft s) t = (c.deliverFunding s t).map o.graft := by
  fun_induction Ctx.deliverFunding c s t <;> rw [Ctx.deliverFunding] <;> simp_all (config := { zetaDelta := true }) [SState.graft, Except.map]
  all_goals intro; omega
theorem deliverBars_graft (c : Ctx α) (o s : SState α) (t : Int) :
    c.deliverBars (o.graft s) t = (c.deliverBars s t).map o.graft := by
  fun_induction Ctx.deliverBars c s t <;> rw [Ctx.deliverBars] <;> simp_all (config := { zetaDelta := true }) [SState.graft, Except.map]
  all_goals intro; omega
theorem deliverEvents_graft (c : Ctx α) (o s : SState α) (t : Int) :
    c.deliverEvents (o.graft s) t = (c.deliverEvents s t).map o.graft := by
  fun_induction Ctx.deliverEvents c s t <;> rw [Ctx.deliverEvents] <;> simp_all (config := { zetaDelta := true }) [SState.graft, Except.map]
  all_goals intro; omega
theorem deliver_graft (c : Ctx α) (o s : SState α) (t : Int) :
    c.deliver (o.graft s) t = (c.deliver s t).map o.graft := by
  simp only [Ctx.deliver, bind, Except.bind, deliverFunding_graft]
  cases c.deliverFunding s t <;> simp [Except.map, deliverBars_graft]
  rename_i s1
  cases c.deliverBars s1 t <;> simp [Except.map, deliverEvents_graft]

omit [Inhabited α] in
theorem graft_self (o s : SState α) (h : o.proj = s.proj) : o.graft s = o := by
  cases o
  simp_all [SState.graft, SState.proj]

omit [Inhabited α] in
theorem proj_graft (o s : SState α) : (o.graft s).proj = s.proj := rfl

theorem execute_proj (N : NumOps α) (c : Ctx α) (s : SState α) (f : Fill α) :
    Except.Holds (c.execute N s f) (fun r => r.proj = s.proj) := by
  unfold Ctx.execute
  exact Except.Holds.bind (Q := fun (r : SState α) => r.proj = s.proj) (R := fun _ => True) (fun _ _ => trivial)
    fun _ _ => Except.Holds.pure _ rfl

/-- Deliveries then ticks at base + k·HOUR for each k in ks: the machine's schedule within a step. -/
def Ctx.tickLoop (N : NumOps α) (c : Ctx α) (base : Int) (ks : List Nat) (s : SState α) : Except Abort (SState α) :=
  forIn ks s fun (k : Nat) (s : SState α) => do
    let s ← c.deliver s (base + ↑k * HOUR + c.pol.delta)
    pure (ForInStep.yield { s with machine := s.machine.tick N c.p (c.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) })

theorem tickLoop_graft (N : NumOps α) (c : Ctx α) (base : Int) (ks : List Nat) (o s : SState α) :
    c.tickLoop N base ks (o.graft s) = (c.tickLoop N base ks s).map o.graft := by
  induction ks generalizing s with
  | nil => simp [Ctx.tickLoop, Except.map]; rfl
  | cons k ks ih =>
    simp only [Ctx.tickLoop, List.forIn_cons, bind, Except.bind, pure, Except.pure, deliver_graft] at ih ⊢
    cases c.deliver s (base + ↑k * HOUR + c.pol.delta) with
    | error e => rfl
    | ok r => exact ih { r with machine := r.machine.tick N c.p (c.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) }

theorem tickLoop_append (N : NumOps α) (c : Ctx α) (base : Int) (l₁ l₂ : List Nat) (s : SState α) :
    c.tickLoop N base (l₁ ++ l₂) s = c.tickLoop N base l₁ s >>= c.tickLoop N base l₂ :=
  Except.forIn_append_yield _ _ _ _ fun _ _ => Except.Holds.bind (fun _ _ => trivial)
    fun _ _ => Except.Holds.pure _ ⟨_, rfl⟩

theorem tickLoop_shift (N : NumOps α) (c : Ctx α) (base : Int) (a d k : Nat) (s : SState α) :
    c.tickLoop N base (List.range' (a + d) k) s = c.tickLoop N (base + ↑d * HOUR) (List.range' a k) s := by
  have e : ∀ i : Nat, base + ↑(d + i) * HOUR = base + ↑d * HOUR + ↑i * HOUR := by
    intro i; push_cast; rw [Int.add_mul]; omega
  have r : List.range' (a + d) k = (List.range' a k).map (d + ·) := by
    rw [List.map_add_range', Nat.add_comm]
  simp only [Ctx.tickLoop, r, List.forIn_map, e]

/-- Filtering a range by a predicate that, once false, stays false keeps a prefix of it. -/
theorem filterMap_range_prefix {β : Type} (n : Nat) (P : Nat → Prop) [DecidablePred P] (g : Nat → β)
    (hP : ∀ k, P (k + 1) → P k) :
    (List.range n).filterMap (fun k => if P k then some (g k) else none) = (List.range ((List.range n).countP P)).map g := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rw [List.range_succ, List.filterMap_append, ih, List.countP_append]
    by_cases h : P n
    · have all : ∀ k, k ≤ n → P k := by
        intro k hk
        obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hk
        clear hk ih
        induction d with
        | zero => exact h
        | succ d ihd => exact ihd (hP _ (by rwa [← Nat.add_assoc] at h))
      have : (List.range n).countP P = n := by
        rw [List.countP_eq_length.mpr fun k hk => by simpa using all k (by simp at hk; omega)]; simp
      simp [h, this, List.range_succ]
    · simp [h]

omit [Inhabited α] in
theorem bounds_eq (c : Ctx α) : c.bounds = (List.range c.bounds.length).map fun i => c.pol.wStart + ↑i * BAR := by
  have h := filterMap_range_prefix (((c.stop - c.pol.wStart) / BAR).toNat + 1)
    (fun k : Nat => c.pol.wStart + ↑k * BAR + 2 * BAR ≤ c.stop) (fun i : Nat => c.pol.wStart + ↑i * BAR)
    (fun k hk => by simp only [BAR, HOUR] at hk ⊢; push_cast at hk; omega)
  unfold Ctx.bounds at *
  simp only [h, List.length_map, List.length_range]

omit [Inhabited α] in
theorem bounds_take (c : Ctx α) (j : Nat) (hj : j ≤ c.bounds.length) :
    c.bounds.take j = (List.range j).map fun i => c.pol.wStart + ↑i * BAR := by
  rw [bounds_eq c, ← List.map_take, List.take_range, Nat.min_eq_left hj]

omit [Inhabited α] in
theorem Holds.forIn_proj {β : Type} (X : MState α × Nat × Nat × Nat) (l : List β) (init : SState α)
    (f : β → SState α → Except Abort (ForInStep (SState α))) (h0 : init.proj = X)
    (hf : ∀ a r, r.proj = X → Except.Holds (f a r) (fun st => st.value.proj = X)) :
    Except.Holds (forIn l init f) (fun r => r.proj = X) :=
  Except.Holds.forIn_list l init f _ h0 fun a _ r hr => hf a r hr

omit [Inhabited α] in
theorem Holds.forIn_projPair {β γ : Type} (X : MState α × Nat × Nat × Nat) (l : List β) (init : SState α × γ)
    (f : β → SState α × γ → Except Abort (ForInStep (SState α × γ))) (h0 : init.1.proj = X)
    (hf : ∀ a r, r.1.proj = X → Except.Holds (f a r) (fun st => st.value.1.proj = X)) :
    Except.Holds (forIn l init f) (fun r => r.1.proj = X) :=
  Except.Holds.forIn_list l init f (fun r => r.1.proj = X) h0 fun a _ r hr => hf a r hr

/-- A step's ticks from a state with s's machine and cursors give the machine and cursors that s's ticks
give. -/
theorem Holds.tickLoop_bind {γ : Type} {Q : γ → Prop} (N : NumOps α) (c : Ctx α) (b : Int) (ks : List Nat)
    (s s₃ : SState α) (g : SState α → Except Abort γ) (h : s₃.proj = s.proj)
    (hg : ∀ r, c.tickLoop N b ks s = .ok r → ∀ r₄, r₄.proj = r.proj → Except.Holds (g r₄) Q) :
    Except.Holds (c.tickLoop N b ks s₃ >>= g) Q := by
  rw [← graft_self s₃ s h, tickLoop_graft]
  cases ht : c.tickLoop N b ks s with
  | error e => intro x hx; simp [Except.map, bind, Except.bind] at hx
  | ok r => exact hg r ht (s₃.graft r) (proj_graft _ _)

theorem Holds.execute_bind {γ : Type} {Q : γ → Prop} (N : NumOps α) (c : Ctx α) (s : SState α) (f : Fill α)
    (X : MState α × Nat × Nat × Nat) (g : SState α → Except Abort γ) (hs : s.proj = X)
    (hg : ∀ r, r.proj = X → Except.Holds (g r) Q) : Except.Holds (c.execute N s f >>= g) Q :=
  Except.Holds.bind (execute_proj N c s f) fun r hr => hg r (hr.trans hs)

set_option hygiene false in
/-- One step of walking the simulator step: loops keep the machine and cursors, executions keep them,
and branches split. -/
macro "pwalk" : tactic => `(tactic| first
  | exact Except.Holds.throw' _
  | (refine Except.Holds.bind (Except.Holds.throw' _) fun _ _ => ?_)
  | exact Except.Holds.pure _ ‹_›
  | exact Except.Holds.pure _ ⟨r, hT, ‹_›⟩
  | (refine Holds.tickLoop_bind N c b (List.range' 1 4) s _ _ ‹_› fun r hT _ _ => ?_)
  | (refine Except.Holds.bind (Holds.forIn_proj _ _ _ _ ‹_› fun _ _ _ => ?_) fun _ _ => ?_)
  | (refine Except.Holds.bind (Holds.forIn_projPair _ _ _ _ ‹_› fun _ _ _ => ?_) fun _ _ => ?_)
  | (refine Holds.execute_bind _ _ _ _ _ _ ‹_› fun _ _ => ?_)
  | (refine Except.Holds.ite ?_ ?_)
  | split)

theorem step_proj (N : NumOps α) (c : Ctx α) (s : SState α) (b : Int) :
    Except.Holds (c.step N s b) (fun s' => ∃ r, c.tickLoop N b (List.range' 1 4) s = .ok r ∧ s'.proj = r.proj) := by
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  have h0 : s.proj = s.proj := rfl
  repeat' pwalk

theorem steps_eq (N : NumOps α) (c : Ctx α) (j : Nat) (hj : j ≤ c.bounds.length) :
    c.steps N j = c.start N >>= fun s₀ =>
      forIn ((List.range j).map fun i => c.pol.wStart + ↑i * BAR) s₀
        (fun b r => (do let r ← c.step N r b; pure (ForInStep.yield r))) := by
  unfold Ctx.steps
  rw [bounds_take c j hj]
  simp

/-- After j steps the simulator's machine and cursors are those of the first 4j hourly ticks. -/
theorem steps_proj (N : NumOps α) (c : Ctx α) (j : Nat) (hj : j ≤ c.bounds.length) :
    Except.Holds (c.steps N j)
      (fun s => ∃ t, (c.start N >>= c.tickLoop N c.pol.wStart (List.range' 1 (4 * j))) = .ok t ∧ t.proj = s.proj) := by
  induction j with
  | zero =>
    rw [steps_eq N c 0 hj]
    intro s hs
    refine ⟨s, ?_, rfl⟩
    simp only [bind, pure] at hs
    cases h : c.start N with
    | error e => rw [h] at hs; cases hs
    | ok s' => rw [h] at hs; cases hs; rfl
  | succ j ih =>
    have F : ∀ b r, Except.Holds (do let r ← c.step N r b; pure (ForInStep.yield r) : Except Abort _)
        (fun st => ∃ v, st = ForInStep.yield v) :=
      fun _ _ => Except.Holds.bind (fun _ _ => trivial) fun v _ => Except.Holds.pure _ ⟨v, rfl⟩
    have hsj := steps_eq N c j (by omega)
    rw [steps_eq N c (j + 1) hj, List.range_succ, List.map_append]
    simp only [Except.forIn_append_yield _ _ _ _ F, ← bind_assoc, ← hsj]
    refine Except.Holds.bind (ih (by omega)) fun r ⟨t, ht, hp⟩ => ?_
    simp only [List.map_cons, List.map_nil, List.forIn_cons, List.forIn_nil, bind_assoc, pure_bind, bind_pure]
    refine (step_proj N c r _).conseq fun r' ⟨q, hq, hpq⟩ => ?_
    have hr : List.range' 1 (4 * (j + 1)) = List.range' 1 (4 * j) ++ List.range' (1 + 4 * j) 4 := by
      rw [List.range'_append_1, Nat.mul_succ]
    have hb : c.pol.wStart + ↑(4 * j) * HOUR = c.pol.wStart + ↑j * BAR := by
      simp only [BAR]; push_cast; rw [Int.mul_comm 4, Int.mul_assoc]
    refine ⟨t.graft q, ?_, hpq.symm ▸ proj_graft _ _⟩
    have hf : c.tickLoop N c.pol.wStart (List.range' 1 (4 * j) ++ List.range' (1 + 4 * j) 4) =
        fun x => c.tickLoop N c.pol.wStart (List.range' 1 (4 * j)) x >>= c.tickLoop N c.pol.wStart (List.range' (1 + 4 * j) 4) :=
      funext fun x => tickLoop_append N c _ _ _ x
    rw [hr, hf, ← bind_assoc, ht]
    show c.tickLoop N c.pol.wStart (List.range' (1 + 4 * j) 4) t = _
    rw [tickLoop_shift, hb, ← graft_self t r hp, tickLoop_graft, hq]
    rfl

/-- The schedule unrolled: preflight and the first tick, then the hourly ticks. -/
theorem Ctx.machineAfter_eq (N : NumOps α) (c : Ctx α) (n : Nat) :
    c.machineAfter N n = (c.start N >>= c.tickLoop N c.pol.wStart (List.range' 1 n)).map (·.machine) := by
  unfold Ctx.machineAfter Ctx.tickLoop
  have hz : [1:n + 1].size = n := by simp [Std.Legacy.Range.size]
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', hz]
  simp only [bind, Except.bind, Except.map, pure, Except.pure]
  split <;> (try rfl)

end
end Ref
