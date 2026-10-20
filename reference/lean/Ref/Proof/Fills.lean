import Ref.Proof.Index
import Ref.Proof.Prefix

/-! L4's fill law, established fill by fill: what the step's construction and the fill check give for
closeouts and ordinary fills, and the bookkeeping that carries them through a run. -/

namespace Ref
variable {α : Type} [Inhabited α]

/-! ## Positions -/

omit [Inhabited α] in
theorem assoc?_some {β : Type} {l : List (Nat × β)} {k : Nat} {v : β} (h : assoc? l k = some v) : (k, v) ∈ l := by
  unfold assoc? at h
  cases hf : l.find? (·.1 == k) with
  | none => rw [hf] at h; cases h
  | some x =>
    rw [hf] at h; cases h
    have := List.mem_of_find?_eq_some hf
    have hk := List.find?_some hf
    simp at hk; rw [← hk]; exact this

omit [Inhabited α] in
theorem mem_assocSet {β : Type} {l : List (Nat × β)} {k : Nat} {v : β} {x : Nat × β} (h : x ∈ assocSet l k v) :
    x ∈ l ∨ x.1 = k := by
  unfold assocSet at h
  rw [(List.mergeSort_perm _ _).mem_iff] at h
  simp only [List.mem_append, List.mem_filter, List.mem_singleton] at h
  rcases h with ⟨h, -⟩ | rfl
  · exact Or.inl h
  · exact Or.inr rfl

omit [Inhabited α] in
theorem mem_assocDel {β : Type} {l : List (Nat × β)} {k : Nat} {x : Nat × β} (h : x ∈ assocDel l k) : x ∈ l := by
  unfold assocDel at h; exact (List.mem_filter.mp h).1

/-- A fill on coin c leaves positions only in c or in coins held before. -/
theorem fill_pos (N : NumOps α) (b : Book α) (c : Nat) (q pr fee : α) (x : Nat × α) (h : x ∈ (b.fill N c q pr fee).pos) :
    (∃ y, (x.1, y) ∈ b.pos) ∨ x.1 = c := by
  unfold Book.fill at h
  simp only at h
  split at h
  · exact Or.inl ⟨x.2, mem_assocDel h⟩
  · rcases mem_assocSet h with h | h
    · exact Or.inl ⟨x.2, h⟩
    · exact Or.inr h

omit [Inhabited α] in
theorem settle_pos (N : NumOps α) (b : Book α) (c : Nat) (pr r : α) : (b.settle N c pr r).1.pos = b.pos := rfl

/-! ## The law for one fill -/

/-- L4_fills' clause for one fill (PROGRESS.md, Stage 6, with its revisions), verbatim. -/
def FillLaw (N : NumOps α) (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) (f : Fill α) : Prop :=
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
          ∃ q, f.qty = N.neg q ∧ f.reference = (if f.why = .delisting then bar.c else if N.lt N.zero q then bar.l else bar.h))

