import Ref.Proof.Reads

/-! Delivery reads only the known prefix: each delivery is a cursor walk over a list of rows sorted by
knownAt, so two markets whose rows known by T agree deliver alike at every tick up to T. -/

namespace Ref
variable {α : Type} [Inhabited α]

/-- Walk the rows from cursor i, applying each row known by t, until one is not. -/
def cursorLoop {R : Type} (rows : List R) (known : R → Int) (step : MState α → R → Int → Except Causality (MState α))
    (t : Int) : MState α × Nat → Except Abort (MState α × Nat)
  | (m, i) =>
    if h : i < rows.length then
      if known rows[i] > t then .ok (m, i) else
      match step m rows[i] t with
      | .error _ => .error .causality
      | .ok m' => cursorLoop rows known step t (m', i + 1)
    else .ok (m, i)
termination_by x => rows.length - x.2

theorem deliver_cursor (c : Ctx α) (s : SState α) (t : Int) :
    c.deliver s t = (cursorLoop (Reads.rows c) (·.known) MState.deliver t (s.machine, s.oi)).map
      fun x => { s with machine := x.1, oi := x.2 } := by
  induction hn : c.oOrder.size - s.oi using Nat.strongRecOn generalizing s with
  | ind n ih =>
    rw [Ctx.deliver, cursorLoop]
    by_cases hi : s.oi < c.oOrder.size
    · have hi' : s.oi < (Reads.rows c).length := by simpa [Reads.rows_length] using hi
      simp only [dif_pos hi, dif_pos hi']
      have hr : (Reads.rows c)[s.oi] = c.obs[c.oOrder[s.oi]]! := by
        simpa only [getElem!_pos (Reads.rows c) s.oi hi'] using Reads.rows_get c s.oi hi
      rw [hr]
      split
      · rfl
      · cases hd : s.machine.deliver c.obs[c.oOrder[s.oi]]! t with
        | error e => rfl
        | ok m =>
          dsimp only
          rw [ih (c.oOrder.size - (s.oi + 1)) (by omega) { s with machine := m, oi := s.oi + 1 } rfl]
    · rw [dif_neg hi, dif_neg (by simpa [Reads.rows_length] using hi)]
      rfl

omit [Inhabited α] in
/-- A loop at t ≤ T started inside the prefix L never reaches rows known after T. -/
theorem cursorLoop_append {R : Type} (known : R → Int) (step : MState α → R → Int → Except Causality (MState α))
    (L D : List R) (T t : Int) (htT : t ≤ T) (hD : ∀ d ∈ D, T < known d) (m : MState α) (i : Nat)
    (hi : i ≤ L.length) :
    cursorLoop (L ++ D) known step t (m, i) = cursorLoop L known step t (m, i) := by
  induction h : L.length - i generalizing m i with
  | zero =>
    have hi' : i = L.length := by omega
    subst hi'
    rw [cursorLoop, cursorLoop]
    simp only [Nat.lt_irrefl, dite_false]
    split
    · rename_i hlt
      have hd : T < known (L ++ D)[L.length] := hD _ (by simp [List.getElem_append_right])
      rw [if_pos (by omega)]
    · rfl
  | succ k ih =>
    have hlt : i < L.length := by omega
    rw [cursorLoop, cursorLoop]
    simp only [List.length_append, dif_pos (show i < L.length + D.length by omega), dif_pos hlt,
      List.getElem_append_left hlt]
    split
    · rfl
    · split
      · rfl
      · exact ih _ _ (by omega) (by omega)

/-- A list sorted by knownAt is its rows known by T followed by the rest. -/
theorem sorted_split {R : Type} (known : R → Int) (T : Int) :
    ∀ rows : List R, rows.Pairwise (fun a b => known a ≤ known b) →
      rows = rows.filter (fun r => known r ≤ T) ++ rows.filter (fun r => ¬ known r ≤ T)
  | [], _ => rfl
  | a :: l, h => by
    rw [List.pairwise_cons] at h
    by_cases ha : known a ≤ T
    · simp only [List.filter_cons, ha, decide_true, if_true, not_true_eq_false, decide_false, Bool.false_eq_true,
        if_false, List.cons_append]
      exact congrArg _ (sorted_split known T l h.2)
    · have hlt : T < known a := by omega
      have hall : ∀ b ∈ l, T < known b := fun b hb => by have := h.1 b hb; omega
      have e₁ : l.filter (fun r => decide (known r ≤ T)) = [] :=
        List.filter_eq_nil_iff.mpr fun b hb => by simp; exact hall b hb
      have e₂ : l.filter (fun r => decide (T < known r)) = l :=
        List.filter_eq_self.mpr fun b hb => by simp; exact hall b hb
      simp [List.filter_cons, ha, hlt, e₁, e₂]

omit [Inhabited α] in
theorem cursorLoop_bound {R : Type} (known : R → Int) (step : MState α → R → Int → Except Causality (MState α))
    (L : List R) (t : Int) (m : MState α) (i : Nat) (hi : i ≤ L.length) :
    Except.Holds (cursorLoop L known step t (m, i)) (fun x => x.2 ≤ L.length) := by
  induction h : L.length - i generalizing m i with
  | zero =>
    rw [cursorLoop, dif_neg (by omega)]
    exact Except.Holds.ok _ hi
  | succ k ih =>
    rw [cursorLoop, dif_pos (by omega)]
    split
    · exact Except.Holds.ok _ hi
    · split
      · exact Except.Holds.error _
      · exact ih _ _ (by omega) (by omega)

omit [Inhabited α] in
/-- Two sorted row lists that agree on their rows known by T walk alike at every tick t ≤ T, from any
cursor inside that prefix, and stay inside it. -/
theorem cursorLoop_agree {R : Type} (known : R → Int) (step : MState α → R → Int → Except Causality (MState α))
    (rows₁ rows₂ : List R) (T t : Int) (htT : t ≤ T)
    (h₁ : rows₁.Pairwise (fun a b => known a ≤ known b)) (h₂ : rows₂.Pairwise (fun a b => known a ≤ known b))
    (hP : rows₁.filter (fun r => known r ≤ T) = rows₂.filter (fun r => known r ≤ T))
    (m : MState α) (i : Nat) (hi : i ≤ (rows₁.filter (fun r => known r ≤ T)).length) :
    cursorLoop rows₁ known step t (m, i) = cursorLoop rows₂ known step t (m, i) ∧
    Except.Holds (cursorLoop rows₁ known step t (m, i))
      (fun x => x.2 ≤ (rows₁.filter (fun r => known r ≤ T)).length) := by
  have tail : ∀ rows : List R, ∀ d ∈ rows.filter (fun r => ¬ known r ≤ T), T < known d := by
    intro rows d hd; simp at hd; omega
  have e₁ : cursorLoop rows₁ known step t (m, i) = cursorLoop (rows₁.filter (fun r => known r ≤ T)) known step t (m, i) := by
    conv => lhs; rw [sorted_split known T rows₁ h₁]
    exact cursorLoop_append known step _ _ T t htT (tail rows₁) m i hi
  have e₂ : cursorLoop rows₂ known step t (m, i) = cursorLoop (rows₂.filter (fun r => known r ≤ T)) known step t (m, i) := by
    conv => lhs; rw [sorted_split known T rows₂ h₂]
    exact cursorLoop_append known step _ _ T t htT (tail rows₂) m i (hP ▸ hi)
  rw [e₁, e₂, hP]
  exact ⟨rfl, hP ▸ cursorLoop_bound known step _ t m i (hP ▸ hi)⟩

/-- The same machine inputs through T, with delivery order explicit. -/
structure Agree (c₁ c₂ : Ctx α) (T : Int) : Prop where
  p : c₁.p = c₂.p
  pol : c₁.pol = c₂.pol
  intervals : c₁.adm.intervals = c₂.adm.intervals
  sources : c₁.reg.decls.size = c₂.reg.decls.size
  rows : c₁.deliveryPrefix T = c₂.deliveryPrefix T
  sorted₁ : (Reads.rows c₁).Pairwise (fun a b => a.known ≤ b.known)
  sorted₂ : (Reads.rows c₂).Pairwise (fun a b => a.known ≤ b.known)

/-- The delivery cursors have not passed the rows known by T. -/
def Inside (c : Ctx α) (T : Int) (s : SState α) : Prop :=
  s.oi ≤ (c.deliveryPrefix T).length

omit [Inhabited α] in
theorem proj_eq {s₁ s₂ : SState α} (h : s₁.proj = s₂.proj) :
    s₁.machine = s₂.machine ∧ s₁.oi = s₂.oi := by
  simpa [SState.proj] using h

theorem deliver_agree {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (htT : t ≤ T) {s₁ s₂ : SState α}
    (h : s₁.proj = s₂.proj) (hi : Inside c₁ T s₁) :
    (c₁.deliver s₁ t).map SState.proj = (c₂.deliver s₂ t).map SState.proj ∧
    Except.Holds (c₁.deliver s₁ t) (Inside c₁ T) := by
  obtain ⟨hm, ho⟩ := proj_eq h
  obtain ⟨e, hold⟩ := cursorLoop_agree Obs.known MState.deliver _ _ T t htT A.sorted₁ A.sorted₂ A.rows
    s₁.machine s₁.oi hi
  rw [deliver_cursor, deliver_cursor, ← hm, ← ho, ← e]
  refine ⟨?_, ?_⟩
  · cases cursorLoop (Reads.rows c₁) Obs.known MState.deliver t (s₁.machine, s₁.oi) <;>
      simp [Except.map, SState.proj]
  · intro r hr
    cases hc : cursorLoop (Reads.rows c₁) Obs.known MState.deliver t (s₁.machine, s₁.oi) with
    | error e => rw [hc] at hr; cases hr
    | ok x => rw [hc] at hr; cases hr; exact hold x hc

omit [Inhabited α] in
/-- Binding computations that agree on the machine and cursors, under an invariant on the first. -/
theorem bind_agree {β γ : Type} {x₁ x₂ : Except Abort (SState α)} {f₁ f₂ : SState α → Except Abort β}
    {I : SState α → Prop} {g : β → γ} {J : β → Prop}
    (hx : x₁.map SState.proj = x₂.map SState.proj) (hxi : Except.Holds x₁ I)
    (hf : ∀ r₁ r₂, r₁.proj = r₂.proj → I r₁ → (f₁ r₁).map g = (f₂ r₂).map g ∧ Except.Holds (f₁ r₁) J) :
    (x₁ >>= f₁).map g = (x₂ >>= f₂).map g ∧ Except.Holds (x₁ >>= f₁) J := by
  cases h₁ : x₁ <;> cases h₂ : x₂ <;> rw [h₁, h₂] at hx <;> simp [Except.map] at hx
  · subst hx; exact ⟨rfl, fun _ h => by cases h⟩
  · rename_i r₁ r₂
    obtain ⟨e, hj⟩ := hf r₁ r₂ hx (hxi r₁ h₁)
    exact ⟨e, by simpa [bind, Except.bind] using hj⟩

omit [Inhabited α] in
theorem mask_agree {c₁ c₂ : Ctx α} (h : c₁.adm.intervals = c₂.adm.intervals) : c₁.mask = c₂.mask := by
  funext t; simp [Ctx.mask, Ctx.coins, Ctx.listed, h]

theorem tickLoop_agree (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T) (base : Int) :
    ∀ (ks : List Nat), (∀ k ∈ ks, base + ↑k * HOUR + c₁.pol.delta ≤ T) → ∀ {s₁ s₂ : SState α},
    s₁.proj = s₂.proj → Inside c₁ T s₁ →
    (c₁.tickLoop N base ks s₁).map SState.proj = (c₂.tickLoop N base ks s₂).map SState.proj ∧
    Except.Holds (c₁.tickLoop N base ks s₁) (Inside c₁ T)
  | [], _, _, _, h, hi => ⟨by simp [Ctx.tickLoop, Except.map, pure, Except.pure, h], fun _ hr => by cases hr; exact hi⟩
  | k :: ks, hks, s₁, s₂, h, hi => by
    simp only [Ctx.tickLoop, List.forIn_cons, bind_assoc, pure_bind]
    rw [show base + ↑k * HOUR + c₂.pol.delta = base + ↑k * HOUR + c₁.pol.delta by rw [A.pol]]
    refine bind_agree (deliver_agree A (hks k (by simp)) h hi).1 (deliver_agree A (hks k (by simp)) h hi).2
      fun r₁ r₂ hr hri => ?_
    obtain ⟨hm, ho⟩ := proj_eq hr
    have hr' : ({ r₁ with machine := r₁.machine.tick N c₁.p (c₁.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) } : SState α).proj =
        ({ r₂ with machine := r₂.machine.tick N c₂.p (c₂.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) } : SState α).proj := by
      simp [SState.proj, hm, ho, A.p, mask_agree A.intervals]
    exact tickLoop_agree N A base ks (fun k' hk' => hks k' (by simp [hk'])) hr' hri

theorem start_agree (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T)
    (hT : c₁.pol.wStart + c₁.pol.delta ≤ T) :
    (c₁.start N).map SState.proj = (c₂.start N).map SState.proj ∧ Except.Holds (c₁.start N) (Inside c₁ T) := by
  have h0 : (c₁.state0 N).proj = (c₂.state0 N).proj := by
    simp [SState.proj, Ctx.state0, Ctx.coins, A.p, A.intervals, A.sources]
  have hi : Inside c₁ T (c₁.state0 N) := by simp [Inside, Ctx.state0]
  unfold Ctx.start
  rw [← A.pol]
  refine bind_agree (deliver_agree A hT h0 hi).1 (deliver_agree A hT h0 hi).2 fun r₁ r₂ hr hri => ?_
  obtain ⟨hm, ho⟩ := proj_eq hr
  exact ⟨by simp [Except.map, pure, Except.pure, SState.proj, hm, ho, A.p, mask_agree A.intervals],
    fun _ h => by cases h; exact hri⟩

omit [Inhabited α] in
theorem map_machine {x₁ x₂ : Except Abort (SState α)} (h : x₁.map SState.proj = x₂.map SState.proj) :
    x₁.map (·.machine) = x₂.map (·.machine) := by
  cases x₁ <;> cases x₂ <;> simp_all [Except.map, SState.proj]

theorem make_agree (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs₁ obs₂ : Array (Obs α))
    (v : Venue α) (pol : Policy) (stop : Int) (req : List Nat) (T : Int)
    (hP : (Ctx.make reg roles p adm obs₁ v pol stop req).deliveryPrefix T =
      (Ctx.make reg roles p adm obs₂ v pol stop req).deliveryPrefix T) :
    Agree (Ctx.make reg roles p adm obs₁ v pol stop req) (Ctx.make reg roles p adm obs₂ v pol stop req) T :=
  ⟨rfl, rfl, rfl, rfl, hP, Reads.sorted reg roles p adm obs₁ v pol stop req,
    Reads.sorted reg roles p adm obs₂ v pol stop req⟩

theorem machineAfter_agree (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T) (n : Nat)
    (hn : c₁.pol.wStart + (n : Int) * HOUR + c₁.pol.delta ≤ T) :
    c₁.machineAfter N n = c₂.machineAfter N n := by
  rw [Ctx.machineAfter_eq, Ctx.machineAfter_eq]
  apply map_machine
  have h0 : c₁.pol.wStart + c₁.pol.delta ≤ T := by simp only [HOUR] at hn; omega
  refine (bind_agree (J := Inside c₁ T) (start_agree N A h0).1 (start_agree N A h0).2 fun r₁ r₂ hr hri => ?_).1
  rw [← A.pol]
  exact tickLoop_agree N A c₁.pol.wStart (List.range' 1 n) (by
    intro k hk
    simp only [List.mem_range'_1] at hk
    simp only [HOUR] at hn ⊢
    omega) hr hri

end Ref
