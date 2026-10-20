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

omit [Inhabited α] in
/-- On a list whose keys are unique, equal keys mean equal elements. -/
theorem eq_of_key {β γ : Type} (f : β → γ) : ∀ {l : List β}, (l.map f).Nodup → ∀ {a b : β}, a ∈ l → b ∈ l →
    f a = f b → a = b
  | [], _, _, _, ha, _, _ => by simp at ha
  | x :: xs, hn, a, b, ha, hb, h => by
    simp only [List.map_cons, List.nodup_cons, List.mem_map, not_exists, not_and] at hn
    simp only [List.mem_cons] at ha hb
    rcases ha with rfl | ha <;> rcases hb with rfl | hb
    · rfl
    · exact absurd h.symm (hn.1 b hb)
    · exact absurd h (hn.1 a ha)
    · exact eq_of_key f hn.2 ha hb h

/-- The fold of `latestClosed`: the first element with the greatest openTime. -/
def maxOpen (acc : Option (BarRow α)) (b : BarRow α) : Option (BarRow α) :=
  match acc with | some a => if a.openTime < b.openTime then some b else acc | none => some b

omit [Inhabited α] in
theorem maxOpen_fold (l : List (BarRow α)) (acc : Option (BarRow α)) (x : BarRow α)
    (h : l.foldl maxOpen acc = some x) :
    (acc = some x ∨ x ∈ l) ∧ (∀ a, acc = some a → a.openTime ≤ x.openTime) ∧ ∀ y ∈ l, y.openTime ≤ x.openTime := by
  induction l generalizing acc with
  | nil =>
    refine ⟨Or.inl h, fun a ha => ?_, by simp⟩
    rw [List.foldl_nil, ha] at h; cases h; exact Int.le_refl _
  | cons b l ih =>
    obtain ⟨hm, ha', hl⟩ := ih _ h
    refine ⟨?_, fun a hac => ?_, fun y hy => ?_⟩
    · rcases hm with hm | hm
      · cases acc with
        | none => simp only [maxOpen, Option.some.injEq] at hm; exact Or.inr (by simp [hm])
        | some a =>
          simp only [maxOpen] at hm
          split at hm
          · cases hm; exact Or.inr (by simp)
          · exact Or.inl hm
      · exact Or.inr (by simp [hm])
    · subst hac
      by_cases hlt : a.openTime < b.openTime
      · have := ha' b (by simp [maxOpen, hlt]); omega
      · exact ha' a (by simp [maxOpen, hlt])
    · simp only [List.mem_cons] at hy
      rcases hy with rfl | hy
      · cases acc with
        | none => exact ha' y (by simp [maxOpen])
        | some a =>
          by_cases hlt : a.openTime < y.openTime
          · exact ha' y (by simp [maxOpen, hlt])
          · have := ha' a (by simp [maxOpen, hlt]); omega
      · exact hl y hy

omit [Inhabited α] in
theorem maxOpen_fold_some (l : List (BarRow α)) (acc : Option (BarRow α)) (h : l ≠ []) :
    l.foldl maxOpen acc ≠ none := by
  induction l generalizing acc with
  | nil => exact absurd rfl h
  | cons b l ih =>
    cases l with
    | nil => cases acc <;> simp [maxOpen] <;> split <;> simp
    | cons b' l => exact ih _ (by simp)