/-- A closeout that passed the check, priced from the coin's bar found under its source time, keeps the law. -/
theorem closeout_law (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (coin : Nat) (q ref : α) (why : Why) (hwhy : why ≠ .fill) (t src : Int)
    (hchk : checkFill N ((Ctx.make p m v pol stop).closeout N coin (N.neg q) ref why t src) m
      (m.index m.intervals.size) v = .ok ())
    (bar0 : BarRow α) (i : Nat) (hi : i < m.bars.size) (hb : (m.index m.intervals.size).barAt[(coin, src)]? = some i)
    (hbar : m.bars[i] = bar0)
    (href : ref = if why = .delisting then bar0.c else if N.lt N.zero q then bar0.l else bar0.h) :
    FillLaw N p m v pol stop ((Ctx.make p m v pol stop).closeout N coin (N.neg q) ref why t src) := by
  obtain ⟨⟨h1, h2, h3⟩, hq, -⟩ := checkFill_ok N _ m _ v hchk
  obtain ⟨i', hi', hb', hlat, hso⟩ := closeout_latest N _ m hA v hchk hwhy
  simp only [Ctx.closeout] at hb' hlat hso hq h1 h2 h3 ⊢
  rw [hb] at hb'; cases hb'
  rw [hbar] at hlat hso
  refine ⟨hq, h1, h2, h3, rfl, rfl, fun h => absurd h hwhy, fun _ => ⟨rfl, rfl, rfl, bar0, hlat, hso, q, rfl, href⟩⟩

/-- The step's ordinary fill of order o, due at boundary b, at reference ref. -/
def ordFill (N : NumOps α) (v : Venue α) (o : Order α) (b : Int) (ref : α) : Fill α where
  why := .fill
  coin := o.coin
  qty := o.qty
  inputsKnown := o.inputsKnown
  decisionPrice := o.price
  decided := o.decided
  submitted := o.decided
  filled := b + BAR
  sourceOpen := b + BAR
  reference := ref
  price := fillPrice N v o.coin o.qty ref
  fee := N.mul (N.mul (N.abs o.qty) (fillPrice N v o.coin o.qty ref)) v.takerFee

/-- An ordinary fill of a due order at its scheduled, traded bar keeps the law, given what the order recorded at
its decision. -/
theorem ordinary_law (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (o : Order α) (b : Int) (i : Nat)
    (hbi : (m.index m.intervals.size).barAt[(o.coin, b + BAR)]? = some i) (htr : m.bars[i]!.trades ≥ 1)
    (hchk : checkFill N (ordFill N v o b m.bars[i]!.o) m (m.index m.intervals.size) v = .ok ())
    (hdec : o.decided = b + pol.delta)
    (hmach : ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = o.decided ∧
      (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = o.inputsKnown) :
    FillLaw N p m v pol stop (ordFill N v o b m.bars[i]!.o) := by
  obtain ⟨⟨h1, h2, h3⟩, hq, -⟩ := checkFill_ok N _ m _ v hchk
  obtain ⟨hi, hspec⟩ := barAt_spec m _ hA hbi
  obtain ⟨hi', -, hot⟩ := barAt_sound m _ hbi
  rw [getElem!_pos m.bars i hi] at htr ⊢
  simp only [ordFill] at h1 h2 h3 hq ⊢
  exact ⟨hq, h1, h2, h3, rfl, rfl, fun _ => ⟨rfl, by simp only; omega, ⟨m.bars[i], hspec, htr, hot.symm, rfl⟩, hmach⟩,
    fun h => absurd rfl h⟩

/-! ## The step's latest bars -/

theorem partitionPoint_pos (xs : Array Int) (q : Int → Bool) (h0 : 0 < xs.size) (hq : q xs[0] = true) :
    1 ≤ partitionPoint xs q ∧ partitionPoint xs q ≤ xs.size := by
  unfold partitionPoint
  cases hf : xs.findIdx? (fun t => !q t) with
  | none => simp; omega
  | some k =>
    obtain ⟨hk, hnk, -⟩ := Array.findIdx?_eq_some_iff_getElem.mp hf
    simp only [Option.getD_some]
    refine ⟨?_, by omega⟩
    rcases Nat.eq_zero_or_pos k with rfl | hpos
    · simp [hq] at hnk
    · exact hpos

/-- The step's lookup of a held coin's latest bar opened by b. -/
def latestOf (ix : Index α) (bars : Array (BarRow α)) (b : Int) (x : Nat × α) : Option (Nat × BarRow α) :=
  if (partitionPoint ix.barTimes[x.1]! (fun t => decide (t ≤ b)) == 0) = true then none
  else some (x.1, bars[ix.barAt[(x.1, ix.barTimes[x.1]![(partitionPoint ix.barTimes[x.1]! fun t => decide (t ≤ b)) - 1]!)]!]!)

/-- A coin with a bar opened by b has a latest bar, found by the index under its own openTime. -/
theorem latestOf_some (m : Market α) (hA : m.Admissible) (b : Int) (x : Nat × α)
    (hx : ∃ bar ∈ m.bars.toList, bar.coin = x.1 ∧ bar.openTime ≤ b) :
    ∃ bar' i, ∃ hi : i < m.bars.size, latestOf (m.index m.intervals.size) m.bars b x = some (x.1, bar') ∧
      m.bars[i] = bar' ∧ (m.index m.intervals.size).barAt[(x.1, bar'.openTime)]? = some i := by
  obtain ⟨bar, hbar, hbc, hbo⟩ := hx
  have hcoins : x.1 < m.intervals.size := hbc ▸ hA.barCoin bar hbar
  have hiff := times_mem m _ _ hcoins
  have hsorted := times_sorted m _ _ hcoins
  unfold latestOf
  generalize (m.index m.intervals.size).barTimes[x.1]! = times at hiff hsorted ⊢
  have hmem : bar.openTime ∈ times.toList := (hiff _).mpr ⟨bar, hbar, hbc, rfl⟩
  have hsz : 0 < times.size := by
    have := List.length_pos_of_mem hmem; simpa using this
  have h0 : times[0] ≤ bar.openTime := by
    obtain ⟨k, hk, hke⟩ := List.getElem_of_mem hmem
    rcases Nat.eq_zero_or_pos k with rfl | hkpos
    · simp at hke; omega
    · have := List.pairwise_iff_getElem.mp hsorted 0 k (by simpa using hsz) hk hkpos
      simp at this hke; omega
  obtain ⟨hk1, hk2⟩ := partitionPoint_pos times (fun t => decide (t ≤ b)) hsz (by simp; omega)
  generalize partitionPoint times (fun t => decide (t ≤ b)) = k at hk1 hk2 ⊢
  have hk : k - 1 < times.size := by omega
  obtain ⟨y, hy, hyc, hyo⟩ := (hiff _).mp (Array.getElem_mem_toList hk)
  obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem hy
  have hj' : j < m.bars.size := by simpa using hj
  have hix := barAt_complete m m.intervals.size hA hj'
  simp only [Array.getElem_toList] at hyc hyo
  rw [hyc, hyo] at hix
  refine ⟨m.bars[j], j, hj', ?_, rfl, by rw [hyo]; exact hix⟩
  have hix' : (m.index m.intervals.size).barAt[(x.1, times[k - 1])]! = j := by
    rw [getElem!_def, hix]
  rw [if_neg (by simp; omega), getElem!_pos times (k - 1) hk, hix', getElem!_pos m.bars j hj']

