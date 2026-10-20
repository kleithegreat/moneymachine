import Ref.Spec

/-! The simulator's market index (`Market.index`) against the plain definitions the laws use: the bar map finds
the unique bar with a (coin, openTime) key. -/

namespace Ref
open Std
variable {α : Type} [Inhabited α]

/-- One bar added to the index under construction. -/
def indexStep (acc : HashMap (Nat × Int) Nat × Nat) (b : BarRow α) : HashMap (Nat × Int) Nat × Nat :=
  (acc.1.insert (b.coin, b.openTime) acc.2, acc.2 + 1)

omit [Inhabited α] in
theorem indexFold_snd (l : List (BarRow α)) (acc : HashMap (Nat × Int) Nat × Nat) :
    (l.foldl indexStep acc).2 = acc.2 + l.length := by
  induction l generalizing acc with
  | nil => rfl
  | cons b l ih => simp only [List.foldl_cons, ih, indexStep, List.length_cons]; omega

omit [Inhabited α] in
/-- A hit is a position of a bar with that key, or was already in the map. -/
theorem indexFold_sound (l : List (BarRow α)) (acc : HashMap (Nat × Int) Nat × Nat) (k : Nat × Int) (i : Nat)
    (h : (l.foldl indexStep acc).1[k]? = some i) :
    acc.1[k]? = some i ∨ ∃ j, ∃ hj : j < l.length, i = acc.2 + j ∧ (l[j].coin, l[j].openTime) = k := by
  induction l generalizing acc with
  | nil => exact Or.inl h
  | cons b l ih =>
    rcases ih _ h with h' | ⟨j, hj, rfl, hk⟩
    · simp only [indexStep, HashMap.getElem?_insert] at h'
      split at h'
      · rename_i hb; cases h'; exact Or.inr ⟨0, by simp, by simp, by simpa using hb⟩
      · exact Or.inl h'
    · exact Or.inr ⟨j + 1, by simp; omega, by simp [indexStep]; omega, by simpa using hk⟩

omit [Inhabited α] in
theorem indexFold_keep (l : List (BarRow α)) (acc : HashMap (Nat × Int) Nat × Nat) (k : Nat × Int)
    (h : ∀ b ∈ l, (b.coin, b.openTime) ≠ k) : (l.foldl indexStep acc).1[k]? = acc.1[k]? := by
  induction l generalizing acc with
  | nil => rfl
  | cons b l ih =>
    simp only [List.foldl_cons]
    rw [ih _ fun b' hb' => h b' (by simp [hb'])]
    simp only [indexStep, HashMap.getElem?_insert]
    rw [if_neg (by simpa using h b (by simp))]

omit [Inhabited α] in
/-- With unique keys, every bar's key finds its position. -/
theorem indexFold_complete (l : List (BarRow α)) (acc : HashMap (Nat × Int) Nat × Nat)
    (hu : (l.map fun b => (b.coin, b.openTime)).Nodup) (j : Nat) (hj : j < l.length) :
    (l.foldl indexStep acc).1[(l[j].coin, l[j].openTime)]? = some (acc.2 + j) := by
  induction l generalizing acc j with
  | nil => simp at hj
  | cons b l ih =>
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at hu
    cases j with
    | zero =>
      simp only [List.foldl_cons, List.getElem_cons_zero]
      rw [indexFold_keep _ _ _ fun b' hb' he => hu.1 ⟨b', hb', he⟩]
      simp [indexStep]
    | succ j =>
      simp only [List.foldl_cons, List.getElem_cons_succ]
      rw [ih _ hu.2 j (by simpa using hj)]
      simp [indexStep]; omega

omit [Inhabited α] in
theorem index_barAt (m : Market α) (coins : Nat) :
    (m.index coins).barAt = (m.bars.toList.foldl indexStep (HashMap.emptyWithCapacity, 0)).1 := by
  simp only [Market.index, ← Array.foldl_toList]
  rfl

omit [Inhabited α] in
/-- A hit in the bar map is a bar with that key. -/
theorem barAt_sound (m : Market α) (coins : Nat) {c : Nat} {t : Int} {i : Nat}
    (h : (m.index coins).barAt[(c, t)]? = some i) :
    ∃ hi : i < m.bars.size, m.bars[i].coin = c ∧ m.bars[i].openTime = t := by
  rw [index_barAt] at h
  rcases indexFold_sound _ _ _ _ h with h' | ⟨j, hj, rfl, hk⟩
  · simp at h'
  · simp only [Nat.zero_add, Prod.mk.injEq] at hk ⊢
    exact ⟨by simpa using hj, by simpa using hk⟩

omit [Inhabited α] in
/-- With unique keys, every bar is found under its key. -/
theorem barAt_complete (m : Market α) (coins : Nat) (hA : m.Admissible) {i : Nat} (hi : i < m.bars.size) :
    (m.index coins).barAt[(m.bars[i].coin, m.bars[i].openTime)]? = some i := by
  rw [index_barAt]
  have := indexFold_complete m.bars.toList (HashMap.emptyWithCapacity, 0) hA.barKeys i (by simpa using hi)
  simpa using this

/-- With unique keys, the bar map agrees with the laws' `barAt`. -/
theorem barAt_spec (m : Market α) (coins : Nat) (hA : m.Admissible) {c : Nat} {t : Int} {i : Nat}
    (h : (m.index coins).barAt[(c, t)]? = some i) : ∃ hi : i < m.bars.size, barAt m c t = some m.bars[i] := by
  obtain ⟨hi, rfl, rfl⟩ := barAt_sound m coins h
  refine ⟨hi, ?_⟩
  unfold barAt
  rw [List.find?_eq_some_iff_getElem]
  refine ⟨by simp, i, by simpa using hi, by simp, fun j hj => ?_⟩
  have hj' : j < m.bars.toList.length := by simp; omega
  cases hb : ((m.bars.toList[j]'hj').coin == m.bars[i].coin && (m.bars.toList[j]'hj').openTime == m.bars[i].openTime)
  · rfl
  exfalso
  simp only [Bool.and_eq_true, beq_iff_eq] at hb
  have e : (m.bars.toList.map fun b => (b.coin, b.openTime))[j]'(by simp; omega) =
      (m.bars.toList.map fun b => (b.coin, b.openTime))[i]'(by simpa using hi) := by
    simp only [List.getElem_map]; rw [hb.1, hb.2]; simp
  have := hA.barKeys.getElem_inj.mp e
  omega

end Ref