/-- The latest closed bar is a bar of the coin closed by t whose openTime no other such bar exceeds. -/
theorem latestClosed_spec (m : Market α) (c : Nat) (t : Int) (x : BarRow α) (h : latestClosed m c t = some x) :
    x ∈ m.bars.toList ∧ x.coin = c ∧ x.event ≤ t ∧
      ∀ y ∈ m.bars.toList, y.coin = c → y.event ≤ t → y.openTime ≤ x.openTime := by
  unfold latestClosed at h
  obtain ⟨hm, -, hl⟩ := maxOpen_fold _ none x h
  rcases hm with hm | hm
  · cases hm
  · simp only [List.mem_filter, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hm
    exact ⟨hm.1, hm.2.1, hm.2.2, fun y hy hc he => hl y (by simp [hy, hc, he])⟩

/-- With unique keys, a bar of the coin closed by t that no such bar exceeds is the latest closed bar. -/
theorem latestClosed_of_max (m : Market α) (hA : m.Admissible) (c : Nat) (t : Int) (x : BarRow α)
    (hx : x ∈ m.bars.toList) (hc : x.coin = c) (he : x.event ≤ t)
    (hmax : ∀ y ∈ m.bars.toList, y.coin = c → y.event ≤ t → y.openTime ≤ x.openTime) :
    latestClosed m c t = some x := by
  cases h : latestClosed m c t with
  | none =>
    unfold latestClosed at h
    exact absurd h (maxOpen_fold_some _ none (List.ne_nil_of_mem (List.mem_filter.mpr ⟨hx, by simp [hc, he]⟩)))
  | some y =>
    obtain ⟨hy, hyc, hye, hymax⟩ := latestClosed_spec m c t y h
    have h1 := hmax y hy hyc hye
    have h2 := hymax x hx hc he
    have := eq_of_key (fun b : BarRow α => (b.coin, b.openTime)) hA.barKeys hy hx (by simp [hyc, hc]; omega)
    rw [this]

omit [Inhabited α] in
theorem times_toList (m : Market α) (coins c : Nat) (hc : c < coins) :
    ((m.index coins).barTimes[c]!).toList = ((m.bars.toList.filter (·.coin == c)).map (·.openTime)).mergeSort (· ≤ ·) := by
  simp only [Market.index]
  rw [getElem!_pos _ c (by simpa using hc), Array.getElem_map, Array.getElem_range, Array.toList_mergeSort,
    Array.toList_map, Array.toList_filter]

omit [Inhabited α] in
theorem times_sorted (m : Market α) (coins c : Nat) (hc : c < coins) :
    ((m.index coins).barTimes[c]!).toList.Pairwise (· ≤ ·) := by
  rw [times_toList m coins c hc]
  have := List.pairwise_mergeSort (le := fun a b : Int => decide (a ≤ b))
    (fun a b c hab hbc => by simp at *; omega) (fun a b => by simp; omega)
    ((m.bars.toList.filter (·.coin == c)).map (·.openTime))
  exact this.imp (by simp)

omit [Inhabited α] in
theorem times_mem (m : Market α) (coins c : Nat) (hc : c < coins) (t : Int) :
    t ∈ ((m.index coins).barTimes[c]!).toList ↔ ∃ b ∈ m.bars.toList, b.coin = c ∧ b.openTime = t := by
  rw [times_toList m coins c hc, (List.mergeSort_perm _ _).mem_iff]
  simp [List.mem_filter, and_assoc]

/-- `find?` on the reverse of an ascending list finds its largest element satisfying p. -/
theorem reverse_find_max (l : List Int) (hs : l.Pairwise (· ≤ ·)) (p : Int → Bool) {x : Int}
    (h : l.reverse.find? p = some x) : x ∈ l ∧ p x ∧ ∀ y ∈ l, p y → y ≤ x := by
  rw [List.find?_eq_some_iff_append] at h
  obtain ⟨hpx, as, bs, hl, has⟩ := h
  have hl' : l = bs.reverse ++ x :: as.reverse := by
    rw [← List.reverse_reverse l, hl]; simp
  refine ⟨by rw [hl']; simp, hpx, fun y hy hpy => ?_⟩
  rw [hl'] at hy hs
  simp only [List.mem_append, List.mem_reverse, List.mem_cons] at hy
  rcases hy with hy | rfl | hy
  · rw [List.pairwise_append] at hs
    exact hs.2.2 y (by simpa using hy) x (by simp)
  · exact Int.le_refl _
  · exact absurd hpy (by simpa using has y hy)

omit [Inhabited α] in
theorem ite_ok {ε β : Type} {b : Bool} {e : ε} {x : Except ε β} {v : β}
    (h : (if b = true then Except.error e else x) = .ok v) : b = false ∧ x = .ok v := by
  cases b <;> simp_all

/-- What a passed fill check establishes. -/
theorem checkFill_ok (N : NumOps α) (f : Fill α) (m : Market α) (ix : Index α) (v : Venue α)
    (h : checkFill N f m ix v = .ok ()) :
    (f.inputsKnown ≤ f.decided ∧ f.decided ≤ f.submitted ∧ f.submitted ≤ f.filled) ∧ N.isZero f.qty = false ∧
    ∃ bi, ix.barAt[(f.coin, f.sourceOpen)]? = some bi ∧
      (f.why ≠ .fill → (ix.barTimes[f.coin]!).toList.reverse.find?
        (fun t => decide (m.bars[ix.barAt[(f.coin, t)]!]!.event ≤ f.filled)) = some m.bars[bi]!.openTime) := by
  unfold checkFill at h
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at h
  split at h
  · cases h
  rename_i ht
  refine ⟨by simpa [and_assoc] using ht, ?_⟩
  revert h
  cases hb : ix.barAt[(f.coin, f.sourceOpen)]? with
  | none => intro h; cases h
  | some bi =>
    intro h
    cases hw : f.why
    · simp only [hw] at h
      obtain ⟨h1, -⟩ := ite_ok h
      simp only [Bool.not_eq_false', Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h1
      exact ⟨by simpa using h1.2.1.1, bi, rfl, fun h => absurd rfl h⟩
    all_goals
      simp only [hw] at h
      obtain ⟨h1, -⟩ := ite_ok h
      simp only [Bool.not_eq_false', Bool.and_eq_true, beq_iff_eq] at h1
      refine ⟨by simpa using h1.2.1.1, bi, rfl, fun _ => ?_⟩
      rw [← h1.1.1, ← Array.find?_toList, Array.toList_reverse]

/-- A passed closeout check names the coin's latest bar closed by the fill. -/
theorem closeout_latest (N : NumOps α) (f : Fill α) (m : Market α) (hA : m.Admissible) (v : Venue α)
    (h : checkFill N f m (m.index m.intervals.size) v = .ok ()) (hw : f.why ≠ .fill) :
    ∃ i, ∃ hi : i < m.bars.size, (m.index m.intervals.size).barAt[(f.coin, f.sourceOpen)]? = some i ∧
      latestClosed m f.coin f.filled = some m.bars[i] ∧ f.sourceOpen = m.bars[i].openTime := by
  obtain ⟨-, -, bi, hbi, hfind⟩ := checkFill_ok N f m _ v h
  obtain ⟨hi, hc, ho⟩ := barAt_sound m _ hbi
  have hcoins : f.coin < m.intervals.size := hc ▸ hA.barCoin _ (Array.getElem_mem_toList hi)
  have hbang : ∀ j (hj : j < m.bars.size), (m.index m.intervals.size).barAt[(m.bars[j].coin, m.bars[j].openTime)]! = j :=
    fun j hj => by rw [getElem!_def, barAt_complete m _ hA hj]
  obtain ⟨-, hp, hmax⟩ := reverse_find_max _ (times_sorted m _ _ hcoins) _ (hfind hw)
  rw [getElem!_pos m.bars bi hi] at hp hmax
  refine ⟨bi, hi, hbi, latestClosed_of_max m hA _ _ _ (Array.getElem_mem_toList hi) hc ?_ ?_, ho.symm⟩
  · have := hbang bi hi
    rw [hc] at this
    simpa [this, getElem!_pos m.bars bi hi] using hp
  · intro y hy hyc hye
    obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem hy
    have hj' : j < m.bars.size := by simpa using hj
    apply hmax
    · exact (times_mem m _ _ hcoins _).mpr ⟨_, hy, hyc, rfl⟩
    · have := hbang j hj'
      simp only [Array.getElem_toList] at hyc hye ⊢
      rw [hyc] at this
      simp [this, getElem!_pos m.bars j hj', hye]

end Ref