theorem latestOf_fst (ix : Index α) (bars : Array (BarRow α)) (b : Int) {x y : Nat × α} (h : x.1 = y.1) :
    latestOf ix bars b x = latestOf ix bars b y := by
  unfold latestOf; rw [h]

theorem latestOf_key (ix : Index α) (bars : Array (BarRow α)) (b : Int) (x : Nat × α) {y : Nat × BarRow α}
    (h : latestOf ix bars b x = some y) : y.1 = x.1 := by
  unfold latestOf at h; split at h <;> simp at h; rw [← h]

/-- Looking up a held coin in the step's latest bars gives that coin's latest bar. -/
theorem assoc_latest (ix : Index α) (bars : Array (BarRow α)) (b : Int) (c : Nat) (bar' : BarRow α) :
    ∀ (l : List (Nat × α)), (∃ q, (c, q) ∈ l) → (∀ q, latestOf ix bars b (c, q) = some (c, bar')) →
      assoc? (l.filterMap (latestOf ix bars b)) c = some bar'
  | [], ⟨_, h⟩, _ => by simp at h
  | x :: l, ⟨q, hq⟩, hc => by
    by_cases hx : x.1 = c
    · have : latestOf ix bars b x = some (c, bar') := by
        rw [latestOf_fst ix bars b (y := (c, x.2)) hx]; exact hc x.2
      simp [List.filterMap_cons, this, assoc?]
    · have hq' : (c, q) ∈ l := by
        simp only [List.mem_cons] at hq; rcases hq with rfl | hq
        · exact absurd rfl hx
        · exact hq
      have ih := assoc_latest ix bars b c bar' l ⟨q, hq'⟩ hc
      cases hf : latestOf ix bars b x with
      | none => simpa [List.filterMap_cons, hf] using ih
      | some y =>
        have hy := latestOf_key ix bars b x hf
        have hb : (y.fst == c) = false := by simp [hy, hx]
        simp only [List.filterMap_cons, hf, assoc?, List.find?_cons, hb] at ih ⊢
        exact ih

theorem fold_set (l : List (Nat × BarRow α)) (i : Nat) (v : α) (hv : ∀ z ∈ l, z.1 = i → z.2.c = v) :
    ∀ (mk : Array α), i < mk.size → ((∃ z ∈ l, z.1 = i) ∨ mk[i]! = v) →
      (l.foldl (fun mk y => mk.set! y.1 y.2.c) mk)[i]! = v := by
  induction l with
  | nil => intro mk _ h; simpa using h
  | cons y l ih =>
    intro mk hi h
    simp only [List.foldl_cons]
    apply ih (fun z hz => hv z (by simp [hz])) _ (by simpa using hi)
    by_cases hy : y.1 = i
    · right; subst hy
      rw [Array.set!_eq_setIfInBounds, getElem!_pos _ y.1 (by simpa using hi)]; simp [hv y (by simp) rfl]
    · rcases h with ⟨z, hz, hzi⟩ | h
      · simp only [List.mem_cons] at hz; rcases hz with rfl | hz
        · exact absurd hzi hy
        · exact Or.inl ⟨z, hz, hzi⟩
      · right
        rw [Array.set!_eq_setIfInBounds, getElem!_pos _ i (by simpa using hi), Array.getElem_setIfInBounds hi,
          if_neg hy, ← getElem!_pos mk i hi, h]

/-- After the marks loop, a listed coin's mark is its latest bar's close. -/
theorem marks_set (ix : Index α) (bars : Array (BarRow α)) (b : Int) (held : List (Nat × α)) (mk : Array α)
    (c : Nat) (bar' : BarRow α) (hin : (c, bar') ∈ held.filterMap (latestOf ix bars b)) (hc : c < mk.size) :
    ((held.filterMap (latestOf ix bars b)).foldl (fun mk y => mk.set! y.1 y.2.c) mk)[c]! = bar'.c := by
  apply fold_set _ c bar'.c _ mk hc (Or.inl ⟨_, hin, rfl⟩)
  intro z hz hzc
  obtain ⟨x, -, hx⟩ := List.mem_filterMap.mp hz
  obtain ⟨x', -, hx'⟩ := List.mem_filterMap.mp hin
  have h1 := latestOf_key ix bars b x hx
  have h2 := latestOf_key ix bars b x' hx'
  rw [latestOf_fst ix bars b (y := x') (by simp at h2; rw [← h1, hzc, h2])] at hx
  rw [hx'] at hx; cases hx; rfl

end Ref
