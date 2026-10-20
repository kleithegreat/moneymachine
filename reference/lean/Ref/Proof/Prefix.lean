import Ref.Proof.Sim

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

/-- Funding rows in delivery order. -/
def Ctx.fRows (c : Ctx α) : List (FundingRow α) := c.fOrder.toList.map (c.m.funding[·]!)

theorem deliverFunding_cursor (c : Ctx α) (s : SState α) (t : Int) :
    c.deliverFunding s t = (cursorLoop c.fRows (·.known) MState.deliverFunding t (s.machine, s.fi)).map
      fun x => { s with machine := x.1, fi := x.2 } := by
  fun_induction Ctx.deliverFunding c s t <;> rw [cursorLoop] <;>
    simp_all (config := { zetaDelta := true }) [Ctx.fRows, Except.map] <;>
    first | rw [dif_neg (by omega)] | grind

/-- Bar rows in delivery order. -/
def Ctx.bRows (c : Ctx α) : List (BarRow α) := c.bOrder.toList.map (c.m.bars[·]!)

theorem deliverBars_cursor (c : Ctx α) (s : SState α) (t : Int) :
    c.deliverBars s t = (cursorLoop c.bRows (·.known) MState.deliverBar t (s.machine, s.bi)).map
      fun x => { s with machine := x.1, bi := x.2 } := by
  fun_induction Ctx.deliverBars c s t <;> rw [cursorLoop] <;>
    simp_all (config := { zetaDelta := true }) [Ctx.bRows, Except.map] <;>
    first | rw [dif_neg (by omega)] | grind

/-- Bound event rows in delivery order. -/
def Ctx.eRows (c : Ctx α) : List (EventRow α) := c.eOrder.toList.map (c.m.events[·]!)

theorem deliverEvents_cursor (c : Ctx α) (s : SState α) (t : Int) :
    c.deliverEvents s t = (cursorLoop c.eRows (·.known) MState.deliverEvent t (s.machine, s.ei)).map
      fun x => { s with machine := x.1, ei := x.2 } := by
  fun_induction Ctx.deliverEvents c s t <;> rw [cursorLoop] <;>
    simp_all (config := { zetaDelta := true }) [Ctx.eRows, Except.map] <;>
    first | rw [dif_neg (by omega)] | grind

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

