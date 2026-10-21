import Ref.Spec

/-! L3: the R version 1 rules keep a program well-formed, and its values and runs. -/

namespace Ref

/-- What WF says of an operator node. -/
theorem WF.op {p : Program} (hp : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (h : p.nodes[i]! = .op o args) :
    (∀ a ∈ args, a < i) ∧ opTy o (args.map (p.types[·]!)) p.convTo[i]! = some p.types[i]! := by
  have := hp.2.2.2.2.2 i hi
  rw [h] at this
  exact this

/-- Redirecting the uses of node i to an earlier node j of the same type keeps a program well-formed. -/
theorem redirect_wf {p : Program} (hp : p.WF) {i j : Nat} (hji : j < i) (hi : i < p.nodes.size)
    (ht : p.types[j]! = p.types[i]!) : (p.redirect i j).WF := by
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hp
  have hf : ∀ k, p.types[if k == i then j else k]! = p.types[k]! := by
    intro k; by_cases hk : k = i
    · subst hk; simp [ht]
    · simp [hk]
  have hlt : ∀ k, (if k == i then j else k) ≤ k := by
    intro k; by_cases hk : k = i
    · subst hk; simp; omega
    · simp [hk]
  unfold Program.redirect
  refine ⟨by simp [h1], by simp [h2], ?_, ?_, fun q hq => ?_, fun k hk => ?_⟩
  · have := hlt p.weight; simp only [Array.size_map] at this ⊢; omega
  · simp only; rw [hf]; exact h4
  · simp only [Option.map_eq_some_iff] at hq
    obtain ⟨q', hq', rfl⟩ := hq
    obtain ⟨hq1, hq2⟩ := h5 q' hq'
    exact ⟨by have := hlt q'; simp only [Array.size_map]; omega, by rw [hf]; exact hq2⟩
  · simp only [Array.size_map] at hk
    have := h6 k hk
    simp only [getElem!_pos (p.nodes.map _) k (by simpa using hk), Array.getElem_map]
    rw [getElem!_pos p.nodes k hk] at this
    cases hn : p.nodes[k] with
    | op o args =>
      rw [hn] at this
      refine ⟨fun a ha => ?_, ?_⟩
      · obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
        have := this.1 b hb; have := hlt b; omega
      · rw [List.map_map]
        have e : ((p.types[·]!) ∘ fun k => if k == i then j else k) = (p.types[·]!) := funext hf
        rw [e]; exact this.2
    | _ => rw [hn] at this; exact this

/-- Replacing node i by an operator node typed as it was keeps a program well-formed. -/
theorem set_wf {p : Program} (hp : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (ha : ∀ a ∈ args, a < i) (ht : opTy o (args.map (p.types[·]!)) p.convTo[i]! = some p.types[i]!) :
    { p with nodes := p.nodes.set! i (.op o args) }.WF := by
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hp
  refine ⟨by simp [h1], by simp [h2], by simpa using h3, h4, fun q hq => by simpa using h5 q hq, fun k hk => ?_⟩
  simp only [Array.size_set!] at hk
  by_cases hki : k = i
  · subst hki
    simp only [Array.getElem!_set!_self _ _ _ hk]
    exact ⟨ha, ht⟩
  · simp only [Array.getElem!_set!_ne _ _ _ _ (Ne.symm hki)]
    exact h6 k hk

/-! Typing facts of the operators the rules rewrite. -/

theorem opTy_unary {o : Op} (ho : o = .neg ∨ o = .abs) {t t' : Ty} {to : Option Dim} (h : opTy o [t] to = some t') :
    t' = t := by
  rcases ho with rfl | rfl <;> cases t <;> simp [opTy] at h <;> simp [h]

theorem opTy_not {t t' : Ty} {to : Option Dim} (h : opTy .not [t] to = some t') : t = .bool ∧ t' = .bool := by
  cases t <;> simp [opTy] at h; simp [h]

theorem zip_same (f : Int → Int → Int) (hf : ∀ x, f x 0 = x) (u u' : Dim) (h : Dim.zip f u Dim.one = some u') : u' = u := by
  unfold Dim.zip at h
  dsimp only at h
  split at h
  · rename_i hc
    simp only [Option.some.injEq] at h
    subst h
    simp only [Bool.and_eq_true, beq_iff_eq] at hc
    cases u with
    | mk e =>
      simp only [Dim.one, List.length_cons, List.length_nil] at hc
      simp only [Dim.mk.injEq, Dim.one]
      match e, hc.1 with
      | [a, b, c, d, e', g], _ => simp [hf]
  · cases h

theorem opTy_one {o : Op} (ho : o = .mul ∨ o = .div) {t t' : Ty} {to : Option Dim}
    (h : opTy o [t, .num Dim.one] to = some t') : t' = t := by
  rcases ho with rfl | rfl <;> cases t with
  | bool => simp [opTy] at h
  | num u =>
    first
    | (cases hm : Dim.mul u Dim.one with
        | none => simp [opTy, hm] at h
        | some u' =>
          simp [opTy, hm] at h
          rw [← h, zip_same _ (by intro; omega) _ _ hm])
    | (cases hm : Dim.div u Dim.one with
        | none => simp [opTy, hm] at h
        | some u' =>
          simp [opTy, hm] at h
          rw [← h, zip_same _ (by intro; omega) _ _ hm])

theorem opTy_sub {t t' : Ty} {u : Dim} {to : Option Dim} (hu : t = .num u) (h : opTy .sub [t, .num u] to = some t') :
    t' = t := by
  subst hu; simp [opTy] at h; simp [h]

theorem zip_comm (f : Int → Int → Int) (hf : ∀ x y, f x y = f y x) (u v : Dim) : Dim.zip f u v = Dim.zip f v u := by
  unfold Dim.zip
  dsimp only
  rw [List.zipWith_comm_of_comm hf, show (u.e.length == v.e.length) = (v.e.length == u.e.length) from
    Bool.eq_iff_iff.mpr (by rw [beq_iff_eq, beq_iff_eq]; exact ⟨Eq.symm, Eq.symm⟩)]

theorem opTy_comm {o : Op} (ho : o = .add ∨ o = .mul ∨ o = .and ∨ o = .or) {t₁ t₂ t : Ty} {to : Option Dim}
    (h : opTy o [t₁, t₂] to = some t) : opTy o [t₂, t₁] to = some t := by
  rcases ho with rfl | rfl | rfl | rfl <;> cases t₁ <;> cases t₂ <;> simp_all [opTy]
  · rename_i u v; obtain ⟨rfl, rfl⟩ := h; simp
  · rename_i u v
    rw [show Dim.mul v u = Dim.mul u v from zip_comm (· + ·) Int.add_comm v u]
    exact h

theorem opTy_flip {o o' : Op} (ho : (o = .gt ∧ o' = .lt) ∨ (o = .lt ∧ o' = .gt) ∨ (o = .ge ∧ o' = .le) ∨ (o = .le ∧ o' = .ge))
    {t₁ t₂ t : Ty} {to to' : Option Dim} (h : opTy o [t₁, t₂] to = some t) : opTy o' [t₂, t₁] to' = some t := by
  rcases ho with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> cases t₁ <;> cases t₂ <;> simp_all [opTy] <;>
    exact h.1.symm

theorem opTy_ite {t₀ t₁ t₂ t : Ty} {to to' : Option Dim} (h : opTy .ite [t₀, t₁, t₂] to = some t) :
    t₀ = .bool ∧ opTy .ite [.bool, t₂, t₁] to' = some t := by
  cases t₀ <;> simp [opTy] at h
  refine ⟨rfl, ?_⟩
  cases t₁ <;> cases t₂ <;> simp [opTy] at h ⊢
  all_goals first | exact h | (obtain ⟨rfl, rfl⟩ := h; exact ⟨rfl, rfl⟩)

theorem insert_get {β : Type} [Inhabited β] (xs : Array β) {k : Nat} (hk : k ≤ xs.size) (x : β) (m : Nat) :
    (xs.insertIdx! k x)[m]! = if m < k then xs[m]! else if m = k then x else xs[m - 1]! := by
  rw [Array.insertIdx!, dif_pos hk]
  simp only [getElem!_def, Array.getElem?_insertIdx hk]
  by_cases h1 : m < k
  · simp [h1]
  · by_cases h2 : m = k
    · subst h2; simp [hk]
    · simp [h1, h2]

theorem insert_shift {β : Type} [Inhabited β] (xs : Array β) {k : Nat} (hk : k ≤ xs.size) (x : β) (j : Nat) :
    (xs.insertIdx! k x)[if j ≥ k then j + 1 else j]! = xs[j]! := by
  rw [insert_get xs hk]
  by_cases h : j ≥ k
  · simp only [h, ite_true]; rw [if_neg (by omega), if_neg (by omega)]; rfl
  · simp only [h, ite_false]; rw [if_pos (by omega)]

theorem insert_size {β : Type} (xs : Array β) {k : Nat} (hk : k ≤ xs.size) (x : β) :
    (xs.insertIdx! k x).size = xs.size + 1 := by
  rw [Array.insertIdx!, dif_pos hk, Array.size_insertIdx]

/-- `ifNotRev` keeps a program well-formed: the inserted negation, then the swapped `if` after it. -/
theorem ifNotRev_wf {p : Program} (hp : p.WF) {i c b a : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .ite [c, b, a]) :
    { p.insertAt i (.op .not [c]) .bool with
      nodes := (p.insertAt i (.op .not [c]) .bool).nodes.set! (i + 1) (.op .ite [i, a, b]) }.WF := by
  obtain ⟨hargs, hty⟩ := WF.op hp hi hn
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hp
  have hc : c < i := hargs c (by simp)
  have hb : b < i := hargs b (by simp)
  have ha : a < i := hargs a (by simp)
  simp only [List.map_cons, List.map_nil] at hty
  obtain ⟨hcb, hite⟩ := opTy_ite (to' := p.convTo[i]!) hty
  have hiT : i ≤ p.types.size := by omega
  have hiC : i ≤ p.convTo.size := by omega
  have hiN : ∀ g : Node → Node, i ≤ (p.nodes.map g).size := fun g => by simp; omega
  let f := fun j : Nat => if j ≥ i then j + 1 else j
  have hT : ∀ j, (p.types.insertIdx! i .bool)[f j]! = p.types[j]! := insert_shift _ hiT _
  have hC : ∀ j, (p.convTo.insertIdx! i none)[f j]! = p.convTo[j]! := insert_shift _ hiC _
  have hlow : ∀ j < i, f j = j := fun j hj => by simp only [f]; rw [if_neg (by omega)]
  unfold Program.insertAt
  dsimp only
  refine ⟨by rw [Array.size_set!, insert_size _ (hiN _), insert_size _ hiT]; simp [h1],
    by rw [Array.size_set!, insert_size _ (hiN _), insert_size _ hiC]; simp [h2],
    by rw [Array.size_set!, insert_size _ (hiN _)]; simp only [Array.size_map]; split <;> omega,
    by rw [hT]; exact h4, fun q hq => ?_, fun k hk => ?_⟩
  · simp only [Option.map_eq_some_iff] at hq
    obtain ⟨q', hq', rfl⟩ := hq
    obtain ⟨hq1, hq2⟩ := h5 q' hq'
    exact ⟨by rw [Array.size_set!, insert_size _ (hiN _)]; simp only [Array.size_map]; split <;> omega, by rw [hT]; exact hq2⟩
  · rw [Array.size_set!, insert_size _ (hiN _), Array.size_map] at hk
    have hsz : ∀ g : Node → Node, i + 1 < ((p.nodes.map g).insertIdx! i (.op .not [c])).size := fun g => by
      rw [insert_size _ (hiN _)]; simp; omega
    have hT' : ∀ j < i, (p.types.insertIdx! i Ty.bool)[j]! = p.types[j]! := fun j hj => by
      have := hT j; rw [hlow j hj] at this; exact this
    have hcases : k = i ∨ k = i + 1 ∨ ∃ k₀ < p.nodes.size, k₀ ≠ i ∧ f k₀ = k := by
      rcases Nat.lt_trichotomy k i with h | h | h
      · exact Or.inr (Or.inr ⟨k, by omega, by omega, hlow k h⟩)
      · exact Or.inl h
      · rcases Nat.lt_or_ge (i + 1) k with h' | h'
        · exact Or.inr (Or.inr ⟨k - 1, by omega, by omega, by simp only [f]; rw [if_pos (by omega)]; omega⟩)
        · exact Or.inr (Or.inl (by omega))
    rcases hcases with rfl | rfl | ⟨k₀, hk₀, hne, rfl⟩
    · rw [Array.getElem!_set!_ne _ _ _ _ (by omega), insert_get _ (hiN _)]
      simp only [Nat.lt_irrefl, ite_false, ite_true]
      refine ⟨fun x hx => by simp at hx; omega, ?_⟩
      simp only [List.map_cons, List.map_nil]
      rw [hT' c hc, hcb, show (p.types.insertIdx! k Ty.bool)[k]! = Ty.bool by rw [insert_get _ hiT]; simp]
      simp [opTy]
    · rw [Array.getElem!_set!_self _ _ _ (hsz _)]
      refine ⟨fun x hx => by simp at hx; omega, ?_⟩
      simp only [List.map_cons, List.map_nil]
      rw [show (p.types.insertIdx! i Ty.bool)[i]! = Ty.bool by rw [insert_get _ hiT]; simp, hT' a ha, hT' b hb,
        show (p.types.insertIdx! i Ty.bool)[i + 1]! = p.types[i]! by
          have := hT i; simp only [f, ge_iff_le, Nat.le_refl, ite_true] at this; exact this,
        show (p.convTo.insertIdx! i none)[i + 1]! = p.convTo[i]! by
          have := hC i; simp only [f, ge_iff_le, Nat.le_refl, ite_true] at this; exact this]
      exact hite
    · rw [Array.getElem!_set!_ne _ _ _ _ (by simp only [f]; split <;> omega), insert_shift _ (hiN _),
        getElem!_pos _ k₀ (by simpa using hk₀), Array.getElem_map, hT]
      have := h6 k₀ hk₀
      rw [getElem!_pos p.nodes k₀ hk₀] at this
      cases hn₀ : p.nodes[k₀] with
      | op o args =>
        rw [hn₀] at this
        refine ⟨fun x hx => ?_, ?_⟩
        · obtain ⟨y, hy, rfl⟩ := List.mem_map.mp hx
          have := this.1 y hy; simp only [f]; split <;> split <;> omega
        · rw [List.map_map, hC]
          have e : (fun x => (p.types.insertIdx! i Ty.bool)[x]!) ∘ f = (fun x => p.types[x]!) := funext hT
          rw [e]; exact this.2
      | _ => rw [hn₀] at this; exact this

theorem op_lt {p : Program} {i : Nat} {o : Op} {args : List Nat} (h : p.nodes[i]! = .op o args) : i < p.nodes.size := by
  rcases Nat.lt_or_ge i p.nodes.size with hi | hi
  · exact hi
  · rw [getElem!_neg p.nodes i (by omega)] at h; cases h

theorem isConst_eq {p : Program} {c : Nat} {bits : UInt64} {u : Dim} (h : isConst p c bits u = true) :
    p.nodes[c]! = .const bits u := by
  simpa [isConst] using h

/-- A constant's node has its declared type. -/
theorem WF.const {p : Program} (hp : p.WF) {c : Nat} {bits : UInt64} {u : Dim} (h : p.nodes[c]! = .const bits u) :
    p.types[c]! = .num u := by
  rcases Nat.lt_or_ge c p.nodes.size with hc | hc
  · have := hp.2.2.2.2.2 c hc; rw [h] at this; exact this
  · rw [getElem!_neg p.nodes c (by omega)] at h; cases h

end Ref
