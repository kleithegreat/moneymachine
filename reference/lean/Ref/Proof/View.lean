import Ref.Proof.Orders

/-! L1 for decisions: everything execution reads by a time is fixed by the execution view by that time. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- Two admissible markets with the same listing intervals and the same execution view by T (`Ctx.execView`). -/
structure SameView (m₁ m₂ : Market α) (T : Int) : Prop where
  A₁ : m₁.Admissible
  A₂ : m₂.Admissible
  intervals : m₁.intervals = m₂.intervals
  rates : (m₁.funding.toList.filter (·.event ≤ T)).map (fun f => (f.coin, f.event, f.rate)) =
    (m₂.funding.toList.filter (·.event ≤ T)).map (fun f => (f.coin, f.event, f.rate))
  closed : m₁.bars.toList.filter (fun b => b.openTime + BAR ≤ T) = m₂.bars.toList.filter (fun b => b.openTime + BAR ≤ T)
  opened : (m₁.bars.toList.filter (·.openTime ≤ T)).map (fun b => (b.coin, b.openTime, b.o, b.trades)) =
    (m₂.bars.toList.filter (·.openTime ≤ T)).map (fun b => (b.coin, b.openTime, b.o, b.trades))

/-- A bar's fields fixed when it opens. -/
def openFields (b : BarRow α) : Nat × Int × α × Int := (b.coin, b.openTime, b.o, b.trades)

/-- The bar open times of a coin, ascending. -/
def times (m : Market α) (c : Nat) : Array Int := (m.index m.intervals.size).barTimes[c]!

omit [Inhabited α] in
theorem times_out (m : Market α) {c : Nat} (hc : m.intervals.size ≤ c) : times m c = #[] := by
  simp [times, Market.index, hc]; rfl

theorem find_restrict {β : Type} (l : List β) (p q : β → Bool) (h : ∀ x, p x = true → q x = true) :
    l.find? p = (l.filter q).find? p := by
  rw [List.find?_filter]
  congr 1; funext x
  cases hp : p x <;> simp [hp, h x]

variable {m₁ m₂ : Market α} {T : Int}

namespace SameView

omit [Inhabited α] in
theorem barAt_opened (S : SameView m₁ m₂ T) {c : Nat} {t : Int} (ht : t ≤ T) :
    (barAt m₁ c t).map openFields = (barAt m₂ c t).map openFields := by
  have key : ∀ m : Market α, (barAt m c t).map openFields =
      ((m.bars.toList.filter (·.openTime ≤ T)).map (fun b => (b.coin, b.openTime, b.o, b.trades))).find?
        (fun x => x.1 == c && x.2.1 == t) := by
    intro m
    unfold barAt
    rw [List.find?_map, find_restrict _ _ (fun b => decide (b.openTime ≤ T)) (by intro x hx; simp at hx ⊢; omega)]
    rfl
  rw [key, key, S.opened]

omit [Inhabited α] in
theorem barAt_closed (S : SameView m₁ m₂ T) {c : Nat} {t : Int} (ht : t + BAR ≤ T) : barAt m₁ c t = barAt m₂ c t := by
  have key : ∀ m : Market α, barAt m c t =
      (m.bars.toList.filter (fun b => b.openTime + BAR ≤ T)).find? (fun b => b.coin == c && b.openTime == t) := by
    intro m
    unfold barAt
    exact find_restrict _ _ _ (by intro x hx; simp at hx ⊢; omega)
  rw [key, key, S.closed]

omit [Inhabited α] in
theorem times_iff (S : SameView m₁ m₂ T) {c : Nat} {t : Int} (ht : t ≤ T) :
    t ∈ (times m₁ c).toList ↔ t ∈ (times m₂ c).toList := by
  unfold times
  by_cases hc : c < m₁.intervals.size
  · rw [times_mem m₁ _ c hc, times_mem m₂ _ c (S.intervals ▸ hc)]
    have e : ∀ m : Market α, (∃ b ∈ m.bars.toList, b.coin = c ∧ b.openTime = t) ↔ (barAt m c t).isSome := by
      intro m; unfold barAt; simp
    rw [e, e, ← Option.isSome_map (f := openFields), S.barAt_opened ht, Option.isSome_map]
  · rw [show (m₁.index m₁.intervals.size).barTimes[c]! = times m₁ c from rfl,
      show (m₂.index m₂.intervals.size).barTimes[c]! = times m₂ c from rfl,
      times_out m₁ (by omega), times_out m₂ (by rw [← S.intervals]; omega)]

end SameView

/-- The index finds the bar `barAt` names. -/
theorem lookup_barAt (m : Market α) (coins : Nat) (hA : m.Admissible) (c : Nat) (t : Int) :
    ((m.index coins).barAt[(c, t)]?).map (m.bars[·]!) = barAt m c t := by
  cases h : (m.index coins).barAt[(c, t)]? with
  | none => exact (barAt_none m coins hA h).symm
  | some i =>
    obtain ⟨hi, hb⟩ := barAt_spec m coins hA h
    rw [hb, Option.map_some, getElem!_pos m.bars i hi]

/-- A coin's bar time names its bar. -/
theorem barAt_time (m : Market α) (hA : m.Admissible) {c : Nat} {t : Int} (ht : t ∈ (times m c).toList) :
    barAt m c t = some m.bars[(m.index m.intervals.size).barAt[(c, t)]!]! := by
  have hc : c < m.intervals.size := by
    rcases Nat.lt_or_ge c m.intervals.size with hc | hc
    · exact hc
    · rw [times_out m hc] at ht; simp at ht
  obtain ⟨b, hb, rfl, rfl⟩ := (times_mem m _ _ hc t).mp ht
  obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem hb
  have hj' : j < m.bars.size := by simpa using hj
  have hix := barAt_complete m m.intervals.size hA hj'
  simp only [Array.getElem_toList]
  have hix' : (m.index m.intervals.size).barAt[(m.bars[j].coin, m.bars[j].openTime)]! = j := by
    rw [getElem!_def, hix]
  obtain ⟨_, hs⟩ := barAt_spec m _ hA hix
  rw [hix', hs, getElem!_pos m.bars j hj']