theorem lexLe_trans : ∀ (a b c : List Int), a.length = b.length → b.length = c.length →
    lexLe a b = true → lexLe b c = true → lexLe a c = true
  | [], _, _, _, _, _, _ => by simp [lexLe]
  | _ :: _, [], _, h, _, _, _ => by simp at h
  | _ :: _, _ :: _, [], _, h, _, _ => by simp at h
  | x :: xs, y :: ys, z :: zs, h₁, h₂, hab, hbc => by
    simp only [lexLe, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at hab hbc ⊢
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h₁ h₂
    rcases hab with hab | ⟨rfl, hab⟩ <;> rcases hbc with hbc | ⟨rfl, hbc⟩
    · left; omega
    · left; omega
    · left; omega
    · right; exact ⟨rfl, lexLe_trans xs ys zs h₁ h₂ hab hbc⟩

theorem lexLe_total : ∀ (a b : List Int), a.length = b.length → (lexLe a b || lexLe b a) = true
  | [], _, _ => by simp [lexLe]
  | _ :: _, [], h => by simp at h
  | x :: xs, y :: ys, h => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h
    have := lexLe_total xs ys h
    simp only [lexLe, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at this ⊢
    rcases Int.lt_trichotomy x y with h₁ | rfl | h₁
    · exact Or.inl (Or.inl h₁)
    · rcases this with h₂ | h₂
      · exact Or.inl (Or.inr ⟨rfl, h₂⟩)
      · exact Or.inr (Or.inr ⟨rfl, h₂⟩)
    · exact Or.inr (Or.inl h₁)

theorem lexLe_head {x y : Int} {xs ys : List Int} (h : lexLe (x :: xs) (y :: ys) = true) : x ≤ y := by
  simp only [lexLe, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at h
  omega

omit [Inhabited α] in
/-- Rows ordered by a lexicographic key that starts with their knownAt are sorted by knownAt. -/
theorem mergeSort_known {R : Type} (xs : Array Nat) (key : Nat → List Int) (len : Nat)
    (hlen : ∀ i, (key i).length = len) (f : Nat → R) (known : R → Int) (hhead : ∀ i, ∃ t, key i = known (f i) :: t) :
    ((xs.mergeSort fun i j => lexLe (key i) (key j)).toList.map f).Pairwise (fun a b => known a ≤ known b) := by
  rw [Array.toList_mergeSort, List.pairwise_map]
  refine (List.pairwise_mergeSort (fun a b c => lexLe_trans (key a) (key b) (key c) ((hlen a).trans (hlen b).symm)
    ((hlen b).trans (hlen c).symm)) (fun a b => lexLe_total (key a) (key b) ((hlen a).trans (hlen b).symm)) _).imp ?_
  intro i j h
  obtain ⟨t, ht⟩ := hhead i
  obtain ⟨u, hu⟩ := hhead j
  rw [ht, hu] at h
  exact lexLe_head h

theorem fRows_sorted (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) :
    (Ctx.make p m v pol stop).fRows.Pairwise (fun a b => a.known ≤ b.known) :=
  mergeSort_known _ (fun i => [m.funding[i]!.known, (m.funding[i]!.coin : Int), m.funding[i]!.event]) 3
    (fun _ => rfl) _ FundingRow.known (fun _ => ⟨_, rfl⟩)

theorem bRows_sorted (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) :
    (Ctx.make p m v pol stop).bRows.Pairwise (fun a b => a.known ≤ b.known) :=
  mergeSort_known _ (fun i => [m.bars[i]!.known, (m.bars[i]!.coin : Int), m.bars[i]!.event]) 3
    (fun _ => rfl) _ BarRow.known (fun _ => ⟨_, rfl⟩)

theorem eRows_sorted (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) :
    (Ctx.make p m v pol stop).eRows.Pairwise (fun a b => a.known ≤ b.known) :=
  mergeSort_known _ (fun i => [m.events[i]!.known, (m.events[i]!.coin : Int), (m.events[i]!.slot : Int), (i : Int)]) 4
    (fun _ => rfl) _ EventRow.known (fun _ => ⟨_, rfl⟩)

/-- Two contexts that run the same program and policy over markets with the same listings, the same
bound sources and the same rows known by T, each delivered in knownAt order. -/
structure Agree (c₁ c₂ : Ctx α) (T : Int) : Prop where
  p : c₁.p = c₂.p
  pol : c₁.pol = c₂.pol
  intervals : c₁.m.intervals = c₂.m.intervals
  bound : c₁.m.bound = c₂.m.bound
  f : c₁.fRows.filter (·.known ≤ T) = c₂.fRows.filter (·.known ≤ T)
  b : c₁.bRows.filter (·.known ≤ T) = c₂.bRows.filter (·.known ≤ T)
  e : c₁.eRows.filter (·.known ≤ T) = c₂.eRows.filter (·.known ≤ T)
  f₁ : c₁.fRows.Pairwise (fun a b => a.known ≤ b.known)
  f₂ : c₂.fRows.Pairwise (fun a b => a.known ≤ b.known)
  b₁ : c₁.bRows.Pairwise (fun a b => a.known ≤ b.known)
  b₂ : c₂.bRows.Pairwise (fun a b => a.known ≤ b.known)
  e₁ : c₁.eRows.Pairwise (fun a b => a.known ≤ b.known)
  e₂ : c₂.eRows.Pairwise (fun a b => a.known ≤ b.known)

/-- The delivery cursors have not passed the rows known by T. -/
def Inside (c : Ctx α) (T : Int) (s : SState α) : Prop :=
  s.fi ≤ (c.fRows.filter (·.known ≤ T)).length ∧ s.bi ≤ (c.bRows.filter (·.known ≤ T)).length ∧
    s.ei ≤ (c.eRows.filter (·.known ≤ T)).length

omit [Inhabited α] in
theorem proj_eq {s₁ s₂ : SState α} (h : s₁.proj = s₂.proj) :
    s₁.machine = s₂.machine ∧ s₁.fi = s₂.fi ∧ s₁.bi = s₂.bi ∧ s₁.ei = s₂.ei := by
  simpa [SState.proj] using h

theorem deliverFunding_agree {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (htT : t ≤ T) {s₁ s₂ : SState α}
    (h : s₁.proj = s₂.proj) (hi : Inside c₁ T s₁) :
    (c₁.deliverFunding s₁ t).map SState.proj = (c₂.deliverFunding s₂ t).map SState.proj ∧
    Except.Holds (c₁.deliverFunding s₁ t) (Inside c₁ T) := by
  obtain ⟨hm, hf, hb, he⟩ := proj_eq h
  obtain ⟨e, hold⟩ := cursorLoop_agree FundingRow.known MState.deliverFunding _ _ T t htT A.f₁ A.f₂ A.f
    s₁.machine s₁.fi hi.1
  rw [deliverFunding_cursor, deliverFunding_cursor, ← hm, ← hf, ← e]
  refine ⟨?_, ?_⟩
  · cases cursorLoop c₁.fRows FundingRow.known MState.deliverFunding t (s₁.machine, s₁.fi) <;>
      simp [Except.map, SState.proj, hb, he]
  · intro r hr
    cases hc : cursorLoop c₁.fRows FundingRow.known MState.deliverFunding t (s₁.machine, s₁.fi) with
    | error e => rw [hc] at hr; cases hr
    | ok x => rw [hc] at hr; cases hr; exact ⟨hold x hc, hi.2.1, hi.2.2⟩

theorem deliverBars_agree {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (htT : t ≤ T) {s₁ s₂ : SState α}
    (h : s₁.proj = s₂.proj) (hi : Inside c₁ T s₁) :
    (c₁.deliverBars s₁ t).map SState.proj = (c₂.deliverBars s₂ t).map SState.proj ∧
    Except.Holds (c₁.deliverBars s₁ t) (Inside c₁ T) := by
  obtain ⟨hm, hf, hb, he⟩ := proj_eq h
  obtain ⟨e, hold⟩ := cursorLoop_agree BarRow.known MState.deliverBar _ _ T t htT A.b₁ A.b₂ A.b
    s₁.machine s₁.bi hi.2.1
  rw [deliverBars_cursor, deliverBars_cursor, ← hm, ← hb, ← e]
  refine ⟨?_, ?_⟩
  · cases cursorLoop c₁.bRows BarRow.known MState.deliverBar t (s₁.machine, s₁.bi) <;>
      simp [Except.map, SState.proj, hf, he]
  · intro r hr
    cases hc : cursorLoop c₁.bRows BarRow.known MState.deliverBar t (s₁.machine, s₁.bi) with
    | error e => rw [hc] at hr; cases hr
    | ok x => rw [hc] at hr; cases hr; exact ⟨hi.1, hold x hc, hi.2.2⟩

theorem deliverEvents_agree {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (htT : t ≤ T) {s₁ s₂ : SState α}
    (h : s₁.proj = s₂.proj) (hi : Inside c₁ T s₁) :
    (c₁.deliverEvents s₁ t).map SState.proj = (c₂.deliverEvents s₂ t).map SState.proj ∧
    Except.Holds (c₁.deliverEvents s₁ t) (Inside c₁ T) := by
  obtain ⟨hm, hf, hb, he⟩ := proj_eq h
  obtain ⟨e, hold⟩ := cursorLoop_agree EventRow.known MState.deliverEvent _ _ T t htT A.e₁ A.e₂ A.e
    s₁.machine s₁.ei hi.2.2
  rw [deliverEvents_cursor, deliverEvents_cursor, ← hm, ← he, ← e]
  refine ⟨?_, ?_⟩
  · cases cursorLoop c₁.eRows EventRow.known MState.deliverEvent t (s₁.machine, s₁.ei) <;>
      simp [Except.map, SState.proj, hf, hb]
  · intro r hr
    cases hc : cursorLoop c₁.eRows EventRow.known MState.deliverEvent t (s₁.machine, s₁.ei) with
    | error e => rw [hc] at hr; cases hr
    | ok x => rw [hc] at hr; cases hr; exact ⟨hi.1, hi.2.1, hold x hc⟩

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

theorem deliver_agree {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (htT : t ≤ T) {s₁ s₂ : SState α}
    (h : s₁.proj = s₂.proj) (hi : Inside c₁ T s₁) :
    (c₁.deliver s₁ t).map SState.proj = (c₂.deliver s₂ t).map SState.proj ∧
    Except.Holds (c₁.deliver s₁ t) (Inside c₁ T) := by
  obtain ⟨ef, hf⟩ := deliverFunding_agree A htT h hi
  refine bind_agree ef hf fun r₁ r₂ hr hri => ?_
  obtain ⟨eb, hb⟩ := deliverBars_agree A htT hr hri
  exact bind_agree eb hb fun q₁ q₂ hq hqi => deliverEvents_agree A htT hq hqi

omit [Inhabited α] in
theorem mask_agree {c₁ c₂ : Ctx α} (h : c₁.m.intervals = c₂.m.intervals) : c₁.mask = c₂.mask := by
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
    obtain ⟨hm, hf, hb, he⟩ := proj_eq hr
    have hr' : ({ r₁ with machine := r₁.machine.tick N c₁.p (c₁.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) } : SState α).proj =
        ({ r₂ with machine := r₂.machine.tick N c₂.p (c₂.mask (base + ↑k * HOUR)) (base + ↑k * HOUR) } : SState α).proj := by
      simp [SState.proj, hm, hf, hb, he, A.p, mask_agree A.intervals]
    exact tickLoop_agree N A base ks (fun k' hk' => hks k' (by simp [hk'])) hr' hri

theorem start_agree (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T)
    (hT : c₁.pol.wStart + c₁.pol.delta ≤ T) :
    (c₁.start N).map SState.proj = (c₂.start N).map SState.proj ∧ Except.Holds (c₁.start N) (Inside c₁ T) := by
  have hb : c₁.bound = c₂.bound := by simp [Ctx.bound, A.p, A.bound]
  have h0 : (c₁.state0 N).proj = (c₂.state0 N).proj := by
    simp [SState.proj, Ctx.state0, Ctx.coins, A.p, A.intervals]
  have hi : Inside c₁ T (c₁.state0 N) := by simp [Inside, Ctx.state0]
  unfold Ctx.start
  rw [← hb, ← A.pol]
  cases c₁.bound
  · exact ⟨rfl, fun _ h => by cases h⟩
  · simp only [Bool.not_true, Bool.false_eq_true, if_false]
    refine bind_agree (deliver_agree A hT h0 hi).1 (deliver_agree A hT h0 hi).2 fun r₁ r₂ hr hri => ?_
    obtain ⟨hm, hf, hb', he⟩ := proj_eq hr
    exact ⟨by simp [Except.map, pure, Except.pure, SState.proj, hm, hf, hb', he, A.p, mask_agree A.intervals],
      fun _ h => by cases h; exact hri⟩

omit [Inhabited α] in
theorem map_machine {x₁ x₂ : Except Abort (SState α)} (h : x₁.map SState.proj = x₂.map SState.proj) :
    x₁.map (·.machine) = x₂.map (·.machine) := by
  cases x₁ <;> cases x₂ <;> simp_all [Except.map, SState.proj]

/-- The machine's per-node state: values, windows and `hours_since` marks, which delivery never reads. -/
def MState.withLocal (m : MState α) (X : Array (Array (Val α))) (W : Array (Array (Option (Win α))))
    (S : Array (Array (Option Int))) : MState α := { m with vals := X, wins := W, since := S }

omit [Inhabited α] in
/-- A cursor walk whose step ignores the per-node state carries any per-node state through. -/
theorem cursorLoop_local {R : Type} (rows : List R) (known : R → Int) (step : MState α → R → Int → Except Causality (MState α))
    (X : Array (Array (Val α))) (W : Array (Array (Option (Win α)))) (S : Array (Array (Option Int)))
    (hstep : ∀ m r t, step (m.withLocal X W S) r t = (step m r t).map (·.withLocal X W S))
    (t : Int) (m : MState α) (i : Nat) :
    cursorLoop rows known step t (m.withLocal X W S, i) =
      (cursorLoop rows known step t (m, i)).map fun x => (x.1.withLocal X W S, x.2) := by
  induction h : rows.length - i generalizing m i with
  | zero => rw [cursorLoop, cursorLoop, dif_neg (by omega), dif_neg (by omega)]; rfl
  | succ k ih =>
    rw [cursorLoop, cursorLoop, dif_pos (by omega), dif_pos (by omega)]
    split
    · rfl
    · rw [hstep]
      cases step m rows[i] t with
      | error e => rfl
      | ok m' => exact ih m' (i + 1) (by omega)

theorem deliver_local (c : Ctx α) (s : SState α) (t : Int) (X : Array (Array (Val α)))
    (W : Array (Array (Option (Win α)))) (S : Array (Array (Option Int))) :
    c.deliver { s with machine := s.machine.withLocal X W S } t =
      (c.deliver s t).map fun r => { r with machine := r.machine.withLocal X W S } := by
  simp only [Ctx.deliver, deliverFunding_cursor, deliverBars_cursor, deliverEvents_cursor]
  rw [cursorLoop_local _ _ _ X W S (fun m r t => by simp [MState.deliverFunding, MState.withLocal]; split <;> rfl)]
  cases cursorLoop c.fRows FundingRow.known MState.deliverFunding t (s.machine, s.fi) with
  | error e => rfl
  | ok x =>
    simp only [Except.map, bind, Except.bind]
    rw [cursorLoop_local _ _ _ X W S (fun m r t => by simp [MState.deliverBar, MState.withLocal]; split <;> rfl)]
    cases cursorLoop c.bRows BarRow.known MState.deliverBar t (x.1, s.bi) with
    | error e => rfl
    | ok y =>
      simp only [Except.map]
      rw [cursorLoop_local _ _ _ X W S (fun m r t => by simp [MState.deliverEvent, MState.withLocal]; split <;> rfl)]
      cases cursorLoop c.eRows EventRow.known MState.deliverEvent t (y.1, s.ei) <;> rfl

/-- Delivery leaves the per-node state as it was. -/
theorem deliver_keeps_local (c : Ctx α) (s r : SState α) (t : Int) (h : c.deliver s t = .ok r) :
    r.machine.vals = s.machine.vals ∧ r.machine.wins = s.machine.wins ∧ r.machine.since = s.machine.since := by
  have e := deliver_local c s t s.machine.vals s.machine.wins s.machine.since
  rw [show ({ s with machine := s.machine.withLocal s.machine.vals s.machine.wins s.machine.since } : SState α) = s
    from rfl, h] at e
  simp only [Except.map, Except.ok.injEq] at e
  rw [e]; exact ⟨rfl, rfl, rfl⟩

end Ref
