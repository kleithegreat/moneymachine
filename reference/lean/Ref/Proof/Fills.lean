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

/-- L4_fills' clause for one fill (audit/criteria.md, stage 6, with its revisions), verbatim. -/
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

/-- A held coin with a bar opened by b: its latest bar, found by the index, and its mark after the marks loop. -/
theorem held_latest (m : Market α) (hA : m.Admissible) (b : Int) (held : List (Nat × α)) (mk : Array α)
    (hmk : mk.size = m.intervals.size)
    (hpos : ∀ x ∈ held, ∃ bar ∈ m.bars.toList, bar.coin = x.1 ∧ bar.openTime ≤ b) (x : Nat × α) (hx : x ∈ held) :
    ∃ bar' i, ∃ hi : i < m.bars.size,
      assoc? (held.filterMap (latestOf (m.index m.intervals.size) m.bars b)) x.1 = some bar' ∧ m.bars[i] = bar' ∧
      (m.index m.intervals.size).barAt[(x.1, bar'.openTime)]? = some i ∧
      ((held.filterMap (latestOf (m.index m.intervals.size) m.bars b)).foldl (fun mk y => mk.set! y.1 y.2.c) mk)[x.1]! =
        bar'.c := by
  obtain ⟨bar', i, hi, hlat, hbi, hix⟩ := latestOf_some m hA b x (hpos x hx)
  refine ⟨bar', i, hi, assoc_latest _ _ b x.1 bar' held ⟨x.2, by simpa using hx⟩
    (fun q => by rw [latestOf_fst _ _ b (x := (x.1, q)) (y := x) rfl]; exact hlat), hbi, hix, ?_⟩
  obtain ⟨bar, hbar, hbc, -⟩ := hpos x hx
  exact marks_set _ _ b held mk x.1 bar' (List.mem_filterMap.mpr ⟨x, hx, hlat⟩)
    (by rw [hmk, ← hbc]; exact hA.barCoin bar hbar)

/-! ## The invariant across steps -/

/-- What holds before the step at boundary wStart + j·BAR. -/
structure Inv4 (N : NumOps α) (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) (j : Nat)
    (s : SState α) : Prop where
  fills : ∀ f, Event.fill f ∈ s.trace.toList → FillLaw N p m v pol stop f
  orders : ∀ e ∈ s.orders, e.1 = pol.wStart + ↑j * BAR + BAR ∧ e.2.decided = pol.wStart + ↑j * BAR + pol.delta ∧
    ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = e.2.decided ∧
      (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = e.2.inputsKnown
  pos : ∀ x ∈ s.book.pos, ∃ bar ∈ m.bars.toList, bar.coin = x.1 ∧ bar.openTime ≤ pol.wStart + ↑j * BAR
  marks : s.marks.size = m.intervals.size
  proj : ∃ t, ((Ctx.make p m v pol stop).start N >>=
    (Ctx.make p m v pol stop).tickLoop N pol.wStart (List.range' 1 (4 * j))) = .ok t ∧ t.proj = s.proj

omit [Inhabited α] in
theorem fill_mem_push {t : Array (Event α)} {e : Event α} {f : Fill α} (h : Event.fill f ∈ (t.push e).toList) :
    Event.fill f ∈ t.toList ∨ e = Event.fill f := by
  simp only [Array.toList_push, List.mem_append, List.mem_singleton] at h
  rcases h with h | h
  · exact Or.inl h
  · exact Or.inr h.symm

/-- A state with no new fills, the same orders, positions and marks, and the same machine and cursors keeps the
invariant. -/
theorem Inv4.frame {N : NumOps α} {p : Program} {m : Market α} {v : Venue α} {pol : Policy} {stop : Int} {j : Nat}
    {s s' : SState α} (h : Inv4 N p m v pol stop j s)
    (htr : ∀ f, Event.fill f ∈ s'.trace.toList → Event.fill f ∈ s.trace.toList ∨ FillLaw N p m v pol stop f)
    (ho : s'.orders = s.orders) (hp : s'.book.pos = s.book.pos) (hm : s'.marks.size = s.marks.size)
    (hpr : s'.proj = s.proj) : Inv4 N p m v pol stop j s' where
  fills f hf := (htr f hf).elim (h.fills f) id
  orders := ho ▸ h.orders
  pos := hp ▸ h.pos
  marks := hm ▸ h.marks
  proj := hpr ▸ h.proj

theorem execute_spec (N : NumOps α) (c : Ctx α) (s r : SState α) (f : Fill α) (h : c.execute N s f = .ok r) :
    checkFill N f c.m c.ix c.v = .ok () ∧ r.trace = s.trace.push (.fill f) ∧ r.orders = s.orders ∧
      r.marks = s.marks ∧ r.proj = s.proj ∧ r.book.pos = (s.book.fill N f.coin f.qty f.price f.fee).pos := by
  unfold Ctx.execute at h
  cases hc : checkFill N f c.m c.ix c.v with
  | error e => rw [hc] at h; cases h
  | ok u => rw [hc] at h; cases h; exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

omit [Inhabited α] in
theorem holds_throw_bind {ε β γ : Type} {e : ε} {f : β → Except ε γ} {Q : γ → Prop} :
    Except.Holds ((throw e : Except ε β) >>= f) Q := by
  intro r h; cases h

omit [Inhabited α] in
theorem size_fold_set (l : List (Nat × BarRow α)) (mk : Array α) :
    (l.foldl (fun mk y => mk.set! y.1 y.2.c) mk).size = mk.size := by
  induction l generalizing mk with
  | nil => rfl
  | cons y l ih => rw [List.foldl_cons, ih, Array.set!_eq_setIfInBounds, Array.size_setIfInBounds]

/-- A step's ticks from a state with s's machine and cursors: the state's own fields with the ticked machine. -/
theorem tickLoop_bind_graft {γ : Type} {Q : γ → Prop} (N : NumOps α) (c : Ctx α) (b : Int) (ks : List Nat)
    (s s₃ : SState α) (g : SState α → Except Abort γ) (h : s₃.proj = s.proj)
    (hg : ∀ r, c.tickLoop N b ks s = .ok r → Except.Holds (g (s₃.graft r)) Q) :
    Except.Holds (c.tickLoop N b ks s₃ >>= g) Q := by
  rw [← graft_self s₃ s h, tickLoop_graft]
  cases ht : c.tickLoop N b ks s with
  | error e => intro x hx; simp [Except.map, bind, Except.bind] at hx
  | ok r => exact hg r ht

omit [Inhabited α] in
theorem marks_loop (l : List (Nat × BarRow α)) (s : SState α) :
    forIn l s (fun x s => (pure (ForInStep.yield { s with marks := s.marks.set! x.1 x.2.c }) :
      Except Abort (ForInStep (SState α)))) = .ok { s with marks := l.foldl (fun mk y => mk.set! y.1 y.2.c) s.marks } := by
  induction l generalizing s with
  | nil => rfl
  | cons x l ih => rw [List.forIn_cons, List.foldl_cons]; exact ih _

theorem step_inv4 (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (j : Nat) (s : SState α) (h : Inv4 N p m v pol stop j s) :
    Except.Holds ((Ctx.make p m v pol stop).step N s (pol.wStart + ↑j * BAR)) (Inv4 N p m v pol stop (j + 1)) := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  refine Except.Holds.bind (R := fun s₁ => Inv4 N p m v pol stop j s₁ ∧ s₁.marks = s.marks)
    (Except.Holds.forIn_list _ _ _ _ ⟨h, rfl⟩ fun k _ s₀ ⟨h₀, hm₀⟩ => ?_) fun s₁ ⟨h₁, hm₁⟩ => ?_
  · refine Except.Holds.bind (Except.Holds.forIn_list _ _ _ (fun s' => Inv4 N p m v pol stop j s' ∧ s'.marks = s.marks)
      ⟨h₀, hm₀⟩ fun x _ s' ⟨h', hm'⟩ => ?_) fun s'' h'' => Except.Holds.pure _ h''
    split
    · refine Except.Holds.pure _ ⟨h'.frame (fun f hf => ?_) rfl rfl rfl rfl, hm'⟩
      rcases fill_mem_push hf with hf | hf
      · exact Or.inl hf
      · cases hf
    · exact Except.Holds.throw' _
  rw [marks_loop]
  refine Except.Holds.bind (Except.Holds.ok _ rfl) fun s₂ hs₂ => ?_
  subst hs₂
  simp only [← latestOf.eq_1]
  have HL : ∀ x ∈ s₁.book.pos, ∃ bar' i, ∃ hi : i < m.bars.size,
      assoc? (List.filterMap (fun x => latestOf (Ctx.make p m v pol stop).ix (Ctx.make p m v pol stop).m.bars
        (pol.wStart + ↑j * BAR) x) s₁.book.pos) x.1 = some bar' ∧ m.bars[i] = bar' ∧
      (m.index m.intervals.size).barAt[(x.1, bar'.openTime)]? = some i ∧
      (List.foldl (fun mk y => mk.set! y.fst y.snd.c) s₁.marks (List.filterMap (fun x => latestOf
        (Ctx.make p m v pol stop).ix (Ctx.make p m v pol stop).m.bars (pol.wStart + ↑j * BAR) x) s₁.book.pos))[x.1]! =
        bar'.c :=
    held_latest m hA _ s₁.book.pos s₁.marks h₁.marks h₁.pos
  have hmk₂ := size_fold_set (List.filterMap (fun x => latestOf (Ctx.make p m v pol stop).ix
    (Ctx.make p m v pol stop).m.bars (pol.wStart + ↑j * BAR) x) s₁.book.pos) s₁.marks
  rw [h₁.marks] at hmk₂
  generalize List.filterMap (fun x => latestOf (Ctx.make p m v pol stop).ix (Ctx.make p m v pol stop).m.bars
    (pol.wStart + ↑j * BAR) x) s₁.book.pos = L at HL hmk₂ ⊢
  generalize List.foldl (fun mk y => mk.set! y.fst y.snd.c) s₁.marks L = mk₂ at HL hmk₂ ⊢
  let J : SState α → Prop := fun s' =>
    (∀ f, Event.fill f ∈ s'.trace.toList → Event.fill f ∈ s₁.trace.toList ∨ FillLaw N p m v pol stop f) ∧
    s'.orders = s₁.orders ∧ s'.marks = mk₂ ∧ s'.proj = s₁.proj ∧ ∀ y ∈ s'.book.pos, ∃ q, (y.1, q) ∈ s₁.book.pos
  have J_exec : ∀ s' r (f : Fill α), J s' → (Ctx.make p m v pol stop).execute N s' f = .ok r →
      FillLaw N p m v pol stop f → (∃ q, (f.coin, q) ∈ s₁.book.pos) → J r := by
    intro s' r f hJ hr hlaw hc
    obtain ⟨-, htr, ho, hmk, hpr, hpos⟩ := execute_spec N _ s' r f hr
    refine ⟨fun g hg => ?_, ho.trans hJ.2.1, hmk.trans hJ.2.2.1, hpr.trans hJ.2.2.2.1, fun y hy => ?_⟩
    · rw [htr] at hg
      rcases fill_mem_push hg with hg | hg
      · exact hJ.1 g hg
      · cases hg; exact Or.inr hlaw
    · rw [hpos] at hy
      rcases fill_pos N _ _ _ _ _ _ hy with ⟨q, hq⟩ | hq
      · exact hJ.2.2.2.2 (y.1, q) hq
      · rw [hq]; exact hc
  have hJ₂ : J { s₁ with marks := mk₂ } := ⟨fun f hf => Or.inl hf, rfl, rfl, rfl, fun y hy => ⟨y.2, hy⟩⟩
  refine Except.Holds.join (R := J) (fun _ => Except.Holds.forIn_list _ _ _ J hJ₂ fun x hx s' hJ => ?_) (fun _ => hJ₂)
    fun s₃ hJ₃ => ?_
  · refine Except.Holds.bind (R := J) (fun r hr => ?_) fun r hr => Except.Holds.pure _ hr
    obtain ⟨bar', i, hi, has, hbi, hix, -⟩ := HL x hx
    rw [has] at hr
    have hchk := (execute_spec N _ s' r _ hr).1
    refine J_exec s' r _ hJ hr (closeout_law N p m hA v pol stop x.1 x.2 _ .liquidation (by decide) _ _ hchk bar' i hi
      (by simpa using hix) hbi (by simp)) ⟨x.2, by simp only [Ctx.closeout]; exact hx⟩
  refine Except.Holds.bind (R := J) (Except.Holds.forIn_list _ _ _ J hJ₃ fun x hx s' hJ => ?_) fun s₄ hJ₄ => ?_
  · refine Except.Holds.ite ?_ (Except.Holds.pure _ hJ)
    refine Except.Holds.bind (R := J) (fun r hr => ?_) fun r hr => Except.Holds.pure _ hr
    obtain ⟨q, hq⟩ := hJ₃.2.2.2.2 x hx
    obtain ⟨bar', i, hi, has, hbi, hix, hmk⟩ := HL (x.1, q) hq
    rw [has, hJ.2.2.1, hmk] at hr
    have hchk := (execute_spec N _ s' r _ hr).1
    exact J_exec s' r _ hJ hr (closeout_law N p m hA v pol stop x.1 x.2 _ .delisting (by decide) _ _ hchk bar' i hi
      (by simpa using hix) hbi (by simp)) ⟨q, by simp only [Ctx.closeout]; exact hq⟩
  refine Except.Holds.bind (R := J) ?_ fun s₄ hJ₄ => ?_
  · unfold Ctx.bankrupt
    refine Except.Holds.ite (Except.Holds.pure _ hJ₄) ?_
    refine Except.Holds.bind (R := J) (Except.Holds.forIn_list _ _ _ J hJ₄ fun x hx s' hJ => ?_)
      fun s' hJ' => Except.Holds.pure _ ⟨hJ'.1, hJ'.2.1, hJ'.2.2.1, hJ'.2.2.2.1, hJ'.2.2.2.2⟩
    refine Except.Holds.bind (R := J) (fun r hr => ?_) fun r hr => Except.Holds.pure _ hr
    obtain ⟨q, hq⟩ := hJ₄.2.2.2.2 x hx
    obtain ⟨bar', i, hi, has, hbi, hix, -⟩ := HL (x.1, q) hq
    rw [has] at hr
    have hchk := (execute_spec N _ s' r _ hr).1
    exact J_exec s' r _ hJ hr (closeout_law N p m hA v pol stop x.1 x.2 _ .liquidation (by decide) _ _ hchk bar' i hi
      (by simpa using hix) hbi (by simp [has])) ⟨q, by simp only [Ctx.closeout]; exact hq⟩
  refine Except.Holds.ite holds_throw_bind ?_
  refine Except.Holds.ite holds_throw_bind ?_
  let K : SState α → Prop := fun s' =>
    (∀ f, Event.fill f ∈ s'.trace.toList → Event.fill f ∈ s₁.trace.toList ∨ FillLaw N p m v pol stop f) ∧
    s'.orders = [] ∧ s'.marks.size = m.intervals.size ∧ s'.proj = s₁.proj ∧
    ∀ y ∈ s'.book.pos, ∃ bar ∈ m.bars.toList, bar.coin = y.1 ∧ bar.openTime ≤ pol.wStart + ↑j * BAR + BAR
  have hK₅ : ∀ (s' : SState α), s'.trace = s₄.trace.push (.equity (pol.wStart + ↑j * BAR + BAR)
      (Book.equity N s₄.book s₄.marks) (Book.reconciled N s₄.book s₄.marks)) →
      s'.orders = s₄.orders.filter (fun x => x.fst != pol.wStart + ↑j * BAR + BAR) → s'.marks = s₄.marks →
      s'.proj = s₄.proj → s'.book = s₄.book → K s' := by
    intro s' htr ho hm hpr hb
    refine ⟨fun f hf => ?_, ?_, by rw [hm, hJ₄.2.2.1, hmk₂], hpr.trans hJ₄.2.2.2.1, fun y hy => ?_⟩
    · rw [htr] at hf
      rcases fill_mem_push hf with hf | hf
      · exact hJ₄.1 f hf
      · cases hf
    · rw [ho, hJ₄.2.1, List.filter_eq_nil_iff]
      intro e he; simp [(h₁.orders e he).1]
    · rw [hb] at hy
      obtain ⟨q, hq⟩ := hJ₄.2.2.2.2 y hy
      obtain ⟨bar, hbar, hbc, hbo⟩ := h₁.pos _ hq
      exact ⟨bar, hbar, hbc, by omega⟩
  have K_push : ∀ s' (e : Event α), (∀ f, e ≠ .fill f) → K s' → K { s' with trace := s'.trace.push e } := by
    intro s' e he hK
    refine ⟨fun f hf => ?_, hK.2.1, hK.2.2.1, hK.2.2.2.1, hK.2.2.2.2⟩
    rcases fill_mem_push hf with hf | hf
    · exact hK.1 f hf
    · exact absurd hf (he f)
  refine Except.Holds.join (R := K) (fun _ => Except.Holds.forIn_list _ _ _ K (hK₅ _ rfl rfl rfl rfl rfl)
    fun o ho s' hK => ?_) (fun _ => hK₅ _ rfl rfl rfl rfl rfl) fun s₆ hK₆ => ?_
  · obtain ⟨e, he, rfl⟩ := List.mem_map.mp ho
    obtain ⟨he, hed⟩ := List.mem_filter.mp he
    rw [hJ₄.2.1] at he
    obtain ⟨-, hdec, hmach⟩ := h₁.orders e he
    split
    · rename_i i hbi
      refine Except.Holds.ite_cond (fun htr => ?_) fun _ => Except.Holds.pure _ (K_push _ _ (fun f h => by cases h) hK)
      refine Except.Holds.bind (R := K) (fun r hr => ?_) fun r hr => Except.Holds.pure _ hr
      obtain ⟨hchk, htr', ho', hmk', hpr', hpos'⟩ := execute_spec N _ s' r _ hr
      have htr : m.bars[i]!.trades ≥ 1 := by simpa [Ctx.make] using (Bool.and_eq_true_iff.mp htr).1
      have hlaw := ordinary_law N p m hA v pol stop e.2 (pol.wStart + (j : Int) * BAR) i hbi htr hchk hdec hmach
      obtain ⟨hi', hcoin, hopen⟩ := barAt_sound m _ hbi
      refine ⟨fun f hf => ?_, ho'.trans hK.2.1, by rw [hmk']; exact hK.2.2.1, hpr'.trans hK.2.2.2.1, fun y hy => ?_⟩
      · rw [htr'] at hf
        rcases fill_mem_push hf with hf | hf
        · exact hK.1 f hf
        · cases hf; exact Or.inr hlaw
      · rw [hpos'] at hy
        rcases fill_pos N _ _ _ _ _ _ hy with ⟨q, hq⟩ | hq
        · exact hK.2.2.2.2 (y.1, q) hq
        · exact ⟨m.bars[i], Array.getElem_mem_toList hi', by rw [hcoin, hq], by rw [hopen]; omega⟩
    · exact Except.Holds.pure _ (K_push _ _ (fun f h => by cases h) hK)
  refine tickLoop_bind_graft N _ (pol.wStart + (j : Int) * BAR) (List.range' 1 4) s₁ s₆ _ hK₆.2.2.2.1
    fun r hr => ?_
  let D : SState α → Prop := fun s' =>
    (∀ f, Event.fill f ∈ s'.trace.toList → Event.fill f ∈ s₁.trace.toList ∨ FillLaw N p m v pol stop f) ∧
    s'.orders = [] ∧ s'.marks.size = m.intervals.size ∧ s'.proj = r.proj ∧
    ∀ y ∈ s'.book.pos, ∃ bar ∈ m.bars.toList, bar.coin = y.1 ∧ bar.openTime ≤ pol.wStart + ↑j * BAR + BAR
  have D_push : ∀ s' (e : Event α), (∀ f, e ≠ .fill f) → D s' → D { s' with trace := s'.trace.push e } := by
    intro s' e he hD
    refine ⟨fun f hf => ?_, hD.2.1, hD.2.2.1, hD.2.2.2.1, hD.2.2.2.2⟩
    rcases fill_mem_push hf with hf | hf
    · exact hD.1 f hf
    · exact absurd hf (he f)
  refine Except.Holds.bind (R := fun (st : SState α × List (Nat × α)) => D st.1)
    (Except.Holds.forIn_list _ _ _ (fun (st : SState α × List (Nat × α)) => D st.1)
      ⟨hK₆.1, hK₆.2.1, hK₆.2.2.1, proj_graft _ _, hK₆.2.2.2.2⟩ fun c₀ _ st hD => ?_) fun st hD => ?_
  · refine Except.Holds.ite (Except.Holds.pure _ hD) (Except.Holds.ite
      (Except.Holds.pure _ (D_push _ _ (fun f h => by cases h) hD)) ?_)
    split
    · exact Except.Holds.pure _ hD
    · exact Except.Holds.pure _ (D_push _ _ (fun f h => by cases h) hD)
  refine Except.Holds.ite holds_throw_bind ?_
  obtain ⟨t, ht, hp⟩ := h₁.proj
  obtain ⟨t', ht', hp'⟩ := proj_succ N _ j s₁ t ht hp r hr
  have hmach : ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta =
      pol.wStart + ↑j * BAR + BAR + pol.delta ∧
      (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = r.machine.maxKnown := by
    refine ⟨4 * (j + 1), t'.machine, by simp only [BAR, HOUR]; push_cast; omega, ?_, by rw [(proj_eq hp').1]⟩
    rw [Ctx.machineAfter_eq, ht']; rfl
  let O : SState α → Prop := fun s' =>
    (∀ f, Event.fill f ∈ s'.trace.toList → Event.fill f ∈ s₁.trace.toList ∨ FillLaw N p m v pol stop f) ∧
    (∀ e ∈ s'.orders, e.1 = pol.wStart + ↑j * BAR + BAR + BAR ∧ e.2.decided = pol.wStart + ↑j * BAR + BAR + pol.delta ∧
      ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = e.2.decided ∧
        (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = e.2.inputsKnown) ∧
    s'.marks.size = m.intervals.size ∧ s'.proj = r.proj ∧
    ∀ y ∈ s'.book.pos, ∃ bar ∈ m.bars.toList, bar.coin = y.1 ∧ bar.openTime ≤ pol.wStart + ↑j * BAR + BAR
  have O_order : ∀ s' (c₀ : Nat) (w q pr : α), O s' →
      O { s' with trace := s'.trace.push (.decision (pol.wStart + ↑j * BAR + BAR + pol.delta) c₀ w q),
                  orders := s'.orders ++ [(pol.wStart + ↑j * BAR + BAR + BAR,
                    ⟨c₀, q, pr, s'.machine.maxKnown, pol.wStart + ↑j * BAR + BAR + pol.delta⟩)] } := by
    intro s' c₀ w q pr hO
    refine ⟨fun f hf => ?_, fun e he => ?_, hO.2.2.1, hO.2.2.2.1, hO.2.2.2.2⟩
    · rcases fill_mem_push hf with hf | hf
      · exact hO.1 f hf
      · cases hf
    · simp only [List.mem_append, List.mem_singleton] at he
      rcases he with he | rfl
      · exact hO.2.1 e he
      · refine ⟨rfl, rfl, ?_⟩
        obtain ⟨n, ms, hn, hms, hk⟩ := hmach
        exact ⟨n, ms, hn, hms, by rw [hk, (proj_eq hO.2.2.2.1).1]⟩
  refine Except.Holds.bind (R := O) (Except.Holds.forIn_list _ _ _ O
    ⟨hD.1, by rw [hD.2.1]; simp, hD.2.2.1, hD.2.2.2.1, hD.2.2.2.2⟩ fun x _ s' hO => ?_) fun s₈ hO₈ => ?_
  · refine Except.Holds.ite ?_ ?_ <;>
      exact Except.Holds.ite (Except.Holds.pure _ (O_order _ _ _ _ _ hO)) (Except.Holds.pure _ hO)
  have hj1 : pol.wStart + ((j + 1 : Nat) : Int) * BAR = pol.wStart + ↑j * BAR + BAR := by
    push_cast; rw [Int.add_mul, Int.one_mul, Int.add_assoc]
  refine Except.Holds.pure _ ⟨fun f hf => ?_, fun e he => ?_, fun y hy => ?_, hO₈.2.2.1, ⟨t', ht', ?_⟩⟩
  · exact (hO₈.1 f hf).elim (h₁.fills f) id
  · rw [hj1]; exact hO₈.2.1 e he
  · rw [hj1]; exact hO₈.2.2.2.2 y hy
  · rw [hp', hO₈.2.2.2.1]

/-- The start has an empty trace, no orders or positions, and a mark slot per coin. -/
theorem start_state (N : NumOps α) (c : Ctx α) : Except.Holds (c.start N)
    (fun s => s.trace = #[] ∧ s.orders = [] ∧ s.book.pos = [] ∧ s.marks.size = c.coins ∧ s.equity = #[]) := by
  intro s hs
  unfold Ctx.start at hs
  rw [← graft_self (c.state0 N) _ rfl, deliver_graft] at hs
  split at hs
  · cases hs
  generalize c.deliver _ _ = d at hs
  cases d <;> simp only [Except.map, bind, Except.bind, pure, Except.pure, Except.ok.injEq, reduceCtorEq] at hs
  subst hs
  simp [SState.graft, Ctx.state0]

theorem start_inv4 (N : NumOps α) (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) :
    Except.Holds ((Ctx.make p m v pol stop).start N) (Inv4 N p m v pol stop 0) := by
  intro s hs
  obtain ⟨htr, ho, hp, hm, -⟩ := start_state N _ s hs
  exact ⟨by simp [htr], by simp [ho], by simp [hp], hm, s, by rw [hs]; rfl, rfl⟩

theorem steps_inv4 (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (j : Nat) (hj : j ≤ (Ctx.make p m v pol stop).bounds.length) :
    Except.Holds ((Ctx.make p m v pol stop).steps N j) (Inv4 N p m v pol stop j) :=
  steps_induct N _ _ (start_inv4 N p m v pol stop) (step_inv4 N p m hA v pol stop) j hj

end Ref