omit [Inhabited α] in
theorem rateAt_fold (l : List (FundingRow α)) (acc : Std.HashMap (Nat × Int) α) (k : Nat × Int) :
    (l.foldl (fun h f => h.insert (f.coin, f.event) f.rate) acc)[k]? =
      ((l.reverse.find? fun f => (f.coin, f.event) == k).map (·.rate)).or acc[k]? := by
  induction l generalizing acc with
  | nil => simp
  | cons x l ih =>
    rw [List.foldl_cons, ih, List.reverse_cons, List.find?_append, Std.HashMap.getElem?_insert]
    cases (l.reverse.find? fun f => (f.coin, f.event) == k) with
    | some y => simp
    | none => cases hx : ((x.coin, x.event) == k) <;> simp [hx]

omit [Inhabited α] in
theorem rateAt_get (m : Market α) (coins : Nat) (k : Nat × Int) :
    (m.index coins).rateAt[k]? = (m.funding.toList.reverse.find? fun f => (f.coin, f.event) == k).map (·.rate) := by
  simp only [Market.index, ← Array.foldl_toList, rateAt_fold]
  simp

omit [Inhabited α] in
theorem SameView.rate (S : SameView m₁ m₂ T) (n₁ n₂ c : Nat) {h : Int} (hh : h ≤ T) :
    (m₁.index n₁).rateAt[(c, h)]? = (m₂.index n₂).rateAt[(c, h)]? := by
  have key : ∀ (m : Market α) (n : Nat), (m.index n).rateAt[(c, h)]? =
      ((((m.funding.toList.filter (·.event ≤ T)).map fun f => (f.coin, f.event, f.rate)).reverse.find?
        fun x => (x.1, x.2.1) == (c, h)).map (·.2.2)) := by
    intro m n
    rw [rateAt_get, find_restrict _ _ (fun f => decide (f.event ≤ T)) (by intro x hx; simp at hx ⊢; omega),
      List.filter_reverse, ← List.map_reverse, List.find?_map, Option.map_map]
    rfl
  rw [key, key, S.rates]

/-- Partition point: before it the predicate holds, at it (if inside) it fails. -/
theorem pp_spec (xs : Array Int) (q : Int → Bool) :
    partitionPoint xs q ≤ xs.size ∧ (∀ i (h : i < xs.size), i < partitionPoint xs q → q xs[i] = true) ∧
      ∀ h : partitionPoint xs q < xs.size, q xs[partitionPoint xs q] = false := by
  unfold partitionPoint
  cases hf : xs.findIdx? (fun t => !q t) with
  | none =>
    have := Array.findIdx?_eq_none_iff.mp hf
    refine ⟨by simp, fun i h _ => by simpa using this xs[i] (Array.getElem_mem h), fun h => by simp at h⟩
  | some k =>
    obtain ⟨hk, hnk, hlt⟩ := Array.findIdx?_eq_some_iff_getElem.mp hf
    simp only [Option.getD_some]
    exact ⟨by omega, fun i h hi => by simpa using hlt i hi, fun _ => by simpa using hnk⟩

/-- In an ascending array, the element before the partition point of `· ≤ b` is the largest one ≤ b. -/
theorem pp_max (xs : Array Int) (hs : xs.toList.Pairwise (· ≤ ·)) (b : Int) :
    (partitionPoint xs (fun t => decide (t ≤ b)) = 0 → ∀ t ∈ xs.toList, ¬t ≤ b) ∧
    ∀ (h : partitionPoint xs (fun t => decide (t ≤ b)) - 1 < xs.size), partitionPoint xs (fun t => decide (t ≤ b)) ≠ 0 →
      xs[partitionPoint xs (fun t => decide (t ≤ b)) - 1] ≤ b ∧
        ∀ t ∈ xs.toList, t ≤ b → t ≤ xs[partitionPoint xs (fun t => decide (t ≤ b)) - 1] := by
  obtain ⟨hsz, hbefore, hat⟩ := pp_spec xs (fun t => decide (t ≤ b))
  have sorted : ∀ i j (hi : i < xs.size) (hj : j < xs.size), i ≤ j → xs[i] ≤ xs[j] := by
    intro i j hi hj hij
    rcases Nat.lt_or_eq_of_le hij with hij | rfl
    · have := List.pairwise_iff_getElem.mp hs i j (by simpa using hi) (by simpa using hj) hij
      simp only [Array.getElem_toList] at this
      exact this
    · exact Int.le_refl _
  generalize partitionPoint xs (fun t => decide (t ≤ b)) = k at hsz hbefore hat ⊢
  refine ⟨fun hk t ht htb => ?_, fun h hk => ⟨by simpa using hbefore _ h (by omega), fun t ht htb => ?_⟩⟩
  · subst hk
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem ht
    have hi' : i < xs.size := by simpa using hi
    have := hat (by omega)
    have := sorted 0 i (by omega) hi' (Nat.zero_le _)
    simp at *; omega
  · obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem ht
    have hi' : i < xs.size := by simpa using hi
    by_cases hik : i < k
    · exact sorted i (k - 1) hi' h (by omega)
    · have := hat (by omega)
      have := sorted k i (by omega) hi' (by omega)
      simp at *; omega

omit [Inhabited α] in
theorem times_sorted' (m : Market α) (c : Nat) : (times m c).toList.Pairwise (· ≤ ·) := by
  by_cases hc : c < m.intervals.size
  · exact times_sorted m _ _ hc
  · rw [times_out m (by omega)]; simp

theorem SameView.latest (S : SameView m₁ m₂ T) {b : Int} (hb : b + BAR ≤ T) (x : Nat × α) :
    latestOf (m₁.index m₁.intervals.size) m₁.bars b x = latestOf (m₂.index m₂.intervals.size) m₂.bars b x := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  unfold latestOf
  have P₁ := pp_max (times m₁ x.1) (times_sorted' m₁ x.1) b
  have P₂ := pp_max (times m₂ x.1) (times_sorted' m₂ x.1) b
  have hiff : ∀ t ≤ b, t ∈ (times m₁ x.1).toList ↔ t ∈ (times m₂ x.1).toList := fun t ht => S.times_iff (by omega)
  have bt₁ := fun t => barAt_time m₁ S.A₁ (c := x.1) (t := t)
  have bt₂ := fun t => barAt_time m₂ S.A₂ (c := x.1) (t := t)
  unfold times at P₁ P₂ hiff bt₁ bt₂
  generalize (m₁.index m₁.intervals.size).barTimes[x.1]! = xs₁ at P₁ hiff bt₁ ⊢
  generalize (m₂.index m₂.intervals.size).barTimes[x.1]! = xs₂ at P₂ hiff bt₂ ⊢
  generalize hk₁ : partitionPoint xs₁ (fun t => decide (t ≤ b)) = k₁ at P₁
  generalize hk₂ : partitionPoint xs₂ (fun t => decide (t ≤ b)) = k₂ at P₂
  have hsz₁ := (pp_spec xs₁ (fun t => decide (t ≤ b))).1
  have hsz₂ := (pp_spec xs₂ (fun t => decide (t ≤ b))).1
  rw [hk₁] at hsz₁; rw [hk₂] at hsz₂
  by_cases h₁ : k₁ = 0 <;> by_cases h₂ : k₂ = 0
  · simp [h₁, h₂]
  · obtain ⟨hle, -⟩ := P₂.2 (by omega) h₂
    exact absurd hle (P₁.1 h₁ _ ((hiff _ hle).mpr (Array.getElem_mem_toList _)))
  · obtain ⟨hle, -⟩ := P₁.2 (by omega) h₁
    exact absurd hle (P₂.1 h₂ _ ((hiff _ hle).mp (Array.getElem_mem_toList _)))
  · obtain ⟨hle₁, hmax₁⟩ := P₁.2 (by omega) h₁
    obtain ⟨hle₂, hmax₂⟩ := P₂.2 (by omega) h₂
    have hm₁ := Array.getElem_mem_toList (xs := xs₁) (i := k₁ - 1) (by omega)
    have hm₂ := Array.getElem_mem_toList (xs := xs₂) (i := k₂ - 1) (by omega)
    have heq : xs₁[k₁ - 1] = xs₂[k₂ - 1] := Int.le_antisymm (hmax₂ _ ((hiff _ hle₁).mp hm₁) hle₁)
      (hmax₁ _ ((hiff _ hle₂).mpr hm₂) hle₂)
    have e₁ := bt₁ _ hm₁
    have e₂ := bt₂ _ hm₂
    rw [S.barAt_closed (by omega), heq, e₂, Option.some.injEq] at e₁
    simp only [h₁, h₂, beq_iff_eq, ite_false, Option.some.injEq, Prod.mk.injEq,
      true_and, getElem!_pos xs₁ (k₁ - 1) (by omega), getElem!_pos xs₂ (k₂ - 1) (by omega)]
    rw [← heq] at e₁ ⊢
    exact e₁.symm

/-- `checkFill` with its market reads named: the bar under the fill's source key, and whether a bar time is the
first at or after submission, or the latest closed by the fill. -/
def checkSpec (N : NumOps α) (f : Fill α) (v : Venue α) (ob : Option (BarRow α)) (first latest : Int → Bool) :
    Except Abort Unit := do
  if !(f.inputsKnown ≤ f.decided && f.decided ≤ f.submitted && f.submitted ≤ f.filled) then throw .timing
  let some bar := ob | throw .fill
  let fee := N.mul (N.mul (N.abs f.qty) f.price) v.takerFee
  let priced := !N.isZero f.qty && N.eq f.price (fillPrice N v f.coin f.qty f.reference) && N.eq f.fee fee
  let ok := match f.why with
    | .fill => first bar.openTime && bar.openTime ≤ f.filled && bar.trades ≥ 1 && N.eq f.reference bar.o
    | w =>
      let reference := if w == .delisting then bar.c else if N.lt N.zero f.qty then bar.h else bar.l
      latest bar.openTime && N.eq f.reference reference
  if !(ok && priced) then throw .fill
  if f.why == .fill && N.lt (N.mul (maxOrderNotional N) (N.add N.one (N.ofBits 0x3D719799812DEA11))) (N.mul (N.abs f.qty) f.decisionPrice) then
    throw .portfolio

/-- The first bar time at or after sub. -/
def IsFirst (xs : List Int) (sub s : Int) : Prop := s ∈ xs ∧ sub ≤ s ∧ ∀ t ∈ xs, sub ≤ t → s ≤ t

/-- The latest bar time closed by t. -/
def IsLatest (xs : List Int) (t s : Int) : Prop := s ∈ xs ∧ s + BAR ≤ t ∧ ∀ u ∈ xs, u + BAR ≤ t → u ≤ s

instance (xs : List Int) (sub s : Int) : Decidable (IsFirst xs sub s) := by unfold IsFirst; infer_instance
instance (xs : List Int) (t s : Int) : Decidable (IsLatest xs t s) := by unfold IsLatest; infer_instance

theorem first_iff (xs : Array Int) (hs : xs.toList.Pairwise (· ≤ ·)) (sub s : Int) :
    (xs[partitionPoint xs (fun t => decide (t < sub))]? == some s) = decide (IsFirst xs.toList sub s) := by
  obtain ⟨hsz, hbefore, hat⟩ := pp_spec xs (fun t => decide (t < sub))
  have sorted : ∀ i j (hi : i < xs.size) (hj : j < xs.size), i ≤ j → xs[i] ≤ xs[j] := by
    intro i j hi hj hij
    rcases Nat.lt_or_eq_of_le hij with hij | rfl
    · have := List.pairwise_iff_getElem.mp hs i j (by simpa using hi) (by simpa using hj) hij
      simp only [Array.getElem_toList] at this
      exact this
    · exact Int.le_refl _
  generalize partitionPoint xs (fun t => decide (t < sub)) = k at hsz hbefore hat ⊢
  have after : ∀ t ∈ xs.toList, sub ≤ t → ∃ i, ∃ hi : i < xs.size, k ≤ i ∧ xs[i] = t := by
    intro t ht hst
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem ht
    have hi' : i < xs.size := by simpa using hi
    refine ⟨i, hi', ?_, by simp⟩
    by_cases hik : i < k
    · have := hbefore i hi' hik; simp at this hst; omega
    · omega
  apply Bool.eq_iff_iff.mpr
  rw [beq_iff_eq, decide_eq_true_iff]
  rcases Nat.lt_or_ge k xs.size with hk | hk
  · have hk0 := hat hk
    simp only [decide_eq_false_iff_not, Int.not_lt] at hk0
    rw [Array.getElem?_eq_getElem hk, Option.some.injEq]
    refine ⟨fun h => h ▸ ⟨Array.getElem_mem_toList hk, hk0, fun t ht hst => ?_⟩, fun ⟨hm, hss, hmin⟩ => ?_⟩
    · obtain ⟨i, hi, hki, rfl⟩ := after t ht hst
      exact sorted k i hk hi hki
    · obtain ⟨i, hi, hki, rfl⟩ := after s hm hss
      exact Int.le_antisymm (sorted k i hk hi hki) (hmin _ (Array.getElem_mem_toList hk) hk0)
  · rw [Array.getElem?_eq_none (by omega)]
    refine ⟨(fun h => by cases h), fun ⟨hm, hss, _⟩ => ?_⟩
    obtain ⟨i, hi, hki, -⟩ := after s hm hss
    omega

theorem latest_iff (m : Market α) (hA : m.Admissible) (c : Nat) (t s : Int) :
    ((times m c).reverse.find? (fun u => decide (m.bars[(m.index m.intervals.size).barAt[(c, u)]!]!.event ≤ t)) == some s) =
      decide (IsLatest (times m c).toList t s) := by
  have hpred : ∀ u ∈ (times m c).toList,
      decide (m.bars[(m.index m.intervals.size).barAt[(c, u)]!]!.event ≤ t) = decide (u + BAR ≤ t) := by
    intro u hu
    have hb := barAt_time m hA hu
    unfold barAt at hb
    have hmem := List.mem_of_find?_eq_some hb
    have hp := List.find?_some hb
    simp only [Bool.and_eq_true, beq_iff_eq] at hp
    rw [hA.barEvent _ hmem, hp.2]
  rw [← Array.find?_toList, Array.toList_reverse]
  apply Bool.eq_iff_iff.mpr
  rw [beq_iff_eq, decide_eq_true_iff]
  cases h : (times m c).toList.reverse.find? (fun u => decide (m.bars[(m.index m.intervals.size).barAt[(c, u)]!]!.event ≤ t)) with
  | none =>
    refine ⟨(fun h => by cases h), fun ⟨hm, hst, _⟩ => ?_⟩
    have := List.find?_eq_none.mp h s (List.mem_reverse.mpr hm)
    rw [hpred s hm] at this
    simp at this; omega
  | some x =>
    obtain ⟨hx, hpx, hmax⟩ := reverse_find_max _ (times_sorted' m c) _ h
    rw [hpred x hx] at hpx
    simp only [decide_eq_true_eq] at hpx
    rw [Option.some.injEq]
    refine ⟨fun h => h ▸ ⟨hx, hpx, fun u hu hut => hmax u hu (by rw [hpred u hu]; simpa using hut)⟩,
      fun ⟨hm, hst, hlat⟩ => Int.le_antisymm (hlat x hx hpx) (hmax s hm (by rw [hpred s hm]; simpa using hst))⟩

theorem checkFill_spec (N : NumOps α) (f : Fill α) (m : Market α) (hA : m.Admissible) (v : Venue α) :
    checkFill N f m (m.index m.intervals.size) v = checkSpec N f v (barAt m f.coin f.sourceOpen)
      (fun s => decide (IsFirst (times m f.coin).toList f.submitted s))
      (fun s => decide (IsLatest (times m f.coin).toList f.filled s)) := by
  unfold checkFill checkSpec
  cases hb : (m.index m.intervals.size).barAt[(f.coin, f.sourceOpen)]? with
  | none => rw [barAt_none m _ hA hb]
  | some bi =>
    obtain ⟨hi, hs⟩ := barAt_spec m _ hA hb
    dsimp only
    rw [hs, getElem!_pos m.bars bi hi, show (m.index m.intervals.size).barTimes[f.coin]! = times m f.coin from rfl]
    simp only [first_iff _ (times_sorted' m f.coin), latest_iff m hA]
    rfl

omit [Inhabited α] in
theorem SameView.first (S : SameView m₁ m₂ T) (c : Nat) {sub s : Int} (hs : s ≤ T) :
    IsFirst (times m₁ c).toList sub s ↔ IsFirst (times m₂ c).toList sub s := by
  have h := fun t (ht : t ≤ T) => S.times_iff (c := c) ht
  constructor
  · rintro ⟨hm, hss, hmin⟩
    refine ⟨(h s hs).mp hm, hss, fun t ht hst => ?_⟩
    by_cases htT : t ≤ T
    · exact hmin t ((h t htT).mpr ht) hst
    · omega
  · rintro ⟨hm, hss, hmin⟩
    refine ⟨(h s hs).mpr hm, hss, fun t ht hst => ?_⟩
    by_cases htT : t ≤ T
    · exact hmin t ((h t htT).mp ht) hst
    · omega

omit [Inhabited α] in
theorem SameView.latest' (S : SameView m₁ m₂ T) (c : Nat) {t s : Int} (ht : t ≤ T) :
    IsLatest (times m₁ c).toList t s ↔ IsLatest (times m₂ c).toList t s := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  have h := fun u (hu : u + BAR ≤ t) => S.times_iff (c := c) (t := u) (by omega)
  constructor
  · rintro ⟨hm, hst, hmax⟩
    exact ⟨(h s hst).mp hm, hst, fun u hu hut => hmax u ((h u hut).mpr hu) hut⟩
  · rintro ⟨hm, hst, hmax⟩
    exact ⟨(h s hst).mpr hm, hst, fun u hu hut => hmax u ((h u hut).mp hu) hut⟩

/-- A fill whose source bar opens after it cannot pass: the check fails as if no bar were found. -/
theorem checkSpec_late (N : NumOps α) (f : Fill α) (v : Venue α) (ob : Option (BarRow α)) (first latest : Int → Bool)
    (hob : ∀ bar, ob = some bar → bar.openTime = f.sourceOpen) (hlate : f.filled < f.sourceOpen)
    (hlat : ∀ s, latest s = true → s + BAR ≤ f.filled) :
    checkSpec N f v ob first latest = checkSpec N f v none first latest := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  cases ob with
  | none => rfl
  | some bar =>
    have ho := hob bar rfl
    have hl : latest f.sourceOpen = false := by
      cases h : latest f.sourceOpen
      · rfl
      · have := hlat _ h; omega
    unfold checkSpec
    cases hw : f.why <;> simp [hw, hl, ho, hlate, Int.not_le.mpr hlate] <;> rfl

theorem SameView.checkSpec (S : SameView m₁ m₂ T) (N : NumOps α) (f : Fill α) (v : Venue α) (hf : f.filled ≤ T) :
    checkSpec N f v (barAt m₁ f.coin f.sourceOpen) (fun s => decide (IsFirst (times m₁ f.coin).toList f.submitted s))
      (fun s => decide (IsLatest (times m₁ f.coin).toList f.filled s)) =
    checkSpec N f v (barAt m₂ f.coin f.sourceOpen) (fun s => decide (IsFirst (times m₂ f.coin).toList f.submitted s))
      (fun s => decide (IsLatest (times m₂ f.coin).toList f.filled s)) := by
  have hopen : ∀ (m : Market α) bar, barAt m f.coin f.sourceOpen = some bar → bar.openTime = f.sourceOpen := by
    intro m bar h
    have := List.find?_some h
    simp only [Bool.and_eq_true, beq_iff_eq] at this
    exact this.2
  by_cases hso : f.sourceOpen ≤ f.filled
  · have hob := S.barAt_opened (c := f.coin) (by omega : f.sourceOpen ≤ T)
    cases h₁ : barAt m₁ f.coin f.sourceOpen <;> cases h₂ : barAt m₂ f.coin f.sourceOpen <;>
      rw [h₁, h₂] at hob <;> simp at hob
    · rfl
    · rename_i b₁ b₂
      simp only [openFields, Prod.mk.injEq] at hob
      obtain ⟨-, ho, hoo, htr⟩ := hob
      have hb₁ := hopen m₁ b₁ h₁
      have hF := S.first f.coin (sub := f.submitted) (by omega : b₁.openTime ≤ T)
      have hL := S.latest' f.coin (s := b₁.openTime) hf
      rw [ho] at hF hL
      unfold Ref.checkSpec
      simp only [hF, hL, ho, hoo, htr]
      cases hw : f.why
      · rfl
      all_goals
        by_cases hl : IsLatest (times m₂ f.coin).toList f.filled b₂.openTime
        · have hcl := S.barAt_closed (c := f.coin) (t := f.sourceOpen) (by have := hl.2.1; omega)
          rw [h₁, h₂, Option.some.injEq] at hcl
          subst hcl; rfl
        · simp [hl]
  · have late := fun (m : Market α) (xs : List Int) => checkSpec_late N f v (barAt m f.coin f.sourceOpen)
      (fun s => decide (IsFirst xs f.submitted s)) (fun s => decide (IsLatest xs f.filled s)) (hopen m)
      (by omega) (fun s h => (of_decide_eq_true h).2.1)
    rw [late, late]
    rfl

theorem SameView.execute (S : SameView m₁ m₂ T) (N : NumOps α) (p : Program) (v : Venue α) (pol : Policy)
    (stop : Int) (s : SState α) (f : Fill α) (hf : f.filled ≤ T) :
    (Ctx.make p m₁ v pol stop).execute N s f = (Ctx.make p m₂ v pol stop).execute N s f := by
  unfold Ctx.execute
  rw [show checkFill N f (Ctx.make p m₁ v pol stop).m (Ctx.make p m₁ v pol stop).ix (Ctx.make p m₁ v pol stop).v =
      checkFill N f m₁ (m₁.index m₁.intervals.size) v from rfl,
    show checkFill N f (Ctx.make p m₂ v pol stop).m (Ctx.make p m₂ v pol stop).ix (Ctx.make p m₂ v pol stop).v =
      checkFill N f m₂ (m₂.index m₂.intervals.size) v from rfl,
    checkFill_spec N f m₁ S.A₁, checkFill_spec N f m₂ S.A₂, S.checkSpec N f v hf]

omit [Inhabited α] in
theorem graft_proj (o : SState α) {x₁ x₂ : Except Abort (SState α)} (h : x₁.map SState.proj = x₂.map SState.proj) :
    x₁.map o.graft = x₂.map o.graft := by
  cases x₁ <;> cases x₂ <;> simp_all [Except.map, SState.graft, SState.proj]

theorem deliver_eq {c₁ c₂ : Ctx α} {T t : Int} (A : Agree c₁ c₂ T) (ht : t ≤ T) {s : SState α} (hi : Inside c₁ T s) :
    c₁.deliver s t = c₂.deliver s t := by
  rw [← graft_self s s rfl, deliver_graft, deliver_graft]
  exact graft_proj s (deliver_agree A ht rfl hi).1

theorem tickLoop_eq (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T) (base : Int) (ks : List Nat)
    (hks : ∀ k ∈ ks, base + ↑k * HOUR + c₁.pol.delta ≤ T) {s : SState α} (hi : Inside c₁ T s) :
    c₁.tickLoop N base ks s = c₂.tickLoop N base ks s := by
  rw [← graft_self s s rfl, tickLoop_graft, tickLoop_graft]
  exact graft_proj s (tickLoop_agree N A base ks hks rfl hi).1

theorem start_graft (N : NumOps α) (c : Ctx α) : c.start N = (c.start N).map (c.state0 N).graft := by
  unfold Ctx.start
  rw [← graft_self (c.state0 N) _ rfl, deliver_graft]
  split
  · rfl
  generalize c.deliver _ _ = d
  cases d <;> rfl

theorem start_eq (N : NumOps α) {c₁ c₂ : Ctx α} {T : Int} (A : Agree c₁ c₂ T) (hT : c₁.pol.wStart + c₁.pol.delta ≤ T) :
    c₁.start N = c₂.start N := by
  have h0 : c₁.state0 N = c₂.state0 N := by simp [Ctx.state0, Ctx.coins, A.p, A.intervals]
  rw [start_graft N c₁, start_graft N c₂, h0]
  exact graft_proj _ (start_agree N A hT).1

/-- Two computations that are equal, the first satisfying Q. -/
def EqH {ε β : Type} (x₁ x₂ : Except ε β) (Q : β → Prop) : Prop := x₁ = x₂ ∧ Except.Holds x₁ Q

namespace EqH
variable {ε β γ : Type} {Q : β → Prop}

theorem pure (b : β) (h : Q b) : EqH (Except.pure b : Except ε β) (Except.pure b) Q := ⟨rfl, Except.Holds.pure b h⟩

theorem refl {x : Except ε β} (h : Except.Holds x Q) : EqH x x Q := ⟨rfl, h⟩

theorem bind {R : β → Prop} {x₁ x₂ : Except ε β} {f₁ f₂ : β → Except ε γ} {Q : γ → Prop} (hx : EqH x₁ x₂ R)
    (hf : ∀ b, R b → EqH (f₁ b) (f₂ b) Q) : EqH (x₁ >>= f₁) (x₂ >>= f₂) Q := by
  refine ⟨?_, Except.Holds.bind hx.2 fun b hb => (hf b hb).2⟩
  rw [← hx.1]
  cases h : x₁ with
  | error e => rfl
  | ok b => exact (hf b (hx.2 b h)).1

theorem ite {c : Prop} [Decidable c] {x₁ x₂ y₁ y₂ : Except ε β} (hx : c → EqH x₁ x₂ Q) (hy : ¬c → EqH y₁ y₂ Q) :
    EqH (if c then x₁ else y₁) (if c then x₂ else y₂) Q := by
  split
  · exact hx ‹_›
  · exact hy ‹_›

theorem forIn {σ : Type} (l : List β) (init : σ) (f₁ f₂ : β → σ → Except ε (ForInStep σ)) (I : σ → Prop)
    (h0 : I init) (hf : ∀ a ∈ l, ∀ s, I s → EqH (f₁ a s) (f₂ a s) (fun r => I r.value)) :
    EqH (ForIn.forIn l init f₁) (ForIn.forIn l init f₂) I := by
  induction l generalizing init with
  | nil => exact pure init h0
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a (by simp) init h0) fun r hr => ?_
    cases r with
    | done s => exact pure s hr
    | yield s => exact ih s hr fun a' ha' => hf a' (by simp [ha'])

theorem throw_bind {e : ε} {f₁ f₂ : β → Except ε γ} {Q : γ → Prop} :
    EqH ((throw e : Except ε β) >>= f₁) ((throw e : Except ε β) >>= f₂) Q :=
  ⟨rfl, fun _ h => by cases h⟩

theorem join {c : Prop} [Decidable c] {R : β → Prop} {x₁ x₂ : Except ε β} {b : β} {k₁ k₂ : β → Except ε γ}
    {Q : γ → Prop} (hx : c → EqH x₁ x₂ R) (hb : ¬c → R b) (hk : ∀ b, R b → EqH (k₁ b) (k₂ b) Q) :
    EqH (if c then x₁ >>= k₁ else k₁ b) (if c then x₂ >>= k₂ else k₂ b) Q :=
  ite (fun h => bind (hx h) hk) fun h => hk b (hb h)

end EqH

/-! The reads of a step, as the step's context names them. -/

theorem SameView.rateC (S : SameView m₁ m₂ T) (p : Program) (v : Venue α) (pol : Policy) (stop : Int) (c : Nat) {h : Int}
    (hh : h ≤ T) : (Ctx.make p m₁ v pol stop).ix.rateAt[(c, h)]? = (Ctx.make p m₂ v pol stop).ix.rateAt[(c, h)]? :=
  S.rate _ _ c hh

/-- A key opened by T is found in both markets or in neither, with the same fields fixed at the open. -/
theorem SameView.lookupC (S : SameView m₁ m₂ T) (p : Program) (v : Venue α) (pol : Policy) (stop : Int) (c : Nat) {t : Int}
    (ht : t ≤ T) :
    ((Ctx.make p m₁ v pol stop).ix.barAt[(c, t)]? = none ∧ (Ctx.make p m₂ v pol stop).ix.barAt[(c, t)]? = none) ∨
    ∃ i₁ i₂, (Ctx.make p m₁ v pol stop).ix.barAt[(c, t)]? = some i₁ ∧ (Ctx.make p m₂ v pol stop).ix.barAt[(c, t)]? = some i₂ ∧
      openFields (Ctx.make p m₁ v pol stop).m.bars[i₁]! = openFields (Ctx.make p m₂ v pol stop).m.bars[i₂]! := by
  have h := S.barAt_opened (c := c) ht
  rw [← lookup_barAt m₁ _ S.A₁, ← lookup_barAt m₂ _ S.A₂] at h
  show ((m₁.index m₁.intervals.size).barAt[(c, t)]? = none ∧ (m₂.index m₂.intervals.size).barAt[(c, t)]? = none) ∨
    ∃ i₁ i₂, (m₁.index m₁.intervals.size).barAt[(c, t)]? = some i₁ ∧ (m₂.index m₂.intervals.size).barAt[(c, t)]? = some i₂ ∧
      openFields m₁.bars[i₁]! = openFields m₂.bars[i₂]!
  cases h₁ : (m₁.index m₁.intervals.size).barAt[(c, t)]? <;> cases h₂ : (m₂.index m₂.intervals.size).barAt[(c, t)]? <;>
    rw [h₁, h₂] at h <;> simp at h
  · exact Or.inl ⟨rfl, rfl⟩
  · exact Or.inr ⟨_, _, rfl, rfl, h⟩

theorem step_view (N : NumOps α) (p : Program) (v : Venue α) (pol : Policy) (stop : Int) (S : SameView m₁ m₂ T)
    (A : Agree (Ctx.make p m₁ v pol stop) (Ctx.make p m₂ v pol stop) T) (b : Int) (hb : b + BAR + pol.delta ≤ T)
    (hδ : 0 ≤ pol.delta) (s : SState α) (hi : Inside (Ctx.make p m₁ v pol stop) T s) :
    (Ctx.make p m₁ v pol stop).step N s b = (Ctx.make p m₂ v pol stop).step N s b := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  refine (?_ : EqH _ _ (fun _ => True)).1
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.forIn _ _ _ _ _ rfl fun k hk s₀ h₀ => ?_) fun s₁ h₁ => ?_
  · refine EqH.bind (EqH.forIn _ _ _ _ (fun s' => s'.proj = s.proj) h₀ fun x _ s' h' => ?_) fun s'' h'' => EqH.pure _ h''
    have hh : b + ↑k * HOUR ≤ T := by
      simp [Std.Legacy.Range.size] at hk
      have : (k : Int) ≤ 4 := by omega
      simp only [BAR, HOUR] at hb ⊢; omega
    rw [S.rateC p v pol stop x.1 hh]
    rcases S.lookupC p v pol stop x.1 (t := b + ↑k * HOUR - (b + ↑k * HOUR) % BAR)
      (by have := Int.emod_nonneg (b + ↑k * HOUR) (by omega : BAR ≠ 0); omega) with ⟨h₁, h₂⟩ | ⟨i₁, i₂, h₁, h₂, ho⟩
    · rw [h₁, h₂]
      cases (Ctx.make p m₂ v pol stop).ix.rateAt[(x.1, b + ↑k * HOUR)]? <;> exact EqH.pure _ h'
    · rw [h₁, h₂]
      simp only [openFields, Prod.mk.injEq] at ho
      cases (Ctx.make p m₂ v pol stop).ix.rateAt[(x.1, b + ↑k * HOUR)]?
      · exact EqH.pure _ h'
      · dsimp only
        rw [ho.2.2.1]
        exact EqH.pure _ h'
  rw [marks_loop, marks_loop]
  simp only [← latestOf.eq_1]
  have hl : (fun x => latestOf (Ctx.make p m₁ v pol stop).ix (Ctx.make p m₁ v pol stop).m.bars b x) =
      (fun x => latestOf (Ctx.make p m₂ v pol stop).ix (Ctx.make p m₂ v pol stop).m.bars b x) :=
    funext fun x => S.latest (b := b) (by omega) x
  rw [hl]
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.refl (Except.Holds.ok _ h₁)) fun s₂ h₂ => ?_
  have hint : (Ctx.make p m₁ v pol stop).m.intervals = (Ctx.make p m₂ v pol stop).m.intervals := S.intervals
  have hcoins : (Ctx.make p m₁ v pol stop).coins = (Ctx.make p m₂ v pol stop).coins := congrArg Array.size S.intervals
  have hex : ∀ s' (f : Fill α), f.filled = b + BAR →
      (Ctx.make p m₁ v pol stop).execute N s' f = (Ctx.make p m₂ v pol stop).execute N s' f :=
    fun s' f hf => S.execute N p v pol stop s' f (by omega)
  have hfilled : ∀ coin (q ref : α) why t src, ((Ctx.make p m₁ v pol stop).closeout N coin q ref why t src).filled = t :=
    fun _ _ _ _ _ _ => rfl
  simp only [hint, hcoins, hex _ _ (hfilled ..)]
  have hexec : ∀ s' f r, (Ctx.make p m₂ v pol stop).execute N s' f = .ok r → r.proj = s'.proj :=
    fun s' f => execute_proj N _ s' f
  refine EqH.join (R := fun s' => s'.proj = s.proj) (fun _ => EqH.forIn _ _ _ _ _ h₂ fun x _ s' h' => ?_) (fun _ => h₂)
    fun s₃ h₃ => ?_
  · exact EqH.bind (R := fun r => r.proj = s.proj) (EqH.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr =>
      EqH.pure _ hr
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.forIn _ _ _ _ _ h₃ fun x _ s' h' => ?_) fun s₄ h₄ => ?_
  · exact EqH.ite (fun _ => EqH.bind (R := fun r => r.proj = s.proj) (EqH.refl fun r hr => (hexec _ _ r hr).trans h')
      fun r hr => EqH.pure _ hr) fun _ => EqH.pure _ h'
  have hbk : ∀ s' adv lat, (Ctx.make p m₁ v pol stop).bankrupt N s' b adv lat =
      (Ctx.make p m₂ v pol stop).bankrupt N s' b adv lat := by
    intro s' adv lat; unfold Ctx.bankrupt; simp only [hex _ _ (hfilled ..)]; rfl
  refine EqH.bind (R := fun s' => s'.proj = s.proj) ?_ fun s₅ h₅ => ?_
  · rw [hbk]; exact EqH.refl (bankrupt_proj N _ s₄ b _ _ _ h₄)
  refine EqH.ite (fun _ => EqH.throw_bind) fun _ => ?_
  refine EqH.ite (fun _ => EqH.throw_bind) fun _ => ?_
  refine EqH.join (R := fun s' => s'.proj = s.proj) (fun _ => EqH.forIn _ _ _ _ _ h₅ fun o _ s' h' => ?_) (fun _ => h₅)
    fun s₆ h₆ => ?_
  · rcases S.lookupC p v pol stop o.coin (t := b + BAR) (by omega) with ⟨e₁, e₂⟩ | ⟨i₁, i₂, e₁, e₂, ho⟩
    · rw [e₁, e₂]; exact EqH.pure _ h'
    · rw [e₁, e₂]
      dsimp only
      simp only [openFields, Prod.mk.injEq] at ho
      rw [ho.2.2.2, ho.2.2.1, hex s' _ rfl]
      exact EqH.ite (fun _ => EqH.bind (R := fun r => r.proj = s.proj)
        (EqH.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr => EqH.pure _ hr) fun _ => EqH.pure _ h'
  have hin : Inside (Ctx.make p m₁ v pol stop) T s₆ := by
    obtain ⟨-, hf, hb', he⟩ := proj_eq h₆
    unfold Inside; rw [hf, hb', he]; exact hi
  have hks : ∀ k ∈ List.range' 1 4, b + ↑k * HOUR + (Ctx.make p m₁ v pol stop).pol.delta ≤ T := by
    intro k hk
    simp only [List.mem_range'_1] at hk
    have : (k : Int) ≤ 4 := by omega
    show b + ↑k * HOUR + pol.delta ≤ T
    simp only [BAR, HOUR] at hb ⊢; omega
  refine EqH.bind (R := fun _ => True) ⟨tickLoop_eq N A b (List.range' 1 4) hks hin, fun _ _ => trivial⟩ fun r _ => ?_
  have hp : (Ctx.make p m₁ v pol stop).p = (Ctx.make p m₂ v pol stop).p := rfl
  have hv : (Ctx.make p m₁ v pol stop).v = (Ctx.make p m₂ v pol stop).v := rfl
  have hpol : (Ctx.make p m₁ v pol stop).pol = (Ctx.make p m₂ v pol stop).pol := rfl
  simp only [hp, hv, hpol]
  exact EqH.refl fun _ _ => trivial

/-- Markets that agree on the delivery prefix and the execution view by T run every step whose decision is by T
alike. -/
theorem steps_view (N : NumOps α) (p : Program) (v : Venue α) (pol : Policy) (stop : Int) (S : SameView m₁ m₂ T)
    (A : Agree (Ctx.make p m₁ v pol stop) (Ctx.make p m₂ v pol stop) T) (hδ : 0 ≤ pol.delta) (j : Nat)
    (hj : pol.wStart + ↑j * BAR + pol.delta ≤ T) :
    (Ctx.make p m₁ v pol stop).steps N j = (Ctx.make p m₂ v pol stop).steps N j := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  refine (?_ : EqH _ _ (fun _ => True)).1
  unfold Ctx.steps
  have h0 : (Ctx.make p m₁ v pol stop).pol.wStart + (Ctx.make p m₁ v pol stop).pol.delta ≤ T := by
    show pol.wStart + pol.delta ≤ T
    have := Int.mul_nonneg (Int.natCast_nonneg j) (Int.le_of_lt hBAR); omega
  refine EqH.bind ⟨start_eq N A h0, (start_agree N A h0).2⟩ fun s₀ h₀ => ?_
  have hbd : (Ctx.make p m₂ v pol stop).bounds = (Ctx.make p m₁ v pol stop).bounds := rfl
  rw [hbd]
  refine EqH.bind (EqH.forIn _ _ _ _ (Inside (Ctx.make p m₁ v pol stop) T) h₀ fun b hb s hs => ?_) fun r _ =>
    EqH.refl fun _ _ => trivial
  obtain ⟨i, hi, rfl⟩ : ∃ i < j, (Ctx.make p m₁ v pol stop).pol.wStart + ↑i * BAR = b := by
    obtain ⟨i, hi, hb⟩ := List.mem_take_iff_getElem.mp hb
    refine ⟨i, by omega, ?_⟩
    rw [← hb, List.getElem_of_eq (bounds_eq (Ctx.make p m₁ v pol stop))]
    simp
  have hib : pol.wStart + ↑i * BAR + BAR + pol.delta ≤ T := by
    have : (i : Int) + 1 ≤ j := by omega
    have := Int.mul_le_mul_of_nonneg_right this (Int.le_of_lt hBAR)
    rw [Int.add_mul, Int.one_mul] at this; omega
  have hstep : Except.Holds ((Ctx.make p m₁ v pol stop).step N s (pol.wStart + ↑i * BAR)) (Inside (Ctx.make p m₁ v pol stop) T) := by
    intro r hr
    obtain ⟨q, hq, hpq⟩ := step_proj N _ s _ r hr
    have hks : ∀ k ∈ List.range' 1 4, pol.wStart + ↑i * BAR + ↑k * HOUR + (Ctx.make p m₁ v pol stop).pol.delta ≤ T := by
      intro k hk
      simp only [List.mem_range'_1] at hk
      have : (k : Int) ≤ 4 := by omega
      show pol.wStart + ↑i * BAR + ↑k * HOUR + pol.delta ≤ T
      simp only [BAR, HOUR] at hib ⊢; omega
    have := (tickLoop_agree N A _ (List.range' 1 4) hks rfl hs).2 q hq
    obtain ⟨-, hf, hb', he⟩ := proj_eq hpq
    unfold Inside at this ⊢; rw [hf, hb', he]; exact this
  exact EqH.bind ⟨step_view N p v pol stop S A _ hib hδ s hs, hstep⟩ fun r hr => EqH.pure _ hr

end Ref
